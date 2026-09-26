#import "CTExternalCarPlayWindow.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <AVFoundation/AVFoundation.h>

static id CTKVC(id object, NSString *key) {
    @try { return [object valueForKey:key]; }
    @catch (__unused NSException *exception) { return nil; }
}
static id CTCall0(id object, NSString *selector) {
    if (!object) return nil;
    SEL sel=NSSelectorFromString(selector);
    if (![object respondsToSelector:sel]) return nil;
    return ((id(*)(id,SEL))objc_msgSend)(object,sel);
}
static id CTCall1(id object, NSString *selector, id a) {
    if (!object) return nil;
    SEL sel=NSSelectorFromString(selector);
    if (![object respondsToSelector:sel]) return nil;
    return ((id(*)(id,SEL,id))objc_msgSend)(object,sel,a);
}
static id CTCall2(id object, NSString *selector, id a, id b) {
    if (!object) return nil;
    SEL sel=NSSelectorFromString(selector);
    if (![object respondsToSelector:sel]) return nil;
    return ((id(*)(id,SEL,id,id))objc_msgSend)(object,sel,a,b);
}
static id CTCall3(id object, NSString *selector, id a, id b, id c) {
    if (!object) return nil;
    SEL sel=NSSelectorFromString(selector);
    if (![object respondsToSelector:sel]) return nil;
    return ((id(*)(id,SEL,id,id,id))objc_msgSend)(object,sel,a,b,c);
}
static void CTCallBool1(id object, NSString *selector, BOOL value) {
    if (!object) return;
    SEL sel=NSSelectorFromString(selector);
    if ([object respondsToSelector:sel]) ((void(*)(id,SEL,BOOL))objc_msgSend)(object,sel,value);
}
static void CTCallInt1(id object, NSString *selector, int value) {
    if (!object) return;
    SEL sel=NSSelectorFromString(selector);
    if ([object respondsToSelector:sel]) ((void(*)(id,SEL,int))objc_msgSend)(object,sel,value);
}
static id CTFindCarPlayDisplay(void) {
    dlopen("/System/Library/Frameworks/AVFoundation.framework/AVFoundation",RTLD_NOW|RTLD_GLOBAL);
    Class externalClass=objc_getClass("AVExternalDevice");
    id external=CTCall0(externalClass, @"currentCarPlayExternalDevice");
    NSArray *identifiers=CTCall0(external, @"screenIDs");
    if (![identifiers isKindOfClass:NSArray.class] || identifiers.count==0) return nil;
    NSString *wanted=identifiers.firstObject;
    for (id display in CTCall0(objc_getClass("CADisplay"), @"displays")) {
        if ([wanted isEqual:CTCall0(display, @"uniqueId")]) return display;
    }
    return nil;
}

@interface CTExternalCarPlayWindow ()
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) id appViewController;
@property(nonatomic,strong) id application;
@end

@implementation CTExternalCarPlayWindow
- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier {
    self=[super init];
    if (!self) return nil;
    @try {
        id display=CTFindCarPlayDisplay();
        if (!display) { NSLog(@"[ConnectTA-Host] no CarPlay display"); return nil; }

        id controller=CTCall0(objc_getClass("SBApplicationController"), @"sharedInstance");
        self.application=CTCall1(controller, @"applicationWithBundleIdentifier:", bundleIdentifier);
        if (!self.application) { NSLog(@"[ConnectTA-Host] app not found %@",bundleIdentifier); return nil; }

        Class displayConfigClass=objc_getClass("FBSDisplayConfiguration");
        id displayConfig=((id(*)(id,SEL,id,BOOL))objc_msgSend)([displayConfigClass alloc],NSSelectorFromString(@"initWithCADisplay:isMainDisplay:"),display,NO);
        Class windowClass=objc_getClass("UIRootSceneWindow");
        self.window=CTCall1([windowClass alloc], @"initWithDisplayConfiguration:", displayConfig);
        if (!self.window) { NSLog(@"[ConnectTA-Host] UIRootSceneWindow unavailable"); return nil; }
        self.window.layer.cornerRadius=13.0;
        self.window.layer.masksToBounds=YES;

        id manager=CTCall0(objc_getClass("SBSceneManagerCoordinator"), @"mainDisplaySceneManager");
        id layout=CTCall0(manager, @"_layoutStateManager");
        id mainIdentity=CTCall0(manager, @"displayIdentity");
        id sceneIdentity=CTCall2(manager, @"_sceneIdentityForApplication:createPrimaryIfRequired:", self.application, @YES);
        id request=CTCall3(objc_getClass("SBApplicationSceneHandleRequest"), @"defaultRequestForApplication:sceneIdentity:displayIdentity:", self.application, sceneIdentity, mainIdentity);
        id sceneHandle=CTCall1(manager, @"fetchOrCreateApplicationSceneHandleForRequest:", request);
        id entity=CTCall1([objc_getClass("SBDeviceApplicationSceneEntity") alloc], @"initWithApplicationSceneHandle:", sceneHandle);
        self.appViewController=CTCall2([objc_getClass("SBAppViewController") alloc], @"initWithIdentifier:andApplicationSceneEntity:", bundleIdentifier, entity);
        if (!self.appViewController) { NSLog(@"[ConnectTA-Host] SBAppViewController unavailable for %@",bundleIdentifier); return nil; }

        CTCallBool1(self.appViewController, @"setIgnoresOcclusions:", NO);
        @try { [self.appViewController setValue:@2 forKey:@"_currentMode"]; } @catch (__unused NSException *exception) {}
        CTCall0(CTKVC(self.appViewController,@"_activationSettings"), @"clearActivationSettings");
        id transaction=CTCall2(self.appViewController, @"_createSceneUpdateTransactionForApplicationSceneEntity:deliveringActions:", entity, @YES);
        NSMutableArray *active=CTKVC(self.appViewController,@"_activeTransitions");
        if ([active isKindOfClass:NSMutableArray.class] && transaction) [active addObject:transaction];
        id begin=transaction;
        SEL beginSelector=NSSelectorFromString(@"begin");
        if ([begin respondsToSelector:beginSelector]) ((void(*)(id,SEL))objc_msgSend)(begin,beginSelector);
        CTCall0(self.appViewController, @"_createSceneViewController");

        id animation=CTCall0(objc_getClass("SBApplicationSceneView"), @"defaultDisplayModeAnimationFactory");
        id appView=CTCall0(self.appViewController, @"appView");
        if (appView) ((void(*)(id,SEL,int,id,id))objc_msgSend)(appView,NSSelectorFromString(@"setDisplayMode:animationFactory:completion:"),4,animation,nil);
        UIView *content=CTCall0(self.appViewController,@"view");
        if (!content) { NSLog(@"[ConnectTA-Host] app scene view missing %@",bundleIdentifier); return nil; }
        CGRect bounds=self.window.bounds;
        if (CGRectIsEmpty(bounds)) bounds=UIScreen.mainScreen.bounds;
        content.frame=bounds;
        content.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        content.backgroundColor=UIColor.blackColor;
        [self.window addSubview:content];
        self.window.alpha=0;
        self.window.hidden=NO;
        [UIView animateWithDuration:0.25 animations:^{ self.window.alpha=1; }];
        NSLog(@"[ConnectTA-Host] attached %@ display=%@ frame=%@ layout=%@",bundleIdentifier,display,NSStringFromCGRect(bounds),layout);
    } @catch (NSException *exception) {
        NSLog(@"[ConnectTA-Host] failed %@: %@ %@",bundleIdentifier,exception.name,exception.reason);
        return nil;
    }
    return self;
}
- (void)dismiss {
    @try {
        [UIView animateWithDuration:0.15 animations:^{ self.window.alpha=0; } completion:^(__unused BOOL finished) {
            self.window.hidden=YES;
            CTCallInt1(self.appViewController,@"_setCurrentMode:",0);
            [CTCall0(self.appViewController,@"view") removeFromSuperview];
            self.window=nil;
            self.appViewController=nil;
            self.application=nil;
        }];
    } @catch (NSException *exception) {
        NSLog(@"[ConnectTA-Host] dismiss failed %@ %@",exception.name,exception.reason);
    }
}
@end

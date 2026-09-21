#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <notify.h>
#import <dlfcn.h>
#import <math.h>

static NSString *const MTBuild=@"88-HOSTALIGN";
static id gEnvironment=nil, gYouTubeInfo=nil, gController=nil;
static NSDictionary *gActivation=nil;
static UIWindow *gWindow=nil;
static UIView *gPresentation=nil;
static BOOL gStarted=NO, gPolling=NO;
static NSUInteger gGeneration=0;

static void MTLog(NSString *format,...){
    va_list args;va_start(args,format);
    NSString *message=[[NSString alloc]initWithFormat:format arguments:args];va_end(args);
    NSString *line=[NSString stringWithFormat:@"[%@ pid=%d] %@\n",MTBuild,NSProcessInfo.processInfo.processIdentifier,message];
    NSLog(@"%@",line);
    BOOL app=[NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.google.ios.youtube"];
    NSString *path=app?[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/MiniTa-client.txt"]:([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.CarPlayApp"]?@"/var/mobile/MiniTa.txt":@"/var/mobile/MiniTa-admission.txt");
    @synchronized(NSFileManager.class){
        NSData *data=[line dataUsingEncoding:NSUTF8StringEncoding];
        NSFileHandle *file=[NSFileHandle fileHandleForWritingAtPath:path];
        if(!file){[data writeToFile:path atomically:YES];return;}
        @try{[file seekToEndOfFile];[file writeData:data];}@catch(__unused NSException *e){}
        [file closeFile];
    }
}
static id MTV(id object,NSString *key){@try{return[object valueForKey:key];}@catch(__unused NSException *e){return nil;}}
static BOOL MTIsYouTube(id info){
    return [MTV(info,@"bundleIdentifier") isEqualToString:@"com.google.ios.youtube"];
}
static UIWindowScene *MTCarScene(void){
    for(UIScene *scene in UIApplication.sharedApplication.connectedScenes){
        if([scene isKindOfClass:UIWindowScene.class] && [scene.session.persistentIdentifier containsString:@"DBDashboard-Car"])return (UIWindowScene*)scene;
    }
    // This code executes only in CarPlayApp; accept its external window scene.
    for(UIScene *scene in UIApplication.sharedApplication.connectedScenes){
        if([scene isKindOfClass:UIWindowScene.class] && ((UIWindowScene*)scene).screen!=UIScreen.mainScreen)return (UIWindowScene*)scene;
    }
    return nil;
}
static void MTReset(void){
    gGeneration++;gStarted=NO;gPolling=NO;
    gWindow.hidden=YES;[gPresentation removeFromSuperview];
    gPresentation=nil;gWindow=nil;gController=nil;gEnvironment=nil;gActivation=nil;gYouTubeInfo=nil;
}
static void MTHostTick(NSUInteger count,NSUInteger generation){
    if(generation!=gGeneration)return;
    @try{
        id scene=MTV(gController,@"scene");
        SEL selector=NSSelectorFromString(@"presentationViewWithIdentifier:");
        if(!gPresentation && scene && [gController respondsToSelector:selector]){
            id view=((id(*)(id,SEL,id))objc_msgSend)(gController,selector,@"com.sushibta.minita.direct79");
            Class presentationClass=NSClassFromString(@"_UIScenePresentationView");
            if(presentationClass && [view isKindOfClass:presentationClass])gPresentation=view;
        }
        UIWindowScene *windowScene=MTCarScene();
        if(gPresentation && windowScene && !gWindow){
            gWindow=[[UIWindow alloc]initWithWindowScene:windowScene];
            gWindow.frame=windowScene.coordinateSpace.bounds;
            gWindow.windowLevel=UIWindowLevelAlert+60;
            gWindow.rootViewController=[UIViewController new];
            UIView *root=gWindow.rootViewController.view;
            root.backgroundColor=UIColor.blackColor;
            [gPresentation removeFromSuperview];
            gPresentation.frame=root.bounds;
            gPresentation.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            [root addSubview:gPresentation];gWindow.hidden=NO;
            MTLog(@"[DIRECT-ATTACH] frame=%@ windowScene=%@",NSStringFromCGRect(gPresentation.frame),windowScene.session.persistentIdentifier);
        }
        if(count==0 || count==2 || count==6 || count==12 || count==24){
            MTLog(@"[DIRECT-STATE] n=%lu scene=%@ client=%@ foreground=%@ attached=%d definition=%@ clientSettings=%@",
                (unsigned long)count,MTV(scene,@"identifier"),MTV(scene,@"clientProcess"),MTV(MTV(scene,@"settings"),@"foreground"),gPresentation.window!=nil,MTV(scene,@"definition"),MTV(scene,@"clientSettings"));
        }
    }@catch(NSException *e){MTLog(@"[DIRECT-HOST-ERROR] %@ %@",e.name,e.reason);}
    if(count<24){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{MTHostTick(count+1,generation);});}
    else{gPolling=NO;MTLog(@"[DIRECT-END] host retained; device image still requires visual confirmation");}
}
static void MTStartHost(NSUInteger generation){
    dispatch_async(dispatch_get_main_queue(),^{
        if(generation!=gGeneration || gPolling || !gController)return;
        gPolling=YES;MTHostTick(0,generation);
    });
}
static void __attribute__((unused)) MTTryDirectLaunch(void){
    if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{MTTryDirectLaunch();});return;}
    if(gStarted || !gEnvironment || !gActivation || !MTCarScene())return;
    gStarted=YES;
    @try{
        Class proxyClass=NSClassFromString(@"LSApplicationProxy");
        Class infoClass=NSClassFromString(@"DBApplicationInfo");
        Class controllerClass=NSClassFromString(@"DBApplicationSceneViewController");
        SEL lookup=NSSelectorFromString(@"applicationProxyForIdentifier:");
        SEL makeInfo=NSSelectorFromString(@"initWithApplicationProxy:");
        SEL makeController=NSSelectorFromString(@"initWithApplicationInfo:proxyApplicationInfo:environment:");
        SEL foreground=NSSelectorFromString(@"foregroundSceneWithSettings:completion:");
        if(![proxyClass respondsToSelector:lookup] || ![infoClass instancesRespondToSelector:makeInfo] || ![controllerClass instancesRespondToSelector:makeController]){
            MTLog(@"[DIRECT-STOP] required constructor unavailable");return;
        }
        id proxy=((id(*)(id,SEL,id))objc_msgSend)(proxyClass,lookup,@"com.google.ios.youtube");
        if(!proxy){MTLog(@"[DIRECT-STOP] YouTube not installed");return;}
        gYouTubeInfo=((id(*)(id,SEL,id))objc_msgSend)([infoClass alloc],makeInfo,proxy);
        if(!gYouTubeInfo){MTLog(@"[DIRECT-STOP] missing app info");return;}
        // The app is the scene client. No Maps proxy, no parallel DBEvent launch.
        gController=((id(*)(id,SEL,id,id,id))objc_msgSend)([controllerClass alloc],makeController,gYouTubeInfo,nil,gEnvironment);
        if(!gController || ![gController respondsToSelector:foreground]){MTLog(@"[DIRECT-STOP] controller/foreground unavailable");return;}
        NSMutableDictionary *activation=[gActivation mutableCopy];
        activation[@"DBActivationSettingSuspended"]=@NO;
        MTLog(@"[DIRECT-LAUNCH] controller=%@ app=%@ proxy=%@ sceneID=%@ activation=%@",gController,MTV(gController,@"applicationInfo"),MTV(gController,@"proxyApplicationInfo"),MTV(gController,@"sceneID"),activation);
        NSUInteger generation=gGeneration;
        void (^done)(void)=^{if(generation==gGeneration){MTLog(@"[DIRECT-COMPLETION]");MTStartHost(generation);}};
        ((void(*)(id,SEL,id,id))objc_msgSend)(gController,foreground,activation,done);
        MTStartHost(generation);
    }@catch(NSException *e){MTLog(@"[DIRECT-LAUNCH-ERROR] %@ %@",e.name,e.reason);}
}

static BOOL MTHybridIsYTProxy(id proxy){
    @try { id b=MTV(proxy,@"bundleIdentifier"); return [b isEqualToString:@"com.google.ios.youtube"]; }
    @catch(__unused NSException *e){ return NO; }
}
static IMP mtOrigInfo=nil, mtOrigEnt2=nil, mtOrigEnt3=nil;
static id MTHybridInfo(id self,SEL _cmd,NSString *key,Class expected){
    id value=((id(*)(id,SEL,id,id))mtOrigInfo)(self,_cmd,key,expected);
    if(!MTHybridIsYTProxy(self)) return value;
    @try{
        if([key isEqualToString:@"SBStarkLaunchModes"] && (!expected||expected==NSArray.class)){
            MTLog(@"[HYBRID-ADMIT] SBStarkLaunchModes");
            return value?:@[@"Default"];
        }
        if([key isEqualToString:@"UIApplicationSceneManifest"] && (!expected||expected==NSDictionary.class)){
            NSDictionary *orig=[value isKindOfClass:NSDictionary.class]?value:nil;
            NSMutableDictionary *manifest=orig?[orig mutableCopy]:[NSMutableDictionary dictionary];
            NSDictionary *old=manifest[@"UISceneConfigurations"];
            NSMutableDictionary *cfg=[old isKindOfClass:NSDictionary.class]?[old mutableCopy]:[NSMutableDictionary dictionary];
            for(NSString *role in [cfg.allKeys copy]) if([role hasPrefix:@"CPTemplateApplication"]) [cfg removeObjectForKey:role];
            if(!cfg[@"UIWindowSceneSessionRoleCarPlay"]) cfg[@"UIWindowSceneSessionRoleCarPlay"]=@[@{@"UISceneConfigurationName":@"MiniTa"}];
            manifest[@"UISceneConfigurations"]=cfg;
            manifest[@"UIApplicationSupportsMultipleScenes"]=@YES;
            [manifest removeObjectForKey:@"CPSupportsDashboardNavigationScene"];
            [manifest removeObjectForKey:@"CPSupportsInstrumentClusterNavigationScene"];
            MTLog(@"[HYBRID-ADMIT] manifest roles=%@",cfg.allKeys);
            return manifest;
        }
    }@catch(NSException *e){MTLog(@"[HYBRID-ADMIT] info error %@ %@",e.name,e.reason);}
    return value;
}
static BOOL MTHybridCapability(NSString *key){
    return [key isEqualToString:@"CARCapableApp"]||[key isEqualToString:@"SBStarkCapable"];
}
static BOOL MTHybridTemplateCapability(NSString *key){
    return [key hasPrefix:@"com.apple.developer.carplay-"]||[key isEqualToString:@"com.apple.developer.playable-content"];
}
static id MTHybridEnt2(id self,SEL _cmd,NSString *key,Class expected){
    id value=((id(*)(id,SEL,id,id))mtOrigEnt2)(self,_cmd,key,expected);
    if(!MTHybridIsYTProxy(self)) return value;
    if(MTHybridTemplateCapability(key)){MTLog(@"[HYBRID-ADMIT] hide entitlement %@",key);return nil;}
    if(!value&&MTHybridCapability(key)&&(!expected||expected==NSNumber.class)){MTLog(@"[HYBRID-ADMIT] grant %@",key);return @YES;}
    return value;
}
static id MTHybridEnt3(id self,SEL _cmd,NSString *key,Class expected,Class valuesExpected){
    id value=((id(*)(id,SEL,id,id,id))mtOrigEnt3)(self,_cmd,key,expected,valuesExpected);
    if(!MTHybridIsYTProxy(self)) return value;
    if(MTHybridTemplateCapability(key)){MTLog(@"[HYBRID-ADMIT] hide entitlement %@",key);return nil;}
    if(!value&&MTHybridCapability(key)&&(!expected||expected==NSNumber.class)){MTLog(@"[HYBRID-ADMIT] grant %@",key);return @YES;}
    return value;
}
static void MTHybridInstallAdmission(void){
    Class c=NSClassFromString(@"LSBundleProxy"); if(!c){MTLog(@"[HYBRID-ADMIT] LSBundleProxy missing");return;}
    Method m=class_getInstanceMethod(c,NSSelectorFromString(@"objectForInfoDictionaryKey:ofClass:"));
    if(m){mtOrigInfo=method_getImplementation(m);method_setImplementation(m,(IMP)MTHybridInfo);}
    m=class_getInstanceMethod(c,NSSelectorFromString(@"entitlementValueForKey:ofClass:"));
    if(m){mtOrigEnt2=method_getImplementation(m);method_setImplementation(m,(IMP)MTHybridEnt2);}
    m=class_getInstanceMethod(c,NSSelectorFromString(@"entitlementValueForKey:ofClass:valuesOfClass:"));
    if(m){mtOrigEnt3=method_getImplementation(m);method_setImplementation(m,(IMP)MTHybridEnt3);}
    MTLog(@"[HYBRID-ADMIT] installed info=%d ent2=%d ent3=%d",mtOrigInfo!=nil,mtOrigEnt2!=nil,mtOrigEnt3!=nil);
}

// This experiment sets the idiom before YouTube creates/caches its phone UI.
// Scoped by explicit Logos group initialization to the YouTube process only.
static volatile int32_t gDeviceIdiomReads=0, gTraitIdiomReads=0;
%group MTTabletIdentity
%hook UIDevice
- (UIUserInterfaceIdiom)userInterfaceIdiom {
    __sync_fetch_and_add(&gDeviceIdiomReads,1);
    return UIUserInterfaceIdiomPad;
}
%end
%hook UITraitCollection
- (UIUserInterfaceIdiom)userInterfaceIdiom {
    __sync_fetch_and_add(&gTraitIdiomReads,1);
    return UIUserInterfaceIdiomPad;
}
%end
%end

static UIWindow *gAppCarWindow=nil, *gDonorWindow=nil;
static UIViewController *gMovedRoot=nil, *gDonorPlaceholder=nil;
static BOOL gAppPumpRunning=NO;
static NSUInteger gAppEpoch=0;
static IMP mtOrigSceneConfigInit=nil,mtOrigSessionRole=nil,mtOrigSupportsMulti=nil;
static IMP mtOrigSetDelegate=nil,mtOrigDelegateConfig=nil;
static Class gPatchedDelegateClass=Nil;
static void MTAppStage(const char *stage){
    NSString *name=[@"com.sushibta.minita.client80." stringByAppendingString:[NSString stringWithUTF8String:stage]];
    notify_post(name.UTF8String);MTLog(@"[CLIENT80] %s",stage);
}
// Lay out the live app at tablet width before mapping its coordinates to CarPlay.
// UIKit performs inverse coordinate conversion for gestures in the transformed canvas.
@interface MTTabletContainer : UIViewController
@property(nonatomic,strong) UIViewController *content;
@property(nonatomic,strong) UIView *canvas;
@property(nonatomic,strong) NSArray<NSLayoutConstraint *> *contentConstraints;
@property(nonatomic,assign) CGRect reportedViewport;
@property(nonatomic,assign) CGSize originalPreferredSize;
@property(nonatomic,assign) BOOL originalTranslates;
@property(nonatomic,assign) BOOL originalPresentationContext;
@property(nonatomic,assign) UIViewAutoresizing originalAutoresizing;
@property(nonatomic,assign) CGRect originalBounds;
@property(nonatomic,assign) CGPoint originalCenter;
@property(nonatomic,assign) CGAffineTransform originalTransform;
- (instancetype)initWithContent:(UIViewController *)content;
- (void)detachContent;
@end
@implementation MTTabletContainer
- (instancetype)initWithContent:(UIViewController *)content {
    self=[super initWithNibName:nil bundle:nil];
    if(self){
        _content=content;_originalPreferredSize=content.preferredContentSize;_originalPresentationContext=content.definesPresentationContext;
        UIView *v=content.view;
        _originalTranslates=v.translatesAutoresizingMaskIntoConstraints;
        _originalAutoresizing=v.autoresizingMask;
        _originalBounds=v.bounds;_originalCenter=v.center;_originalTransform=v.transform;
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=UIColor.blackColor;
    self.view.clipsToBounds=YES;
    self.canvas=[[UIView alloc]initWithFrame:CGRectMake(0,0,1024,576)];
    self.canvas.backgroundColor=UIColor.blackColor;
    [self.view addSubview:self.canvas];
    [self addChildViewController:self.content];
    UITraitCollection *traits=[UITraitCollection traitCollectionWithTraitsFromCollections:@[
        [UITraitCollection traitCollectionWithUserInterfaceIdiom:UIUserInterfaceIdiomPad],
        [UITraitCollection traitCollectionWithHorizontalSizeClass:UIUserInterfaceSizeClassRegular],
        [UITraitCollection traitCollectionWithVerticalSizeClass:UIUserInterfaceSizeClassRegular],
        [UITraitCollection traitCollectionWithPreferredContentSizeCategory:UIContentSizeCategoryMedium]
    ]];
    [self setOverrideTraitCollection:traits forChildViewController:self.content];
    UIView *v=self.content.view;
    v.transform=CGAffineTransformIdentity;
    v.translatesAutoresizingMaskIntoConstraints=NO;
    [self.canvas addSubview:v];
    self.contentConstraints=@[
        [v.leadingAnchor constraintEqualToAnchor:self.canvas.leadingAnchor],
        [v.trailingAnchor constraintEqualToAnchor:self.canvas.trailingAnchor],
        [v.topAnchor constraintEqualToAnchor:self.canvas.topAnchor],
        [v.bottomAnchor constraintEqualToAnchor:self.canvas.bottomAnchor]
    ];
    [NSLayoutConstraint activateConstraints:self.contentConstraints];
    [self.content didMoveToParentViewController:self];
    // Keep presentations owned by the content subtree when UIKit permits it.
    self.content.definesPresentationContext=YES;
    MTAppStage("tablet");
}
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    [self.view setNeedsLayout];
}
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(__unused id<UIViewControllerTransitionCoordinatorContext> context){
        [self.view setNeedsLayout];[self.view layoutIfNeeded];
    } completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> context){
        [self.view setNeedsLayout];[self.view layoutIfNeeded];
    }];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // UIKit supplies the app-safe rectangle: reserve the dock on whichever side
    // the head unit places it. Do not hard-code screen width or dock thickness.
    CGRect viewport=CGRectIntersection(self.view.bounds,self.view.safeAreaLayoutGuide.layoutFrame);
    if(CGRectIsNull(viewport) || CGRectIsEmpty(viewport))return;
    if(CGRectEqualToRect(viewport,self.reportedViewport))return;
    self.reportedViewport=viewport;
    CGFloat scale=viewport.size.width/1024.0;
    CGSize logical=CGSizeMake(1024.0,viewport.size.height/scale);
    self.canvas.bounds=(CGRect){CGPointZero,logical};
    self.canvas.center=CGPointMake(CGRectGetMidX(viewport),CGRectGetMidY(viewport));
    self.canvas.transform=CGAffineTransformMakeScale(scale,scale);
    // The child is entirely inside the safe area; UIKit computes its local
    // safe area after the transform. Auto Layout reflows against logical bounds.
    if(!CGSizeEqualToSize(self.content.preferredContentSize,logical))self.content.preferredContentSize=logical;
    [self.canvas setNeedsLayout];[self.canvas layoutIfNeeded];
    [self.content.view setNeedsLayout];[self.content.view layoutIfNeeded];
    MTLog(@"[RESIZE86] window=%@ root=%@ safeInsets=%@ viewport=%@ logical=%@ child=%@ scale=%.4f",
          NSStringFromCGRect(self.view.window.bounds),NSStringFromCGRect(self.view.bounds),
          NSStringFromUIEdgeInsets(self.view.safeAreaInsets),NSStringFromCGRect(viewport),
          NSStringFromCGSize(logical),NSStringFromCGRect(self.content.view.bounds),scale);
    MTAppStage("resized-safearea");
    // Send numeric geometry to the main CarPlay log, without sharing app files.
    // Four unsigned 16-bit fields in points: x, y, width, height.
    uint64_t geometry=((uint64_t)MIN(65535,MAX(0,lround(viewport.origin.x)))<<48) |
        ((uint64_t)MIN(65535,MAX(0,lround(viewport.origin.y)))<<32) |
        ((uint64_t)MIN(65535,MAX(0,lround(viewport.size.width)))<<16) |
        (uint64_t)MIN(65535,MAX(0,lround(viewport.size.height)));
    int token=0;
    if(notify_register_check("com.sushibta.minita.geometry86",&token)==NOTIFY_STATUS_OK){
        notify_set_state(token,geometry);notify_post("com.sushibta.minita.geometry86");notify_cancel(token);
    }
}
- (BOOL)shouldAutorotate{return YES;}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations{return UIInterfaceOrientationMaskLandscape;}
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation{return UIInterfaceOrientationLandscapeRight;}
- (BOOL)prefersStatusBarHidden{return YES;}
- (BOOL)prefersHomeIndicatorAutoHidden{return YES;}
- (void)detachContent {
    if(self.content.parentViewController==self){
        [self.content willMoveToParentViewController:nil];
        self.content.definesPresentationContext=self.originalPresentationContext;
        self.content.preferredContentSize=self.originalPreferredSize;
        [NSLayoutConstraint deactivateConstraints:self.contentConstraints];
        self.contentConstraints=nil;
        [self setOverrideTraitCollection:nil forChildViewController:self.content];
        UIView *v=self.content.view;
        [v removeFromSuperview];[self.content removeFromParentViewController];
        v.transform=self.originalTransform;v.bounds=self.originalBounds;v.center=self.originalCenter;
        v.autoresizingMask=self.originalAutoresizing;
        v.translatesAutoresizingMaskIntoConstraints=self.originalTranslates;
    }
}
@end
static MTTabletContainer *gTabletContainer=nil;

static BOOL MTHybridCarRole(NSString *role){return [role hasPrefix:@"CPTemplateApplicationSceneSessionRole"]||[role hasPrefix:@"UIWindowSceneSessionRoleCarPlay"];}
static BOOL MTAppCarSession(UISceneSession *session){
    NSString *role=mtOrigSessionRole?((id(*)(id,SEL))mtOrigSessionRole)(session,@selector(role)):session.role;
    return MTHybridCarRole(role)||[session.persistentIdentifier hasPrefix:@"Car["];
}
static BOOL MTAppCarScene(UIScene *scene){
    return [scene isKindOfClass:UIWindowScene.class] && (MTAppCarSession(scene.session)||((UIWindowScene*)scene).screen!=UIScreen.mainScreen);
}
static void MTAppRestore(void){
    gAppEpoch++;gAppPumpRunning=NO;
    if(gMovedRoot){
        [gTabletContainer detachContent];
        gAppCarWindow.rootViewController=nil;
        gTabletContainer=nil;
        if(gDonorWindow && gDonorWindow.rootViewController==gDonorPlaceholder)gDonorWindow.rootViewController=gMovedRoot;
    }
    gAppCarWindow.hidden=YES;gAppCarWindow=nil;gDonorWindow=nil;gMovedRoot=nil;gDonorPlaceholder=nil;
}
static void MTAppPump(NSUInteger attempt,NSUInteger epoch){
    if(epoch!=gAppEpoch)return;
    @try{
        UIWindowScene *car=nil;
        for(UIScene *scene in UIApplication.sharedApplication.connectedScenes)if(MTAppCarScene(scene)){car=(UIWindowScene*)scene;break;}
        if(car && !gAppCarWindow){
            gAppCarWindow=[[UIWindow alloc]initWithWindowScene:car];
            gAppCarWindow.frame=(CGRect){CGPointZero,car.coordinateSpace.bounds.size};
            gAppCarWindow.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            UIViewController *loading=[UIViewController new];
            loading.view.backgroundColor=[UIColor colorWithRed:0.05 green:0.09 blue:0.16 alpha:1];
            UILabel *label=[[UILabel alloc]initWithFrame:loading.view.bounds];
            label.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            label.text=@"MiniTa 88 — Đang mở YouTube…";label.textColor=UIColor.whiteColor;label.textAlignment=NSTextAlignmentCenter;
            [loading.view addSubview:label];gAppCarWindow.rootViewController=loading;
            [gAppCarWindow makeKeyAndVisible];MTAppStage("window");
        }
        if(gAppCarWindow && !gMovedRoot){
            NSMutableArray *windows=[UIApplication.sharedApplication.windows mutableCopy];
            for(UIScene *scene in UIApplication.sharedApplication.connectedScenes){
                if([scene isKindOfClass:UIWindowScene.class] && !MTAppCarScene(scene))[windows addObjectsFromArray:((UIWindowScene*)scene).windows];
            }
            id delegateWindow=MTV(UIApplication.sharedApplication.delegate,@"window");
            if([delegateWindow isKindOfClass:UIWindow.class] && ![windows containsObject:delegateWindow])[windows addObject:delegateWindow];
            UIWindow *donor=nil;
            for(UIWindow *window in windows){
                if(window==gAppCarWindow || window.screen!=UIScreen.mainScreen || !window.rootViewController || window.windowLevel!=UIWindowLevelNormal)continue;
                if(!donor || (donor.hidden && !window.hidden))donor=window;
            }
            if(donor){
                gDonorWindow=donor;gMovedRoot=donor.rootViewController;
                gDonorPlaceholder=[UIViewController new];gDonorPlaceholder.view.backgroundColor=UIColor.blackColor;
                donor.rootViewController=gDonorPlaceholder;
                gTabletContainer=[[MTTabletContainer alloc]initWithContent:gMovedRoot];
                gAppCarWindow.rootViewController=gTabletContainer;
                [gTabletContainer.view setNeedsLayout];[gTabletContainer.view layoutIfNeeded];
                [gAppCarWindow makeKeyAndVisible];MTAppStage("root");
                MTLog(@"[PAD83-IDENTITY] deviceReads=%d traitReads=%d effectiveIdiom=%ld root=%@",
                      gDeviceIdiomReads,gTraitIdiomReads,(long)gMovedRoot.traitCollection.userInterfaceIdiom,NSStringFromClass(gMovedRoot.class));
                if(gDeviceIdiomReads>0)MTAppStage("pad-device-used");
                if(gTraitIdiomReads>0)MTAppStage("pad-traits-used");
                MTLog(@"[CLIENT80-ROOT] class=%@ frame=%@ scene=%@",NSStringFromClass(gMovedRoot.class),NSStringFromCGRect(gMovedRoot.view.frame),car.session.persistentIdentifier);
            }
        }
    }@catch(NSException *e){MTAppStage("error");MTLog(@"[CLIENT80-ERROR] %@ %@",e.name,e.reason);}
    if(!gMovedRoot && attempt<40){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{MTAppPump(attempt+1,epoch);});}
    else{gAppPumpRunning=NO;if(!gMovedRoot)MTAppStage(gAppCarWindow?"no-root":"no-scene");}
}
static void MTAppStart(void){dispatch_async(dispatch_get_main_queue(),^{if(gAppPumpRunning||gMovedRoot)return;gAppPumpRunning=YES;MTAppPump(0,gAppEpoch);});}
static void MTAppResizeScene(UIWindowScene *scene){
    if(!gAppCarWindow || gAppCarWindow.windowScene!=scene)return;
    CGRect bounds=(CGRect){CGPointZero,scene.coordinateSpace.bounds.size};
    if(CGRectIsEmpty(bounds))return;
    MTLog(@"[VIEWPORT87-CLIENT] scene=%@ localWindow=%@ previousWindow=%@",
        NSStringFromCGRect(scene.coordinateSpace.bounds),NSStringFromCGRect(bounds),NSStringFromCGRect(gAppCarWindow.frame));
    if(!CGRectEqualToRect(gAppCarWindow.frame,bounds))gAppCarWindow.frame=bounds;
    [gAppCarWindow setNeedsLayout];[gAppCarWindow layoutIfNeeded];
    [gTabletContainer.view setNeedsLayout];[gTabletContainer.view layoutIfNeeded];
}
@interface MTYouTubeCarSceneDelegate : UIResponder <UIWindowSceneDelegate>
@end
@implementation MTYouTubeCarSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    (void)scene;(void)session;(void)options;MTAppStage("connect");MTAppStart();
}
- (void)sceneDidBecomeActive:(UIScene *)scene {
    MTAppStart();
    if([scene isKindOfClass:UIWindowScene.class])MTAppResizeScene((UIWindowScene*)scene);
}
- (void)windowScene:(UIWindowScene *)scene didUpdateCoordinateSpace:(id<UICoordinateSpace>)previousCoordinateSpace interfaceOrientation:(UIInterfaceOrientation)previousInterfaceOrientation traitCollection:(UITraitCollection *)previousTraitCollection {
    (void)previousCoordinateSpace;(void)previousInterfaceOrientation;(void)previousTraitCollection;
    MTAppResizeScene(scene);
}
- (void)sceneDidDisconnect:(UIScene *)scene {if(scene==gAppCarWindow.windowScene)MTAppRestore();}
@end
static id MTHybridSceneConfigInit(id self,SEL cmd,NSString *name,NSString *role){
    BOOL car=MTHybridCarRole(role);
    id result=((id(*)(id,SEL,id,id))mtOrigSceneConfigInit)(self,cmd,car?nil:name,car?UIWindowSceneSessionRoleApplication:role);
    if(car){((UISceneConfiguration*)result).sceneClass=UIWindowScene.class;((UISceneConfiguration*)result).delegateClass=MTYouTubeCarSceneDelegate.class;MTAppStage("config");}
    return result;
}
static id MTHybridSessionRole(id self,SEL cmd){NSString *role=((id(*)(id,SEL))mtOrigSessionRole)(self,cmd);return MTHybridCarRole(role)?UIWindowSceneSessionRoleApplication:role;}
static BOOL MTHybridSupportsMulti(id self,SEL cmd){(void)self;(void)cmd;return YES;}
static UISceneConfiguration *MTDelegateConfig(id self,SEL cmd,UIApplication *app,UISceneSession *session,UISceneConnectionOptions *options){
    if(MTAppCarSession(session)){
        UISceneConfiguration *config=[[UISceneConfiguration alloc]initWithName:nil sessionRole:UIWindowSceneSessionRoleApplication];
        config.sceneClass=UIWindowScene.class;config.delegateClass=MTYouTubeCarSceneDelegate.class;MTAppStage("config");return config;
    }
    if(mtOrigDelegateConfig)return ((id(*)(id,SEL,id,id,id))mtOrigDelegateConfig)(self,cmd,app,session,options);
    return session.configuration;
}
static void MTInstallDelegate(id delegate){
    if(!delegate||gPatchedDelegateClass)return;
    Class cls=object_getClass(delegate);SEL sel=@selector(application:configurationForConnectingSceneSession:options:);
    Method method=class_getInstanceMethod(cls,sel);mtOrigDelegateConfig=method?method_getImplementation(method):NULL;
    const char *types=method?method_getTypeEncoding(method):"@@:@@@";
    class_replaceMethod(cls,sel,(IMP)MTDelegateConfig,types);gPatchedDelegateClass=cls;
}
static void MTSetDelegate(id self,SEL cmd,id delegate){MTInstallDelegate(delegate);((void(*)(id,SEL,id))mtOrigSetDelegate)(self,cmd,delegate);}
static void MTHybridInstallAppBridge(void){
    Method m=class_getInstanceMethod(UISceneConfiguration.class,@selector(initWithName:sessionRole:));
    if(m){mtOrigSceneConfigInit=method_getImplementation(m);method_setImplementation(m,(IMP)MTHybridSceneConfigInit);}
    m=class_getInstanceMethod(UISceneSession.class,@selector(role));
    if(m){mtOrigSessionRole=method_getImplementation(m);method_setImplementation(m,(IMP)MTHybridSessionRole);}
    Class manifest=NSClassFromString(@"UIApplicationSceneManifest");m=manifest?class_getInstanceMethod(manifest,NSSelectorFromString(@"supportsMultipleScenes")):NULL;
    if(m){mtOrigSupportsMulti=method_getImplementation(m);method_setImplementation(m,(IMP)MTHybridSupportsMulti);}
    m=class_getInstanceMethod(UIApplication.class,@selector(setDelegate:));
    if(m){mtOrigSetDelegate=method_getImplementation(m);method_setImplementation(m,(IMP)MTSetDelegate);}
    MTInstallDelegate(UIApplication.sharedApplication.delegate);
    for(NSString *name in @[UISceneWillConnectNotification,UISceneDidActivateNotification,UIApplicationDidBecomeActiveNotification]){
        [[NSNotificationCenter defaultCenter]addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note){MTAppStart();}];
    }
    [[NSNotificationCenter defaultCenter]addObserverForName:UISceneDidDisconnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){if(note.object==gAppCarWindow.windowScene)MTAppRestore();}];
    MTAppStage("loaded");MTAppStart();
}

// Policy is evaluated outside the YouTube process as well as in CarPlayApp.
static id MTHomePolicy(id policy,id declaration){
    if(!MTIsYouTube(declaration))return policy;
    if(!policy)policy=[NSClassFromString(@"CRCarPlayAppPolicy") new];
    if(!policy)return nil;
    @try{
        [policy setValue:@YES forKey:@"carPlaySupported"];
        [policy setValue:@YES forKey:@"canDisplayOnCarScreen"];
        [policy setValue:@NO forKey:@"launchUsingSiri"];
        [policy setValue:@NO forKey:@"launchUsingMusicUIService"];
        [policy setValue:@NO forKey:@"launchUsingTemplateUI"];
        static dispatch_once_t once;
        dispatch_once(&once,^{MTLog(@"[HOME84-POLICY] YouTube supported; direct app launch");});
    }@catch(NSException *e){MTLog(@"[HOME84-POLICY-ERROR] %@",e);}
    return policy;
}
%group MTHomeAdmission
%hook CRCarPlayAppDeclaration
- (BOOL)supportsAudio {
    if(MTIsYouTube(self))return YES;
    return %orig;
}
%end
%hook CRCarPlayAppPolicyEvaluator
- (id)effectivePolicyForAppDeclaration:(id)declaration {
    id policy=%orig;
    return MTHomePolicy(policy,declaration);
}
- (id)effectivePolicyForAppDeclaration:(id)declaration inVehicleWithCertificateSerial:(id)serial {
    id policy=%orig;
    return MTHomePolicy(policy,declaration);
}
%end
%end

// Feed Home the installed application's native DBLeafIcon, not an overlay button.
static id gHomeYouTubeIcon=nil;
static BOOL MTHomeIsYTIcon(id icon){
    return MTIsYouTube(MTV(icon,@"applicationInfo")) ||
        [MTV(icon,@"applicationBundleID") isEqualToString:@"com.google.ios.youtube"] ||
        [MTV(icon,@"leafIdentifier") isEqualToString:@"com.google.ios.youtube"];
}
static id MTHomeYouTubeIcon(void){
    if(gHomeYouTubeIcon)return gHomeYouTubeIcon;
    @try{
        Class proxyClass=NSClassFromString(@"LSApplicationProxy");
        Class infoClass=NSClassFromString(@"DBApplicationInfo");
        Class iconClass=NSClassFromString(@"DBLeafIcon");
        SEL lookup=NSSelectorFromString(@"applicationProxyForIdentifier:");
        SEL infoInit=NSSelectorFromString(@"initWithApplicationProxy:");
        SEL iconInit=NSSelectorFromString(@"initWithApplicationInfo:");
        if(![proxyClass respondsToSelector:lookup] || ![infoClass instancesRespondToSelector:infoInit] ||
           ![iconClass instancesRespondToSelector:iconInit]){
            MTLog(@"[HOME85-UNAVAILABLE] proxy=%@ info=%@ icon=%@",proxyClass,infoClass,iconClass);return nil;
        }
        id proxy=((id(*)(id,SEL,id))objc_msgSend)(proxyClass,lookup,@"com.google.ios.youtube");
        if(!MTIsYouTube(proxy))return nil;
        id info=((id(*)(id,SEL,id))objc_msgSend)([infoClass alloc],infoInit,proxy);
        if(!info)return nil;
        gHomeYouTubeIcon=((id(*)(id,SEL,id))objc_msgSend)([iconClass alloc],iconInit,info);
        MTLog(@"[HOME85-CREATED] icon=%@ identifier=%@ info=%@",gHomeYouTubeIcon,MTV(gHomeYouTubeIcon,@"leafIdentifier"),info);
    }@catch(NSException *e){MTLog(@"[HOME85-CREATE-ERROR] %@",e);}
    return gHomeYouTubeIcon;
}
static id MTHomeIncludeYouTube(id original){
    if(original && ![original isKindOfClass:NSArray.class]){
        MTLog(@"[HOME85-LIST-TYPE] %@",NSStringFromClass([original class]));return original;
    }
    for(id icon in original)if(MTHomeIsYTIcon(icon))return original;
    id icon=MTHomeYouTubeIcon();if(!icon)return original;
    NSMutableArray *icons=original?[original mutableCopy]:[NSMutableArray array];
    [icons addObject:icon];
    static dispatch_once_t once;
    dispatch_once(&once,^{MTLog(@"[HOME85-LIST] native YouTube icon appended, count=%lu",(unsigned long)icons.count);});
    return [icons copy];
}
%hook DBDashboardHomeViewController
- (id)allApplicationIcons {
    id icons=%orig;
    return MTHomeIncludeYouTube(icons);
}
- (BOOL)isIconVisible:(id)icon {
    if(MTHomeIsYTIcon(icon))return YES;
    return %orig;
}
- (BOOL)isIconVisibleForIdentifier:(id)identifier {
    if([identifier isEqualToString:@"com.google.ios.youtube"])return YES;
    return %orig;
}
- (void)iconManager:(id)manager launchIconForIconView:(id)view {
    id icon=MTV(view,@"icon");
    if(MTHomeIsYTIcon(icon))MTLog(@"[HOME85-ICON-TAP] native launch %@",MTV(icon,@"applicationInfo"));
    %orig;
}
%end
%hook DBIconLayoutVehicleDataProvider
- (id)allApplicationIcons {
    id icons=%orig;
    return MTHomeIncludeYouTube(icons);
}
%end
%hook DBIconModel
- (BOOL)isIconVisible:(id)icon {
    if(MTHomeIsYTIcon(icon))return YES;
    return %orig;
}
- (id)hiddenBundleIdentifiers {
    id original=%orig;
    if(![original isKindOfClass:NSArray.class])return original;
    NSMutableArray *hidden=[original mutableCopy];
    [hidden removeObject:@"com.google.ios.youtube"];
    return [hidden copy];
}
%end

%hook DBApplicationInfo
- (BOOL)presentsUnderStatusBar {
    if(MTIsYouTube(self))return NO;
    return %orig;
}
- (BOOL)isHidden {
    if(MTIsYouTube(self))return NO;
    return %orig;
}
%end
// Host owns screen-space placement; client owns a zero-origin local window.
static CGRect MTNativeAppViewport(id dashboard,CGRect original){
    UIWindowScene *scene=MTV(dashboard,@"windowScene");
    if(![scene isKindOfClass:UIWindowScene.class])return original;
    CGRect display=scene.coordinateSpace.bounds;
    id config=MTV(dashboard,@"environmentConfiguration");
    id area=MTV(config,@"viewAreaFrame");
    if([area isKindOfClass:NSValue.class] && strcmp([area objCType],@encode(CGRect))==0){
        CGRect candidate=[area CGRectValue];
        CGRect clipped=CGRectIntersection(display,candidate);
        if(!CGRectIsNull(clipped) && !CGRectIsEmpty(clipped))display=clipped;
    }
    SEL insetsSelector=NSSelectorFromString(@"statusBarInsets");
    if(![dashboard respondsToSelector:insetsSelector])return original;
    UIEdgeInsets insets=((UIEdgeInsets(*)(id,SEL))objc_msgSend)(dashboard,insetsSelector);
    if(insets.top<0 || insets.left<0 || insets.bottom<0 || insets.right<0)return original;
    CGRect viewport=UIEdgeInsetsInsetRect(display,insets);
    if(CGRectIsEmpty(viewport) || CGRectIsNull(viewport))return original;
    MTLog(@"[VIEWPORT87-HOST] original=%@ display=%@ dock=%@ target=%@",
          NSStringFromCGRect(original),NSStringFromCGRect(display),NSStringFromUIEdgeInsets(insets),NSStringFromCGRect(viewport));
    return viewport;
}
static char kMTAligning88,kMTLastGeometry88;
static void MTAlignNativeHost(id controller){
    if(!MTIsYouTube(MTV(controller,@"applicationInfo")))return;
    if([objc_getAssociatedObject(controller,&kMTAligning88) boolValue])return;
    UIViewController *vc=(UIViewController*)controller;
    if(!vc.isViewLoaded || !vc.view.window || !vc.view.superview)return;
    UIView *root=vc.view;
    UIView *host=MTV(controller,@"sceneHostView");
    if(![host isKindOfClass:UIView.class] || !host.superview || ![host isDescendantOfView:root])return;
    UIWindowScene *scene=root.window.windowScene;
    if(!scene)return;
    objc_setAssociatedObject(controller,&kMTAligning88,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try{
        CGRect before=[root convertRect:root.bounds toCoordinateSpace:scene.coordinateSpace];
        CGRect target=MTNativeAppViewport(MTV(controller,@"environment"),before);
        CGRect local=[root.superview convertRect:target fromCoordinateSpace:scene.coordinateSpace];
        // Convert screen geometry through the actual parent. Never add 45 points
        // blindly: the parent may already be positioned beyond the dock.
        if(CGAffineTransformIsIdentity(root.transform) && !CGRectEqualToRect(root.frame,local))root.frame=local;
        CGRect hostLocal=[host.superview convertRect:root.bounds fromView:root];
        if(CGAffineTransformIsIdentity(host.transform) && !CGRectEqualToRect(host.frame,hostLocal))host.frame=hostLocal;
        CGRect actual=[host convertRect:host.bounds toCoordinateSpace:scene.coordinateSpace];
        NSString *state=[NSString stringWithFormat:@"rootBefore=%@ target=%@ root=%@ hostFrame=%@ hostScreen=%@ parent=%@ proxy=%@",
            NSStringFromCGRect(before),NSStringFromCGRect(target),NSStringFromCGRect(root.frame),
            NSStringFromCGRect(host.frame),NSStringFromCGRect(actual),NSStringFromClass(root.superview.class),MTV(controller,@"proxyApplicationInfo")];
        if(![state isEqual:objc_getAssociatedObject(controller,&kMTLastGeometry88)]){
            objc_setAssociatedObject(controller,&kMTLastGeometry88,state,OBJC_ASSOCIATION_COPY_NONATOMIC);
            MTLog(@"[HOST88-ALIGN] %@",state);
        }
    }@catch(NSException *e){MTLog(@"[HOST88-ERROR] %@",e);}
    @finally{objc_setAssociatedObject(controller,&kMTAligning88,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
}
%hook DBApplicationSceneViewController
- (id)initWithApplicationInfo:(id)app proxyApplicationInfo:(id)proxy environment:(id)environment {
    if(MTIsYouTube(app)){
        MTLog(@"[HOST88-INIT] remove controller proxy=%@",proxy);
        proxy=nil;
    }
    return %orig(app,proxy,environment);
}
- (id)_initWithApplicationInfo:(id)app proxyApplicationInfo:(id)proxy environment:(id)environment {
    if(MTIsYouTube(app))proxy=nil;
    return %orig(app,proxy,environment);
}
- (BOOL)presentsUnderStatusBar {
    if(MTIsYouTube(MTV(self,@"applicationInfo")))return NO;
    return %orig;
}
- (void)viewDidLayoutSubviews {
    %orig;
    MTAlignNativeHost(self);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    MTAlignNativeHost(self);
}
- (void)setSceneHostView:(id)view {
    %orig;
    dispatch_async(dispatch_get_main_queue(),^{MTAlignNativeHost(self);});
}
%end

%hook DBDashboard
- (CGRect)sceneFrameForAppInfo:(id)app {
    CGRect frame=%orig;
    return MTIsYouTube(app)?MTNativeAppViewport(self,frame):frame;
}
- (CGRect)sceneFrameForAppInfo:(id)app proxyAppInfo:(id)proxy {
    CGRect frame=%orig;
    return MTIsYouTube(app)?MTNativeAppViewport(self,frame):frame;
}
- (UIEdgeInsets)safeAreaInsetsForAppInfo:(id)app {
    if(MTIsYouTube(app))return UIEdgeInsetsZero;
    return %orig;
}
- (UIEdgeInsets)safeAreaInsetsForAppInfo:(id)app proxyAppInfo:(id)proxy {
    if(MTIsYouTube(app))return UIEdgeInsetsZero;
    return %orig;
}
- (void)_handleCarPlayUIReady {
    %orig;
    MTLog(@"[HOME85-READY] homeClass=%@ iconsSelector=%d iconModel=%@ leafClass=%@",
        NSClassFromString(@"DBDashboardHomeViewController"),
        [NSClassFromString(@"DBDashboardHomeViewController") instancesRespondToSelector:NSSelectorFromString(@"allApplicationIcons")],
        NSClassFromString(@"DBIconModel"),NSClassFromString(@"DBLeafIcon"));
}
- (void)_handleOpenApplicationEvent:(id)event {
    id context=MTV(event,@"context");if(!context)context=MTV(event,@"_context");
    id app=MTV(context,@"application");
    if(!app){id value=MTV(context,@"value");if(value){context=value;app=MTV(value,@"application");}}
    if(MTIsYouTube(app))MTLog(@"[HOME84-TAP] YouTube activation=%@",MTV(context,@"activationSettings"));
    %orig;
}
- (id)sceneIdentifierForAppInfo:(id)info {
    id original=%orig;
    if(MTIsYouTube(info) && [original isKindOfClass:NSString.class]){
        NSString *sid=original;
        sid=[sid stringByReplacingOccurrencesOfString:@":com.apple.MusicUIService:" withString:@":"];
        sid=[sid stringByReplacingOccurrencesOfString:@":com.apple.CarPlayTemplateUIHost:" withString:@":"];
        MTLog(@"[DIRECT-ID] %@ -> %@",original,sid);return sid;
    }
    return original;
}
%end
%hook DBSceneUpdate
- (id)initWithApplicationInfo:(id)app proxyApplicationInfo:(id)proxy environment:(id)env activationSettings:(id)settings {
    BOOL target=MTIsYouTube(app);
    if(target)proxy=nil;
    id result=%orig(app,proxy,env,settings);
    if(target)MTLog(@"[HOME84-NATIVE-UPDATE] app=%@ proxy=%@",MTV(result,@"applicationInfo"),MTV(result,@"proxyApplicationInfo"));
    return result;
}
%end

%ctor {
    @autoreleasepool {
        NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
        if([bundle isEqualToString:@"com.google.ios.youtube"]){
            %init(MTTabletIdentity);
            MTLog(@"[PAD83-BOOT] early device + trait idiom override enabled for YouTube process");
            MTLog(@"[DIRECT-APP-LOADED]");MTHybridInstallAppBridge();return;
        }
        BOOL car=[bundle isEqualToString:@"com.apple.CarPlayApp"];
        BOOL spring=[bundle isEqualToString:@"com.apple.springboard"];
        BOOL daemon=[NSProcessInfo.processInfo.processName isEqualToString:@"carplayd"];
        if(!car && !spring && !daemon)return;
        dlopen("/System/Library/PrivateFrameworks/CarKit.framework/CarKit",RTLD_NOW);
        %init(MTHomeAdmission);
        if(!car){MTHybridInstallAdmission();return;}
        %init;
        [[NSFileManager defaultManager]removeItemAtPath:@"/var/mobile/MiniTa.txt" error:nil];
        MTLog(@"[DIRECT-BOOT] native Home icon launch; no automatic Maps launch or overlay host");
        for(NSString *stage in @[@"loaded",@"config",@"connect",@"window",@"root",@"no-root",@"no-scene",@"error",@"tablet",@"canvas-1024",@"regular-both",@"pad-device-used",@"pad-traits-used",@"resized-safearea"]){
            NSString *name=[@"com.sushibta.minita.client80." stringByAppendingString:stage];
            int token=0;
            notify_register_dispatch(name.UTF8String,&token,dispatch_get_main_queue(),^(__unused int t){MTLog(@"[CLIENT80-IPC] %@",stage);});
        }
        int geometryToken=0;
        notify_register_dispatch("com.sushibta.minita.geometry86",&geometryToken,dispatch_get_main_queue(),^(int token){
            uint64_t value=0;
            if(notify_get_state(token,&value)==NOTIFY_STATUS_OK){
                MTLog(@"[RESIZE86-IPC] safeViewport x=%u y=%u width=%u height=%u",
                    (unsigned)((value>>48)&65535),(unsigned)((value>>32)&65535),
                    (unsigned)((value>>16)&65535),(unsigned)(value&65535));
            }
        });
        MTHybridInstallAdmission();
        [[NSNotificationCenter defaultCenter]addObserverForName:UISceneDidDisconnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
            if(note.object==gWindow.windowScene || [((UIScene*)note.object).session.persistentIdentifier containsString:@"DBDashboard-Car"]){MTLog(@"[DIRECT-DISCONNECT]");MTReset();}
        }];
    }
}

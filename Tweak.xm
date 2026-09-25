#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <notify.h>
#import <dlfcn.h>
#import "CTConfig.h"

static NSSet<NSString *> *gEnabledApps;
static BOOL gAppClient=NO, gYouTubeLayout=NO;
static BOOL CTEnabled(id identifier){
    if(!CTEligibleIdentifier(identifier))return NO;
    @synchronized(NSProcessInfo.processInfo){return [gEnabledApps containsObject:identifier];}
}
static NSArray *CTEnabledIdentifiers(void){
    @synchronized(NSProcessInfo.processInfo){return [[gEnabledApps allObjects] sortedArrayUsingSelector:@selector(compare:)];}
}
static void CTReloadConfiguration(void){
    NSSet *apps=CTReadEnabledApps();
    @synchronized(NSProcessInfo.processInfo){gEnabledApps=apps;}
}

static NSString *const CTBuild=@"CONNECTTA-0.4.0";
static void CTLog(NSString *format,...){
    va_list args;va_start(args,format);
    NSString *message=[[NSString alloc]initWithFormat:format arguments:args];va_end(args);
    NSString *line=[NSString stringWithFormat:@"[%@ pid=%d] %@\n",CTBuild,NSProcessInfo.processInfo.processIdentifier,message];
    BOOL app=gAppClient;
    NSString *path=app?[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/ConnectTA-client.txt"]:([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.CarPlayApp"]?@"/var/mobile/ConnectTA.txt":@"/var/mobile/ConnectTA-admission.txt");
    @synchronized(NSFileManager.class){
        NSData *data=[line dataUsingEncoding:NSUTF8StringEncoding];
        NSFileHandle *file=[NSFileHandle fileHandleForWritingAtPath:path];
        if(!file){[data writeToFile:path atomically:YES];return;}
        @try{if([file seekToEndOfFile]>1024*1024){[file truncateFileAtOffset:0];[file seekToFileOffset:0];}[file writeData:data];}@catch(__unused NSException *e){}
        [file closeFile];
    }
}
static id CTV(id object,NSString *key){@try{return[object valueForKey:key];}@catch(__unused NSException *e){return nil;}}
static BOOL CTIsEnabledApp(id info){
    return CTEnabled(CTV(info,@"bundleIdentifier"));
}
static IMP ctOrigInfo=nil, ctOrigEnt2=nil, ctOrigEnt3=nil;
static id CTHybridInfo(id self,SEL _cmd,NSString *key,Class expected){
    id value=((id(*)(id,SEL,id,id))ctOrigInfo)(self,_cmd,key,expected);
    if(!CTIsEnabledApp(self)) return value;
    @try{
        if([key isEqualToString:@"SBStarkLaunchModes"] && (!expected||expected==NSArray.class)){
            return value?:@[@"Default"];
        }
        if([key isEqualToString:@"UIApplicationSceneManifest"] && (!expected||expected==NSDictionary.class)){
            NSDictionary *orig=[value isKindOfClass:NSDictionary.class]?value:nil;
            NSMutableDictionary *manifest=orig?[orig mutableCopy]:[NSMutableDictionary dictionary];
            NSDictionary *old=manifest[@"UISceneConfigurations"];
            NSMutableDictionary *cfg=[old isKindOfClass:NSDictionary.class]?[old mutableCopy]:[NSMutableDictionary dictionary];
            for(NSString *role in [cfg.allKeys copy]) if([role hasPrefix:@"CPTemplateApplication"]) [cfg removeObjectForKey:role];
            if(!cfg[@"UIWindowSceneSessionRoleCarPlay"]) cfg[@"UIWindowSceneSessionRoleCarPlay"]=@[@{@"UISceneConfigurationName":@"ConnectTA"}];
            manifest[@"UISceneConfigurations"]=cfg;
            manifest[@"UIApplicationSupportsMultipleScenes"]=@YES;
            [manifest removeObjectForKey:@"CPSupportsDashboardNavigationScene"];
            [manifest removeObjectForKey:@"CPSupportsInstrumentClusterNavigationScene"];
            return manifest;
        }
    }@catch(NSException *e){CTLog(@"[HYBRID-ADMIT] info error %@ %@",e.name,e.reason);}
    return value;
}
static BOOL CTHybridCapability(NSString *key){
    return [key isEqualToString:@"CARCapableApp"]||[key isEqualToString:@"SBStarkCapable"];
}
static BOOL CTHybridTemplateCapability(NSString *key){
    return [key hasPrefix:@"com.apple.developer.carplay-"]||[key isEqualToString:@"com.apple.developer.playable-content"];
}
static id CTHybridEnt2(id self,SEL _cmd,NSString *key,Class expected){
    id value=((id(*)(id,SEL,id,id))ctOrigEnt2)(self,_cmd,key,expected);
    if(!CTIsEnabledApp(self)) return value;
    if(CTHybridTemplateCapability(key)){return nil;}
    if(!value&&CTHybridCapability(key)&&(!expected||expected==NSNumber.class)){return @YES;}
    return value;
}
static id CTHybridEnt3(id self,SEL _cmd,NSString *key,Class expected,Class valuesExpected){
    id value=((id(*)(id,SEL,id,id,id))ctOrigEnt3)(self,_cmd,key,expected,valuesExpected);
    if(!CTIsEnabledApp(self)) return value;
    if(CTHybridTemplateCapability(key)){return nil;}
    if(!value&&CTHybridCapability(key)&&(!expected||expected==NSNumber.class)){return @YES;}
    return value;
}
static void CTHybridInstallAdmission(void){
    Class c=NSClassFromString(@"LSBundleProxy"); if(!c){CTLog(@"[HYBRID-ADMIT] LSBundleProxy missing");return;}
    Method m=class_getInstanceMethod(c,NSSelectorFromString(@"objectForInfoDictionaryKey:ofClass:"));
    if(m){ctOrigInfo=method_getImplementation(m);method_setImplementation(m,(IMP)CTHybridInfo);}
    m=class_getInstanceMethod(c,NSSelectorFromString(@"entitlementValueForKey:ofClass:"));
    if(m){ctOrigEnt2=method_getImplementation(m);method_setImplementation(m,(IMP)CTHybridEnt2);}
    m=class_getInstanceMethod(c,NSSelectorFromString(@"entitlementValueForKey:ofClass:valuesOfClass:"));
    if(m){ctOrigEnt3=method_getImplementation(m);method_setImplementation(m,(IMP)CTHybridEnt3);}
    CTLog(@"[HYBRID-ADMIT] installed info=%d ent2=%d ent3=%d",ctOrigInfo!=nil,ctOrigEnt2!=nil,ctOrigEnt3!=nil);
}

// Set tablet identity before YouTube creates/caches its UI.
// Scoped by explicit Logos group initialization to the YouTube process only.
%group CTTabletIdentity
%hook UIDevice
- (UIUserInterfaceIdiom)userInterfaceIdiom {
    return UIUserInterfaceIdiomPad;
}
%end
%hook UITraitCollection
- (UIUserInterfaceIdiom)userInterfaceIdiom {
    return UIUserInterfaceIdiomPad;
}
%end
%end

static UIWindow *gAppCarWindow=nil, *gDonorWindow=nil;
static UIViewController *gMovedRoot=nil, *gDonorPlaceholder=nil;
static BOOL gAppPumpRunning=NO;
static NSUInteger gAppEpoch=0;
static IMP ctOrigSceneConfigInit=nil,ctOrigSessionRole=nil;
static IMP ctOrigSetDelegate=nil,ctOrigDelegateConfig=nil;
static Class gPatchedDelegateClass=Nil;
static NSArray<NSString *> *CTClientStages(void){
    return @[@"loaded",@"config",@"connect",@"window",@"root",@"no-root",@"no-scene",@"error",@"tablet"];
}
static NSString *CTClientStatusName(NSString *bundle){return [@"com.sushibta.connectta.client." stringByAppendingString:bundle];}
static NSMutableDictionary<NSString *,NSNumber *> *gClientObservers;
static void CTObserveClients(void){
    for(NSNumber *token in gClientObservers.allValues)notify_cancel(token.intValue);
    gClientObservers=[NSMutableDictionary dictionary];
    for(NSString *bundle in CTEnabledIdentifiers()){
        int token=-1;
        uint32_t result=notify_register_dispatch(CTClientStatusName(bundle).UTF8String,&token,dispatch_get_main_queue(),^(int t){
            uint64_t state=0;notify_get_state(t,&state);
            NSArray *stages=CTClientStages();
            CTLog(@"[CLIENT] bundle=%@ stage=%@",bundle,(state>0 && state<=stages.count)?stages[state-1]:@"not-loaded");
        });
        if(result==NOTIFY_STATUS_OK){
            gClientObservers[bundle]=@(token);
            uint64_t state=0;notify_get_state(token,&state);
            NSArray *stages=CTClientStages();
            CTLog(@"[CLIENT-SNAPSHOT] bundle=%@ stage=%@",bundle,(state>0 && state<=stages.count)?stages[state-1]:@"not-loaded");
        }
    }
}
static void CTAppStage(const char *stage){
    static int token=-1;
    NSString *status=CTClientStatusName(NSBundle.mainBundle.bundleIdentifier);
    if(token<0 && notify_register_check(status.UTF8String,&token)!=NOTIFY_STATUS_OK){token=-1;return;}
    NSUInteger index=[CTClientStages() indexOfObject:[NSString stringWithUTF8String:stage]];
    if(index!=NSNotFound){notify_set_state(token,index+1);notify_post(status.UTF8String);}
}
// Lay out the live app at tablet width before mapping its coordinates to CarPlay.
// UIKit performs inverse coordinate conversion for gestures in the transformed canvas.
@interface CTTabletContainer : UIViewController
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
@implementation CTTabletContainer
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
    if(gYouTubeLayout){
    UITraitCollection *traits=[UITraitCollection traitCollectionWithTraitsFromCollections:@[
        [UITraitCollection traitCollectionWithUserInterfaceIdiom:UIUserInterfaceIdiomPad],
        [UITraitCollection traitCollectionWithHorizontalSizeClass:UIUserInterfaceSizeClassRegular],
        [UITraitCollection traitCollectionWithVerticalSizeClass:UIUserInterfaceSizeClassRegular],
        [UITraitCollection traitCollectionWithPreferredContentSizeCategory:UIContentSizeCategoryMedium]
    ]];
    [self setOverrideTraitCollection:traits forChildViewController:self.content];
    }
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
    CTAppStage("tablet");
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
    CGFloat logicalWidth=gYouTubeLayout?1024.0:viewport.size.width;
    CGFloat scale=viewport.size.width/logicalWidth;
    CGSize logical=CGSizeMake(logicalWidth,viewport.size.height/scale);
    self.canvas.bounds=(CGRect){CGPointZero,logical};
    self.canvas.center=CGPointMake(CGRectGetMidX(viewport),CGRectGetMidY(viewport));
    self.canvas.transform=CGAffineTransformMakeScale(scale,scale);
    // The child is entirely inside the safe area; UIKit computes its local
    // safe area after the transform. Auto Layout reflows against logical bounds.
    if(!CGSizeEqualToSize(self.content.preferredContentSize,logical))self.content.preferredContentSize=logical;
    [self.canvas setNeedsLayout];[self.canvas layoutIfNeeded];
    [self.content.view setNeedsLayout];[self.content.view layoutIfNeeded];


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
static CTTabletContainer *gTabletContainer=nil;

static BOOL CTHybridCarRole(NSString *role){return [role hasPrefix:@"CPTemplateApplicationSceneSessionRole"]||[role hasPrefix:@"UIWindowSceneSessionRoleCarPlay"];}
static BOOL CTAppCarSession(UISceneSession *session){
    NSString *role=ctOrigSessionRole?((id(*)(id,SEL))ctOrigSessionRole)(session,@selector(role)):session.role;
    return CTHybridCarRole(role)||[session.persistentIdentifier hasPrefix:@"Car["];
}
static BOOL CTAppCarScene(UIScene *scene){
    return [scene isKindOfClass:UIWindowScene.class] && (CTAppCarSession(scene.session)||((UIWindowScene*)scene).screen!=UIScreen.mainScreen);
}
static void CTAppRestore(void){
    gAppEpoch++;gAppPumpRunning=NO;
    if(gMovedRoot){
        [gTabletContainer detachContent];
        gAppCarWindow.rootViewController=nil;
        gTabletContainer=nil;
        if(gDonorWindow && gDonorWindow.rootViewController==gDonorPlaceholder)gDonorWindow.rootViewController=gMovedRoot;
    }
    gAppCarWindow.hidden=YES;gAppCarWindow=nil;gDonorWindow=nil;gMovedRoot=nil;gDonorPlaceholder=nil;
}
static void CTAppPump(NSUInteger attempt,NSUInteger epoch){
    if(epoch!=gAppEpoch)return;
    @try{
        UIWindowScene *car=nil;
        for(UIScene *scene in UIApplication.sharedApplication.connectedScenes)if(CTAppCarScene(scene)){car=(UIWindowScene*)scene;break;}
        // Connection/activation notifications restart discovery when CarPlay appears.
        if(!car){gAppPumpRunning=NO;return;}
        if(car && !gAppCarWindow){
            gAppCarWindow=[[UIWindow alloc]initWithWindowScene:car];
            gAppCarWindow.frame=(CGRect){CGPointZero,car.coordinateSpace.bounds.size};
            gAppCarWindow.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            UIViewController *loading=[UIViewController new];
            loading.view.backgroundColor=[UIColor colorWithRed:0.05 green:0.09 blue:0.16 alpha:1];
            UILabel *label=[[UILabel alloc]initWithFrame:loading.view.bounds];
            label.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            label.text=@"ConnectTA — Đang mở ứng dụng…";label.textColor=UIColor.whiteColor;label.textAlignment=NSTextAlignmentCenter;
            [loading.view addSubview:label];gAppCarWindow.rootViewController=loading;
            [gAppCarWindow makeKeyAndVisible];CTAppStage("window");
        }
        if(gAppCarWindow && !gMovedRoot){
            NSMutableOrderedSet *windows=[NSMutableOrderedSet orderedSetWithArray:UIApplication.sharedApplication.windows?:@[]];
            for(UIScene *scene in UIApplication.sharedApplication.connectedScenes){
                if([scene isKindOfClass:UIWindowScene.class] && !CTAppCarScene(scene))[windows addObjectsFromArray:((UIWindowScene*)scene).windows];
            }
            id delegateWindow=CTV(UIApplication.sharedApplication.delegate,@"window");
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
                gTabletContainer=[[CTTabletContainer alloc]initWithContent:gMovedRoot];
                gAppCarWindow.rootViewController=gTabletContainer;
                [gTabletContainer.view setNeedsLayout];[gTabletContainer.view layoutIfNeeded];
                [gAppCarWindow makeKeyAndVisible];CTAppStage("root");
                CTLog(@"[CLIENT-ROOT] class=%@ frame=%@ scene=%@",NSStringFromClass(gMovedRoot.class),NSStringFromCGRect(gMovedRoot.view.frame),car.session.persistentIdentifier);
            }
        }
    }@catch(NSException *e){CTAppStage("error");CTLog(@"[CLIENT-ERROR] %@ %@",e.name,e.reason);}
    if(!gMovedRoot && attempt<40){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{CTAppPump(attempt+1,epoch);});}
    else{gAppPumpRunning=NO;if(!gMovedRoot)CTAppStage(gAppCarWindow?"no-root":"no-scene");}
}
static void CTAppStart(void){dispatch_async(dispatch_get_main_queue(),^{if(gAppPumpRunning||gMovedRoot)return;gAppPumpRunning=YES;CTAppPump(0,gAppEpoch);});}
static void CTAppResizeScene(UIWindowScene *scene){
    if(!gAppCarWindow || gAppCarWindow.windowScene!=scene)return;
    CGRect bounds=(CGRect){CGPointZero,scene.coordinateSpace.bounds.size};
    if(CGRectIsEmpty(bounds))return;
    if(!CGRectEqualToRect(gAppCarWindow.frame,bounds))gAppCarWindow.frame=bounds;
    [gAppCarWindow setNeedsLayout];[gAppCarWindow layoutIfNeeded];
    [gTabletContainer.view setNeedsLayout];[gTabletContainer.view layoutIfNeeded];
}
@interface CTAppCarSceneDelegate : UIResponder <UIWindowSceneDelegate>
@end
@implementation CTAppCarSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    (void)scene;(void)session;(void)options;CTAppStage("connect");CTAppStart();
}
- (void)sceneDidBecomeActive:(UIScene *)scene {
    CTAppStart();
    if([scene isKindOfClass:UIWindowScene.class])CTAppResizeScene((UIWindowScene*)scene);
}
- (void)windowScene:(UIWindowScene *)scene didUpdateCoordinateSpace:(id<UICoordinateSpace>)previousCoordinateSpace interfaceOrientation:(UIInterfaceOrientation)previousInterfaceOrientation traitCollection:(UITraitCollection *)previousTraitCollection {
    (void)previousCoordinateSpace;(void)previousInterfaceOrientation;(void)previousTraitCollection;
    CTAppResizeScene(scene);
}
- (void)sceneDidDisconnect:(UIScene *)scene {if(scene==gAppCarWindow.windowScene)CTAppRestore();}
@end
static id CTHybridSceneConfigInit(id self,SEL cmd,NSString *name,NSString *role){
    BOOL car=CTHybridCarRole(role);
    id result=((id(*)(id,SEL,id,id))ctOrigSceneConfigInit)(self,cmd,car?nil:name,car?UIWindowSceneSessionRoleApplication:role);
    if(car){((UISceneConfiguration*)result).sceneClass=UIWindowScene.class;((UISceneConfiguration*)result).delegateClass=CTAppCarSceneDelegate.class;CTAppStage("config");}
    return result;
}
static id CTHybridSessionRole(id self,SEL cmd){NSString *role=((id(*)(id,SEL))ctOrigSessionRole)(self,cmd);return CTHybridCarRole(role)?UIWindowSceneSessionRoleApplication:role;}
static BOOL CTHybridSupportsMulti(id self,SEL cmd){(void)self;(void)cmd;return YES;}
static UISceneConfiguration *CTDelegateConfig(id self,SEL cmd,UIApplication *app,UISceneSession *session,UISceneConnectionOptions *options){
    if(CTAppCarSession(session)){
        UISceneConfiguration *config=[[UISceneConfiguration alloc]initWithName:nil sessionRole:UIWindowSceneSessionRoleApplication];
        config.sceneClass=UIWindowScene.class;config.delegateClass=CTAppCarSceneDelegate.class;CTAppStage("config");return config;
    }
    if(ctOrigDelegateConfig)return ((id(*)(id,SEL,id,id,id))ctOrigDelegateConfig)(self,cmd,app,session,options);
    return session.configuration;
}
static void CTInstallDelegate(id delegate){
    if(!delegate||gPatchedDelegateClass)return;
    Class cls=object_getClass(delegate);SEL sel=@selector(application:configurationForConnectingSceneSession:options:);
    Method method=class_getInstanceMethod(cls,sel);ctOrigDelegateConfig=method?method_getImplementation(method):NULL;
    const char *types=method?method_getTypeEncoding(method):"@@:@@@";
    class_replaceMethod(cls,sel,(IMP)CTDelegateConfig,types);gPatchedDelegateClass=cls;
}
static void CTSetDelegate(id self,SEL cmd,id delegate){CTInstallDelegate(delegate);((void(*)(id,SEL,id))ctOrigSetDelegate)(self,cmd,delegate);}
static void CTHybridInstallAppBridge(void){
    Method m=class_getInstanceMethod(UISceneConfiguration.class,@selector(initWithName:sessionRole:));
    if(m){ctOrigSceneConfigInit=method_getImplementation(m);method_setImplementation(m,(IMP)CTHybridSceneConfigInit);}
    m=class_getInstanceMethod(UISceneSession.class,@selector(role));
    if(m){ctOrigSessionRole=method_getImplementation(m);method_setImplementation(m,(IMP)CTHybridSessionRole);}
    Class manifest=NSClassFromString(@"UIApplicationSceneManifest");m=manifest?class_getInstanceMethod(manifest,NSSelectorFromString(@"supportsMultipleScenes")):NULL;
    if(m){method_setImplementation(m,(IMP)CTHybridSupportsMulti);}
    m=class_getInstanceMethod(UIApplication.class,@selector(setDelegate:));
    if(m){ctOrigSetDelegate=method_getImplementation(m);method_setImplementation(m,(IMP)CTSetDelegate);}
    CTInstallDelegate(UIApplication.sharedApplication.delegate);
    for(NSString *name in @[UISceneWillConnectNotification,UISceneDidActivateNotification,UIApplicationDidBecomeActiveNotification]){
        [[NSNotificationCenter defaultCenter]addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note){CTAppStart();}];
    }
    [[NSNotificationCenter defaultCenter]addObserverForName:UISceneDidDisconnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){if(note.object==gAppCarWindow.windowScene)CTAppRestore();}];
    CTAppStage("loaded");CTAppStart();
}

// Policy is evaluated outside the YouTube process as well as in CarPlayApp.
static id CTHomePolicy(id policy,id declaration){
    if(!CTIsEnabledApp(declaration))return policy;
    if(!policy)policy=[NSClassFromString(@"CRCarPlayAppPolicy") new];
    if(!policy)return nil;
    @try{
        [policy setValue:@YES forKey:@"carPlaySupported"];
        [policy setValue:@YES forKey:@"canDisplayOnCarScreen"];
        [policy setValue:@NO forKey:@"launchUsingSiri"];
        [policy setValue:@NO forKey:@"launchUsingMusicUIService"];
        [policy setValue:@NO forKey:@"launchUsingTemplateUI"];
        static dispatch_once_t once;
        dispatch_once(&once,^{CTLog(@"[HOME-POLICY] Selected app supported; direct app launch");});
    }@catch(NSException *e){CTLog(@"[HOME-POLICY-ERROR] %@",e);}
    return policy;
}
%group CTHomeAdmission
%hook CRCarPlayAppDeclaration
- (BOOL)supportsAudio {
    if(CTIsEnabledApp(self))return YES;
    return %orig;
}
%end
%hook CRCarPlayAppPolicyEvaluator
- (id)effectivePolicyForAppDeclaration:(id)declaration {
    id policy=%orig;
    return CTHomePolicy(policy,declaration);
}
- (id)effectivePolicyForAppDeclaration:(id)declaration inVehicleWithCertificateSerial:(id)serial {
    id policy=%orig;
    return CTHomePolicy(policy,declaration);
}
%end
%end

// Feed Home the installed application's native DBLeafIcon, not an overlay button.
static NSMutableDictionary *gHomeIcons;
static NSString *CTHomeIconIdentifier(id icon){
    id identifier=CTV(CTV(icon,@"applicationInfo"),@"bundleIdentifier");
    if(![identifier isKindOfClass:NSString.class])identifier=CTV(icon,@"applicationBundleID");
    if(![identifier isKindOfClass:NSString.class])identifier=CTV(icon,@"leafIdentifier");
    return [identifier isKindOfClass:NSString.class]?identifier:nil;
}
static BOOL CTHomeIsEnabledIcon(id icon){return CTEnabled(CTHomeIconIdentifier(icon));}
static id CTHomeIcon(NSString *identifier){
    if(!gHomeIcons)gHomeIcons=[NSMutableDictionary dictionary];
    if(gHomeIcons[identifier])return gHomeIcons[identifier];
    @try{
        Class proxyClass=NSClassFromString(@"LSApplicationProxy");
        Class infoClass=NSClassFromString(@"DBApplicationInfo");
        Class iconClass=NSClassFromString(@"DBLeafIcon");
        SEL lookup=NSSelectorFromString(@"applicationProxyForIdentifier:");
        SEL infoInit=NSSelectorFromString(@"initWithApplicationProxy:");
        SEL iconInit=NSSelectorFromString(@"initWithApplicationInfo:");
        if(![proxyClass respondsToSelector:lookup] || ![infoClass instancesRespondToSelector:infoInit] ||
           ![iconClass instancesRespondToSelector:iconInit])return nil;
        id proxy=((id(*)(id,SEL,id))objc_msgSend)(proxyClass,lookup,identifier);
        if(![CTV(proxy,@"bundleIdentifier") isEqual:identifier] || !CTV(proxy,@"bundleURL"))return nil;
        id info=((id(*)(id,SEL,id))objc_msgSend)([infoClass alloc],infoInit,proxy);
        if(!info)return nil;
        id icon=((id(*)(id,SEL,id))objc_msgSend)([iconClass alloc],iconInit,info);
        if(icon)gHomeIcons[identifier]=icon;
        CTLog(@"[APPBRIDGE-ICON] %@ created=%d",identifier,icon!=nil);
        return icon;
    }@catch(NSException *e){CTLog(@"[APPBRIDGE-ICON-ERROR] %@ %@",identifier,e);}
    return nil;
}
static id CTHomeIncludeApps(id original){
    if(original && ![original isKindOfClass:NSArray.class])return original;
    NSMutableSet *existing=[NSMutableSet set];
    for(id icon in original){NSString *identifier=CTHomeIconIdentifier(icon);if(identifier)[existing addObject:identifier];}
    NSMutableArray *icons=nil;
    for(NSString *identifier in CTEnabledIdentifiers()){
        if([existing containsObject:identifier])continue;
        id icon=CTHomeIcon(identifier);
        if(!icon)continue;
        if(!icons)icons=original?[original mutableCopy]:[NSMutableArray array];
        [icons addObject:icon];[existing addObject:identifier];
    }
    return icons?[icons copy]:original;
}
%hook DBDashboardHomeViewController
- (id)allApplicationIcons {
    id icons=%orig;
    return CTHomeIncludeApps(icons);
}
- (BOOL)isIconVisible:(id)icon {
    if(CTHomeIsEnabledIcon(icon))return YES;
    return %orig;
}
- (BOOL)isIconVisibleForIdentifier:(id)identifier {
    if(CTEnabled(identifier))return YES;
    return %orig;
}
%end
%hook DBIconLayoutVehicleDataProvider
- (id)allApplicationIcons {
    id icons=%orig;
    return CTHomeIncludeApps(icons);
}
%end
%hook DBIconModel
- (BOOL)isIconVisible:(id)icon {
    if(CTHomeIsEnabledIcon(icon))return YES;
    return %orig;
}
- (id)hiddenBundleIdentifiers {
    id original=%orig;
    if(![original isKindOfClass:NSArray.class])return original;
    NSMutableArray *hidden=[original mutableCopy];
    [hidden removeObjectsInArray:CTEnabledIdentifiers()];
    return [hidden copy];
}
%end

%hook DBApplicationInfo
- (BOOL)presentsUnderStatusBar {
    if(CTIsEnabledApp(self))return NO;
    return %orig;
}
- (BOOL)isHidden {
    if(CTIsEnabledApp(self))return NO;
    return %orig;
}
%end
// Host owns screen-space placement; client owns a zero-origin local window.
static CGRect CTNativeAppViewport(id dashboard,CGRect original){
    UIWindowScene *scene=CTV(dashboard,@"windowScene");
    if(![scene isKindOfClass:UIWindowScene.class])return original;
    CGRect display=scene.coordinateSpace.bounds;
    id config=CTV(dashboard,@"environmentConfiguration");
    id area=CTV(config,@"viewAreaFrame");
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
    return viewport;
}
static char kCTAligning;
static void CTAlignNativeHost(id controller){
    if(!CTIsEnabledApp(CTV(controller,@"applicationInfo")))return;
    if([objc_getAssociatedObject(controller,&kCTAligning) boolValue])return;
    UIViewController *vc=(UIViewController*)controller;
    if(!vc.isViewLoaded || !vc.view.window || !vc.view.superview)return;
    UIView *root=vc.view;
    UIView *host=CTV(controller,@"sceneHostView");
    if(![host isKindOfClass:UIView.class] || !host.superview || ![host isDescendantOfView:root])return;
    UIWindowScene *scene=root.window.windowScene;
    if(!scene)return;
    objc_setAssociatedObject(controller,&kCTAligning,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try{
        CGRect before=[root convertRect:root.bounds toCoordinateSpace:scene.coordinateSpace];
        CGRect target=CTNativeAppViewport(CTV(controller,@"environment"),before);
        CGRect local=[root.superview convertRect:target fromCoordinateSpace:scene.coordinateSpace];
        // Convert screen geometry through the actual parent. Never add 45 points
        // blindly: the parent may already be positioned beyond the dock.
        if(CGAffineTransformIsIdentity(root.transform) && !CGRectEqualToRect(root.frame,local))root.frame=local;
        CGRect hostLocal=[host.superview convertRect:root.bounds fromView:root];
        if(CGAffineTransformIsIdentity(host.transform) && !CGRectEqualToRect(host.frame,hostLocal))host.frame=hostLocal;
    }@catch(NSException *e){CTLog(@"[HOST-ERROR] %@",e);}
    @finally{objc_setAssociatedObject(controller,&kCTAligning,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
}
%hook DBApplicationSceneViewController
- (id)initWithApplicationInfo:(id)app proxyApplicationInfo:(id)proxy environment:(id)environment {
    if(CTIsEnabledApp(app)){
        CTLog(@"[HOST-INIT] remove controller proxy=%@",proxy);
        proxy=nil;
    }
    return %orig(app,proxy,environment);
}
- (id)_initWithApplicationInfo:(id)app proxyApplicationInfo:(id)proxy environment:(id)environment {
    if(CTIsEnabledApp(app))proxy=nil;
    return %orig(app,proxy,environment);
}
- (BOOL)presentsUnderStatusBar {
    if(CTIsEnabledApp(CTV(self,@"applicationInfo")))return NO;
    return %orig;
}
- (void)viewDidLayoutSubviews {
    %orig;
    CTAlignNativeHost(self);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    CTAlignNativeHost(self);
}
- (void)setSceneHostView:(id)view {
    %orig;
    if(CTIsEnabledApp(CTV(self,@"applicationInfo")))dispatch_async(dispatch_get_main_queue(),^{CTAlignNativeHost(self);});
}
%end

%hook DBDashboard
- (CGRect)sceneFrameForAppInfo:(id)app {
    CGRect frame=%orig;
    return CTIsEnabledApp(app)?CTNativeAppViewport(self,frame):frame;
}
- (CGRect)sceneFrameForAppInfo:(id)app proxyAppInfo:(id)proxy {
    CGRect frame=%orig;
    return CTIsEnabledApp(app)?CTNativeAppViewport(self,frame):frame;
}
- (UIEdgeInsets)safeAreaInsetsForAppInfo:(id)app {
    if(CTIsEnabledApp(app))return UIEdgeInsetsZero;
    return %orig;
}
- (UIEdgeInsets)safeAreaInsetsForAppInfo:(id)app proxyAppInfo:(id)proxy {
    if(CTIsEnabledApp(app))return UIEdgeInsetsZero;
    return %orig;
}
- (id)sceneIdentifierForAppInfo:(id)info {
    id original=%orig;
    if(CTIsEnabledApp(info) && [original isKindOfClass:NSString.class]){
        NSString *sid=original;
        sid=[sid stringByReplacingOccurrencesOfString:@":com.apple.MusicUIService:" withString:@":"];
        sid=[sid stringByReplacingOccurrencesOfString:@":com.apple.CarPlayTemplateUIHost:" withString:@":"];
        CTLog(@"[DIRECT-ID] %@ -> %@",original,sid);return sid;
    }
    return original;
}
%end
%hook DBSceneUpdate
- (id)initWithApplicationInfo:(id)app proxyApplicationInfo:(id)proxy environment:(id)env activationSettings:(id)settings {
    BOOL target=CTIsEnabledApp(app);
    if(target)proxy=nil;
    id result=%orig(app,proxy,env,settings);
    if(target)CTLog(@"[HOME-NATIVE-UPDATE] app=%@ proxy=%@",CTV(result,@"applicationInfo"),CTV(result,@"proxyApplicationInfo"));
    return result;
}
%end

%ctor {
    @autoreleasepool {
        NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
        CTReloadConfiguration();
        if(CTEligibleIdentifier(bundle) && CTReadPublishedEnabled(bundle,CTEnabled(bundle))){
            if(![NSBundle.mainBundle.bundlePath.pathExtension isEqualToString:@"app"])return;
            gAppClient=YES;
            gYouTubeLayout=[bundle isEqualToString:@"com.google.ios.youtube"];
            if(gYouTubeLayout){
                %init(CTTabletIdentity);
            }
            CTLog(@"[APPBRIDGE-CLIENT] bundle=%@ tablet=%d",bundle,gYouTubeLayout);
            CTHybridInstallAppBridge();return;
        }
        BOOL car=[bundle isEqualToString:@"com.apple.CarPlayApp"];
        BOOL spring=[bundle isEqualToString:@"com.apple.springboard"];
        BOOL daemon=[NSProcessInfo.processInfo.processName isEqualToString:@"carplayd"];
        if(!car && !spring && !daemon)return;
        if(spring)CTPublishEnabledApps([NSSet setWithArray:CTEnabledIdentifiers()]);
        int preferencesToken=0;
        notify_register_dispatch(CTPreferencesChanged,&preferencesToken,dispatch_get_main_queue(),^(__unused int token){
            CTReloadConfiguration();
            if(spring)CTPublishEnabledApps([NSSet setWithArray:CTEnabledIdentifiers()]);
            [gHomeIcons removeAllObjects];
            if(car)CTObserveClients();
            CTLog(@"[APPBRIDGE-CONFIG] %@; reconnect CarPlay after changing apps",CTEnabledIdentifiers());
        });
        dlopen("/System/Library/PrivateFrameworks/CarKit.framework/CarKit",RTLD_NOW);
        %init(CTHomeAdmission);
        if(!car){CTHybridInstallAdmission();return;}
        %init;
        [[NSFileManager defaultManager]removeItemAtPath:@"/var/mobile/ConnectTA.txt" error:nil];
        CTLog(@"[DIRECT-BOOT] native Home icon launch; no automatic Maps launch or overlay host");
        // iOS 14 (Taurine) diagnostics: which Home classes and initializers exist.
        CTLog(@"[DIAG] os=%@ enabled=%@",UIDevice.currentDevice.systemVersion,CTEnabledIdentifiers());
        for(NSString *name in @[@"DBDashboardHomeViewController",@"DBIconLayoutVehicleDataProvider",@"DBIconModel",@"DBLeafIcon",@"DBApplicationInfo",@"DBApplicationSceneViewController",@"DBDashboard",@"DBSceneUpdate",@"CRCarPlayAppPolicyEvaluator",@"CRCarPlayAppDeclaration",@"LSApplicationProxy"])
            CTLog(@"[DIAG] class %@ present=%d",name,NSClassFromString(name)!=nil);
        CTLog(@"[DIAG] DBApplicationInfo initWithApplicationProxy:=%d DBLeafIcon initWithApplicationInfo:=%d home allApplicationIcons=%d",
              [NSClassFromString(@"DBApplicationInfo") instancesRespondToSelector:NSSelectorFromString(@"initWithApplicationProxy:")],
              [NSClassFromString(@"DBLeafIcon") instancesRespondToSelector:NSSelectorFromString(@"initWithApplicationInfo:")],
              [NSClassFromString(@"DBDashboardHomeViewController") instancesRespondToSelector:NSSelectorFromString(@"allApplicationIcons")]);
        CTObserveClients();
        CTHybridInstallAdmission();

    }
}


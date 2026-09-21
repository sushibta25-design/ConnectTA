#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <notify.h>
#import <dlfcn.h>
#import "MTConfig.h"
#import "MTAdaptiveLayout.h"

static NSSet<NSString *> *gEnabledApps;
static BOOL gAppClient=NO, gYouTubeLayout=NO;
static BOOL MTEnabled(id identifier){
    if(!MTEligibleIdentifier(identifier))return NO;
    @synchronized(NSProcessInfo.processInfo){return [gEnabledApps containsObject:identifier];}
}
static NSArray *MTEnabledIdentifiers(void){
    @synchronized(NSProcessInfo.processInfo){return [[gEnabledApps allObjects] sortedArrayUsingSelector:@selector(compare:)];}
}
static void MTReloadConfiguration(void){
    NSSet *apps=MTReadEnabledApps();
    @synchronized(NSProcessInfo.processInfo){gEnabledApps=apps;}
}

static NSString *const MTBuild=@"92-ADAPTIVE";
static void MTLog(NSString *format,...){
    va_list args;va_start(args,format);
    NSString *message=[[NSString alloc]initWithFormat:format arguments:args];va_end(args);
    NSString *line=[NSString stringWithFormat:@"[%@ pid=%d] %@\n",MTBuild,NSProcessInfo.processInfo.processIdentifier,message];
    NSLog(@"%@",line);
    BOOL app=gAppClient;
    NSString *path=app?[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/MiniTa-client.txt"]:([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.CarPlayApp"]?@"/var/mobile/MiniTa.txt":@"/var/mobile/MiniTa-admission.txt");
    @synchronized(NSFileManager.class){
        NSData *data=[line dataUsingEncoding:NSUTF8StringEncoding];
        NSFileHandle *file=[NSFileHandle fileHandleForWritingAtPath:path];
        if(!file){[data writeToFile:path atomically:YES];return;}
        @try{if([file seekToEndOfFile]>1024*1024){[file truncateFileAtOffset:0];[file seekToFileOffset:0];}[file writeData:data];}@catch(__unused NSException *e){}
        [file closeFile];
    }
}
static id MTV(id object,NSString *key){@try{return[object valueForKey:key];}@catch(__unused NSException *e){return nil;}}
static BOOL MTIsEnabledApp(id info){
    return MTEnabled(MTV(info,@"bundleIdentifier"));
}
static IMP mtOrigInfo=nil, mtOrigEnt2=nil, mtOrigEnt3=nil;
static id MTHybridInfo(id self,SEL _cmd,NSString *key,Class expected){
    id value=((id(*)(id,SEL,id,id))mtOrigInfo)(self,_cmd,key,expected);
    if(!MTIsEnabledApp(self)) return value;
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
            if(!cfg[@"UIWindowSceneSessionRoleCarPlay"]) cfg[@"UIWindowSceneSessionRoleCarPlay"]=@[@{@"UISceneConfigurationName":@"MiniTa"}];
            manifest[@"UISceneConfigurations"]=cfg;
            manifest[@"UIApplicationSupportsMultipleScenes"]=@YES;
            [manifest removeObjectForKey:@"CPSupportsDashboardNavigationScene"];
            [manifest removeObjectForKey:@"CPSupportsInstrumentClusterNavigationScene"];
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
    if(!MTIsEnabledApp(self)) return value;
    if(MTHybridTemplateCapability(key)){return nil;}
    if(!value&&MTHybridCapability(key)&&(!expected||expected==NSNumber.class)){return @YES;}
    return value;
}
static id MTHybridEnt3(id self,SEL _cmd,NSString *key,Class expected,Class valuesExpected){
    id value=((id(*)(id,SEL,id,id,id))mtOrigEnt3)(self,_cmd,key,expected,valuesExpected);
    if(!MTIsEnabledApp(self)) return value;
    if(MTHybridTemplateCapability(key)){return nil;}
    if(!value&&MTHybridCapability(key)&&(!expected||expected==NSNumber.class)){return @YES;}
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

static UIWindow *gAppCarWindow=nil, *gDonorWindow=nil;
static UIViewController *gMovedRoot=nil, *gDonorPlaceholder=nil;
static BOOL gAppPumpRunning=NO;
static NSUInteger gAppEpoch=0;
static IMP mtOrigSceneConfigInit=nil,mtOrigSessionRole=nil;
static IMP mtOrigSetDelegate=nil,mtOrigDelegateConfig=nil;
static Class gPatchedDelegateClass=Nil;
static NSArray<NSString *> *MTClientStages(void){
    return @[@"loaded",@"config",@"connect",@"window",@"root",@"no-root",@"no-scene",@"error",@"tablet",@"resized-safearea"];
}
static NSString *MTClientStatusName(NSString *bundle){return [@"com.sushibta.minita.client91." stringByAppendingString:bundle];}
static NSMutableDictionary<NSString *,NSNumber *> *gClientObservers;
static void MTObserveClients(void){
    for(NSNumber *token in gClientObservers.allValues)notify_cancel(token.intValue);
    gClientObservers=[NSMutableDictionary dictionary];
    for(NSString *bundle in MTEnabledIdentifiers()){
        int token=-1;
        uint32_t result=notify_register_dispatch(MTClientStatusName(bundle).UTF8String,&token,dispatch_get_main_queue(),^(int t){
            uint64_t state=0;notify_get_state(t,&state);
            NSArray *stages=MTClientStages();
            MTLog(@"[CLIENT91] bundle=%@ stage=%@",bundle,(state>0 && state<=stages.count)?stages[state-1]:@"not-loaded");
        });
        if(result==NOTIFY_STATUS_OK){
            gClientObservers[bundle]=@(token);
            uint64_t state=0;notify_get_state(token,&state);
            NSArray *stages=MTClientStages();
            MTLog(@"[CLIENT91-SNAPSHOT] bundle=%@ stage=%@",bundle,(state>0 && state<=stages.count)?stages[state-1]:@"not-loaded");
        }
    }
}
static void MTAppStage(const char *stage){
    NSString *name=[@"com.sushibta.minita.client80." stringByAppendingString:[NSString stringWithUTF8String:stage]];
    notify_post(name.UTF8String);MTLog(@"[CLIENT80] %s",stage);
    static int token=-1;
    NSString *status=MTClientStatusName(NSBundle.mainBundle.bundleIdentifier);
    if(token<0 && notify_register_check(status.UTF8String,&token)!=NOTIFY_STATUS_OK){token=-1;return;}
    NSUInteger index=[MTClientStages() indexOfObject:[NSString stringWithUTF8String:stage]];
    if(index!=NSNotFound){notify_set_state(token,index+1);notify_post(status.UTF8String);}
}
// Reflow the live child at a stable density as the CarPlay viewport changes.
// UIKit performs inverse coordinate conversion for gestures in the transformed canvas.
@interface MTTabletContainer : UIViewController
@property(nonatomic,strong) UIViewController *content;
@property(nonatomic,strong) UIView *canvas;
@property(nonatomic,strong) NSArray<NSLayoutConstraint *> *contentConstraints;
@property(nonatomic,assign) CGRect reportedViewport;
@property(nonatomic,assign) BOOL layoutModeInitialized;
@property(nonatomic,assign) BOOL tabletMode;
@property(nonatomic,assign) BOOL applyingLayout;
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
    if(self.applyingLayout || CGRectEqualToRect(viewport,self.reportedViewport))return;
    self.applyingLayout=YES;
    @try {
    self.reportedViewport=viewport;
    CGFloat logicalWidth=gYouTubeLayout?MTYouTubeLogicalWidth(viewport.size.width):viewport.size.width;
    if(gYouTubeLayout){
        BOOL tablet=MTYouTubeTabletMode(logicalWidth,self.layoutModeInitialized,self.tabletMode);
        if(!self.layoutModeInitialized || tablet!=self.tabletMode){
            self.tabletMode=tablet;self.layoutModeInitialized=YES;
            UITraitCollection *traits=[UITraitCollection traitCollectionWithTraitsFromCollections:@[
                [UITraitCollection traitCollectionWithUserInterfaceIdiom:tablet?UIUserInterfaceIdiomPad:UIUserInterfaceIdiomPhone],
                [UITraitCollection traitCollectionWithHorizontalSizeClass:tablet?UIUserInterfaceSizeClassRegular:UIUserInterfaceSizeClassCompact],
                [UITraitCollection traitCollectionWithVerticalSizeClass:UIUserInterfaceSizeClassRegular],
                [UITraitCollection traitCollectionWithPreferredContentSizeCategory:UIContentSizeCategoryMedium]
            ]];
            [self setOverrideTraitCollection:traits forChildViewController:self.content];
            // UIKit propagates the override through the existing controller tree.
            // Do not recreate controllers or touch playback to change the layout.
            MTLog(@"[ADAPTIVE92] mode=%@ viewport=%@ logicalWidth=%.1f",tablet?@"ipad":@"phone",NSStringFromCGRect(viewport),logicalWidth);
        }
    }
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
    MTLog(@"[RESIZE86] window=%@ root=%@ safeInsets=%@ viewport=%@ logical=%@ child=%@ scale=%.4f",
          NSStringFromCGRect(self.view.window.bounds),NSStringFromCGRect(self.view.bounds),
          NSStringFromUIEdgeInsets(self.view.safeAreaInsets),NSStringFromCGRect(viewport),
          NSStringFromCGSize(logical),NSStringFromCGRect(self.content.view.bounds),scale);
    MTAppStage("resized-safearea");
    } @finally {self.applyingLayout=NO;}
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
            label.text=@"MiniTa 92 — Đang mở ứng dụng…";label.textColor=UIColor.whiteColor;label.textAlignment=NSTextAlignmentCenter;
            [loading.view addSubview:label];gAppCarWindow.rootViewController=loading;
            [gAppCarWindow makeKeyAndVisible];MTAppStage("window");
        }
        if(gAppCarWindow && !gMovedRoot){
            NSMutableOrderedSet *windows=[NSMutableOrderedSet orderedSetWithArray:UIApplication.sharedApplication.windows?:@[]];
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
@interface MTAppCarSceneDelegate : UIResponder <UIWindowSceneDelegate>
@end
@implementation MTAppCarSceneDelegate
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
    if(car){((UISceneConfiguration*)result).sceneClass=UIWindowScene.class;((UISceneConfiguration*)result).delegateClass=MTAppCarSceneDelegate.class;MTAppStage("config");}
    return result;
}
static id MTHybridSessionRole(id self,SEL cmd){NSString *role=((id(*)(id,SEL))mtOrigSessionRole)(self,cmd);return MTHybridCarRole(role)?UIWindowSceneSessionRoleApplication:role;}
static BOOL MTHybridSupportsMulti(id self,SEL cmd){(void)self;(void)cmd;return YES;}
static UISceneConfiguration *MTDelegateConfig(id self,SEL cmd,UIApplication *app,UISceneSession *session,UISceneConnectionOptions *options){
    if(MTAppCarSession(session)){
        UISceneConfiguration *config=[[UISceneConfiguration alloc]initWithName:nil sessionRole:UIWindowSceneSessionRoleApplication];
        config.sceneClass=UIWindowScene.class;config.delegateClass=MTAppCarSceneDelegate.class;MTAppStage("config");return config;
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
    if(m){method_setImplementation(m,(IMP)MTHybridSupportsMulti);}
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
    if(!MTIsEnabledApp(declaration))return policy;
    if(!policy)policy=[NSClassFromString(@"CRCarPlayAppPolicy") new];
    if(!policy)return nil;
    @try{
        [policy setValue:@YES forKey:@"carPlaySupported"];
        [policy setValue:@YES forKey:@"canDisplayOnCarScreen"];
        [policy setValue:@NO forKey:@"launchUsingSiri"];
        [policy setValue:@NO forKey:@"launchUsingMusicUIService"];
        [policy setValue:@NO forKey:@"launchUsingTemplateUI"];
        static dispatch_once_t once;
        dispatch_once(&once,^{MTLog(@"[HOME84-POLICY] Selected app supported; direct app launch");});
    }@catch(NSException *e){MTLog(@"[HOME84-POLICY-ERROR] %@",e);}
    return policy;
}
%group MTHomeAdmission
%hook CRCarPlayAppDeclaration
- (BOOL)supportsAudio {
    if(MTIsEnabledApp(self))return YES;
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
static NSMutableDictionary *gHomeIcons;
static NSString *MTHomeIconIdentifier(id icon){
    id identifier=MTV(MTV(icon,@"applicationInfo"),@"bundleIdentifier");
    if(![identifier isKindOfClass:NSString.class])identifier=MTV(icon,@"applicationBundleID");
    if(![identifier isKindOfClass:NSString.class])identifier=MTV(icon,@"leafIdentifier");
    return [identifier isKindOfClass:NSString.class]?identifier:nil;
}
static BOOL MTHomeIsEnabledIcon(id icon){return MTEnabled(MTHomeIconIdentifier(icon));}
static id MTHomeIcon(NSString *identifier){
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
        if(![MTV(proxy,@"bundleIdentifier") isEqual:identifier] || !MTV(proxy,@"bundleURL"))return nil;
        id info=((id(*)(id,SEL,id))objc_msgSend)([infoClass alloc],infoInit,proxy);
        if(!info)return nil;
        id icon=((id(*)(id,SEL,id))objc_msgSend)([iconClass alloc],iconInit,info);
        if(icon)gHomeIcons[identifier]=icon;
        MTLog(@"[APPBRIDGE-ICON] %@ created=%d",identifier,icon!=nil);
        return icon;
    }@catch(NSException *e){MTLog(@"[APPBRIDGE-ICON-ERROR] %@ %@",identifier,e);}
    return nil;
}
static id MTHomeIncludeApps(id original){
    if(original && ![original isKindOfClass:NSArray.class])return original;
    NSMutableSet *existing=[NSMutableSet set];
    for(id icon in original){NSString *identifier=MTHomeIconIdentifier(icon);if(identifier)[existing addObject:identifier];}
    NSMutableArray *icons=nil;
    for(NSString *identifier in MTEnabledIdentifiers()){
        if([existing containsObject:identifier])continue;
        id icon=MTHomeIcon(identifier);
        if(!icon)continue;
        if(!icons)icons=original?[original mutableCopy]:[NSMutableArray array];
        [icons addObject:icon];[existing addObject:identifier];
    }
    return icons?[icons copy]:original;
}
%hook DBDashboardHomeViewController
- (id)allApplicationIcons {
    id icons=%orig;
    return MTHomeIncludeApps(icons);
}
- (BOOL)isIconVisible:(id)icon {
    if(MTHomeIsEnabledIcon(icon))return YES;
    return %orig;
}
- (BOOL)isIconVisibleForIdentifier:(id)identifier {
    if(MTEnabled(identifier))return YES;
    return %orig;
}
%end
%hook DBIconLayoutVehicleDataProvider
- (id)allApplicationIcons {
    id icons=%orig;
    return MTHomeIncludeApps(icons);
}
%end
%hook DBIconModel
- (BOOL)isIconVisible:(id)icon {
    if(MTHomeIsEnabledIcon(icon))return YES;
    return %orig;
}
- (id)hiddenBundleIdentifiers {
    id original=%orig;
    if(![original isKindOfClass:NSArray.class])return original;
    NSMutableArray *hidden=[original mutableCopy];
    [hidden removeObjectsInArray:MTEnabledIdentifiers()];
    return [hidden copy];
}
%end

%hook DBApplicationInfo
- (BOOL)presentsUnderStatusBar {
    if(MTIsEnabledApp(self))return NO;
    return %orig;
}
- (BOOL)isHidden {
    if(MTIsEnabledApp(self))return NO;
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
    return viewport;
}
static char kMTAligning88;
static void MTAlignNativeHost(id controller){
    if(!MTIsEnabledApp(MTV(controller,@"applicationInfo")))return;
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
    }@catch(NSException *e){MTLog(@"[HOST88-ERROR] %@",e);}
    @finally{objc_setAssociatedObject(controller,&kMTAligning88,@NO,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
}
%hook DBApplicationSceneViewController
- (id)initWithApplicationInfo:(id)app proxyApplicationInfo:(id)proxy environment:(id)environment {
    if(MTIsEnabledApp(app)){
        MTLog(@"[HOST88-INIT] remove controller proxy=%@",proxy);
        proxy=nil;
    }
    return %orig(app,proxy,environment);
}
- (id)_initWithApplicationInfo:(id)app proxyApplicationInfo:(id)proxy environment:(id)environment {
    if(MTIsEnabledApp(app))proxy=nil;
    return %orig(app,proxy,environment);
}
- (BOOL)presentsUnderStatusBar {
    if(MTIsEnabledApp(MTV(self,@"applicationInfo")))return NO;
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
    if(MTIsEnabledApp(MTV(self,@"applicationInfo")))dispatch_async(dispatch_get_main_queue(),^{MTAlignNativeHost(self);});
}
%end

%hook DBDashboard
- (CGRect)sceneFrameForAppInfo:(id)app {
    CGRect frame=%orig;
    return MTIsEnabledApp(app)?MTNativeAppViewport(self,frame):frame;
}
- (CGRect)sceneFrameForAppInfo:(id)app proxyAppInfo:(id)proxy {
    CGRect frame=%orig;
    return MTIsEnabledApp(app)?MTNativeAppViewport(self,frame):frame;
}
- (UIEdgeInsets)safeAreaInsetsForAppInfo:(id)app {
    if(MTIsEnabledApp(app))return UIEdgeInsetsZero;
    return %orig;
}
- (UIEdgeInsets)safeAreaInsetsForAppInfo:(id)app proxyAppInfo:(id)proxy {
    if(MTIsEnabledApp(app))return UIEdgeInsetsZero;
    return %orig;
}
- (id)sceneIdentifierForAppInfo:(id)info {
    id original=%orig;
    if(MTIsEnabledApp(info) && [original isKindOfClass:NSString.class]){
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
    BOOL target=MTIsEnabledApp(app);
    if(target)proxy=nil;
    id result=%orig(app,proxy,env,settings);
    if(target)MTLog(@"[HOME84-NATIVE-UPDATE] app=%@ proxy=%@",MTV(result,@"applicationInfo"),MTV(result,@"proxyApplicationInfo"));
    return result;
}
%end

%ctor {
    @autoreleasepool {
        NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
        MTReloadConfiguration();
        if(MTEligibleIdentifier(bundle) && MTReadPublishedEnabled(bundle,MTEnabled(bundle))){
            if(![NSBundle.mainBundle.bundlePath.pathExtension isEqualToString:@"app"])return;
            gAppClient=YES;
            gYouTubeLayout=[bundle isEqualToString:@"com.google.ios.youtube"];
            MTLog(@"[APPBRIDGE-CLIENT] bundle=%@ tablet=%d",bundle,gYouTubeLayout);
            MTHybridInstallAppBridge();return;
        }
        BOOL car=[bundle isEqualToString:@"com.apple.CarPlayApp"];
        BOOL spring=[bundle isEqualToString:@"com.apple.springboard"];
        BOOL daemon=[NSProcessInfo.processInfo.processName isEqualToString:@"carplayd"];
        if(!car && !spring && !daemon)return;
        if(spring)MTPublishEnabledApps([NSSet setWithArray:MTEnabledIdentifiers()]);
        int preferencesToken=0;
        notify_register_dispatch(MTPreferencesChanged,&preferencesToken,dispatch_get_main_queue(),^(__unused int token){
            MTReloadConfiguration();
            if(spring)MTPublishEnabledApps([NSSet setWithArray:MTEnabledIdentifiers()]);
            [gHomeIcons removeAllObjects];
            if(car)MTObserveClients();
            MTLog(@"[APPBRIDGE-CONFIG] %@; reconnect CarPlay after changing apps",MTEnabledIdentifiers());
        });
        dlopen("/System/Library/PrivateFrameworks/CarKit.framework/CarKit",RTLD_NOW);
        %init(MTHomeAdmission);
        if(!car){MTHybridInstallAdmission();return;}
        %init;
        [[NSFileManager defaultManager]removeItemAtPath:@"/var/mobile/MiniTa.txt" error:nil];
        MTLog(@"[DIRECT-BOOT] native Home icon launch; no automatic Maps launch or overlay host");
        MTObserveClients();
        for(NSString *stage in @[@"loaded",@"config",@"connect",@"window",@"root",@"no-root",@"no-scene",@"error",@"tablet",@"resized-safearea"]){
            NSString *name=[@"com.sushibta.minita.client80." stringByAppendingString:stage];
            int token=0;
            notify_register_dispatch(name.UTF8String,&token,dispatch_get_main_queue(),^(__unused int t){MTLog(@"[CLIENT80-IPC] %@",stage);});
        }
        MTHybridInstallAdmission();

    }
}

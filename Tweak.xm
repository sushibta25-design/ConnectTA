#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const MTBuild=@"79-DIRECT";
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
    NSString *path=app?[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/MiniTa-client.txt"]:@"/var/mobile/MiniTa.txt";
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
static void MTTryDirectLaunch(void){
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

static IMP mtOrigSceneConfigInit=nil,mtOrigSessionRole=nil,mtOrigSupportsMulti=nil;
static BOOL MTHybridCarRole(NSString *r){return [r hasPrefix:@"CPTemplateApplicationSceneSessionRole"]||[r hasPrefix:@"UIWindowSceneSessionRoleCarPlay"];}
static id MTHybridSceneConfigInit(id self,SEL _cmd,NSString *name,NSString *role){
    if(MTHybridCarRole(role)){
        MTLog(@"[HYBRID-APP] rewrite config role %@ -> %@",role,UIWindowSceneSessionRoleApplication);
        id o=((id(*)(id,SEL,id,id))mtOrigSceneConfigInit)(self,_cmd,nil,UIWindowSceneSessionRoleApplication);
        if([o respondsToSelector:@selector(setSceneClass:)]) ((void(*)(id,SEL,id))objc_msgSend)(o,@selector(setSceneClass:),UIWindowScene.class);
        return o;
    }
    return ((id(*)(id,SEL,id,id))mtOrigSceneConfigInit)(self,_cmd,name,role);
}
static id MTHybridSessionRole(id self,SEL _cmd){
    NSString *r=((id(*)(id,SEL))mtOrigSessionRole)(self,_cmd);
    if(MTHybridCarRole(r)){MTLog(@"[HYBRID-APP] rewrite session role %@",r);return UIWindowSceneSessionRoleApplication;}
    return r;
}
static BOOL MTHybridSupportsMulti(id self,SEL _cmd){(void)self;(void)_cmd;return YES;}
static void MTHybridInstallAppBridge(void){
    Method m=class_getInstanceMethod(UISceneConfiguration.class,@selector(initWithName:sessionRole:));
    if(m){mtOrigSceneConfigInit=method_getImplementation(m);method_setImplementation(m,(IMP)MTHybridSceneConfigInit);}
    m=class_getInstanceMethod(UISceneSession.class,@selector(role));
    if(m){mtOrigSessionRole=method_getImplementation(m);method_setImplementation(m,(IMP)MTHybridSessionRole);}
    Class manifest=NSClassFromString(@"UIApplicationSceneManifest");
    m=manifest?class_getInstanceMethod(manifest,NSSelectorFromString(@"supportsMultipleScenes")):NULL;
    if(m){mtOrigSupportsMulti=method_getImplementation(m);method_setImplementation(m,(IMP)MTHybridSupportsMulti);}
    MTLog(@"[HYBRID-APP] installed config=%d role=%d multi=%d",mtOrigSceneConfigInit!=nil,mtOrigSessionRole!=nil,mtOrigSupportsMulti!=nil);
    [[NSNotificationCenter defaultCenter] addObserverForName:UISceneDidActivateNotification object:nil queue:nil usingBlock:^(NSNotification *n){
        UIScene *scene=n.object; NSString *sid=scene.session.persistentIdentifier?:@"";
        MTLog(@"[HYBRID-APP] ACTIVATE sid=%@ role=%@ class=%@ screen=%@",sid,scene.session.role,NSStringFromClass(scene.class),[scene isKindOfClass:UIWindowScene.class]?((UIWindowScene*)scene).screen:nil);
    }];
}
%hook DBDashboard
- (void)_handleCarPlayUIReady {
    %orig;
    MTLog(@"[DIRECT-READY] open Google Maps once to supply native environment and activation settings");
    dispatch_async(dispatch_get_main_queue(),^{MTTryDirectLaunch();});
}
- (void)_handleOpenApplicationEvent:(id)event {
    id context=MTV(event,@"context");if(!context)context=MTV(event,@"_context");
    id app=MTV(context,@"application");
    if(!app){id value=MTV(context,@"value");if(value){context=value;app=MTV(value,@"application");}}
    NSString *bundle=MTV(app,@"bundleIdentifier");
    BOOL maps=[bundle isEqualToString:@"com.google.Maps"]||[bundle isEqualToString:@"com.apple.Maps"];
    if(maps){
        id settings=MTV(context,@"activationSettings");
        if([settings isKindOfClass:NSDictionary.class]){gActivation=[settings copy];MTLog(@"[DIRECT-SEED] app=%@ settings=%@",bundle,gActivation);}
    }
    %orig;
    if(maps)dispatch_async(dispatch_get_main_queue(),^{MTTryDirectLaunch();});
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
- (id)initWithApplicationInfo:(id)app environment:(id)env {
    id result=%orig;
    NSString *bundle=MTV(app,@"bundleIdentifier");
    if(env && ([bundle isEqualToString:@"com.google.Maps"]||[bundle isEqualToString:@"com.apple.Maps"])){
        gEnvironment=env;dispatch_async(dispatch_get_main_queue(),^{MTTryDirectLaunch();});
    }
    return result;
}
- (id)initWithApplicationInfo:(id)app proxyApplicationInfo:(id)proxy environment:(id)env activationSettings:(id)settings {
    BOOL target=MTIsYouTube(app);
    if(target)proxy=nil;
    id result=%orig(app,proxy,env,settings);
    NSString *bundle=MTV(app,@"bundleIdentifier");
    if(env && ([bundle isEqualToString:@"com.google.Maps"]||[bundle isEqualToString:@"com.apple.Maps"])){
        gEnvironment=env;dispatch_async(dispatch_get_main_queue(),^{MTTryDirectLaunch();});
    }
    if(target)MTLog(@"[DIRECT-UPDATE] app=%@ actualProxy=%@",MTV(result,@"applicationInfo"),MTV(result,@"proxyApplicationInfo"));
    return result;
}
%end

%ctor {
    @autoreleasepool {
        NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
        if([bundle isEqualToString:@"com.google.ios.youtube"]){
            MTLog(@"[DIRECT-APP-LOADED]");MTHybridInstallAppBridge();return;
        }
        if(![bundle isEqualToString:@"com.apple.CarPlayApp"])return;
        %init;
        [[NSFileManager defaultManager]removeItemAtPath:@"/var/mobile/MiniTa.txt" error:nil];
        MTLog(@"[DIRECT-BOOT] single controller, direct client, no proxy-template launch");
        MTHybridInstallAdmission();
        [[NSNotificationCenter defaultCenter]addObserverForName:UISceneDidDisconnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
            if(note.object==gWindow.windowScene || [((UIScene*)note.object).session.persistentIdentifier containsString:@"DBDashboard-Car"]){MTLog(@"[DIRECT-DISCONNECT]");MTReset();}
        }];
    }
}

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const MTLogPath=@"/var/mobile/MiniTa.txt";
static id gYTController=nil; static NSDictionary *gYTSettings=nil; static id gYTAppInfo=nil; static id gDashboardEnv=nil;
static void MTValidateYouTubeInDashboard(void);
static void MTTryDashboardLaunchYouTube(void); static UIWindow *gHostWindow=nil; static UIView *gPresentation=nil;
static void MTLog(NSString *fmt,...){va_list a;va_start(a,fmt);NSString*m=[[NSString alloc]initWithFormat:fmt arguments:a];va_end(a);NSData*d=[[m stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];NSFileHandle*h=[NSFileHandle fileHandleForWritingAtPath:MTLogPath];if(!h){[d writeToFile:MTLogPath atomically:YES];return;}[h seekToEndOfFile];[h writeData:d];[h closeFile];}
static id MTV(id o,NSString*k){@try{return[o valueForKey:k];}@catch(__unused NSException*e){return nil;}}
static NSString *MTBundleFromSID(NSString *sid){if(![sid isKindOfClass:NSString.class])return nil;for(NSString*p in [sid componentsSeparatedByString:@":"])if([p isEqualToString:@"com.google.ios.youtube"])return p;return nil;}
static UIWindowScene *MTCarScene(void){for(UIScene*s in UIApplication.sharedApplication.connectedScenes)if([s isKindOfClass:UIWindowScene.class]){UIWindowScene*w=(UIWindowScene*)s;CGSize z=w.coordinateSpace.bounds.size;if(z.width>300&&z.height<=500)return w;}return nil;}
static void MTHostYouTube(void){
 if(!gYTController||!gYTSettings){MTLog(@"[HOST] no captured YouTube controller");return;}
 UIWindowScene*scene=MTCarScene();if(!scene){MTLog(@"[HOST] no CarPlay scene");return;}
 SEL fg=NSSelectorFromString(@"foregroundSceneWithSettings:completion:");SEL pv=NSSelectorFromString(@"presentationViewWithIdentifier:");
 if(![gYTController respondsToSelector:fg]||![gYTController respondsToSelector:pv]){MTLog(@"[HOST] APIs missing controller=%@",NSStringFromClass([gYTController class]));return;}
 @try{
   ((void(*)(id,SEL,id,id))objc_msgSend)(gYTController,fg,gYTSettings,nil);
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.7*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
     NSString*pid=@"com.sushibta.minita.youtube";
     id v=((id(*)(id,SEL,id))objc_msgSend)(gYTController,pv,pid);
     MTLog(@"[HOST] presentation class=%@ super=%@",NSStringFromClass([v class]),NSStringFromClass([v superview].class));
     if(![v isKindOfClass:UIView.class])return;
     if(!gHostWindow){gHostWindow=[[UIWindow alloc]initWithWindowScene:scene];gHostWindow.frame=scene.coordinateSpace.bounds;gHostWindow.windowLevel=UIWindowLevelAlert+60;gHostWindow.rootViewController=[UIViewController new];gHostWindow.rootViewController.view.backgroundColor=UIColor.blackColor;}
     gPresentation=v;[gPresentation removeFromSuperview];gPresentation.frame=gHostWindow.bounds;gPresentation.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[gHostWindow.rootViewController.view addSubview:gPresentation];gHostWindow.hidden=NO;
     MTLog(@"[HOST] ATTACHED frame=%@ scene=%@",NSStringFromCGRect(gPresentation.frame),scene.session.persistentIdentifier);
   });
 }@catch(NSException*e){MTLog(@"[HOST] ERROR %@ %@",e.name,e.reason);}
}

static void MTDumpMethods(Class c, NSString *name){
    unsigned int count=0;Method *methods=class_copyMethodList(c,&count);
    for(unsigned int i=0;i<count;i++){
        SEL sel=method_getName(methods[i]);NSString *sn=NSStringFromSelector(sel);
        if([sn localizedCaseInsensitiveContainsString:@"activ"]||
           [sn localizedCaseInsensitiveContainsString:@"launch"]||
           [sn localizedCaseInsensitiveContainsString:@"application"]||
           [sn localizedCaseInsensitiveContainsString:@"scene"]||
           [sn localizedCaseInsensitiveContainsString:@"carplay"]||
           [sn localizedCaseInsensitiveContainsString:@"foreground"])
            MTLog(@"[ACT-METHOD] %@ -%@ types=%s",name,sn,method_getTypeEncoding(methods[i]));
    }
    free(methods);
    Class meta=object_getClass(c);count=0;methods=class_copyMethodList(meta,&count);
    for(unsigned int i=0;i<count;i++){
        SEL sel=method_getName(methods[i]);NSString *sn=NSStringFromSelector(sel);
        if([sn localizedCaseInsensitiveContainsString:@"activ"]||
           [sn localizedCaseInsensitiveContainsString:@"launch"]||
           [sn localizedCaseInsensitiveContainsString:@"application"]||
           [sn localizedCaseInsensitiveContainsString:@"scene"]||
           [sn localizedCaseInsensitiveContainsString:@"carplay"]||
           [sn localizedCaseInsensitiveContainsString:@"shared"])
            MTLog(@"[ACT-METHOD] %@ +%@ types=%s",name,sn,method_getTypeEncoding(methods[i]));
    }
    free(methods);
}
static void MTProbeActivationServices(void){
    NSArray *classes=@[@"SBSApplicationCarPlayService",@"SBApplicationController",@"DBApplicationInfoCache",@"DBApplicationLaunchService",@"DBProcessMonitor"];
    NSArray *sels=@[@"sharedInstance",@"sharedService",@"service",@"defaultService",@"applicationWithBundleIdentifier:",@"applicationForBundleIdentifier:",
                    @"requestActivationForBundleIdentifier:",@"activateApplication:",@"launchApplication:",@"openApplication:"];
    for(NSString *cn in classes){
        Class c=NSClassFromString(cn);if(!c){MTLog(@"[ACT-PROBE] class %@ missing",cn);continue;}
        MTLog(@"[ACT-PROBE] class %@ present",cn); MTDumpMethods(c,cn);
        id obj=nil;
        for(NSString *ss in @[@"sharedInstance",@"sharedService",@"service",@"defaultService"]){SEL sel=NSSelectorFromString(ss);if([c respondsToSelector:sel]){@try{obj=((id(*)(id,SEL))objc_msgSend)(c,sel);MTLog(@"[ACT-PROBE] %@ +%@ -> %@",cn,ss,obj);if(obj)break;}@catch(NSException*e){MTLog(@"[ACT-PROBE] %@ +%@ error=%@",cn,ss,e.name);}}}
        id target=obj?:c;
        for(NSString *ss in sels){SEL sel=NSSelectorFromString(ss);if([target respondsToSelector:sel])MTLog(@"[ACT-PROBE] %@ responds %@",cn,ss);}
    }
}
static void MTProbeDBSceneController(void){
    Class c=NSClassFromString(@"DBApplicationSceneViewController");
    if(!c){MTLog(@"[DBSCENE] class missing");return;}
    MTLog(@"[DBSCENE] class present superclass=%@",NSStringFromClass(class_getSuperclass(c)));
    MTDumpMethods(c,@"DBApplicationSceneViewController");
    unsigned int mc=0;Method *allm=class_copyMethodList(c,&mc);
    MTLog(@"[DBSCENE] methodCount=%u",mc);
    for(unsigned int i=0;i<mc;i++) MTLog(@"[DB-METHOD] -%@ types=%s",NSStringFromSelector(method_getName(allm[i])),method_getTypeEncoding(allm[i]));
    free(allm);
    unsigned int count=0;Ivar *ivars=class_copyIvarList(c,&count);
    for(unsigned int i=0;i<count;i++){
        const char *n=ivar_getName(ivars[i]);const char *t=ivar_getTypeEncoding(ivars[i]);
        NSString *name=n?[NSString stringWithUTF8String:n]:@"";
        if([name localizedCaseInsensitiveContainsString:@"manager"]||
           [name localizedCaseInsensitiveContainsString:@"scene"]||
           [name localizedCaseInsensitiveContainsString:@"service"]||
           [name localizedCaseInsensitiveContainsString:@"application"]||
           [name localizedCaseInsensitiveContainsString:@"process"])
            MTLog(@"[DB-IVAR] %@ type=%s",name,t?t:"");
    }
    free(ivars);
    unsigned int pc=0;objc_property_t *props=class_copyPropertyList(c,&pc);
    for(unsigned int i=0;i<pc;i++){
        NSString *name=[NSString stringWithUTF8String:property_getName(props[i])];
        if([name localizedCaseInsensitiveContainsString:@"manager"]||
           [name localizedCaseInsensitiveContainsString:@"scene"]||
           [name localizedCaseInsensitiveContainsString:@"service"]||
           [name localizedCaseInsensitiveContainsString:@"application"]||
           [name localizedCaseInsensitiveContainsString:@"process"])
            MTLog(@"[DB-PROP] %@ attrs=%s",name,property_getAttributes(props[i]));
    }
    free(props);
}
static void MTProbeDBApplicationInfo(void){
    Class c=NSClassFromString(@"DBApplicationInfo");
    if(!c){MTLog(@"[APPINFO] class missing");return;}
    MTLog(@"[APPINFO] class present superclass=%@",NSStringFromClass(class_getSuperclass(c)));
    unsigned int mc=0;Method *m=class_copyMethodList(c,&mc);
    for(unsigned int i=0;i<mc;i++)MTLog(@"[APPINFO-METHOD] -%@ types=%s",NSStringFromSelector(method_getName(m[i])),method_getTypeEncoding(m[i]));
    free(m);
    Class meta=object_getClass(c);mc=0;m=class_copyMethodList(meta,&mc);
    for(unsigned int i=0;i<mc;i++)MTLog(@"[APPINFO-METHOD] +%@ types=%s",NSStringFromSelector(method_getName(m[i])),method_getTypeEncoding(m[i]));
    free(m);
}
static void MTProbeFBSApplicationInfo(void){
    Class c=NSClassFromString(@"FBSApplicationInfo");
    if(!c){MTLog(@"[FBSAPPINFO] class missing");return;}
    MTLog(@"[FBSAPPINFO] class present superclass=%@",NSStringFromClass(class_getSuperclass(c)));
    unsigned int mc=0;Method *m=class_copyMethodList(c,&mc);
    for(unsigned int i=0;i<mc;i++){
        NSString *sn=NSStringFromSelector(method_getName(m[i]));
        if([sn localizedCaseInsensitiveContainsString:@"bundle"]||
           [sn localizedCaseInsensitiveContainsString:@"proxy"]||
           [sn localizedCaseInsensitiveContainsString:@"init"]||
           [sn localizedCaseInsensitiveContainsString:@"application"]||
           [sn localizedCaseInsensitiveContainsString:@"identifier"])
            MTLog(@"[FBSAPPINFO-METHOD] -%@ types=%s",sn,method_getTypeEncoding(m[i]));
    }
    free(m);
    Class meta=object_getClass(c);mc=0;m=class_copyMethodList(meta,&mc);
    for(unsigned int i=0;i<mc;i++){
        NSString *sn=NSStringFromSelector(method_getName(m[i]));
        if([sn localizedCaseInsensitiveContainsString:@"bundle"]||
           [sn localizedCaseInsensitiveContainsString:@"proxy"]||
           [sn localizedCaseInsensitiveContainsString:@"application"]||
           [sn localizedCaseInsensitiveContainsString:@"identifier"])
            MTLog(@"[FBSAPPINFO-METHOD] +%@ types=%s",sn,method_getTypeEncoding(m[i]));
    }
    free(m);
}
static void MTProbeApplicationProxy(void){
    NSArray *names=@[@"LSApplicationProxy",@"LSApplicationWorkspace"];
    for(NSString *cn in names){
        Class c=NSClassFromString(cn);
        if(!c){MTLog(@"[LSPROXY] class %@ missing",cn);continue;}
        MTLog(@"[LSPROXY] class %@ present",cn);
        Class meta=object_getClass(c);unsigned int mc=0;Method *m=class_copyMethodList(meta,&mc);
        for(unsigned int i=0;i<mc;i++){
            NSString *sn=NSStringFromSelector(method_getName(m[i]));
            if([sn localizedCaseInsensitiveContainsString:@"application"]||
               [sn localizedCaseInsensitiveContainsString:@"bundle"]||
               [sn localizedCaseInsensitiveContainsString:@"proxy"]||
               [sn localizedCaseInsensitiveContainsString:@"default"])
                MTLog(@"[LSPROXY-METHOD] %@ +%@ types=%s",cn,sn,method_getTypeEncoding(m[i]));
        }
        free(m);
    }
}
static void MTTryBuildYouTubeAppInfo(void){
    Class lp=NSClassFromString(@"LSApplicationProxy"), di=NSClassFromString(@"DBApplicationInfo");
    if(!lp||!di){MTLog(@"[BUILD] classes missing proxy=%@ info=%@",lp,di);return;}
    SEL ps=NSSelectorFromString(@"applicationProxyForIdentifier:");
    if(![lp respondsToSelector:ps]){MTLog(@"[BUILD] proxy factory missing");return;}
    id proxy=nil,info=nil;
    @try{
        proxy=((id(*)(id,SEL,id))objc_msgSend)(lp,ps,@"com.google.ios.youtube");
        MTLog(@"[BUILD] proxy=%@ class=%@",proxy,NSStringFromClass([proxy class]));
        if(!proxy)return;
        SEL init=NSSelectorFromString(@"initWithApplicationProxy:");
        info=((id(*)(id,SEL,id))objc_msgSend)([di alloc],init,proxy);
        MTLog(@"[BUILD] appInfo=%@ class=%@ valid=%@ name=%@ declaration=%@",info,NSStringFromClass([info class]),MTV(info,@"isValid"),MTV(info,@"displayName"),MTV(info,@"carPlayDeclaration"));
        if(!info)return;
        if([info respondsToSelector:NSSelectorFromString(@"setCBFake:")])((void(*)(id,SEL,BOOL))objc_msgSend)(info,NSSelectorFromString(@"setCBFake:"),YES);
        if([info respondsToSelector:NSSelectorFromString(@"setCBBridged:")])((void(*)(id,SEL,BOOL))objc_msgSend)(info,NSSelectorFromString(@"setCBBridged:"),YES);
        gYTAppInfo=info;
        MTLog(@"[BUILD] flags CBFake=%@ CBBridged=%@",MTV(info,@"CBFake"),MTV(info,@"CBBridged"));
        MTValidateYouTubeInDashboard();
    }@catch(NSException*e){MTLog(@"[BUILD] ERROR %@ %@",e.name,e.reason);}
}
static void MTProbeControllerEnvironment(id controller, NSString *sid){
    if(!controller)return;
    id env=MTV(controller,@"environment"); if(env && [NSStringFromClass([env class]) isEqualToString:@"DBDashboard"]) gDashboardEnv=env;
    id req=MTV(controller,@"requester");
    MTLog(@"[ENV] sid=%@ controller=%@ environment=%@ envClass=%@ requester=%@ requesterClass=%@",
          sid,NSStringFromClass([controller class]),env,NSStringFromClass([env class]),req,NSStringFromClass([req class]));
    if(env)MTDumpMethods([env class],[NSString stringWithFormat:@"ENV:%@",NSStringFromClass([env class])]);
    MTValidateYouTubeInDashboard();
}
static void MTValidateYouTubeInDashboard(void){
    if(!gYTAppInfo||!gDashboardEnv){MTLog(@"[DASH] waiting appInfo=%d env=%d",gYTAppInfo!=nil,gDashboardEnv!=nil);return;}
    @try{
        SEL pre=NSSelectorFromString(@"preflightRequiredForApplicationInfo:");
        SEL sid=NSSelectorFromString(@"sceneIdentifierForAppInfo:");
        SEL frm=NSSelectorFromString(@"sceneFrameForAppInfo:");
        SEL scene=NSSelectorFromString(@"sceneForAppInfo:");
        if([gDashboardEnv respondsToSelector:pre]) MTLog(@"[DASH] preflightRequired=%d",((BOOL(*)(id,SEL,id))objc_msgSend)(gDashboardEnv,pre,gYTAppInfo));
        if([gDashboardEnv respondsToSelector:sid]) MTLog(@"[DASH] sceneIdentifier=%@",((id(*)(id,SEL,id))objc_msgSend)(gDashboardEnv,sid,gYTAppInfo));
        if([gDashboardEnv respondsToSelector:frm]){CGRect r=((CGRect(*)(id,SEL,id))objc_msgSend)(gDashboardEnv,frm,gYTAppInfo);MTLog(@"[DASH] sceneFrame=%@",NSStringFromCGRect(r));}
        if([gDashboardEnv respondsToSelector:scene]) MTLog(@"[DASH] existingScene=%@",((id(*)(id,SEL,id))objc_msgSend)(gDashboardEnv,scene,gYTAppInfo));
        MTTryDashboardLaunchYouTube();
    }@catch(NSException*e){MTLog(@"[DASH] ERROR %@ %@",e.name,e.reason);}
}
static BOOL gDidLaunchYT=NO;
static void MTTryDashboardLaunchYouTube(void){
    if(gDidLaunchYT||!gYTAppInfo||!gDashboardEnv)return;
    SEL launch=NSSelectorFromString(@"_launchAppWithInfo:forURL:");
    if(![gDashboardEnv respondsToSelector:launch]){MTLog(@"[LAUNCH] selector missing");return;}
    gDidLaunchYT=YES;
    @try{
        MTLog(@"[LAUNCH] preparing Dashboard launch appInfo=%@ sceneID=%@",gYTAppInfo,
              ((id(*)(id,SEL,id))objc_msgSend)(gDashboardEnv,NSSelectorFromString(@"sceneIdentifierForAppInfo:"),gYTAppInfo));
        Class li=NSClassFromString(@"DBApplicationLaunchInfo");
        SEL initLI=NSSelectorFromString(@"initWithApplication:activationSettings:");
        if(!li || ![li instancesRespondToSelector:initLI]) { MTLog(@"[LAUNCH] launchInfo class/init missing"); gDidLaunchYT=NO; return; }
        NSDictionary *activation=@{@"DBActivationSettingLaunchSource":@"MiniTa"};
        id launchInfo=((id(*)(id,SEL,id,id))objc_msgSend)([li alloc],initLI,gYTAppInfo,activation);
        MTLog(@"[LAUNCH] launchInfo=%@ application=%@ settings=%@",launchInfo,MTV(launchInfo,@"application"),MTV(launchInfo,@"activationSettings"));
        ((void(*)(id,SEL,id,id))objc_msgSend)(gDashboardEnv,launch,launchInfo,nil);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            id scene=nil;
            @try{scene=((id(*)(id,SEL,id))objc_msgSend)(gDashboardEnv,NSSelectorFromString(@"sceneForAppInfo:"),gYTAppInfo);}@catch(__unused NSException*e){}
            MTLog(@"[LAUNCH] after scene=%@",scene);
        });
    }@catch(NSException*e){MTLog(@"[LAUNCH] ERROR %@ %@",e.name,e.reason);gDidLaunchYT=NO;}
}
static void MTProbeLaunchInfoClass(void){
    NSArray *names=@[@"DBApplicationLaunchInfo",@"DBApplicationLaunchInformation",@"DBLaunchInfo",@"DBOpenApplicationEvent"];
    for(NSString *cn in names){
        Class c=NSClassFromString(cn);if(!c){MTLog(@"[LAUNCHINFO] %@ missing",cn);continue;}
        MTLog(@"[LAUNCHINFO] %@ present superclass=%@",cn,NSStringFromClass(class_getSuperclass(c)));
        unsigned int mc=0;Method *m=class_copyMethodList(c,&mc);
        for(unsigned int i=0;i<mc;i++)MTLog(@"[LAUNCHINFO-METHOD] %@ -%@ types=%s",cn,NSStringFromSelector(method_getName(m[i])),method_getTypeEncoding(m[i]));
        free(m);
    }
}
static void MTTryKnownCarPlayActivation(void){
    MTProbeActivationServices();
    MTProbeDBSceneController();
    MTProbeDBApplicationInfo();
    MTProbeFBSApplicationInfo();
    MTProbeApplicationProxy();
    MTProbeLaunchInfoClass();
    MTTryBuildYouTubeAppInfo();
    Class c=NSClassFromString(@"SBSApplicationCarPlayService");if(!c)return;
    id svc=nil;for(NSString *ss in @[@"sharedInstance",@"sharedService",@"service",@"defaultService"]){SEL sel=NSSelectorFromString(ss);if([c respondsToSelector:sel]){@try{svc=((id(*)(id,SEL))objc_msgSend)(c,sel);if(svc)break;}@catch(__unused NSException*e){}}}
    if(!svc)return;
    NSString *bundle=@"com.google.ios.youtube";
    for(NSString *ss in @[@"requestActivationForBundleIdentifier:",@"activateApplication:",@"launchApplication:",@"openApplication:"]){
        SEL sel=NSSelectorFromString(ss);if(![svc respondsToSelector:sel])continue;
        @try{MTLog(@"[ACT] trying %@ %@",ss,bundle);((void(*)(id,SEL,id))objc_msgSend)(svc,sel,bundle);return;}
        @catch(NSException*e){MTLog(@"[ACT] %@ error %@ %@",ss,e.name,e.reason);}
    }
}
%hook DBApplicationSceneViewController
- (void)foregroundSceneWithSettings:(id)settings completion:(id)completion{
 NSString*sid=MTV((id)self,@"sceneID"); MTProbeControllerEnvironment((id)self,sid); NSString*b=MTBundleFromSID(sid);
 if(b&&[settings isKindOfClass:NSDictionary.class]&&settings[@"DBActivationSettingLaunchSource"]){
   gYTController=(id)self;gYTSettings=[settings copy];MTLog(@"[CAPTURE] youtube sid=%@ controller=%@ source=%@",sid,NSStringFromClass(object_getClass((id)self)),settings[@"DBActivationSettingLaunchSource"]);
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{MTHostYouTube();});
 }
 %orig;
}
%end
%ctor{@autoreleasepool{[[NSFileManager defaultManager]removeItemAtPath:MTLogPath error:nil];MTLog(@"=== MINITA PHASE3 YOUTUBE ACTIVATION === bundle=%@ process=%@",NSBundle.mainBundle.bundleIdentifier,NSProcessInfo.processInfo.processName);
dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{MTTryKnownCarPlayActivation();});}}

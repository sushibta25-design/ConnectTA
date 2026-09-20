#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const MTLogPath=@"/var/mobile/MiniTa.txt";
static id gMTHybridNativeLaunchArg=nil;
static __weak id gMTHybridDashboard=nil;
static id gYTController=nil; static NSDictionary *gYTSettings=nil; static id gYTAppInfo=nil; static id gDashboardEnv=nil; static id gCarDisplayConfig=nil; static id gDirectYTScene=nil;
static void MTValidateYouTubeInDashboard(void);
static void MTProbeRealYouTubeIdentity(void);
static void MTTryLaunchYouTubeProcess(void);
static void MTProbeValidClientIdentity(void);
static void MTBuildDirectDefinitionProbe(void);
static void MTTryCreateDirectYouTubeScene(void);
static void MTProbeDirectSceneActivation(id scene);
static void MTTryActivateDirectYouTubeScene(id scene);
static void MTProbeDirectSceneObjects(void);
static void MTProbeDirectSceneInputs(void);
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
        if([sn localizedCaseInsensitiveContainsString:@"activ"]||[sn localizedCaseInsensitiveContainsString:@"launch"]||[sn localizedCaseInsensitiveContainsString:@"application"]||[sn localizedCaseInsensitiveContainsString:@"scene"]||[sn localizedCaseInsensitiveContainsString:@"carplay"]||[sn localizedCaseInsensitiveContainsString:@"foreground"]){ /* quiet */ }
    free(methods);
    Class meta=object_getClass(c);count=0;methods=class_copyMethodList(meta,&count);
    for(unsigned int i=0;i<count;i++){
        SEL sel=method_getName(methods[i]);NSString *sn=NSStringFromSelector(sel);
        if([sn localizedCaseInsensitiveContainsString:@"activ"]||[sn localizedCaseInsensitiveContainsString:@"launch"]||[sn localizedCaseInsensitiveContainsString:@"application"]||[sn localizedCaseInsensitiveContainsString:@"scene"]||[sn localizedCaseInsensitiveContainsString:@"carplay"]||[sn localizedCaseInsensitiveContainsString:@"shared"]){ /* quiet */ }
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
        MTProbeRealYouTubeIdentity();
        MTTryLaunchYouTubeProcess();
        MTProbeValidClientIdentity();
        MTBuildDirectDefinitionProbe();
        MTTryCreateDirectYouTubeScene();
        MTProbeDirectSceneObjects();
        MTProbeDirectSceneInputs();
        MTValidateYouTubeInDashboard();
    }@catch(NSException*e){MTLog(@"[BUILD] ERROR %@ %@",e.name,e.reason);}
}
static void MTProbeControllerEnvironment(id controller, NSString *sid){
    if(!controller)return;
    id realScene=MTV(controller,@"scene");
    id realSettings=MTV(realScene,@"settings");
    id dc=MTV(realSettings,@"displayConfiguration");
    if(dc) {
        gCarDisplayConfig=dc;
        if(gDirectYTScene && !MTV(gDirectYTScene,@"clientProcess")){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.25*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                MTLog(@"[DIRECTGO] retry after display capture");
                MTTryActivateDirectYouTubeScene(gDirectYTScene);
            });
        }
    }

    id req=MTV(controller,@"requester");
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
static void __attribute__((used)) MTDumpSceneInternals(id controller){
    if(!controller)return;
    id scene=MTV(controller,@"scene");
    id update=MTV(controller,@"currentSceneUpdate");
    id presenters=MTV(controller,@"scenePresentersByIdentifier");
    MTLog(@"[SCENE] scene=%@ class=%@ update=%@ updateClass=%@ presenters=%@",scene,NSStringFromClass([scene class]),update,NSStringFromClass([update class]),presenters);
    if(scene){
        for(NSString *k in @[@"identifier",@"clientProcess",@"clientIdentity",@"settings",@"clientSettings",@"specification",@"definition",@"hostProcess",@"workspaceIdentifier"]){
            MTLog(@"[SCENE] %@=%@",k,MTV(scene,k));
        }
    }
    if(update){
        unsigned int mc=0;Method *m=class_copyMethodList([update class],&mc);
        for(unsigned int i=0;i<mc;i++) MTLog(@"[UPDATE-METHOD] -%@ types=%s",NSStringFromSelector(method_getName(m[i])),method_getTypeEncoding(m[i]));
        free(m);
        MTLog(@"[UPDATE] %@",update);
    }
}
static void MTProbeSceneSpecificationClasses(void){
    NSArray *names=@[@"CRSUIProxyApplicationSceneSpecification",@"FBSSceneDefinition",@"FBSSceneIdentity",@"FBSceneManager"];
    for(NSString *cn in names){
        Class c=NSClassFromString(cn); if(!c){MTLog(@"[SPEC] %@ missing",cn);continue;}
        MTLog(@"[SPEC] %@ present superclass=%@",cn,NSStringFromClass(class_getSuperclass(c)));
        unsigned int mc=0; Method *m=class_copyMethodList(c,&mc);
        for(unsigned int i=0;i<mc;i++){
            NSString *sn=NSStringFromSelector(method_getName(m[i]));
            if([sn localizedCaseInsensitiveContainsString:@"init"]||
               [sn localizedCaseInsensitiveContainsString:@"identity"]||
               [sn localizedCaseInsensitiveContainsString:@"client"]||
               [sn localizedCaseInsensitiveContainsString:@"application"]||
               [sn localizedCaseInsensitiveContainsString:@"scene"]||
               [sn localizedCaseInsensitiveContainsString:@"specification"])
                MTLog(@"[SPEC-METHOD] %@ -%@ types=%s",cn,sn,method_getTypeEncoding(m[i]));
        } free(m);
        Class meta=object_getClass(c);mc=0;m=class_copyMethodList(meta,&mc);
        for(unsigned int i=0;i<mc;i++){
            NSString *sn=NSStringFromSelector(method_getName(m[i]));
            if([sn localizedCaseInsensitiveContainsString:@"identity"]||
               [sn localizedCaseInsensitiveContainsString:@"application"]||
               [sn localizedCaseInsensitiveContainsString:@"scene"]||
               [sn localizedCaseInsensitiveContainsString:@"specification"])
                MTLog(@"[SPEC-METHOD] %@ +%@ types=%s",cn,sn,method_getTypeEncoding(m[i]));
        } free(m);
    }
}
static void MTProbeIdentityAndSpecFactories(void){
    NSArray *names=@[@"FBSApplicationIdentity",@"FBSProcessIdentity",@"UIApplicationSceneSpecification",@"UIApplicationStarkSceneSpecification",@"UIApplicationSceneSettings",@"UIApplicationSceneClientSettings"];
    for(NSString *cn in names){
        Class c=NSClassFromString(cn);if(!c){MTLog(@"[DIRECT] %@ missing",cn);continue;}
        MTLog(@"[DIRECT] %@ present superclass=%@",cn,NSStringFromClass(class_getSuperclass(c)));
        for(id target in @[c,object_getClass(c)]){
            BOOL meta=(target==object_getClass(c));unsigned int mc=0;Method *m=class_copyMethodList(target,&mc);
            for(unsigned int i=0;i<mc;i++){
                NSString *sn=NSStringFromSelector(method_getName(m[i]));
                if([sn localizedCaseInsensitiveContainsString:@"identity"]||
                   [sn localizedCaseInsensitiveContainsString:@"bundle"]||
                   [sn localizedCaseInsensitiveContainsString:@"application"]||
                   [sn localizedCaseInsensitiveContainsString:@"specification"]||
                   [sn localizedCaseInsensitiveContainsString:@"settings"]||
                   [sn localizedCaseInsensitiveContainsString:@"init"])
                    MTLog(@"[DIRECT-METHOD] %@ %c%@ types=%s",cn,meta?'+':'-',sn,method_getTypeEncoding(m[i]));
            } free(m);
        }
    }
    if(gYTAppInfo) MTLog(@"[DIRECT] yt applicationIdentity=%@ processIdentity=%@",MTV(gYTAppInfo,@"applicationIdentity"),MTV(gYTAppInfo,@"processIdentity"));
}
static void MTProbeRealYouTubeIdentity(void){
    if(!gYTAppInfo){MTLog(@"[YTIDENT] appInfo missing");return;}
    for(NSString *key in @[@"applicationIdentity",@"processIdentity"]){
        id ident=MTV(gYTAppInfo,key);
        MTLog(@"[YTIDENT] %@=%@ class=%@",key,ident,NSStringFromClass([ident class]));
        if(!ident)continue;
        Class c=[ident class];
        unsigned int mc=0;Method *m=class_copyMethodList(c,&mc);
        for(unsigned int i=0;i<mc;i++){
            NSString *sn=NSStringFromSelector(method_getName(m[i]));
            if([sn localizedCaseInsensitiveContainsString:@"identity"]||
               [sn localizedCaseInsensitiveContainsString:@"identifier"]||
               [sn localizedCaseInsensitiveContainsString:@"bundle"]||
               [sn localizedCaseInsensitiveContainsString:@"application"]||
               [sn localizedCaseInsensitiveContainsString:@"process"]||
               [sn localizedCaseInsensitiveContainsString:@"init"])
                MTLog(@"[YTIDENT-METHOD] %@ -%@ types=%s",NSStringFromClass(c),sn,method_getTypeEncoding(m[i]));
        }
        free(m);
        Class meta=object_getClass(c);mc=0;m=class_copyMethodList(meta,&mc);
        for(unsigned int i=0;i<mc;i++){
            NSString *sn=NSStringFromSelector(method_getName(m[i]));
            if([sn localizedCaseInsensitiveContainsString:@"identity"]||
               [sn localizedCaseInsensitiveContainsString:@"identifier"]||
               [sn localizedCaseInsensitiveContainsString:@"bundle"]||
               [sn localizedCaseInsensitiveContainsString:@"application"]||
               [sn localizedCaseInsensitiveContainsString:@"process"])
                MTLog(@"[YTIDENT-METHOD] %@ +%@ types=%s",NSStringFromClass(c),sn,method_getTypeEncoding(m[i]));
        }
        free(m);
    }
}
static void MTProbeDirectSceneInputs(void){
    if(!gYTAppInfo){MTLog(@"[DIRECT2] appInfo missing");return;}
    id pid=MTV(gYTAppInfo,@"processIdentity");
    MTLog(@"[DIRECT2] processIdentity=%@ class=%@",pid,NSStringFromClass([pid class]));
    Class def=NSClassFromString(@"FBSSceneDefinition");
    Class spec=NSClassFromString(@"UIApplicationStarkSceneSpecification");
    if(def){
        unsigned int mc=0;Method *m=class_copyMethodList(def,&mc);
        for(unsigned int i=0;i<mc;i++) MTLog(@"[DIRECT2-DEF] -%@ types=%s",NSStringFromSelector(method_getName(m[i])),method_getTypeEncoding(m[i]));
        free(m);
        Class meta=object_getClass(def);mc=0;m=class_copyMethodList(meta,&mc);
        for(unsigned int i=0;i<mc;i++) MTLog(@"[DIRECT2-DEF] +%@ types=%s",NSStringFromSelector(method_getName(m[i])),method_getTypeEncoding(m[i]));
        free(m);
    }
    if(spec){
        Class meta=object_getClass(spec);unsigned int mc=0;Method *m=class_copyMethodList(meta,&mc);
        for(unsigned int i=0;i<mc;i++) MTLog(@"[DIRECT2-SPEC] +%@ types=%s",NSStringFromSelector(method_getName(m[i])),method_getTypeEncoding(m[i]));
        free(m);
    }
    Class mgr=NSClassFromString(@"FBSceneManager");
    if(mgr){
        Class meta=object_getClass(mgr);unsigned int mc=0;Method *m=class_copyMethodList(meta,&mc);
        for(unsigned int i=0;i<mc;i++) MTLog(@"[DIRECT2-MGR] +%@ types=%s",NSStringFromSelector(method_getName(m[i])),method_getTypeEncoding(m[i]));
        free(m);
    }
}
static void MTProbeDirectSceneObjects(void){
    if(!gYTAppInfo)return;
    id proc=MTV(gYTAppInfo,@"processIdentity");
    Class def=NSClassFromString(@"FBSSceneDefinition");
    Class ident=NSClassFromString(@"FBSSceneIdentity");
    Class spec=NSClassFromString(@"UIApplicationSceneSpecification");
    MTLog(@"[DIRECT2] processIdentity=%@ def=%@ ident=%@ spec=%@",proc,def,ident,spec);
    if(spec){
        id o=nil;
        @try{o=[spec new];} @catch(NSException *e){MTLog(@"[DIRECT2] spec new ERROR %@ %@",e.name,e.reason);}
        MTLog(@"[DIRECT2] specObject=%@ settingsClass=%@ clientSettingsClass=%@",o,
              o?((id(*)(id,SEL))objc_msgSend)(o,NSSelectorFromString(@"settingsClass")):nil,
              o?((id(*)(id,SEL))objc_msgSend)(o,NSSelectorFromString(@"clientSettingsClass")):nil);
    }
    if(def){
        unsigned int mc=0;Method *m=class_copyMethodList(def,&mc);
        for(unsigned int i=0;i<mc;i++) MTLog(@"[DIRECT2-DEF] -%@ types=%s",NSStringFromSelector(method_getName(m[i])),method_getTypeEncoding(m[i]));
        free(m);
        Class meta=object_getClass(def);mc=0;m=class_copyMethodList(meta,&mc);
        for(unsigned int i=0;i<mc;i++) MTLog(@"[DIRECT2-DEF] +%@ types=%s",NSStringFromSelector(method_getName(m[i])),method_getTypeEncoding(m[i]));
        free(m);
    }
}
static void MTBuildDirectDefinitionProbe(void){
    if(!gYTAppInfo){MTLog(@"[DIRECTDEF] appInfo missing");return;}
    id proc=MTV(gYTAppInfo,@"processIdentity");
    Class dc=NSClassFromString(@"FBSSceneDefinition");
    Class ic=NSClassFromString(@"FBSSceneIdentity");
    Class sc=NSClassFromString(@"UIApplicationStarkSceneSpecification");
    if(!proc||!dc||!ic||!sc){MTLog(@"[DIRECTDEF] missing proc=%@ def=%@ ident=%@ spec=%@",proc,dc,ic,sc);return;}
    @try{
        id def=((id(*)(id,SEL))objc_msgSend)(dc,NSSelectorFromString(@"definition"));
        NSString *sid=@"MiniTa.Direct.com.google.ios.youtube";
        id ident=((id(*)(id,SEL,id,id))objc_msgSend)(ic,NSSelectorFromString(@"identityForIdentifier:workspaceIdentifier:"),sid,@"kDBAppWorkspaceIdentifier");
        id spec=[[sc alloc] init];
        ((void(*)(id,SEL,id))objc_msgSend)(def,NSSelectorFromString(@"setIdentity:"),ident);
        ((void(*)(id,SEL,id))objc_msgSend)(def,NSSelectorFromString(@"setClientIdentity:"),proc);
        ((void(*)(id,SEL,id))objc_msgSend)(def,NSSelectorFromString(@"setSpecification:"),spec);
        MTLog(@"[DIRECTDEF] def=%@ valid=%@ identity=%@ client=%@ spec=%@ settingsClass=%@ clientSettingsClass=%@",
              def,MTV(def,@"isValid"),MTV(def,@"identity"),MTV(def,@"clientIdentity"),MTV(def,@"specification"),
              MTV(spec,@"settingsClass"),MTV(spec,@"clientSettingsClass"));
    }@catch(NSException *e){MTLog(@"[DIRECTDEF] ERROR %@ %@",e.name,e.reason);}
}
static BOOL gDidCreateDirectYT=NO;
static void MTTryCreateDirectYouTubeScene(void){
    if(gDidCreateDirectYT||!gYTAppInfo)return;
    id proc=MTV(gYTAppInfo,@"processIdentity");
    id client=nil;
    SEL cidSel=NSSelectorFromString(@"fbs_sceneClientIdentity");
    if(proc && [proc respondsToSelector:cidSel]) client=((id(*)(id,SEL))objc_msgSend)(proc,cidSel);
    Class dc=NSClassFromString(@"FBSSceneDefinition"),ic=NSClassFromString(@"FBSSceneIdentity");
    Class sc=NSClassFromString(@"UIApplicationStarkSceneSpecification"),mc=NSClassFromString(@"FBSceneManager");
    if(!client||!dc||!ic||!sc||!mc){MTLog(@"[DIRECTCREATE] prerequisites missing client=%@",client);return;}
    @try{
        id def=((id(*)(id,SEL))objc_msgSend)(dc,NSSelectorFromString(@"definition"));
        NSString *sid=@"MiniTa.Direct.com.google.ios.youtube";
        id ident=((id(*)(id,SEL,id,id))objc_msgSend)(ic,NSSelectorFromString(@"identityForIdentifier:workspaceIdentifier:"),sid,@"kDBAppWorkspaceIdentifier");
        id spec=[[sc alloc] init];
        ((void(*)(id,SEL,id))objc_msgSend)(def,NSSelectorFromString(@"setIdentity:"),ident);
        ((void(*)(id,SEL,id))objc_msgSend)(def,NSSelectorFromString(@"setClientIdentity:"),client);
        ((void(*)(id,SEL,id))objc_msgSend)(def,NSSelectorFromString(@"setSpecification:"),spec);
        MTLog(@"[DIRECTCREATE] process=%@ sceneClientIdentity=%@ class=%@ isValidSel=%d",proc,client,NSStringFromClass([client class]),[client respondsToSelector:NSSelectorFromString(@"isValid")]);
        BOOL valid=((BOOL(*)(id,SEL))objc_msgSend)(def,NSSelectorFromString(@"isValid"));
        MTLog(@"[DIRECTCREATE] definition valid=%d def=%@",valid,def);
        if(!valid)return;
        id mgr=((id(*)(id,SEL))objc_msgSend)(mc,NSSelectorFromString(@"sharedInstance"));
        gDidCreateDirectYT=YES;
        id scene=((id(*)(id,SEL,id))objc_msgSend)(mgr,NSSelectorFromString(@"createSceneWithDefinition:"),def);
        gDirectYTScene=scene;
        MTLog(@"[DIRECTCREATE] returned scene=%@ class=%@",scene,NSStringFromClass([scene class]));
        MTProbeDirectSceneActivation(scene);
        MTTryActivateDirectYouTubeScene(scene);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            id again=((id(*)(id,SEL,id))objc_msgSend)(mgr,NSSelectorFromString(@"sceneWithIdentifier:"),sid);
            MTLog(@"[DIRECTCREATE] after scene=%@ clientProcess=%@ definition=%@",again,MTV(again,@"clientProcess"),MTV(again,@"definition"));
        });
    }@catch(NSException *e){MTLog(@"[DIRECTCREATE] ERROR %@ %@",e.name,e.reason);gDidCreateDirectYT=NO;}
}
static void MTProbeValidClientIdentity(void){
    if(!gYTAppInfo)return;
    id proc=MTV(gYTAppInfo,@"processIdentity");
    id app=MTV(gYTAppInfo,@"applicationIdentity");
    NSArray *objs=@[proc?:[NSNull null],app?:[NSNull null]];
    for(id o in objs){
        if(o==(id)[NSNull null])continue;
        Class c=[o class];
        MTLog(@"[CID] object=%@ class=%@",o,NSStringFromClass(c));
        for(Class k=c;k;k=class_getSuperclass(k)){
            MTLog(@"[CID] chain=%@ isValid=%d",NSStringFromClass(k),[k instancesRespondToSelector:NSSelectorFromString(@"isValid")]);
        }
    }
    NSArray *names=@[@"FBProcessIdentity",@"FBApplicationProcessIdentity",@"FBSProcessIdentity",@"FBSApplicationIdentity",@"BSProcessIdentity",@"RBSProcessIdentity"];
    for(NSString *cn in names){
        Class c=NSClassFromString(cn);
        MTLog(@"[CIDCLASS] %@=%@ isValid=%d",cn,c,[c instancesRespondToSelector:NSSelectorFromString(@"isValid")]);
        if(!c)continue;
        unsigned int mc=0;Method*m=class_copyMethodList(c,&mc);
        for(unsigned int i=0;i<mc;i++){
            NSString*sn=NSStringFromSelector(method_getName(m[i]));
            if([sn localizedCaseInsensitiveContainsString:@"init"]||[sn localizedCaseInsensitiveContainsString:@"identity"]||[sn localizedCaseInsensitiveContainsString:@"process"]||[sn localizedCaseInsensitiveContainsString:@"application"])
                MTLog(@"[CIDMETHOD] %@ -%@ types=%s",cn,sn,method_getTypeEncoding(m[i]));
        }free(m);
        Class meta=object_getClass(c);mc=0;m=class_copyMethodList(meta,&mc);
        for(unsigned int i=0;i<mc;i++){
            NSString*sn=NSStringFromSelector(method_getName(m[i]));
            if([sn localizedCaseInsensitiveContainsString:@"identity"]||[sn localizedCaseInsensitiveContainsString:@"process"]||[sn localizedCaseInsensitiveContainsString:@"application"])
                MTLog(@"[CIDMETHOD] %@ +%@ types=%s",cn,sn,method_getTypeEncoding(m[i]));
        }free(m);
    }
}
static void MTProbeDirectSceneActivation(id scene){
    if(!scene)return;
    MTLog(@"[DIRECTACT] scene=%@ clientProcess=%@ settings=%@ clientSettings=%@",scene,MTV(scene,@"clientProcess"),MTV(scene,@"settings"),MTV(scene,@"clientSettings"));
    NSArray *classes=@[@"FBScene",@"FBSSceneParameters",@"FBSSceneParametersMutable",@"FBSSceneSettings",@"UICarPlayApplicationSceneSettings",@"UIApplicationSceneClientSettings"];
    for(NSString *cn in classes){
        Class c=NSClassFromString(cn);if(!c){MTLog(@"[DIRECTACT] class %@ missing",cn);continue;}
        unsigned int mc=0;Method*m=class_copyMethodList(c,&mc);
        for(unsigned int i=0;i<mc;i++){
            NSString*sn=NSStringFromSelector(method_getName(m[i]));
            if([sn localizedCaseInsensitiveContainsString:@"update"]||
               [sn localizedCaseInsensitiveContainsString:@"activate"]||
               [sn localizedCaseInsensitiveContainsString:@"foreground"]||
               [sn localizedCaseInsensitiveContainsString:@"settings"]||
               [sn localizedCaseInsensitiveContainsString:@"display"]||
               [sn localizedCaseInsensitiveContainsString:@"frame"]||
               [sn localizedCaseInsensitiveContainsString:@"parameter"]||
               [sn localizedCaseInsensitiveContainsString:@"init"])
                MTLog(@"[DIRECTACT-METHOD] %@ -%@ types=%s",cn,sn,method_getTypeEncoding(m[i]));
        }free(m);
    }
}
static void MTTryActivateDirectYouTubeScene(id scene){
    if(!scene)return;
    @try{
        id settings=MTV(scene,@"settings");
        MTLog(@"[DIRECTGO] before process=%@ display=%@ frame=%@ foreground=%@",
              MTV(scene,@"clientProcess"),MTV(settings,@"displayConfiguration"),
              NSStringFromCGRect(((CGRect(*)(id,SEL))objc_msgSend)(settings,NSSelectorFromString(@"frame"))),
              @(((BOOL(*)(id,SEL))objc_msgSend)(settings,NSSelectorFromString(@"isForeground"))));
        if(!gCarDisplayConfig){MTLog(@"[DIRECTGO] waiting for CarPlay displayConfiguration");return;}

        ((void(*)(id,SEL,id))objc_msgSend)(scene,NSSelectorFromString(@"updateSettingsWithBlock:"),^(id mutableSettings){
            @try{
                SEL sd=NSSelectorFromString(@"setDisplayConfiguration:");
                SEL sf=NSSelectorFromString(@"setFrame:");
                SEL sfg=NSSelectorFromString(@"setForeground:");
                if([mutableSettings respondsToSelector:sd]) ((void(*)(id,SEL,id))objc_msgSend)(mutableSettings,sd,gCarDisplayConfig);
                if([mutableSettings respondsToSelector:sf]) ((void(*)(id,SEL,CGRect))objc_msgSend)(mutableSettings,sf,CGRectMake(0,0,426.66666666666663,240));
                if([mutableSettings respondsToSelector:sfg]) ((void(*)(id,SEL,BOOL))objc_msgSend)(mutableSettings,sfg,YES);
                MTLog(@"[DIRECTGO] mutation class=%@ display=%@ frame=%@",NSStringFromClass([mutableSettings class]),MTV(mutableSettings,@"displayConfiguration"),
                      NSStringFromCGRect(((CGRect(*)(id,SEL))objc_msgSend)(mutableSettings,NSSelectorFromString(@"frame"))));
            }@catch(NSException *e){MTLog(@"[DIRECTGO] mutation ERROR %@ %@",e.name,e.reason);}
        });

        SEL act=NSSelectorFromString(@"pb_activate:withCompletion:");
        if(NO && [scene respondsToSelector:act]){
            MTLog(@"[DIRECTGO] pb_activate");
            void (^cfg)(id)=^(id mutableSettings){
                @try{
                    SEL sd=NSSelectorFromString(@"setDisplayConfiguration:");
                    SEL sf=NSSelectorFromString(@"setFrame:");
                    SEL sfg=NSSelectorFromString(@"setForeground:");
                    if([mutableSettings respondsToSelector:sd]) ((void(*)(id,SEL,id))objc_msgSend)(mutableSettings,sd,gCarDisplayConfig);
                    if([mutableSettings respondsToSelector:sf]) ((void(*)(id,SEL,CGRect))objc_msgSend)(mutableSettings,sf,CGRectMake(0,0,426.66666666666663,240));
                    if([mutableSettings respondsToSelector:sfg]) ((void(*)(id,SEL,BOOL))objc_msgSend)(mutableSettings,sfg,YES);
                }@catch(NSException *e){MTLog(@"[DIRECTGO] activate mutation ERROR %@ %@",e.name,e.reason);}
            };
            void (^done)(id)=^(id result){MTLog(@"[DIRECTGO] completion result=%@ process=%@ settings=%@",result,MTV(scene,@"clientProcess"),MTV(scene,@"settings"));};
            ((void(*)(id,SEL,id,id))objc_msgSend)(scene,act,cfg,done);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                id cp=MTV(scene,@"clientProcess");
                MTLog(@"[DIRECTGO] watchdog process=%@ settings=%@",cp,MTV(scene,@"settings"));
                if(!cp){
                    SEL ac2=NSSelectorFromString(@"activateWithTransitionContext:completion:");
                    if([scene respondsToSelector:ac2]){
                        MTLog(@"[DIRECTGO] watchdog fallback activateWithTransitionContext");
                        ((void(*)(id,SEL,id,id))objc_msgSend)(scene,ac2,nil,^(id result){
                            MTLog(@"[DIRECTGO] watchdog fallback completion=%@ process=%@ settings=%@",result,MTV(scene,@"clientProcess"),MTV(scene,@"settings"));
                        });
                    }
                }
            });
        }else{
            MTLog(@"[DIRECTGO] pb_activate selector missing");
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            MTLog(@"[DIRECTGO] after process=%@ settings=%@ clientSettings=%@",MTV(scene,@"clientProcess"),MTV(scene,@"settings"),MTV(scene,@"clientSettings"));
            if(!MTV(scene,@"clientProcess")){
                SEL ac=NSSelectorFromString(@"activateWithTransitionContext:completion:");
                if([scene respondsToSelector:ac]){
                    MTLog(@"[DIRECTGO] fallback activateWithTransitionContext");
                    ((void(*)(id,SEL,id,id))objc_msgSend)(scene,ac,nil,^(id result){
                        MTLog(@"[DIRECTGO] fallback completion=%@ process=%@ settings=%@",result,MTV(scene,@"clientProcess"),MTV(scene,@"settings"));
                    });
                }
            }
        });
    }@catch(NSException *e){MTLog(@"[DIRECTGO] ERROR %@ %@",e.name,e.reason);}
}
static void MTProbeClientProviderPath(void){
    NSArray *names=@[@"FBSceneClientProvider",@"FBApplicationSceneClientProvider",@"FBProcessManager",@"FBApplicationProcess",@"FBApplicationProcessLaunchTransaction",@"FBProcess"];
    for(NSString *cn in names){
        Class c=NSClassFromString(cn);if(!c){MTLog(@"[PROVIDER] %@ missing",cn);continue;}
        MTLog(@"[PROVIDER] %@ present superclass=%@",cn,NSStringFromClass(class_getSuperclass(c)));
        for(id target in @[c,object_getClass(c)]){
            BOOL meta=(target==object_getClass(c));unsigned int mc=0;Method*m=class_copyMethodList(target,&mc);
            for(unsigned int i=0;i<mc;i++){
                NSString *sn=NSStringFromSelector(method_getName(m[i]));
                if([sn localizedCaseInsensitiveContainsString:@"client"]||
                   [sn localizedCaseInsensitiveContainsString:@"process"]||
                   [sn localizedCaseInsensitiveContainsString:@"launch"]||
                   [sn localizedCaseInsensitiveContainsString:@"provider"]||
                   [sn localizedCaseInsensitiveContainsString:@"application"]||
                   [sn localizedCaseInsensitiveContainsString:@"identity"]||
                   [sn localizedCaseInsensitiveContainsString:@"init"])
                    MTLog(@"[PROVIDER-METHOD] %@ %c%@ types=%s",cn,meta?'+':'-',sn,method_getTypeEncoding(m[i]));
            }free(m);
        }
    }
}
static void MTProbeProcessLaunchContext(void){
    NSArray *names=@[@"FBProcessExecutionContext",@"FBApplicationProcessExecutionContext",@"RBSLaunchContext",@"RBSProcessIdentity",@"FBApplicationProcessLaunchTransaction"];
    for(NSString *cn in names){
        Class c=NSClassFromString(cn);if(!c){MTLog(@"[EXECCTX] %@ missing",cn);continue;}
        MTLog(@"[EXECCTX] %@ present superclass=%@",cn,NSStringFromClass(class_getSuperclass(c)));
        for(id target in @[c,object_getClass(c)]){
            BOOL meta=(target==object_getClass(c));unsigned int mc=0;Method*m=class_copyMethodList(target,&mc);
            for(unsigned int i=0;i<mc;i++){
                NSString*sn=NSStringFromSelector(method_getName(m[i]));
                if([sn localizedCaseInsensitiveContainsString:@"init"]||
                   [sn localizedCaseInsensitiveContainsString:@"context"]||
                   [sn localizedCaseInsensitiveContainsString:@"identity"]||
                   [sn localizedCaseInsensitiveContainsString:@"bundle"]||
                   [sn localizedCaseInsensitiveContainsString:@"launch"]||
                   [sn localizedCaseInsensitiveContainsString:@"application"])
                    MTLog(@"[EXECCTX-METHOD] %@ %c%@ types=%s",cn,meta?'+':'-',sn,method_getTypeEncoding(m[i]));
            }free(m);
        }
    }
}
static id gYTLaunchTransaction=nil;
static void MTTryLaunchYouTubeProcess(void){
    if(!gYTAppInfo)return;
    id procIdent=MTV(gYTAppInfo,@"processIdentity");
    Class txc=NSClassFromString(@"FBApplicationProcessLaunchTransaction");
    Class ecc=NSClassFromString(@"FBProcessExecutionContext");
    if(!procIdent||!txc||!ecc){MTLog(@"[PROCSTART] prerequisites missing");return;}
    @try{
        id ec=((id(*)(id,SEL,id))objc_msgSend)([ecc alloc],NSSelectorFromString(@"initWithIdentity:"),procIdent);
        MTLog(@"[PROCSTART] executionContext=%@ identity=%@ launchIntent=%@",ec,MTV(ec,@"identity"),MTV(ec,@"launchIntent"));
        id (^provider)(void)=^id{ MTLog(@"[PROCSTART] executionContextProvider called"); return ec; };
        id tx=((id(*)(id,SEL,id,id))objc_msgSend)([txc alloc],NSSelectorFromString(@"initWithProcessIdentity:executionContextProvider:"),procIdent,provider);
        gYTLaunchTransaction=tx;
        MTLog(@"[PROCSTART] transaction=%@ class=%@",tx,NSStringFromClass([tx class]));
        SEL begin=NSSelectorFromString(@"begin");
        if([tx respondsToSelector:begin]){
            MTLog(@"[PROCSTART] begin");
            ((void(*)(id,SEL))objc_msgSend)(tx,begin);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                MTLog(@"[PROCSTART] after failed=%@ process=%@ finished=%@",MTV(tx,@"failedLaunch"),MTV(tx,@"process"),MTV(MTV(tx,@"process"),@"finishedLaunching"));
            });
        }else MTLog(@"[PROCSTART] begin selector missing");
    }@catch(NSException *e){MTLog(@"[PROCSTART] ERROR %@ %@",e.name,e.reason);}
}
static void __attribute__((unused)) MTTryKnownCarPlayActivation(void){
    MTProbeActivationServices();
    MTProbeDBSceneController();
    MTProbeDBApplicationInfo();
    MTProbeFBSApplicationInfo();
    MTProbeApplicationProxy();
    MTProbeLaunchInfoClass();
    MTProbeSceneSpecificationClasses();
    MTProbeClientProviderPath();
    MTProbeProcessLaunchContext();
    MTProbeIdentityAndSpecFactories();
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

static void __attribute__((unused)) MTHybridRequestYouTubeLaunch(void){
    MTLog(@"[HYBRID-LAUNCH] AUTO-LAUNCH DISABLED"); return;
    Class proxy=NSClassFromString(@"LSApplicationProxy");
    Class info=NSClassFromString(@"DBApplicationInfo");
    if(!proxy||!info){MTLog(@"[HYBRID-LAUNCH] classes missing proxy=%@ info=%@",proxy,info);return;}
    @try{
        id p=((id(*)(id,SEL,id))objc_msgSend)(proxy,NSSelectorFromString(@"applicationProxyForIdentifier:"),@"com.google.ios.youtube");
        id ai=((id(*)(id,SEL,id))objc_msgSend)([info alloc],NSSelectorFromString(@"initWithApplicationProxy:"),p);
        if([ai respondsToSelector:NSSelectorFromString(@"setCBFake:")])((void(*)(id,SEL,BOOL))objc_msgSend)(ai,NSSelectorFromString(@"setCBFake:"),YES);
        if([ai respondsToSelector:NSSelectorFromString(@"setCBBridged:")])((void(*)(id,SEL,BOOL))objc_msgSend)(ai,NSSelectorFromString(@"setCBBridged:"),YES);
        MTLog(@"[HYBRID-LAUNCH] appInfo=%@ valid=%@ declaration=%@",ai,MTV(ai,@"isValid"),MTV(ai,@"carPlayDeclaration"));
        Class app=NSClassFromString(@"UIApplication"); id shared=((id(*)(id,SEL))objc_msgSend)(app,@selector(sharedApplication));
        id dash=MTV(shared,@"_currentDashboard");
        if(!dash){MTLog(@"[HYBRID-LAUNCH] dashboard missing");return;}
        SEL pre=NSSelectorFromString(@"preflightRequiredForApplicationInfo:");
        if([dash respondsToSelector:pre])MTLog(@"[HYBRID-LAUNCH] preflight=%d",((BOOL(*)(id,SEL,id))objc_msgSend)(dash,pre,ai));
        SEL launch=NSSelectorFromString(@"_launchAppWithInfo:forURL:");
        if([dash respondsToSelector:launch]){
            MTLog(@"[HYBRID-LAUNCH] invoking dashboard launch");
            ((void(*)(id,SEL,id,id))objc_msgSend)(dash,launch,ai,nil);
        }else MTLog(@"[HYBRID-LAUNCH] dashboard launch selector missing");
    }@catch(NSException *e){MTLog(@"[HYBRID-LAUNCH] ERROR %@ %@",e.name,e.reason);}
}
static __weak id gMTHybridWorkspace=nil;
static IMP mtOrigWorkspaceInit=nil;
static id MTHybridWorkspaceInit(id self,SEL _cmd,id owner){
    id result=((id(*)(id,SEL,id))mtOrigWorkspaceInit)(self,_cmd,owner);
    NSString *oc=owner?NSStringFromClass([owner class]):@"";
    if([oc isEqualToString:@"DBDashboardWorkspaceOwner"]){gMTHybridWorkspace=result;MTLog(@"[HYBRID-WS] captured workspace=%@",result);}
    return result;
}
static void MTHybridInstallWorkspaceCapture(void){
    Class c=NSClassFromString(@"DBWorkspace");Method m=c?class_getInstanceMethod(c,NSSelectorFromString(@"initWithOwner:")):NULL;
    if(!m){MTLog(@"[HYBRID-WS] DBWorkspace/initWithOwner missing");return;}
    mtOrigWorkspaceInit=method_getImplementation(m);method_setImplementation(m,(IMP)MTHybridWorkspaceInit);
    MTLog(@"[HYBRID-WS] capture installed");
}

static void MTHybridRefreshRosterAndActivate(void){
    Class info=NSClassFromString(@"DBApplicationInfo");
    Class proxy=NSClassFromString(@"LSApplicationProxy");
    if(!info||!proxy){MTLog(@"[HYBRID-ROSTER] prerequisites info=%@ proxy=%@",info,proxy);return;}
    @try{
        id p=((id(*)(id,SEL,id))objc_msgSend)(proxy,NSSelectorFromString(@"applicationProxyForIdentifier:"),@"com.google.ios.youtube");
        MTLog(@"[HYBRID-ROSTER] proxy=%@",p);
        id ai=nil;
        for(NSString *name in @[@"initWithApplicationProxy:",@"initWithApplicationProxy:carPlayDeclaration:"]){
            SEL sel=NSSelectorFromString(name);if(![[info alloc] respondsToSelector:sel])continue;
            if([name containsString:@"carPlayDeclaration"]){
                Class dc=NSClassFromString(@"CRCarPlayAppDeclaration");id d=dc?[dc new]:nil;
                if([d respondsToSelector:NSSelectorFromString(@"setSupportsTemplates:")])((void(*)(id,SEL,BOOL))objc_msgSend)(d,NSSelectorFromString(@"setSupportsTemplates:"),NO);
                if([d respondsToSelector:NSSelectorFromString(@"setSupportsMaps:")])((void(*)(id,SEL,BOOL))objc_msgSend)(d,NSSelectorFromString(@"setSupportsMaps:"),YES);
                if([d respondsToSelector:NSSelectorFromString(@"setBundleIdentifier:")])((void(*)(id,SEL,id))objc_msgSend)(d,NSSelectorFromString(@"setBundleIdentifier:"),@"com.google.ios.youtube");
                ai=((id(*)(id,SEL,id,id))objc_msgSend)([info alloc],sel,p,d);
            }else ai=((id(*)(id,SEL,id))objc_msgSend)([info alloc],sel,p);
            if(ai){MTLog(@"[HYBRID-ROSTER] built appInfo via %@ => %@",name,ai);break;}
        }
        if(!ai)return;
        id dash=gMTHybridDashboard;
        MTLog(@"[HYBRID-ROSTER] live launch owner=%@",dash);
        if(dash){
            SEL pre=NSSelectorFromString(@"preflightRequiredForApplicationInfo:");
            if([dash respondsToSelector:pre])MTLog(@"[HYBRID-ROSTER] preflight=%d",((BOOL(*)(id,SEL,id))objc_msgSend)(dash,pre,ai));
            MTLog(@"[HYBRID-ROSTER] DBApplicationInfo is not launchInfo; waiting to capture native launch contract. sample=%@",gMTHybridNativeLaunchArg);
        }
    }@catch(NSException *e){MTLog(@"[HYBRID-ROSTER] ERROR %@ %@",e.name,e.reason);}
}
#pragma mark - MiniTa hybrid bridge (DuoPhone host + CarSurf-style role bridge)

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
    static BOOL once=NO;if(once)return;once=YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{MTHybridRefreshRosterAndActivate();});
}

- (void)_launchAppWithInfo:(id)info forURL:(id)url {
    MTLog(@"[HYBRID-CONTRACT] native launch arg=%@ class=%@ application=%@ appClass=%@",info,NSStringFromClass([info class]),MTV(info,@"application"),NSStringFromClass([MTV(info,@"application") class]));
    gMTHybridNativeLaunchArg=info;
    %orig;
}
- (void)_handleOpenApplicationEvent:(id)event {
    MTLog(@"[HYBRID-OPEN] event=%@ class=%@",event,NSStringFromClass([event class]));
    id ctx=MTV(event,@"context");
    if(!ctx){@try{ctx=[event valueForKey:@"_context"];}@catch(__unused NSException*e){}}
    if(ctx){
        MTLog(@"[HYBRID-CONTEXT] value=%@ class=%@",ctx,NSStringFromClass([ctx class]));
        static BOOL onceA=NO;if(!onceA){onceA=YES;Class px=NSClassFromString(@"LSApplicationProxy");Class ic=NSClassFromString(@"DBApplicationInfo");id pp=((id(*)(id,SEL,id))objc_msgSend)(px,NSSelectorFromString(@"applicationProxyForIdentifier:"),@"com.google.ios.youtube");id localYT=((id(*)(id,SEL,id))objc_msgSend)([ic alloc],NSSelectorFromString(@"initWithApplicationProxy:"),pp);MTLog(@"[TEST-A] localYT=%@",localYT);Class c=NSClassFromString(@"DBApplicationLaunchInfo");SEL z=NSSelectorFromString(@"initWithApplication:activationSettings:");id as=MTV(ctx,@"activationSettings");if(c&&[[c alloc] respondsToSelector:z]){id y=((id(*)(id,SEL,id,id))objc_msgSend)([c alloc],z,localYT,as);MTLog(@"[TEST-A] launchInfo=%@ app=%@",y,MTV(y,@"application"));if(gMTHybridDashboard)((void(*)(id,SEL,id,id))objc_msgSend)(gMTHybridDashboard,NSSelectorFromString(@"_launchAppWithInfo:forURL:"),y,nil);}}
        for(NSString*k in @[@"application",@"applicationInfo",@"bundleIdentifier",@"URL",@"url",@"identifier",@"sourceApplication",@"targetApplication"]){
            id v=MTV(ctx,k);if(v)MTLog(@"[HYBRID-CONTEXT] key=%@ value=%@ class=%@",k,v,NSStringFromClass([v class]));
        }
        static BOOL cd=NO;if(!cd){cd=YES;unsigned int mc2=0;Method*mm=class_copyMethodList([ctx class],&mc2);
            for(unsigned int j=0;j<mc2;j++){NSString*n=NSStringFromSelector(method_getName(mm[j]));NSString*l=n.lowercaseString;
                if([l containsString:@"application"]||[l containsString:@"bundle"]||[l containsString:@"identifier"]||[l containsString:@"url"]||[l hasPrefix:@"set"])
                    MTLog(@"[HYBRID-CONTEXT-METHOD] -%@ types=%s",n,method_getTypeEncoding(mm[j]));}free(mm);}
    }
    for(NSString *k in @[@"application",@"applicationInfo",@"launchInfo",@"bundleIdentifier",@"URL",@"url",@"source",@"type",@"name",@"payload",@"userInfo",@"value",@"identifier"]){
        id v=MTV(event,k);if(v)MTLog(@"[HYBRID-OPEN] key=%@ value=%@ class=%@",k,v,NSStringFromClass([v class]));
    }
    static BOOL dumped=NO;if(!dumped){dumped=YES;
        unsigned int ic=0;Ivar *ivs=class_copyIvarList([event class],&ic);
        BOOL hasObjectPayload=NO, hasWritableTarget=NO;
        for(unsigned int i=0;i<ic;i++){
            const char*n=ivar_getName(ivs[i]);const char*t=ivar_getTypeEncoding(ivs[i]);id v=nil;
            /* raw object_getIvar disabled after v6 crash */
            if(t&&t[0]=='@'&&v)hasObjectPayload=YES;
            NSString *in=n?[NSString stringWithUTF8String:n]:@"";
            NSString *il=in.lowercaseString;
            if([il containsString:@"application"]||[il containsString:@"bundle"]||[il containsString:@"identifier"]||[il containsString:@"payload"]||[il containsString:@"info"])hasWritableTarget=YES;
            MTLog(@"[HYBRID-EVENT-IVAR] %s type=%s value=%@ class=%@",n?:"?",t?:"?",v,NSStringFromClass([v class]));
        }free(ivs);
        unsigned int mc=0;Method *ms=class_copyMethodList([event class],&mc);
        static BOOL loggedMethods=NO;if(loggedMethods){free(ms);mc=0;}else loggedMethods=YES; for(unsigned int i=0;i<mc;i++){NSString*n=NSStringFromSelector(method_getName(ms[i]));NSString*l=n.lowercaseString;
            if([l containsString:@"application"]||[l containsString:@"bundle"]||[l containsString:@"payload"]||[l containsString:@"event"]||[l containsString:@"identifier"]||[l containsString:@"value"]||[l containsString:@"info"]||[l hasPrefix:@"set"])
                MTLog(@"[HYBRID-EVENT-METHOD] -%@ types=%s",n,method_getTypeEncoding(ms[i]));}free(ms);
        MTLog(@"[HYBRID-DUAL] A(native)=TRUE event continues unchanged");
        MTLog(@"[HYBRID-DUAL] B(retarget-candidate)=%@ objectPayload=%d writableNameCandidate=%d",
              (hasObjectPayload&&hasWritableTarget)?@"TRUE":@"FALSE",hasObjectPayload,hasWritableTarget);
    }
    %orig;
}
%end
%hook DBApplicationSceneViewController
- (void)foregroundSceneWithSettings:(id)settings completion:(id)completion{
 NSString*sid=MTV((id)self,@"sceneID"); MTProbeControllerEnvironment((id)self,sid); NSString*b=MTBundleFromSID(sid);
 if(b&&[settings isKindOfClass:NSDictionary.class]&&settings[@"DBActivationSettingLaunchSource"]){
   gYTController=(id)self;gYTSettings=[settings copy];MTLog(@"[CAPTURE] youtube sid=%@ controller=%@ source=%@",sid,NSStringFromClass(object_getClass((id)self)),settings[@"DBActivationSettingLaunchSource"]);
    id env=gMTHybridDashboard; id ai=nil; @try{ai=((id(*)(id,SEL,id))objc_msgSend)(env,NSSelectorFromString(@"applicationInfoForScene:"),MTV((id)self,@"scene"));}@catch(__unused NSException*e){} MTLog(@"[FG-B] dashboard=%@ appInfoForScene=%@",env,ai);
    static int renderLogs=0; BOOL logRender=(renderLogs++<3); if(logRender) MTLog(@"[RENDER-B] sceneID=%@ controller=%@ appInfo=%@",sid,NSStringFromClass([(id)self class]),ai);
    id sc=MTV((id)self,@"scene"); id st=MTV(sc,@"settings"); id cp=MTV(sc,@"clientProcess");
    if(logRender) MTLog(@"[RENDER-B] scene=%@ clientProcess=%@ settings=%@",sc,cp,st);
    id pv=nil; @try{pv=((id(*)(id,SEL,id))objc_msgSend)((id)self,NSSelectorFromString(@"presentationViewWithIdentifier:"),@"com.sushibta.minita.youtube");}@catch(NSException*e){MTLog(@"[RENDER-B] presentation error=%@",e.reason);}
    if(logRender) MTLog(@"[RENDER-B] presentation=%@ class=%@ window=%@ subviews=%lu",pv,NSStringFromClass([pv class]),[pv window],(unsigned long)[pv subviews].count); dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.25*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ MTHostYouTube(); });
   static BOOL mtDidDumpScene=NO; if(!mtDidDumpScene){mtDidDumpScene=YES;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{MTDumpSceneInternals((id)self);});}
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{MTHostYouTube();});
 }
 %orig;
}
%end
%ctor{@autoreleasepool{
    NSString *bundle=NSBundle.mainBundle.bundleIdentifier?:@"";
    if([bundle isEqualToString:@"com.google.ios.youtube"]){
        MTLog(@"=== MINITA HYBRID APP === bundle=%@ process=%@",bundle,NSProcessInfo.processInfo.processName);
        MTHybridInstallAppBridge();
        return;
    }
    if(![bundle isEqualToString:@"com.apple.CarPlayApp"]) return;
    [[NSFileManager defaultManager]removeItemAtPath:MTLogPath error:nil];
    MTLog(@"=== MINITA HYBRID CARPLAY === bundle=%@ process=%@",bundle,NSProcessInfo.processInfo.processName);
    MTHybridInstallAdmission();
    MTHybridInstallWorkspaceCapture();
    MTLog(@"[HYBRID] workspace mode installed; waiting for CarPlay UI ready");
}}
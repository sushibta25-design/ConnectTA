#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const MTLogPath=@"/var/mobile/MiniTa.txt";
static id gYTController=nil; static NSDictionary *gYTSettings=nil; static UIWindow *gHostWindow=nil; static UIView *gPresentation=nil;
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
%hook DBApplicationSceneViewController
- (void)foregroundSceneWithSettings:(id)settings completion:(id)completion{
 NSString*sid=MTV((id)self,@"sceneID");NSString*b=MTBundleFromSID(sid);
 if(b&&[settings isKindOfClass:NSDictionary.class]&&settings[@"DBActivationSettingLaunchSource"]){
   gYTController=(id)self;gYTSettings=[settings copy];MTLog(@"[CAPTURE] youtube sid=%@ controller=%@ source=%@",sid,NSStringFromClass(object_getClass((id)self)),settings[@"DBActivationSettingLaunchSource"]);
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{MTHostYouTube();});
 }
 %orig;
}
%end
%ctor{@autoreleasepool{[[NSFileManager defaultManager]removeItemAtPath:MTLogPath error:nil];MTLog(@"=== MINITA PHASE2 YOUTUBE HOST === bundle=%@ process=%@",NSBundle.mainBundle.bundleIdentifier,NSProcessInfo.processInfo.processName);}}

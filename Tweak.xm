#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSString * const MTLogPath=@"/var/mobile/MiniTaProbe.txt";
static void MTLog(NSString *fmt, ...){
    va_list a;va_start(a,fmt);NSString *m=[[NSString alloc]initWithFormat:fmt arguments:a];va_end(a);
    NSString *line=[NSString stringWithFormat:@"%@\n",m];
    NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:MTLogPath];
    if(!h){[line writeToFile:MTLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];return;}
    [h seekToEndOfFile];[h writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];[h closeFile];
}
static void MTDump(NSString *why){
    UIApplication *app=UIApplication.sharedApplication;
    MTLog(@"[DUMP] %@ bundle=%@ process=%@ screens=%lu scenes=%lu",why,NSBundle.mainBundle.bundleIdentifier,NSProcessInfo.processInfo.processName,(unsigned long)UIScreen.screens.count,(unsigned long)app.connectedScenes.count);
    NSInteger i=0;for(UIScreen *s in UIScreen.screens)MTLog(@"[SCREEN %ld] bounds=%@ native=%@ scale=%.2f",(long)i++,NSStringFromCGRect(s.bounds),NSStringFromCGRect(s.nativeBounds),s.scale);
    for(UIScene *sc in app.connectedScenes)MTLog(@"[SCENE] class=%@ role=%@ state=%ld id=%@",NSStringFromClass(sc.class),sc.session.role,(long)sc.activationState,sc.session.persistentIdentifier);
}
%hook UIWindow
- (instancetype)initWithFrame:(CGRect)frame{
    self=%orig;
    MTLog(@"[WINDOW] init frame=%@",NSStringFromCGRect(frame));
    return self;
}
- (void)setScreen:(UIScreen *)screen{
    MTLog(@"[WINDOW] setScreen=%@ bounds=%@",screen,NSStringFromCGRect(screen.bounds));%orig;
}
%end
%ctor{
    @autoreleasepool{
        [[NSFileManager defaultManager] removeItemAtPath:MTLogPath error:nil];
        MTLog(@"=== MINITA PHASE1 EXTERNAL DISPLAY PROBE ===");
        dispatch_async(dispatch_get_main_queue(),^{
            MTDump(@"START");
            NSNotificationCenter *nc=NSNotificationCenter.defaultCenter;
            [nc addObserverForName:UIScreenDidConnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification*n){MTLog(@"[EVENT] UIScreenDidConnect object=%@",n.object);MTDump(@"SCREEN_CONNECT");}];
            [nc addObserverForName:UIScreenDidDisconnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification*n){MTLog(@"[EVENT] UIScreenDidDisconnect object=%@",n.object);MTDump(@"SCREEN_DISCONNECT");}];
            // Phase 1A: harmless synthetic notification. This does NOT create a real UIScreen.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                MTLog(@"[TEST] posting synthetic UIScreenDidConnectNotification mainScreen");
                [nc postNotificationName:UIScreenDidConnectNotification object:UIScreen.mainScreen];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{MTDump(@"AFTER_SYNTHETIC");});
            });
        });
    }
}

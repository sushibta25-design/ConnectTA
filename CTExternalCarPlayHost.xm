#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <notify.h>
#import "CTConfig.h"
#import "CTExternalCarPlayWindow.h"

static NSString *const CTHostLaunchNotification=@"com.sushibta.connectta.host.launch";
static NSString *const CTHostBuild=@"0.4.6-host-prototype";
static CTExternalCarPlayWindow *gCTExternalWindow=nil;
static NSString *gCTExternalBundle=nil;
static int gCTHostLaunchToken=-1;
static int gCTPreferencesToken=-1;

static BOOL CTHostEnabled(NSString *bundle) { return [bundle isKindOfClass:NSString.class] && [CTReadEnabledApps() containsObject:bundle]; }
static void CTHostLog(NSString *message) {
    NSString *line=[NSString stringWithFormat:@"[ConnectTA-%@ pid=%d] %@\n",CTHostBuild,NSProcessInfo.processInfo.processIdentifier,message];
    NSData *data=[line dataUsingEncoding:NSUTF8StringEncoding];
    @synchronized(NSFileManager.class) {
        NSFileHandle *file=[NSFileHandle fileHandleForWritingAtPath:@"/var/mobile/ConnectTA.txt"];
        if (!file) { [data writeToFile:@"/var/mobile/ConnectTA.txt" atomically:YES]; return; }
        @try { [file seekToEndOfFile]; [file writeData:data]; } @catch (__unused NSException *exception) {}
        [file closeFile];
    }
}
static void CTHostClose(void) {
    if (gCTExternalWindow) [gCTExternalWindow dismiss];
    CTHostLog([NSString stringWithFormat:@"host closed bundle=%@",gCTExternalBundle?:@"(none)"]);
    gCTExternalWindow=nil;
    gCTExternalBundle=nil;
}
static void CTHostLaunch(NSString *bundle) {
    if (![bundle isKindOfClass:NSString.class] || ![bundle isEqualToString:@"com.netflix.Netflix"] || !CTHostEnabled(bundle)) {
        CTHostLog([NSString stringWithFormat:@"host launch rejected bundle=%@ enabled=0",bundle]);
        return;
    }
    CTHostClose();
    CTHostLog([NSString stringWithFormat:@"host launch requested bundle=%@",bundle]);
    CTExternalCarPlayWindow *candidate=[[CTExternalCarPlayWindow alloc] initWithBundleIdentifier:bundle];
    if (!candidate) { CTHostLog([NSString stringWithFormat:@"host create failed bundle=%@",bundle]); return; }
    gCTExternalWindow=candidate;
    gCTExternalBundle=[bundle copy];
}
static void CTInstallSpringBoardObservers(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        notify_register_dispatch(CTHostLaunchNotification.UTF8String,&gCTHostLaunchToken,dispatch_get_main_queue(),^(__unused int changedToken) {
            CTHostLaunch(@"com.netflix.Netflix");
        });
        [[NSNotificationCenter defaultCenter] addObserverForName:@"CarPlayIsConnectedDidChange" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
            id device=((id(*)(id,SEL))objc_msgSend)(objc_getClass("AVExternalDevice"),NSSelectorFromString(@"currentCarPlayExternalDevice"));
            if (!device) CTHostClose();
        }];
        notify_register_dispatch(CTPreferencesChanged,&gCTPreferencesToken,dispatch_get_main_queue(),^(__unused int changedToken) {
            if (gCTExternalBundle && !CTHostEnabled(gCTExternalBundle)) CTHostClose();
        });
    });
}

%group CTCarPlayLaunch
%hook CARApplicationLaunchInfo
+ (id)launchInfoForApplication:(id)application withActivationSettings:(id)settings {
    NSString *bundle=nil;
    @try { bundle=[application valueForKey:@"bundleIdentifier"]; } @catch (__unused NSException *exception) {}
    // Intercept only Netflix when its ConnectTA toggle is ON.
    if ([bundle isEqualToString:@"com.netflix.Netflix"] && CTHostEnabled(bundle)) {
        CTHostLog([NSString stringWithFormat:@"intercept enabled app=%@",bundle]);
        notify_post(CTHostLaunchNotification.UTF8String);
        return nil;
    }
    return %orig;
}
%end
%end

%ctor {
    @autoreleasepool {
        NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
        if ([bundle isEqualToString:@"com.apple.CarPlayApp"]) %init(CTCarPlayLaunch);
        else if ([bundle isEqualToString:@"com.apple.springboard"]) CTInstallSpringBoardObservers();
    }
}

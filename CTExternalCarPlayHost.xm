#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <notify.h>
#import "CTConfig.h"
#import "CTExternalCarPlayWindow.h"

static NSString *const CTHostLaunchNotification=@"com.sushibta.connectta.netflix.host.launch";
static NSString *const CTHostBuild=@"0.4.8-netflix-isolated";
static NSString *const CTNetflixBundle=@"com.netflix.Netflix";
static CTExternalCarPlayWindow *gCTExternalWindow=nil;
static NSString *gCTExternalBundle=nil;
static int gCTHostLaunchToken=-1;
static int gCTPreferencesToken=-1;
static BOOL gCTHostObserversInstalled=NO;

static BOOL CTNetflixEnabled(void) {
    return [CTReadEnabledApps() containsObject:CTNetflixBundle];
}
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
    gCTExternalWindow=nil;
    gCTExternalBundle=nil;
    CTHostLog(@"Netflix host closed");
}
static void CTHostLaunch(void) {
    if (!CTNetflixEnabled()) return;
    CTHostClose();
    CTHostLog(@"Netflix external host requested");
    CTExternalCarPlayWindow *candidate=[[CTExternalCarPlayWindow alloc] initWithBundleIdentifier:CTNetflixBundle];
    if (!candidate) { CTHostLog(@"Netflix host create failed"); return; }
    gCTExternalWindow=candidate;
    gCTExternalBundle=[CTNetflixBundle copy];
}
static void CTInstallSpringBoardObservers(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gCTHostObserversInstalled) return;
        gCTHostObserversInstalled=YES;
        notify_register_dispatch(CTHostLaunchNotification.UTF8String,&gCTHostLaunchToken,dispatch_get_main_queue(),^(__unused int changedToken) {
            CTHostLaunch();
        });
        notify_register_dispatch(CTPreferencesChanged,&gCTPreferencesToken,dispatch_get_main_queue(),^(__unused int changedToken) {
            if (!CTNetflixEnabled()) CTHostClose();
        });
        [[NSNotificationCenter defaultCenter] addObserverForName:@"CarPlayIsConnectedDidChange" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
            id device=((id(*)(id,SEL))objc_msgSend)(objc_getClass("AVExternalDevice"),NSSelectorFromString(@"currentCarPlayExternalDevice"));
            if (!device) CTHostClose();
        }];
    });
}

%group CTCarPlayLaunch
%hook CARApplicationLaunchInfo
+ (id)launchInfoForApplication:(id)application withActivationSettings:(id)settings {
    NSString *bundle=nil;
    @try { bundle=[application valueForKey:@"bundleIdentifier"]; } @catch (__unused NSException *exception) {}
    if ([bundle isEqualToString:CTNetflixBundle] && CTNetflixEnabled()) {
        CTHostLog(@"intercept enabled Netflix launch");
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
        else if ([bundle isEqualToString:@"com.apple.springboard"] && CTNetflixEnabled()) CTInstallSpringBoardObservers();
    }
}

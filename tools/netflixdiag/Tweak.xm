#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <sys/utsname.h>

static NSString *const NDLogPath=@"/var/mobile/NetflixDiag.log";
static const unsigned long long NDMaxLogSize=524288;

static void NDLog(NSString *format, ...) {
    va_list args;
    va_start(args,format);
    NSString *message=[[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSString *line=[NSString stringWithFormat:@"[NetflixDiag %@ pid=%d] %@\n",NSProcessInfo.processInfo.systemUptime,NSProcessInfo.processInfo.processIdentifier,message];
    NSData *data=[line dataUsingEncoding:NSUTF8StringEncoding];
    @synchronized(NSFileManager.class) {
        NSFileHandle *file=[NSFileHandle fileHandleForWritingAtPath:NDLogPath];
        if (!file) { [data writeToFile:NDLogPath atomically:YES]; return; }
        @try {
            unsigned long long end=[file seekToEndOfFile];
            if (end>NDMaxLogSize) { [file truncateFileAtOffset:0]; [file seekToFileOffset:0]; }
            [file writeData:data];
        } @catch (__unused NSException *exception) {}
        [file closeFile];
    }
}

static void NDScreenSnapshot(NSString *reason) {
    NSArray<UIScreen *> *screens=UIScreen.screens;
    NDLog(@"SCREEN reason=%@ count=%lu",reason,(unsigned long)screens.count);
    for (NSUInteger i=0;i<screens.count;i++) {
        UIScreen *screen=screens[i];
        CGSize mode=screen.currentMode.size;
        NDLog(@"DISPLAY index=%lu main=%d captured=%d mirrored=%d bounds=%@ mode=%.0fx%.0f scale=%.2f",
              (unsigned long)i,screen==UIScreen.mainScreen,screen.isCaptured,screen.mirroredScreen!=nil,
              NSStringFromCGRect(screen.bounds),mode.width,mode.height,screen.scale);
    }
    NSSet<UIScene *> *scenes=UIApplication.sharedApplication.connectedScenes;
    for (UIScene *scene in scenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *windowScene=(UIWindowScene *)scene;
        NSUInteger screenIndex=[screens indexOfObject:windowScene.screen];
        NDLog(@"SCENE state=%ld screenIndex=%lu bounds=%@",
              (long)scene.activationState,(unsigned long)screenIndex,NSStringFromCGRect(windowScene.coordinateSpace.bounds));
    }
}

static void NDAudioSnapshot(NSString *reason) {
    AVAudioSessionRouteDescription *route=AVAudioSession.sharedInstance.currentRoute;
    NSMutableArray *outputs=[NSMutableArray array];
    for (AVAudioSessionPortDescription *port in route.outputs) {
        [outputs addObject:[NSString stringWithFormat:@"%@/%@",port.portType?:@"?",port.portName?:@"?"]];
    }
    NDLog(@"AUDIO reason=%@ outputs=%@",reason,outputs);
}

static NSString *NDMachine(void) {
    struct utsname value;
    if (uname(&value)==0) return [NSString stringWithUTF8String:value.machine]?:@"unknown";
    return @"unknown";
}

static void NDInstallObservers(void) {
    NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
    [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(__unused NSNotification *note) {
        NDLog(@"APP became-active");
        NDScreenSnapshot(@"became-active");
        NDAudioSnapshot(@"became-active");
    }];
    [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:nil usingBlock:^(__unused NSNotification *note) {
        NDLog(@"APP will-resign-active");
    }];
    [center addObserverForName:UIScreenDidConnectNotification object:nil queue:nil usingBlock:^(__unused NSNotification *note) {
        NDScreenSnapshot(@"screen-connected");
    }];
    [center addObserverForName:UIScreenDidDisconnectNotification object:nil queue:nil usingBlock:^(__unused NSNotification *note) {
        NDScreenSnapshot(@"screen-disconnected");
    }];
    [center addObserverForName:UIScreenCapturedDidChangeNotification object:nil queue:nil usingBlock:^(__unused NSNotification *note) {
        NDScreenSnapshot(@"capture-state-changed");
    }];
    [center addObserverForName:AVAudioSessionRouteChangeNotification object:nil queue:nil usingBlock:^(__unused NSNotification *note) {
        NDAudioSnapshot(@"route-changed");
    }];
    [center addObserverForName:AVPlayerItemFailedToPlayToEndTimeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        NSError *error=note.userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey];
        if (![error isKindOfClass:NSError.class] && [note.object isKindOfClass:AVPlayerItem.class]) {
            error=((AVPlayerItem *)note.object).error;
        }
        NDLog(@"PLAYER failed-to-end domain=%@ code=%ld",error.domain?:@"?",(long)error.code);
    }];
    [center addObserverForName:AVPlayerItemPlaybackStalledNotification object:nil queue:nil usingBlock:^(__unused NSNotification *note) {
        NDLog(@"PLAYER playback-stalled");
    }];
    [center addObserverForName:AVPlayerItemNewErrorLogEntryNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        AVPlayerItem *item=[note.object isKindOfClass:AVPlayerItem.class]?note.object:nil;
        AVPlayerItemErrorLogEvent *event=item.errorLog.events.lastObject;
        NDLog(@"PLAYER error-log entries=%lu domain=%@ status=%ld",
              (unsigned long)item.errorLog.events.count,event.errorDomain?:@"?",(long)event.errorStatusCode);
    }];
}

%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.netflix.Netflix"]) return;
        NDLog(@"START iOS=%@ device=%@",UIDevice.currentDevice.systemVersion,NDMachine());
        NDScreenSnapshot(@"process-start");
        NDAudioSnapshot(@"process-start");
        NDInstallObservers();
    }
}

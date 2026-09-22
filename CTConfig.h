#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <notify.h>

#define CTPreferencesDomain CFSTR("com.sushibta.connectta")
#define CTPreferencesChanged "com.sushibta.connectta.preferences-changed"
#define CTConfigReady "com.sushibta.connectta.config.ready"

static inline NSString *CTAppStateName(NSString *identifier) {
    return [@"com.sushibta.connectta.config.app." stringByAppendingString:identifier];
}
// Keep publisher registrations alive; notify state is not a persistent preferences store.
// SpringBoard recreates the snapshot on every respring. Settings also publishes on save.
static inline void CTPublishEnabledApps(NSSet<NSString *> *apps) {
    static NSMutableDictionary<NSString *,NSNumber *> *tokens;
    static int readyToken=-1;
    if(!tokens)tokens=[NSMutableDictionary dictionary];
    if(readyToken<0 && notify_register_check(CTConfigReady,&readyToken)!=NOTIFY_STATUS_OK){readyToken=-1;return;}
    notify_set_state(readyToken,0);
    for(NSString *identifier in tokens)notify_set_state(tokens[identifier].intValue,0);
    for(NSString *identifier in apps){
        NSNumber *existing=tokens[identifier];
        int token=existing?existing.intValue:-1;
        if(token<0 && notify_register_check(CTAppStateName(identifier).UTF8String,&token)!=NOTIFY_STATUS_OK)continue;
        tokens[identifier]=@(token);
        notify_set_state(token,1);
    }
    notify_set_state(readyToken,1);
}
// Apps can read Darwin notify state without reading another app's preference domain.
static inline BOOL CTReadPublishedEnabled(NSString *identifier,BOOL fallback) {
    int ready=-1,token=-1;
    uint64_t available=0,enabled=0;
    if(notify_register_check(CTConfigReady,&ready)!=NOTIFY_STATUS_OK)return fallback;
    uint32_t result=notify_get_state(ready,&available);
    if(result!=NOTIFY_STATUS_OK || available!=1){notify_cancel(ready);return fallback;}
    if(notify_register_check(CTAppStateName(identifier).UTF8String,&token)!=NOTIFY_STATUS_OK){notify_cancel(ready);return fallback;}
    result=notify_get_state(token,&enabled);
    notify_cancel(token);notify_cancel(ready);
    return result==NOTIFY_STATUS_OK?enabled==1:fallback;
}

static inline BOOL CTEligibleIdentifier(id identifier) {
    return [identifier isKindOfClass:NSString.class] && [identifier length] > 0 &&
        ![identifier hasPrefix:@"com.apple."];
}
static inline NSSet<NSString *> *CTReadEnabledApps(void) {
    CFPreferencesSynchronize(CTPreferencesDomain,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
    id stored=CFBridgingRelease(CFPreferencesCopyValue(CFSTR("EnabledApps"),CTPreferencesDomain,
        kCFPreferencesCurrentUser,kCFPreferencesAnyHost));
    // Compatibility only: retain the old selection until ConnectTA settings are saved.
    if(!stored){
        CFStringRef legacy=CFSTR("com.sushibta.minita");
        CFPreferencesSynchronize(legacy,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
        stored=CFBridgingRelease(CFPreferencesCopyValue(CFSTR("EnabledApps"),legacy,
            kCFPreferencesCurrentUser,kCFPreferencesAnyHost));
    }
    // Preserve the working YouTube behavior on first install; an empty array means OFF.
    if(![stored isKindOfClass:NSArray.class])return [NSSet setWithObject:@"com.google.ios.youtube"];
    NSMutableSet *result=[NSMutableSet set];
    for(id identifier in stored)if(CTEligibleIdentifier(identifier))[result addObject:identifier];
    return [result copy];
}


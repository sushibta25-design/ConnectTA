#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <notify.h>

#define MTPreferencesDomain CFSTR("com.sushibta.minita")
#define MTPreferencesChanged "com.sushibta.minita.preferences-changed"
#define MTConfigReady "com.sushibta.minita.config91.ready"

static inline NSString *MTAppStateName(NSString *identifier) {
    return [@"com.sushibta.minita.config91.app." stringByAppendingString:identifier];
}
// Keep publisher registrations alive; notify state is not a persistent preferences store.
// SpringBoard recreates the snapshot on every respring. Settings also publishes on save.
static inline void MTPublishEnabledApps(NSSet<NSString *> *apps) {
    static NSMutableDictionary<NSString *,NSNumber *> *tokens;
    static int readyToken=-1;
    if(!tokens)tokens=[NSMutableDictionary dictionary];
    if(readyToken<0 && notify_register_check(MTConfigReady,&readyToken)!=NOTIFY_STATUS_OK){readyToken=-1;return;}
    notify_set_state(readyToken,0);
    for(NSString *identifier in tokens)notify_set_state(tokens[identifier].intValue,0);
    for(NSString *identifier in apps){
        NSNumber *existing=tokens[identifier];
        int token=existing?existing.intValue:-1;
        if(token<0 && notify_register_check(MTAppStateName(identifier).UTF8String,&token)!=NOTIFY_STATUS_OK)continue;
        tokens[identifier]=@(token);
        notify_set_state(token,1);
    }
    notify_set_state(readyToken,1);
}
// Apps can read Darwin notify state without reading another app's preference domain.
static inline BOOL MTReadPublishedEnabled(NSString *identifier,BOOL fallback) {
    int ready=-1,token=-1;
    uint64_t available=0,enabled=0;
    if(notify_register_check(MTConfigReady,&ready)!=NOTIFY_STATUS_OK)return fallback;
    uint32_t result=notify_get_state(ready,&available);
    if(result!=NOTIFY_STATUS_OK || available!=1){notify_cancel(ready);return fallback;}
    if(notify_register_check(MTAppStateName(identifier).UTF8String,&token)!=NOTIFY_STATUS_OK){notify_cancel(ready);return fallback;}
    result=notify_get_state(token,&enabled);
    notify_cancel(token);notify_cancel(ready);
    return result==NOTIFY_STATUS_OK?enabled==1:fallback;
}

static inline BOOL MTEligibleIdentifier(id identifier) {
    return [identifier isKindOfClass:NSString.class] && [identifier length] > 0 &&
        ![identifier hasPrefix:@"com.apple."];
}
static inline NSSet<NSString *> *MTReadEnabledApps(void) {
    CFPreferencesSynchronize(MTPreferencesDomain,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
    id stored=CFBridgingRelease(CFPreferencesCopyValue(CFSTR("EnabledApps"),MTPreferencesDomain,
        kCFPreferencesCurrentUser,kCFPreferencesAnyHost));
    // Preserve the working YouTube behavior on first install; an empty array means OFF.
    if(![stored isKindOfClass:NSArray.class])return [NSSet setWithObject:@"com.google.ios.youtube"];
    NSMutableSet *result=[NSMutableSet set];
    for(id identifier in stored)if(MTEligibleIdentifier(identifier))[result addObject:identifier];
    return [result copy];
}

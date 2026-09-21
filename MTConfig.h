#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

#define MTPreferencesDomain CFSTR("com.sushibta.minita")
#define MTPreferencesChanged "com.sushibta.minita.preferences-changed"

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

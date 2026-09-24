#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <objc/message.h>
#import <notify.h>
#import "../CTConfig.h"

static id CTValue(id object,NSString *key){
    @try{return [object valueForKey:key];}@catch(__unused NSException *e){return nil;}
}
@interface CTRootListController : PSListController
@end
@implementation CTRootListController
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title=@"ConnectTA — App Bridge";
    [self reloadSpecifiers];
}
- (NSMutableArray *)specifiers {
    if(_specifiers)return _specifiers;
    NSMutableArray *items=[NSMutableArray array];
    PSSpecifier *intro=[PSSpecifier groupSpecifierWithName:@"ConnectTA 0.4.1 • Rootless"];
    [intro setProperty:@"ON thử đưa giao diện iPhone lên CarPlay; OFF giữ giao diện CarPlay gốc. Ngắt rồi kết nối lại CarPlay sau khi đổi. ConnectTA nhận thay đổi mà không cần respring. Tắt CarBridge cho cùng app. Chỉ dùng video khi xe đỗ." forKey:@"footerText"];
    [items addObject:intro];
    PSSpecifier *reset=[PSSpecifier preferenceSpecifierNamed:@"Tắt toàn bộ App Bridge" target:self set:NULL get:NULL detail:Nil cell:PSButtonCell edit:Nil];
    reset.buttonAction=@selector(disableAll);
    [items addObject:reset];
    NSMutableDictionary *apps=[NSMutableDictionary dictionary];
    @try {
        Class cls=NSClassFromString(@"LSApplicationWorkspace");
        SEL workspaceSelector=NSSelectorFromString(@"defaultWorkspace");
        SEL appsSelector=NSSelectorFromString(@"allApplications");
        id workspace=[cls respondsToSelector:workspaceSelector]?((id(*)(id,SEL))objc_msgSend)(cls,workspaceSelector):nil;
        NSArray *proxies=[workspace respondsToSelector:appsSelector]?((id(*)(id,SEL))objc_msgSend)(workspace,appsSelector):nil;
        for(id proxy in proxies){
            NSString *identifier=CTValue(proxy,@"bundleIdentifier");
            NSURL *url=CTValue(proxy,@"bundleURL");
            if(!CTEligibleIdentifier(identifier) || ![url isKindOfClass:NSURL.class] || ![url.pathExtension isEqualToString:@"app"])continue;
            if([CTValue(proxy,@"isPlaceholder") boolValue])continue;
            NSString *name=CTValue(proxy,@"localizedName");
            apps[identifier]=[name isKindOfClass:NSString.class]?name:identifier;
        }
    }@catch(__unused NSException *e){}
    // Retain switches for stored selections even if an app was uninstalled.
    for(NSString *identifier in CTReadEnabledApps())if(!apps[identifier])apps[identifier]=[identifier stringByAppendingString:@" (chưa tìm thấy)"];
    PSSpecifier *group=[PSSpecifier groupSpecifierWithName:@"Ứng dụng"];
    [group setProperty:@"Maps/Vietmap nên để OFF để dùng giao diện dẫn đường CarPlay gốc; ON thử giao diện iPhone. Log vừa kiểm tra cho thấy hai app này chưa kết nối được scene CarPlay. Zalo vẫn có thể yêu cầu mở trên iPhone do cách Zalo hoạt động. YouTube giữ bố cục tablet; app khác dùng kích thước vùng CarPlay. Mức tương thích tùy app." forKey:@"footerText"];
    [items addObject:group];
    NSArray *identifiers=[apps.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a,NSString *b){return [apps[a] localizedCaseInsensitiveCompare:apps[b]];}];
    for(NSString *identifier in identifiers){
        PSSpecifier *item=[PSSpecifier preferenceSpecifierNamed:apps[identifier] target:self set:@selector(setEnabled:specifier:) get:@selector(isEnabled:) detail:Nil cell:PSSwitchCell edit:Nil];
        [item setProperty:identifier forKey:@"bundleID"];
        [items addObject:item];
    }
    if(!identifiers.count){
        PSSpecifier *empty=[PSSpecifier groupSpecifierWithName:@"Không đọc được danh sách app"];
        [empty setProperty:@"Thử mở lại Cài đặt sau respring. Không cần nhập bundle ID." forKey:@"footerText"];
        [items addObject:empty];
    }
    _specifiers=items;
    return _specifiers;
}
- (id)isEnabled:(PSSpecifier *)specifier {
    return @([CTReadEnabledApps() containsObject:[specifier propertyForKey:@"bundleID"]]);
}
- (BOOL)saveApps:(NSSet *)apps {
    NSArray *identifiers=[[apps allObjects] sortedArrayUsingSelector:@selector(compare:)];
    CFPreferencesSetValue(CFSTR("EnabledApps"),(__bridge CFArrayRef)identifiers,CTPreferencesDomain,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
    BOOL saved=CFPreferencesSynchronize(CTPreferencesDomain,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
    if(saved){CTPublishEnabledApps(apps);notify_post(CTPreferencesChanged);}
    else {
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Chưa lưu được" message:@"Không ghi được cài đặt ConnectTA. Hãy thử lại." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
    return saved;
}
- (void)setEnabled:(id)value specifier:(PSSpecifier *)specifier {
    NSString *identifier=[specifier propertyForKey:@"bundleID"];
    if(!CTEligibleIdentifier(identifier))return;
    NSMutableSet *apps=[CTReadEnabledApps() mutableCopy];
    if([value boolValue])[apps addObject:identifier];else [apps removeObject:identifier];
    [self saveApps:apps];
    [self reloadSpecifier:specifier];
}
- (void)disableAll {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Tắt ConnectTA cho mọi app?" message:@"Sau khi tắt, ngắt rồi kết nối lại CarPlay để dùng lại giao diện gốc." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Tắt toàn bộ" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action){[self saveApps:[NSSet set]];[self reloadSpecifiers];}]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

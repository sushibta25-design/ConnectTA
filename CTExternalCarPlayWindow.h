#import <UIKit/UIKit.h>

@interface CTExternalCarPlayWindow : NSObject
- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier;
- (void)dismiss;
@end

/**
 * File              : YandexConnect.h
 * Sign-in screen: Yandex OAuth device flow with a QR code for ya.ru/device
 * and the confirmation code.
 */

#import <UIKit/UIKit.h>

extern NSString * const YandexTokenDidUpdateNotification;

@interface YandexConnect : UIViewController

- (id)initWithFrame:(CGRect)frame;
- (void)beginDeviceAuthorization;

+ (void)refreshSavedTokenIfNeeded;
+ (void)signOut;

@end

// vim:ft=objc

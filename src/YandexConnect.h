/**
 * File              : YandexConnect.h
 * Patched for iYMLegacy legacy iOS build.
 */

#import <UIKit/UIKit.h>

extern NSString * const YandexTokenDidUpdateNotification;

@interface YandexConnect : UIViewController <UIWebViewDelegate>
{
}

@property (strong) UIWebView *webView;
@property (strong) UIActivityIndicatorView *spinner;
@property (strong) UIAlertView *authorizationAlert;
@property CGRect frame;

- (id)initWithFrame:(CGRect)frame;
- (void)beginDeviceAuthorization;

+ (void)refreshSavedTokenIfNeeded;

@end

// vim:ft=objc

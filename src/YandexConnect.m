/**
 * Patched Yandex OAuth connector for iYMLegacy.
 */

#import "YandexConnect.h"
#include "AppDelegate.h"
#include "UIKit/UIKit.h"
#include "Foundation/Foundation.h"
#include <stdio.h>
#include <time.h>
#include <CoreFoundation/CoreFoundation.h>
#include "../cYandexMusic/cYandexOAuth.h"
#include "../cYandexMusic/cYandexMusic.h"

#include "iYMLegacyConfig.h"
#define CLIENTID IYMLEGACY_YANDEX_CLIENT_ID
#define CLIENTSECRET IYMLEGACY_YANDEX_CLIENT_SECRET

NSString * const YandexTokenDidUpdateNotification = @"YandexTokenDidUpdateNotification";

static NSString *device_identifier(void)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *deviceID = [defaults stringForKey:@"yandex_device_id"];
    if (deviceID && [deviceID length])
        return deviceID;

    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    if (!uuid)
        return @"iYMLegacy";
    CFStringRef string = CFUUIDCreateString(kCFAllocatorDefault, uuid);
    NSString *result = (__bridge_transfer NSString *)string;
    CFRelease(uuid);
    if (!result)
        result = @"iYMLegacy";
    [defaults setObject:result forKey:@"yandex_device_id"];
    [defaults synchronize];
    return result;
}

static void save_oauth_tokens(const char *access_token,
                              int expires_in,
                              const char *refresh_token)
{
    if (!access_token || !*access_token)
        return;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:[NSString stringWithUTF8String:access_token]
                 forKey:@"token"];

    if (refresh_token && *refresh_token) {
        [defaults setValue:[NSString stringWithUTF8String:refresh_token]
                     forKey:@"refresh_token"];
    }

    if (expires_in > 0) {
        NSTimeInterval expires_at = [[NSDate date] timeIntervalSince1970] + expires_in;
        [defaults setDouble:expires_at forKey:@"token_expires_at"];
    }

    [defaults synchronize];
}

static void notify_token_updated(void)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:YandexTokenDidUpdateNotification object:nil];
    });
}

static void clear_saved_tokens(void)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"token"];
    [defaults removeObjectForKey:@"refresh_token"];
    [defaults removeObjectForKey:@"token_expires_at"];
    [defaults removeObjectForKey:@"uid"];
    [defaults synchronize];
}

@implementation YandexConnect

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super init])) {
        self.frame = frame;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];

    self.spinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0,
                                      self.view.bounds.size.height / 2.0);
    [self.view addSubview:self.spinner];
    [self.spinner startAnimating];

    /* The legacy UIWebView is intentionally not used for device flow. */
    [self beginDeviceAuthorization];
}

- (void)beginDeviceAuthorization {
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    [queue addOperationWithBlock:^{
        NSString *deviceID = device_identifier();
        c_yandex_oauth_code_from_user(
            CLIENTID,
            [deviceID UTF8String],
            [[UIDevice currentDevice].name UTF8String],
            (__bridge void *)self,
            code_callback);
    }];
}

static void refresh_saved_token_callback(
    void *user_data,
    const char *access_token,
    int expires_in,
    const char *new_refresh_token,
    const char *error)
{
    (void)user_data;
    if (error || !access_token) {
        if (error)
            NSLog(@"Yandex OAuth refresh failed: %s", error);
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"token"];
        [defaults removeObjectForKey:@"refresh_token"];
        [defaults removeObjectForKey:@"token_expires_at"];
        [defaults synchronize];
        notify_token_updated();
        return;
    }
    save_oauth_tokens(access_token, expires_in, new_refresh_token);
    notify_token_updated();
}


static void music_auth_validation_callback(
    void *user_data,
    long uid,
    const char *error)
{
    YandexConnect *self = (__bridge YandexConnect *)user_data;

    if (error || uid <= 0) {
        NSString *message = error
            ? [NSString stringWithUTF8String:error]
            : @"Yandex Music returned no account UID";
        clear_saved_tokens();
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            if (self.authorizationAlert) { [self.authorizationAlert dismissWithClickedButtonIndex:-1 animated:NO]; }
            self.authorizationAlert = nil;
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate showMessage:[NSString stringWithFormat:@"Yandex Music API: %@", message]];
        });
        return;
    }

    [[NSUserDefaults standardUserDefaults] setInteger:uid forKey:@"uid"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    notify_token_updated();

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.authorizationAlert) {
            [self.authorizationAlert dismissWithClickedButtonIndex:-1 animated:NO];
            self.authorizationAlert = nil;
        }
        [self.spinner stopAnimating];
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate showMessage:@"connected!"];
        [self dismissViewControllerAnimated:YES completion:nil];
    });
}

static int token_callback(
    void *user_data,
    const char *access_token,
    int expires_in,
    const char *refresh_token,
    const char *error)
{
    YandexConnect *self = (__bridge YandexConnect *)user_data;
    if (error) {
        NSString *message = [NSString stringWithUTF8String:error];
        dispatch_async(dispatch_get_main_queue(), ^{
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate showMessage:
                [NSString stringWithFormat:@"Yandex OAuth token exchange failed: %@", message]];
            [self.spinner stopAnimating];
        });
        return 0;
    }

    if (access_token) {
        save_oauth_tokens(access_token, expires_in, refresh_token);

        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 1;
        NSString *tokenCopy = [[NSString alloc] initWithUTF8String:access_token];
        [queue addOperationWithBlock:^{
            c_yandex_music_check_auth(
                [tokenCopy UTF8String],
                (__bridge void *)self,
                music_auth_validation_callback);
        }];
    }
    return 0;
}

static int code_callback(
    void *user_data,
    const char *device_code,
    const char *user_code,
    const char *verification_url,
    int interval,
    int expires_in,
    const char *error)
{
    YandexConnect *self = (__bridge YandexConnect *)user_data;

    if (error) {
        NSString *message = [NSString stringWithUTF8String:error];
        dispatch_async(dispatch_get_main_queue(), ^{
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate showMessage:message];
            [self.spinner stopAnimating];
        });
        return 0;
    }

    if (!device_code || !user_code || !verification_url)
        return 0;

    /* Copy every value before C JSON storage is released. */
    NSString *deviceCode = [NSString stringWithUTF8String:device_code];
    NSString *userCode = [NSString stringWithUTF8String:user_code];
    NSString *verificationURL = [NSString stringWithUTF8String:verification_url];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.authorizationAlert) {
            [self.authorizationAlert dismissWithClickedButtonIndex:-1 animated:NO];
            self.authorizationAlert = nil;
        }

        [UIPasteboard generalPasteboard].string = userCode;

        NSString *message = [NSString stringWithFormat:
            @"Откройте %@\nвведите код: %@\n\nКод скопирован в буфер обмена.",
            verificationURL, userCode];

        self.authorizationAlert = [[UIAlertView alloc]
            initWithTitle:@"Яндекс"
            message:message
            delegate:nil
            cancelButtonTitle:@"Закрыть"
            otherButtonTitles:nil];

        [self.authorizationAlert show];

        /* Do not open Safari automatically. On iOS 6 this would always
         * launch the device's legacy Safari. The user can open the URL
         * manually on a current browser/device. */
    });

    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    [queue addOperationWithBlock:^{
        c_yandex_oauth_get_token_from_user(
            [deviceCode UTF8String],
            CLIENTID,
            CLIENTSECRET,
            interval,
            expires_in,
            (__bridge void *)self,
            token_callback);
    }];

    return 0;
}

+ (void)refreshSavedTokenIfNeeded
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *refresh = [defaults stringForKey:@"refresh_token"];
    if (!refresh || ![refresh length])
        return;

    NSTimeInterval expiresAt = [defaults doubleForKey:@"token_expires_at"];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (expiresAt > now + 60.0)
        return;

    NSString *refreshCopy = [refresh copy];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    [queue addOperationWithBlock:^{
        c_yandex_oauth_refresh_token(
            [refreshCopy UTF8String],
            CLIENTID,
            CLIENTSECRET,
            NULL,
            refresh_saved_token_callback);
    }];
}

- (void)webViewDidStartLoad:(UIWebView *)webView { }
- (void)webViewDidFinishLoad:(UIWebView *)webView { }

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [self.spinner stopAnimating];
    UIAlertView *alert = [[UIAlertView alloc]
        initWithTitle:@"error"
        message:error.localizedDescription
        delegate:self
        cancelButtonTitle:@"Закрыть"
        otherButtonTitles:nil];
    [alert show];
}

@end

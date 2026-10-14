/**
 * File              : YandexConnect.m
 * Sign-in screen: Yandex OAuth device flow with a QR code for ya.ru/device
 * and the confirmation code.
 */

#import "YandexConnect.h"
#import <QuartzCore/QuartzCore.h>
#include "AppDelegate.h"
#import "YMTheme.h"
#import "YMQRView.h"
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

/* One request for a code. Polling for an old code keeps running on its
 * own thread, so its callbacks must be told apart from the current one. */
@interface YMAuthAttempt : NSObject
@property (weak) YandexConnect *owner;
@property NSInteger generation;
@property BOOL cancelled;
@end
@implementation YMAuthAttempt
@end

@interface YandexConnect ()
@property (strong) UIScrollView *scroll;
@property (strong) UIImageView *logo;
@property (strong) UILabel *titleLabel;
@property (strong) UILabel *subtitleLabel;
@property (strong) UIImageView *card;
@property (strong) YMQRView *qr;
@property (strong) UIActivityIndicatorView *qrSpinner;
@property (strong) UILabel *scanLabel;
@property (strong) UILabel *urlLabel;
@property (strong) UILabel *orLabel;
@property (strong) UIImageView *codeField;
@property (strong) UILabel *codeLabel;
@property (strong) UIButton *codeCopyButton;
@property (strong) UIButton *renewButton;
@property (strong) UIActivityIndicatorView *spinner;
@property (strong) UILabel *statusLabel;
@property (strong) NSTimer *countdown;
@property (strong) NSDate *expiresAt;
@property (strong) NSString *userCode;
@property (strong) NSMutableArray *attempts;
@property NSInteger generation;
@property CGRect frame;
@end

@implementation YandexConnect

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super init])) {
        self.frame = frame;
        self.attempts = [NSMutableArray array];
    }
    return self;
}

#pragma mark - interface

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color
{
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.backgroundColor = [UIColor clearColor];
    l.font = font;
    l.textColor = color;
    l.textAlignment = NSTextAlignmentCenter;
    l.numberOfLines = 0;
    return l;
}

- (UIButton *)pillWithTitle:(NSString *)title glyph:(YMGlyph)glyph accent:(BOOL)accent
{
    YMTheme *t = [YMTheme current];
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    [b setBackgroundImage:[t pillButtonPressed:NO accent:accent] forState:UIControlStateNormal];
    [b setBackgroundImage:[t pillButtonPressed:YES accent:accent] forState:UIControlStateHighlighted];
    UIColor *textColor = accent ? t.accentText : t.text;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:textColor forState:UIControlStateNormal];
    [b setTitleColor:[textColor colorWithAlphaComponent:0.4] forState:UIControlStateDisabled];
    BOOL lightText = accent ? (t.kind == YMThemeClassic || t.leather) : (t.kind == YMThemeYandexDark);
    [b setTitleShadowColor:lightText ? YMRGBA(0, 0, 0, 0.4) : YMRGBA(255, 255, 255, 0.6) forState:UIControlStateNormal];
    b.titleLabel.shadowOffset = CGSizeMake(0, lightText ? -1 : 1);
    b.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [b setImage:[YMDraw glyph:glyph size:16 color:textColor] forState:UIControlStateNormal];
    b.imageEdgeInsets = UIEdgeInsetsMake(0, -6, 0, 0);
    b.titleEdgeInsets = UIEdgeInsetsMake(0, 4, 0, 0);
    b.adjustsImageWhenHighlighted = NO;
    return b;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    YMTheme *t = [YMTheme current];
    self.view.backgroundColor = [t backgroundPattern];

    self.scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scroll.alwaysBounceVertical = YES;
    [self.view addSubview:self.scroll];

    UIImage *icon = [UIImage imageNamed:@"Icon@2x.png"];
    if (!icon) icon = [UIImage imageNamed:@"Icon.png"];
    self.logo = [[UIImageView alloc] initWithImage:icon];
    self.logo.layer.cornerRadius = 11;
    self.logo.layer.masksToBounds = YES;
    UIView *logoShadow = [[UIView alloc] initWithFrame:CGRectZero];
    logoShadow.tag = 7;
    logoShadow.layer.shadowColor = [UIColor blackColor].CGColor;
    logoShadow.layer.shadowOpacity = 0.45;
    logoShadow.layer.shadowOffset = CGSizeMake(0, 2);
    logoShadow.layer.shadowRadius = 3;
    [logoShadow addSubview:self.logo];
    [self.scroll addSubview:logoShadow];

    UIColor *emboss = (t.kind == YMThemeYandexDark) ? YMRGBA(0, 0, 0, 0.8) : YMRGBA(255, 255, 255, 0.7);
    self.titleLabel = [self labelWithFont:[UIFont boldSystemFontOfSize:24] color:t.text];
    self.titleLabel.text = @"Яндекс Музыка";
    self.titleLabel.shadowColor = emboss;
    self.titleLabel.shadowOffset = CGSizeMake(0, 1);
    self.titleLabel.textAlignment = NSTextAlignmentLeft;
    [self.scroll addSubview:self.titleLabel];

    self.subtitleLabel = [self labelWithFont:[UIFont systemFontOfSize:14] color:t.subtext];
    self.subtitleLabel.text = @"Вход в аккаунт Яндекса";
    self.subtitleLabel.shadowColor = emboss;
    self.subtitleLabel.shadowOffset = CGSizeMake(0, 1);
    self.subtitleLabel.textAlignment = NSTextAlignmentLeft;
    [self.scroll addSubview:self.subtitleLabel];

    self.card = [[UIImageView alloc] initWithImage:[t cardImageWithRadius:14]];
    self.card.userInteractionEnabled = YES;
    [self.scroll addSubview:self.card];

    UIColor *cardText = t.text;
    UIColor *cardSub = t.leather ? YMRGB(110, 66, 24) : t.subtext;

    self.qr = [[YMQRView alloc] initWithFrame:CGRectZero];
    [self.card addSubview:self.qr];
    self.qrSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.qr addSubview:self.qrSpinner];
    [self.qrSpinner startAnimating];

    self.scanLabel = [self labelWithFont:[UIFont boldSystemFontOfSize:15] color:cardText];
    self.scanLabel.text = @"Отсканируйте камерой телефона";
    [self.card addSubview:self.scanLabel];

    self.urlLabel = [self labelWithFont:[UIFont systemFontOfSize:13] color:cardSub];
    self.urlLabel.text = @"или откройте ya.ru/device и введите код";
    [self.card addSubview:self.urlLabel];

    self.codeField = [[UIImageView alloc] initWithImage:[t fieldImage]];
    self.codeField.userInteractionEnabled = YES;
    [self.card addSubview:self.codeField];
    self.codeLabel = [self labelWithFont:[UIFont fontWithName:@"Courier-Bold" size:32] color:t.fieldText];
    self.codeLabel.numberOfLines = 1;
    self.codeLabel.adjustsFontSizeToFitWidth = YES;
    self.codeLabel.text = @"· · · · · · ·";
    [self.codeField addSubview:self.codeLabel];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(copyCode:)];
    [self.codeField addGestureRecognizer:tap];

    self.codeCopyButton = [self pillWithTitle:@"Скопировать" glyph:YMGlyphCopy accent:YES];
    [self.codeCopyButton addTarget:self action:@selector(copyCode:) forControlEvents:UIControlEventTouchUpInside];
    self.codeCopyButton.enabled = NO;
    [self.card addSubview:self.codeCopyButton];

    self.renewButton = [self pillWithTitle:@"Новый код" glyph:YMGlyphRefresh accent:NO];
    [self.renewButton addTarget:self action:@selector(renewCode:) forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:self.renewButton];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
                    t.leather ? UIActivityIndicatorViewStyleGray : t.spinnerStyle];
    self.spinner.hidesWhenStopped = YES;
    [self.card addSubview:self.spinner];

    self.statusLabel = [self labelWithFont:[UIFont systemFontOfSize:13] color:cardSub];
    self.statusLabel.text = @"Запрашиваем код у Яндекса…";
    [self.card addSubview:self.statusLabel];

    [self layoutContent];
    [self beginDeviceAuthorization];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self layoutContent];
}

- (void)layoutContent
{
    CGSize b = self.view.bounds.size;
    BOOL compact = b.height < 500;
    CGFloat cardW = MIN(b.width - 16, 320);
    CGFloat x = floor((b.width - cardW) / 2);

    /* card contents; the card image has a 5pt shadow margin */
    const CGFloat m = 5;
    CGFloat qrSide = compact ? 128 : 156;
    CGFloat y = m + 18;
    self.qr.frame = CGRectMake(m + floor((cardW - qrSide) / 2), y, qrSide, qrSide);
    self.qrSpinner.center = CGPointMake(qrSide / 2, qrSide / 2);
    y += qrSide + 8;
    self.scanLabel.frame = CGRectMake(m + 16, y, cardW - 32, 19); y += 19;
    self.urlLabel.frame = CGRectMake(m + 16, y, cardW - 32, 18); y += 18 + 10;
    self.codeField.frame = CGRectMake(m + 20, y, cardW - 40, 52);
    self.codeLabel.frame = CGRectInset(self.codeField.bounds, 10, 4);
    y += 52 + 10;
    CGFloat bw = floor((cardW - 40 - 10) / 2);
    self.codeCopyButton.frame = CGRectMake(m + 20, y, bw, 44);
    self.renewButton.frame = CGRectMake(m + 30 + bw, y, bw, 44);
    y += 44 + 8;
    self.statusLabel.frame = CGRectMake(m + 40, y, cardW - 80, 34);
    self.spinner.center = CGPointMake(m + 28, y + 17);
    y += 34 + 12 - m;
    CGFloat cardH = y;

    /* header */
    CGFloat logoSide = compact ? 46 : 57;
    CGFloat headerH = logoSide;
    CGFloat total = headerH + 14 + cardH;
    CGFloat top = MAX(12, floor((b.height - total) / 2) - (compact ? 0 : 10));
    UIView *logoShadow = [self.scroll viewWithTag:7];
    logoShadow.frame = CGRectMake(x + 8, top, logoSide, logoSide);
    self.logo.frame = logoShadow.bounds;
    CGFloat tx = x + 8 + logoSide + 12;
    self.titleLabel.frame = CGRectMake(tx, top + logoSide / 2 - 26, cardW - (tx - x), 30);
    self.subtitleLabel.frame = CGRectMake(tx, top + logoSide / 2 + 3, cardW - (tx - x), 18);

    self.card.frame = CGRectMake(x - m, top + headerH + 14 - m, cardW + 2 * m, cardH + 2 * m);
    self.scroll.contentSize = CGSizeMake(b.width, CGRectGetMaxY(self.card.frame) + 12);
}

- (NSUInteger)supportedInterfaceOrientations {
    return YMIsPad() ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o {
    return YMIsPad() || o == UIInterfaceOrientationPortrait;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return [YMTheme current].statusBarStyle;
}

#pragma mark - state

- (void)setStatus:(NSString *)text busy:(BOOL)busy error:(BOOL)error
{
    YMTheme *t = [YMTheme current];
    self.statusLabel.text = text;
    self.statusLabel.textColor = error ? YMRGB(200, 40, 30) : (t.leather ? YMRGB(110, 66, 24) : t.subtext);
    if (busy) [self.spinner startAnimating]; else [self.spinner stopAnimating];
}

- (void)showCode:(NSString *)code url:(NSString *)url expiresIn:(int)expiresIn
{
    self.userCode = code;
    [UIPasteboard generalPasteboard].string = code;

    NSMutableString *spaced = [NSMutableString string];
    for (NSUInteger i = 0; i < code.length; ++i) {
        if (i) [spaced appendString:(code.length > 6 && i == code.length / 2) ? @"  " : @" "];
        [spaced appendString:[code substringWithRange:NSMakeRange(i, 1)]];
    }
    self.codeLabel.text = spaced;
    self.codeLabel.alpha = 0;
    [UIView animateWithDuration:0.3 animations:^{ self.codeLabel.alpha = 1; }];

    [self.qrSpinner stopAnimating];
    self.qr.text = url;
    NSString *shortURL = url;
    for (NSString *prefix in @[@"https://", @"http://"])
        if ([shortURL hasPrefix:prefix])
            shortURL = [shortURL substringFromIndex:prefix.length];
    if ([shortURL hasSuffix:@"/"])
        shortURL = [shortURL substringToIndex:shortURL.length - 1];
    self.urlLabel.text = [NSString stringWithFormat:@"или откройте %@ и введите код", shortURL];
    self.codeCopyButton.enabled = YES;

    self.expiresAt = [NSDate dateWithTimeIntervalSinceNow:expiresIn > 0 ? expiresIn : 600];
    [self.countdown invalidate];
    self.countdown = [NSTimer scheduledTimerWithTimeInterval:1 target:self
                                                    selector:@selector(tick:) userInfo:nil repeats:YES];
    [self tick:nil];
}

- (void)tick:(NSTimer *)timer
{
    NSTimeInterval left = [self.expiresAt timeIntervalSinceNow];
    if (left <= 0) {
        [self.countdown invalidate];
        [self setStatus:@"Код истёк. Нажмите «Новый код»." busy:NO error:YES];
        return;
    }
    [self setStatus:[NSString stringWithFormat:@"Код скопирован. Ждём подтверждения… %@",
                     [YMDraw formatTime:left]] busy:YES error:NO];
}

- (void)copyCode:(id)sender
{
    if (!self.userCode.length)
        return;
    [UIPasteboard generalPasteboard].string = self.userCode;
    [UIView animateWithDuration:0.12 animations:^{
        self.codeField.transform = CGAffineTransformMakeScale(1.04, 1.04);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.12 animations:^{ self.codeField.transform = CGAffineTransformIdentity; }];
    }];
    [self setStatus:@"Код скопирован в буфер обмена" busy:self.spinner.isAnimating error:NO];
}

- (void)renewCode:(id)sender
{
    [self beginDeviceAuthorization];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.isBeingDismissed) {
        [self.countdown invalidate];
        for (YMAuthAttempt *a in self.attempts)
            a.cancelled = YES;
    }
}

#pragma mark - device flow

- (BOOL)isCurrent:(YMAuthAttempt *)attempt
{
    return !attempt.cancelled && attempt.owner && attempt.generation == attempt.owner.generation;
}

- (void)beginDeviceAuthorization {
    for (YMAuthAttempt *a in self.attempts)
        a.cancelled = YES;
    [self.attempts removeAllObjects];
    [self.countdown invalidate];

    YMAuthAttempt *attempt = [[YMAuthAttempt alloc] init];
    attempt.owner = self;
    attempt.generation = ++self.generation;
    [self.attempts addObject:attempt];

    self.userCode = nil;
    self.qr.text = nil;
    [self.qrSpinner startAnimating];
    self.codeLabel.text = @"· · · · · · ·";
    self.codeCopyButton.enabled = NO;
    [self setStatus:@"Запрашиваем код у Яндекса…" busy:YES error:NO];

    NSString *deviceID = device_identifier();
    NSString *deviceName = [UIDevice currentDevice].name;
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue addOperationWithBlock:^{
        c_yandex_oauth_code_from_user(
            CLIENTID,
            [deviceID UTF8String],
            [deviceName UTF8String],
            (__bridge void *)attempt,
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
    YMAuthAttempt *attempt = (__bridge YMAuthAttempt *)user_data;

    if (error || uid <= 0) {
        NSString *message = error
            ? [NSString stringWithUTF8String:error]
            : @"Яндекс Музыка не вернула UID аккаунта";
        clear_saved_tokens();
        dispatch_async(dispatch_get_main_queue(), ^{
            YandexConnect *self = attempt.owner;
            [self setStatus:[NSString stringWithFormat:@"Яндекс Музыка: %@", message] busy:NO error:YES];
        });
        return;
    }

    [[NSUserDefaults standardUserDefaults] setInteger:uid forKey:@"uid"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    notify_token_updated();

    dispatch_async(dispatch_get_main_queue(), ^{
        YandexConnect *self = attempt.owner;
        if (!self)
            return;
        [self.countdown invalidate];
        [self setStatus:@"Готово! Добро пожаловать." busy:NO error:NO];
        self.codeLabel.text = @"✓";
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:nil];
        });
    });
}

static int token_callback(
    void *user_data,
    const char *access_token,
    int expires_in,
    const char *refresh_token,
    const char *error)
{
    YMAuthAttempt *attempt = (__bridge YMAuthAttempt *)user_data;
    YandexConnect *owner = attempt.owner;
    if (!owner || ![owner isCurrent:attempt])
        return 1;

    if (error) {
        NSString *message = [NSString stringWithUTF8String:error];
        dispatch_async(dispatch_get_main_queue(), ^{
            YandexConnect *self = attempt.owner;
            [self.countdown invalidate];
            [self setStatus:[NSString stringWithFormat:@"Не удалось войти: %@", message] busy:NO error:YES];
        });
        return 0;
    }

    if (access_token) {
        save_oauth_tokens(access_token, expires_in, refresh_token);
        dispatch_async(dispatch_get_main_queue(), ^{
            [attempt.owner setStatus:@"Код подтверждён, проверяем аккаунт…" busy:YES error:NO];
            [attempt.owner.countdown invalidate];
        });

        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        NSString *tokenCopy = [[NSString alloc] initWithUTF8String:access_token];
        [queue addOperationWithBlock:^{
            c_yandex_music_check_auth(
                [tokenCopy UTF8String],
                (__bridge void *)attempt,
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
    YMAuthAttempt *attempt = (__bridge YMAuthAttempt *)user_data;
    YandexConnect *owner = attempt.owner;
    if (!owner || ![owner isCurrent:attempt])
        return 0;

    if (error) {
        NSString *message = [NSString stringWithUTF8String:error];
        dispatch_async(dispatch_get_main_queue(), ^{
            YandexConnect *self = attempt.owner;
            [self.qrSpinner stopAnimating];
            [self setStatus:[NSString stringWithFormat:@"Не удалось получить код: %@", message] busy:NO error:YES];
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
        YandexConnect *self = attempt.owner;
        if (self && [self isCurrent:attempt])
            [self showCode:userCode url:verificationURL expiresIn:expires_in];
    });

    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue addOperationWithBlock:^{
        c_yandex_oauth_get_token_from_user(
            [deviceCode UTF8String],
            CLIENTID,
            CLIENTSECRET,
            interval,
            expires_in,
            (__bridge void *)attempt,
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

+ (void)signOut
{
    clear_saved_tokens();
    notify_token_updated();
}

- (void)dealloc {
    [self.countdown invalidate];
}

@end

// vim:ft=objc

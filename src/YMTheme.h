/**
 * File              : YMTheme.h
 * The four interface themes: Classic (iOS 6 blue and white), Yandex
 * (yellow and white), Yandex Dark (yellow and black) and Original (the
 * leather of the app icon).
 */

#import <UIKit/UIKit.h>
#import "YMDraw.h"

/* iPad gets the same interface, laid out for the bigger screen */
#define YMIsPad() (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)

typedef enum {
	YMThemeClassic = 0,
	YMThemeYandex,
	YMThemeYandexDark,
	YMThemeOriginal,
	YMThemeCount
} YMThemeKind;

extern NSString * const YMThemeDidChangeNotification;

@interface YMTheme : NSObject

+ (YMTheme *)current;
+ (YMTheme *)themeWithKind:(YMThemeKind)kind;
+ (void)setCurrentKind:(YMThemeKind)kind;

@property (readonly) YMThemeKind kind;
@property (strong) NSString *name;
@property (strong) NSString *subtitle;

/* bars */
@property (strong) UIColor *navTop, *navBottom, *navLine, *navTitle, *navTitleShadow;
@property CGSize navTitleShadowOffset;
@property (strong) UIColor *buttonTop, *buttonBottom, *buttonBorder, *buttonText, *buttonTextShadow;
@property (strong) UIColor *tabTop, *tabBottom, *tabLine;
@property (strong) UIColor *tabSelectedTop, *tabSelectedBottom, *tabUnselected, *tabSelection;

/* content */
@property (strong) UIColor *background, *cell, *cellSelectedTop, *cellSelectedBottom, *separator;
@property (strong) UIColor *text, *subtext, *accent, *accentDark, *accentText;
@property (strong) UIColor *heroTop, *heroBottom, *heroText, *heroSubtext;
@property (strong) UIColor *panelTop, *panelBottom, *panelGlyph, *panelText;
@property (strong) UIColor *fieldTop, *fieldBottom, *fieldText;

/* materials */
@property BOOL leather;        /* noise grain and stitching */
@property BOOL metal;          /* brushed aluminium player panel */
@property (strong) UIColor *stitch, *stitchHighlight;
@property UIStatusBarStyle statusBarStyle;
@property UIActivityIndicatorViewStyle spinnerStyle;
@property UIKeyboardAppearance keyboardAppearance;

- (void)applyAppearance;

/* backgrounds */
- (UIColor *)backgroundPattern;
- (UIImage *)navBackgroundWithHeight:(CGFloat)height;
- (UIImage *)tabBackground;

/* controls */
- (UIImage *)barButtonImagePressed:(BOOL)pressed back:(BOOL)back height:(CGFloat)height;
- (UIImage *)tabGlyph:(YMGlyph)glyph selected:(BOOL)selected;
- (UIImage *)roundButtonWithDiameter:(CGFloat)d glyph:(YMGlyph)glyph
                              accent:(BOOL)accent pressed:(BOOL)pressed;
- (UIImage *)pillButtonPressed:(BOOL)pressed accent:(BOOL)accent;
- (UIImage *)cardImageWithRadius:(CGFloat)radius;
- (UIImage *)heroImageWithSize:(CGSize)size;
- (UIImage *)panelImageWithSize:(CGSize)size;
- (UIImage *)fieldImage;
- (UIImage *)sliderTrack:(BOOL)filled;
- (UIImage *)sliderThumb;
- (UIImage *)coverPlaceholderWithSize:(CGSize)size;

/* a bar button that keeps the glyph in the theme's colours */
- (UIBarButtonItem *)barButtonWithGlyph:(YMGlyph)glyph target:(id)target action:(SEL)action;

/* tables */
- (UIView *)sectionHeaderWithTitle:(NSString *)title width:(CGFloat)width grouped:(BOOL)grouped;
- (void)styleTableView:(UITableView *)tableView;
- (void)styleCell:(UITableViewCell *)cell;
- (void)styleController:(UIViewController *)controller;

@end

// vim:ft=objc

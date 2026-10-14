/**
 * File              : YMDraw.h
 * Drawing helpers for the skeuomorphic interface: every texture, button
 * and glyph is drawn with Core Graphics so the four themes can recolour it.
 */

#import <UIKit/UIKit.h>

#define YMRGB(r, g, b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1.0]
#define YMRGBA(r, g, b, a) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:(a)]

typedef enum {
	YMGlyphHome,
	YMGlyphSearch,
	YMGlyphNote,
	YMGlyphHeart,
	YMGlyphHeartFilled,
	YMGlyphPlaylists,
	YMGlyphPlay,
	YMGlyphPause,
	YMGlyphNext,
	YMGlyphPrev,
	YMGlyphShuffle,
	YMGlyphRepeat,
	YMGlyphRepeatOne,
	YMGlyphGear,
	YMGlyphQueue,
	YMGlyphWave,
	YMGlyphCopy,
	YMGlyphRefresh,
	YMGlyphChevronDown,
	YMGlyphMore,
} YMGlyph;

@interface YMDraw : NSObject

+ (UIImage *)imageWithSize:(CGSize)size opaque:(BOOL)opaque
                   drawing:(void (^)(CGContextRef ctx, CGRect rect))drawing;

+ (void)fillRect:(CGRect)rect inContext:(CGContextRef)ctx
          colors:(NSArray *)colors locations:(const CGFloat *)locations;
+ (void)fillPath:(UIBezierPath *)path inContext:(CGContextRef)ctx
          colors:(NSArray *)colors;

/* Tileable monochrome noise used for leather, paper and brushed metal. */
+ (UIImage *)noiseTileWithAlpha:(CGFloat)alpha;
/* Horizontal streaks: brushed aluminium. */
+ (UIImage *)brushedTileWithAlpha:(CGFloat)alpha;

/* Dashed stitching along a (rounded) rect with an embossed highlight. */
+ (void)drawStitchInRect:(CGRect)rect radius:(CGFloat)radius
                   color:(UIColor *)color highlight:(UIColor *)highlight
               inContext:(CGContextRef)ctx;
+ (void)drawStitchLineFrom:(CGPoint)a to:(CGPoint)b
                     color:(UIColor *)color highlight:(UIColor *)highlight
                 inContext:(CGContextRef)ctx;

/* The closed path traced the other way round, for punching holes with the
 * nonzero rule. -bezierPathByReversingPath on iOS 6 drops the move-to of the
 * reversed subpath ("no current point"), so this rebuilds it by hand. */
+ (UIBezierPath *)reversedPath:(UIBezierPath *)path;

+ (UIBezierPath *)pathForGlyph:(YMGlyph)glyph inRect:(CGRect)rect;
/* Glyph filled with a vertical gradient, optional emboss shadow. */
+ (UIImage *)glyph:(YMGlyph)glyph size:(CGFloat)size
               top:(UIColor *)top bottom:(UIColor *)bottom
            shadow:(UIColor *)shadow offset:(CGSize)offset;
+ (UIImage *)glyph:(YMGlyph)glyph size:(CGFloat)size color:(UIColor *)color;

/* Image with a reflection below it (Cover Flow), height = size * (1 + fraction). */
+ (UIImage *)reflectedImage:(UIImage *)image size:(CGSize)size fraction:(CGFloat)fraction;

+ (UIColor *)blend:(UIColor *)a with:(UIColor *)b amount:(CGFloat)t;
+ (NSString *)formatTime:(NSTimeInterval)seconds;

@end

// vim:ft=objc

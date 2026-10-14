/**
 * File              : YMDraw.m
 * Drawing helpers for the skeuomorphic interface.
 */

#import "YMDraw.h"
#import <QuartzCore/QuartzCore.h>

@implementation YMDraw

+ (UIImage *)imageWithSize:(CGSize)size opaque:(BOOL)opaque
                   drawing:(void (^)(CGContextRef ctx, CGRect rect))drawing
{
	UIGraphicsBeginImageContextWithOptions(size, opaque, 0);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	drawing(ctx, CGRectMake(0, 0, size.width, size.height));
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

static CGGradientRef create_gradient(NSArray *colors, const CGFloat *locations)
{
	NSMutableArray *cg = [NSMutableArray arrayWithCapacity:colors.count];
	for (UIColor *c in colors)
		[cg addObject:(__bridge id)c.CGColor];
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGGradientRef g = CGGradientCreateWithColors(space, (__bridge CFArrayRef)cg, locations);
	CGColorSpaceRelease(space);
	return g;
}

+ (void)fillRect:(CGRect)rect inContext:(CGContextRef)ctx
          colors:(NSArray *)colors locations:(const CGFloat *)locations
{
	if (colors.count == 1) {
		CGContextSetFillColorWithColor(ctx, [colors[0] CGColor]);
		CGContextFillRect(ctx, rect);
		return;
	}
	CGGradientRef g = create_gradient(colors, locations);
	CGContextSaveGState(ctx);
	CGContextClipToRect(ctx, rect);
	CGContextDrawLinearGradient(ctx, g,
			CGPointMake(0, CGRectGetMinY(rect)),
			CGPointMake(0, CGRectGetMaxY(rect)), 0);
	CGContextRestoreGState(ctx);
	CGGradientRelease(g);
}

+ (void)fillPath:(UIBezierPath *)path inContext:(CGContextRef)ctx
          colors:(NSArray *)colors
{
	CGContextSaveGState(ctx);
	CGContextAddPath(ctx, path.CGPath);
	CGContextClip(ctx);
	[self fillRect:path.bounds inContext:ctx colors:colors locations:NULL];
	CGContextRestoreGState(ctx);
}

#pragma mark - textures

static uint32_t ym_seed = 0x1234567;
static uint32_t ym_rand(void)
{
	ym_seed = ym_seed * 1664525u + 1013904223u;
	return ym_seed >> 8;
}

static UIImage *tile_from_alpha(uint8_t *alpha, int side, BOOL white)
{
	CGFloat scale = [UIScreen mainScreen].scale;
	uint8_t *rgba = calloc((size_t)side * side, 4);
	for (int i = 0; i < side * side; ++i) {
		uint8_t v = white ? 255 : 0;
		/* premultiplied */
		uint8_t a = alpha[i];
		rgba[i * 4 + 0] = (uint8_t)(v * a / 255);
		rgba[i * 4 + 1] = (uint8_t)(v * a / 255);
		rgba[i * 4 + 2] = (uint8_t)(v * a / 255);
		rgba[i * 4 + 3] = a;
	}
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef bc = CGBitmapContextCreate(rgba, side, side, 8, side * 4, space,
			kCGImageAlphaPremultipliedLast);
	CGImageRef cg = CGBitmapContextCreateImage(bc);
	UIImage *image = [UIImage imageWithCGImage:cg scale:scale orientation:UIImageOrientationUp];
	CGImageRelease(cg);
	CGContextRelease(bc);
	CGColorSpaceRelease(space);
	free(rgba);
	return image;
}

+ (UIImage *)noiseTileWithAlpha:(CGFloat)alpha
{
	/* Two layers: dark specks and light specks, giving a grain that reads
	 * as leather or paper over any base colour. */
	const int side = 128;
	uint8_t *dark = malloc(side * side);
	uint8_t *light = malloc(side * side);
	ym_seed = 0xC0FFEE;
	for (int i = 0; i < side * side; ++i) {
		uint32_t r = ym_rand() & 0xFF;
		dark[i] = (uint8_t)(r < 128 ? (128 - r) * alpha * 1.6 : 0);
		light[i] = (uint8_t)(r > 160 ? (r - 160) * alpha * 1.4 : 0);
	}
	UIImage *d = tile_from_alpha(dark, side, NO);
	UIImage *l = tile_from_alpha(light, side, YES);
	free(dark);
	free(light);
	CGSize size = d.size;
	return [self imageWithSize:size opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		[d drawInRect:rect];
		[l drawInRect:rect];
	}];
}

+ (UIImage *)brushedTileWithAlpha:(CGFloat)alpha
{
	const int side = 128;
	uint8_t *dark = malloc(side * side);
	uint8_t *light = malloc(side * side);
	ym_seed = 0xBADA55;
	for (int y = 0; y < side; ++y) {
		int row = (int)(ym_rand() & 0xFF) - 128;
		int acc = 0;
		for (int x = 0; x < side; ++x) {
			acc = (acc * 7 + ((int)(ym_rand() & 0xFF) - 128)) / 8;
			int v = row / 2 + acc;
			dark[y * side + x] = (uint8_t)(v < 0 ? MIN(255, -v * alpha * 2.0) : 0);
			light[y * side + x] = (uint8_t)(v > 0 ? MIN(255, v * alpha * 2.0) : 0);
		}
	}
	UIImage *d = tile_from_alpha(dark, side, NO);
	UIImage *l = tile_from_alpha(light, side, YES);
	free(dark);
	free(light);
	return [self imageWithSize:d.size opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		[d drawInRect:rect];
		[l drawInRect:rect];
	}];
}

#pragma mark - stitching

static void stroke_dashed(CGContextRef ctx, CGPathRef path, UIColor *color, CGSize offset)
{
	CGFloat dash[] = {4.0, 3.0};
	CGContextSaveGState(ctx);
	CGContextTranslateCTM(ctx, offset.width, offset.height);
	CGContextAddPath(ctx, path);
	CGContextSetLineDash(ctx, 0, dash, 2);
	CGContextSetLineWidth(ctx, 1.2);
	CGContextSetLineCap(ctx, kCGLineCapRound);
	CGContextSetStrokeColorWithColor(ctx, color.CGColor);
	CGContextStrokePath(ctx);
	CGContextRestoreGState(ctx);
}

+ (void)drawStitchInRect:(CGRect)rect radius:(CGFloat)radius
                   color:(UIColor *)color highlight:(UIColor *)highlight
               inContext:(CGContextRef)ctx
{
	UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
	if (highlight)
		stroke_dashed(ctx, p.CGPath, highlight, CGSizeMake(0, 1));
	stroke_dashed(ctx, p.CGPath, color, CGSizeZero);
}

+ (void)drawStitchLineFrom:(CGPoint)a to:(CGPoint)b
                     color:(UIColor *)color highlight:(UIColor *)highlight
                 inContext:(CGContextRef)ctx
{
	UIBezierPath *p = [UIBezierPath bezierPath];
	[p moveToPoint:a];
	[p addLineToPoint:b];
	if (highlight)
		stroke_dashed(ctx, p.CGPath, highlight, CGSizeMake(0, 1));
	stroke_dashed(ctx, p.CGPath, color, CGSizeZero);
}

#pragma mark - reversing

typedef struct {
	CGPathElementType type;
	CGPoint pts[3];
} ym_element;

static void collect_element(void *info, const CGPathElement *e)
{
	NSMutableData *data = (__bridge NSMutableData *)info;
	ym_element el;
	memset(&el, 0, sizeof(el));
	el.type = e->type;
	int n = 0;
	switch (e->type) {
	case kCGPathElementMoveToPoint:
	case kCGPathElementAddLineToPoint: n = 1; break;
	case kCGPathElementAddQuadCurveToPoint: n = 2; break;
	case kCGPathElementAddCurveToPoint: n = 3; break;
	default: break;
	}
	for (int i = 0; i < n; ++i)
		el.pts[i] = e->points[i];
	[data appendBytes:&el length:sizeof(el)];
}

static CGPoint element_end(const ym_element *e)
{
	switch (e->type) {
	case kCGPathElementAddQuadCurveToPoint: return e->pts[1];
	case kCGPathElementAddCurveToPoint: return e->pts[2];
	default: return e->pts[0];
	}
}

/* Reverse one subpath: elements [from, to), from is its move-to. */
static void reverse_subpath(UIBezierPath *out, const ym_element *el, NSUInteger from, NSUInteger to, BOOL closed)
{
	if (to <= from + 1)
		return;
	CGPoint start = el[from].pts[0];
	CGPoint end = element_end(&el[to - 1]);
	if (closed) {
		/* the implicit closing line runs end -> start; reversed it is start -> end */
		[out moveToPoint:start];
		if (!CGPointEqualToPoint(start, end))
			[out addLineToPoint:end];
	} else {
		[out moveToPoint:end];
	}
	for (NSUInteger i = to - 1; i > from; --i) {
		CGPoint prev = element_end(&el[i - 1]);
		switch (el[i].type) {
		case kCGPathElementAddLineToPoint:
			[out addLineToPoint:prev];
			break;
		case kCGPathElementAddQuadCurveToPoint:
			[out addQuadCurveToPoint:prev controlPoint:el[i].pts[0]];
			break;
		case kCGPathElementAddCurveToPoint:
			[out addCurveToPoint:prev controlPoint1:el[i].pts[1] controlPoint2:el[i].pts[0]];
			break;
		default:
			break;
		}
	}
	if (closed)
		[out closePath];
}

+ (UIBezierPath *)reversedPath:(UIBezierPath *)path
{
	NSMutableData *data = [NSMutableData data];
	CGPathApply(path.CGPath, (__bridge void *)data, collect_element);
	const ym_element *el = data.bytes;
	NSUInteger count = data.length / sizeof(ym_element);
	UIBezierPath *out = [UIBezierPath bezierPath];
	NSUInteger start = NSNotFound;
	for (NSUInteger i = 0; i <= count; ++i) {
		BOOL atEnd = (i == count);
		if (!atEnd && el[i].type == kCGPathElementMoveToPoint) {
			if (start != NSNotFound)
				reverse_subpath(out, el, start, i, NO);
			start = i;
		} else if (atEnd || el[i].type == kCGPathElementCloseSubpath) {
			if (start != NSNotFound)
				reverse_subpath(out, el, start, i, !atEnd);
			start = NSNotFound;
		}
	}
	return out;
}

#pragma mark - glyphs (drawn in a 100x100 design space)

/* Material Symbols Rounded, see icons/material-symbols and tools/gen_icons.py */
#include "YMIcons.inc"

static const char *glyph_icon_name(YMGlyph glyph)
{
	switch (glyph) {
	case YMGlyphHome: return "home-fill";
	case YMGlyphSearch: return "search";
	case YMGlyphNote: return "music_note-fill";
	case YMGlyphHeart: return "favorite";
	case YMGlyphHeartFilled: return "favorite-fill";
	case YMGlyphPlaylists: return "library_music-fill";
	case YMGlyphPlay: return "play_arrow-fill";
	case YMGlyphPause: return "pause-fill";
	case YMGlyphNext: return "skip_next-fill";
	case YMGlyphPrev: return "skip_previous-fill";
	case YMGlyphShuffle: return "shuffle";
	case YMGlyphRepeat: return "repeat";
	case YMGlyphRepeatOne: return "repeat_one";
	case YMGlyphGear: return "settings-fill";
	case YMGlyphQueue: return "queue_music";
	case YMGlyphWave: return "graphic_eq";
	case YMGlyphCopy: return "content_copy-fill";
	case YMGlyphRefresh: return "refresh";
	case YMGlyphChevronDown: return "keyboard_arrow_down";
	case YMGlyphMore: return "more_horiz";
	}
	return NULL;
}

static UIBezierPath *design_path(YMGlyph glyph)
{
	UIBezierPath *p = [UIBezierPath bezierPath];
	const char *name = glyph_icon_name(glyph);
	if (!name)
		return p;
	for (size_t k = 0; k < sizeof(ym_icons) / sizeof(ym_icons[0]); ++k) {
		if (strcmp(ym_icons[k].name, name))
			continue;
		const float *v = ym_icons[k].pts;
		for (const char *op = ym_icons[k].ops; *op; ++op) {
			switch (*op) {
			case 'M': [p moveToPoint:CGPointMake(v[0], v[1])]; v += 2; break;
			case 'L': [p addLineToPoint:CGPointMake(v[0], v[1])]; v += 2; break;
			case 'Q': [p addQuadCurveToPoint:CGPointMake(v[2], v[3]) controlPoint:CGPointMake(v[0], v[1])]; v += 4; break;
			case 'Z': [p closePath]; break;
			}
		}
		break;
	}
	return p;
}

+ (UIBezierPath *)pathForGlyph:(YMGlyph)glyph inRect:(CGRect)rect
{
	UIBezierPath *p = [design_path(glyph) copy];
	CGFloat s = MIN(rect.size.width, rect.size.height) / 100.0;
	CGAffineTransform t = CGAffineTransformMakeTranslation(
			CGRectGetMidX(rect) - 50 * s, CGRectGetMidY(rect) - 50 * s);
	t = CGAffineTransformScale(t, s, s);
	[p applyTransform:t];
	return p;
}

+ (UIImage *)glyph:(YMGlyph)glyph size:(CGFloat)size
               top:(UIColor *)top bottom:(UIColor *)bottom
            shadow:(UIColor *)shadow offset:(CGSize)offset
{
	CGFloat pad = shadow ? 2 : 0;
	CGSize canvas = CGSizeMake(size + pad * 2, size + pad * 2);
	return [self imageWithSize:canvas opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		UIBezierPath *p = [self pathForGlyph:glyph inRect:CGRectMake(pad, pad, size, size)];
		if (shadow) {
			CGContextSaveGState(ctx);
			CGContextTranslateCTM(ctx, offset.width, offset.height);
			[shadow setFill];
			[p fill];
			CGContextRestoreGState(ctx);
		}
		[self fillPath:p inContext:ctx colors:@[top, bottom ? bottom : top]];
	}];
}

+ (UIImage *)glyph:(YMGlyph)glyph size:(CGFloat)size color:(UIColor *)color
{
	return [self glyph:glyph size:size top:color bottom:color shadow:nil offset:CGSizeZero];
}

#pragma mark - reflection

+ (UIImage *)reflectedImage:(UIImage *)image size:(CGSize)size fraction:(CGFloat)fraction
{
	CGFloat rh = floor(size.height * fraction);
	CGSize canvas = CGSizeMake(size.width, size.height + rh);
	return [self imageWithSize:canvas opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		CGRect top = CGRectMake(0, 0, size.width, size.height);
		[image drawInRect:top];

		/* Gradient mask for the mirrored copy. */
		CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
		CGContextRef mc = CGBitmapContextCreate(NULL, 1, 64, 8, 0, gray, kCGImageAlphaNone);
		CGFloat comps[] = {0.45, 1.0, 0.0, 1.0};
		CGGradientRef g = CGGradientCreateWithColorComponents(gray, comps, NULL, 2);
		/* bitmap rows are flipped when the mask is applied in a UIKit context,
		 * so the bright end goes at the bitmap's bottom */
		CGContextDrawLinearGradient(mc, g, CGPointMake(0, 0), CGPointMake(0, 64), 0);
		CGImageRef mask = CGBitmapContextCreateImage(mc);
		CGGradientRelease(g);
		CGContextRelease(mc);
		CGColorSpaceRelease(gray);

		CGRect refl = CGRectMake(0, size.height, size.width, rh);
		CGContextSaveGState(ctx);
		CGContextClipToMask(ctx, refl, mask);
		CGContextTranslateCTM(ctx, 0, size.height * 2);
		CGContextScaleCTM(ctx, 1, -1);
		[image drawInRect:top];
		CGContextRestoreGState(ctx);
		CGImageRelease(mask);
	}];
}

#pragma mark - misc

+ (UIColor *)blend:(UIColor *)a with:(UIColor *)b amount:(CGFloat)t
{
	CGFloat r1, g1, b1, a1, r2, g2, b2, a2;
	[a getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
	[b getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
	return [UIColor colorWithRed:r1 + (r2 - r1) * t green:g1 + (g2 - g1) * t
	                        blue:b1 + (b2 - b1) * t alpha:a1 + (a2 - a1) * t];
}

+ (NSString *)formatTime:(NSTimeInterval)seconds
{
	if (isnan(seconds) || seconds < 0)
		seconds = 0;
	int s = (int)seconds;
	return [NSString stringWithFormat:@"%d:%02d", s / 60, s % 60];
}

@end

// vim:ft=objc

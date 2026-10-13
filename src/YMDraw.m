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

static UIBezierPath *stroked(UIBezierPath *path, CGFloat width)
{
	CGPathRef s = CGPathCreateCopyByStrokingPath(path.CGPath, NULL, width,
			kCGLineCapRound, kCGLineJoinRound, 10);
	UIBezierPath *result = [UIBezierPath bezierPathWithCGPath:s];
	CGPathRelease(s);
	return result;
}

static void add_poly(UIBezierPath *p, const CGFloat *pts, int n)
{
	[p moveToPoint:CGPointMake(pts[0], pts[1])];
	for (int i = 1; i < n; ++i)
		[p addLineToPoint:CGPointMake(pts[i * 2], pts[i * 2 + 1])];
	[p closePath];
}

static UIBezierPath *heart_path(void)
{
	UIBezierPath *p = [UIBezierPath bezierPath];
	[p moveToPoint:CGPointMake(50, 88)];
	[p addCurveToPoint:CGPointMake(8, 34) controlPoint1:CGPointMake(22, 66) controlPoint2:CGPointMake(8, 52)];
	[p addCurveToPoint:CGPointMake(30, 12) controlPoint1:CGPointMake(8, 20) controlPoint2:CGPointMake(18, 12)];
	[p addCurveToPoint:CGPointMake(50, 26) controlPoint1:CGPointMake(40, 12) controlPoint2:CGPointMake(47, 18)];
	[p addCurveToPoint:CGPointMake(70, 12) controlPoint1:CGPointMake(53, 18) controlPoint2:CGPointMake(60, 12)];
	[p addCurveToPoint:CGPointMake(92, 34) controlPoint1:CGPointMake(82, 12) controlPoint2:CGPointMake(92, 20)];
	[p addCurveToPoint:CGPointMake(50, 88) controlPoint1:CGPointMake(92, 52) controlPoint2:CGPointMake(78, 66)];
	[p closePath];
	return p;
}

static UIBezierPath *arrow_head(CGPoint tip, CGFloat angle, CGFloat size)
{
	UIBezierPath *p = [UIBezierPath bezierPath];
	[p moveToPoint:CGPointMake(size, 0)];
	[p addLineToPoint:CGPointMake(-size * 0.6, -size * 0.8)];
	[p addLineToPoint:CGPointMake(-size * 0.6, size * 0.8)];
	[p closePath];
	CGAffineTransform t = CGAffineTransformMakeTranslation(tip.x, tip.y);
	t = CGAffineTransformRotate(t, angle);
	[p applyTransform:t];
	return p;
}

static UIBezierPath *design_path(YMGlyph glyph)
{
	UIBezierPath *p = [UIBezierPath bezierPath];
	switch (glyph) {
	case YMGlyphHome: {
		CGFloat roof[] = {8, 50, 50, 10, 92, 50, 82, 50, 50, 22, 18, 50};
		add_poly(p, roof, 6);
		[p appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(22, 48, 56, 40)]];
		[p appendPath:[YMDraw reversedPath:[UIBezierPath bezierPathWithRect:CGRectMake(43, 62, 14, 26)]]];
		[p appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(68, 16, 10, 22)]];
		break;
	}
	case YMGlyphSearch: {
		[p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(8, 8, 62, 62)]];
		[p appendPath:[YMDraw reversedPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(19, 19, 40, 40)]]];
		UIBezierPath *handle = [UIBezierPath bezierPath];
		[handle moveToPoint:CGPointMake(64, 64)];
		[handle addLineToPoint:CGPointMake(88, 88)];
		[p appendPath:stroked(handle, 14)];
		break;
	}
	case YMGlyphNote: {
		[p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(12, 66, 30, 22)]];
		[p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(56, 58, 30, 22)]];
		[p appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(35, 22, 7, 56)]];
		[p appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(79, 12, 7, 58)]];
		CGFloat beam[] = {35, 22, 86, 10, 86, 24, 35, 36};
		add_poly(p, beam, 4);
		break;
	}
	case YMGlyphHeart:
		p = stroked(heart_path(), 9);
		break;
	case YMGlyphHeartFilled:
		p = heart_path();
		break;
	case YMGlyphPlaylists: {
		for (int i = 0; i < 3; ++i) {
			CGFloat y = 18 + i * 26;
			[p appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(8, y, 14, 14) cornerRadius:3]];
			[p appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(30, y + 1, 62, 12) cornerRadius:3]];
		}
		break;
	}
	case YMGlyphPlay: {
		CGFloat t[] = {24, 10, 88, 50, 24, 90};
		add_poly(p, t, 3);
		break;
	}
	case YMGlyphPause:
		[p appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(20, 12, 22, 76) cornerRadius:3]];
		[p appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(58, 12, 22, 76) cornerRadius:3]];
		break;
	case YMGlyphNext: {
		CGFloat a[] = {6, 20, 46, 50, 6, 80};
		CGFloat b[] = {44, 20, 84, 50, 44, 80};
		add_poly(p, a, 3);
		add_poly(p, b, 3);
		[p appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(84, 20, 9, 60)]];
		break;
	}
	case YMGlyphPrev: {
		CGFloat a[] = {94, 20, 54, 50, 94, 80};
		CGFloat b[] = {56, 20, 16, 50, 56, 80};
		add_poly(p, a, 3);
		add_poly(p, b, 3);
		[p appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(7, 20, 9, 60)]];
		break;
	}
	case YMGlyphShuffle: {
		UIBezierPath *l1 = [UIBezierPath bezierPath];
		[l1 moveToPoint:CGPointMake(8, 28)];
		[l1 addCurveToPoint:CGPointMake(72, 72) controlPoint1:CGPointMake(44, 28) controlPoint2:CGPointMake(40, 72)];
		UIBezierPath *l2 = [UIBezierPath bezierPath];
		[l2 moveToPoint:CGPointMake(8, 72)];
		[l2 addCurveToPoint:CGPointMake(72, 28) controlPoint1:CGPointMake(44, 72) controlPoint2:CGPointMake(40, 28)];
		[p appendPath:stroked(l1, 9)];
		[p appendPath:stroked(l2, 9)];
		[p appendPath:arrow_head(CGPointMake(84, 28), 0, 14)];
		[p appendPath:arrow_head(CGPointMake(84, 72), 0, 14)];
		break;
	}
	case YMGlyphRepeat:
	case YMGlyphRepeatOne: {
		UIBezierPath *loop = [UIBezierPath bezierPath];
		[loop moveToPoint:CGPointMake(60, 26)];
		[loop addLineToPoint:CGPointMake(30, 26)];
		[loop addArcWithCenter:CGPointMake(30, 50) radius:24 startAngle:-M_PI_2 endAngle:M_PI_2 clockwise:NO];
		[loop addLineToPoint:CGPointMake(70, 74)];
		[loop addArcWithCenter:CGPointMake(70, 50) radius:24 startAngle:M_PI_2 endAngle:-M_PI_2 * 0.3 clockwise:NO];
		[p appendPath:stroked(loop, 9)];
		[p appendPath:arrow_head(CGPointMake(66, 26), 0, 14)];
		if (glyph == YMGlyphRepeatOne)
			[p appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(45, 38, 10, 26) cornerRadius:2]];
		break;
	}
	case YMGlyphGear: {
		for (int i = 0; i < 8; ++i) {
			UIBezierPath *tooth = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(-8, -46, 16, 22) cornerRadius:3];
			CGAffineTransform t = CGAffineTransformMakeTranslation(50, 50);
			t = CGAffineTransformRotate(t, i * M_PI / 4);
			[tooth applyTransform:t];
			[p appendPath:tooth];
		}
		[p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(18, 18, 64, 64)]];
		[p appendPath:[YMDraw reversedPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(37, 37, 26, 26)]]];
		break;
	}
	case YMGlyphQueue: {
		CGFloat t[] = {8, 14, 26, 25, 8, 36};
		add_poly(p, t, 3);
		[p appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(34, 19, 58, 12) cornerRadius:3]];
		[p appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(8, 46, 84, 12) cornerRadius:3]];
		[p appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(8, 72, 84, 12) cornerRadius:3]];
		break;
	}
	case YMGlyphWave: {
		for (int k = 0; k < 3; ++k) {
			UIBezierPath *w = [UIBezierPath bezierPath];
			CGFloat amp = 8 + k * 7, y0 = 50;
			for (int x = 0; x <= 84; x += 2) {
				CGFloat y = y0 + sin((x / 84.0) * 2 * M_PI + k * 0.9) * amp;
				CGPoint pt = CGPointMake(8 + x, y);
				if (x == 0) [w moveToPoint:pt]; else [w addLineToPoint:pt];
			}
			[p appendPath:stroked(w, k == 0 ? 8 : 4)];
		}
		break;
	}
	case YMGlyphCopy: {
		[p appendPath:stroked([UIBezierPath bezierPathWithRoundedRect:CGRectMake(14, 10, 50, 60) cornerRadius:8], 8)];
		[p appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(36, 30, 50, 60) cornerRadius:8]];
		break;
	}
	case YMGlyphRefresh: {
		UIBezierPath *arc = [UIBezierPath bezierPathWithArcCenter:CGPointMake(50, 52) radius:32
				startAngle:-M_PI_2 + 0.5 endAngle:-M_PI_2 - 0.2 + 2 * M_PI clockwise:YES];
		[p appendPath:stroked(arc, 10)];
		[p appendPath:arrow_head(CGPointMake(46, 20), M_PI, 14)];
		break;
	}
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

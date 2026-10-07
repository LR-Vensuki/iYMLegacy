/**
 * File              : YMTheme.m
 * The four interface themes and the UIAppearance set-up for them.
 */

#import "YMTheme.h"
#import <QuartzCore/QuartzCore.h>

NSString * const YMThemeDidChangeNotification = @"YMThemeDidChangeNotification";
static NSString * const kThemeKey = @"theme";

@interface YMTheme ()
@property (readwrite) YMThemeKind kind;
@property (strong) UIColor *tabTitleSelected;
@property (strong, nonatomic) UIImage *noise;
@end

@implementation YMTheme

static YMTheme *current_theme = nil;

+ (YMTheme *)current
{
	if (!current_theme) {
		NSInteger kind = [[NSUserDefaults standardUserDefaults] integerForKey:kThemeKey];
		if (kind < 0 || kind >= YMThemeCount)
			kind = YMThemeOriginal;
		if (![[NSUserDefaults standardUserDefaults] objectForKey:kThemeKey])
			kind = YMThemeOriginal;
		current_theme = [self themeWithKind:(YMThemeKind)kind];
	}
	return current_theme;
}

+ (void)setCurrentKind:(YMThemeKind)kind
{
	[[NSUserDefaults standardUserDefaults] setInteger:kind forKey:kThemeKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
	current_theme = [self themeWithKind:kind];
	[current_theme applyAppearance];
	[[NSNotificationCenter defaultCenter] postNotificationName:YMThemeDidChangeNotification object:current_theme];
}

+ (YMTheme *)themeWithKind:(YMThemeKind)kind
{
	YMTheme *t = [[YMTheme alloc] init];
	t.kind = kind;
	t.navTitleShadowOffset = CGSizeMake(0, -1);
	t.statusBarStyle = UIStatusBarStyleDefault;
	t.spinnerStyle = UIActivityIndicatorViewStyleGray;
	t.keyboardAppearance = UIKeyboardAppearanceDefault;

	switch (kind) {
	case YMThemeClassic:
		t.name = @"Классика";
		t.subtitle = @"Голубой с белым, как в iOS 6";
		t.navTop = YMRGB(176, 188, 205);   t.navBottom = YMRGB(109, 132, 162);
		t.navLine = YMRGB(45, 62, 83);
		t.navTitle = [UIColor whiteColor]; t.navTitleShadow = YMRGBA(0, 0, 0, 0.45);
		t.buttonTop = YMRGB(146, 164, 190); t.buttonBottom = YMRGB(81, 106, 140);
		t.buttonBorder = YMRGB(52, 72, 99);
		t.buttonText = [UIColor whiteColor]; t.buttonTextShadow = YMRGBA(0, 0, 0, 0.45);
		t.tabTop = YMRGB(60, 60, 60);      t.tabBottom = YMRGB(0, 0, 0);
		t.tabLine = YMRGBA(255, 255, 255, 0.12);
		t.tabSelectedTop = YMRGB(120, 210, 255); t.tabSelectedBottom = YMRGB(24, 128, 218);
		t.tabUnselected = YMRGB(140, 140, 140); t.tabSelection = YMRGBA(255, 255, 255, 0.13);
		t.tabTitleSelected = [UIColor whiteColor];
		t.background = YMRGB(255, 255, 255); t.cell = YMRGB(255, 255, 255);
		t.cellSelectedTop = YMRGB(5, 140, 245); t.cellSelectedBottom = YMRGB(1, 93, 230);
		t.separator = YMRGB(224, 224, 224);
		t.text = YMRGB(0, 0, 0);           t.subtext = YMRGB(128, 128, 128);
		t.accent = YMRGB(52, 132, 230);    t.accentDark = YMRGB(24, 84, 180);
		t.accentText = [UIColor whiteColor];
		t.heroTop = YMRGB(96, 168, 240);   t.heroBottom = YMRGB(30, 92, 186);
		t.heroText = [UIColor whiteColor]; t.heroSubtext = YMRGBA(255, 255, 255, 0.75);
		t.panelTop = YMRGB(236, 239, 243); t.panelBottom = YMRGB(190, 197, 208);
		t.panelGlyph = YMRGB(44, 62, 90);  t.panelText = YMRGB(60, 72, 92);
		t.fieldTop = YMRGB(238, 241, 246); t.fieldBottom = YMRGB(255, 255, 255);
		t.fieldText = YMRGB(36, 52, 78);
		break;

	case YMThemeYandex:
		t.name = @"Яндекс";
		t.subtitle = @"Жёлтый с белым, классика Яндекса";
		t.navTop = YMRGB(255, 225, 72);    t.navBottom = YMRGB(255, 200, 0);
		t.navLine = YMRGB(214, 164, 0);
		t.navTitle = YMRGB(34, 34, 34);    t.navTitleShadow = YMRGBA(255, 255, 255, 0.55);
		t.navTitleShadowOffset = CGSizeMake(0, 1);
		t.buttonTop = YMRGB(255, 236, 140); t.buttonBottom = YMRGB(250, 205, 30);
		t.buttonBorder = YMRGB(196, 150, 0);
		t.buttonText = YMRGB(34, 34, 34);  t.buttonTextShadow = YMRGBA(255, 255, 255, 0.55);
		t.tabTop = YMRGB(255, 255, 255);   t.tabBottom = YMRGB(232, 232, 232);
		t.tabLine = YMRGB(205, 205, 205);
		t.tabSelectedTop = YMRGB(50, 50, 50); t.tabSelectedBottom = YMRGB(20, 20, 20);
		t.tabUnselected = YMRGB(150, 150, 150); t.tabSelection = YMRGB(255, 204, 0);
		t.tabTitleSelected = YMRGB(20, 20, 20);
		t.background = YMRGB(255, 255, 255); t.cell = YMRGB(255, 255, 255);
		t.cellSelectedTop = YMRGB(255, 222, 70); t.cellSelectedBottom = YMRGB(255, 200, 0);
		t.separator = YMRGB(232, 232, 232);
		t.text = YMRGB(34, 34, 34);        t.subtext = YMRGB(128, 128, 128);
		t.accent = YMRGB(255, 204, 0);     t.accentDark = YMRGB(240, 170, 0);
		t.accentText = YMRGB(34, 34, 34);
		t.heroTop = YMRGB(255, 226, 64);   t.heroBottom = YMRGB(255, 184, 0);
		t.heroText = YMRGB(34, 34, 34);    t.heroSubtext = YMRGBA(34, 34, 34, 0.7);
		t.panelTop = YMRGB(255, 255, 255); t.panelBottom = YMRGB(236, 236, 236);
		t.panelGlyph = YMRGB(34, 34, 34);  t.panelText = YMRGB(90, 90, 90);
		t.fieldTop = YMRGB(240, 240, 240); t.fieldBottom = YMRGB(255, 255, 255);
		t.fieldText = YMRGB(34, 34, 34);
		break;

	case YMThemeYandexDark:
		t.name = @"Яндекс Дарк";
		t.subtitle = @"Жёлтый с чёрным";
		t.navTop = YMRGB(56, 56, 56);      t.navBottom = YMRGB(22, 22, 22);
		t.navLine = YMRGB(0, 0, 0);
		t.navTitle = YMRGB(245, 245, 245); t.navTitleShadow = YMRGBA(0, 0, 0, 0.8);
		t.buttonTop = YMRGB(70, 70, 70);   t.buttonBottom = YMRGB(32, 32, 32);
		t.buttonBorder = YMRGB(0, 0, 0);
		t.buttonText = YMRGB(255, 204, 0); t.buttonTextShadow = YMRGBA(0, 0, 0, 0.8);
		t.tabTop = YMRGB(34, 34, 34);      t.tabBottom = YMRGB(6, 6, 6);
		t.tabLine = YMRGBA(255, 255, 255, 0.08);
		t.tabSelectedTop = YMRGB(255, 222, 70); t.tabSelectedBottom = YMRGB(255, 186, 0);
		t.tabUnselected = YMRGB(115, 115, 115); t.tabSelection = YMRGBA(255, 255, 255, 0.07);
		t.tabTitleSelected = YMRGB(255, 204, 0);
		t.background = YMRGB(18, 18, 18);  t.cell = YMRGB(28, 28, 28);
		t.cellSelectedTop = YMRGB(255, 218, 60); t.cellSelectedBottom = YMRGB(255, 190, 0);
		t.separator = YMRGB(48, 48, 48);
		t.text = YMRGB(240, 240, 240);     t.subtext = YMRGB(150, 150, 150);
		t.accent = YMRGB(255, 204, 0);     t.accentDark = YMRGB(230, 160, 0);
		t.accentText = YMRGB(20, 20, 20);
		t.heroTop = YMRGB(48, 44, 30);     t.heroBottom = YMRGB(16, 16, 16);
		t.heroText = YMRGB(255, 255, 255); t.heroSubtext = YMRGBA(255, 255, 255, 0.6);
		t.panelTop = YMRGB(44, 44, 44);    t.panelBottom = YMRGB(12, 12, 12);
		t.panelGlyph = YMRGB(235, 235, 235); t.panelText = YMRGB(170, 170, 170);
		t.fieldTop = YMRGB(20, 20, 20);    t.fieldBottom = YMRGB(40, 40, 40);
		t.fieldText = YMRGB(255, 204, 0);
		t.statusBarStyle = UIStatusBarStyleBlackOpaque;
		t.spinnerStyle = UIActivityIndicatorViewStyleWhite;
		t.keyboardAppearance = UIKeyboardAppearanceAlert;
		break;

	case YMThemeOriginal:
	default:
		t.name = @"Ориджинал";
		t.subtitle = @"Кожа и строчка, как на иконке";
		t.navTop = YMRGB(234, 172, 100);   t.navBottom = YMRGB(196, 124, 56);
		t.navLine = YMRGB(120, 70, 24);
		t.navTitle = YMRGB(78, 44, 10);    t.navTitleShadow = YMRGBA(255, 228, 185, 0.6);
		t.navTitleShadowOffset = CGSizeMake(0, 1);
		t.buttonTop = YMRGB(176, 108, 46); t.buttonBottom = YMRGB(140, 82, 30);
		t.buttonBorder = YMRGB(96, 54, 16);
		t.buttonText = YMRGB(255, 238, 210); t.buttonTextShadow = YMRGBA(60, 30, 5, 0.7);
		t.tabTop = YMRGB(96, 58, 26);      t.tabBottom = YMRGB(56, 32, 12);
		t.tabLine = YMRGB(36, 20, 6);
		t.tabSelectedTop = YMRGB(255, 218, 156); t.tabSelectedBottom = YMRGB(232, 158, 78);
		t.tabUnselected = YMRGB(170, 132, 96); t.tabSelection = YMRGBA(0, 0, 0, 0.22);
		t.tabTitleSelected = YMRGB(255, 212, 150);
		t.background = YMRGB(246, 236, 218); t.cell = YMRGB(252, 246, 234);
		t.cellSelectedTop = YMRGB(226, 160, 90); t.cellSelectedBottom = YMRGB(196, 122, 54);
		t.separator = YMRGB(228, 210, 182);
		t.text = YMRGB(78, 44, 10);        t.subtext = YMRGB(146, 110, 74);
		t.accent = YMRGB(214, 140, 66);    t.accentDark = YMRGB(160, 92, 32);
		t.accentText = YMRGB(255, 244, 226);
		t.heroTop = YMRGB(236, 172, 98);   t.heroBottom = YMRGB(192, 118, 50);
		t.heroText = YMRGB(78, 44, 10);    t.heroSubtext = YMRGBA(78, 44, 10, 0.7);
		t.panelTop = YMRGB(104, 64, 30);   t.panelBottom = YMRGB(58, 34, 12);
		t.panelGlyph = YMRGB(255, 220, 166); t.panelText = YMRGB(222, 182, 132);
		t.fieldTop = YMRGB(236, 222, 198); t.fieldBottom = YMRGB(252, 246, 234);
		t.fieldText = YMRGB(78, 44, 10);
		t.leather = YES;
		t.stitch = YMRGBA(255, 226, 178, 0.85);
		t.stitchHighlight = YMRGBA(60, 30, 4, 0.45);
		break;
	}
	if (kind == YMThemeClassic)
		t.metal = YES;
	return t;
}

- (UIImage *)noise
{
	if (!_noise)
		_noise = [YMDraw noiseTileWithAlpha:0.18];
	return _noise;
}

/* Fill the rect with the grain of the material, if the theme has one. */
- (void)grain:(CGRect)rect ctx:(CGContextRef)ctx strength:(CGFloat)strength
{
	if (!self.leather)
		return;
	CGContextSaveGState(ctx);
	CGContextSetAlpha(ctx, strength);
	CGContextSetFillColorWithColor(ctx, [UIColor colorWithPatternImage:self.noise].CGColor);
	CGContextFillRect(ctx, rect);
	CGContextRestoreGState(ctx);
}

/* Stitch colours for a dark or a light piece of leather. */
- (UIColor *)stitchOnDark { return self.stitch; }
- (UIColor *)stitchOnLight { return YMRGBA(110, 60, 18, 0.75); }

#pragma mark - backgrounds

- (UIColor *)backgroundPattern
{
	if (!self.leather)
		return self.background;
	UIColor *base = self.background;
	UIImage *tile = [YMDraw imageWithSize:self.noise.size opaque:YES drawing:^(CGContextRef ctx, CGRect rect) {
		[base setFill];
		CGContextFillRect(ctx, rect);
		CGContextSetAlpha(ctx, 0.35);
		[self.noise drawInRect:rect];
	}];
	return [UIColor colorWithPatternImage:tile];
}

- (UIImage *)navBackgroundWithHeight:(CGFloat)height
{
	return [YMDraw imageWithSize:CGSizeMake(64, height) opaque:YES drawing:^(CGContextRef ctx, CGRect rect) {
		[YMDraw fillRect:rect inContext:ctx colors:@[self.navTop, self.navBottom] locations:NULL];
		[self grain:rect ctx:ctx strength:0.7];
		if (self.kind == YMThemeYandexDark) {
			/* faint yellow glow along the bottom edge */
			[YMDraw fillRect:CGRectMake(0, height - 3, 64, 2) inContext:ctx
			          colors:@[YMRGBA(255, 204, 0, 0.0), YMRGBA(255, 204, 0, 0.35)] locations:NULL];
		}
		CGContextSetFillColorWithColor(ctx, YMRGBA(255, 255, 255, self.kind == YMThemeYandexDark ? 0.12 : 0.4).CGColor);
		CGContextFillRect(ctx, CGRectMake(0, 0, 64, 1));
		CGContextSetFillColorWithColor(ctx, self.navLine.CGColor);
		CGContextFillRect(ctx, CGRectMake(0, height - 1, 64, 1));
		if (self.leather)
			[YMDraw drawStitchLineFrom:CGPointMake(-2, height - 4.5) to:CGPointMake(66, height - 4.5)
			                     color:[self stitchOnLight] highlight:YMRGBA(255, 232, 196, 0.6) inContext:ctx];
	}];
}

- (UIImage *)tabBackground
{
	return [YMDraw imageWithSize:CGSizeMake(64, 49) opaque:YES drawing:^(CGContextRef ctx, CGRect rect) {
		if (self.kind == YMThemeClassic) {
			/* iOS 6 glossy black */
			[YMDraw fillRect:CGRectMake(0, 0, 64, 24) inContext:ctx
			          colors:@[YMRGB(78, 78, 78), YMRGB(40, 40, 40)] locations:NULL];
			[YMDraw fillRect:CGRectMake(0, 24, 64, 25) inContext:ctx
			          colors:@[YMRGB(18, 18, 18), YMRGB(0, 0, 0)] locations:NULL];
		} else {
			[YMDraw fillRect:rect inContext:ctx colors:@[self.tabTop, self.tabBottom] locations:NULL];
		}
		[self grain:rect ctx:ctx strength:0.9];
		CGContextSetFillColorWithColor(ctx, self.tabLine.CGColor);
		CGContextFillRect(ctx, CGRectMake(0, 0, 64, 1));
		if (self.leather)
			[YMDraw drawStitchLineFrom:CGPointMake(-2, 4.5) to:CGPointMake(66, 4.5)
			                     color:[self stitchOnDark] highlight:self.stitchHighlight inContext:ctx];
	}];
}

- (UIImage *)tabSelectionImage
{
	UIImage *img = [YMDraw imageWithSize:CGSizeMake(24, 44) opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		CGRect r = CGRectInset(rect, 2, 3);
		UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:6];
		if (self.kind == YMThemeYandex) {
			[YMDraw fillPath:p inContext:ctx colors:@[YMRGB(255, 220, 60), YMRGB(255, 196, 0)]];
			[YMRGBA(200, 150, 0, 0.8) setStroke];
			[p stroke];
		} else {
			[self.tabSelection setFill];
			[p fill];
			if (self.leather) {
				CGContextSaveGState(ctx);
				[p addClip];
				CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 3, YMRGBA(0, 0, 0, 0.6).CGColor);
				UIBezierPath *frame = [UIBezierPath bezierPathWithRect:CGRectInset(r, -6, -6)];
				[frame appendPath:[p bezierPathByReversingPath]];
				[frame fill];
				CGContextRestoreGState(ctx);
			}
		}
	}];
	return [img resizableImageWithCapInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
}

#pragma mark - controls

- (UIImage *)barButtonImagePressed:(BOOL)pressed back:(BOOL)back height:(CGFloat)height
{
	CGFloat w = back ? 32 : 20;
	UIImage *img = [YMDraw imageWithSize:CGSizeMake(w, height) opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		CGRect r = CGRectMake(0.5, 0.5, w - 1, height - 2);
		UIBezierPath *p;
		if (back) {
			CGFloat mid = CGRectGetMidY(r), arrow = 11;
			p = [UIBezierPath bezierPath];
			[p moveToPoint:CGPointMake(r.origin.x, mid)];
			[p addLineToPoint:CGPointMake(r.origin.x + arrow, r.origin.y + 1)];
			[p addLineToPoint:CGPointMake(CGRectGetMaxX(r) - 5, r.origin.y)];
			[p addQuadCurveToPoint:CGPointMake(CGRectGetMaxX(r), r.origin.y + 5) controlPoint:CGPointMake(CGRectGetMaxX(r), r.origin.y)];
			[p addLineToPoint:CGPointMake(CGRectGetMaxX(r), CGRectGetMaxY(r) - 5)];
			[p addQuadCurveToPoint:CGPointMake(CGRectGetMaxX(r) - 5, CGRectGetMaxY(r)) controlPoint:CGPointMake(CGRectGetMaxX(r), CGRectGetMaxY(r))];
			[p addLineToPoint:CGPointMake(r.origin.x + arrow, CGRectGetMaxY(r) - 1)];
			[p closePath];
			p.lineJoinStyle = kCGLineJoinRound;
		} else {
			p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:5];
		}
		/* bottom highlight ("pressed into the bar") */
		CGContextSaveGState(ctx);
		CGContextTranslateCTM(ctx, 0, 1);
		[YMRGBA(255, 255, 255, self.kind == YMThemeYandexDark ? 0.08 : 0.3) setFill];
		[p fill];
		CGContextRestoreGState(ctx);

		UIColor *top = self.buttonTop, *bottom = self.buttonBottom;
		if (pressed) {
			top = [YMDraw blend:top with:[UIColor blackColor] amount:0.22];
			bottom = [YMDraw blend:bottom with:[UIColor blackColor] amount:0.22];
		}
		[YMDraw fillPath:p inContext:ctx colors:@[top, bottom]];
		if (self.leather) {
			CGContextSaveGState(ctx);
			[p addClip];
			CGContextSetAlpha(ctx, 0.6);
			CGContextSetFillColorWithColor(ctx, [UIColor colorWithPatternImage:self.noise].CGColor);
			CGContextFillRect(ctx, rect);
			CGContextRestoreGState(ctx);
		}
		/* inner top highlight */
		CGContextSaveGState(ctx);
		[p addClip];
		[YMDraw fillRect:CGRectMake(0, 0, w, height / 2) inContext:ctx
		          colors:@[YMRGBA(255, 255, 255, pressed ? 0.05 : 0.22), YMRGBA(255, 255, 255, 0.02)] locations:NULL];
		CGContextRestoreGState(ctx);
		[self.buttonBorder setStroke];
		p.lineWidth = 1;
		[p stroke];
	}];
	if (back)
		return [img resizableImageWithCapInsets:UIEdgeInsetsMake(0, 14, 0, 7)];
	return [img resizableImageWithCapInsets:UIEdgeInsetsMake(0, 7, 0, 7)];
}

- (UIImage *)tabGlyph:(YMGlyph)glyph selected:(BOOL)selected
{
	if (selected)
		return [YMDraw glyph:glyph size:26 top:self.tabSelectedTop bottom:self.tabSelectedBottom
		              shadow:YMRGBA(0, 0, 0, self.kind == YMThemeYandex ? 0.15 : 0.6) offset:CGSizeMake(0, -1)];
	UIColor *shadow = (self.kind == YMThemeYandex) ? YMRGBA(255, 255, 255, 0.9) : YMRGBA(0, 0, 0, 0.6);
	return [YMDraw glyph:glyph size:26 top:self.tabUnselected bottom:self.tabUnselected
	              shadow:shadow offset:CGSizeMake(0, self.kind == YMThemeYandex ? 1 : -1)];
}

- (UIImage *)roundButtonWithDiameter:(CGFloat)d glyph:(YMGlyph)glyph
                              accent:(BOOL)accent pressed:(BOOL)pressed
{
	return [YMDraw imageWithSize:CGSizeMake(d + 4, d + 4) opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		CGRect r = CGRectMake(2, 1, d, d);
		UIBezierPath *outer = [UIBezierPath bezierPathWithOvalInRect:r];

		/* drop shadow */
		CGContextSaveGState(ctx);
		CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1.5), 3, YMRGBA(0, 0, 0, 0.45).CGColor);
		[self.buttonBorder setFill];
		[outer fill];
		CGContextRestoreGState(ctx);

		UIColor *top, *bottom, *glyphColor;
		if (accent) {
			top = [YMDraw blend:self.accent with:[UIColor whiteColor] amount:0.35];
			bottom = self.accentDark;
			glyphColor = self.accentText;
		} else if (self.leather) {
			top = YMRGB(150, 94, 44); bottom = YMRGB(92, 54, 20);
			glyphColor = self.panelGlyph;
		} else {
			top = [YMDraw blend:self.panelTop with:[UIColor whiteColor] amount:0.5];
			bottom = self.panelBottom;
			glyphColor = self.panelGlyph;
		}
		if (pressed) {
			top = [YMDraw blend:top with:[UIColor blackColor] amount:0.2];
			bottom = [YMDraw blend:bottom with:[UIColor blackColor] amount:0.2];
		}
		CGRect inner = CGRectInset(r, 1.5, 1.5);
		UIBezierPath *face = [UIBezierPath bezierPathWithOvalInRect:inner];
		[YMDraw fillPath:face inContext:ctx colors:@[top, bottom]];
		if (self.leather) {
			CGContextSaveGState(ctx);
			[face addClip];
			CGContextSetAlpha(ctx, 0.7);
			CGContextSetFillColorWithColor(ctx, [UIColor colorWithPatternImage:self.noise].CGColor);
			CGContextFillRect(ctx, inner);
			CGContextRestoreGState(ctx);
			[YMDraw drawStitchInRect:CGRectInset(inner, 4, 4) radius:(d - 11) / 2
			                   color:accent ? [self stitchOnLight] : [self stitchOnDark]
			               highlight:nil inContext:ctx];
		}
		/* gloss */
		if (!pressed) {
			CGContextSaveGState(ctx);
			[face addClip];
			CGRect gloss = CGRectMake(inner.origin.x - inner.size.width * 0.15, inner.origin.y - inner.size.height * 0.45,
			                          inner.size.width * 1.3, inner.size.height * 0.95);
			UIBezierPath *g = [UIBezierPath bezierPathWithOvalInRect:gloss];
			[YMDraw fillPath:g inContext:ctx colors:@[YMRGBA(255, 255, 255, 0.55), YMRGBA(255, 255, 255, 0.08)]];
			CGContextRestoreGState(ctx);
		}
		CGFloat gs = d * 0.42;
		CGRect gr = CGRectMake(CGRectGetMidX(r) - gs / 2 + (glyph == YMGlyphPlay ? d * 0.03 : 0),
		                       CGRectGetMidY(r) - gs / 2, gs, gs);
		UIBezierPath *gp = [YMDraw pathForGlyph:glyph inRect:gr];
		CGContextSaveGState(ctx);
		CGContextTranslateCTM(ctx, 0, 1);
		BOOL darkGlyph = accent ? (self.kind == YMThemeYandex || self.kind == YMThemeYandexDark) : (self.kind != YMThemeYandexDark && !self.leather);
		[(darkGlyph ? YMRGBA(255, 255, 255, 0.5) : YMRGBA(0, 0, 0, 0.5)) setFill];
		[gp fill];
		CGContextRestoreGState(ctx);
		[glyphColor setFill];
		[gp fill];
	}];
}

- (UIImage *)pillButtonPressed:(BOOL)pressed accent:(BOOL)accent
{
	UIImage *img = [YMDraw imageWithSize:CGSizeMake(40, 46) opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		CGRect r = CGRectMake(1, 1, 38, 42);
		UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:10];
		CGContextSaveGState(ctx);
		CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 1.5, YMRGBA(0, 0, 0, 0.35).CGColor);
		[(accent ? self.accentDark : self.buttonBorder) setFill];
		[p fill];
		CGContextRestoreGState(ctx);

		UIColor *top = accent ? [YMDraw blend:self.accent with:[UIColor whiteColor] amount:0.3] : [YMDraw blend:self.cell with:[UIColor whiteColor] amount:0.4];
		UIColor *bottom = accent ? self.accentDark : [YMDraw blend:self.cell with:[UIColor blackColor] amount:0.1];
		if (pressed) {
			top = [YMDraw blend:top with:[UIColor blackColor] amount:0.18];
			bottom = [YMDraw blend:bottom with:[UIColor blackColor] amount:0.18];
		}
		UIBezierPath *face = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(r, 1, 1) cornerRadius:9];
		[YMDraw fillPath:face inContext:ctx colors:@[top, bottom]];
		if (self.leather) {
			CGContextSaveGState(ctx);
			[face addClip];
			CGContextSetAlpha(ctx, 0.6);
			CGContextSetFillColorWithColor(ctx, [UIColor colorWithPatternImage:self.noise].CGColor);
			CGContextFillRect(ctx, r);
			CGContextRestoreGState(ctx);
			[YMDraw drawStitchInRect:CGRectInset(r, 4, 4) radius:6
			                   color:accent ? self.stitch : [self stitchOnLight] highlight:nil inContext:ctx];
		}
		if (!pressed) {
			CGContextSaveGState(ctx);
			[face addClip];
			[YMDraw fillRect:CGRectMake(0, 0, 40, 22) inContext:ctx
			          colors:@[YMRGBA(255, 255, 255, 0.4), YMRGBA(255, 255, 255, 0.1)] locations:NULL];
			CGContextRestoreGState(ctx);
		}
	}];
	return [img resizableImageWithCapInsets:UIEdgeInsetsMake(12, 12, 12, 12)];
}

- (UIImage *)cardImageWithRadius:(CGFloat)radius
{
	CGFloat m = 5, side = radius * 2 + m * 2 + 12;
	UIImage *img = [YMDraw imageWithSize:CGSizeMake(side, side) opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		CGRect r = CGRectInset(rect, m, m);
		UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius];
		CGContextSaveGState(ctx);
		CGContextSetShadowWithColor(ctx, CGSizeMake(0, 2), 4, YMRGBA(0, 0, 0, self.kind == YMThemeYandexDark ? 0.8 : 0.3).CGColor);
		[self.cell setFill];
		[p fill];
		CGContextRestoreGState(ctx);
		if (self.leather) {
			UIColor *top = YMRGB(240, 186, 120), *bottom = YMRGB(214, 146, 78);
			[YMDraw fillPath:p inContext:ctx colors:@[top, bottom]];
			CGContextSaveGState(ctx);
			[p addClip];
			CGContextSetAlpha(ctx, 0.7);
			CGContextSetFillColorWithColor(ctx, [UIColor colorWithPatternImage:self.noise].CGColor);
			CGContextFillRect(ctx, r);
			CGContextRestoreGState(ctx);
			[YMDraw drawStitchInRect:CGRectInset(r, 5, 5) radius:MAX(radius - 4, 2)
			                   color:[self stitchOnLight] highlight:YMRGBA(255, 232, 196, 0.6) inContext:ctx];
		} else {
			[YMDraw fillPath:p inContext:ctx colors:@[[YMDraw blend:self.cell with:[UIColor whiteColor] amount:0.06], self.cell]];
			[(self.kind == YMThemeYandexDark ? YMRGBA(255, 255, 255, 0.08) : YMRGBA(0, 0, 0, 0.12)) setStroke];
			[p stroke];
		}
	}];
	CGFloat cap = radius + m + 1;
	return [img resizableImageWithCapInsets:UIEdgeInsetsMake(cap, cap, cap, cap)];
}

- (UIImage *)heroImageWithSize:(CGSize)size
{
	return [YMDraw imageWithSize:size opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		CGRect r = CGRectInset(rect, 4, 4);
		r.size.height -= 2;
		UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:12];
		CGContextSaveGState(ctx);
		CGContextSetShadowWithColor(ctx, CGSizeMake(0, 2), 4, YMRGBA(0, 0, 0, 0.4).CGColor);
		[self.heroBottom setFill];
		[p fill];
		CGContextRestoreGState(ctx);

		CGContextSaveGState(ctx);
		[p addClip];
		[YMDraw fillRect:r inContext:ctx colors:@[self.heroTop, self.heroBottom] locations:NULL];
		[self grain:r ctx:ctx strength:0.8];

		/* concentric "wave" rings radiating from the play button */
		CGPoint c = CGPointMake(CGRectGetMaxX(r) - 62, CGRectGetMidY(r));
		UIColor *ring = (self.kind == YMThemeYandexDark) ? YMRGBA(255, 204, 0, 1) :
		                (self.kind == YMThemeYandex || self.leather) ? YMRGBA(255, 255, 255, 1) : YMRGBA(255, 255, 255, 1);
		for (int i = 1; i <= 9; ++i) {
			UIBezierPath *circle = [UIBezierPath bezierPathWithArcCenter:c radius:28 + i * 16 startAngle:0 endAngle:2 * M_PI clockwise:YES];
			circle.lineWidth = 2;
			[[ring colorWithAlphaComponent:0.28 - i * 0.025] setStroke];
			[circle stroke];
		}
		/* top gloss */
		[YMDraw fillRect:CGRectMake(r.origin.x, r.origin.y, r.size.width, r.size.height * 0.45) inContext:ctx
		          colors:@[YMRGBA(255, 255, 255, 0.25), YMRGBA(255, 255, 255, 0.04)] locations:NULL];
		CGContextRestoreGState(ctx);

		if (self.leather)
			[YMDraw drawStitchInRect:CGRectInset(r, 5, 5) radius:8
			                   color:[self stitchOnLight] highlight:YMRGBA(255, 232, 196, 0.6) inContext:ctx];
		else {
			[YMRGBA(0, 0, 0, 0.18) setStroke];
			[p stroke];
		}
	}];
}

- (UIImage *)panelImageWithSize:(CGSize)size
{
	return [YMDraw imageWithSize:size opaque:YES drawing:^(CGContextRef ctx, CGRect rect) {
		[YMDraw fillRect:rect inContext:ctx colors:@[self.panelTop, self.panelBottom] locations:NULL];
		if (self.metal) {
			CGContextSaveGState(ctx);
			CGContextSetAlpha(ctx, 0.5);
			CGContextSetFillColorWithColor(ctx, [UIColor colorWithPatternImage:[YMDraw brushedTileWithAlpha:0.12]].CGColor);
			CGContextFillRect(ctx, rect);
			CGContextRestoreGState(ctx);
		}
		[self grain:rect ctx:ctx strength:1.0];
		CGContextSetFillColorWithColor(ctx, (self.kind == YMThemeYandexDark ? YMRGBA(255, 255, 255, 0.1) : YMRGBA(255, 255, 255, 0.6)).CGColor);
		CGContextFillRect(ctx, CGRectMake(0, 1, size.width, 1));
		CGContextSetFillColorWithColor(ctx, YMRGBA(0, 0, 0, 0.45).CGColor);
		CGContextFillRect(ctx, CGRectMake(0, 0, size.width, 1));
		if (self.leather)
			[YMDraw drawStitchLineFrom:CGPointMake(0, 6.5) to:CGPointMake(size.width, 6.5)
			                     color:[self stitchOnDark] highlight:self.stitchHighlight inContext:ctx];
	}];
}

- (UIImage *)fieldImage
{
	UIImage *img = [YMDraw imageWithSize:CGSizeMake(30, 50) opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		CGRect r = CGRectMake(0.5, 0.5, 29, 48);
		UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:8];
		CGContextSaveGState(ctx);
		CGContextTranslateCTM(ctx, 0, 1);
		[YMRGBA(255, 255, 255, self.kind == YMThemeYandexDark ? 0.08 : 0.5) setFill];
		[p fill];
		CGContextRestoreGState(ctx);
		[YMDraw fillPath:p inContext:ctx colors:@[self.fieldTop, self.fieldBottom]];
		/* inner shadow */
		CGContextSaveGState(ctx);
		[p addClip];
		CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1.5), 3, YMRGBA(0, 0, 0, 0.45).CGColor);
		UIBezierPath *frame = [UIBezierPath bezierPathWithRect:CGRectInset(r, -8, -8)];
		[frame appendPath:[p bezierPathByReversingPath]];
		[[UIColor blackColor] setFill];
		[frame fill];
		CGContextRestoreGState(ctx);
		[YMRGBA(0, 0, 0, 0.3) setStroke];
		[p stroke];
	}];
	return [img resizableImageWithCapInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
}

- (UIImage *)sliderTrack:(BOOL)filled
{
	UIImage *img = [YMDraw imageWithSize:CGSizeMake(14, 10) opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		CGRect r = CGRectMake(0.5, 1, 13, 7);
		UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:3.5];
		CGContextSaveGState(ctx);
		CGContextTranslateCTM(ctx, 0, 1);
		[YMRGBA(255, 255, 255, self.kind == YMThemeYandexDark || self.leather ? 0.12 : 0.6) setFill];
		[p fill];
		CGContextRestoreGState(ctx);
		if (filled)
			[YMDraw fillPath:p inContext:ctx colors:@[[YMDraw blend:self.accent with:[UIColor whiteColor] amount:0.3], self.accentDark]];
		else
			[YMDraw fillPath:p inContext:ctx colors:@[YMRGBA(0, 0, 0, 0.45), YMRGBA(0, 0, 0, 0.2)]];
		[YMRGBA(0, 0, 0, 0.35) setStroke];
		[p stroke];
	}];
	return [img resizableImageWithCapInsets:UIEdgeInsetsMake(0, 6, 0, 6)];
}

- (UIImage *)sliderThumb
{
	return [YMDraw imageWithSize:CGSizeMake(26, 26) opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		CGRect r = CGRectMake(3, 2, 20, 20);
		UIBezierPath *p = [UIBezierPath bezierPathWithOvalInRect:r];
		CGContextSaveGState(ctx);
		CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1.5), 2, YMRGBA(0, 0, 0, 0.55).CGColor);
		[YMRGB(120, 120, 120) setFill];
		[p fill];
		CGContextRestoreGState(ctx);
		NSArray *colors = self.leather ? @[YMRGB(255, 226, 180), YMRGB(206, 140, 70)] :
		                  (self.kind == YMThemeYandex || self.kind == YMThemeYandexDark) ? @[YMRGB(255, 236, 140), YMRGB(246, 190, 0)] :
		                  @[YMRGB(255, 255, 255), YMRGB(196, 200, 206)];
		[YMDraw fillPath:[UIBezierPath bezierPathWithOvalInRect:CGRectInset(r, 0.5, 0.5)] inContext:ctx colors:colors];
		UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(10.5, 9.5, 5, 5)];
		[YMDraw fillPath:dot inContext:ctx colors:@[YMRGBA(0, 0, 0, 0.3), YMRGBA(255, 255, 255, 0.4)]];
	}];
}

- (UIImage *)coverPlaceholderWithSize:(CGSize)size
{
	return [YMDraw imageWithSize:size opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		UIColor *base = [YMDraw blend:self.cell with:self.subtext amount:0.18];
		[YMDraw fillRect:rect inContext:ctx colors:@[[YMDraw blend:base with:[UIColor whiteColor] amount:0.1], base] locations:NULL];
		CGFloat g = MIN(size.width, size.height) * 0.4;
		UIBezierPath *p = [YMDraw pathForGlyph:YMGlyphNote
				inRect:CGRectMake((size.width - g) / 2, (size.height - g) / 2, g, g)];
		[[self.subtext colorWithAlphaComponent:0.5] setFill];
		[p fill];
	}];
}

- (UIBarButtonItem *)barButtonWithGlyph:(YMGlyph)glyph target:(id)target action:(SEL)action
{
	UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
	b.frame = CGRectMake(0, 0, 38, 31);
	[b setBackgroundImage:[self barButtonImagePressed:NO back:NO height:31] forState:UIControlStateNormal];
	[b setBackgroundImage:[self barButtonImagePressed:YES back:NO height:31] forState:UIControlStateHighlighted];
	[b setImage:[YMDraw glyph:glyph size:18 top:self.buttonText bottom:self.buttonText
	                   shadow:self.buttonTextShadow offset:self.navTitleShadowOffset] forState:UIControlStateNormal];
	b.imageEdgeInsets = UIEdgeInsetsMake(-1, 0, 1, 0);
	b.adjustsImageWhenHighlighted = NO;
	[b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
	return [[UIBarButtonItem alloc] initWithCustomView:b];
}

#pragma mark - appearance

- (void)applyAppearance
{
	UIApplication *app = [UIApplication sharedApplication];
	[app setStatusBarStyle:self.statusBarStyle animated:NO];

	/* navigation bar */
	UINavigationBar *nav = [UINavigationBar appearance];
	[nav setBackgroundImage:[self navBackgroundWithHeight:44] forBarMetrics:UIBarMetricsDefault];
	[nav setBackgroundImage:[self navBackgroundWithHeight:32] forBarMetrics:UIBarMetricsLandscapePhone];
	[nav setTintColor:self.buttonBottom];
	[nav setTitleTextAttributes:@{
		UITextAttributeTextColor: self.navTitle,
		UITextAttributeTextShadowColor: self.navTitleShadow,
		UITextAttributeTextShadowOffset: [NSValue valueWithUIOffset:UIOffsetMake(self.navTitleShadowOffset.width, self.navTitleShadowOffset.height)],
		UITextAttributeFont: [UIFont boldSystemFontOfSize:20],
	}];
	if ([nav respondsToSelector:@selector(setShadowImage:)])
		[nav setShadowImage:[[UIImage alloc] init]];

	/* bar buttons */
	UIBarButtonItem *item = [UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil];
	[item setBackgroundImage:[self barButtonImagePressed:NO back:NO height:31] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
	[item setBackgroundImage:[self barButtonImagePressed:YES back:NO height:31] forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
	[item setBackgroundImage:[self barButtonImagePressed:NO back:NO height:25] forState:UIControlStateNormal barMetrics:UIBarMetricsLandscapePhone];
	[item setBackgroundImage:[self barButtonImagePressed:YES back:NO height:25] forState:UIControlStateHighlighted barMetrics:UIBarMetricsLandscapePhone];
	[item setBackButtonBackgroundImage:[self barButtonImagePressed:NO back:YES height:31] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
	[item setBackButtonBackgroundImage:[self barButtonImagePressed:YES back:YES height:31] forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
	[item setBackButtonBackgroundImage:[self barButtonImagePressed:NO back:YES height:25] forState:UIControlStateNormal barMetrics:UIBarMetricsLandscapePhone];
	[item setBackButtonBackgroundImage:[self barButtonImagePressed:YES back:YES height:25] forState:UIControlStateHighlighted barMetrics:UIBarMetricsLandscapePhone];
	NSDictionary *buttonText = @{
		UITextAttributeTextColor: self.buttonText,
		UITextAttributeTextShadowColor: self.buttonTextShadow,
		UITextAttributeTextShadowOffset: [NSValue valueWithUIOffset:UIOffsetMake(self.navTitleShadowOffset.width, self.navTitleShadowOffset.height)],
		UITextAttributeFont: [UIFont boldSystemFontOfSize:12],
	};
	[item setTitleTextAttributes:buttonText forState:UIControlStateNormal];
	[item setTitleTextAttributes:buttonText forState:UIControlStateHighlighted];
	[item setTintColor:self.buttonBottom];

	/* toolbar */
	UIToolbar *toolbar = [UIToolbar appearance];
	[toolbar setBackgroundImage:[self navBackgroundWithHeight:44] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
	[toolbar setBackgroundImage:[self navBackgroundWithHeight:32] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsLandscapePhone];
	[toolbar setTintColor:self.buttonBottom];

	/* tab bar */
	UITabBar *tab = [UITabBar appearance];
	[tab setBackgroundImage:[self tabBackground]];
	[tab setSelectionIndicatorImage:[self tabSelectionImage]];
	[tab setSelectedImageTintColor:self.tabSelectedBottom];
	if ([tab respondsToSelector:@selector(setShadowImage:)])
		[tab setShadowImage:[[UIImage alloc] init]];
	UITabBarItem *tabItem = [UITabBarItem appearance];
	[tabItem setTitleTextAttributes:@{
		UITextAttributeTextColor: self.tabUnselected,
		UITextAttributeTextShadowColor: (self.kind == YMThemeYandex) ? YMRGBA(255, 255, 255, 0.9) : YMRGBA(0, 0, 0, 0.6),
		UITextAttributeTextShadowOffset: [NSValue valueWithUIOffset:UIOffsetMake(0, self.kind == YMThemeYandex ? 1 : -1)],
		UITextAttributeFont: [UIFont boldSystemFontOfSize:10],
	} forState:UIControlStateNormal];
	[tabItem setTitleTextAttributes:@{
		UITextAttributeTextColor: self.tabTitleSelected,
	} forState:UIControlStateSelected];

	/* search bar */
	UISearchBar *search = [UISearchBar appearance];
	[search setBackgroundImage:[self navBackgroundWithHeight:44]];
	[search setTintColor:self.buttonBottom];
	UIImage *field = [YMDraw imageWithSize:CGSizeMake(30, 30) opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.5, 0.5, 29, 28) cornerRadius:14];
		CGContextSaveGState(ctx);
		CGContextTranslateCTM(ctx, 0, 1);
		[YMRGBA(255, 255, 255, 0.35) setFill];
		[p fill];
		CGContextRestoreGState(ctx);
		[YMDraw fillPath:p inContext:ctx colors:@[YMRGB(232, 232, 232), YMRGB(255, 255, 255)]];
		[YMRGBA(0, 0, 0, 0.35) setStroke];
		[p stroke];
	}];
	[search setSearchFieldBackgroundImage:[field resizableImageWithCapInsets:UIEdgeInsetsMake(14, 14, 14, 14)]
	                             forState:UIControlStateNormal];

	/* sliders and switches */
	[[UISwitch appearance] setOnTintColor:self.accent];
	[[UIRefreshControl appearance] setTintColor:self.subtext];
}

#pragma mark - tables

- (void)styleTableView:(UITableView *)tableView
{
	UIView *bg = [[UIView alloc] initWithFrame:tableView.bounds];
	bg.backgroundColor = [self backgroundPattern];
	tableView.backgroundView = bg;
	tableView.backgroundColor = self.background;
	tableView.separatorColor = self.separator;
	tableView.indicatorStyle = (self.kind == YMThemeYandexDark) ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleDefault;
}

- (UIView *)sectionHeaderWithTitle:(NSString *)title width:(CGFloat)width grouped:(BOOL)grouped
{
	CGFloat h = grouped ? 38 : 24;
	UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, h)];
	if (!grouped) {
		UIImageView *bg = [[UIImageView alloc] initWithFrame:v.bounds];
		bg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		bg.image = [YMDraw imageWithSize:CGSizeMake(8, h) opaque:YES drawing:^(CGContextRef ctx, CGRect rect) {
			UIColor *base = self.leather ? YMRGB(214, 160, 100) : [YMDraw blend:self.cell with:self.subtext amount:0.25];
			[YMDraw fillRect:rect inContext:ctx colors:@[[YMDraw blend:base with:[UIColor whiteColor] amount:0.15], base] locations:NULL];
			[self grain:rect ctx:ctx strength:0.6];
			CGContextSetFillColorWithColor(ctx, YMRGBA(0, 0, 0, 0.15).CGColor);
			CGContextFillRect(ctx, CGRectMake(0, h - 1, 8, 1));
		}];
		bg.alpha = 0.95;
		[v addSubview:bg];
	}
	UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(grouped ? 20 : 12, grouped ? 12 : 2, width - 40, 20)];
	l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	l.backgroundColor = [UIColor clearColor];
	l.font = [UIFont boldSystemFontOfSize:grouped ? 17 : 15];
	l.text = title;
	l.textColor = self.text;
	l.shadowColor = (self.kind == YMThemeYandexDark) ? YMRGBA(0, 0, 0, 0.9) : YMRGBA(255, 255, 255, 0.7);
	l.shadowOffset = CGSizeMake(0, 1);
	[v addSubview:l];
	return v;
}

- (UIImage *)selectedCellImage
{
	return [YMDraw imageWithSize:CGSizeMake(8, 44) opaque:YES drawing:^(CGContextRef ctx, CGRect rect) {
		[YMDraw fillRect:rect inContext:ctx colors:@[self.cellSelectedTop, self.cellSelectedBottom] locations:NULL];
		[self grain:rect ctx:ctx strength:0.6];
		CGContextSetFillColorWithColor(ctx, YMRGBA(255, 255, 255, 0.25).CGColor);
		CGContextFillRect(ctx, CGRectMake(0, 0, 8, 1));
	}];
}

- (void)styleCell:(UITableViewCell *)cell
{
	cell.backgroundColor = self.cell;
	if (![cell.selectedBackgroundView isKindOfClass:[UIImageView class]] ||
	    cell.selectedBackgroundView.tag != (NSInteger)self.kind + 100) {
		UIImageView *sel = [[UIImageView alloc] initWithImage:
				[[self selectedCellImage] resizableImageWithCapInsets:UIEdgeInsetsMake(2, 0, 2, 0)]];
		sel.tag = (NSInteger)self.kind + 100;
		cell.selectedBackgroundView = sel;
	}
	cell.textLabel.backgroundColor = [UIColor clearColor];
	cell.detailTextLabel.backgroundColor = [UIColor clearColor];
	cell.textLabel.textColor = self.text;
	cell.detailTextLabel.textColor = self.subtext;
	cell.textLabel.highlightedTextColor = self.accentText;
	cell.detailTextLabel.highlightedTextColor = self.accentText;
	cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
	cell.imageView.layer.cornerRadius = 4;
	cell.imageView.layer.masksToBounds = YES;
	if ([cell.accessoryView isKindOfClass:[UIActivityIndicatorView class]])
		[(UIActivityIndicatorView *)cell.accessoryView setActivityIndicatorViewStyle:self.spinnerStyle];
}

- (void)styleController:(UIViewController *)controller
{
	if ([controller isKindOfClass:[UITableViewController class]]) {
		UITableViewController *tvc = (UITableViewController *)controller;
		[self styleTableView:tvc.tableView];
		tvc.refreshControl.tintColor = self.subtext;
		for (UIView *v in tvc.tableView.subviews)
			if ([v isKindOfClass:[UIActivityIndicatorView class]])
				[(UIActivityIndicatorView *)v setActivityIndicatorViewStyle:self.spinnerStyle];
	} else {
		controller.view.backgroundColor = [self backgroundPattern];
	}
}

@end

// vim:ft=objc

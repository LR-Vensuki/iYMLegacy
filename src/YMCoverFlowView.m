/**
 * File              : YMCoverFlowView.m
 * iPod-style Cover Flow carousel of tracks, and a flat shelf of playlists.
 */

#import "YMCoverFlowView.h"
#import "YMTheme.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat kReflection = 0.32;
static const CGFloat kSideAngle = 1.2;   /* ~70 degrees */

@interface YMCoverFlowView ()
@property (strong) UIView *stage;
@property (strong) UIScrollView *scroll;
@property (strong) NSMutableArray *covers;
@property (strong) UILabel *titleLabel;
@property (strong) UILabel *subtitleLabel;
@property (strong) UIImage *placeholder;
@property (readwrite) NSInteger selectedIndex;
@end

@implementation YMCoverFlowView

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		self.backgroundColor = [UIColor clearColor];
		self.clipsToBounds = YES;
		_coverSize = 130;
		self.covers = [NSMutableArray array];

		self.stage = [[UIView alloc] initWithFrame:self.bounds];
		self.stage.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		CATransform3D perspective = CATransform3DIdentity;
		perspective.m34 = -1.0 / 520.0;
		self.stage.layer.sublayerTransform = perspective;
		[self addSubview:self.stage];

		self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		for (UILabel *l in @[self.titleLabel, self.subtitleLabel]) {
			l.backgroundColor = [UIColor clearColor];
			l.textAlignment = NSTextAlignmentCenter;
			l.shadowOffset = CGSizeMake(0, 1);
			[self addSubview:l];
		}
		self.titleLabel.font = [UIFont boldSystemFontOfSize:15];
		self.subtitleLabel.font = [UIFont systemFontOfSize:13];

		self.scroll = [[UIScrollView alloc] initWithFrame:self.bounds];
		self.scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.scroll.backgroundColor = [UIColor clearColor];
		self.scroll.showsHorizontalScrollIndicator = NO;
		self.scroll.decelerationRate = UIScrollViewDecelerationRateFast;
		self.scroll.delegate = self;
		self.scroll.scrollsToTop = NO;
		[self addSubview:self.scroll];

		UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
		[self.scroll addGestureRecognizer:tap];
		UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pressed:)];
		[self.scroll addGestureRecognizer:press];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(coverLoaded:)
				name:YMItemCoverDidLoadNotification object:nil];
		[self reloadTheme];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reloadTheme
{
	YMTheme *t = [YMTheme current];
	self.titleLabel.textColor = t.text;
	self.subtitleLabel.textColor = t.subtext;
	UIColor *emboss = (t.kind == YMThemeYandexDark) ? YMRGBA(0, 0, 0, 0.9) : YMRGBA(255, 255, 255, 0.7);
	self.titleLabel.shadowColor = emboss;
	self.subtitleLabel.shadowColor = emboss;
	self.placeholder = [YMDraw reflectedImage:[t coverPlaceholderWithSize:CGSizeMake(self.coverSize, self.coverSize)]
	                                     size:CGSizeMake(self.coverSize, self.coverSize) fraction:kReflection];
	[self reloadImages];
}

- (CGFloat)spacing { return self.coverSize * 0.62; }
- (CGFloat)sideOffset { return self.coverSize * 0.78; }
- (CGFloat)sideSpacing { return self.coverSize * 0.26; }

- (void)setItems:(NSArray *)items
{
	_items = [items copy];
	for (UIView *v in self.covers)
		[v removeFromSuperview];
	[self.covers removeAllObjects];
	for (NSUInteger i = 0; i < _items.count; ++i) {
		UIImageView *v = [[UIImageView alloc] initWithFrame:CGRectZero];
		v.layer.anchorPoint = CGPointMake(0.5, 0.5 / (1 + kReflection));
		v.layer.shouldRasterize = NO;
		v.layer.doubleSided = NO;
		[self.covers addObject:v];
		[self.stage addSubview:v];
	}
	[self reloadImages];
	[self setNeedsLayout];
	[self layoutIfNeeded];
}

- (UIImage *)coverImageForItem:(Item *)item
{
	if (!item.coverImage)
		return self.placeholder;
	return [YMDraw reflectedImage:item.coverImage size:CGSizeMake(self.coverSize, self.coverSize) fraction:kReflection];
}

- (void)reloadImages
{
	for (NSUInteger i = 0; i < self.covers.count && i < self.items.count; ++i)
		[[self.covers objectAtIndex:i] setImage:[self coverImageForItem:[self.items objectAtIndex:i]]];
}

- (void)coverLoaded:(NSNotification *)n
{
	NSUInteger i = [self.items indexOfObjectIdenticalTo:n.object];
	if (i == NSNotFound || i >= self.covers.count)
		return;
	[[self.covers objectAtIndex:i] setImage:[self coverImageForItem:n.object]];
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	CGSize b = self.bounds.size;
	self.scroll.contentSize = CGSizeMake(b.width + MAX(0, (NSInteger)self.items.count - 1) * [self spacing], b.height);
	CGFloat captionY = 10 + self.coverSize + self.coverSize * kReflection * 0.45;
	self.titleLabel.frame = CGRectMake(10, captionY, b.width - 20, 19);
	self.subtitleLabel.frame = CGRectMake(10, captionY + 19, b.width - 20, 17);
	[self layoutCovers];
}

- (void)layoutCovers
{
	CGSize b = self.bounds.size;
	CGFloat S = self.coverSize;
	CGFloat position = self.scroll.contentOffset.x / [self spacing];
	CGPoint base = CGPointMake(b.width / 2, 10 + S / 2);

	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	for (NSUInteger i = 0; i < self.covers.count; ++i) {
		UIImageView *v = [self.covers objectAtIndex:i];
		CGFloat d = i - position;
		CGFloat ad = fabs(d);
		if (ad > 7) {
			v.hidden = YES;
			continue;
		}
		v.hidden = NO;
		v.bounds = CGRectMake(0, 0, S, S * (1 + kReflection));
		v.layer.position = base;
		CGFloat sign = d < 0 ? -1 : 1;
		CGFloat x, angle, z;
		if (ad <= 1) {
			x = d * [self sideOffset];
			angle = -d * kSideAngle;
			z = (1 - ad) * S * 0.32;
		} else {
			x = sign * ([self sideOffset] + (ad - 1) * [self sideSpacing]);
			angle = -sign * kSideAngle;
			z = 0;
		}
		CATransform3D t = CATransform3DMakeTranslation(x, 0, z);
		t = CATransform3DRotate(t, angle, 0, 1, 0);
		v.layer.transform = t;
		v.layer.zPosition = -ad;
		v.alpha = ad > 5 ? MAX(0, 6 - ad) : 1;
	}
	[CATransaction commit];

	NSInteger index = (NSInteger)lround(position);
	index = MAX(0, MIN(index, (NSInteger)self.items.count - 1));
	if (self.items.count && (index != self.selectedIndex || !self.titleLabel.text.length)) {
		self.selectedIndex = index;
		Item *item = [self.items objectAtIndex:index];
		self.titleLabel.text = item.title;
		self.subtitleLabel.text = item.subtitle;
	} else if (!self.items.count) {
		self.titleLabel.text = nil;
		self.subtitleLabel.text = nil;
	}
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	[self layoutCovers];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity
              targetContentOffset:(inout CGPoint *)target
{
	CGFloat s = [self spacing];
	CGFloat index = round(target->x / s);
	index = MAX(0, MIN(index, (CGFloat)self.items.count - 1));
	target->x = index * s;
}

- (void)scrollToIndex:(NSInteger)index
{
	[self.scroll setContentOffset:CGPointMake(index * [self spacing], 0) animated:YES];
}

- (NSInteger)indexAtPoint:(CGPoint)p
{
	CGFloat dx = p.x - self.scroll.contentOffset.x - self.bounds.size.width / 2;
	if (fabs(dx) < self.coverSize / 2)
		return self.selectedIndex;
	CGFloat side = (fabs(dx) - [self sideOffset]) / [self sideSpacing];
	NSInteger steps = 1 + (NSInteger)MAX(0, round(side));
	NSInteger index = self.selectedIndex + (dx < 0 ? -steps : steps);
	return MAX(0, MIN(index, (NSInteger)self.items.count - 1));
}

- (void)tapped:(UITapGestureRecognizer *)g
{
	if (!self.items.count)
		return;
	CGPoint p = [g locationInView:self.scroll];
	if (p.y - self.scroll.contentOffset.y > 10 + self.coverSize + 40)
		return;
	NSInteger index = [self indexAtPoint:p];
	if (index == self.selectedIndex) {
		UIView *v = [self.covers objectAtIndex:index];
		CATransform3D t = v.layer.transform;
		[UIView animateWithDuration:0.1 animations:^{
			v.layer.transform = CATransform3DScale(t, 0.95, 0.95, 1);
		} completion:^(BOOL finished) {
			[UIView animateWithDuration:0.1 animations:^{ v.layer.transform = t; }];
		}];
		if (self.onTap)
			self.onTap([self.items objectAtIndex:index], index);
	} else {
		[self scrollToIndex:index];
	}
}

- (void)pressed:(UILongPressGestureRecognizer *)g
{
	if (g.state != UIGestureRecognizerStateBegan || !self.items.count)
		return;
	NSInteger index = [self indexAtPoint:[g locationInView:self.scroll]];
	if (index == self.selectedIndex && self.onLongPress)
		self.onLongPress([self.items objectAtIndex:index], index);
}

@end

#pragma mark - shelf

@interface YMShelfView ()
@property (strong) NSMutableArray *tiles;
@end

@implementation YMShelfView

static const CGFloat kTileCover = 100;
static const CGFloat kTileWidth = 112;

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		self.showsHorizontalScrollIndicator = NO;
		self.alwaysBounceHorizontal = YES;
		self.scrollsToTop = NO;
		self.backgroundColor = [UIColor clearColor];
		self.tiles = [NSMutableArray array];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(coverLoaded:)
				name:YMItemCoverDidLoadNotification object:nil];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (UIImage *)coverForItem:(Item *)item
{
	YMTheme *t = [YMTheme current];
	CGSize size = CGSizeMake(kTileCover, kTileCover);
	UIImage *image = item.coverImage ? item.coverImage : [t coverPlaceholderWithSize:size];
	return [YMDraw imageWithSize:CGSizeMake(kTileCover + 8, kTileCover + 8) opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		CGRect r = CGRectMake(4, 2, kTileCover, kTileCover);
		UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:6];
		CGContextSaveGState(ctx);
		CGContextSetShadowWithColor(ctx, CGSizeMake(0, 2), 3, YMRGBA(0, 0, 0, 0.45).CGColor);
		[[UIColor blackColor] setFill];
		[p fill];
		CGContextRestoreGState(ctx);
		CGContextSaveGState(ctx);
		[p addClip];
		[image drawInRect:r];
		/* glossy sheen, like the iTunes shelf */
		[YMDraw fillRect:CGRectMake(r.origin.x, r.origin.y, r.size.width, r.size.height * 0.5) inContext:ctx
		          colors:@[YMRGBA(255, 255, 255, 0.28), YMRGBA(255, 255, 255, 0.0)] locations:NULL];
		CGContextRestoreGState(ctx);
		[YMRGBA(0, 0, 0, 0.25) setStroke];
		[p stroke];
	}];
}

- (void)setItems:(NSArray *)items
{
	_items = [items copy];
	for (UIView *v in self.tiles)
		[v removeFromSuperview];
	[self.tiles removeAllObjects];
	YMTheme *t = [YMTheme current];
	UIColor *emboss = (t.kind == YMThemeYandexDark) ? YMRGBA(0, 0, 0, 0.9) : YMRGBA(255, 255, 255, 0.7);
	for (NSUInteger i = 0; i < _items.count; ++i) {
		Item *item = [_items objectAtIndex:i];
		UIButton *tile = [UIButton buttonWithType:UIButtonTypeCustom];
		tile.frame = CGRectMake(8 + i * kTileWidth, 4, kTileWidth, kTileCover + 46);
		tile.tag = i;
		[tile addTarget:self action:@selector(tileTapped:) forControlEvents:UIControlEventTouchUpInside];
		UIImageView *cover = [[UIImageView alloc] initWithImage:[self coverForItem:item]];
		cover.frame = CGRectMake(0, 0, kTileCover + 8, kTileCover + 8);
		cover.tag = 1001;
		[tile addSubview:cover];
		UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(4, kTileCover + 8, kTileCover, 34)];
		title.backgroundColor = [UIColor clearColor];
		title.numberOfLines = 2;
		title.font = [UIFont boldSystemFontOfSize:12];
		title.textColor = t.text;
		title.shadowColor = emboss;
		title.shadowOffset = CGSizeMake(0, 1);
		title.text = item.title;
		[tile addSubview:title];
		[self.tiles addObject:tile];
		[self addSubview:tile];
	}
	self.contentSize = CGSizeMake(16 + _items.count * kTileWidth, self.bounds.size.height);
}

- (void)reloadTheme
{
	[self setItems:self.items];
}

- (void)coverLoaded:(NSNotification *)n
{
	NSUInteger i = [self.items indexOfObjectIdenticalTo:n.object];
	if (i == NSNotFound || i >= self.tiles.count)
		return;
	UIImageView *cover = (UIImageView *)[[self.tiles objectAtIndex:i] viewWithTag:1001];
	cover.image = [self coverForItem:n.object];
}

- (void)tileTapped:(UIButton *)sender
{
	if (self.onTap && sender.tag < (NSInteger)self.items.count)
		self.onTap([self.items objectAtIndex:sender.tag], sender.tag);
}

@end

// vim:ft=objc

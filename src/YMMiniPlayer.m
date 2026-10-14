/*
 * The bar above the tabs that shows what is playing, like Apple Music:
 * tap it to open the player, play/pause and next work in place.
 */
#import "YMMiniPlayer.h"
#import <QuartzCore/QuartzCore.h>
#import <MediaPlayer/MediaPlayer.h>
#import "AppDelegate.h"
#import "YMTheme.h"

@interface YMMiniPlayer ()
@property (strong) UIImageView *background;
@property (strong) UIImageView *art;
@property (strong) UILabel *titleLabel;
@property (strong) UILabel *artistLabel;
@property (strong) UIButton *playButton;
@property (strong) UIButton *nextButton;
@property (strong) UIView *progress;
@property (strong) NSTimer *timer;
@end

@implementation YMMiniPlayer

- (PlayerController *)player
{
	return ((AppDelegate *)[UIApplication sharedApplication].delegate).player;
}

- (UIButton *)button:(SEL)action
{
	UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
	b.showsTouchWhenHighlighted = YES;
	[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	[self addSubview:b];
	return b;
}

- (UILabel *)label:(UIFont *)font color:(UIColor *)color
{
	YMTheme *t = [YMTheme current];
	UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
	l.backgroundColor = [UIColor clearColor];
	l.font = font;
	l.textColor = color;
	BOOL light = (t.kind == YMThemeClassic || t.kind == YMThemeYandex);
	l.shadowColor = light ? YMRGBA(255, 255, 255, 0.7) : YMRGBA(0, 0, 0, 0.7);
	l.shadowOffset = CGSizeMake(0, light ? 1 : -1);
	[self addSubview:l];
	return l;
}

- (id)initWithFrame:(CGRect)frame
{
	if (!(self = [super initWithFrame:frame]))
		return nil;
	YMTheme *t = [YMTheme current];
	self.clipsToBounds = YES;

	self.background = [[UIImageView alloc] initWithFrame:self.bounds];
	self.background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self addSubview:self.background];

	self.art = [[UIImageView alloc] initWithFrame:CGRectMake(8, 9, 34, 34)];
	self.art.contentMode = UIViewContentModeScaleAspectFill;
	self.art.clipsToBounds = YES;
	self.art.layer.cornerRadius = 3;
	self.art.layer.borderWidth = 1;
	self.art.layer.borderColor = YMRGBA(0, 0, 0, 0.35).CGColor;
	[self addSubview:self.art];

	self.titleLabel = [self label:[UIFont boldSystemFontOfSize:14] color:t.panelText];
	self.artistLabel = [self label:[UIFont systemFontOfSize:12] color:[t.panelText colorWithAlphaComponent:0.75]];

	self.playButton = [self button:@selector(playPause:)];
	self.nextButton = [self button:@selector(next:)];
	[self.nextButton setImage:[YMDraw glyph:YMGlyphNext size:22 color:t.panelGlyph] forState:UIControlStateNormal];

	self.progress = [[UIView alloc] initWithFrame:CGRectZero];
	self.progress.backgroundColor = t.accent;
	[self addSubview:self.progress];

	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(open:)];
	[self addGestureRecognizer:tap];
	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
	[self addGestureRecognizer:pan];

	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(changed:) name:YMPlayerTrackDidChangeNotification object:nil];
	[nc addObserver:self selector:@selector(changed:) name:YMPlayerStateDidChangeNotification object:nil];
	[nc addObserver:self selector:@selector(changed:) name:YMItemArtDidLoadNotification object:nil];
	[nc addObserver:self selector:@selector(changed:) name:YMItemCoverDidLoadNotification object:nil];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self.timer invalidate];
}

- (void)willMoveToWindow:(UIWindow *)window
{
	[self.timer invalidate];
	self.timer = window ? [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick:)
	                                                     userInfo:nil repeats:YES] : nil;
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	CGSize b = self.bounds.size;
	if (!CGSizeEqualToSize(self.background.image.size, b))
		self.background.image = [[YMTheme current] panelImageWithSize:b];
	BOOL leather = [YMTheme current].leather;
	CGFloat top = leather ? 5 : 0;
	self.art.frame = CGRectMake(8, top + floor((b.height - top - 34) / 2), 34, 34);
	CGFloat tx = CGRectGetMaxX(self.art.frame) + 10;
	self.nextButton.frame = CGRectMake(b.width - 44, top, 44, b.height - top);
	self.playButton.frame = CGRectMake(b.width - 88, top, 44, b.height - top);
	CGFloat tw = CGRectGetMinX(self.playButton.frame) - tx - 4;
	CGFloat mid = top + (b.height - top) / 2;
	self.titleLabel.frame = CGRectMake(tx, mid - 18, tw, 18);
	self.artistLabel.frame = CGRectMake(tx, mid, tw, 16);
	[self tick:nil];
}

- (void)refresh
{
	YMTheme *t = [YMTheme current];
	PlayerController *player = [self player];
	Item *item = player.nowPlaying;
	self.titleLabel.text = item ? item.title : @"Ничего не играет";
	self.artistLabel.text = item.subtitle;
	UIImage *art = item.coverImage ? item.coverImage : item.artImage;
	self.art.image = art ? art : [t coverPlaceholderWithSize:CGSizeMake(34, 34)];
	BOOL playing = item && player.playbackState == MPMoviePlaybackStatePlaying;
	[self.playButton setImage:[YMDraw glyph:playing ? YMGlyphPause : YMGlyphPlay size:26 color:t.panelGlyph]
	                 forState:UIControlStateNormal];
	[self tick:nil];
}

- (void)tick:(NSTimer *)timer
{
	PlayerController *player = [self player];
	NSTimeInterval d = player.duration, p = player.currentPlaybackTime;
	CGFloat f = (player.nowPlaying && d > 0 && !isnan(p)) ? MIN(1, MAX(0, p / d)) : 0;
	self.progress.frame = CGRectMake(0, self.bounds.size.height - 2, floor(self.bounds.size.width * f), 2);
}

- (void)changed:(NSNotification *)n
{
	[self refresh];
}

- (void)open:(UITapGestureRecognizer *)tap
{
	if (self.onOpen)
		self.onOpen();
}

- (void)drag:(UIPanGestureRecognizer *)pan
{
	if (self.onDrag)
		self.onDrag(pan);
}

- (void)playPause:(id)sender
{
	[[self player] togglePlayPause];
}

- (void)next:(id)sender
{
	[[self player] next];
}

@end

// vim:ft=objc

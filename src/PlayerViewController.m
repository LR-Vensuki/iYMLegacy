/**
 * File              : PlayerViewController.m
 * Author            : Igor V. Sementsov <ig.kuzm@gmail.com>
 * Date              : 22.08.2023
 * Last Modified Date: 13.09.2023
 * Last Modified By  : Igor V. Sementsov <ig.kuzm@gmail.com>
 *
 * Now Playing: artwork that flips over to the queue like the iPod, the
 * scrubber, transport controls, shuffle/repeat, like and volume.
 */
#import "PlayerViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <MediaPlayer/MediaPlayer.h>
#include "Item.h"
#import "YMTheme.h"
#import "YMCoverFlowView.h"
#import "../cYandexMusic/cYandexMusic.h"

@interface PlayerViewController ()
@property (strong) YMCoverFlowView *flow;
@property NSInteger flowOffset;
@property CGRect artRect;
@property (strong) UITableView *queueTable;
@property BOOL showingQueue;
@property (strong) UILabel *stationLabel;
@property (strong) UILabel *titleLabel;
@property (strong) UILabel *artistLabel;
@property (strong) UIButton *likeButton;
@property (strong) UIImageView *panel;
@property (strong) UISlider *scrubber;
@property (strong) UILabel *elapsedLabel;
@property (strong) UILabel *remainingLabel;
@property (strong) UIButton *playButton;
@property (strong) UIButton *prevButton;
@property (strong) UIButton *nextButton;
@property (strong) UIButton *shuffleButton;
@property (strong) UIButton *repeatButton;
@property (strong) MPVolumeView *volume;
@property (strong) NSTimer *timer;
@property BOOL scrubbing;
@end

@implementation PlayerViewController

- (id)init
{
	if ((self = [super init]))
		self.title = @"Сейчас играет";
	return self;
}

- (UIButton *)roundButton:(YMGlyph)glyph diameter:(CGFloat)d accent:(BOOL)accent action:(SEL)action
{
	YMTheme *t = [YMTheme current];
	UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
	b.frame = CGRectMake(0, 0, d + 4, d + 4);
	b.adjustsImageWhenHighlighted = NO;
	[b setImage:[t roundButtonWithDiameter:d glyph:glyph accent:accent pressed:NO] forState:UIControlStateNormal];
	[b setImage:[t roundButtonWithDiameter:d glyph:glyph accent:accent pressed:YES] forState:UIControlStateHighlighted];
	[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	return b;
}

- (UIButton *)smallButtonWithAction:(SEL)action
{
	UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
	b.frame = CGRectMake(0, 0, 40, 40);
	b.showsTouchWhenHighlighted = YES;
	[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	return b;
}

- (UILabel *)label:(UIFont *)font color:(UIColor *)color
{
	UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
	l.backgroundColor = [UIColor clearColor];
	l.font = font;
	l.textColor = color;
	l.textAlignment = NSTextAlignmentCenter;
	return l;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	YMTheme *t = [YMTheme current];
	self.appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	self.token = [[NSUserDefaults standardUserDefaults] valueForKey:@"token"];
	self.doLike = [[NSOperationQueue alloc] init];
	self.view.backgroundColor = [t backgroundPattern];

	self.navigationItem.rightBarButtonItem = [t barButtonWithGlyph:YMGlyphQueue target:self action:@selector(flip:)];

	/* what plays and what comes next, as Cover Flow; it flips over to the queue list */
	__weak PlayerViewController *weakSelf = self;
	self.flow = [[YMCoverFlowView alloc] initWithFrame:CGRectMake(0, 0, 320, 260)];
	self.flow.hidesCaption = YES;
	self.flow.prefersArtwork = YES;
	self.flow.onTap = ^(Item *item, NSInteger index) { [weakSelf flip:nil]; };
	self.flow.onSelect = ^(Item *item, NSInteger index) { [weakSelf flowSelected:index]; };
	self.flow.onLongPress = ^(Item *item, NSInteger index) { [weakSelf flip:nil]; };
	[self.view addSubview:self.flow];

	self.queueTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
	self.queueTable.dataSource = self;
	self.queueTable.delegate = self;
	self.queueTable.rowHeight = 48;
	[t styleTableView:self.queueTable];
	self.queueTable.layer.borderWidth = 1;
	self.queueTable.layer.borderColor = YMRGBA(0, 0, 0, 0.35).CGColor;

	/* track info */
	self.stationLabel = [self label:[UIFont boldSystemFontOfSize:11] color:t.leather ? t.accentDark : t.accent];
	if (t.kind == YMThemeYandex) self.stationLabel.textColor = YMRGB(200, 150, 0);
	self.titleLabel = [self label:[UIFont boldSystemFontOfSize:17] color:t.text];
	self.artistLabel = [self label:[UIFont systemFontOfSize:14] color:t.subtext];
	UIColor *emboss = (t.kind == YMThemeYandexDark) ? YMRGBA(0, 0, 0, 0.9) : YMRGBA(255, 255, 255, 0.75);
	for (UILabel *l in @[self.stationLabel, self.titleLabel, self.artistLabel]) {
		l.shadowColor = emboss;
		l.shadowOffset = CGSizeMake(0, 1);
		[self.view addSubview:l];
	}
	self.likeButton = [self smallButtonWithAction:@selector(likeIsPushed:)];
	[self.view addSubview:self.likeButton];

	/* control panel */
	self.panel = [[UIImageView alloc] initWithFrame:CGRectZero];
	self.panel.userInteractionEnabled = YES;
	[self.view addSubview:self.panel];

	self.scrubber = [[UISlider alloc] initWithFrame:CGRectZero];
	[self.scrubber setMinimumTrackImage:[t sliderTrack:YES] forState:UIControlStateNormal];
	[self.scrubber setMaximumTrackImage:[t sliderTrack:NO] forState:UIControlStateNormal];
	[self.scrubber setThumbImage:[t sliderThumb] forState:UIControlStateNormal];
	[self.scrubber addTarget:self action:@selector(scrubStart:) forControlEvents:UIControlEventTouchDown];
	[self.scrubber addTarget:self action:@selector(scrubMove:) forControlEvents:UIControlEventValueChanged];
	[self.scrubber addTarget:self action:@selector(scrubEnd:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
	[self.panel addSubview:self.scrubber];

	UIColor *panelShadow = (t.kind == YMThemeClassic || t.kind == YMThemeYandex) ? YMRGBA(255, 255, 255, 0.8) : YMRGBA(0, 0, 0, 0.7);
	self.elapsedLabel = [self label:[UIFont boldSystemFontOfSize:11] color:t.panelText];
	self.remainingLabel = [self label:[UIFont boldSystemFontOfSize:11] color:t.panelText];
	for (UILabel *l in @[self.elapsedLabel, self.remainingLabel]) {
		l.shadowColor = panelShadow;
		l.shadowOffset = CGSizeMake(0, (t.kind == YMThemeClassic || t.kind == YMThemeYandex) ? 1 : -1);
		[self.panel addSubview:l];
	}

	self.prevButton = [self roundButton:YMGlyphPrev diameter:44 accent:NO action:@selector(prev:)];
	self.nextButton = [self roundButton:YMGlyphNext diameter:44 accent:NO action:@selector(next:)];
	self.playButton = [self roundButton:YMGlyphPlay diameter:58 accent:YES action:@selector(playPause:)];
	self.shuffleButton = [self smallButtonWithAction:@selector(toggleShuffle:)];
	self.repeatButton = [self smallButtonWithAction:@selector(toggleRepeat:)];
	for (UIView *v in @[self.prevButton, self.nextButton, self.playButton, self.shuffleButton, self.repeatButton])
		[self.panel addSubview:v];

	self.volume = [[MPVolumeView alloc] initWithFrame:CGRectZero];
	self.volume.showsRouteButton = YES;
	if ([self.volume respondsToSelector:@selector(setVolumeThumbImage:forState:)]) {
		[self.volume setMinimumVolumeSliderImage:[t sliderTrack:YES] forState:UIControlStateNormal];
		[self.volume setMaximumVolumeSliderImage:[t sliderTrack:NO] forState:UIControlStateNormal];
		[self.volume setVolumeThumbImage:[t sliderThumb] forState:UIControlStateNormal];
	}
	[self.panel addSubview:self.volume];

	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(trackDidChange:) name:YMPlayerTrackDidChangeNotification object:nil];
	[nc addObserver:self selector:@selector(stateDidChange:) name:YMPlayerStateDidChangeNotification object:nil];
	[nc addObserver:self selector:@selector(queueDidChange:) name:YMPlayerQueueDidChangeNotification object:nil];
	[nc addObserver:self selector:@selector(artDidLoad:) name:YMItemArtDidLoadNotification object:nil];
	[nc addObserver:self selector:@selector(artDidLoad:) name:YMItemCoverDidLoadNotification object:nil];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self.timer invalidate];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.token = [[NSUserDefaults standardUserDefaults] valueForKey:@"token"];
	[self.appDelegate.player setDelegate:self];
	[self refreshTrack];
	[self refreshControls];
	[self.queueTable reloadData];
	[self.timer invalidate];
	self.timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
	[self tick:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self.timer invalidate];
	self.timer = nil;
}

#pragma mark - layout

- (void)viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];
	CGSize b = self.view.bounds.size;
	/* the iPad has room to stack everything in either orientation */
	BOOL landscape = !YMIsPad() && b.width > b.height;
	CGFloat panelH = 128;
	CGFloat infoH = 58;

	CGRect art, info, panel;
	if (!landscape) {
		CGFloat side = MIN(b.width - 40, b.height - panelH - infoH - 18);
		if (YMIsPad())
			side = MIN(side, 460);
		side = MAX(side, 80);
		CGFloat top = MAX(10, floor((b.height - panelH - infoH - side) / 2) - 2);
		art = CGRectMake(floor((b.width - side) / 2), top, side, side);
		info = CGRectMake(0, CGRectGetMaxY(art) + 4, b.width, infoH);
		panel = CGRectMake(0, b.height - panelH, b.width, panelH);
	} else {
		CGFloat side = b.height - 20;
		art = CGRectMake(12, 10, side, side);
		CGFloat rx = CGRectGetMaxX(art) + 8;
		panel = CGRectMake(rx, b.height - panelH, b.width - rx, panelH);
		info = CGRectMake(rx, MAX(4, (b.height - panelH - infoH) / 2), b.width - rx, infoH);
	}
	self.artRect = art;
	/* the cover in the middle sits exactly on %art, neighbours peek in from the sides */
	CGFloat flowW = landscape ? (art.origin.x + art.size.width / 2) * 2 : b.width;
	CGFloat cover = floor(art.size.width * 0.84);
	self.flow.frame = CGRectMake(0, art.origin.y - 10, flowW, art.size.height + 14);
	self.flow.coverSize = cover;
	self.queueTable.frame = art;
	[self syncFlow:NO];

	self.stationLabel.frame = CGRectMake(info.origin.x + 44, info.origin.y, info.size.width - 88, 14);
	self.titleLabel.frame = CGRectMake(info.origin.x + 44, info.origin.y + 15, info.size.width - 88, 22);
	self.artistLabel.frame = CGRectMake(info.origin.x + 44, info.origin.y + 37, info.size.width - 88, 18);
	self.likeButton.center = CGPointMake(CGRectGetMaxX(info) - 26, info.origin.y + 30);

	if (!CGSizeEqualToSize(self.panel.frame.size, panel.size))
		self.panel.image = [[YMTheme current] panelImageWithSize:panel.size];
	self.panel.frame = panel;
	CGFloat w = panel.size.width;
	/* on the iPad the scrubber and volume keep a comfortable length in the middle */
	CGFloat cw = YMIsPad() ? MIN(w, 600) : w;
	CGFloat cx = floor((w - cw) / 2);
	self.elapsedLabel.frame = CGRectMake(cx + 4, 14, 44, 16);
	self.remainingLabel.frame = CGRectMake(cx + cw - 48, 14, 44, 16);
	self.scrubber.frame = CGRectMake(cx + 50, 10, cw - 100, 24);

	CGFloat row = 66;
	self.playButton.center = CGPointMake(w / 2, row);
	self.prevButton.center = CGPointMake(w / 2 - 70, row);
	self.nextButton.center = CGPointMake(w / 2 + 70, row);
	self.shuffleButton.center = CGPointMake(MAX(26, w / 2 - 130), row);
	self.repeatButton.center = CGPointMake(MIN(w - 26, w / 2 + 130), row);
	self.volume.frame = CGRectMake(cx + 24, panel.size.height - 30, cw - 48, 24);
}

#pragma mark - state

- (void)refreshTrack
{
	PlayerController *player = self.appDelegate.player;
	Item *item = player.nowPlaying;
	self.current = item;
	if (!item) {
		self.titleLabel.text = @"Ничего не играет";
		self.artistLabel.text = @"Выберите трек или включите Мою волну";
		self.stationLabel.text = nil;
		self.likeButton.hidden = YES;
		[self syncFlow:NO];
		return;
	}
	self.likeButton.hidden = NO;
	self.titleLabel.text = item.title;
	self.artistLabel.text = item.albumTitle.length
		? [NSString stringWithFormat:@"%@ — %@", item.subtitle, item.albumTitle] : item.subtitle;
	NSString *position = player.playlist.count > 1
		? [NSString stringWithFormat:@"%d ИЗ %d", (int)player.current + 1, (int)player.playlist.count] : nil;
	if ([player.station isEqualToString:YMStationMyWave])
		self.stationLabel.text = @"МОЯ ВОЛНА";
	else if ([player.station hasPrefix:@"track:"])
		self.stationLabel.text = @"МОЯ ВОЛНА ПО ТРЕКУ";
	else if (player.contextTitle.length)
		self.stationLabel.text = [(position ? [NSString stringWithFormat:@"%@ · %@", player.contextTitle, position]
		                                    : player.contextTitle) uppercaseString];
	else
		self.stationLabel.text = position;
	[self showArtFor:item];
	[self checkTrackIsLiked:item];
}

- (void)showArtFor:(Item *)item
{
	[self syncFlow:YES];
}

/* Show a window of the queue around the current track: what was played on
 * the left, what comes next on the right (My Wave or the playlist). */
- (void)syncFlow:(BOOL)animated
{
	PlayerController *player = self.appDelegate.player;
	NSArray *queue = [player.playlist copy];
	NSInteger current = MAX(0, MIN(player.current, (NSInteger)queue.count - 1));
	if (!queue.count) {
		self.flowOffset = 0;
		if (self.flow.items.count)
			self.flow.items = @[];
		return;
	}
	NSInteger first = MAX(0, current - 10);
	NSInteger last = MIN((NSInteger)queue.count, current + 30);
	NSArray *window = [queue subarrayWithRange:NSMakeRange(first, last - first)];
	if (first != self.flowOffset || ![window isEqualToArray:self.flow.items]) {
		self.flowOffset = first;
		self.flow.items = window;
		[self.flow showIndex:current - first animated:NO];
	} else if (self.flow.selectedIndex != current - first) {
		[self.flow showIndex:current - first animated:animated];
	}
}

- (void)flowSelected:(NSInteger)index
{
	PlayerController *player = self.appDelegate.player;
	NSInteger target = self.flowOffset + index;
	if (target != player.current)
		[player playIndex:target onDone:NULL];
}

- (void)refreshControls
{
	YMTheme *t = [YMTheme current];
	PlayerController *player = self.appDelegate.player;
	BOOL playing = player.nowPlaying && player.playbackState == MPMoviePlaybackStatePlaying;
	YMGlyph g = playing ? YMGlyphPause : YMGlyphPlay;
	[self.playButton setImage:[t roundButtonWithDiameter:58 glyph:g accent:YES pressed:NO] forState:UIControlStateNormal];
	[self.playButton setImage:[t roundButtonWithDiameter:58 glyph:g accent:YES pressed:YES] forState:UIControlStateHighlighted];

	UIColor *on = (t.kind == YMThemeYandex) ? YMRGB(220, 160, 0) : (t.leather ? t.panelGlyph : t.accent);
	UIColor *off = [t.panelGlyph colorWithAlphaComponent:0.4];
	UIColor *shadow = (t.kind == YMThemeClassic || t.kind == YMThemeYandex) ? YMRGBA(255, 255, 255, 0.8) : YMRGBA(0, 0, 0, 0.7);
	CGSize offset = CGSizeMake(0, (t.kind == YMThemeClassic || t.kind == YMThemeYandex) ? 1 : -1);

	BOOL station = player.station != nil;
	self.shuffleButton.enabled = !station;
	self.repeatButton.enabled = !station;
	UIColor *sc = (player.shuffle && !station) ? on : off;
	[self.shuffleButton setImage:[YMDraw glyph:YMGlyphShuffle size:22 top:sc bottom:sc shadow:shadow offset:offset]
	                    forState:UIControlStateNormal];
	YMGlyph rg = (player.queueRepeat == YMRepeatOne) ? YMGlyphRepeatOne : YMGlyphRepeat;
	UIColor *rc = (player.queueRepeat != YMRepeatOff && !station) ? on : off;
	[self.repeatButton setImage:[YMDraw glyph:rg size:22 top:rc bottom:rc shadow:shadow offset:offset]
	                   forState:UIControlStateNormal];
	self.shuffleButton.alpha = station ? 0.4 : 1;
	self.repeatButton.alpha = station ? 0.4 : 1;
}

- (void)tick:(NSTimer *)timer
{
	PlayerController *player = self.appDelegate.player;
	NSTimeInterval duration = player.nowPlaying ? player.duration : 0;
	NSTimeInterval position = player.nowPlaying ? player.currentPlaybackTime : 0;
	if (isnan(duration) || duration <= 0) duration = 0;
	if (isnan(position) || position < 0) position = 0;
	self.scrubber.enabled = duration > 0;
	if (!self.scrubbing) {
		self.scrubber.value = duration > 0 ? position / duration : 0;
		self.elapsedLabel.text = [YMDraw formatTime:position];
		self.remainingLabel.text = [@"-" stringByAppendingString:[YMDraw formatTime:duration - position]];
	}
}

- (void)trackDidChange:(NSNotification *)n
{
	[self refreshTrack];
	[self refreshControls];
	[self.queueTable reloadData];
	[self scrollQueueToCurrent];
}

- (void)stateDidChange:(NSNotification *)n
{
	[self refreshControls];
}

- (void)queueDidChange:(NSNotification *)n
{
	[self.queueTable reloadData];
	[self refreshControls];
	if (self.current)
		[self refreshTrack];
}

- (void)artDidLoad:(NSNotification *)n
{
	if (n.object == self.current)
		[self showArtFor:self.current];
}

#pragma mark - actions

- (void)playPause:(id)sender { [self.appDelegate.player togglePlayPause]; [self refreshControls]; }
- (void)next:(id)sender { [self.appDelegate.player next]; }
- (void)prev:(id)sender { [self.appDelegate.player prev]; [self tick:nil]; }

- (void)toggleShuffle:(id)sender
{
	PlayerController *player = self.appDelegate.player;
	player.shuffle = !player.shuffle;
	[self refreshControls];
}

- (void)toggleRepeat:(id)sender
{
	PlayerController *player = self.appDelegate.player;
	player.queueRepeat = (YMRepeatMode)((player.queueRepeat + 1) % 3);
	[self refreshControls];
}

- (void)scrubStart:(UISlider *)s { self.scrubbing = YES; }

- (void)scrubMove:(UISlider *)s
{
	NSTimeInterval duration = self.appDelegate.player.duration;
	if (isnan(duration) || duration <= 0) return;
	self.elapsedLabel.text = [YMDraw formatTime:s.value * duration];
	self.remainingLabel.text = [@"-" stringByAppendingString:[YMDraw formatTime:(1 - s.value) * duration]];
}

- (void)scrubEnd:(UISlider *)s
{
	NSTimeInterval duration = self.appDelegate.player.duration;
	if (!isnan(duration) && duration > 0)
		self.appDelegate.player.currentPlaybackTime = s.value * duration;
	self.scrubbing = NO;
}

/* Flip the artwork over to the queue, like the iPod. */
- (void)flip:(id)sender
{
	UIView *from = self.showingQueue ? self.queueTable : self.flow;
	UIView *to = self.showingQueue ? self.flow : self.queueTable;
	UIViewAnimationOptions dir = self.showingQueue ? UIViewAnimationOptionTransitionFlipFromLeft : UIViewAnimationOptionTransitionFlipFromRight;
	[self.view setNeedsLayout];
	[self.view layoutIfNeeded];
	if (!self.showingQueue) {
		[self.queueTable reloadData];
		[self scrollQueueToCurrent];
	}
	[UIView transitionFromView:from toView:to duration:0.6
	                   options:dir | UIViewAnimationOptionCurveEaseInOut completion:nil];
	self.showingQueue = !self.showingQueue;
}

- (void)scrollQueueToCurrent
{
	NSInteger current = self.appDelegate.player.current;
	if (current >= 0 && current < [self.queueTable numberOfRowsInSection:0])
		[self.queueTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:current inSection:0]
		                       atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
}

#pragma mark - like

- (void)setLikeImage
{
	YMTheme *t = [YMTheme current];
	UIColor *c = self.liked ? (t.kind == YMThemeYandex ? YMRGB(240, 60, 60) : (t.leather ? t.accentDark : t.accent))
	                        : [t.subtext colorWithAlphaComponent:0.8];
	UIColor *shadow = (t.kind == YMThemeYandexDark) ? YMRGBA(0, 0, 0, 0.9) : YMRGBA(255, 255, 255, 0.8);
	[self.likeButton setImage:[YMDraw glyph:self.liked ? YMGlyphHeartFilled : YMGlyphHeart size:24
	                                    top:c bottom:c shadow:shadow offset:CGSizeMake(0, 1)]
	                 forState:UIControlStateNormal];
}

-(void)checkTrackIsLiked:(Item *)track{
	self.liked = NO;
	for (Item *item in self.appDelegate.likedTracks){
		if ([item.itemId isEqual:track.itemId]){
			self.liked = YES;
			break;
		}
	}
	[self setLikeImage];
}

static void like_callback(void *data, const char *error){
	if (!error)
		return;
	NSLog(@"%s", error);
	PlayerViewController *self = (__bridge PlayerViewController *)data;
	dispatch_async(dispatch_get_main_queue(), ^{
		/* the request failed: undo the optimistic change */
		[self checkTrackIsLiked:self.current];
	});
}

-(void)likeIsPushed:(id)sender{
	Item *item = self.current;
	if (!item || !self.token)
		return;
	NSInteger uid = [[NSUserDefaults standardUserDefaults] integerForKey:@"uid"];
	if (!uid)
		return;

	BOOL like = !self.liked;
	NSMutableArray *liked = self.appDelegate.likedTracks;
	if (like) {
		[liked insertObject:item atIndex:0];
	} else {
		NSIndexSet *matches = [liked indexesOfObjectsPassingTest:^BOOL(Item *obj, NSUInteger idx, BOOL *stop) {
			return [obj.itemId isEqual:item.itemId];
		}];
		[liked removeObjectsAtIndexes:matches];
	}
	self.liked = like;
	[self setLikeImage];
	[UIView animateWithDuration:0.12 animations:^{
		self.likeButton.transform = CGAffineTransformMakeScale(1.35, 1.35);
	} completion:^(BOOL finished) {
		[UIView animateWithDuration:0.15 animations:^{ self.likeButton.transform = CGAffineTransformIdentity; }];
	}];

	NSString *token = [self.token copy];
	NSString *itemId = [item.itemId copy];
	[self.doLike addOperationWithBlock:^{
		if (like)
			c_yandex_music_set_like_current([token UTF8String], uid, [itemId UTF8String],
					(__bridge void *)self, like_callback);
		else
			c_yandex_music_set_unlike_current([token UTF8String], uid, [itemId UTF8String],
					(__bridge void *)self, like_callback);
	}];
}

#pragma mark - PlayerControllerDelegate

-(void)playerControllerStartPlayTrack:(Item *)track{
	/* handled by YMPlayerTrackDidChangeNotification */
}

#pragma mark - queue table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.appDelegate.player.playlist.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"queue"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"queue"];
	NSArray *playlist = self.appDelegate.player.playlist;
	if (indexPath.row >= (NSInteger)playlist.count)
		return cell;
	Item *item = [playlist objectAtIndex:indexPath.row];
	cell.textLabel.text = item.title;
	cell.detailTextLabel.text = item.subtitle;
	BOOL now = (indexPath.row == self.appDelegate.player.current) && self.appDelegate.player.nowPlaying;
	YMTheme *t = [YMTheme current];
	cell.accessoryView = now ? [[UIImageView alloc] initWithImage:
		[YMDraw glyph:YMGlyphNote size:16 color:(t.kind == YMThemeYandex ? YMRGB(220, 160, 0) : t.accent)]] : nil;
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	[[YMTheme current] styleCell:cell];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:[YMTheme current].spinnerStyle];
	cell.accessoryView = spinner;
	[spinner startAnimating];
	[self.appDelegate.player playIndex:indexPath.row onDone:^{
		[spinner stopAnimating];
		[tableView reloadData];
	}];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.row != self.appDelegate.player.current;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	PlayerController *player = self.appDelegate.player;
	if (indexPath.row >= (NSInteger)player.playlist.count || indexPath.row == player.current)
		return;
	[player.playlist removeObjectAtIndex:indexPath.row];
	if (indexPath.row < player.current) {
		player.current--;
		player.playing = player.current;
	}
	[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	return @"Убрать";
}

@end
// vim:ft=objc

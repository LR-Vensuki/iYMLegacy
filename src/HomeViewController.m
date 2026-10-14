/**
 * File              : HomeViewController.m
 * Home: My Wave, a Cover Flow of recommended tracks and the playlists
 * generated for the user.
 */

#import "HomeViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "YMTheme.h"
#import "YMCoverFlowView.h"
#import "TrackListViewController.h"
#import "ThemesViewController.h"
#import "ActionSheet.h"
#import "Item.h"
#import "../cYandexMusic/cYandexMusic.h"

enum { kSectionWave, kSectionTracks, kSectionPlaylists, kSectionCount };

@interface HomeViewController ()
@property (strong) NSMutableArray *tracks;
@property (strong) NSMutableArray *playlists;
@property (strong) NSOperationQueue *syncData;
@property (strong) YMCoverFlowView *coverFlow;
@property (strong) YMShelfView *shelf;
@property (strong) UIImageView *hero;
@property (strong) UILabel *heroTitle;
@property (strong) UILabel *heroSubtitle;
@property (strong) UIButton *heroButton;
@property (strong) UIActivityIndicatorView *heroSpinner;
@property (strong) CALayer *pulse;
@property (strong) UIActivityIndicatorView *spinner;
@property NSInteger generation;
@end

@implementation HomeViewController

- (id)init
{
	if ((self = [super initWithStyle:UITableViewStylePlain])) {
		self.title = @"Главная";
	}
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	self.tracks = [NSMutableArray array];
	self.playlists = [NSMutableArray array];
	self.syncData = [[NSOperationQueue alloc] init];
	self.syncData.maxConcurrentOperationCount = 1;

	YMTheme *t = [YMTheme current];
	[t styleController:self];
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	self.tableView.allowsSelection = NO;

	self.navigationItem.leftBarButtonItem = [t barButtonWithGlyph:YMGlyphGear target:self action:@selector(showThemes:)];

	self.refreshControl = [[UIRefreshControl alloc] init];
	self.refreshControl.tintColor = t.subtext;
	[self.refreshControl addTarget:self action:@selector(reloadData) forControlEvents:UIControlEventValueChanged];

	[self buildHero];

	self.coverFlow = [[YMCoverFlowView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, [self coverFlowHeight])];
	self.coverFlow.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.coverFlow.coverSize = [self coverSize];
	__weak HomeViewController *weakSelf = self;
	self.coverFlow.onTap = ^(Item *item, NSInteger index) {
		[weakSelf.appDelegate playTrackAt:index in:weakSelf.tracks asList:YES from:@"Треки для вас" onDone:NULL];
	};
	self.coverFlow.onLongPress = ^(Item *item, NSInteger index) {
		ActionSheet *as = [[ActionSheet alloc] initWithItem:item isDir:NO onDone:nil];
		YMCoverFlowView *flow = weakSelf.coverFlow;
		CGFloat s = flow.coverSize;
		[as showFromRect:CGRectMake((flow.bounds.size.width - s) / 2, 10, s, s) inView:flow
		          tabBar:weakSelf.tabBarController.tabBar];
	};

	self.shelf = [[YMShelfView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 156)];
	self.shelf.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.shelf.onTap = ^(Item *item, NSInteger index) {
		TrackListViewController *vc = [[TrackListViewController alloc] initWithParent:item];
		[weakSelf.navigationController pushViewController:vc animated:YES];
	};

	self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:t.spinnerStyle];
	self.spinner.hidesWhenStopped = YES;

	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(tokenDidUpdate:) name:@"YandexTokenDidUpdateNotification" object:nil];
	[nc addObserver:self selector:@selector(playerDidChange:) name:YMPlayerTrackDidChangeNotification object:nil];
	[nc addObserver:self selector:@selector(playerDidChange:) name:YMPlayerStateDidChangeNotification object:nil];
	[nc addObserver:self selector:@selector(playerDidChange:) name:YMPlayerQueueDidChangeNotification object:nil];

	[self reloadData];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self playerDidChange:nil];
}

- (void)viewDidLayoutSubviews
{
	[super viewDidLayoutSubviews];
	CGFloat w = self.tableView.bounds.size.width - 8;
	if (fabs(self.hero.image.size.width - w) > 0.5) {
		self.hero.frame = CGRectMake(4, 4, w, 124);
		self.hero.image = [[YMTheme current] heroImageWithSize:CGSizeMake(w, 124)];
		[CATransaction begin];
		[CATransaction setDisableActions:YES];
		self.pulse.frame = CGRectInset(self.heroButton.frame, 2, 2);
		[CATransaction commit];
	}
}

- (CGFloat)coverSize
{
	return YMIsPad() ? 220 : 130;
}

- (CGFloat)coverFlowHeight
{
	CGFloat s = [self coverSize];
	return 10 + s + s * 0.32 * 0.45 + 44;
}

- (void)showThemes:(id)sender
{
	[self.navigationController pushViewController:[[ThemesViewController alloc] init] animated:YES];
}

#pragma mark - My Wave

- (void)buildHero
{
	YMTheme *t = [YMTheme current];
	CGFloat w = self.view.bounds.size.width;
	self.hero = [[UIImageView alloc] initWithFrame:CGRectMake(4, 4, w - 8, 124)];
	self.hero.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.hero.image = [t heroImageWithSize:CGSizeMake(w - 8, 124)];
	self.hero.userInteractionEnabled = YES;

	UIColor *emboss = (t.kind == YMThemeYandexDark || t.kind == YMThemeClassic) ? YMRGBA(0, 0, 0, 0.45) : YMRGBA(255, 255, 255, 0.5);
	CGSize embossOffset = (t.kind == YMThemeYandexDark || t.kind == YMThemeClassic) ? CGSizeMake(0, -1) : CGSizeMake(0, 1);

	UIImageView *wave = [[UIImageView alloc] initWithImage:
		[YMDraw glyph:YMGlyphWave size:22 top:t.heroText bottom:t.heroText shadow:emboss offset:embossOffset]];
	wave.frame = CGRectMake(20, 22, 26, 26);
	[self.hero addSubview:wave];

	self.heroTitle = [[UILabel alloc] initWithFrame:CGRectMake(50, 18, w - 160, 32)];
	self.heroTitle.text = @"Моя волна";
	self.heroTitle.font = [UIFont boldSystemFontOfSize:26];
	self.heroSubtitle = [[UILabel alloc] initWithFrame:CGRectMake(22, 54, w - 130, 48)];
	self.heroSubtitle.font = [UIFont systemFontOfSize:13];
	self.heroSubtitle.numberOfLines = 3;
	for (UILabel *l in @[self.heroTitle, self.heroSubtitle]) {
		l.backgroundColor = [UIColor clearColor];
		l.shadowColor = emboss;
		l.shadowOffset = embossOffset;
		l.adjustsFontSizeToFitWidth = YES;
		[self.hero addSubview:l];
	}
	self.heroTitle.textColor = t.heroText;
	self.heroSubtitle.textColor = t.heroSubtext;

	CGFloat d = 64;
	self.heroButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.heroButton.frame = CGRectMake(w - 8 - 62 - (d + 4) / 2, 62 - (d + 4) / 2, d + 4, d + 4);
	self.heroButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	self.heroButton.adjustsImageWhenHighlighted = NO;
	[self.heroButton addTarget:self action:@selector(waveTapped:) forControlEvents:UIControlEventTouchUpInside];

	self.pulse = [CALayer layer];
	self.pulse.frame = CGRectInset(self.heroButton.frame, 2, 2);
	self.pulse.cornerRadius = d / 2;
	self.pulse.borderWidth = 3;
	self.pulse.borderColor = [(t.kind == YMThemeYandexDark ? t.accent : [UIColor whiteColor]) colorWithAlphaComponent:0.8].CGColor;
	self.pulse.opacity = 0;
	[self.hero.layer addSublayer:self.pulse];
	[self.hero addSubview:self.heroButton];

	self.heroSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	self.heroSpinner.center = CGPointMake((d + 4) / 2, (d + 4) / 2 - 1);
	self.heroSpinner.hidesWhenStopped = YES;
	[self.heroButton addSubview:self.heroSpinner];

	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(waveTapped:)];
	[self.hero addGestureRecognizer:tap];
	[self updateHero];
}

- (BOOL)waveActive
{
	return [self.appDelegate.player.station isEqualToString:YMStationMyWave];
}

- (void)updateHero
{
	YMTheme *t = [YMTheme current];
	PlayerController *player = self.appDelegate.player;
	BOOL active = [self waveActive];
	BOOL playing = active && player.playbackState == MPMoviePlaybackStatePlaying;
	YMGlyph glyph = playing ? YMGlyphPause : YMGlyphPlay;
	[self.heroButton setImage:[t roundButtonWithDiameter:64 glyph:glyph accent:YES pressed:NO] forState:UIControlStateNormal];
	[self.heroButton setImage:[t roundButtonWithDiameter:64 glyph:glyph accent:YES pressed:YES] forState:UIControlStateHighlighted];

	if (active && player.nowPlaying)
		self.heroSubtitle.text = [NSString stringWithFormat:@"Сейчас играет:\n%@ — %@",
		                          player.nowPlaying.title, player.nowPlaying.subtitle];
	else
		self.heroSubtitle.text = @"Бесконечный поток музыки,\nподобранный под ваш вкус";

	if (playing && ![self.pulse animationForKey:@"pulse"]) {
		CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
		scale.fromValue = @1.0;
		scale.toValue = @1.7;
		CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
		fade.fromValue = @0.9;
		fade.toValue = @0.0;
		CAAnimationGroup *group = [CAAnimationGroup animation];
		group.animations = @[scale, fade];
		group.duration = 1.6;
		group.repeatCount = HUGE_VALF;
		group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
		[self.pulse addAnimation:group forKey:@"pulse"];
	} else if (!playing) {
		[self.pulse removeAnimationForKey:@"pulse"];
	}
}

- (void)waveTapped:(id)sender
{
	PlayerController *player = self.appDelegate.player;
	if ([self waveActive] && player.nowPlaying) {
		[player togglePlayPause];
		return;
	}
	if (self.heroSpinner.isAnimating)
		return;
	[self.heroSpinner startAnimating];
	[self.heroButton setImage:nil forState:UIControlStateNormal];
	[self.heroButton setImage:nil forState:UIControlStateHighlighted];
	[self.heroButton setBackgroundImage:[[YMTheme current] roundButtonWithDiameter:64 glyph:YMGlyphWave accent:YES pressed:YES]
	                           forState:UIControlStateNormal];
	[player startStation:YMStationMyWave onDone:^(NSString *error) {
		[self.heroSpinner stopAnimating];
		[self.heroButton setBackgroundImage:nil forState:UIControlStateNormal];
		[self updateHero];
		if (error && ![error isEqualToString:@"cancelled"])
			[self.appDelegate showMessage:[NSString stringWithFormat:@"Моя волна: %@", error]];
	}];
}

- (void)playerDidChange:(NSNotification *)n
{
	[self updateHero];
}

#pragma mark - data

- (void)tokenDidUpdate:(NSNotification *)n
{
	[self reloadData];
}

static int get_feed(void *data, playlist_t *playlist, track_t *track, const char *error)
{
	NSMutableDictionary *ctx = (__bridge NSMutableDictionary *)data;
	NSString *token = [ctx objectForKey:@"token"];
	if (error) {
		[ctx setObject:[NSString stringWithUTF8String:error] forKey:@"error"];
		return 0;
	}
	if (track) {
		Item *t = [[Item alloc] initWithTrack:track token:token];
		[[ctx objectForKey:@"tracks"] addObject:t];
	}
	if (playlist) {
		Item *p = [[Item alloc] initWithPlaylist:playlist token:token];
		[[ctx objectForKey:@"playlists"] addObject:p];
	}
	return 0;
}

- (void)reloadData
{
	NSString *token = [[NSUserDefaults standardUserDefaults] valueForKey:@"token"];
	if (!token) {
		[self.refreshControl endRefreshing];
		return;
	}
	NSInteger generation = ++self.generation;
	if (!self.refreshControl.refreshing && !self.tracks.count)
		[self.spinner startAnimating];
	[self.syncData addOperationWithBlock:^{
		NSMutableDictionary *ctx = [NSMutableDictionary dictionaryWithObjectsAndKeys:
			token, @"token", [NSMutableArray array], @"tracks", [NSMutableArray array], @"playlists", nil];
		c_yandex_music_get_feed([token UTF8String], "200x200", (__bridge void *)ctx, get_feed);
		dispatch_async(dispatch_get_main_queue(), ^{
			if (generation != self.generation)
				return;
			[self.spinner stopAnimating];
			[self.refreshControl endRefreshing];
			NSString *error = [ctx objectForKey:@"error"];
			if (error) {
				[self.appDelegate showMessage:[NSString stringWithFormat:@"Яндекс Музыка: %@", error]];
				return;
			}
			[self.tracks setArray:[ctx objectForKey:@"tracks"]];
			[self.playlists setArray:[ctx objectForKey:@"playlists"]];
			self.coverFlow.items = self.tracks;
			self.shelf.items = self.playlists;
			[self.tableView reloadData];
		});
	}];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return kSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	switch (indexPath.section) {
	case kSectionWave: return 132;
	case kSectionTracks: return self.tracks.count ? [self coverFlowHeight] : 60;
	default: return self.playlists.count ? 160 : 0;
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	if (section == kSectionWave) return 4;
	if (section == kSectionPlaylists && !self.playlists.count) return 0;
	return 34;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	YMTheme *t = [YMTheme current];
	UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 34)];
	v.backgroundColor = [UIColor clearColor];
	if (section == kSectionWave)
		return v;
	UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, 8, tableView.bounds.size.width - 28, 24)];
	l.backgroundColor = [UIColor clearColor];
	l.font = [UIFont boldSystemFontOfSize:18];
	l.textColor = t.text;
	l.shadowColor = (t.kind == YMThemeYandexDark) ? YMRGBA(0, 0, 0, 0.9) : YMRGBA(255, 255, 255, 0.8);
	l.shadowOffset = CGSizeMake(0, 1);
	l.text = (section == kSectionTracks) ? @"Треки для вас" : @"Плейлисты для вас";
	[v addSubview:l];
	return v;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *ident = [NSString stringWithFormat:@"home%d", (int)indexPath.section];
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ident];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ident];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		/* a new cell is 320pt wide: give it the table's width before the
		 * flexible-width content goes in, or on the iPad that content would
		 * grow by the difference once the table lays the cell out */
		cell.frame = CGRectMake(0, 0, tableView.bounds.size.width, cell.frame.size.height);
		cell.contentView.frame = cell.bounds;
		UIView *content = nil;
		if (indexPath.section == kSectionWave)
			content = self.hero;
		else if (indexPath.section == kSectionTracks)
			content = self.coverFlow;
		else
			content = self.shelf;
		[cell.contentView addSubview:content];
		if (indexPath.section == kSectionTracks)
			[cell.contentView addSubview:self.spinner];
	}
	cell.backgroundColor = [UIColor clearColor];
	cell.backgroundView = [[UIView alloc] init];
	cell.backgroundView.backgroundColor = [UIColor clearColor];
	if (indexPath.section == kSectionTracks) {
		self.coverFlow.frame = CGRectMake(0, 0, tableView.bounds.size.width, [self coverFlowHeight]);
		self.spinner.center = CGPointMake(tableView.bounds.size.width / 2, 30);
	} else if (indexPath.section == kSectionPlaylists) {
		self.shelf.frame = CGRectMake(0, 0, tableView.bounds.size.width, 156);
	}
	return cell;
}

@end

// vim:ft=objc

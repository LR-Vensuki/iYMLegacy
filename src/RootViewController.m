/**
 * File              : RootViewController.m
 * Author            : Igor V. Sementsov <ig.kuzm@gmail.com>
 * Date              : 22.08.2023
 * Last Modified Date: 13.09.2023
 * Last Modified By  : Igor V. Sementsov <ig.kuzm@gmail.com>
 */
#import "RootViewController.h"
#include "AppDelegate.h"
#include "Foundation/Foundation.h"
#include "UIKit/UIKit.h"
#import "HomeViewController.h"
#import "FavoritesViewController.h"
#import "SearchViewController.h"
#import "PlaylistsViewController.h"
#import "PlayerViewController.h"
#import "YandexConnect.h"
#import "YMTheme.h"
#import "YMMiniPlayer.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>

@interface RootViewController () <UIGestureRecognizerDelegate>
@property (strong) YMMiniPlayer *mini;
@property (strong) UINavigationController *playerNav;
@property (readwrite) BOOL playerOpen;
@property BOOL dragging;
/* an appearance transition of Now Playing that has not ended yet */
@property BOOL appearing;
@property NSUInteger transition;
@end

@implementation RootViewController

- (UINavigationController *)tab:(UIViewController *)vc title:(NSString *)title glyph:(YMGlyph)glyph tag:(NSInteger)tag
{
	YMTheme *t = [YMTheme current];
	UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:vc];
	UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:title image:nil tag:tag];
	[item setFinishedSelectedImage:[t tabGlyph:glyph selected:YES]
	   withFinishedUnselectedImage:[t tabGlyph:glyph selected:NO]];
	[nc setTabBarItem:item];
	return nc;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	[self setViewControllers:@[
		[self tab:[[HomeViewController alloc] init] title:@"Главная" glyph:YMGlyphHome tag:0],
		[self tab:[[SearchViewController alloc] init] title:@"Поиск" glyph:YMGlyphSearch tag:1],
		[self tab:[[FavoritesViewController alloc] init] title:@"Избранное" glyph:YMGlyphHeartFilled tag:2],
		[self tab:[[PlaylistsViewController alloc] init] title:@"Плейлисты" glyph:YMGlyphPlaylists tag:3],
	] animated:NO];

	__weak RootViewController *weakSelf = self;
	self.mini = [[YMMiniPlayer alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, YMMiniPlayerHeight)];
	self.mini.onOpen = ^{ [weakSelf openPlayer:YES]; };
	self.mini.onDrag = ^(UIPanGestureRecognizer *pan) {
		if (pan.state == UIGestureRecognizerStateBegan && [pan velocityInView:pan.view].y < 0)
			[weakSelf openPlayer:YES];
	};
	[self.mini refresh];
	[self.view addSubview:self.mini];

	PlayerViewController *pvc = [[PlayerViewController alloc] init];
	pvc.navigationItem.leftBarButtonItem = [[YMTheme current] barButtonWithGlyph:YMGlyphChevronDown
			target:self action:@selector(closeTapped:)];
	self.playerNav = [[UINavigationController alloc] initWithRootViewController:pvc];
	UIView *pv = self.playerNav.view;
	pv.hidden = YES;
	pv.layer.shadowColor = [UIColor blackColor].CGColor;
	pv.layer.shadowOpacity = 0.5;
	pv.layer.shadowRadius = 6;
	pv.layer.shadowOffset = CGSizeMake(0, -2);
	[self.view addSubview:pv];
	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragPlayer:)];
	pan.delegate = self;
	[pv addGestureRecognizer:pan];

	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(playerDidChange:) name:YMPlayerTrackDidChangeNotification object:nil];
	[nc addObserver:self selector:@selector(playerDidChange:) name:YMPlayerQueueDidChangeNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tokenDidUpdate:)
			name:YandexTokenDidUpdateNotification object:nil];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self presentLoginIfNeeded];
}

- (void)tokenDidUpdate:(NSNotification *)notification {
	[self presentLoginIfNeeded];
}

- (void)presentLoginIfNeeded {
	if ([[NSUserDefaults standardUserDefaults] valueForKey:@"token"])
		return;
	if (self.presentedViewController || !self.view.window)
		return;
	YandexConnect *yc = [[YandexConnect alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[self presentViewController:yc animated:YES completion:nil];
}

#pragma mark - mini player and Now Playing

- (BOOL)miniVisible
{
	PlayerController *player = ((AppDelegate *)[UIApplication sharedApplication].delegate).player;
	return player.nowPlaying != nil || player.playlist.count > 0;
}

- (void)playerDidChange:(NSNotification *)n
{
	BOOL visible = [self miniVisible];
	if (visible == self.mini.hidden)
		[UIView animateWithDuration:0.25 animations:^{ [self.view setNeedsLayout]; [self.view layoutIfNeeded]; }];
}

- (void)viewDidLayoutSubviews
{
	[super viewDidLayoutSubviews];
	CGRect b = self.view.bounds;
	CGRect tab = self.tabBar.frame;
	BOOL show = [self miniVisible];
	CGFloat h = show ? YMMiniPlayerHeight : 0;
	/* the tab content ends above the mini player */
	for (UIView *v in self.view.subviews) {
		if (v == self.tabBar || v == self.mini || v == self.playerNav.view)
			continue;
		CGRect f = v.frame;
		f.size.height = MAX(0, tab.origin.y - h - f.origin.y);
		v.frame = f;
	}
	self.mini.hidden = !show;
	self.mini.frame = CGRectMake(0, tab.origin.y - YMMiniPlayerHeight, b.size.width, YMMiniPlayerHeight);
	if (!self.playerNav.view.hidden && !self.dragging)
		self.playerNav.view.frame = self.playerOpen ? b : CGRectOffset(b, 0, b.size.height);
	[self.view bringSubviewToFront:self.mini];
	[self.view bringSubviewToFront:self.playerNav.view];
}

- (void)openPlayer:(BOOL)animated
{
	if (self.playerOpen)
		return;
	self.playerOpen = YES;
	UIView *v = self.playerNav.view;
	CGRect b = self.view.bounds;
	if (v.hidden)
		v.frame = CGRectOffset(b, 0, b.size.height);
	v.hidden = NO;
	[self.view bringSubviewToFront:v];
	NSUInteger transition = [self beginPlayerAppearance:YES animated:animated];
	[UIView animateWithDuration:animated ? 0.35 : 0 delay:0
	                    options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
	                 animations:^{ v.frame = b; }
	                 completion:^(BOOL finished) { [self endPlayerAppearance:transition]; }];
}

/* Opening and closing can overlap (a quick tap, then a swipe): end the
 * previous appearance transition before starting the next one. */
- (NSUInteger)beginPlayerAppearance:(BOOL)appearing animated:(BOOL)animated
{
	if (self.appearing)
		[self.playerNav endAppearanceTransition];
	[self.playerNav beginAppearanceTransition:appearing animated:animated];
	self.appearing = YES;
	return ++self.transition;
}

- (void)endPlayerAppearance:(NSUInteger)transition
{
	if (transition != self.transition || !self.appearing)
		return;
	self.appearing = NO;
	[self.playerNav endAppearanceTransition];
}

- (void)closePlayer:(BOOL)animated
{
	if (!self.playerOpen)
		return;
	self.playerOpen = NO;
	UIView *v = self.playerNav.view;
	CGRect b = self.view.bounds;
	NSUInteger transition = [self beginPlayerAppearance:NO animated:animated];
	[UIView animateWithDuration:animated ? 0.3 : 0 delay:0
	                    options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
	                 animations:^{ v.frame = CGRectOffset(b, 0, b.size.height); }
	                 completion:^(BOOL finished) {
		if (!self.playerOpen)
			v.hidden = YES;
		[self endPlayerAppearance:transition];
	}];
}

- (void)closeTapped:(id)sender
{
	[self closePlayer:YES];
}

/* drag Now Playing down to put it away */
- (void)dragPlayer:(UIPanGestureRecognizer *)pan
{
	UIView *v = self.playerNav.view;
	CGRect b = self.view.bounds;
	CGFloat y = MAX(0, [pan translationInView:self.view].y);
	switch (pan.state) {
	case UIGestureRecognizerStateBegan:
		self.dragging = YES;
		break;
	case UIGestureRecognizerStateChanged:
		v.frame = CGRectOffset(b, 0, y);
		break;
	default: {
		self.dragging = NO;
		CGFloat speed = [pan velocityInView:self.view].y;
		if (pan.state == UIGestureRecognizerStateEnded && (y > b.size.height / 4 || speed > 600)) {
			[self closePlayer:YES];
		} else {
			[UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut
			                 animations:^{ v.frame = b; } completion:nil];
		}
		break;
	}
	}
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)g
{
	if (![g isKindOfClass:[UIPanGestureRecognizer class]])
		return YES;
	CGPoint vel = [(UIPanGestureRecognizer *)g velocityInView:self.view];
	return vel.y > 0 && vel.y > fabs(vel.x);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldReceiveTouch:(UITouch *)touch
{
	/* leave sliders, the volume control and the queue list alone */
	for (UIView *v = touch.view; v && v != g.view; v = v.superview)
		if ([v isKindOfClass:[UISlider class]] || [v isKindOfClass:[MPVolumeView class]] ||
		    [v isKindOfClass:[UITableView class]])
			return NO;
	return YES;
}

@end


// vim:ft=objc

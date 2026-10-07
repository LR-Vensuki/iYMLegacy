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
		[self tab:[[PlayerViewController alloc] init] title:@"Плеер" glyph:YMGlyphNote tag:2],
		[self tab:[[FavoritesViewController alloc] init] title:@"Избранное" glyph:YMGlyphHeartFilled tag:3],
		[self tab:[[PlaylistsViewController alloc] init] title:@"Плейлисты" glyph:YMGlyphPlaylists tag:4],
	] animated:NO];

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

@end


// vim:ft=objc

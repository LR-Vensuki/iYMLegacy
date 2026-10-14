/**
 * File              : AppDelegate.m
 * Author            : Igor V. Sementsov <ig.kuzm@gmail.com>
 * Date              : 09.08.2023
 * Last Modified Date: 31.08.2023
 * Last Modified By  : Igor V. Sementsov <ig.kuzm@gmail.com>
 */

#import "AppDelegate.h"
#import "YandexConnect.h"
#import <UIKit/UIResponder.h>
#include "Foundation/Foundation.h"
#include "UIKit/UIKit.h"
#include "RootViewController.h"
#import "PlayerController.h"
#import "PlayerViewController.h"
#import "ThemesViewController.h"
#import "YMTheme.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

	// Override point for customization after application launch.
	self.likedTracks = [NSMutableArray array];
	
	[[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
	self.player = [[PlayerController alloc]init];

	[[YMTheme current] applyAppearance];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeDidChange:)
			name:YMThemeDidChangeNotification object:nil];

	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];	
	RootViewController *vc = 
			[[RootViewController alloc]init];
	[self.window setRootViewController:vc];
	[self.window makeKeyAndVisible];
	[self attachPlayerView];
	[YandexConnect refreshSavedTokenIfNeeded];
	return true;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
	if (event.type == UIEventTypeRemoteControl) {
		switch (event.subtype) {
			case UIEventSubtypeRemoteControlTogglePlayPause:
					// Pause or play action
					[self.player togglePlayPause];
					break;
			case UIEventSubtypeRemoteControlNextTrack:
					// Next track action
					[self.player next];
					break;
			case UIEventSubtypeRemoteControlPreviousTrack:
					// Previous track action
					[self.player prev];
					break;
			case UIEventSubtypeRemoteControlStop:
					// Stop action
					[self.player stop];
					break;
			case UIEventSubtypeRemoteControlPlay:
					// Stop action
					[self.player play];
					break;
			case UIEventSubtypeRemoteControlPause:
					// Stop action
					[self.player pause];
					break;

			default:
					// catch all action
					break;
		}
	}
}

/* The movie player only plays audio here, but keep its view in the
 * window (invisible) so playback is never tied to a screen's lifetime. */
-(void)attachPlayerView{
	UIView *v = self.player.view;
	[v removeFromSuperview];
	v.frame = CGRectMake(0, 0, 1, 1);
	v.alpha = 0;
	v.userInteractionEnabled = NO;
	[self.player setControlStyle:MPMovieControlStyleNone];
	[self.window addSubview:v];
	[self.window sendSubviewToBack:v];
}

/* UIAppearance only affects views created afterwards, so a new theme
 * means building the interface again, on the same tab. */
-(void)rebuildInterface{
	UITabBarController *old = (UITabBarController *)self.window.rootViewController;
	NSUInteger tab = [old isKindOfClass:[UITabBarController class]] ? old.selectedIndex : 0;
	BOOL inThemes = NO;
	if ([old isKindOfClass:[UITabBarController class]]) {
		UINavigationController *nc = (UINavigationController *)old.selectedViewController;
		if ([nc isKindOfClass:[UINavigationController class]])
			inThemes = [nc.topViewController isKindOfClass:[ThemesViewController class]];
	}
	RootViewController *vc = [[RootViewController alloc] init];
	[UIView transitionWithView:self.window duration:0.4
			options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
			animations:^{
				BOOL enabled = [UIView areAnimationsEnabled];
				[UIView setAnimationsEnabled:NO];
				[self.window setRootViewController:vc];
				vc.selectedIndex = tab;
				if (inThemes) {
					UINavigationController *nc = (UINavigationController *)vc.selectedViewController;
					[nc pushViewController:[[ThemesViewController alloc] init] animated:NO];
				}
				[UIView setAnimationsEnabled:enabled];
			} completion:nil];
	[self attachPlayerView];
}

-(void)themeDidChange:(NSNotification *)notification{
	[self rebuildInterface];
}

-(void)playButtonPushed:(id)sender{
	[self openPlayer];
}

-(void)openPlayer{
	RootViewController *root = (RootViewController *)self.window.rootViewController;
	if ([root isKindOfClass:[RootViewController class]])
		[root openPlayer:YES];
}

-(void)playTrackAt:(NSInteger)index in:(NSArray *)items asList:(BOOL)asList from:(NSString *)title onDone:(void (^)(void))onDone{
	if (index < 0 || index >= (NSInteger)items.count) {
		if (onDone) onDone();
		return;
	}
	Item *tapped = [items objectAtIndex:index];
	NSMutableArray *queue = [NSMutableArray array];
	if (asList) {
		for (Item *item in items)
			if (item.itemType == ITEM_TRACK || item.itemType == ITEM_PODCAST_EPOSODE)
				[queue addObject:item];
	} else {
		[queue addObject:tapped];
	}
	NSUInteger start = [queue indexOfObject:tapped];
	if (start == NSNotFound) {
		if (onDone) onDone();
		return;
	}
	[self.player playItems:queue startingAt:start onDone:onDone];
	self.player.contextTitle = asList ? title : nil;
	[self openPlayer];
}

-(void)showMessage:(NSString *)msg {
	if (!msg.length) return;
	UIAlertView *alert = 
			[[UIAlertView alloc]initWithTitle:@"" 
			message:msg 
			delegate:nil 
			cancelButtonTitle:@"Закрыть" 
			otherButtonTitles:nil];

		[alert show];
}

@end
// vim:ft=objc


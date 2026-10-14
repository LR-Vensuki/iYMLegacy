/**
 * File              : AppDelegate.h
 * Author            : Igor V. Sementsov <ig.kuzm@gmail.com>
 * Date              : 09.08.2023
 * Last Modified Date: 13.09.2023
 * Last Modified By  : Igor V. Sementsov <ig.kuzm@gmail.com>
 */

#include "Foundation/Foundation.h"
#import <UIKit/UIKit.h>
#import "PlayerController.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong,nonatomic) NSURL *url;
@property (strong, nonatomic) PlayerController *player;
@property (strong) NSMutableArray *likedTracks;
-(void)playButtonPushed:(id)sender;
/* Tap on a track, Apple Music style: play it and open Now Playing.
 * %asList: the rest of %items follows (a playlist, an album, liked tracks);
 * otherwise only the tapped track, then My Wave by it. */
-(void)playTrackAt:(NSInteger)index in:(NSArray *)items asList:(BOOL)asList from:(NSString *)title onDone:(void (^)(void))onDone;
-(void)openPlayer;
-(void)showMessage:(NSString *)msg;
-(void)rebuildInterface;

@end

// vim:ft=objc

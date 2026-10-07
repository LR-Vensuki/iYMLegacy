/**
 * File              : PlayerViewController.h
 * Author            : Igor V. Sementsov <ig.kuzm@gmail.com>
 * Date              : 22.08.2023
 * Last Modified Date: 10.09.2023
 * Last Modified By  : Igor V. Sementsov <ig.kuzm@gmail.com>
 *
 * Now Playing: artwork that flips over to the queue like the iPod, the
 * scrubber, transport controls, shuffle/repeat, like and volume.
 */

#include "UIKit/UIKit.h"
#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "Item.h"

@interface PlayerViewController : UIViewController
<UITableViewDelegate, UITableViewDataSource, PlayerControllerDelegate>
@property (strong) AppDelegate *appDelegate;
@property (strong) Item *current;
@property (strong) NSString *token;
@property BOOL liked;
@property (strong) NSOperationQueue *doLike;
@end

// vim:ft=objc

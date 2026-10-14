/**
 * File              : RootViewController.h
 * Author            : Igor V. Sementsov <ig.kuzm@gmail.com>
 * Date              : 22.08.2023
 * Last Modified Date: 22.08.2023
 * Last Modified By  : Igor V. Sementsov <ig.kuzm@gmail.com>
 */

#include <UIKit/UIKit.h>
#include "UIKit/UIKit.h"
@interface RootViewController : UITabBarController
/* Now Playing slides up over everything from the mini player and can be
 * dragged back down, like Apple Music. */
- (void)openPlayer:(BOOL)animated;
- (void)closePlayer:(BOOL)animated;
@property (readonly) BOOL playerOpen;
@end


// vim:ft=objc

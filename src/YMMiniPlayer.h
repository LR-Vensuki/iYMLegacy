/*
 * The bar above the tabs that shows what is playing, like Apple Music:
 * tap it to open the player, play/pause and next work in place.
 */
#import <UIKit/UIKit.h>

#define YMMiniPlayerHeight 50

@interface YMMiniPlayer : UIView
@property (copy) void (^onOpen)(void);
@property (copy) void (^onDrag)(UIPanGestureRecognizer *pan);
- (void)refresh;
@end

// vim:ft=objc

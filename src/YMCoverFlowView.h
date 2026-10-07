/**
 * File              : YMCoverFlowView.h
 * iPod-style Cover Flow carousel of tracks, and a flat shelf of playlists.
 */

#import <UIKit/UIKit.h>
#import "Item.h"

@interface YMCoverFlowView : UIView <UIScrollViewDelegate>
@property (strong, nonatomic) NSArray *items;
@property (nonatomic) CGFloat coverSize;
@property (readonly) NSInteger selectedIndex;
@property (copy) void (^onTap)(Item *item, NSInteger index);
@property (copy) void (^onLongPress)(Item *item, NSInteger index);
- (void)reloadTheme;
@end

@interface YMShelfView : UIScrollView
@property (strong, nonatomic) NSArray *items;
@property (copy) void (^onTap)(Item *item, NSInteger index);
- (void)reloadTheme;
@end

// vim:ft=objc

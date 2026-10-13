/**
 * File              : PlayerController.h
 * Author            : Igor V. Sementsov <ig.kuzm@gmail.com>
 * Date              : 28.08.2023
 * Last Modified Date: 11.09.2023
 * Last Modified By  : Igor V. Sementsov <ig.kuzm@gmail.com>
 */

#include "Foundation/Foundation.h"
#import "MediaPlayer/MediaPlayer.h"
#import "Item.h"
extern NSString * const YMPlayerTrackDidChangeNotification;
extern NSString * const YMPlayerStateDidChangeNotification;
extern NSString * const YMPlayerQueueDidChangeNotification;

typedef enum {
	YMRepeatOff,
	YMRepeatAll,
	YMRepeatOne,
} YMRepeatMode;

#define YMStationMyWave @"user:onyourwave"

@protocol PlayerControllerDelegate <NSObject>
-(void)playerControllerStartPlayTrack:(Item *)track;
@end
@interface PlayerController : MPMoviePlayerController
@property (strong,nonatomic) NSMutableArray *playlist;
@property (strong,nonatomic) Item *nowPlaying;
@property NSInteger playing;
@property NSInteger current;
@property (nonatomic) YMRepeatMode queueRepeat;
@property (nonatomic) BOOL shuffle;
@property (strong) NSArray *unshuffled;
/* rotor station being played ("My Wave"), nil for an ordinary queue */
@property (strong) NSString *station;
@property (strong) NSString *stationBatch;
@property BOOL loadingStation;
@property NSUInteger stationGeneration;
@property (weak) id appDelegate;
@property (strong) NSTimer *timer;
@property (strong) NSTimer *downloadPlaylist;
@property (weak) id delegate;
-(void)addToTopAndPlay:(Item *)item onDone:(void (^)())onDone;
-(void)addToLast:(Item *)item;
-(void)addAfterCurrent:(Item *)item;
-(void)playCurrent:(void (^)())onDone;
-(void)next;
-(void)prev;
-(void)togglePlayPause;
-(void)startStation:(NSString *)station onDone:(void (^)(NSString *error))onDone;
-(void)playIndex:(NSInteger)index onDone:(void (^)())onDone;
/* replace the queue with %items and start playing at %index */
-(void)playItems:(NSArray *)items startingAt:(NSInteger)index onDone:(void (^)())onDone;

@end

// vim:ft=objc

/**
 * File              : PlayerController.m
 * Author            : Igor V. Sementsov <ig.kuzm@gmail.com>
 * Date              : 28.08.2023
 * Last Modified Date: 12.09.2023
 * Last Modified By  : Igor V. Sementsov <ig.kuzm@gmail.com>
 */

#import "PlayerController.h"
#include "stdbool.h"
#include "MediaPlayer/MediaPlayer.h"
#include "UIKit/UIKit.h"
#include "Foundation/Foundation.h"
#include "AVFoundation/AVAudioSession.h"
#include "../cYandexMusic/cYandexMusic.h"
#import "AppDelegate.h"

NSString * const YMPlayerTrackDidChangeNotification = @"YMPlayerTrackDidChangeNotification";
NSString * const YMPlayerStateDidChangeNotification = @"YMPlayerStateDidChangeNotification";
NSString * const YMPlayerQueueDidChangeNotification = @"YMPlayerQueueDidChangeNotification";

@implementation PlayerController
- (id)init
{
	if (self = [super init]) {
		self.appDelegate = [[UIApplication sharedApplication]delegate];
		self.playlist = [NSMutableArray array];		
		self.current = -1;
		self.queueRepeat = YMRepeatOff;
		[self setUseApplicationAudioSession:FALSE];
		[self setupPlayBackAudioSession];
		//[self setMovieSourceType:MPMovieSourceTypeStreaming];

	[[NSNotificationCenter defaultCenter] 
		addObserver:self selector:@selector(willEnterFullscreen:) 
					 name:MPMoviePlayerWillEnterFullscreenNotification object:nil];
	[[NSNotificationCenter defaultCenter] 
		addObserver:self selector:@selector(willExitFullscreen:) 
					 name:MPMoviePlayerWillExitFullscreenNotification object:nil];
	[[NSNotificationCenter defaultCenter] 
		addObserver:self selector:@selector(enteredFullscreen:) 
					 name:MPMoviePlayerDidEnterFullscreenNotification object:nil];
	[[NSNotificationCenter defaultCenter] 
		addObserver:self selector:@selector(exitedFullscreen:) 
					 name:MPMoviePlayerDidExitFullscreenNotification object:nil];
	[[NSNotificationCenter defaultCenter] 
		addObserver:self selector:@selector(playbackFinished:) 
					 name:MPMoviePlayerPlaybackDidFinishNotification object:nil];
	[[NSNotificationCenter defaultCenter] 
		addObserver:self selector:@selector(loadStateChanged:) 
					 name:MPMoviePlayerLoadStateDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] 
		addObserver:self selector:@selector(nowPlayingChanged:) 
					 name:MPMoviePlayerNowPlayingMovieDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] 
		addObserver:self selector:@selector(playbackStateChanged:) 
					 name:MPMoviePlayerPlaybackStateDidChangeNotification object:nil];
		// add timer
		self.timer = [NSTimer scheduledTimerWithTimeInterval:10 
				target:self selector:@selector(timer:) 
					userInfo:nil repeats:YES];

	}
	return self;
}

void post_error(void *data, const char *error){
	(void)data;
	if (error){
		NSLog(@"%s", error);
		//dispatch_sync(dispatch_get_main_queue(), ^{
			//[appDelegate showMessage:[NSString stringWithUTF8String:error] title:@"error"];
		//});
	}
}

-(void)timer:(id)sender{
	// do timer funct
	if (!self.nowPlaying)
		return;

	if (self.playbackState == MPMoviePlaybackStatePlaying){
		NSInteger uid = [[NSUserDefaults standardUserDefaults]integerForKey:@"uid"];
		NSString *token = [self.nowPlaying.token copy];
		NSString *itemId = [self.nowPlaying.itemId copy];
		NSInteger duration = self.duration;
		NSInteger played = self.playableDuration;
		if (!uid) {
			[[[NSOperationQueue alloc] init] addOperationWithBlock:^{
				long fetchedUID = token ? c_yandex_music_get_uid([token UTF8String]) : 0;
				if (fetchedUID) [[NSUserDefaults standardUserDefaults] setInteger:fetchedUID forKey:@"uid"];
				if (!fetchedUID) {
					dispatch_async(dispatch_get_main_queue(), ^{ NSLog(@"Could not determine Yandex UID"); });
					return;
				}
			c_yandex_music_post_current([token UTF8String], NULL, [itemId UTF8String], duration, played, fetchedUID, (__bridge void *)self.appDelegate, post_error);
			}];
			return;
		}

		[[[NSOperationQueue alloc]init] addOperationWithBlock:^{
			c_yandex_music_post_current(
					token ? [token UTF8String] : NULL, 
					NULL,
					[itemId UTF8String], 
					duration,
					played,
					uid,
					(__bridge void *)self.appDelegate, post_error);
		}];
	}
}

-(void)playItem:(Item *)item{
	if (!item || !item.downloadURL) return;
	[self setContentURL:item.downloadURL];
	[self prepareToPlay];
	[self play];
	[self setPlayInfo:item];
	
	[self setNowPlaying:item];
	[self setPlaying:self.current];
	if (self.delegate)
		[self.delegate playerControllerStartPlayTrack:item];
	[[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerTrackDidChangeNotification object:self];
	[self stationTrackStarted:item];

	// download current and next items after 10 sec
	if (self.downloadPlaylist){
		// stop timer
		[self.downloadPlaylist fire];
	}
	// start after 10 sec
	self.downloadPlaylist = 
		[NSTimer scheduledTimerWithTimeInterval:10 
			target:self selector:@selector(downloadCurrentAndNext:) 
			userInfo:nil repeats:NO];
}

-(void)downloadNext:(int)i{
	// download next item
	if (
			self.playlist.count > self.current + i &&
			i < 10)
	{
		Item *item = [self.playlist objectAtIndex:self.current + i];
		if (item){
			[item downloadFile:^(Item *item){
				// do when downloaded
				// prepare image
				[item prepareImage:^(Item *item){
					// on done
					[self downloadNext:i+1];
				}];
			}];
		}
	}
}

-(void)downloadCurrentAndNext:(id)sender{
	if (self.current < 0 || self.current >= (NSInteger)self.playlist.count) return;
	// download current
	Item *item = [self.playlist objectAtIndex:self.current];
	if (item){
		[item downloadFile:^(Item *item){
			// do when downloaded
			[self downloadNext:1];
		}];
	}
}

-(void)preparePlayItem:(Item *)item onDone:(void (^)())onDone{
	if (!item.hasFile && !item.hasDownloadURL){
		[item prepareDownloadURL:^(Item *item){
			[self playItem:item];
			if (onDone)
				onDone();
		}];
	}else {
		[self playItem:item];
		if (onDone)
			onDone();
	}
}

-(void)playCurrent:(void (^)())onDone{
	if (self.current < 0 || self.current >= (NSInteger)self.playlist.count) {
		if (onDone) onDone();
		return;
	}
	if (self.playlist.count > self.current){
		Item *item = [self.playlist objectAtIndex:self.current];
		if (item)
			[self preparePlayItem:item onDone:onDone];
	}
}

-(void)addToLast:(Item *)item {
	if (item) [self.playlist addObject:item];
	[self queueChanged];
}

-(void)addAfterCurrent:(Item *)item{
	if (!item) return;
	NSUInteger index = (self.current < 0) ? self.playlist.count : (NSUInteger)(self.current + 1);
	if (index > self.playlist.count) index = self.playlist.count;
	[self.playlist insertObject:item atIndex:index];
	[self queueChanged];
}

-(void)addToTopAndPlay:(Item *)item onDone:(void (^)())onDone{
	if (!item) { if (onDone) onDone(); return; }
	self.station = nil;
	self.contextTitle = nil;
	if (self.current < 0) self.current = 0;
	if (self.current > (NSInteger)self.playlist.count) self.current = self.playlist.count;
	[self.playlist insertObject:item atIndex:self.current];
	[self playCurrent:onDone];
}

-(void)queueChanged{
	[[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerQueueDidChangeNotification object:self];
}

-(void)playIndex:(NSInteger)index onDone:(void (^)())onDone{
	if (index < 0 || index >= (NSInteger)self.playlist.count) {
		if (onDone) onDone();
		return;
	}
	self.current = index;
	[self playCurrent:onDone];
	[self fetchStationIfNeeded];
}

-(void)playItems:(NSArray *)items startingAt:(NSInteger)index onDone:(void (^)())onDone{
	self.station = nil;
	self.unshuffled = nil;
	_shuffle = NO;
	[self.playlist setArray:items];
	[self queueChanged];
	[self playIndex:index onDone:onDone];
}

/* Skip by the user: tell the station, then move on. */
-(void)next{
	if (self.station && self.nowPlaying)
		[self stationFeedback:@"skip" item:self.nowPlaying played:self.currentPlaybackTime];
	[self advance];
}

-(void)advance{
	if (self.current + 1 >= (NSInteger)self.playlist.count) {
		if (self.queueRepeat == YMRepeatAll && !self.station && self.playlist.count) {
			[self playIndex:0 onDone:NULL];
		} else if (self.station) {
			/* wait for the next batch; fetchStationIfNeeded plays it */
			self.current = self.playlist.count - 1;
			[self fetchStationIfNeeded];
		} else if (self.nowPlaying.itemType == ITEM_TRACK && self.nowPlaying.itemId) {
			/* the queue ran out: carry on with My Wave seeded by the last track,
			 * the way Yandex Music does */
			[self continueWaveFrom:self.nowPlaying];
		}
		return;
	}
	[self playIndex:self.current + 1 onDone:NULL];
}

-(void)continueWaveFrom:(Item *)item{
	self.station = [@"track:" stringByAppendingString:item.itemId];
	self.stationBatch = nil;
	self.stationGeneration++;
	self.loadingStation = NO;
	self.unshuffled = nil;
	_shuffle = NO;
	self.current = self.playlist.count - 1;
	[self loadStationBatch:^(NSString *error) {
		if (error)
			return;
		[self stationFeedback:@"radioStarted" item:nil played:0];
		if (self.current + 1 < (NSInteger)self.playlist.count)
			[self playIndex:self.current + 1 onDone:NULL];
	}];
}

/* The track played to its end (not skipped). */
-(void)trackEnded{
	if (self.queueRepeat == YMRepeatOne && !self.station && self.nowPlaying) {
		[self playIndex:self.current onDone:NULL];
		return;
	}
	if (self.station && self.nowPlaying)
		[self stationFeedback:@"trackFinished" item:self.nowPlaying played:self.duration];
	[self advance];
}

-(void)prev{
	/* like the iPod: restart the track unless it has only just begun */
	if (self.nowPlaying && self.currentPlaybackTime > 3) {
		self.currentPlaybackTime = 0;
		return;
	}
	NSInteger index = self.current - 1;
	if (index < 0)
		index = (self.queueRepeat == YMRepeatAll) ? (NSInteger)self.playlist.count - 1 : 0;
	[self playIndex:index onDone:NULL];
}

-(void)togglePlayPause{
	if (!self.nowPlaying) {
		if (self.playlist.count)
			[self playIndex:MAX(self.current, 0) onDone:NULL];
		return;
	}
	if (self.playbackState == MPMoviePlaybackStatePlaying)
		[self pause];
	else
		[self play];
}

#pragma mark <Shuffle>

-(void)setShuffle:(BOOL)shuffle{
	if (_shuffle == shuffle)
		return;
	_shuffle = shuffle;
	Item *now = (self.current >= 0 && self.current < (NSInteger)self.playlist.count)
		? [self.playlist objectAtIndex:self.current] : nil;
	if (shuffle) {
		self.unshuffled = [self.playlist copy];
		/* keep what has been played, shuffle what is still to come */
		NSUInteger start = now ? (NSUInteger)self.current + 1 : 0;
		for (NSUInteger i = self.playlist.count; i > start + 1; --i) {
			NSUInteger j = start + arc4random_uniform((u_int32_t)(i - start));
			[self.playlist exchangeObjectAtIndex:i - 1 withObjectAtIndex:j];
		}
	} else if (self.unshuffled) {
		NSMutableArray *restored = [NSMutableArray arrayWithArray:self.unshuffled];
		for (Item *item in self.playlist)
			if (![restored containsObject:item])
				[restored addObject:item];
		[restored filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *b) {
			return [self.playlist containsObject:obj];
		}]];
		[self.playlist setArray:restored];
		self.unshuffled = nil;
		if (now) {
			self.current = [self.playlist indexOfObject:now];
			self.playing = self.current;
		}
	}
	[self queueChanged];
}

#pragma mark <Stations>

-(void)startStation:(NSString *)station onDone:(void (^)(NSString *error))onDone{
	NSString *token = [[NSUserDefaults standardUserDefaults] valueForKey:@"token"];
	if (!token) {
		if (onDone) onDone(@"Нужно войти в аккаунт");
		return;
	}
	[self stop];
	[self.playlist removeAllObjects];
	self.unshuffled = nil;
	_shuffle = NO;
	self.current = -1;
	self.nowPlaying = nil;
	self.station = station;
	self.stationBatch = nil;
	self.contextTitle = nil;
	/* Drop any batch still loading for a previous start, even of the same station. */
	self.stationGeneration++;
	self.loadingStation = NO;
	[self queueChanged];
	[self loadStationBatch:^(NSString *error) {
		if (!error) {
			[self stationFeedback:@"radioStarted" item:nil played:0];
			[self playIndex:0 onDone:^{
				if (onDone) onDone(nil);
			}];
		} else if (onDone) {
			onDone(error);
		}
	}];
}

static int station_track(void *data, const char *batch_id, track_t *track, const char *error){
	NSMutableDictionary *ctx = (__bridge NSMutableDictionary *)data;
	if (error) {
		[ctx setObject:[NSString stringWithUTF8String:error] forKey:@"error"];
		return 0;
	}
	if (batch_id && ![ctx objectForKey:@"batch"])
		[ctx setObject:[NSString stringWithUTF8String:batch_id] forKey:@"batch"];
	if (track) {
		Item *item = [[Item alloc] initWithTrack:track token:[ctx objectForKey:@"token"]];
		if (item.itemId)
			[[ctx objectForKey:@"items"] addObject:item];
	}
	return 0;
}

-(void)loadStationBatch:(void (^)(NSString *error))onDone{
	if (self.loadingStation || !self.station) {
		if (onDone) onDone(nil);
		return;
	}
	NSString *token = [[NSUserDefaults standardUserDefaults] valueForKey:@"token"];
	NSString *station = [self.station copy];
	Item *last = [self.playlist lastObject];
	NSString *queue = last ? [last.itemId copy] : nil;
	NSUInteger generation = self.stationGeneration;
	self.loadingStation = YES;
	[[[NSOperationQueue alloc] init] addOperationWithBlock:^{
		NSMutableDictionary *ctx = [NSMutableDictionary dictionaryWithObjectsAndKeys:
			[NSMutableArray array], @"items", token, @"token", nil];
		c_yandex_music_get_station_tracks([token UTF8String], [station UTF8String],
				[queue UTF8String], "200x200", (__bridge void *)ctx, station_track);
		dispatch_async(dispatch_get_main_queue(), ^{
			if (generation != self.stationGeneration) {
				if (onDone) onDone(@"cancelled");
				return;
			}
			self.loadingStation = NO;
			if (![station isEqualToString:self.station]) {
				if (onDone) onDone(@"cancelled");
				return;
			}
			NSArray *items = [ctx objectForKey:@"items"];
			if ([ctx objectForKey:@"batch"])
				self.stationBatch = [ctx objectForKey:@"batch"];
			NSMutableSet *known = [NSMutableSet set];
			for (Item *i in self.playlist)
				[known addObject:i.itemId];
			for (Item *i in items)
				if (![known containsObject:i.itemId])
					[self.playlist addObject:i];
			[self queueChanged];
			NSString *error = [ctx objectForKey:@"error"];
			if (!error && !items.count)
				error = @"Моя волна не вернула треков";
			if (onDone) onDone(error);
		});
	}];
}

/* Keep a couple of tracks queued ahead while a station plays. */
-(void)fetchStationIfNeeded{
	if (!self.station || self.loadingStation)
		return;
	if (self.current + 2 < (NSInteger)self.playlist.count)
		return;
	BOOL waiting = (self.current + 1 >= (NSInteger)self.playlist.count) &&
		self.playbackState != MPMoviePlaybackStatePlaying;
	[self loadStationBatch:^(NSString *error) {
		if (!error && waiting && self.current + 1 < (NSInteger)self.playlist.count)
			[self playIndex:self.current + 1 onDone:NULL];
	}];
}

-(NSString *)feedbackTrackId:(Item *)item{
	if (!item)
		return nil;
	if (item.albumId)
		return [NSString stringWithFormat:@"%@:%ld", item.itemId, item.albumId];
	return item.itemId;
}

-(void)stationFeedback:(NSString *)type item:(Item *)item played:(NSTimeInterval)played{
	if (!self.station)
		return;
	NSString *token = [[NSUserDefaults standardUserDefaults] valueForKey:@"token"];
	NSString *station = [self.station copy];
	NSString *batch = [self.stationBatch copy];
	NSString *trackId = [self feedbackTrackId:item];
	if (isnan(played) || played < 0)
		played = 0;
	[[[NSOperationQueue alloc] init] addOperationWithBlock:^{
		c_yandex_music_rotor_feedback([token UTF8String], [station UTF8String],
				[batch UTF8String], [type UTF8String], [trackId UTF8String], played);
	}];
}

-(void)stationTrackStarted:(Item *)item{
	if (!self.station)
		return;
	[self stationFeedback:@"trackStarted" item:item played:0];
	[self fetchStationIfNeeded];
}

-(void)setPlayInfoWithArt:(Item *)item{
	if (item.artImage){
		MPNowPlayingInfoCenter * nowPlaying = [MPNowPlayingInfoCenter defaultCenter];
			MPMediaItemArtwork *artwork = [[MPMediaItemArtwork	alloc]initWithImage:item.artImage];
			nowPlaying.nowPlayingInfo =  
			@{MPMediaItemPropertyTitle:item.title,
				MPMediaItemPropertyArtist:item.subtitle, 
				MPMediaItemPropertyAlbumTitle:item.albumTitle,
				MPMediaItemPropertyArtwork:artwork};
	}
}

-(void)setPlayInfo:(Item *)item{
	MPNowPlayingInfoCenter * nowPlaying = [MPNowPlayingInfoCenter defaultCenter];
	if (item.hasAtrImage){
			[self setPlayInfoWithArt:item];
	} else {
		nowPlaying.nowPlayingInfo =  
				@{MPMediaItemPropertyTitle:
							item.title, 
							MPMediaItemPropertyArtist:item.subtitle,
					MPMediaItemPropertyAlbumTitle:item.albumTitle};
		[item prepareImage:^(Item *item){
			[self setPlayInfoWithArt:item];
		 }];
	}
}

#pragma mark <AudioSession Setup>
- (void)setupPlayBackAudioSession
{
	AVAudioSession *audioSession = [AVAudioSession sharedInstance];
	if (audioSession.category != AVAudioSessionCategoryPlayback) {
		UIDevice *device = [UIDevice currentDevice];
		if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
			if (device.multitaskingSupported) {										                
				
				NSError *setCategoryError = nil;
				[audioSession setCategory:AVAudioSessionCategoryPlayback
											withOptions:AVAudioSessionCategoryOptionAllowBluetooth
											error:&setCategoryError];
				if (setCategoryError)
					NSLog(@"%@", setCategoryError.description);
				
				NSError *activationError = nil;
				[audioSession setActive:YES error:&activationError];
				if (activationError)
					NSLog(@"%@", activationError.description);
			}
		}									    
	}				
}
 - (void)willEnterFullscreen:(NSNotification*)notification {
	NSLog(@"willEnterFullscreen");
	[self setControlStyle:MPMovieControlStyleFullscreen];
}

- (void)enteredFullscreen:(NSNotification*)notification {
	NSLog(@"enteredFullscreen");
}

- (void)willExitFullscreen:(NSNotification*)notification {
	NSLog(@"willExitFullscreen");
}

- (void)exitedFullscreen:(NSNotification*)notification {
	NSLog(@"exitedFullscreen");
}

- (void)playbackFinished:(NSNotification*)notification {
NSNumber* reason = [[notification userInfo] objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
	switch ([reason intValue]) {
			case MPMovieFinishReasonPlaybackEnded:
					[self trackEnded];
					NSLog(@"playbackFinished. Reason: Playback Ended");
							break;
			case MPMovieFinishReasonPlaybackError:
					NSLog(@"playbackFinished. Reason: Playback Error");
							break;
			case MPMovieFinishReasonUserExited:
					NSLog(@"playbackFinished. Reason: User Exited");
							break;
			default:
					break;
	}
	//[self.movieController setFullscreen:NO animated:YES];
}

- (void)loadStateChanged:(NSNotification*)notification {
	switch (self.loadState) {
		case MPMovieLoadStateUnknown: break;
		case MPMovieLoadStateStalled: break;
		case MPMovieLoadStatePlayable: break;
		case MPMovieLoadStatePlaythroughOK: break;
	
		default: break;
	}
}
- (void)nowPlayingChanged:(NSNotification*)notification {
}
- (void)playbackStateChanged:(NSNotification*)notification {
	[[NSNotificationCenter defaultCenter] postNotificationName:YMPlayerStateDidChangeNotification object:self];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.downloadPlaylist invalidate];
    [self.timer invalidate];
}

@end

// vim:ft=objc

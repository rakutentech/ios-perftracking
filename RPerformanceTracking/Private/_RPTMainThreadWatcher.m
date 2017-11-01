#import "_RPTMainThreadWatcher.h"
#import "_RPTHelpers.h"
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"

@interface _RPTMainThreadWatcher ()
@property (nonatomic) BOOL                 watcherRunning;
@property (nonatomic) dispatch_semaphore_t semaphore;
@property (nonatomic) NSTimeInterval       blockThreshold;
@property (nonatomic) NSTimeInterval       startTime;
@property (nonatomic) NSTimeInterval       endTime;
@property (nonatomic) uint_fast64_t        trackingIdentifier;
@end

// Inspired by https://medium.com/@mandrigin/ios-app-performance-instruments-beyond-48fe7b7cdf2
@implementation _RPTMainThreadWatcher

- (instancetype)init
{
    if (self = [super init])
    {
        _watcherRunning = NO;
        _blockThreshold = 0.4;
        _semaphore = dispatch_semaphore_create(0);
    }
    return self;
}

- (void)main
{
    while (!self.isCancelled)
    {
        _watcherRunning = YES;
        _startTime = [NSDate timeIntervalSinceReferenceDate];
        
        // If this block doesn't get to run on the main thread in
        // <= blockThreshold seconds then we consider the main
        // thread blocked
        dispatch_async(dispatch_get_main_queue(), ^{
            _watcherRunning = NO; // reset watcher
            dispatch_semaphore_signal(_semaphore);
        });
        
        [NSThread sleepForTimeInterval:_blockThreshold];

        if (_watcherRunning)
        {
            // Main thread has been blocked for at least 'threshold' seconds
            _endTime = [NSDate timeIntervalSinceReferenceDate];
            RPTLog(@"Thread watcher: main thread blocked");

            uint_fast64_t ti = [_RPTTrackingManager.sharedInstance.tracker addDevice:@"main_thread_blocked" start:_startTime end:_endTime];
            if (!ti) RPTLog(@"Thread watcher: failed to add measurement");
        }
        
        dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    }
}

@end

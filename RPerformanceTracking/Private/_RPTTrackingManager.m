#import <RPerformanceTracking/RPTPerformanceMetric.h>
#import "_RPTTrackingManager.h"
#import "_RPTConfiguration.h"
#import "_RPTRingBuffer.h"
#import "_RPTSender.h"
#import "_RPTTracker.h"
#import "_RPTMetric.h"
#import "_RPTHelpers.h"
#import "_RPTEventWriter.h"
#import "_RPTLocation.h"
#import "_RPTMainThreadWatcher.h"
#import "_RPTEnvironment.h"
#import "_RPTClassManipulator.h"

static const NSUInteger      MAX_MEASUREMENTS               = 512u;
static const NSUInteger      TRACKING_DATA_LIMIT            = 100u;

static NSString *const       METRIC_LAUNCH                  = @"_launch";

static const NSUInteger      ARCRANDOM_MAX              = 0x100000000;

static const NSTimeInterval  REFRESH_CONFIG_INTERVAL        = 3600.0; // 1 hour
static const NSTimeInterval  MAIN_THREAD_BLOCK_THRESHOLD    = 0.4;

RPT_EXPORT @interface _RPTTrackingKey : NSObject<NSCopying>
@property (nonatomic, readonly) NSString      *identifier;
@property (nonatomic, readonly) NSObject      *object;
@end

@implementation _RPTTrackingKey
- (instancetype)initWithIdentifier:(NSString *)identifier
                            object:(NSObject *)object
{
    if ((self = [super init]))
    {
        _identifier = identifier;
        _object     = object;
    }
    return self;
}

- (NSUInteger)hash
{
    // Only the identifier and the object participate in equality testing
    return _identifier.hash ^ _object.hash;
}

- (BOOL)isEqual:(_RPTTrackingKey *)other
{
    // Only the identifier and the object participate in equality testing
    if (self == other) return YES;

    if (![other isMemberOfClass:self.class]) return NO;

    return
    (!_identifier || (other.identifier && [_identifier isEqualToString:other.identifier])) &&
    (!_object     || (other.object     && [_object     isEqual:other.object]));
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    return [[self.class allocWithZone:zone] initWithIdentifier:_identifier object:_object];
}
@end

@interface _RPTTrackingManager()
@property (nonatomic, readwrite) _RPTConfiguration    *configuration;
@property (nonatomic, readwrite) _RPTRingBuffer       *ringBuffer;
@property (nonatomic, readwrite) _RPTTracker          *tracker;
@property (nonatomic, readwrite) _RPTSender           *sender;
@property (nonatomic)            _RPTEventWriter      *eventWriter;
@property (nonatomic)            _RPTMetric           *currentMetric;
@property (nonatomic)            NSTimeInterval        refreshConfigInterval;
@property (nonatomic)            NSTimer              *refreshConfigTimer;
@property (nonatomic)            double                currentActivationRatio;
@property (nonatomic)            NSMutableDictionary<_RPTTrackingKey *, NSNumber *> *trackingData;
@property (nonatomic)            BOOL                  forceTrackingEnabled;
@property (nonatomic)            _RPTMainThreadWatcher *watcher;
@property (nonatomic, readwrite) BOOL                   disableSwizzling;
@end

/* RPT_EXPORT */ @implementation _RPTTrackingManager

- (instancetype)init
{
    if ((self = [super init]))
    {
        _refreshConfigInterval = REFRESH_CONFIG_INTERVAL;
        
        _refreshConfigTimer = [NSTimer timerWithTimeInterval:_refreshConfigInterval target:self selector:@selector(refreshConfigTimerFire:) userInfo:nil repeats:YES];
        _refreshConfigTimer.tolerance = _refreshConfigInterval * 0.1;
        [[NSRunLoop mainRunLoop] addTimer:_refreshConfigTimer forMode:NSRunLoopCommonModes];
        
        NSBundle *appBundle = NSBundle.mainBundle;
      
#if DEBUG
        _forceTrackingEnabled = [[appBundle objectForInfoDictionaryKey:@"RPTForceTrackingEnabled"] boolValue];
#endif
        _disableSwizzling = NO;
        
        do
        {
            _configuration = [_RPTConfiguration loadConfiguration];
            if (!_configuration) break;

            if ([self disableTracking] || boolForInfoPlistKey(@"RPTDeferSwizzlingUntilActivateResponseReceived"))
            {
                break;
            }
            
            if (![self setupTracking]) return nil;
            
        } while (0);
        
        // Note that the update call MUST be performed async so that we return an
        // initialized instance immediately.
        //
        // Otherwise there will be a crash due to nested dispatch_once calls that occurs
        // when NSURLSessionTask swizzling attempts to get RPTTrackingManager.shared
        // before the first call to RPTTrackingManager.shared has successfully returned.
        dispatch_async(dispatch_get_main_queue(), ^{
           [self updateConfiguration];
        });
    }
    return self;
}

+ (instancetype)sharedInstance
{
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (BOOL)setupTracking
{
    _trackingData = [NSMutableDictionary.alloc initWithCapacity:TRACKING_DATA_LIMIT];
    if (!_trackingData) return NO;
    
    _ringBuffer = [_RPTRingBuffer.alloc initWithSize:MAX_MEASUREMENTS];
    if (!_ringBuffer) return NO;
    
    _currentMetric = [_RPTMetric new];
    
    _tracker = [_RPTTracker.alloc initWithRingBuffer:_ringBuffer
                                       configuration:_configuration
                                       currentMetric:_currentMetric];
    if (!_tracker) return NO;
    
    _eventWriter = [_RPTEventWriter.alloc initWithConfiguration:_configuration];
    if (!_eventWriter) return NO;
    
    _sender = [_RPTSender.alloc initWithRingBuffer:_ringBuffer
                                     configuration:_configuration
                                     currentMetric:_currentMetric
                                       eventWriter:_eventWriter];
    if (!_sender) return NO;
    
    _eventWriter.delegate = _sender;
    
    [self addEndMetricObservers];
    [_sender start];
    
    // Profile main thread to check if it is running for > threshold time
    _watcher = [_RPTMainThreadWatcher.alloc initWithThreshold:MAIN_THREAD_BLOCK_THRESHOLD];
    [_watcher start];
    
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    
    return YES;
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)updateConfiguration
{
    [_RPTConfigurationFetcher fetchWithCompletionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        BOOL invalidConfig = NO;
        if (error)
        {
            invalidConfig = YES;
        }
        else if ([response isKindOfClass:NSHTTPURLResponse.class])
        {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
            if (httpResponse.statusCode != 200)
            {
                invalidConfig = YES;
            }
            else if (data)
            {
                // store "current" activation ratio because we are about to overwrite it
                if ((self.configuration = [_RPTConfiguration loadConfiguration]))
                {
                    self.currentActivationRatio = self.configuration.activationRatio;
                }
                
                _RPTConfiguration *config = [_RPTConfiguration.alloc initWithData:data];
                if (config)
                {
                    [_RPTConfiguration persistWithData:data];
                }
                else
                {
                    invalidConfig = YES;
                }
            }
        }
        
        // If the activation ratio is set to 0 on the portal, the server won't send anything, so the config will be nil.
        // It means that we will disable the method swizzling if the config is nil.
        self.disableSwizzling = invalidConfig;
        
        BOOL shouldDisableTracking = [self disableTracking];
        if (shouldDisableTracking || invalidConfig)
        {
            RPTLog(@"Tracking disabled: activation check response %@, Config API response %@", shouldDisableTracking?@"OFF":@"ON", invalidConfig?@"invalid":@"valid");
            [self stopTracking];
        }
        else
        {
            // config is valid and tracking enabled
            RPTLog(@"Valid config received and activation check returned true");
            
            if (boolForInfoPlistKey(@"RPTDeferSwizzlingUntilActivateResponseReceived") &&
                [_RPTLocation loadLocation])
            {
                // Location was already fetched and saved so this isn't first run post install
                [self setupTracking];
                [_RPTClassManipulator setupDeferredSwizzles];
            }
            
            [_RPTLocationFetcher fetch];
        }
    }];
}

- (BOOL)disableTracking
{
    double random_value = (double)arc4random() / ARCRANDOM_MAX;

    _configuration = [_RPTConfiguration loadConfiguration];
    
    return (random_value < 1.0 - _configuration.activationRatio || _configuration.activationRatio < _currentActivationRatio) && !_forceTrackingEnabled;
}

- (void)stopTracking
{
    // async in background because the sender stop is blocking
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.sender stop];
        self.tracker = nil;
    });
    [self invalidateRefreshConfigTimer];
    [_watcher cancel];
}

- (void)refreshConfigTimerFire:(__unused NSTimer *)timer
{
    [self updateConfiguration];
}

- (void)invalidateRefreshConfigTimer
{
    // The timer is added on the main thread, ensure timer is invalidated on the same thread that it was added.
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.refreshConfigTimer isValid])
        {
            [self.refreshConfigTimer invalidate];
        }
        self.refreshConfigTimer = nil;
    });
}

// MARK: Metric and measurement handling

// Auto-start
+ (void)load
{
    [_RPTTrackingManager.sharedInstance startMetric:METRIC_LAUNCH];
}

- (void)addEndMetricObservers
{
    for (NSString *notification in @[UITextFieldTextDidBeginEditingNotification,
                                     UITextViewTextDidBeginEditingNotification])
    {
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(endMetric) name:notification object:nil];
    }
}

- (void)endMetric
{
    @synchronized (self) {
        [_tracker endMetric];
    }
}

- (void)startMetric:(NSString *)metric
{
    @synchronized (self) {
        [_tracker startMetric:metric];
    }
}

- (void)prolongMetric
{
    @synchronized (self) {
        [_tracker prolongMetric];
    }
}

- (void)startMeasurement:(NSString *)measurement object:(nullable NSObject *)object
{
    @synchronized (self) {
        if (_tracker)
        {
            _RPTTrackingKey *key = [_RPTTrackingKey.alloc initWithIdentifier:measurement object:object];
            NSNumber *item = _trackingData[key];
            if (item == nil)
            {
                if (_trackingData.count == TRACKING_DATA_LIMIT) [_trackingData removeAllObjects];

                uint_fast64_t trackingIdentifier = [_tracker startCustom:measurement];
                if (trackingIdentifier) _trackingData[key] = @(trackingIdentifier);
            }
        }
    }
}

- (void)endMeasurement:(NSString *)measurement object:(nullable NSObject *)object
{
    @synchronized (self) {
        if (_tracker)
        {
            _RPTTrackingKey *key = [_RPTTrackingKey.alloc initWithIdentifier:measurement object:object];
            NSNumber *item = _trackingData[key];
            if (item != nil)
            {
                [_tracker end:(uint_fast64_t) item.unsignedLongLongValue];
                [_trackingData removeObjectForKey:key];
            }
        }
    }
}
@end

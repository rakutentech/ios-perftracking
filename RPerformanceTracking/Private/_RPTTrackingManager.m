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

static const NSUInteger      MAX_MEASUREMENTS           = 512u;
static const NSUInteger      TRACKING_DATA_LIMIT        = 100u;

static NSString *const       METRIC_LAUNCH              = @"_launch";

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconstant-conversion"
static const NSUInteger      ARCRANDOM_MAX              = 0x100000000;
#pragma clang diagnostic push

static const NSTimeInterval  REFRESH_CONFIG_INTERVAL    = 3600.0; // 1 hour

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
@property (nonatomic)            BOOL                 forceTrackingEnabled;
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
        
        do
        {
            _configuration = [_RPTConfiguration loadConfiguration];
            if (!_configuration) break;
            
            if ([self disableTracking]) break;
            
            _trackingData = [NSMutableDictionary.alloc initWithCapacity:TRACKING_DATA_LIMIT];
            if (!_trackingData) return nil;
            
            _ringBuffer = [_RPTRingBuffer.alloc initWithSize:MAX_MEASUREMENTS];
            if (!_ringBuffer) return nil;
            
            _currentMetric = [_RPTMetric new];
            
            _tracker = [_RPTTracker.alloc initWithRingBuffer:_ringBuffer currentMetric:_currentMetric];
            if (!_tracker) return nil;
            
            _eventWriter = [_RPTEventWriter.alloc initWithConfiguration:_configuration];
            if (!_eventWriter) return nil;
            
            _sender = [_RPTSender.alloc initWithRingBuffer:_ringBuffer
                                             configuration:_configuration
                                             currentMetric:_currentMetric
                                               eventWriter:_eventWriter];
            if (!_sender) return nil;
            
            _eventWriter.delegate = _sender;
            
            [self addEndMetricObservers];
            [_sender start];
            
        } while (0);
        
        [self updateConfiguration];
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

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (BOOL)disableTracking
{
    double random_value = (double)arc4random() / ARCRANDOM_MAX;

    _configuration = [_RPTConfiguration loadConfiguration];
    
    return (random_value < 1.0 - _configuration.activationRatio || _configuration.activationRatio < _currentActivationRatio) && !_forceTrackingEnabled;
}

// FIXME : fix "-Wnullable-to-nonnull-conversion" warning, then remove pragma
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
- (void)updateConfiguration
{
    NSBundle *thisBundle    = [NSBundle bundleForClass:self.class];
    NSString *thisVersion   = [thisBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    
    NSBundle *appBundle     = NSBundle.mainBundle;
    NSString *relayAppID    = [appBundle objectForInfoDictionaryKey:@"RPTRelayAppID"];
    NSString *appVersion    = [appBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    
    NSString *country       = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    
    NSString *path = [NSString stringWithFormat:@"/platform/ios/"];
    if (relayAppID.length){ path = [path stringByAppendingString:[NSString stringWithFormat:@"app/%@/", relayAppID]]; }
#if DEBUG
    NSAssert(relayAppID.length, @"Your application's Info.plist must contain a key 'RPTRelayAppID' set to the relay Portal application ID");
#endif
    
    path = [path stringByAppendingString:[NSString stringWithFormat:@"version/%@/", appVersion]];
    
    NSURLSessionConfiguration *sessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration;
    
    NSURL *base = nil;
    NSString *baseURLString = [appBundle objectForInfoDictionaryKey:@"RPTConfigAPIEndpoint"];
    if (baseURLString.length) { base = [NSURL URLWithString:baseURLString]; }
#if DEBUG
    NSAssert(base, @"Your application's Info.plist must contain a key 'RPTConfigAPIEndpoint' set to the endpoint URL of your Config API");
#endif
		
    NSString *subscriptionKey = [appBundle objectForInfoDictionaryKey:@"RPTSubscriptionKey"];
    if (subscriptionKey.length) { sessionConfiguration.HTTPAdditionalHeaders = @{@"Ocp-Apim-Subscription-Key":subscriptionKey}; }
#if DEBUG
    NSAssert(subscriptionKey.length, @"Your application's Info.plist file must contain a key 'RPTSubscriptionKey' which should be set to your 'Ocp-Apim-Subscription-Key' from the API Portal");
#endif
    
    _forceTrackingEnabled = [[appBundle objectForInfoDictionaryKey:@"RPTForceTrackingEnabledKey"] boolValue];
    _disableProtocolWebviewObserving = [[appBundle objectForInfoDictionaryKey:@"RPTDisableProtocolWebviewObserving"] boolValue];
    
    NSURL *url = [base URLByAppendingPathComponent:path];
    
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    components.query = [NSString stringWithFormat:@"sdk=%@&country=%@", thisVersion, country];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
    [[session dataTaskWithURL:components.URL completionHandler:^(NSData *data, __unused NSURLResponse *response, __unused NSError * error)
      {
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

          BOOL disableTracking = [self disableTracking];
          if (disableTracking || invalidConfig)
          {
              RPTLog(@"Tracking disabled: activation check response %@, Config API response %@", disableTracking?@"OFF":@"ON", invalidConfig?@"invalid":@"valid");
              
              // async in background because the sender stop is blocking
              dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                  [self.sender stop];
                  self.tracker = nil;
              });
              [self invalidateRefreshConfigTimer];
          }
          else
          {
              // config is valid and tracking enabled
              if (self.tracker) [self refreshLocation];
          }
      }] resume];
}
- (void)refreshLocation
{
	NSURLSessionConfiguration *sessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration;
	NSString *subscriptionKey = [NSBundle.mainBundle objectForInfoDictionaryKey:@"RPTSubscriptionKey"];
	
    NSURL *locationURL = nil;
    NSString *locationURLString = [NSBundle.mainBundle objectForInfoDictionaryKey:@"RPTLocationAPIEndpoint"];
    
    if (locationURLString.length) { locationURL = [NSURL URLWithString:locationURLString]; }
#if DEBUG
    NSAssert(locationURL, @"Your application's Info.plist must contain a key 'RPTLocationAPIEndpoint' set to the endpoint URL of your Location API");
#endif
	
	if (subscriptionKey) { sessionConfiguration.HTTPAdditionalHeaders = @{@"Ocp-Apim-Subscription-Key":subscriptionKey}; }
	
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
	
	[[session dataTaskWithURL:locationURL completionHandler:^(NSData *data, __unused NSURLResponse *response, __unused NSError * error)
	  {
		  if (!error && [response isKindOfClass:NSHTTPURLResponse.class])
		  {
			  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
			  if (httpResponse.statusCode == 200 && data)
			  {
				  _RPTLocation *locationConfig = [_RPTLocation.alloc initWithData:data];
				  if (locationConfig)
				  {
					  [_RPTLocation persistWithData:data];
				  }
			  }
		  }
	  }] resume];
}
#pragma clang diagnostic pop

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

- (void)startMeasurement:(NSString *)measurement object:(NSObject *)object
{
    @synchronized (self) {
        if (_tracker)
        {
            _RPTTrackingKey *key = [_RPTTrackingKey.alloc initWithIdentifier:measurement object:object];
            NSNumber *item = _trackingData[key];
            if (!item)
            {
                if (_trackingData.count == TRACKING_DATA_LIMIT) [_trackingData removeAllObjects];

                uint_fast64_t trackingIdentifier = [_tracker startCustom:measurement];
                if (trackingIdentifier) _trackingData[key] = @(trackingIdentifier);
            }
        }
    }
}

- (void)endMeasurement:(NSString *)measurement object:(NSObject *)object
{
    @synchronized (self) {
        if (_tracker)
        {
            _RPTTrackingKey *key = [_RPTTrackingKey.alloc initWithIdentifier:measurement object:object];
            NSNumber *item = _trackingData[key];
            if (item)
            {
                [_tracker end:(uint_fast64_t) item.unsignedLongLongValue];
                [_trackingData removeObjectForKey:key];
            }
        }
    }
}
@end

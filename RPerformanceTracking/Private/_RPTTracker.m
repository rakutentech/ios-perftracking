#import "_RPTTracker.h"
#import "_RPTMetric.h"
#import "_RPTMeasurement.h"
#import "_RPTRingBuffer.h"
#import "_RPTTrackingManager.h"

@interface _RPTTracker ()
@property (atomic) _RPTMetric *currentMetric;
@end

/* RPT_EXPORT */ @implementation _RPTTracker

- (instancetype)init NS_UNAVAILABLE
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)startMetric:(NSString *)metricIdentifier
{
    @synchronized(self)
    {
        _currentMetric = nil;
        _RPTMetric *metric = [_RPTMetric new];
        metric.identifier = metricIdentifier;

        _RPTMeasurement *measurement = [self _startWithKind:_RPTMetricMeasurementKind receiver:metric method:nil];
        if (measurement)
        {
            metric.startTime = measurement.startTime;
            metric.endTime = measurement.endTime;
            _currentMetric = metric;
        }
    }
}

- (void)prolongMetric
{
    @synchronized(self)
    {
        _RPTMetric *metric = _currentMetric;
        if (metric)
        {
            NSTimeInterval now = [NSDate.date timeIntervalSince1970];
            
            metric.endTime = now;
            
            if (now - metric.startTime > _RPT_METRIC_MAXTIME)
            {
                _currentMetric = nil;
            }
        }
    }
}

- (void)endMetric
{
    @synchronized(self)
    {
        _currentMetric = nil;
    }
}

- (uint_fast64_t)startMethod:(NSString *)method receiver:(NSObject *)receiver
{
    _RPTMeasurement *measurement = [self _startWithKind:_RPTMethodMeasurementKind receiver:NSStringFromClass([receiver class]) method:method];
    return measurement ? measurement.trackingIdentifier : 0;
}

- (uint_fast64_t)startRequest:(NSURLRequest *)request
{
    NSString *urlString = request.URL.absoluteString;
    if (!urlString) return 0;

    NSString *method    = request.HTTPMethod.uppercaseString ?: @"GET";
    _RPTMeasurement *measurement = [self _startWithKind:_RPTURLMeasurementKind receiver:urlString method:method];
    return measurement ? measurement.trackingIdentifier : 0;
}

- (uint_fast64_t)startCustom:(NSString *)custom
{
    _RPTMeasurement *measurement = [self _startWithKind:_RPTCustomMeasurementKind receiver:custom.copy method:nil];
    return measurement ? measurement.trackingIdentifier : 0;
}

- (uint_fast64_t)addDevice:(NSString *)name start:(NSTimeInterval)startTime end:(NSTimeInterval)endTime
{
    _RPTMeasurement *measurement = [self _startWithKind:_RPTDeviceMeasurementKind receiver:name.copy method:nil];
    
    measurement.startTime = startTime; // override value set by _startWithKind
    measurement.endTime = endTime;
    
    return measurement ? measurement.trackingIdentifier : 0;
}

- (void)end:(uint_fast64_t)trackingIdentifier
{
    if (trackingIdentifier)
    {
        _RPTMeasurement *measurement = [_ringBuffer measurementWithTrackingIdentifier:trackingIdentifier];
        measurement.endTime = [NSDate.date timeIntervalSince1970];
    }
}

- (_RPTMeasurement *)_startWithKind:(_RPTMeasurementKind)kind receiver:(NSObject *)receiver method:(nullable NSString *)method
{
    _RPTMeasurement *measurement = _ringBuffer.nextMeasurement;
    if (measurement)
    {
        measurement.kind      = kind;
        measurement.receiver  = receiver;
        measurement.method    = method;
        measurement.startTime = [NSDate.date timeIntervalSince1970];
        if (_RPTTrackingManager.sharedInstance.currentScreen.length)
        {
            measurement.screen = _RPTTrackingManager.sharedInstance.currentScreen;
        }
    }
    return measurement;
}

- (instancetype)initWithRingBuffer:(_RPTRingBuffer *)ringBuffer currentMetric:(nonnull _RPTMetric *)currentMetric
{
    if ((self = [super init]))
    {
        _ringBuffer = ringBuffer;
        _currentMetric = currentMetric;
    }
    return self;
}

@end

#import "_RPTTracker.h"
#import "_RPTMetric.h"
#import "_RPTMeasurement.h"
#import "_RPTRingBuffer.h"
#import "_RPTTrackingManager.h"
#import "_RPTEventBroadcast.h"
#import "NSURL+RPerformanceTracking.h"
#import "_RPTHelpers.h"
#import "_RPTConfiguration.h"

@interface _RPTTracker ()
@property (atomic) _RPTMetric *currentMetric;
@property (nonatomic) _RPTConfiguration *configuration;
@end

/* RPT_EXPORT */ @implementation _RPTTracker

- (instancetype)init NS_UNAVAILABLE {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)startMetric:(NSString *)metricIdentifier {
    @synchronized(self) {
        _currentMetric = nil;
        _RPTMetric *metric = [_RPTMetric new];
        metric.identifier = metricIdentifier;

        _RPTMeasurement *measurement = [self _startWithKind:_RPTMetricMeasurementKind receiver:metric method:nil metric:metric];
        if (measurement) {
            metric.startTime = measurement.startTime;
            metric.endTime = measurement.endTime;
            _currentMetric = metric;
        }
    }
}

- (void)prolongMetric {
    @synchronized(self) {
        _RPTMetric *metric = _currentMetric;
        if (metric) {
            NSTimeInterval now = [NSDate.date timeIntervalSince1970];

            metric.endTime = now;

            NSTimeInterval maxDurationInSecs = [_RPTMetric maxDurationInSecs];
            if (now - metric.startTime > maxDurationInSecs) {
                // Metric has timed out
                RPTLog(@"Metric %@ that started at %@ has been nil'd because it exceeded the max duration of %f seconds when attempting to prolong it at %@", metric.identifier, [NSDate dateWithTimeIntervalSince1970:metric.startTime], maxDurationInSecs, [NSDate dateWithTimeIntervalSince1970:now]);
                _currentMetric = nil;
            }
        }
    }
}

- (void)endMetric {
    @synchronized(self) {
        _currentMetric = nil;
    }
}

- (uint_fast64_t)startMethod:(NSString *)method receiver:(NSObject *)receiver {
    _RPTMeasurement *measurement = [self _startWithKind:_RPTMethodMeasurementKind receiver:NSStringFromClass([receiver class]) method:method];
    return measurement ? measurement.trackingIdentifier : 0;
}

- (uint_fast64_t)startRequest:(NSURLRequest *)request {
    NSString *urlString = request.URL.absoluteString;
    if (!urlString.length)
        return 0;

    NSString *method = request.HTTPMethod.uppercaseString ?: @"GET";
    _RPTMeasurement *measurement = [self _startWithKind:_RPTURLMeasurementKind receiver:urlString method:method];
    return measurement ? measurement.trackingIdentifier : 0;
}

- (uint_fast64_t)startCustom:(NSString *)custom {
    _RPTMeasurement *measurement = [self _startWithKind:_RPTCustomMeasurementKind receiver:custom.copy method:nil];
    return measurement ? measurement.trackingIdentifier : 0;
}

- (uint_fast64_t)addDevice:(NSString *)name start:(NSTimeInterval)startTime end:(NSTimeInterval)endTime {
    _RPTMeasurement *measurement = [self _startWithKind:_RPTDeviceMeasurementKind receiver:name.copy method:nil];

    measurement.startTime = startTime; // override value set by _startWithKind
    measurement.endTime = endTime;

    return measurement ? measurement.trackingIdentifier : 0;
}

- (void)end:(uint_fast64_t)trackingIdentifier {
    if (trackingIdentifier) {
        _RPTMeasurement *measurement = [_ringBuffer measurementWithTrackingIdentifier:trackingIdentifier];
        measurement.endTime = [NSDate.date timeIntervalSince1970];
    }
}

- (void)updateStatusCode:(NSInteger)statusCode trackingIdentifier:(uint_fast64_t)trackingIdentifier {
    if (trackingIdentifier) {
        _RPTMeasurement *measurement = [_ringBuffer measurementWithTrackingIdentifier:trackingIdentifier];
        measurement.statusCode = statusCode;
    }
}

- (void)updateURL:(NSURL *)url trackingIdentifier:(uint_fast64_t)trackingIdentifier {
    if (trackingIdentifier) {
        _RPTMeasurement *measurement = [_ringBuffer measurementWithTrackingIdentifier:trackingIdentifier];
        if (measurement.kind == _RPTURLMeasurementKind) {
            measurement.receiver = url.absoluteString;
        }
    }
}

- (void)sendResponseHeaders:(NSDictionary *)responseHeaders trackingIdentifier:(uint_fast64_t)trackingIdentifier {
    if (!_configuration.shouldSendDataToRAT) {
        return;
    }

    _RPTMeasurement *measurement = [_ringBuffer measurementWithTrackingIdentifier:trackingIdentifier];
    NSString *sourceURLString = (NSString *)measurement.receiver;
    if (!sourceURLString.length || [[NSURL URLWithString:sourceURLString] isBlacklisted]) {
        return;
    }

    int64_t startTime = _RPTTimeIntervalInMiliseconds(measurement.startTime);
    int64_t responseEnd = _RPTTimeIntervalInMiliseconds(measurement.endTime);
    int64_t duration = MAX(0ll, responseEnd - startTime);
    NSString *cdn = responseHeaders[@"x-cdn-served-from"];
    NSMutableDictionary *dataEntry = [NSMutableDictionary dictionary];
    dataEntry[@"start_time"] = @(startTime);
    dataEntry[@"response_end"] = @(responseEnd);
    dataEntry[@"duration"] = @(duration);
    dataEntry[@"name"] = sourceURLString;
    if (cdn.length) {
        dataEntry[@"cdn"] = cdn;
    }
    NSDictionary *perfData = @{@"perfdata": @{@"type": @"resource",
                                              @"entries": @[dataEntry.copy]}};
    [_RPTEventBroadcast sendEventName:@"perf" topLevelDataObject:perfData];
}

- (_RPTMeasurement *)_startWithKind:(_RPTMeasurementKind)kind receiver:(NSObject *)receiver method:(nullable NSString *)method {
    return [self _startWithKind:kind
                       receiver:receiver
                         method:method
                         metric:_currentMetric];
}

- (_RPTMeasurement *)_startWithKind:(_RPTMeasurementKind)kind receiver:(NSObject *)receiver method:(nullable NSString *)method metric:(_RPTMetric *)metric {
    if (!_configuration.shouldTrackNonMetricMeasurements && !metric) {
        return nil;
    }

    _RPTMeasurement *measurement = _ringBuffer.nextMeasurement;
    if (measurement) {
        measurement.kind = kind;
        measurement.receiver = receiver;
        measurement.method = method;
        measurement.startTime = [NSDate.date timeIntervalSince1970];
        if (_RPTTrackingManager.sharedInstance.currentScreen.length) {
            measurement.screen = _RPTTrackingManager.sharedInstance.currentScreen;
        }
    }
    return measurement;
}

- (instancetype)initWithRingBuffer:(_RPTRingBuffer *)ringBuffer
                     configuration:(_RPTConfiguration *)configuration
                     currentMetric:(nonnull _RPTMetric *)currentMetric {
    if ((self = [super init])) {
        _ringBuffer = ringBuffer;
        _currentMetric = currentMetric;
        _configuration = configuration;
    }
    return self;
}

@end

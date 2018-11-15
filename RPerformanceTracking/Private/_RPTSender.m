#import "_RPTSender.h"
#import "_RPTRingBuffer.h"
#import "_RPTMeasurement.h"
#import "_RPTMetric.h"
#import "_RPTEventWriter.h"
#import "_RPTHelpers.h"
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"
#import "_RPTConfiguration.h"

static const NSInteger      MIN_COUNT                   = 10;
static const NSTimeInterval SLEEP_INTERVAL_SECONDS      = 10.0; // 10s
static const NSTimeInterval MIN_TIME_METRIC             = 5.0 / 1000; // 5ms
static const NSTimeInterval MIN_TIME_MEASUREMENT        = 1.0 / 1000; // 1ms
static const NSTimeInterval SLEEP_MAX_INTERVAL          = 1800; // 30 minutes

@interface _RPTTrackingManager()
@property (nonatomic, readwrite) _RPTTracker    *tracker;
@end

@interface _RPTSender ()
@property (nonatomic) _RPTRingBuffer            *ringBuffer;
@property (nonatomic) _RPTConfiguration         *configuration;
@property (nonatomic) _RPTEventWriter           *eventWriter;
@property (nonatomic) NSOperationQueue          *backgroundQueue;
@property (nonatomic) NSInvocationOperation     *backgroundOperation;
@property (nonatomic) NSTimeInterval             sleepInterval;
@property (nonatomic) NSUInteger                 sentCount;
@property (nonatomic) NSInteger                  failures;
@property (atomic)    _RPTMetric                *currentMetric;
@property (nonatomic) _RPTMetric                *metric;
@property (nonatomic) _RPTMetric                *savedMetric;
@property (nonatomic, nullable) NSURLResponse   *response;
@property (nonatomic, nullable) NSError         *error;
@end

/* RPT_EXPORT */ @implementation _RPTSender

- (instancetype)init NS_UNAVAILABLE
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initWithRingBuffer:(_RPTRingBuffer *)ringBuffer
                     configuration:(_RPTConfiguration *)configuration
                     currentMetric:(_RPTMetric *)currentMetric
                       eventWriter:(_RPTEventWriter *)eventWriter
{
    if ((self = [super init]))
    {
        _ringBuffer       = ringBuffer;
        _configuration    = configuration;
        _currentMetric    = currentMetric;
        _eventWriter      = eventWriter;
        _sleepInterval    = SLEEP_INTERVAL_SECONDS;

        _backgroundQueue      = NSOperationQueue.new;
        _backgroundQueue.name = @"com.rakuten.tech.perf";
        _backgroundOperation  = [NSInvocationOperation.alloc initWithTarget:self
                                                                   selector:@selector(processLoop)
                                                                     object:nil];
        _failures = 0;
    }
    return self;
}

- (void)start
{
    if (![_backgroundQueue.operations containsObject:_backgroundOperation])
    {
        // Operation is not already queued
        _backgroundOperation  = [NSInvocationOperation.alloc initWithTarget:self
                                                                   selector:@selector(processLoop)
                                                                     object:nil];
        [_backgroundQueue addOperation:_backgroundOperation];
    }
}

- (void)stop
{
    if (_backgroundOperation &&
        _backgroundQueue.operationCount &&
        [_backgroundQueue.operations containsObject:_backgroundOperation])
    {
        [_backgroundOperation cancel];
        [_backgroundQueue waitUntilAllOperationsAreFinished];
        _backgroundOperation = nil;
    }
}

- (void)processLoop
{
    assert(NSOperationQueue.currentQueue == _backgroundQueue);

    NSUInteger index = 1;

    while (true)
    {
        if (_backgroundOperation.isCancelled)
        {
            break;
        }

        NSUInteger idIndex = ([_ringBuffer nextMeasurement].trackingIdentifier % _ringBuffer.size);
        NSInteger count = (NSInteger)(idIndex - index);

        if (count < 0)
        {
            count += _ringBuffer.size;
        }
        
        if (count >= MIN_COUNT)
        {
            index = [self sendWithStartIndex:index endIndex:idIndex];
        }
        
        NSTimeInterval sleepTime = MIN(SLEEP_MAX_INTERVAL, pow(2, MIN(10, _failures)) * _sleepInterval);
        [NSThread sleepForTimeInterval:sleepTime];
    }
}

- (NSUInteger)sendWithStartIndex:(NSUInteger)startIndex endIndex:(NSUInteger)endIndex
{
    RPTLogVerbose(@"RPTSender sendWithStartIndex %ld endIndex %ld", (long)startIndex, (long)endIndex);
    NSUInteger returnIndex = startIndex;
    NSTimeInterval now             = [NSDate.date timeIntervalSince1970];
    _sentCount                     = 0;
    _savedMetric = _metric ? _metric.copy : nil;

    @synchronized (self)
    {
        for (NSUInteger i = startIndex; i != endIndex; i = (i + 1) % _ringBuffer.size)
        {
            _RPTMeasurement *measurement = [_ringBuffer measurementAtIndex:(unsigned long)i];

            if (measurement.kind == _RPTMetricMeasurementKind)
            {
                if (_metric)
                {
                    [self writeMetric:_metric];
                    _metric = nil;
                }

                _RPTMetric *metric = (_RPTMetric *)measurement.receiver;

                if (metric == _currentMetric)
                {
                    if (now - measurement.startTime < _RPT_METRIC_MAXTIME)
                    {
                        return i;
                    }
                    _currentMetric = nil;
                }

                _metric = metric;
                [measurement clear];
            }
            else
            {
                NSTimeInterval startTime = measurement.startTime;
                NSTimeInterval endTime   = measurement.endTime;

                if (endTime <= 0)
                {
                    if (now - startTime < _RPT_MEASUREMENT_MAXTIME)
                    {
                        return i;
                    }

                    [measurement clear];
                    continue;
                }

                if (_metric && (startTime > _metric.endTime))
                {
                    [self writeMetric:_metric];
                    _metric = nil;
                }

                if (_metric && (measurement.kind == _RPTURLMeasurementKind))
                {
                    _metric.urlCount++;
                }

                [self writeMeasurement:measurement metricId:_metric ? _metric.identifier : nil];
                [measurement clear];
            }
        }

        returnIndex = [self indexAfterSendingWithStartIndex:startIndex endIndex:endIndex];
    }

    return returnIndex;
}

- (void)writeMetric:(_RPTMetric *)metric
{
    if (!_configuration.shouldSendDataToPerformanceTracking || (metric.endTime - metric.startTime < MIN_TIME_METRIC)) { return; }

    if (!_sentCount) { [_eventWriter begin]; }

    [_eventWriter writeWithMetric:metric];
    _sentCount++;
}

- (void)writeMeasurement:(_RPTMeasurement *)measurement metricId:(NSString *)metricId
{
    if (!_configuration.shouldSendDataToPerformanceTracking ||
        (!_configuration.shouldTrackNonMetricMeasurements && !metricId.length) ||
        (measurement.endTime - measurement.startTime < MIN_TIME_MEASUREMENT)) { return; }

    if (!_sentCount) { [_eventWriter begin]; }

    [_eventWriter writeWithMeasurement:measurement metricIdentifier:metricId];
    _sentCount++;
}

- (NSUInteger)indexAfterSendingWithStartIndex:(NSUInteger)startIndex endIndex:(NSUInteger)endIndex
{
    NSUInteger returnIndex = startIndex;
    // if _sentCount == 0, don't send metric.
    if (_sentCount == 0)
    {
        returnIndex = endIndex;
    }
    else
    {
        _response = nil;
        _error = nil;

        [_eventWriter end];

        // here the response and error are updated. Because the 'end' method is excuted synchronously.
        if (_error)
        {
            _failures ++;
            _metric = _savedMetric;
        }
        else if ([_response isKindOfClass:NSHTTPURLResponse.class])
        {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) _response;
            if (httpResponse.statusCode == 201) // Created
            {
                _failures = 0;
                returnIndex = endIndex;
            }
            else if (httpResponse.statusCode == 401) // Unauthorized
            {
                [_RPTTrackingManager sharedInstance].tracker = nil;
                [self stop];
            }
            else
            {
                _failures ++;
                _metric = _savedMetric;
            }
        }
    }
    return returnIndex;
}

#pragma mark - EventWriter protocol
- (void)handleURLResponse:(nullable NSURLResponse *)response error:(nullable NSError *)error;
{
    _response = response;
    _error = error;
}

@end

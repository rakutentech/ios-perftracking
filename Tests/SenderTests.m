@import XCTest;
@import RPerformanceTracking;
#import "_RPTRingBuffer.h"
#import "_RPTMetric.h"
#import "_RPTMeasurement.h"
#import "_RPTSender.h"
#import "_RPTTracker.h"
#import "_RPTConfiguration.h"
#import "_RPTEventWriter.h"
#import "TestUtils.h"
#import <OHHTTPStubs/OHHTTPStubs.h>

#import <Kiwi/Kiwi.h>
#import "TestUtils.h"

static const NSUInteger      MAX_MEASUREMENTS    = 512u;

@interface _RPTSender ()
@property (nonatomic) _RPTConfiguration     *configuration;
@property (nonatomic) _RPTEventWriter       *eventWriter;
@property (nonatomic) NSOperationQueue      *backgroundQueue;
@property (nonatomic) NSTimeInterval         sleepInterval;
@property (nonatomic) _RPTMetric            *metric;
@property (nonatomic) NSUInteger             failures;
@property (nonatomic) NSUInteger             sentCount;

- (NSInteger)indexAfterSendingWithStartIndex:(NSInteger)startIndex endIndex:(NSInteger)endIndex;
- (void)writeMetric:(_RPTMetric *)metric;
- (void)writeMeasurement:(_RPTMeasurement *)measurement metricId:(NSString *)metricId;
@end

SPEC_BEGIN(RPTSenderTests)

describe(@"RPTSender", ^{

    __block _RPTConfiguration *config;
    __block _RPTMetric *metric;
    __block _RPTSender *sender;
    __block _RPTEventWriter *eventWriter;
    beforeEach(^{
        config = [_RPTConfiguration nullMock];
        [config stub:@selector(shouldSendDataToPerformanceTracking) andReturn:theValue(true)];
        eventWriter        = [_RPTEventWriter.alloc initWithConfiguration:config];
        metric = [_RPTMetric nullMock];
        [metric stub:@selector(identifier) andReturn:@"metric"];
        [metric stub:@selector(startTime) andReturn:theValue(1)];
        [metric stub:@selector(endTime) andReturn:theValue(2)];
        sender = [_RPTSender.alloc initWithRingBuffer:mkRingBufferStub(nil)
                                                    configuration:config
                                                    currentMetric:metric
                                                      eventWriter:eventWriter];
    });

    afterEach(^{
        config = nil;
        metric = nil;
        sender = nil;
        eventWriter = nil;
    });

    describe(@"sendMetric", ^{
        context(@"shouldSendDataToPerformanceTracking", ^{
            it(@"should call 'writeWithMetric:' method of eventWriter if shouldSendDataToPerformanceTracking of configuration is true", ^{
                [config stub:@selector(shouldSendDataToPerformanceTracking) andReturn:theValue(true)];

                [[eventWriter should] receive:@selector(writeWithMetric:)];

                [sender writeMetric:metric];
            });

            it(@"should not call 'writeWithMetric:' method of eventWriter if shouldSendDataToPerformanceTracking of configuration is false", ^{
                [config stub:@selector(shouldSendDataToPerformanceTracking) andReturn:theValue(false)];

                [[eventWriter shouldNot] receive:@selector(writeWithMetric:)];

                [sender writeMetric:metric];
            });
        });

        context(@"metric duration", ^{
            it(@"should call 'writeWithMetric:' method of eventWriter if the metric's duration is greater or equal than MIN_TIME_METRIC(= 5ms)", ^{
                [metric stub:@selector(startTime) andReturn:theValue(1)];
                [metric stub:@selector(endTime) andReturn:theValue(1.0051)];

                [[eventWriter should] receive:@selector(writeWithMetric:)];

                [sender writeMetric:metric];
            });

            it(@"should not call 'writeWithMetric:' method of eventWriter if the metric's duration is less than MIN_TIME_METRIC(= 5ms)", ^{
                [metric stub:@selector(startTime) andReturn:theValue(1)];
                [metric stub:@selector(endTime) andReturn:theValue(1.0049)];

                [[eventWriter shouldNot] receive:@selector(writeWithMetric:)];

                [sender writeMetric:metric];
            });
        });
    });

    context(@"sendMeasurementWithMetric", ^{
        __block _RPTMeasurement *measurement;
        beforeEach(^{
            measurement = [_RPTMeasurement nullMock];
            [measurement stub:@selector(trackingIdentifier) andReturn:theValue(1)];
            [measurement stub:@selector(startTime) andReturn:theValue(1)];
            [measurement stub:@selector(endTime) andReturn:theValue(2)];
        });

        afterEach(^{
            measurement = nil;
        });

        context(@"shouldSendDataToPerformanceTracking", ^{
            it(@"should call 'writeWithMeasurement:metricIdentifier:' method of eventWriter if shouldSendDataToPerformanceTracking of configuration is true", ^{
                [config stub:@selector(shouldSendDataToPerformanceTracking) andReturn:theValue(true)];

                [[eventWriter should] receive:@selector(writeWithMeasurement:metricIdentifier:)];

                [sender writeMeasurement:measurement metricId:metric.identifier];
            });

            it(@"should not call 'writeWithMeasurement:metricIdentifier:' method of eventWriter if shouldSendDataToPerformanceTracking of configuration is false", ^{
                [config stub:@selector(shouldSendDataToPerformanceTracking) andReturn:theValue(false)];

                [[eventWriter shouldNot] receive:@selector(writeWithMeasurement:metricIdentifier:)];

                [sender writeMeasurement:measurement metricId:metric.identifier];
            });
        });

        context(@"shouldTrackNonMetricMeasurements", ^{
            it(@"should call 'writeWithMeasurement:metricIdentifier:' method of eventWriter if shouldTrackNonMetricMeasurements of configuration is true and the metric's identifier is nil", ^{
                [config stub:@selector(shouldTrackNonMetricMeasurements) andReturn:theValue(true)];
                [metric stub:@selector(identifier) andReturn:nil];

                [[eventWriter should] receive:@selector(writeWithMeasurement:metricIdentifier:)];

                [sender writeMeasurement:measurement metricId:metric.identifier];
            });

            it(@"should not call 'writeWithMeasurement:metricIdentifier:' method of eventWriter if shouldTrackNonMetricMeasurements of configuration is false and the metric's identifier is nil", ^{
                [config stub:@selector(shouldTrackNonMetricMeasurements) andReturn:theValue(false)];
                [metric stub:@selector(identifier) andReturn:nil];

                [[eventWriter shouldNot] receive:@selector(writeWithMeasurement:metricIdentifier:)];

                [sender writeMeasurement:measurement metricId:metric.identifier];
            });

            it(@"should call 'writeWithMeasurement:metricIdentifier:' method of eventWriter if shouldTrackNonMetricMeasurements of configuration is true and the metric's identifier is empty", ^{
                [config stub:@selector(shouldTrackNonMetricMeasurements) andReturn:theValue(true)];
                [metric stub:@selector(identifier) andReturn:@""];

                [[eventWriter should] receive:@selector(writeWithMeasurement:metricIdentifier:)];

                [sender writeMeasurement:measurement metricId:metric.identifier];
            });

            it(@"should not call 'writeWithMeasurement:metricIdentifier:' method of eventWriter if shouldTrackNonMetricMeasurements of configuration is false and the metric's identifier is empty", ^{
                [config stub:@selector(shouldTrackNonMetricMeasurements) andReturn:theValue(false)];
                [metric stub:@selector(identifier) andReturn:@""];

                [[eventWriter shouldNot] receive:@selector(writeWithMeasurement:metricIdentifier:)];

                [sender writeMeasurement:measurement metricId:metric.identifier];
            });
        });

        context(@"measurement duration", ^{
            it(@"should call 'writeWithMeasurement:metricIdentifier:' method of eventWriter if the measurement's duration is greater or equal than MIN_TIME_MEASUREMENT(= 1ms)", ^{
                [measurement stub:@selector(startTime) andReturn:theValue(1)];
                [measurement stub:@selector(endTime) andReturn:theValue(1.0011)];

                [[eventWriter should] receive:@selector(writeWithMeasurement:metricIdentifier:)];

                [sender writeMeasurement:measurement metricId:metric.identifier];
            });

            it(@"should not call 'writeWithMeasurement:metricIdentifier:' method of eventWriter if the measurement's duration is less than MIN_TIME_MEASUREMENT(= 1ms)", ^{
                [measurement stub:@selector(startTime) andReturn:theValue(1)];
                [measurement stub:@selector(endTime) andReturn:theValue(1.0005)];

                [[eventWriter shouldNot] receive:@selector(writeWithMeasurement:metricIdentifier:)];

                [sender writeMeasurement:measurement metricId:metric.identifier];
            });
        });
    });
});

SPEC_END

@interface SenderTests : XCTestCase
@property (nonatomic) _RPTSender           *sender;
@end

@implementation SenderTests

- (void)setUp
{
    [super setUp];
    _RPTConfiguration *configuration    = mkConfigurationStub(nil);
    _RPTEventWriter *eventWriter        = [_RPTEventWriter.alloc initWithConfiguration:configuration];
    _RPTRingBuffer *ringBuffer          = [_RPTRingBuffer.alloc initWithSize:MAX_MEASUREMENTS];
    _sender                             = [_RPTSender.alloc initWithRingBuffer:ringBuffer configuration:configuration currentMetric:_RPTMetric.new eventWriter:eventWriter];
    eventWriter.delegate = _sender;
}

- (void)tearDown
{
    [_sender stop];
    _sender = nil;
    [NSUserDefaults.standardUserDefaults setObject:nil forKey:@"com.rakuten.performancetracking"];
    [OHHTTPStubs removeAllStubs];
    [super tearDown];
}

- (_RPTMeasurement *)defaultMetricMeasurement
{
    _RPTMeasurement *measurement = [_RPTMeasurement.alloc init];
    measurement.kind = _RPTMetricMeasurementKind;
    measurement.trackingIdentifier = 10;

    _RPTMetric *receiver = [_RPTMetric new];
    receiver.identifier = @"other_metric";
    receiver.urlCount = 15;
    measurement.receiver = receiver;

    measurement.startTime = 1;
    measurement.endTime = 4.5;
    return measurement;
}

- (void)testThatSenderCanBeStarted
{
    [_sender start];
    XCTAssertEqualObjects([_sender backgroundQueue].name, @"com.rakuten.tech.perf");
}

- (void)testThatStartedSenderHasQueueOperation
{
    [_sender start];
    XCTAssert([_sender backgroundQueue].operationCount == 1);
}

- (void)testThatSenderCanBeStopped
{
    _sender.sleepInterval = 0.5;
    [_sender start];

    XCTestExpectation *expectation = [self expectationWithDescription:@"wait"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        XCTAssert([self.sender backgroundQueue].operationCount == 1);
        [self.sender stop];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

            XCTAssert([self.sender backgroundQueue].operationCount == 0);
            [expectation fulfill];
        });
    });

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testReturnIndexWhenEventIsNotSent
{
    _RPTConfiguration *configuration = _sender.configuration;
    _RPTEventWriter *eventWriter = _sender.eventWriter;

    [eventWriter begin];
    [eventWriter writeWithMeasurement:[self defaultMetricMeasurement] metricIdentifier:@"default_metric"];

    // sentCount is 0 so that the 'end' method of the eventWriter is not called
    _sender.sentCount = 0;
    _sender.failures = 1;

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString isEqualToString:configuration.eventHubURL.absoluteString];
    } withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:201 headers:nil];
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"sent"];

    NSInteger returnIndex = [_sender indexAfterSendingWithStartIndex:5 endIndex:15];
    XCTAssertEqual(_sender.failures, 1);
    XCTAssertEqual(returnIndex, 15);
    [expectation fulfill];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testReturnIndexWhenSendEventSuccessfully
{
    _RPTConfiguration *configuration = _sender.configuration;
    _RPTEventWriter *eventWriter = _sender.eventWriter;

    [eventWriter begin];
    [eventWriter writeWithMeasurement:[self defaultMetricMeasurement] metricIdentifier:@"default_metric"];

    // sentCount is bigger than 0 so that the 'end' method of the eventWriter is called
    _sender.sentCount = 1;
    _sender.failures = 1;

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString isEqualToString:configuration.eventHubURL.absoluteString];
    } withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:201 headers:nil];
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"sent"];

    NSInteger returnIndex = [_sender indexAfterSendingWithStartIndex:5 endIndex:15];
    XCTAssertEqual(_sender.failures, 0);
    XCTAssertEqual(returnIndex, 15);
    [expectation fulfill];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testReturnIndexWhenSendEventUnsuccessfully
{
    _RPTConfiguration *configuration = _sender.configuration;
    _RPTEventWriter *eventWriter = _sender.eventWriter;

    [eventWriter begin];
    [eventWriter writeWithMeasurement:[self defaultMetricMeasurement] metricIdentifier:@"default_metric"];

    // sentCount is bigger than 0 so that the 'end' method of the eventWriter is called
    _sender.sentCount = 1;
    _sender.failures = 1;

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString isEqualToString:configuration.eventHubURL.absoluteString];
    } withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
        NSError* error = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:nil];
        return [OHHTTPStubsResponse responseWithError:error];
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"sent"];

    NSInteger returnIndex = [_sender indexAfterSendingWithStartIndex:5 endIndex:15];
    XCTAssertEqual(_sender.failures, 2);
    XCTAssertEqual(returnIndex, 5);
    [expectation fulfill];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

@end

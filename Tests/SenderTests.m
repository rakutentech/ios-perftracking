@import XCTest;
@import RPerformanceTracking;
#import "_RPTRingBuffer.h"
#import "_RPTMetric.h"
#import "_RPTMeasurement.h"
#import "_RPTSender.h"
#import "_RPTTracker.h"
#import "_RPTConfiguration.h"
#import "_RPTEventWriter.h"
#import <OHHTTPStubs/OHHTTPStubs.h>

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
@end

@interface SenderTests : XCTestCase
@property (nonatomic) _RPTSender           *sender;
@end

@implementation SenderTests

- (void)setUp
{
    [super setUp];

    _RPTConfiguration *configuration    = [_RPTConfiguration loadConfiguration];
    _RPTEventWriter *eventWriter        = [_RPTEventWriter.alloc initWithConfiguration:configuration];
    _RPTRingBuffer *ringBuffer          = [_RPTRingBuffer.alloc initWithSize:MAX_MEASUREMENTS];
    _sender                             = [_RPTSender.alloc initWithRingBuffer:ringBuffer configuration:configuration currentMetric:_RPTMetric.new eventWriter:eventWriter];
    eventWriter.delegate = _sender;
}

- (void)tearDown
{
    [_sender stop];
    _sender = nil;
    
    [super tearDown];
    [OHHTTPStubs removeAllStubs];
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

@import XCTest;
@import RPerformanceTracking;
#import "../RPerformanceTracking/Private/_RPTRingBuffer.h"
#import "../RPerformanceTracking/Private/_RPTMetric.h"
#import "../RPerformanceTracking/Private/_RPTMeasurement.h"
#import "../RPerformanceTracking/Private/_RPTSender.h"
#import "../RPerformanceTracking/Private/_RPTTracker.h"
#import "../RPerformanceTracking/Private/_RPTConfiguration.h"
#import "../RPerformanceTracking/Private/_RPTEventWriter.h"
#import "../RPerformanceTracking/Private/_RPTTrackingManager.h"
#import "TestUtils.h"

// Buffer size that is slightly greater than minimum send count of 10
static const NSUInteger      MIN_BUFFER_SIZE        = 12u;

// Time taken to process the minimum send count of 10 measurements
static const NSTimeInterval  MIN_COUNT_PROCESSING   = 6.0;

@interface _RPTSender ()
@property (nonatomic) _RPTConfiguration         *configuration;
@property (nonatomic) NSOperationQueue          *backgroundQueue;
@property (nonatomic) NSTimeInterval             sleepInterval;
@property (nonatomic, nullable) NSURLResponse   *response;
@property (nonatomic, nullable) NSError         *error;
@end

@interface _RPTEventWriterMock : _RPTEventWriter
@property (nonatomic) NSUInteger beginCalls;
@property (nonatomic) NSUInteger writeCalls;
@property (nonatomic) NSUInteger endCalls;
- (void)begin;
- (void)writeWithMeasurement:(_RPTMeasurement *)measurement metricIdentifier:(NSString *)metricIdentifier;
- (void)writeWithMetric:(_RPTMetric *)metric;
- (void)end;
@end

@implementation _RPTEventWriterMock

- (void)begin
{
    _beginCalls += 1;
}

- (void)writeWithMeasurement:(_RPTMeasurement *)measurement metricIdentifier:(NSString *)metricIdentifier
{
    _writeCalls += 1;
}

- (void)writeWithMetric:(_RPTMetric *)metric
{
    _writeCalls += 1;
}

- (void)end
{
    _endCalls += 1;
    _RPTSender *sender = (_RPTSender*)self.delegate;
    sender.error = nil;
    sender.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"www.google.com"] statusCode:201 HTTPVersion:nil headerFields:nil];
}

@end

@interface Receiver : NSObject
@end

@implementation Receiver
@end

@interface SenderIntegrationTests : XCTestCase
@property (nonatomic) _RPTRingBuffer       *ringBuffer;
@property (nonatomic) _RPTTracker          *tracker;
@property (nonatomic) _RPTSender           *sender;
@property (nonatomic) _RPTMetric           *currentMetric;
@property (nonatomic) _RPTConfiguration    *configuration;
@property (nonatomic) _RPTEventWriterMock  *eventWriter;
@end

@implementation SenderIntegrationTests

- (void)setUp
{
    [super setUp];

    _configuration  = [_RPTConfiguration loadConfiguration];
    _eventWriter    = [_RPTEventWriterMock.alloc initWithConfiguration:_configuration];
    _ringBuffer     = [_RPTRingBuffer.alloc initWithSize:MIN_BUFFER_SIZE];
    _currentMetric  = [_RPTMetric new];
    _tracker        = [_RPTTracker.alloc initWithRingBuffer:_ringBuffer
                                              configuration:_configuration
                                              currentMetric:_currentMetric];
    _sender         = [_RPTSender.alloc initWithRingBuffer:_ringBuffer
                                             configuration:_configuration
                                             currentMetric:_currentMetric
                                               eventWriter:_eventWriter];
    _eventWriter.delegate = _sender;
    _sender.sleepInterval = 0.5;
}

- (void)tearDown
{
    _configuration  = nil;
    _eventWriter    = nil;
    _ringBuffer     = nil;
    _currentMetric  = nil;
    _tracker        = nil;
    
    [_sender stop];
    _sender = nil;
    
    [super tearDown];
}

- (void)testThatWriterIsNotCalledWhenThereAreNoMeasurements
{
    [self startSenderThenWait:MIN_COUNT_PROCESSING];
    XCTAssert(self.eventWriter.beginCalls == 0);
    XCTAssert(self.eventWriter.writeCalls == 0, @"expected 0 write calls, got %ld", (long)self.eventWriter.writeCalls);
    XCTAssert(self.eventWriter.endCalls == 0);
}

- (void)DISABLEtestThatCompletedMeasurementIsWritten
{
    uint_fast64_t trackingIdentifier = [_tracker startCustom:@"m1"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [self.tracker end:trackingIdentifier];
    });
    
    [self startSenderThenWait:MIN_COUNT_PROCESSING];
    
    XCTAssert(self.eventWriter.beginCalls == 1);
    XCTAssert(self.eventWriter.writeCalls == 1, @"expected 1 write call, got %ld", (long)_eventWriter.writeCalls);
    XCTAssert(self.eventWriter.endCalls == 1);
}

- (void)DISABLEtestThatCompletedMetricIsWritten
{
    [_tracker startMetric:@"metric1"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [self.tracker prolongMetric]; // sets an end time
        [self.tracker endMetric];
        [self.tracker startMetric:@"metric2"]; // forces the sender to write the 'current' metric
    });
    
    [self startSenderThenWait:MIN_COUNT_PROCESSING];
    
    XCTAssert(self.eventWriter.beginCalls == 1);
    XCTAssert(self.eventWriter.writeCalls == 1, @"expected 1 write call, got %ld", (long)_eventWriter.writeCalls);
    XCTAssert(self.eventWriter.endCalls == 1);
}

- (void)DISABLEtestThatMultipleCompletedMeasurementsAreWritten
{
    uint_fast64_t ti1 = [_tracker startCustom:@"m1"];
    uint_fast64_t ti2 = [_tracker startCustom:@"m2"];
    uint_fast64_t ti3 = [_tracker startCustom:@"m3"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [self.tracker end:ti1];
        [self.tracker end:ti2];
        [self.tracker end:ti3];
    });
    
    [self startSenderThenWait:MIN_COUNT_PROCESSING];
    
    XCTAssert(self.eventWriter.beginCalls == 1);
    XCTAssert(self.eventWriter.writeCalls == 3, @"expected 3 write calls, got %ld", (long)_eventWriter.writeCalls);
    XCTAssert(self.eventWriter.endCalls == 1);
}

- (void)testThatUncompletedMeasurementIsNotWritten
{
    [_tracker startCustom:@"m1"];
    
    [self startSenderThenWait:MIN_COUNT_PROCESSING];
    
    XCTAssert(self.eventWriter.beginCalls == 0);
    XCTAssert(self.eventWriter.writeCalls == 0, @"expected 0 write calls, got %ld", (long)_eventWriter.writeCalls);
    XCTAssert(self.eventWriter.endCalls == 0);
}

- (void)DISABLEtestThatMaxBufferSizeCompletedMeasurementsAreWritten
{
    for (NSUInteger index = 0; index < _ringBuffer.size; ++index)
    {
        NSString *custom = [NSString stringWithFormat:@"custom%lu", (unsigned long)index];
        uint_fast64_t ti = [_tracker startCustom:custom];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.tracker end:ti];
        });
    }
    
    [self startSenderThenWait:MIN_COUNT_PROCESSING * 2]; // wait for two measurement counts in sender loop
    
    XCTAssert(self.eventWriter.beginCalls == 2);
    XCTAssert(self.eventWriter.writeCalls == _ringBuffer.size, @"expected %lu write calls, got %ld", (long)_ringBuffer.size, (long)_eventWriter.writeCalls);
//    XCTAssert(self.eventWriter.endCalls == 2);
}

#pragma mark - Helpers

- (void)startSenderThenWait:(NSTimeInterval)ti
{
    [_sender start];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ti * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:ti+1 handler:nil];
}

@end

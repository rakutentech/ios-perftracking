@import XCTest;
@import OCMock;
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"
#import "_RPTConfiguration.h"
#import "_RPTMainThreadWatcher.h"
#import "_RPTRingBuffer.h"
#import "_RPTMetric.h"
#import "TestUtils.h"

static const NSTimeInterval BLOCK_THRESHOLD = 0.4;

@interface _RPTTrackingManager ()
@property (nonatomic, readwrite) _RPTTracker *tracker;
@property (nonatomic)            _RPTMainThreadWatcher *watcher;
- (void)stopTracking;
- (void)updateConfiguration;
@end

@interface _RPTMainThreadWatcher ()
@property (nonatomic) NSTimeInterval       startTime;
@property (nonatomic) NSTimeInterval       endTime;
@end

@interface MainThreadWatcherTests : XCTestCase
@property (nonatomic) _RPTMainThreadWatcher *watcher;
@property (nonatomic) id trackerMock;
@end

@implementation MainThreadWatcherTests

- (void)setUp
{
    _watcher = [_RPTMainThreadWatcher.alloc initWithThreshold:BLOCK_THRESHOLD];
    [_watcher start];
    
    _RPTRingBuffer *ringBuffer = [_RPTRingBuffer.alloc initWithSize:12];
    _RPTMetric *currentMetric = [_RPTMetric new];
    _RPTConfiguration* config = mkConfigurationStub(nil);
    _RPTTrackingManager.sharedInstance.tracker = [_RPTTracker.alloc initWithRingBuffer:ringBuffer configuration:config currentMetric:currentMetric];
    
    _trackerMock = OCMPartialMock(_RPTTrackingManager.sharedInstance.tracker);
}

- (void)tearDown
{
    [_trackerMock stopMocking];
    [_watcher cancel];
    [super tearDown];
}

- (void)testThatMeasurementIsAddedWhenMainThreadIsBlockedLongerThanThreshold
{
    [self blockMainThreadForTimeInterval:1.0];
    OCMVerify([[_trackerMock ignoringNonObjectArgs] addDevice:OCMOCK_ANY start:0 end:0]);
}

- (void)testThatMeasurementAddedUsesSince1970WhenMainThreadIsBlockedLongerThanThreshold
{
    [self blockMainThreadForTimeInterval:1.0];
    NSTimeInterval anHourAgo = NSDate.date.timeIntervalSince1970 - (60.0 * 60.0);
    
    // Measurements created in this test run should have start/end dates more recent than an hour ago
    XCTAssertGreaterThan([NSDate dateWithTimeIntervalSince1970:_watcher.startTime].timeIntervalSince1970, anHourAgo);
    XCTAssertGreaterThan([NSDate dateWithTimeIntervalSince1970:_watcher.endTime].timeIntervalSince1970, anHourAgo);
}

- (void)testThatMeasurementIsNotAddedWhenMainThreadIsBlockedLessThanThreshold
{
    OCMStub([[_trackerMock ignoringNonObjectArgs] addDevice:OCMOCK_ANY start:0 end:0]).andDo(^(NSInvocation *invocation){
        XCTFail(@"Main thread blocked measurement should not be added");
    });
    [self blockMainThreadForTimeInterval:0.2];
}

- (void)blockMainThreadForTimeInterval:(NSTimeInterval)blockTime
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSThread sleepForTimeInterval:blockTime];
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

- (void)testThatWatcherIsCancelledWhenTrackingIsStopped
{
    NSDictionary* obj = @{ @"enablePercent": @(100),
                           @"sendUrl": @"https://blah.blah",
                           @"enableNonMetricMeasurement": @"true",
                           @"sendHeaders": @{@"header1": @"update1",
                                             @"header2": @"update2"} };
    
    id configMock = OCMClassMock(_RPTConfiguration.class);
    
    _RPTConfiguration *config = [_RPTConfiguration.alloc initWithData:[NSJSONSerialization dataWithJSONObject:obj options:0 error:nil]];
    
    OCMStub([configMock loadConfiguration]).andReturn(config);
    
    _RPTTrackingManager *manager = _RPTTrackingManager.new;
    XCTAssert(manager.watcher.isExecuting);
    [manager stopTracking];
    XCTAssert(manager.watcher.isCancelled);
    [configMock stopMocking];
}

@end

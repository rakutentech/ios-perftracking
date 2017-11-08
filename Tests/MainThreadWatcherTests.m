@import XCTest;
@import OCMock;
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"
#import "_RPTConfiguration.h"
#import "_RPTMainThreadWatcher.h"
#import "_RPTRingBuffer.h"
#import "_RPTMetric.h"

@interface _RPTTrackingManager ()
@property (nonatomic, readwrite) _RPTTracker *tracker;
@end

@interface MainThreadWatcherTests : XCTestCase
@property (nonatomic) _RPTMainThreadWatcher *watcher;
@property (nonatomic) id trackerMock;
@end

@implementation MainThreadWatcherTests

- (void)setUp
{
    _watcher = _RPTMainThreadWatcher.new;
    [_watcher start];
    
    _RPTRingBuffer *ringBuffer = [_RPTRingBuffer.alloc initWithSize:12];
    _RPTMetric *currentMetric = [_RPTMetric new];
    _RPTTrackingManager.sharedInstance.tracker = [_RPTTracker.alloc initWithRingBuffer:ringBuffer currentMetric:currentMetric];
    
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
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
       [NSThread sleepForTimeInterval:1.0];
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        OCMVerify([[self.trackerMock ignoringNonObjectArgs] addDevice:OCMOCK_ANY start:0 end:0]);
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

- (void)testThatMeasurementIsNotAddedWhenMainThreadIsBlockedLessThanThreshold
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait"];
    
    OCMStub([[_trackerMock ignoringNonObjectArgs] addDevice:OCMOCK_ANY start:0 end:0]).andDo(^(NSInvocation *invocation){
        XCTFail(@"Main thread blocked measurement should not be added");
    });
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSThread sleepForTimeInterval:0.2];
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end

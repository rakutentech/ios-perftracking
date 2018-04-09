@import OCMock;
@import Foundation;
#import <XCTest/XCTest.h>
#import "_RPTTracker.h"
#import "_RPTRingBuffer.h"
#import "_RPTMetric.h"
#import "_RPTMeasurement.h"

#import <Kiwi/Kiwi.h>
#import <Underscore_m/Underscore.h>

#import "TestUtils.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

SPEC_BEGIN(RPTTRackerTests)

describe(@"RPTTracker", ^{
    describe(@"constructor", ^{
        it(@"should enable tracking by default", ^{
            _RPTTracker* tracker = [_RPTTracker.alloc initWithRingBuffer:mkRingBufferStub(nil)
                                                          currentMetric:mkMetricStub(nil)
                                   ];
            
            [[theValue(tracker.shouldTrackNonMetricMeasurements) should] equal:theValue(YES)];
        });
    });
    
    describe(@"startMetric:", ^{        
        it(@"should start metric if configured to not track non-metric measurements", ^{
            _RPTTracker* tracker = [_RPTTracker.alloc initWithRingBuffer:mkRingBufferStub(nil) currentMetric:nil];
            tracker.shouldTrackNonMetricMeasurements = NO;
            
            [tracker startMetric:@"some_metric"];
            
            // measurements can be tracked only when metric started if `shouldTrackNonMetricMeasurements` == NO
            [[theValue([tracker startCustom:@"some_measurement"]) shouldNot] equal:theValue(0)];
        });
    });
    
    describe(@"startMethod:receiver:", ^{
        it(@"should not start tracking measurement if tracking non-metric measurements disabled and no active metric exists", ^{
            _RPTTracker* tracker = [_RPTTracker.alloc initWithRingBuffer:mkRingBufferStub(nil) currentMetric:nil];
            tracker.shouldTrackNonMetricMeasurements = NO;
            
            uint_fast64_t measurementId = [tracker startMethod:@"some_method" receiver:[NSObject nullMock]];
            
            [[theValue(measurementId) should] equal:theValue(0)];
        });
        
        it(@"should start tracking meaurement if tracking non-metric measurements enabled and no active metric exists", ^{
            _RPTTracker* tracker = [_RPTTracker.alloc initWithRingBuffer:mkRingBufferStub(nil) currentMetric:nil];
            tracker.shouldTrackNonMetricMeasurements = YES;
            
            uint_fast64_t measurementId = [tracker startMethod:@"some_method" receiver:[NSObject nullMock]];
            
            [[theValue(measurementId) shouldNot] equal:theValue(0)];
        });
    });
    
    describe(@"startRequest", ^{
        it(@"should not start tracking measurement if tracking non-metric measurements disabled and no active metric exists", ^{
            _RPTTracker* tracker = [_RPTTracker.alloc initWithRingBuffer:mkRingBufferStub(nil) currentMetric:nil];
            tracker.shouldTrackNonMetricMeasurements = NO;
            
            uint_fast64_t measurementId = [tracker startRequest:[NSURLRequest nullMock]];
            
            [[theValue(measurementId) should] equal:theValue(0)];
        });
        
        it(@"should start tracking meaurement if tracking non-metric measurements enabled and no active metric exists", ^{
            _RPTTracker* tracker = [_RPTTracker.alloc initWithRingBuffer:mkRingBufferStub(nil) currentMetric:nil];
            tracker.shouldTrackNonMetricMeasurements = YES;
            
            uint_fast64_t measurementId = [tracker startRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://example.com"]]];
            
            [[theValue(measurementId) shouldNot] equal:theValue(0)];
        });
    });
    
    describe(@"startCustom:", ^{
        it(@"should not start tracking measurement if tracking non-metric measurements disabled and no active metric exists", ^{
            _RPTTracker* tracker = [_RPTTracker.alloc initWithRingBuffer:mkRingBufferStub(nil) currentMetric:nil];
            tracker.shouldTrackNonMetricMeasurements = NO;
            
            uint_fast64_t measurementId = [tracker startCustom:@"custrom_metric"];
            
            [[theValue(measurementId) should] equal:theValue(0)];
        });
        
        it(@"should start tracking meaurement if tracking non-metric measurements enabled and no active metric exists", ^{
            _RPTTracker* tracker = [_RPTTracker.alloc initWithRingBuffer:mkRingBufferStub(nil) currentMetric:nil];
            tracker.shouldTrackNonMetricMeasurements = YES;
            
            uint_fast64_t measurementId = [tracker startCustom:@"custrom_metric"];
            
            [[theValue(measurementId) shouldNot] equal:theValue(0)];
        });
    });
    
    describe(@"addDevice", ^{
        it(@"should not start tracking measurement if tracking non-metric measurements disabled and no active metric exists", ^{
            _RPTTracker* tracker = [_RPTTracker.alloc initWithRingBuffer:mkRingBufferStub(nil) currentMetric:nil];
            tracker.shouldTrackNonMetricMeasurements = NO;
            
            uint_fast64_t measurementId = [tracker addDevice:@"device_id" start:0 end:1];
            
            [[theValue(measurementId) should] equal:theValue(0)];
        });
        
        it(@"should start tracking meaurement if tracking non-metric measurements enabled and no active metric exists", ^{
            _RPTTracker* tracker = [_RPTTracker.alloc initWithRingBuffer:mkRingBufferStub(nil) currentMetric:nil];
            tracker.shouldTrackNonMetricMeasurements = YES;
            
            uint_fast64_t measurementId = [tracker addDevice:@"device_id" start:0 end:1];
            
            [[theValue(measurementId) shouldNot] equal:theValue(0)];
        });
    });
});

SPEC_END

#pragma clang diagnostic pop

@interface _RPTTracker ()
@property (atomic) _RPTMetric *currentMetric;
@end

@interface TrackerTests : XCTestCase

@end

@implementation TrackerTests

- (_RPTTracker *)defaultTracker
{
    _RPTRingBuffer *ringBuffer           = [_RPTRingBuffer.alloc initWithSize:512];
    _RPTMetric *currentMetric            = _RPTMetric.new;
    currentMetric.identifier             = @"defaultMetric";
    _RPTTracker *tracker                 = [_RPTTracker.alloc initWithRingBuffer:ringBuffer currentMetric:currentMetric];
    return tracker;
}

- (void)testInitThrows
{
    XCTAssertThrowsSpecificNamed([_RPTTracker.alloc init], NSException, NSInvalidArgumentException);
}

- (void)testInitWithRingBufferAndCurrentMetric
{
    _RPTTracker *tracker = [self defaultTracker];
    XCTAssertNotNil(tracker);
    XCTAssertNotNil(tracker.ringBuffer);
    XCTAssertNotNil(tracker.currentMetric);
    XCTAssertEqualObjects(tracker.currentMetric.identifier, @"defaultMetric");
}

- (void)testInstancesAreNotEqual
{
    XCTAssertNotEqualObjects([self defaultTracker], [self defaultTracker]);
}

- (void)testCurrentMetricStateAfterInit
{
    _RPTTracker *tracker = [self defaultTracker];
    XCTAssertNotNil(tracker.currentMetric);
    XCTAssertEqualObjects(tracker.currentMetric.identifier, @"defaultMetric");
    XCTAssert(!tracker.currentMetric.startTime);
    XCTAssert(!tracker.currentMetric.endTime);
}

- (void)testStartMetric
{
    _RPTTracker *tracker = [self defaultTracker];
    [tracker startMetric:@"newMetric"];
    XCTAssertNotNil(tracker.currentMetric);
    XCTAssertEqualObjects(tracker.currentMetric.identifier, @"newMetric");
    XCTAssert(tracker.currentMetric.startTime);
}

- (void)testProlongMetricWhenDurationDoesNotExceedTheMetricMaxTime
{
    _RPTTracker *tracker = [self defaultTracker];
    [tracker startMetric:@"newMetric"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait"];

    // The metric maxtime is 10s. We dispatch the prolongMetric after 9s
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(9 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [tracker prolongMetric];
        XCTAssertGreaterThan(tracker.currentMetric.endTime, 0);
        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:15 handler:nil];
}

- (void)testProlongMetricWhenDurationExceedTheMetricMaxTime
{
    _RPTTracker *tracker = [self defaultTracker];
    [tracker startMetric:@"newMetric"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"wait"];

    // The metric maxtime is 10s. We dispatch the prolongMetric after 11s
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(11 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [tracker prolongMetric];
        XCTAssertNil(tracker.currentMetric);
        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:15 handler:nil];
}

- (void)testEndMetric
{
    _RPTTracker *tracker = [self defaultTracker];
    [tracker startMetric:@"newMetric"];
    [tracker endMetric];
    XCTAssertNil(tracker.currentMetric);
}

- (void)testStartMethod
{
    _RPTTracker *tracker = [self defaultTracker];
    NSString *methodName = @"loadView";
    UIViewController *viewController = [UIViewController.alloc init];
    uint_fast64_t trackingIdentifier = [tracker startMethod:methodName receiver:viewController];
    XCTAssert(trackingIdentifier);

    _RPTMeasurement *measurement = [tracker.ringBuffer measurementWithTrackingIdentifier:trackingIdentifier];
    XCTAssertEqual(measurement.kind, _RPTMethodMeasurementKind);
    XCTAssertEqualObjects(measurement.method, @"loadView");
    XCTAssertEqualObjects(measurement.receiver, NSStringFromClass([UIViewController class]));
    XCTAssertGreaterThan(measurement.startTime, 0);
    XCTAssertLessThan(measurement.endTime, 0);
}

- (void)testStartRequestWithGetMethod
{
    _RPTTracker *tracker = [self defaultTracker];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL.alloc initWithString:@"https://google.com"]];
    uint_fast64_t trackingIdentifier = [tracker startRequest:request];
    XCTAssert(trackingIdentifier);

    _RPTMeasurement *measurement = [tracker.ringBuffer measurementWithTrackingIdentifier:trackingIdentifier];
    XCTAssertEqual(measurement.kind, _RPTURLMeasurementKind);
    XCTAssertEqualObjects(measurement.method, @"GET");
    XCTAssertEqualObjects(measurement.receiver, @"https://google.com");
    XCTAssertGreaterThan(measurement.startTime, 0);
    XCTAssertLessThan(measurement.endTime, 0);
}

- (void)testStartRequestWithPostMethod
{
    _RPTTracker *tracker = [self defaultTracker];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL.alloc initWithString:@"https://google.co.jp"]];
    request.HTTPMethod = @"POST";
    uint_fast64_t trackingIdentifier = [tracker startRequest:request];
    XCTAssert(trackingIdentifier);

    _RPTMeasurement *measurement = [tracker.ringBuffer measurementWithTrackingIdentifier:trackingIdentifier];
    XCTAssertEqual(measurement.kind, _RPTURLMeasurementKind);
    XCTAssertEqualObjects(measurement.method, @"POST");
    XCTAssertEqualObjects(measurement.receiver, @"https://google.co.jp");
    XCTAssertGreaterThan(measurement.startTime, 0);
    XCTAssertLessThan(measurement.endTime, 0);
}

- (void)testStartRequestWithEmptyURL
{
    _RPTTracker *tracker = [self defaultTracker];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL.alloc initWithString:@""]];
    request.HTTPMethod = @"GET";
    uint_fast64_t trackingIdentifier = [tracker startRequest:request];
    XCTAssertFalse(trackingIdentifier);
}

- (void)testStartCustom
{
    _RPTTracker *tracker = [self defaultTracker];
    NSString *custom = @"custom";
    uint_fast64_t trackingIdentifier = [tracker startCustom:custom];
    XCTAssert(trackingIdentifier);

    _RPTMeasurement *measurement = [tracker.ringBuffer measurementWithTrackingIdentifier:trackingIdentifier];
    XCTAssertEqual(measurement.kind, _RPTCustomMeasurementKind);
    XCTAssertNil(measurement.method);
    XCTAssertEqualObjects(measurement.receiver, @"custom");
    XCTAssertGreaterThan(measurement.startTime, 0);
    XCTAssertLessThan(measurement.endTime, 0);
}

- (void)testEndMeasurement
{
    _RPTTracker *tracker = [self defaultTracker];
    NSString *custom = @"custom";
    uint_fast64_t trackingIdentifier = [tracker startCustom:custom];
    XCTAssert(trackingIdentifier);

    XCTestExpectation *expectNotification = [self expectationWithDescription:@"waitForNotification"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [tracker end:trackingIdentifier];
        _RPTMeasurement *measurement = [tracker.ringBuffer measurementWithTrackingIdentifier:trackingIdentifier];
        XCTAssertEqual(measurement.kind, _RPTCustomMeasurementKind);
        XCTAssertNil(measurement.method);
        XCTAssertEqualObjects(measurement.receiver, @"custom");
        XCTAssertGreaterThan(measurement.startTime, 0);
        XCTAssertGreaterThan(measurement.endTime, measurement.startTime);
        [expectNotification fulfill];
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end

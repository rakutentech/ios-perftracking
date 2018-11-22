@import OCMock;
@import Foundation;
#import <XCTest/XCTest.h>
#import "_RPTRingBuffer.h"
#import "_RPTMeasurement.h"
#import <stdatomic.h>
#import "_RPTMetric.h"
#import "_RPTTracker.h"
#import "_RPTMetric.h"
#import "TestUtils.h"

@interface _RPTRingBuffer ()
@property (nonatomic) NSArray<_RPTMeasurement *> *measurements;
@end

@interface RingBufferTests : XCTestCase
@property (nonatomic) _RPTRingBuffer    *ringBuffer;
@property (nonatomic) _RPTTracker       *tracker;
@end

@implementation RingBufferTests

- (void)setUp
{
    [super setUp];
    
    _ringBuffer                          = [_RPTRingBuffer.alloc initWithSize:512];
    _RPTMetric *currentMetric            = _RPTMetric.new;
    currentMetric.identifier             = @"metric";
    _RPTConfiguration *configuration     = mkConfigurationStub(nil);
    _tracker                             = [_RPTTracker.alloc initWithRingBuffer:_ringBuffer
                                                                   configuration:configuration
                                                                   currentMetric:currentMetric];
    // Inserting some measurements
    [_tracker startCustom:@"m1"];
    [_tracker startMetric:@"_item"];
}

- (void)testInitThrows
{
    XCTAssertThrowsSpecificNamed([_RPTRingBuffer.alloc init], NSException, NSInvalidArgumentException);
}

- (void)testInitWithSpecifiedSize
{
    _ringBuffer = [_RPTRingBuffer.alloc initWithSize:100];
    XCTAssertNotNil(_ringBuffer);
    XCTAssertEqual(_ringBuffer.measurements.count, 100);
}

- (void)testInitWithWrongSpecifiedSize
{
    _ringBuffer = [_RPTRingBuffer.alloc initWithSize:100];
    XCTAssertNotNil(_ringBuffer);
    XCTAssertNotEqual(_ringBuffer.measurements.count, 101);
}

- (void)tearDown {
    [super tearDown];
    _tracker = nil;
    _ringBuffer = nil;
}

- (void)testCustomMeasurement
{
    _RPTMeasurement *measurement = [_ringBuffer measurementAtIndex:1];
    XCTAssertNotNil(_ringBuffer);
    XCTAssertNotNil(measurement);
    XCTAssertNil(measurement.method);
    XCTAssertEqual(measurement.kind, _RPTCustomMeasurementKind);
    XCTAssertEqualObjects(measurement.receiver, @"m1");
}

- (void)testMetricMeasurement
{
    _RPTMeasurement *measurement = [_ringBuffer measurementAtIndex:2];
    XCTAssertNotNil(_ringBuffer);
    XCTAssertNotNil(measurement);
    XCTAssertNil(measurement.method);
    XCTAssertEqual(measurement.kind, _RPTMetricMeasurementKind);
    XCTAssertEqualObjects(((_RPTMetric *)measurement.receiver).identifier, @"_item");
}

- (void)testMethodMeasurement
{
    UIViewController *viewController = [UIViewController.alloc init];
    [_tracker startMethod:@"defaultMethod" receiver:viewController];
    
    _RPTMeasurement *measurement = [_ringBuffer measurementAtIndex:3];
    XCTAssertNotNil(measurement);
    XCTAssertNotNil(measurement.method);
    XCTAssertEqual(measurement.kind, _RPTMethodMeasurementKind);
    XCTAssertEqualObjects(measurement.method, @"defaultMethod");
}

- (void)testURLGetMeasurement
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL.alloc initWithString:@"https://google.com"]];
    uint_fast64_t trackingIdentifier = [_tracker startRequest:request];
    XCTAssert(trackingIdentifier);
    _RPTMeasurement *measurement = [_ringBuffer measurementWithTrackingIdentifier:trackingIdentifier];
    XCTAssertEqual(measurement.kind, _RPTURLMeasurementKind);
    XCTAssertEqualObjects(measurement.method, @"GET");
    XCTAssertEqualObjects(measurement.receiver, @"https://google.com");
}

- (void)testURLPostMeasurement
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL.alloc initWithString:@"https://google.com"]];
    request.HTTPMethod = @"POST";
    uint_fast64_t trackingIdentifier = [_tracker startRequest:request];
    XCTAssert(trackingIdentifier);
    _RPTMeasurement *measurement = [_ringBuffer measurementWithTrackingIdentifier:trackingIdentifier];
    XCTAssertEqual(measurement.kind, _RPTURLMeasurementKind);
    XCTAssertEqualObjects(measurement.method, @"POST");
    XCTAssertEqualObjects(measurement.receiver, @"https://google.com");
}


- (void)testMethodMeasurementWithTrackingIdentifier
{
    UIViewController *viewController = [UIViewController.alloc init];
    uint_fast64_t trackingIdentifier = [_tracker startMethod:@"defaultMethod" receiver:viewController];
    XCTAssert(trackingIdentifier);
    _RPTMeasurement *measurement = [_ringBuffer measurementWithTrackingIdentifier:trackingIdentifier];
    XCTAssertNotNil(_ringBuffer);
    XCTAssertNotNil(measurement);
    XCTAssertEqualObjects(measurement.method, @"defaultMethod");
    XCTAssertEqual(measurement.kind, _RPTMethodMeasurementKind);
}

- (void)testCustomMeasurementWithTrackingIdentifier
{
    uint_fast64_t trackingIdentifier = [_tracker startCustom:@"customMeasurement"];
    XCTAssert(trackingIdentifier);
    _RPTMeasurement *measurement = [_ringBuffer measurementWithTrackingIdentifier:trackingIdentifier];
    XCTAssertNotNil(_ringBuffer);
    XCTAssertNotNil(measurement);
    XCTAssertNil(measurement.method);
    XCTAssertEqual(measurement.kind, _RPTCustomMeasurementKind);
    XCTAssertEqualObjects(measurement.receiver, @"customMeasurement");
}

- (void)testMeasurementWithWrongTrackingIdentifier
{
    _RPTMeasurement *measurement = [_ringBuffer measurementWithTrackingIdentifier:10024];
    XCTAssertNil(measurement);
    XCTAssertNotNil(_ringBuffer);
}

- (void)testMeasurementWithTrackingIdentifierZero
{
    _RPTMeasurement *measurement = [_ringBuffer measurementWithTrackingIdentifier:0];
    XCTAssertNil(measurement);
}

- (void)testNoMeasurementAtIndex
{
    _RPTMeasurement *measurement = [_ringBuffer measurementAtIndex:515];
    XCTAssertNotNil(_ringBuffer);
    XCTAssertNil(measurement);
}

- (void)testNextMeasurement
{
    _RPTMeasurement *measurement = [_ringBuffer nextMeasurement];
    XCTAssertNotNil(_ringBuffer);
    XCTAssertNotNil(measurement);
}

- (void)testNextMeasurementIsNilWhenBufferFull
{
    _RPTRingBuffer *ringBuffer          = [_RPTRingBuffer.alloc initWithSize:12];
    _RPTMetric *currentMetric           = _RPTMetric.new;
    currentMetric.identifier            = @"metric";
    _RPTConfiguration *configuration     = mkConfigurationStub(nil);
    _RPTTracker *tracker                = [_RPTTracker.alloc initWithRingBuffer:ringBuffer
                                                                  configuration:configuration
                                                                  currentMetric:currentMetric];
    
    for( int i = 0; i < 12; i++)
    {
        [tracker startCustom:@"m1"];
    }
    _RPTMeasurement *measurement = [ringBuffer nextMeasurement];
    XCTAssertNil(measurement);
    XCTAssertNotNil(ringBuffer);
}
- (void)testNextMeasurementIsValidWhenTrackingIdIsGreaterThanBufferSize
{
    _RPTRingBuffer *ringBuffer          = [_RPTRingBuffer.alloc initWithSize:12];
    _RPTMetric *currentMetric           = _RPTMetric.new;
    currentMetric.identifier            = @"metric";
    _RPTConfiguration *configuration     = mkConfigurationStub(nil);
    _RPTTracker *tracker                = [_RPTTracker.alloc initWithRingBuffer:ringBuffer
                                                                  configuration:configuration
                                                                  currentMetric:currentMetric];
    
    for( int i = 0; i < 12; i++)
    {
        [tracker startCustom:@"m1"];
    }
    
    for(int i = 0; i < ringBuffer.measurements.count; i++)
    {
        [[ringBuffer.measurements objectAtIndex:i] clear];
    }
    _RPTMeasurement *nextMeasurement = ringBuffer.nextMeasurement;
    XCTAssertNotNil(ringBuffer);
    XCTAssertNotNil(nextMeasurement);
    XCTAssert(nextMeasurement.trackingIdentifier);
}

@end

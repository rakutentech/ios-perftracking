@import OCMock;
@import Foundation;
#import <XCTest/XCTest.h>
#import "_RPTTrackingManager.h"
#import "_RPTRingBuffer.h"
#import "_RPTTracker.h"
#import "_RPTMetric.h"
#import "_RPTMeasurement.h"
#import "_RPTConfiguration.h"
#import "_RPTEventWriter.h"
#import "_RPTSender.h"
#import "TestUtils.h"

static const NSUInteger     TRACKING_DATA_LIMIT  = 100u;

@interface _RPTTrackingManager ()

@property (nonatomic) _RPTTracker           *tracker;
@property (nonatomic) _RPTRingBuffer        *ringBuffer;
@property (nonatomic) _RPTEventWriter       *eventWriter;
@property (nonatomic) BOOL                 forceTrackingEnabled;
@property (nonatomic) NSMutableDictionary<id, NSNumber *> *trackingData;
- (void)endMetric;
- (BOOL)disableTracking;

@end

@interface _RPTTracker ()
@property (atomic) _RPTMetric *currentMetric;
- (uint_fast64_t)startCustom:(NSString *)custom;
- (void)prolongMetric;
@end

@interface _RPTRingBuffer ()
@property (nonatomic) NSArray<_RPTMeasurement *> *measurements;
@end

@interface _RPTConfiguration ()
+ (instancetype)loadConfiguration;
@end

@interface TrackingManagerTests : XCTestCase
@end

@implementation TrackingManagerTests

- (void)setUp
{
    [super setUp];
    NSDictionary *dict = @{
                           @"enablePercent": @(100),
                           @"sendUrl": @"https://performance-endpoint.com/measurements/messages?timeout=60&api-version=2014-01",
                           @"enableNonMetricMeasurement": @"true",
                           @"sendHeaders":@{@"Authorization": @"SharedAccessSignature sr=foo",
                                            @"Content-Type": @"application/atom+xml;type=entry;charset=utf-8",
                                            @"BrokerProperties": @"PartitionKey: ABC"
                                            }
                           };
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:0];
    [_RPTConfiguration persistWithData:data];
}

- (void)tearDown
{
    [NSUserDefaults.standardUserDefaults setObject:nil forKey:@"com.rakuten.performancetracking"];
    [super tearDown];
}

- (void)testSharedInstancesAreEqual
{
    XCTAssertEqualObjects([_RPTTrackingManager sharedInstance], [_RPTTrackingManager sharedInstance]);
}

- (_RPTTrackingManager *)defaultTrackingManager
{
    _RPTRingBuffer *ringBuffer             = [_RPTRingBuffer.alloc initWithSize:12];
    _RPTTrackingManager *trackingManager    = [_RPTTrackingManager sharedInstance];
    trackingManager.ringBuffer             = ringBuffer;
    _RPTMetric *currentMetric              = _RPTMetric.new;
    currentMetric.identifier               = @"metric";
    _RPTConfiguration *config              = mkConfigurationStub(nil);
    trackingManager.tracker                = [[_RPTTracker alloc] initWithRingBuffer:ringBuffer
                                                                       configuration:config
                                                                       currentMetric:currentMetric];
    return trackingManager;
}

- (void)testInitWithNilRingBuffer
{
    _RPTTrackingManager *trackingManager = [_RPTTrackingManager alloc];
    id mockTrackingManager = [OCMockObject partialMockForObject:trackingManager];
    [[[mockTrackingManager stub] andReturnValue:OCMOCK_VALUE(NO)] disableTracking];
    
    id mockRingBuffer = OCMClassMock([_RPTRingBuffer class]);
    OCMStub([mockRingBuffer alloc]).andReturn(mockRingBuffer);
    OCMStub([(_RPTRingBuffer *)mockRingBuffer initWithSize:12]).andReturn(nil);
    
    trackingManager = [trackingManager init];
    XCTAssertNil(trackingManager);
    [mockRingBuffer stopMocking];
    [mockTrackingManager stopMocking];
}

- (void)testInitWithNilTracker
{
    _RPTTrackingManager *trackingManager = [_RPTTrackingManager alloc];
    id mockTrackingManager = [OCMockObject partialMockForObject:trackingManager];
    [[[mockTrackingManager stub] andReturnValue:OCMOCK_VALUE(NO)] disableTracking];

    id mockTracker = OCMClassMock([_RPTTracker class]);
    OCMStub([mockTracker alloc]).andReturn(mockTracker);
    OCMStub([(_RPTTracker *)mockTracker initWithRingBuffer:[OCMArg any] configuration:[OCMArg any] currentMetric:[OCMArg any]]).andReturn(nil);

    trackingManager = [trackingManager init];
    XCTAssertNil(trackingManager);
    [mockTracker stopMocking];
    [mockTrackingManager stopMocking];
}

- (void)testInitWithNilEventWriter
{
    _RPTTrackingManager *trackingManager = [_RPTTrackingManager alloc];
    id mockTrackingManager = [OCMockObject partialMockForObject:trackingManager];
    [[[mockTrackingManager stub] andReturnValue:OCMOCK_VALUE(NO)] disableTracking];
    
    id mockEventWriter = OCMClassMock([_RPTEventWriter class]);
    OCMStub([mockEventWriter alloc]).andReturn(mockEventWriter);
    OCMStub([(_RPTEventWriter *)mockEventWriter initWithConfiguration:[OCMArg any]]).andReturn(nil);
 
    trackingManager = [trackingManager init];
    XCTAssertNil(trackingManager);
    [mockEventWriter stopMocking];
    [mockTrackingManager stopMocking];
}

- (void)testInitWithNilSender
{
    _RPTTrackingManager *trackingManager = [_RPTTrackingManager alloc];
    id mockTrackingManager = [OCMockObject partialMockForObject:trackingManager];
    [[[mockTrackingManager stub] andReturnValue:OCMOCK_VALUE(NO)] disableTracking];
    
    id mockSender = OCMClassMock([_RPTSender class]);
    OCMStub([mockSender alloc]).andReturn(mockSender);
    OCMStub([(_RPTSender *)mockSender initWithRingBuffer:[OCMArg any] configuration:[OCMArg any] currentMetric:[OCMArg any] eventWriter:[OCMArg any]]).andReturn(nil);
    
    trackingManager = [trackingManager init];
    XCTAssertNil(trackingManager);
    [mockSender stopMocking];
    [mockTrackingManager stopMocking];
}

- (void)testInitWithNOForceTracking
{
    id mockConfiguration = OCMClassMock([_RPTConfiguration class]);
    OCMStub([mockConfiguration loadConfiguration]).andReturn(nil);
    
    id mockSender = OCMClassMock([_RPTSender class]);
    OCMStub([mockSender alloc]).andReturn(mockSender);
    OCMStub([(_RPTSender *)mockSender initWithRingBuffer:[OCMArg any] configuration:[OCMArg any] currentMetric:[OCMArg any] eventWriter:[OCMArg any]]).andReturn(mockSender);
    
    id mockBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockBundle bundleIdentifier]).andReturn(@"jp.co.rakuten.HostApp");
    OCMStub([mockBundle objectForInfoDictionaryKey:@"RPTForceTrackingEnabled"]).andReturn(@NO);
    
    _RPTTrackingManager *trackingManager = [_RPTTrackingManager.alloc init];
    
    (void)trackingManager;
    
    OCMStub([(_RPTSender *)mockSender start]).andDo(^(__unused NSInvocation *invoc){
        
        XCTFail(@"Sender#start should not be called if force tracking is NOT enabled");
    });
    XCTAssertFalse(trackingManager.forceTrackingEnabled);
    [mockConfiguration stopMocking];
    [mockSender stopMocking];
    [mockBundle stopMocking];
}

- (void)testDefaultTrackingManager
{
    _RPTTrackingManager *trackingManager = [self defaultTrackingManager];
    XCTAssertNotNil(trackingManager.tracker);
    XCTAssertNotNil(trackingManager.tracker.ringBuffer);
    XCTAssertNotNil(trackingManager.tracker.currentMetric);
    XCTAssertEqualObjects(trackingManager.tracker.currentMetric.identifier, @"metric");
}

- (void)testItemMetric
{
    _RPTTrackingManager *trackingManager = [self defaultTrackingManager];
    [trackingManager startMetric:@"_item"];
    XCTAssertNotNil(trackingManager.tracker);
    XCTAssertNotNil(trackingManager.tracker.ringBuffer);
    XCTAssertNotNil(trackingManager.tracker.currentMetric);
    XCTAssertEqualObjects(trackingManager.tracker.currentMetric.identifier, @"_item");
}


- (void)testDefaultLaunchMetric
{
    _RPTTrackingManager *trackingManager = [self defaultTrackingManager];
    [_RPTTrackingManager load];
    XCTAssertNotNil(trackingManager.tracker);
    XCTAssertNotNil(trackingManager.tracker.ringBuffer);
    XCTAssertNotNil(trackingManager.tracker.currentMetric);
    XCTAssertEqualObjects(trackingManager.tracker.currentMetric.identifier, @"_launch");
}

- (void)testEndItemMetric
{
    _RPTTrackingManager *trackingManager = [self defaultTrackingManager];
    [trackingManager startMetric:@"_item"];
    XCTAssertEqualObjects(trackingManager.tracker.currentMetric.identifier, @"_item");
    [trackingManager endMetric];
    XCTAssertNotEqualObjects(trackingManager.tracker.currentMetric.identifier, @"_item");
}

- (void)testMetricWillNotHaveEndTime
{
    _RPTTrackingManager *trackingManager = [self defaultTrackingManager];
    [trackingManager startMetric:@"_item"];
    XCTAssertNotNil(trackingManager.tracker);
    XCTAssertNotNil(trackingManager.tracker.ringBuffer);
    XCTAssertNotNil(trackingManager.tracker.currentMetric);
    XCTAssertEqualObjects(trackingManager.tracker.currentMetric.identifier, @"_item");
    XCTAssertLessThanOrEqual(trackingManager.tracker.currentMetric.endTime, 0);
}

- (void)testMetricEndTimeUpdatedOnProlongMetric
{
    _RPTTrackingManager *trackingManager = [self defaultTrackingManager];
    [trackingManager startMetric:@"_item"];
    XCTAssertNotNil(trackingManager.tracker);
    XCTAssertNotNil(trackingManager.tracker.ringBuffer);
    XCTAssertNotNil(trackingManager.tracker.currentMetric);
    XCTAssertEqualObjects(trackingManager.tracker.currentMetric.identifier, @"_item");
    [trackingManager.tracker prolongMetric];
    XCTAssertGreaterThan(trackingManager.tracker.currentMetric.endTime, 0);
}

- (void)testMeasurement
{
    _RPTTrackingManager *trackingManager = [self defaultTrackingManager];
    trackingManager.trackingData = [NSMutableDictionary.alloc initWithCapacity:100u];
    [trackingManager startMeasurement:@"TestMeasurement1" object:@"M1"];
    _RPTMeasurement *measurement1 = [trackingManager.ringBuffer.measurements objectAtIndex:1];
    XCTAssertNotNil(measurement1);
    XCTAssertNotNil(trackingManager);
    XCTAssertEqualObjects(@"TestMeasurement1",measurement1.receiver);
    XCTAssertGreaterThan(measurement1.startTime, 0);
    XCTAssertLessThan(measurement1.endTime, 0);
}

- (void)testEndMeasurement
{
    _RPTTrackingManager *trackingManager = [self defaultTrackingManager];
    trackingManager.trackingData = [NSMutableDictionary.alloc initWithCapacity:100u];
    [trackingManager startMeasurement:@"TestMeasurement" object:@"M1"];
    _RPTMeasurement *measurement = [trackingManager.ringBuffer.measurements objectAtIndex:1];
    XCTAssertNotNil(measurement);
    XCTAssertEqualObjects(@"TestMeasurement",measurement.receiver);
    XCTAssertGreaterThan(measurement.startTime, 0);
    XCTAssertLessThan(measurement.endTime, 0);

    XCTestExpectation *expectNotification = [self expectationWithDescription:@"waitForNotification"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [trackingManager endMeasurement:@"TestMeasurement" object:@"M1"];
        _RPTMeasurement *measurement = [trackingManager.ringBuffer.measurements objectAtIndex:1];
        XCTAssertEqual(measurement.kind, _RPTCustomMeasurementKind);
        XCTAssertNil(measurement.method);
        XCTAssertEqualObjects(measurement.receiver, @"TestMeasurement");
        XCTAssertGreaterThan(measurement.startTime, 0);
        XCTAssertGreaterThan(measurement.endTime, measurement.startTime);
        [expectNotification fulfill];
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testStartAggregatedMeasurements
{
    _RPTTrackingManager *trackingManager = [self defaultTrackingManager];
    trackingManager.trackingData = [NSMutableDictionary.alloc initWithCapacity:100u];
    [trackingManager startMeasurement:@"TestMeasurement1" object:@"M1"];
    [trackingManager startMeasurement:@"TestMeasurement2" object:@"M1"];
    _RPTMeasurement *measurement1 = [trackingManager.ringBuffer.measurements objectAtIndex:1];
    XCTAssertNotNil(measurement1);
    XCTAssertNotNil(trackingManager);
    XCTAssertEqualObjects(@"TestMeasurement1",measurement1.receiver);
    XCTAssertGreaterThan(measurement1.startTime, 0);
    XCTAssertLessThan(measurement1.endTime, 0);

    _RPTMeasurement *measurement2 = [trackingManager.ringBuffer.measurements objectAtIndex:2];
    XCTAssertNotNil(measurement2);
    XCTAssertNotNil(trackingManager);
    XCTAssertEqualObjects(@"TestMeasurement2",measurement2.receiver);
    XCTAssertGreaterThan(measurement2.startTime, 0);
    XCTAssertLessThan(measurement2.endTime, 0);
}

- (void)testEndAggregatedMeasurements
{
    _RPTTrackingManager *trackingManager = [self defaultTrackingManager];
    trackingManager.trackingData = [NSMutableDictionary.alloc initWithCapacity:100u];
    [trackingManager startMeasurement:@"TestMeasurement1" object:@"M1"];
    [trackingManager startMeasurement:@"TestMeasurement2" object:@"M1"];
    _RPTMeasurement *measurement1 = [trackingManager.ringBuffer.measurements objectAtIndex:1];
    XCTAssertNotNil(measurement1);
    XCTAssertEqualObjects(@"TestMeasurement1",measurement1.receiver);
    XCTAssertGreaterThan(measurement1.startTime, 0);
    XCTAssertLessThan(measurement1.endTime, 0);
    
    _RPTMeasurement *measurement2 = [trackingManager.ringBuffer.measurements objectAtIndex:2];
    XCTAssertNotNil(measurement2);
    XCTAssertEqualObjects(@"TestMeasurement2",measurement2.receiver);
    XCTAssertGreaterThan(measurement2.startTime, 0);
    XCTAssertLessThan(measurement2.endTime, 0);
    
    XCTestExpectation *expectNotification = [self expectationWithDescription:@"waitForNotification"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [trackingManager endMeasurement:@"TestMeasurement1" object:@"M1"];
        _RPTMeasurement *measurement = [trackingManager.ringBuffer.measurements objectAtIndex:1];
        XCTAssertEqual(measurement.kind, _RPTCustomMeasurementKind);
        XCTAssertNil(measurement.method);
        XCTAssertEqualObjects(measurement.receiver, @"TestMeasurement1");
        XCTAssertGreaterThan(measurement.startTime, 0);
        XCTAssertGreaterThan(measurement.endTime, measurement.startTime);
        
        [trackingManager endMeasurement:@"TestMeasurement2" object:@"M1"];
        _RPTMeasurement *measurement2 = [trackingManager.ringBuffer.measurements objectAtIndex:2];
        XCTAssertEqual(measurement2.kind, _RPTCustomMeasurementKind);
        XCTAssertNil(measurement2.method);
        XCTAssertEqualObjects(measurement2.receiver, @"TestMeasurement2");
        XCTAssertGreaterThan(measurement2.startTime, 0);
        XCTAssertGreaterThan(measurement2.endTime, measurement2.startTime);
        
        [expectNotification fulfill];
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testEndUnstartedMeasurement
{
    _RPTTrackingManager *trackingManager = [self defaultTrackingManager];
    [trackingManager endMeasurement:@"Test" object:NSObject.new];
    for (_RPTMeasurement *measurement in trackingManager.ringBuffer.measurements)
    {
        XCTAssertNotNil(measurement);
        XCTAssertNotEqual(measurement.receiver, @"Test");
    }
}

- (void)testThatMeasurementIsOnlyStartedOnce
{
    _RPTTrackingManager *trackingManager = [self defaultTrackingManager];
    trackingManager.trackingData = [NSMutableDictionary.alloc initWithCapacity:100u];
    id trackerMock = OCMPartialMock(trackingManager.tracker);
    
    __block int callCount = 0;
    OCMStub([trackerMock startCustom:@"TestMeasurement"]).andDo(^(NSInvocation *invocation) {
        ++callCount;
    }).andReturn(1);
    
    [trackingManager startMeasurement:@"TestMeasurement" object:@"M1"];
    [trackingManager startMeasurement:@"TestMeasurement" object:@"M1"];
    
    int expectedNumberOfCalls = 1;
    XCTAssertEqual(callCount, expectedNumberOfCalls);
    [trackerMock stopMocking];
}

- (void)testThatMeasurementIsOnlyEndedOnce
{
    _RPTTrackingManager *trackingManager = [self defaultTrackingManager];
    trackingManager.trackingData = [NSMutableDictionary.alloc initWithCapacity:100u];
    id trackerMock = OCMPartialMock(trackingManager.tracker);
    __block int callCount = 0;
    
    [trackingManager startMeasurement:@"TestMeasurement" object:@"M1"];
    OCMStub([[trackerMock ignoringNonObjectArgs] end:2]).andDo(^(NSInvocation *invocation) {
        ++callCount;
    });
    
    [trackingManager endMeasurement:@"TestMeasurement" object:@"M1"];
    [trackingManager endMeasurement:@"TestMeasurement" object:@"M1"];

    int expectedNumberOfCalls = 1;
    XCTAssertEqual(callCount, expectedNumberOfCalls);
    [trackerMock stopMocking];
}

- (void)testThatManyMeasurementsAreHandled
{
    _RPTTrackingManager *trackingManager = [self defaultTrackingManager];
    trackingManager.trackingData = [NSMutableDictionary.alloc initWithCapacity:TRACKING_DATA_LIMIT];
    for (int i = 0; i < TRACKING_DATA_LIMIT; i++)
    {
        [trackingManager startMeasurement:[NSString stringWithFormat:@"%d",i] object:@"M1"];
    }
    for (int i = 0; i < TRACKING_DATA_LIMIT; i++)
    {
        [trackingManager endMeasurement:[NSString stringWithFormat:@"%d",i] object:@"M1"];
    }
    for (int i = 0; i < trackingManager.ringBuffer.measurements.count; i++)
    {
        _RPTMeasurement *measurement = trackingManager.ringBuffer.measurements[i];
        XCTAssertNotNil(measurement);
        XCTAssertGreaterThan(measurement.startTime, 0);
        XCTAssertGreaterThan(measurement.endTime, measurement.startTime);
    }    
}

@end

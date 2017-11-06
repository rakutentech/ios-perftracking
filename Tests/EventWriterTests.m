@import XCTest;
#import <OHHTTPStubs/OHHTTPStubs.h>
#import <OHHTTPStubs/OHHTTPStubsResponse+JSON.h>
#import <OCMock/OCMock.h>
#import "../RPerformanceTracking/Private/_RPTEventWriter.h"
#import "../RPerformanceTracking/Private/_RPTConfiguration.h"
#import "../RPerformanceTracking/Private/_RPTMeasurement.h"
#import "../RPerformanceTracking/Private/_RPTMetric.h"
#import "_RPTLocation.h"
#import "../RPerformanceTracking/Private/UIDevice+RPerformanceTracking.h"

@interface _RPTEventWriter ()
@property (nonatomic) NSMutableString           *writer;
@property (nonatomic) NSInteger                  measurementCount;
@end

@interface EventWriterTests : XCTestCase
{
    id mockDevice;
}
@property (nonatomic, copy) NSString            *fixedPrefix;
@end

@implementation EventWriterTests

- (void)setUp {
    [super setUp];
    NSDictionary *dict = @{
        @"enablePercent": @(20.00),
        @"sendUrl": @"https://performance-endpoint.com/measurements/messages?timeout=60&api-version=2014-01",
        @"sendHeaders":@{@"Authorization": @"SharedAccessSignature sr=foo",
                         @"Content-Type": @"application/atom+xml;type=entry;charset=utf-8",
                         @"BrokerProperties": @"PartitionKey: ABC"
                         }
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:0];
    [_RPTConfiguration persistWithData:data];

    mockDevice = OCMPartialMock(UIDevice.currentDevice);
    OCMStub([mockDevice freeDeviceMemory]).andReturn(3000);
    OCMStub([mockDevice totalDeviceMemory]).andReturn(10000);
    OCMStub([mockDevice usedAppMemory]).andReturn(100);
    OCMStub([mockDevice batteryLevel]).andReturn(0.86f);

    _fixedPrefix = [NSString stringWithFormat:@"{\"app\":\"%@\",\"version\":\"1.0\",\"device\":\"x86_64\",\"country\":\"US\",\"network\":\"wifi\",\"os\":\"ios\",\"os_version\":\"%@\",\"app_mem_used\":100,\"device_mem_free\":3000,\"device_mem_total\":10000,\"battery_level\":0.86,\"measurements\":[", NSBundle.mainBundle.bundleIdentifier, UIDevice.currentDevice.systemVersion];
    
    // Ensure locale is used
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString containsString:@"location"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:NSData.data statusCode:500 headers:nil];
    }];
}

- (void)tearDown {
    [super tearDown];
    [OHHTTPStubs removeAllStubs];
    [mockDevice stopMocking];
}

- (_RPTConfiguration *)defaultConfiguration
{
    return [_RPTConfiguration loadConfiguration];
}

- (_RPTEventWriter *)defaultEventWriter
{
    return [_RPTEventWriter.alloc initWithConfiguration:[self defaultConfiguration]];
}

- (_RPTMeasurement *)defaultMetricMeasurement
{
    _RPTMeasurement *measurement = [_RPTMeasurement.alloc init];
    measurement.kind               = _RPTMetricMeasurementKind;
    measurement.trackingIdentifier = 10;

    _RPTMetric *receiver = [_RPTMetric new];
    receiver.identifier  = @"other_metric";
    receiver.urlCount    = 15;
    measurement.receiver = receiver;

    measurement.startTime = 1;
    measurement.endTime   = 4.5;
    return measurement;
}

- (_RPTMeasurement *)defaultMethodMeasurement
{
    _RPTMeasurement *measurement = [_RPTMeasurement.alloc init];
    measurement.kind               = _RPTMethodMeasurementKind;
    measurement.trackingIdentifier = 11;
    measurement.method             = @"measurement_method";
    measurement.startTime          = 1;
    measurement.endTime            = 4.5;
    return measurement;
}

- (_RPTMeasurement *)defaultURLMeasurement
{
    _RPTMeasurement *measurement = [_RPTMeasurement.alloc init];
    measurement.kind               = _RPTURLMeasurementKind;
    measurement.trackingIdentifier = 12;
    measurement.receiver           = @"https://performance-endpoint.com";
    measurement.method             = @"POST";
    measurement.startTime          = 0.001;
    measurement.endTime            = 0.0014;
    return measurement;
}

- (_RPTMeasurement *)defaultCustomMeasurement
{
    _RPTMeasurement *measurement = [_RPTMeasurement.alloc init];
    measurement.kind               = _RPTCustomMeasurementKind;
    measurement.trackingIdentifier = 13;
    measurement.receiver           = @"custom_measurement";
    measurement.startTime          = 1;
    measurement.endTime            = 4.5;
    return measurement;
}

- (_RPTMetric *)defaultMetric
{
    _RPTMetric *metric = [_RPTMetric.alloc init];
    metric.identifier = @"default_metric";
    metric.urlCount   = 5;
    metric.startTime  = 1.2;
    metric.endTime    = 4.2;
    return metric;
}

- (_RPTMetric *)metricWithStartTimeStampCloseToZero
{
    _RPTMetric *metric = [_RPTMetric.alloc init];
    metric.identifier = @"startTimeStampCloseToZero_metric";
    metric.urlCount   = 5;
    metric.startTime  = 0.0001;
    metric.endTime    = 4.0002;
    return metric;
}

- (void)testInitThrows
{
    XCTAssertThrowsSpecificNamed([_RPTEventWriter.alloc init], NSException, NSInvalidArgumentException);
}

- (void)testInitWithDefaultConfiguration
{
    _RPTEventWriter *eventWriter = [self defaultEventWriter];
    XCTAssertNotNil(eventWriter);
}

- (void)testBegin
{
    _RPTEventWriter *eventWriter = [self defaultEventWriter];
    XCTAssertNil(eventWriter.writer);
    [eventWriter begin];
    XCTAssertNotNil(eventWriter.writer);
	XCTAssertEqualObjects(eventWriter.writer.copy, _fixedPrefix);
    XCTAssert(!eventWriter.measurementCount);
}

- (void)testWriteWithoutBegining
{
    _RPTEventWriter *eventWriter = [self defaultEventWriter];
    [eventWriter writeWithMeasurement:[self defaultMetricMeasurement] metricIdentifier:@"default_metric"];
    XCTAssertNil(eventWriter.writer);
}


- (void)testWriteMetric
{
    _RPTEventWriter *eventWriter = [self defaultEventWriter];
    [eventWriter begin];
    [eventWriter writeWithMetric:[self defaultMetric]];
    XCTAssertNotNil(eventWriter.writer);
	NSString *responseString = [NSString stringWithFormat:@"%@{\"metric\":\"default_metric\",\"urls\":5,\"time\":3000,\"start\":1200}", _fixedPrefix];
    XCTAssertEqualObjects(eventWriter.writer.copy, responseString);
    XCTAssertEqual(eventWriter.measurementCount, 1);
}

- (void)testWriteMetricWithoutRegion
{
    id locMock = OCMClassMock(_RPTLocation.class);
    OCMStub([locMock loadLocation]).andReturn(nil);
    
    _RPTEventWriter *eventWriter = [self defaultEventWriter];
    [eventWriter begin];
    [eventWriter writeWithMetric:[self defaultMetric]];
    XCTAssertNotNil(eventWriter.writer);
    
    NSString *prefix = [NSString stringWithFormat:@"{\"app\":\"%@\",\"version\":\"1.0\",\"device\":\"x86_64\",\"country\":\"%@\",\"network\":\"wifi\",\"os\":\"ios\",\"os_version\":\"%@\",\"app_mem_used\":100,\"device_mem_free\":3000,\"device_mem_total\":10000,\"battery_level\":0.86,\"measurements\":[", NSBundle.mainBundle.bundleIdentifier, [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode], UIDevice.currentDevice.systemVersion];
    
    NSString *responseString = [NSString stringWithFormat:@"%@{\"metric\":\"default_metric\",\"urls\":5,\"time\":3000,\"start\":1200}", prefix];
    XCTAssertEqualObjects(eventWriter.writer.copy, responseString);
    XCTAssertEqual(eventWriter.measurementCount, 1);
    
    [locMock stopMocking];
}

- (void)testWriteMetricWithStartTimeStampRoundToZero
{
    _RPTEventWriter *eventWriter = [self defaultEventWriter];
    [eventWriter begin];
    [eventWriter writeWithMetric:[self metricWithStartTimeStampCloseToZero]];
    XCTAssertNotNil(eventWriter.writer);
    NSString *responseString = [NSString stringWithFormat:@"%@{\"metric\":\"startTimeStampCloseToZero_metric\",\"urls\":5,\"time\":4000,\"start\":0}", _fixedPrefix];
    XCTAssertEqualObjects(eventWriter.writer.copy, responseString);
    XCTAssertEqual(eventWriter.measurementCount, 1);
}

- (void)testWriteWithMethodMeasurement
{
    _RPTEventWriter *eventWriter = [self defaultEventWriter];
    [eventWriter begin];
    [eventWriter writeWithMeasurement:[self defaultMethodMeasurement] metricIdentifier:@"default_metric"];
    XCTAssertNotNil(eventWriter.writer);
	NSString *responseString = [NSString stringWithFormat:@"%@{\"method\":\"measurement_method\",\"metric\":\"default_metric\",\"time\":3500,\"start\":1000}", _fixedPrefix];
	XCTAssertEqualObjects(eventWriter.writer.copy, responseString);
    XCTAssertEqual(eventWriter.measurementCount, 1);
}

- (void)testWriteWithURLMeasurement
{
    _RPTEventWriter *eventWriter = [self defaultEventWriter];
    [eventWriter begin];
    [eventWriter writeWithMeasurement:[self defaultURLMeasurement] metricIdentifier:@"default_metric"];
    XCTAssertNotNil(eventWriter.writer);
	NSString *responseString = [NSString stringWithFormat:@"%@{\"url\":\"https://performance-endpoint.com\",\"verb\":\"POST\",\"metric\":\"default_metric\",\"time\":1,\"start\":1}", _fixedPrefix]; // duration is round to 1ms
    XCTAssertEqualObjects(eventWriter.writer.copy, responseString);
	
    XCTAssertEqual(eventWriter.measurementCount, 1);
}

- (void)testWriteWithCustomMeasurement
{
    _RPTEventWriter *eventWriter = [self defaultEventWriter];
    [eventWriter begin];
    [eventWriter writeWithMeasurement:[self defaultCustomMeasurement] metricIdentifier:@"default_metric"];
    XCTAssertNotNil(eventWriter.writer);
	NSString *responseString = [NSString stringWithFormat:@"%@{\"custom\":\"custom_measurement\",\"metric\":\"default_metric\",\"time\":3500,\"start\":1000}", _fixedPrefix];
    XCTAssertEqualObjects(eventWriter.writer.copy, responseString);
    XCTAssertEqual(eventWriter.measurementCount, 1);
}

- (void)testSendEventSuccessfully
{
    _RPTConfiguration *configuration = [self defaultConfiguration];
    _RPTEventWriter *eventWriter = [self defaultEventWriter];
    [eventWriter begin];
    [eventWriter writeWithMeasurement:[self defaultMetricMeasurement] metricIdentifier:@"default_metric"];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString isEqualToString:configuration.eventHubURL.absoluteString];
    } withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:201 headers:nil];
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"sent"];
    [eventWriter end];
    XCTAssertNil(eventWriter.writer);
    XCTAssert(!eventWriter.measurementCount);
    [expectation fulfill];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testSendEventUnsuccessfully
{
    _RPTConfiguration *configuration = [self defaultConfiguration];
    _RPTEventWriter *eventWriter = [self defaultEventWriter];
    [eventWriter begin];
    [eventWriter writeWithMeasurement:[self defaultMetricMeasurement] metricIdentifier:@"default_metric"];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.absoluteString isEqualToString:configuration.eventHubURL.absoluteString];
    } withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:500 headers:nil];
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"sent"];
    [eventWriter end];
    XCTAssertNil(eventWriter.writer);
    XCTAssert(!eventWriter.measurementCount);

    [expectation fulfill];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

@end

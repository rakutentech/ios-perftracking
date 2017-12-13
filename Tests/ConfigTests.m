@import OCMock;
#import <XCTest/XCTest.h>
#import <OHHTTPStubs/OHHTTPStubs.h>
#import <OHHTTPStubs/OHHTTPStubsResponse+HTTPMessage.h>
#import <OHHTTPStubs/OHHTTPStubsResponse+JSON.h>
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"
#import "_RPTSender.h"
#import "_RPTConfiguration.h"

@interface _RPTTrackingManager()
@property (nonatomic) NSTimeInterval         refreshConfigInterval;
@property (nonatomic, readwrite) _RPTSender *sender;
@property (nonatomic) _RPTMetric            *currentMetric;
@property (nonatomic) _RPTEventWriter       *eventWriter;

- (void)updateConfiguration;
- (BOOL)disableTracking;

@end

@interface MockSender: _RPTSender
@property (nonatomic) BOOL stopped;
@end

@implementation MockSender

- (void)start
{
    [super start];
    _stopped = NO;
}

- (void)stop
{
    // Don't call super because it's a blocking call and messes up async tests
    _stopped = YES;
}

@end

@interface ConfigTests : XCTestCase
@end

@implementation ConfigTests

static _RPTTrackingManager *_trackingManager = nil;

- (void)tearDown
{
    [OHHTTPStubs removeAllStubs];
    [_trackingManager.sender stop];
    _trackingManager = nil;
    [super tearDown];
}

- (void)setUp
{
    [super setUp];
    _trackingManager = [_RPTTrackingManager sharedInstance];
    _trackingManager.sender = [MockSender.alloc initWithRingBuffer:_trackingManager.ringBuffer
                                                     configuration:_trackingManager.configuration
                                                     currentMetric:_trackingManager.currentMetric
                                                       eventWriter:_trackingManager.eventWriter];
}

- (BOOL)isPerfConfigURL:(NSURL *)requestURL
{
    return [requestURL.host hasPrefix:@"perf"];  // PROD
}

- (void)stubConfigResponseWithActivationRatio:(NSInteger)ratio
{
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [self isPerfConfigURL:request.URL];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSDictionary* obj = @{ @"enablePercent": @(ratio),
                               @"sendUrl": @"https://blah.blah",
                               @"sendHeaders": @{@"header1": @"value1",
                                                 @"header2": @"value2"} };
        return [OHHTTPStubsResponse responseWithJSONObject:obj statusCode:200 headers:nil];
    }];
}

- (void)testThatTrackingIsRunningWhenStubbedConfigHasOneHundredPercentActivationRatio
{
    [self stubConfigResponseWithActivationRatio:100];
    
    XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
    
    [_trackingManager updateConfiguration];
    
    // Wait for fetched configuration
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        XCTAssertFalse(((MockSender *)_trackingManager.sender).stopped);
        [waitForResponse fulfill];
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testThatTrackingStoppedWhenStubbedConfigHasZeroPercentActivationRatio
{
    [self stubConfigResponseWithActivationRatio:0];
    
    XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
    
    [_trackingManager updateConfiguration];
    
    // Wait for fetched configuration
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        XCTAssert(((MockSender *)_trackingManager.sender).stopped);
        [waitForResponse fulfill];
    });
    
    [self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)testThatTrackingStoppedWhenStubbedConfigHas500StatusCode
{
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [self isPerfConfigURL:request.URL];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSDictionary* obj = @{ @"enablePercent": @(100),
                               @"sendUrl": @"https://blah.blah",
                               @"sendHeaders": @{@"header1": @"value1",
                                                 @"header2": @"value2"} };
        return [OHHTTPStubsResponse responseWithJSONObject:obj statusCode:500 headers:nil];
    }];

    XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];

    [_trackingManager updateConfiguration];

    // Wait for fetched configuration
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        XCTAssert(((MockSender *)_trackingManager.sender).stopped);
        [waitForResponse fulfill];
    });

    [self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)testThatTrackingStoppedWhenStubbedInvalidConfig
{
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [self isPerfConfigURL:request.URL];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSDictionary* obj = @{};
        return [OHHTTPStubsResponse responseWithJSONObject:obj statusCode:200 headers:nil];
    }];

    XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];

    [_trackingManager updateConfiguration];

    // Wait for fetched configuration
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        XCTAssert(((MockSender *)_trackingManager.sender).stopped);
        [waitForResponse fulfill];
    });

    [self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)testThatIrrespectiveOfConfigActivationRatioSenderIsRunningInDebugBuilds
{
    [self stubConfigResponseWithActivationRatio:100];
    
    XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
    
    [_trackingManager updateConfiguration];
    
    // Wait for fetched configuration
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        XCTAssertFalse(((MockSender *)_trackingManager.sender).stopped);
        [self stubConfigResponseWithActivationRatio:10];
        [_trackingManager updateConfiguration];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
            XCTAssertFalse(((MockSender *)_trackingManager.sender).stopped);
            [waitForResponse fulfill];
        });
    });
    
    [self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)testThatSenderIsNotRunningWhenActivationRatioIsCloseToZero
{
    XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
    
    [self stubConfigResponseWithActivationRatio:0.01];
    
    id mockBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockBundle objectForInfoDictionaryKey:@"RPTForceTrackingEnabled"]).andReturn(@NO);
    
    [_trackingManager updateConfiguration];
    
    // Wait for fetched configuration
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssert(((MockSender *)_trackingManager.sender).stopped);
        [waitForResponse fulfill];
    });
    [self waitForExpectationsWithTimeout:3 handler:nil];
    [mockBundle stopMocking];
}

- (void)testThatSenderIsRunningWhenConfigResponseIsValid
{
    XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
    
    [self stubConfigResponseWithActivationRatio:1];
    
    id mockBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockBundle objectForInfoDictionaryKey:@"RPTForceTrackingEnabled"]).andReturn(@YES);
    
    [_trackingManager updateConfiguration];
    
    // Wait for fetched configuration
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertFalse(((MockSender *)_trackingManager.sender).stopped);
        [waitForResponse fulfill];
    });
    [self waitForExpectationsWithTimeout:3 handler:nil];
    [mockBundle stopMocking];
}

- (void)testThatTrackingStoppedWhenConfigIsInvalid
{
    id configMock = OCMClassMock(_RPTConfiguration.class);
    OCMStub([configMock loadConfiguration]).andReturn(nil);
    
    [_trackingManager updateConfiguration];
    
    XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        XCTAssert(((MockSender *)_trackingManager.sender).stopped);
        [waitForResponse fulfill];
    });
    
    [self waitForExpectationsWithTimeout:3 handler:nil];
    [configMock stopMocking];
}

- (void)testThatConfigIsRefreshedAfterRefreshInterval
{
    _trackingManager.refreshConfigInterval = 2.0;
    
    [self stubConfigResponseWithActivationRatio:100];
    
    XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
    
    [_trackingManager updateConfiguration];
    
    // Wait for fetched configuration
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSDictionary *HTTPHeaders = _trackingManager.configuration.eventHubHTTPHeaderFields;
        XCTAssertNotNil(HTTPHeaders);
        XCTAssertEqualObjects(HTTPHeaders[@"header1"], @"value1");
        XCTAssertEqualObjects(HTTPHeaders[@"header2"], @"value2");
        
        [OHHTTPStubs removeAllStubs];
        
        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return [self isPerfConfigURL:request.URL];
        } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
            NSDictionary* obj = @{ @"enablePercent": @(100),
                                   @"sendUrl": @"https://blah.blah",
                                   @"sendHeaders": @{@"header1": @"update1",
                                                     @"header2": @"update2"} };
            return [OHHTTPStubsResponse responseWithJSONObject:obj statusCode:200 headers:nil];
        }];
        
        [_trackingManager updateConfiguration];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            NSDictionary *HTTPHeaders = _trackingManager.configuration.eventHubHTTPHeaderFields;
            XCTAssertNotNil(HTTPHeaders);
            XCTAssertEqualObjects(HTTPHeaders[@"header1"], @"update1");
            XCTAssertEqualObjects(HTTPHeaders[@"header2"], @"update2");
            
            [waitForResponse fulfill];
        });
    });
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)testThatConfigCanBeFetchedFromServer
{
    XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
    
    [_trackingManager updateConfiguration];
    
    // Wait for fetched configuration
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        XCTAssertNotNil(_trackingManager.configuration);
        NSDictionary *HTTPHeaders = _trackingManager.configuration.eventHubHTTPHeaderFields;
        XCTAssertNotNil(HTTPHeaders);

        [waitForResponse fulfill];
    });
    
    [self waitForExpectationsWithTimeout:4 handler:nil];
}


- (void)testInfoPlistConfigurationAPIIsUsedIfProvided
{
	XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
	
	id mockBundle = OCMPartialMock([NSBundle mainBundle]);
	OCMStub([mockBundle bundleIdentifier]).andReturn(@"jp.co.rakuten.HostApp");
	OCMStub([mockBundle objectForInfoDictionaryKey:@"RPTConfigAPIEndpoint"]).andReturn(@"www.configuration.com");
	
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
		return [request.URL.absoluteString containsString:@"www.configuration.com"];
	} withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
		NSDictionary* obj = @{ @"enablePercent": @(10.0),
							   @"sendUrl": @"https://test",
							   @"sendHeaders": @{@"header1": @"value1",
												 @"header2": @"value2"} };
		return [OHHTTPStubsResponse responseWithJSONObject:obj statusCode:200 headers:nil];
	}];
	
	[_trackingManager updateConfiguration];
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		
		XCTAssertNotNil(_trackingManager.configuration);
		XCTAssertEqualObjects(_trackingManager.configuration.eventHubURL, [NSURL URLWithString:@"https://test"]);
		
		NSDictionary *HTTPHeaders = _trackingManager.configuration.eventHubHTTPHeaderFields;
		XCTAssertNotNil(HTTPHeaders);
		XCTAssertEqualObjects(HTTPHeaders[@"header1"], @"value1");
		XCTAssertEqualObjects(HTTPHeaders[@"header2"], @"value2");
		
		[waitForResponse fulfill];
	});
	
	[mockBundle stopMocking];
	[self waitForExpectationsWithTimeout:4 handler:nil];
}

- (void)assertThatConfigRequestIsNotSentWhenPlistReturnsValue:(NSString *)value forKey:(NSString *)key
{
    id mockBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockBundle bundleIdentifier]).andReturn(@"jp.co.rakuten.HostApp");
    OCMStub([mockBundle objectForInfoDictionaryKey:key]).andReturn(value);
    
    id mockNSURLSessionClass = OCMClassMock(NSURLSession.class);
    OCMStub([mockNSURLSessionClass sessionWithConfiguration:OCMOCK_ANY]).andDo(^(NSInvocation *inv){
        XCTFail(@"Shouldn't call sessionWithConfiguration when %@ is set to %@", key, value ?: @"nil");
    });
    
    XCTAssertThrowsSpecificNamed([_trackingManager updateConfiguration], NSException, NSInternalInconsistencyException); // Our NSAssert("key value".length) causes this to fire
    
    [mockNSURLSessionClass stopMocking];
    [mockBundle stopMocking];
}

- (void)testThatConfigRequestIsNotSentIfConfigEndpointIsNotInPlist
{
    [self assertThatConfigRequestIsNotSentWhenPlistReturnsValue:nil forKey:@"RPTConfigAPIEndpoint"];
}

- (void)testThatConfigRequestIsNotSentIfConfigEndpointIsZeroLengthInPlist
{
    [self assertThatConfigRequestIsNotSentWhenPlistReturnsValue:@"" forKey:@"RPTConfigAPIEndpoint"];
}

- (void)testThatConfigRequestIsNotSentIfSubscriptionKeyIsNotInPlist
{
    [self assertThatConfigRequestIsNotSentWhenPlistReturnsValue:nil forKey:@"RPTSubscriptionKey"];
}

- (void)testThatConfigRequestIsNotSentIfSubscriptionKeyIsZeroLengthInPlist
{
    [self assertThatConfigRequestIsNotSentWhenPlistReturnsValue:@"" forKey:@"RPTSubscriptionKey"];
}

- (void)testThatConfigRequestIsNotSentIfAppIDIsNotInPlist
{
    [self assertThatConfigRequestIsNotSentWhenPlistReturnsValue:nil forKey:@"RPTRelayAppID"];
}

- (void)testThatConfigRequestIsNotSentIfAppIDIsZeroLengthInPlist
{
    [self assertThatConfigRequestIsNotSentWhenPlistReturnsValue:@"" forKey:@"RPTRelayAppID"];
}

@end

@import OCMock;
#import <XCTest/XCTest.h>
#import <OHHTTPStubs/OHHTTPStubs.h>
#import <OHHTTPStubs/OHHTTPStubsResponse+HTTPMessage.h>
#import <OHHTTPStubs/OHHTTPStubsResponse+JSON.h>
#import "_RPTTrackingManager.h"
#import "_RPTTracker.h"
#import "_RPTSender.h"
#import "_RPTConfiguration.h"
#import "_RPTEnvironment.h"

#import <Kiwi/Kiwi.h>
#import <Underscore_m/Underscore.h>
#import "TestUtils.h"

SPEC_BEGIN(RPTTrackingManagerTests)

describe(@"RPTTRackingManager", ^{
    describe(@"init", ^{
        describe(@"config request", ^{
            __block NSURLSession* configURLSession;
            beforeEach(^{
                configURLSession = [NSURLSession nullMock];
                [NSURLSession stub:@selector(sessionWithConfiguration:) andReturn:configURLSession];
            });

            it(@"should append to config request os version as QS parameter", ^{
                KWCaptureSpy *spy = [configURLSession captureArgument:@selector(dataTaskWithURL:completionHandler:) atIndex:0];
                [_RPTEnvironment stub:@selector(new) andReturn:mkEnvironmentStub(@{@"osVersion": @"100500"})];
                
                [_RPTTrackingManager new];
                NSURL* configURL = spy.argument;
                
                [[configURL.query should] containString:@"osVersion=100500"];
            });
            
            it(@"should append to config request device model name as QS parameter", ^{
                KWCaptureSpy *spy = [configURLSession captureArgument:@selector(dataTaskWithURL:completionHandler:) atIndex:0];
                [_RPTEnvironment stub:@selector(new) andReturn:mkEnvironmentStub(@{@"modelIdentifier": @"ios_device"})];
                
                [_RPTTrackingManager new];
                NSURL* configURL = spy.argument;
                
                [[configURL.query should] containString:@"device=ios_device"];
            });
        });
    });
});

SPEC_END

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

- (void)stubConfigResponse:(NSDictionary*)params
{
    params = Underscore.defaults(params ? params : @{}, @{
        @"payload": mkConfigPayload_(nil),
        @"statusCode": @(200),
    });
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [self isPerfConfigURL:request.URL];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:params[@"payload"] statusCode:[params[@"statusCode"] intValue] headers:@{@"Content-Type": @"application/json"}];
    }];
}

- (void)testThatTrackingIsRunningWhenStubbedConfigHasOneHundredPercentActivationRatio
{
    [self stubConfigResponse:nil];
    
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
    [self stubConfigResponse:@{
        @"payload": mkConfigPayload_(@{@"enablePercent": @(0)})
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

- (void)testThatTrackingStoppedWhenStubbedConfigHas500StatusCode
{
    [self stubConfigResponse:@{@"statusCode": @(500)}];

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
    [self stubConfigResponse:@{
        @"payload": [NSData data]
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
    [self stubConfigResponse:nil];
    
    XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
    
    [_trackingManager updateConfiguration];
    
    // Wait for fetched configuration
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        XCTAssertFalse(((MockSender *)_trackingManager.sender).stopped);
        [self stubConfigResponse:@{
            @"payload": mkConfigPayload_(@{@"enablePercent": @(10)})
        }];
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
    
    [self stubConfigResponse:@{
        @"payload": mkConfigPayload_(@{@"enablePercent": @(0.00001)})
    }];
    
    id mockBundle = OCMPartialMock([NSBundle mainBundle]);
    OCMStub([mockBundle objectForInfoDictionaryKey:@"RPTForceTrackingEnabled"]).andReturn(@NO);
    
    _RPTTrackingManager* manager = [[_RPTTrackingManager alloc] init];
    manager.sender = [MockSender.alloc initWithRingBuffer:_trackingManager.ringBuffer
                                                     configuration:_trackingManager.configuration
                                                     currentMetric:_trackingManager.currentMetric
                                                       eventWriter:_trackingManager.eventWriter];
    
    [manager updateConfiguration];
    
    // Wait for fetched configuration
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssert(((MockSender *)manager.sender).stopped);
        [waitForResponse fulfill];
    });
    [self waitForExpectationsWithTimeout:3 handler:nil];
    [mockBundle stopMocking];
}

- (void)testThatSenderIsRunningWhenConfigResponseIsValid
{
    XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
    
    [self stubConfigResponse:nil];
    
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
    
    [self stubConfigResponse:@{
        @"payload": mkConfigPayload_(@{
            @"sendHeaders": @{
                @"header1": @"value1",
                @"header2": @"value2"
            }
        })
    }];
    
    XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
    
    [_trackingManager updateConfiguration];
    
    // Wait for fetched configuration
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSDictionary *HTTPHeaders = _trackingManager.configuration.eventHubHTTPHeaderFields;
        XCTAssertNotNil(HTTPHeaders);
        XCTAssertEqualObjects(HTTPHeaders[@"header1"], @"value1");
        XCTAssertEqualObjects(HTTPHeaders[@"header2"], @"value2");
        
        [OHHTTPStubs removeAllStubs];
        
        [self stubConfigResponse:@{
            @"payload": mkConfigPayload_(@{@"enablePercent": @(0.01)})
        }];
        
        [self stubConfigResponse:@{
            @"payload": mkConfigPayload_(@{
                @"sendHeaders": @{
                    @"header1": @"update1",
                    @"header2": @"update2"
                }
            })
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
    OCMStub([mockBundle objectForInfoDictionaryKey:@"RPTConfigAPIEndpoint"]).andReturn(@"https://www.configuration.com");
	
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
		return [request.URL.absoluteString containsString:@"https://www.configuration.com"];
	} withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
		NSDictionary* obj = @{ @"enablePercent": @(10.0),
							   @"sendUrl": @"https://test.com",
                               @"enableNonMetricMeasurement": @"true",
							   @"sendHeaders": @{@"header1": @"value1",
												 @"header2": @"value2"} };
		return [OHHTTPStubsResponse responseWithJSONObject:obj statusCode:200 headers:nil];
	}];
	
	[_trackingManager updateConfiguration];
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		
		XCTAssertNotNil(_trackingManager.configuration);
		XCTAssertEqualObjects(_trackingManager.configuration.eventHubURL, [NSURL URLWithString:@"https://test.com"]);
		
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

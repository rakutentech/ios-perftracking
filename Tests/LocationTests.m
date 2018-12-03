@import OCMock;
#import <XCTest/XCTest.h>
#import <OHHTTPStubs/OHHTTPStubs.h>
#import <OHHTTPStubs/OHHTTPStubsResponse+HTTPMessage.h>
#import <OHHTTPStubs/OHHTTPStubsResponse+JSON.h>
#import "_RPTTrackingManager.h"
#import "_RPTLocation.h"
#import "_RPTEventWriter.h"
#import "_RPTSender.h"
#import "_RPTTracker.h"
#import "_RPTConfiguration.h"

@interface _RPTTrackingManager()
@property (nonatomic) _RPTEventWriter       *eventWriter;
- (void)refreshLocation;
- (void)updateConfiguration;
@end

@interface _RPTConfiguration()
+ (instancetype)loadConfiguration;
@end

@interface _RPTEventWriter()

@property (nonatomic) NSMutableString					*writer;
- (void)begin;

@end

@interface LocationTests : XCTestCase
@end

@implementation LocationTests
static _RPTTrackingManager *_trackingManager = nil;

- (void)setUp
{
	[super setUp];

	_trackingManager = [_RPTTrackingManager sharedInstance];
	_trackingManager.eventWriter =  [_RPTEventWriter.alloc initWithConfiguration:[_RPTConfiguration loadConfiguration]];
	
	//Clear any object which has been stored in the keystore
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"com.rakuten.performancetracking.location"];
}

- (void)tearDown
{
	[OHHTTPStubs removeAllStubs];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"com.rakuten.performancetracking.location"];
	_trackingManager = nil;
	[super tearDown];
}

// To enable, set a valid `RPTLocationAPIEndpoint` and `RPTSubscriptionKey` in HostApp's info.plist
- (void)DISABLED_testThatLocationAndCountryCanBeFetchedFromServer
{
	XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
	
	[_trackingManager refreshLocation];
	
	// Wait for fetched location
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		
		_RPTLocation *locationHelper = [_RPTLocation loadLocation];
		XCTAssertNotNil(locationHelper);
		NSString *location = locationHelper.location;
		NSString *country = locationHelper.country;
		XCTAssertNotNil(location);
		XCTAssertNotNil(country);
		[waitForResponse fulfill];
	});
	
	[self waitForExpectationsWithTimeout:4 handler:nil];
}

- (void)testThatInvalidLocationAPIResponseIsHandled
{
	XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
	
	[self stubLocationRequestsWithStatusCode:200 responseDictionary:@{ @"Location": @(95)}];
	
    [_RPTLocationFetcher fetch];
	
	// Wait for fetched location
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		
		_RPTLocation *locationHelper = [_RPTLocation loadLocation];
		XCTAssertNil(locationHelper);
		NSString *location = locationHelper.location;
		NSString *country = locationHelper.country;
		XCTAssertNil(location);
		XCTAssertNil(country);
		[waitForResponse fulfill];
	});
	[self waitForExpectationsWithTimeout:6 handler:nil];
}

- (void)testThatLocationAPI500ResponseIsHandled
{
	XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
	
	[self stubLocationRequestsWithStatusCode:500 responseDictionary:@{ @"Location": @(95)}];

	[_RPTLocationFetcher fetch];
	
	// Wait for fetched location
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		
		_RPTLocation *locationHelper = [_RPTLocation loadLocation];
		XCTAssertNil(locationHelper);
		NSString *location = locationHelper.location;
		NSString *country = locationHelper.country;
		XCTAssertNil(location);
		XCTAssertNil(country);
		[waitForResponse fulfill];
	});
	[self waitForExpectationsWithTimeout:6 handler:nil];
}

- (void)testThatLocationAPIResposeErrorSendsDefaultLocale
{
	XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
	
	[_trackingManager updateConfiguration];
	
	[self stubLocationRequestsWithStatusCode:500 responseDictionary:@{ @"Location": @(95)}];
	
	[_RPTLocationFetcher fetch];
	
	uint_fast64_t ti = [_trackingManager.tracker startCustom:@"m1"];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[_trackingManager.tracker end:ti];
	});
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[_trackingManager.eventWriter begin];
		XCTAssertNotNil(_trackingManager.eventWriter.writer);
		XCTAssertTrue([_trackingManager.eventWriter.writer containsString:[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]]);
		[waitForResponse fulfill];
	});
	[self waitForExpectationsWithTimeout:4 handler:nil];
}

- (void)testThatWriterSendsLocationAndCountryResponseCorrectly
{
	XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
	
	[_trackingManager updateConfiguration];
	
	NSDictionary *obj = @{ @"status": @"ok", @"list": @[@{@"subdivisions" : @[@{@"names" : @{@"en" : @"teststate"}}], @"country" : @{@"iso_code" : @"testcountry"}}]};

	[self stubLocationRequestsWithStatusCode:200 responseDictionary:obj];
	[_RPTLocationFetcher fetch];
		
	uint_fast64_t ti = [_trackingManager.tracker startCustom:@"m1"];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[_trackingManager.tracker end:ti];
	});
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[_trackingManager.eventWriter begin];
		XCTAssertNotNil(_trackingManager.eventWriter.writer);
		XCTAssertTrue([_trackingManager.eventWriter.writer containsString:@"teststate"]);
		XCTAssertTrue([_trackingManager.eventWriter.writer containsString:@"testcountry"]);
		[waitForResponse fulfill];
	});
	[self waitForExpectationsWithTimeout:4 handler:nil];
}

- (void)testInfoPlistLocationAPIIsUsedIfProvided
{
	XCTestExpectation *waitForResponse = [self expectationWithDescription:@"wait"];
	
	id mockBundle = OCMPartialMock([NSBundle mainBundle]);
	OCMStub([mockBundle bundleIdentifier]).andReturn(@"jp.co.rakuten.HostApp");
	OCMStub([mockBundle objectForInfoDictionaryKey:@"RPTLocationAPIEndpoint"]).andReturn(@"www.location.com/performance/geo");
	
	NSDictionary *obj = @{ @"status": @"ok", @"list": @[@{@"subdivisions" : @[@{@"names" : @{@"en" : @"teststate"}}], @"country" : @{@"iso_code" : @"testcountry"}}]};
	
	[self stubLocationRequestsWithStatusCode:200 responseDictionary:obj];
	
	[_RPTLocationFetcher fetch];
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		
		_RPTLocation *locationObj = [_RPTLocation loadLocation];
		XCTAssertNotNil(locationObj);
		XCTAssertEqualObjects(locationObj.location, @"teststate");
		XCTAssertEqualObjects(locationObj.country, @"testcountry");
		[waitForResponse fulfill];
	});
	
	[mockBundle stopMocking];
	[self waitForExpectationsWithTimeout:4 handler:nil];
}

#pragma mark - Helpers

- (void)stubLocationRequestsWithStatusCode:(int)statusCode responseDictionary:(NSDictionary *)responseDictionary
{
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
		return [self isLocationURL:request.URL];
	} withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
		NSDictionary* obj = responseDictionary;
		return [OHHTTPStubsResponse responseWithJSONObject:obj statusCode:statusCode headers:nil];
	}];
}
- (BOOL)isLocationURL:(NSURL *)requestURL
{
	return [requestURL.absoluteString containsString:@"location"];
}

@end

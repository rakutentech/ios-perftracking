#import <Kiwi/Kiwi.h>
#import "_RPTConfiguration.h"
#import "_RPTEnvironment.h"

#import "TestUtils.h"

SPEC_BEGIN(RPTConfigurationTests)

describe(@"RPTConfiguration", ^{
    describe(@"initWithData:", ^{
        it(@"should `shouldTrackNonMetricMeasurements` property as `YES` by default", ^{
            NSData* payload = mkConfigPayload_(nil);

            _RPTConfiguration* config = [[_RPTConfiguration alloc] initWithData:payload];

            [[theValue(config.shouldTrackNonMetricMeasurements) should] beTrue];
        });

        it(@"should `shouldSendDataToPerformanceTracking` property as `YES` by default", ^{
            NSData* payload = mkConfigPayload_(nil);

            _RPTConfiguration* config = [[_RPTConfiguration alloc] initWithData:payload];

            [[theValue(config.shouldSendDataToPerformanceTracking) should] beTrue];
        });

        it(@"should `shouldSendDataToRAT` property as `NO` by default", ^{
            NSData* payload = mkConfigPayload_(nil);

            _RPTConfiguration* config = [[_RPTConfiguration alloc] initWithData:payload];

            [[theValue(config.shouldSendDataToRAT) should] beFalse];
        });

        it(@"should `shouldTrackNonMetricMeasurements` property as `YES` if `enableNonMetricMeasurement` payload field is not a number", ^{
            NSData* payload = mkConfigPayload_(@{@"enableNonMetricMeasurement": @"123"});
            
            _RPTConfiguration* config = [[_RPTConfiguration alloc] initWithData:payload];
            
            [[theValue(config.shouldTrackNonMetricMeasurements) should] beTrue];
        });
        
        it(@"should set `shouldTrackNonMetricMeasurements` property as `YES` if `enableNonMetricMeasurement` payload field is `true`", ^{
            NSData* payload = mkConfigPayload_(@{@"enableNonMetricMeasurement": @YES});
            
            _RPTConfiguration* config = [[_RPTConfiguration alloc] initWithData:payload];
            
            [[theValue(config.shouldTrackNonMetricMeasurements) should] beTrue];
        });
        
        it(@"should set `shouldTrackNonMetricMeasurements` property as `NO` if `enableNonMetricMeasurement` payload field is not `true`", ^{
            NSData* payload = mkConfigPayload_(@{@"enableNonMetricMeasurement": @NO});
            
            _RPTConfiguration* config = [[_RPTConfiguration alloc] initWithData:payload];
            
            [[theValue(config.shouldTrackNonMetricMeasurements) should] beFalse];
        });

        it(@"should set `shouldSendDataToPerformanceTracking` property as `YES` if `module.enablePerformanceTracking` payload field is `true`", ^{
            NSData* payload = mkConfigPayload_(@{@"modules": @{@"enablePerformanceTracking": @YES}});

            _RPTConfiguration* config = [[_RPTConfiguration alloc] initWithData:payload];

            [[theValue(config.shouldSendDataToPerformanceTracking) should] beTrue];
        });

        it(@"should set `shouldSendDataToPerformanceTracking` property as `NO` if `module.enablePerformanceTracking` payload field is not `true`", ^{
            NSData* payload = mkConfigPayload_(@{@"modules": @{@"enablePerformanceTracking": @NO}});

            _RPTConfiguration* config = [[_RPTConfiguration alloc] initWithData:payload];

            [[theValue(config.shouldSendDataToPerformanceTracking) should] beFalse];
        });

        it(@"should set `shouldSendDataToRAT` property as `YES` if `module.enableRat` payload field is `true`", ^{
            NSData* payload = mkConfigPayload_(@{@"modules": @{@"enableRat": @YES}});

            _RPTConfiguration* config = [[_RPTConfiguration alloc] initWithData:payload];

            [[theValue(config.shouldSendDataToRAT) should] beTrue];
        });

        it(@"should set `shouldSendDataToRAT` property as `NO` if `module.enableRat` payload field is not `true`", ^{
            NSData* payload = mkConfigPayload_(@{@"modules": @{@"enableRat": @NO}});

            _RPTConfiguration* config = [[_RPTConfiguration alloc] initWithData:payload];

            [[theValue(config.shouldSendDataToRAT) should] beFalse];
        });
    });
});

SPEC_END

SPEC_BEGIN(_RPTConfigurationFetcherTests)

describe(@"_RPTConfigurationFetcher", ^{
    describe(@"config fetch", ^{
        __block NSURLSession* configURLSession;
        beforeEach(^{
            configURLSession = [NSURLSession nullMock];
            [NSURLSession stub:@selector(sessionWithConfiguration:) andReturn:configURLSession];
        });
        
        it(@"should append to config request os version as QS parameter", ^{
            KWCaptureSpy *spy = [configURLSession captureArgument:@selector(dataTaskWithURL:completionHandler:) atIndex:0];
            [_RPTEnvironment stub:@selector(new) andReturn:mkEnvironmentStub(@{@"osVersion": @"100500"})];
            
            [_RPTConfigurationFetcher fetchWithCompletionHandler:nil];
            NSURL* configURL = spy.argument;
            
            [[configURL.query should] containString:@"osVersion=100500"];
        });
        
        it(@"should append to config request device model name as QS parameter", ^{
            KWCaptureSpy *spy = [configURLSession captureArgument:@selector(dataTaskWithURL:completionHandler:) atIndex:0];
            [_RPTEnvironment stub:@selector(new) andReturn:mkEnvironmentStub(@{@"modelIdentifier": @"ios_device"})];
            
            [_RPTConfigurationFetcher fetchWithCompletionHandler:nil];
            NSURL* configURL = spy.argument;
            
            [[configURL.query should] containString:@"device=ios_device"];
        });
    });
});

SPEC_END

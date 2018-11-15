#import <Kiwi/Kiwi.h>
#import "_RPTConfiguration.h"

#import "TestUtils.h"

SPEC_BEGIN(RPTConfigurationTests)

describe(@"RPTTracker", ^{
    describe(@"initWithData:", ^{
        it(@"should `shouldTrackNonMetricMeasurements` property as `YES` if `enableNonMetricMeasurement` payload field is not a number", ^{
            NSData* payload = mkConfigPayload_(@{@"enableNonMetricMeasurement": [NSNull null]});
            
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
            NSData* payload = mkConfigPayload_(@{@"modules": @{@"enableNonMetricMeasurement": @YES}});

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

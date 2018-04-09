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
    });
});

SPEC_END

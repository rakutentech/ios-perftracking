#import <Kiwi/Kiwi.h>
#import "_RPTEnvironment.h"

#import "TestUtils.h"

SPEC_BEGIN(RPTEnvironmentTests)

describe(@"RPTEnvironment", ^{
    describe(@"init", ^{
        it(@"should set app identifier as main bundle identifier", ^{
            [[NSBundle mainBundle] stub:@selector(bundleIdentifier) andReturn:@"current_bundle_identifier"];
            
            _RPTEnvironment* env = [_RPTEnvironment new];
            
            [[env.appIdentifier should] equal:@"current_bundle_identifier"];
        });
        
        it(@"should set app version as short version version string from info.plist", ^{
            [[NSBundle mainBundle] stub:@selector(objectForInfoDictionaryKey:) andReturn:@"current_app_version" withArguments:@"CFBundleShortVersionString"];
            
            _RPTEnvironment* env = [_RPTEnvironment new];
            
            [[env.appVersion should] equal:@"current_app_version"];
        });
        
        it(@"should set device model as machine information from system info", ^{
            // Hardware info is fetched via C-level API, which is hard to stub without breaking incapsulation. Stubbing function which processes its result
            [NSString stub:@selector(stringWithUTF8String:) andReturn:@"device_model_id"];
            
            _RPTEnvironment* env = [_RPTEnvironment new];
            
            [[env.modelIdentifier should] equal:@"device_model_id"];
        });
        
        it(@"should set OS version as system version", ^{
            [UIDevice.currentDevice stub:@selector(systemVersion) andReturn:@"100500"];
            
            _RPTEnvironment* env = [_RPTEnvironment new];
            
            [[env.osVersion should] equal:@"100500"];
        });
        
        it(@"should set SDK version to podspec version", ^{
            _RPTEnvironment* env = [_RPTEnvironment new];
            
            [[env.sdkVersion should] equal:RPTSDKVersion];
        });
        
        it(@"should set relay app id as relay app id from info.plist", ^{
            [[NSBundle mainBundle] stub:@selector(objectForInfoDictionaryKey:) andReturn:@"relay_app_id" withArguments:@"RPTRelayAppID"];
            
            _RPTEnvironment* env = [_RPTEnvironment new];
            
            [[env.relayAppId should] equal:@"relay_app_id"];
        });
        
        describe(@"performanceTrackingBaseURL", ^{
            it(@"should set performance tracking base URL as RPTConfigAPIEndpoint from info.plist", ^{
                [[NSBundle mainBundle] stub:@selector(objectForInfoDictionaryKey:) andReturn:@"http://example.com" withArguments:@"RPTConfigAPIEndpoint"];
                
                _RPTEnvironment* env = [_RPTEnvironment new];
                
                [[env.baseURL should] equal:[NSURL URLWithString:@"http://example.com"]];
            });
            
            it(@"should set performance tracking base URL as nil if base URL is not available in info.plist", ^{
                [[NSBundle mainBundle] stub:@selector(objectForInfoDictionaryKey:) andReturn:nil withArguments:@"RPTConfigAPIEndpoint"];
                
                _RPTEnvironment* env = [_RPTEnvironment new];
                
                [[env.baseURL should] beNil];
            });
            
            it(@"should set performance tracking base URL as nil if base URL in info.plist is not a valid URL", ^{
                [[NSBundle mainBundle] stub:@selector(objectForInfoDictionaryKey:) andReturn:@"ht:\\some_random_string" withArguments:@"RPTConfigAPIEndpoint"];
                
                _RPTEnvironment* env = [_RPTEnvironment new];
                
                [[env.baseURL should] beNil];
            });
            
            it(@"should set performance tracking base URL as nil if base URL in info.plist is an empty string", ^{
                [[NSBundle mainBundle] stub:@selector(objectForInfoDictionaryKey:) andReturn:@"" withArguments:@"RPTConfigAPIEndpoint"];
                
                _RPTEnvironment* env = [_RPTEnvironment new];
                
                [[env.baseURL should] beNil];
            });
        });

        describe(@"performanceTrackingSubscriptionKey", ^{
            it(@"should set subscription key to info.plist sub key with a ras- prefix", ^{
                [[NSBundle mainBundle] stub:@selector(objectForInfoDictionaryKey:) andReturn:@"perftrack_subscription_key" withArguments:@"RPTSubscriptionKey"];

                _RPTEnvironment* env = [_RPTEnvironment new];

                [[env.subscriptionKey should] equal:@"ras-perftrack_subscription_key"];
            });

            it(@"subscription key should be nil when info.plist doesn't contain sub key", ^{
                [[NSBundle mainBundle] stub:@selector(objectForInfoDictionaryKey:) andReturn:nil];

                _RPTEnvironment* env = [_RPTEnvironment new];

                [[env.subscriptionKey should] beNil];
            });
        });

        describe(@"maximumMetricDurationSeconds", ^{
            it(@"should set max duration to info.plist RPTMaximumMetricDurationSeconds integer value", ^{
                [[NSBundle mainBundle] stub:@selector(objectForInfoDictionaryKey:) andReturn:@(20) withArguments:@"RPTMaximumMetricDurationSeconds"];

                _RPTEnvironment* env = [_RPTEnvironment new];

                [[theValue(env.maximumMetricDurationSeconds) should] equal:theValue(20.0)];
            });

            it(@"should set max duration to info.plist RPTMaximumMetricDurationSeconds double value", ^{
                [[NSBundle mainBundle] stub:@selector(objectForInfoDictionaryKey:) andReturn:@(20.5) withArguments:@"RPTMaximumMetricDurationSeconds"];

                _RPTEnvironment* env = [_RPTEnvironment new];

                [[theValue(env.maximumMetricDurationSeconds) should] equal:theValue(20.5)];
            });

            it(@"should set max duration to 0 when RPTMaximumMetricDurationSeconds is not in info.plist", ^{
                [[NSBundle mainBundle] stub:@selector(objectForInfoDictionaryKey:) andReturn:nil withArguments:@"RPTMaximumMetricDurationSeconds"];

                _RPTEnvironment* env = [_RPTEnvironment new];

                [[theValue(env.maximumMetricDurationSeconds) should] equal:theValue(0)];
            });
        });
        
        it(@"should set device country as country reported by current locale", ^{
            [[NSLocale currentLocale] stub:@selector(objectForKey:) andReturn:@"country_code" withArguments:NSLocaleCountryCode];
            
            _RPTEnvironment* env = [_RPTEnvironment new];
            
            [[env.deviceCountry should] equal:@"country_code"];
        });
    });
});

SPEC_END


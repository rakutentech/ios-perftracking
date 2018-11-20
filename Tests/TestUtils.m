#import <Kiwi/Kiwi.h>
#import <Underscore_m/Underscore.h>

#import "_RPTTracker.h"
#import "_RPTRingBuffer.h"
#import "_RPTMeasurement.h"
#import "_RPTMetric.h"
#import "_RPTConfiguration.h"
#import "_RPTEnvironment.h"

NSData* mkConfigPayload_(NSDictionary* params) {
    NSDictionary* payload = Underscore.defaults(params ? params : @{}, @{
        @"enablePercent": @(100),
        @"sendUrl": @"https://example.com",
        @"enableNonMetricMeasurement": @(YES),
        @"sendHeaders": @{@"header1": @"value1", @"header2": @"value2"},
        @"modules": @{@"enablePerformanceTracking": @(YES),
                      @"enableRat": @(NO)}
    });
    
    return [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:0];
}

_RPTMeasurement* mkMeasurementStub(NSDictionary* params) {
    params = Underscore.defaults(params ? params : @{}, @{
        @"trackingIdentifier": theValue(-1)
    });
    
    _RPTMeasurement* measurement = [_RPTMeasurement nullMock];
    
    [measurement stub:@selector(trackingIdentifier) andReturn:params[@"trackingIdentifier"]];
    
    return measurement;
}


_RPTRingBuffer* mkRingBufferStub(NSDictionary* params) {
    params = Underscore.defaults(params ? params : @{}, @{
        @"nextMeasurement": mkMeasurementStub(nil)
    });
    
    _RPTRingBuffer* buffer = [_RPTRingBuffer nullMock];
    
    [buffer stub:@selector(nextMeasurement) andReturn:params[@"nextMeasurement"]];
    
    return buffer;
}

_RPTMetric* mkMetricStub(NSDictionary* params) {
    return [_RPTMetric nullMock];
}

_RPTConfiguration* mkConfigurationStub(NSDictionary* params) {
    params = Underscore.defaults(params ? params : @{}, @{
        @"activationRatio": @(100),
        @"eventHubURL": [NSURL URLWithString:@"https://default.event.hub.url"],
        @"eventHubHTTPHeaderFields": @{@"default_header": @"default_header_value"},
        @"shouldTrackNonMetricMeasurements": @(YES),
        @"shouldSendDataToPerformanceTracking": @(YES),
        @"shouldSendDataToRAT": @(NO)
    });
    
    _RPTConfiguration* config = [_RPTConfiguration nullMock];

    [config stub:@selector(activationRatio) andReturn:params[@"activationRatio"]];
    [config stub:@selector(eventHubURL) andReturn:params[@"eventHubURL"]];
    [config stub:@selector(eventHubHTTPHeaderFields) andReturn:params[@"eventHubHTTPHeaderFields"]];
    [config stub:@selector(shouldTrackNonMetricMeasurements) andReturn:params[@"shouldTrackNonMetricMeasurements"]];
    [config stub:@selector(shouldSendDataToPerformanceTracking) andReturn:params[@"shouldSendDataToPerformanceTracking"]];
    [config stub:@selector(shouldSendDataToRAT) andReturn:params[@"shouldSendDataToRAT"]];

    return config;
}

_RPTEnvironment* mkEnvironmentStub(NSDictionary* params) {
    params = Underscore.defaults(params ? params : @{}, @{
        @"appIdentifier": @"com.default.app.identifier",
        @"appVersion": @"0.0.1",
        @"modelIdentifier": @"default_iOS_device",
        @"osVersion": @"0.0.1",
        @"relayAppId": @"default_relay_app_id",
        @"performanceTrackingBaseURL": [NSURL URLWithString:@"http://default_perftrack_base_url"],
        @"performanceTrackingSubscriptionKey": @"default_performance_tracking_subscription_key",
        @"deviceCountry": @"default_device_country"
    });
    
    _RPTEnvironment* environment = [_RPTEnvironment nullMock];
    
    for (NSString* key in params) {
        id value = [params objectForKey:key];
        
        [environment stub:NSSelectorFromString(key) andReturn:value];
    }
    
    return environment;
}

void mkFillBuffer(_RPTRingBuffer *buffer, NSInteger fromIndex, NSInteger toIndex)
{
    _RPTMeasurement *measurement = nil;
    for (NSInteger i = 0; i < toIndex; i++) {
        measurement = [buffer nextMeasurement];
        if (i < fromIndex-1) {
            [measurement clear];
        }
    }
}


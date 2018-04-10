#import <Kiwi/Kiwi.h>
#import <Underscore_m/Underscore.h>

#import "_RPTTracker.h"
#import "_RPTRingBuffer.h"
#import "_RPTMeasurement.h"
#import "_RPTMetric.h"
#import "_RPTConfiguration.h"

NSData* mkConfigPayload_(NSDictionary* params) {
    NSDictionary* payload = Underscore.defaults(params ? params : @{}, @{
        @"enablePercent": @(100),
        @"sendUrl": @"https://blah.blah",
        @"enableNonMetricMeasurement": @"true",
        @"sendHeaders": @{@"header1": @"value1", @"header2": @"value2"}
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
        @"shouldTrackNonMetricMeasurements": @(YES)
    });
    
    _RPTConfiguration* config = [_RPTConfiguration nullMock];
    
    [config stub:@selector(activationRatio) andReturn:params[@"activationRatio"]];
    [config stub:@selector(eventHubURL) andReturn:params[@"eventHubURL"]];
    [config stub:@selector(eventHubHTTPHeaderFields) andReturn:params[@"eventHubHTTPHeaderFields"]];
    [config stub:@selector(shouldTrackNonMetricMeasurements) andReturn:@"shouldTrackNonMetricMeasurements"];
    
    return config;
}

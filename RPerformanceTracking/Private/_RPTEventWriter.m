@import UIKit.UIDevice;
@import Darwin.POSIX.sys.utsname;
@import CoreTelephony;
#import <SystemConfiguration/SystemConfiguration.h>
#import "_RPTEventWriter.h"
#import "_RPTConfiguration.h"
#import "_RPTMetric.h"
#import "_RPTMeasurement.h"
#import "_RPTHelpers.h"
#import "RPerformanceTracking.h"
#import "_RPTLocation.h"
#import "_RPTTrackingManager.h"
#import "UIDevice+RPerformanceTracking.h"

NSString *_RPTJSONFormatWithStringValue(NSString *key, NSString *value);
NSString *_RPTJSONFormatWithIntegerValue(NSString *key, long long value);
NSString *_RPTJSONFormatWithUnsignedIntegerValue(NSString *key, unsigned long long value);
NSString *_RPTJSONFormatWithFloatValue(NSString *key, float value);

NSString *_RPTJSONFormatWithStringValue(NSString *key, NSString *value)
{
    return [NSString stringWithFormat:@"\"%@\":\"%@\"", key, value];
}

NSString *_RPTJSONFormatWithIntegerValue(NSString *key, long long value)
{
    return [NSString stringWithFormat:@"\"%@\":%lld", key, value];
}

NSString *_RPTJSONFormatWithUnsignedIntegerValue(NSString *key, unsigned long long value)
{
    return [NSString stringWithFormat:@"\"%@\":%llu", key, value];
}

NSString *_RPTJSONFormatWithFloatValue(NSString *key, float value)
{
    return [NSString stringWithFormat:@"\"%@\":%.2f", key, value];
}

@interface _RPTEventWriter ()
@property (nonatomic) _RPTConfiguration					*configuration;
@property (nonatomic) CTTelephonyNetworkInfo			*telephonyNetworkInfo;

@property (nonatomic) NSMutableString					*writer;
@property (nonatomic) NSInteger					 		 measurementCount;
@property (nonatomic) _RPTLocation						*locationHelper;
@end

@implementation _RPTEventWriter

#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"

- (instancetype)init NS_UNAVAILABLE
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initWithConfiguration:(_RPTConfiguration *)configuration
{
    if ((self = [super init]))
    {
        _configuration = configuration;
        _telephonyNetworkInfo  = CTTelephonyNetworkInfo.new;
    }
    return self;
}

- (void)begin
{
    static NSString *appIdentifier;
    static NSString *appVersion;
    static NSString *modelIdentifier;
    static UIDevice *device;
    static NSString *osVersion;
    __block NSString *carrierName;
    static SCNetworkReachabilityRef reachability;

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSBundle *bundle = NSBundle.mainBundle;
        appIdentifier = bundle.bundleIdentifier;
        appVersion = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        device = UIDevice.currentDevice;
        osVersion = [NSString stringWithFormat:@"%@", device.systemVersion];

        struct utsname systemInfo;
        uname(&systemInfo);
        BOOL isNullTerminated = NO;
        for (int i = 0 ; i != sizeof(systemInfo.machine) ; i++) {
            if (systemInfo.machine[i] == '\0') {
                isNullTerminated = YES;
                break;
            }
        }
        if (isNullTerminated)
        {
            modelIdentifier = [NSString.alloc initWithUTF8String:systemInfo.machine];
        }
    });

    void (^assignCarrierName)(CTCarrier *) = ^(CTCarrier *carrier) {
        if(carrier.carrierName)
        {
            carrierName = carrier.carrierName.copy;
        }
    };
    
    // Find the reachability then update the carrierName
    reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [_RPTTrackingManager sharedInstance].configuration.eventHubURL.host.UTF8String);
    SCNetworkReachabilityScheduleWithRunLoop(reachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    SCNetworkReachabilityFlags flags;
    if (SCNetworkReachabilityGetFlags(reachability, &flags))
    {
        if ((flags & kSCNetworkReachabilityFlagsIsWWAN))
        {
            CTTelephonyNetworkInfo *telephonyNetworkInfo = self.telephonyNetworkInfo;
            assignCarrierName(telephonyNetworkInfo.subscriberCellularProvider);
            telephonyNetworkInfo.subscriberCellularProviderDidUpdateNotifier = ^(CTCarrier *carrier) {
                assignCarrierName(carrier);
            };
        }
        else
        {
            carrierName = @"wifi";
        }
    }
    
    _measurementCount = 0;
    if (_writer)
    {
        _writer = nil;
    }
    _writer = [NSMutableString string];
    [_writer appendString:@"{"];
    if (appIdentifier)
    {
        [_writer appendString:_RPTJSONFormatWithStringValue(@"app", appIdentifier)];
    }

    if (appVersion)
    {
        [_writer appendString:@","];
        [_writer appendString:_RPTJSONFormatWithStringValue(@"version", appVersion)];
    }

    if (modelIdentifier)
    {
        [_writer appendString:@","];
        [_writer appendString:_RPTJSONFormatWithStringValue(@"device", modelIdentifier)];
    }
	
    NSString *region = [_RPTLocation loadLocation].location;
    if (region)
    {
        [_writer appendString:@","];
        [_writer appendString:_RPTJSONFormatWithStringValue(@"region", region)];
    }
    
	NSString *country = [_RPTLocation loadLocation].country ? : [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    if (country)
    {
        [_writer appendString:@","];
        [_writer appendString:_RPTJSONFormatWithStringValue(@"country", country)];
    }

    if (carrierName)
    {
        [_writer appendString:@","];
        [_writer appendString:_RPTJSONFormatWithStringValue(@"network", carrierName)];
    }
    
    [_writer appendString:@","];
    [_writer appendString:_RPTJSONFormatWithStringValue(@"os", @"ios")];
    
    if (osVersion)
    {
        [_writer appendString:@","];
        [_writer appendString:_RPTJSONFormatWithStringValue(@"os_version", osVersion)];
    }

    [_writer appendString:@","];
    [_writer appendString:_RPTJSONFormatWithIntegerValue(@"app_mem_used", [device usedAppMemory])];

    [_writer appendString:@","];
    [_writer appendString:_RPTJSONFormatWithIntegerValue(@"device_mem_free", [device freeDeviceMemory])];

    [_writer appendString:@","];
    [_writer appendString:_RPTJSONFormatWithIntegerValue(@"device_mem_total", [device totalDeviceMemory])];

    [_writer appendString:@","];
    [_writer appendString:_RPTJSONFormatWithFloatValue(@"battery_level", device.batteryLevel)];

    [_writer appendString:@",\"measurements\":["];
}

- (void)writeWithMetric:(_RPTMetric *)metric
{
    if (!_writer || (metric.endTime - metric.startTime < 0)) return;

    NSTimeInterval duration = (metric.endTime - metric.startTime) * 1000.0;

    if (_measurementCount > 0)
    {
        [_writer appendString:@","];
    }

    [_writer appendString:@"{"];
    [_writer appendString:_RPTJSONFormatWithStringValue(@"metric", metric.identifier)];
    [_writer appendString:@","];
    [_writer appendString:_RPTJSONFormatWithUnsignedIntegerValue(@"urls", metric.urlCount)];
    [_writer appendString:@","];
    [_writer appendString:_RPTJSONFormatWithUnsignedIntegerValue(@"time", MAX(1ull, (unsigned long long)duration))]; // round to 1ms
    [_writer appendString:@","];
    [_writer appendString:_RPTJSONFormatWithUnsignedIntegerValue(@"start", MAX(0ull, (unsigned long long)(metric.startTime * 1000.0)))];
    [_writer appendString:@"}"];

    _measurementCount ++;
}

- (void)writeWithMeasurement:(_RPTMeasurement *)measurement metricIdentifier:(nullable NSString *)metricIdentifier
{
    if(!_writer || (measurement.endTime - measurement.startTime < 0)) return;

    if (_measurementCount > 0)
    {
        [_writer appendString:@","];
    }
    [_writer appendString:@"{"];

    switch (measurement.kind)
    {
        case _RPTMethodMeasurementKind:
            [_writer appendString:_RPTJSONFormatWithStringValue(@"method", measurement.receiver ? [NSString stringWithFormat:@"%@.%@", measurement.receiver, measurement.method] : measurement.method)];
            break;

        case _RPTURLMeasurementKind:
            if ([measurement.receiver isKindOfClass:NSString.class])
            {
                [_writer appendString:_RPTJSONFormatWithStringValue(@"url", (NSString *)measurement.receiver)];
            }
            if (measurement.method.length)
            {
                [_writer appendString:@","];
                [_writer appendString:_RPTJSONFormatWithStringValue(@"verb", measurement.method)];
            }
            break;
            
        case _RPTDeviceMeasurementKind:
            if ([measurement.receiver isKindOfClass:NSString.class])
            {
                [_writer appendString:_RPTJSONFormatWithStringValue(@"device", (NSString *)measurement.receiver)];
            }
            break;

        case _RPTCustomMeasurementKind:
            if ([measurement.receiver isKindOfClass:NSString.class])
            {
                [_writer appendString:_RPTJSONFormatWithStringValue(@"custom", (NSString *)measurement.receiver)];
            }
            break;

        default:
            break;
    }
    if (measurement.screen.length)
    {
        [_writer appendString:@","];
        [_writer appendString:_RPTJSONFormatWithStringValue(@"screen", measurement.screen)];
    }

    if (metricIdentifier.length)
    {
        [_writer appendString:@","];
        [_writer appendString:_RPTJSONFormatWithStringValue(@"metric", metricIdentifier)];
    }

    NSTimeInterval duration = (measurement.endTime - measurement.startTime) * 1000.0;
    [_writer appendString:@","];
    [_writer appendString:_RPTJSONFormatWithUnsignedIntegerValue(@"time", MAX(1ull, (unsigned long long)duration))]; // round to 1ms

    [_writer appendString:@","];
    [_writer appendString:_RPTJSONFormatWithUnsignedIntegerValue(@"start", MAX(0ull, (unsigned long long)(measurement.startTime * 1000.0)))];
    [_writer appendString:@"}"];

    _measurementCount ++;
}

- (void)end
{
    [_writer appendString:@"]}"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_configuration.eventHubURL];
    request.HTTPMethod = @"POST";
    [request setAllHTTPHeaderFields:_configuration.eventHubHTTPHeaderFields];
    NSData *jsonData = [_writer dataUsingEncoding:NSUTF8StringEncoding];
    request.HTTPBody = jsonData;
    
    RPTLog(@"Send measurements to URL %@ : %@", request.URL.absoluteString, _writer);
    
    _writer = nil;
    _measurementCount = 0;

    NSURLResponse *response = nil;
    NSError *error = nil;
    [NSURLConnection sendSynchronousRequest:request
                          returningResponse:&response
                                      error:&error];

    id<RPTEventWriterHandleNetworkResponse> networkResponseDelegate = self.delegate;
    if ([networkResponseDelegate respondsToSelector:@selector(handleURLResponse:error:)])
    {
        [networkResponseDelegate handleURLResponse:response error:error];
    }
}

@end

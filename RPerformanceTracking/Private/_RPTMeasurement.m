#import "_RPTMeasurement.h"

const NSTimeInterval _RPT_MEASUREMENT_MAXTIME = 30.0;

/* RPT_EXPORT */ @implementation _RPTMeasurement
- (instancetype)init
{
    if (self = [super init])
    {
        _endTime = [NSDate.distantPast timeIntervalSinceDate:NSDate.date];
    }
    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wassign-enum"
- (void)clear
{
    _kind               = 0;
    _trackingIdentifier = 0ull;
    _startTime          = 0;
    _endTime            = [NSDate.distantPast timeIntervalSinceDate:NSDate.date];
    _receiver           = nil;
    _method             = nil;
    _screen             = nil;
}
#pragma clang diagnostic pop

- (NSString *)description
{
    return [NSString stringWithFormat:@"Measurement<%p>: kind %lu trackingId %llu startTime %f endTime %f receiver %@ method %@ screen %@", self, (unsigned long)_kind, (unsigned long long)_trackingIdentifier, _startTime, _endTime, _receiver, _method, _screen];
}
@end

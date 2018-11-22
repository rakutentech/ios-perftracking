#import "_RPTHelpers.h"

int64_t _RPTTimeIntervalInMiliseconds(NSTimeInterval timeInterval)
{
    return MAX(0ll, (long long)(timeInterval * 1000));
}

BOOL _RPTNumberToBool(NSNumber *number, BOOL defaultValue)
{
    BOOL result = defaultValue;
    if ([number isKindOfClass:NSNumber.class])  {
        result = [number boolValue];
    }
    return result;
}

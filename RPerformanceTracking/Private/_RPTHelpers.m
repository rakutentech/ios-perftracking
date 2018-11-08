#import "_RPTHelpers.h"

int64_t _RPTTimeIntervalInMiliseconds(NSTimeInterval timeInterval)
{
    return MAX(0ll, (long long)(timeInterval * 1000));
}

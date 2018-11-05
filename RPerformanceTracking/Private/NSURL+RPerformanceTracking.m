#import "NSURL+RPerformanceTracking.h"

@implementation NSURL (RPerformanceTracking)

- (BOOL)isBlacklisted
{
    static NSURL *RATEndPointURL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *RATEndPoint = [NSBundle.mainBundle objectForInfoDictionaryKey:@"RATEndpoint"];
        NSURL *url = [NSURL URLWithString:RATEndPoint];
        RATEndPointURL = url ?: [NSURL URLWithString:@"https://rat.rakuten.co.jp/"];
    });

    if ([self.host isEqualToString:RATEndPointURL.host]) {
        return YES;
    }
    return NO;
}

@end

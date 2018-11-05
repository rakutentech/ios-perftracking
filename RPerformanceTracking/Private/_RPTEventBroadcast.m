#import "_RPTEventBroadcast.h"

@implementation _RPTEventBroadcast

+ (void)sendEventName:(NSString *)name topLevelDataObject:(NSDictionary<NSString *, id> *)object
{
    if (![name isKindOfClass:NSString.class] || !name.length) {
        return;
    }

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"eventName"] = name;

    if ([object isKindOfClass:NSDictionary.class] && object.count) parameters[@"topLevelObject"] = object.copy;

    [NSNotificationCenter.defaultCenter postNotificationName:@"com.rakuten.esd.sdk.events.custom" object:parameters];
}

@end

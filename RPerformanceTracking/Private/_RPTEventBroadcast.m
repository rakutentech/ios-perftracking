#import "_RPTEventBroadcast.h"

@implementation _RPTEventBroadcast

+ (void)sendEventName:(NSString *)name topLevelDataObject:(NSDictionary<NSString *, id> *)object
{
    NSParameterAssert(name);

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"eventName"] = name;

    if ([object isKindOfClass:NSDictionary.class]) parameters[@"topLevelObject"] = object.copy;

    [NSNotificationCenter.defaultCenter postNotificationName:@"com.rakuten.esd.sdk.events.custom" object:parameters];
}

@end

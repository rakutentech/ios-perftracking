#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface _RPTEventBroadcast : NSObject

+ (void)sendEventName:(NSString *)name topLevelDataObject:(NSDictionary<NSString *, id> *)object;

@end

NS_ASSUME_NONNULL_END

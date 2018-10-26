#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN

RPT_EXPORT @interface _RPTClassManipulator : NSObject
+ (void)swizzleSelector:(SEL)sel onClass:(Class)recipient newImplementation:(IMP)newImp types:(const char *)types;

+ (_Nullable IMP)implementationForOriginalSelector:(SEL)selector class:(Class)className;

+ (void)setupDeferredSwizzles;
@end

NS_ASSUME_NONNULL_END

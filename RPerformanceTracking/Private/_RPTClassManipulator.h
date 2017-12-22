#import <RPerformanceTracking/RPTDefines.h>

NS_ASSUME_NONNULL_BEGIN

RPT_EXPORT @interface _RPTClassManipulator : NSObject
/*
 * Add a new method to a class, optionally replacing an existing one.
 *
 * @param sender            Sender class
 * @param newSelector       Selector of the current class' method to add to the recipient class.
 * @param recipient         Recipient class
 * @param originalSelector  Selector naming the method on the recipient class. If the selector already
 *                          exists, that original method will be swapped for the new one.
 * @param onlyIfPresent     If `originalSelector` is not found on the recipient class, the method does
 *                          nothing and returns `NO`.
 * @return Whether or not the method was added to the recipient class.
 */
+ (BOOL)addMethodFromClass:(Class)sender
              withSelector:(SEL)newSelector
                   toClass:(Class)recipient
                 replacing:(SEL)originalSelector
             onlyIfPresent:(BOOL)onlyIfPresent;

/*
 * Add the newSelector and its method of the sender class to the recipient class, we don't want to change the implementation of the method in the sender, because it might be used for other classes (For example, 2 WKWebViews with different delegate's classes).
 * Change the implementation of newMethod and original method in recipient class.
 *
 * @param sender            Sender class
 * @param newSelector       Selector of the sender class' method to add to the recipient class.
 * @param recipient         Recipient class
 * @param originalSelector  Selector naming the method on the recipient class. If the selector already
 *                          exists, that original method will be swapped for the new one.
 * @param onlyIfPresent     If `originalSelector` is not found on the recipient class, the method does
 *                          nothing and returns `NO`.
 * @return Whether or not the method was added to the recipient class.
 */
+ (BOOL)swizzleMethodFromClass:(Class)sender
                  withSelector:(SEL)newSelector
                       toClass:(Class)recipient
                     replacing:(SEL)originalSelector
                 onlyIfPresent:(BOOL)onlyIfPresent;

// FIXME: the methods above that use selector IMP swapping should be deprecated/removed after
// all the swizzling setup calls are changed to use the below selector preserving method (which
// makes us compatible with 3rd party SDK swizzlers e.g. New Relic)
+ (void)swizzleSelector:(SEL)sel onClass:(Class)recipient newImplementation:(IMP)newImp types:(const char *)types;

+ (IMP)implementationForOriginalSelector:(SEL)selector class:(Class)className;
@end

NS_ASSUME_NONNULL_END

#import <objc/runtime.h>
#import "_RPTClassManipulator.h"

@interface SwizzleDetail : NSObject
@property (nonatomic, readonly, copy) NSString *className;
@property (nonatomic, readonly)       NSValue  *originalImplementation;

+ (instancetype)swizzleDetailWithClass:(NSString *)className implementation:(IMP)imp;
@end

@implementation SwizzleDetail
- (instancetype)initWithClass:(NSString *)className implementation:(IMP)imp
{
    if (self = [super init])
    {
        _className = className;
        _originalImplementation = [NSValue valueWithPointer:imp];
    }
    return self;
}

+ (instancetype)swizzleDetailWithClass:(NSString *)className implementation:(IMP)imp
{
    return className ? [self.alloc initWithClass:className implementation:imp] : nil;
}
@end

// Map of selectors to objects containing the class name and original implementation (or
// pointer-to-NULL if there wasn't an original)
typedef NSMutableDictionary<NSString *, SwizzleDetail *> swizzleMappingDictionary;

@interface _RPTClassManipulator ()
@property (class, nonatomic) swizzleMappingDictionary *swizzleMap;
@end

@implementation _RPTClassManipulator
static swizzleMappingDictionary *_swizzleMap = nil;

+ (swizzleMappingDictionary *)swizzleMap
{
    return _swizzleMap;
}

+ (void)setSwizzleMap:(swizzleMappingDictionary *)newSwizzleMap
{
    _swizzleMap = newSwizzleMap;
}

+ (void)load
{
    if (!self.swizzleMap) _swizzleMap = NSMutableDictionary.new;
}

+ (BOOL)addMethodFromClass:(Class)sender
              withSelector:(SEL)newSelector
                   toClass:(Class)recipient
                 replacing:(SEL)originalSelector
             onlyIfPresent:(BOOL)onlyIfPresent
{
    NSParameterAssert(newSelector);
    NSParameterAssert(originalSelector);
    if (!recipient) return NO;

    Method newMethod      = class_getInstanceMethod(sender,    newSelector);
    Method originalMethod = class_getInstanceMethod(recipient, originalSelector);
    SEL resultSelector    = originalSelector;

    /*
     * If the target method exists, we exchange its implementation with our new one and
     * update originalSelector to still point to the original implementation.
     */
    if (originalMethod)
    {
        method_exchangeImplementations(newMethod, originalMethod);
        resultSelector = newSelector;
    }
    /*
     * If the target method doesn't exist but was required, we don't do anything.
     */
    else if (onlyIfPresent)
    {
        return NO;
    }

    /*
     * If at this point no method exists for the selector, it means that either:
     * - The original method didn't exist, so we need to add the new method in its place; or
     * - The original method was replaced, so we need to add back its original implementation (that now
     *   uses what was passed as `newSelector`).
     */
    if (!class_getInstanceMethod(recipient, resultSelector))
    {
        class_addMethod(recipient,
                        resultSelector,
                        method_getImplementation(newMethod),
                        method_getTypeEncoding(newMethod));
    }

    return YES;
}

+ (BOOL)swizzleMethodFromClass:(Class)sender
                  withSelector:(SEL)newSelector
                       toClass:(Class)recipient
                     replacing:(SEL)originalSelector
                 onlyIfPresent:(BOOL)onlyIfPresent
{
    NSParameterAssert(newSelector);
    NSParameterAssert(originalSelector);
    if (!recipient) return NO;

    Method newMethod      = class_getInstanceMethod(sender,    newSelector);
    Method originalMethod = class_getInstanceMethod(recipient, originalSelector);
    IMP newImp            = method_getImplementation(newMethod);

    /*
     * If the originalMethod doesn't exist
     */
    if (!originalMethod)
    {
        /*
         * Don't add if not present.
         */
        if (onlyIfPresent)
        {
            return NO;
        }

        /*
         * Add the newMethod to the originalSelector in recipient class
         */
        class_addMethod(recipient,
                        originalSelector,
                        method_getImplementation(newMethod),
                        method_getTypeEncoding(newMethod));
    }
    else
    {
        IMP originalImp = method_getImplementation(originalMethod);

        /*
         * If originalMethod exists and the implementation of the originalMethod is same to the implementation of the newMethod,
         * it means that the originalMethod has already been added or swizzled, so do nothing.
         * Otherwise, we need to add the newMethod with the newSelector to the recipient class and exchange the implementation of them.
         */
        if (originalImp != newImp)
        {
            if (!class_respondsToSelector(recipient, newSelector))
            {
                class_addMethod(recipient,
                                newSelector,
                                method_getImplementation(newMethod),
                                method_getTypeEncoding(newMethod));
            }
            Method newMethodInRecipient = class_getInstanceMethod(recipient, newSelector);

            if (originalMethod && newMethodInRecipient)
            {
                method_exchangeImplementations(newMethodInRecipient, originalMethod);
            }
        }
    }
    
    return YES;
}

+ (void)swizzleSelector:(SEL)sel onClass:(Class)recipient newImplementation:(IMP)newImp types:(const char *)types
{
    if (!sel || !recipient || !newImp || !types)
    {
        return;
    }
    
    if ([[_RPTClassManipulator _classNameForSelector:sel class:recipient] isEqualToString:NSStringFromClass(recipient)])
    {
        // Same selector and recipient - already swizzled
        return;
    }
    
    Method m = class_getInstanceMethod(recipient, sel);
    IMP originalImplementation = NULL;
    
    if (m)
    {
        originalImplementation = method_setImplementation(m, newImp);
    }
    else
    {
        // add method, there's no original implementation
        class_addMethod(recipient, sel, newImp, types);
    }
    [self _addSelectorMapping:sel class:recipient implementation:originalImplementation];
}

+ (IMP)implementationForOriginalSelector:(SEL)selector class:(Class)classObj
{
    NSString *key = [self _keyForSelector:selector class:classObj];
    SwizzleDetail *swizzleDetail = _swizzleMap[key];
    return [swizzleDetail.originalImplementation pointerValue];
}

+ (void)_addSelectorMapping:(SEL)selector class:(Class)classObj implementation:(__nullable IMP)implementation
{
    SwizzleDetail *swizzleDetail = [SwizzleDetail swizzleDetailWithClass:NSStringFromClass(classObj) implementation:implementation];
    if (swizzleDetail)
    {
        NSString *key = [self _keyForSelector:selector class:classObj];
        _swizzleMap[key] = swizzleDetail;
    }
}

+ (NSString *)_classNameForSelector:(SEL)selector class:(Class)classObj
{
    NSString *key = [self _keyForSelector:selector class:classObj];
    SwizzleDetail *swizzleDetail = _swizzleMap[key];
    if (swizzleDetail)
    {
        return swizzleDetail.className;
    }
    return nil;
}

+ (NSString *)_keyForSelector:(SEL)selector class:(Class)classObj
{
    return (selector && classObj) ? [NSString stringWithFormat:@"%@-%@", NSStringFromSelector(selector), NSStringFromClass(classObj)] : nil;
}

@end

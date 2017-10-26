#import <objc/runtime.h>
#import "_RPTClassManipulator.h"

@implementation _RPTClassManipulator
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
@end

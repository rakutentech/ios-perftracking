#if DEBUG
#   define RPTLog(...) NSLog(@"[Performance Tracking] %@", ([NSString stringWithFormat:__VA_ARGS__]))

//#   define RPTLogVerbose(...) RPTLog(__VA_ARGS__)
#   define RPTLogVerbose(...) do { } while(0)
#else
#   define RPTLog(...) do { } while(0)

#   define RPTLogVerbose(...) do { } while(0)
#endif

NS_INLINE int64_t _RPTTimeIntervalInMiliseconds(NSTimeInterval timeInterval)
{
    return MAX(0ll, (long long)(timeInterval * 1000));
}

NS_INLINE BOOL _RPTNumberToBool(NSNumber *number, BOOL defaultValue)
{
    BOOL result = defaultValue;
    if ([number isKindOfClass:NSNumber.class]) {
        result = [number boolValue];
    }
    return result;
}

NS_INLINE BOOL boolForInfoPlistKey(NSString *key)
{
    return [[NSBundle.mainBundle objectForInfoDictionaryKey:key] boolValue];
}



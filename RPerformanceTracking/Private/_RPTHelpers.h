#if DEBUG
#   define RPTLog(...) NSLog(@"[Performance Tracking] %@", ([NSString stringWithFormat:__VA_ARGS__]))
#else
#   define RPTLog(...) do { } while(0)
#endif


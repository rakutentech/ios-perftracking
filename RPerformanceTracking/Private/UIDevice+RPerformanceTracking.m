#import "UIDevice+RPerformanceTracking.h"
#import <mach/mach.h>

@implementation UIDevice (RPerformanceTracking)

- (int64_t)freeDeviceMemory
{
    vm_size_t pagesize;

    mach_port_t host_port = mach_host_self();
    mach_msg_type_number_t host_size = HOST_VM_INFO64_COUNT;
    host_page_size(host_port, &pagesize);

    vm_statistics64_data_t vmstat;

    if (host_statistics64(host_port, HOST_VM_INFO64, (host_info64_t)&vmstat, &host_size) != KERN_SUCCESS)
        return -1;

    uint64_t free_mem_in_bytes = vmstat.free_count * pagesize;
    return (long long)(free_mem_in_bytes / (1024 * 1024));
}

- (int64_t)totalDeviceMemory
{
    uint64_t total_mem_in_bytes = [NSProcessInfo processInfo].physicalMemory;
    return (long long)(total_mem_in_bytes / (1024 * 1024));
}

- (int64_t)usedAppMemory
{
    struct mach_task_basic_info info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) != KERN_SUCCESS)
        return -1;
    return (long long)(info.resident_size / (1024 * 1024));
}

@end

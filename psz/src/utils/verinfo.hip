// HIP version of device info utilities
// Replaces verinfo.cu and verinfo_nv.cu for HIP backend

#include <hip/hip_runtime.h>

#include <cstdio>
#include <iostream>

#include "utils/verinfo.h"

// Forward declarations
static void print_HIPCC_ver();
static int print_AMD_driver();
static void HIP_devices_impl();

// Aliases to match CUDA function names used in context.cc
void print_NVCC_ver() { print_HIPCC_ver(); }
int print_CUDA_driver() { return print_AMD_driver(); }
int print_NVIDIA_driver() { return 0; }  // no-op for HIP
void CUDA_devices() { HIP_devices_impl(); }

static void print_HIPCC_ver()
{
#if defined(__HIP_DEVICE_COMPILE__)
  // This is executed during device compilation
#else
  printf(
      "- hipcc: HIP %d.%d\n",
      HIP_VERSION_MAJOR,
      HIP_VERSION_MINOR);
#endif
}

static int print_AMD_driver()
{
  int driver_version = 0;
  auto result = hipDriverGetVersion(&driver_version);

  std::cout << "- ROCm/HIP driver: ";

  if (result != hipSuccess) {
    std::cerr << "(failed to get driver version: " << hipGetErrorString(result) << ")" << std::endl;
    return 1;
  }

  int major_version = driver_version / 10000000;
  int minor_version = (driver_version / 100000) % 100;
  std::cout << major_version << "." << minor_version << std::endl;

  return 0;
}

static void HIP_devices_impl()
{
  int device_count = 0;
  hipGetDeviceCount(&device_count);

  if (device_count == 0) {
    printf("0 devices detected\n");
  }
  else {
    printf("%d HIP/AMD device(s):\n", device_count);
  }

  for (auto dev = 0; dev < device_count; ++dev) {
    hipSetDevice(dev);
    hipDeviceProp_t deviceProp;
    hipGetDeviceProperties(&deviceProp, dev);

    auto membw_GiBps = membw_base1024(deviceProp.memoryBusWidth, deviceProp.memoryClockRate * 1e3);
    auto membw_GBps  = membw_base1000(deviceProp.memoryBusWidth, deviceProp.memoryClockRate * 1e3);

    printf("- %s (gcnArchName: %s)\n", deviceProp.name, deviceProp.gcnArchName);
    printf(
        "  - %d compute units; wavefront size: %d\n",
        deviceProp.multiProcessorCount, deviceProp.warpSize);
    printf(
        "  - global VRAM: %.0f MB (theoretically) at \n",
        (float)deviceProp.totalGlobalMem / 1048576.0f);
    printf(
        "    %.1f GiB/s (base-1024) or %.1f GB/s (base-1000)\n", membw_GiBps,
        membw_GBps);
    printf("  - L2 cache: %d bytes\n", deviceProp.l2CacheSize);
    printf(
        "  - per-block/CU total shared memory: %zu/%zu bytes\n",
        deviceProp.sharedMemPerBlock, deviceProp.maxSharedMemoryPerMultiProcessor);
    printf(
        "  - per-block/CU max thread count: %d/%d\n",
        deviceProp.maxThreadsPerBlock, deviceProp.maxThreadsPerMultiProcessor);
    printf(
        "  - max thread-block dim (x,y,z): (%d, %d, %d)\n",
        deviceProp.maxThreadsDim[0], deviceProp.maxThreadsDim[1],
        deviceProp.maxThreadsDim[2]);
    printf(
        "  - per-block total registers count: %d\n", deviceProp.regsPerBlock);
  }
}

/**
 * @file test_mem_unique.hip
 * @author Jeff Daily <jeff.daily@amd.com>
 * @brief HIP/ROCm port of the unique-memory-object test.
 *
 * Copyright (c) 2026 Advanced Micro Devices, Inc.
 *
 */

#include <hip/hip_runtime.h>

#include <cassert>
#include <iostream>

#include "mem/cxx_backends.h"  // Assuming this is your provided file

constexpr size_t len = 1024;
constexpr float scalar = 5.0f;
constexpr size_t bytes = len * sizeof(float);

constexpr dim3 block(256);
constexpr dim3 grid((len - 1) / block.x + 1);

__global__ void add_scalar(float* arr, size_t len, float scalar)
{
  auto idx = blockIdx.x * blockDim.x + threadIdx.x;
  if (idx < len) {
    arr[idx] += scalar;
    // printf("arr[%d] = %f\n", idx, arr[idx]);
  }
}

int test_hip_unique_ptr()
{
  /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

  float* d_array_native = nullptr;
  float* h_array_native = new float[len];

  hipMalloc(&d_array_native, bytes);
  hipMemset(d_array_native, 0, bytes);

  add_scalar<<<grid, block>>>(d_array_native, len, scalar);
  hipDeviceSynchronize();

  hipMemcpy(h_array_native, d_array_native, bytes, hipMemcpyDeviceToHost);

  /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

  auto d_array_smart = GPU_make_unique(malloc_d<float>(len), GPU_DELETER_D());
  auto h_array_smart = GPU_make_unique(malloc_h<float>(len), GPU_DELETER_H());

  add_scalar<<<grid, block>>>(d_array_smart.get(), len, scalar);
  hipDeviceSynchronize();

  memcpy_allkinds<D2H>(h_array_smart.get(), d_array_smart.get(), len);

  /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

  bool success = true;
  for (size_t i = 0; i < len; i++) {
    if (h_array_native[i] != h_array_smart[i]) {
      success = false;
      printf(
          "(native[%lu] = %f) != (smart[%lu] = %f)\n", i, h_array_native[i], i, h_array_smart[i]);
      break;
    }
  }

  /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

  hipFree(d_array_native);
  delete[] h_array_native;

  /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

  if (success) {
    std::cout << "passed: GPU_unique_ptr matches native impl." << std::endl;
    return 0;
  }
  else {
    std::cerr << "FAILED: results mismatch." << std::endl;
    return 1;
  }

  /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
}

int main() { return test_hip_unique_ptr(); }

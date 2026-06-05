#include <hip/hip_runtime.h>
#include "macro/c_cu2hip_1_fix_primitives.h"
#include <thrust/equal.h>
#include <thrust/execution_policy.h>

#include "cusz/type.h"
#include "detail/compare.hh"

bool psz::thrustgpu::GPU_identical(
    void* d1, void* d2, size_t sizeof_T, size_t const len, void* stream)
{
  // Note: stream parameter is unused in thrust implementation
  (void)stream;
  return thrust::equal(
      thrust::device, (u1*)d1, (u1*)d1 + sizeof_T * len, (u1*)d2);
}

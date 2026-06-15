/**
 * @file extrema.hip.inl
 * @author Jeff Daily <jeff.daily@amd.com>
 * @brief HIP/ROCm port of the extrema statistics kernels.
 *
 * Copyright (c) 2026 Advanced Micro Devices, Inc.
 *
 */

#include <hip/hip_runtime.h>
#include "macro/c_cu2hip_0_translation.h"

#include <cmath>
#include <cstdio>
#include <type_traits>

#include "cusz/type.h"
#include "detail/compare.hh"
#include "utils/err.hh"

namespace psz {

namespace {

template <int bytewidth>
struct matchby;
template <>
struct matchby<4> {
  using utype = unsigned int;
  using itype = int;
  using ftype = float;
};
template <>
struct matchby<8> {
  using utype = unsigned long long;
  using itype = long long;
  using ftype = double;
};

#define __ATOMIC_PLUGIN                                                                 \
  constexpr auto bytewidth = sizeof(T);                                                 \
  using itype = typename matchby<bytewidth>::itype;                                     \
  using utype = typename matchby<bytewidth>::utype;                                     \
  using ftype = typename matchby<bytewidth>::ftype;                                     \
  static_assert(std::is_same<T, ftype>::value, "T and ftype don't match.");             \
  auto fp_as_int = [](T fpval) -> itype { return *reinterpret_cast<itype*>(&fpval); };  \
  auto fp_as_uint = [](T fpval) -> utype { return *reinterpret_cast<utype*>(&fpval); }; \
  auto int_as_fp = [](itype ival) -> T { return *reinterpret_cast<T*>(&ival); };        \
  auto uint_as_fp = [](utype uval) -> T { return *reinterpret_cast<T*>(&uval); };

// modifed from https://stackoverflow.com/a/51549250 (CC BY-SA 4.0)
// https://stackoverflow.com/a/72461459
template <typename T>
__device__ __forceinline__ T atomicMinFp(T* addr, T value)
{
  __ATOMIC_PLUGIN
  auto old = !signbit(value) ? int_as_fp(atomicMin((itype*)addr, fp_as_int(value)))
                             : uint_as_fp(atomicMax((utype*)addr, fp_as_uint(value)));
  return old;
}

template <typename T>
__device__ __forceinline__ T atomicMaxFp(T* addr, T value)
{
  __ATOMIC_PLUGIN
  auto old = !signbit(value) ? int_as_fp(atomicMax((itype*)addr, fp_as_int(value)))
                             : uint_as_fp(atomicMin((utype*)addr, fp_as_uint(value)));
  return old;
}

template <typename T>
__device__ __forceinline__ T atomicAddFp(T* addr, T value)
{
  // HIP supports atomicAdd for float natively, and for double via unsafeAtomicAdd
  if constexpr (std::is_same<T, float>::value) {
    return atomicAdd(addr, value);
  }
  else if constexpr (std::is_same<T, double>::value) {
    return unsafeAtomicAdd(addr, value);
  }
  else {
    return atomicAdd(addr, value);
  }
}

}  // namespace

template <typename T>
__global__ void KERNEL_CUHIP_extrema(
    T* in, size_t const len, T* minel, T* maxel, T* sum, T const failsafe, int const R)
{
  __shared__ T shared_minv, shared_maxv, shared_sum;
  // failsafe; require external setup
  T tp_minv{failsafe}, tp_maxv{failsafe}, tp_sum{0};

  auto _entry = [&]() { return (blockDim.x * R) * blockIdx.x + threadIdx.x; };
  auto _idx = [&](auto r) { return _entry() + (r * blockDim.x); };

  if (threadIdx.x == 0) shared_minv = failsafe, shared_maxv = failsafe, shared_sum = 0;

  __syncthreads();

  for (auto r = 0; r < R; r++) {
    auto idx = _idx(r);
    if (idx < len) {
      auto val = in[idx];

      tp_minv = min(tp_minv, val);
      tp_maxv = max(tp_maxv, val);
      tp_sum += val;
    }
  }
  __syncthreads();

  constexpr auto is_FP = std::is_floating_point<T>::value;
  constexpr auto is_INT = std::is_integral<T>::value;

  if constexpr (is_FP) {
    atomicMinFp<T>(&shared_minv, tp_minv);
    atomicMaxFp<T>(&shared_maxv, tp_maxv);
    atomicAddFp<T>(&shared_sum, tp_sum);
    __syncthreads();

    if (threadIdx.x == 0) {
      atomicMinFp<T>(minel, shared_minv);
      atomicMaxFp<T>(maxel, shared_maxv);
      atomicAddFp<T>(sum, shared_sum);
    }
  }
  else if constexpr (is_INT) {
    atomicMin(&shared_minv, tp_minv);
    atomicMax(&shared_maxv, tp_maxv);
    atomicAdd(&shared_sum, tp_sum);
    __syncthreads();

    if (threadIdx.x == 0) {
      atomicMin(minel, shared_minv);
      atomicMax(maxel, shared_maxv);
      atomicAdd(sum, shared_sum);
    }
  }
  else
    static_assert(is_FP || is_INT, "T must be either floating point or integer.");
}

}  // namespace psz

namespace psz::module {

template <typename T>
void GPU_extrema(T* in, size_t len, T res[4])
{
  static const int MINVAL = 0;
  static const int MAXVAL = 1;
  static const int AVGVAL = 2;
  static const int RNG = 3;

  // TODO use external stream
  hipStream_t stream;
  hipStreamCreate(&stream);

  auto div = [](auto _l, auto _subl) { return (_l - 1) / _subl + 1; };

  auto chunk = 32768;
  auto nworker = 128;
  auto R = chunk / nworker;

  T h_min, h_max, h_sum, failsafe;
  T *d_minel, *d_maxel, *d_sum;

  CHECK_GPU(hipMalloc(&d_minel, sizeof(T)));
  CHECK_GPU(hipMalloc(&d_maxel, sizeof(T)));
  CHECK_GPU(hipMalloc(&d_sum, sizeof(T)));
  hipMemset(d_sum, 0, sizeof(T));

  // failsafe init
  CHECK_GPU(hipMemcpy(&failsafe, in, sizeof(T), hipMemcpyDeviceToHost));  // transfer the 1st val
  CHECK_GPU(hipMemcpy(d_minel, in, sizeof(T), hipMemcpyDeviceToDevice));  // init min el
  CHECK_GPU(hipMemcpy(d_maxel, in, sizeof(T), hipMemcpyDeviceToDevice));  // init max el

  // launch
  psz::KERNEL_CUHIP_extrema<T><<<div(len, chunk), nworker, sizeof(T) * 2, stream>>>(
      in, len, d_minel, d_maxel, d_sum, failsafe, R);

  hipStreamSynchronize(stream);

  // collect results
  CHECK_GPU(hipMemcpy(&h_min, d_minel, sizeof(T), hipMemcpyDeviceToHost));
  CHECK_GPU(hipMemcpy(&h_max, d_maxel, sizeof(T), hipMemcpyDeviceToHost));
  CHECK_GPU(hipMemcpy(&h_sum, d_sum, sizeof(T), hipMemcpyDeviceToHost));

  res[MINVAL] = h_min;
  res[MAXVAL] = h_max;
  res[AVGVAL] = h_sum / len;
  res[RNG] = h_max - h_min;

  CHECK_GPU(hipFree(d_minel));
  CHECK_GPU(hipFree(d_maxel));
  CHECK_GPU(hipFree(d_sum));

  hipStreamDestroy(stream);
}

}  // namespace psz::module

#define __INSTANTIATE_CUHIP_EXTREMA(T) \
  template void psz::module::GPU_extrema<T>(T * in, size_t len, T res[4]);

#include <hip/hip_runtime.h>
#include "detail/port.hh"
#include "utils/viewer.hh"
#include "viewer.cuhip.inl"

#define __INSTANTIATE_CUHIP_VIEWER(T, P) \
  template void psz::analysis::GPU_evaluate_quality_and_print<T, P>(T*, T*, size_t, size_t);

// ROCM runtime instantiations
__INSTANTIATE_CUHIP_VIEWER(float, PROPER_RUNTIME)
__INSTANTIATE_CUHIP_VIEWER(double, PROPER_RUNTIME)
// Also instantiate with CUDA enum for backwards compatibility (the CLI uses the default)
__INSTANTIATE_CUHIP_VIEWER(float, CUDA)
__INSTANTIATE_CUHIP_VIEWER(double, CUDA)

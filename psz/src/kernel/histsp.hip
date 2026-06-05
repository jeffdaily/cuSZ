#include <hip/hip_runtime.h>
#include "macro/c_cu2hip_1_fix_primitives.h"
#include "detail/histsp.cuhip.inl"

template struct psz::module::GPU_histogram_Cauchy<u1>;
template struct psz::module::GPU_histogram_Cauchy<u2>;
template struct psz::module::GPU_histogram_Cauchy<u4>;
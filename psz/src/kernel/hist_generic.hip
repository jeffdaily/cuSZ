#include <hip/hip_runtime.h>
#include "macro/c_cu2hip_0_translation.h"
#include "macro/c_cu2hip_1_fix_primitives.h"
#include "detail/hist.cuhip.inl"

template struct psz::module::GPU_histogram_generic<u1>;
template struct psz::module::GPU_histogram_generic<u2>;
template struct psz::module::GPU_histogram_generic<u4>;

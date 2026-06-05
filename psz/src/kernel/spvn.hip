#include <hip/hip_runtime.h>
#include "macro/c_cu2hip_0_translation.h"
#include "macro/c_cu2hip_1_fix_primitives.h"
#include "c_type.h"
#include "detail/spvn.cuhip.inl"
#include "kernel/spvn.hh"

template struct psz::module::GPU_scatter<f4, u4>;
template struct psz::module::GPU_scatter<f8, u4>;
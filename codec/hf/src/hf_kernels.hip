// TODO put u? in hf path
#include <hip/hip_runtime.h>
#include "macro/c_cu2hip_0_translation.h"
#include "macro/c_cu2hip_1_fix_primitives.h"
#include "hf_kernels.cuhip.inl"

namespace phf::cuhip {

template class modules<u1, u4>;
template class modules<u2, u4>;
template class modules<u4, u4>;

}  // namespace phf::cuhip

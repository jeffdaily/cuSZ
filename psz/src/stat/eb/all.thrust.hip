#include <hip/hip_runtime.h>
#include "macro/c_cu2hip_1_fix_primitives.h"
#include "../detail/ebness.thrust.inl"
__INSTANTIATE_THRUST_EB(float);
__INSTANTIATE_THRUST_EB(double);
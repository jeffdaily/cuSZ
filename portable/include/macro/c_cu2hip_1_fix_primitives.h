// clang-format off

// Warp shuffle intrinsics: HIP does not use the _sync suffix.
// Use variadic macros to support both 3-arg and 4-arg forms (WIDTH is optional).
#define __shfl_sync(MASK, VAR, SRC_LANE, ...) __shfl(VAR, SRC_LANE, ##__VA_ARGS__)
#define __shfl_up_sync(MASK, VAR, DELTA, ...) __shfl_up(VAR, DELTA, ##__VA_ARGS__)
#define __shfl_down_sync(MASK, VAR, DELTA, ...) __shfl_down(VAR, DELTA, ##__VA_ARGS__)
#define __shfl_xor_sync(MASK, VAR, LANE_MASK, ...) __shfl_xor(VAR, LANE_MASK, ##__VA_ARGS__)

// Ballot intrinsic: HIP __ballot returns unsigned long long on wave64.
// The code uses width-32 logical warp operations which work on wave64
// (they operate within a 32-lane subgroup). We truncate to 32-bit to
// match CUDA's uint32_t return type.
#define __ballot_sync(MASK, PRED) ((unsigned int)__ballot(PRED))

// Population count: HIP uses the same intrinsic name as CUDA
// No translation needed for __popc

// clang-format on
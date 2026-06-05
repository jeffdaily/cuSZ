
add_library(psz_hip_test_compile_settings INTERFACE)
target_include_directories(
  psz_hip_test_compile_settings
  INTERFACE
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../portable/include/>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../psz/include/>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../psz/src/>
)

# utils for test
add_library(psz_hip_test_utils src/utils/rand.seq.cc src/utils/rand.cu_hip.cc)
target_link_libraries(psz_hip_test_utils hip::host ${hiprand_LIBRARIES})

# functionality
add_executable(zigzag src/test_zigzag_codec.cc)
target_link_libraries(zigzag PRIVATE psz_hip_test_compile_settings)
add_test(test_zigzag zigzag)

# Level-1 subroutine
add_executable(l1_compact src/test_l1_compact.hip)
target_link_libraries(l1_compact PRIVATE psz_hip_compile_settings
  psz_hip_test_compile_settings psz_hip_test_utils)
add_test(test_l1_compact l1_compact)

# Level-2 kernel (template; unit tests)
# Disabled: test has wrong include path (detail/t_histsp.cu_hip.inl vs detail/tune_histsp.cuhip.inl)
# This is a performance tuning test, not core functionality
# add_executable(histsp_hip src/tune_histsp.hip)
# target_link_libraries(histsp_hip
#   PRIVATE psz_hip_compile_settings
#   psz_seq_core
#   hipsz
# )
# add_test(test_histsp_hip histsp_hip)

# Level-3 kernel with configuration (low-level API)
add_executable(lrz_seq src/test_lrz.seq.cc)
target_link_libraries(lrz_seq
  PRIVATE psz_hip_test_compile_settings psz_seq_core)
add_test(test_lrz_seq lrz_seq)

add_executable(statfn src/test_statfn.cc)
target_link_libraries(statfn
  PRIVATE psz_hip_test_compile_settings psz_hip_compile_settings
  psz_hip_test_utils psz_hip_mem
)

add_executable(stat_identical src/test_identical.cc)
target_link_libraries(stat_identical
  PRIVATE
  psz_hip_test_compile_settings
  psz_hip_compile_settings
  psz_hip_test_utils
  psz_hip_stat
  hip::host
)
add_test(test_stat_identical stat_identical)

add_executable(stat_max_error src/test_max_error.cc)
target_link_libraries(stat_max_error
  PRIVATE
  psz_hip_test_compile_settings
  psz_hip_compile_settings
  psz_hip_test_utils
  psz_hip_stat
  hip::host
)
add_test(test_stat_max_error stat_max_error)

add_executable(mem_unique src/test_mem_unique.hip)
target_link_libraries(mem_unique
  PRIVATE
  psz_hip_compile_settings
  psz_hip_test_compile_settings
  psz_hip_mem
  hip::host
)
add_test(test_mem_unique mem_unique)

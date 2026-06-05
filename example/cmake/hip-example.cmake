add_library(example_utils2_hip src/ex_utils2.cc)
target_link_libraries(example_utils2_hip PRIVATE hipsz)

add_executable(demo_hip_v1 src/demo_v1.hip.cc)
target_link_libraries(demo_hip_v1 PRIVATE hipsz)

add_executable(demo_hip_v2 src/demo_v2.hip.cc)
target_link_libraries(demo_hip_v2 PRIVATE hipsz)

add_executable(bin_hf src/bin_phf.cc)
target_link_libraries(bin_hf PRIVATE hipsz hip::host)

add_executable(bin_hist src/bin_hist.cc)
target_link_libraries(bin_hist PRIVATE hipsz hip::host)

add_executable(batch_run src/batch_run.cc)
target_link_libraries(batch_run PRIVATE hipsz example_utils2_hip hip::host)

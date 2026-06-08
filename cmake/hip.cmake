# ------------------------------------------------------------------------------
# Source code switches
# ------------------------------------------------------------------------------

add_compile_definitions(
  PSZ_USE_HIP
  _PORTABLE_USE_HIP
)

find_package(hip REQUIRED)
find_package(rocthrust REQUIRED)
find_package(rocprim REQUIRED)
find_package(hiprand REQUIRED)
find_package(rocrand REQUIRED)

message("[psz::info] rocthrust_INCLUDE_DIRS: ${rocthrust_INCLUDE_DIRS}")
message("[psz::info] rocprim_INCLUDE_DIRS: ${rocprim_INCLUDE_DIRS}")
message("[psz::info] hiprand_INCLUDE_DIRS: ${hiprand_INCLUDE_DIRS}")
message("[psz::info] rocrand_INCLUDE_DIRS: ${rocrand_INCLUDE_DIRS}")

include(GNUInstallDirs)
include(CTest)

configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/psz/src/cusz_version.h.in"
  "${CMAKE_CURRENT_BINARY_DIR}/psz/include/cusz_version.h"
  @ONLY
)

# ------------------------------------------------------------------------------
# Common compile settings (interface target)
# ------------------------------------------------------------------------------

add_library(psz_hip_compile_settings INTERFACE)

target_compile_features(psz_hip_compile_settings
  INTERFACE
    cxx_std_17
)

target_compile_definitions(psz_hip_compile_settings
  INTERFACE
    $<$<COMPILE_LANG_AND_ID:HIP,Clang>:__STRICT_ANSI__>
    __HIP_PLATFORM_AMD__
    # On Windows (ROCm/TheRock 7.14), amd_hip_bf16.h redefines __shfl_*_sync
    # overloads that conflict with the template definitions already pulled in
    # by amd_warp_sync_functions.h, causing "redefinition of default argument"
    # errors when compiling thrust-based .hip files. Suppress those bf16 sync
    # overloads; the cu2hip macros provide __shfl_*_sync via __shfl_* instead.
    $<$<BOOL:${WIN32}>:HIP_DISABLE_WARP_SYNC_BUILTINS>
)

target_compile_options(psz_hip_compile_settings
  INTERFACE
    $<$<COMPILE_LANGUAGE:HIP>:-Wno-deprecated-declarations>
)

target_include_directories(psz_hip_compile_settings
  INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/psz/src>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/psz/include>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/psz/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/cusz>
)

# ------------------------------------------------------------------------------
# Dependencies (installed or fallback)
# ------------------------------------------------------------------------------

find_package(PORTABLE QUIET)
if(NOT TARGET PORTABLE::PORTABLE AND NOT TARGET PORTABLE)
  add_subdirectory(portable)
endif()

# Normalize PORTABLE target name
set(_PORTABLE_TARGET "")
if(TARGET PORTABLE::PORTABLE)
  set(_PORTABLE_TARGET PORTABLE::PORTABLE)
elseif(TARGET PORTABLE)
  set(_PORTABLE_TARGET PORTABLE)
else()
  message(FATAL_ERROR
    "PORTABLE target not available. Provide PORTABLE or add the portable subdirectory."
  )
endif()

# Back-compat alias used throughout this project
if(NOT TARGET DEPS::deps)
  add_library(DEPS::deps ALIAS "${_PORTABLE_TARGET}")
endif()

target_link_libraries(psz_hip_compile_settings
  INTERFACE
    DEPS::deps
)

find_package(FZG QUIET)
if(NOT TARGET FZG::fzg_hip AND NOT FZG_FOUND)
  add_subdirectory(codec/fzg)
endif()

find_package(PHF QUIET)
if(NOT TARGET PHF::phf_hip AND NOT PHF_FOUND)
  add_subdirectory(codec/hf)
endif()

# ------------------------------------------------------------------------------
# Libraries
# ------------------------------------------------------------------------------

add_library(psz_hip_stat
  psz/src/stat/compare.stl.cc
  psz/src/stat/identical/all.hip
  psz/src/stat/identical/all.thrust.hip
  psz/src/stat/extrema/f4.hip
  psz/src/stat/extrema/f8.hip
  psz/src/stat/extrema/f4.thrust.hip
  psz/src/stat/extrema/f8.thrust.hip
  psz/src/stat/assess/f4.hip
  psz/src/stat/assess/f8.hip
  psz/src/stat/assess/f4.thrust.hip
  psz/src/stat/assess/f8.thrust.hip
  psz/src/stat/calcerr/f4.hip
  psz/src/stat/calcerr/f8.hip
  psz/src/stat/maxerr/max_err.hip
  psz/src/stat/maxerr/f4.thrust.hip
  psz/src/stat/maxerr/f8.thrust.hip
)
target_link_libraries(psz_hip_stat
  PUBLIC
    psz_hip_compile_settings
    roc::rocthrust
)

# FUNC={core,api}, BACKEND={serial,cuda,...}
add_library(psz_seq_core
  psz/src/kernel/lrz.seq.cc
  psz/src/kernel/hist_generic.seq.cc
  psz/src/kernel/histsp.seq.cc
  psz/src/kernel/spvn.seq.cc
)
target_link_libraries(psz_seq_core
  PUBLIC
    psz_hip_compile_settings
)

add_library(psz_hip_mem
  psz/src/mem/buf_comp.cc
)
target_link_libraries(psz_hip_mem
  PUBLIC
    psz_hip_compile_settings
    psz_hip_stat
    DEPS::deps
    PHF::phf_hip
    hip::host
)

add_library(psz_hip_core
  psz/src/kernel/hist_generic.hip
  psz/src/kernel/histsp.hip
  psz/src/kernel/spvn.hip
  psz/src/kernel/lrz_c.hip
  psz/src/kernel/lrz_x.hip
  psz/src/kernel/proto_lrz_c.hip
  psz/src/kernel/proto_lrz_x.hip
  psz/src/kernel/spline3.hip
)
target_link_libraries(psz_hip_core
  PUBLIC
    psz_hip_compile_settings
    psz_hip_mem
    PHF::phf_hip
    hip::device
)

add_library(psz_hip_utils
  psz/src/utils/viewer.cc
  psz/src/utils/viewer.hip
  psz/src/utils/verinfo.cc
  psz/src/utils/verinfo.hip
  psz/src/utils/vis_stat.cc
  psz/src/utils/context.cc
  psz/src/utils/header.c
)
target_link_libraries(psz_hip_utils
  PUBLIC
    psz_hip_compile_settings
    psz_hip_stat
    PHF::phf_hip
    hip::host
)

add_library(hipsz
  psz/src/compressor.cc
  psz/src/libcusz.cc
)
target_link_libraries(hipsz
  PUBLIC
    psz_hip_compile_settings
    psz_hip_core
    psz_hip_stat
    psz_hip_mem
    psz_hip_utils
    PHF::phf_hip
    FZG::fzg_hip
    hip::host
)

# ------------------------------------------------------------------------------
# Executable
# ------------------------------------------------------------------------------

add_executable(hipsz-bin psz/src/cli/cli.cc)
set_source_files_properties(psz/src/cli/cli.cc PROPERTIES LANGUAGE HIP)
target_link_libraries(hipsz-bin PRIVATE hipsz)
set_target_properties(hipsz-bin PROPERTIES OUTPUT_NAME hipsz)

# ------------------------------------------------------------------------------
# Examples / Tests
# ------------------------------------------------------------------------------

if(PSZ_BUILD_EXAMPLES)
  add_subdirectory(example)
endif()

if(BUILD_TESTING)
  add_subdirectory(test)
endif()

# ------------------------------------------------------------------------------
# Installation (CUSZ:: namespace, back compat)
# ------------------------------------------------------------------------------

install(TARGETS psz_hip_compile_settings EXPORT CUSZTargets)

install(TARGETS
  psz_seq_core
  psz_hip_core
  psz_hip_stat
  psz_hip_mem
  psz_hip_utils
  hipsz
  EXPORT CUSZTargets
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(TARGETS
  hipsz-bin
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(
  EXPORT CUSZTargets
  NAMESPACE CUSZ::
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/CUSZ
)

include(CMakePackageConfigHelpers)

configure_package_config_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CUSZConfig.cmake.in"
  "${CMAKE_CURRENT_BINARY_DIR}/CUSZConfig.cmake"
  INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/CUSZ
)

write_basic_package_version_file(
  "${CMAKE_CURRENT_BINARY_DIR}/CUSZConfigVersion.cmake"
  VERSION "${PROJECT_VERSION}"
  COMPATIBILITY AnyNewerVersion
)

install(FILES
  "${CMAKE_CURRENT_BINARY_DIR}/CUSZConfig.cmake"
  "${CMAKE_CURRENT_BINARY_DIR}/CUSZConfigVersion.cmake"
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/CUSZ
)

install(DIRECTORY
  portable/include
  psz/include
  codec/hf/include
  codec/fzg/include
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/cusz
)

install(FILES
  "${CMAKE_CURRENT_BINARY_DIR}/psz/include/cusz_version.h"
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/cusz
)

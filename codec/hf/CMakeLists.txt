
cmake_minimum_required(VERSION 3.18)

# Detect if we're building with HIP or CUDA based on parent project
if(PSZ_USE_HIP OR DEFINED PSZ_BACKEND AND (PSZ_BACKEND STREQUAL "HIP" OR PSZ_BACKEND STREQUAL "hip"))
  project(PHF
    VERSION 0.1.0
    LANGUAGES CXX HIP
  )
  set(_PHF_USE_HIP ON)
else()
  project(PHF
    VERSION 0.1.0
    LANGUAGES CXX CUDA
  )
  find_package(CUDAToolkit REQUIRED)
  set(_PHF_USE_HIP OFF)
endif()

find_package(PORTABLE QUIET)
if(NOT TARGET PORTABLE AND NOT TARGET PORTABLE::PORTABLE)
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../../portable")
    add_subdirectory(
      "${CMAKE_CURRENT_SOURCE_DIR}/../../portable"
      "${CMAKE_CURRENT_BINARY_DIR}/portable"
    )
  else()
    message(FATAL_ERROR
      "PORTABLE not found and ../../portable does not exist"
    )
  endif()
endif()

# PORTABLE is header-only; extend its interface for PHF
if(TARGET PORTABLE)
  set(PHF_PORTABLE_TARGET PORTABLE)
elseif(TARGET PORTABLE::PORTABLE)
  set(PHF_PORTABLE_TARGET PORTABLE::PORTABLE)
endif()

if(NOT PHF_PORTABLE_TARGET)
  message(FATAL_ERROR "PORTABLE target not available after setup")
endif()

# ------------------------------------------------------------------------------
# Library
# ------------------------------------------------------------------------------

if(_PHF_USE_HIP)
  target_compile_definitions(${PHF_PORTABLE_TARGET}
    INTERFACE
      PHF_USE_HIP
  )

  add_library(phf_hip
    src/hf_bk.seq.cc
    src/hf_bk_impl1.seq.cc
    src/hf_bk_impl2.seq.cc
    src/hf_bk_internal.seq.cc
    src/hf_buf.cc
    src/hf_canon.seq.cc
    src/hf_est.cc
    src/hf_hl.cc
    src/hf_kernels.hip
    src/libphf.cc
  )
  add_library(PHF::phf_hip ALIAS phf_hip)

  target_include_directories(phf_hip
    PUBLIC
      $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
      $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
  )

  target_link_libraries(phf_hip
    PUBLIC
      hip::host
      ${PHF_PORTABLE_TARGET}
  )

  set_target_properties(phf_hip
    PROPERTIES
      LINKER_LANGUAGE CXX
  )

  # Make phf_cu an alias for phf_hip so hip.cmake can reference PHF::phf_hip
  # while cuda.cmake references PHF::phf_cu
else()
  target_compile_definitions(${PHF_PORTABLE_TARGET}
    INTERFACE
      PHF_USE_CUDA
  )

  add_library(phf_cu
    src/hf_bk.seq.cc
    src/hf_bk_impl1.seq.cc
    src/hf_bk_impl2.seq.cc
    src/hf_bk_internal.seq.cc
    src/hf_buf.cc
    src/hf_canon.seq.cc
    src/hf_est.cc
    src/hf_hl.cc
    src/hf_kernels.cu
    src/libphf.cc
  )
  add_library(PHF::phf_cu ALIAS phf_cu)

  target_include_directories(phf_cu
    PUBLIC
      $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
      $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
  )

  target_link_libraries(phf_cu
    PUBLIC
      CUDA::cudart
      ${PHF_PORTABLE_TARGET}
  )

  set_target_properties(phf_cu
    PROPERTIES
      LINKER_LANGUAGE CXX
  )
endif()

# ------------------------------------------------------------------------------
# Installation + package config
# ------------------------------------------------------------------------------

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

if(_PHF_USE_HIP)
  install(TARGETS phf_hip
    EXPORT HFTargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
  )
else()
  install(TARGETS phf_cu
    EXPORT HFTargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
  )
endif()

install(DIRECTORY
  include/
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(EXPORT HFTargets
  FILE HFTargets.cmake
  NAMESPACE PHF::
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/PHF
)

write_basic_package_version_file(
  "${CMAKE_CURRENT_BINARY_DIR}/HFConfigVersion.cmake"
  VERSION "${PROJECT_VERSION}"
  COMPATIBILITY SameMajorVersion
)

configure_package_config_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/HFConfig.cmake.in"
  "${CMAKE_CURRENT_BINARY_DIR}/HFConfig.cmake"
  INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/PHF
)

install(FILES
  "${CMAKE_CURRENT_BINARY_DIR}/HFConfig.cmake"
  "${CMAKE_CURRENT_BINARY_DIR}/HFConfigVersion.cmake"
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/PHF
)

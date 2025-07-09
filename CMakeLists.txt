# SPDX-FileCopyrightText: 2024-2025 Andy Curtis <contactandyc@gmail.com>
# SPDX-FileCopyrightText: 2024-2025 Knode.ai
# SPDX-License-Identifier: Apache-2.0
cmake_minimum_required(VERSION 3.10)

# Project details
project("A CMake Library" VERSION 1.0.0 LANGUAGES NONE)

# Default to /usr/local if CMAKE_INSTALL_PREFIX is not set
if(NOT CMAKE_INSTALL_PREFIX OR CMAKE_INSTALL_PREFIX STREQUAL "")
    set(CMAKE_INSTALL_PREFIX "/usr/local" CACHE PATH "Install path prefix" FORCE)
endif()

# Ensure CMAKE_INSTALL_DATADIR is defined
if(NOT DEFINED CMAKE_INSTALL_DATADIR)
    set(CMAKE_INSTALL_DATADIR "share" CACHE STRING "Install data directory")
endif()

# Install the CMake module files
install(
    FILES
        cmake/BinaryConfig.cmake
        cmake/BinaryFunctions.cmake
        cmake/BinaryLibraryFunctions.cmake
        cmake/CodeCoverage.cmake
        cmake/CodeCoverageCustomTarget.cmake
        cmake/LibraryBuild.cmake
        cmake/LibraryHeaderOnly.cmake
        cmake/LibraryNormal.cmake
        cmake/LibraryConfig.cmake
    DESTINATION ${CMAKE_INSTALL_DATADIR}/a-cmake-library
)

# Generate the a-cmake-libraryConfig.cmake.in file
file(WRITE "${CMAKE_BINARY_DIR}/a-cmake-libraryConfig.cmake.in" "
@PACKAGE_INIT@

# Add the installed a-cmake-library path to CMAKE_MODULE_PATH
set(CMAKE_MODULE_PATH \"@CMAKE_INSTALL_PREFIX@/@CMAKE_INSTALL_DATADIR@/a-cmake-library\" \${CMAKE_MODULE_PATH})
")

# Export package configuration
include(CMakePackageConfigHelpers)

# Write the config and version files
write_basic_package_version_file(
    "${CMAKE_BINARY_DIR}/a-cmake-libraryConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY AnyNewerVersion
)

configure_file(
    "${CMAKE_BINARY_DIR}/a-cmake-libraryConfig.cmake.in"
    "${CMAKE_BINARY_DIR}/a-cmake-libraryConfig.cmake"
    @ONLY
)

install(
    FILES
        "${CMAKE_BINARY_DIR}/a-cmake-libraryConfig.cmake"
        "${CMAKE_BINARY_DIR}/a-cmake-libraryConfigVersion.cmake"
    DESTINATION ${CMAKE_INSTALL_DATADIR}/a-cmake-library
)
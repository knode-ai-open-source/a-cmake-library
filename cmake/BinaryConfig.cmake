# SPDX-FileCopyrightText: 2024-2025 Andy Curtis <contactandyc@gmail.com>
# SPDX-FileCopyrightText: 2024-2025 Knode.ai
# SPDX-License-Identifier: Apache-2.0

####################################################################################################
# BinaryConfig.cmake
# This script is used to configure the build for both regular executables and test executables
# for a library. It handles source file inclusion, package dependencies, and linkage settings.
#
# Purpose:
# - Automates the configuration of test and regular executables.
# - Ensures proper linkage against static, shared, or debug libraries.
# - Provides flexibility to define additional sources and dependencies per executable.
#
# Variables:
# - BINARY_SOURCES (optional): List of source files for regular executables.
# - TEST_SOURCES (optional): List of source files for test executables.
# - <BINARY_NAME>_SOURCES (optional): Additional sources for a specific regular executable.
# - <TEST_NAME>_SOURCES (optional): Additional sources for a specific test executable.
# - CUSTOM_PACKAGES (optional): List of custom packages to include (using this CMake setup).
# - THIRD_PARTY_PACKAGES (optional): List of third-party packages to include (e.g., ZLIB).
# - LIB_TO_TEST (optional): The library to test.
#
# Linkage Options (default is debug):
# - STATIC_BUILD: Link against the static library.
# - SHARED_BUILD: Link against the shared library.
# - DEBUG_BUILD: Link against the debug library (default - must specify other BUILD option to turn off).
# - ENABLE_CODE_COVERAGE: Enable code coverage reporting.
# - ENABLE_CLANG_TIDY: Enable Clang-Tidy analysis.
# - ADDRESS_SANITIZER: Enable Address Sanitizer.
#
# Example Usage:
# cmake_minimum_required(VERSION 3.10)
#
# set(CUSTOM_PACKAGES the-io-library)
# set(BINARY_SOURCES src/io_demo.c)
# set(io_demo_SOURCES src/io_demo_utils.c)
#
# find_package(a-cmake-library REQUIRED)
# include(BinaryConfig)
#
# Behavior:
# - For each binary or test executable, the script automatically:
#   1. Collects base sources (from `BINARY_SOURCES` or `TEST_SOURCES`).
#   2. Appends additional sources defined as <NAME>_SOURCES.
#   3. Links against libraries defined in `CUSTOM_PACKAGES` and `THIRD_PARTY_PACKAGES`.
#   4. Registers tests (if applicable) with CTest.
####################################################################################################

# Options
option(ADDRESS_SANITIZER "Enable Address Sanitizer" OFF)
option(ENABLE_CODE_COVERAGE "Enable code coverage reporting" OFF)
option(ENABLE_CLANG_TIDY "Enable Clang-Tidy analysis" OFF)
option(STATIC_BUILD "Link against static library" OFF)
option(SHARED_BUILD "Link against shared library" OFF)
option(DEBUG_BUILD "Link against debug library" ON)

# C version
set(CMAKE_C_STANDARD 23)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# Compiler options
if(ADDRESS_SANITIZER)
    add_compile_options(-fsanitize=address)
endif()

if(ENABLE_CLANG_TIDY)
    set(CMAKE_C_CLANG_TIDY clang-tidy)
endif()

if(EXISTS "/opt/homebrew/opt/openssl")
    # Add the path if it exists
    set(OpenSSL_DIR "/opt/homebrew/opt/openssl/lib/cmake/OpenSSL")
    message(STATUS "set OpenSSL_DIR to ${OpenSSL_DIR}")
else()
    message(STATUS "/opt/homebrew/opt/openssl does not exist (maybe not a mac?)")
endif()

include(${CMAKE_CURRENT_LIST_DIR}/BinaryFunctions.cmake)

construct_package_list(PACKAGE_LIST)
if(PACKAGE_LIST)
    foreach(PACKAGE ${PACKAGE_LIST})
        find_generic_package(${PACKAGE})
#        message(STATUS "find_package (binary) ${PACKAGE}")
#        if(${PACKAGE} MATCHES "OpenSSL")
#            find_package(OpenSSL REQUIRED)
#        elseif (${PACKAGE} STREQUAL "nonstd::expected-lite")
#            find_package(expected-lite REQUIRED)
#        else()
#            find_package(${PACKAGE} REQUIRED)
#        endif()
    endforeach()
endif()

if(SHARED_BUILD)
    set(LIB_STYLE shared)
    add_compile_options(-O2)
elseif(STATIC_BUILD)
    set(LIB_STYLE static)
    add_compile_options(-O3)
else()
    set(LIB_STYLE debug)
    # add_compile_definitions(-D_AML_DEBUG_)
    add_compile_options(-g -O0)
endif()

construct_packages("")

if(NOT DEFINED PACKAGES OR PACKAGES STREQUAL "")
    unset(PACKAGES)
endif()

message(STATUS "Linking against ${PACKAGES}")

include(${CMAKE_CURRENT_LIST_DIR}/CodeCoverage.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/CodeCoverageCustomTarget.cmake)

# Include directories for the main library
include_directories(${CMAKE_SOURCE_DIR}/include)

# Add test executables
foreach(BINARY_SOURCE ${BINARY_SOURCES})
    # Extract test name (e.g., test_io.c -> test_io)
    get_filename_component(BINARY_NAME ${BINARY_SOURCE} NAME_WE)

    # Collect the base source for the test
    set(CURRENT_BINARY_SOURCES ${BINARY_SOURCE})

    # Check if additional sources are defined for the BINARY
    if(DEFINED ${BINARY_NAME}_SOURCES)
        list(APPEND CURRENT_BINARY_SOURCES ${${BINARY_NAME}_SOURCES})
    endif()

    # Add executable for the test with the collected sources
    add_executable(${BINARY_NAME} ${CURRENT_BINARY_SOURCES})

    # Link against the chosen library
    if(PACKAGES)
        target_link_libraries(${BINARY_NAME} PRIVATE ${PACKAGES} -lm -lpthread)
    endif()
endforeach()


# Add test executables
foreach(TEST_SOURCE ${TEST_SOURCES})
    # Extract test name (e.g., test_io.c -> test_io)
    get_filename_component(TEST_NAME ${TEST_SOURCE} NAME_WE)

    # Collect the base source for the test
    set(CURRENT_TEST_SOURCES ${TEST_SOURCE})

    # Check if additional sources are defined for the test
    if(DEFINED ${TEST_NAME}_SOURCES)
        list(APPEND CURRENT_TEST_SOURCES ${${TEST_NAME}_SOURCES})
    endif()

    # Add executable for the test with the collected sources
    add_executable(${TEST_NAME} ${CURRENT_TEST_SOURCES})

    # Link against the chosen library
    if(PACKAGES)
        target_link_libraries(${TEST_NAME} PRIVATE ${PACKAGES} -lm -lpthread)
    endif()

    # Register the test with CTest
    add_test(NAME ${TEST_NAME} COMMAND ${TEST_NAME})
endforeach()

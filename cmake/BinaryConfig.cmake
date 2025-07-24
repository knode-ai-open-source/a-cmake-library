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

# ---- Options -----------------------------------------------------------------
option(ADDRESS_SANITIZER   "Enable Address Sanitizer"        OFF)
option(ENABLE_CODE_COVERAGE "Enable code coverage reporting" OFF)
option(ENABLE_CLANG_TIDY   "Enable Clang‑Tidy analysis"      OFF)
option(STATIC_BUILD        "Link against static library"     OFF)
option(SHARED_BUILD        "Link against shared library"     OFF)
option(DEBUG_BUILD         "Link against debug library"      ON)

# ---- C standard guard ---------------------------------------------------------
include(CheckCCompilerFlag)
check_c_compiler_flag("-std=c23" _HAS_C23)
if (_HAS_C23)
    set(CMAKE_C_STANDARD 23)
else()
    set(CMAKE_C_STANDARD 17)
endif()
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# ---- Sanitizers / tooling -----------------------------------------------------
if (ADDRESS_SANITIZER)
    add_compile_options(-fsanitize=address)
endif()
if (ENABLE_CLANG_TIDY)
    set(CMAKE_C_CLANG_TIDY clang-tidy)
endif()

include(${CMAKE_CURRENT_LIST_DIR}/BinaryFunctions.cmake)

construct_package_list(PACKAGE_LIST)
foreach(PACKAGE IN LISTS PACKAGE_LIST)
    find_generic_package(${PACKAGE})
endforeach()

# ---- Optimisation profile selection ------------------------------------------
if (SHARED_BUILD)
    set(LIB_STYLE shared)
    add_compile_options(-O2)
elseif (STATIC_BUILD)
    set(LIB_STYLE static)
    add_compile_options(-O3)
else()
    set(LIB_STYLE debug)
    add_compile_options(-g -O0)
endif()

# Recursively collect INTERFACE deps for a target
function(_collect_deps tgt out_var)
    if(NOT TARGET "${tgt}")
        set(${out_var} "" PARENT_SCOPE)
        return()
    endif()

    get_target_property(_deps "${tgt}" INTERFACE_LINK_LIBRARIES)
    if(NOT _deps)
        set(_deps "")
    endif()

    set(_seen "")
    foreach(d IN LISTS _deps)
        if(TARGET "${d}")
            list(APPEND _seen "${d}")
            _collect_deps("${d}" _sub)
            list(APPEND _seen ${_sub})
        endif()
    endforeach()

    list(REMOVE_DUPLICATES _seen)
    set(${out_var} "${_seen}" PARENT_SCOPE)
endfunction()

# Remove from IN_LIST every target that is a transitive dep of another target in the list
function(prune_root_packages IN_LIST OUT_LIST)
    set(_in "${${IN_LIST}}")
    set(_remove "")

    foreach(root IN LISTS _in)
        if(TARGET "${root}")
            _collect_deps("${root}" _deps)
            foreach(d IN LISTS _deps)
                list(FIND _in "${d}" _idx)
                if(NOT _idx EQUAL -1)
                    list(APPEND _remove "${d}")
                endif()
            endforeach()
        endif()
    endforeach()

    list(REMOVE_DUPLICATES _remove)
    set(_pruned "${_in}")
    foreach(r IN LISTS _remove)
        list(REMOVE_ITEM _pruned "${r}")
    endforeach()
    list(REMOVE_DUPLICATES _pruned)

    set(${OUT_LIST} "${_pruned}" PARENT_SCOPE)
endfunction()


construct_packages("")

if (PACKAGES STREQUAL "")
    unset(PACKAGES)
else()
    prune_root_packages(PACKAGES PACKAGES_PRUNED)
    set(PACKAGES "${PACKAGES_PRUNED}")
endif()

message(STATUS "Linking against ${PACKAGES}")

include(${CMAKE_CURRENT_LIST_DIR}/CodeCoverage.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/CodeCoverageCustomTarget.cmake)

include_directories(${CMAKE_SOURCE_DIR}/include)   # main library headers

# ---- Regular executables ------------------------------------------------------
foreach(BINARY_SOURCE IN LISTS BINARY_SOURCES)
    get_filename_component(BINARY_NAME ${BINARY_SOURCE} NAME_WE)
    set(CURRENT_BINARY_SOURCES ${BINARY_SOURCE})
    if(DEFINED ${BINARY_NAME}_SOURCES)
        list(APPEND CURRENT_BINARY_SOURCES ${${BINARY_NAME}_SOURCES})
    endif()
    add_executable(${BINARY_NAME} ${CURRENT_BINARY_SOURCES})
    if (PACKAGES)
        list(REMOVE_DUPLICATES PACKAGES)
        target_link_libraries(${BINARY_NAME} PRIVATE ${PACKAGES})
    endif()
endforeach()

# ---- Tests --------------------------------------------------------------------
foreach(TEST_SOURCE IN LISTS TEST_SOURCES)
    get_filename_component(TEST_NAME ${TEST_SOURCE} NAME_WE)
    set(CURRENT_TEST_SOURCES ${TEST_SOURCE})
    if(DEFINED ${TEST_NAME}_SOURCES)
        list(APPEND CURRENT_TEST_SOURCES ${${TEST_NAME}_SOURCES})
    endif()
    add_executable(${TEST_NAME} ${CURRENT_TEST_SOURCES})
    if (PACKAGES)
        list(REMOVE_DUPLICATES PACKAGES)
        target_link_libraries(${TEST_NAME} PRIVATE ${PACKAGES})
    endif()
    add_test(NAME ${TEST_NAME} COMMAND ${TEST_NAME})
endforeach()
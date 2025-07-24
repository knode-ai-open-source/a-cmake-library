# SPDX-FileCopyrightText: 2024-2025 Andy Curtis <contactandyc@gmail.com>
# SPDX-FileCopyrightText: 2024-2025 Knode.ai
# SPDX-License-Identifier: Apache-2.0

################################################################################
# BinaryFunctions.cmake
#
# This file contains functions for constructing package lists and variables for
# the binary executables.
#
# Functions:
# - construct_package_list(RESULT_VAR): Construct a list of packages to include for find_package.
# - construct_packages(TARGET_NAME): Construct a list of packages to include for a specific target. If TARGET_NAME is not defined,
#     the global packages are used and PACKAGES is set. Otherwise, the target-specific packages are used and
#     ${TARGET_NAME}_PACKAGES is set.
#
# Example Usage:
# set(LIB_TO_TEST "my_library")
# set(CUSTOM_PACKAGES "custom_lib1;custom_lib2")
# set(THIRD_PARTY_PACKAGES "ZLIB")
# set(LIB_STYLE "static")
#
# construct_packages()
# message(STATUS "Packages: ${PACKAGES}")
################################################################################

include(${CMAKE_CURRENT_LIST_DIR}/BinaryLibraryFunctions.cmake)

# -----------------------------------------------------------------------------
# Append items from SOURCE_LIST into LIST_NAME if they are not already present
# -----------------------------------------------------------------------------
function(_append_unique_packages LIST_NAME SOURCE_LIST)
    if(DEFINED "${SOURCE_LIST}" AND NOT "${${SOURCE_LIST}}" STREQUAL "")
        foreach(PKG ${${SOURCE_LIST}})
            list(FIND ${LIST_NAME} "${PKG}" _idx)
            if(_idx EQUAL -1)
                list(APPEND ${LIST_NAME} "${PKG}")
            endif()
        endforeach()
        set(${LIST_NAME} "${${LIST_NAME}}" PARENT_SCOPE)
    endif()
endfunction()

# -----------------------------------------------------------------------------
# Build a *flat* list of all packages referenced by binaries / tests
# -----------------------------------------------------------------------------
function(construct_package_list RESULT_VAR)
    set(PACKAGES "")

    _append_unique_packages(PACKAGES THIRD_PARTY_PACKAGES)

    if(DEFINED BINARY_SOURCES)
        foreach(TGT ${BINARY_SOURCES})
            _append_unique_packages(PACKAGES "${TGT}_THIRD_PARTY_PACKAGES")
        endforeach()
    endif()

    if(DEFINED TEST_SOURCES)
        foreach(TGT ${TEST_SOURCES})
            _append_unique_packages(PACKAGES "${TGT}_THIRD_PARTY_PACKAGES")
        endforeach()
    endif()

    if(DEFINED BINARY_SOURCES)
        foreach(TGT ${BINARY_SOURCES})
            _append_unique_packages(PACKAGES "${TGT}_CUSTOM_PACKAGES")
        endforeach()
    endif()

    if(DEFINED TEST_SOURCES)
        foreach(TGT ${TEST_SOURCES})
            _append_unique_packages(PACKAGES "${TGT}_CUSTOM_PACKAGES")
        endforeach()
    endif()

    _append_unique_packages(PACKAGES LIB_TO_TEST)
    _append_unique_packages(PACKAGES CUSTOM_PACKAGES)

    set(${RESULT_VAR} "${PACKAGES}" PARENT_SCOPE)
endfunction()

# -----------------------------------------------------------------------------
# Helper that decides whether to use <pkg>::static / ::shared or header‑only
# -----------------------------------------------------------------------------
function(construct_packages_variable HEADER_RESULT_VAR RESULT_VAR
                                      LIB_TO_TEST CUSTOM_PACKAGES
                                      THIRD_PARTY_PACKAGES LIB_STYLE)
    set(PACKAGES           "")
    set(HEADER_ONLY_PKGS   "")

    # ----- main library -------------------------------------------------------
    if(NOT "${LIB_TO_TEST}" STREQUAL "")
        is_header_only_library("${LIB_TO_TEST}" _is_header_only)
        if(_is_header_only)
            list(APPEND HEADER_ONLY_PKGS "${LIB_TO_TEST}::${LIB_TO_TEST}")
        else()
            list(APPEND PACKAGES "${LIB_TO_TEST}::${LIB_STYLE}")
        endif()
    endif()

    # ----- custom packages ----------------------------------------------------
    if(NOT "${CUSTOM_PACKAGES}" STREQUAL "")
        foreach(PKG ${CUSTOM_PACKAGES})
            if(NOT "${PKG}" STREQUAL "${LIB_TO_TEST}")
                is_header_only_library("${PKG}" _is_header_only)
                if(_is_header_only)
                    list(APPEND HEADER_ONLY_PKGS "${PKG}::${PKG}")
                else()
                    list(APPEND PACKAGES "${PKG}::${LIB_STYLE}")
                endif()
            endif()
        endforeach()
    endif()

    # ----- third‑party packages ----------------------------------------------
    if(NOT "${THIRD_PARTY_PACKAGES}" STREQUAL "")
        foreach(PKG ${THIRD_PARTY_PACKAGES})
            if("${PKG}" MATCHES "::")
                list(APPEND PACKAGES "${PKG}")
            else()
                list(APPEND PACKAGES "${PKG}::${PKG}")
            endif()
        endforeach()
    endif()

    set(${RESULT_VAR}        "${PACKAGES}"         PARENT_SCOPE)
    set(${HEADER_RESULT_VAR} "${HEADER_ONLY_PKGS}" PARENT_SCOPE)
endfunction()

# Constructs a variable based upon the target-specific before the global
function(_resolve_custom TARGET_NAME CUSTOM_VAR RESULT_VAR)
    # Check if the target-specific custom packages are defined
    if(DEFINED "${TARGET_NAME}_${CUSTOM_VAR}")
        set(RESULT_VAR "${${TARGET_NAME}_${CUSTOM_VAR}}" PARENT_SCOPE)
    elseif(DEFINED "${CUSTOM_VAR}")
        set(RESULT_VAR "${${CUSTOM_VAR}}" PARENT_SCOPE)
    else()
        set(RESULT_VAR "" PARENT_SCOPE)
    endif()
endfunction()

# Construct a list of packages to include for a specific target.  If TARGET_NAME is not defined, the global packages are
# used and PACKAGES is set.  Otherwise, the target-specific packages are used and ${TARGET_NAME}_PACKAGES is set.
function(construct_packages TARGET_NAME)
    # Check for required variables and set defaults
    if(NOT DEFINED LIB_TO_TEST)
        set(LIB_TO_TEST "")
    endif()
    if(NOT DEFINED CUSTOM_PACKAGES)
        set(CUSTOM_PACKAGES "")
    endif()
    if(NOT DEFINED THIRD_PARTY_PACKAGES)
        set(THIRD_PARTY_PACKAGES "")
    endif()
    if(NOT DEFINED LIB_STYLE)
        set(LIB_STYLE debug)
    endif()

    if(NOT "${TARGET_NAME}" OR "${TARGET_NAME}" STREQUAL "")
        # Use global or default settings
        construct_packages_variable(HEADER_PACKAGES
                                    PACKAGES
                                    "${LIB_TO_TEST}"
                                    "${CUSTOM_PACKAGES}"
                                    "${THIRD_PARTY_PACKAGES}"
                                    "${LIB_STYLE}")
        set(HEADER_PACKAGES "${HEADER_PACKAGES}" PARENT_SCOPE)
        set(PACKAGES "${PACKAGES}" PARENT_SCOPE)
    else()
        # Use target-specific logic
        _resolve_custom("${TARGET_NAME}" CUSTOM_PACKAGES TARGET_CUSTOM_PACKAGES)
        _resolve_custom("${TARGET_NAME}" THIRD_PARTY_PACKAGES TARGET_THIRD_PARTY_PACKAGES)

        construct_packages_variable(HEADER_PACKAGES
                                    PACKAGES
                                    "${LIB_TO_TEST}"
                                    "${TARGET_CUSTOM_PACKAGES}"
                                    "${TARGET_THIRD_PARTY_PACKAGES}"
                                    "${LIB_STYLE}")
        set(${TARGET_NAME}_PACKAGES "${PACKAGES}" PARENT_SCOPE)
        set(${TARGET_NAME}_HEADER_PACKAGES "${HEADER_PACKAGES}" PARENT_SCOPE)
    endif()
endfunction()
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

# Internal function to append unique packages to a list
function(_append_unique_packages LIST_NAME SOURCE_LIST)
    if(DEFINED "${SOURCE_LIST}" AND NOT "${${SOURCE_LIST}}" STREQUAL "")
        foreach(PACKAGE ${${SOURCE_LIST}})
            list(FIND "${LIST_NAME}" "${PACKAGE}" INDEX)
            if(INDEX EQUAL -1)
                list(APPEND "${LIST_NAME}" "${PACKAGE}")
            endif()
        endforeach()
        set("${LIST_NAME}" "${${LIST_NAME}}" PARENT_SCOPE)
    endif()
endfunction()

# Construct a list of packages to include for find_package
function(construct_package_list RESULT_VAR)
    # Initialize the packages list
    set(PACKAGES "")

    # Add global third-party packages
    _append_unique_packages(PACKAGES THIRD_PARTY_PACKAGES)

    # Add binary source-specific packages
    if(DEFINED BINARY_SOURCES AND NOT "${BINARY_SOURCES}" STREQUAL "")
        foreach(TARGET_NAME ${BINARY_SOURCES})
            _append_unique_packages(PACKAGES "${TARGET_NAME}_THIRD_PARTY_PACKAGES")
        endforeach()
    endif()

    # Add test source-specific packages
    if(DEFINED TEST_SOURCES AND NOT "${TEST_SOURCES}" STREQUAL "")
        foreach(TARGET_NAME ${TEST_SOURCES})
            _append_unique_packages(PACKAGES "${TARGET_NAME}_THIRD_PARTY_PACKAGES")
        endforeach()
    endif()

    # Add binary source-specific packages
    if(DEFINED BINARY_SOURCES AND NOT "${BINARY_SOURCES}" STREQUAL "")
        foreach(TARGET_NAME ${BINARY_SOURCES})
            _append_unique_packages(PACKAGES "${TARGET_NAME}_CUSTOM_PACKAGES")
        endforeach()
    endif()

    # Add test source-specific packages
    if(DEFINED TEST_SOURCES AND NOT "${TEST_SOURCES}" STREQUAL "")
        foreach(TARGET_NAME ${TEST_SOURCES})
            _append_unique_packages(PACKAGES "${TARGET_NAME}_CUSTOM_PACKAGES")
        endforeach()
    endif()

    # Add main library
    _append_unique_packages(PACKAGES LIB_TO_TEST)

    # Add global custom packages
    _append_unique_packages(PACKAGES CUSTOM_PACKAGES)

    # Set the resulting packages variable
    set("${RESULT_VAR}" "${PACKAGES}" PARENT_SCOPE)
endfunction()

# Internal function to construct the packages variable
function(construct_packages_variable HEADER_RESULT_VAR RESULT_VAR LIB_TO_TEST CUSTOM_PACKAGES THIRD_PARTY_PACKAGES LIB_STYLE)
    # Initialize the packages list
    set(PACKAGES "")
    set(HEADER_ONLY_PACKAGES "")

    # Include the main library if defined and valid
    if(NOT "${LIB_TO_TEST}" STREQUAL "")
        is_header_only_library("${LIB_TO_TEST}" IS_HEADER_ONLY)
        if(IS_HEADER_ONLY)
            list(APPEND HEADER_ONLY_PACKAGES "${LIB_TO_TEST}::${PACKAGE}")
        else()
            list(APPEND PACKAGES "${LIB_TO_TEST}::${LIB_STYLE}")
        endif()
    endif()

    # Include custom packages
    if(NOT "${CUSTOM_PACKAGES}" STREQUAL "")
        foreach(PACKAGE ${CUSTOM_PACKAGES})
            if(NOT "${PACKAGE}" STREQUAL "${LIB_TO_TEST}")
                is_header_only_library("${PACKAGE}" IS_HEADER_ONLY)
                if(IS_HEADER_ONLY)
                    list(APPEND HEADER_ONLY_PACKAGES "${PACKAGE}::${PACKAGE}")
                else()
                    list(APPEND PACKAGES "${PACKAGE}::${LIB_STYLE}")
                endif()
            endif()
        endforeach()
    endif()

    # Include third-party packages
    if(NOT "${THIRD_PARTY_PACKAGES}" STREQUAL "")
        foreach(PACKAGE ${THIRD_PARTY_PACKAGES})
            if(${PACKAGE} MATCHES "::")
                list(APPEND PACKAGES "${PACKAGE}")
            else()
                list(APPEND PACKAGES "${PACKAGE}::${PACKAGE}")
            endif()
        endforeach()
    endif()

    # Set the resulting packages variable
    set("${RESULT_VAR}" "${PACKAGES}" PARENT_SCOPE)
    set("${HEADER_RESULT_VAR}" "${HEADER_ONLY_PACKAGES}" PARENT_SCOPE)
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
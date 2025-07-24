# SPDX-FileCopyrightText: 2024-2025 Andy Curtis <contactandyc@gmail.com>
# SPDX-FileCopyrightText: 2024-2025 Knode.ai
# SPDX-License-Identifier: Apache-2.0

################################################################################
# LibraryHeaderOnly.cmake
################################################################################

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Fallbacks if LibraryConfig.cmake was not included first
if(NOT DEFINED INSTALL_LIBDIR      OR INSTALL_LIBDIR      STREQUAL "")
    set(INSTALL_LIBDIR      "${CMAKE_INSTALL_LIBDIR}")
endif()
if(NOT DEFINED INSTALL_INCLUDEDIR  OR INSTALL_INCLUDEDIR  STREQUAL "")
    set(INSTALL_INCLUDEDIR  "${CMAKE_INSTALL_INCLUDEDIR}")
endif()
if(NOT DEFINED INSTALL_BINDIR      OR INSTALL_BINDIR      STREQUAL "")
    set(INSTALL_BINDIR      "${CMAKE_INSTALL_BINDIR}")
endif()
if(NOT DEFINED INSTALL_DOCDIR      OR INSTALL_DOCDIR      STREQUAL "")
    set(INSTALL_DOCDIR      "${CMAKE_INSTALL_DATAROOTDIR}/doc/${PROJECT_NAME}")
endif()

set(_pkg_cmake_dir "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}")

# -----------------------------------------------------------------------------
# Target
# -----------------------------------------------------------------------------
add_library(${PROJECT_NAME} INTERFACE)

target_include_directories(${PROJECT_NAME} INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${INSTALL_INCLUDEDIR}>
)
add_library(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME})

# -----------------------------------------------------------------------------
# Headers
# -----------------------------------------------------------------------------
if(NOT DEFINED INCLUDE_DIR_NAME OR INCLUDE_DIR_NAME STREQUAL "")
    install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include/"
            DESTINATION "${INSTALL_INCLUDEDIR}")
else()
    install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include/${INCLUDE_DIR_NAME}"
            DESTINATION "${INSTALL_INCLUDEDIR}")
endif()

# -----------------------------------------------------------------------------
# Exported targets
# -----------------------------------------------------------------------------
install(TARGETS   ${PROJECT_NAME}
        EXPORT    ${PROJECT_NAME}Targets
        INCLUDES  DESTINATION "${INSTALL_INCLUDEDIR}")

install(EXPORT    ${PROJECT_NAME}Targets
        NAMESPACE ${PROJECT_NAME}::
        FILE      ${PROJECT_NAME}Targets.cmake
        DESTINATION "${_pkg_cmake_dir}")

# -----------------------------------------------------------------------------
# Gather deps to emit find_dependency() calls
# -----------------------------------------------------------------------------
set(_raw_deps "")
foreach(_v CUSTOM_PACKAGES THIRD_PARTY_PACKAGES)
    if(DEFINED ${_v} AND NOT "${${_v}}" STREQUAL "")
        list(APPEND _raw_deps ${${_v}})
    endif()
endforeach()

set(_cfg_deps "")
foreach(_d IN LISTS _raw_deps)
    if(_d MATCHES "::")
        string(REGEX REPLACE "::.*" "" _pkg "${_d}")
    else()
        set(_pkg "${_d}")
    endif()
    if(NOT _pkg STREQUAL "")
        list(APPEND _cfg_deps "${_pkg}")
    endif()
endforeach()
list(REMOVE_DUPLICATES _cfg_deps)

# -----------------------------------------------------------------------------
# Package config files
# -----------------------------------------------------------------------------
set(_cfg_in   "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake.in")
set(_cfg_out  "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake")
set(_ver_out  "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake")

file(WRITE "${_cfg_in}" [[
@PACKAGE_INIT@
include(CMakeFindDependencyMacro)
set(_deps "@PROJECT_DEPS@")
foreach(_d IN LISTS _deps)
  if(NOT _d STREQUAL "")
    find_dependency(${_d} REQUIRED)
  endif()
endforeach()
include("${CMAKE_CURRENT_LIST_DIR}/@PROJECT_NAME@Targets.cmake")
]])

# pass deps into the template
set(PROJECT_DEPS "${_cfg_deps}")

write_basic_package_version_file(
    "${_ver_out}"
    VERSION       ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

configure_file("${_cfg_in}" "${_cfg_out}" @ONLY)

install(FILES
        "${_cfg_out}"
        "${_ver_out}"
        DESTINATION "${_pkg_cmake_dir}")

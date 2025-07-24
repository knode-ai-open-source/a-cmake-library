# SPDX-FileCopyrightText: 2024-2025 Andy Curtis <contactandyc@gmail.com>
# SPDX-FileCopyrightText: 2024-2025 Knode.ai
# SPDX-License-Identifier: Apache-2.0

################################################################################
# LibraryNormal.cmake
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

function(_common_lib_setup tgt)
    target_include_directories(${tgt} PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:${INSTALL_INCLUDEDIR}>)
endfunction()

# -----------------------------------------------------------------------------
# Debug
# -----------------------------------------------------------------------------
if(DEBUG_BUILD)
    add_library(${PROJECT_NAME}_debug STATIC ${SOURCE_FILES})
    _common_lib_setup(${PROJECT_NAME}_debug)
    target_compile_options(${PROJECT_NAME}_debug PRIVATE -g -O0)
    set_target_properties(${PROJECT_NAME}_debug PROPERTIES
        EXPORT_NAME debug
        OUTPUT_NAME "${PROJECT_NAME}_debug")
    target_link_libraries(${PROJECT_NAME}_debug
        PUBLIC  "${DEBUG_PACKAGES}"
        PRIVATE "${COVERAGE_LIBS}")
    add_library(${PROJECT_NAME}::debug ALIAS ${PROJECT_NAME}_debug)

    if(NOT STATIC_BUILD AND NOT SHARED_BUILD)
        add_library(${PROJECT_NAME} ALIAS ${PROJECT_NAME}_debug)
        add_library(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME}_debug)
    endif()
endif()

# -----------------------------------------------------------------------------
# Static
# -----------------------------------------------------------------------------
if(STATIC_BUILD)
    add_library(${PROJECT_NAME}_static STATIC ${SOURCE_FILES})
    _common_lib_setup(${PROJECT_NAME}_static)
    target_compile_options(${PROJECT_NAME}_static PRIVATE -O3)
    set_target_properties(${PROJECT_NAME}_static PROPERTIES
        EXPORT_NAME static
        OUTPUT_NAME "${PROJECT_NAME}_static")
    target_link_libraries(${PROJECT_NAME}_static
        PUBLIC  "${STATIC_PACKAGES}"
        PRIVATE "${COVERAGE_LIBS}")

    add_library(${PROJECT_NAME} ALIAS ${PROJECT_NAME}_static)
    add_library(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME}_static)
    add_library(${PROJECT_NAME}::static ALIAS ${PROJECT_NAME}_static)
endif()

# -----------------------------------------------------------------------------
# Shared
# -----------------------------------------------------------------------------
if(SHARED_BUILD)
    add_library(${PROJECT_NAME}_shared SHARED ${SOURCE_FILES})
    _common_lib_setup(${PROJECT_NAME}_shared)
    target_compile_options(${PROJECT_NAME}_shared PRIVATE -O3)
    set_target_properties(${PROJECT_NAME}_shared PROPERTIES
        EXPORT_NAME shared
        OUTPUT_NAME "${PROJECT_NAME}")
    target_link_libraries(${PROJECT_NAME}_shared
        PUBLIC  "${SHARED_PACKAGES}"
        PRIVATE "${COVERAGE_LIBS}")

    add_library(${PROJECT_NAME}::shared ALIAS ${PROJECT_NAME}_shared)

    if(NOT STATIC_BUILD)
        add_library(${PROJECT_NAME} ALIAS ${PROJECT_NAME}_shared)
        add_library(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME}_shared)
    endif()
endif()

# -----------------------------------------------------------------------------
# Install
# -----------------------------------------------------------------------------
if(STATIC_BUILD)
    install(TARGETS ${PROJECT_NAME}_static
            EXPORT  ${PROJECT_NAME}Targets
            ARCHIVE DESTINATION ${INSTALL_LIBDIR}
            PUBLIC_HEADER DESTINATION ${INSTALL_INCLUDEDIR})
endif()

if(DEBUG_BUILD)
    install(TARGETS ${PROJECT_NAME}_debug
            EXPORT  ${PROJECT_NAME}Targets
            ARCHIVE DESTINATION ${INSTALL_LIBDIR}
            PUBLIC_HEADER DESTINATION ${INSTALL_INCLUDEDIR})
endif()

if(SHARED_BUILD)
    install(TARGETS ${PROJECT_NAME}_shared
            EXPORT   ${PROJECT_NAME}Targets
            LIBRARY  DESTINATION ${INSTALL_LIBDIR}
            RUNTIME  DESTINATION ${INSTALL_BINDIR}
            PUBLIC_HEADER DESTINATION ${INSTALL_INCLUDEDIR})
endif()

install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include/"
        DESTINATION "${INSTALL_INCLUDEDIR}")

install(EXPORT    ${PROJECT_NAME}Targets
        NAMESPACE ${PROJECT_NAME}::
        FILE      ${PROJECT_NAME}Targets.cmake
        DESTINATION "${_pkg_cmake_dir}")

# -----------------------------------------------------------------------------
# Gather deps → find_dependency()
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
# Config files
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

set(PROJECT_DEPS "${_cfg_deps}")

write_basic_package_version_file(
    "${_ver_out}"
    VERSION       ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion)

configure_file("${_cfg_in}" "${_cfg_out}" @ONLY)

install(FILES
        "${_cfg_out}"
        "${_ver_out}"
        DESTINATION "${_pkg_cmake_dir}")

# -----------------------------------------------------------------------------
# Optional uninstall helper
# -----------------------------------------------------------------------------
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake.in" "
if(NOT EXISTS \"@CMAKE_BINARY_DIR@/install_manifest.txt\")
    message(FATAL_ERROR \"Cannot find install manifest: @CMAKE_BINARY_DIR@/install_manifest.txt\")
endif()
file(READ \"@CMAKE_BINARY_DIR@/install_manifest.txt\" files)
string(REGEX REPLACE \"\\n\" \";\" files \"\${files}\")
foreach(file \"\${files}\")
    message(STATUS \"Uninstalling \$ENV{DESTDIR}\${file}\")
    if(EXISTS \"\$ENV{DESTDIR}\${file}\")
        execute_process(COMMAND @CMAKE_COMMAND@ -E remove \"\$ENV{DESTDIR}\${file}\")
    endif()
endforeach()
")

configure_file(
    "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake" IMMEDIATE @ONLY)

add_custom_target(uninstall
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY  "${CMAKE_BINARY_DIR}/${INSTALL_LIBDIR}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY  "${CMAKE_BINARY_DIR}/${INSTALL_LIBDIR}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY  "${CMAKE_BINARY_DIR}/${INSTALL_BINDIR}")

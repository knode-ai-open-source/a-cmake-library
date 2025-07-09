# SPDX-FileCopyrightText: 2024-2025 Andy Curtis <contactandyc@gmail.com>
# SPDX-FileCopyrightText: 2024-2025 Knode.ai
# SPDX-License-Identifier: Apache-2.0

################################################################################
# LibraryNormal.cmake
#
# This CMake script is used to configure, build, and install a library with
# source files. It supports multiple library variants: debug, static, and shared.
# The script dynamically generates configuration files for seamless consumption.
#
# Features:
# - Supports three library variants:
#   - Debug (`DEBUG_BUILD`): Includes debug flags (`-g -O0`) and debug-specific definitions.
#   - Static (`STATIC_BUILD`): Optimized for performance (`-O3`).
#   - Shared (`SHARED_BUILD`): General-purpose flags (`-O3`).
#
# - Dynamically generates and installs:
#   - Export targets configuration files (`Targets.cmake`).
#   - A version file (`ConfigVersion.cmake`).
#   - A main configuration file (`Config.cmake`).
#
# - Provides uninstall logic for cleaning up installed files.
#
# - Installs:
#   - The built library files (static or shared).
#   - The public headers.
#   - Exported targets for consumer projects.
#
# Key Variables:
# - `PROJECT_NAME`: The name of the library project.
# - `SOURCE_FILES`: List of source files for the library.
# - `INSTALL_INCLUDEDIR`: Directory for installing header files.
# - `INSTALL_LIBDIR`: Directory for installing library files and configuration files.
# - `INSTALL_BINDIR`: Directory for installing runtime files (shared library binaries).
#
# Options:
# - `DEBUG_BUILD` (ON by default): Builds the debug library variant.
# - `STATIC_BUILD` (ON by default): Builds the static library variant.
# - `SHARED_BUILD` (OFF by default): Builds the shared library variant.
#
# Output:
# - Library variants are available with targets:
#   - `${PROJECT_NAME}::debug`
#   - `${PROJECT_NAME}::static`
#   - `${PROJECT_NAME}::shared`
#   - `${PROJECT_NAME}` (defaults to the static variant unless overridden).
#
# Example Usage:
# ```cmake
# cmake_minimum_required(VERSION 3.10)
#
# project(mylibrary VERSION 1.0 LANGUAGES C)
# set(PROJECT_NAME mylibrary)
# set(SOURCE_FILES src/file1.c src/file2.c)
#
# include(LibraryNormal.cmake)
# ```
#
# Notes:
# - Ensure that all source files for the library are provided in `SOURCE_FILES`.
# - Consumers can link to the library using the target aliases provided.
################################################################################

# Debug library
if(DEBUG_BUILD)
    add_library(${PROJECT_NAME}_debug STATIC ${SOURCE_FILES})
    target_include_directories(${PROJECT_NAME}_debug PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:${INSTALL_INCLUDEDIR}>)
    # target_compile_definitions(${PROJECT_NAME}_debug PUBLIC -D_AML_DEBUG_)
    target_compile_options(${PROJECT_NAME}_debug PRIVATE -g -O0)

    set_target_properties(${PROJECT_NAME}_debug PROPERTIES
        EXPORT_NAME debug
        OUTPUT_NAME "${PROJECT_NAME}_debug"
        INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_INSTALL_PREFIX}/${INSTALL_INCLUDEDIR}
    )

    target_link_libraries(${PROJECT_NAME}_debug PUBLIC "${DEBUG_PACKAGES}" PRIVATE "${COVERAGE_LIBS}")

    add_library(${PROJECT_NAME}::debug ALIAS ${PROJECT_NAME}_debug)
    if(NOT STATIC_BUILD AND NOT SHARED_BUILD)
        add_library(${PROJECT_NAME} ALIAS ${PROJECT_NAME}_debug)
        add_library(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME}_debug)
    endif()
endif()

# Static library
if(STATIC_BUILD)
    add_library(${PROJECT_NAME}_static STATIC ${SOURCE_FILES})
    target_include_directories(${PROJECT_NAME}_static PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:${INSTALL_INCLUDEDIR}>)
    target_compile_options(${PROJECT_NAME}_static PRIVATE -O3)

    set_target_properties(${PROJECT_NAME}_static PROPERTIES
        EXPORT_NAME static
        OUTPUT_NAME "${PROJECT_NAME}_static"
        INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_INSTALL_PREFIX}/${INSTALL_INCLUDEDIR}
    )

    target_link_libraries(${PROJECT_NAME}_static PUBLIC "${STATIC_PACKAGES}" PRIVATE "${COVERAGE_LIBS}")

    add_library(${PROJECT_NAME} ALIAS ${PROJECT_NAME}_static)
    add_library(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME}_static)
    add_library(${PROJECT_NAME}::static ALIAS ${PROJECT_NAME}_static)
endif()

# Shared library
if(SHARED_BUILD)
    add_library(${PROJECT_NAME} SHARED ${SOURCE_FILES})
    target_include_directories(${PROJECT_NAME} PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:${INSTALL_INCLUDEDIR}>)
    target_compile_options(${PROJECT_NAME} PRIVATE -O3)

    set_target_properties(${PROJECT_NAME} PROPERTIES
        EXPORT_NAME shared
        OUTPUT_NAME "${PROJECT_NAME}"
        INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_INSTALL_PREFIX}/${INSTALL_INCLUDEDIR}
    )

    target_link_libraries(${PROJECT_NAME}_shared PUBLIC "${SHARED_PACKAGES}" PRIVATE "${COVERAGE_LIBS}")

    add_library(${PROJECT_NAME}::shared ALIAS ${PROJECT_NAME})
    if(NOT STATIC_BUILD)
        add_library(${PROJECT_NAME} ALIAS ${PROJECT_NAME})
        add_library(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME})
    endif()
endif()

# Installation of the libraries
if(STATIC_BUILD)
    install(TARGETS ${PROJECT_NAME}_static
        EXPORT ${PROJECT_NAME}Targets
        ARCHIVE DESTINATION ${INSTALL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${INSTALL_INCLUDEDIR})
endif()

if(DEBUG_BUILD)
    install(TARGETS ${PROJECT_NAME}_debug
        EXPORT ${PROJECT_NAME}Targets
        ARCHIVE DESTINATION ${INSTALL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${INSTALL_INCLUDEDIR})
endif()

if(SHARED_BUILD)
    install(TARGETS ${PROJECT_NAME}
        EXPORT ${PROJECT_NAME}Targets
        LIBRARY DESTINATION ${INSTALL_LIBDIR}
        RUNTIME DESTINATION ${INSTALL_BINDIR}
        PUBLIC_HEADER DESTINATION ${INSTALL_INCLUDEDIR})
endif()

# Export the targets
install(EXPORT ${PROJECT_NAME}Targets
    NAMESPACE ${PROJECT_NAME}::
    FILE ${PROJECT_NAME}Targets.cmake
    DESTINATION ${CMAKE_INSTALL_PREFIX}/share/${PROJECT_NAME}
)

install(
    DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/include/
    DESTINATION ${INSTALL_INCLUDEDIR}
 )

# Generate Config.cmake.in dynamically
file(WRITE "${CMAKE_BINARY_DIR}/${PROJECT_NAME}Config.cmake.in" "
@PACKAGE_INIT@

# Include directory
set(${PROJECT_NAME}_INCLUDE_DIR \"${CMAKE_INSTALL_PREFIX}/${INSTALL_INCLUDEDIR}\")

# Include the exported targets
include(\"\${CMAKE_CURRENT_LIST_DIR}/${PROJECT_NAME}Targets.cmake\")
")

# Generate cmake_uninstall.cmake.in dynamically
file(WRITE "${CMAKE_BINARY_DIR}/cmake_uninstall.cmake.in" "
if(NOT EXISTS \"@CMAKE_BINARY_DIR@/install_manifest.txt\")
    message(FATAL_ERROR \"Cannot find install manifest: @CMAKE_BINARY_DIR@/install_manifest.txt\")
endif()

file(READ \"@CMAKE_BINARY_DIR@/install_manifest.txt\" files)
string(REGEX REPLACE \"\\n\" \";\" files \"\${files}\")
foreach(file \${files})
    message(STATUS \"Uninstalling \$ENV{DESTDIR}\${file}\")
    if(EXISTS \"\$ENV{DESTDIR}\${file}\")
        execute_process(COMMAND @CMAKE_COMMAND@ -E remove \"\$ENV{DESTDIR}\${file}\")
    else()
        message(STATUS \"File \$ENV{DESTDIR}\${file} does not exist.\")
    endif()
endforeach()
")

# Create and install the config files
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

configure_file("${CMAKE_BINARY_DIR}/${PROJECT_NAME}Config.cmake.in"
               "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
               @ONLY)

install(
    FILES
        "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
    DESTINATION ${CMAKE_INSTALL_PREFIX}/share/${PROJECT_NAME}
)

# Uninstall command
configure_file(
    "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
    IMMEDIATE @ONLY
)
add_custom_target(uninstall
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake
)

# Output directories
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${INSTALL_LIBDIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${INSTALL_LIBDIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${INSTALL_BINDIR})

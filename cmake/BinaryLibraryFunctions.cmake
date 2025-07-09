# SPDX-FileCopyrightText: 2024-2025 Andy Curtis <contactandyc@gmail.com>
# SPDX-FileCopyrightText: 2024-2025 Knode.ai
# SPDX-License-Identifier: Apache-2.0

# Add -lm (math library) and -lpthread (thread library) globally
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -lm -lpthread")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -lm -lpthread")
set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -lm -lpthread")

# add_compile_definitions(_GNU_SOURCE)
add_compile_definitions(_GNU_SOURCE)
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
    add_compile_options(-mavx2 -mfma)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "arm")
    add_compile_options(-mfpu=neon)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    message(STATUS "NEON enabled by default on AArch64")
else()
    message(FATAL_ERROR "Unsupported architecture for SIMD")
endif()

if(EXISTS "/opt/homebrew")
    message(STATUS "Homebrew detected at /opt/homebrew")
    include_directories("/opt/homebrew/include")
    link_directories("/opt/homebrew/lib")
endif()

function(is_package_found PACKAGE_NAME OUTPUT_VAR)
    # Default to false
    set(${OUTPUT_VAR} FALSE PARENT_SCOPE)

    # Check if <PACKAGE_NAME>_FOUND exists and is true
    if(DEFINED ${PACKAGE_NAME}_FOUND AND ${PACKAGE_NAME}_FOUND)
        set(${OUTPUT_VAR} TRUE PARENT_SCOPE)
    endif()

    string(TOUPPER "${PACKAGE_NAME}" UPPER_PACKAGE_NAME)
    if(DEFINED ${UPPER_PACKAGE_NAME}_FOUND AND ${UPPER_PACKAGE_NAME}_FOUND)
        set(${OUTPUT_VAR} TRUE PARENT_SCOPE)
    endif()
endfunction()

function(create_imported_package_target TARGET_NAME INCLUDE_DIRS LIBRARIES)
    if(NOT TARGET "${TARGET_NAME}")
        add_library("${TARGET_NAME}" INTERFACE IMPORTED)
        # Include dirs
        set_target_properties("${TARGET_NAME}" PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${INCLUDE_DIRS}"
        )
        # Link libs if any
        if(LIBRARIES)
            set_target_properties("${TARGET_NAME}" PROPERTIES
                INTERFACE_LINK_LIBRARIES "${LIBRARIES}"
            )
        endif()
    endif()
endfunction()

function(find_generic_target TARGET_NAME FOUND_PACKAGE)
    message(STATUS "Trying to find target: \"${TARGET_NAME}\"")

    # Initialize the output variable
    set(${FOUND_PACKAGE} "not_found" PARENT_SCOPE)

    # -----------------------------------------------------------------------
    # We do NOT short-circuit if the target already exists; we still do checks.
    # -----------------------------------------------------------------------

    # Extract potential package names from the target name
    string(REGEX REPLACE "::.*" "" PACKAGE_NAME "${TARGET_NAME}") # prefix
    string(REGEX REPLACE ".*::" "" ACTUAL_NAME "${TARGET_NAME}")  # actual name

    # Try the package name directly
    find_generic_package_quiet("${PACKAGE_NAME}")
    is_package_found("${PACKAGE_NAME}" PACKAGE_FOUND)
    if(PACKAGE_FOUND AND TARGET "${TARGET_NAME}")
        message(STATUS "Found package: \"${PACKAGE_NAME}\" for target: \"${TARGET_NAME}\"")
        set(${FOUND_PACKAGE} "${PACKAGE_NAME}" PARENT_SCOPE)
        return()
    endif()

    # Try the actual name as a package (if different)
    if(NOT "${PACKAGE_NAME}" STREQUAL "${ACTUAL_NAME}")
        find_generic_package_quiet("${ACTUAL_NAME}")
        is_package_found("${ACTUAL_NAME}" PACKAGE_FOUND)
        if(PACKAGE_FOUND AND TARGET "${TARGET_NAME}")
            message(STATUS "Found package: \"${ACTUAL_NAME}\" for target: \"${TARGET_NAME}\"")
            set(${FOUND_PACKAGE} "${ACTUAL_NAME}" PARENT_SCOPE)
            return()
        endif()
    endif()

    # Try searching for CMake config files
    set(CMAKE_FALLBACK_PATHS
        /usr/local/lib/cmake
        /usr/local/share
        /opt/homebrew/lib/cmake
        /usr/lib/cmake
        /usr/share/cmake
    )
    # 1) For PACKAGE_NAME
    foreach(PATH ${CMAKE_FALLBACK_PATHS})
        file(GLOB CMAKE_CONFIG_FILES
            "${PATH}/${PACKAGE_NAME}*/${PACKAGE_NAME}*-config.cmake"
            "${PATH}/${PACKAGE_NAME}*/CMakeLists.txt"
        )
        foreach(CMAKE_CONFIG_FILE ${CMAKE_CONFIG_FILES})
            message(STATUS "Considering CMake config: \"${CMAKE_CONFIG_FILE}\" for \"${PACKAGE_NAME}\"")
            include("${CMAKE_CONFIG_FILE}")
            if(TARGET "${TARGET_NAME}")
                message(STATUS "Found target \"${TARGET_NAME}\" via CMake configuration for package \"${PACKAGE_NAME}\"")
                set(${FOUND_PACKAGE} "${PACKAGE_NAME}" PARENT_SCOPE)
                return()
            endif()
        endforeach()
    endforeach()

    # 2) For ACTUAL_NAME
    if(NOT "${PACKAGE_NAME}" STREQUAL "${ACTUAL_NAME}")
        foreach(PATH ${CMAKE_FALLBACK_PATHS})
            file(GLOB CMAKE_CONFIG_FILES
                "${PATH}/${ACTUAL_NAME}*/${ACTUAL_NAME}*-config.cmake"
                "${PATH}/${ACTUAL_NAME}*/CMakeLists.txt"
            )
            foreach(CMAKE_CONFIG_FILE ${CMAKE_CONFIG_FILES})
                message(STATUS "Considering CMake config: \"${CMAKE_CONFIG_FILE}\" for \"${ACTUAL_NAME}\"")
                include("${CMAKE_CONFIG_FILE}")
                if(TARGET "${TARGET_NAME}")
                    message(STATUS "Found target \"${TARGET_NAME}\" via CMake configuration for package \"${ACTUAL_NAME}\"")
                    set(${FOUND_PACKAGE} "${ACTUAL_NAME}" PARENT_SCOPE)
                    return()
                endif()
            endforeach()
        endforeach()
    endif()

    message(STATUS "Could not find target: \"${TARGET_NAME}\"")
endfunction()

function(_find_generic_package_quiet PACKAGE_NAME FOUND_PACKAGE)
    message(STATUS "Trying to find \"${PACKAGE_NAME}\"")

    # ------------------------------------------------------------------
    # Default: assume we won't find it
    # ------------------------------------------------------------------
    set(${FOUND_PACKAGE} "not_found" PARENT_SCOPE)

    # ------------------------------------------------------------------
    # Handle imported-target names (those containing "::") first
    # ------------------------------------------------------------------
    if("${PACKAGE_NAME}" MATCHES "::")
        # 1) See if the target already exists, or can be found via helper
        find_generic_target("${PACKAGE_NAME}" FOUND_TARGET_PACKAGE)
        if(NOT "${FOUND_TARGET_PACKAGE}" STREQUAL "not_found")
            set(${FOUND_PACKAGE} "${FOUND_TARGET_PACKAGE}" PARENT_SCOPE)
        endif()
        # ▲ NEW:  For target-style names we never fall through to pkg-config
        return()
    endif()

    # ------------------------------------------------------------------
    # Try the classic find_package() search
    # ------------------------------------------------------------------
    find_package("${PACKAGE_NAME}" QUIET)
    if("${PACKAGE_NAME}" STREQUAL "libjwt")
        # List all imported targets that exist right now
        get_property(_afterLibjwt DIRECTORY PROPERTY IMPORTED_TARGETS)
        message(STATUS "[probe] IMPORTED_TARGETS after libjwt: ${_afterLibjwt}")

        # Show the classic variables too
        message(STATUS "[probe] LIBJWT_LIBRARY        = ${LIBJWT_LIBRARY}")
        message(STATUS "[probe] LIBJWT_INCLUDE_DIRS   = ${LIBJWT_INCLUDE_DIRS}")
    endif()

    # ▲ NEW: if the OpenSSL *module* was picked up but imported targets are
    #        still missing, force the CONFIG variant that defines them.
    if("${PACKAGE_NAME}" STREQUAL "OpenSSL" AND NOT TARGET OpenSSL::Crypto)
        find_package(OpenSSL CONFIG REQUIRED)
    endif()

    is_package_found("${PACKAGE_NAME}" PACKAGE_FOUND)
    if(PACKAGE_FOUND)
        # ----- auto-namespace single bare targets -------------------------------
        get_property(_pkg_targets DIRECTORY PROPERTY IMPORTED_TARGETS)
        list(FILTER _pkg_targets INCLUDE REGEX "^[A-Za-z0-9_]+$")   # bare names
        list(LENGTH _pkg_targets _pkg_count)

        # ► DEBUG – show what we discovered
        message(STATUS "[alias] bare targets: ${_pkg_targets}")
        message(STATUS "[alias] count       : ${_pkg_count}")
        message(STATUS "[alias] jwt exists? : $<BOOL:$<TARGET_EXISTS:jwt>>")

        if(_pkg_count EQUAL 1)
            list(GET _pkg_targets 0 _bare)
            set(_alias "${PACKAGE_NAME}::${PACKAGE_NAME}")
            message(STATUS "[alias] creating ${_alias} -> ${_bare}")
            if(NOT TARGET "${_alias}")
                add_library("${_alias}" ALIAS "${_bare}")
            endif()
        endif()

        unset(_pkg_targets)
        unset(_pkg_count)
        unset(_bare)
        unset(_alias)
        # ------------------------------------------------------------------------
        message(STATUS "Found \"${PACKAGE_NAME}\" with find_package")
        #
        # ──────────────────────────────────────────────────────────────────────────
        #  SELF-HEAL FOR “PkgConfig::<module>” PLACE-HOLDER TARGETS
        #
        #  Some packages (libjwt, libepoxy, cairo,…​) ship CMake configs that add
        #  imported targets whose *link interface* refers to
        #       PkgConfig::<MODULE>
        #  but do **not** create that target themselves.  When it’s missing CMake
        #  aborts during configure.  The snippet below scans every imported target
        #  that the newly-found package put in the directory scope; whenever it sees
        #  a `PkgConfig::X` that is *still* undefined it:
        #
        #    1.  runs `pkg_check_modules(X …)`  → this *usually* defines the target;
        #    2.  if it still isn’t there, synthesises a minimal IMPORTED-INTERFACE
        #        target that carries include-dirs and libraries obtained from
        #        pkg-config.
        # ──────────────────────────────────────────────────────────────────────────
        #
        get_property(_new_imported_targets DIRECTORY PROPERTY IMPORTED_TARGETS)

        foreach(_t IN LISTS _new_imported_targets)
            get_target_property(_iface_libs  "${_t}" INTERFACE_LINK_LIBRARIES)

            foreach(_lib IN LISTS _iface_libs)
                if(_lib MATCHES "^PkgConfig::([A-Za-z0-9_\\-]+)$"
                   AND NOT TARGET "${_lib}")

                    set(_pc_mod "${CMAKE_MATCH_1}")

                    # 1) Try to create it via pkg-config
                    find_package(PkgConfig QUIET)
                    if(PKG_CONFIG_FOUND)
                        pkg_check_modules("${_pc_mod}" QUIET "${_pc_mod}")
                    endif()

                    # 2) If it is *still* missing, fall back to a tiny interface lib
                    if(NOT TARGET "${_lib}"
                       AND (DEFINED "${_pc_mod}_LIBRARIES"
                            OR DEFINED "${_pc_mod}_INCLUDE_DIRS"))
                        create_imported_package_target(
                            "${_lib}"
                            "${${_pc_mod}_INCLUDE_DIRS}"
                            "${${_pc_mod}_LIBRARIES}"
                        )
                        message(STATUS
                            "[fixup] synthesised ${_lib} "
                            "(incl=${${_pc_mod}_INCLUDE_DIRS}; "
                            "libs=${${_pc_mod}_LIBRARIES})")
                    endif()
                endif()
            endforeach()
        endforeach()

        unset(_new_imported_targets)
        unset(_iface_libs)
        unset(_lib)
        unset(_pc_mod)
        # ──────────────────────────────────────────────────────────────────────────

        set(${FOUND_PACKAGE} "${PACKAGE_NAME}" PARENT_SCOPE)

        if("${PACKAGE_NAME}" STREQUAL "libjwt")
            # If the upstream config gave us LibJWT::jwt, alias it.
            if(TARGET LibJWT::jwt AND NOT TARGET libjwt::libjwt)
                message(STATUS "[fixup] aliasing libjwt::libjwt -> LibJWT::jwt")
                add_library(libjwt::libjwt ALIAS LibJWT::jwt)
            endif()

            # If we later create (or already have) a bare 'jwt' target, alias that.
            if(TARGET jwt AND NOT TARGET libjwt::libjwt)
                message(STATUS "[fixup] aliasing libjwt::libjwt -> jwt")
                add_library(libjwt::libjwt ALIAS jwt)
            endif()

            # As a last resort create an IMPORTED library yourself when nothing exists.
            if(NOT TARGET libjwt::libjwt AND NOT TARGET LibJWT::jwt AND NOT TARGET jwt)
                message(STATUS "[fixup] creating IMPORTED target jwt and alias")
                add_library(jwt UNKNOWN IMPORTED)
                # Adjust these two paths to your installation prefix if necessary
                set_target_properties(jwt PROPERTIES
                    IMPORTED_LOCATION "/usr/local/opt/libjwt/lib/libjwt.dylib"
                    INTERFACE_INCLUDE_DIRECTORIES "/usr/local/opt/libjwt/include")
                add_library(libjwt::libjwt ALIAS jwt)
            endif()
        endif()

        return()
    endif()

    # ------------------------------------------------------------------
    # Fallback to pkg-config  (only for plain names — see early return)
    # ------------------------------------------------------------------
    if(NOT PKG_CONFIG_FOUND)
        find_package(PkgConfig QUIET)
        if (NOT PKG_CONFIG_FOUND)
            message(FATAL_ERROR "pkg-config not found")
        endif()
    endif()

    if(PKG_CONFIG_FOUND)
        pkg_check_modules("${PACKAGE_NAME}" QUIET "${PACKAGE_NAME}")
        is_package_found("${PACKAGE_NAME}" PACKAGE_FOUND)
        if(PACKAGE_FOUND)
            message(STATUS "Found \"${PACKAGE_NAME}\" with pkg-config")
            string(TOLOWER "${PACKAGE_NAME}" LOWER_NAME)
            set(TGT_NAME "${LOWER_NAME}::${LOWER_NAME}")
            create_imported_package_target(
                "${TGT_NAME}"
                "${${PACKAGE_NAME}_INCLUDE_DIRS}"
                "${${PACKAGE_NAME}_LIBRARIES}"
            )
            set(${FOUND_PACKAGE} "${PACKAGE_NAME}" PARENT_SCOPE)
            return()
        endif()
    endif()

    # ------------------------------------------------------------------
    # Last-chance scan of typical CMake install paths
    # ------------------------------------------------------------------
    set(CMAKE_FALLBACK_PATHS
        /usr/local/lib/cmake
        /usr/local/share
        /opt/homebrew/lib/cmake
        /usr/lib/cmake
        /usr/share/cmake
        ${CMAKE_CUSTOM_PACKAGE_PATHS}
    )
    foreach(PATH ${CMAKE_FALLBACK_PATHS})
        file(GLOB CMAKE_CONFIG_FILES
            "${PATH}/${PACKAGE_NAME}*/${PACKAGE_NAME}*-config.cmake"
            "${PATH}/${PACKAGE_NAME}*/CMakeLists.txt"
        )
        foreach(CMAKE_CONFIG_FILE ${CMAKE_CONFIG_FILES})
            message(STATUS "Considering CMake configuration file: \"${CMAKE_CONFIG_FILE}\"")
            include("${CMAKE_CONFIG_FILE}")
            is_package_found("${PACKAGE_NAME}" PACKAGE_FOUND)
            if(PACKAGE_FOUND)
                message(STATUS "Successfully included \"${CMAKE_CONFIG_FILE}\" for \"${PACKAGE_NAME}\"")
                set(${FOUND_PACKAGE} "${PACKAGE_NAME}" PARENT_SCOPE)
                return()
            endif()
        endforeach()
    endforeach()

    # ------------------------------------------------------------------
    # Still not found
    # ------------------------------------------------------------------
    message(STATUS "Could not find \"${PACKAGE_NAME}\"")
endfunction()


function(find_generic_package_quiet PACKAGE_NAME)
    _find_generic_package_quiet("${PACKAGE_NAME}" FOUND_PACKAGE)
    if(NOT "${FOUND_PACKAGE}" STREQUAL "not_found")
        message(STATUS "Found package: \"${FOUND_PACKAGE}\"")
        string(TOUPPER "${FOUND_PACKAGE}" UPPER_FOUND_PACKAGE)
        string(TOUPPER "${PACKAGE_NAME}" UPPER_PACKAGE_NAME)
        set("${PACKAGE_NAME}_FOUND" TRUE PARENT_SCOPE)
        if(NOT "${UPPER_PACKAGE_NAME}" STREQUAL "${PACKAGE_NAME}")
            set("${UPPER_PACKAGE_NAME}_FOUND" TRUE PARENT_SCOPE)
        endif()
        if(NOT "${UPPER_FOUND_PACKAGE}" STREQUAL "${UPPER_PACKAGE_NAME}")
            set("${FOUND_PACKAGE}_FOUND" TRUE PARENT_SCOPE)
            if(NOT "${UPPER_FOUND_PACKAGE}" STREQUAL "${FOUND_PACKAGE}")
                set("${UPPER_FOUND_PACKAGE}_FOUND" TRUE PARENT_SCOPE)
            endif()
        endif()
    endif()
endfunction()

function(find_generic_package PACKAGE_NAME)
    _find_generic_package_quiet("${PACKAGE_NAME}" FOUND_PACKAGE)
    if("${FOUND_PACKAGE}" STREQUAL "not_found")
        message(FATAL_ERROR "Could not find package: \"${PACKAGE_NAME}\"")
    else()
        message(STATUS "Found package: \"${FOUND_PACKAGE}\"")
        string(TOUPPER "${FOUND_PACKAGE}" UPPER_FOUND_PACKAGE)
        string(TOUPPER "${PACKAGE_NAME}" UPPER_PACKAGE_NAME)
        set("${PACKAGE_NAME}_FOUND" TRUE PARENT_SCOPE)
        if(NOT "${UPPER_PACKAGE_NAME}" STREQUAL "${PACKAGE_NAME}")
            set("${UPPER_PACKAGE_NAME}_FOUND" TRUE PARENT_SCOPE)
        endif()
        if(NOT "${UPPER_FOUND_PACKAGE}" STREQUAL "${UPPER_PACKAGE_NAME}")
            set("${FOUND_PACKAGE}_FOUND" TRUE PARENT_SCOPE)
            if(NOT "${UPPER_FOUND_PACKAGE}" STREQUAL "${FOUND_PACKAGE}")
                set("${UPPER_FOUND_PACKAGE}_FOUND" TRUE PARENT_SCOPE)
            endif()
        endif()
    endif()
endfunction()

function(is_header_only_library TARGET RESULT_VAR)
    set(${RESULT_VAR} FALSE PARENT_SCOPE)
    message(STATUS "Checking if ${TARGET}::${TARGET} is a header-only library")
    if(TARGET ${TARGET}::debug)
        message(STATUS "Found ${TARGET}::debug")
        set(${RESULT_VAR} FALSE PARENT_SCOPE)
    else()
        message(STATUS "Header only library ${TARGET}::${TARGET}")
        set(${RESULT_VAR} TRUE PARENT_SCOPE)
    endif()
endfunction()

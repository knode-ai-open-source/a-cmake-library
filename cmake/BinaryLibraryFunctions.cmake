# SPDX-FileCopyrightText: 2024-2025 Andy Curtis <contactandyc@gmail.com>
# SPDX-FileCopyrightText: 2024-2025 Knode.ai
# SPDX-License-Identifier: Apache-2.0

# -----------------------------------------------------------------------------
# Minimal, portable defaults
# -----------------------------------------------------------------------------
add_compile_definitions(_GNU_SOURCE)

# SIMD / CPU‑specific opts – **only** when the host tool‑chain can accept them
include(CheckCCompilerFlag)

if (NOT CMAKE_CROSSCOMPILING AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
    if (CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
        check_c_compiler_flag("-mavx2"  _HAS_MAVX2)
        check_c_compiler_flag("-mfma"   _HAS_MFMA)
        if (_HAS_MAVX2)
            add_compile_options(-mavx2)
        endif()
        if (_HAS_MFMA)
            add_compile_options(-mfma)
        endif()
    elseif (CMAKE_SYSTEM_PROCESSOR MATCHES "arm")
        check_c_compiler_flag("-mfpu=neon" _HAS_NEON)
        if (_HAS_NEON)
            add_compile_options(-mfpu=neon)
        endif()
    endif()
endif()

# Homebrew helper (macOS)
if (EXISTS "/opt/homebrew")
    message(STATUS "Homebrew detected at /opt/homebrew")
    include_directories("/opt/homebrew/include")
    link_directories("/opt/homebrew/lib")
endif()

# -----------------------------------------------------------------------------
# Utility: check if a *find_package* set a FOUND variable
# -----------------------------------------------------------------------------
function(is_package_found PACKAGE_NAME OUTPUT_VAR)
    set(${OUTPUT_VAR} FALSE PARENT_SCOPE)
    if(DEFINED ${PACKAGE_NAME}_FOUND AND ${PACKAGE_NAME}_FOUND)
        set(${OUTPUT_VAR} TRUE PARENT_SCOPE)
    endif()
    string(TOUPPER "${PACKAGE_NAME}" UPPER)
    if(DEFINED ${UPPER}_FOUND AND ${UPPER}_FOUND)
        set(${OUTPUT_VAR} TRUE PARENT_SCOPE)
    endif()
endfunction()

# ------------------------------------------------------------------------------
# create_imported_package_target
#
# Makes a tiny INTERFACE IMPORTED target when the upstream CMake / pkg-config
# file didn’t create one itself.  In addition to the include-directories it
# now tries to resolve every bare   jansson   openssl   gnutls   …  token to the
# *full path* of the real library, and publishes that path (or at least its
# parent directory) so the link-step never needs a global  link_directories().
#
# Usage:
#   create_imported_package_target(
#        <new-target-name>            # e.g.   jansson::jansson
#        "<include-dir>;<include2>"   # include search path(s)
#        "<libA>;<libB>"              # what the .pc file exposed
#   )
# ------------------------------------------------------------------------------
function(create_imported_package_target TARGET_NAME INCLUDE_DIRS LIBRARIES)
    # Skip if someone already provided a proper target
    if(TARGET "${TARGET_NAME}")
        return()
    endif()

    add_library("${TARGET_NAME}" INTERFACE IMPORTED)

    # --------------------------------------------------------  include-dirs
    if(INCLUDE_DIRS)
        set_target_properties("${TARGET_NAME}" PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${INCLUDE_DIRS}")
    endif()

    # --------------------------------------------------------  resolve libs
    set(_resolved_libs "")      # what we’ll publish
    set(_link_dirs     "")      # extra -L path(s) to expose, if any

    foreach(_lib IN LISTS LIBRARIES)
        # ---------------------------------------------------------------
        # 1) Already a full path / imported target / file‑name → keep verbatim
        # ---------------------------------------------------------------
        if(_lib MATCHES "^/.*"                # absolute path
           OR _lib MATCHES "\\.(a|so|dylib)$" # explicit file
           OR _lib MATCHES "::"               # imported target
        )
            list(APPEND _resolved_libs "${_lib}")
            continue()
        endif()

        # ---------------------------------------------------------------
        # 2) Handle the pkg‑config style “‑lname”  →  name = <match 1>
        # ---------------------------------------------------------------
        if(_lib MATCHES "^-l(.+)$")
            set(_basename "${CMAKE_MATCH_1}")
        else()
            set(_basename "${_lib}")
        endif()

        # ---------------------------------------------------------------
        # 3) Try to locate a real file lib<basename>.(so|dylib|a)
        # ---------------------------------------------------------------
        find_library(
            _full_path
            NAMES        "${_basename}"
            PATHS        /usr/local/lib /opt/homebrew/lib /usr/lib /usr/local/opt
        )

        if(_full_path)
            list(APPEND _resolved_libs "${_full_path}")
            get_filename_component(_dir "${_full_path}" DIRECTORY)
            list(APPEND _link_dirs "${_dir}")
        else()
            # couldn’t resolve → leave token untouched
            list(APPEND _resolved_libs "${_lib}")
        endif()
    endforeach()

    # --------------------------------------------------------  publish props
    if(_resolved_libs)
        list(REMOVE_DUPLICATES _resolved_libs)
        set_target_properties("${TARGET_NAME}" PROPERTIES
            INTERFACE_LINK_LIBRARIES "${_resolved_libs}")
    endif()

    if(_link_dirs)
        list(REMOVE_DUPLICATES _link_dirs)
        set_target_properties("${TARGET_NAME}" PROPERTIES
            INTERFACE_LINK_DIRECTORIES "${_link_dirs}")
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

function(_ensure_pkgconfig_target MODULE_NAME)
    # 1. Run pkg‑config (once) to fill <MOD>_INCLUDE_DIRS / _LIBRARIES
    find_package(PkgConfig QUIET)
    if (PKG_CONFIG_FOUND)
        pkg_check_modules(${MODULE_NAME} QUIET ${MODULE_NAME})
    endif()

    # 2. Always build (or replace) the PkgConfig::<MOD> interface target
    set(_pc_target "PkgConfig::${MODULE_NAME}")
    create_imported_package_target(
        "${_pc_target}"
        "${${MODULE_NAME}_INCLUDE_DIRS}"
        "${${MODULE_NAME}_LIBRARIES}"
    )

    # 3. (optional) also provide a shorter <mod>::<mod> alias
    string(TOLOWER "${MODULE_NAME}" _lower)
    set(_alias "${_lower}::${_lower}")
    if(NOT TARGET "${_alias}")
        add_library("${_alias}" ALIAS "${_pc_target}")
    endif()
endfunction()



function(_find_generic_package_quiet PACKAGE_NAME FOUND_PACKAGE)
  message(STATUS "Trying to find \"${PACKAGE_NAME}\"")
  # assume failure by default
  set(${FOUND_PACKAGE} "not_found" PARENT_SCOPE)

  # ────────────────────────────────────────────────────────────────────────────
  # 0) FAST PATH: if *any* of the common targets already exist, accept & mark
  #    the package as FOUND. This happens when another package's Config.cmake
  #    called find_dependency(${PACKAGE_NAME}) for us.
  # ────────────────────────────────────────────────────────────────────────────
  foreach(_cand
          "${PACKAGE_NAME}::${PACKAGE_NAME}"
          "${PACKAGE_NAME}::static"
          "${PACKAGE_NAME}::shared"
          "${PACKAGE_NAME}::debug")
    if(TARGET "${_cand}")
      message(STATUS "[fast-path] ${PACKAGE_NAME} already available as target \"${_cand}\"")
      string(TOUPPER "${PACKAGE_NAME}" _UP)
      set(${PACKAGE_NAME}_FOUND TRUE PARENT_SCOPE)
      set(${_UP}_FOUND          TRUE PARENT_SCOPE)
      set(${FOUND_PACKAGE} "${PACKAGE_NAME}" PARENT_SCOPE)
      return()
    endif()
  endforeach()

  #
  # 1) If the caller literally passed a ::‑qualified target, try that and return
  #
  if("${PACKAGE_NAME}" MATCHES "::")
    find_generic_target("${PACKAGE_NAME}" FOUND)
    if(NOT "${FOUND}" STREQUAL "not_found")
      set(${FOUND_PACKAGE} "${FOUND}" PARENT_SCOPE)
    endif()
    return()
  endif()

  #
  # 2) Snapshot which IMPORTED_TARGETS exist right now
  #
  get_property(_before_targets DIRECTORY PROPERTY IMPORTED_TARGETS)

  #
  # 3) Try the normal find_package
  #
  find_package("${PACKAGE_NAME}" QUIET)

  #
  # 4) OpenSSL sometimes only shows up under CONFIG mode
  #
  if("${PACKAGE_NAME}" STREQUAL "OpenSSL" AND NOT TARGET OpenSSL::Crypto)
    find_package(OpenSSL CONFIG REQUIRED)
  endif()

  #
  # 5) Snapshot again, and compute the *new* imported targets
  #
  get_property(_after_targets DIRECTORY PROPERTY IMPORTED_TARGETS)
  set(_new_targets)
  foreach(_t IN LISTS _after_targets)
    list(FIND _before_targets "${_t}" _idx)
    if(_idx EQUAL -1 AND NOT _t MATCHES "^PkgConfig::")
      list(APPEND _new_targets "${_t}")
    endif()
  endforeach()

  # after you compute _new_targets from find_package()
  foreach(_tgt IN LISTS _new_targets)
    get_target_property(_iface_libs "${_tgt}" INTERFACE_LINK_LIBRARIES)
    foreach(_dep IN LISTS _iface_libs)
      if(_dep MATCHES "^PkgConfig::([A-Za-z0-9_\\-]+)$" AND NOT TARGET "${_dep}")
        _ensure_pkgconfig_target("${CMAKE_MATCH_1}")
        message(STATUS "[fixup] imported pkg‑config dependency ${CMAKE_MATCH_1} → ${_dep}")
      endif()
    endforeach()
  endforeach()

  if(_new_targets)
    message(STATUS "find_package(${PACKAGE_NAME}) added targets: ${_new_targets}")

    #
    # 6) Special‑case libjwt → alias LibJWT::jwt → libjwt::libjwt (and bare jwt)
    #
    if("${PACKAGE_NAME}" STREQUAL "libjwt")
      if(TARGET LibJWT::jwt AND NOT TARGET libjwt::libjwt)
        add_library(libjwt::libjwt ALIAS LibJWT::jwt)
      endif()
      if(TARGET jwt AND NOT TARGET libjwt::libjwt)
        add_library(libjwt::libjwt ALIAS jwt)
      endif()
    endif()

    #
    # 7) SELF‑HEAL: for each new target, pull in any PkgConfig::FOO deps it lists
    #
    foreach(_tgt IN LISTS _new_targets)
      get_target_property(_iface_libs "${_tgt}" INTERFACE_LINK_LIBRARIES)
      foreach(_dep IN LISTS _iface_libs)
        if(_dep MATCHES "^PkgConfig::([A-Za-z0-9_-]+)$")
          set(_mod "${CMAKE_MATCH_1}")
          find_package(PkgConfig QUIET)
          if(PKG_CONFIG_FOUND)
            pkg_check_modules("${_mod}" QUIET "${_mod}")
            if(DEFINED ${_mod}_LIBRARIES OR DEFINED ${_mod}_INCLUDE_DIRS)
              string(TOLOWER "${_mod}" _lower)
              set(_alias "${_lower}::${_lower}")
              create_imported_package_target(
                "${_alias}"
                "${${_mod}_INCLUDE_DIRS}"
                "${${_mod}_LIBRARIES}"
              )
              message(STATUS "[fixup] imported pkg‑config dependency ${_mod} → ${_alias}")
            endif()
          endif()
        endif()
      endforeach()
    endforeach()

    #
    # 8) If exactly one of the new targets is named “Pkg::Pkg”, auto‑alias Pkg::Pkg → that
    #
    list(FILTER _new_targets INCLUDE REGEX "^${PACKAGE_NAME}::")
    list(LENGTH  _new_targets _count)
    if(_count EQUAL 1)
      list(GET _new_targets 0 _only)
      set(_alias "${PACKAGE_NAME}::${PACKAGE_NAME}")
      if(NOT TARGET "${_alias}")
        message(STATUS "Auto‑aliasing ${_alias} → ${_only}")
        add_library("${_alias}" ALIAS "${_only}")
      endif()
    endif()

    # Mark FOUND
    string(TOUPPER "${PACKAGE_NAME}" _UP)
    set(${PACKAGE_NAME}_FOUND TRUE PARENT_SCOPE)
    set(${_UP}_FOUND          TRUE PARENT_SCOPE)
    set(${FOUND_PACKAGE} "${PACKAGE_NAME}" PARENT_SCOPE)
    return()
  endif()

  #
  # 9) Fallback: pkg‑config for plain names
  #
  find_package(PkgConfig QUIET)
  if(PKG_CONFIG_FOUND)
    pkg_check_modules("${PACKAGE_NAME}" QUIET "${PACKAGE_NAME}")
    if(DEFINED ${PACKAGE_NAME}_LIBRARIES OR DEFINED ${PACKAGE_NAME}_INCLUDE_DIRS)
      string(TOLOWER "${PACKAGE_NAME}" _lower)
      set(_alias "${_lower}::${_lower}")
      create_imported_package_target(
        "${_alias}"
        "${${PACKAGE_NAME}_INCLUDE_DIRS}"
        "${${PACKAGE_NAME}_LIBRARIES}"
      )
      message(STATUS "Found \"${PACKAGE_NAME}\" via pkg‑config → alias ${_alias}")
      string(TOUPPER "${PACKAGE_NAME}" _UP)
      set(${PACKAGE_NAME}_FOUND TRUE PARENT_SCOPE)
      set(${_UP}_FOUND          TRUE PARENT_SCOPE)
      set(${FOUND_PACKAGE} "${PACKAGE_NAME}" PARENT_SCOPE)
      return()
    endif()
  endif()

  #
  # 10) Last chance: scan common <pkg>-config.cmake paths
  #
  foreach(_path IN LISTS
      /usr/local/lib/cmake
      /usr/local/share
      /opt/homebrew/lib/cmake
      /usr/lib/cmake
      /usr/share/cmake
      ${CMAKE_CUSTOM_PACKAGE_PATHS}
    )
    file(GLOB _cfgs
      "${_path}/${PACKAGE_NAME}*/${PACKAGE_NAME}*-config.cmake"
      "${_path}/${PACKAGE_NAME}*/CMakeLists.txt"
    )
    foreach(_cfg IN LISTS _cfgs)
      message(STATUS "Considering CMake config: \"${_cfg}\"")
      include("${_cfg}")
      foreach(_cand
              "${PACKAGE_NAME}::${PACKAGE_NAME}"
              "${PACKAGE_NAME}::static"
              "${PACKAGE_NAME}::shared"
              "${PACKAGE_NAME}::debug")
        if(TARGET "${_cand}")
          message(STATUS "Found target via ${_cfg}: ${_cand}")
          string(TOUPPER "${PACKAGE_NAME}" _UP)
          set(${PACKAGE_NAME}_FOUND TRUE PARENT_SCOPE)
          set(${_UP}_FOUND          TRUE PARENT_SCOPE)
          set(${FOUND_PACKAGE} "${PACKAGE_NAME}" PARENT_SCOPE)
          return()
        endif()
      endforeach()
    endforeach()
  endforeach()

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
    # default
    set(${RESULT_VAR} FALSE PARENT_SCOPE)

    message(STATUS "Checking if ${TARGET} is a header-only library")

    # If *any* compiled variant exists, it's not header-only
    if(TARGET ${TARGET}::debug OR TARGET ${TARGET}::static OR TARGET ${TARGET}::shared)
        message(STATUS "Found a compiled variant of ${TARGET} → NOT header-only")
        set(${RESULT_VAR} FALSE PARENT_SCOPE)
        return()
    endif()

    # If the canonical target exists and it's an INTERFACE lib, treat as header-only
    if(TARGET ${TARGET}::${TARGET})
        get_target_property(_t ${TARGET}::${TARGET} TYPE)
        if(_t STREQUAL "INTERFACE_LIBRARY")
            message(STATUS "Header only library ${TARGET}::${TARGET}")
            set(${RESULT_VAR} TRUE PARENT_SCOPE)
        endif()
    endif()
endfunction()

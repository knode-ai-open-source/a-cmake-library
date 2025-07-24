# SPDX-FileCopyrightText: 2024-2025 Andy Curtis <contactandyc@gmail.com>
# SPDX-FileCopyrightText: 2024-2025 Knode.ai
# SPDX-License-Identifier: Apache-2.0

################################################################################
# Code Coverage Configuration
#
# This section configures code coverage options for the build if
# ENABLE_CODE_COVERAGE is set to ON. It checks for compiler support for
# coverage flags and falls back to tools like llvm-cov or gcov if direct
# support is unavailable. If no suitable coverage tool is found, a warning
# is issued, and coverage is disabled.
#
# Key Steps:
# 1. Checks if the `--coverage` flag is supported by the compiler.
# 2. Adds the necessary compile and link options for coverage instrumentation.
# 3. Tries to locate `llvm-cov` or `gcov` as fallback tools.
# 4. Adds coverage flags appropriate for the tool found (`-fprofile-arcs`,
#    `-ftest-coverage`, etc.).
# 5. Displays a warning and disables coverage if no suitable tool is found.
################################################################################
if (ENABLE_CODE_COVERAGE)
    include(CheckCXXCompilerFlag)
    check_cxx_compiler_flag("--coverage" HAS_COVERAGE_FLAG)

    # Compile‑time instrumentation ------------------------------------------------
    if (HAS_COVERAGE_FLAG)
        add_compile_options(--coverage)
        set(COVERAGE_LIBS "--coverage")
    else()
        find_program(LLVM_COV_EXECUTABLE llvm-cov QUIET)
        find_program(GCOV_EXECUTABLE   gcov     QUIET)

        if (LLVM_COV_EXECUTABLE)
            add_compile_options(-fprofile-instr-generate -fcoverage-mapping)
            set(COVERAGE_LIBS "-fprofile-instr-generate;-fcoverage-mapping")
        elseif (GCOV_EXECUTABLE)
            add_compile_options(-fprofile-arcs -ftest-coverage)
            set(COVERAGE_LIBS "-fprofile-arcs;-ftest-coverage")
        else()
            message(WARNING "No suitable code‑coverage tool found – disabling coverage.")
            set(ENABLE_CODE_COVERAGE OFF)
            set(COVERAGE_LIBS "")
        endif()
    endif()
else()
    set(COVERAGE_LIBS "")
endif()

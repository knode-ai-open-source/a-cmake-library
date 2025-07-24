# SPDX-FileCopyrightText: 2024-2025 Andy Curtis <contactandyc@gmail.com>
# SPDX-FileCopyrightText: 2024-2025 Knode.ai
# SPDX-License-Identifier: Apache-2.0

################################################################################
# Code Coverage Report Generation
#
# This section creates a custom target `coverage` to generate code coverage
# reports if ENABLE_CODE_COVERAGE is set to ON. It utilizes tools such as
# `lcov`, `genhtml`, `llvm-cov`, or `gcov`, depending on availability, to
# capture and process coverage data. If no suitable tool is found, a warning
# is issued, and coverage report generation is disabled.
#
# Key Steps:
# 1. Locates tools like `genhtml`, `lcov`, `llvm-cov`, or `gcov`.
# 2. Generates coverage reports using the best available tool:
#    - `lcov` and `genhtml` for HTML-based coverage reports.
#    - `llvm-cov` for reports compatible with LLVM profiling.
#    - `gcov` for basic text-based coverage analysis.
# 3. Ensures reports are stored in a designated directory (`coverage-report`).
# 4. Issues a warning if no tools are found, disabling the `coverage` target.
#
# Notes:
# - Requires lcov/genhtml or equivalent tools to be installed for enhanced
#   HTML-based reports.
# - Compatible with compilers that support coverage instrumentation flags.
################################################################################

if(ENABLE_CODE_COVERAGE)

    # Ensure compiler flag check variable exists
    if(NOT DEFINED HAS_COVERAGE_FLAG)
        set(HAS_COVERAGE_FLAG FALSE)
    endif()

    # Locate tools (they might already be cached from CodeCoverage.cmake)
    find_program(LCOV_EXECUTABLE   lcov)
    find_program(GENHTML_EXECUTABLE genhtml)
    find_program(LLVM_COV_EXECUTABLE llvm-cov)
    find_program(GCOV_EXECUTABLE   gcov)

    # ──────────────────────────────────────────────────────────────────────────
    # Preferred path: compiler supports --coverage AND we have lcov & genhtml
    # ──────────────────────────────────────────────────────────────────────────
    if(HAS_COVERAGE_FLAG AND LCOV_EXECUTABLE AND GENHTML_EXECUTABLE)

        add_custom_target(coverage
            COMMAND ${LCOV_EXECUTABLE}  --capture
                                         --directory ${CMAKE_BINARY_DIR}
                                         --output-file coverage.info
            COMMAND ${LCOV_EXECUTABLE}  --remove  coverage.info '/usr/*'
                                         "${CMAKE_BINARY_DIR}/*"
                                         --output-file coverage.info
            COMMAND ${GENHTML_EXECUTABLE} coverage.info
                                          --output-directory coverage-report
            WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
            COMMENT "Generating coverage report with lcov/genhtml")

    # ──────────────────────────────────────────────────────────────────────────
    # Fallback: llvm‑cov
    # ──────────────────────────────────────────────────────────────────────────
    elseif(LLVM_COV_EXECUTABLE)

        # Reports for every target can get messy.  Here we assume the primary
        # target has the project name; adjust if necessary.
        add_custom_target(coverage
            COMMAND ${LLVM_COV_EXECUTABLE} report
                     --instr-profile=coverage.profdata
                     --object $<TARGET_FILE:${PROJECT_NAME}>
            WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
            COMMENT "Generating coverage report with llvm-cov")

    # ──────────────────────────────────────────────────────────────────────────
    # Last resort: gcov
    # ──────────────────────────────────────────────────────────────────────────
    elseif(GCOV_EXECUTABLE)

        add_custom_target(coverage
            COMMAND ${CMAKE_COMMAND} -E make_directory coverage-report
            COMMAND ${GCOV_EXECUTABLE} -b -r
                    $(find ${CMAKE_BINARY_DIR} -name \"*.gcno\") >
                    coverage-report/coverage.txt
            WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
            COMMENT "Generating coverage report with gcov")

    else()
        message(WARNING "No suitable code‑coverage tool found; 'coverage' "
                        "target will not be created.")
    endif()

endif()


# SPDX-FileCopyrightText: 2024-2025 Andy Curtis <contactandyc@gmail.com>
# SPDX-FileCopyrightText: 2024-2025 Knode.ai
# SPDX-License-Identifier: Apache-2.0

################################################################################
# Library Configuration Selection
#
# This section dynamically selects and includes the appropriate configuration
# file for the library based on the presence and content of `SOURCE_FILES`.
#
# Logic:
# - If `SOURCE_FILES` is defined and contains one or more source files, the
#   script assumes the library is a standard (non-header-only) library and
#   includes `LibraryNormal.cmake`.
# - If `SOURCE_FILES` is undefined or empty, the script assumes the library is
#   header-only and includes `LibraryHeaderOnly.cmake`.
#
# Notes:
# - This approach allows for a single configuration setup to handle both
#   header-only and standard libraries without manual intervention.
# - Ensure `SOURCE_FILES` is correctly set before including this script to
#   avoid misconfiguration.
################################################################################

# Check if SOURCE_FILES is defined and not empty
if(DEFINED SOURCE_FILES AND SOURCE_FILES)
    # Include the configuration for a normal library
    include(${CMAKE_CURRENT_LIST_DIR}/LibraryNormal.cmake)
else()
    # Include the configuration for a header-only library
    include(${CMAKE_CURRENT_LIST_DIR}/LibraryHeaderOnly.cmake)
endif()
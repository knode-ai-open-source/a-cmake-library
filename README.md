# A CMake Library - README

This repository contains a collection of CMake scripts designed to streamline building **C libraries** (both header-only and compiled), as well as associated executables and tests. The primary goal is to provide a flexible, modular approach to configuring, compiling, and installing libraries and binaries with minimal boilerplate.

## Table of Contents

1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Directory Structure](#directory-structure)
4. [Prerequisites](#prerequisites)
5. [Basic Usage](#basic-usage)
6. [Building Libraries](#building-libraries)
7. [Building Executables / Utilities](#building-executables--utilities)
8. [Building & Running Tests](#building--running-tests)
9. [Code Coverage](#code-coverage)
10. [Installation & Uninstallation](#installation--uninstallation)
11. [Example Projects](#example-projects)
12. [Advanced Configuration Options](#advanced-configuration-options)
13. [Troubleshooting](#troubleshooting)
14. [License](#license)

---

## Overview

These CMake modules aim to make it simple to:

- Build a **header-only** or **compiled** C library (static or shared, with optional debug variant).
- Configure **executables** or **utilities** that depend on the libraries.
- Enable testing frameworks and register C tests.
- Handle **code coverage** instrumentation and report generation.
- Provide easy installation/uninstallation targets.

---

## Key Features

- **Header-Only or Normal Libraries**: Automatically switch between building header-only or compiled libraries based on whether source files are specified.
- **Multiple Build Options**:
  - Static Library (`STATIC_BUILD`)
  - Shared Library (`SHARED_BUILD`)
  - Debug Library (`DEBUG_BUILD`)
- **Code Coverage** (optional): Supports multiple coverage tools (GCC’s `gcov`, LLVM’s `llvm-cov`, or the `--coverage` compiler flag).
- **Easy Exports & Installs**: Generates `Targets.cmake`, `Config.cmake`, and `ConfigVersion.cmake` files for easy consumption in other projects.
- **Utility/Executable Handling**: Facilities for linking executables against the configured libraries.
- **Package & Dependencies**: Built-in logic for including custom or third-party packages.

---

## Directory Structure

A typical directory layout for using these CMake scripts could look like this:

```
your-project/
├── CMakeLists.txt
├── include/
│   └── your_header_files.h
├── src/
│   ├── your_source_files.c
│   └── …
├── tests/
│   └── test_source.c
├── cmake/
│   └── (optionally place these a-cmake-library scripts here if local)
└── …
```

If you cloned or installed the **a-cmake-library** scripts separately, you might reference them via a system path or `find_package(a-cmake-library REQUIRED)`.

---

## Prerequisites

1. **CMake 3.10 or newer** (some advanced features rely on modern CMake behavior).
2. A supported **C compiler** (GCC, Clang, or MSVC, though coverage or sanitizer flags may vary by compiler).
3. **Optional:** Tools for coverage reports, e.g.:
   - `lcov`, `genhtml` (for HTML-based coverage reports).
   - `llvm-cov`, `gcov`.

---

## Basic Usage

1. **Acquire** the **a-cmake-library** modules (either by copying them into your project’s `cmake/` directory, or by installing them as a package).
2. In your `CMakeLists.txt`, ensure you have:

```cmake
cmake_minimum_required(VERSION 3.10)
project(my-awesome-library VERSION 1.0 LANGUAGES C)

# (1) Locate the a-cmake-library
find_package(a-cmake-library REQUIRED)

# (2) Include the desired scripts
# For libraries:
include(LibraryConfig)  # Common library configuration
include(LibraryBuild)   # Chooses between normal or header-only library

# For executables or tests:
# include(BinaryConfig)

# (3) Define your source files
# set(SOURCE_FILES src/my_file.c src/another.c) # if building a compiled library
# ... or define none if it’s a header-only library

# (4) Build flags or coverage options
option(ENABLE_CODE_COVERAGE "Enable coverage instrumentation" OFF)
```

3. **Configure** your project:

```bash
mkdir build && cd build
cmake -DENABLE_CODE_COVERAGE=ON -DBUILD_TESTING=ON ..
```

4. **Compile**:

```bash
cmake --build .
```

5. **Install** (optional):

```bash
cmake --build . --target install
```

---

## Building Libraries

### Header-Only Libraries

If you **omit `SOURCE_FILES`** (i.e., you do **not** define any `.c` files), the scripts assume a **header-only** library. For instance:

```cmake
cmake_minimum_required(VERSION 3.10)
project(my_header_only_lib VERSION 1.0 LANGUAGES C)

find_package(a-cmake-library REQUIRED)

# No SOURCE_FILES => Header-only
include(LibraryConfig)
include(LibraryBuild)
```

The library is then set up as an INTERFACE target, exposing include paths and installing headers accordingly.

Normal (Compiled) Libraries

If you define SOURCE_FILES, the scripts assume a normal library build. For example:

```cmake
cmake_minimum_required(VERSION 3.10)
project(my_regular_lib VERSION 1.0 LANGUAGES C)

set(SOURCE_FILES
    src/main_lib.c
    src/utils.c
)

find_package(a-cmake-library REQUIRED)

include(LibraryConfig)
include(LibraryBuild)
```

By default, both static and debug variants are built unless you override with CMake options:  
	•	-DSTATIC_BUILD=ON or OFF  
	•	-DDEBUG_BUILD=ON or OFF  
	•	-DSHARED_BUILD=ON or OFF  

Customizing Build Output

You can customize output names, library installation paths, or compile flags by modifying:  
	•	INSTALL_LIBDIR, INSTALL_INCLUDEDIR, INSTALL_BINDIR  
	•	DEBUG_BUILD, STATIC_BUILD, SHARED_BUILD  
	•	Additional compiler flags, e.g. -O3, -fsanitize=address, etc.  

## Building Executables / Utilities

Use BinaryConfig.cmake to create standalone executables or CLI utilities that link against your library (and optionally other libraries):

```cmake
cmake_minimum_required(VERSION 3.10)
project(my_app LANGUAGES C)

set(BINARY_SOURCES
    src/main_cli.c   # This is your main source for the app
)

# Optionally define <binary_name>_SOURCES for additional files
set(main_cli_SOURCES
    src/cli_utils.c
)

# Optionally define packages to link
set(CUSTOM_PACKAGES my_regular_lib)

find_package(a-cmake-library REQUIRED)
include(BinaryConfig)
```

## Building & Running Tests

If your project has tests:  
1.	Define TEST_SOURCES for each test entry point.  
2.	Optionally define <test_name>_SOURCES for extra test files.  
3.	Enable testing via -DBUILD_TESTING=ON or directly calling enable_testing().  

```cmake
cmake_minimum_required(VERSION 3.10)
project(my_tests LANGUAGES C)

option(BUILD_TESTING "Enable tests" ON)

if(BUILD_TESTING)
    set(TEST_SOURCES
        tests/test_utils.c
        tests/test_api.c
    )

    set(test_utils_SOURCES
        tests/helpers.c
    )
    
    find_package(a-cmake-library REQUIRED)
    include(BinaryConfig)

    # This will create test executables for test_utils and test_api
    # and link them against the chosen library variant(s).
endif()
```

To run the tests:

```bash
cmake --build . --target test
```

or

```bash
ctest
```

## Code Coverage

If you enable coverage (-DENABLE_CODE_COVERAGE=ON), the scripts detect possible coverage flags or fallback to llvm-cov, gcov, lcov/genhtml, etc. A coverage target may be created if the necessary tools are found.  
•	Run coverage (if available):  

```bash
cmake --build . --target coverage
```

•	Reports might be generated in coverage-report/ (HTML-based) or as text files, depending on the tools found.

## Installation & Uninstallation

Installation:

```
cmake --build . --target install
```

Uninstallation:

The scripts generate a uninstall target:

```
cmake --build . --target uninstall
```

## Example Projects

Look into the samples/ directory for examples that demonstrate typical usage patterns for libraries, executables, and tests.

## Advanced Configuration Options  
•	Address Sanitizer: -DADDRESS_SANITIZER=ON  
•	Clang-Tidy: -DENABLE_CLANG_TIDY=ON  
•	Custom Packages: Define CUSTOM_PACKAGES or THIRD_PARTY_PACKAGES.  

## Troubleshooting  
1.	Missing Dependencies: Ensure necessary tools (e.g., lcov, llvm-cov) are installed.  
2.	Wrong Library Variant: Double-check STATIC_BUILD, SHARED_BUILD, and DEBUG_BUILD values.  

## License

Public Domain
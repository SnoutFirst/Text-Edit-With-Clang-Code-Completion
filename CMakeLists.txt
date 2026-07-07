cmake_minimum_required(VERSION 3.21)

# Disable modules support, this template option is broken with clang-tidy at the moment
cmake_policy(SET CMP0155 OLD)

# Only set the cxx_standard if it is not set by someone else
if(NOT DEFINED CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 17)
endif()

# strongly encouraged to enable this globally to avoid conflicts between
# -Wpedantic being enabled and -std=c++20 and -std=gnu++20 for example
# when compiling with PCH enabled
set(CMAKE_CXX_EXTENSIONS OFF)

project(
  TextEditWithClangCodeCompletion
  VERSION 0.0.1
  DESCRIPTION "A Qt text editor with Clang code completion"
  HOMEPAGE_URL "https://github.com/d3fault/Text-Edit-With-Clang-Code-Completion"
  LANGUAGES CXX C)

include(cmake/PreventInSourceBuilds.cmake)
include(cmake/Emscripten.cmake)
include(ProjectOptions.cmake)

TextEditWithClangCodeCompletion_setup_options()

TextEditWithClangCodeCompletion_global_options()
include(Dependencies.cmake)
TextEditWithClangCodeCompletion_setup_dependencies()

TextEditWithClangCodeCompletion_local_options()

set(CMAKE_CXX_VISIBILITY_PRESET hidden)

set(GIT_SHA
    "Unknown"
    CACHE STRING "SHA this build was generated from")
string(
  SUBSTRING "${GIT_SHA}"
            0
            8
            GIT_SHORT_SHA)

target_compile_features(TextEditWithClangCodeCompletion_options INTERFACE cxx_std_${CMAKE_CXX_STANDARD})

add_library(TextEditWithClangCodeCompletion::TextEditWithClangCodeCompletion_options ALIAS TextEditWithClangCodeCompletion_options)
add_library(TextEditWithClangCodeCompletion::TextEditWithClangCodeCompletion_warnings ALIAS TextEditWithClangCodeCompletion_warnings)

# configure files based on CMake configuration options
add_subdirectory(configured_files)

# Adding the src:
add_subdirectory(src)

# Create unified web deployment directory (for WASM builds)
if(EMSCRIPTEN)
  TextEditWithClangCodeCompletion_create_web_dist()
endif()

# Don't even look at tests if we're not top level
if(NOT PROJECT_IS_TOP_LEVEL)
  return()
endif()

# This project has no tests yet; fuzz tests are disabled
if(TextEditWithClangCodeCompletion_BUILD_FUZZ_TESTS)
  message(AUTHOR_WARNING "Building Fuzz Tests, using fuzzing sanitizer https://www.llvm.org/docs/LibFuzzer.html")
  if(NOT TextEditWithClangCodeCompletion_ENABLE_SANITIZER_ADDRESS AND NOT TextEditWithClangCodeCompletion_ENABLE_SANITIZER_THREAD)
    message(WARNING "You need asan or tsan enabled for meaningful fuzz testing")
  endif()
endif()

# If MSVC is being used, and ASAN is enabled, we need to set the debugger environment
# so that it behaves well with MSVC's debugger, and we can run the target from visual studio
if(MSVC)
  get_all_installable_targets(all_targets)
  message("all_targets=${all_targets}")
  set_target_properties(${all_targets} PROPERTIES VS_DEBUGGER_ENVIRONMENT "PATH=$(VC_ExecutablePath_x64);%PATH%")
endif()

# set the startup project for the "play" button in MSVC
set_property(DIRECTORY PROPERTY VS_STARTUP_PROJECT texteditwithclangcodecompletion)

if(CMAKE_SKIP_INSTALL_RULES)
  return()
endif()

include(cmake/PackageProject.cmake)

# Package the one executable we know we want to ship
TextEditWithClangCodeCompletion_package_project(
  TARGETS
  texteditwithclangcodecompletion
  TextEditWithClangCodeCompletion_options
  TextEditWithClangCodeCompletion_warnings
)

set(CPACK_PACKAGE_FILE_NAME
    "${CMAKE_PROJECT_NAME}-${CMAKE_PROJECT_VERSION}-${GIT_SHORT_SHA}-${CMAKE_SYSTEM_NAME}-${CMAKE_BUILD_TYPE}-${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}"
)

include(CPack)

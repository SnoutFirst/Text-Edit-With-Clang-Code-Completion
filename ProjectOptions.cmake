include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(TextEditWithClangCodeCompletion_supports_sanitizers)
  # Emscripten doesn't support sanitizers
  if(EMSCRIPTEN)
    set(SUPPORTS_UBSAN OFF)
    set(SUPPORTS_ASAN OFF)
  elseif((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  elseif(EMSCRIPTEN)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(TextEditWithClangCodeCompletion_setup_options)
  option(TextEditWithClangCodeCompletion_ENABLE_HARDENING "Enable hardening" ON)
  option(TextEditWithClangCodeCompletion_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    TextEditWithClangCodeCompletion_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    TextEditWithClangCodeCompletion_ENABLE_HARDENING
    OFF)

  TextEditWithClangCodeCompletion_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR TextEditWithClangCodeCompletion_PACKAGING_MAINTAINER_MODE)
    option(TextEditWithClangCodeCompletion_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(TextEditWithClangCodeCompletion_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(TextEditWithClangCodeCompletion_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(TextEditWithClangCodeCompletion_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(TextEditWithClangCodeCompletion_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(TextEditWithClangCodeCompletion_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(TextEditWithClangCodeCompletion_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(TextEditWithClangCodeCompletion_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(TextEditWithClangCodeCompletion_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(TextEditWithClangCodeCompletion_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(TextEditWithClangCodeCompletion_ENABLE_PCH "Enable precompiled headers" OFF)
    option(TextEditWithClangCodeCompletion_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(TextEditWithClangCodeCompletion_ENABLE_IPO "Enable IPO/LTO" ON)
    option(TextEditWithClangCodeCompletion_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(TextEditWithClangCodeCompletion_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(TextEditWithClangCodeCompletion_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(TextEditWithClangCodeCompletion_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(TextEditWithClangCodeCompletion_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(TextEditWithClangCodeCompletion_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(TextEditWithClangCodeCompletion_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(TextEditWithClangCodeCompletion_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(TextEditWithClangCodeCompletion_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(TextEditWithClangCodeCompletion_ENABLE_PCH "Enable precompiled headers" OFF)
    option(TextEditWithClangCodeCompletion_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      TextEditWithClangCodeCompletion_ENABLE_IPO
      TextEditWithClangCodeCompletion_WARNINGS_AS_ERRORS
      TextEditWithClangCodeCompletion_ENABLE_SANITIZER_ADDRESS
      TextEditWithClangCodeCompletion_ENABLE_SANITIZER_LEAK
      TextEditWithClangCodeCompletion_ENABLE_SANITIZER_UNDEFINED
      TextEditWithClangCodeCompletion_ENABLE_SANITIZER_THREAD
      TextEditWithClangCodeCompletion_ENABLE_SANITIZER_MEMORY
      TextEditWithClangCodeCompletion_ENABLE_UNITY_BUILD
      TextEditWithClangCodeCompletion_ENABLE_CLANG_TIDY
      TextEditWithClangCodeCompletion_ENABLE_CPPCHECK
      TextEditWithClangCodeCompletion_ENABLE_COVERAGE
      TextEditWithClangCodeCompletion_ENABLE_PCH
      TextEditWithClangCodeCompletion_ENABLE_CACHE)
  endif()

  TextEditWithClangCodeCompletion_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (TextEditWithClangCodeCompletion_ENABLE_SANITIZER_ADDRESS OR TextEditWithClangCodeCompletion_ENABLE_SANITIZER_THREAD OR TextEditWithClangCodeCompletion_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(TextEditWithClangCodeCompletion_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(TextEditWithClangCodeCompletion_global_options)
  if(TextEditWithClangCodeCompletion_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    TextEditWithClangCodeCompletion_enable_ipo()
  endif()

  TextEditWithClangCodeCompletion_supports_sanitizers()

  if(TextEditWithClangCodeCompletion_ENABLE_HARDENING AND TextEditWithClangCodeCompletion_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR TextEditWithClangCodeCompletion_ENABLE_SANITIZER_UNDEFINED
       OR TextEditWithClangCodeCompletion_ENABLE_SANITIZER_ADDRESS
       OR TextEditWithClangCodeCompletion_ENABLE_SANITIZER_THREAD
       OR TextEditWithClangCodeCompletion_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${TextEditWithClangCodeCompletion_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${TextEditWithClangCodeCompletion_ENABLE_SANITIZER_UNDEFINED}")
    TextEditWithClangCodeCompletion_enable_hardening(TextEditWithClangCodeCompletion_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(TextEditWithClangCodeCompletion_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(TextEditWithClangCodeCompletion_warnings INTERFACE)
  add_library(TextEditWithClangCodeCompletion_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  TextEditWithClangCodeCompletion_set_project_warnings(
    TextEditWithClangCodeCompletion_warnings
    ${TextEditWithClangCodeCompletion_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  include(cmake/Linker.cmake)
  # Must configure each target with linker options, we're avoiding setting it globally for now

  if(NOT EMSCRIPTEN)
    include(cmake/Sanitizers.cmake)
    TextEditWithClangCodeCompletion_enable_sanitizers(
      TextEditWithClangCodeCompletion_options
      ${TextEditWithClangCodeCompletion_ENABLE_SANITIZER_ADDRESS}
      ${TextEditWithClangCodeCompletion_ENABLE_SANITIZER_LEAK}
      ${TextEditWithClangCodeCompletion_ENABLE_SANITIZER_UNDEFINED}
      ${TextEditWithClangCodeCompletion_ENABLE_SANITIZER_THREAD}
      ${TextEditWithClangCodeCompletion_ENABLE_SANITIZER_MEMORY})
  endif()

  set_target_properties(TextEditWithClangCodeCompletion_options PROPERTIES UNITY_BUILD ${TextEditWithClangCodeCompletion_ENABLE_UNITY_BUILD})

  if(TextEditWithClangCodeCompletion_ENABLE_PCH)
    target_precompile_headers(
      TextEditWithClangCodeCompletion_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(TextEditWithClangCodeCompletion_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    TextEditWithClangCodeCompletion_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(TextEditWithClangCodeCompletion_ENABLE_CLANG_TIDY)
    TextEditWithClangCodeCompletion_enable_clang_tidy(TextEditWithClangCodeCompletion_options ${TextEditWithClangCodeCompletion_WARNINGS_AS_ERRORS})
  endif()

  if(TextEditWithClangCodeCompletion_ENABLE_CPPCHECK)
    TextEditWithClangCodeCompletion_enable_cppcheck(${TextEditWithClangCodeCompletion_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(TextEditWithClangCodeCompletion_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    TextEditWithClangCodeCompletion_enable_coverage(TextEditWithClangCodeCompletion_options)
  endif()

  if(TextEditWithClangCodeCompletion_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(TextEditWithClangCodeCompletion_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(TextEditWithClangCodeCompletion_ENABLE_HARDENING AND NOT TextEditWithClangCodeCompletion_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR TextEditWithClangCodeCompletion_ENABLE_SANITIZER_UNDEFINED
       OR TextEditWithClangCodeCompletion_ENABLE_SANITIZER_ADDRESS
       OR TextEditWithClangCodeCompletion_ENABLE_SANITIZER_THREAD
       OR TextEditWithClangCodeCompletion_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    TextEditWithClangCodeCompletion_enable_hardening(TextEditWithClangCodeCompletion_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()

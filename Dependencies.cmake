include(cmake/CPM.cmake)

function(TextEditWithClangCodeCompletion_setup_dependencies)
  # Prefer Qt6; fall back to Qt5 for local/legacy convenience.
  find_package(Qt6 QUIET COMPONENTS Core Gui Widgets)
  if(Qt6_FOUND)
    set(TEXTEDIT_QT_TARGETS Qt6::Core Qt6::Gui Qt6::Widgets PARENT_SCOPE)
    set(TEXTEDIT_QT_VERSION_MAJOR 6 PARENT_SCOPE)
    message(STATUS "Using Qt6")
  else()
    find_package(Qt5 REQUIRED COMPONENTS Core Gui Widgets)
    set(TEXTEDIT_QT_TARGETS Qt5::Core Qt5::Gui Qt5::Widgets PARENT_SCOPE)
    set(TEXTEDIT_QT_VERSION_MAJOR 5 PARENT_SCOPE)
    message(STATUS "Using Qt5")
  endif()

  set(CMAKE_AUTOMOC ON PARENT_SCOPE)

  # For Emscripten we use a prebuilt libclang root (set via EMSCRIPTEN_LIBCLANG_ROOT env or cache),
  # because compiling LLVM itself to WASM in CI is impractical.
  if(EMSCRIPTEN)
    if(DEFINED ENV{EMSCRIPTEN_LIBCLANG_ROOT})
      set(_EM_LIBCLANG_ROOT "$ENV{EMSCRIPTEN_LIBCLANG_ROOT}")
    elseif(DEFINED EMSCRIPTEN_LIBCLANG_ROOT)
      set(_EM_LIBCLANG_ROOT "${EMSCRIPTEN_LIBCLANG_ROOT}")
    endif()

    if(DEFINED _EM_LIBCLANG_ROOT)
      message(STATUS "Using prebuilt Emscripten libclang at ${_EM_LIBCLANG_ROOT}")
      set(LLVM_DIR "${_EM_LIBCLANG_ROOT}/lib/cmake/llvm" CACHE PATH "LLVM config dir" FORCE)
      set(Clang_DIR "${_EM_LIBCLANG_ROOT}/lib/cmake/clang" CACHE PATH "Clang config dir" FORCE)
      find_package(LLVM REQUIRED CONFIG)
      find_package(Clang REQUIRED CONFIG)

      set(TEXTEDIT_CLANG_INCLUDE_DIRS "${_EM_LIBCLANG_ROOT}/include" PARENT_SCOPE)
      set(TEXTEDIT_CLANG_LINK_LIBRARIES libclang PARENT_SCOPE)
      return()
    endif()

    message(WARNING "No EMSCRIPTEN_LIBCLANG_ROOT provided. libclang will not be available in the WASM build.")
  endif()

  # Find libclang
  # Try pkg-config first, then llvm-config, then CMake LLVM/Clang configs, then manual search.
  find_package(PkgConfig QUIET)
  if(PkgConfig_FOUND AND NOT EMSCRIPTEN)
    pkg_check_modules(LIBCLANG QUIET libclang)
  endif()

  if(LIBCLANG_FOUND)
    message(STATUS "Found libclang via pkg-config: ${LIBCLANG_LINK_LIBRARIES}")
    set(TEXTEDIT_CLANG_INCLUDE_DIRS ${LIBCLANG_INCLUDE_DIRS} PARENT_SCOPE)
    set(TEXTEDIT_CLANG_LINK_LIBRARIES ${LIBCLANG_LINK_LIBRARIES} PARENT_SCOPE)
    set(TEXTEDIT_CLANG_COMPILE_OPTIONS ${LIBCLANG_CFLAGS_OTHER} PARENT_SCOPE)
  else()
    # Respect an explicit LLVM_PATH from the environment (e.g. KyleMayes/install-llvm-action)
    if(DEFINED ENV{LLVM_PATH})
      set(_LLVM_HINTS $ENV{LLVM_PATH}/bin)
      message(STATUS "LLVM_PATH set to $ENV{LLVM_PATH}")
    endif()

    find_program(LLVM_CONFIG_EXECUTABLE llvm-config HINTS ${_LLVM_HINTS})

    if(LLVM_CONFIG_EXECUTABLE)
      message(STATUS "Found llvm-config: ${LLVM_CONFIG_EXECUTABLE}")
      execute_process(
        COMMAND ${LLVM_CONFIG_EXECUTABLE} --includedir
        OUTPUT_VARIABLE LLVM_INCLUDE_DIR
        OUTPUT_STRIP_TRAILING_WHITESPACE)
      execute_process(
        COMMAND ${LLVM_CONFIG_EXECUTABLE} --libdir
        OUTPUT_VARIABLE LLVM_LIBRARY_DIR
        OUTPUT_STRIP_TRAILING_WHITESPACE)
      execute_process(
        COMMAND ${LLVM_CONFIG_EXECUTABLE} --ldflags
        OUTPUT_VARIABLE LLVM_LDFLAGS
        OUTPUT_STRIP_TRAILING_WHITESPACE)
      execute_process(
        COMMAND ${LLVM_CONFIG_EXECUTABLE} --libs
        OUTPUT_VARIABLE LLVM_LIBS
        OUTPUT_STRIP_TRAILING_WHITESPACE)
      execute_process(
        COMMAND ${LLVM_CONFIG_EXECUTABLE} --system-libs
        OUTPUT_VARIABLE LLVM_SYSTEM_LIBS
        OUTPUT_STRIP_TRAILING_WHITESPACE)
      execute_process(
        COMMAND ${LLVM_CONFIG_EXECUTABLE} --cxxflags
        OUTPUT_VARIABLE LLVM_CXXFLAGS
        OUTPUT_STRIP_TRAILING_WHITESPACE)

      string(REPLACE " " ";" LLVM_LIBS_LIST "${LLVM_LIBS}")
      set(CLANG_ONLY_LIBS "")
      foreach(lib ${LLVM_LIBS_LIST})
        if(lib MATCHES "clang")
          list(APPEND CLANG_ONLY_LIBS ${lib})
        endif()
      endforeach()
      if(NOT CLANG_ONLY_LIBS)
        set(CLANG_ONLY_LIBS "clang")
      endif()

      set(TEXTEDIT_CLANG_INCLUDE_DIRS ${LLVM_INCLUDE_DIR} PARENT_SCOPE)
      set(TEXTEDIT_CLANG_LINK_LIBRARIES ${CLANG_ONLY_LIBS} ${LLVM_SYSTEM_LIBS} PARENT_SCOPE)
      set(TEXTEDIT_CLANG_LINK_OPTIONS ${LLVM_LDFLAGS} PARENT_SCOPE)
      set(TEXTEDIT_CLANG_COMPILE_OPTIONS ${LLVM_CXXFLAGS} PARENT_SCOPE)
    else()
      if(DEFINED ENV{LLVM_PATH})
        find_package(LLVM QUIET CONFIG PATHS $ENV{LLVM_PATH}/lib/cmake/llvm NO_DEFAULT_PATH)
      endif()
      if(NOT LLVM_FOUND)
        find_package(LLVM QUIET CONFIG)
      endif()
      if(LLVM_FOUND)
        message(STATUS "Found LLVM CMake config: ${LLVM_DIR}")
        find_library(CLANG_LIBRARY
          NAMES clang libclang
          PATHS ${LLVM_LIBRARY_DIR} ${LLVM_LIBRARY_DIRS}
          NO_DEFAULT_PATH)
        find_path(CLANG_INCLUDE_DIR
          NAMES clang-c/Index.h
          PATHS ${LLVM_INCLUDE_DIRS}
          NO_DEFAULT_PATH)
        set(TEXTEDIT_CLANG_INCLUDE_DIRS ${CLANG_INCLUDE_DIR} PARENT_SCOPE)
        set(TEXTEDIT_CLANG_LINK_LIBRARIES ${CLANG_LIBRARY} PARENT_SCOPE)
      else()
        find_library(CLANG_LIBRARY NAMES clang libclang)
        find_path(CLANG_INCLUDE_DIR NAMES clang-c/Index.h)
        if(NOT CLANG_LIBRARY OR NOT CLANG_INCLUDE_DIR)
          message(FATAL_ERROR "Could not find libclang. Please install libclang-dev / llvm-dev or set CLANG_LIBRARY/CLANG_INCLUDE_DIR manually.")
        endif()
        set(TEXTEDIT_CLANG_INCLUDE_DIRS ${CLANG_INCLUDE_DIR} PARENT_SCOPE)
        set(TEXTEDIT_CLANG_LINK_LIBRARIES ${CLANG_LIBRARY} PARENT_SCOPE)
      endif()
    endif()
  endif()
endfunction()

include(cmake/CPM.cmake)

function(TextEditWithClangCodeCompletion_setup_dependencies)
  # Prefer Qt6; fall back to Qt5 for local/legacy convenience.
  find_package(Qt6 QUIET COMPONENTS Core Gui Widgets)
  if(Qt6_FOUND)
    # Order high-level targets before low-level ones so static linking works
    # correctly (dependent libraries precede their dependencies).
    set(TEXTEDIT_QT_TARGETS Qt6::Widgets Qt6::Gui Qt6::Core PARENT_SCOPE)
    set(TEXTEDIT_QT_VERSION_MAJOR 6 PARENT_SCOPE)
    message(STATUS "Using Qt6")
  else()
    find_package(Qt5 REQUIRED COMPONENTS Core Gui Widgets)
    set(TEXTEDIT_QT_TARGETS Qt5::Widgets Qt5::Gui Qt5::Core PARENT_SCOPE)
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
      # libclang's C API needs LLVM Support, which on this prebuilt WASM archive
      # references the wasm longjmp runtime (__wasm_setjmp / emscripten_longjmp).
      # That runtime is incompatible with the JS longjmp model used by Qt 6.7.3
      # official binaries and the rest of our Emscripten 3.1.50 link.  The only
      # object in libLLVMSupport.a that pulls those symbols in is
      # CrashRecoveryContext.cpp.o.  Drop it from the link set; the editor's
      # libclang usage only exercises parsing/code-completion and never needs
      # LLVM's crash recovery machinery.
      set(_EM_LLVM_SUPPORT_LIB "${_EM_LIBCLANG_ROOT}/lib/libLLVMSupport.a")
      if(EXISTS "${_EM_LLVM_SUPPORT_LIB}")
        set(_EM_FILTERED_SUPPORT_DIR "${CMAKE_BINARY_DIR}/emscripten-libclang-hack")
        set(_EM_FILTERED_SUPPORT_LIB "${_EM_FILTERED_SUPPORT_DIR}/libLLVMSupport-no-crash-recovery.a")
        file(MAKE_DIRECTORY "${_EM_FILTERED_SUPPORT_DIR}")
        file(REMOVE "${_EM_FILTERED_SUPPORT_LIB}")
        execute_process(
          COMMAND ${CMAKE_AR} t "${_EM_LLVM_SUPPORT_LIB}"
          OUTPUT_VARIABLE _EM_SUPPORT_MEMBERS
          OUTPUT_STRIP_TRAILING_WHITESPACE
          ERROR_QUIET)
        if(_EM_SUPPORT_MEMBERS)
          string(REPLACE "\n" ";" _EM_SUPPORT_MEMBERS_LIST "${_EM_SUPPORT_MEMBERS}")
          list(REMOVE_ITEM _EM_SUPPORT_MEMBERS_LIST "CrashRecoveryContext.cpp.o")
          foreach(_member ${_EM_SUPPORT_MEMBERS_LIST})
            execute_process(
              COMMAND ${CMAKE_AR} p "${_EM_LLVM_SUPPORT_LIB}" "${_member}"
              OUTPUT_FILE "${_EM_FILTERED_SUPPORT_DIR}/${_member}"
              ERROR_QUIET)
          endforeach()
          execute_process(
            COMMAND ${CMAKE_AR} rcs "${_EM_FILTERED_SUPPORT_LIB}" ${_EM_SUPPORT_MEMBERS_LIST}
            WORKING_DIRECTORY "${_EM_FILTERED_SUPPORT_DIR}"
            ERROR_QUIET)

          # Redirect every LLVM target that depends on the LLVMSupport imported
          # target to the filtered archive, so the original archive is never
          # pulled back in as a transitive dependency of libclang/LLVM.
          if(TARGET LLVMSupport)
            set_target_properties(LLVMSupport PROPERTIES
              IMPORTED_LOCATION "${_EM_FILTERED_SUPPORT_LIB}"
              IMPORTED_LOCATION_NOCONFIG "${_EM_FILTERED_SUPPORT_LIB}"
              IMPORTED_LOCATION_RELEASE "${_EM_FILTERED_SUPPORT_LIB}"
              IMPORTED_LOCATION_DEBUG "${_EM_FILTERED_SUPPORT_LIB}"
              IMPORTED_LOCATION_RELWITHDEBINFO "${_EM_FILTERED_SUPPORT_LIB}"
              IMPORTED_LOCATION_MINSIZEREL "${_EM_FILTERED_SUPPORT_LIB}")
          endif()
        endif()
      endif()

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
    # Respect an explicit LLVM_PATH from the environment (e.g. KyleMayes/install-llvm-action on Windows)
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
        COMMAND ${LLVM_CONFIG_EXECUTABLE} --cxxflags
        OUTPUT_VARIABLE LLVM_CXXFLAGS
        OUTPUT_STRIP_TRAILING_WHITESPACE)

      # Convert space-separated flags into CMake lists so target_link_options
      # / target_compile_options treat each flag separately.
      string(REPLACE " " ";" LLVM_LDFLAGS_LIST "${LLVM_LDFLAGS}")
      string(REPLACE " " ";" LLVM_CXXFLAGS_LIST "${LLVM_CXXFLAGS}")

      # Remove -std=c++NN from llvm-config flags; we set our own C++ standard.
      list(FILTER LLVM_CXXFLAGS_LIST EXCLUDE REGEX "^-std=c\\+\\+.*$")

      # Find the actual libclang library (name varies by platform).
      find_library(CLANG_LIBRARY
        NAMES clang libclang clang.lib libclang.lib
        PATHS ${LLVM_LIBRARY_DIR}
        NO_DEFAULT_PATH)
      if(NOT CLANG_LIBRARY)
        message(FATAL_ERROR "Could not find libclang in ${LLVM_LIBRARY_DIR}")
      endif()

      set(TEXTEDIT_CLANG_INCLUDE_DIRS ${LLVM_INCLUDE_DIR} PARENT_SCOPE)
      set(TEXTEDIT_CLANG_LINK_LIBRARIES ${CLANG_LIBRARY} ${LLVM_LDFLAGS_LIST} PARENT_SCOPE)
      set(TEXTEDIT_CLANG_COMPILE_OPTIONS ${LLVM_CXXFLAGS_LIST} PARENT_SCOPE)
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
          NAMES clang libclang clang.lib libclang.lib
          PATHS ${LLVM_LIBRARY_DIR} ${LLVM_LIBRARY_DIRS}
          NO_DEFAULT_PATH)
        find_path(CLANG_INCLUDE_DIR
          NAMES clang-c/Index.h
          PATHS ${LLVM_INCLUDE_DIRS}
          NO_DEFAULT_PATH)
        if(NOT CLANG_LIBRARY)
          message(FATAL_ERROR "Could not find libclang via LLVM CMake config")
        endif()
        set(TEXTEDIT_CLANG_INCLUDE_DIRS ${CLANG_INCLUDE_DIR} PARENT_SCOPE)
        set(TEXTEDIT_CLANG_LINK_LIBRARIES ${CLANG_LIBRARY} PARENT_SCOPE)
      else()
        find_library(CLANG_LIBRARY NAMES clang libclang clang.lib libclang.lib)
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

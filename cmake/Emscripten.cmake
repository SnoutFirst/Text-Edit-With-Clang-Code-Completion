# cmake/Emscripten.cmake
# Emscripten/WebAssembly build configuration

# Common paths for web assets
set(TextEditWithClangCodeCompletion_WEB_DIR "${CMAKE_SOURCE_DIR}/web")
set(TextEditWithClangCodeCompletion_COI_WORKER "${TextEditWithClangCodeCompletion_WEB_DIR}/coi-serviceworker.min.js")
set(TextEditWithClangCodeCompletion_SHELL_TEMPLATE "${TextEditWithClangCodeCompletion_WEB_DIR}/shell_template.html.in")
set(TextEditWithClangCodeCompletion_INDEX_TEMPLATE "${TextEditWithClangCodeCompletion_WEB_DIR}/index_template.html.in")

# Helper function to escape HTML special characters
function(escape_html output_var input)
  set(result "${input}")
  string(REPLACE "&" "&amp;" result "${result}")
  string(REPLACE "<" "&lt;" result "${result}")
  string(REPLACE ">" "&gt;" result "${result}")
  string(REPLACE "\"" "&quot;" result "${result}")
  set(${output_var} "${result}" PARENT_SCOPE)
endfunction()

# Detect if we're building with Emscripten
if(EMSCRIPTEN)
  message(STATUS "Emscripten build detected - configuring for WebAssembly")

  # Set WASM build flag
  set(TextEditWithClangCodeCompletion_WASM_BUILD ON CACHE BOOL "Building for WebAssembly" FORCE)

  # Sanitizers don't work with Emscripten
  foreach(sanitizer ADDRESS LEAK UNDEFINED THREAD MEMORY)
    set(TextEditWithClangCodeCompletion_ENABLE_SANITIZER_${sanitizer} OFF CACHE BOOL "Not supported with Emscripten")
  endforeach()

  # Disable static analysis and strict warnings for Emscripten builds
  foreach(option CLANG_TIDY CPPCHECK WARNINGS_AS_ERRORS)
    set(TextEditWithClangCodeCompletion_ENABLE_${option} OFF CACHE BOOL "Disabled for Emscripten")
  endforeach()

  # Disable testing - no way to execute WASM test targets
  set(BUILD_TESTING OFF CACHE BOOL "No test runner for WASM")

  # WASM runtime configuration - tunable performance parameters
  set(TextEditWithClangCodeCompletion_WASM_ENABLE_PTHREADS OFF CACHE BOOL
      "Enable pthreads for WASM (requires a multithread Qt WASM build)")
  set(TextEditWithClangCodeCompletion_WASM_INITIAL_MEMORY "33554432" CACHE STRING
      "Initial WASM memory in bytes (default: 32MB)")
  set(TextEditWithClangCodeCompletion_WASM_PTHREAD_POOL_SIZE "4" CACHE STRING
      "Pthread pool size for WASM builds (default: 4)")
  set(TextEditWithClangCodeCompletion_WASM_ASYNCIFY_STACK_SIZE "65536" CACHE STRING
      "Asyncify stack size in bytes (default: 64KB)")

  # The template originally forced pthreads for FTXUI. This project uses Qt6 WASM
  # singlethread by default, so we only enable pthreads when requested.
  if(TextEditWithClangCodeCompletion_WASM_ENABLE_PTHREADS)
    message(STATUS "WASM pthreads enabled")
    add_compile_options(-pthread -fwasm-exceptions)
    add_link_options(-pthread -fwasm-exceptions)
  endif()
endif()

# Function to apply WASM settings to a target
function(TextEditWithClangCodeCompletion_configure_wasm_target target)
  if(EMSCRIPTEN)
    # Parse optional named arguments
    set(options "")
    set(oneValueArgs TITLE DESCRIPTION RESOURCES_DIR)
    set(multiValueArgs "")
    cmake_parse_arguments(WASM "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Set defaults if not provided
    if(NOT WASM_TITLE)
      set(WASM_TITLE "${target}")
    endif()

    if(NOT WASM_DESCRIPTION)
      set(WASM_DESCRIPTION "WebAssembly application")
    endif()

    # Get the actual output name (may differ from target name)
    get_target_property(OUTPUT_NAME ${target} OUTPUT_NAME)
    if(NOT OUTPUT_NAME)
      set(OUTPUT_NAME "${target}")
    endif()

    # Register this target in the global WASM targets list
    set_property(GLOBAL APPEND PROPERTY TextEditWithClangCodeCompletion_WASM_TARGETS "${target}")
    set_property(GLOBAL PROPERTY TextEditWithClangCodeCompletion_WASM_TARGET_${target}_TITLE "${WASM_TITLE}")
    set_property(GLOBAL PROPERTY TextEditWithClangCodeCompletion_WASM_TARGET_${target}_DESCRIPTION "${WASM_DESCRIPTION}")
    set_property(GLOBAL PROPERTY TextEditWithClangCodeCompletion_WASM_TARGET_${target}_OUTPUT_NAME "${OUTPUT_NAME}")

    target_compile_definitions(${target} PRIVATE TextEditWithClangCodeCompletion_WASM_BUILD=1)

    set(_WASM_LINK_OPTIONS
      "-lembind"
      "-sASYNCIFY=1"
      "-sASYNCIFY_STACK_SIZE=${TextEditWithClangCodeCompletion_WASM_ASYNCIFY_STACK_SIZE}"
      "-sALLOW_MEMORY_GROWTH=1"
      "-sINITIAL_MEMORY=${TextEditWithClangCodeCompletion_WASM_INITIAL_MEMORY}"
      "-sEXPORTED_RUNTIME_METHODS=['FS','ccall','cwrap','UTF8ToString','stringToUTF8','lengthBytesUTF8']"
      "-sEXPORTED_FUNCTIONS=['_main','_malloc','_free']"
      "-sASSERTIONS=1"
    )

    if(TextEditWithClangCodeCompletion_WASM_ENABLE_PTHREADS)
      list(APPEND _WASM_LINK_OPTIONS
        "-sUSE_PTHREADS=1"
        "-sPROXY_TO_PTHREAD=1"
        "-sPTHREAD_POOL_SIZE=${TextEditWithClangCodeCompletion_WASM_PTHREAD_POOL_SIZE}"
        "-sENVIRONMENT=web,worker"
      )
    else()
      list(APPEND _WASM_LINK_OPTIONS
        "-sENVIRONMENT=web"
      )
    endif()

    target_link_options(${target} PRIVATE ${_WASM_LINK_OPTIONS})

    # Embed resources into WASM binary (optional, per-target)
    if(WASM_RESOURCES_DIR AND EXISTS "${WASM_RESOURCES_DIR}")
      # Convert to absolute path to avoid issues with Emscripten path resolution
      get_filename_component(ABS_RESOURCES_DIR "${WASM_RESOURCES_DIR}" ABSOLUTE BASE_DIR "${CMAKE_SOURCE_DIR}")

      target_link_options(${target} PRIVATE
        "--embed-file=${ABS_RESOURCES_DIR}@/resources"
      )
      message(STATUS "Embedding resources for ${target} from ${ABS_RESOURCES_DIR}")
    endif()

    # Configure the shell HTML template for this target
    set(TARGET_NAME "${OUTPUT_NAME}")
    set(TARGET_TITLE "${WASM_TITLE}")
    set(TARGET_DESCRIPTION "${WASM_DESCRIPTION}")
    set(AT "@")  # For escaping @ in npm package URLs
    set(CONFIGURED_SHELL "${CMAKE_BINARY_DIR}/web/${target}_shell.html")

    # Generate target-specific shell file (configure_file creates parent directories automatically)
    if(EXISTS "${TextEditWithClangCodeCompletion_SHELL_TEMPLATE}")
      configure_file(
        "${TextEditWithClangCodeCompletion_SHELL_TEMPLATE}"
        "${CONFIGURED_SHELL}"
        @ONLY
      )

      # Use the generated shell file
      target_link_options(${target} PRIVATE
        "--shell-file=${CONFIGURED_SHELL}"
      )

      # Add both template and configured file as link dependencies
      set_property(TARGET ${target} APPEND PROPERTY LINK_DEPENDS
        "${TextEditWithClangCodeCompletion_SHELL_TEMPLATE}"
        "${CONFIGURED_SHELL}"
      )

      message(STATUS "Configured WASM shell for ${target}: ${CONFIGURED_SHELL}")
    else()
      message(FATAL_ERROR "Shell template not found: ${TextEditWithClangCodeCompletion_SHELL_TEMPLATE}")
    endif()

    # Copy service worker to target build directory for standalone target builds
    if(EXISTS "${TextEditWithClangCodeCompletion_COI_WORKER}")
      add_custom_command(TARGET ${target} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
          "${TextEditWithClangCodeCompletion_COI_WORKER}"
          "$<TARGET_FILE_DIR:${target}>/coi-serviceworker.min.js"
        COMMENT "Copying coi-serviceworker.min.js to ${target} build directory"
      )
    endif()

    # Set output suffix to .html
    set_target_properties(${target} PROPERTIES SUFFIX ".html")

    message(STATUS "Configured ${target} for WebAssembly")
  endif()
endfunction()

# Create a unified web deployment directory with all WASM targets
function(TextEditWithClangCodeCompletion_create_web_dist)
  if(NOT EMSCRIPTEN)
    return()
  endif()

  # Define output directory
  set(WEB_DIST_DIR "${CMAKE_BINARY_DIR}/web-dist")

  # Get list of all WASM targets
  get_property(WASM_TARGETS GLOBAL PROPERTY TextEditWithClangCodeCompletion_WASM_TARGETS)

  if(NOT WASM_TARGETS)
    message(WARNING "No WASM targets registered. Skipping web-dist generation.")
    return()
  endif()

  # Generate HTML for app cards
  set(WASM_APPS_HTML "")
  foreach(target ${WASM_TARGETS})
    get_property(TITLE GLOBAL PROPERTY TextEditWithClangCodeCompletion_WASM_TARGET_${target}_TITLE)
    get_property(DESCRIPTION GLOBAL PROPERTY TextEditWithClangCodeCompletion_WASM_TARGET_${target}_DESCRIPTION)

    # Escape HTML special characters to prevent injection
    escape_html(TITLE_ESCAPED "${TITLE}")
    escape_html(DESC_ESCAPED "${DESCRIPTION}")

    string(APPEND WASM_APPS_HTML
"            <a href=\"${target}/\" class=\"app-card\">
                <h3>${TITLE_ESCAPED}</h3>
                <p>${DESC_ESCAPED}</p>
            </a>
")
  endforeach()

  # Generate index.html from template
  set(INDEX_OUTPUT "${WEB_DIST_DIR}/index.html")

  if(EXISTS "${TextEditWithClangCodeCompletion_INDEX_TEMPLATE}")
    configure_file("${TextEditWithClangCodeCompletion_INDEX_TEMPLATE}" "${INDEX_OUTPUT}" @ONLY)
  else()
    message(WARNING "Index template not found: ${TextEditWithClangCodeCompletion_INDEX_TEMPLATE}")
  endif()

  # Build list of copy commands
  set(COPY_COMMANDS "")

  # For each WASM target, copy artifacts to subdirectory
  # Each target gets its own service worker copy for standalone deployment
  foreach(target ${WASM_TARGETS})
    get_target_property(TARGET_BINARY_DIR ${target} BINARY_DIR)
    get_property(OUTPUT_NAME GLOBAL PROPERTY TextEditWithClangCodeCompletion_WASM_TARGET_${target}_OUTPUT_NAME)
    set(TARGET_DIST_DIR "${WEB_DIST_DIR}/${target}")

    # Copy WASM artifacts: .html (as index.html), .js, .wasm, and service worker
    # Use OUTPUT_NAME instead of target name for file names
    list(APPEND COPY_COMMANDS
      COMMAND ${CMAKE_COMMAND} -E make_directory "${TARGET_DIST_DIR}"
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${TARGET_BINARY_DIR}/${OUTPUT_NAME}.html"
        "${TARGET_DIST_DIR}/index.html"
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${TARGET_BINARY_DIR}/${OUTPUT_NAME}.js"
        "${TARGET_DIST_DIR}/${OUTPUT_NAME}.js"
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${TARGET_BINARY_DIR}/${OUTPUT_NAME}.wasm"
        "${TARGET_DIST_DIR}/${OUTPUT_NAME}.wasm"
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${TextEditWithClangCodeCompletion_COI_WORKER}"
        "${TARGET_DIST_DIR}/coi-serviceworker.min.js"
    )
  endforeach()

  # Create custom target with all commands (part of ALL so it builds by default)
  add_custom_target(web-dist ALL
    COMMAND ${CMAKE_COMMAND} -E make_directory "${WEB_DIST_DIR}"
    ${COPY_COMMANDS}
    COMMENT "Creating unified web deployment directory"
  )

  # Ensure web-dist runs after all WASM targets are built
  add_dependencies(web-dist ${WASM_TARGETS})

  message(STATUS "Configured web-dist target with ${WASM_TARGETS}")
endfunction()

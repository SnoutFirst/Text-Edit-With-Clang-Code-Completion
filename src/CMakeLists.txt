# Re-find Qt6 in this directory so AUTOGEN can detect the Qt version for the
# texteditwithclangcodecompletion target (especially important for Emscripten
# cross-builds where Qt tools are split between host and target installs).
find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets)

add_executable(texteditwithclangcodecompletion
  ${CMAKE_SOURCE_DIR}/main.cpp
  ${CMAKE_SOURCE_DIR}/texteditwithclangcodecompletion.cpp
  ${CMAKE_SOURCE_DIR}/texteditwithclangcodecompletion.h)

set_target_properties(texteditwithclangcodecompletion PROPERTIES AUTOMOC ON)

target_include_directories(texteditwithclangcodecompletion PRIVATE
  "${CMAKE_BINARY_DIR}/configured_files/include"
  ${TEXTEDIT_CLANG_INCLUDE_DIRS})

target_link_libraries(texteditwithclangcodecompletion
  PRIVATE TextEditWithClangCodeCompletion::TextEditWithClangCodeCompletion_options
          TextEditWithClangCodeCompletion::TextEditWithClangCodeCompletion_warnings
          ${TEXTEDIT_QT_TARGETS}
          ${TEXTEDIT_CLANG_LINK_LIBRARIES})

if(TEXTEDIT_CLANG_LINK_OPTIONS)
  target_link_options(texteditwithclangcodecompletion PRIVATE ${TEXTEDIT_CLANG_LINK_OPTIONS})
endif()

if(TEXTEDIT_CLANG_COMPILE_OPTIONS)
  target_compile_options(texteditwithclangcodecompletion PRIVATE ${TEXTEDIT_CLANG_COMPILE_OPTIONS})
endif()

TextEditWithClangCodeCompletion_configure_linker(texteditwithclangcodecompletion)

if(EMSCRIPTEN)
  TextEditWithClangCodeCompletion_configure_wasm_target(texteditwithclangcodecompletion
    TITLE "Text Edit with Clang Code Completion"
    DESCRIPTION "Qt-based text editor with Clang code completion"
  )
endif()

cmake_minimum_required(VERSION 3.16)

project(TextEditWithClangCodeCompletion LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets)

execute_process(COMMAND llvm-config --cxxflags OUTPUT_VARIABLE LLVM_CXXFLAGS OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND llvm-config --ldflags OUTPUT_VARIABLE LLVM_LDFLAGS OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND llvm-config --libs OUTPUT_VARIABLE LLVM_LIBS OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND llvm-config --system-libs OUTPUT_VARIABLE LLVM_SYSTEM_LIBS OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND llvm-config --includedir OUTPUT_VARIABLE LLVM_INCLUDE_DIR OUTPUT_STRIP_TRAILING_WHITESPACE)

add_executable(TextEditWithClangCodeCompletion main.cpp texteditwithclangcodecompletion.cpp texteditwithclangcodecompletion.h)

target_compile_options(TextEditWithClangCodeCompletion PRIVATE ${LLVM_CXXFLAGS})
target_include_directories(TextEditWithClangCodeCompletion PRIVATE ${LLVM_INCLUDE_DIR})
target_link_libraries(TextEditWithClangCodeCompletion PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets clang ${LLVM_LIBS} ${LLVM_SYSTEM_LIBS})
target_link_options(TextEditWithClangCodeCompletion PRIVATE ${LLVM_LDFLAGS})

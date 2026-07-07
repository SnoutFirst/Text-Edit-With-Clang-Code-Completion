# Text Edit with Clang Code Completion

A small Qt text editor that uses libclang to provide C/C++ code completion.

This repository was generated from the [cpp-best-practices/cmake_template](https://github.com/cpp-best-practices/cmake_template) and retains the original project history from `d3fault/Text-Edit-With-Clang-Code-Completion`.

## Build

### Requirements

- CMake >= 3.21
- Qt6 (Qt5 is used as a fallback)
- libclang / llvm-dev
- (optional) Ninja, ccache

### Configure and build

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

## CI / Deployment

The project is built on GitHub Actions for:

- Linux (gcc-14, llvm-19.1.1)
- macOS (llvm-19.1.1)
- Windows (MSVC)
- WebAssembly (Emscripten + Qt6 WASM + prebuilt libclang)

Packages are produced with CPack and release artifacts are attached to tags.
WASM builds are deployed to GitHub Pages.

## License

BSD-2-Clause (see `COPYING`).

// Stubs for LLVM Support symbols that are ABI-incompatible with the Emscripten
// longjmp/exception model used by Qt 6.7.3 official WASM binaries.
//
// The prebuilt libclang-wasm archive was built against emcc 3.1.61 with the
// Wasm longjmp runtime, while Qt 6.7.3 uses emcc 3.1.50 with the JS longjmp
// runtime.  Mixing the two at link time produces undefined references to
// __wasm_setjmp / emscripten_longjmp.  The only LLVM Support object that pulls
// those symbols in is CrashRecoveryContext.cpp.o, so we replace it with these
// no-op stubs.  The editor only uses libclang for parsing and code completion;
// actual crash recovery is unnecessary in the browser.

#include "llvm/Support/CrashRecoveryContext.h"

#include <cstdlib>
#include <vector>

namespace llvm {

struct StubCleanupStorage {
  std::vector<CrashRecoveryContextCleanup *> cleanups;
};

CrashRecoveryContextCleanup::~CrashRecoveryContextCleanup() = default;

CrashRecoveryContext::CrashRecoveryContext() = default;

CrashRecoveryContext::~CrashRecoveryContext() {
  // Delete any registered cleanups.  Recovering resources is unnecessary in a
  // stub, but we still own the cleanup objects.
  if (auto *storage = static_cast<StubCleanupStorage *>(Impl)) {
    for (CrashRecoveryContextCleanup *cleanup : storage->cleanups) {
      delete cleanup;
    }
    delete storage;
  }
}

void CrashRecoveryContext::Enable() {}
void CrashRecoveryContext::Disable() {}

CrashRecoveryContext *CrashRecoveryContext::GetCurrent() { return nullptr; }

bool CrashRecoveryContext::isRecoveringFromCrash() { return false; }

bool CrashRecoveryContext::RunSafely(function_ref<void()> Fn) {
  Fn();
  return true;
}

bool CrashRecoveryContext::RunSafelyOnThread(function_ref<void()> Fn,
                                              unsigned /*RequestedStackSize*/) {
  Fn();
  return true;
}

[[noreturn]] void CrashRecoveryContext::HandleExit(int /*RetCode*/) {
  __builtin_trap();
}

bool CrashRecoveryContext::isCrash(int /*RetCode*/) { return false; }

bool CrashRecoveryContext::throwIfCrash(int /*RetCode*/) { return false; }

void CrashRecoveryContext::registerCleanup(CrashRecoveryContextCleanup *cleanup) {
  if (!Impl) {
    Impl = new StubCleanupStorage();
  }
  static_cast<StubCleanupStorage *>(Impl)->cleanups.push_back(cleanup);
}

void CrashRecoveryContext::unregisterCleanup(CrashRecoveryContextCleanup *cleanup) {
  if (auto *storage = static_cast<StubCleanupStorage *>(Impl)) {
    auto &vec = storage->cleanups;
    for (auto it = vec.begin(); it != vec.end(); ++it) {
      if (*it == cleanup) {
        vec.erase(it);
        break;
      }
    }
  }
}

} // namespace llvm

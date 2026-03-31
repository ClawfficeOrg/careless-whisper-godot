#!/usr/bin/env bash
# check_windows_deps.sh
# Validate required files for careless-whisper-godot Windows build.
# Run from Git Bash or WSL from the repository root.
#
# Usage: bash scripts/check_windows_deps.sh [--release]

set -euo pipefail

BUILD_TYPE="${1:-debug}"
if [[ "$1" == "--release" ]]; then
  BUILD_TYPE="release"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="x86_64-pc-windows-msvc"
DLL_SRC="$REPO_ROOT/addons/os_control/target/$TARGET/$BUILD_TYPE/careless_whisper_os.dll"
DLL_DEST_DIR="$REPO_ROOT/addons/os_control/bin/windows"
DLL_DEST="$DLL_DEST_DIR/careless_whisper_os.dll"

PASS=0
FAIL=0

check() {
  local label="$1"
  local path="$2"
  if [[ -e "$path" ]]; then
    echo "  [OK]   $label"
    ((PASS++))
  else
    echo "  [MISS] $label — expected at: $path"
    ((FAIL++))
  fi
}

echo "=== careless-whisper Windows dependency check ==="
echo "Build type: $BUILD_TYPE"
echo ""

echo "--- Rust toolchain ---"
if command -v cargo &>/dev/null; then
  echo "  [OK]   cargo: $(cargo --version)"
  ((PASS++))
else
  echo "  [MISS] cargo not found — install rustup from https://rustup.rs"
  ((FAIL++))
fi

if rustup target list --installed 2>/dev/null | grep -q "$TARGET"; then
  echo "  [OK]   rustup target: $TARGET"
  ((PASS++))
else
  echo "  [MISS] rustup target $TARGET not installed"
  echo "         Run: rustup target add $TARGET"
  ((FAIL++))
fi

echo ""
echo "--- Built artifacts ---"
check "Extension DLL (build output)" "$DLL_SRC"
check "Extension DLL (bin/ deploy)"  "$DLL_DEST"

echo ""
echo "--- LLVM/libclang (for bindgen) ---"
if [[ -n "${LIBCLANG_PATH:-}" ]]; then
  check "libclang.dll" "$LIBCLANG_PATH/libclang.dll"
else
  echo "  [WARN] LIBCLANG_PATH not set — needed only if rebuilding crates with bindgen"
  echo "         Install LLVM and set: export LIBCLANG_PATH=/path/to/llvm/bin"
fi

echo ""
echo "--- Summary ---"
echo "  Passed: $PASS"
echo "  Missing: $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "Some checks failed. See BUILD_WINDOWS.md for setup instructions."
  exit 1
else
  echo "All required files present. Ready to run on Windows."
fi

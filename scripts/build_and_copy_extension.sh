#!/usr/bin/env bash
# Build the Rust GDExtension and copy the resulting DLL/shared lib into the
# project's addons/os_control/bin/{windows,linux,macos} folders.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADDON_DIR="$REPO_ROOT/addons/os_control"
BUILD_TYPE="debug"
TARGETS=()

usage() {
  cat <<EOF
Usage: $0 [--release|--debug] [--target windows|linux|macos|all]

Defaults: --debug --target all (builds debug for current host)

Options:
  --release    Build release artifacts (cargo build --release)
  --debug      Build debug artifacts (default)
  --target     Target platform: windows, linux, macos, all
EOF
}

TARGET="all"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)
      BUILD_TYPE="release"; shift ;;
    --debug)
      BUILD_TYPE="debug"; shift ;;
    --target)
      TARGET="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

mkdir -p "$ADDON_DIR/bin/windows" "$ADDON_DIR/bin/linux" "$ADDON_DIR/bin/macos"

pushd "$ADDON_DIR" >/dev/null

case "$TARGET" in
  windows)
    cargo build --target x86_64-pc-windows-msvc $( [ "$BUILD_TYPE" = "release" ] && echo "--release" )
    cp "target/x86_64-pc-windows-msvc/$BUILD_TYPE/careless_whisper_os.dll" "bin/windows/"
    ;;
  linux)
    cargo build $( [ "$BUILD_TYPE" = "release" ] && echo "--release" )
    cp "target/$BUILD_TYPE/libcareless_whisper_os.so" "bin/linux/"
    ;;
  macos)
    cargo build $( [ "$BUILD_TYPE" = "release" ] && echo "--release" )
    cp "target/$BUILD_TYPE/libcareless_whisper_os.dylib" "bin/macos/"
    ;;
  all)
    # Build native host target for linux/mac on this machine
    cargo build $( [ "$BUILD_TYPE" = "release" ] && echo "--release" )
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
      cp "target/$BUILD_TYPE/libcareless_whisper_os.so" "bin/linux/"
    fi
    if [[ "$OSTYPE" == "darwin" ]]; then
      cp "target/$BUILD_TYPE/libcareless_whisper_os.dylib" "bin/macos/"
    fi
    # Windows target build requires MSVC toolchain — user should run on Windows
    ;;
esac

popd >/dev/null

echo "Build and copy complete (type=$BUILD_TYPE, target=$TARGET)"
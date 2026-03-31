#!/usr/bin/env bash
# Run Godot with RUST_BACKTRACE=1 for helpful Rust panic backtraces.
# Usage: ./scripts/run_godot_with_backtrace.sh [--path /path/to/project] [--godot /path/to/Godot.exe]

set -euo pipefail

PROJECT_DIR="."
GODOT_BIN="godot"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --path)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --godot)
      GODOT_BIN="$2"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

echo "Running Godot with RUST_BACKTRACE=1"
RUST_BACKTRACE=1 "$GODOT_BIN" --path "$PROJECT_DIR" "$@"

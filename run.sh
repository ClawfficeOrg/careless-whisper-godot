#!/usr/bin/env bash
# run.sh — Launch Careless Whisper in the Godot editor or as headless
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find godot binary
GODOT=""
for candidate in godot godot4 godot-4.6 /usr/local/bin/godot /usr/bin/godot; do
    if command -v "$candidate" &>/dev/null; then
        GODOT="$candidate"
        break
    fi
done

if [ -z "$GODOT" ]; then
    echo "ERROR: Godot binary not found. Install Godot 4.6+ and ensure it's in PATH."
    echo "Download: https://godotengine.org/download"
    exit 1
fi

echo "Using Godot: $GODOT ($($GODOT --version 2>/dev/null || echo 'version unknown'))"
echo "Project: $SCRIPT_DIR"

# Check for model
MODEL_PATH="$SCRIPT_DIR/models/ggml-base.en.bin"
if [ -f "$MODEL_PATH" ]; then
    echo "Model: $MODEL_PATH ($(du -sh "$MODEL_PATH" | cut -f1))"
else
    echo "WARNING: Model not found at $MODEL_PATH"
    echo "         Run: curl -L -o models/ggml-base.en.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
fi

echo ""
echo "Launching..."
"$GODOT" --path "$SCRIPT_DIR" "$@"

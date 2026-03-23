#!/bin/bash
# GDScript Linting Script
# Validates all GDScript files by running Godot in headless mode
# Usage: ./scripts/lint.sh [--verbose] [--strict]
#
# Exit codes:
#   0 - No errors found
#   1 - Errors found (when --strict is used)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

VERBOSE=false
STRICT=false

for arg in "$@"; do
    case $arg in
        --verbose|-v) VERBOSE=true ;;
        --strict|-s) STRICT=true ;;
    esac
done

echo "🔍 Linting GDScript files..."
echo ""

# Run Godot in headless mode to validate scripts
# --headless: No display
# --quit-after: Timeout in seconds (prevents hanging)
OUTPUT=$(godot --headless --quit-after 10 2>&1)
EXIT_CODE=$?

# Check for errors and warnings
ERRORS=$(echo "$OUTPUT" | grep -E "(SCRIPT ERROR|Compile Error|Parse Error)" || true)
WARNINGS=$(echo "$OUTPUT" | grep -E "(warning|Warning)" || true)

if [ "$VERBOSE" = true ]; then
    echo "$OUTPUT"
else
    if [ -n "$ERRORS" ]; then
        echo "❌ Errors found:"
        echo "$ERRORS"
    fi
    if [ -n "$WARNINGS" ]; then
        echo "⚠️  Warnings:"
        echo "$WARNINGS"
    fi
fi

echo ""
if [ -n "$ERRORS" ]; then
    echo "❌ Lint failed with errors"
    if [ "$STRICT" = true ]; then
        exit 1
    fi
elif [ -n "$WARNINGS" ]; then
    echo "⚠️  Lint passed with warnings"
else
    echo "✅ Lint complete - no issues found"
fi

exit 0

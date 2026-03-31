#!/bin/bash
# Servo Browser Launcher for Converged Platform
# Launches browser from servo_src/ without servo_origin/ dependency

set -e

echo "=== Servo Browser Launcher - Converged Platform ==="
echo

# Verify binary exists
if [ ! -f "./servoshell.exe" ]; then
    echo "❌ Error: servoshell.exe not found"
    echo "Please ensure browser is in: ./servoshell.exe"
    exit 1
fi

# Verify DLLs exist
if [ ! -d "./runtime" ]; then
    echo "❌ Error: runtime/ directory not found"
    echo "Please copy all DLLs from servo_origin/target/debug/ to servo_src/runtime/"
    exit 1
fi

# Verify DLLs are present
DLL_COUNT=$(ls runtime/*.dll 2>/dev/null | wc -l)
if [ "$DLL_COUNT" -lt 50 ]; then
    echo "⚠ Warning: Less than 50 DLLs found in runtime/ directory"
    echo "Expected: 91 DLL files from servo_origin/target/debug/"
fi

# Default URL
DEFAULT_URL="file:///D:/workspace/claude/servo-multi/servo_src/fixtures/multilingual-test.html"

# Check if URL provided as argument
if [ -n "$1" ]; then
    URL="$1"
else
    URL="$DEFAULT_URL"
fi

echo "Browser: ./servoshell.exe"
echo "Runtime: ./runtime/ (DLLs)"
echo "URL: $URL"
echo
echo "Launching browser..."
echo "Close the browser window (Alt+F4 or Ctrl+C) to exit."
echo

# Set PATH to include runtime DLLs
export PATH="./runtime:$PATH"

# Set user stylesheet for CJK font fallback
export SERVO_USER_STYLESHEET="/d/workspace/claude/servo-multi/servo_src/fixtures/cjk-font-fallback.css"

# Launch servoshell with CJK font fallback
"./servoshell.exe" --user-stylesheet "$SERVO_USER_STYLESHEET" "$URL"
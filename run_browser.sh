#!/bin/bash
# Servo Browser Launcher
# This script launches the servoshell browser with proper configuration

set -e

echo "=== Servo Browser Launcher ==="
echo

# Check for servoshell binary
if [ ! -f "servo_origin/target/debug/servoshell.exe" ]; then
    echo "❌ Error: servoshell binary not found"
    echo "Please build servoshell first:"
    echo "  cd servo_origin/ports/servoshell"
    echo "  cargo build --target x86_64-pc-windows-msvc"
    exit 1
fi

# Default URL
DEFAULT_URL="file:///D:/workspace/claude/servo-multi/servo_src/fixtures/multilingual-test.html"

# Check if URL provided as argument
if [ -n "$1" ]; then
    URL="$1"
else
    URL="$DEFAULT_URL"
fi

echo "Browser: servo_origin/target/debug/servoshell.exe"
echo "URL: $URL"
echo
echo "Launching browser..."
echo "Close the browser window (Alt+F4 or Ctrl+C) to exit."
echo

# Launch servoshell
"./servo_origin/target/debug/servoshell.exe" "$URL"
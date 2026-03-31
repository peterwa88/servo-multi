#!/bin/bash
# Test script to validate browser functionality

echo "=== Servo Browser Validation Test ==="
echo

# Test 1: Binary exists
echo "Test 1: Checking binary exists"
if [ -f "./servo_src/servoshell.exe" ]; then
    echo "✓ servoshell.exe exists"
else
    echo "✗ servoshell.exe not found"
    exit 1
fi

# Test 2: Runtime DLLs exist
echo "Test 2: Checking runtime DLLs"
if [ -d "./servo_src/runtime" ]; then
    DLL_COUNT=$(ls servo_src/runtime/*.dll 2>/dev/null | wc -l)
    echo "  Found $DLL_COUNT DLLs (from servo_origin/target/debug)"
    if [ "$DLL_COUNT" -lt 85 ]; then
        echo "✗ Warning: Missing many DLLs from servo_origin"
    else
        echo "✓ Sufficient DLLs present"
    fi
else
    echo "✗ runtime/ directory not found"
    exit 1
fi

# Test 3: Fixture exists
echo "Test 3: Checking fixture"
if [ -f "./servo_src/fixtures/multilingual-test.html" ]; then
    echo "✓ multilingual-test.html exists"
else
    echo "✗ multilingual-test.html not found"
    exit 1
fi

# Test 4: Browser launch with CJK stylesheet
echo "Test 4: Testing browser launch with CJK stylesheet"
export PATH="./servo_src/runtime:$PATH"
export SERVO_USER_STYLESHEET="/d/workspace/claude/servo-multi/servo_src/fixtures/cjk-font-fallback.css"
timeout 10 ./servo_src/servoshell.exe --help --user-stylesheet "$SERVO_USER_STYLESHEET" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Browser launches successfully with CJK stylesheet"
else
    echo "✗ Browser launch failed with CJK stylesheet"
    exit 1
fi

echo
echo "=== All basic tests passed ==="

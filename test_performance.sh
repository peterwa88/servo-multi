#!/bin/bash
# Performance test for Servo browser

echo "=== Servo Browser Performance Test ==="
echo

# Test URL
TEST_URL="https://www.baidu.com/"

echo "Test URL: $TEST_URL"
echo "Expected: Baidu should load in reasonable time"
echo

# Set environment
export PATH="./servo_src/runtime:$PATH"
export SERVO_USER_STYLESHEET="/d/workspace/claude/servo-multi/servo_src/fixtures/cjk-font-fallback.css"

# Clear any previous logs
rm -f /tmp/servo-performance.log 2>/dev/null

# Start browser with logging
echo "Starting browser with logging..."
echo "Browser output will be saved to /tmp/servo-performance.log"
echo

# Launch browser in background and capture output
./servo_src/servoshell.exe \
    --user-stylesheet "$SERVO_USER_STYLESHEET" \
    "$TEST_URL" \
    > /tmp/servo-performance.log 2>&1 &

BROWSER_PID=$!

echo "Browser started with PID: $BROWSER_PID"
echo "Waiting for initial load (10 seconds)..."
sleep 10

# Check if browser is still running
if ps -p $BROWSER_PID > /dev/null 2>&1; then
    echo "Browser is still running. Checking logs..."
    echo
    echo "=== Initial Log Output ==="
    head -50 /tmp/servo-performance.log

    echo
    echo "=== Network/Resource Loading Logs ==="
    grep -i "load\|network\|request\|fetch\|resource" /tmp/servo-performance.log | head -20

    echo
    echo "=== Timing Information ==="
    grep -i "time\|ms\|s\|render\|paint\|frame" /tmp/servo-performance.log | head -20

    echo
    echo "Stopping browser..."
    kill $BROWSER_PID 2>/dev/null
    wait $BROWSER_PID 2>/dev/null
else
    echo "Browser closed prematurely"
    echo "=== Last Log Output ==="
    tail -50 /tmp/servo-performance.log
fi

echo
echo "=== Performance Test Complete ==="
echo "Check /tmp/servo-performance.log for full output"
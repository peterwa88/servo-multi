
#!/usr/bin/env bash

set -euo pipefail



ROOT="$(cd "$(dirname "$0")" && pwd)"

cd "$ROOT"



echo "========================================"

echo "Unicode/CJK validation"

echo "ROOT: $ROOT"

echo "========================================"



if [ ! -f "./servoshell.exe" ]; then

  echo "[ERROR] ./servoshell.exe not found"

  echo "Run ./build_product.sh first."

  exit 1

fi



if [ ! -d "./runtime" ]; then

  echo "[ERROR] ./runtime not found"

  echo "Run ./build_product.sh first."

  exit 1

fi



export PATH="./runtime:$PATH"



URL="file:///D:/workspace/claude/servo-multi/servo_src/fixtures/multilingual-test.html"



echo "[INFO] Launching:"

echo "  ./servoshell.exe $URL"



# Kill old process if any

ps aux | grep -E "(servoshell|servo_browser)" | grep -v grep | awk '{print $2}' | xargs -r kill -9 || true



./servoshell.exe "$URL" &

PID=$!



echo "[INFO] PID=$PID"

sleep 10



if ps -p "$PID" >/dev/null 2>&1; then

  echo "[OK] servoshell.exe is still running"

else

  echo "[WARN] servoshell.exe exited early"

fi



echo

echo "Manual verification checklist:"

echo "  1. Chinese tab title should read: 多语言测试页面 - Multilingual Test"

echo "  2. H1 should read: 多语言测试页面"

echo "  3. Body Chinese should render without □"

echo "  4. Mixed Chinese/English should render without □"

echo "  5. Input value should display Chinese correctly"



echo

echo "[INFO] Close the browser window manually after checking."

wait $PID || true


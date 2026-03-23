#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVO_DIR="$ROOT/servo_origin"
UPSTREAM_URL="${SERVO_UPSTREAM_URL:-https://github.com/servo/servo.git}"

if [ -d "$SERVO_DIR/.git" ]; then
  echo "[info] servo_origin already initialized"
else
  rm -rf "$SERVO_DIR"
  git clone "$UPSTREAM_URL" "$SERVO_DIR"
fi

cd "$SERVO_DIR"

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$UPSTREAM_URL"

PIN_FILE="$ROOT/SERVO_UPSTREAM_PIN.txt"
if [ -f "$PIN_FILE" ]; then
  PIN="$(tr -d ' \n\r' < "$PIN_FILE")"
  if [ -n "$PIN" ]; then
    git fetch upstream
    git checkout "$PIN"
  fi
fi

echo "[done] servo_origin is ready at $SERVO_DIR"
git rev-parse HEAD

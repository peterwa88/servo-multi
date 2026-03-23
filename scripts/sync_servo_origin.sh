#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/servo_origin"

git fetch upstream
git checkout main
git pull --ff-only upstream main

echo "[done] servo_origin updated to upstream/main"
git rev-parse HEAD

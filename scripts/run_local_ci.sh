#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ -f servo_src/Cargo.toml ]; then
  cargo fmt --manifest-path servo_src/Cargo.toml --all --check
  cargo clippy --manifest-path servo_src/Cargo.toml --workspace --all-targets --all-features -- -D warnings || true
  cargo test --manifest-path servo_src/Cargo.toml --workspace
else
  echo "[warn] servo_src/Cargo.toml not found yet"
fi

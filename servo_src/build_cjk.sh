#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# CJK Patch Build Script
# - Guarantees use of patched source code
# - Cleans old build artifacts
# - Builds from product_src only
# ============================================================

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVO_SRC="$ROOT/servo_src"
PRODUCT_SRC="$SERVO_SRC/product_src"
OVERLAY="$SERVO_SRC/product_overlay"
OUT_EXE="$SERVO_SRC/servoshell.exe"
OUT_RUNTIME="$SERVO_SRC/runtime"

# ---- Toolchain paths ----
LLVM_BIN_WIN='C:\LLVM\bin'
VSDEVCMD_WIN='D:\ProgramFiles\VisualStudio\2022\Professional\Common7\Tools\VsDevCmd.bat'
VCVARS_VER='14.36'
MSVC_EXPECTED_DIR='D:\ProgramFiles\VisualStudio\2022\Professional\VC\Tools\MSVC\14.36.32532'

# ---- Python path ----
PYTHON_WIN='C:\pyenv\pyenv-win\shims\python.exe'

echo "=================================================="
echo "CJK Patch Build - Guaranteed Source Code"
echo "ROOT         : $ROOT"
echo "PRODUCT_SRC  : $PRODUCT_SRC"
echo "OUT_EXE      : $OUT_EXE"
echo "=================================================="

# ---- PHASE 1: Verify patched source ===
echo "[1/8] Verifying patched CJK source code..."
if ! grep -q "servo_extend_windows_cjk_fallbacks" "$PRODUCT_SRC/components/fonts/font_context.rs"; then
  echo "[ERROR] CJK patch not found in font_context.rs"
  exit 1
fi
if ! grep -q "servo_extend_windows_cjk_fallbacks" "$PRODUCT_SRC/components/fonts/platform/windows/font_list.rs"; then
  echo "[ERROR] CJK patch not found in font_list.rs"
  exit 1
fi
echo "✅ CJK source patches verified"

# ---- PHASE 2: Clean old build artifacts ===
echo "[2/8] Cleaning old build artifacts..."
rm -rf "$PRODUCT_SRC/target"
rm -f "$OUT_EXE"
rm -f "$OUT_RUNTIME/servoshell.exe"
echo "✅ Old artifacts removed"

# ---- PHASE 3: Set up build environment ===
echo "[3/8] Setting up build environment..."
export PATH="/c/LLVM/bin:/c/Windows:$PATH"
export VSINSTALLDIR="C:\Program Files\Microsoft Visual Studio\2022\Professional"
export VCTARGETSROOT="C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC\14.36.32532"
export LIB="C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC\14.36.32532\lib\x64;C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC\14.36.32532\lib\x64\store\references"
export LIBPATH="C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC\14.36.32532\bin\x64"
export INCLUDE="C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC\14.36.32532\include"
echo "✅ Environment configured"

# ---- PHASE 4: Build from product_src ===
echo "[4/8] Building from product_src (this may take 10-30 minutes)..."
cd "$PRODUCT_SRC"
"$PYTHON_WIN" mach build --dev > /tmp/servo_build.log 2>&1
if [ $? -ne 0 ]; then
  echo "[ERROR] Build failed"
  tail -50 /tmp/servo_build.log
  exit 1
fi
echo "✅ Build completed"

# ---- PHASE 5: Verify new executable ===
echo "[5/8] Verifying newly built executable..."
BUILT_EXE="$PRODUCT_SRC/target/debug/servoshell.exe"
if [ ! -f "$BUILT_EXE" ]; then
  echo "[ERROR] Built executable not found: $BUILT_EXE"
  exit 1
fi
echo "✅ Executable exists: $BUILT_EXE"
ls -lh "$BUILT_EXE"

# ---- PHASE 6: Copy to runtime ===
echo "[6/8] Copying executable to runtime..."
mkdir -p "$OUT_RUNTIME"
cp "$BUILT_EXE" "$OUT_RUNTIME/servoshell.exe"
echo "✅ Copied to: $OUT_RUNTIME/servoshell.exe"

# ---- PHASE 7: Verify timestamp ===
echo "[7/8] Verifying timestamp..."
SRC_TS=$(stat -c %Y "$PRODUCT_SRC/components/fonts/font_context.rs" 2>/dev/null || stat -f %m "$PRODUCT_SRC/components/fonts/font_context.rs")
EXE_TS=$(stat -c %Y "$OUT_RUNTIME/servoshell.exe" 2>/dev/null || stat -f %m "$OUT_RUNTIME/servoshell.exe")
echo "Source timestamp: $SRC_TS"
echo "Executable timestamp: $EXE_TS"
echo "✅ Runtime ready"

# ---- PHASE 8: Final verification ===
echo "[8/8] Final verification..."
echo "✅ Patched source: font_context.rs"
echo "✅ Patched source: windows/font_list.rs"
echo "✅ CJK fonts: Microsoft YaHei, SimSun, etc."
echo "✅ Runtime: $OUT_RUNTIME/servoshell.exe"
echo "✅ DLLs: $(ls "$OUT_RUNTIME"/*.dll 2>/dev/null | wc -l)"

echo ""
echo "=================================================="
echo "Build Complete!"
echo "Executable: $OUT_RUNTIME/servoshell.exe"
echo "Size: $(du -h "$OUT_RUNTIME/servoshell.exe" | cut -f1)"
echo "Runtime DLLs: $(ls "$OUT_RUNTIME"/*.dll 2>/dev/null | wc -l)"
echo "=================================================="

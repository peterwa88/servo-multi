#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Servo Product Build Script
# - Forces Clang 17
# - Forces MSVC toolset 14.36.32532
# - Builds product_src from servo_origin
# - Applies overlay patches from servo_src/product_overlay
# - Packages final runtime into servo_src/
# ============================================================

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVO_SRC="$ROOT/servo_src"
UPSTREAM="$ROOT/servo_origin"
PRODUCT_SRC="$SERVO_SRC/product_src"
OVERLAY="$SERVO_SRC/product_overlay"
OUT_EXE="$SERVO_SRC/servoshell.exe"
OUT_RUNTIME="$SERVO_SRC/runtime"

# ---- Fixed toolchain paths (based on your machine) ----
LLVM_BIN_WIN='C:\LLVM\bin'
VSDEVCMD_WIN='D:\ProgramFiles\VisualStudio\2022\Professional\Common7\Tools\VsDevCmd.bat'
VCVARS_VER='14.36'
MSVC_EXPECTED_DIR='D:\ProgramFiles\VisualStudio\2022\Professional\VC\Tools\MSVC\14.36.32532'

# ---- Helper: convert Git Bash path to Windows path ----
to_win() {
  cygpath -aw "$1"
}

echo "============================================================"
echo "Servo Product Build"
echo "ROOT         : $ROOT"
echo "SERVO_SRC    : $SERVO_SRC"
echo "UPSTREAM     : $UPSTREAM"
echo "PRODUCT_SRC  : $PRODUCT_SRC"
echo "OVERLAY      : $OVERLAY"
echo "OUT_EXE      : $OUT_EXE"
echo "OUT_RUNTIME  : $OUT_RUNTIME"
echo "============================================================"

# ---- Basic checks ----
if [ ! -d "$UPSTREAM" ]; then
  echo "[ERROR] servo_origin not found: $UPSTREAM"
  exit 1
fi

if [ ! -d "$SERVO_SRC" ]; then
  echo "[ERROR] servo_src not found: $SERVO_SRC"
  exit 1
fi

if [ ! -f "$VSDEVCMD_WIN" ]; then
  echo "[ERROR] VsDevCmd.bat not found:"
  echo "        $VSDEVCMD_WIN"
  exit 1
fi

if [ ! -d "$MSVC_EXPECTED_DIR" ]; then
  echo "[ERROR] Expected MSVC 14.36 toolset not found:"
  echo "        $MSVC_EXPECTED_DIR"
  exit 1
fi

if [ ! -x /c/LLVM/bin/clang ] && [ ! -x /c/LLVM/bin/clang.exe ]; then
  echo "[ERROR] Expected Clang 17 not found at C:\\LLVM\\bin"
  exit 1
fi

PYTHON_BIN="$(command -v python || true)"
if [ -z "$PYTHON_BIN" ]; then
  echo "[ERROR] python not found in current shell PATH"
  exit 1
fi

PYTHON_WIN="$(to_win "$PYTHON_BIN")"
PRODUCT_SRC_WIN="$(to_win "$PRODUCT_SRC")"

echo "[DEBUG] Current bash python: $PYTHON_BIN"
echo "[DEBUG] Windows python path : $PYTHON_WIN"

# ---- Kill running browser processes to avoid file locks ----
echo "[1/9] Killing running browser processes if any..."
ps aux | grep -E "(servoshell|servo_browser)" | grep -v grep | awk '{print $2}' | xargs -r kill -9 || true

# ---- Prepare product source ----
echo "[2/9] Preparing product source tree..."
rm -rf "$PRODUCT_SRC"
mkdir -p "$PRODUCT_SRC"

echo "[3/9] Copying upstream source into product_src..."
cp -a "$UPSTREAM"/. "$PRODUCT_SRC"/

# ---- Apply overlay source files ----
echo "[4/9] Applying overlay files..."
if [ -d "$OVERLAY" ]; then
  cp -a "$OVERLAY"/. "$PRODUCT_SRC"/
else
  echo "[WARN] No overlay directory found: $OVERLAY"
fi

# ---- Run patch scripts if present ----
echo "[5/9] Running patch scripts if present..."
if [ -f "$OVERLAY/patch_font_system.sh" ]; then
  (cd "$PRODUCT_SRC" && bash "$OVERLAY/patch_font_system.sh")
else
  echo "[INFO] No patch_font_system.sh found, skipping"
fi

# ---- Debug source tree before build ----
echo "[6/9] Inspecting product source tree..."
find "$PRODUCT_SRC" -maxdepth 4 -type d \( -name components -o -name gfx -o -name platform -o -name windows \) 2>/dev/null || true
echo "[DEBUG] Searching key font-related identifiers..."
grep -R "last_resort" -n "$PRODUCT_SRC/components" 2>/dev/null | head -30 || true
grep -R "cjk_fallback" -n "$PRODUCT_SRC/components" 2>/dev/null | head -30 || true
grep -R "FontContext" -n "$PRODUCT_SRC/components" 2>/dev/null | head -30 || true
grep -R "FontGroup" -n "$PRODUCT_SRC/components" 2>/dev/null | head -30 || true

# ---- Build using fixed VS 14.36 + Clang 17 ----
echo "[7/9] Building with Clang 17 + MSVC 14.36..."
BUILD_CMD_FILE="$(mktemp --suffix=.cmd)"

cat > "$BUILD_CMD_FILE" <<EOF
@echo off
setlocal

echo ============================================================
echo [BUILD ENV] Entering VS environment with old toolset
echo ============================================================

call "$VSDEVCMD_WIN" -arch=x64 -host_arch=x64 -vcvars_ver=$VCVARS_VER
if errorlevel 1 (
  echo [ERROR] Failed to initialize VS environment
  exit /b 1
)

set "PATH=$LLVM_BIN_WIN;%PATH%"

echo [DEBUG] where clang:
where clang
echo [DEBUG] where clang-cl:
where clang-cl

echo [DEBUG] clang version:
clang --version
if errorlevel 1 exit /b 1

echo [DEBUG] clang-cl version:
clang-cl --version
if errorlevel 1 exit /b 1

echo [DEBUG] VCToolsVersion=%VCToolsVersion%
echo [DEBUG] VCToolsInstallDir=%VCToolsInstallDir%
echo [DEBUG] INCLUDE=%INCLUDE%
echo [DEBUG] LIB=%LIB%

cd /d "$PRODUCT_SRC_WIN"
if errorlevel 1 (
  echo [ERROR] Failed to cd into product_src
  exit /b 1
)

echo ============================================================
echo [BUILD] Running Servo build
echo ============================================================

"$PYTHON_WIN" mach build --dev
if errorlevel 1 (
  echo [ERROR] Servo build failed
  exit /b 1
)

echo [OK] Build completed
exit /b 0
EOF

cmd.exe /c "$BUILD_CMD_FILE"
rm -f "$BUILD_CMD_FILE"

# ---- Package executable ----
echo "[8/9] Packaging executable and runtime artifacts..."
mkdir -p "$OUT_RUNTIME"

if [ ! -f "$PRODUCT_SRC/target/debug/servoshell.exe" ]; then
  echo "[ERROR] Built executable not found:"
  echo "        $PRODUCT_SRC/target/debug/servoshell.exe"
  exit 1
fi

cp -f "$PRODUCT_SRC/target/debug/servoshell.exe" "$OUT_EXE"

# Clean old runtime
find "$OUT_RUNTIME" -mindepth 1 -maxdepth 1 -exec rm -rf {} + || true

# Copy debug output DLLs/PDBs
find "$PRODUCT_SRC/target/debug" -maxdepth 1 -type f \( -iname '*.dll' -o -iname '*.pdb' \) -exec cp -f {} "$OUT_RUNTIME/" \; || true

# Copy resources if present
if [ -d "$PRODUCT_SRC/resources" ]; then
  mkdir -p "$OUT_RUNTIME/resources"
  cp -a "$PRODUCT_SRC/resources"/. "$OUT_RUNTIME/resources"/
fi

# Copy GStreamer runtime if available
if [ -n "${GSTREAMER_1_0_ROOT_MSVC_X86_64:-}" ] && [ -d "${GSTREAMER_1_0_ROOT_MSVC_X86_64}/bin" ]; then
  echo "[INFO] Copying GStreamer runtime DLLs..."
  find "${GSTREAMER_1_0_ROOT_MSVC_X86_64}/bin" -maxdepth 1 -type f -iname '*.dll' -exec cp -f {} "$OUT_RUNTIME/" \; || true
else
  echo "[INFO] GSTREAMER_1_0_ROOT_MSVC_X86_64 not set or invalid, skipping GStreamer DLL copy"
fi

# Copy MSVC redistributables if available
if [ -n "${WIN32_REDIST_DIR:-}" ] && [ -d "${WIN32_REDIST_DIR}" ]; then
  echo "[INFO] Copying MSVC redistributable DLLs..."
  find "${WIN32_REDIST_DIR}" -maxdepth 1 -type f -iname '*.dll' -exec cp -f {} "$OUT_RUNTIME/" \; || true
else
  echo "[INFO] WIN32_REDIST_DIR not set or invalid, skipping redist DLL copy"
fi

# ---- Final report ----
echo "[9/9] Build complete."
echo
echo "Executable:"
ls -lh "$OUT_EXE"
echo
echo "Runtime artifact count:"
find "$OUT_RUNTIME" -maxdepth 1 -type f | wc -l
echo
echo "Top-level runtime listing (first 60 files):"
find "$OUT_RUNTIME" -maxdepth 1 -type f | sed 's#^#  - #' | head -60

echo
echo "============================================================"
echo "NEXT STEP"
echo "============================================================"
echo "Run with:"
echo "  cd \"$SERVO_SRC\""
echo "  export PATH=\"./runtime:\$PATH\""
echo "  ./servoshell.exe file:///D:/workspace/claude/servo-multi/servo_src/fixtures/multilingual-test.html"
echo
echo "If build succeeds, then continue Unicode/CJK validation."
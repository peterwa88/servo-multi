#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Servo Product Build Script (Git Bash)
# - Uses Clang 17
# - Uses MSVC toolset 14.36.32532
# - Keeps servo_src/product_src as maintained product source
# - Copies from servo_origin only when missing or when user confirms
# - Applies overlay + patch scripts
# - Forces final linker to link.exe
# - Packages final runtime into servo_src/runtime
# ============================================================

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVO_SRC="$ROOT/servo_src"
UPSTREAM="$ROOT/servo_origin"
PRODUCT_SRC="$SERVO_SRC/product_src"
OVERLAY="$SERVO_SRC/product_overlay"
OUT_RUNTIME="$SERVO_SRC/runtime"
OUT_EXE="$OUT_RUNTIME/servoshell.exe"

LLVM_BIN_WIN='C:\LLVM\bin'
VSDEVCMD_WIN='D:\ProgramFiles\VisualStudio\2022\Professional\Common7\Tools\VsDevCmd.bat'
VCVARS_VER='14.36'
MSVC_EXPECTED_DIR='D:\ProgramFiles\VisualStudio\2022\Professional\VC\Tools\MSVC\14.36.32532'

to_win() {
  cygpath -aw "$1"
}

echo "============================================================"
echo "Servo Product Build (Git Bash)"
echo "ROOT         : $ROOT"
echo "SERVO_SRC    : $SERVO_SRC"
echo "UPSTREAM     : $UPSTREAM"
echo "PRODUCT_SRC  : $PRODUCT_SRC"
echo "OVERLAY      : $OVERLAY"
echo "OUT_RUNTIME  : $OUT_RUNTIME"
echo "OUT_EXE      : $OUT_EXE"
echo "============================================================"

if [ ! -d "$UPSTREAM" ]; then
  echo "[ERROR] servo_origin not found: $UPSTREAM"
  exit 1
fi

if [ ! -d "$SERVO_SRC" ]; then
  echo "[ERROR] servo_src not found: $SERVO_SRC"
  exit 1
fi

if [ ! -f "$VSDEVCMD_WIN" ]; then
  echo "[ERROR] VsDevCmd.bat not found: $VSDEVCMD_WIN"
  exit 1
fi

if [ ! -d "$MSVC_EXPECTED_DIR" ]; then
  echo "[ERROR] Expected MSVC 14.36 toolset not found: $MSVC_EXPECTED_DIR"
  exit 1
fi

if [ ! -x /c/LLVM/bin/clang ] && [ ! -x /c/LLVM/bin/clang.exe ]; then
  echo "[ERROR] Expected Clang 17 not found at C:\\LLVM\\bin"
  exit 1
fi

PYTHON_BIN="/c/Python314/python.exe"
if [ ! -f "$PYTHON_BIN" ]; then
  PYTHON_BIN="$(command -v python || true)"
  if [ -z "$PYTHON_BIN" ]; then
    echo "[ERROR] python not found in current shell PATH"
    exit 1
  fi
fi

export PYTHON3="$PYTHON_BIN"

PYTHON_WIN="$(to_win "$PYTHON_BIN")"
PRODUCT_SRC_WIN="$(to_win "$PRODUCT_SRC")"

echo "[DEBUG] Current bash python: $PYTHON_BIN"
echo "[DEBUG] Windows python path : $PYTHON_WIN"

echo "[1/8] Killing running browser processes if any..."
ps aux | grep -E "(servoshell|servo_browser)" | grep -v grep | awk '{print $2}' | xargs -r kill -9 || true

echo "[2/8] Preparing product source tree..."
if [ ! -d "$PRODUCT_SRC" ]; then
  echo "[INFO] product_src does not exist. Copying from servo_origin..."
  mkdir -p "$PRODUCT_SRC"
  cp -a "$UPSTREAM"/. "$PRODUCT_SRC"/
else
  echo "[INFO] product_src already exists."
  echo "[INFO] Refresh product_src from servo_origin? Type 'y' to refresh, anything else to keep current product_src:"
  read -r REFRESH_CHOICE || true
  if [ "${REFRESH_CHOICE:-n}" = "y" ] || [ "${REFRESH_CHOICE:-n}" = "Y" ]; then
    echo "[INFO] Refreshing product_src from servo_origin..."
    rm -rf "$PRODUCT_SRC"
    mkdir -p "$PRODUCT_SRC"
    cp -a "$UPSTREAM"/. "$PRODUCT_SRC"/
  else
    echo "[INFO] Keeping existing product_src."
  fi
fi

echo "[3/8] Applying overlay files..."
if [ -d "$OVERLAY" ]; then
  cp -a "$OVERLAY"/. "$PRODUCT_SRC"/
else
  echo "[WARN] No overlay directory found: $OVERLAY"
fi

echo "[4/8] Running patch scripts if present..."
if [ -f "$OVERLAY/patch_font_system.sh" ]; then
  echo "[INFO] Running patch_font_system.sh..."
  (cd "$PRODUCT_SRC" && bash "$OVERLAY/patch_font_system.sh")
else
  echo "[INFO] No patch_font_system.sh found, skipping"
fi

if [ -f "$SERVO_SRC/apply_unicode_patch.py" ]; then
  echo "[INFO] Running apply_unicode_patch.py..."
  "$PYTHON_BIN" "$SERVO_SRC/apply_unicode_patch.py"
else
  echo "[INFO] No apply_unicode_patch.py found, skipping"
fi

if [ -f "$SERVO_SRC/apply_ui_clipboard_patch.py" ]; then
  echo "[INFO] Running apply_ui_clipboard_patch.py..."
  "$PYTHON_BIN" "$SERVO_SRC/apply_ui_clipboard_patch.py"
else
  echo "[INFO] No apply_ui_clipboard_patch.py found, skipping"
fi

if [ -f "$SERVO_SRC/apply_tab_egui_patch.py" ]; then
  echo "[INFO] Running apply_tab_egui_patch.py..."
  "$PYTHON_BIN" "$SERVO_SRC/apply_tab_egui_patch.py"
else
  echo "[INFO] No apply_tab_egui_patch.py found, skipping"
fi

echo "[5/8] Inspecting product source tree..."
find "$PRODUCT_SRC" -maxdepth 4 -type d \( -name components -o -name fonts -o -name platform -o -name windows -o -name ports \) 2>/dev/null || true
grep -R "fallback_font_families" -n "$PRODUCT_SRC/components" 2>/dev/null | head -20 || true
grep -R "servo_extend_windows_cjk_fallbacks" -n "$PRODUCT_SRC/components" 2>/dev/null | head -20 || true

echo "[6/8] Cleaning old target to avoid stale executable..."
rm -rf "$PRODUCT_SRC/target"

echo "[6/8] Building with Clang 17 + MSVC 14.36 + link.exe..."
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
set "CC=clang-cl"
set "CXX=clang-cl"
set "CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER=link.exe"
set "RUSTFLAGS=-Clinker=link.exe"
set "PYTHON3=$PYTHON_WIN"

echo [DEBUG] where clang:
where clang
echo [DEBUG] where clang-cl:
where clang-cl
echo [DEBUG] where link:
where link

echo [DEBUG] clang version:
clang --version
if errorlevel 1 exit /b 1

echo [DEBUG] clang-cl version:
clang-cl --version
if errorlevel 1 exit /b 1

echo [DEBUG] VCToolsVersion=%VCToolsVersion%
echo [DEBUG] VCToolsInstallDir=%VCToolsInstallDir%
echo [DEBUG] CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER=%CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER%
echo [DEBUG] RUSTFLAGS=%RUSTFLAGS%
echo [DEBUG] PYTHON3=%PYTHON3%

cd /d "$PRODUCT_SRC_WIN"
if errorlevel 1 (
  echo [ERROR] Failed to cd into product_src
  exit /b 1
)

if not exist mach (
  echo [ERROR] mach not found in product_src
  exit /b 1
)

echo ============================================================
echo [BUILD] Running local mach build
echo ============================================================

call mach build --dev
if errorlevel 1 (
  echo [ERROR] Servo build failed
  exit /b 1
)

echo [OK] Build completed
exit /b 0
EOF

cmd.exe /c "$BUILD_CMD_FILE" || {
  rm -f "$BUILD_CMD_FILE"
  echo "[FATAL] Build failed"
  exit 1
}
rm -f "$BUILD_CMD_FILE"

echo "[7/8] Packaging executable and runtime artifacts..."
echo "[INFO] Searching for built servoshell.exe..."
mapfile -t EXE_CANDIDATES < <(find "$PRODUCT_SRC/target" -type f -iname "servoshell.exe" 2>/dev/null)

if [ ${#EXE_CANDIDATES[@]} -eq 0 ]; then
  echo "[ERROR] No servoshell.exe found under target directory!"
  echo "[DEBUG] Listing target directory structure:"
  find "$PRODUCT_SRC/target" -maxdepth 4 -type d | head -80
  exit 1
fi

echo "[INFO] Found ${#EXE_CANDIDATES[@]} candidate(s):"
for exe in "${EXE_CANDIDATES[@]}"; do
  echo "  - $exe"
done

LATEST_EXE=""
LATEST_TIME=0
for exe in "${EXE_CANDIDATES[@]}"; do
  t=$(stat -c %Y "$exe")
  if [ "$t" -gt "$LATEST_TIME" ]; then
    LATEST_TIME="$t"
    LATEST_EXE="$exe"
  fi
done

echo "[INFO] Selected latest executable:"
echo "       $LATEST_EXE"
stat "$LATEST_EXE"

PATCH_FILE="$PRODUCT_SRC/components/fonts/font_context.rs"
if [ -f "$PATCH_FILE" ]; then
  PATCH_TIME=$(stat -c %Y "$PATCH_FILE")
  if [ "$LATEST_TIME" -lt "$PATCH_TIME" ]; then
    echo "[ERROR] Executable is older than patched source."
    exit 1
  else
    echo "[OK] Executable is newer than patched source."
  fi
fi

NOW=$(date +%s)
DELTA=$((NOW - LATEST_TIME))
echo "[DEBUG] Build time delta: $DELTA seconds"
if [ "$DELTA" -gt 600 ]; then
  echo "[ERROR] Executable is not freshly built (older than 10 minutes)."
  exit 1
else
  echo "[OK] Fresh executable confirmed."
fi

echo "[INFO] Cleaning runtime directory..."
rm -rf "$OUT_RUNTIME"
mkdir -p "$OUT_RUNTIME"

cp -f "$LATEST_EXE" "$OUT_EXE"
if [ ! -f "$OUT_EXE" ]; then
  echo "[ERROR] Failed to copy executable to $OUT_EXE"
  exit 1
fi

echo "[INFO] Copying runtime DLLs/PDBs..."
find "$PRODUCT_SRC/target" -type f \( -iname '*.dll' -o -iname '*.pdb' \) -exec cp -f {} "$OUT_RUNTIME/" \; || true

if [ -d "$PRODUCT_SRC/resources" ]; then
  echo "[INFO] Copying resources..."
  mkdir -p "$OUT_RUNTIME/resources"
  cp -a "$PRODUCT_SRC/resources"/. "$OUT_RUNTIME/resources"/
else
  echo "[WARN] No resources directory found in product_src"
fi

if [ -n "${GSTREAMER_1_0_ROOT_MSVC_X86_64:-}" ] && [ -d "${GSTREAMER_1_0_ROOT_MSVC_X86_64}/bin" ]; then
  echo "[INFO] Copying GStreamer runtime DLLs..."
  find "${GSTREAMER_1_0_ROOT_MSVC_X86_64}/bin" -maxdepth 1 -type f -iname '*.dll' -exec cp -f {} "$OUT_RUNTIME/" \; || true
else
  echo "[INFO] GSTREAMER_1_0_ROOT_MSVC_X86_64 not set or invalid, skipping GStreamer DLL copy"
fi

if [ -n "${WIN32_REDIST_DIR:-}" ] && [ -d "${WIN32_REDIST_DIR}" ]; then
  echo "[INFO] Copying MSVC redistributable DLLs..."
  find "${WIN32_REDIST_DIR}" -maxdepth 1 -type f -iname '*.dll' -exec cp -f {} "$OUT_RUNTIME/" \; || true
else
  echo "[INFO] WIN32_REDIST_DIR not set or invalid, skipping redist DLL copy"
fi

echo "[8/8] Build complete."
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
echo "Run with Windows CMD:"
echo "  cd D:\\workspace\\claude\\servo-multi\\servo_src\\runtime"
echo "  servoshell.exe file:///D:/workspace/claude/servo-multi/servo_src/fixtures/multilingual-test.html"
echo
echo "If Unicode or tab/chrome text is still wrong, continue source-level patching and rebuild from existing product_src."
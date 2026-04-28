@echo off
setlocal ENABLEDELAYEDEXPANSION

REM ============================================================
REM Servo Product Build Script (Windows CMD)
REM - Uses Clang 17
REM - Uses MSVC toolset 14.36.32532
REM - Keeps servo_src\product_src as maintained product source
REM - Copies from ..\servo_origin only when product_src is missing
REM - Does NOT ask Y/N
REM - Applies overlay + patch scripts
REM - Forces final linker to link.exe
REM - Packages final runtime into servo_src\runtime
REM ============================================================

REM Resolve paths relative to this script location
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "SERVO_SRC=%SCRIPT_DIR%"
for %%I in ("%SERVO_SRC%\..") do set "ROOT=%%~fI"
set "UPSTREAM=%ROOT%\servo_origin"
set "PRODUCT_SRC=%SERVO_SRC%\product_src"
set "OVERLAY=%SERVO_SRC%\product_overlay"
set "OUT_RUNTIME=%SERVO_SRC%\runtime"
set "OUT_EXE=%OUT_RUNTIME%\servoshell.exe"

set "LLVM_BIN_WIN=C:\LLVM\bin"
set "VSDEVCMD_WIN=D:\ProgramFiles\VisualStudio\2022\Professional\Common7\Tools\VsDevCmd.bat"
set "VCVARS_VER=14.36"
set "MSVC_EXPECTED_DIR=D:\ProgramFiles\VisualStudio\2022\Professional\VC\Tools\MSVC\14.36.32532"
set "PYTHON_WIN=C:\Python314\python.exe"

REM Optional Git Bash for shell patch scripts
set "GIT_BASH=C:\Program Files\Git\bin\bash.exe"

echo ============================================================
echo Servo Product Build (Windows CMD)
echo ROOT         : %ROOT%
echo SERVO_SRC    : %SERVO_SRC%
echo UPSTREAM     : %UPSTREAM%
echo PRODUCT_SRC  : %PRODUCT_SRC%
echo OVERLAY      : %OVERLAY%
echo OUT_RUNTIME  : %OUT_RUNTIME%
echo OUT_EXE      : %OUT_EXE%
echo ============================================================

if not exist "%UPSTREAM%" (
  echo [ERROR] servo_origin not found: %UPSTREAM%
  exit /b 1
)

if not exist "%SERVO_SRC%" (
  echo [ERROR] servo_src not found: %SERVO_SRC%
  exit /b 1
)

if not exist "%VSDEVCMD_WIN%" (
  echo [ERROR] VsDevCmd.bat not found: %VSDEVCMD_WIN%
  exit /b 1
)

if not exist "%MSVC_EXPECTED_DIR%" (
  echo [ERROR] Expected MSVC 14.36 toolset not found: %MSVC_EXPECTED_DIR%
  exit /b 1
)

if not exist "%LLVM_BIN_WIN%\clang.exe" (
  echo [ERROR] Expected Clang 17 not found at %LLVM_BIN_WIN%
  exit /b 1
)

if not exist "%PYTHON_WIN%" (
  echo [ERROR] Python not found: %PYTHON_WIN%
  exit /b 1
)

echo [1/8] Killing running browser/build processes if any...
taskkill /F /IM servoshell.exe >nul 2>nul
taskkill /F /IM clang.exe >nul 2>nul
taskkill /F /IM clang-cl.exe >nul 2>nul
taskkill /F /IM link.exe >nul 2>nul
taskkill /F /IM lld-link.exe >nul 2>nul
taskkill /F /IM python.exe >nul 2>nul
taskkill /F /IM cargo.exe >nul 2>nul
taskkill /F /IM rustc.exe >nul 2>nul

echo [2/8] Preparing product source tree...
if not exist "%PRODUCT_SRC%" (
  echo [INFO] product_src does not exist. Copying from ..\servo_origin ...
  call :copy_upstream_to_product
  if errorlevel 1 exit /b 1
) else (
  echo [INFO] product_src already exists. Reusing current product_src without refresh.
)

if not exist "%PRODUCT_SRC%" (
  echo [ERROR] product_src missing after prepare step
  exit /b 1
)

if not exist "%PRODUCT_SRC%\mach" (
  echo [ERROR] mach not found in product_src after prepare step
  exit /b 1
)

echo [3/8] Applying overlay files...
if exist "%OVERLAY%" (
  xcopy "%OVERLAY%\*" "%PRODUCT_SRC%\" /E /I /H /Y >nul
  if errorlevel 1 (
    echo [ERROR] Failed to apply overlay files
    exit /b 1
  )
) else (
  echo [WARN] No overlay directory found: %OVERLAY%
)

echo [4/8] Running patch scripts if present...
if exist "%OVERLAY%\patch_font_system.sh" (
  if exist "%GIT_BASH%" (
    echo [INFO] Running patch_font_system.sh with Git Bash...
    pushd "%PRODUCT_SRC%"
    "%GIT_BASH%" "%OVERLAY%\patch_font_system.sh"
    set "PATCH_ERR=%ERRORLEVEL%"
    popd
    if not "%PATCH_ERR%"=="0" (
      echo [ERROR] patch_font_system.sh failed
      exit /b 1
    )
  ) else (
    echo [WARN] Git Bash not found, skipping patch_font_system.sh
  )
)

if exist "%SERVO_SRC%\apply_unicode_patch.py" (
  echo [INFO] Running apply_unicode_patch.py...
  "%PYTHON_WIN%" "%SERVO_SRC%\apply_unicode_patch.py"
  if errorlevel 1 (
    echo [ERROR] apply_unicode_patch.py failed
    exit /b 1
  )
)

if exist "%SERVO_SRC%\apply_ui_clipboard_patch.py" (
  echo [INFO] Running apply_ui_clipboard_patch.py...
  "%PYTHON_WIN%" "%SERVO_SRC%\apply_ui_clipboard_patch.py"
  if errorlevel 1 (
    echo [ERROR] apply_ui_clipboard_patch.py failed
    exit /b 1
  )
)

if exist "%SERVO_SRC%\apply_tab_egui_patch.py" (
  echo [INFO] Running apply_tab_egui_patch.py...
  "%PYTHON_WIN%" "%SERVO_SRC%\apply_tab_egui_patch.py"
  if errorlevel 1 (
    echo [ERROR] apply_tab_egui_patch.py failed
    exit /b 1
  )
)

echo [5/8] Cleaning old target to avoid stale executable...
if exist "%PRODUCT_SRC%\target" (
  rmdir /S /Q "%PRODUCT_SRC%\target"
  if exist "%PRODUCT_SRC%\target" (
    echo [ERROR] Failed to remove old target directory
    exit /b 1
  )
)

echo [6/8] Building with Clang 17 + MSVC 14.36 + link.exe...
call "%VSDEVCMD_WIN%" -arch=x64 -host_arch=x64 -vcvars_ver=%VCVARS_VER%
if errorlevel 1 (
  echo [ERROR] Failed to initialize VS environment
  exit /b 1
)

set "PATH=%LLVM_BIN_WIN%;%PATH%"
set "CC=clang-cl"
set "CXX=clang-cl"
set "CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER=link.exe"
set "RUSTFLAGS=-Clinker=link.exe"
set "PYTHON3=%PYTHON_WIN%"

where clang
where clang-cl
where link
clang --version
clang-cl --version

echo [DEBUG] VCToolsVersion=%VCToolsVersion%
echo [DEBUG] VCToolsInstallDir=%VCToolsInstallDir%

cd /d "%PRODUCT_SRC%"
if not exist mach (
  echo [ERROR] mach not found in product_src
  exit /b 1
)

call mach build --dev
if errorlevel 1 (
  echo [ERROR] Servo build failed
  exit /b 1
)

echo [OK] Build completed

echo [7/8] Packaging executable and runtime artifacts...
if not exist "%PRODUCT_SRC%\target\debug\servoshell.exe" (
  echo [ERROR] Built executable not found:
  echo         %PRODUCT_SRC%\target\debug\servoshell.exe
  exit /b 1
)

if exist "%OUT_RUNTIME%" rmdir /S /Q "%OUT_RUNTIME%"
mkdir "%OUT_RUNTIME%"
if errorlevel 1 (
  echo [ERROR] Failed to create runtime directory
  exit /b 1
)

copy /Y "%PRODUCT_SRC%\target\debug\servoshell.exe" "%OUT_EXE%" >nul
if errorlevel 1 (
  echo [ERROR] Failed to copy executable to runtime
  exit /b 1
)

for /R "%PRODUCT_SRC%\target" %%F in (*.dll *.pdb) do copy /Y "%%F" "%OUT_RUNTIME%\" >nul 2>nul

if exist "%PRODUCT_SRC%\resources" (
  xcopy "%PRODUCT_SRC%\resources\*" "%OUT_RUNTIME%\resources\" /E /I /H /Y >nul
)

echo [8/8] Build complete.
dir "%OUT_EXE%"

echo.
echo ============================================================
echo NEXT STEP
echo ============================================================
echo Run:
echo   cd /d "%OUT_RUNTIME%"
echo   servoshell.exe file:///D:/workspace/claude/servo-multi/fixtures/multilingual-test.html
exit /b 0

:copy_upstream_to_product
echo [INFO] Copying upstream source into product_src...
if exist "%PRODUCT_SRC%" (
  echo [ERROR] product_src already exists before copy_upstream_to_product
  exit /b 1
)
mkdir "%PRODUCT_SRC%"
if errorlevel 1 (
  echo [ERROR] Failed to create product_src
  exit /b 1
)
xcopy "%UPSTREAM%\*" "%PRODUCT_SRC%\" /E /I /H /Y >nul
if errorlevel 1 (
  echo [ERROR] Failed to copy servo_origin into product_src
  exit /b 1
)
echo [OK] product_src created from ..\servo_origin
exit /b 0
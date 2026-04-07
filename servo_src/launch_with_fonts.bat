@echo off
REM Servo Browser Launcher with CJK Font Support
REM 设置Windows字体环境

echo ========================================
echo Servo Browser Launcher - CJK Font Mode
echo ========================================
echo.

REM 设置字体相关环境变量（尝试影响渲染）
set FONT_FALLBACK=Microsoft YaHei,SimSun,Segoe UI,Arial Unicode MS,PingFang SC,Noto Sans CJK SC,sans-serif
set FREETYPE_FONT_PATH=
set HARFBUZZ_ENABLED=1

REM 设置PATH包含runtime DLLs
set PATH=%CD%\runtime;%PATH%

REM 使用CSS user stylesheet
set USER_STYLESHEET=file:///D:/workspace/claude/servo-multi/servo_src/fixtures/cjk-font-fallback.css

REM 启动浏览器
echo Browser: servo_src/servoshell.exe
echo Runtime: servo_src/runtime/
echo User Stylesheet: %USER_STYLESHEET%
echo.
echo Launching browser...
echo.

REM 启动浏览器
servo_src\servoshell.exe --user-stylesheet "%USER_STYLESHEET%" %*

pause
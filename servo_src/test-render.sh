#!/bin/bash
# CJK渲染测试脚本 - 诊断和修复

echo "=== Servo浏览器CJK渲染诊断 ==="
echo

# 测试1: 检查本地runtime
echo "1. 检查本地runtime:"
if [ -f "./servoshell.exe" ]; then
    echo "   ✅ servoshell.exe存在 ($(du -h servoshell.exe | cut -f1))"
else
    echo "   ❌ servoshell.exe不存在"
    exit 1
fi

if [ -d "./runtime" ]; then
    DLL_COUNT=$(ls runtime/*.dll 2>/dev/null | wc -l)
    echo "   ✅ runtime/存在 ($DLL_COUNT个DLL)"
else
    echo "   ❌ runtime/不存在"
    exit 1
fi

# 测试2: 检查CSS文件
echo
echo "2. 检查CSS文件:"
if [ -f "./fixtures/cjk-font-fallback.css" ]; then
    echo "   ✅ cjk-font-fallback.css存在"
    echo "   内容预览:"
    head -10 fixtures/cjk-font-fallback.css
else
    echo "   ❌ cjk-font-fallback.css不存在"
fi

# 测试3: 测试浏览器启动
echo
echo "3. 测试浏览器启动:"
export PATH="./runtime:$PATH"
if timeout 3 ./servoshell.exe --help 2>&1 | grep -q "URL"; then
    echo "   ✅ 浏览器可以启动"
else
    echo "   ❌ 浏览器启动失败"
fi

# 测试4: 测试加载fixture
echo
echo "4. 测试加载本地fixture:"
TIMEOUT=5
OUTPUT=$(timeout $TIMEOUT ./servoshell.exe --user-stylesheet "/d/workspace/claude/servo-multi/servo_src/fixtures/cjk-font-fallback.css" "file:///D:/workspace/claude/servo-multi/servo_src/fixtures/multilingual-test.html" 2>&1)
if [ $? -eq 0 ] || [ ${#OUTPUT} -gt 0 ]; then
    echo "   ✅ 浏览器尝试加载fixture"
else
    echo "   ⚠️ 浏览器可能在GUI模式中运行"
fi

# 测试5: 检查字体安装
echo
echo "5. 检查Windows字体:"
echo "   建议安装的字体:"
echo "   - Microsoft YaHei (微软雅黑)"
echo "   - SimSun (宋体)"
echo "   - Segoe UI (Segoe UI)"
echo "   - Arial Unicode MS"
echo "   - PingFang SC (苹方)"
echo "   - Noto Sans CJK SC (思源黑体)"

# 测试6: 运行命令
echo
echo "6. 运行浏览器:"
echo "   ./run_browser.sh file:///D:/workspace/claude/servo-multi/servo_src/fixtures/multilingual-test.html"
echo "   或测试外部页面:"
echo "   ./run_browser.sh https://www.baidu.com/"

echo
echo "=== 诊断完成 ==="
echo "注意: 如果仍看到方格子，请检查:"
echo "  1. Windows字体是否正确安装"
echo "  2. 是否有权限访问系统字体"
echo "  3. 杀毒软件是否阻止了字体访问"
echo "  4. 尝试以管理员权限运行"
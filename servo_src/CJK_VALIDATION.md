# CJK Unicode Rendering Validation Guide

## Product Status
✅ Source patches integrated: `servo_src/product_src/components/fonts/font_context.rs`  
✅ Fallback chain configured: `servo_src/product_src/components/fonts/platform/windows/font_list.rs`  
✅ CSS fallback stylesheet: `servo_src/fixtures/cjk-font-fallback.css`  
✅ Executable built: `servo_src/servoshell.exe` (254 MB)  
✅ Runtime artifacts: `servo_src/runtime/` (91+ DLLs)  

## Manual Validation Steps

### Prerequisites
1. Run from Windows Command Prompt or PowerShell (not Git Bash)
2. Ensure all runtime DLLs in `servo_src/runtime/` are accessible
3. Verify required fonts are installed (Microsoft YaHei, SimSun, Segoe UI, Arial, etc.)

### Launch Browser
```bash
cd D:\workspace\claude\servo-multi\servo_src
export PATH="./runtime:$PATH"
./servoshell.exe --user-stylesheet "./fixtures/cjk-font-fallback.css" "file:///D:/workspace/claude/servo-multi/servo_src/fixtures/multilingual-test.html"
```

Or use provided launcher:
```bash
cd D:\workspace\claude\servo-multi\servo_src
./run_browser.sh file:///D:/workspace/claude/servo-multi/servo_src/fixtures/multilingual-test.html
```

### Validation Checklist

1. **Tab Title**: Should display "多语言测试页面 - Multilingual Test"
2. **Page Title** (`<title>` tag): Should display "多语言测试页面 - Multilingual Test"
3. **H1 Heading**: Should display "多语言测试页面" in correct Chinese characters
4. **Body Text**: Chinese text should render without square-box (□) glyphs
5. **English Text**: English text should render normally
6. **Mixed Content**: Mixed Chinese/English text should render correctly
7. **No Square Boxes**: Verify no Unicode characters display as □

### Test External Page
```bash
./run_browser.sh https://www.baidu.com/
```

Validate:
- Chinese text in search bar renders correctly
- Page title displays "百度一下，你就知道"
- Search results display Chinese text properly

## Source-Level Implementation

### Font Fallback Chain
The browser uses a two-tier fallback system:

1. **Source-level**: `servo_extend_windows_cjk_fallbacks()` in `font_context.rs`
   - Adds comprehensive CJK font family list
   - Includes: Microsoft YaHei, SimSun, SimHei, KaiTi, FangSong, etc.

2. **CSS-level**: `cjk-font-fallback.css` stylesheet
   - Applies font-family to all elements
   - Targets specific languages (zh-CN, ja, ko)
   - Prevents square-box glyphs

### Font Priority Order
The fallback chain attempts fonts in this order:
1. Microsoft YaHei (微软雅黑)
2. SimSun (宋体)
3. Segoe UI Emoji/Symbol
4. Arial Unicode MS
5. Arial
6. Tahoma, Verdana
7. Platform-specific fonts

## Known Limitations

1. **GUI Required**: Browser must run in a Windows GUI environment
2. **No Automated Testing**: Visual validation must be performed manually
3. **Display Dependencies**: Requires proper Windows display subsystem
4. **Font Permissions**: May require admin rights for system font access

## Troubleshooting

### Browser won't launch
- Ensure PATH includes `servo_src/runtime/`
- Verify all DLLs are present in runtime/
- Run from Windows CMD/PowerShell, not Git Bash

### Chinese text shows as squares
- Verify Microsoft YaHei and other CJK fonts are installed
- Check font permissions
- Ensure no antivirus blocking font access
- Try running as Administrator

### External pages fail to load
- Check network connectivity
- Verify browser can load HTTPS pages
- Check if firewall is blocking connections

## Technical Details

### Files Modified
- `servo_src/product_src/components/fonts/font_context.rs`: Added `servo_extend_windows_cjk_fallbacks()`
- `servo_src/product_src/components/fonts/platform/windows/font_list.rs`: Integrated extension function
- `servo_src/fixtures/cjk-font-fallback.css`: CSS-level font fallback

### Build Artifacts
- Executable: `servo_src/servoshell.exe`
- Runtime: `servo_src/runtime/` (91+ DLLs)
- Product Source: `servo_src/product_src/`
- Fixtures: `servo_src/fixtures/`

### Final Product Structure
```
servo_src/
├── servoshell.exe           (254 MB - Main executable)
├── runtime/                 (Runtime dependencies)
│   ├── *.dll               (91+ DLL files)
│   └── api-ms-win-*.dll    (CRT runtime)
├── product_src/             (Servo source tree)
│   ├── components/
│   │   └── fonts/
│   │       ├── font_context.rs      (CJK patch)
│   │       └── platform/
│   │           └── windows/
│   │               └── font_list.rs  (Fallback integration)
│   ├── fixtures/
│   │   └── multilingual-test.html
│   └── fixtures/
│       └── cjk-font-fallback.css
├── run_browser.sh          (Launcher script)
├── validate_unicode.sh      (Validation script)
└── CJK_VALIDATION.md        (This document)
```

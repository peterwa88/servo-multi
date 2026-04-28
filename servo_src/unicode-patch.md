# Servo Multi Patch 说明文档

## 1. 背景

本项目基于 Servo 浏览器内核进行 Windows 平台产品化改造，目标是在 `servo_src/product_src` 中形成可维护、可重复构建的源码版本，并解决以下核心问题：

1. 网页正文中文显示存在方块；
2. Servo 自定义 tab 标签栏中文标题显示为方块；
3. UI 层复制、粘贴、输入等交互能力需要增强；
4. 构建产物需要能够打包到 `servo_src/runtime`，形成相对独立的运行目录。

当前最终有效的 patch 文件包括：

```text
servo_src/apply_unicode_patch.py
servo_src/apply_ui_clipboard_patch.py
servo_src/apply_tab_egui_patch.py
```

这三个 patch 脚本会在 `build_product.cmd` 构建流程中自动执行。

---

## 2. apply_unicode_patch.py

### 2.1 目标

`apply_unicode_patch.py` 主要解决 Servo 网页内容渲染层的 Unicode / CJK 字体 fallback 问题。

### 2.2 主要修改方向

该脚本主要 patch Servo 字体系统相关文件，增强不同平台下的 fallback font families，使中文、英文、符号、emoji 等字符可以找到合适字体。

### 2.3 典型涉及文件

实际涉及文件会随 Servo 版本略有不同，当前主要包括：

```text
components/fonts/platform/windows/font_list.rs
components/fonts/platform/freetype/font_list.rs
components/fonts/platform/freetype/android/font_list.rs
components/fonts/platform/freetype/ohos/font_list.rs
components/fonts/platform/macos/font_list.rs
components/fonts/font_context.rs
```

### 2.4 解决的问题

该 patch 解决的是：

```text
网页正文、输入框、搜索结果、正文标题等页面内容中的中文方块问题
```

### 2.5 注意事项

该 patch 主要作用于网页渲染层，不一定影响 Servo 自定义浏览器 chrome UI，例如 tab 标签栏、工具栏、按钮文字等。

---

## 3. apply_ui_clipboard_patch.py

### 3.1 目标

`apply_ui_clipboard_patch.py` 主要用于增强 Servo shell UI 层的基础交互能力，包括复制、粘贴、输入、快捷键等相关支持。

### 3.2 主要修改方向

该脚本主要面向 `ports/servoshell/desktop` 相关 UI 代码，尝试增强以下能力：

1. 地址栏或输入框中的文本输入；
2. 剪贴板 copy / paste；
3. UI 层键盘快捷键；
4. 多语言输入相关路径。

### 3.3 典型涉及目录

```text
ports/servoshell/desktop/
```

可能涉及文件包括：

```text
ports/servoshell/desktop/gui.rs
ports/servoshell/desktop/app.rs
ports/servoshell/desktop/headed_window.rs
ports/servoshell/desktop/window.rs
```

具体以脚本实际 patch 结果为准。

### 3.4 解决的问题

该 patch 主要解决：

```text
浏览器 shell UI 层无法正常输入、复制、粘贴、多语言交互不完整等问题
```

---

## 4. apply_tab_egui_patch.py

### 4.1 目标

`apply_tab_egui_patch.py` 是最终解决 tab 中文方块问题的关键 patch。

之前的全局字体 fallback、RichText、Button patch 都无法解决 tab 中文显示问题。最终定位发现：

```text
网页正文中文正常；
搜索框中文正常；
Windows 原生窗口标题中文正常；
只有 Servo 自定义 tab 条中的中文标题显示方块。
```

因此问题不是 localization，也不是 title 字符串编码问题，而是：

```text
Servo 自定义 tab strip 的 egui 文本渲染路径没有加载 CJK 字体。
```

### 4.2 最终有效修复策略

最终 patch 使用了以下策略：

1. 将本地 CJK 字体复制到：

```text
servo_src/product_src/resources/fonts/NotoSerifCJKsc-Regular.otf
```

2. 在 `ports/servoshell/desktop/gui.rs` 中注入 egui 字体安装函数：

```rust
servo_install_tab_fonts_exact(ui.ctx());
```

3. 不再依赖全局网页字体 fallback，而是在 `browser_tab()` 中通过 `ui.ctx()` 明确安装 egui 字体。

4. 对 tab 文本使用：

```rust
egui::RichText
egui::FontFamily::Proportional
egui::Label
egui::Sense::click()
```

从而绕开 `Button::selectable(...)` 内部默认字体链。

### 4.3 字体来源

当前使用的字体目录为：

```text
servo_src/09_NotoSerifCJKsc/OTF/SimplifiedChinese/NotoSerifCJKsc-Regular.otf
```

构建时脚本会复制到：

```text
servo_src/product_src/resources/fonts/NotoSerifCJKsc-Regular.otf
```

运行时也会被打包到：

```text
servo_src/runtime/resources/fonts/NotoSerifCJKsc-Regular.otf
```

### 4.4 典型涉及文件

```text
ports/servoshell/desktop/gui.rs
```

主要修改 `browser_tab()` 附近代码。

### 4.5 运行日志

当前 patch 会输出类似日志：

```text
[servo-tab-font] loaded servo-tab-cjk-0 from "runtime/resources/fonts/NotoSerifCJKsc-Regular.otf"
[servo-tab-font] loaded servo-tab-cjk-1 from "C:\\Windows\\Fonts\\simhei.ttf"
[servo-tab-font] loaded servo-tab-cjk-2 from "C:\\Windows\\Fonts\\Deng.ttf"
```

这些日志用于验证 egui tab 字体确实被加载。

如果后续确认稳定，可以降低日志输出频率，或者去掉 `eprintln!` 调试输出。

---

## 5. 推荐目录结构

最终建议保留以下结构：

```text
servo-multi/
├── servo_origin/                      # 原始 Servo 上游源码，本地可保留，不建议作为最终产品源码
├── servo_src/
│   ├── product_src/                   # 当前产品级 Servo 源码
│   ├── runtime/                       # 打包后的运行目录
│   ├── product_overlay/               # 覆盖文件和资源
│   ├── 09_NotoSerifCJKsc/             # CJK 字体资源
│   ├── build_product.cmd
│   ├── build_product.sh
│   ├── apply_unicode_patch.py
│   ├── apply_ui_clipboard_patch.py
│   ├── apply_tab_egui_patch.py
│   └── unicode-patch.md / README.md
├── fixtures/
└── README.md
```

---

## 6. 构建方式

推荐在 Windows CMD 中执行：

```cmd
cd /d D:\workspace\claude\servo-multi\servo_src
build_product.cmd
```

构建完成后运行：

```cmd
cd /d D:\workspace\claude\servo-multi\servo_src\runtime
servoshell.exe https://www.baidu.com/
```

或者测试本地页面：

```cmd
servoshell.exe file:///D:/workspace/claude/servo-multi/fixtures/multilingual-test.html
```

---

## 7. 验证标准

### 7.1 网页正文

网页正文、输入框、百度搜索结果、中文标题应正常显示中文。

### 7.2 tab 标签栏

浏览器 tab 标签栏中的中文标题应正常显示，例如：

```text
百度一下，你就知道
多语言测试页面 - Multilingual Test
```

不应再显示为：

```text
□□□□□□
```

### 7.3 运行日志

如果启用调试日志，应该能看到：

```text
[servo-tab-font] loaded ...
```

说明 egui UI 字体已被加载。

---

## 8. 后续优化建议

### 8.1 降低 tab 字体日志输出

当前 `apply_tab_egui_patch.py` 中通过 `eprintln!` 输出字体加载日志，便于验证。稳定后建议：

1. 删除 `eprintln!`；
2. 或增加一次性初始化标志，避免每一帧重复输出；
3. 或改成仅 debug 模式输出。

### 8.2 product_src 独立化

后续建议逐步减少对 `servo_origin` 的依赖，使 `servo_src/product_src` 成为长期维护的产品源码。

### 8.3 Runtime 打包

推荐将运行所需内容集中到：

```text
servo_src/runtime/
```

包括：

```text
servoshell.exe
*.dll
resources/
resources/fonts/
```

如果 GitHub 单文件大小限制导致无法推送大型二进制，可保留目录结构和构建脚本，二进制本地生成。

---

## 9. Git 推送建议

建议推送以下内容：

```text
servo_src/apply_unicode_patch.py
servo_src/apply_ui_clipboard_patch.py
servo_src/apply_tab_egui_patch.py
servo_src/build_product.cmd
servo_src/build_product.sh
servo_src/product_overlay/
servo_src/09_NotoSerifCJKsc/
servo_src/product_src/
fixtures/
README.md
unicode-patch.md
```

大型文件如：

```text
servo_src/runtime/servoshell.exe
servo_src/runtime/*.dll
servo_src/product_src/target/
```

如果超过 GitHub 限制，建议不推送。

---

## 10. 当前结论

最终有效修复路径是：

```text
网页层 Unicode fallback
    -> apply_unicode_patch.py

UI / clipboard / input
    -> apply_ui_clipboard_patch.py

tab 标签栏中文显示
    -> apply_tab_egui_patch.py
```

其中 tab 问题的根因不是字符串编码，而是 egui tab UI 没有安装和使用 CJK 字体。最终通过在 `browser_tab()` 中使用 `ui.ctx()` 安装字体并替换 tab 文本渲染路径后解决。

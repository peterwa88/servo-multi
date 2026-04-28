#!/usr/bin/env python3
from pathlib import Path
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
SERVO_SRC = ROOT / "servo_src"
PRODUCT_SRC = SERVO_SRC / "product_src"

if not PRODUCT_SRC.exists():
    print(f"[ERROR] product_src not found: {PRODUCT_SRC}")
    print("Run ./build_product.sh first.")
    sys.exit(1)

def backup(path: Path):
    bak = path.with_suffix(path.suffix + ".bak_ui")
    if not bak.exists():
        shutil.copy2(path, bak)

def patch_css_file(path: Path):
    text = path.read_text(encoding="utf-8", errors="ignore")
    original = text

    inject_block = r'''
/* ===== servo_src CJK + clipboard patch ===== */
html, body, input, textarea, button, select,
.tab, .tab-title, .browser-title, .toolbar, .addressbar,
.title, .titlebar, .chrome-label {
  font-family:
    "Microsoft YaHei",
    "Microsoft JhengHei",
    "SimSun",
    "Segoe UI",
    "Segoe UI Symbol",
    "Segoe UI Emoji",
    "Arial Unicode MS",
    Arial,
    sans-serif !important;
}

html, body, p, span, div, input, textarea {
  -webkit-user-select: text !important;
  user-select: text !important;
}

input, textarea {
  caret-color: auto !important;
}
/* ===== end servo_src patch ===== */
'''.strip()

    if "servo_src CJK + clipboard patch" not in text:
        text = text.rstrip() + "\n\n" + inject_block + "\n"

    # 尽量消除全局 user-select:none
    text = re.sub(r"user-select\s*:\s*none\s*;", "user-select: text;", text)
    text = re.sub(r"-webkit-user-select\s*:\s*none\s*;", "-webkit-user-select: text;", text)

    if text != original:
        backup(path)
        path.write_text(text, encoding="utf-8", newline="\n")
        print(f"[PATCH] CSS updated: {path}")

def patch_html_file(path: Path):
    text = path.read_text(encoding="utf-8", errors="ignore")
    original = text

    if "<head" in text and "servo-ui-keyboard-clipboard-patch" not in text:
        js_block = r'''
<script id="servo-ui-keyboard-clipboard-patch">
document.addEventListener("keydown", function(e) {
  const ctrl = e.ctrlKey || e.metaKey;
  if (!ctrl) return;

  const key = (e.key || "").toLowerCase();

  // Allow default browser editing shortcuts in editable regions
  const active = document.activeElement;
  const editable =
    active &&
    (
      active.tagName === "INPUT" ||
      active.tagName === "TEXTAREA" ||
      active.isContentEditable
    );

  if (key === "a" || key === "c" || key === "v" || key === "x") {
    if (editable) {
      return;
    }

    // For non-editable page text, allow select all and copy
    if (key === "a") {
      try {
        const range = document.createRange();
        range.selectNodeContents(document.body);
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
        e.preventDefault();
      } catch (_) {}
      return;
    }

    if (key === "c") {
      try {
        const sel = window.getSelection();
        const text = sel ? sel.toString() : "";
        if (text && navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).catch(() => {});
        }
      } catch (_) {}
      return;
    }
  }
}, true);
</script>
'''.strip()

        text = text.replace("</head>", js_block + "\n</head>")

    if text != original:
        backup(path)
        path.write_text(text, encoding="utf-8", newline="\n")
        print(f"[PATCH] HTML updated: {path}")

def patch_rust_source(path: Path):
    text = path.read_text(encoding="utf-8", errors="ignore")
    original = text

    if "DEFAULT_UI_FONT_FALLBACK_SERVO_SRC" not in text:
        block = r'''
// ===== servo_src UI font fallback patch =====
pub const DEFAULT_UI_FONT_FALLBACK_SERVO_SRC: &[&str] = &[
    "Microsoft YaHei",
    "Microsoft JhengHei",
    "SimSun",
    "Segoe UI",
    "Segoe UI Symbol",
    "Segoe UI Emoji",
    "Arial Unicode MS",
    "Arial",
];
// ===== end servo_src UI font fallback patch =====
'''.strip()

        text = text.rstrip() + "\n\n" + block + "\n"

    if text != original:
        backup(path)
        path.write_text(text, encoding="utf-8", newline="\n")
        print(f"[PATCH] Rust UI source updated: {path}")

# 1. Patch likely CSS files
css_candidates = []
for pattern in [
    "ports/**/*.css",
    "resources/**/*.css",
    "browser/**/*.css",
    "tools/**/*.css",
]:
    css_candidates.extend(PRODUCT_SRC.glob(pattern))

seen = set()
for path in css_candidates:
    if path in seen:
        continue
    seen.add(path)
    patch_css_file(path)

# 2. Patch likely HTML UI files
html_candidates = []
for pattern in [
    "ports/**/*.html",
    "resources/**/*.html",
    "browser/**/*.html",
    "tools/**/*.html",
]:
    html_candidates.extend(PRODUCT_SRC.glob(pattern))

seen = set()
for path in html_candidates:
    if path in seen:
        continue
    seen.add(path)
    patch_html_file(path)

# 3. Patch likely Rust shell/browser UI files
rust_candidates = []
for pattern in [
    "ports/servoshell/**/*.rs",
    "browser/**/*.rs",
    "tools/**/*.rs",
]:
    rust_candidates.extend(PRODUCT_SRC.glob(pattern))

for path in rust_candidates:
    # 只对可能的 UI/chrome 文件做轻量附加
    lower = str(path).lower()
    if any(k in lower for k in ["window", "toolbar", "tab", "browser", "shell", "ui"]):
        patch_rust_source(path)

print("[DONE] UI + clipboard patch applied.")

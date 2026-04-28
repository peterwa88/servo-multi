#!/usr/bin/env python3
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
SERVO_SRC = ROOT / "servo_src"
PRODUCT_SRC = SERVO_SRC / "product_src"

GUI_RS = PRODUCT_SRC / "ports" / "servoshell" / "desktop" / "gui.rs"

FONT_SRC = (
    SERVO_SRC
    / "09_NotoSerifCJKsc"
    / "OTF"
    / "SimplifiedChinese"
    / "NotoSerifCJKsc-Regular.otf"
)

FONT_DST_DIR = PRODUCT_SRC / "resources" / "fonts"
FONT_DST = FONT_DST_DIR / "NotoSerifCJKsc-Regular.otf"

if not PRODUCT_SRC.exists():
    print(f"[ERROR] product_src not found: {PRODUCT_SRC}")
    sys.exit(1)

if not GUI_RS.exists():
    print(f"[ERROR] gui.rs not found: {GUI_RS}")
    sys.exit(1)


def backup(path: Path):
    bak = path.with_suffix(path.suffix + ".bak_tab_final_ctx")
    if not bak.exists():
        shutil.copy2(path, bak)


def strip_old_blocks(text: str) -> str:
    markers = [
        (
            "// ===== servo_src egui tab CJK font patch v3 =====",
            "// ===== end servo_src egui tab CJK font patch v3 =====",
        ),
        (
            "// ===== servo_src tab force-render patch final =====",
            "// ===== end servo_src tab force-render patch final =====",
        ),
        (
            "// ===== servo_src tab exact patch =====",
            "// ===== end servo_src tab exact patch =====",
        ),
        (
            "// ===== servo_src tab exact font patch =====",
            "// ===== end servo_src tab exact font patch =====",
        ),
        (
            "// ===== servo_src tab exact label+sense patch =====",
            "// ===== end servo_src tab exact label+sense patch =====",
        ),
        (
            "// ===== servo_src tab ctx font patch =====",
            "// ===== end servo_src tab ctx font patch =====",
        ),
        (
            "// ===== servo_src tab ui.ctx font patch =====",
            "// ===== end servo_src tab ui.ctx font patch =====",
        ),
    ]

    out = text
    for start_marker, end_marker in markers:
        while start_marker in out and end_marker in out:
            start = out.index(start_marker)
            end = out.index(end_marker, start) + len(end_marker)
            while end < len(out) and out[end] in "\r\n":
                end += 1
            out = out[:start] + out[end:]
    return out


def helper_block() -> str:
    abs_font = str(FONT_SRC).replace("\\", "\\\\")
    return f'''
// ===== servo_src tab ui.ctx font patch =====
fn servo_tab_label_text_exact<S: Into<String>>(s: S) -> egui::RichText {{
    egui::RichText::new(s.into())
        .family(egui::FontFamily::Proportional)
        .size(18.0)
}}

fn servo_try_add_font_file_exact(
    fonts: &mut egui::FontDefinitions,
    key: &str,
    path: &std::path::Path,
) -> bool {{
    match std::fs::read(path) {{
        Ok(bytes) => {{
            fonts.font_data.insert(
                key.to_owned(),
                egui::FontData::from_owned(bytes).into(),
            );
            eprintln!("[servo-tab-font] loaded {{}} from {{:?}}", key, path);
            true
        }}
        Err(_) => false,
    }}
}}

fn servo_install_tab_fonts_exact(ctx: &egui::Context) {{
    let mut fonts = egui::FontDefinitions::default();

    let candidates = [
        std::path::PathBuf::from("resources/fonts/NotoSerifCJKsc-Regular.otf"),
        std::path::PathBuf::from("runtime/resources/fonts/NotoSerifCJKsc-Regular.otf"),
        std::path::PathBuf::from(r"{abs_font}"),
        std::path::PathBuf::from(r"C:\\Windows\\Fonts\\simhei.ttf"),
        std::path::PathBuf::from(r"C:\\Windows\\Fonts\\Deng.ttf"),
        std::path::PathBuf::from(r"C:\\Windows\\Fonts\\Dengb.ttf"),
        std::path::PathBuf::from(r"C:\\Windows\\Fonts\\Dengl.ttf"),
    ];

    let mut loaded: Vec<String> = Vec::new();

    for path in candidates.iter() {{
        let key = format!("servo-tab-cjk-{{}}", loaded.len());
        if servo_try_add_font_file_exact(&mut fonts, &key, path) {{
            loaded.push(key);
        }}
    }}

    if loaded.is_empty() {{
        eprintln!("[servo-tab-font] WARNING: no CJK font loaded for tab UI");
        return;
    }}

    let prop = fonts
        .families
        .entry(egui::FontFamily::Proportional)
        .or_default();

    for name in loaded.iter().rev() {{
        if !prop.iter().any(|x| x == name) {{
            prop.insert(0, name.clone());
        }}
    }}

    let mono = fonts
        .families
        .entry(egui::FontFamily::Monospace)
        .or_default();

    for name in loaded.iter().rev() {{
        if !mono.iter().any(|x| x == name) {{
            mono.insert(0, name.clone());
        }}
    }}

    ctx.set_fonts(fonts);

    let mut style = (*ctx.style()).clone();
    use egui::{{FontFamily, FontId, TextStyle}};

    style.text_styles.insert(TextStyle::Heading, FontId::new(22.0, FontFamily::Proportional));
    style.text_styles.insert(TextStyle::Body, FontId::new(18.0, FontFamily::Proportional));
    style.text_styles.insert(TextStyle::Button, FontId::new(18.0, FontFamily::Proportional));
    style.text_styles.insert(TextStyle::Small, FontId::new(16.0, FontFamily::Proportional));
    style.text_styles.insert(TextStyle::Monospace, FontId::new(17.0, FontFamily::Monospace));

    ctx.set_style(style);
}}
// ===== end servo_src tab ui.ctx font patch =====
'''.strip()


def patch_browser_tab(text: str) -> str:
    # 删除之前错误插入到 update() 里的 ctx 调用
    text = text.replace("        servo_install_tab_fonts_exact(ctx);\n", "")

    # 恢复固定中文测试为真实 title
    text = text.replace(
        '(Some(_title), _) if !_title.is_empty() => "中文标签测试".to_string(),',
        "(Some(title), _) if !title.is_empty() => title,",
    )

    # 在 browser_tab 函数开始处，通过 ui.ctx() 安装字体
    insert_point = """    ) {
        let label = match (webview.page_title(), webview.url()) {"""

    if "servo_install_tab_fonts_exact(ui.ctx());" not in text:
        replacement = """    ) {
        servo_install_tab_fonts_exact(ui.ctx());

        let label = match (webview.page_title(), webview.url()) {"""
        if insert_point not in text:
            print("[WARN] browser_tab insertion point not found")
        else:
            text = text.replace(insert_point, replacement, 1)

    old_button_block = """let tab = tab_frame
                .content_ui
                .add(Button::selectable(
                    active,
                    truncate_with_ellipsis(&label, 20),
                ))
                .on_hover_ui(|ui| {
                    ui.label(servo_tab_label_text_exact(label.to_string()));
                });"""

    old_rich_button_block = """let tab = tab_frame
                .content_ui
                .add(Button::selectable(
                    active,
                    servo_tab_label_text_exact(truncate_with_ellipsis(&label, 20)),
                ))
                .on_hover_ui(|ui| {
                    ui.label(servo_tab_label_text_exact(label.to_string()));
                });"""

    new_label_block = """let tab = tab_frame
                .content_ui
                .add(
                    egui::Label::new(
                        servo_tab_label_text_exact(truncate_with_ellipsis(&label, 20))
                    )
                    .sense(egui::Sense::click())
                )
                .on_hover_ui(|ui| {
                    ui.label(servo_tab_label_text_exact(label.to_string()));
                });"""

    if old_button_block in text:
        text = text.replace(old_button_block, new_label_block, 1)
    elif old_rich_button_block in text:
        text = text.replace(old_rich_button_block, new_label_block, 1)
    elif new_label_block in text:
        pass
    else:
        print("[WARN] tab drawing block not found; no Button/Label replacement applied")

    return text


def main():
    if FONT_SRC.exists():
        FONT_DST_DIR.mkdir(parents=True, exist_ok=True)
        shutil.copy2(FONT_SRC, FONT_DST)
        print(f"[OK] Copied font to: {FONT_DST}")
    else:
        print(f"[WARN] Font not found: {FONT_SRC}")

    text = GUI_RS.read_text(encoding="utf-8", errors="ignore")
    original = text

    text = strip_old_blocks(text)
    text = text.rstrip() + "\n\n" + helper_block() + "\n"
    text = patch_browser_tab(text)

    if text != original:
        backup(GUI_RS)
        GUI_RS.write_text(text, encoding="utf-8", newline="\n")
        print(f"[PATCH] Updated: {GUI_RS}")
    else:
        print("[INFO] No changes made")

    print("[DONE] apply_tab_egui_patch.py finished.")


if __name__ == "__main__":
    main()
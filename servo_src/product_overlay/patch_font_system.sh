#!/usr/bin/env bash
set -e

echo "[PATCH] Applying CJK font fallback patches..."

# 找 font_list.rs
TARGET_FILE=$(grep -R "last_resort" -n components 2>/dev/null | grep font | cut -d: -f1 | head -n 1 || true)

if [ -z "$TARGET_FILE" ]; then
  echo "[WARN] Could not locate font_list.rs automatically"
  exit 0
fi

echo "[PATCH] Found font file: $TARGET_FILE"

# 注入 fallback 模块（如果没有）
grep -q "cjk_fallback" "$TARGET_FILE" || sed -i '1i mod cjk_fallback;' "$TARGET_FILE"

# 替换 last_resort_font_families（粗暴但有效）
sed -i '/last_resort_font_families/,+20c\
pub fn last_resort_font_families() -> Vec<&'\''static str> {\
    crate::gfx::platform::windows::cjk_fallback::windows_cjk_last_resort_families()\
}' "$TARGET_FILE"

echo "[PATCH] font_list.rs patched"

# ===== Patch FontCache / fallback逻辑 =====

CACHE_FILE=$(grep -R "FontCache" -n components 2>/dev/null | cut -d: -f1 | head -n 1 || true)

if [ -n "$CACHE_FILE" ]; then
  echo "[PATCH] Found FontCache: $CACHE_FILE"

cat >> "$CACHE_FILE" << 'EOF'

// ===== Injected CJK multi-fallback =====
pub fn last_resort_font_templates_multi(&mut self) -> Vec<FontTemplateRef> {
    let mut out = Vec::new();

    for family in crate::gfx::platform::windows::cjk_fallback::windows_cjk_last_resort_families() {
        if let Some(t) = self.find_font_template_by_family_name(family) {
            if !out.iter().any(|e| e.identifier() == t.identifier()) {
                out.push(t);
            }
        }
    }

    out
}
EOF

fi

echo "[PATCH] FontCache extended"

echo "[PATCH] DONE"
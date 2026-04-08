
#!/usr/bin/env python3

from pathlib import Path

import re

import shutil

import sys



ROOT = Path(__file__).resolve().parents[1]

SERVO_SRC = ROOT / "servo_src"

PRODUCT_SRC = SERVO_SRC / "product_src"

COMPONENTS = PRODUCT_SRC / "components"

FONTS_DIR = COMPONENTS / "fonts"



if not PRODUCT_SRC.exists():

    print(f"[ERROR] product_src not found: {PRODUCT_SRC}")

    print("Run ./servo_src/build_product.sh first.")

    sys.exit(1)



if not FONTS_DIR.exists():

    print(f"[ERROR] fonts dir not found: {FONTS_DIR}")

    sys.exit(1)



def backup(path: Path):

    bak = path.with_suffix(path.suffix + ".bak_cjk")

    if not bak.exists():

        shutil.copy2(path, bak)



def replace_function_body(src: str, fn_name: str, new_body: str) -> str:

    pat = re.compile(rf"(pub\s+fn\s+{re.escape(fn_name)}\s*\([^)]*\)\s*->\s*[^{{]+\{{)", re.M)

    m = pat.search(src)

    if not m:

        return src



    start = m.start(1)

    brace_start = src.find("{", m.start(1))

    if brace_start < 0:

        return src



    depth = 0

    i = brace_start

    while i < len(src):

        ch = src[i]

        if ch == "{":

            depth += 1

        elif ch == "}":

            depth -= 1

            if depth == 0:

                header = src[start:brace_start+1]

                return src[:start] + header + "\n" + new_body + "\n}\n" + src[i+1:]

        i += 1

    return src



def ensure_helper_block(text: str, marker: str, block: str) -> str:

    if marker in text:

        return text

    return text.rstrip() + "\n\n" + block + "\n"



# ------------------------------------------------------------

# 1. Patch all font_list.rs that define fallback_font_families

# ------------------------------------------------------------

font_list_files = list(FONTS_DIR.rglob("font_list.rs"))

if not font_list_files:

    print("[ERROR] No font_list.rs found under components/fonts")

    sys.exit(1)



patched_font_list = 0



new_fallback_body = r'''

    vec![

        "Microsoft YaHei",

        "Microsoft JhengHei",

        "SimSun",

        "NSimSun",

        "SimHei",

        "KaiTi",

        "FangSong",

        "PMingLiU",

        "MingLiU",

        "Meiryo",

        "Yu Gothic UI",

        "MS Gothic",

        "Malgun Gothic",

        "Gulim",

        "Segoe UI",

        "Segoe UI Symbol",

        "Segoe UI Emoji",

        "Arial Unicode MS",

        "Arial",

        "Tahoma",

        "Verdana",

    ]

'''.strip("\n")



for path in font_list_files:

    text = path.read_text(encoding="utf-8")

    if "fallback_font_families" not in text:

        continue



    original = text

    text = replace_function_body(text, "fallback_font_families", new_fallback_body)

    if text != original:

        backup(path)

        path.write_text(text, encoding="utf-8", newline="\n")

        print(f"[PATCH] patched fallback_font_families in {path}")

        patched_font_list += 1



if patched_font_list == 0:

    print("[WARN] No fallback_font_families function body was patched.")

    print("[WARN] Will still try font_context.rs patch.")



# ------------------------------------------------------------

# 2. Patch font_context.rs to extend fallback families in use

# ------------------------------------------------------------

font_context = FONTS_DIR / "font_context.rs"

if not font_context.exists():

    print(f"[ERROR] font_context.rs not found: {font_context}")

    sys.exit(1)



text = font_context.read_text(encoding="utf-8")

original = text



helper_block = r'''

// ===== servo_src CJK patch injected =====

fn servo_extend_windows_cjk_fallbacks(families: &mut Vec<&'static str>) {

    let preferred = [

        "Microsoft YaHei",

        "Microsoft JhengHei",

        "SimSun",

        "NSimSun",

        "SimHei",

        "KaiTi",

        "FangSong",

        "PMingLiU",

        "MingLiU",

        "Meiryo",

        "Yu Gothic UI",

        "MS Gothic",

        "Malgun Gothic",

        "Gulim",

        "Segoe UI",

        "Segoe UI Symbol",

        "Segoe UI Emoji",

        "Arial Unicode MS",

        "Arial",

        "Tahoma",

        "Verdana",

    ];



    let mut out = Vec::with_capacity(preferred.len() + families.len());

    for name in preferred {

        if !out.contains(&name) {

            out.push(name);

        }

    }

    for &name in families.iter() {

        if !out.contains(&name) {

            out.push(name);

        }

    }

    *families = out;

}

// ===== end servo_src CJK patch =====

'''.strip("\n")



text = ensure_helper_block(

    text,

    "servo_extend_windows_cjk_fallbacks(",

    helper_block

)



# Common likely pattern:

# let fallback_font_families = fallback_font_families(...);

pat1 = re.compile(

    r"let\s+fallback_font_families\s*=\s*fallback_font_families\(([^;]+)\);"

)

if pat1.search(text):

    text = pat1.sub(

        r"let mut fallback_font_families = fallback_font_families(\1);\n        servo_extend_windows_cjk_fallbacks(&mut fallback_font_families);",

        text,

        count=1,

    )

    print("[PATCH] patched fallback_font_families assignment in font_context.rs")

else:

    # Another possible naming style

    pat2 = re.compile(

        r"let\s+mut\s+fallback_font_families\s*=\s*fallback_font_families\(([^;]+)\);"

    )

    if pat2.search(text):

        text = pat2.sub(

            r"let mut fallback_font_families = fallback_font_families(\1);\n        servo_extend_windows_cjk_fallbacks(&mut fallback_font_families);",

            text,

            count=1,

        )

        print("[PATCH] extended existing mutable fallback_font_families in font_context.rs")

    else:

        print("[WARN] Did not find a direct 'let fallback_font_families = fallback_font_families(...)' pattern.")

        print("[WARN] Helper was injected, but call-site patch may still be needed automatically by Claude after inspection.")



if text != original:

    backup(font_context)

    font_context.write_text(text, encoding="utf-8", newline="\n")

    print(f"[PATCH] updated {font_context}")

else:

    print("[INFO] font_context.rs content unchanged except maybe helper already existed.")



# ------------------------------------------------------------

# 3. Optional: strengthen fixture CSS for body/title/input

# ------------------------------------------------------------

fixture = SERVO_SRC / "fixtures" / "multilingual-test.html"

if fixture.exists():

    html = fixture.read_text(encoding="utf-8")

    if "Microsoft YaHei" not in html:

        html = html.replace(

            "<style>",

            """<style>

    html, body, input, textarea, button, select, h1, h2, h3, .tab, .tab-title, .browser-title {

      font-family:

        "Microsoft YaHei",

        "Microsoft JhengHei",

        "SimSun",

        "Segoe UI",

        "Segoe UI Symbol",

        "Segoe UI Emoji",

        "Arial Unicode MS",

        Arial,

        sans-serif;

    }

""",

            1,

        )

        backup(fixture)

        fixture.write_text(html, encoding="utf-8", newline="\n")

        print(f"[PATCH] strengthened fixture CSS in {fixture}")



print("[DONE] Unicode patch application finished.")


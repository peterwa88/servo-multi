/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

pub(crate) mod resource;
pub(crate) mod servo;
pub(crate) mod urlinfo;

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

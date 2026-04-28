/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

use std::sync::Arc;

use base::text::{UnicodeBlock, UnicodeBlockMethod, unicode_plane};
use dwrote::{Font, FontCollection, FontStretch, FontStyle};
use fonts_traits::LocalFontIdentifier;
use style::values::computed::font::GenericFontFamily;
use style::values::computed::{FontStyle as StyleFontStyle, FontWeight as StyleFontWeight};
use style::values::specified::font::FontStretchKeyword;

use crate::{
    EmojiPresentationPreference, FallbackFontSelectionOptions, FontIdentifier, FontTemplate,
    FontTemplateDescriptor, LowercaseFontFamilyName,
};

pub(crate) fn for_each_available_family<F>(mut callback: F)
where
    F: FnMut(String),
{
    let system_fc = FontCollection::system();
    for family in system_fc.families_iter() {
        if let Ok(family_name) = family.family_name() {
            callback(family_name);
        }
    }
}

pub(crate) fn for_each_variation<F>(family_name: &str, mut callback: F)
where
    F: FnMut(FontTemplate),
{
    let system_fc = FontCollection::system();
    if let Ok(Some(family)) = system_fc.font_family_by_name(family_name) {
        let count = family.get_font_count();
        for i in 0..count {
            let Ok(font) = family.font(i) else {
                continue;
            };
            let template_descriptor = font_template_descriptor_from_font(&font);
            let local_font_identifier = LocalFontIdentifier {
                font_descriptor: Arc::new(font.to_descriptor()),
            };
            callback(FontTemplate::new(
                FontIdentifier::Local(local_font_identifier),
                template_descriptor,
                None,
                None,
            ))
        }
    }
}

// Based on gfxWindowsPlatform::GetCommonFallbackFonts() in Gecko
pub fn fallback_font_families(options: FallbackFontSelectionOptions) -> Vec<&'static str> {
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
}





fn font_template_descriptor_from_font(font: &Font) -> FontTemplateDescriptor {
    let style = match font.style() {
        FontStyle::Normal => StyleFontStyle::NORMAL,
        FontStyle::Oblique => StyleFontStyle::OBLIQUE,
        FontStyle::Italic => StyleFontStyle::ITALIC,
    };
    let weight = StyleFontWeight::from_float(font.weight().to_u32() as f32);
    let stretch = match font.stretch() {
        FontStretch::Undefined => FontStretchKeyword::Normal,
        FontStretch::UltraCondensed => FontStretchKeyword::UltraCondensed,
        FontStretch::ExtraCondensed => FontStretchKeyword::ExtraCondensed,
        FontStretch::Condensed => FontStretchKeyword::Condensed,
        FontStretch::SemiCondensed => FontStretchKeyword::SemiCondensed,
        FontStretch::Normal => FontStretchKeyword::Normal,
        FontStretch::SemiExpanded => FontStretchKeyword::SemiExpanded,
        FontStretch::Expanded => FontStretchKeyword::Expanded,
        FontStretch::ExtraExpanded => FontStretchKeyword::ExtraExpanded,
        FontStretch::UltraExpanded => FontStretchKeyword::UltraExpanded,
    }
    .compute();
    FontTemplateDescriptor::new(weight, stretch, style)
}

pub(crate) fn default_system_generic_font_family(
    generic: GenericFontFamily,
) -> LowercaseFontFamilyName {
    match generic {
        GenericFontFamily::None | GenericFontFamily::Serif => "Times New Roman",
        GenericFontFamily::SansSerif => "Arial",
        GenericFontFamily::Monospace => "Courier New",
        GenericFontFamily::Cursive => "Comic Sans MS",
        GenericFontFamily::Fantasy => "Impact",
        GenericFontFamily::SystemUi => "Segoe UI",
    }
    .into()
}

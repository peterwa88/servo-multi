/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

use std::ffi::c_void;

use base::text::{UnicodeBlock, UnicodeBlockMethod, unicode_plane};
use fonts_traits::LocalFontIdentifier;
use log::debug;
use objc2_core_foundation::{CFDictionary, CFRetained, CFSet, CFString, CFType, CFURL};
use objc2_core_text::{
    CTFontDescriptor, CTFontManagerCopyAvailableFontFamilyNames, kCTFontFamilyNameAttribute,
    kCTFontNameAttribute, kCTFontTraitsAttribute, kCTFontURLAttribute,
};
use style::Atom;
use style::values::computed::XLang;
use style::values::computed::font::GenericFontFamily;
use unicode_script::Script;

use crate::platform::add_noto_fallback_families;
use crate::platform::font::font_template_descriptor_from_ctfont_attributes;
use crate::{
    EmojiPresentationPreference, FallbackFontSelectionOptions, FontIdentifier, FontTemplate,
    LowercaseFontFamilyName,
};

pub(crate) fn for_each_available_family<F>(mut callback: F)
where
    F: FnMut(String),
{
    let family_names = unsafe { CTFontManagerCopyAvailableFontFamilyNames() };
    let family_names = unsafe { family_names.cast_unchecked::<CFString>() };
    for family_name in family_names.iter() {
        callback(family_name.to_string());
    }
}

pub(crate) fn font_template_for_local_font_descriptor(
    family_descriptor: CFRetained<CTFontDescriptor>,
) -> Option<FontTemplate> {
    let url = unsafe {
        family_descriptor
            .attribute(kCTFontURLAttribute)?
            .downcast::<CFURL>()
            .ok()?
    };
    let font_name = unsafe {
        family_descriptor
            .attribute(kCTFontNameAttribute)?
            .downcast::<CFString>()
            .ok()?
    };
    let traits = unsafe {
        family_descriptor
            .attribute(kCTFontTraitsAttribute)?
            .downcast::<CFDictionary>()
            .ok()?
    };
    let identifier = LocalFontIdentifier {
        postscript_name: Atom::from(font_name.to_string()),
        path: Atom::from(url.to_file_path()?.to_str()?),
    };
    Some(FontTemplate::new(
        FontIdentifier::Local(identifier),
        font_template_descriptor_from_ctfont_attributes(traits),
        None,
        None,
    ))
}

pub(crate) fn for_each_variation<F>(family_name: &str, mut callback: F)
where
    F: FnMut(FontTemplate),
{
    debug!("Looking for faces of family: {}", family_name);

    let specified_attributes: CFRetained<CFDictionary<CFString, CFType>> =
        CFDictionary::from_slices(
            &[unsafe { kCTFontFamilyNameAttribute }],
            &[CFString::from_str(family_name).as_ref()],
        );
    let wildcard_descriptor =
        unsafe { CTFontDescriptor::with_attributes(specified_attributes.as_ref()) };

    let values = [unsafe { kCTFontFamilyNameAttribute }];
    let values = values.as_ptr().cast::<*const c_void>().cast_mut();
    let mandatory_attributes = unsafe { CFSet::new(None, values, 1, std::ptr::null()) };
    let Some(mandatory_attributes) = mandatory_attributes else {
        return;
    };

    let matched_descriptors =
        unsafe { wildcard_descriptor.matching_font_descriptors(Some(&mandatory_attributes)) };
    let Some(matched_descriptors) = matched_descriptors else {
        return;
    };
    let matched_descriptors = unsafe { matched_descriptors.cast_unchecked::<CTFontDescriptor>() };

    for family_descriptor in matched_descriptors.iter() {
        if let Some(font_template) = font_template_for_local_font_descriptor(family_descriptor) {
            callback(font_template)
        }
    }
}

/// Get the list of fallback fonts given an optional codepoint. This is
/// based on `gfxPlatformMac::GetCommonFallbackFonts()` in Gecko from
/// <https://searchfox.org/mozilla-central/source/gfx/thebes/gfxPlatformMac.cpp>.
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





pub(crate) fn default_system_generic_font_family(
    generic: GenericFontFamily,
) -> LowercaseFontFamilyName {
    match generic {
        GenericFontFamily::None | GenericFontFamily::Serif => "Times",
        GenericFontFamily::SansSerif => "Helvetica",
        GenericFontFamily::Monospace => "Menlo",
        GenericFontFamily::Cursive => "Apple Chancery",
        GenericFontFamily::Fantasy => "Papyrus",
        GenericFontFamily::SystemUi => "Helvetica",
    }
    .into()
}

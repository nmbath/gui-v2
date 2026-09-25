/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtTest
import Victron.VenusOS

TestCase {
    name: "PartnerTheme"

    property color defaultDark
    property color defaultLight

    function initTestCase() {
        Theme.clearPartnerTheme()
        Theme.colorScheme = Theme.Dark
        defaultDark = Theme.color_page_background
        Theme.colorScheme = Theme.Light
        defaultLight = Theme.color_page_background
    }

    function init() {
        Theme.clearPartnerTheme()
    }

    function cleanup() {
        Theme.clearPartnerTheme()
    }

    function test_applies_and_clears_scheme_overrides() {
        verify(Theme.applyPartnerTheme({
            "color_page_background": { "dark": "#102030", "light": "#e0f0ff" }
        }))
        verify(Theme.partnerThemeActive)
        verify(Theme.hasPartnerOverride("color_page_background"))

        Theme.colorScheme = Theme.Dark
        compare(Theme.color_page_background, "#102030")
        Theme.colorScheme = Theme.Light
        compare(Theme.color_page_background, "#e0f0ff")

        Theme.clearPartnerTheme()
        compare(Theme.color_page_background, defaultLight)
        verify(!Theme.partnerThemeActive)
    }

    function test_rejects_invalid_candidate_atomically() {
        verify(Theme.applyPartnerTheme({ "color_page_background": "#123456" }))
        verify(!Theme.applyPartnerTheme({
            "color_page_background": "#abcdef",
            "color_unknown": "#ffffff"
        }))
        compare(Theme.color_page_background, "#123456")
    }

    function test_unset_scheme_uses_compiled_fallback() {
        verify(Theme.applyPartnerTheme({
            "color_page_background": { "dark": "#102030" }
        }))
        Theme.colorScheme = Theme.Light
        compare(Theme.color_page_background, defaultLight)
    }

    function test_applies_semantic_surface_overrides() {
        verify(Theme.applyPartnerTheme({
            "color_background_secondary": { "dark": "#102b38", "light": "#ffffff" },
            "color_card_background": { "dark": "#102b38", "light": "#ffffff" },
            "color_listItem_background": { "dark": "#102b38", "light": "#ffffff" },
            "color_navigationBar_background": { "dark": "#0b2430", "light": "#e8f2f5" },
            "color_font_secondary": { "dark": "#a9c3ce", "light": "#46636f" },
            "color_listItem_separator": { "dark": "#294653", "light": "#cadce3" },
            "color_separator": { "dark": "#294653", "light": "#cadce3" }
        }))

        Theme.colorScheme = Theme.Dark
        compare(Theme.color_background_secondary, "#102b38")
        compare(Theme.color_card_background, "#102b38")
        compare(Theme.color_listItem_background, "#102b38")
        compare(Theme.color_navigationBar_background, "#0b2430")
        compare(Theme.color_font_secondary, "#a9c3ce")
        compare(Theme.color_listItem_separator, "#294653")
        compare(Theme.color_separator, "#294653")

        Theme.colorScheme = Theme.Light
        compare(Theme.color_background_secondary, "#ffffff")
        compare(Theme.color_card_background, "#ffffff")
        compare(Theme.color_listItem_background, "#ffffff")
        compare(Theme.color_navigationBar_background, "#e8f2f5")
        compare(Theme.color_font_secondary, "#46636f")
        compare(Theme.color_listItem_separator, "#cadce3")
        compare(Theme.color_separator, "#cadce3")
    }

    function test_applies_tank_role_overrides_per_scheme() {
        verify(Theme.applyPartnerTheme({
            "color_fuel": { "dark": "#d6c94a", "light": "#c2b52f" },
            "color_freshWater": { "dark": "#55c7e8", "light": "#2ea9cd" },
            "color_blackWater": { "dark": "#a58ad8", "light": "#8b6fc0" }
        }))

        Theme.colorScheme = Theme.Dark
        compare(Theme.color_fuel, "#d6c94a")
        compare(Theme.color_freshWater, "#55c7e8")
        compare(Theme.color_blackWater, "#a58ad8")

        Theme.colorScheme = Theme.Light
        compare(Theme.color_fuel, "#c2b52f")
        compare(Theme.color_freshWater, "#2ea9cd")
        compare(Theme.color_blackWater, "#8b6fc0")
    }
}

/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

pragma Singleton

import QtQuick
import Victron.VenusOS

// Versioned, read-only visual contract for partner-owned pages. This keeps
// partner sources independent of the private Theme implementation.
QtObject {
	readonly property color accent: Theme.color_brand_accent
	readonly property color pageBackground: Theme.color_page_background
	readonly property color cardBackground: Theme.color_card_background
	readonly property color fontPrimary: Theme.color_font_primary
	readonly property color fontSecondary: Theme.color_font_secondary
	readonly property color success: Theme.color_success
	readonly property color warning: Theme.color_warning
	readonly property color critical: Theme.color_critical

	readonly property int cardRadius: Theme.geometry_card_radius
	readonly property int pageMargin: Theme.geometry_page_content_horizontalMargin
	readonly property int bodyFontSize: Theme.font_size_body1
	readonly property int headingFontSize: Theme.font_size_body3
	readonly property int sectionFontSize: Theme.font_size_h2
	readonly property int captionFontSize: Theme.font_size_caption
	readonly property bool portrait: Theme.screenSize === Theme.Portrait
}

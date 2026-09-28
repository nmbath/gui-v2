/*
** Copyright (C) 2024 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

Label {
	// These mimic the same properties from ListItem, so that the item can be
	// marked as hidden by VisibleItemModel.
	readonly property bool effectiveVisible: preferredVisible
	property bool preferredVisible: true

	visible: preferredVisible
	font.pixelSize: Theme.font_listItem_secondary_size
	color: Theme.color_listItem_secondaryText
	wrapMode: Text.Wrap
	horizontalAlignment: Text.AlignRight
	verticalAlignment: Text.AlignVCenter
}

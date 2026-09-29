/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

// One registered web page in the PageSettingsWebPages list. Tapping it
// opens its detail page (PageSettingsWebPage.qml), which shows where it
// points and owns the remove action - this row is navigation only, per
// explicit correction: the list previously had an inline Remove button per
// row, which was wrong.

import QtQuick
import Victron.VenusOS

ListNavigation {
	id: root

	required property string pagePrefix // .../WebPages/<id>
	required property string pageTitle
	readonly property string pageId: idItem.valid ? idItem.value : ""
	// Absent/invalid Origin is treated as manual, so nothing already-
	// removable becomes stuck non-removable (e.g. before a venus-web-pages
	// daemon that publishes this field has been deployed).
	readonly property bool isManual: !originItem.valid || originItem.value === "manual"

	text: root.pageTitle
	// Not qsTrId - see PageSettingsIntegrations.qml's "Web pages" entry for why.
	secondaryText: availableItem.valid && availableItem.value !== 1 ? "Unavailable" : ""
	// Pushed by path, not a locally-declared "PageSettingsWebPage {}"
	// Component - a static reference to a type this file's own directory
	// doesn't own made the whole list page fail to compile ("... is not a
	// type"), aborting every push of it from every entry point. Same root
// cause and fix as WebContentPage elsewhere in this feature.
	onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsWebPage.qml", {
		"title": root.pageTitle,
		"pageId": root.pageId,
		"pagePrefix": root.pagePrefix,
		"pageTitle": root.pageTitle,
	})

	VeQuickItem {
		id: availableItem
		uid: root.pagePrefix + "/Available"
	}
	VeQuickItem {
		id: idItem
		uid: root.pagePrefix + "/Id"
	}
	VeQuickItem {
		id: originItem
		uid: root.pagePrefix + "/Origin"
	}
}

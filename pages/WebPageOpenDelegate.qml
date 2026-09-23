/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

// One entry in WebPagesPage.qml's list. Tapping it opens the page directly -
// this list has no detail/management screen of its own, unlike
// pages/settings/WebPageDelegate.qml (which is a different delegate, for a
// different, Settings-scoped list).

import QtQuick
import Victron.VenusOS

ListNavigation {
	id: root

	required property VeQItem item // item for the "Title" subpath

	readonly property string pagePrefix: item.itemParent().uid // .../WebPages/<id>
	readonly property string pageTitle: item.value || ""

	text: root.pageTitle
	flat: true
	// Not qsTrId - see PageSettingsIntegrations.qml's "Web pages" entry for why.
	secondaryText: availableItem.valid && availableItem.value !== 1 ? "Unavailable" : ""
	preferredVisible: platformVisibilityItem.valid && platformVisibilityItem.value === 1
	enabled: availableItem.valid && availableItem.value === 1
			&& selectedProxyPortItem.valid && selectedProxyPortItem.value > 0
	readonly property VeQuickItem selectedProxyPortItem: Qt.platform.os === "wasm"
			? wasmProxyPortItem : localProxyPortItem

	// Pushed by path, not a locally-declared Component - see
	// WebContentPage.qml's own header for why a static type reference to a
	// component in a different directory breaks compilation wherever it
	// hasn't already been resolved.
	onClicked: {
		// This list is shown in MainView's cards layer. Close that layer before
		// pushing the actual content page; otherwise the new stack page exists
		// behind the still-active cards layer and never becomes current.
		Global.mainView.cardsLoader.hide()
		Qt.callLater(Global.pageManager.pushPage, "/components/WebContentPage.qml", {
			"title": root.pageTitle,
			"localProxyPort": localProxyPortItem.value,
			"wasmProxyPort": wasmProxyPortItem.value,
		})
	}

	VeQuickItem {
		id: availableItem
		uid: root.pagePrefix + "/Available"
	}
	VeQuickItem {
		id: localProxyPortItem
		uid: root.pagePrefix + "/LocalProxyPort"
	}
	VeQuickItem {
		id: wasmProxyPortItem
		uid: root.pagePrefix + "/WasmProxyPort"
	}
	VeQuickItem {
		id: platformVisibilityItem
		uid: root.pagePrefix + (Qt.platform.os === "wasm"
				? "/Visibility/Wasm" : "/Visibility/Local")
	}
}

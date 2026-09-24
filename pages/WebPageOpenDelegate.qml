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
	// A VRM Remote Console session is still Qt.platform.os === "wasm", but
	// must be gated on Visibility/Vrm, not Visibility/Wasm - see
	// PageSettingsWebPage.qml's own surfaceVisible for the same three-way
	// check and its reasoning. The proxy port stays wasmProxyPort either
	// way; only the visibility gate differs.
	preferredVisible: Qt.platform.os !== "wasm"
			? localVisibilityItem.valid && localVisibilityItem.value === 1
			: BackendConnection.vrm
				? vrmVisibilityItem.valid && vrmVisibilityItem.value === 1
				: wasmVisibilityItem.valid && wasmVisibilityItem.value === 1
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
		id: localVisibilityItem
		uid: root.pagePrefix + "/Visibility/Local"
	}
	VeQuickItem {
		id: wasmVisibilityItem
		uid: root.pagePrefix + "/Visibility/Wasm"
	}
	VeQuickItem {
		id: vrmVisibilityItem
		uid: root.pagePrefix + "/Visibility/Vrm"
	}
}

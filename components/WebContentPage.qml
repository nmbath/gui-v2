/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

// Platform-neutral embedded web-content page. Native GX builds load the
// QtWebEngine implementation; WebAssembly loads a DOM iframe implementation.
// Keeping the platform imports in separate, dynamically-loaded files is
// important: QtWebEngine is deliberately unavailable in a WASM build.

import QtQuick
import Victron.VenusOS

Page {
	id: root

	property int localProxyPort: 0
	property int wasmProxyPort: 0
	property bool available: true
	property string errorText: implementation.item?.errorText ?? ""
	readonly property bool loading: implementation.item?.loading ?? false
	readonly property bool canGoBack: implementation.item?.canGoBack ?? false
	readonly property bool canGoForward: implementation.item?.canGoForward ?? false
	readonly property int selectedProxyPort: Qt.platform.os === "wasm"
			? wasmProxyPort : localProxyPort

	function reload() { implementation.item?.reload() }
	function stop() { implementation.item?.stop() }
	function goBack() { implementation.item?.goBack() }
	function goForward() { implementation.item?.goForward() }
	function openExternal(url) { Qt.openUrlExternally(url) }

	signal loadStarted()
	signal loadFinished(bool success)
	signal navigationRequested(url url, bool external)
	signal availabilityChanged(bool available)

	onAvailableChanged: root.availabilityChanged(root.available)
	topLeftButton: VenusOS.StatusBar_LeftButton_Back
	webNavigationBar: true

	Loader {
		id: implementation

		anchors.fill: parent
		active: root.isCurrentPage
		source: Qt.platform.os === "wasm"
				? "WebContentPageWasm.qml" : "WebContentPageNative.qml"

		onLoaded: {
			item.proxyPort = Qt.binding(function() { return root.selectedProxyPort })
			item.available = Qt.binding(function() { return root.available })
		}
	}

	Connections {
		target: implementation.item
		ignoreUnknownSignals: true
		function onLoadStarted() { root.loadStarted() }
		function onLoadFinished(success) {
			root.errorText = implementation.item?.errorText ?? ""
			root.loadFinished(success)
		}
		function onNavigationRequested(url, external) {
			root.navigationRequested(url, external)
			if (external) {
				root.openExternal(url)
			}
		}
	}
}

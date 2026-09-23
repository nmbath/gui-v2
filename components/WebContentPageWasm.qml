/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

Item {
	id: root

	property int proxyPort: 0
	property bool available: true
	property string errorText: ""
	property bool loading: false
	readonly property bool canGoBack: wasmWebViewBridge.canGoBack
	readonly property bool canGoForward: wasmWebViewBridge.canGoForward

	function reload() { wasmWebViewBridge.reload() }
	function stop() {}
	function goBack() { wasmWebViewBridge.goBack() }
	function goForward() { wasmWebViewBridge.goForward() }

	function showFrame() {
		if (!visible || proxyPort <= 0) {
			return
		}
		const scenePosition = mapToItem(null, 0, 0)
		loading = true
		loadStarted()
		wasmWebViewBridge.show(proxyPort,
				scenePosition.x, scenePosition.y, width, height,
				Theme.geometry_screen_width, Theme.geometry_screen_height)
		loading = false
		loadFinished(true)
	}

	signal loadStarted()
	signal loadFinished(bool success)
	signal navigationRequested(url url, bool external)

	onProxyPortChanged: Qt.callLater(showFrame)
	onWidthChanged: Qt.callLater(showFrame)
	onHeightChanged: Qt.callLater(showFrame)
	onVisibleChanged: visible ? Qt.callLater(showFrame) : wasmWebViewBridge.hide()
	Component.onCompleted: Qt.callLater(showFrame)
	Component.onDestruction: wasmWebViewBridge.hide()
}

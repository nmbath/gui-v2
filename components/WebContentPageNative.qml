/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtWebEngine

Item {
	id: root

	property int proxyPort: 0
	property bool available: true
	property string errorText: ""
	readonly property string proxyOrigin: proxyPort > 0
			? "http://127.0.0.1:" + proxyPort : ""
	readonly property bool loading: engine.loading
	readonly property bool canGoBack: engine.canGoBack
	readonly property bool canGoForward: engine.canGoForward

	function reload() { engine.reload() }
	function stop() { engine.stop() }
	function goBack() { engine.goBack() }
	function goForward() { engine.goForward() }

	signal loadStarted()
	signal loadFinished(bool success)
	signal navigationRequested(url url, bool external)

	WebEngineView {
		id: engine

		anchors.fill: parent
		url: root.proxyOrigin.length > 0 ? root.proxyOrigin + "/" : ""

		onUrlChanged: {
			if (root.proxyOrigin.length > 0
					&& !url.toString().startsWith(root.proxyOrigin + "/")) {
				root.navigationRequested(url, true)
				stop()
				return
			}
			root.navigationRequested(url, false)
		}

		onLoadingChanged: function(loadRequest) {
			switch (loadRequest.status) {
			case WebEngineView.LoadStartedStatus:
				root.loadStarted()
				break
			case WebEngineView.LoadSucceededStatus:
				root.errorText = ""
				root.loadFinished(true)
				break
			case WebEngineView.LoadFailedStatus:
				root.errorText = loadRequest.errorString
				root.loadFinished(false)
				break
			}
		}
	}
}

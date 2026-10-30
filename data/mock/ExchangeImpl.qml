/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

// Answers venus-exchange's requests for the package actions as the real service
// does. Nothing is uploaded: on the GX display the file arrives a few seconds
// after the QR code is shown, as if from a phone, and in a browser once it is chosen.
Item {
	id: root

	readonly property string serviceUid: BackendConnection.serviceUidForType("exchange")

	// What venus-package-manager has installed, by package name.
	property var installed: ({ "acme-marine": { title: "Acme Marine Console", version: "1.0.0" } })
	property var _package: null

	function value(path) {
		return MockManager.value(serviceUid + path)
	}

	function setValue(path, value) {
		MockManager.setValue(serviceUid + path, value)
	}

	function reply(trigger, requestId, errorCode, error, sessionId) {
		setValue(trigger + "Reply", JSON.stringify({ requestId: requestId, result: errorCode === 0 ? 1 : 0,
				errorCode: errorCode, error: error, sessionId: sessionId }))
		setValue(trigger + "Sequence", (value(trigger + "Sequence") + 1) % 4294967296)
	}

	function nowSeconds() {
		return Math.floor(Date.now() / 1000)
	}

	function randomText(length, characters) {
		let text = ""
		for (let i = 0; i < length; ++i) {
			text += characters.charAt(Math.floor(Math.random() * characters.length))
		}
		return text
	}

	function sessionEnded() {
		const state = value("/State")
		return state === VenusOS.Exchange_State_Idle || state === VenusOS.Exchange_State_Complete
				|| state === VenusOS.Exchange_State_Failed || state === VenusOS.Exchange_State_Canceled
	}

	function start(raw) {
		setValue("/Request", "")
		const request = JSON.parse(raw)
		const key = request.action.replace(/-/g, "_")
		if (value("/Actions/%1/Id".arg(key)) !== request.action) {
			reply("/Request", request.requestId, 108, "Unknown action", "")
			return
		}
		if (!sessionEnded()) {
			reply("/Request", request.requestId, 100, "Another exchange is in progress", "")
			return
		}
		const name = request.parameters.name
		if (request.action === "package-update" && typeof name !== "string") {
			reply("/Request", request.requestId, 306, "package-update parameters must be {\"name\": <package>}", "")
			return
		}
		// The package in the file that arrives.
		_package = request.action === "package-install"
				? { name: "acme-tanks", title: "Acme Tank Monitor", version: "1.0.0" }
				: { name: name, title: installed[name] ? installed[name].title : name, version: "1.1.0" }

		const sessionId = randomText(32, "0123456789abcdef")
		setValue("/SessionId", sessionId)
		setValue("/Action", request.action)
		setValue("/Name", "")
		setValue("/Summary", "")
		setValue("/ErrorCode", 0)
		setValue("/Error", "")
		setValue("/ResultId", "")
		setValue("/Result", "")
		setValue("/CanConfirm", 0)
		setValue("/CanCancel", 1)
		setValue("/Transfer/Filename", "")
		setValue("/Transfer/FileSize", -1)
		setValue("/Transfer/BytesTransferred", 0)
		setValue("/Transfer/Expires", nowSeconds() + 600)
		setValue("/Transfer/CapabilityRef", randomText(24,
				"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"))
		setValue("/Transfer/Ready", 1)
		setValue("/State", VenusOS.Exchange_State_Waiting)
		reply("/Request", request.requestId, 0, "", sessionId)
		if (Qt.platform.os !== "wasm") {
			phoneTimer.restart()
		}
	}

	function receive() {
		if (value("/State") !== VenusOS.Exchange_State_Waiting) {
			return
		}
		setValue("/Transfer/Ready", 0)
		setValue("/Transfer/Filename", "%1-%2.vpk".arg(_package.name).arg(_package.version))
		setValue("/Transfer/FileSize", 245760)
		setValue("/State", VenusOS.Exchange_State_Receiving)
		receiveTimer.restart()
	}

	// As venus-exchange does after venus-package-manager's Inspect.
	function review() {
		const current = installed[_package.name]
		if (value("/Action") === "package-install" && current) {
			fail(401, "This package is already installed. Update it from its own page.")
		} else if (value("/Action") === "package-update" && !current) {
			fail(401, "%1 is not installed.".arg(_package.name))
		} else {
			setValue("/Name", _package.title)
			setValue("/Summary", current
					? "Version %1, replacing %2".arg(_package.version).arg(current.version)
					: "Version %1".arg(_package.version))
			setValue("/ResultId", _package.name)
			setValue("/Transfer/Expires", nowSeconds() + 600)
			setValue("/CanConfirm", 1)
			setValue("/State", VenusOS.Exchange_State_Review)
		}
	}

	function fail(errorCode, error) {
		setValue("/CanConfirm", 0)
		setValue("/CanCancel", 0)
		setValue("/Transfer/Ready", 0)
		setValue("/Transfer/Expires", 0)
		setValue("/ErrorCode", errorCode)
		setValue("/Error", error)
		setValue("/State", VenusOS.Exchange_State_Failed)
	}

	function control(raw) {
		setValue("/ControlRequest", "")
		const request = JSON.parse(raw)
		const state = value("/State")
		if (request.sessionId !== value("/SessionId")) {
			reply("/Control", request.requestId, 106, "Not the current session", "")
		} else if (request.command === "confirm") {
			if (state !== VenusOS.Exchange_State_Review || value("/CanConfirm") !== 1) {
				reply("/Control", request.requestId, 101, "Cannot confirm now", request.sessionId)
				return
			}
			setValue("/CanConfirm", 0)
			setValue("/CanCancel", 0)
			setValue("/Transfer/Expires", 0)
			setValue("/State", VenusOS.Exchange_State_Processing)
			processTimer.requestId = request.requestId
			processTimer.restart()
		} else if (request.command === "cancel") {
			if (value("/CanCancel") !== 1) {
				reply("/Control", request.requestId, 101, "Cannot cancel now", request.sessionId)
				return
			}
			phoneTimer.stop()
			receiveTimer.stop()
			setValue("/CanConfirm", 0)
			setValue("/CanCancel", 0)
			setValue("/Transfer/Ready", 0)
			setValue("/Transfer/Expires", 0)
			setValue("/State", VenusOS.Exchange_State_Canceled)
			reply("/Control", request.requestId, 0, "", request.sessionId)
		} else if (request.command === "dismiss") {
			if (!sessionEnded()) {
				reply("/Control", request.requestId, 101, "The exchange has not ended", request.sessionId)
				return
			}
			setValue("/SessionId", "")
			setValue("/Action", "")
			setValue("/State", VenusOS.Exchange_State_Idle)
			reply("/Control", request.requestId, 0, "", request.sessionId)
		} else {
			reply("/Control", request.requestId, 107, "Unsupported command", request.sessionId)
		}
	}

	Timer {
		id: phoneTimer
		interval: 4000
		onTriggered: root.receive()
	}

	Timer {
		id: receiveTimer
		interval: 250
		repeat: true
		onTriggered: {
			const size = root.value("/Transfer/FileSize")
			const received = Math.min(size, root.value("/Transfer/BytesTransferred") + size / 8)
			root.setValue("/Transfer/BytesTransferred", received)
			if (received >= size) {
				stop()
				root.review()
			}
		}
	}

	Timer {
		id: processTimer
		property string requestId
		interval: 1500
		onTriggered: {
			const name = root._package.name
			const current = root.installed[name]
			// Shows venus-package-manager refusing: an update to the same version.
			if (current && current.version === root._package.version) {
				root.fail(401, "%1 %2 is already installed.".arg(name).arg(current.version))
			} else {
				let packages = root.installed
				packages[name] = { title: root._package.title, version: root._package.version }
				root.installed = packages
				root.setValue("/Result", name)
				root.setValue("/State", VenusOS.Exchange_State_Complete)
			}
			root.reply("/Control", requestId, 0, "", root.value("/SessionId"))
		}
	}

	Connections {
		target: BackendConnection
		function onExchangeUploadStatusChanged() {
			if (BackendConnection.exchangeUploadStatus === BackendConnection.ExchangeUploadSending) {
				root.receive()
			}
		}
	}

	VeQuickItem {
		uid: root.serviceUid + "/Request"
		onValueChanged: if (value) root.start(value)
	}

	VeQuickItem {
		uid: root.serviceUid + "/ControlRequest"
		onValueChanged: if (value) root.control(value)
	}
}

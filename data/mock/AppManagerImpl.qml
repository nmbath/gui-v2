/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

// Answers com.victronenergy.appmanager's writes as venus-app-manager does: enabling and removing
// GX Apps, and its file exchange. Nothing is uploaded: on the GX display the file arrives a few
// seconds after the QR code is shown, as if from a phone, and in a browser once it is chosen.
// An install receives Acme Tank Monitor 1.0.0, and an update the app's version 1.1.0.
Item {
	id: root

	readonly property string serviceUid: BackendConnection.serviceUidForType("appmanager")
	readonly property string fileExchangeUid: serviceUid + "/FileExchange"

	// What the file that arrives holds.
	property var _received: null

	function appValue(name, path) {
		return MockManager.value("%1/GxApps/%2/%3".arg(serviceUid).arg(name).arg(path))
	}

	function setAppValue(name, path, value) {
		MockManager.setValue("%1/GxApps/%2/%3".arg(serviceUid).arg(name).arg(path), value)
	}

	function install(app) {
		const fresh = !appValue(app.name, "Version")
		setAppValue(app.name, "Name", app.name)
		setAppValue(app.name, "Title", app.title)
		setAppValue(app.name, "Version", app.version)
		setAppValue(app.name, "Description", app.description)
		setAppValue(app.name, "Organization", app.organization)
		setAppValue(app.name, "Support", app.support)
		if (fresh) {
			setAppValue(app.name, "Components", 1)
			setAppValue(app.name, "Remove", 0)
			// An app is added disabled.
			setAppValue(app.name, "Enable", 0)
		}
	}

	// Refuses to disable the app whose Custom Branding is in use, and removes an app whose /Remove
	// is written 1 while it is disabled.
	Instantiator {
		model: VeQItemTableModel {
			uids: [ root.serviceUid + "/GxApps" ]
			flags: VeQItemTableModel.AddChildren | VeQItemTableModel.AddNonLeaves | VeQItemTableModel.DontAddItem
		}
		delegate: QtObject {
			id: app

			required property string uid
			readonly property VeQuickItem enableItem: VeQuickItem {
				uid: app.uid + "/Enable"
				onValueChanged: {
					if (value === 0 && MockManager.value(root.serviceUid + "/CustomBranding") === MockManager.value(app.uid + "/Name")) {
						Qt.callLater(MockManager.setValue, app.uid + "/Enable", 1)
					}
				}
			}
			readonly property VeQuickItem removeItem: VeQuickItem {
				uid: app.uid + "/Remove"
				onValueChanged: {
					if (value === 1) {
						// Later, so this item isn't deleted while it is still signalling.
						Qt.callLater(MockManager.setValue, app.uid + "/Remove", 0)
						if (app.enableItem.value === 0) {
							Qt.callLater(MockManager.removeValue, app.uid)
						}
					}
				}
			}
		}
	}

	function value(path) {
		return MockManager.value(fileExchangeUid + path)
	}

	function setValue(path, value) {
		MockManager.setValue(fileExchangeUid + path, value)
	}

	// The sequence changes before the reply, as they can arrive over MQTT.
	function reply(trigger, requestId, errorCode, error, sessionId) {
		setValue(trigger + "Sequence", (value(trigger + "Sequence") + 1) % 4294967296)
		const text = JSON.stringify({ requestId: requestId, result: errorCode === 0 ? 1 : 0,
				errorCode: errorCode, error: error, sessionId: sessionId })
		Qt.callLater(() => setValue(trigger + "Reply", text))
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

	function sessionRetained() {
		return value("/Session/State") !== VenusOS.FileExchange_State_Idle
	}

	function received(request) {
		const name = request.parameters.name
		if (request.action === "app-install") {
			return { kind: "app", app: { name: "acmetanks", title: "Acme Tank Monitor", version: "1.0.0",
					description: "Tank levels for Acme senders", organization: "Acme",
					support: "support@example.com", license: "MIT License\n\nCopyright (c) 2026 Acme" } }
		} else if (request.action === "app-update") {
			return { kind: "app", app: { name: name, title: appValue(name, "Title"), version: "1.1.0",
					description: appValue(name, "Description"), organization: appValue(name, "Organization"),
					support: appValue(name, "Support"), license: "",
					installedVersion: appValue(name, "Version") } }
		}
		return null
	}

	function start(raw) {
		setValue("/Request", "")
		const request = JSON.parse(raw)
		const key = request.action.replace(/-/g, "_")
		if (value("/Actions/%1/Id".arg(key)) !== request.action) {
			reply("/Request", request.requestId, 108, "Unknown action", "")
			return
		}
		if (sessionRetained()) {
			reply("/Request", request.requestId, 100, "Another file exchange is in progress", "")
			return
		}
		if (request.action === "app-update" && !appValue(request.parameters.name, "Version")) {
			reply("/Request", request.requestId, 306, "%1 is not installed".arg(request.parameters.name), "")
			return
		}
		_received = received(request)

		const sessionId = randomText(32, "0123456789abcdef")
		setValue("/Session/Id", sessionId)
		setValue("/Session/Action", request.action)
		setValue("/Session/Component", request.parameters.component || "")
		setValue("/Session/Review", "")
		setValue("/Session/ErrorCode", 0)
		setValue("/Session/Error", "")
		setValue("/Session/CanConfirm", 0)
		setValue("/Session/CanCancel", 1)
		setValue("/Session/Transfer/Filename", "")
		setValue("/Session/Transfer/FileSize", -1)
		setValue("/Session/Transfer/BytesTransferred", 0)
		setValue("/Session/Transfer/Expires", nowSeconds() + 600)
		setValue("/Session/Transfer/CapabilityRef", randomText(32,
				"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"))
		setValue("/Session/Transfer/Ready", 1)
		setValue("/Session/State", VenusOS.FileExchange_State_Waiting)
		reply("/Request", request.requestId, 0, "", sessionId)
		if (Qt.platform.os !== "wasm") {
			phoneTimer.restart()
		}
	}

	function receive() {
		if (value("/Session/State") !== VenusOS.FileExchange_State_Waiting) {
			return
		}
		setValue("/Session/Transfer/Ready", 0)
		setValue("/Session/Transfer/Filename", "%1-%2.gxapp".arg(_received.app.name).arg(_received.app.version))
		setValue("/Session/Transfer/FileSize", 245760)
		setValue("/Session/Transfer/Expires", nowSeconds() + 14400)
		setValue("/Session/State", VenusOS.FileExchange_State_Receiving)
		receiveTimer.restart()
	}

	// As venus-app-manager does once the file has been checked.
	function review() {
		if (value("/Session/Action") === "app-install" && appValue(_received.app.name, "Version")) {
			fail(305, "%1 is already installed.".arg(_received.app.name))
			return
		}
		setValue("/Session/Review", JSON.stringify(_received.app))
		setValue("/Session/Transfer/Expires", nowSeconds() + 600)
		setValue("/Session/CanConfirm", 1)
		setValue("/Session/State", VenusOS.FileExchange_State_Review)
	}

	function fail(errorCode, error) {
		phoneTimer.stop()
		receiveTimer.stop()
		validateTimer.stop()
		setValue("/Session/CanConfirm", 0)
		setValue("/Session/CanCancel", 0)
		setValue("/Session/Transfer/Ready", 0)
		setValue("/Session/Transfer/Expires", 0)
		setValue("/Session/ErrorCode", errorCode)
		setValue("/Session/Error", error)
		setValue("/Session/State", VenusOS.FileExchange_State_Failed)
	}

	function clear() {
		setValue("/Session/Id", "")
		setValue("/Session/Action", "")
		setValue("/Session/Component", "")
		setValue("/Session/Review", "")
		setValue("/Session/ErrorCode", 0)
		setValue("/Session/Error", "")
		setValue("/Session/Transfer/CapabilityRef", "")
		setValue("/Session/Transfer/FileSize", -1)
		setValue("/Session/Transfer/BytesTransferred", 0)
		setValue("/Session/State", VenusOS.FileExchange_State_Idle)
	}

	function control(raw) {
		setValue("/ControlRequest", "")
		const request = JSON.parse(raw)
		const state = value("/Session/State")
		if (request.sessionId !== value("/Session/Id")) {
			reply("/Control", request.requestId, 106, "Not the current session", "")
		} else if (request.command === "confirm") {
			if (state !== VenusOS.FileExchange_State_Review || value("/Session/CanConfirm") !== 1) {
				reply("/Control", request.requestId, 101, "Cannot confirm now", request.sessionId)
				return
			}
			setValue("/Session/CanConfirm", 0)
			setValue("/Session/CanCancel", 0)
			setValue("/Session/Transfer/Expires", 0)
			setValue("/Session/State", VenusOS.FileExchange_State_Processing)
			processTimer.requestId = request.requestId
			processTimer.restart()
		} else if (request.command === "cancel") {
			if (value("/Session/CanCancel") !== 1) {
				reply("/Control", request.requestId, 101, "Cannot cancel now", request.sessionId)
				return
			}
			phoneTimer.stop()
			receiveTimer.stop()
			validateTimer.stop()
			setValue("/Session/CanConfirm", 0)
			setValue("/Session/CanCancel", 0)
			setValue("/Session/Transfer/Ready", 0)
			setValue("/Session/Transfer/Expires", 0)
			setValue("/Session/State", VenusOS.FileExchange_State_Cancelled)
			reply("/Control", request.requestId, 0, "", request.sessionId)
		} else if (request.command === "dismiss") {
			if (state !== VenusOS.FileExchange_State_Complete && state !== VenusOS.FileExchange_State_Failed
					&& state !== VenusOS.FileExchange_State_Cancelled) {
				reply("/Control", request.requestId, 101, "The session has not ended", request.sessionId)
				return
			}
			clear()
			reply("/Control", request.requestId, 0, "", request.sessionId)
		} else {
			reply("/Control", request.requestId, 107, "Unsupported command", request.sessionId)
		}
	}

	function process() {
		install(_received.app)
		setValue("/Session/State", VenusOS.FileExchange_State_Complete)
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
			const size = root.value("/Session/Transfer/FileSize")
			const received = Math.min(size, root.value("/Session/Transfer/BytesTransferred") + size / 8)
			root.setValue("/Session/Transfer/BytesTransferred", received)
			if (received >= size) {
				stop()
				root.setValue("/Session/State", VenusOS.FileExchange_State_Validating)
				validateTimer.restart()
			}
		}
	}

	Timer {
		id: validateTimer
		interval: 1800
		onTriggered: root.review()
	}

	Timer {
		id: processTimer
		property string requestId
		interval: 1500
		onTriggered: {
			root.process()
			root.reply("/Control", requestId, 0, "", root.value("/Session/Id"))
		}
	}

	Connections {
		target: BackendConnection
		function onFileExchangeUploadStatusChanged() {
			if (BackendConnection.fileExchangeUploadStatus === BackendConnection.FileExchangeUploadSending) {
				root.receive()
			}
		}
	}

	// Answered later, as by the real service, not inside the write.
	VeQuickItem {
		uid: root.fileExchangeUid + "/Request"
		onValueChanged: if (value) Qt.callLater(root.start, value)
	}

	VeQuickItem {
		uid: root.fileExchangeUid + "/ControlRequest"
		onValueChanged: if (value) Qt.callLater(root.control, value)
	}
}

/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

// Answers com.victronenergy.appmanager's writes as venus-app-manager does: enabling and removing
// GX Apps, and its file exchange. Nothing is uploaded: on the GX display the file arrives a few
// seconds after the QR code is shown, as if from a phone, and in a browser once it is chosen.
// An install receives Acme Tank Monitor 1.0.0, an update the app's version 1.1.0, and the
// installer information Acme Installations' details.
Item {
	id: root

	readonly property string serviceUid: BackendConnection.serviceUidForType("appmanager")
	readonly property string fileExchangeUid: serviceUid + "/FileExchange"
	readonly property string installerInformationUid: serviceUid + "/InstallerInformation"
	readonly property string installerSettingsUid: Services.settings.serviceUid + "/Settings/InstallerInformation"
	readonly property string logo: "data:image/png;base64,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"

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
		} else if (request.action === "component-install" && request.parameters.component === "installerInformation") {
			return { kind: "installerInformation", values: { companyName: "Acme Installations",
					companyAddress: "1 Harbour Road\nExampletown", telephone: "+44 1632 960123",
					supportEmail: "service@acme-installations.example", logo: root.logo } }
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
		if (request.action === "component-install" && request.parameters.component !== "installerInformation") {
			reply("/Request", request.requestId, 306, "No such component", "")
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
		const app = _received.kind === "app"
		setValue("/Session/Transfer/Filename", app ? "%1-%2.gxapp".arg(_received.app.name).arg(_received.app.version)
				: "installer-information.json")
		setValue("/Session/Transfer/FileSize", app ? 245760 : 11264)
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
		setValue("/Session/Review", JSON.stringify(_received.kind === "app" ? _received.app : _received.values))
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

	// Stores a text field in localsettings, then publishes it, as the app manager does.
	function setInstallerInformation(path, value) {
		MockManager.setValue(installerSettingsUid + path, value)
		MockManager.setValue(installerInformationUid + path, value)
	}

	function process() {
		if (_received.kind === "app") {
			install(_received.app)
		} else {
			const values = _received.values
			MockManager.setValue(installerInformationUid + "/Logo", values.logo || "")
			setInstallerInformation("/CompanyName", values.companyName || "")
			setInstallerInformation("/CompanyAddress", values.companyAddress || "")
			setInstallerInformation("/Telephone", values.telephone || "")
			setInstallerInformation("/SupportEmail", values.supportEmail || "")
		}
		setValue("/Session/State", VenusOS.FileExchange_State_Complete)
	}

	// Clears the installer information when /InstallerInformation/Remove is written 1.
	VeQuickItem {
		uid: root.installerInformationUid + "/Remove"
		onValueChanged: {
			if (value === 1) {
				MockManager.setValue(root.installerInformationUid + "/Logo", "")
				for (const path of ["/CompanyName", "/CompanyAddress", "/Telephone", "/SupportEmail"]) {
					root.setInstallerInformation(path, "")
				}
				Qt.callLater(MockManager.setValue, root.installerInformationUid + "/Remove", 0)
			}
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

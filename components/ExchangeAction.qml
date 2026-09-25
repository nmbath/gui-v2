/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

Item {
	id: root
	readonly property int stateIdle: 0
	readonly property int statePreparing: 1
	readonly property int stateWaiting: 2
	readonly property int stateReceiving: 3
	readonly property int stateReview: 4
	readonly property int stateProcessing: 5
	readonly property int stateComplete: 7
	readonly property int stateFailed: 8
	readonly property int stateCancelled: 9

	property string actionId
	property string actionDbusKey: actionId.replace(/-/g, "_")
	property string reviewPageTitle
	property string subjectLabel
	property string summaryLabel
	property string confirmActionText
	property string confirmTitle
	property string confirmDescription
	property string processingText
	property string completionText
	property string completionToast
	property string scanInstruction
	property string fileAccept

	readonly property string exchangeServiceUid: BackendConnection.serviceUidForType("exchange")
	readonly property bool serviceConnected: connected.valid && connected.value === 1
	readonly property bool actionAvailable: availableItem.valid && availableItem.value === 1
	readonly property bool available: serviceConnected && actionAvailable && !BackendConnection.vrm
	readonly property string claimPath: capabilityRef.value
			? "/exchange/claim/" + capabilityRef.value : ""

	property bool active
	property bool cancelPending
	property bool uploadFailureNotified
	property bool failureToastPending
	property string pendingStartRequestId
	property string pendingControlRequestId

	visible: false
	width: 0
	height: 0

	function newRequestId(prefix) {
		return prefix + "-" + Date.now().toString(36) + "-"
				+ Math.floor(Math.random() * 0x100000000).toString(36)
	}

	function parseReply(raw) {
		if (typeof raw !== "string" || raw.length === 0) {
			return null
		}
		try {
			return JSON.parse(raw)
		} catch (error) {
			return null
		}
	}

	function start() {
		if (!root.available) {
			return
		}
		if (state.value === root.stateReview) {
			root.openReviewPage()
			return
		}
		if (Qt.platform.os !== "wasm") {
			Global.dialogLayer.open(qrDialogComponent)
			return
		}

		root.active = true
		root.cancelPending = false
		root.uploadFailureNotified = false
		root.failureToastPending = false
		BackendConnection.chooseExchangeFile(root.fileAccept)
		root.maybeStart()
	}

	function maybeStart() {
		if (!root.active || root.pendingStartRequestId || !root.available
				|| !requestItem.valid || !state.valid) {
			return
		}
		if (state.value === root.stateIdle
				|| state.value === root.stateComplete
				|| state.value === root.stateFailed
				|| state.value === root.stateCancelled) {
			root.pendingStartRequestId = root.newRequestId(root.actionId)
			requestItem.setValue(JSON.stringify({
				requestId: root.pendingStartRequestId,
				action: root.actionId,
				parameters: {}
			}))
		}
	}

	function processStartReply() {
		const reply = root.parseReply(requestReply.value)
		if (!reply || reply.requestId !== root.pendingStartRequestId) {
			return
		}
		root.pendingStartRequestId = ""
		if (reply.result !== 1) {
			root.active = false
			//% "Unable to start exchange"
			Global.showToastNotification(VenusOS.Notification_Warning,
					reply.error || qsTrId("exchangeaction_start_failed"), 5000)
		}
	}

	function cancelSession() {
		if (!sessionId.value || root.pendingControlRequestId || !controlRequest.valid) {
			return
		}
		root.pendingControlRequestId = root.newRequestId("cancel")
		controlRequest.setValue(JSON.stringify({
			requestId: root.pendingControlRequestId,
			sessionId: sessionId.value,
			command: "cancel"
		}))
	}

	function handleUpload() {
		if (!root.active || Qt.platform.os !== "wasm") {
			return
		}
		const uploadStatus = BackendConnection.exchangeFileUploadStatus()
		if (uploadStatus === -2) {
			root.cancelPending = true
			root.cancelSession()
			return
		}
		if (uploadStatus === -1) {
			root.cancelPending = true
			root.cancelSession()
			if (!root.uploadFailureNotified) {
				root.uploadFailureNotified = true
				//% "File upload failed"
				Global.showToastNotification(VenusOS.Notification_Warning,
						qsTrId("exchangeaction_upload_failed"), 5000)
			}
			return
		}
		if (uploadStatus === 1 && transferReady.value === 1 && root.claimPath.length > 0) {
			BackendConnection.uploadSelectedExchangeFile(root.claimPath)
		}
		if (root.cancelPending) {
			root.cancelSession()
		}
	}

	function handleState() {
		if (!root.active || !state.valid) {
			return
		}
		if (state.value === root.stateReview) {
			root.active = false
			root.openReviewPage()
		} else if (state.value === root.stateCancelled) {
			root.active = false
		} else if (state.value === root.stateFailed) {
			root.active = false
			root.failureToastPending = true
			failureToastTimer.restart()
		}
	}

	function showFailureToast(useFallback) {
		if (!root.failureToastPending) {
			return
		}
		const message = errorText.value
		if (!message && !useFallback) {
			return
		}
		root.failureToastPending = false
		failureToastTimer.stop()
		//% "Exchange failed"
		Global.showToastNotification(VenusOS.Notification_Warning,
				message || qsTrId("exchangeaction_exchange_failed"), 5000)
	}

	function reviewPageProperties() {
		return {
			title: root.reviewPageTitle,
			subjectLabel: root.subjectLabel,
			summaryLabel: root.summaryLabel,
			confirmActionText: root.confirmActionText,
			confirmTitle: root.confirmTitle,
			confirmDescription: root.confirmDescription,
			processingText: root.processingText,
			completionText: root.completionText,
			completionToast: root.completionToast
		}
	}

	function openReviewPage() {
		Qt.callLater(Global.pageManager.pushPage,
				"/pages/settings/PageSettingsExchange.qml", root.reviewPageProperties())
	}

	Timer {
		interval: 100
		repeat: true
		running: root.active && Qt.platform.os === "wasm"
		onTriggered: {
			root.maybeStart()
			root.handleUpload()
		}
	}

	Timer {
		id: failureToastTimer
		interval: 250
		repeat: false
		onTriggered: root.showFailureToast(true)
	}

	VeQuickItem { id: connected; uid: root.exchangeServiceUid + "/Connected"; onValidChanged: root.maybeStart() }
	VeQuickItem { id: availableItem; uid: root.exchangeServiceUid + "/Actions/" + root.actionDbusKey + "/Available"; onValidChanged: root.maybeStart() }
	VeQuickItem { id: requestItem; uid: root.exchangeServiceUid + "/Request"; onValidChanged: root.maybeStart() }
	VeQuickItem { id: requestReply; uid: root.exchangeServiceUid + "/RequestReply" }
	VeQuickItem { id: requestSequence; uid: root.exchangeServiceUid + "/RequestSequence"; onValueChanged: root.processStartReply() }
	VeQuickItem { id: controlRequest; uid: root.exchangeServiceUid + "/ControlRequest" }
	VeQuickItem { id: controlReply; uid: root.exchangeServiceUid + "/ControlReply" }
	VeQuickItem {
		id: controlSequence
		uid: root.exchangeServiceUid + "/ControlSequence"
		onValueChanged: {
			const reply = root.parseReply(controlReply.value)
			if (reply && reply.requestId === root.pendingControlRequestId) {
				root.pendingControlRequestId = ""
			}
		}
	}
	VeQuickItem { id: sessionId; uid: root.exchangeServiceUid + "/SessionId" }
	VeQuickItem {
		id: state
		uid: root.exchangeServiceUid + "/State"
		onValidChanged: root.handleState()
		onValueChanged: root.handleState()
	}
	VeQuickItem { id: transferReady; uid: root.exchangeServiceUid + "/Transfer/Ready" }
	VeQuickItem { id: capabilityRef; uid: root.exchangeServiceUid + "/Transfer/CapabilityRef" }
	VeQuickItem {
		id: errorText
		uid: root.exchangeServiceUid + "/Error"
		onValueChanged: root.showFailureToast(false)
	}

	Component {
		id: qrDialogComponent

		ExchangeQrDialog {
			actionId: root.actionId
			actionDbusKey: root.actionDbusKey
			title: root.reviewPageTitle
			scanInstruction: root.scanInstruction
			onReviewReady: root.openReviewPage()
		}
	}
}

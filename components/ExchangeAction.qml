/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

QtObject {
	id: root

	property string actionId
	property string actionDbusKey: actionId.replace(/-/g, "_")
	property string reviewPageTitle
	property string failureTitle
	property string subjectLabel
	property string summaryLabel
	property string confirmActionText
	property string cancelActionText
	property string confirmTitle
	property string confirmDescription
	property string processingText
	property string completionText
	property string completionToast
	property string uploadingText
	property string scanInstruction
	property string fileAccept
	property var startParameters: ({})

	readonly property bool available: root._connected.value === 1 && root._available.value === 1 && !BackendConnection.vrm

	property bool _active
	property bool _cancelPending
	property bool _uploadFailureNotified
	property bool _failureToastPending
	property bool _restartPending
	property string _pendingStartRequestId
	property string _pendingControlRequestId

	function start() {
		if (!root.available) {
			return
		}
		if (root._state.value === VenusOS.Exchange_State_Review && !root._reviewExpired()) {
			root._openReviewPage()
			return
		}
		if (Qt.platform.os !== "wasm") {
			Global.dialogLayer.open(root._qrDialogComponent)
			return
		}

		root._active = true
		root._cancelPending = false
		root._uploadFailureNotified = false
		root._failureToastPending = false
		BackendConnection.chooseExchangeFile(root.fileAccept)
		root._restartPending = root._state.value === VenusOS.Exchange_State_Review
		if (root._restartPending) {
			root._cancelPending = true
			root._cancelSession()
		} else {
			root._maybeStart()
		}
	}

	function _reviewExpired() {
		return !root._transferExpires.valid || root._transferExpires.value <= Date.now() / 1000
	}

	function _maybeStart() {
		if (!root._active || root._pendingStartRequestId || !root.available
				|| !root._request.valid || !root._state.valid) {
			return
		}
		if (root._state.value === VenusOS.Exchange_State_Idle
				|| root._state.value === VenusOS.Exchange_State_Complete
				|| root._state.value === VenusOS.Exchange_State_Failed
				|| root._state.value === VenusOS.Exchange_State_Canceled) {
			root._pendingStartRequestId = Exchange.newRequestId(root.actionId)
			root._request.setValue(Exchange.startRequest(root._pendingStartRequestId, root.actionId,
					root.startParameters))
		}
	}

	function _processStartReply() {
		const reply = Exchange.parseJson(root._requestReply.value)
		if (!reply || reply.requestId !== root._pendingStartRequestId) {
			return
		}
		root._pendingStartRequestId = ""
		if (reply.result !== 1) {
			root._active = false
			Global.showToastNotification(VenusOS.Notification_Warning,
					reply.error || Exchange.startFailedText, 5000)
		}
	}

	function _cancelSession() {
		if (!root._sessionId.value || root._pendingControlRequestId || !root._controlRequest.valid) {
			return
		}
		root._pendingControlRequestId = Exchange.newRequestId("cancel")
		root._controlRequest.setValue(Exchange.controlRequest(root._pendingControlRequestId, root._sessionId.value, "cancel"))
	}

	function _handleUpload() {
		if (!root._active || Qt.platform.os !== "wasm") {
			return
		}
		const uploadStatus = BackendConnection.exchangeUploadStatus
		if (uploadStatus === BackendConnection.ExchangeUploadCanceled) {
			root._cancelPending = true
		} else if (uploadStatus === BackendConnection.ExchangeUploadFailed) {
			root._cancelPending = true
			if (!root._uploadFailureNotified) {
				root._uploadFailureNotified = true
				//% "File upload failed"
				Global.showToastNotification(VenusOS.Notification_Warning,
						qsTrId("exchangeaction_upload_failed"), 5000)
			}
		} else if (uploadStatus === BackendConnection.ExchangeUploadSelected
				&& root._transferReady.value === 1 && root._capabilityRef.value) {
			// Read here, not through a binding, which can lag behind the change being handled.
			if (BackendConnection.uploadSelectedExchangeFile("/exchange/claim/" + root._capabilityRef.value)
					&& root.uploadingText.length > 0) {
				Global.showToastNotification(VenusOS.Notification_Info, root.uploadingText, 3000)
			}
		}
		if (root._cancelPending) {
			root._cancelSession()
		}
	}

	function _handleState() {
		if (!root._active || !root._state.valid) {
			return
		}
		if (root._state.value === VenusOS.Exchange_State_Review) {
			root._active = false
			root._openReviewPage()
		} else if (root._state.value === VenusOS.Exchange_State_Canceled) {
			if (root._restartPending) {
				root._restartPending = false
				root._cancelPending = false
				root._maybeStart()
			} else {
				root._active = false
			}
		} else if (root._state.value === VenusOS.Exchange_State_Failed) {
			root._active = false
			root._failureToastPending = true
			root._failureToastTimer.restart()
		} else {
			root._maybeStart()
		}
	}

	function _showFailureToast(useFallback) {
		if (!root._failureToastPending) {
			return
		}
		const detail = root._errorText.value
		if (!detail && !useFallback) {
			return
		}
		root._failureToastPending = false
		root._failureToastTimer.stop()
		const reason = Exchange.errorSummaryText(root._errorCode.value, detail)
		const title = root.failureTitle || Exchange.failedText
		Global.showToastNotification(VenusOS.Notification_Warning,
				reason ? title + "\n" + reason : title, 5000)
	}

	function _openReviewPage() {
		Qt.callLater(Global.pageManager.pushPage, "/pages/settings/PageSettingsExchange.qml", {
			title: root.reviewPageTitle,
			failureTitle: root.failureTitle,
			subjectLabel: root.subjectLabel,
			summaryLabel: root.summaryLabel,
			confirmActionText: root.confirmActionText,
			cancelActionText: root.cancelActionText,
			confirmTitle: root.confirmTitle,
			confirmDescription: root.confirmDescription,
			processingText: root.processingText,
			completionText: root.completionText,
			completionToast: root.completionToast
		})
	}

	readonly property Connections _uploadConnection: Connections {
		target: BackendConnection
		function onExchangeUploadStatusChanged() { root._handleUpload() }
	}

	readonly property Timer _failureToastTimer: Timer {
		interval: 250
		onTriggered: root._showFailureToast(true)
	}

	readonly property VeQuickItem _connected: VeQuickItem {
		uid: Exchange.serviceUid + "/Connected"
		onValidChanged: root._maybeStart()
	}
	readonly property VeQuickItem _available: VeQuickItem {
		uid: Exchange.serviceUid + "/Actions/" + root.actionDbusKey + "/Available"
		onValidChanged: root._maybeStart()
	}
	readonly property VeQuickItem _request: VeQuickItem {
		uid: Exchange.serviceUid + "/Request"
		onValidChanged: root._maybeStart()
	}
	readonly property VeQuickItem _requestReply: VeQuickItem {
		uid: Exchange.serviceUid + "/RequestReply"
	}
	readonly property VeQuickItem _requestSequence: VeQuickItem {
		uid: Exchange.serviceUid + "/RequestSequence"
		onValueChanged: root._processStartReply()
	}
	readonly property VeQuickItem _controlRequest: VeQuickItem {
		uid: Exchange.serviceUid + "/ControlRequest"
	}
	readonly property VeQuickItem _controlReply: VeQuickItem {
		uid: Exchange.serviceUid + "/ControlReply"
	}
	readonly property VeQuickItem _controlSequence: VeQuickItem {
		uid: Exchange.serviceUid + "/ControlSequence"
		onValueChanged: {
			const reply = Exchange.parseJson(root._controlReply.value)
			if (reply && reply.requestId === root._pendingControlRequestId) {
				root._pendingControlRequestId = ""
				root._handleUpload()
			}
		}
	}
	readonly property VeQuickItem _sessionId: VeQuickItem {
		uid: Exchange.serviceUid + "/SessionId"
		onValueChanged: root._handleUpload()
	}
	readonly property VeQuickItem _state: VeQuickItem {
		uid: Exchange.serviceUid + "/State"
		onValidChanged: root._handleState()
		onValueChanged: root._handleState()
	}
	readonly property VeQuickItem _transferReady: VeQuickItem {
		uid: Exchange.serviceUid + "/Transfer/Ready"
		onValueChanged: root._handleUpload()
	}
	readonly property VeQuickItem _capabilityRef: VeQuickItem {
		uid: Exchange.serviceUid + "/Transfer/CapabilityRef"
		onValueChanged: root._handleUpload()
	}
	readonly property VeQuickItem _transferExpires: VeQuickItem {
		uid: Exchange.serviceUid + "/Transfer/Expires"
	}
	readonly property VeQuickItem _errorCode: VeQuickItem {
		uid: Exchange.serviceUid + "/ErrorCode"
	}
	readonly property VeQuickItem _errorText: VeQuickItem {
		uid: Exchange.serviceUid + "/Error"
		onValueChanged: root._showFailureToast(false)
	}

	readonly property Component _qrDialogComponent: Component {
		ExchangeQrDialog {
			actionId: root.actionId
			actionDbusKey: root.actionDbusKey
			title: root.reviewPageTitle
			scanInstruction: root.scanInstruction
			startParameters: root.startParameters
			onReviewReady: root._openReviewPage()
		}
	}
}

/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

Page {
	id: root
	readonly property int stateReview: 4
	readonly property int stateProcessing: 5
	readonly property int stateComplete: 7
	readonly property int stateFailed: 8
	readonly property int stateCancelled: 9

	property string subjectLabel
	property string confirmActionText
	property string confirmTitle
	property string confirmDescription
	property string processingText
	property string completionText
	property string completionToast

	readonly property string exchangeServiceUid: BackendConnection.serviceUidForType("exchange")
	property string pendingControlRequestId
	property bool completionPending
	property bool cancellationPending

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

	function sendControl(command) {
		if (!sessionId.value || pendingControlRequestId || !controlRequest.valid) {
			return
		}
		pendingControlRequestId = newRequestId(command)
		completionPending = command === "confirm"
		cancellationPending = command === "cancel"
		controlRequest.setValue(JSON.stringify({
			requestId: pendingControlRequestId,
			sessionId: sessionId.value,
			command: command
		}))
	}

	function processControlReply() {
		const reply = parseReply(controlReply.value)
		if (!reply || reply.requestId !== pendingControlRequestId) {
			return
		}
		pendingControlRequestId = ""
		if (reply.result !== 1) {
			completionPending = false
			cancellationPending = false
			//% "Unable to update exchange"
			Global.showToastNotification(VenusOS.Notification_Warning,
					reply.error || qsTrId("exchangeaction_control_failed"), 5000)
		}
	}

	VeQuickItem { id: controlRequest; uid: root.exchangeServiceUid + "/ControlRequest" }
	VeQuickItem { id: controlReply; uid: root.exchangeServiceUid + "/ControlReply" }
	VeQuickItem { id: controlSequence; uid: root.exchangeServiceUid + "/ControlSequence"; onValueChanged: root.processControlReply() }
	VeQuickItem { id: sessionId; uid: root.exchangeServiceUid + "/SessionId" }
	VeQuickItem {
		id: state
		uid: root.exchangeServiceUid + "/State"
		onValueChanged: {
			if (root.completionPending && value === root.stateComplete) {
				root.completionPending = false
				Global.showToastNotification(VenusOS.Notification_Info,
						root.completionToast, 3000)
				Qt.callLater(Global.pageManager.popPage)
			} else if (root.cancellationPending && value === root.stateCancelled) {
				root.cancellationPending = false
				Qt.callLater(Global.pageManager.popPage)
			}
		}
	}
	VeQuickItem { id: name; uid: root.exchangeServiceUid + "/Name" }
	VeQuickItem { id: summary; uid: root.exchangeServiceUid + "/Summary" }
	VeQuickItem { id: errorCode; uid: root.exchangeServiceUid + "/ErrorCode" }
	VeQuickItem { id: errorText; uid: root.exchangeServiceUid + "/Error" }
	VeQuickItem { id: resultId; uid: root.exchangeServiceUid + "/ResultId" }
	VeQuickItem { id: canConfirm; uid: root.exchangeServiceUid + "/CanConfirm" }
	VeQuickItem { id: canCancel; uid: root.exchangeServiceUid + "/CanCancel" }
	VeQuickItem { id: filename; uid: root.exchangeServiceUid + "/Transfer/Filename" }

	GradientListView {
		model: VisibleItemModel {
			SettingsListHeader {
				//% "Review"
				text: qsTrId("exchangeaction_review")
				preferredVisible: state.value === root.stateReview
			}

			ListText {
				text: root.subjectLabel
				secondaryText: name.value || ""
				preferredVisible: state.value === root.stateReview
			}

			ListText {
				//% "File"
				text: qsTrId("exchangeaction_file")
				secondaryText: filename.value || ""
				caption: summary.value || ""
				preferredVisible: state.value === root.stateReview
			}

			ListButton {
				text: root.confirmActionText
				//% "Add"
				secondaryText: qsTrId("exchangeaction_add")
				writeAccessLevel: VenusOS.User_AccessType_User
				preferredVisible: state.value === root.stateReview && canConfirm.value === 1
				onClicked: Global.dialogLayer.open(confirmDialogComponent)
			}

			ListText {
				text: root.processingText
				//% "Please wait…"
				secondaryText: qsTrId("exchangeaction_please_wait")
				preferredVisible: state.value === root.stateProcessing
			}

			PrimaryListLabel {
				text: root.completionText
				preferredVisible: state.value === root.stateComplete
			}

			PrimaryListLabel {
				//% "Exchange failed"
				text: errorText.value || qsTrId("exchangeaction_exchange_failed")
				preferredVisible: state.value === root.stateFailed
			}

			ListButton {
				//% "Cancel"
				text: qsTrId("exchangeaction_cancel")
				secondaryText: CommonWords.cancel
				writeAccessLevel: VenusOS.User_AccessType_User
				preferredVisible: canCancel.value === 1
				onClicked: root.sendControl("cancel")
			}
		}
	}

	Component {
		id: confirmDialogComponent

		ModalWarningDialog {
			title: root.confirmTitle
			description: root.confirmDescription.arg(name.value || "")
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
			onAccepted: root.sendControl("confirm")
		}
	}
}

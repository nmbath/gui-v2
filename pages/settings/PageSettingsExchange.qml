/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

Page {
	id: root

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

	property string pendingControlRequestId
	property bool completionPending
	property bool cancellationPending

	function sendControl(command) {
		if (!sessionId.value || root.pendingControlRequestId || !controlRequest.valid) {
			return
		}
		root.pendingControlRequestId = Exchange.newRequestId(command)
		root.completionPending = command === "confirm"
		root.cancellationPending = command === "cancel"
		controlRequest.setValue(Exchange.controlRequest(root.pendingControlRequestId, sessionId.value, command))
	}

	function processControlReply() {
		const reply = Exchange.parseJson(controlReply.value)
		if (!reply || reply.requestId !== root.pendingControlRequestId) {
			return
		}
		root.pendingControlRequestId = ""
		if (reply.result !== 1) {
			root.completionPending = false
			root.cancellationPending = false
			//% "Unable to update exchange"
			Global.showToastNotification(VenusOS.Notification_Warning,
					reply.error || qsTrId("exchangeaction_control_failed"), 5000)
		}
	}

	VeQuickItem {
		id: controlRequest
		uid: Exchange.serviceUid + "/ControlRequest"
	}
	VeQuickItem {
		id: controlReply
		uid: Exchange.serviceUid + "/ControlReply"
	}
	VeQuickItem {
		id: controlSequence
		uid: Exchange.serviceUid + "/ControlSequence"
		onValueChanged: root.processControlReply()
	}
	VeQuickItem {
		id: sessionId
		uid: Exchange.serviceUid + "/SessionId"
	}
	VeQuickItem {
		id: state
		uid: Exchange.serviceUid + "/State"
		onValueChanged: {
			if (root.completionPending && value === VenusOS.Exchange_State_Complete) {
				root.completionPending = false
				Global.showToastNotification(VenusOS.Notification_Info, root.completionToast, 3000)
				Qt.callLater(Global.pageManager.popPage)
			} else if (root.cancellationPending && value === VenusOS.Exchange_State_Canceled) {
				root.cancellationPending = false
				Qt.callLater(Global.pageManager.popPage)
			}
		}
	}
	VeQuickItem {
		id: name
		uid: Exchange.serviceUid + "/Name"
	}
	VeQuickItem {
		id: summary
		uid: Exchange.serviceUid + "/Summary"
	}
	VeQuickItem {
		id: errorCode
		uid: Exchange.serviceUid + "/ErrorCode"
	}
	VeQuickItem {
		id: errorText
		uid: Exchange.serviceUid + "/Error"
	}
	VeQuickItem {
		id: canConfirm
		uid: Exchange.serviceUid + "/CanConfirm"
	}
	VeQuickItem {
		id: canCancel
		uid: Exchange.serviceUid + "/CanCancel"
	}
	VeQuickItem {
		id: filename
		uid: Exchange.serviceUid + "/Transfer/Filename"
	}

	GradientListView {
		model: VisibleItemModel {
			SettingsListHeader {
				//% "Review"
				text: qsTrId("exchangeaction_review")
				preferredVisible: state.value === VenusOS.Exchange_State_Review
			}

			ListText {
				text: root.subjectLabel
				secondaryText: name.value || ""
				preferredVisible: state.value === VenusOS.Exchange_State_Review
			}

			ListText {
				//% "File"
				text: qsTrId("exchangeaction_file")
				secondaryText: filename.value || ""
				caption: root.summaryLabel.length === 0 ? summary.value || "" : ""
				preferredVisible: state.value === VenusOS.Exchange_State_Review
			}

			ListText {
				text: root.summaryLabel
				secondaryText: summary.value || ""
				preferredVisible: state.value === VenusOS.Exchange_State_Review
						&& root.summaryLabel.length > 0
						&& summary.valid
						&& summary.value
			}

			ListButton {
				text: root.confirmActionText
				//% "Add"
				secondaryText: qsTrId("exchangeaction_add")
				writeAccessLevel: VenusOS.User_AccessType_User
				preferredVisible: state.value === VenusOS.Exchange_State_Review && canConfirm.value === 1
				onClicked: Global.dialogLayer.open(confirmDialogComponent)
			}

			ListText {
				text: root.processingText
				//% "Please wait..."
				secondaryText: qsTrId("exchangeaction_please_wait")
				preferredVisible: state.value === VenusOS.Exchange_State_Processing
			}

			PrimaryListLabel {
				text: root.completionText
				preferredVisible: state.value === VenusOS.Exchange_State_Complete
			}

			PrimaryListLabel {
				text: root.failureTitle || Exchange.failedText
				preferredVisible: state.value === VenusOS.Exchange_State_Failed
			}

			SecondaryListLabel {
				text: Exchange.errorSummaryText(errorCode.value, errorText.value)
				preferredVisible: state.value === VenusOS.Exchange_State_Failed && text.length > 0
			}

			ListButton {
				//% "Cancel this upload"
				text: root.cancelActionText || qsTrId("exchangeaction_cancel_upload")
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

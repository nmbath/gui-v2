/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

Page {
	id: root

	readonly property int stateIdle: 0
	readonly property int stateWaiting: 1
	readonly property int stateReceiving: 2
	readonly property int stateReview: 3
	readonly property int stateImporting: 4
	readonly property int stateComplete: 5
	readonly property int stateFailed: 6
	readonly property int stateCancelled: 7
	readonly property string importServiceUid: BackendConnection.serviceUidForType("import")
	readonly property bool remoteWasm: Qt.platform.os === "wasm" && BackendConnection.vrm
	readonly property bool serviceAvailable: connected.valid && connected.value === 1
	readonly property int secondsRemaining: expires.valid && expires.value > 0
			? Math.max(0, Math.ceil(expires.value - nowSeconds)) : 0
	property real nowSeconds: Date.now() / 1000
	property bool startRequested
	property bool confirmRequested

	function maybeStart() {
		if (startRequested || remoteWasm || !serviceAvailable || !state.valid || !startAction.valid) {
			return
		}
		if (state.value === stateIdle || state.value === stateComplete
				|| state.value === stateFailed || state.value === stateCancelled) {
			startRequested = true
			startAction.setValue("container")
		}
	}

	function actionErrorText(code) {
		switch (code) {
		case 100:
			//% "Another import is already active"
			return qsTrId("pagesettingscontainerimport_action_busy")
		case 101:
			//% "That action is not available at this stage"
			return qsTrId("pagesettingscontainerimport_action_invalid_state")
		case 102:
			//% "This import type is not supported"
			return qsTrId("pagesettingscontainerimport_action_unsupported")
		default:
			//% "The action could not be completed"
			return qsTrId("pagesettingscontainerimport_action_failed")
		}
	}

	function retry() {
		startRequested = true
		startAction.setValue("container")
	}

	Component.onCompleted: maybeStart()

	Timer {
		interval: 1000
		repeat: true
		running: root.secondsRemaining > 0
		onTriggered: root.nowSeconds = Date.now() / 1000
	}

	VeQuickItem { id: connected; uid: root.importServiceUid + "/Connected"; onValidChanged: root.maybeStart() }
	VeQuickItem {
		id: state
		uid: root.importServiceUid + "/State"
		onValidChanged: root.maybeStart()
		onValueChanged: {
			if (root.confirmRequested && value === root.stateComplete) {
				root.confirmRequested = false
				//% "Container added"
				Global.showToastNotification(VenusOS.Notification_Info,
						qsTrId("pagesettingscontainerimport_added"), 3000)
				Qt.callLater(Global.pageManager.popPage)
			}
		}
	}
	VeQuickItem { id: name; uid: root.importServiceUid + "/Name" }
	VeQuickItem { id: uploadUrl; uid: root.importServiceUid + "/Url" }
	VeQuickItem { id: relativePath; uid: root.importServiceUid + "/Path" }
	VeQuickItem { id: expires; uid: root.importServiceUid + "/Expires" }
	VeQuickItem { id: filename; uid: root.importServiceUid + "/Filename" }
	VeQuickItem { id: bytesReceived; uid: root.importServiceUid + "/BytesReceived" }
	VeQuickItem { id: errorCode; uid: root.importServiceUid + "/ErrorCode" }
	VeQuickItem { id: errorText; uid: root.importServiceUid + "/Error" }
	VeQuickItem { id: resultId; uid: root.importServiceUid + "/ResultId" }
	VeQuickItem { id: actionSequence; uid: root.importServiceUid + "/ActionSequence" }
	VeQuickItem { id: actionResult; uid: root.importServiceUid + "/ActionResult" }
	VeQuickItem { id: actionErrorCode; uid: root.importServiceUid + "/ActionErrorCode" }
	VeQuickItem { id: startAction; uid: root.importServiceUid + "/Start"; onValidChanged: root.maybeStart() }
	VeQuickItem { id: confirmAction; uid: root.importServiceUid + "/Confirm" }
	VeQuickItem { id: cancelAction; uid: root.importServiceUid + "/Cancel" }

	GradientListView {
		model: VisibleItemModel {
			PrimaryListLabel {
				//% "Adding containers from a VRM Remote Console session is not supported yet. Connect to the GX device directly to import a file."
				text: qsTrId("pagesettingscontainerimport_vrm_unavailable")
				preferredVisible: root.remoteWasm
			}

			PrimaryListLabel {
				//% "The local import service is unavailable."
				text: qsTrId("pagesettingscontainerimport_service_unavailable")
				preferredVisible: !root.remoteWasm && connected.valid && !root.serviceAvailable
			}

			ListLink {
				//% "Upload container definition"
				text: qsTrId("pagesettingscontainerimport_upload")
				url: Qt.platform.os === "wasm" ? relativePath.value : uploadUrl.value
				// ListSetting.clickable is read-only. Control whether the QR/link can
				// be activated through its interactive input instead.
				interactive: url.length > 0
				preferredVisible: !root.remoteWasm && root.serviceAvailable
						&& (state.value === root.stateWaiting || state.value === root.stateReceiving)
			}

			ListText {
				//% "Time remaining"
				text: qsTrId("pagesettingscontainerimport_time_remaining")
				//% "%1 seconds"
				secondaryText: qsTrId("pagesettingscontainerimport_seconds").arg(root.secondsRemaining)
				preferredVisible: root.secondsRemaining > 0
			}

			ListText {
				//% "Upload"
				text: qsTrId("pagesettingscontainerimport_upload_status")
				//% "%1 bytes received"
				secondaryText: qsTrId("pagesettingscontainerimport_bytes_received").arg(bytesReceived.value || 0)
				preferredVisible: state.value === root.stateReceiving
			}

			SettingsListHeader {
				//% "Review"
				text: qsTrId("pagesettingscontainerimport_review")
				preferredVisible: state.value === root.stateReview
			}

			ListText {
				//% "Container"
				text: qsTrId("pagesettingscontainerimport_container")
				secondaryText: name.value || ""
				preferredVisible: state.value === root.stateReview
			}

			ListText {
				//% "File"
				text: qsTrId("pagesettingscontainerimport_file")
				secondaryText: filename.value || ""
				preferredVisible: state.value === root.stateReview
			}

			ListButton {
				//% "Add this container"
				text: qsTrId("pagesettingscontainerimport_confirm")
				//% "Add"
				secondaryText: qsTrId("pagesettingscontainerimport_add")
				writeAccessLevel: VenusOS.User_AccessType_User
				preferredVisible: state.value === root.stateReview
				onClicked: Global.dialogLayer.open(confirmDialogComponent)
			}

			ListText {
				//% "Adding container"
				text: qsTrId("pagesettingscontainerimport_adding")
				//% "Please wait…"
				secondaryText: qsTrId("pagesettingscontainerimport_please_wait")
				preferredVisible: state.value === root.stateImporting
			}

			PrimaryListLabel {
				//% "Container added. Setup continues on the container page."
				text: qsTrId("pagesettingscontainerimport_complete")
				preferredVisible: state.value === root.stateComplete
			}

			ListText {
				//% "Definition ID"
				text: qsTrId("pagesettingscontainerimport_result_id")
				secondaryText: resultId.value || ""
				preferredVisible: state.value === root.stateComplete && !!resultId.value
			}

			ListButton {
				//% "Open container"
				text: qsTrId("pagesettingscontainerimport_open_container")
				//% "Open"
				secondaryText: qsTrId("pagesettingscontainerimport_open")
				preferredVisible: state.value === root.stateComplete && !!resultId.value
				onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsContainer.qml", {
						"title": name.value || text,
						"containerPrefix": BackendConnection.serviceUidForType("containers")
								+ "/Containers/" + resultId.value.replace(/-/g, "_")
				})
			}

			PrimaryListLabel {
				//% "Import failed: %1"
				text: qsTrId("pagesettingscontainerimport_failed").arg(errorText.value || errorCode.value || "")
				preferredVisible: state.value === root.stateFailed
			}

			PrimaryListLabel {
				text: root.actionErrorText(actionErrorCode.value)
				preferredVisible: actionResult.valid && actionResult.value === 2
			}

			ListButton {
				//% "Try another file"
				text: qsTrId("pagesettingscontainerimport_retry")
				//% "Retry"
				secondaryText: qsTrId("pagesettingscontainerimport_retry_button")
				writeAccessLevel: VenusOS.User_AccessType_User
				preferredVisible: state.value === root.stateComplete || state.value === root.stateFailed
				onClicked: root.retry()
			}

			ListButton {
				//% "Cancel import"
				text: qsTrId("pagesettingscontainerimport_cancel")
				secondaryText: CommonWords.cancel
				writeAccessLevel: VenusOS.User_AccessType_User
				preferredVisible: state.value === root.stateWaiting || state.value === root.stateReceiving
						|| state.value === root.stateReview
				onClicked: cancelAction.setValue(1)
			}
		}
	}

	Component {
		id: confirmDialogComponent

		ModalWarningDialog {
			//% "Add container?"
			title: qsTrId("pagesettingscontainerimport_confirm_title")
			//% "The validated definition for ‘%1’ will be added to this GX device."
			description: qsTrId("pagesettingscontainerimport_confirm_description").arg(name.value || "")
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
			onAccepted: {
				root.confirmRequested = true
				confirmAction.setValue(1)
			}
		}
	}
}

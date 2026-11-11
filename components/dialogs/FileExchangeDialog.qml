/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

// Shows the file exchange session while the user waits: the QR code for a phone, the file
// arriving and being checked, the confirmed change being made, and why it failed.
ModalDialog {
	id: root

	enum Mode {
		Scan,       // start a session, and show a QR code for a phone to send the file
		Upload,     // start a session, and send the file the browser has
		Confirm,    // confirm the session under review
		Follow      // show the open session, whoever started it
	}

	// The FileExchangeAction, which isn't named as the type here: it uses this type itself.
	required property QtObject fileExchangeAction
	property int mode: FileExchangeDialog.Mode.Scan
	property Page reviewPage

	property string sessionId
	property string pendingRequestId
	// A confirm, cancel or dismiss is pending, sent while the session was in pendingFromState.
	property bool pendingControl
	property int pendingFromState
	property string requestError
	property bool uploadStarted
	// The session belongs to another action, so it is only shown, and can be cancelled.
	property bool foreign
	// The session's id has been published, so its going means it has been cleared.
	property bool sessionSeen

	readonly property bool ownSession: !!root.sessionId && FileExchange.sessionId === root.sessionId
	readonly property int sessionState: root.ownSession ? FileExchange.state : VenusOS.FileExchange_State_Idle
	readonly property bool failed: !!root.requestError || root.sessionState === VenusOS.FileExchange_State_Failed
	readonly property bool waiting: !root.failed && root.sessionState === VenusOS.FileExchange_State_Waiting
	readonly property bool showQrCode: root.waiting && root.mode === FileExchangeDialog.Mode.Scan
	readonly property string progressText: {
		if (root.foreign) {
			return FileExchange.inProgressText()
		}
		switch (root.sessionState) {
		case VenusOS.FileExchange_State_Idle:
			//% "Preparing..."
			return root.failed ? "" : qsTrId("fileexchange_preparing")
		case VenusOS.FileExchange_State_Waiting:
			//% "Sending..."
			return root.mode === FileExchangeDialog.Mode.Upload ? qsTrId("fileexchange_sending") : ""
		case VenusOS.FileExchange_State_Receiving:
			return root.fileExchangeAction.receivingText
		case VenusOS.FileExchange_State_Validating:
			return root.fileExchangeAction.validatingText
		case VenusOS.FileExchange_State_Processing:
			return root.fileExchangeAction.processingText
		case VenusOS.FileExchange_State_Complete:
			return root.fileExchangeAction.completedText
		case VenusOS.FileExchange_State_Cancelled:
			//% "Cancelled"
			return qsTrId("fileexchange_cancelled")
		default:
			return ""
		}
	}

	readonly property string uploadAddress: localAddress(networkServices.value)
	readonly property string uploadScheme: securityProfile.valid
			&& securityProfile.value === VenusOS.Security_Profile_Secured ? "https" : "http"
	readonly property string uploadUrl: FileExchange.capabilityRef
			? "%1://%2/exchange/%3".arg(root.uploadScheme).arg(root.uploadAddress || "venus.local").arg(FileExchange.capabilityRef)
			: ""
	property real nowSeconds: Date.now() / 1000
	readonly property int secondsRemaining: root.waiting && FileExchange.expires > 0
			? Math.max(0, Math.ceil(FileExchange.expires - root.nowSeconds)) : 0

	// The GX device's address on the local network, for a phone to reach it.
	function localAddress(rawServices) {
		const services = FileExchange.parseJson(rawServices)
		if (!services) {
			return ""
		}
		for (const technology of ["ethernet", "wifi"]) {
			for (const details of Object.values(services[technology] || {})) {
				const address = details["Address"] || ""
				if ((details["State"] === "online" || details["State"] === "ready") && address.indexOf(".") >= 0) {
					return address
				}
			}
		}
		return ""
	}

	// Follows the open session, whichever action it is for.
	function follow() {
		root.mode = FileExchangeDialog.Mode.Follow
		root.foreign = !root.fileExchangeAction.ownsSession()
		root.sessionId = FileExchange.sessionId
	}

	// Sends confirm, cancel or dismiss, and waits for its reply or the state it leads to.
	function sendControl(command) {
		root.pendingControl = true
		root.pendingFromState = FileExchange.state
		root.pendingRequestId = FileExchange.control(command)
	}

	// Starts the session, once any ended session is dismissed, or follows it.
	function update() {
		if (root.pendingRequestId) {
			// Over MQTT, the state a control request leads to can arrive before its reply.
			if (!root.pendingControl || FileExchange.state === root.pendingFromState) {
				return
			}
			root.pendingRequestId = ""
		}
		if (root.failed) {
			return
		}
		if (!root.sessionId) {
			if (!FileExchange.valid) {
				return
			}
			if (FileExchange.state === VenusOS.FileExchange_State_Idle) {
				root.pendingControl = false
				root.pendingRequestId = FileExchange.start(root.fileExchangeAction.actionId, root.fileExchangeAction.parameters)
			} else if (FileExchange.ended
					|| (FileExchange.state === VenusOS.FileExchange_State_Waiting && root.fileExchangeAction.ownsSession())) {
				// Ended, or left waiting for this action: nothing was sent, so start afresh.
				root.sendControl(FileExchange.ended ? "dismiss" : "cancel")
			} else {
				// Opened elsewhere since: show it, so it can be finished or cancelled.
				root.follow()
				root.update()
			}
			return
		}
		if (root.ownSession) {
			root.sessionSeen = true
		} else {
			// The reply can arrive before the session's id is published. Once it has been, its
			// going means the session was cleared, such as by the app manager restarting.
			if (root.sessionSeen || (FileExchange.sessionId && FileExchange.sessionId !== root.sessionId)) {
				root.close()
			}
			return
		}

		if (root.foreign) {
			if (FileExchange.ended || FileExchange.state === VenusOS.FileExchange_State_Idle) {
				if (FileExchange.ended) {
					FileExchange.control("dismiss")
				}
				root.close()
			}
			return
		}

		switch (FileExchange.state) {
		case VenusOS.FileExchange_State_Waiting:
			if (root.mode === FileExchangeDialog.Mode.Upload && !root.uploadStarted
					&& FileExchange.transferReady && FileExchange.capabilityRef) {
				root.uploadStarted = true
				if (!BackendConnection.uploadFileExchangeFile(FileExchange.capabilityRef)
						&& Qt.platform.os === "wasm") {
					root.uploadFailed()
				}
			}
			break
		case VenusOS.FileExchange_State_Review:
			if (root.mode !== FileExchangeDialog.Mode.Confirm) {
				root.close()
				root.fileExchangeAction.openReview()
			}
			break
		case VenusOS.FileExchange_State_Complete:
			FileExchange.control("dismiss")
			root.close()
			if (root.fileExchangeAction.completedText) {
				Global.showToastNotification(VenusOS.Notification_Info, root.fileExchangeAction.completedText, 3000)
			}
			root.fileExchangeAction.finish(root.reviewPage)
			break
		case VenusOS.FileExchange_State_Cancelled:
			FileExchange.control("dismiss")
			root.close()
			root.fileExchangeAction.finish(root.reviewPage)
			break
		}
	}

	function uploadFailed() {
		//% "The file could not be sent"
		root.requestError = qsTrId("fileexchange_upload_failed")
		FileExchange.control("cancel")
	}

	title: root.fileExchangeAction.title
	dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkOnly
	//% "Close"
	acceptText: root.failed || (root.foreign && !FileExchange.canCancel) ? qsTrId("fileexchange_close") : CommonWords.cancel
	canAccept: root.failed || root.foreign || !root.ownSession || FileExchange.canCancel
	tryAccept: function() {
		if (root.failed) {
			if (root.ownSession) {
				FileExchange.control("dismiss")
			}
			if (root.mode === FileExchangeDialog.Mode.Confirm) {
				root.fileExchangeAction.finish(root.reviewPage)
			}
			return true
		}
		if (root.ownSession && FileExchange.canCancel) {
			// Closed once the session is Cancelled.
			FileExchange.control("cancel")
			return false
		}
		return true
	}

	Component.onCompleted: {
		if (root.mode === FileExchangeDialog.Mode.Confirm) {
			root.sessionId = FileExchange.sessionId
			root.sendControl("confirm")
		} else {
			if (root.mode === FileExchangeDialog.Mode.Follow) {
				root.follow()
			}
			root.update()
		}
	}

	Connections {
		target: FileExchange
		// Later, once the session's values have all changed.
		function onStateChanged() { Qt.callLater(root.update) }
		function onValidChanged() { Qt.callLater(root.update) }
		function onTransferReadyChanged() { Qt.callLater(root.update) }
		function onCapabilityRefChanged() { Qt.callLater(root.update) }
		function onSessionIdChanged() { Qt.callLater(root.update) }

		function onStartReplied(requestId, accepted, error, sessionId) {
			if (requestId !== root.pendingRequestId) {
				return
			}
			root.pendingRequestId = ""
			if (accepted) {
				root.sessionId = sessionId
			} else {
				root.requestError = error || FileExchange.failedText
			}
			root.update()
		}

		function onControlReplied(requestId, accepted, error) {
			if (requestId !== root.pendingRequestId) {
				return
			}
			root.pendingRequestId = ""
			if (!accepted) {
				root.requestError = error || FileExchange.failedText
			}
			root.update()
		}
	}

	Connections {
		target: BackendConnection
		enabled: root.uploadStarted
		function onFileExchangeUploadStatusChanged() {
			if (BackendConnection.fileExchangeUploadStatus === BackendConnection.FileExchangeUploadFailed) {
				root.uploadFailed()
			}
		}
	}

	Timer {
		interval: 1000
		repeat: true
		running: root.secondsRemaining > 0
		onTriggered: root.nowSeconds = Date.now() / 1000
	}

	VeQuickItem {
		id: networkServices
		uid: Services.platform.serviceUid + "/Network/Services"
	}

	VeQuickItem {
		id: securityProfile
		uid: Services.settings.serviceUid + "/Settings/System/SecurityProfile"
	}

	contentItem: ModalDialog.FocusableContentItem {
		implicitHeight: root.showQrCode ? Theme.geometry_fileExchangeDialog_contentItem_height : contentColumn.implicitHeight + 2 * Theme.geometry_modalDialog_content_spacing

		ColumnLayout {
			id: contentColumn

			anchors {
				fill: parent
				margins: Theme.geometry_modalDialog_content_spacing
			}
			spacing: Theme.geometry_modalDialog_content_spacing

			Label {
				text: root.fileExchangeAction.scanInstruction
				visible: root.showQrCode
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.Wrap
				Layout.fillWidth: true
			}

			Item {
				visible: root.showQrCode
				Layout.fillHeight: true
				Layout.preferredWidth: height
				Layout.maximumWidth: parent.width
				Layout.alignment: Qt.AlignHCenter

				Rectangle {
					anchors.fill: parent
					color: Theme.color_white
					visible: !!root.uploadUrl

					Image {
						anchors {
							fill: parent
							margins: Theme.geometry_fileExchangeDialog_qrCode_margin
						}
						source: root.uploadUrl && width > 0 && height > 0
								? `image://QZXing/encode/${root.uploadUrl}?correctionLevel=M&format=qrcode` : ""
						sourceSize: Qt.size(width, height)
						fillMode: Image.PreserveAspectFit
					}
				}
			}

			Label {
				//% "Or type this address into a browser:"
				text: qsTrId("fileexchange_type_address")
				visible: root.showQrCode && !!root.uploadUrl
				horizontalAlignment: Text.AlignHCenter
				Layout.fillWidth: true
			}

			Label {
				text: root.uploadUrl
				visible: root.showQrCode && !!root.uploadUrl
				font.pixelSize: Theme.font_size_caption
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.WrapAnywhere
				textFormat: Text.PlainText
				Layout.fillWidth: true
			}

			Label {
				//: %1 = number of seconds
				//% "Time remaining: %1 seconds"
				text: qsTrId("fileexchange_time_remaining").arg(root.secondsRemaining)
				visible: root.showQrCode && root.secondsRemaining > 0
				horizontalAlignment: Text.AlignHCenter
				Layout.fillWidth: true
			}

			Label {
				text: root.progressText
				visible: !root.showQrCode && !root.failed
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.Wrap
				Layout.fillWidth: true
			}

			ProgressBar {
				from: 0
				to: Math.max(1, FileExchange.fileSize)
				value: FileExchange.bytesTransferred
				indeterminate: root.sessionState !== VenusOS.FileExchange_State_Receiving || FileExchange.fileSize <= 0
				visible: !root.showQrCode && !root.failed
				Layout.fillWidth: true
			}

			Label {
				text: root.fileExchangeAction.failedTitle || FileExchange.failedText
				visible: root.failed
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.Wrap
				Layout.fillWidth: true
			}

			Label {
				text: root.requestError || FileExchange.errorSummary(FileExchange.errorCode, FileExchange.error)
				visible: root.failed && text.length > 0
				color: Theme.color_font_secondary
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.Wrap
				textFormat: Text.PlainText
				Layout.fillWidth: true
			}
		}
	}
}

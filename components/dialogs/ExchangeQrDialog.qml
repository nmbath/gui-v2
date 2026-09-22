/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

ModalDialog {
	id: root

	required property string actionId
	required property string actionDbusKey
	property string scanInstruction
	property var startParameters: ({})

	readonly property string claimAddress: localAddress(networkServices.value)
	readonly property string claimScheme: securityProfile.valid
			&& securityProfile.value === VenusOS.Security_Profile_Secured ? "https" : "http"
	readonly property string claimOrigin: claimAddress.length > 0
			? claimScheme + "://" + claimAddress : claimScheme + "://venus.local"
	readonly property string claimUrl: capabilityRef.value
			? claimOrigin + "/exchange/claim/" + capabilityRef.value : ""
	readonly property bool failed: !!requestError || state.value === VenusOS.Exchange_State_Failed
	readonly property int secondsRemaining: transferExpires.valid && transferExpires.value > 0
			? Math.max(0, Math.ceil(transferExpires.value - nowSeconds)) : 0
	property real nowSeconds: Date.now() / 1000
	property string pendingStartRequestId
	property string pendingControlRequestId
	property string requestError

	signal reviewReady

	function localAddress(rawServices) {
		const services = Exchange.parseJson(rawServices)
		if (!services) {
			return ""
		}
		for (const technology of ["ethernet", "wifi"]) {
			for (const details of Object.values(services[technology] || {})) {
				const address = details["Address"] || ""
				if ((details["State"] === "online" || details["State"] === "ready")
						&& address.indexOf(".") >= 0) {
					return address
				}
			}
		}
		return ""
	}

	function maybeStart() {
		if (root.pendingStartRequestId || connected.value !== 1 || availableItem.value !== 1
				|| !requestItem.valid || !state.valid) {
			return
		}
		if (state.value === VenusOS.Exchange_State_Idle
				|| state.value === VenusOS.Exchange_State_Complete
				|| state.value === VenusOS.Exchange_State_Failed
				|| state.value === VenusOS.Exchange_State_Canceled) {
			root.pendingStartRequestId = Exchange.newRequestId(root.actionId)
			requestItem.setValue(Exchange.startRequest(root.pendingStartRequestId, root.actionId,
					root.startParameters))
		}
	}

	function processStartReply() {
		const reply = Exchange.parseJson(requestReply.value)
		if (!reply || reply.requestId !== root.pendingStartRequestId) {
			return
		}
		root.pendingStartRequestId = ""
		if (reply.result !== 1) {
			root.requestError = reply.error || Exchange.startFailedText
		}
	}

	function handleState() {
		// A closed dialog must not start sessions of its own.
		if (!root.opened) {
			return
		}
		if (state.value === VenusOS.Exchange_State_Review) {
			root.reviewReady()
			root.close()
		} else {
			root.maybeStart()
		}
	}

	function cancelExchange() {
		if (!sessionId.value || root.pendingControlRequestId || !controlRequest.valid) {
			return false
		}
		root.pendingControlRequestId = Exchange.newRequestId("cancel")
		controlRequest.setValue(Exchange.controlRequest(root.pendingControlRequestId, sessionId.value, "cancel"))
		return true
	}

	dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkOnly
	//% "Close"
	acceptText: root.failed ? qsTrId("exchangeaction_close") : CommonWords.cancel
	tryAccept: function() {
		if (state.value === VenusOS.Exchange_State_Preparing
				|| state.value === VenusOS.Exchange_State_Waiting
				|| state.value === VenusOS.Exchange_State_Receiving) {
			return root.cancelExchange()
		}
		return true
	}

	Component.onCompleted: root.maybeStart()

	Timer {
		interval: 1000
		repeat: true
		running: root.secondsRemaining > 0
		onTriggered: root.nowSeconds = Date.now() / 1000
	}

	VeQuickItem {
		id: connected
		uid: Exchange.serviceUid + "/Connected"
		onValidChanged: root.maybeStart()
	}
	VeQuickItem {
		id: networkServices
		uid: Services.platform.serviceUid + "/Network/Services"
	}
	VeQuickItem {
		id: securityProfile
		uid: Services.settings.serviceUid + "/Settings/System/SecurityProfile"
	}
	VeQuickItem {
		id: availableItem
		uid: Exchange.serviceUid + "/Actions/" + root.actionDbusKey + "/Available"
		onValidChanged: root.maybeStart()
	}
	VeQuickItem {
		id: requestItem
		uid: Exchange.serviceUid + "/Request"
		onValidChanged: root.maybeStart()
	}
	VeQuickItem {
		id: requestReply
		uid: Exchange.serviceUid + "/RequestReply"
	}
	VeQuickItem {
		id: requestSequence
		uid: Exchange.serviceUid + "/RequestSequence"
		onValueChanged: root.processStartReply()
	}
	VeQuickItem {
		id: controlRequest
		uid: Exchange.serviceUid + "/ControlRequest"
	}
	VeQuickItem {
		id: sessionId
		uid: Exchange.serviceUid + "/SessionId"
	}
	VeQuickItem {
		id: state
		uid: Exchange.serviceUid + "/State"
		onValidChanged: root.handleState()
		onValueChanged: root.handleState()
	}
	VeQuickItem {
		id: capabilityRef
		uid: Exchange.serviceUid + "/Transfer/CapabilityRef"
	}
	VeQuickItem {
		id: transferExpires
		uid: Exchange.serviceUid + "/Transfer/Expires"
	}
	VeQuickItem {
		id: fileSize
		uid: Exchange.serviceUid + "/Transfer/FileSize"
	}
	VeQuickItem {
		id: bytesTransferred
		uid: Exchange.serviceUid + "/Transfer/BytesTransferred"
	}
	VeQuickItem {
		id: errorText
		uid: Exchange.serviceUid + "/Error"
	}

	contentItem: ModalDialog.FocusableContentItem {
		implicitHeight: Theme.geometry_exchangeQrDialog_contentItem_height

		ColumnLayout {
			anchors {
				fill: parent
				margins: Theme.geometry_modalDialog_content_spacing
			}
			spacing: Theme.geometry_modalDialog_content_spacing

			Label {
				text: root.scanInstruction
				visible: !root.failed
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.Wrap
				Layout.fillWidth: true
			}

			Item {
				visible: !root.failed
				Layout.fillHeight: true
				Layout.preferredWidth: height
				Layout.maximumWidth: parent.width
				Layout.alignment: Qt.AlignHCenter

				Rectangle {
					anchors.fill: parent
					color: Theme.color_white
					visible: !!root.claimUrl

					Image {
						anchors {
							fill: parent
							margins: Theme.geometry_exchangeQrDialog_qrCode_margin
						}
						source: root.claimUrl && width > 0 && height > 0
								? `image://QZXing/encode/${root.claimUrl}?correctionLevel=M&format=qrcode` : ""
						sourceSize: Qt.size(width, height)
						fillMode: Image.PreserveAspectFit
					}
				}

				Label {
					anchors.centerIn: parent
					//% "Preparing..."
					text: qsTrId("exchangeaction_preparing")
					visible: !root.claimUrl
				}
			}

			Label {
				//% "Or type this address into a browser:"
				text: qsTrId("exchangeaction_type_address")
				visible: !!root.claimUrl
				horizontalAlignment: Text.AlignHCenter
				Layout.fillWidth: true
			}

			Label {
				text: root.claimUrl
				visible: !!root.claimUrl
				font.pixelSize: Theme.font_size_caption
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.WrapAnywhere
				textFormat: Text.PlainText
				Layout.fillWidth: true
			}

			Label {
				//: %1 = number of seconds
				//% "Time remaining: %1 seconds"
				text: qsTrId("exchangeaction_time_remaining").arg(root.secondsRemaining)
				visible: state.value === VenusOS.Exchange_State_Waiting
				horizontalAlignment: Text.AlignHCenter
				Layout.fillWidth: true
			}

			ProgressBar {
				from: 0
				to: Math.max(1, fileSize.value || 0)
				value: bytesTransferred.value || 0
				indeterminate: !(fileSize.value > 0)
				visible: state.value === VenusOS.Exchange_State_Receiving
				Layout.fillWidth: true
			}

			Label {
				text: root.requestError || errorText.value || Exchange.failedText
				horizontalAlignment: Text.AlignHCenter
				verticalAlignment: Text.AlignVCenter
				wrapMode: Text.Wrap
				visible: root.failed
				Layout.fillWidth: true
				Layout.fillHeight: true
			}
		}
	}
}

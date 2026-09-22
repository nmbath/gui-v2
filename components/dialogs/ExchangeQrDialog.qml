/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

ModalDialog {
	id: root
	readonly property int stateIdle: 0
	readonly property int statePreparing: 1
	readonly property int stateWaiting: 2
	readonly property int stateReceiving: 3
	readonly property int stateReview: 4
	readonly property int stateComplete: 7
	readonly property int stateFailed: 8
	readonly property int stateCancelled: 9

	required property string actionId
	required property string actionDbusKey
	property string scanInstruction
	signal reviewReady

	readonly property string exchangeServiceUid: BackendConnection.serviceUidForType("exchange")
	readonly property string claimAddress: localAddress(networkServices.value)
	readonly property string claimOrigin: claimAddress.length > 0
			? "http://" + claimAddress : "http://venus.local"
	readonly property string claimUrl: capabilityRef.value
			? claimOrigin + "/exchange/claim/" + capabilityRef.value : ""
	readonly property int secondsRemaining: transferExpires.valid && transferExpires.value > 0
			? Math.max(0, Math.ceil(transferExpires.value - nowSeconds)) : 0
	property real nowSeconds: Date.now() / 1000
	property string pendingStartRequestId
	property string pendingControlRequestId
	property string requestError

	function newRequestId(prefix) {
		return prefix + "-" + Date.now().toString(36) + "-"
				+ Math.floor(Math.random() * 0x100000000).toString(36)
	}

	function localAddress(rawServices) {
		if (typeof rawServices !== "string" || rawServices.length === 0) {
			return ""
		}
		try {
			const services = JSON.parse(rawServices)
			for (const technology of ["ethernet", "wifi"]) {
				for (const details of Object.values(services[technology] || {})) {
					const address = details["Address"] || ""
					if ((details["State"] === "online" || details["State"] === "ready")
							&& address.indexOf(".") >= 0) {
						return address
					}
				}
			}
		} catch (error) {
			return ""
		}
		return ""
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

	function maybeStart() {
		if (pendingStartRequestId || connected.value !== 1 || availableItem.value !== 1
				|| !requestItem.valid || !state.valid) {
			return
		}
		if (state.value === root.stateIdle
				|| state.value === root.stateComplete
				|| state.value === root.stateFailed
				|| state.value === root.stateCancelled) {
			pendingStartRequestId = newRequestId(actionId)
			requestItem.setValue(JSON.stringify({
				requestId: pendingStartRequestId,
				action: actionId,
				parameters: {}
			}))
		}
	}

	function processStartReply() {
		const reply = parseReply(requestReply.value)
		if (!reply || reply.requestId !== pendingStartRequestId) {
			return
		}
		pendingStartRequestId = ""
		if (reply.result !== 1) {
			//% "Unable to start exchange"
			requestError = reply.error || qsTrId("exchangeaction_start_failed")
		}
	}

	function handleState() {
		if (state.value === root.stateReview) {
			reviewReady()
			close()
		} else {
			maybeStart()
		}
	}

	function cancelExchange() {
		if (!sessionId.value || pendingControlRequestId || !controlRequest.valid) {
			return false
		}
		pendingControlRequestId = newRequestId("cancel")
		controlRequest.setValue(JSON.stringify({
			requestId: pendingControlRequestId,
			sessionId: sessionId.value,
			command: "cancel"
		}))
		return true
	}

	dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkOnly
	//% "Close"
	acceptText: state.value === root.stateFailed || requestError
			? qsTrId("exchangeaction_close") : CommonWords.cancel
	tryAccept: function() {
		if (state.value === root.statePreparing
				|| state.value === root.stateWaiting
				|| state.value === root.stateReceiving) {
			return cancelExchange()
		}
		return true
	}

	Component.onCompleted: maybeStart()

	Timer {
		interval: 1000
		repeat: true
		running: root.secondsRemaining > 0
		onTriggered: root.nowSeconds = Date.now() / 1000
	}

	VeQuickItem { id: connected; uid: root.exchangeServiceUid + "/Connected"; onValidChanged: root.maybeStart() }
	VeQuickItem { id: networkServices; uid: Global.venusPlatform.serviceUid + "/Network/Services" }
	VeQuickItem { id: availableItem; uid: root.exchangeServiceUid + "/Actions/" + root.actionDbusKey + "/Available"; onValidChanged: root.maybeStart() }
	VeQuickItem { id: requestItem; uid: root.exchangeServiceUid + "/Request"; onValidChanged: root.maybeStart() }
	VeQuickItem { id: requestReply; uid: root.exchangeServiceUid + "/RequestReply" }
	VeQuickItem { id: requestSequence; uid: root.exchangeServiceUid + "/RequestSequence"; onValueChanged: root.processStartReply() }
	VeQuickItem { id: controlRequest; uid: root.exchangeServiceUid + "/ControlRequest" }
	VeQuickItem { id: sessionId; uid: root.exchangeServiceUid + "/SessionId" }
	VeQuickItem {
		id: state
		uid: root.exchangeServiceUid + "/State"
		onValidChanged: root.handleState()
		onValueChanged: root.handleState()
	}
	VeQuickItem { id: capabilityRef; uid: root.exchangeServiceUid + "/Transfer/CapabilityRef" }
	VeQuickItem { id: transferExpires; uid: root.exchangeServiceUid + "/Transfer/Expires" }
	VeQuickItem { id: bytesTransferred; uid: root.exchangeServiceUid + "/Transfer/BytesTransferred" }
	VeQuickItem { id: errorText; uid: root.exchangeServiceUid + "/Error" }

	contentItem: ModalDialog.FocusableContentItem {
		implicitHeight: Math.min(Theme.geometry_screen_height * 0.72, 560)

		ColumnLayout {
			anchors {
				fill: parent
				margins: Theme.geometry_modalDialog_content_spacing
			}
			spacing: Theme.geometry_modalDialog_content_spacing

			Label {
				text: root.scanInstruction
				visible: !root.requestError && state.value !== root.stateFailed
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.Wrap
				Layout.fillWidth: true
			}

			Item {
				visible: !root.requestError && state.value !== root.stateFailed
				Layout.fillHeight: true
				Layout.preferredWidth: height
				Layout.maximumWidth: parent.width
				Layout.alignment: Qt.AlignHCenter

				Rectangle {
					anchors.fill: parent
					color: Theme.color_white
					visible: !!root.claimUrl

					Image {
						anchors { fill: parent; margins: parent.width * 0.12 }
						source: `image://QZXing/encode/${root.claimUrl}?correctionLevel=M&format=qrcode`
						sourceSize: Qt.size(width, height)
						fillMode: Image.PreserveAspectFit
					}
				}

				Label {
					anchors.centerIn: parent
					//% "Preparing…"
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
				//% "Time remaining: %1 seconds"
				text: qsTrId("exchangeaction_time_remaining").arg(root.secondsRemaining)
				visible: state.value === root.stateWaiting
						|| state.value === root.stateReceiving
				horizontalAlignment: Text.AlignHCenter
				Layout.fillWidth: true
			}

			Label {
				//% "%1 bytes received"
				text: qsTrId("exchangeaction_bytes_received").arg(bytesTransferred.value || 0)
				horizontalAlignment: Text.AlignHCenter
				visible: state.value === root.stateReceiving
				Layout.fillWidth: true
			}

			Label {
				//% "Exchange failed"
				text: root.requestError || errorText.value || qsTrId("exchangeaction_exchange_failed")
				horizontalAlignment: Text.AlignHCenter
				verticalAlignment: Text.AlignVCenter
				wrapMode: Text.Wrap
				visible: !!root.requestError || state.value === root.stateFailed
				Layout.fillWidth: true
				Layout.fillHeight: true
			}
		}
	}
}

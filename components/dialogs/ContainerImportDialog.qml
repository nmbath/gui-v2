/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

ModalDialog {
	id: root

	signal reviewReady

	readonly property int stateIdle: 0
	readonly property int stateWaiting: 1
	readonly property int stateReceiving: 2
	readonly property int stateReview: 3
	readonly property int stateComplete: 5
	readonly property int stateFailed: 6
	readonly property int stateCancelled: 7
	readonly property string importServiceUid: BackendConnection.serviceUidForType("import")
	//% "Close"
	readonly property string closeText: qsTrId("pagesettingscontainerimport_close")
	readonly property int secondsRemaining: expires.valid && expires.value > 0
			? Math.max(0, Math.ceil(expires.value - nowSeconds)) : 0
	property real nowSeconds: Date.now() / 1000
	property bool startRequested

	function maybeStart() {
		if (startRequested || !state.valid || !startAction.valid) {
			return
		}
		if (state.value === stateIdle || state.value === stateComplete
				|| state.value === stateFailed || state.value === stateCancelled) {
			startRequested = true
			startAction.setValue("container")
		}
	}

	title: qsTrId("pagesettingscontainers_add_from_file")
	// ModalDialog's CancelOnly mode still renders its normal accept button on
	// landscape displays. Use the single-button layout and make that action
	// cancel this import.
	dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkOnly
	acceptText: state.value === stateFailed ? root.closeText : CommonWords.cancel

	onAccepted: {
		if (state.value === stateWaiting || state.value === stateReceiving) {
			cancelAction.setValue(1)
		}
	}

	Component.onCompleted: maybeStart()

	Timer {
		interval: 1000
		repeat: true
		running: root.secondsRemaining > 0
		onTriggered: root.nowSeconds = Date.now() / 1000
	}

	VeQuickItem {
		id: state
		uid: root.importServiceUid + "/State"
		onValidChanged: root.maybeStart()
		onValueChanged: {
			if (value === root.stateReview) {
				root.reviewReady()
				root.close()
			}
		}
	}
	VeQuickItem { id: uploadUrl; uid: root.importServiceUid + "/Url" }
	VeQuickItem { id: expires; uid: root.importServiceUid + "/Expires" }
	VeQuickItem { id: bytesReceived; uid: root.importServiceUid + "/BytesReceived" }
	VeQuickItem { id: errorText; uid: root.importServiceUid + "/Error" }
	VeQuickItem { id: startAction; uid: root.importServiceUid + "/Start"; onValidChanged: root.maybeStart() }
	VeQuickItem { id: cancelAction; uid: root.importServiceUid + "/Cancel" }

	contentItem: ModalDialog.FocusableContentItem {
		implicitHeight: Math.min(Theme.geometry_screen_height * 0.65, 500)

		ColumnLayout {
			anchors {
				fill: parent
				margins: Theme.geometry_modalDialog_content_spacing
			}
			spacing: Theme.geometry_modalDialog_content_spacing

			Label {
				//% "Scan this QR code to upload a container definition."
				text: qsTrId("pagesettingscontainerimport_scan_instruction")
				visible: state.value !== root.stateFailed
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.Wrap
				Layout.fillWidth: true
			}

			Item {
				visible: state.value !== root.stateFailed
				Layout.fillHeight: true
				Layout.preferredWidth: height
				Layout.maximumWidth: parent.width
				Layout.alignment: Qt.AlignHCenter

				Rectangle {
					anchors.fill: parent
					color: Theme.color_white
					visible: uploadUrl.valid && !!uploadUrl.value

					Image {
						anchors {
							fill: parent
							margins: parent.width * 0.12
						}
						source: `image://QZXing/encode/${uploadUrl.value}?correctionLevel=M&format=qrcode`
						sourceSize: Qt.size(width, height)
						fillMode: Image.PreserveAspectFit
					}
				}

				Label {
					anchors.centerIn: parent
					//% "Preparing…"
					text: qsTrId("pagesettingscontainerimport_preparing")
					visible: !uploadUrl.valid || !uploadUrl.value
				}
			}

			Label {
				//% "Time remaining: %1 seconds"
				text: qsTrId("pagesettingscontainerimport_time_remaining_value").arg(root.secondsRemaining)
				visible: state.value === root.stateWaiting || state.value === root.stateReceiving
				horizontalAlignment: Text.AlignHCenter
				Layout.fillWidth: true
			}

			Label {
				//% "%1 bytes received"
				text: qsTrId("pagesettingscontainerimport_bytes_received").arg(bytesReceived.value || 0)
				horizontalAlignment: Text.AlignHCenter
				visible: state.value === root.stateReceiving
				Layout.fillWidth: true
			}

			Label {
				//% "Container definition rejected"
				text: qsTrId("pagesettingscontainerimport_rejected")
				font.pixelSize: Theme.font_dialog_header_smallSize
				font.bold: true
				horizontalAlignment: Text.AlignHCenter
				visible: state.value === root.stateFailed
				Layout.fillWidth: true
			}

			Label {
				text: errorText.value || qsTrId("pagesettingscontainerimport_action_failed")
				horizontalAlignment: Text.AlignHCenter
				verticalAlignment: Text.AlignVCenter
				wrapMode: Text.Wrap
				visible: state.value === root.stateFailed
				Layout.fillWidth: true
				Layout.fillHeight: true
			}
		}
	}
}

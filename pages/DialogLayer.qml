/*
** Copyright (C) 2024 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

Item {
	id: root

	property QtObject currentDialog
	anchors.fill: parent

	function open(dialogComponent, properties) {
		currentDialog = dialogComponent.createObject(root, properties)
		currentDialog.closed.connect(function() {
			if (currentDialog) {
				currentDialog.destroy()
				currentDialog = null
			}
		})
		currentDialog.open()
		return currentDialog
	}

	Connections {
		target: Global.mainView
		ignoreUnknownSignals: true
		function onCurrentPageChanged() {
			// If the parent page is closed close the dialog also,
			// e.g. when an alarm is received, which pops existing
			// pages on the page stack and opens Notificationgs page.
			if (currentDialog) {
				currentDialog.destroy()
				currentDialog = null
			}
		}
	}

	Connections {
		target: ScreenBlanker
		function onBlankedChanged() {
			// If the screen blanker blanks the screen, we should
			// close the dialog.
			if (ScreenBlanker.blanked && currentDialog) {
				currentDialog.destroy()
				currentDialog = null
			}
		}
	}

	Connections {
		target: Theme
		function onScreenSizeChanged() {
			// If the orientation changes repeatedly between portrait and landscape, any open dialog
			// will not update its geometry correctly as expected. So, force-close any opened
			// dialogs when the screen size changes.
			if (currentDialog) {
				currentDialog.destroy()
				currentDialog = null
			}
		}
	}

	// For WebAssembly, if the firmware changed on device, this might
	// mean that the webassembly blob served by its webserver has changed.
	// We need to trigger a page reload to ensure we are running the right one.
	property Component _firmwareVersionRestartDialog: Component {
		ModalWarningDialog {
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_NoOptions
			//% "GX device has been updated"
			title: qsTrId("firmware_installed_build_gx_device_updated")
			//% "Page will automatically reload in ten seconds to load the latest version."
			description: qsTrId("firmware_installed_build_page_will_reload")
			icon.source: "qrc:/images/icon_info_48.svg"
			icon.color: Theme.color_blue
			Timer {
				running: true
				interval: 10*1000
				onTriggered: BackendConnection.reloadPage()
			}
		}
	}

	property bool _needPageReload: Global.needPageReload
	on_NeedPageReloadChanged: if (_needPageReload) open(_firmwareVersionRestartDialog)

	// A brand-new, not-yet-adopted Storage Manager volume was just seen
	// (data/Storage.qml, app-wide - not scoped to any particular storage
	// settings page) - offer to manage it, or dismiss for this session.
	Connections {
		target: Global.storage
		function onNewTransientVolumeDetected(volumeId, volumePrefix) {
			root.open(root._newStorageDetectedDialog, {"volumeId": volumeId, "volumePrefix": volumePrefix})
		}
	}

	property Component _newStorageDetectedDialog: Component {
		ModalDialog {
			id: newStorageDialog

			required property string volumeId
			required property string volumePrefix

			//% "New storage detected"
			title: qsTrId("dialoglayer_new_storage_title")
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_NoOptions

			readonly property string volumeLabel: labelItem.value || ""
			readonly property real volumeCapacity: capacityItem.value || 0

			VeQuickItem { id: labelItem; uid: newStorageDialog.volumePrefix + "/Label" }
			VeQuickItem { id: capacityItem; uid: newStorageDialog.volumePrefix + "/Capacity" }
			VeQuickItem { id: adoptAction; uid: newStorageDialog.volumePrefix + "/Admin/Adopt" }

			contentItem: Item {
				implicitWidth: Theme.geometry_modalDialog_width
				implicitHeight: bodyLabel.implicitHeight + (2 * Theme.geometry_modalDialog_content_spacing)

				Label {
					id: bodyLabel
					anchors {
						left: parent.left
						right: parent.right
						verticalCenter: parent.verticalCenter
						margins: Theme.geometry_modalDialog_content_spacing
					}
					//% "%1 (%2) can be managed by this device for use as extended storage."
					text: qsTrId("dialoglayer_new_storage_body")
							.arg(newStorageDialog.volumeLabel.length
								 //% "Unnamed volume"
								 ? newStorageDialog.volumeLabel : qsTrId("dialoglayer_new_storage_unnamed"))
							.arg(Containers.formatBytes(newStorageDialog.volumeCapacity))
					wrapMode: Text.Wrap
				}
			}

			footer: FocusScope {
				implicitHeight: Theme.geometry_modalDialog_footer_height
				focus: true
				Keys.onEscapePressed: newStorageDialog.reject()
				Keys.enabled: Global.keyNavigationEnabled

				SeparatorBar {
					anchors { left: parent.left; right: parent.right; top: parent.top }
				}

				RowLayout {
					anchors { fill: parent; topMargin: 1 }
					spacing: 0

					Button {
						//% "Ignore"
						text: qsTrId("dialoglayer_new_storage_ignore")
						flat: true
						Layout.fillWidth: true
						Layout.fillHeight: true
						onClicked: newStorageDialog.reject()
					}
					Button {
						//% "Manage"
						text: qsTrId("dialoglayer_new_storage_manage")
						flat: true
						Layout.fillWidth: true
						Layout.fillHeight: true
						onClicked: {
							adoptAction.setValue(1)
							newStorageDialog.accept()
						}
					}
				}
			}
		}
	}
}

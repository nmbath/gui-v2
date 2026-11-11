/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

// One GX App, as com.victronenergy.appmanager publishes it under /GxApps/<name>: enabling,
// updating and removing it.
Page {
	id: root

	required property string appUid

	readonly property string appManagerUid: appUid.substring(0, appUid.lastIndexOf("/GxApps/"))
	readonly property bool enabled: enableItem.value === 1
	// The app manager refuses to disable the app whose Custom Branding is in use.
	readonly property bool customBrandingInUse: !!nameItem.value && nameItem.value === customBrandingItem.value

	function componentsText(components) {
		let names = []
		if (components & VenusOS.GxApp_Component_Gui) {
			//% "GUI extension"
			names.push(qsTrId("settings_gxapp_component_gui"))
		}
		if (components & VenusOS.GxApp_Component_CustomBranding) {
			//% "Custom Branding"
			names.push(qsTrId("settings_gxapp_component_custom_branding"))
		}
		if (components & VenusOS.GxApp_Component_Service) {
			//% "Service"
			names.push(qsTrId("settings_gxapp_component_service"))
		}
		return names.join(", ")
	}

	// Back to the list, unless already there.
	function leave() {
		if (Global.pageManager.pageStack.currentPage === root) {
			Global.pageManager.popPage()
		}
	}

	VeQuickItem {
		id: nameItem
		uid: root.appUid + "/Name"
		// The app was removed.
		onValidChanged: if (!valid) root.leave()
	}
	VeQuickItem { id: enableItem; uid: root.appUid + "/Enable" }
	VeQuickItem { id: componentsItem; uid: root.appUid + "/Components" }
	VeQuickItem { id: organizationItem; uid: root.appUid + "/Organization" }
	VeQuickItem { id: supportItem; uid: root.appUid + "/Support" }
	VeQuickItem { id: removeItem; uid: root.appUid + "/Remove" }
	VeQuickItem { id: customBrandingItem; uid: root.appManagerUid + "/CustomBranding" }

	FileExchangeAction {
		id: updateAction

		actionId: "app-update"
		page: root
		parameters: ({ name: nameItem.value || "" })
		fileAccept: ".gx-app,.zip"
		//% "Update GX App"
		title: qsTrId("settings_gxapp_update_title")
		scanInstruction: qsTrId("settings_gxapps_scan_instruction")
		receivingText: qsTrId("settings_gxapps_receiving")
		validatingText: qsTrId("settings_gxapps_validating")
		//% "Update this GX App"
		confirmText: qsTrId("settings_gxapp_update_confirm_text")
		//% "Update"
		confirmButtonText: qsTrId("settings_gxapp_update_button")
		//% "Update GX App?"
		confirmTitle: qsTrId("settings_gxapp_update_confirm_title")
		//: %1 = the GX App's title
		//% "'%1' will be updated on this GX device."
		confirmDescription: qsTrId("settings_gxapp_update_confirm_description")
		//% "Updating GX App..."
		processingText: qsTrId("settings_gxapp_updating")
		//% "GX App updated"
		completedText: qsTrId("settings_gxapp_updated")
		//% "GX App could not be updated"
		failedTitle: qsTrId("settings_gxapp_update_failed")
	}

	GradientListView {
		model: VisibleItemModel {
			ListSwitch {
				text: CommonWords.enabled
				dataItem.uid: root.appUid + "/Enable"
				preferredVisible: !root.customBrandingInUse
			}

			ListText {
				text: CommonWords.enabled
				//% "In use as Custom Branding"
				secondaryText: qsTrId("settings_gxapp_custom_branding_in_use")
				preferredVisible: root.customBrandingInUse
			}

			ListText {
				//% "Version"
				text: qsTrId("settings_gxapp_version")
				dataItem.uid: root.appUid + "/Version"
			}

			ListText {
				//% "Description"
				text: qsTrId("settings_gxapp_description")
				dataItem.uid: root.appUid + "/Description"
				preferredVisible: !!dataItem.value
			}

			ListText {
				//% "Contact"
				text: qsTrId("settings_gxapp_contact")
				secondaryText: [organizationItem.value, supportItem.value].filter(v => !!v).join(", ")
				preferredVisible: secondaryText.length > 0
			}

			ListText {
				//% "Contains"
				text: qsTrId("settings_gxapp_contains")
				secondaryText: root.componentsText(componentsItem.value || 0)
			}

			ListButton {
				//% "Update"
				text: qsTrId("settings_gxapp_update")
				secondaryText: updateAction.confirmButtonText
				preferredVisible: updateAction.available
				interactive: !!nameItem.value
				onClicked: updateAction.start()
			}

			ListText {
				text: qsTrId("settings_gxapp_update")
				secondaryText: updateAction.unavailableText
				preferredVisible: !updateAction.available
			}

			ListButton {
				text: CommonWords.remove
				secondaryText: CommonWords.remove
				preferredVisible: !root.enabled
				onClicked: Global.dialogLayer.open(removeDialogComponent)
			}
		}
	}

	Component {
		id: removeDialogComponent

		ModalWarningDialog {
			//% "Remove GX App?"
			title: qsTrId("settings_gxapp_remove_title")
			//: %1 = the GX App's title
			//% "'%1' will be removed from this GX device."
			description: qsTrId("settings_gxapp_remove_description").arg(root.title)
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
			acceptText: CommonWords.remove
			onAccepted: {
				removeItem.setValue(1)
				//% "GX App removed"
				Global.showToastNotification(VenusOS.Notification_Info, qsTrId("settings_gxapp_removed"), 3000)
				// Later, once the dialog layer has let this dialog go.
				Qt.callLater(root.leave)
			}
		}
	}
}

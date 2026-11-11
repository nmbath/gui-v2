/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

// The GX Apps that com.victronenergy.appmanager has installed, the Custom Branding in use, and
// adding an app.
Page {
	id: root

	readonly property string appManagerUid: BackendConnection.serviceUidForType("appmanager")
	// Without storage for GX Apps, none of the page can be used, so it only says why.
	readonly property bool storageUnavailable: FileExchange.isStorageReason(installAction.unavailableReason)

	// The Custom Branding options: Standard, and every enabled app that has a Custom Branding.
	function customBrandingOptions() {
		//% "Standard"
		let options = [ { display: qsTrId("settings_gxapps_custom_branding_standard"), value: "" } ]
		for (let i = 0; i < apps.count; ++i) {
			const app = apps.objectAt(i)
			if (app && app.enabled && (app.components & VenusOS.GxApp_Component_CustomBranding) && app.name) {
				options.push({ display: app.title || app.name, value: app.name })
			}
		}
		return options
	}

	FileExchangeAction {
		id: installAction

		actionId: "app-install"
		page: root
		fileAccept: ".gxapp"
		//% "Add GX App"
		title: qsTrId("settings_gxapps_add_title")
		//% "Scan this QR code to send the GX App from your phone."
		scanInstruction: qsTrId("settings_gxapps_scan_instruction")
		//% "Receiving GX App..."
		receivingText: qsTrId("settings_gxapps_receiving")
		//% "Validating GX App..."
		validatingText: qsTrId("settings_gxapps_validating")
		//% "Add this GX App"
		confirmText: qsTrId("settings_gxapps_add_confirm_text")
		//% "Add"
		confirmButtonText: qsTrId("settings_gxapps_add_button")
		//% "Add GX App?"
		confirmTitle: qsTrId("settings_gxapps_add_confirm_title")
		//: %1 = the GX App's title
		//% "'%1' will be added to this GX device."
		confirmDescription: qsTrId("settings_gxapps_add_confirm_description")
		//% "Adding GX App..."
		processingText: qsTrId("settings_gxapps_adding")
		//% "GX App added"
		completedText: qsTrId("settings_gxapps_added")
		//% "GX App could not be added"
		failedTitle: qsTrId("settings_gxapps_add_failed")
	}

	// Every app, to find the enabled ones with a Custom Branding.
	Instantiator {
		id: apps

		model: VeQItemTableModel {
			uids: [ root.appManagerUid + "/GxApps" ]
			flags: VeQItemTableModel.AddChildren | VeQItemTableModel.AddNonLeaves | VeQItemTableModel.DontAddItem
		}
		delegate: QtObject {
			id: app

			required property string uid
			readonly property bool enabled: enableItem.value === 1
			readonly property int components: componentsItem.value || 0
			readonly property string title: titleItem.value || ""
			readonly property string name: nameItem.value || ""
			readonly property VeQuickItem enableItem: VeQuickItem { uid: app.uid + "/Enable" }
			readonly property VeQuickItem componentsItem: VeQuickItem { uid: app.uid + "/Components" }
			readonly property VeQuickItem titleItem: VeQuickItem { uid: app.uid + "/Title" }
			readonly property VeQuickItem nameItem: VeQuickItem { uid: app.uid + "/Name" }
		}
	}

	// Each app's /Title, sorted.
	VeQItemSortTableModel {
		id: appTitles

		model: VeQItemChildModel {
			model: VeQItemSortTableModel {
				model: VeQItemTableModel {
					uids: [ root.appManagerUid + "/GxApps" ]
					flags: VeQItemTableModel.AddChildren | VeQItemTableModel.AddNonLeaves | VeQItemTableModel.DontAddItem
				}
				dynamicSortFilter: true
				filterFlags: VeQItemSortTableModel.FilterOffline
			}
			childId: "Title"
		}
		dynamicSortFilter: true
		filterFlags: VeQItemSortTableModel.FilterInvalid
	}

	EmptyPageItem {
		anchors {
			left: parent.left
			right: parent.right
			leftMargin: Theme.geometry_page_content_horizontalMargin
			rightMargin: Theme.geometry_page_content_horizontalMargin
			verticalCenter: parent.verticalCenter
		}
		visible: root.storageUnavailable
		primaryText: installAction.unavailableText
		//% "GX Apps, and everything kept with them, can't be used until the storage is back."
		secondaryText: qsTrId("settings_gxapps_storage_unavailable")
	}

	GradientListView {
		visible: !root.storageUnavailable
		model: VisibleItemModel {
			ListButton {
				//% "Add a GX App"
				text: qsTrId("settings_gxapps_add")
				secondaryText: installAction.confirmButtonText
				preferredVisible: installAction.available
				onClicked: installAction.start()
			}

			ListText {
				text: qsTrId("settings_gxapps_add")
				secondaryText: installAction.unavailableText
				preferredVisible: !installAction.available
			}

			ListRadioButtonGroup {
				//% "Custom Branding"
				text: qsTrId("settings_gxapps_custom_branding")
				dataItem.uid: root.appManagerUid + "/CustomBranding"
				optionModel: root.customBrandingOptions()
			}

			SettingsListHeader {
				//% "Installed"
				text: qsTrId("settings_gxapps_installed")
				preferredVisible: appRepeater.count > 0
			}

			SettingsColumn {
				width: parent ? parent.width : 0
				preferredVisible: appRepeater.count > 0

				Repeater {
					id: appRepeater

					model: appTitles
					delegate: ListNavigation {
						id: appDelegate

						required property VeQItem item
						readonly property string appUid: item.itemParent().uid

						text: item.value || ""
						secondaryText: enableItem.value === 1 ? CommonWords.enabled : CommonWords.disabled
						onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsGxApp.qml",
								{ "title": text, "appUid": appUid })

						VeQuickItem {
							id: enableItem
							uid: appDelegate.appUid + "/Enable"
						}
					}
				}
			}
		}
	}
}

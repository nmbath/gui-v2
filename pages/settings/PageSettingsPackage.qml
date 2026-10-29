/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

// Mockup: one package from com.victronenergy.packagemanager.
Page {
	id: root

	required property string packageUid
	readonly property string stateUid: BackendConnection.serviceUidForType("platform") + "/Apps/"
			+ packageUid.substring(packageUid.lastIndexOf("/") + 1) + "/State"
	readonly property bool hasService: (componentsItem.value & 4) !== 0

	// Components bit field: 1 = gui, 2 = skin, 4 = service.
	function componentsText(components) {
		let names = []
		//% "GUI extension"
		if (components & 1) names.push(qsTrId("packages_component_gui"))
		//% "Skin"
		if (components & 2) names.push(qsTrId("packages_component_skin"))
		//% "Service"
		if (components & 4) names.push(qsTrId("packages_component_service"))
		return names.join(", ")
	}

	// com.victronenergy.platform /Apps/<name>/State: 0 = not running, 1 = running, 2 = failed.
	function serviceText(state) {
		//% "Running"
		return state === 1 ? qsTrId("packages_service_running")
			//% "Failed"
			: state === 2 ? qsTrId("packages_service_failed")
			//% "Stopped"
			: qsTrId("packages_service_stopped")
	}

	// A package whose skin is selected can't be disabled until another skin is chosen.
	readonly property bool skinInUse: nameItem.value !== undefined && nameItem.value === skinItem.value

	VeQuickItem { id: componentsItem; uid: root.packageUid + "/Components" }
	VeQuickItem { id: nameItem; uid: root.packageUid + "/Name" }
	VeQuickItem {
		id: skinItem
		uid: root.packageUid.substring(0, root.packageUid.lastIndexOf("/Packages/")) + "/Skin"
	}
	VeQuickItem { id: stateItem; uid: root.stateUid }

	GradientListView {
		model: VisibleItemModel {
			ListSwitch {
				id: enableSwitch
				text: CommonWords.enabled
				dataItem.uid: root.packageUid + "/Enable"
				preferredVisible: !(checked && root.skinInUse)
			}

			ListInfoLabel {
				//% "This package's skin is in use, so it can't be disabled. Choose another skin first."
				text: qsTrId("pagesettingspackage_skin_in_use")
				preferredVisible: enableSwitch.checked && root.skinInUse
			}

			ListText {
				//% "Service"
				text: qsTrId("pagesettingspackage_service")
				secondaryText: root.serviceText(stateItem.value)
				preferredVisible: root.hasService && enableSwitch.checked
			}

			SectionHeader {
				//% "Details"
				text: qsTrId("pagesettingspackage_details")
			}

			ListText {
				//% "Description"
				text: qsTrId("pagesettingspackage_description")
				dataItem.uid: root.packageUid + "/Description"
				preferredVisible: dataItem.value
			}

			ListText {
				//% "Contains"
				text: qsTrId("pagesettingspackage_contains")
				secondaryText: root.componentsText(componentsItem.value)
			}

			ListText {
				//% "Version"
				text: qsTrId("pagesettingspackage_version")
				dataItem.uid: root.packageUid + "/Version"
			}

			ListText {
				//% "Organization"
				text: qsTrId("pagesettingspackage_organization")
				dataItem.uid: root.packageUid + "/Organization"
				preferredVisible: dataItem.value
			}

			ListText {
				//% "Support"
				text: qsTrId("pagesettingspackage_support")
				dataItem.uid: root.packageUid + "/Support"
				preferredVisible: dataItem.value
			}

			ListText {
				//% "Location"
				text: qsTrId("pagesettingspackage_location")
				dataItem.uid: root.packageUid + "/Path"
			}

			SectionHeader {
				//% "Maintenance"
				text: qsTrId("pagesettingspackage_maintenance")
			}

			ListButton {
				//% "Update"
				text: qsTrId("pagesettingspackage_update")
				//% "Choose file"
				secondaryText: qsTrId("pagesettingspackage_choose_file")
				// Would start venus-exchange's package-update action with this package's name.
			}

			ListButton {
				//% "Remove"
				text: qsTrId("pagesettingspackage_remove")
				//% "Remove"
				secondaryText: qsTrId("pagesettingspackage_remove_button")
				preferredVisible: !enableSwitch.checked
				onClicked: removeItem.setValue(1)

				VeQuickItem { id: removeItem; uid: root.packageUid + "/Remove" }
			}

			ListInfoLabel {
				//% "Disable the package to remove it."
				text: qsTrId("pagesettingspackage_disable_to_remove")
				preferredVisible: enableSwitch.checked
			}
		}
	}
}

/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

// Mockup: packages from com.victronenergy.packagemanager.
Page {
	id: root

	readonly property string packageManagerUid: BackendConnection.serviceUidForType("packagemanager")

	function statusText(enable, components, state) {
		if (enable !== 1) {
			return CommonWords.disabled
		}
		return (components & 4) ? serviceText(state) : CommonWords.enabled
	}

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

	function skinOptions() {
		//% "Standard"
		let options = [ { display: qsTrId("pagesettingspackages_skin_standard"), value: "" } ]
		for (let i = 0; i < packages.count; ++i) {
			const p = packages.objectAt(i)
			if (p && p.enabled && (p.components & 2)) {
				options.push({ display: p.title, value: p.name })
			}
		}
		return options
	}

	// Every package, to find the enabled ones with a skin.
	Instantiator {
		id: packages

		model: VeQItemTableModel {
			uids: [ root.packageManagerUid + "/Packages" ]
			flags: VeQItemTableModel.AddChildren | VeQItemTableModel.AddNonLeaves | VeQItemTableModel.DontAddItem
		}
		delegate: QtObject {
			id: pkg

			required property VeQItem item
			readonly property bool enabled: enableItem.value === 1
			readonly property int components: componentsItem.value || 0
			readonly property string title: titleItem.value || ""
			readonly property string name: nameItem.value || ""

			readonly property VeQuickItem enableItem: VeQuickItem { uid: pkg.item.uid + "/Enable" }
			readonly property VeQuickItem componentsItem: VeQuickItem { uid: pkg.item.uid + "/Components" }
			readonly property VeQuickItem titleItem: VeQuickItem { uid: pkg.item.uid + "/Title" }
			readonly property VeQuickItem nameItem: VeQuickItem { uid: pkg.item.uid + "/Name" }
		}
	}

	VeQItemSortTableModel {
		id: packageTitles

		model: VeQItemChildModel {
			model: VeQItemSortTableModel {
				model: VeQItemTableModel {
					uids: [ root.packageManagerUid + "/Packages" ]
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

	GradientListView {
		model: VisibleItemModel {
			ListRadioButtonGroup {
				//% "Skin"
				text: qsTrId("pagesettingspackages_skin")
				dataItem.uid: root.packageManagerUid + "/Skin"
				optionModel: root.skinOptions()
				//% "The skins of enabled packages can be chosen."
				caption: qsTrId("pagesettingspackages_skin_caption")
			}

			ListButton {
				//% "Add a package"
				text: qsTrId("pagesettingspackages_add")
				//% "Add"
				secondaryText: qsTrId("pagesettingspackages_add_button")
				// Would start venus-exchange's package-install action.
			}

			SectionHeader {
				//% "Installed"
				text: qsTrId("pagesettingspackages_installed")
				preferredVisible: packageRepeater.count > 0
			}

			SettingsColumn {
				width: parent ? parent.width : 0
				preferredVisible: packageRepeater.count > 0

				Repeater {
					id: packageRepeater
					model: packageTitles
					delegate: ListNavigation {
						id: packageDelegate

						required property VeQItem item
						readonly property string packageUid: item.itemParent().uid

						text: item.value || ""
						secondaryText: root.statusText(enableItem.value, componentsItem.value, stateItem.value)
						onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsPackage.qml",
								{ "title": text, "packageUid": packageUid })

						VeQuickItem { id: enableItem; uid: packageDelegate.packageUid + "/Enable" }
						VeQuickItem { id: componentsItem; uid: packageDelegate.packageUid + "/Components" }
						VeQuickItem {
							id: stateItem
							uid: BackendConnection.serviceUidForType("platform") + "/Apps/" + packageDelegate.item.itemParent().id + "/State"
						}
					}
				}
			}

			ListInfoLabel {
				//% "No packages installed"
				text: qsTrId("pagesettingspackages_none")
				preferredVisible: packageRepeater.count === 0
			}
		}
	}
}

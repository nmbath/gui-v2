/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

// The installer's company name, address, telephone and support email, from localsettings
// /Settings/InstallerInformation, and the logo, which only com.victronenergy.appmanager publishes.
// They are set up from the GX Applications page; removing them needs the app manager.
Page {
	id: root

	readonly property string settingsUid: Services.settings.serviceUid + "/Settings/InstallerInformation"
	readonly property string installerInformationUid: BackendConnection.serviceUidForType("appmanager") + "/InstallerInformation"
	readonly property bool isSet: !!companyNameItem.value || !!companyAddressItem.value || !!telephoneItem.value
			|| !!supportEmailItem.value

	function leave() {
		if (Global.pageManager.pageStack.currentPage === root) {
			Global.pageManager.popPage()
		}
	}

	onIsSetChanged: if (!isSet) Qt.callLater(root.leave)

	component InformationText : ListSetting {
		id: informationText

		property string secondaryText

		preferredVisible: !!secondaryText
		contentItem: ListItemLabelLayout {
			primaryText: informationText.text
			primaryLabel.font: informationText.font
			secondaryText: informationText.secondaryText
			secondaryLabel.textFormat: Text.PlainText
		}
	}

	VeQuickItem { id: companyNameItem; uid: root.settingsUid + "/CompanyName" }
	VeQuickItem { id: companyAddressItem; uid: root.settingsUid + "/CompanyAddress" }
	VeQuickItem { id: telephoneItem; uid: root.settingsUid + "/Telephone" }
	VeQuickItem { id: supportEmailItem; uid: root.settingsUid + "/SupportEmail" }
	VeQuickItem { id: logoItem; uid: root.installerInformationUid + "/Logo" }
	VeQuickItem { id: removeItem; uid: root.installerInformationUid + "/Remove" }

	GradientListView {
		model: VisibleItemModel {
			ListSetting {
				id: logoRow

				//% "Logo"
				text: qsTrId("settings_installer_information_logo")
				preferredVisible: !!logoItem.value
				contentItem: RowLayout {
					Label {
						text: logoRow.text
						font: logoRow.font
						color: Theme.color_font_primary
						Layout.fillWidth: true
					}
					Image {
						source: logoItem.value || ""
						fillMode: Image.PreserveAspectFit
						Layout.preferredHeight: Theme.geometry_installerInformation_logo_height
						Layout.preferredWidth: Theme.geometry_installerInformation_logo_width
					}
				}
			}

			InformationText {
				//% "Company name"
				text: qsTrId("settings_installer_information_company_name")
				secondaryText: companyNameItem.value || ""
			}

			InformationText {
				//% "Company address"
				text: qsTrId("settings_installer_information_company_address")
				secondaryText: companyAddressItem.value || ""
			}

			InformationText {
				//% "Telephone"
				text: qsTrId("settings_installer_information_telephone")
				secondaryText: telephoneItem.value || ""
			}

			InformationText {
				//% "Support email"
				text: qsTrId("settings_installer_information_support_email")
				secondaryText: supportEmailItem.value || ""
			}

			ListButton {
				//% "Remove installer information"
				text: qsTrId("settings_installer_information_remove")
				secondaryText: CommonWords.remove
				// Only the app manager can remove the logo it keeps on disk.
				preferredVisible: removeItem.valid
				onClicked: Global.dialogLayer.open(removeDialogComponent)
			}
		}
	}

	Component {
		id: removeDialogComponent

		ModalWarningDialog {
			//% "Remove installer information?"
			title: qsTrId("settings_installer_information_remove_title")
			//% "The company details and logo will be removed from this GX device."
			description: qsTrId("settings_installer_information_remove_description")
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
			acceptText: CommonWords.remove
			onAccepted: {
				removeItem.setValue(1)
				//% "Installer information removed"
				Global.showToastNotification(VenusOS.Notification_Info, qsTrId("settings_installer_information_removed"), 3000)
			}
		}
	}
}

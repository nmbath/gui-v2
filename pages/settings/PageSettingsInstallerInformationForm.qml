/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

// In a browser, the installer information is entered in the GUI itself, and sent as
// installer-information.json, as the phone's upload page does on the GX display.
Page {
	id: root

	required property InstallerInformationAction fileExchangeAction
	property string logo
	property string logoFilename

	readonly property bool canSend: companyName.secondaryText.trim().length > 0
			&& (telephone.secondaryText.trim().length > 0 || supportEmail.secondaryText.trim().length > 0)

	function send() {
		let values = { companyName: companyName.secondaryText.trim() }
		for (const [key, field] of [["companyAddress", companyAddress], ["telephone", telephone], ["supportEmail", supportEmail]]) {
			if (field.secondaryText.trim().length > 0) {
				values[key] = field.secondaryText.trim()
			}
		}
		if (root.logo) {
			values.logo = root.logo
		}
		BackendConnection.setFileExchangeUploadData("installer-information.json", JSON.stringify(values))
		root.fileExchangeAction.send()
	}

	Connections {
		target: BackendConnection
		function onFileExchangeImageChosen(filename, dataUri) {
			if (dataUri.startsWith("data:image/png;base64,")) {
				root.logo = dataUri
				root.logoFilename = filename
			} else {
				//% "The logo must be a PNG of at most 64 KiB"
				Global.showToastNotification(VenusOS.Notification_Warning, qsTrId("settings_installer_information_logo_invalid"), 5000)
			}
		}
	}

	GradientListView {
		model: VisibleItemModel {
			ListTextField {
				id: companyName
				text: qsTrId("settings_installer_information_company_name")
				//% "Required"
				placeholderText: qsTrId("settings_installer_information_required")
				maximumLength: 64
				writeAccessLevel: VenusOS.User_AccessType_User
			}

			ListTextField {
				id: companyAddress
				text: qsTrId("settings_installer_information_company_address")
				//% "Optional"
				placeholderText: qsTrId("settings_installer_information_optional")
				maximumLength: 256
				writeAccessLevel: VenusOS.User_AccessType_User
			}

			ListTextField {
				id: telephone
				text: qsTrId("settings_installer_information_telephone")
				placeholderText: "+44 1632 960123"
				maximumLength: 32
				inputMethodHints: Qt.ImhDialableCharactersOnly
				writeAccessLevel: VenusOS.User_AccessType_User
			}

			ListTextField {
				id: supportEmail
				text: qsTrId("settings_installer_information_support_email")
				placeholderText: "service@example.com"
				maximumLength: 128
				inputMethodHints: Qt.ImhEmailCharactersOnly
				writeAccessLevel: VenusOS.User_AccessType_User
			}

			PrimaryListLabel {
				//% "A company name is required, and a telephone number or a support email."
				text: qsTrId("settings_installer_information_form_hint")
				font.pixelSize: Theme.font_size_caption
				color: Theme.color_font_secondary
			}

			ListButton {
				text: root.logoFilename
						//: %1 = the logo's file name
						//% "Logo: %1"
						? qsTrId("settings_installer_information_logo_file").arg(root.logoFilename)
						: qsTrId("settings_installer_information_logo")
				//% "Choose"
				secondaryText: qsTrId("settings_installer_information_choose")
				writeAccessLevel: VenusOS.User_AccessType_User
				onClicked: BackendConnection.chooseFileExchangeImage(".png,image/png", root.fileExchangeAction.maximumLogoSize)
			}

			ListButton {
				//% "Send to this GX device"
				text: qsTrId("settings_installer_information_send_text")
				//% "Send"
				secondaryText: qsTrId("settings_installer_information_send")
				writeAccessLevel: VenusOS.User_AccessType_User
				preferredVisible: root.fileExchangeAction.available
				interactive: root.canSend
				onClicked: root.send()
			}

			ListText {
				text: qsTrId("settings_installer_information_send_text")
				secondaryText: root.fileExchangeAction.unavailableText
				preferredVisible: !root.fileExchangeAction.available
			}
		}
	}
}

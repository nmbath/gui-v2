/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

// Sets up the installer information through com.victronenergy.appmanager's file exchange.
FileExchangeAction {
	// The most the app manager takes, in bytes.
	readonly property int maximumLogoSize: 65536

	actionId: "component-install"
	parameters: ({ component: "installerInformation" })
	//% "Installer information"
	title: qsTrId("installerinformationaction_title")
	//% "Scan this QR code to enter your company details and logo on your phone."
	scanInstruction: qsTrId("installerinformationaction_scan_instruction")
	//% "Receiving details..."
	receivingText: qsTrId("installerinformationaction_receiving")
	//% "Checking details..."
	validatingText: qsTrId("installerinformationaction_validating")
	//% "Save on this GX device"
	confirmText: qsTrId("installerinformationaction_confirm_text")
	//% "Save"
	confirmButtonText: qsTrId("installerinformationaction_save")
	//% "Saving..."
	processingText: qsTrId("installerinformationaction_saving")
	//% "Installer information saved"
	completedText: qsTrId("installerinformationaction_saved")
	//% "Installer information could not be saved"
	failedTitle: qsTrId("installerinformationaction_failed")
}

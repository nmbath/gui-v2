/*
** Copyright (C) 2021 Victron Energy B.V.
*/

import QtQuick
import QtQuick.Controls.impl as CP
import Victron.VenusOS

ModalWarningDialog {
	id: root

	dialogDoneOptions: ModalDialog.DialogDoneOptions.OkAndCancel

	//% "Disable Autostart?"
	title: qsTrId("controlcard_generator_disableautostartdialog_title")

	//% "Consequences description..."
	description: qsTrId("controlcard_generator_disableautostartdialog_consequences")
}
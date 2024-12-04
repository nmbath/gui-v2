/*
** Copyright (C) 2024 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

DeviceListDelegate {
	id: root

	text: Global.digitalInputs.inputTypeToText(type.value)
	secondaryText: Global.digitalInputs.inputStateToText(state.value)

	onClicked: {
		Global.pageManager.pushPage("/pages/settings/devicelist/PageDigitalInput.qml",
				{ "title": text, bindPrefix : root.device.serviceUid })
	}

	VeQuickItem {
		id: state
		uid: root.device.serviceUid + "/State"
	}

	VeQuickItem {
		id: type
		uid: root.device.serviceUid + "/Type"
	}
}

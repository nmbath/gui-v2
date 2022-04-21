/*
** Copyright (C) 2022 Victron Energy B.V.
*/

import QtQuick
import QtQuick.Controls.impl as CP
import Victron.VenusOS
import Victron.Velib

SettingsListItem {
	id: root

	property alias checked: switchItem.checked
	property string source
	readonly property alias veItem: veItem

	signal clicked()

	function _setChecked(c) {
		if (root.source.length > 0) {
			veItem.setValue(c ? 1 : 0)  // set dbus value instead of breaking Switch "checked" binding
		} else {
			switchItem.checked = c
		}
		clicked()
	}

	down: mouseArea.containsPress

	content.children: [
		Switch {
			id: switchItem
			checked: veItem.value === 1
			onClicked: root._setChecked(!checked)
		}
	]

	MouseArea {
		id: mouseArea

		anchors.fill: parent
		onClicked: root._setChecked(!switchItem.checked)
	}

	VeQuickItem {
		id: veItem
		uid: source.length > 0 && dbusConnected ? "dbus/" + source : ""
	}
}
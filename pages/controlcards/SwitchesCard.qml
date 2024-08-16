/*
** Copyright (C) 2023 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

ControlCard {
	id: root

	property ManualRelayModel model

	icon.source: "qrc:/images/switches.svg"
	//% "Switches"
	title.text: qsTrId("controlcard_switches")

	ListView {
		id: switchesView

		anchors {
			top: parent.top
			topMargin: Theme.geometry_controlCard_mediumItem_height
			left: parent.left
			right: parent.right
			bottom: parent.bottom
		}
		model: root.model
		delegate: SwitchControlValue {
			//: %1 = Relay number
			//% "Relay %1"
			label.text: qsTrId("controlcard_switches_relay_name").arg(model.relayNumber + 1)
			button.checked: model.relayState === VenusOS.Relays_State_Active
			onClicked: {
				const newState = model.relayState === VenusOS.Relays_State_Active
						? VenusOS.Relays_State_Inactive
						: VenusOS.Relays_State_Active
				root.model.setRelayState(model.relayNumber, newState)
			}
		}
	}
}

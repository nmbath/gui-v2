/*
** Copyright (C) 2021 Victron Energy B.V.
*/

import QtQuick
import Victron.Velib
import "../components/Utils.js" as Utils

Item {
	property real stateOfCharge: veBatterySoC.value || 0
	property real power: veBatteryPower.value || 0
	property real current: veBatteryCurrent.value || 0
	property real temperature: veBatteryTemp.value || 0
	property real timeToGo: veTimeToGo.value || 0    // in seconds
	property string icon: Utils.batteryIcon(root)
	readonly property bool idle: current === 0 || power === 0

	VeQuickItem {
		id: veBatterySoC
		uid: veSystem.childUId("/Dc/Battery/Soc")
	}

	VeQuickItem {
		id: veBatteryPower
		uid: veSystem.childUId("/Dc/Battery/Power")
	}

	VeQuickItem {
		id: veBatteryCurrent
		uid: veSystem.childUId("/Dc/Battery/Current")
	}

	VeQuickItem {
		id: veBatteryTemp
		uid: veSystem.childUId("/Dc/Battery/Temperature")
	}

	VeQuickItem {
		id: veTimeToGo
		uid: veSystem.childUId("/Dc/Battery/TimeToGo")
	}
}

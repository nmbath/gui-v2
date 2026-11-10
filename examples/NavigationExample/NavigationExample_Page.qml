/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.GuiPlugins

// A navigation page. It must not import Victron.VenusOS. The list items draw
// the text, so the page does not read the GUI's colors or fonts.
PluginPage {
	id: root

	//% "Example"
	title: qsTrId("navigationexample_title")

	PluginDataItem {
		id: batteryPower

		serviceType: "system"
		path: "/Dc/Battery/Power"
	}

	PluginGradientListView {
		PluginSettingsListHeader {
			text: PluginWords.battery
		}

		PluginListQuantity {
			//% "State of charge"
			text: qsTrId("navigationexample_state_of_charge")
			unit: PluginUnit.Percentage
			dataItem.serviceType: "system"
			dataItem.path: "/Dc/Battery/Soc"
		}

		PluginListQuantity {
			text: PluginWords.voltage
			unit: PluginUnit.Volt_DC
			decimals: 2
			dataItem.serviceType: "system"
			dataItem.path: "/Dc/Battery/Voltage"
		}

		PluginListQuantity {
			text: PluginWords.power_watts
			unit: PluginUnit.Watt
			dataItem.serviceType: "system"
			dataItem.path: "/Dc/Battery/Power"
		}

		PluginListText {
			text: PluginWords.state
			secondaryText: {
				if (!batteryPower.valid) {
					//% "No battery"
					return qsTrId("navigationexample_no_battery")
				}
				const power = Number(batteryPower.value)
				if (isNaN(power)) {
					//% "No battery"
					return qsTrId("navigationexample_no_battery")
				}
				if (power > 0) {
					//% "Charging"
					return qsTrId("navigationexample_charging")
				}
				if (power < 0) {
					//% "Discharging"
					return qsTrId("navigationexample_discharging")
				}
				//% "Idle"
				return qsTrId("navigationexample_idle")
			}
		}

		PluginListQuantity {
			//% "Solar"
			text: qsTrId("navigationexample_solar")
			//% "DC PV power"
			caption: qsTrId("navigationexample_dc_pv")
			unit: PluginUnit.Watt
			dataItem.serviceType: "system"
			dataItem.path: "/Dc/Pv/Power"
		}

		PluginListQuantity {
			//% "DC system"
			text: qsTrId("navigationexample_dc_system")
			unit: PluginUnit.Watt
			dataItem.serviceType: "system"
			dataItem.path: "/Dc/System/Power"
		}

		PluginListSwitch {
			//% "Pump"
			text: qsTrId("navigationexample_pump")
			//% "Local example. It does not control a pump."
			caption: qsTrId("navigationexample_pump_caption")
			checkable: true
			writeAccessLevel: PluginAccessLevel.User
		}
	}
}

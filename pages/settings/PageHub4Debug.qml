/*
** Copyright (C) 2023 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS
import Victron.Veutil

Page {
	id: root

	readonly property string batteryService: Global.batteries.firstObject ? Global.batteries.firstObject.serviceUid : null

	//% "Grid Setpoint"
	title: qsTrId("settings_ess_debug_grid_setpoint")

	GradientListView {
		model: ObjectModel {
			ListSpinBox {
				id: gridSetpoint

				text: root.title
				dataSource: Global.systemSettings.serviceUid + "/Settings/CGwacs/AcPowerSetPoint"
				suffix: "W"
				from: -15000
				to: 15000
				stepSize: 10

				bottomContent.children: [
					SettingsSlider {
						id: gridSetpointSlider

						width: parent.width
						dataSource: Global.systemSettings.serviceUid + "/Settings/CGwacs/AcPowerSetPoint"
						from: -15000
						to: 15000
						stepSize: 50
					}
				]
			}

			ListTextItem {
				//% "AC-In setpoint"
				text: qsTrId("settings_ess_debug_ac_in_setpoint")
				dataSource: Global.system.veBus.serviceUid ? Global.system.veBus.serviceUid + "/Hub4/L1/AcPowerSetpoint" : ""
			}

			ListTextGroup {
				text: CommonWords.battery
				textModel: [
					//: Battery current, in amps
					//% "Current: %1"
					qsTrId("settings_ess_debug_battery_current").arg(batteryCurrent.value || "--"),
					//: Battery voltage, in volts
					//% "Voltage: %1"
					qsTrId("settings_ess_debug_battery_voltage").arg(batteryVoltage.value || "--"),
				]

				DataPoint {
					id: batteryCurrent
					source: root.batteryService + "/Dc/0/Current"
				}

				DataPoint {
					id: batteryVoltage
					source: root.batteryService + "/Dc/0/Voltage"
				}
			}

			ListTextGroup {
				//% "Limits (I)"
				text: qsTrId("settings_ess_debug_limits_i")
				textModel: [
					//% "Charge: %1"
					qsTrId("settings_ess_debug_battery_charge").arg(batteryChargeCurrent.value || "--"),
					//% "Discharge: %1"
					qsTrId("settings_ess_debug_battery_discharge").arg(batteryDischargeCurrent.value || "--"),
				]

				DataPoint {
					id: batteryChargeCurrent
					source: root.batteryService + "/Info/MaxChargeCurrent"
				}

				DataPoint {
					id: batteryDischargeCurrent
					source: root.batteryService + "/Info/MaxDischargeCurrent"
				}
			}

			ListTextGroup {
				//% "Limits (P)"
				text: qsTrId("settings_ess_debug_limits_p")
				textModel: [
					//% "Charge: %1"
					qsTrId("settings_ess_debug_battery_charge").arg(batteryChargePower.value || "--"),
					//% "Discharge: %1"
					qsTrId("settings_ess_debug_battery_discharge").arg(batteryDischargePower.value || "--"),
				]

				DataPoint {
					id: batteryChargePower
					source: Global.systemSettings.serviceUid + "/Settings/CGwacs/MaxChargePower"
				}

				DataPoint {
					id: batteryDischargePower
					source: Global.systemSettings.serviceUid + "/Settings/CGwacs/MaxDischargePower"
				}
			}
		}
	}
}

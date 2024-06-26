/*
** Copyright (C) 2023 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

Page {
	id: root

	property string bindPrefix

	readonly property bool showStarterVoltage: hasStarterVoltage.isValid && hasStarterVoltage.value
	readonly property bool showTemperature: hasTemperature.isValid && hasTemperature.value

	VeQuickItem {
		id: hasStarterVoltage
		uid: root.bindPrefix + "/Settings/HasStarterVoltage"
	}

	VeQuickItem {
		id: hasTemperature
		uid: root.bindPrefix + "/Settings/HasTemperature"
	}

	GradientListView {
		model: ObjectModel {
			ListQuantityItem {
				text: CommonWords.minimum_voltage
				dataItem.uid: root.bindPrefix + "/History/MinimumVoltage"
				allowed: defaultAllowed && dataItem.isValid
				unit: VenusOS.Units_Volt_DC
			}

			ListQuantityItem {
				text: CommonWords.maximum_voltage
				dataItem.uid: root.bindPrefix + "/History/MaximumVoltage"
				allowed: defaultAllowed && dataItem.isValid
				unit: VenusOS.Units_Volt_DC
			}

			ListTextItem {
				text: CommonWords.low_voltage_alarms
				dataItem.uid: root.bindPrefix + "/History/LowVoltageAlarms"
				allowed: defaultAllowed && dataItem.isValid
			}

			ListTextItem {
				text: CommonWords.high_voltage_alarms
				dataItem.uid: root.bindPrefix + "/History/HighVoltageAlarms"
				allowed: defaultAllowed && dataItem.isValid
			}

			ListTextItem {
				//% "Low aux voltage alarms"
				text: qsTrId("dcmeter_history_low_aux_voltage_alarms")
				dataItem.uid: visible ? root.bindPrefix + "/History/LowStarterVoltageAlarms" : ""
				allowed: defaultAllowed && root.showStarterVoltage
			}

			ListTextItem {
				//% "High aux voltage alarms"
				text: qsTrId("dcmeter_history_high_aux_voltage_alarms")
				dataItem.uid: visible ? root.bindPrefix + "/History/HighStarterVoltageAlarms" : ""
				allowed: defaultAllowed && root.showStarterVoltage
			}

			ListQuantityItem {
				//% "Minimum aux voltage"
				text: qsTrId("dcmeter_history_minimum_aux_voltage")
				dataItem.uid: visible ? root.bindPrefix + "/History/MinimumStarterVoltage" : ""
				allowed: defaultAllowed && root.showStarterVoltage
				unit: VenusOS.Units_Volt_DC
			}

			ListQuantityItem {
				//% "Maximum aux voltage"
				text: qsTrId("dcmeter_history_maximum_aux_voltage")
				dataItem.uid: visible ? root.bindPrefix + "/History/MaximumStarterVoltage" : ""
				allowed: defaultAllowed && root.showStarterVoltage
				unit: VenusOS.Units_Volt_DC
			}

			ListTemperatureItem {
				text: CommonWords.minimum_temperature
				allowed: defaultAllowed && showTemperature
				dataItem.uid: root.bindPrefix + "/History/MinimumTemperature"
			}

			ListTemperatureItem {
				text: CommonWords.maximum_temperature
				allowed: defaultAllowed && showTemperature
				dataItem.uid: root.bindPrefix + "/History/MaximumTemperature"
			}

			ListQuantityItem {
				//% "Produced energy"
				text: qsTrId("dcmeter_history_produced_energy")
				dataItem.uid: root.bindPrefix + "/History/EnergyOut"
				allowed: defaultAllowed && dataItem.isValid
				unit: VenusOS.Units_Energy_KiloWattHour
			}

			ListQuantityItem {
				//% "Consumed energy"
				text: qsTrId("dcmeter_history_consumed_energy")
				dataItem.uid: root.bindPrefix + "/History/EnergyIn"
				allowed: defaultAllowed && dataItem.isValid
				unit: VenusOS.Units_Energy_KiloWattHour
			}

			ListResetHistoryLabel {
				visible: !clearHistory.visible
			}

			ListClearHistoryButton {
				id: clearHistory
				bindPrefix: root.bindPrefix
			}
		}
	}
}

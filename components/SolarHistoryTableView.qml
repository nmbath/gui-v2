/*
** Copyright (C) 2023 Victron Energy B.V.
*/

import QtQuick
import Victron.VenusOS
import "/components/Utils.js" as Utils

Column {
	id: root

	property var solarCharger
	property var dayRange: [0, 1]   // exclusive range: [first day, last day + 1]

	property bool smallTextMode
	property bool summaryOnly
	property real minimumHeight: NaN // TODO, for single-tracker mode, stretch the spacer

	width: parent ? parent.width : 0
	bottomPadding: solarDetailBox.visible ? Theme.geometry.solarDetailBox.verticalMargin : 0

	function _trackerHistoryTotal(role, trackerIndex) {
		let totalValue = NaN
		for (let day = dayRange[0]; day < dayRange[1]; ++day) {
			const history = root.solarCharger.dailyHistory(day, trackerIndex)
			if (history) {
				const value = history[role]
				if (!isNaN(value)) {
					totalValue = isNaN(totalValue) ? value : totalValue + value
				}
			}
		}
		return totalValue
	}

	function _trackerHistoryMin(role, trackerIndex) {
		let minValue = NaN
		for (let day = dayRange[0]; day < dayRange[1]; ++day) {
			const history = root.solarCharger.dailyHistory(day, trackerIndex)
			if (history) {
				const value = history[role]
				if (!isNaN(value)) {
					minValue = isNaN(minValue) ? value : Math.min(minValue, value)
				}
			}
		}
		return minValue
	}

	function _trackerHistoryMax(role, trackerIndex) {
		let maxValue = NaN
		for (let day = dayRange[0]; day < dayRange[1]; ++day) {
			const history = root.solarCharger.dailyHistory(day, trackerIndex)
			if (history) {
				const value = history[role]
				if (!isNaN(value)) {
					maxValue = isNaN(maxValue) ? value : Math.max(maxValue, value)
				}
			}
		}
		return maxValue
	}

	QuantityTableSummary {
		id: tableSummary

		// Omit right margin to give the table a little more space.
		x: Theme.geometry.listItem.content.horizontalMargin
		width: parent.width - Theme.geometry.listItem.content.horizontalMargin
		smallTextMode: root.smallTextMode

		model: [
			{
				title: "",
				text: CommonWords.total,
				unit: -1,
			},
			{
				title: CommonWords.yield_kwh,
				value: root._trackerHistoryTotal("yieldKwh"),
				unit: VenusOS.Units_Energy_KiloWattHour
			},
			{
				//% "Max Voltage"
				title: qsTrId("charger_history_max_voltage"),
				value: root._trackerHistoryMax("maxPvVoltage"),
				unit: VenusOS.Units_Volt
			},
			{
				//% "Max Power"
				title: qsTrId("charger_history_max_power"),
				value: root._trackerHistoryMax("maxPower"),
				unit: VenusOS.Units_Watt
			},
		]
	}

	QuantityTable {
		id: trackerTable

		width: parent.width
		bottomPadding: Theme.geometry.quantityTable.bottomMargin
		visible: !root.summaryOnly && root.solarCharger.trackers.count > 1
		headerVisible: false

		rowCount: root.solarCharger.trackers.count
		units: [
			// No 'title' property is specified, since these are same as summary headers.
			{ unit: -1 },
			{ unit: VenusOS.Units_Energy_KiloWattHour },
			{ unit: VenusOS.Units_Volt },
			{ unit: VenusOS.Units_Watt },
		]
		valueForModelIndex: function(trackerIndex, column) {
			const tracker = root.solarCharger.trackers.get(trackerIndex).solarTracker
			if (column === 0) {
				return tracker.name
			} else if (column === 1) {
				return root._trackerHistoryTotal("yieldKwh", trackerIndex)
			} else if (column === 2) {
				return root._trackerHistoryMax("maxPvVoltage", trackerIndex)
			} else if (column === 3) {
				return root._trackerHistoryMax("maxPower", trackerIndex)
			}
		}
	}

	Item {
		width: 1
		height: isNaN(root.minimumHeight) ? 0
			: root.minimumHeight - tableSummary.height - trackerTable.height - solarDetailBox.height
	}

	SolarDetailBox {
		id: solarDetailBox

		x: Theme.geometry.solarDetailBox.horizontalMargin
		width: parent.width - (2 * x)
		visible: !root.summaryOnly
		minBatteryVoltage: root._trackerHistoryMin("minBatteryVoltage")
		maxBatteryVoltage: root._trackerHistoryMax("maxBatteryVoltage")
		maxBatteryCurrent: root._trackerHistoryMax("maxBatteryCurrent")
		timeInBulk: root._trackerHistoryTotal("timeInBulk")
		timeInAbsorption: root._trackerHistoryTotal("timeInAbsorption")
		timeInFloat: root._trackerHistoryTotal("timeInFloat")
		smallTextMode: root.smallTextMode
	}
}
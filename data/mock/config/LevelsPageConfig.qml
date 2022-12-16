/*
** Copyright (C) 2022 Victron Energy B.V.
*/

import QtQuick
import Victron.VenusOS

QtObject {
	id: root

	property var configs: Global.pageManager.levelsTabIndex === 0
			? tankConfigs
			: environmentConfigs

	property var tankConfigs: [
		{
			name: "Check Fuel colors",
			tanks: [
				{ type: VenusOS.Tank_Type_Fuel, level: 100, capacity: 1.1 },
				{ type: VenusOS.Tank_Type_Fuel, level: 75, capacity: 1 },
				{ type: VenusOS.Tank_Type_Fuel, level: 20, capacity: 1 },
				{ type: VenusOS.Tank_Type_Fuel, level: 10, capacity: 1 },
				{ type: VenusOS.Tank_Type_Fuel, level: 0, capacity: 1 },
			]
		},
		{
			name: "Check BlackWater colors (different from Fuel level colors)",
			tanks: [
				{ type: VenusOS.Tank_Type_BlackWater, level: 100, capacity: 1 },
				{ type: VenusOS.Tank_Type_BlackWater, level: 90, capacity: 1 },
				{ type: VenusOS.Tank_Type_BlackWater, level: 85, capacity: 1 },
				{ type: VenusOS.Tank_Type_BlackWater, level: 75, capacity: 1 },
				{ type: VenusOS.Tank_Type_BlackWater, level: 0, capacity: 1 },
			]
		},
		{
			name: "1 tank",
			tanks: [
				{ type: VenusOS.Tank_Type_Fuel, level: 46.34, capacity: 1 },
			],
		},
		{
			name: "2 tanks",
			tanks: [
				{ type: VenusOS.Tank_Type_Fuel, level: 46.34, capacity: 1 },
				{ type: VenusOS.Tank_Type_FreshWater, level: 50, capacity: 2 },
			],
		},
		{
			name: "3 tanks (two of same type)",
			tanks: [
				{ type: VenusOS.Tank_Type_Fuel, level: 16.34, capacity: 1 },
				{ type: VenusOS.Tank_Type_Fuel, level: 75.334, capacity: 1 },
				{ type: VenusOS.Tank_Type_FreshWater, level: 10, capacity: 2 },
			]
		},
		{
			name: "4 tanks (two of same type)",
			tanks: [
				{ type: VenusOS.Tank_Type_Fuel, level: 46.34, capacity: 1 },
				{ type: VenusOS.Tank_Type_Fuel, level: 75.334, capacity: 1 },
				{ type: VenusOS.Tank_Type_FreshWater, level: 10, capacity: 2 },
				{ type: VenusOS.Tank_Type_BlackWater, level: 25, capacity: .2 },
			]
		},
		{
			name: "5 tanks (two of same type)",
			tanks: [
				{ type: VenusOS.Tank_Type_Fuel, level: 46.34, capacity: 1 },
				{ type: VenusOS.Tank_Type_Fuel, level: 75.334, capacity: 1 },
				{ type: VenusOS.Tank_Type_FreshWater, level: 10, capacity: 2 },
				{ type: VenusOS.Tank_Type_WasteWater, level: 75, capacity: 1 },
				{ type: VenusOS.Tank_Type_BlackWater, level: 25, capacity: .2 },
			]
		},
		{
			name: "6 tanks (merge 2 Fuel tanks)",
			tanks: [
				{ type: VenusOS.Tank_Type_Fuel, level: 46.34, capacity: 1 },
				{ type: VenusOS.Tank_Type_Fuel, level: 75.334, capacity: 1 },
				{ type: VenusOS.Tank_Type_FreshWater, level: 10, capacity: 2 },
				{ type: VenusOS.Tank_Type_WasteWater, level: 75, capacity: 1 },
				{ type: VenusOS.Tank_Type_Oil, level: 80.2, capacity: .1 },
				{ type: VenusOS.Tank_Type_BlackWater, level: 25, capacity: .2 },
			]
		},
		{
			name: "7 tanks (merge 2 Freshwater tanks)",
			tanks: [
				{ type: VenusOS.Tank_Type_Fuel, level: 75.334, capacity: 1 },
				{ type: VenusOS.Tank_Type_FreshWater, level: 10, capacity: 2 },
				{ type: VenusOS.Tank_Type_FreshWater, level: 50, capacity: 2 },
				{ type: VenusOS.Tank_Type_Fuel, level: 75.334, capacity: 1 },
				{ type: VenusOS.Tank_Type_LiveWell, level: 20, capacity: 1 },
				{ type: VenusOS.Tank_Type_Oil, level: 80.2, capacity: .1 },
				{ type: VenusOS.Tank_Type_BlackWater, level: 25, capacity: .2 },
			]
		},
		{
			name: "8 tanks (merge 3 BlackWater tanks)",
			tanks: [
				{ type: VenusOS.Tank_Type_Fuel, level: 75.334, capacity: 1 },
				{ type: VenusOS.Tank_Type_FreshWater, level: 10, capacity: 2 },
				{ type: VenusOS.Tank_Type_FreshWater, level: 50, capacity: 2 },
				{ type: VenusOS.Tank_Type_Fuel, level: 75.334, capacity: 1 },
				{ type: VenusOS.Tank_Type_LiveWell, level: 20, capacity: 1 },
				{ type: VenusOS.Tank_Type_Oil, level: 80.2, capacity: .1 },
				{ type: VenusOS.Tank_Type_BlackWater, level: 25, capacity: .2 },
				{ type: VenusOS.Tank_Type_BlackWater, level: 50, capacity: .2 },
				{ type: VenusOS.Tank_Type_BlackWater, level: 75, capacity: .2 },
			]
		},
		{
			name: "10 tanks (merge 3 Fuel tanks and 2 WasteWater tanks)",
			tanks: [
				{ type: VenusOS.Tank_Type_Fuel, level: 46.34, capacity: 1 },
				{ type: VenusOS.Tank_Type_Fuel, level: 75.334, capacity: 1 },
				{ type: VenusOS.Tank_Type_Fuel, level: 75.334, capacity: 1 },
				{ type: VenusOS.Tank_Type_FreshWater, level: 10, capacity: 2 },
				{ type: VenusOS.Tank_Type_WasteWater, level: 75.334, capacity: 1 },
				{ type: VenusOS.Tank_Type_WasteWater, level: 75.334, capacity: 1 },
				{ type: VenusOS.Tank_Type_LiveWell, level: 20, capacity: 1 },
				{ type: VenusOS.Tank_Type_Oil, level: 80.2, capacity: .1 },
				{ type: VenusOS.Tank_Type_BlackWater, level: 25, capacity: .2 },
				{ type: VenusOS.Tank_Type_Gasoline, level: 75, capacity: .2 },
			]
		},

	]

	property var environmentConfigs: [
		{
			name: "Double gauge",
			inputs: [ { customName: "Refrigerator", temperature_celsius: 4.4223, humidity: 32.6075 } ]
		},
		{
			name: "Double gauge x 2",
			inputs: [
				{ customName: "Refrigerator", temperature_celsius: 4.4, humidity: 32.6075 },
				{ customName: "Freezer", temperature_celsius: -18.2, humidity: 28.921 },
			]
		},
		{
			name: "Double gauge x 3",
			inputs: [
				{ customName: "Refrigerator", temperature_celsius: -30, humidity: 0 },
				{ customName: "Freezer", temperature_celsius: 0, humidity: 50 },
				{ customName: "Sensor", temperature_celsius: 50, humidity: 100 }
			]
		},
		{
			name: "Double gauge x 4",
			inputs: [
				{ customName: "Refrigerator", temperature_celsius: 4.4, humidity: 32.6075 },
				{ customName: "Freezer", temperature_celsius: -18.2, humidity: 28.921 },
				{ customName: "Sensor A", temperature_celsius: 48.4122, humidity: 5.2 },
				{ customName: "Sensor B", temperature_celsius: 68.2, humidity: 7.3 },
			]
		},
		{
			name: "Mix single/double gauge layouts",
			inputs: [
				{ customName: "Refrigerator", temperature_celsius: 4.4, humidity: 32.6075 },
				{ customName: "Freezer", temperature_celsius: -18.2, humidity: 28.921 },
				{ customName: "Sensor A", temperature_celsius: 12, humidity: NaN },
				{ customName: "Sensor B", temperature_celsius: 52, humidity: NaN },
				{ customName: "Sensor C", temperature_celsius: 72, humidity: NaN },
			]
		},
		{
			name: "Single gauge",
			inputs: [ { customName: "Water tank", temperature_celsius: 17, humidity: NaN } ]
		},
		{
			name: "Single gauge x 2",
			inputs: [
				{ customName: "Water tank", temperature_celsius: 17, humidity: NaN },
				{ customName: "Sensor A", temperature_celsius: 54.2124, humidity: NaN },
			]
		},
		{
			name: "Single gauge x 3",
			inputs: [
				{ customName: "Water tank", temperature_celsius: 17, humidity: NaN },
				{ customName: "Sensor A", temperature_celsius: 64, humidity: NaN },
				{ customName: "Sensor B", temperature_celsius: 23.822, humidity: NaN },
			]
		},
		{
			name: "Single gauge x 4",
			inputs: [
				{ customName: "Sensor A", temperature_celsius: 14.12, humidity: NaN },
				{ customName: "Sensor B", temperature_celsius: 45.3234, humidity: NaN },
				{ customName: "Sensor C", temperature_celsius: -13.1123, humidity: NaN },
				{ customName: "Sensor D", temperature_celsius: 100, humidity: NaN },
			]
		},
		{
			name: "Single gauge x 5",
			inputs: [
				{ customName: "Sensor A", temperature_celsius: 64.12, humidity: NaN },
				{ customName: "Sensor B", temperature_celsius: 45.3234, humidity: NaN },
				{ customName: "Sensor C", temperature_celsius: 23.1123, humidity: NaN },
				{ customName: "Sensor D", temperature_celsius: 100, humidity: NaN },
				{ customName: "Sensor E", temperature_celsius: 0, humidity: NaN },
			]
		},
		{
			name: "Single gauge x 6",
			inputs: [
				{ customName: "Sensor A", temperature_celsius: 64.12, humidity: NaN },
				{ customName: "Sensor B", temperature_celsius: 45.3234, humidity: NaN },
				{ customName: "Sensor C", temperature_celsius: 23.1123 , humidity: NaN },
				{ customName: "Sensor D", temperature_celsius: 100, humidity: NaN },
				{ customName: "Sensor E", temperature_celsius: 0, humidity: NaN },
				{ customName: "Sensor F", temperature_celsius: 43.35 , humidity: NaN },
			]
		},
		{
			name: "Single gauge x 7",
			inputs: [
				{ customName: "Sensor A", temperature_celsius: 64.12 , humidity: NaN },
				{ customName: "Sensor B", temperature_celsius: 45.3234 , humidity: NaN },
				{ customName: "Sensor C", temperature_celsius: 23.1123 , humidity: NaN },
				{ customName: "Sensor D", temperature_celsius: 100, humidity: NaN },
				{ customName: "Sensor E", temperature_celsius: 0, humidity: NaN },
				{ customName: "Sensor F", temperature_celsius: 43.35, humidity: NaN },
				{ customName: "Sensor G", temperature_celsius: 23.35, humidity: NaN },     // scrolls off screen
			]
		},
	]

	function loadConfig(config) {
		Global.mockDataSimulator.setTanksRequested(config.tanks)
		Global.mockDataSimulator.setEnvironmentInputsRequested(config.inputs)
	}
}
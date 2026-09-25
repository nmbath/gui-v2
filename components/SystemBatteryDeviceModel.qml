/*
** Copyright (C) 2025 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

// A model of Device objects, generated from com.victronenergy.system/Batteries.
DeviceModel {
	id: root
	property var excludedServiceUids: []

	function refresh() {
		if (!_batteriesItem.valid) {
			root.deleteAllAndClear()
			return
		}
		const unfilteredBatteryList = _batteriesItem.value
		const batteryList = []
		for (let i = 0; i < unfilteredBatteryList.length; ++i) {
			const info = unfilteredBatteryList[i]
			const uid = info.instance === undefined
				? info.id
				: BackendConnection.serviceUidFromName(info.id, info.instance)
			if (excludedServiceUids.indexOf(uid) < 0) {
				batteryList.push(info)
			}
		}

		// Make a list of battery uids for identifying each battery in batteryList.
		let batteryUids = []
		let i
		for (i = 0; i < batteryList.length; ++i) {
			const serviceName = batteryList[i].id
			if (batteryList[i].instance === undefined) {
				batteryUids.push(serviceName)
			} else {
				batteryUids.push(BackendConnection.serviceUidFromName(serviceName, batteryList[i].instance))
			}
		}

		root.intersect(batteryUids)

		for (i = 0; i < batteryList.length; ++i) {
			const batteryInfo = batteryList[i]
			const batteryUid = batteryUids[i]
			let batteryObject
			const batteryIndex = root.indexOf(batteryUid)
			if (batteryIndex < 0) {
				batteryObject = _batteryComponent.createObject(root, {
					serviceUid: batteryUid,
					deviceInstance: batteryInfo.instance || 0,
					customName: batteryInfo.name || "",
				})
			} else {
				batteryObject = root.deviceAt(batteryIndex)
			}
			batteryObject.setValueIfValid("current", batteryInfo.current)
			batteryObject.setValueIfValid("power", batteryInfo.power)
			batteryObject.setValueIfValid("stateOfCharge", batteryInfo.soc)
			batteryObject.setValueIfValid("temperature", batteryInfo.temperature)
			batteryObject.setValueIfValid("timeToGo", batteryInfo.timetogo)
			batteryObject.setValueIfValid("voltage", batteryInfo.voltage)
		}
	}

	onExcludedServiceUidsChanged: refresh()

	// The battery list is a list of JSON values like this:
	// [{'active_battery_service': 1,'current': 55,'id': com.victronenergy.battery.ttyO0,'instance': 256,'name': House battery,'power': 1337,'soc': 98.4,'state': 1,'timetogo': 38040,'voltage': 24.3}]
	// Only 'id', 'name' and 'active_battery_service' are guaranteed to be present for each battery.
	readonly property VeQuickItem _batteriesItem: VeQuickItem {
		uid: Global.system.serviceUid + "/Batteries"
		onValueChanged: root.refresh()
	}

	component Battery : BaseDevice {
		id: battery

		property real current: NaN
		property real power: NaN
		property real stateOfCharge: NaN
		property real temperature: NaN
		property int timeToGo: 0
		property real voltage: NaN
		readonly property int mode: VenusOS.battery_modeFromPower(power)

		function setValueIfValid(propertyName, value) {
			if (value !== undefined) {
				if (propertyName === "temperature") {
					value = Units.convert(value, VenusOS.Units_Temperature_Celsius, Global.systemSettings.temperatureUnit)
				}
				battery[propertyName] = value
			}
		}

		name: customName
	}

	readonly property Component _batteryComponent: Component {
		Battery {
		   id: battery

			onValidChanged: {
				if (valid) {
					root.addDevice(battery)
				} else {
					root.removeDevice(battery.serviceUid)
					battery.destroy()
				}
			}
		}
	}
}

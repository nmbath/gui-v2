/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

pragma Singleton

import QtQuick
import Victron.VenusOS

// Curated, read-only partner data contract. Partner pages and Model 3
// contributions receive this object only when they declare readSystemData.
QtObject {
	id: root

	function finiteOr(value, fallback) {
		return typeof value === "number" && isFinite(value) ? value : fallback
	}

	readonly property var freshWaterModel: Global.tanks
		? Global.tanks.tankModel(VenusOS.Tank_Type_FreshWater) : null
	readonly property var fuelModel: Global.tanks
		? Global.tanks.tankModel(VenusOS.Tank_Type_Fuel) : null
	readonly property var wasteModel: Global.tanks
		? Global.tanks.tankModel(VenusOS.Tank_Type_WasteWater) : null

	function tankLevel(model) {
		return model && model.count > 0 ? Math.round(finiteOr(model.averageLevel, 0)) : 0
	}

	function firstAdditionalBattery(batteries) {
		if (!batteries || batteries.length < 2) {
			return null
		}
		for (let i = 0; i < batteries.length; ++i) {
			if (!batteries[i].active_battery_service) {
				return batteries[i]
			}
		}
		return batteries[1]
	}

	function mappedBattery(batteries, selector) {
		if (!batteries || !selector) {
			return null
		}
		let match = null
		for (let i = 0; i < batteries.length; ++i) {
			const battery = batteries[i]
			if (selector.name && battery.name !== selector.name) {
				continue
			}
			if (selector.serviceId && battery.id !== selector.serviceId) {
				continue
			}
			if (selector.deviceInstance !== undefined
					&& battery.instance !== selector.deviceInstance) {
				continue
			}
			// Ambiguous names are not safe role mappings. An installation-resolved
			// service ID or device instance can disambiguate them.
			if (match) {
				return null
			}
			match = battery
		}
		return match
	}

	function selectedBattery(dataSource, selector) {
		if (dataSource.startsWith("system.battery.")) {
			return mappedBattery(root._batteries, selector)
		}
		return root._additionalBattery
	}

	function batteryServiceUid(dataSource, selector) {
		const battery = selectedBattery(dataSource, selector)
		if (!battery) {
			return ""
		}
		return battery.instance === undefined
			? battery.id
			: BackendConnection.serviceUidFromName(battery.id, battery.instance)
	}

	function mappedDevice(selector) {
		if (!selector) {
			return null
		}
		let match = null
		const count = AllDevicesModel.count
		for (let i = 0; i < count; ++i) {
			const device = AllDevicesModel.deviceAt(i)
			if (selector.name && device.name !== selector.name) {
				continue
			}
			if (selector.serviceType && device.serviceType !== selector.serviceType) {
				continue
			}
			if (selector.deviceInstance !== undefined
					&& device.deviceInstance !== selector.deviceInstance) {
				continue
			}
			if (selector.serviceId) {
				const expectedUid = BackendConnection.serviceUidFromName(
					selector.serviceId, device.deviceInstance)
				if (device.serviceUid !== expectedUid) {
					continue
				}
			}
			if (match) {
				return null
			}
			match = device
		}
		return match
	}

	function mappedDeviceServiceUid(selector) {
		return mappedDevice(selector)?.serviceUid || ""
	}

	function mappedDeviceName(selector, fallback) {
		return mappedDevice(selector)?.name || fallback || qsTr("Mapped device")
	}

	function batteryName(dataSource, selector, fallback) {
		return selectedBattery(dataSource, selector)?.name || fallback || qsTr("Battery")
	}

	function metricAvailable(dataSource, selector) {
		if (!dataSource) {
			return false
		}
		switch (dataSource) {
		case "system.tank.freshWater.level": return root.freshWaterModel?.count > 0
		case "system.tank.fuel.level": return root.fuelModel?.count > 0
		case "system.tank.wasteWater.level": return root.wasteModel?.count > 0
		case "system.gxRelay.1.state": return root.relays.relay1Available
		case "system.firstAdditionalBattery.stateOfCharge":
		case "system.firstAdditionalBattery.voltage":
		case "system.firstAdditionalBattery.power":
		case "system.battery.starter.stateOfCharge":
		case "system.battery.starter.voltage":
		case "system.battery.starter.power":
		case "system.battery.auxiliary.stateOfCharge":
		case "system.battery.auxiliary.voltage":
		case "system.battery.auxiliary.power":
			return !!selectedBattery(dataSource, selector)
		default:
			return true
		}
	}

	function metricValue(dataSource, selector) {
		const battery = selectedBattery(dataSource, selector)
		switch (dataSource) {
		case "system.houseBattery.stateOfCharge": return houseBattery.stateOfCharge
		case "system.houseBattery.voltage": return houseBattery.voltage
		case "system.houseBattery.power": return houseBattery.powerWatts
		case "system.solar.power": return solar.powerWatts
		case "system.acLoad.power": return ac.loadWatts
		case "system.dcLoad.power": return dc.loadWatts
		case "system.tank.freshWater.level": return root.tanks.freshWaterPercent
		case "system.tank.fuel.level": return root.tanks.fuelPercent
		case "system.tank.wasteWater.level": return root.tanks.wastePercent
		case "system.gxRelay.1.state": return root.relays.relay1Available
			? (root.relays.relay1On ? 1 : 0) : NaN
		case "system.firstAdditionalBattery.stateOfCharge":
		case "system.battery.starter.stateOfCharge":
		case "system.battery.auxiliary.stateOfCharge": return finiteOr(battery?.soc, NaN)
		case "system.firstAdditionalBattery.voltage":
		case "system.battery.starter.voltage":
		case "system.battery.auxiliary.voltage": return finiteOr(battery?.voltage, NaN)
		case "system.firstAdditionalBattery.power":
		case "system.battery.starter.power":
		case "system.battery.auxiliary.power": return finiteOr(battery?.power, NaN)
		default: return NaN
		}
	}

	property var _batteries: []
	property var _additionalBattery: null
	readonly property VeQuickItem _batteriesItem: VeQuickItem {
		uid: Global.system.serviceUid + "/Batteries"
		onValueChanged: {
			root._batteries = valid ? value : []
			root._additionalBattery = valid ? root.firstAdditionalBattery(value) : null
		}
	}

	readonly property GuiPluginIntegrationModel _partnerBatteryIntegrations: GuiPluginIntegrationModel {
		type: GuiPluginLoader.OverviewBattery
	}
	readonly property var mappedBatteryServiceUids: {
		const result = []
		// Referencing count and _batteries keeps this binding live as plug-ins or
		// system battery entries change.
		const count = _partnerBatteryIntegrations.count
		const batteries = root._batteries
		for (let i = 0; i < count; ++i) {
			const configuration = _partnerBatteryIntegrations.integrationAt(i).configuration
			const uid = batteryServiceUid(configuration.dataSource, configuration.batterySelector)
			if (uid && result.indexOf(uid) < 0) {
				result.push(uid)
			}
		}
		return result
	}

	readonly property QtObject propulsion: QtObject {
		// A portable dual-propulsion aggregate is not yet exposed by Venus OS.
		// Keep the stable shape and report an honest unavailable state.
		readonly property string state: qsTr("Not available")
		readonly property int portRpm: 0
		readonly property int starboardRpm: 0
	}

	readonly property QtObject houseBattery: QtObject {
		readonly property real stateOfCharge: Math.round(root.finiteOr(
			Global.system?.battery?.stateOfCharge, 0))
		readonly property real powerWatts: Math.round(root.finiteOr(
			Global.system?.battery?.power, 0))
		readonly property real voltage: root.finiteOr(Global.system?.battery?.voltage, 0)
	}

	readonly property QtObject additionalBattery: QtObject {
		readonly property bool available: !!root._additionalBattery
		readonly property string name: root._additionalBattery?.name || qsTr("Additional battery")
		readonly property real stateOfCharge: root.finiteOr(root._additionalBattery?.soc, NaN)
		readonly property real powerWatts: root.finiteOr(root._additionalBattery?.power, NaN)
		readonly property real voltage: root.finiteOr(root._additionalBattery?.voltage, NaN)
	}

	readonly property QtObject solar: QtObject {
		readonly property real powerWatts: Math.round(root.finiteOr(
			Global.system?.solar?.dcPower, 0))
	}

	readonly property QtObject dc: QtObject {
		readonly property real loadWatts: Math.round(root.finiteOr(
			Global.system?.dc?.power, 0))
	}

	readonly property QtObject ac: QtObject {
		readonly property string source: Global.acInputs
			? Global.acInputs.sourceToText(Global.acInputs.activeInSource) : qsTr("Not available")
		readonly property real loadWatts: Math.round(root.finiteOr(
			Global.system?.load?.ac?.power, 0))
	}

	readonly property VeQuickItem _relay1State: VeQuickItem {
		uid: Global.system.serviceUid + "/Relay/0/State"
	}

	readonly property QtObject relays: QtObject {
		readonly property string relay1Name: qsTr("GX relay 1")
		readonly property bool relay1Available: root._relay1State.valid
		readonly property bool relay1On: root._relay1State.valid && Number(root._relay1State.value) !== 0
	}

	readonly property QtObject tanks: QtObject {
		readonly property real freshWaterPercent: root.tankLevel(root.freshWaterModel)
		readonly property real fuelPercent: root.tankLevel(root.fuelModel)
		readonly property real wastePercent: root.tankLevel(root.wasteModel)
	}

	readonly property QtObject systemHealth: QtObject {
		readonly property bool freshWaterLow: root.freshWaterModel?.count > 0
			&& root.tanks.freshWaterPercent < 20
		readonly property bool wasteHigh: root.wasteModel?.count > 0
			&& root.tanks.wastePercent > 75
		readonly property bool batteryLow: root.houseBattery.stateOfCharge > 0
			&& root.houseBattery.stateOfCharge < 20
		readonly property string severity: freshWaterLow || wasteHigh || batteryLow ? "warning" : "ok"
		readonly property string state: freshWaterLow ? qsTr("Fresh water low")
			: wasteHigh ? qsTr("Waste tank high")
			: batteryLow ? qsTr("House battery low")
			: qsTr("All systems normal")
	}
}

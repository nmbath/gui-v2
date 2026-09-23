/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

pragma Singleton

import QtQuick
import Victron.VenusOS

// Resolves the single active, declarative partner policy for the Brief centre.
// The partner configuration is never written into the user's settings, so
// disabling the pack immediately restores the user's previous choices.
QtObject {
	id: root

	readonly property GuiPluginIntegrationModel _integrations: GuiPluginIntegrationModel {
		type: GuiPluginLoader.BriefLayout
	}
	readonly property var configuration: _integrations.count > 0
		? _integrations.integrationAt(0).configuration : ({})
	readonly property string mode: configuration.mode || "user"
	readonly property bool active: _integrations.count > 0 && mode !== "user"
	readonly property bool locked: active && mode === "partnerLocked"
	readonly property string ownerName: _integrations.count > 0
		? _integrations.integrationAt(0).title : ""
	readonly property var centerDetail: configuration.centerDetail || ({
		dataSource: "system.houseBattery.stateOfCharge"
	})
	readonly property bool usesMappedCenterBattery: active
		&& centerDetail.dataSource !== "system.houseBattery.stateOfCharge"

	function _gauge(data) {
		const source = data?.dataSource || ""
		switch (source) {
		case "system.houseBattery.stateOfCharge":
			return { centerGaugeType: VenusOS.BriefView_CentralGauge_SystemBattery, value: "" }
		case "system.battery.starter.stateOfCharge":
		case "system.battery.auxiliary.stateOfCharge": {
			const battery = PartnerSystemData.selectedBattery(source, data.batterySelector)
			return battery ? { centerGaugeType: VenusOS.BriefView_CentralGauge_BatteryId, value: battery.id } : null
		}
		case "system.tank.freshWater.level":
			return { centerGaugeType: VenusOS.BriefView_CentralGauge_TankAggregate, value: VenusOS.Tank_Type_FreshWater }
		case "system.tank.fuel.level":
			return { centerGaugeType: VenusOS.BriefView_CentralGauge_TankAggregate, value: VenusOS.Tank_Type_Fuel }
		case "system.tank.wasteWater.level":
			return { centerGaugeType: VenusOS.BriefView_CentralGauge_TankAggregate, value: VenusOS.Tank_Type_WasteWater }
		default:
			return null
		}
	}

	function partnerGauges() {
		const result = []
		const configured = configuration.centerGauges || []
		for (let i = 0; i < configured.length; ++i) {
			const gauge = _gauge(configured[i])
			if (gauge) {
				result.push(gauge)
			}
		}
		return result
	}

	function effectiveGauges(userGauges) {
		if (!active) {
			return userGauges || []
		}
		const configured = partnerGauges()
		if (mode === "partnerDefault" && userGauges && userGauges.length > 0) {
			return userGauges
		}
		return configured
	}
}

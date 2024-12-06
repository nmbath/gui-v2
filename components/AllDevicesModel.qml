/*
** Copyright (C) 2024 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

AggregateDeviceModel {
	id: aggregateModel

	sourceModels: [
		batteryDevices,
		Global.dcInputs.model,
		Global.dcLoads.model,
		digitalInputDevices,
		Global.environmentInputs.model,
		Global.evChargers.model,
		Global.inverterChargers.veBusDevices,
		Global.inverterChargers.acSystemDevices,
		Global.inverterChargers.inverterDevices,
		Global.inverterChargers.chargerDevices,
		meteoDevices,
		motorDriveDevices,
		pulseMeterDevices,
		Global.pvInverters.model,
		Global.solarChargers.model,
		unsupportedDevices,

		// AC input models
		gridDevices,
		gensetDevices,
		acLoadDevices,
		heatPumpDevices

	].concat(Global.tanks.allTankModels)

	readonly property ServiceDeviceModel batteryDevices: ServiceDeviceModel {
		serviceType: "battery"
		modelId: "battery"
	}

	readonly property ServiceDeviceModel digitalInputDevices: ServiceDeviceModel {
		serviceType: "digitalinput"
		modelId: "digitalinput"
	}

	readonly property ServiceDeviceModel gridDevices: ServiceDeviceModel {
		serviceType: "grid"
		modelId: "grid"
	}

	readonly property ServiceDeviceModel gensetDevices: ServiceDeviceModel {
		serviceType: "genset"
		modelId: "genset"
	}

	readonly property ServiceDeviceModel acLoadDevices: ServiceDeviceModel {
		serviceType: "acload"
		modelId: "acload"
	}

	readonly property ServiceDeviceModel heatPumpDevices: ServiceDeviceModel {
		serviceType: "heatpump"
		modelId: "heatpump"
	}

	readonly property ServiceDeviceModel meteoDevices: ServiceDeviceModel {
		serviceType: "meteo"
		modelId: "meteo"
	}

	readonly property ServiceDeviceModel motorDriveDevices: ServiceDeviceModel {
		serviceType: "motordrive"
		modelId: "motordrive"
	}

	readonly property ServiceDeviceModel pulseMeterDevices: ServiceDeviceModel {
		serviceType: "pulsemeter"
		modelId: "pulsemeter"
	}

	readonly property ServiceDeviceModel unsupportedDevices: ServiceDeviceModel {
		serviceType: "unsupported"
		modelId: "unsupported"
	}
}

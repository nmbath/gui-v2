/*
** Copyright (C) 2021 Victron Energy B.V.
*/

import QtQuick
import Victron.VenusOS

Page {
	id: root

	readonly property string settingsBindPrefix: "com.victronenergy.settings"
	readonly property string pumpBindPrefix: "com.victronenergy.pump.startstop0"

	SettingsListView {
		id: settingsListView

		model: relayFunction.value === undefined ? startStopModel : relayFunction.value  === 3 ? startStopModel : disabledModel

		DataPoint {
			id: relayFunction
			source: settingsBindPrefix + "/Settings/Relay/Function"
		}
	}

	ObjectModel {
		id: disabledModel

		SettingsListItem {
			primaryLabel.horizontalAlignment: Text.AlignHCenter
			//% "Tank pump start/stop function is not enabled, go to relay settings and set function to \"Tank pump\""
			text: qsTrId("settings_pump_function_not_enabled" )
		}
	}

	ObjectModel {
		id: startStopModel

		SettingsListTextItem {
			//% "Pump state"
			text: qsTrId("settings_pump_state")
			source: root.pumpBindPrefix + "/State"
			secondaryText: CommonWords.onOrOff(dataPoint.value)
		}

		SettingsListRadioButtonGroup {
			//% "Mode"
			text: qsTrId("settings_pump_mode")
			optionModel: [
				//% "Auto"
				{ display: qsTrId("settings_pump_auto"), value: 0 },
				{ display: CommonWords.onOrOff(1), value: 1 },
				{ display: CommonWords.onOrOff(0), value: 2 },
			]
			source: root.settingsBindPrefix + "/Settings/Pump0/Mode"
		}

		SettingsListRadioButtonGroup {
			id: monitorService

			//% "Tank sensor"
			text: qsTrId("settings_tank_sensor")
			defaultSecondaryText: "TODO" // TODO - finish this when tank sensors arrive. The dbus schema for this is complex and dynamic.
			enabled: false
		}

		SettingsListSpinBox {
			//% "Start level"
			text: qsTrId("settings_tank_start_level")
			source: root.settingsBindPrefix + "/Settings/Pump0/StartValue"
			from: 0
			to: 100
			suffix: "%"
		}

		SettingsListSpinBox {
			//% "Stop level"
			text: qsTrId("settings_tank_stop_level")
			source: root.settingsBindPrefix + "/Settings/Pump0/StopValue"
			from: 0
			to: 100
			suffix: "%"
		}
	}
}

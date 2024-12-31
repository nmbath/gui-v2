/*
** Copyright (C) 2023 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

Page {
	id: root

	GradientListView {
		id: settingsListView

		model: ObjectModel {
			ListNavigation {
				text: CommonWords.add_device
				icon.source: "qrc:/images/icon_plus_32.svg"
				icon.color: Theme.color_blue
				icon.width: 32
				icon.height: 32
				onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsModbusAddDevice.qml", {"title": text})
			}

			SettingsListHeader { }

			ListNavigation {
				//% "PV Inverters"
				text: qsTrId("pagesettingsintegrations_pv_inverters")
				onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsFronius.qml", {"title": text})
			}

			ListNavigation {
				//% "Modbus Devices"
				text: qsTrId("pagesettingsintegrations_modbus_devices")
				onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsModbus.qml", {"title": text})
			}

			ListNavigation {
				//% "Bluetooth Sensors"
				text: qsTrId("pagesettingsintegrations_bluetooth_sensors")
				allowed: hasBluetoothSupport.value
				onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsBleSensors.qml", {"title": text})

				VeQuickItem {
					id: hasBluetoothSupport
					uid: Global.venusPlatform.serviceUid + "/Network/HasBluetoothSupport"
				}
			}

			ListNavigation {
				//% "Tank and Temperature Sensors"
				text: qsTrId("pagesettingsintegrations_tank_and_temperature_sensors")
				allowed: defaultAllowed && analogModel.rowCount > 0
				onClicked: Global.pageManager.pushPage(analogInputsComponent, {"title": text})

				VeQItemTableModel {
					id: analogModel
					uids: [ BackendConnection.serviceUidForType("adc") + "/Devices" ]
					flags: VeQItemTableModel.AddChildren | VeQItemTableModel.AddNonLeaves | VeQItemTableModel.DontAddItem
				}

				Component {
					id: analogInputsComponent

					Page {
						GradientListView {
							model: analogModel
							delegate: ListSwitch {
								text: switchLabel.value || ""
								dataItem.uid: model.uid + "/Function"

								VeQuickItem {
									id: switchLabel
									uid: model.uid + "/Label"
								}
							}
						}
					}
				}
			}

			ListNavigation {
				//% "Relays"
				text: qsTrId("pagesettingsintegrations_relays")
				onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsRelay.qml", {"title": text})
				allowed: relay0.isValid

				VeQuickItem {
					id: relay0
					uid: Global.system.serviceUid + "/Relay/0/State"
				}
			}

			ListNavigation {
				//% "Digital I/O"
				text: qsTrId("pagesettingsintegrations_digital_io")
				allowed: defaultAllowed && digitalModel.rowCount > 0
				onClicked: Global.pageManager.pushPage(digitalInputsComponent, {"title": text})

				VeQItemSortTableModel {
					id: digitalModel
					filterRegExp: "/[1-9]$"
					model: VeQItemTableModel {
						uids: [ Global.systemSettings.serviceUid + "/Settings/DigitalInput" ]
						flags: VeQItemTableModel.AddChildren | VeQItemTableModel.AddNonLeaves | VeQItemTableModel.DontAddItem
					}
				}

				Component {
					id: digitalInputsComponent

					Page {
						readonly property var delegateOptionModel: [
							VenusOS.DigitalInput_Type_Disabled,
							VenusOS.DigitalInput_Type_PulseMeter,
							VenusOS.DigitalInput_Type_DoorAlarm,
							VenusOS.DigitalInput_Type_BilgePump,
							VenusOS.DigitalInput_Type_BilgeAlarm,
							VenusOS.DigitalInput_Type_BurglarAlarm,
							VenusOS.DigitalInput_Type_SmokeAlarm,
							VenusOS.DigitalInput_Type_FireAlarm,
							VenusOS.DigitalInput_Type_CO2Alarm,
							VenusOS.DigitalInput_Type_Generator,
							VenusOS.DigitalInput_Type_TouchInputControl
						].map(function(v) { return { value: v, display: VenusOS.digitalInput_typeToText(v)} } )

						GradientListView {
							model: digitalModel

							delegate: ListRadioButtonGroup {
								//: %1 = number of the digital input
								//% "Digital input %1"
								text: qsTrId("settings_io_digital_input").arg(model.uid.split('/').pop())
								dataItem.uid: model.uid + "/Type"
								optionModel: delegateOptionModel
							}
						}
					}
				}
			}

			ListMqttAccessSwitch { }

			ListNavigation {
				//% "Modbus TCP Server"
				text: qsTrId("pagesettingsintegrations_modbus_tcp_server")
				onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsModbusTcp.qml", {"title": text}) // TODO - is this correct?
			}

			PrimaryListLabel {
				//% "Note that the following features are not officially supported by Victron. Please turn to community.victronenergy.com for questions.\n\nDocumentation at https://ve3.nl/vol"
				text: qsTrId("settings_large_features_not_offically_supported")
			}

			ListSwitch {
				id: signalk

				//% "Signal K"
				text: qsTrId("settings_large_signal_k")
				dataItem.uid: Global.venusPlatform.serviceUid + "/Services/SignalK/Enabled"
				allowed: dataItem.isValid
			}

			PrimaryListLabel {
				//% "Access Signal K at http://venus.local:3000 and via VRM."
				text: qsTrId("settings_large_access_signal_k")
				allowed: signalk.checked
			}

			ListNavigation {
				//% "Node-RED"
				text: qsTrId("settings_large_node_red")
				allowed: nodeRedModeItem.isValid
				onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsNodeRed.qml", {"title": text })

				VeQuickItem {
					id: nodeRedModeItem
					uid: Global.venusPlatform.serviceUid + "/Services/NodeRed/Mode"
				}
			}
		}
	}
}

/*
** Copyright (C) 2023 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Window
import Victron.VenusOS

Page {
	id: root

	property int cardWidth: cardsView.count > 2
			? Theme.geometry_controlCard_minimumWidth
			: Theme.geometry_controlCard_maximumWidth

	topLeftButton: VenusOS.StatusBar_LeftButton_ControlsActive
	width: parent.width
	anchors {
		top: parent.top
		bottom: parent.bottom
		bottomMargin: Theme.geometry_controlCardsPage_bottomMargin
	}

	ListView {
		id: cardsView

		anchors {
			fill: parent
			leftMargin: Theme.geometry_controlCardsPage_horizontalMargin
			rightMargin: Theme.geometry_controlCardsPage_horizontalMargin
		}
		spacing: Theme.geometry_controlCardsPage_spacing
		orientation: ListView.Horizontal
		boundsBehavior: Flickable.StopAtBounds
		maximumFlickVelocity: Theme.geometry_flickable_maximumFlickVelocity
		flickDeceleration: Theme.geometry_flickable_flickDeceleration

		model: VisibleItemModel {
			Loader {
				active: systemType.value === "ESS" || systemType.value === "Hub-4"
				width: active ? root.cardWidth : -cardsView.spacing
				sourceComponent: ESSCard {
					width: root.cardWidth
					height: cardsView.height
				}

				VeQuickItem {
					id: systemType
					uid: Global.system.serviceUid + "/SystemType"
				}
			}

			Row {
				height: cardsView.height
				spacing: Theme.geometry_controlCardsPage_spacing

				Repeater {
					model: evChargerModel

					EVCSCard {
						width: root.cardWidth
						serviceUid: model.device.serviceUid
					}
				}
			}

			Row {
				height: cardsView.height
				spacing: Theme.geometry_controlCardsPage_spacing

				Repeater {
					model: Global.generators.model

					GeneratorCard {
						width: root.cardWidth
						generator: model.device
					}
				}
			}

			Row {
				height: cardsView.height
				spacing: Theme.geometry_controlCardsPage_spacing

				Repeater {
					model: Global.inverterChargers.veBusDevices

					InverterChargerCard {
						width: root.cardWidth
						serviceUid: model.device.serviceUid
						name: model.device.name
					}
				}

				Repeater {
					model: Global.inverterChargers.acSystemDevices

					InverterChargerCard {
						width: root.cardWidth
						serviceUid: model.device.serviceUid
						name: model.device.name
					}
				}

				Repeater {
					model: Global.inverterChargers.inverterDevices

					InverterChargerCard {
						width: root.cardWidth
						serviceUid: model.device.serviceUid
						name: model.device.name
					}
				}
			}

			Loader {
				active: manualRelays.count > 0
				width: active ? root.cardWidth : -cardsView.spacing
				sourceComponent: SwitchesCard {
					width: root.cardWidth
					height: cardsView.height
					model: manualRelays
				}

				ManualRelayModel { id: manualRelays }
			}
		}
	}

	// A model of evcharger services that represent controllable EV chargers, i.e. those with a
	// valid /Mode value. Global.evChargers.model cannot be used in the control cards, as it
	// includes services without a /Mode, such as Energy Meters configured as EV chargers.
	ServiceDeviceModel {
		id: evChargerModel

		serviceType: "evcharger"
		modelId: "evcharger"
		deviceDelegate: Device {
			id: device

			required property string uid
			readonly property bool isRealCharger: valid && _chargerMode.valid

			readonly property VeQuickItem _chargerMode: VeQuickItem {
				uid: device.serviceUid + "/Mode"
			}

			serviceUid: uid
			onIsRealChargerChanged: {
				if (isRealCharger) {
					evChargerModel.addDevice(device)
				} else {
					evChargerModel.removeDevice(device.serviceUid)
				}
			}
		}
	}
}

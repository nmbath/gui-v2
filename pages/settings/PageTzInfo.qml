/*
** Copyright (C) 2022 Victron Energy B.V.
*/

import QtQuick
import Victron.VenusOS
import "tz"

Page {
	id: root

	property var _timeZoneModels: [ tzAfrica, tzAmerica, tzAntartica, tzArtic, tzAsia, tzAtlantic, tzAustralia, tzEurope, tzIndian, tzPacific, tzEtc ]

	function _findTimeZoneName(region, city) {
		if (city === "UTC") {
			return city
		}
		for (let i = 0; i < _timeZoneModels.length; ++i) {
			const tzModel = _timeZoneModels[i]
			if (tzModel.region !== region) {
				continue
			}
			for (let j = 0; j < tzModel.count; ++j) {
				const tz = tzModel.get(j)
				if (tz.city === city) {
					return tz.display
				}
			}
		}
		return ""
	}

	SettingsListView {
		model: ObjectModel {

			SettingsListTextItem {
				//% "Date/Time UTC"
				text: qsTrId("settings_tz_date_time_utc")
				secondaryText: Qt.formatDateTime(ClockTime.currentDateTimeUtc, "yyyy-MM-dd hh:mm")
			}

			SettingsListButton {
				//% "Date/Time local"
				text: qsTrId("settings_tz_date_time_local")
				button.text: ClockTime.currentTimeText
				writeAccessLevel: VenusOS.User_AccessType_User

				onClicked: {
					const dt = ClockTime.currentDateTime
					Global.dialogManager.timeSelectorDialog.hour = dt.getHours()
					Global.dialogManager.timeSelectorDialog.minute = dt.getMinutes()
					Global.dialogManager.timeSelectorDialog.open()
				}

				Connections {
					target: Global.dialogManager.timeSelectorDialog
					function onAccepted() {
						let dt = ClockTime.currentDateTime
						dt.setHours(Global.dialogManager.timeSelectorDialog.hour)
						dt.setMinutes(Global.dialogManager.timeSelectorDialog.minute)

						// TODO set system date time to 'dt' using venus-platform or such
						Global.dialogManager.showToastNotification(VenusOS.Notification_Notification, "TODO not yet implemented")
					}
				}
			}

			SettingsListNavigationItem {
				//% "Time zone"
				text: qsTrId("settings_tz_time_zone")
				secondaryText: root._findTimeZoneName(tzData.region, tzData.city)

				onClicked: Global.pageManager.pushPage(pageTzMenuComponent)

				DataPoint {
					id: tzData

					property string city
					property string region

					function saveTimeZone(region, city) {
						tzData.city = city
						tzData.region = region
						setValue(region + "/" + city)
					}

					source: "com.victronenergy.settings/Settings/System/TimeZone"
					onValueChanged: {
						if (value !== undefined) {
							const slash = value.indexOf('/')
							if (slash >= 0) {
								region = value.substring(0, slash)
								city = value.substring(slash + 1)
							}
						}
					}
				}

				Component {
					id: pageTzMenuComponent

					Page {
						SettingsListView {
							id: tzListView
							header: SettingsListSwitch {
								text: "UTC"
								writeAccessLevel: VenusOS.User_AccessType_User
								checked: tzData.city === text
								updateOnClick: false
								onClicked: {
									tzData.saveTimeZone("", text)
									Global.pageManager.popPage(root)
								}
							}
							model: root._timeZoneModels

							delegate: SettingsListRadioButtonGroup {
								text: modelData.name
								model: modelData
								secondaryText: ""
								writeAccessLevel: VenusOS.User_AccessType_User
								updateOnClick: false
								currentIndex: {
									if (tzData.region === modelData.region) {
										for (let i = 0; i < modelData.count; ++i) {
											if (modelData.get(i).city === tzData.city) {
												return i
											}
										}
									}
									return -1
								}

								onOptionClicked: function(index) {
									tzData.saveTimeZone(modelData.region, modelData.get(index).city)
									Global.pageManager.popPage(root)
								}
							}
						}
					}
				}
			}
		}
	}

	TzAfricaData {
		id: tzAfrica
		//% "Africa"
		readonly property string name: qsTrId("settings_tz_africa")
		readonly property string region: "Africa"
	}
	TzAmericaData {
		id: tzAmerica
		//% "America"
		readonly property string name: qsTrId("settings_tz_america")
		readonly property string region: "America"
	}
	TzAntarcticaData {
		id: tzAntartica
		//% "Antartica"
		readonly property string name: qsTrId("settings_tz_antartica")
		readonly property string region: "Antartica"
	}
	TzArcticData {
		id: tzArtic
		//% "Artic"
		readonly property string name: qsTrId("settings_tz_artic")
		readonly property string region: "Artic"
	}
	TzAsiaData {
		id: tzAsia
		//% "Asia"
		readonly property string name: qsTrId("settings_tz_asia")
		readonly property string region: "Asia"
	}
	TzAtlanticData {
		id: tzAtlantic
		//% "Atlantic"
		readonly property string name: qsTrId("settings_tz_atlantic")
		readonly property string region: "Atlantic"
	}
	TzAustraliaData {
		id: tzAustralia
		//% "Australia"
		readonly property string name: qsTrId("settings_tz_ustralia")
		readonly property string region: "Australia"
	}
	TzEuropeData {
		id: tzEurope
		//% "Europe"
		readonly property string name: qsTrId("settings_tz_europe")
		readonly property string region: "Europe"
	}
	TzIndianData {
		id: tzIndian
		//% "Indian"
		readonly property string name: qsTrId("settings_tz_indian")
		readonly property string region: "Indian"
	}
	TzPacificData {
		id: tzPacific
		//% "Pacific"
		readonly property string name: qsTrId("settings_tz_pacific")
		readonly property string region: "Pacific"
	}
	TzEtcData {
		id: tzEtc
		//% "Etc"
		readonly property string name: qsTrId("settings_tz_etc")
		readonly property string region: "Etc"
	}
}

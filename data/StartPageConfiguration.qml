/*
** Copyright (C) 2024 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

QtObject {
	id: root

	required property string systemSettingsUid

	readonly property bool hasStartPage: startPageInfo != null
	readonly property bool autoSelect: _startPageMode.value === VenusOS.StartPage_Mode_AutoSelect
	readonly property int startPageTimeout: _startPageTimeout.value || 0     // in seconds
	readonly property var startPageInfo: _configurationAllowed(_startPageNameConfig)
		? _startPageNameConfig : null

	readonly property var options: {
		const result = []
		if (!PartnerNavigationConfiguration.isCorePageHidden("boat")) result.push({
			display: CommonWords.boat_page,
			value: _jsonStringForType(VenusOS.StartPage_Type_Boat),
		})
		if (!PartnerNavigationConfiguration.isCorePageHidden("brief")) result.push({
			display: CommonWords.brief_page,
			value: _jsonStringForType(VenusOS.StartPage_Type_Brief_SidePanelClosed),
		}, {
			//: The 'Brief' page, with the side panel opened
			//% "Brief (side panel open)"
			display: qsTrId("startpage_option_brief_with_panel"),
			value: _jsonStringForType(VenusOS.StartPage_Type_Brief_SidePanelOpened),
		})
		if (!PartnerNavigationConfiguration.isCorePageHidden("overview")) result.push({
			//: The 'Overview' page
			//% "Overview"
			display: qsTrId("startpage_option_overview"),
			value: _jsonStringForType(VenusOS.StartPage_Type_Overview),
		})
		if (!PartnerNavigationConfiguration.isCorePageHidden("levels")) result.push({
			//: The 'Levels' page, with the "Tanks" section opened
			//% "Levels (Tanks)"
			display: qsTrId("startpage_option_levels_tanks"),
			value: _jsonStringForType(VenusOS.StartPage_Type_Levels_Tanks),
		}, {
			//: The 'Levels' page, with the "Environment" section opened
			//% "Levels (Environment)"
			display: qsTrId("startpage_option_levels_environment"),
			value: _jsonStringForType(VenusOS.StartPage_Type_Levels_Environment),
		})
		result.push({
			display: CommonWords.notifications,
			value: _jsonStringForType(VenusOS.StartPage_Type_Notifications),
		})
		if (!PartnerNavigationConfiguration.isCorePageHidden("overview")) result.push({
			//% "Battery list"
			display: qsTrId("startpage_option_battery_list"),
			value: _jsonStringForType(VenusOS.StartPage_Type_BatteryList),
		})
		result.push({
			//% "Device list"
			display: qsTrId("startpage_option_device_list"),
			value: _jsonStringForType(VenusOS.StartPage_Type_DeviceList),
		})
		return result
	}

	property var _startPageNameConfig

	// Changes the "start page" to be the current visible page, if possible.
	function autoSelectStartPage(mainPageName, mainPage, topStackPageUrl) {
		if (!autoSelect) {
			return
		}
		if (!mainPageName || !mainPage) {
			console.warn("autoSelect() failed: mainPageName or mainPage not set")
			return
		}
		const startPageType = _findStartPageTypeForView(mainPageName, mainPage, topStackPageUrl)
		if (startPageType >= 0) {
			_startPageName.setValue(_jsonStringForType(startPageType))
		}
	}

	function _jsonStringForType(startPageType) {
		switch (startPageType) {
		case VenusOS.StartPage_Type_Boat:
			return JSON.stringify({
				main: { page: "BoatPage.qml", properties: {} },
				stack: [],
			})
		case VenusOS.StartPage_Type_Brief_SidePanelClosed:
			return JSON.stringify({
				main: { page: "BriefPage.qml", properties: { showSidePanel: false } },
				stack: [],
			})
		case VenusOS.StartPage_Type_Brief_SidePanelOpened:
			return JSON.stringify({
				main: { page: "BriefPage.qml", properties: { showSidePanel: true } },
				stack: [],
			})
		case VenusOS.StartPage_Type_Overview:
			return JSON.stringify({
				main: { page: "OverviewPage.qml", properties: {} },
				stack: [],
			})
		case VenusOS.StartPage_Type_Levels_Tanks:
			return JSON.stringify({
				main: { page: "LevelsPage.qml", properties: { currentTabIndex: 0 } },
				stack: [],
			})
		case VenusOS.StartPage_Type_Levels_Environment:
			return JSON.stringify({
				main: { page: "LevelsPage.qml", properties: { currentTabIndex: 1 } },
				stack: [],
			})
		case VenusOS.StartPage_Type_Notifications:
			return JSON.stringify({
				main: { page: "NotificationsPage.qml", properties: {} },
				stack: [],
			})
		case VenusOS.StartPage_Type_BatteryList:
			return JSON.stringify({
				main: { page: "OverviewPage.qml", properties: {} },
				stack: [{ page: "/pages/battery/BatteryListPage.qml" }],
			})
		case VenusOS.StartPage_Type_DeviceList:
			return JSON.stringify({
				main: { page: "SettingsPage.qml", properties: {} },
				stack: [{ page: "/pages/settings/devicelist/DeviceListPage.qml" }],
			})
		default:
			console.warn("Unsupported start page type:", startPageType)
			return ""
		}
	}

	function _configurationAllowed(configuration) {
		if (!configuration || !configuration.main) return false
		switch (configuration.main.page) {
		case "BoatPage.qml":
			return !PartnerNavigationConfiguration.isCorePageHidden("boat")
		case "BriefPage.qml":
			return !PartnerNavigationConfiguration.isCorePageHidden("brief")
		case "OverviewPage.qml":
			return !PartnerNavigationConfiguration.isCorePageHidden("overview")
		case "LevelsPage.qml":
			return !PartnerNavigationConfiguration.isCorePageHidden("levels")
		default:
			return true
		}
	}

	function _findStartPageTypeForView(mainPageName, mainPage, topStackPageUrl) {
		switch (mainPageName) {
		case "BoatPage.qml":
			return VenusOS.StartPage_Type_Boat
		case "BriefPage.qml":
			if (!topStackPageUrl) {
				if (mainPage.showSidePanel === undefined) {
					console.warn("Error: BriefPage does not have showSidePanel property!")
				} else {
					return mainPage.showSidePanel
							? VenusOS.StartPage_Type_Brief_SidePanelOpened
							: VenusOS.StartPage_Type_Brief_SidePanelClosed
				}
			}
			break
		case "OverviewPage.qml":
			if (!topStackPageUrl) {
				return VenusOS.StartPage_Type_Overview
			} else if (topStackPageUrl.endsWith("/BatteryListPage.qml")) {
				return VenusOS.StartPage_Type_BatteryList
			}
			break
		case "LevelsPage.qml":
			if (!topStackPageUrl) {
				if (mainPage.currentTabIndex === undefined) {
					console.warn("Error: LevelsPage does not have currentTabIndex property!")
				} else {
					return mainPage.currentTabIndex === 0
							? VenusOS.StartPage_Type_Levels_Tanks
							: VenusOS.StartPage_Type_Levels_Environment
				}
			}
			break
		case "NotificationsPage.qml":
			return VenusOS.StartPage_Type_Notifications
		case "SettingsPage.qml":
			if (topStackPageUrl && topStackPageUrl.endsWith("/DeviceListPage.qml")) {
				return VenusOS.StartPage_Type_DeviceList
			}
			break
		}
		return -1
	}

	// Whether the start page is enabled. 0 = disabled (i.e. auto-select), 1 = enabled (do not auto-select)
	readonly property VeQuickItem _startPageMode: VeQuickItem {
		uid: root.systemSettingsUid + "/Settings/Gui2/StartPage"
	}

	// JSON string containing the start page configuration.
	readonly property VeQuickItem _startPageName: VeQuickItem {
		uid: root.systemSettingsUid + "/Settings/Gui2/StartPageName"
		onValueChanged: {
			if (valid && value !== "") {
				root._startPageNameConfig = valid && value !== "" ? JSON.parse(_startPageName.value) : null
			}
		}
	}

	// Time to wait (in seconds) when the app is idle, before loading the start page.
	readonly property VeQuickItem _startPageTimeout: VeQuickItem {
		uid: root.systemSettingsUid + "/Settings/Gui2/StartPageTimeout"
	}
}

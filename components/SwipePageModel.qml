import QtQuick
import QtQml.Models
import Victron.VenusOS
import Victron.Boat as Boat

ObjectModel {
	id: root

	required property SwipeView view
	readonly property list<SwipeViewPage> pages: {
		root._pluginRevision
		return root._composePages()
	}
	readonly property bool showLevelsPage: !PartnerNavigationConfiguration.isCorePageHidden("levels")
		&& levelsPageLoader.active && !!levelsPageLoader.item
	readonly property bool showBoatPage: !PartnerNavigationConfiguration.isCorePageHidden("boat")
		&& boatPageLoader.active && !!boatPageLoader.item
	readonly property int tankCount: Global.tanks ? Global.tanks.totalTankCount : 0
	readonly property int environmentInputCount: Global.environmentInputs ? Global.environmentInputs.model.count : 0

	readonly property bool completed: _completed
		&& Global.dataManagerLoaded
		&& Global.systemSettings
		&& Global.tanks
		&& Global.environmentInputs
		&& !GuiPluginLoader.busy
		&& _pluginLoadersSettled

	property bool _completed: false
	property int _pluginRevision: 0
	property var _pluginPages: []
	readonly property bool _pluginLoadersSettled: {
		for (let i = 0; i < navigationPageInstantiator.count; ++i) {
			const loader = navigationPageInstantiator.objectAt(i)
			if (loader && loader.status === Loader.Loading) {
				return false
			}
		}
		return true
	}

	function _pagesAt(placement) {
		return _pluginPages.filter(function(entry) { return entry.placement === placement })
			.sort(function(a, b) {
				if (a.order !== b.order) return a.order - b.order
				if (a.pluginName !== b.pluginName) return a.pluginName.localeCompare(b.pluginName)
				return a.integrationId.localeCompare(b.integrationId)
			}).map(function(entry) { return entry.page })
	}

	function _composePages() {
		let result = []
		if (showBoatPage) result.push(boatPageLoader.item)
		result = result.concat(_pagesAt("beforeBrief"))
		if (!PartnerNavigationConfiguration.isCorePageHidden("brief")) result.push(briefPage)
		result = result.concat(_pagesAt("afterBrief"), _pagesAt("beforeOverview"))
		if (!PartnerNavigationConfiguration.isCorePageHidden("overview")) result.push(overviewPage)
		result = result.concat(_pagesAt("afterOverview"))
		if (showLevelsPage) result.push(levelsPageLoader.item)
		result = result.concat(_pagesAt("beforeNotifications"))
		result.push(notificationsPage)
		result = result.concat(_pagesAt("afterNotifications"), _pagesAt("beforeSettings"))
		result.push(settingsPage)
		return result
	}

	function _refreshNavigationPolicy() {
		const previousPage = root.view ? root.view.currentItem : null
		_pluginRevision++
		const availablePages = _composePages()
		if (previousPage && availablePages.indexOf(previousPage) < 0 && root.view) {
			root.view.setCurrentIndex(0)
		}
	}

	function _refreshPluginPages() {
		const pages = []
		for (let i = 0; i < navigationPageInstantiator.count; ++i) {
			const loader = navigationPageInstantiator.objectAt(i)
			if (!loader || loader.status !== Loader.Ready || !loader.item) continue
			if (loader.item.isSwipeViewPage !== true) {
				console.warn("Ignoring navigation integration whose root is not SwipeViewPage:", loader.pluginName, loader.integrationId)
				continue
			}
			loader.item.pageId = loader.pluginName + "." + loader.integrationId
			loader.item.sourcePlugin = loader.pluginName
			loader.item.view = root.view
			pages.push({
				page: loader.item,
				pluginName: loader.pluginName,
				integrationId: loader.integrationId,
				placement: loader.placement,
				order: loader.pageOrder
			})
		}
		_pluginPages = pages
		_pluginRevision++
	}

	onViewChanged: {
		for (let i = 0; i < _pluginPages.length; ++i) {
			_pluginPages[i].page.view = view
		}
	}

	GuiPluginIntegrationModel {
		id: navigationPageModel
		type: GuiPluginLoader.NavigationPage
	}

	Connections {
		target: PartnerNavigationConfiguration
		function onHiddenCorePagesChanged() { root._refreshNavigationPolicy() }
	}

	Instantiator {
		id: navigationPageInstantiator
		model: navigationPageModel

		delegate: Loader {
			property string pluginName: model.pluginName
			property string integrationId: model.integrationId
			property string placement: model.placement
			property int pageOrder: model.order
			property var capabilities: model.capabilities
			property var configuration: model.configuration

			Component.onCompleted: setSource(model.url, {
				"view": root.view,
				"url": model.url,
				"iconSource": model.icon,
				"title": model.title,
				"configuration": configuration,
				"partnerData": capabilities.indexOf("readSystemData") >= 0 ? PartnerSystemData : ({})
			})
			onStatusChanged: {
				if (status === Loader.Error) {
					console.warn("Failed to load partner navigation page:", pluginName, integrationId, source)
				} else if (status === Loader.Ready) {
					console.info("Loaded partner navigation page:", pluginName, integrationId)
				}
				root._refreshPluginPages()
			}
		}

		onObjectAdded: (index, object) => root._refreshPluginPages()
		onObjectRemoved: (index, object) => {
			// Ensure callers move to a valid core page before the old plugin item is destroyed.
			if (root.view && root.view.currentItem === object.item) root.view.setCurrentIndex(0)
			root._refreshPluginPages()
		}
	}

	Loader {
		id: boatPageLoader

		active: showBoatPageItem.value ?? false
		sourceComponent: Boat.BoatPage {
			view: root.view
			pageId: "core.boat"
		}

		VeQuickItem {
			id: showBoatPageItem
			uid: !!Global.systemSettings ? Global.systemSettings.serviceUid + "/Settings/Gui/ElectricPropulsionUI/Enabled" : ""
		}
	}

	BriefPage {
		id: briefPage
		view: root.view
		pageId: "core.brief"

		Image {
			width: status === Image.Null ? 0 : Theme.geometry_screen_width
			fillMode: Image.PreserveAspectFit
			source: UiConfig.demoImageFileName
			onStatusChanged: {
				if (status === Image.Ready) {
					console.info("Loaded demo image:", source)
				}
			}
		}
	}

	OverviewPage {
		id: overviewPage
		view: root.view
		pageId: "core.overview"
	}

	Loader {
		id: levelsPageLoader

		active: root.tankCount > 0 || root.environmentInputCount > 0
		sourceComponent: LevelsPage {
			view: root.view
			pageId: "core.levels"
		}
	}

	NotificationsPage {
		id: notificationsPage
		view: root.view
		pageId: "core.notifications"
	}

	SettingsPage {
		id: settingsPage
		view: root.view
		pageId: "core.settings"
	}

	Component.onCompleted: Qt.callLater(function() { root._completed = true })
}

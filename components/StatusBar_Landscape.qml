/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Controls.impl as CP
import Victron.VenusOS

FocusScope {
	id: root

	required property PageStack pageStack
	readonly property bool webNavigationActive: Global.mainView.currentPage?.webNavigationBar ?? false

	signal controlCardsActivated()
	signal auxCardsActivated()
	signal webPagesActivated()
	signal cardsDeactivated()
	signal sidePanelToggled()

	function updateBreadcrumbsFocusHint() {
		// When breadcrumbs list is focused: if focus is arriving from the left side, focus the
		// the left-most breadcrumb, or if from the right side, focus the right-most breadcrumb.
		if (leftButton.activeFocus || auxButton.activeFocus || webPagesButton.activeFocus) {
			breadcrumbs.focusEdgeHint = Qt.LeftEdge
		} else if (rightButton.activeFocus || sleepButton.activeFocus) {
			breadcrumbs.focusEdgeHint = Qt.RightEdge
		} else {
			for (let i = 0; i < pluginPaneButtons.count; ++i) {
				if (pluginPaneButtons.itemAt(i)?.activeFocus) {
					breadcrumbs.focusEdgeHint = Qt.LeftEdge
					return
				}
			}
			// Focus is coming elsewhere, so do not change the current index
			breadcrumbs.focusEdgeHint = -1
		}
	}

	implicitWidth: Theme.geometry_screen_width
	implicitHeight: Theme.geometry_statusBar_height

	component NotificationButton : Button {
		readonly property bool animating: animator.running

		opacity: enabled ? 1 : 0
		font.family: Global.fontFamily
		font.pixelSize: Theme.font_size_caption
		Behavior on opacity {
			enabled: Global.animationEnabled
			OpacityAnimator {
				id: animator
				duration: Theme.animation_toastNotification_fade_duration
			}
		}
	}

	StatusBarButton {
		id: leftButton

		readonly property bool controlsPaneActive: (Global.mainView?.cardsActive ?? false)
				&& Global.mainView.cardsLoader.sourceComponent === Global.mainView.controlCardsComponent

		readonly property int buttonType: {
			if (controlsPaneActive) {
				return VenusOS.StatusBar_LeftButton_ControlsActive
			}
			const customButton = Global.mainView.currentPage?.topLeftButton ?? VenusOS.StatusBar_LeftButton_None
			if (customButton === VenusOS.StatusBar_LeftButton_None && pageStack.opened) {
				return VenusOS.StatusBar_LeftButton_Back
			}
			return customButton
		}

		// Expand clickable area on left and bottom edges.
		leftInset: Theme.geometry_statusBar_horizontalMargin
		bottomInset: Theme.geometry_statusBar_spacing

		y: root.webNavigationActive ? -Theme.geometry_statusBar_spacing / 2 : 0
		icon.source: root.webNavigationActive ? "qrc:/images/icon_webpages_32.svg"
			: Global.mainView.webPagesActive ? ""
			: buttonType === VenusOS.StatusBar_LeftButton_ControlsInactive ? "qrc:/images/icon_controls_off_32.svg"
			: buttonType === VenusOS.StatusBar_LeftButton_ControlsActive ? "qrc:/images/icon_controls_on_32.svg"
			: buttonType === VenusOS.StatusBar_LeftButton_Back ? "qrc:/images/icon_back_32.svg"
			: ""
		enabled: !(Global.mainView?.webPagesActive ?? false) && buttonType !== VenusOS.StatusBar_LeftButton_None
		visible: !(Global.mainView?.cardsActive ?? false) || controlsPaneActive || pageStack.opened
		KeyNavigation.right: auxButton

		onClicked: {
			switch (buttonType) {
			case VenusOS.StatusBar_LeftButton_ControlsInactive:
				root.controlCardsActivated()
				break
			case VenusOS.StatusBar_LeftButton_ControlsActive:
				root.cardsDeactivated()
				break;
			case VenusOS.StatusBar_LeftButton_Back:
				Global.pageManager.popPage()
				break
			default:
				break
			}
		}

		onActiveFocusChanged: {
			if (activeFocus) {
				root.updateBreadcrumbsFocusHint()
			}
		}
	}

	StatusBarButton {
		id: auxButton

		readonly property bool auxCardsOpened: (Global.mainView?.cardsActive ?? false)
				&& Global.mainView.cardsLoader.sourceComponent === Global.mainView.auxCardsComponent

		// Expand clickable area on right and bottom edges, and on left if leftButton is hidden.
		anchors {
			left: leftButton.right
			leftMargin: -leftInset
		}
		leftInset: leftButton.enabled ? 0 : Theme.geometry_statusBar_spacing
		rightInset: Theme.geometry_statusBar_spacing
		bottomInset: Theme.geometry_statusBar_spacing

		visible: (!root.pageStack.opened && Global.switches.groups.count > 0
				&& !(Global.mainView?.cardsActive ?? false))
				|| auxCardsOpened // allow cards to be closed if all switches are disconnected while opened
		icon.source: (Global.mainView?.webPagesActive ?? false) ? ""
				: leftButton.buttonType === VenusOS.StatusBar_LeftButton_ControlsActive ? ""
				: auxCardsOpened ? "qrc:/images/icon_smartswitch_on_32.svg"
				: "qrc:/images/icon_smartswitch_off_32.svg"
		enabled: visible && !(Global.mainView?.webPagesActive ?? false)
		KeyNavigation.right: pluginPaneButtons.count > 0
			? pluginPaneButtons.itemAt(0) : webPagesButton

		onClicked: {
			if (auxCardsOpened) {
				root.cardsDeactivated()
			} else {
				root.auxCardsActivated()
			}
		}

		onActiveFocusChanged: {
			if (activeFocus) {
				root.updateBreadcrumbsFocusHint()
			}
		}
	}

	Row {
		id: pluginButtonRow

		height: parent.height
		anchors.left: auxButton.visible ? auxButton.right : leftButton.right

		Repeater {
			id: pluginPaneButtons

			model: pluginQuickAccessModel

			delegate: StatusBarButton {
				id: pluginPaneButton

				required property int index
				required property string pluginName
				required property string title
				required property url url
				required property var capabilities
				required property var configuration
				readonly property url pluginIcon: pluginQuickAccessModel.integrationAt(index).icon
				readonly property url pluginIconActive: pluginQuickAccessModel.integrationAt(index).iconActive
				readonly property bool paneOpened: (Global.mainView?.cardsActive ?? false)
						&& Global.mainView.cardsLoader.sourceComponent === _paneComponent

				visible: !root.pageStack.opened
						&& (!(Global.mainView?.cardsActive ?? false) || paneOpened)
				enabled: visible
				leftInset: Theme.geometry_statusBar_spacing
				bottomInset: Theme.geometry_statusBar_spacing
				icon.cache: false
				icon.source: paneOpened && String(pluginIconActive).length > 0
						? pluginIconActive : pluginIcon

				KeyNavigation.left: index > 0 ? pluginPaneButtons.itemAt(index - 1) : auxButton
				KeyNavigation.right: index < pluginPaneButtons.count - 1
						? pluginPaneButtons.itemAt(index + 1) : webPagesButton

				onClicked: {
					if (paneOpened) {
						Global.mainView.cardsLoader.hide()
					} else {
						Global.mainView.cardsLoader.show(_paneComponent)
					}
				}

				onActiveFocusChanged: if (activeFocus) root.updateBreadcrumbsFocusHint()

				Component {
					id: _paneComponent

					Page {
						title: pluginPaneButton.title
						focusPolicy: Qt.TabFocus

						onActiveFocusChanged: {
							if (activeFocus && _paneContentLoader.item) {
								_paneContentLoader.item.forceActiveFocus()
							}
						}

						Loader {
							id: _paneContentLoader
							anchors.fill: parent
							Component.onCompleted: {
								const properties = {
									"partnerData": pluginPaneButton.capabilities.indexOf("readSystemData") >= 0
										? PartnerSystemData : ({})
								}
								if (pluginPaneButton.configuration?.dataBindings) {
									properties.configuration = pluginPaneButton.configuration
								}
								setSource(pluginPaneButton.url, properties)
							}
						}
					}
				}
			}
		}
	}

	StatusBarButton {
		id: webPagesButton

		// Always-available entry point to the registered-web-pages list
		// (VenusOS_GUIv2_Web_Content_and_Container_Proxy_Design,
		// venus-private#707) - not page-specific, unlike leftButton/auxButton.
		anchors {
			left: pluginButtonRow.right
			leftMargin: pluginPaneButtons.count > 0 ? 0 : -auxButton.rightInset
		}
		rightInset: Theme.geometry_statusBar_spacing
		bottomInset: Theme.geometry_statusBar_spacing

		enabled: visible
		visible: !root.pageStack.opened
				&& (!(Global.mainView?.cardsActive ?? false) || (Global.mainView?.webPagesActive ?? false))
		icon.source: "qrc:/images/icon_webpages_32.svg"
		KeyNavigation.left: pluginPaneButtons.count > 0
				? pluginPaneButtons.itemAt(pluginPaneButtons.count - 1) : auxButton
		KeyNavigation.right: breadcrumbs

		// Shown via cardsLoader (root.webPagesActivated(), relayed to
		// MainView's cardsLoader.show()), not pageManager.pushPage() - same
		// mechanism as auxButton/AuxCardsPage above, not a stacked page. A
		// pushed page always picks up a "Boat > ..." breadcrumb (Breadcrumbs.qml
		// shows one for any pageStack depth >= 1, regardless of which tab),
		// which read as "taken to Settings/Boat first" - the cards mechanism
		// has no such breadcrumb and also covers the nav bar while open,
		// matching how every other top-left-area button already behaves.
		onClicked: (Global.mainView?.webPagesActive ?? false)
				? root.cardsDeactivated() : root.webPagesActivated()
		onActiveFocusChanged: {
			if (activeFocus) {
				root.updateBreadcrumbsFocusHint()
			}
		}
	}

	Breadcrumbs {
		id: breadcrumbs

		anchors {
			top: parent.top
			topMargin: Theme.geometry_settings_breadcrumb_topMargin
			left: webPagesButton.right
			leftMargin: Theme.geometry_settings_breadcrumb_horizontalMargin
			right: rightButtonRow.left
		}
		pageStack: root.pageStack
		visible: !root.webNavigationActive && count >= 2

		KeyNavigation.right: wifiButton

		Rectangle { // fade out the breadcrumbs RHS when overflowing
			width: parent.width
			height: Theme.geometry_settings_breadcrumb_height
			visible: !parent.atXEnd

			gradient: Gradient {
				orientation: Gradient.Horizontal

				GradientStop {
					position: 1 - Theme.geometry_breadcrumbs_viewGradient_width
					color: Theme.color_viewGradient_color1
				}
				GradientStop {
					position: 1 - Theme.geometry_breadcrumbs_viewGradient_width / 2
					color: Theme.color_viewGradient_color2
				}
				GradientStop {
					position: 1
					color: Theme.color_viewGradient_color3
				}
			}
		}
	}

	Label {
		id: webNavigationTitle

		anchors {
			left: leftButton.right
			leftMargin: Theme.geometry_statusBar_spacing
			right: webHistoryBackButton.left
			rightMargin: Theme.geometry_statusBar_spacing
			verticalCenter: parent.verticalCenter
			verticalCenterOffset: -Theme.geometry_statusBar_spacing / 2
		}
		visible: root.webNavigationActive
		height: Theme.geometry_statusBar_button_height
		verticalAlignment: Text.AlignVCenter
		elide: Text.ElideRight
		font.pixelSize: Theme.font_size_body2
		text: Global.mainView.currentPage?.title ?? ""
	}

	StatusBarButton {
		id: webHistoryBackButton

		anchors {
			right: webHistoryForwardButton.left
			verticalCenter: parent.verticalCenter
			verticalCenterOffset: -Theme.geometry_statusBar_spacing / 2
		}
		visible: root.webNavigationActive
		// Keep this control clickable even if the asynchronous iframe history
		// state has not reached QML yet. The injected bridge safely ignores a
		// back request when the iframe has no earlier entry.
		enabled: visible
		icon.source: "qrc:/images/icon_back_32.svg"
		onClicked: Global.mainView.currentPage?.goBack()
	}

	StatusBarButton {
		id: webHistoryForwardButton

		anchors {
			right: rightButtonRow.left
			verticalCenter: parent.verticalCenter
			verticalCenterOffset: -Theme.geometry_statusBar_spacing / 2
		}
		visible: root.webNavigationActive
		// See webHistoryBackButton: availability is enforced by the iframe
		// bridge, avoiding a stale QML state from swallowing the click.
		enabled: visible
		icon.source: "qrc:/images/icon_back_32.svg"
		rotation: 180
		onClicked: Global.mainView.currentPage?.goForward()
	}

	Label {
		id: clockLabel
		anchors.centerIn: parent
		font.pixelSize: Theme.font_size_body2
		visible: !breadcrumbs.visible && !root.webNavigationActive
		text: ClockTime.currentTime
	}

	Row {
		id: connectivityRow

		anchors {
			left: clockLabel.right
			leftMargin: Theme.geometry_statusBar_spacing
			verticalCenter: parent.verticalCenter
		}
		visible: !breadcrumbs.visible && !root.webNavigationActive

		StatusBarButton {
			id: wifiButton

			opacity: enabled ? 1.0 : 0.0 //  Override fading icon on unit inactivity
			color: Theme.color_font_primary // Override base button color
			enabled: signalStrength.valid

			icon.source: !signalStrength.valid ? ""
				: signalStrength.value > 75 ? "qrc:/images/icon_WiFi_4_32.svg"
				: signalStrength.value > 50 ? "qrc:/images/icon_WiFi_3_32.svg"
				: signalStrength.value > 25 ? "qrc:/images/icon_WiFi_2_32.svg"
				: signalStrength.value > 0 ? "qrc:/images/icon_WiFi_1_32.svg"
				: "qrc:/images/icon_WiFi_noconnection_32.svg"

			KeyNavigation.right: mobileButton

			onClicked: Global.mainView.goToConnectivityPage("wifi")

			VeQuickItem {
				id: signalStrength

				uid: Global.venusPlatform.serviceUid +  "/Network/Wifi/SignalStrength"
			}
		}

		StatusBarButton {
			id: mobileButton

			opacity: enabled ? 1.0 : 0.0 //  Override fading icon on unit inactivity
			visible: mobileIcon.valid

			KeyNavigation.right: activityButton

			onClicked: Global.mainView.goToConnectivityPage("mobile")

			GsmStatusIcon {
				id: mobileIcon
				height: Theme.geometry_status_bar_gsmModem_icon_height
				anchors.centerIn: parent
			}
		}

		// Inside the Row (not a manually-anchored sibling like
		// notificationButton/alarmButton below) so its space collapses
		// automatically when not busy, same as mobileButton above.
		StatusBarButton {
			id: activityButton

			visible: Global.backgroundActivity?.busy ?? false
			enabled: visible
			// No dedicated "background activity" icon exists yet - reuses
			// the generic refresh glyph, with continuous rotation as the
			// "something is happening" cue a static icon can't give alone.
			icon.source: "qrc:/images/icon_refresh_32.svg"

			RotationAnimation on rotation {
				running: activityButton.visible && Global.animationEnabled
				loops: Animation.Infinite
				from: 0
				to: 360
				duration: 1500
			}

			KeyNavigation.right: notificationButton

			onClicked: Global.dialogLayer.open(backgroundActivityDialogComponent)

			Component {
				id: backgroundActivityDialogComponent

				BackgroundActivityDialog {}
			}
		}
	}

	StatusBarButton {
		id: notificationButton

		anchors {
			left: connectivityRow.right
			verticalCenter: parent.verticalCenter
		}
		// Expand clickable area on vertical and bottom edges.
		rightInset: Theme.geometry_statusBar_spacing / 2
		topInset: Theme.geometry_statusBar_spacing
		bottomInset: Theme.geometry_statusBar_spacing

		// The notificationButton should always be shown, even when the page is not interactive
		opacity: 1
		visible: !breadcrumbs.visible && !root.webNavigationActive
				&& (Global.notifications?.statusBarNotificationIconVisible ?? false)

		color: Global.notifications?.statusBarNotificationIconColor ?? "transparent"
		icon.source: Global.notifications?.statusBarNotificationIconSource ?? ""

		onClicked: Global.mainView.goToNotificationsPage()
		onActiveFocusChanged: {
			if (activeFocus) {
				root.updateBreadcrumbsFocusHint()
			}
		}

		KeyNavigation.right: alarmButton
	}

	SilenceAlarmButton {
		id: alarmButton

		anchors {
			left: notificationButton.right
			verticalCenter: parent.verticalCenter
		}
		width: Math.min(parent.width - x - rightButtonRow.width, implicitWidth)
		// Expand clickable area on horizontal and bottom edges.
		leftInset: Theme.geometry_statusBar_spacing / 2
		rightInset: Theme.geometry_statusBar_spacing / 2
		topInset: Theme.geometry_statusBar_spacing
		bottomInset: Theme.geometry_statusBar_spacing
		enabled: Global.mainView?.notificationButtonsEnabled
		visible: enabled

		onClicked: NotificationModel.acknowledgeAll()
		KeyNavigation.right: rightButton
	}

	GuiPluginIntegrationModel {
		id: pluginQuickAccessModel
		type: GuiPluginLoader.QuickAccessPane
	}

	Row {
		id: rightButtonRow

		height: parent.height
		anchors.right: parent.right

		StatusBarButton {
			id: rightButton

			readonly property int buttonType: Global.mainView?.currentPage?.topRightButton ?? VenusOS.StatusBar_RightButton_None

			// Expand clickable area on left and bottom edges.
			leftInset: Theme.geometry_statusBar_spacing
			bottomInset: Theme.geometry_statusBar_spacing

			enabled: buttonType != VenusOS.StatusBar_RightButton_None
			visible: enabled
			icon.source: buttonType === VenusOS.StatusBar_RightButton_SidePanelActive
						 ? "qrc:/images/icon_sidepanel_on_32.svg"
						 : buttonType === VenusOS.StatusBar_RightButton_SidePanelInactive
						   ? "qrc:/images/icon_sidepanel_off_32.svg"
						   : buttonType === VenusOS.StatusBar_RightButton_Add
							 ? "qrc:/images/icon_plus.svg"
							 : buttonType === VenusOS.StatusBar_RightButton_Refresh
							   ? "qrc:/images/icon_refresh_32.svg"
							   : ""
			KeyNavigation.left: pluginPaneButtons.count > 0
					? pluginPaneButtons.itemAt(pluginPaneButtons.count - 1) : alarmButton
			KeyNavigation.right: sleepButton

			onClicked: root.sidePanelToggled()
			onActiveFocusChanged: {
				if (activeFocus) {
					root.updateBreadcrumbsFocusHint()
				}
			}
		}

		StatusBarButton {
			id: sleepButton

			// Expand clickable area on right and bottom edges, and on left edge if right button is
			// hidden. This is the right-most button in the row, so on the right edge, use
			// Theme.geometry_statusBar_horizontalMargin instead of Theme.geometry_statusBar_spacing.
			leftInset: rightButton.visible || pluginPaneButtons.count > 0
					? 0 : Theme.geometry_statusBar_spacing
			rightInset: Theme.geometry_statusBar_horizontalMargin
			bottomInset: Theme.geometry_statusBar_spacing

			icon.source: "qrc:/images/icon_screen_sleep_32.svg"
			visible: ScreenBlanker.supported && ScreenBlanker.enabled

			onClicked: ScreenBlanker.setDisplayOff()
			onActiveFocusChanged: {
				if (activeFocus) {
					root.updateBreadcrumbsFocusHint()
				}
			}
		}
	}

	// The status bar should never become the focused item; if it does, it means there was no
	// previously focused button in the status bar, or the last focused button is now disabled and
	// not focusable. So, find the first available button and focus that instead.
	Connections {
		target: Global.main
		enabled: Global.keyNavigationEnabled
		function onActiveFocusItemChanged() {
			if (Global.main.activeFocusItem === root) {
				for (let i = 0; i < pluginPaneButtons.count; ++i) {
					const button = pluginPaneButtons.itemAt(i)
					if (button?.visible && button.enabled) {
						button.focus = true
						return
					}
				}
				for (const button of [leftButton, auxButton, webPagesButton, breadcrumbs, notificationButton, alarmButton, rightButton, sleepButton]) {
					if (button.enabled) {
						button.focus = true
						break
					}
				}
			}
		}
	}
}

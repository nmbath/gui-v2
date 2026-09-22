/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

/*
	Startup behaviour for one managed container: start automatically, startup
	delay and restart policy (venus-containers Drop 3 spec Section 14). Split
	out of PageSettingsContainer.qml's own Startup section and
	PageSettingsContainerResources.qml's Restart policy section, which is not
	really a resource limit and never applied to the aggregate sub-container
	Resources page (PageSettingsContainerResources.qml, isAggregate=true) that
	page definition is now shared with - grouping it here with the other
	startup-time behaviour instead reads more naturally either way.

	StartupDelay lives on com.victronenergy.settings, a *different* D-Bus
	service than com.victronenergy.containers - see the containerUuidSegment/
	settingsPrefix comment in PageSettingsContainer.qml for why this must be
	built from the settings service directly rather than by rewriting
	containerPrefix. StartOnBoot and RestartPolicy are both plain R/W leaves
	under the container's own /Lifecycle/* on com.victronenergy.containers.
*/
Page {
	id: root

	required property string containerPrefix

	readonly property string containerUuidSegment: containerPrefix.substring(containerPrefix.lastIndexOf("/") + 1)
	readonly property string settingsPrefix: BackendConnection.serviceUidForType("settings") + "/Settings/Containers/" + root.containerUuidSegment

	VeQuickItem { id: startOnBoot; uid: root.containerPrefix + "/Lifecycle/StartOnBoot" }
	VeQuickItem { id: startupDelay; uid: root.settingsPrefix + "/StartupDelay" }
	VeQuickItem { id: restartPolicy; uid: root.containerPrefix + "/Lifecycle/RestartPolicy" }

	GradientListView {
		model: VisibleItemModel {
			SettingsListHeader {
				//% "Startup"
				text: qsTrId("pagesettingscontainerstartup_startup")
			}

			ListSwitch {
				//% "Start automatically"
				text: qsTrId("pagesettingscontainerstartup_start_automatically")
				//% "Start after dbus-containers starts"
				caption: qsTrId("pagesettingscontainerstartup_start_automatically_caption")
				dataItem.uid: startOnBoot.uid
			}

			ListSlider {
				// ListSlider has no separate value-readout property (see
				// components/listitems/core/ListSlider.qml) - shown as
				// part of the label itself instead, e.g. "Delay: 15 s".
				//% "Delay: %1 s"
				text: qsTrId("pagesettingscontainerstartup_delay").arg(Math.round(value))
				//% "Staggering prevents several heavy applications from starting together after a GX reboot or service restart."
				caption: qsTrId("pagesettingscontainerstartup_delay_caption")
				dataItem.uid: startupDelay.uid
				from: 0
				to: 120
				stepSize: 1
				// Wire type for StartOnBoot is Int32, not a genuine boolean.
				preferredVisible: !!startOnBoot.value
			}

			SettingsListHeader {
				//% "Restart policy"
				text: qsTrId("pagesettingscontainerstartup_restart_policy")
			}

			ListRadioButtonGroup {
				//% "Restart policy"
				text: qsTrId("pagesettingscontainerstartup_restart_policy")
				dataItem.uid: restartPolicy.uid
				optionModel: Containers.restartPolicyOptions()
			}
		}
	}
}

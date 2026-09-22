/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

/*
	One sub-container's own detail page, reached from
	PageSettingsContainerSubcontainers.qml's child list. Split out from that
	list so a managed child's Pull policy - the one genuinely editable field
	either ownership mode has (docs/dbus-api.md note 7) - has its own place
	to live instead of being squeezed inline under the child's row in the
	flat aggregate list, which read as though it belonged to whichever
	child happened to be drawn above or below it.

	Covers both ownership modes the same way the list page's own delegate
	did: root.isManaged (Children/Mode) is still the one flag everything
	here branches on. Deliberately no start/stop/restart/delete action for
	either mode - same reasoning as the list page's own footer note, which
	still applies here (docs/dbus-api.md notes 3/6).
*/
Page {
	id: root

	required property string childPrefix
	required property bool isManaged

	VeQuickItem { id: image; uid: root.childPrefix + "/Image" }
	VeQuickItem { id: runtimeId; uid: root.childPrefix + "/RuntimeId" }
	VeQuickItem { id: running; uid: root.childPrefix + "/Running" }
	VeQuickItem { id: childState; uid: root.childPrefix + "/State" }
	VeQuickItem { id: errorCode; uid: root.childPrefix + "/ErrorCode" }
	VeQuickItem { id: error; uid: root.childPrefix + "/Error" }
	VeQuickItem { id: pullPolicy; uid: root.childPrefix + "/Image/PullPolicy" }

	GradientListView {
		model: VisibleItemModel {
			SettingsListHeader {
				//% "Status"
				text: qsTrId("pagesettingscontainer_status")
			}

			ListText {
				//% "Status"
				text: qsTrId("pagesettingscontainer_status")
				secondaryText: root.isManaged
						? Containers.stateToText(childState.value)
						: Containers.childStateToText(running.value)
			}

			// Managed mode only - a runtime-mode child publishes no error
			// leaves of its own (docs/dbus-api.md note 6).
			PrimaryListLabel {
				//% "Error: %1"
				text: qsTrId("pagesettingscontainer_error").arg(error.value || "")
				preferredVisible: root.isManaged && errorCode.value !== 0 && !!error.value
			}

			SettingsListHeader {
				//% "Configuration"
				text: qsTrId("pagesettingscontainersubcontainers_configuration")
				preferredVisible: root.isManaged
			}

			// Managed mode only - governs a future pull, never anything
			// already running, so it carries none of the lifecycle-control
			// risk the list page's own footer note is about (docs/dbus-
			// api.md note 7).
			ListRadioButtonGroup {
				//% "Pull policy"
				text: qsTrId("pagesettingscontainersubcontainers_pull_policy")
				dataItem.uid: pullPolicy.uid
				optionModel: Containers.pullPolicyOptions()
				preferredVisible: root.isManaged
			}

			SettingsListHeader {
				//% "Information"
				text: qsTrId("pagesettingscontainer_information")
			}

			ListText {
				//% "Image"
				text: qsTrId("pagesettingscontainer_image")
				secondaryText: image.value || ""
			}

			ListText {
				//% "Runtime ID"
				text: qsTrId("pagesettingscontainer_runtime_id")
				secondaryText: runtimeId.value || ""
				showAccessLevel: VenusOS.User_AccessType_SuperUser
				preferredVisible: !!runtimeId.value
			}
		}
	}
}

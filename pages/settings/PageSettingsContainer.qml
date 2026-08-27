/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

/*
	One managed container's detail page (venus-containers Drop 3 spec
	Section 14, concept mock-ups 3 and 7 (failure/recovery)).

	Delete has no dedicated D-Bus method or trigger-path: it is
	DesiredState=2 (Deleted) written to the settings path Start/Stop
	already use for 0/1 - see docs/dbus-api.md in the venus-containers
	repo. Restart is implemented the same way the CLI's own `restart`
	command is (stop, then start) rather than via a dedicated trigger-path,
	since a plain re-write of DesiredState=Running when it is already 1 is
	a no-op (SetValue only calls back on an actual value change) - this
	also doubles as the recovery action for a container stuck in Error
	after exceeding its restart-loop limit (mock-up 7), or WaitingForDependency
	(state 8, Group F proxy-readiness work) - a manual "try now" that
	bypasses the pending backoff - where desired state is already Running
	but nothing is retrying it (or retrying on its own schedule).
*/
Page {
	id: root

	required property string containerPrefix

	// DesiredState/StartupDelay live on com.victronenergy.settings, a
	// *different* D-Bus service than com.victronenergy.containers -
	// containerPrefix.replace("/Containers/", "/Settings/Containers/") only
	// ever rewrote the path, never the service name, so it produced a
	// nonsense uid still addressed to com.victronenergy.containers
	// (confirmed live: "ignoring request ... (not online)" on every
	// setValue) - every Start/Stop/Restart and startup-delay write has been
	// silently failing since this page was written. Build the settings uid
	// from the settings service directly instead of mangling this one.
	readonly property string containerUuidSegment: containerPrefix.substring(containerPrefix.lastIndexOf("/") + 1)
	readonly property string settingsPrefix: BackendConnection.serviceUidForType("settings") + "/Settings/Containers/" + root.containerUuidSegment
	readonly property bool isRunning: state.value === 4 // ContainerState.Running, see Containers.qml

	VeQuickItem { id: state; uid: root.containerPrefix + "/State" }
	VeQuickItem { id: statusText; uid: root.containerPrefix + "/Status" }
	VeQuickItem { id: image; uid: root.containerPrefix + "/Image" }
	VeQuickItem { id: runtimeId; uid: root.containerPrefix + "/RuntimeId" }
	VeQuickItem { id: uptime; uid: root.containerPrefix + "/Uptime" }
	VeQuickItem { id: restartCount; uid: root.containerPrefix + "/RestartCount" }
	VeQuickItem { id: errorCode; uid: root.containerPrefix + "/ErrorCode" }
	VeQuickItem { id: errorText; uid: root.containerPrefix + "/Error" }
	VeQuickItem { id: dbusState; uid: root.containerPrefix + "/Dbus/State" }
	VeQuickItem { id: dbusErrorText; uid: root.containerPrefix + "/Dbus/Error" }
	VeQuickItem { id: dependency; uid: root.containerPrefix + "/Dependency" }
	VeQuickItem { id: retryIn; uid: root.containerPrefix + "/RetryIn" }
	VeQuickItem { id: memoryLimit; uid: root.containerPrefix + "/Resources/MemoryLimit" }
	VeQuickItem { id: cpuLimit; uid: root.containerPrefix + "/Resources/CpuLimit" }
	VeQuickItem { id: startOnBoot; uid: root.containerPrefix + "/Lifecycle/StartOnBoot" }
	VeQuickItem { id: startupDelay; uid: root.settingsPrefix + "/StartupDelay" }
	VeQuickItem { id: desiredState; uid: root.settingsPrefix + "/DesiredState" }

	// Forces a real value change (0 then 1) rather than a same-value
	// no-op write - see module docstring.
	Timer {
		id: restartTimer
		interval: 500
		onTriggered: desiredState.setValue(1)
	}

	function restart() {
		desiredState.setValue(0)
		restartTimer.start()
	}

	GradientListView {
		model: VisibleItemModel {
			SettingsListHeader {
				//% "Status"
				text: qsTrId("pagesettingscontainer_status")
			}

			ListText {
				//% "Status"
				text: qsTrId("pagesettingscontainer_status")
				secondaryText: Containers.stateToText(state.value)
				// /Status (docs/dbus-api.md) only ever carries detail the
				// bare /State enum can't - the container's own restart-loop
				// progress ("restart attempt 2 of 5") while it's still
				// trying to recover, in particular, which otherwise has no
				// representation in this page at all. Empty (and so
				// invisible - captionText only reflows the layout when
				// non-empty, see ListText.qml) whenever there's nothing to
				// add beyond the state text above.
				caption: statusText.value
			}

			PrimaryListLabel {
				//% "Error: %1"
				text: qsTrId("pagesettingscontainer_error").arg(errorText.value)
				preferredVisible: errorCode.value !== 0 && !!errorText.value
			}

			// Waiting to start (state 8): not an error - self-recovers as
			// soon as the dependency is Ready - but the bare state text
			// alone gives no reason and no sense of progress. Names what
			// it's waiting for and counts down to the next retry (spec
			// v14's suggested GUI wording), and offers Restart below as an
			// explicit "try now" action for anyone who doesn't want to wait
			// out the backoff.
			ListText {
				//% "Waiting to start"
				text: qsTrId("pagesettingscontainer_waiting_for_dependency")
				caption: Containers.waitingForDependencyText(dependency.value, retryIn.value)
				preferredVisible: state.value === 8 // ContainerState.WaitingForDependency
			}

			// Degraded while Running (Dbus/State Unavailable): the workload
			// itself is fine and was deliberately left running - only its
			// D-Bus link is down. Restarting the container would not fix
			// an external proxy outage, so no action is offered here; it
			// clears itself automatically once the proxy is Ready again.
			ListText {
				//% "D-Bus unavailable"
				text: qsTrId("pagesettingscontainer_dbus_unavailable")
				secondaryText: dbusErrorText.value
				//% "Will reconnect automatically once the D-Bus proxy is available again"
				caption: qsTrId("pagesettingscontainer_dbus_unavailable_caption")
				preferredVisible: root.isRunning && dbusState.value === 3 // DbusState.Unavailable
			}

			SettingsListHeader {
				//% "Startup"
				text: qsTrId("pagesettingscontainer_startup")
			}

			ListSwitch {
				//% "Start automatically"
				text: qsTrId("pagesettingscontainer_start_automatically")
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
				//% "Control"
				text: qsTrId("pagesettingscontainer_control")
			}

			ListSwitch {
				//% "Running"
				text: qsTrId("pagesettingscontainer_running")
				// checked is derived from observed state (not desiredState)
				// so it reflects reality even when they briefly disagree
				// during a transition - same manual checked/onClicked
				// pattern as the Unlimited-memory switch on the Resources
				// page (ListSwitch.qml's own docstring, option 2).
				checked: root.isRunning
				onClicked: {
					if (checked) {
						desiredState.setValue(0)
					} else if (desiredState.value === 1) {
						// Already desired Running but not actually Running
						// (stuck after exceeding the restart-loop limit,
						// mock-up 7 - or WaitingForDependency, state 8): a
						// re-write to 1 would be a no-op, so force a
						// restart instead. For WaitingForDependency this
						// also bypasses the pending backoff (Stop clears
						// the wait, then Start re-checks the dependency
						// immediately - see reconciler.py's
						// _reconcile_stopped/_clear_dependency_wait).
						root.restart()
					} else {
						desiredState.setValue(1)
					}
				}
			}

			ListButton {
				// text/secondaryText split matches PageDebug.qml's Quit
				// button and the Delete button below ("Restart container"
				// label, "Restart" on the button). Also offered while
				// WaitingForDependency (state 8) as the explicit "try now"
				// action from the caption above, since root.restart()
				// already bypasses the pending backoff for that state too
				// (see the Running switch's onClicked comment above).
				//% "Restart container"
				text: qsTrId("pagesettingscontainer_restart_container")
				//% "Restart"
				secondaryText: qsTrId("pagesettingscontainer_restart")
				preferredVisible: root.isRunning || state.value === 8
				onClicked: root.restart()
			}

			ListNavigation {
				//% "Resource limits"
				text: qsTrId("pagesettingscontainer_resource_limits")
				//% "Memory %1, CPU %2"
				secondaryText: qsTrId("pagesettingscontainer_resource_limits_summary")
						.arg(Containers.memoryLimitToText(memoryLimit.value))
						.arg(Containers.cpuLimitToText(cpuLimit.value))
				// title: text (this row's own "Resource limits" label, not
				// root.title) - passing the container page's own title here
				// duplicated it in the breadcrumb instead of showing the
				// sub-page's own name (Containers > node-red > node-red
				// instead of Containers > node-red > Resource limits).
				onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsContainerResources.qml",
						{"title": text, "containerPrefix": root.containerPrefix})
			}

			ListButton {
				// text/secondaryText split matches PageDebug.qml's Quit
				// button ("Quit application" label, "Quit" on the button).
				//% "Delete container"
				text: qsTrId("pagesettingscontainer_delete_container")
				//% "Delete"
				secondaryText: qsTrId("pagesettingscontainer_delete")
				//% "Definition is retained for restore"
				caption: qsTrId("pagesettingscontainer_delete_caption")
				writeAccessLevel: VenusOS.User_AccessType_Installer
				// ListButton.click() (components/listitems/core/ListButton.qml)
				// already gates on checkWriteAccessLevel() before this signal
				// fires - no need to call it again here, same as the running
				// switch above.
				onClicked: Global.dialogLayer.open(deleteConfirmationDialogComponent)

				Component {
					id: deleteConfirmationDialogComponent

					ModalWarningDialog {
						//% "Delete container?"
						title: qsTrId("pagesettingscontainer_delete_confirm_title")
						//% "The container will be stopped and removed. Its definition is kept, so it can be restored later from the CLI."
						description: qsTrId("pagesettingscontainer_delete_confirm_description")
						dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
						onAccepted: {
							desiredState.setValue(2)
							Global.pageManager.popPage()
						}
					}
				}
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

			ListText {
				//% "Uptime"
				text: qsTrId("pagesettingscontainer_uptime")
				secondaryText: Utils.secondsToString(uptime.value, false)
				preferredVisible: root.isRunning
			}

			ListText {
				//% "Restart count"
				text: qsTrId("pagesettingscontainer_restart_count")
				secondaryText: restartCount.value
			}
		}
	}
}

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

	// DesiredState (and, on the Startup Options page, StartupDelay) live on
	// com.victronenergy.settings, a *different* D-Bus service than
	// com.victronenergy.containers -
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
	readonly property bool isDeleted: state.value === 7 // ContainerState.Deleted

	VeQuickItem { id: state; uid: root.containerPrefix + "/State" }
	VeQuickItem { id: statusText; uid: root.containerPrefix + "/Status" }
	VeQuickItem { id: image; uid: root.containerPrefix + "/Image" }
	VeQuickItem { id: pullPolicy; uid: root.containerPrefix + "/Image/PullPolicy" }
	VeQuickItem { id: runtimeId; uid: root.containerPrefix + "/RuntimeId" }
	VeQuickItem { id: uptime; uid: root.containerPrefix + "/Uptime" }
	VeQuickItem { id: restartCount; uid: root.containerPrefix + "/RestartCount" }
	VeQuickItem { id: errorCode; uid: root.containerPrefix + "/ErrorCode" }
	VeQuickItem { id: errorText; uid: root.containerPrefix + "/Error" }
	VeQuickItem { id: dbusState; uid: root.containerPrefix + "/Dbus/State" }
	VeQuickItem { id: dbusErrorText; uid: root.containerPrefix + "/Dbus/Error" }
	VeQuickItem { id: dependency; uid: root.containerPrefix + "/Dependency" }
	VeQuickItem { id: retryIn; uid: root.containerPrefix + "/RetryIn" }
	VeQuickItem { id: memoryUsage; uid: root.containerPrefix + "/Resources/MemoryUsage" }
	VeQuickItem { id: memoryLimit; uid: root.containerPrefix + "/Resources/MemoryLimit" }
	VeQuickItem { id: cpuUsage; uid: root.containerPrefix + "/Resources/CpuUsage" }
	VeQuickItem { id: cpuLimit; uid: root.containerPrefix + "/Resources/CpuLimit" }
	VeQuickItem { id: pids; uid: root.containerPrefix + "/Resources/Pids" }
	VeQuickItem { id: pidsLimit; uid: root.containerPrefix + "/Resources/PidsLimit" }
	VeQuickItem { id: diskTotal; uid: root.containerPrefix + "/DiskUsage/TotalBytes" }
	VeQuickItem { id: diskImage; uid: root.containerPrefix + "/DiskUsage/ImageBytes" }
	VeQuickItem { id: diskLocal; uid: root.containerPrefix + "/DiskUsage/ExclusiveBytes" }
	VeQuickItem { id: diskHostTotal; uid: root.containerPrefix + "/DiskUsage/HostTotalBytes" }
	VeQuickItem { id: diskHostUsed; uid: root.containerPrefix + "/DiskUsage/HostUsedBytes" }
	VeQuickItem { id: diskUpdatedAt; uid: root.containerPrefix + "/DiskUsage/UpdatedAt" }
	VeQuickItem { id: desiredState; uid: root.settingsPrefix + "/DesiredState" }
	VeQuickItem { id: startOnBoot; uid: root.containerPrefix + "/Lifecycle/StartOnBoot" }
	VeQuickItem { id: purge; uid: root.containerPrefix + "/Admin/Purge" }
	VeQuickItem { id: containerRuntimeEnabled; uid: root.containerPrefix + "/ContainerRuntime/Enabled" }
	// Unified across both child ownership modes (docs/dbus-api.md note 5) -
	// Mode is "", "managed" or "runtime"; Count/Running cover either shape
	// through the one path, replacing the older ContainerRuntime/Children/*
	// equivalent this row used to read (still published, just runtime-mode
	// only, so no longer sufficient on its own to decide this row's
	// visibility).
	VeQuickItem { id: childrenMode; uid: root.containerPrefix + "/Children/Mode" }
	VeQuickItem { id: childrenCount; uid: root.containerPrefix + "/Children/TotalCount" }
	VeQuickItem { id: childrenRunning; uid: root.containerPrefix + "/Children/RunningCount" }
	// HostIdentity/* still publishes empty-string sentinels until the
	// extensionidentities integration lands (docs/dbus-api.md note 1) - the
	// caption below is simply blank on real hardware until then, not broken.
	VeQuickItem { id: hostIdentityName; uid: root.containerPrefix + "/HostIdentity/Name" }

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

	// CpuUsage is a percentage (100% = one full logical CPU busy for the
	// sample period, backend/podman.py in venus-containers) while CpuLimit
	// is in cores - same conversion PageSettingsContainerSubcontainers.qml
	// already applies for its own aggregate gauges, needed here for the
	// same reason: comparing a percentage against a core count directly
	// would be meaningless.
	readonly property real cpuUsageCores: cpuUsage.value / 100

	GradientListView {
		model: VisibleItemModel {
			SettingsListHeader {
				//% "Current usage"
				text: qsTrId("pagesettingscontainer_current_usage")
				preferredVisible: !root.isDeleted
			}

			ListResourceGauge {
				//% "Memory"
				text: qsTrId("pagesettingscontainerresources_memory")
				//% "%1 MB / %2 MB"
				valueText: qsTrId("pagesettingscontainerresources_memory_usage_value")
						.arg(Containers.bytesToMebibytes(memoryUsage.value)).arg(Containers.bytesToMebibytes(memoryLimit.value))
				value: memoryUsage.value
				to: memoryLimit.value
				preferredVisible: !root.isDeleted
			}

			ListResourceGauge {
				//% "CPU"
				text: qsTrId("pagesettingscontainerresources_cpu")
				//% "%1 / %2"
				valueText: qsTrId("pagesettingscontainerresources_cpu_usage_value")
						.arg(root.cpuUsageCores.toFixed(2)).arg(cpuLimit.value)
				value: root.cpuUsageCores
				to: cpuLimit.value
				preferredVisible: !root.isDeleted
			}

			ListResourceGauge {
				//% "Processes"
				text: qsTrId("pagesettingscontainerresources_processes")
				//% "%1 / %2"
				valueText: qsTrId("pagesettingscontainerresources_pids_usage_value").arg(pids.value).arg(pidsLimit.value)
				value: pids.value
				to: pidsLimit.value
				preferredVisible: !root.isDeleted
			}

			SettingsListHeader {
				//% "Disk usage"
				text: qsTrId("pagesettingscontainer_disk_usage")
				// DiskUsage/UpdatedAt is 0 until the first periodic sample -
				// same "pending" convention vcm show/list already use,
				// see cli.py's _format_disk_usage.
				preferredVisible: !root.isDeleted && !!diskUpdatedAt.value
			}

			ListText {
				//% "Total"
				text: qsTrId("pagesettingscontainer_disk_total")
				secondaryText: Containers.formatBytes(diskTotal.value)
				preferredVisible: !root.isDeleted && !!diskUpdatedAt.value
			}

			ListText {
				//% "Image"
				text: qsTrId("pagesettingscontainer_disk_image")
				secondaryText: Containers.formatBytes(diskImage.value)
				preferredVisible: !root.isDeleted && !!diskUpdatedAt.value
			}

			ListText {
				//% "Local"
				text: qsTrId("pagesettingscontainer_disk_local")
				secondaryText: Containers.formatBytes(diskLocal.value)
				//% "Writable layer + managed storage - the part unique to this container"
				caption: qsTrId("pagesettingscontainer_disk_local_caption")
				preferredVisible: !root.isDeleted && !!diskUpdatedAt.value
			}

			ListResourceGauge {
				//% "Disk (host)"
				text: qsTrId("pagesettingscontainer_disk_host")
				//% "%1 used of %2 (%3)"
				valueText: qsTrId("pagesettingscontainer_disk_host_value")
						.arg(Containers.formatBytes(diskHostUsed.value))
						.arg(Containers.formatBytes(diskHostTotal.value))
						.arg(diskHostTotal.value > 0
							? Math.round(diskHostUsed.value / diskHostTotal.value * 100) + "%"
							: "-")
				//% "How full the disk this container's own storage lives on actually is - usually the same for every container, since most share one disk."
				caption: qsTrId("pagesettingscontainer_disk_host_caption")
				value: diskHostUsed.value
				to: diskHostTotal.value
				preferredVisible: !root.isDeleted && !!diskUpdatedAt.value && diskHostTotal.value > 0
			}

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
				// add beyond the state text above, or while an error is
				// active - the PrimaryListLabel below already covers that
				// case with a properly labelled, retry-aware summary, and
				// /Status carries the same raw text /Error does once
				// there's an active error (confirmed live on a
				// raspberrypi5 test device, 2026-09-02: a pull failure's
				// full multi-line "Copying blob sha256:..." capture showed
				// up in both places at once). firstMeaningfulLine collapses
				// that raw text to its one meaningful line either way, in
				// case a future backend change ever populates /Status with
				// multi-line detail while /ErrorCode is still 0.
				caption: errorCode.value !== 0 ? "" : Containers.firstMeaningfulLine(statusText.value)
			}

			PrimaryListLabel {
				//% "Error: %1"
				text: qsTrId("pagesettingscontainer_error")
						.arg(Containers.errorSummaryText(errorCode.value, errorText.value, retryIn.value))
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
				//% "Configuration"
				text: qsTrId("pagesettingscontainer_configuration")
				preferredVisible: !root.isDeleted
			}

			ListNavigation {
				//% "Resources"
				text: qsTrId("pagesettingscontainer_resources")
				//% "Memory %1, %2"
				secondaryText: qsTrId("pagesettingscontainer_resource_limits_summary")
						.arg(Containers.memoryLimitToText(memoryLimit.value))
						.arg(Containers.cpuLimitToText(cpuLimit.value))
				preferredVisible: !root.isDeleted
				// title: text (this row's own label, not root.title) -
				// passing the container page's own title here duplicated it
				// in the breadcrumb instead of showing the sub-page's own
				// name (Containers > node-red > node-red instead of
				// Containers > node-red > Resources).
				onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsContainerResources.qml",
						{"title": text, "containerPrefix": root.containerPrefix})
			}

			ListNavigation {
				//% "Startup Options"
				text: qsTrId("pagesettingscontainer_startup_options")
				preferredVisible: !root.isDeleted
				onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsContainerStartup.qml",
						{"title": text, "containerPrefix": root.containerPrefix})
			}

			ListNavigation {
				//% "Sub-containers"
				text: qsTrId("pagesettingscontainer_subcontainers")
				secondaryText: Containers.childRunningSummaryText(childrenRunning.value, childrenCount.value)
				// Only the runtime-mode case has its own dedicated identity
				// worth calling out - a managed-mode container's children
				// run under whatever identity the parent itself already
				// has (shared or dedicated), not a separate one of their
				// own, so there is nothing extra to surface here for it.
				//% "Dedicated runtime identity: %1"
				caption: containerRuntimeEnabled.value && hostIdentityName.value
						? qsTrId("pagesettingscontainer_subcontainers_identity_caption").arg(hostIdentityName.value) : ""
				// Wire type for ContainerRuntime/Enabled is Int32, not a
				// genuine boolean (docs/dbus-api.md note 3) - published for
				// every container, 0/Unavailable for the overwhelming
				// majority that never request the capability. Children/Mode
				// (docs/dbus-api.md note 5) covers the managed-mode case the
				// same way - "" for the overwhelming majority with no
				// children of either kind - so this row is absent for
				// almost every container either way.
				preferredVisible: !root.isDeleted && (!!containerRuntimeEnabled.value || childrenMode.value === "managed")
				onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsContainerSubcontainers.qml",
						{"title": text, "containerPrefix": root.containerPrefix})
			}

			SettingsListHeader {
				//% "Control"
				text: qsTrId("pagesettingscontainer_control")
				preferredVisible: !root.isDeleted
			}

			ListButton {
				// text/secondaryText split matches the Restart/Delete
				// buttons below ("Stop container" label, "Stop" on the
				// button).
				//% "Stop container"
				text: qsTrId("pagesettingscontainer_stop_container")
				//% "Stop"
				secondaryText: qsTrId("pagesettingscontainer_stop")
				preferredVisible: !root.isDeleted && root.isRunning
				onClicked: desiredState.setValue(0)
			}

			ListButton {
				//% "Start container"
				text: qsTrId("pagesettingscontainer_start_container")
				//% "Start"
				secondaryText: qsTrId("pagesettingscontainer_start")
				preferredVisible: !root.isDeleted && !root.isRunning
				onClicked: {
					if (desiredState.value === 1) {
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
				// Also offered while WaitingForDependency (state 8) as the
				// explicit "try now" action from the Waiting caption above,
				// since root.restart() already bypasses the pending backoff
				// for that state too (see the Start button's onClicked
				// comment above).
				//% "Restart container"
				text: qsTrId("pagesettingscontainer_restart_container")
				//% "Restart"
				secondaryText: qsTrId("pagesettingscontainer_restart")
				preferredVisible: !root.isDeleted && (root.isRunning || state.value === 8)
				onClicked: root.restart()
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
				preferredVisible: !root.isDeleted
				// ListButton.click() (components/listitems/core/ListButton.qml)
				// already gates on checkWriteAccessLevel() before this signal
				// fires - no need to call it again here, same as the Stop/
				// Start/Restart buttons above.
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
				//% "Recovery"
				text: qsTrId("pagesettingscontainer_recovery")
				preferredVisible: root.isDeleted
			}

			ListButton {
				//% "Restore container"
				text: qsTrId("pagesettingscontainer_restore_container")
				//% "Restore"
				secondaryText: qsTrId("pagesettingscontainer_restore")
				//% "Recreates the container from its retained definition"
				caption: qsTrId("pagesettingscontainer_restore_caption")
				preferredVisible: root.isDeleted
				writeAccessLevel: VenusOS.User_AccessType_Installer
				onClicked: {
					desiredState.setValue(startOnBoot.value ? 1 : 0)
					Global.pageManager.popPage()
				}
			}

			ListButton {
				//% "Permanently remove container"
				text: qsTrId("pagesettingscontainer_purge_container")
				//% "Purge"
				secondaryText: qsTrId("pagesettingscontainer_purge")
				//% "Removes the definition, identity and all managed storage"
				caption: qsTrId("pagesettingscontainer_purge_caption")
				preferredVisible: root.isDeleted
				writeAccessLevel: VenusOS.User_AccessType_Installer
				onClicked: Global.dialogLayer.open(purgeConfirmationDialogComponent)

				Component {
					id: purgeConfirmationDialogComponent

					ModalWarningDialog {
						//% "Permanently remove container?"
						title: qsTrId("pagesettingscontainer_purge_confirm_title")
						//% "The retained definition, identity and all managed storage will be permanently removed. This cannot be undone."
						description: qsTrId("pagesettingscontainer_purge_confirm_description")
						dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
						onAccepted: {
							purge.setValue(1)
							Global.pageManager.popPage()
						}
					}
				}
			}

			SettingsListHeader {
				//% "Information"
				text: qsTrId("pagesettingscontainer_information")
				preferredVisible: !root.isDeleted
			}

			ListText {
				//% "Image"
				text: qsTrId("pagesettingscontainer_image")
				secondaryText: image.value || ""
				preferredVisible: !root.isDeleted
			}

			ListRadioButtonGroup {
				//% "Pull policy"
				text: qsTrId("pagesettingscontainer_pull_policy")
				dataItem.uid: pullPolicy.uid
				optionModel: Containers.pullPolicyOptions()
				preferredVisible: !root.isDeleted
			}

			ListText {
				//% "Runtime ID"
				text: qsTrId("pagesettingscontainer_runtime_id")
				secondaryText: runtimeId.value || ""
				showAccessLevel: VenusOS.User_AccessType_SuperUser
				preferredVisible: !root.isDeleted && !!runtimeId.value
			}

			ListText {
				//% "Uptime"
				text: qsTrId("pagesettingscontainer_uptime")
				secondaryText: Utils.secondsToString(uptime.value, false)
				preferredVisible: !root.isDeleted && root.isRunning
			}

			ListText {
				//% "Restart count"
				text: qsTrId("pagesettingscontainer_restart_count")
				secondaryText: restartCount.value
				preferredVisible: !root.isDeleted
			}
		}
	}
}

/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

pragma Singleton

import QtQml
import Victron.VenusOS

/*
	Shared text for the venus-containers integration (Settings > Integrations
	> Containers). Numeric values match docs/dbus-api.md in the
	venus-containers repo exactly - ServiceState 0..3, ContainerState 0..9,
	DbusState 0..3, DbusProxyState 0..2.
*/
QtObject {
	id: root

	function serviceStateToText(value) {
		switch (value) {
		//% "Initialising"
		case 0: return qsTrId("containers_service_state_initialising")
		//% "Running"
		case 1: return qsTrId("containers_service_state_running")
		//% "Degraded"
		case 2: return qsTrId("containers_service_state_degraded")
		//% "Error"
		case 3: return qsTrId("containers_service_state_error")
		default: return ""
		}
	}

	// DbusProxyState (docs/dbus-api.md) - a distinct enum from ServiceState
	// above, not the same 0/1/2 meanings even though the numbers overlap.
	// /DbusProxy/State used to just reuse ServiceState.Ready/Error before
	// the Group F proxy-readiness work split it into its own enum; this
	// function was missing entirely, so PageSettingsContainerService.qml
	// was mislabelling it via serviceStateToText (e.g. Ready showed as
	// "Running", Unavailable showed as "Degraded").
	function dbusProxyStateToText(value) {
		switch (value) {
		//% "Unknown"
		case 0: return qsTrId("containers_dbus_proxy_state_unknown")
		//% "Ready"
		case 1: return qsTrId("containers_dbus_proxy_state_ready")
		//% "Unavailable"
		case 2: return qsTrId("containers_dbus_proxy_state_unavailable")
		default: return ""
		}
	}

	// Per-container Dbus/State (docs/dbus-api.md).
	function dbusStateToText(value) {
		switch (value) {
		//% "Disabled"
		case 0: return qsTrId("containers_dbus_state_disabled")
		//% "Waiting"
		case 1: return qsTrId("containers_dbus_state_waiting")
		//% "Available"
		case 2: return qsTrId("containers_dbus_state_available")
		//% "Unavailable"
		case 3: return qsTrId("containers_dbus_state_unavailable")
		default: return ""
		}
	}

	// A registered dependency name (currently only "DbusProxy") as shown to
	// the supplier/installer - kept separate from the wire value so new
	// dependency kinds can be added later without a schema change here.
	function dependencyToText(name) {
		switch (name) {
		//% "the D-Bus proxy"
		case "DbusProxy": return qsTrId("containers_dependency_dbus_proxy")
		default: return name
		}
	}

	function stateToText(value) {
		switch (value) {
		//% "Missing"
		case 0: return qsTrId("containers_state_missing")
		//% "Creating"
		case 1: return qsTrId("containers_state_creating")
		//% "Stopped"
		case 2: return qsTrId("containers_state_stopped")
		//% "Starting"
		case 3: return qsTrId("containers_state_starting")
		//% "Running"
		case 4: return qsTrId("containers_state_running")
		//% "Stopping"
		case 5: return qsTrId("containers_state_stopping")
		//% "Recreating"
		case 6: return qsTrId("containers_state_recreating")
		//% "Deleted"
		case 7: return qsTrId("containers_state_deleted")
		//% "Waiting to start"
		case 8: return qsTrId("containers_state_waiting_for_dependency")
		//% "Failed"
		case 9: return qsTrId("containers_state_failed")
		default: return ""
		}
	}

	// Richer than stateToText(8) alone: names what it's waiting on and,
	// once RetryIn is known, when it'll try again - spec v14's suggested
	// GUI wording ("Waiting to start - D-Bus proxy unavailable - retry in
	// Xs"). RetryIn is authoritative and server-computed; this only
	// formats it, never calculates it (docs/dbus-api.md).
	function waitingForDependencyText(dependency, retryInSeconds) {
		if (!dependency) {
			//% "Waiting to start"
			return qsTrId("containers_waiting_for_dependency_caption_unknown")
		}
		if (retryInSeconds > 0) {
			//% "Waiting for %1 - retry in %2s"
			return qsTrId("containers_waiting_for_dependency_caption_retry")
					.arg(root.dependencyToText(dependency)).arg(retryInSeconds)
		}
		//% "Waiting for %1"
		return qsTrId("containers_waiting_for_dependency_caption").arg(root.dependencyToText(dependency))
	}

	readonly property var _restartPolicyOptions: [
		//% "Never"
		{ display: qsTrId("containers_restart_policy_none"), value: "none" },
		//% "On failure"
		{ display: qsTrId("containers_restart_policy_on_failure"), value: "on-failure" },
		//% "Always"
		{ display: qsTrId("containers_restart_policy_always"), value: "always" },
	]

	function restartPolicyOptions() {
		return root._restartPolicyOptions
	}

	function restartPolicyToText(value) {
		for (let i = 0; i < root._restartPolicyOptions.length; ++i) {
			if (root._restartPolicyOptions[i].value === value) {
				return root._restartPolicyOptions[i].display
			}
		}
		return value
	}

	// image.pullPolicy (schema.py) - governs a future pull only, never
	// anything already running (reconciler.py's update_pull_policy/
	// update_child_pull_policy docstrings). Managed containers/children
	// only - a runtime-mode child has no definition of its own for this
	// to edit (docs/dbus-api.md note 7).
	readonly property var _pullPolicyOptions: [
		//% "If missing"
		{ display: qsTrId("containers_pull_policy_if_missing"), value: "if-missing" },
		//% "Always"
		{ display: qsTrId("containers_pull_policy_always"), value: "always" },
		//% "Never"
		{ display: qsTrId("containers_pull_policy_never"), value: "never" },
	]

	function pullPolicyOptions() {
		return root._pullPolicyOptions
	}

	// Sub-container runtime children only expose a Running bool
	// (docs/dbus-api.md ContainerRuntime/Child/<runtime-id>/Running) - no full
	// ContainerState enum, so this is deliberately not stateToText().
	function childStateToText(running) {
		//% "Running"
		return running ? qsTrId("containers_child_state_running")
				//% "Stopped"
				: qsTrId("containers_child_state_stopped")
	}

	// "3 of 4 running" summary for a sub-container runtime's Children/{Count,
	// Running} (docs/dbus-api.md) - used both on the parent container's
	// Sub-containers nav row and the sub-container list page's own header.
	function childRunningSummaryText(running, total) {
		//% "%1 of %2 running"
		return qsTrId("containers_child_running_summary").arg(running).arg(total)
	}

	function bytesToMebibytes(bytes) {
		return Math.round(bytes / (1024 * 1024))
	}

	// DiskUsage/* values span a much wider range than a container's own
	// resource limits (a few KB of managed storage up to tens of GB of
	// host disk) - a single fixed unit reads badly at either end, so this
	// auto-scales the same way PageSettingsSupportStatus.qml's own
	// scaleBytes does for the SD-card-equivalent storage figures
	// elsewhere in the app.
	function formatBytes(bytes) {
		bytes = Number(bytes) || 0
		if (bytes < 1024) {
			return bytes + " B"
		} else if (bytes < 1024 * 1024) {
			return (bytes / 1024).toFixed(1) + " KB"
		} else if (bytes < 1024 * 1024 * 1024) {
			return (bytes / 1024 / 1024).toFixed(1) + " MB"
		} else {
			return (bytes / 1024 / 1024 / 1024).toFixed(1) + " GB"
		}
	}

	function mebibytesToBytes(mib) {
		return Math.round(mib * 1024 * 1024)
	}

	// 0 means unlimited for memoryLimitBytes/cpuLimit (see backend/podman.py
	// in the venus-containers repo) - shared so every summary showing these
	// values renders "Unlimited" consistently rather than "0 MB"/"0".
	function memoryLimitToText(bytes) {
		if (!bytes) {
			//% "Unlimited"
			return qsTrId("containers_unlimited")
		}
		//% "%1 MB"
		return qsTrId("containers_memory_mb").arg(root.bytesToMebibytes(bytes))
	}

	function cpuLimitToText(cores) {
		if (!cores) {
			//% "Unlimited"
			return qsTrId("containers_unlimited")
		}
		//% "%1 CPU"
		return qsTrId("containers_cpu_cores").arg(cores)
	}

	// Status-dot colour for the container list: red for an active error,
	// amber while a transition is in progress (Creating/Starting/Stopping/
	// Recreating - momentary but worth flagging) or while blocked/degraded
	// on a dependency (WaitingForDependency, or Running with its D-Bus link
	// currently Unavailable - see dbusState below), green for genuinely
	// healthy Running, and "nothing" (transparent) for Stopped/Missing/
	// Deleted, where there's nothing to warn about.
	//
	// dbusState is optional (defaults to "no opinion") so every existing
	// call site that doesn't pass it keeps working unchanged.
	function severityColor(state, errorCode, dbusState) {
		// Literal red/orange/green (not the semantic color_ok/color_warning
		// aliases, which map to blue/orange in this theme - a plain
		// red/amber/green traffic-light reading was the actual ask).
		if (errorCode || state === 9) { // 9 = Error
			return Theme.color_red
		}
		if (state === 8) { // WaitingForDependency
			return Theme.color_orange
		}
		if (state === 4) { // Running
			return dbusState === 3 /* DbusState.Unavailable */ ? Theme.color_orange : Theme.color_green
		}
		switch (state) {
		case 1: case 3: case 5: case 6: // Creating/Starting/Stopping/Recreating
			return Theme.color_orange
		default: // Missing/Stopped/Deleted
			return "transparent"
		}
	}
}

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
	venus-containers repo exactly - ServiceState 0..3, ContainerState 0..8.
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
		//% "Failed"
		case 8: return qsTrId("containers_state_failed")
		default: return ""
		}
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

	function bytesToMebibytes(bytes) {
		return Math.round(bytes / (1024 * 1024))
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
	// Recreating - momentary but worth flagging), green for genuinely
	// Running with no error, and "nothing" (transparent) for Stopped/
	// Missing/Deleted, where there's nothing to warn about.
	function severityColor(state, errorCode) {
		// Literal red/orange/green (not the semantic color_ok/color_warning
		// aliases, which map to blue/orange in this theme - a plain
		// red/amber/green traffic-light reading was the actual ask).
		if (errorCode) {
			return Theme.color_red
		}
		switch (state) {
		case 4: // Running
			return Theme.color_green
		case 1: case 3: case 5: case 6: // Creating/Starting/Stopping/Recreating
			return Theme.color_orange
		default: // Missing/Stopped/Deleted
			return "transparent"
		}
	}
}

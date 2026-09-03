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

	// ErrorCode (docs/dbus-api.md's "Error codes" table, venus-containers
	// repo enums.py) - a short, specific label for what actually went
	// wrong (timeout vs. image unavailable vs. identity provisioning vs.
	// ...), not just "there's an error". Every ErrorCode/Children/Child/
	// <id>/ErrorCode leaf in this app should go through this rather than
	// showing the raw integer or falling back to whatever free-text
	// happened to be in Error/Status - those are backend detail (see
	// firstMeaningfulLine below), not the category.
	function errorCodeToText(value) {
		switch (value) {
		case 0: return ""
		//% "Invalid definition"
		case 10: return qsTrId("containers_error_definition_invalid")
		//% "Image unavailable"
		case 11: return qsTrId("containers_error_image_unavailable")
		//% "Create failed"
		case 12: return qsTrId("containers_error_create_failed")
		//% "Start failed"
		case 13: return qsTrId("containers_error_start_failed")
		//% "Stop failed"
		case 14: return qsTrId("containers_error_stop_failed")
		//% "Runtime missing"
		case 15: return qsTrId("containers_error_runtime_missing")
		//% "Could not apply resource limits"
		case 16: return qsTrId("containers_error_resource_apply_failed")
		//% "Out of memory"
		case 17: return qsTrId("containers_error_oom_killed")
		//% "Restart loop"
		case 18: return qsTrId("containers_error_restart_loop")
		//% "Device unavailable"
		case 19: return qsTrId("containers_error_device_unavailable")
		//% "D-Bus unavailable"
		case 20: return qsTrId("containers_error_dbus_unavailable")
		//% "Persistent data unavailable"
		case 21: return qsTrId("containers_error_persistent_data_unavailable")
		//% "Remove failed"
		case 22: return qsTrId("containers_error_remove_failed")
		//% "Timed out"
		case 23: return qsTrId("containers_error_backend_timeout")
		//% "Definition changed outside Venus"
		case 24: return qsTrId("containers_error_definition_drift")
		//% "Identity provisioning failed"
		case 25: return qsTrId("containers_error_identity_provisioning_failed")
		//% "User resolution failed"
		case 26: return qsTrId("containers_error_process_user_resolution_failed")
		//% "Sub-container runtime API unavailable"
		case 27: return qsTrId("containers_error_runtime_api_unavailable")
		default: return ""
		}
	}

	// The one line of a raw backend error capture that actually carries
	// the reason, not the multi-line output skopeo/podman produces along
	// the way to it - a pull failure's raw text is a "Trying to pull ..."
	// preamble followed by one "Copying blob sha256:..." line per image
	// layer, with the real reason only on its own final "Error: ..." line
	// (mirrors venus-containers repo cli.py's _first_meaningful_line,
	// which the CLI's own `vcm list`/`vcm show` use for the same reason -
	// dumping the whole raw capture into one Status line made a failing
	// container's cause unreadable and buried the one line that
	// mattered). Falls back to the last non-empty line for anything that
	// doesn't follow that shape, so a short single-line status (e.g.
	// "restart attempt 2 of 5") passes through unchanged.
	function firstMeaningfulLine(text) {
		if (!text) {
			return ""
		}
		const lines = String(text).split("\n").map(line => line.trim()).filter(line => !!line)
		if (lines.length === 0) {
			return ""
		}
		for (let i = lines.length - 1; i >= 0; --i) {
			if (lines[i].toLowerCase().startsWith("error:")) {
				return lines[i]
			}
		}
		return lines[lines.length - 1]
	}

	// Combines the three published fields that together describe a
	// container's trouble - ErrorCode (the category), Error/Status (the
	// detail), RetryIn (authoritative retry timing, see
	// waitingForDependencyText's own note on that) - into one line, the
	// same shape as the CLI's _summarize_status. retryInSeconds is
	// optional (defaults to 0/no countdown) since not every call site
	// tracks it - e.g. a managed child has no RetryIn leaf of its own yet.
	function errorSummaryText(errorCodeValue, text, retryInSeconds) {
		const label = root.errorCodeToText(errorCodeValue)
		const detail = root.firstMeaningfulLine(text)
		let summary
		if (label && detail) {
			summary = label + ": " + detail
		} else {
			summary = label || detail
		}
		if (retryInSeconds > 0) {
			//% "%1 (retry in %2s)"
			return qsTrId("containers_error_summary_retry").arg(summary).arg(retryInSeconds)
		}
		return summary
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

	// Creating/Recreating row detail for the container list, in place of
	// the %CPU/MB a Running row shows (there's nothing to measure yet).
	// docs/dbus-api.md note 10 in the venus-containers repo: layersTotal
	// is -1 until the manifest resolves (falls through to the plain
	// layers-started count below), and a percentage would be actively
	// misleading - podman front-loads blob copies so it races to ~99% in
	// the first few seconds and then plateaus for the real, much longer,
	// transfer + unpack time - hence a layer count and elapsed time here,
	// never a percentage. elapsedSeconds is 0 before it's worth mentioning
	// (matches the backend's own /Status text, which omits it below 5s);
	// callers should fall back to stateToText() when this returns "" (no
	// layers seen yet and elapsed hasn't crossed that threshold).
	function creatingProgressText(layersDone, layersTotal, elapsedSeconds) {
		if (layersTotal > 0) {
			if (elapsedSeconds >= 5) {
				//% "Pulling: layer %1 of %2 (%3s)"
				return qsTrId("containers_creating_layer_of_elapsed")
						.arg(layersDone).arg(layersTotal).arg(elapsedSeconds)
			}
			//% "Pulling: layer %1 of %2"
			return qsTrId("containers_creating_layer_of").arg(layersDone).arg(layersTotal)
		}
		if (layersDone > 0) {
			if (elapsedSeconds >= 5) {
				//% "Pulling: %1 layer(s) started (%2s)"
				return qsTrId("containers_creating_layers_started_elapsed").arg(layersDone).arg(elapsedSeconds)
			}
			//% "Pulling: %1 layer(s) started"
			return qsTrId("containers_creating_layers_started").arg(layersDone)
		}
		if (elapsedSeconds >= 5) {
			//% "Creating (%1s)"
			return qsTrId("containers_creating_elapsed").arg(elapsedSeconds)
		}
		return ""
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

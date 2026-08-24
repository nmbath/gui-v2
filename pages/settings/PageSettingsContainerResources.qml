/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

/*
	Per-container resource limits and live usage (venus-containers Drop 3
	spec Section 14, concept mock-ups 5 and 6 (illustrative, not final
	visual design)).

	Memory/CPU/PIDs limits are all R/W directly under
	/Containers/<UUID>/Resources/... (docs/dbus-api.md in the
	venus-containers repo) - not under /Settings/Containers/... like
	DesiredState/StartupDelay, since these are validated/persisted by
	dbus-containers itself rather than routed through localsettings.

	0 means "unlimited" for Memory/CPU/PIDs (schema only requires >= 0;
	backend/podman.py omits the corresponding podman flag entirely when the
	value is 0, since e.g. "--memory 0b" is rejected outright rather than
	treated as no limit) - Memory gets an explicit Unlimited switch since
	it's the limit most likely to cause a visible failure (OOM-kill, mock-up
	7) when misjudged; CPU/PIDs just allow spinning the value down to 0.
*/
Page {
	id: root

	required property string containerPrefix

	readonly property int memoryStepMib: 64

	VeQuickItem { id: memoryUsage; uid: root.containerPrefix + "/Resources/MemoryUsage" }
	VeQuickItem { id: memoryLimit; uid: root.containerPrefix + "/Resources/MemoryLimit" }
	VeQuickItem { id: cpuUsage; uid: root.containerPrefix + "/Resources/CpuUsage" }
	VeQuickItem { id: cpuLimit; uid: root.containerPrefix + "/Resources/CpuLimit" }
	VeQuickItem { id: cpuWeight; uid: root.containerPrefix + "/Resources/CpuWeight" }
	VeQuickItem { id: pids; uid: root.containerPrefix + "/Resources/Pids" }
	VeQuickItem { id: pidsLimit; uid: root.containerPrefix + "/Resources/PidsLimit" }
	VeQuickItem { id: restartPolicy; uid: root.containerPrefix + "/Lifecycle/RestartPolicy" }

	GradientListView {
		model: VisibleItemModel {
			SettingsListHeader {
				//% "Current usage"
				text: qsTrId("pagesettingscontainerresources_current_usage")
			}

			ListText {
				//% "Memory"
				text: qsTrId("pagesettingscontainerresources_memory")
				//% "%1 MB"
				secondaryText: qsTrId("pagesettingscontainerresources_memory_value")
						.arg(Containers.bytesToMebibytes(memoryUsage.value))
			}

			ListQuantity {
				//% "CPU"
				text: qsTrId("pagesettingscontainerresources_cpu")
				value: cpuUsage.value
				unit: VenusOS.Units_Percentage
			}

			ListText {
				//% "Processes"
				text: qsTrId("pagesettingscontainerresources_processes")
				secondaryText: pids.value
			}

			SettingsListHeader {
				//% "Limits"
				text: qsTrId("pagesettingscontainerresources_limits")
			}

			ListSwitch {
				//% "Unlimited memory"
				text: qsTrId("pagesettingscontainerresources_memory_unlimited")
				//% "The container can use as much memory as is available. It may be stopped by the system if memory runs out."
				caption: qsTrId("pagesettingscontainerresources_memory_unlimited_caption")
				// checked is fully derived from the live dataItem rather than
				// bound via dataItem.uid, since MemoryLimit is a byte value,
				// not a boolean - see ListSwitch.qml's own docstring, option
				// 2 (manual checked/onClicked). ListSwitch.click() already
				// gates on checkWriteAccessLevel() before this fires, same
				// as the Delete button on the parent page.
				checked: memoryLimit.valid && memoryLimit.value === 0
				// checked reflects the state *before* this click (a live
				// binding on the still-unchanged memoryLimit.value): if it
				// was already unlimited, turn that off and set a real
				// ceiling; otherwise turn unlimited on. (Previously
				// inverted: checked ? 0 : ... left the switch a no-op.)
				onClicked: memoryLimit.setValue(checked ? Containers.mebibytesToBytes(512) : 0)
			}

			ListSpinBox {
				// dataItem.uid is deliberately left unbound: MemoryLimit is
				// bytes on D-Bus but shown here in MB (components/Containers.qml
				// bytesToMebibytes/mebibytesToBytes) - ListSpinBox has no unit
				// scaling hook, only a raw dataItem passthrough. Per
				// NumberSelectorDialog's own logic (components/dialogs/
				// NumberSelectorDialog.qml onAccepted), leaving dataItem unbound
				// means accepting a value imperatively replaces the "value:"
				// binding below with a static number - so after an edit this
				// spinbox stops tracking memoryLimit.value live until the page
				// is reloaded (pop/push). Acceptable here: nothing else writes
				// MemoryLimit while this page is open, and the write itself
				// still lands correctly via onSelectorAccepted regardless.
				//% "Memory maximum"
				text: qsTrId("pagesettingscontainerresources_memory_limit")
				preferredVisible: memoryLimit.valid && memoryLimit.value !== 0
				value: Containers.bytesToMebibytes(memoryLimit.value)
				//% " MB"
				suffix: qsTrId("pagesettingscontainerresources_mb_suffix")
				from: root.memoryStepMib
				to: 4096
				stepSize: root.memoryStepMib
				presets: [
					{ value: "256" },
					{ value: "512" },
					{ value: "768" },
					{ value: "1024" },
				]
				onSelectorAccepted: (newValue) => memoryLimit.setValue(Containers.mebibytesToBytes(newValue))
			}

			ListSpinBox {
				//% "CPU maximum"
				text: qsTrId("pagesettingscontainerresources_cpu_limit")
				//% "Logical CPUs, 0 = unlimited"
				caption: qsTrId("pagesettingscontainerresources_cpu_limit_caption")
				dataItem.uid: cpuLimit.uid
				decimals: 1
				from: 0
				to: 8
				stepSize: 0.5
			}

			ListSpinBox {
				//% "CPU priority"
				text: qsTrId("pagesettingscontainerresources_cpu_weight")
				dataItem.uid: cpuWeight.uid
				from: 1
				to: 1000
				stepSize: 10
			}

			ListSpinBox {
				//% "Process maximum"
				text: qsTrId("pagesettingscontainerresources_pids_limit")
				//% "0 = unlimited"
				caption: qsTrId("pagesettingscontainerresources_pids_limit_caption")
				dataItem.uid: pidsLimit.uid
				from: 0
				to: 4096
				stepSize: 16
			}

			SettingsListHeader {
				//% "Restart policy"
				text: qsTrId("pagesettingscontainerresources_restart_policy")
			}

			ListRadioButtonGroup {
				//% "Restart policy"
				text: qsTrId("pagesettingscontainerresources_restart_policy")
				dataItem.uid: restartPolicy.uid
				optionModel: Containers.restartPolicyOptions()
			}
		}
	}
}

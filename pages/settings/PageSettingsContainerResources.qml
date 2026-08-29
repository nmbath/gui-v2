/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

/*
	Resource limits and live usage - venus-containers Drop 3 spec Section 14,
	concept mock-ups 5/6 (own container) and 13 (sub-container aggregate,
	Sub-container Runtime Design v1). One page definition serves both cases
	(isAggregate selects which, i.e. only which point in the D-Bus tree is
	read/written) - the layout itself is identical between the two, per the
	concept mock-ups' own instruction that the two should share a page
	definition rather than diverge.

	PageSettingsContainerSubcontainers.qml (one level up, for the aggregate
	case) additionally shows the same usage as a richer bar-against-limit
	visualisation and the sub-container list - that page's own status/browse
	role, not a reason to omit the plain Current usage values here too.

	Own container: /Containers/<UUID>/Resources/{MemoryUsage,MemoryLimit,
	CpuUsage,CpuLimit,CpuWeight,Pids,PidsLimit} (docs/dbus-api.md).

	Aggregate (isAggregate=true): /Containers/<UUID>/ContainerRuntime/Resources/
	{MemoryUsedBytes,MemoryLimitBytes,CpuUsage,CpuLimit,PidsUsed,PidsLimit} - the
	envelope applied across all of that container's sub-containers collectively,
	entirely separate from the parent's own Resources above (docs/dbus-api.md
	note 3). No CpuWeight equivalent exists for the aggregate case. Writing one
	of these three R/W leaves calls update_runtime_resources (reconciler.py),
	which persists and applies live but never recreates the parent.

	Memory/CPU maximum are sliders from 0 (which already means "unlimited" per
	the schema, see below) to the host ceiling published at the containers
	service's top-level /System/MaxMemoryLimitBytes and /System/MaxCpuLimit -
	so there is no separate "Unlimited" switch here: sliding all the way to 0
	already produces the same wire value backend/podman.py already treats as
	unlimited. Same bound for both own-container and aggregate: a
	sub-container runtime's aggregate envelope lives in its own separate
	cgroup (RUNTIME_API_CGROUP_ROOT in backend/podman.py), not carved out of
	the parent's own (DEDICATED_CGROUP_ROOT) - it's an additional allocation
	of host memory, not a subdivision of the parent's limit, confirmed live -
	see [[containers_system_resources]] in memory. Both rows stay hidden
	until the backend publishes those two leaves (preferredVisible on each
	system-max item's .valid).
*/
Page {
	id: root

	required property string containerPrefix
	property bool isAggregate: false

	readonly property int memoryStepMib: 64

	readonly property string resourcePrefix: root.containerPrefix + (root.isAggregate ? "/ContainerRuntime/Resources" : "/Resources")
	readonly property string memoryUsageLeaf: root.isAggregate ? "MemoryUsedBytes" : "MemoryUsage"
	readonly property string memoryLimitLeaf: root.isAggregate ? "MemoryLimitBytes" : "MemoryLimit"
	readonly property string pidsUsageLeaf: root.isAggregate ? "PidsUsed" : "Pids"

	readonly property string containersServiceUid: BackendConnection.serviceUidForType("containers")

	VeQuickItem { id: memoryUsage; uid: root.resourcePrefix + "/" + root.memoryUsageLeaf }
	VeQuickItem { id: memoryLimit; uid: root.resourcePrefix + "/" + root.memoryLimitLeaf }
	VeQuickItem { id: cpuUsage; uid: root.resourcePrefix + "/CpuUsage" }
	VeQuickItem { id: cpuLimit; uid: root.resourcePrefix + "/CpuLimit" }
	VeQuickItem { id: cpuWeight; uid: root.resourcePrefix + "/CpuWeight" }
	VeQuickItem { id: pids; uid: root.resourcePrefix + "/" + root.pidsUsageLeaf }
	VeQuickItem { id: pidsLimit; uid: root.resourcePrefix + "/PidsLimit" }

	// Top-level, not per-container - the same host ceiling bounds every
	// Memory/CPU-maximum slider in the app, own-container or aggregate alike.
	// A sub-container runtime's aggregate envelope is its own additional
	// allocation on top of the parent's own limit (confirmed by the user
	// 2026-08-29 - NOT carved out of it, despite an earlier misreading of a
	// stale comment in venus-containers' dbus_service.py - see
	// [[containers_system_resources]]), so it is bounded the same way the
	// parent's own limit is, not by the parent's own limit itself.
	VeQuickItem { id: systemMaxMemory; uid: root.containersServiceUid + "/System/MaxMemoryLimitBytes" }
	VeQuickItem { id: systemMaxCpu; uid: root.containersServiceUid + "/System/MaxCpuLimit" }

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
				// Both own-container and aggregate CpuUsage are the same
				// percentage convention (100% = one full logical CPU busy for
				// the sample period, can exceed 100% with several cores
				// busy) - confirmed 2026-08-29 by reading backend/podman.py
				// in venus-containers: the aggregate figure comes from
				// cpu.stat's usage_usec delta * 100 (podman.py's
				// _read_runtime_stats, formerly misread as a core count),
				// the own-container figure from podman stats' native CPU%
				// field - both genuinely percentages, unlike CpuLimit (both
				// variants), which is in cores.
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

			ListSlider {
				// ListSlider has no separate value-readout property - shown as
				// part of the label itself instead, matching the startup Delay
				// slider's own pattern (PageSettingsContainerStartup.qml).
				// memoryLimitToText already renders "Unlimited" at 0, so
				// dragging to the left end of the slider reads correctly
				// without any extra unlimited-specific label handling.
				//% "Memory maximum: %1"
				text: qsTrId("pagesettingscontainerresources_memory_limit_slider").arg(Containers.memoryLimitToText(memoryLimit.value))
				//% "0 = unlimited"
				caption: qsTrId("pagesettingscontainerresources_memory_limit_caption")
				preferredVisible: systemMaxMemory.valid && systemMaxMemory.value > 0
				dataItem.uid: memoryLimit.uid
				from: 0
				to: systemMaxMemory.value
				stepSize: root.memoryStepMib * 1024 * 1024
			}

			ListSlider {
				//% "CPU maximum: %1"
				text: qsTrId("pagesettingscontainerresources_cpu_limit_slider").arg(Containers.cpuLimitToText(cpuLimit.value))
				//% "0 = unlimited"
				caption: qsTrId("pagesettingscontainerresources_cpu_limit_caption")
				preferredVisible: systemMaxCpu.valid && systemMaxCpu.value > 0
				dataItem.uid: cpuLimit.uid
				from: 0
				to: systemMaxCpu.value
				stepSize: 0.5
			}

			ListSpinBox {
				//% "CPU priority"
				text: qsTrId("pagesettingscontainerresources_cpu_weight")
				// No aggregate equivalent (docs/dbus-api.md note 3) - the
				// aggregate cgroup has a single CPU weight shared by the
				// runtime service and all its children, not a per-runtime
				// knob exposed here.
				preferredVisible: !root.isAggregate
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

			ListInfoLabel {
				//% "Changes apply live and do not recreate the parent container."
				text: qsTrId("pagesettingscontainerresources_aggregate_limits_note")
				preferredVisible: root.isAggregate
			}
		}
	}
}

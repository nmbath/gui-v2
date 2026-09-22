/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

/*
	Child-container overview for one managed container, covering both
	ownership modes the Recursive Child Container Model v2 (docs/dbus-api.md
	Section 9/note 5-6) supports: "runtime" (Sub-container Runtime Design v1 -
	a containerRuntime.enabled=true container exposing its own Podman API for
	an app to create its own sub-containers) and "managed" (children declared
	directly in the definition, created/started by Venus itself). Reached
	from PageSettingsContainer.qml's own "Sub-containers" row, shown for
	either mode. root.isManaged (Children/Mode) is the one flag this page
	branches on throughout.

	Same structural model as the parent container's own page
	(PageSettingsContainer.qml): usage is shown directly here rather than
	behind a nav, and so is the child list. Editing the aggregate limits is
	its own destination for either mode ("Resources" pushes
	PageSettingsContainerResources.qml with isAggregate=true, sharing that
	page definition with the own-container case) - update_children_resources
	(reconciler.py) gives managed mode's children.resources the same
	live-update path update_runtime_resources already gives the runtime-mode
	aggregate (docs/dbus-api.md note 5).

	/Containers/<UUID>/Children/Resources/* (docs/dbus-api.md note 5) is the
	aggregate envelope applied across all of this container's children
	collectively, for either mode - entirely separate from, and additive on
	top of, the parent's own /Resources/* (see
	[[containers_system_resources]] in memory: the two are
	independently-enforced cgroups, not one shared pool).

	Children live under /Containers/<UUID>/Children/Child/<id>/* (docs/
	dbus-api.md note 6) - observational only, added/removed as children
	appear/disappear, <id> being a runtime ID for a runtime-mode child or the
	child's own definition name for a managed one. Deliberately no per-child
	memory/CPU usage: no per-child cgroup exists to read from (flat-cgroup
	aggregate design for runtime mode, confirmed absent from the schema for
	managed mode too, not an oversight in either case) - runtime-mode
	children show only Running/Stopped, managed-mode ones the fuller
	State/ErrorCode/Error Venus itself tracks for them, unlike the parent
	container list's richer live-stats secondaryText. Each row here just
	navigates to PageSettingsContainerChild.qml, which shows that child's own
	status/image/error detail plus, for managed mode only, its Pull policy
	(docs/dbus-api.md note 7) - the one genuinely editable field either
	ownership mode has, since it governs a future pull rather than anything
	already running. Nothing here starts, stops, deletes or recreates a
	child of either kind, and there is intentionally no D-Bus path through
	which a client could ask it to (docs/dbus-api.md notes 3/6) - hence the
	footer note, which still applies on the child's own page too.
*/
Page {
	id: root

	required property string containerPrefix

	// Unified across both child ownership modes (docs/dbus-api.md note 5) -
	// same six leaves either way, so no isAggregate-style branching is
	// needed here the way PageSettingsContainerResources.qml's own-vs-
	// aggregate split requires (that page still reads ContainerRuntime/
	// Resources/* directly, since only the runtime-mode aggregate has a
	// live-update path to edit through - see the Resources row below).
	readonly property string resourcePrefix: root.containerPrefix + "/Children/Resources"

	VeQuickItem { id: childrenMode; uid: root.containerPrefix + "/Children/Mode" }
	readonly property bool isManaged: childrenMode.value === "managed"

	VeQuickItem { id: memoryUsage; uid: root.resourcePrefix + "/MemoryUsedBytes" }
	VeQuickItem { id: memoryLimit; uid: root.resourcePrefix + "/MemoryLimitBytes" }
	VeQuickItem { id: cpuUsage; uid: root.resourcePrefix + "/CpuUsage" }
	VeQuickItem { id: cpuLimit; uid: root.resourcePrefix + "/CpuLimit" }
	VeQuickItem { id: pids; uid: root.resourcePrefix + "/PidsUsed" }
	VeQuickItem { id: pidsLimit; uid: root.resourcePrefix + "/PidsLimit" }

	// CpuUsage is a percentage (100% = one full logical CPU busy for the
	// sample period, backend/podman.py in venus-containers) while CpuLimit
	// is in cores ("1.0 == one logical CPU", same file) - converting to
	// cores here is what makes the bar/value-vs-limit pairing below
	// meaningful, confirmed 2026-08-29 after an earlier version of this row
	// compared the two directly (a percentage against a core count).
	readonly property real cpuUsageCores: cpuUsage.value / 100

	VeQuickItem { id: containerName; uid: root.containerPrefix + "/Name" }

	VeQItemSortTableModel {
		id: children

		model: VeQItemTableModel {
			// Children/Child (docs/dbus-api.md note 6) is ContainerRuntime/
			// Child's superset, covering both ownership modes through the
			// one path - <id> is a runtime ID for a runtime-mode child, or
			// the child's own definition name for a managed one.
			uids: [ root.containerPrefix + "/Children/Child" ]
			flags: VeQItemTableModel.AddChildren | VeQItemTableModel.AddNonLeaves | VeQItemTableModel.DontAddItem
		}
		dynamicSortFilter: true
		filterFlags: VeQItemSortTableModel.FilterOffline
	}

	GradientListView {
		model: VisibleItemModel {
			SettingsListHeader {
				//% "Aggregate usage"
				text: qsTrId("pagesettingscontainersubcontainers_aggregate_usage")
			}

			// Same horizontal-row summary style as the parent container's own
			// "Current usage" row (PageSettingsContainer.qml's usageSummary) -
			// just 3 cells instead of 6, since the aggregate cgroup only ever
			// publishes Memory/CPU/Processes (docs/dbus-api.md note 5's six
			// Children/Resources/* leaves have no disk/image counterpart -
			// there is no per-child cgroup to read image/local usage from,
			// see this page's own top comment).
			ListItem {
				id: usageSummary
				readonly property real cellWidth: availableWidth / 3

				contentItem: RowLayout {
					spacing: 0

					ColumnLayout {
						spacing: 0
						Layout.minimumWidth: usageSummary.cellWidth
						Layout.preferredWidth: usageSummary.cellWidth
						Layout.maximumWidth: usageSummary.cellWidth

						Label {
							//% "Memory (MB)"
							text: qsTrId("pagesettingscontainer_memory_mb")
							font: usageSummary.font
							horizontalAlignment: Text.AlignHCenter
							Layout.fillWidth: true
						}

						SecondaryListLabel {
							//% "%1 / %2"
							text: qsTrId("pagesettingscontainer_memory_usage_compact")
									.arg(Containers.bytesToMebibytes(memoryUsage.value))
									.arg(Containers.bytesToMebibytes(memoryLimit.value))
							horizontalAlignment: Text.AlignHCenter
							Layout.fillWidth: true
						}
					}

					ColumnLayout {
						spacing: 0
						Layout.minimumWidth: usageSummary.cellWidth
						Layout.preferredWidth: usageSummary.cellWidth
						Layout.maximumWidth: usageSummary.cellWidth

						Label {
							//% "CPU"
							text: qsTrId("pagesettingscontainerresources_cpu")
							font: usageSummary.font
							Layout.alignment: Qt.AlignHCenter
						}

						SecondaryListLabel {
							//% "%1 / %2"
							text: qsTrId("pagesettingscontainer_cpu_usage_compact")
									.arg(root.cpuUsageCores.toFixed(2)).arg(cpuLimit.value)
							Layout.alignment: Qt.AlignHCenter
						}
					}

					ColumnLayout {
						spacing: 0
						Layout.minimumWidth: usageSummary.cellWidth
						Layout.preferredWidth: usageSummary.cellWidth
						Layout.maximumWidth: usageSummary.cellWidth

						Label {
							//% "Processes"
							text: qsTrId("pagesettingscontainerresources_processes")
							font: usageSummary.font
							Layout.alignment: Qt.AlignHCenter
						}

						SecondaryListLabel {
							//% "%1 / %2"
							text: qsTrId("pagesettingscontainerresources_pids_usage_value").arg(pids.value).arg(pidsLimit.value)
							Layout.alignment: Qt.AlignHCenter
						}
					}
				}
			}

			SettingsListHeader {
				//% "Configuration"
				text: qsTrId("pagesettingscontainersubcontainers_configuration")
			}

			ListNavigation {
				//% "Resources"
				text: qsTrId("pagesettingscontainersubcontainers_resources")
				// Same summary string as the parent container's own Resources
				// row (PageSettingsContainer.qml) - same page definition, just
				// reading the aggregate limit values (memoryLimit/cpuLimit
				// above are Children/Resources/*, not the parent's own
				// Resources/*) instead of duplicating the format here.
				//% "Memory %1, %2"
				secondaryText: qsTrId("pagesettingscontainer_resource_limits_summary")
						.arg(Containers.memoryLimitToText(memoryLimit.value))
						.arg(Containers.cpuLimitToText(cpuLimit.value))
				// Editable for either mode - update_children_resources
				// (reconciler.py) gives the managed-mode aggregate the same
				// live-update path update_runtime_resources already gives
				// the runtime-mode one, both reached through this same
				// Children/Resources/* leaf (docs/dbus-api.md note 5).
				onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsContainerResources.qml",
						{"title": text, "containerPrefix": root.containerPrefix, "isAggregate": true})
			}

			// A bare Repeater placed directly as a VisibleItemModel entry
			// never renders - it has no layout of its own, so it needs a
			// real layout container to position its generated children
			// (same gotcha documented in PageSettingsContainers.qml).
			SettingsColumn {
				width: parent ? parent.width : 0

				SettingsListHeader {
					//% "Containers"
					text: qsTrId("pagesettingscontainersubcontainers_containers")
				}

				Repeater {
					model: VeQItemSortTableModel {
						model: VeQItemChildModel {
							model: children
							childId: "Name"
						}
						dynamicSortFilter: true
						filterFlags: VeQItemSortTableModel.FilterInvalid
					}

					delegate: ListNavigation {
						id: childDelegate

						required property VeQItem item

						readonly property string childPrefix: item.itemParent().uid

						// Runtime-mode children publish Image/Running/Status
						// only; managed-mode ones publish State/ErrorCode/
						// Error instead (docs/dbus-api.md note 6) - binding
						// both sets unconditionally is harmless (an absent
						// path just reads as invalid/default), and which
						// pair to *display* follows the page's own mode,
						// same as every child under one container sharing
						// it.
						text: item.value || ""
						caption: root.isManaged ? (error.value || "") : (image.value || "")
						secondaryText: root.isManaged
								? Containers.stateToText(childState.value)
								: Containers.childStateToText(running.value)

						// Same left-edge indicator the top-level container list uses
						// instead of a dot - full traffic-light semantics for managed
						// mode (same helper), runtime mode keeps its existing plain
						// green-if-running reading, since Running is all it has.
						indicatorColor: root.isManaged
								? Containers.severityColor(childState.value, errorCode.value)
								: (running.value ? Theme.color_green : "transparent")

						// Own page per child (PageSettingsContainerChild.qml)
						// rather than exposing Pull policy inline in this
						// flat list - found live on Venus Grafana's managed
						// influxdb/venus-influx-loader pair: a radio group
						// squeezed directly under each child's row read as
						// ambiguous about which child it belonged to, and
						// looked like a navigation row without actually
						// being one.
						onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsContainerChild.qml",
								{"title": text, "childPrefix": childDelegate.childPrefix, "isManaged": root.isManaged})

						VeQuickItem {
							id: image
							uid: childPrefix + "/Image"
						}
						VeQuickItem {
							id: running
							uid: childPrefix + "/Running"
						}
						VeQuickItem {
							id: childState
							uid: childPrefix + "/State"
						}
						VeQuickItem {
							id: errorCode
							uid: childPrefix + "/ErrorCode"
						}
						VeQuickItem {
							id: error
							uid: childPrefix + "/Error"
						}
					}
				}
			}

			ListInfoLabel {
				// Accurate for either mode, but for a different reason each
				// time: a runtime-mode child's lifecycle genuinely belongs
				// to the app itself (it created the child through its own
				// exposed Podman API - Venus never asked to, and has no way
				// to). A managed-mode child's lifecycle is Venus's own to
				// run, but only ever as a consequence of the parent's own
				// start/stop/purge, never addressed individually - "same
				// place" either way, just "the app" vs "the parent
				// container" as who that place actually is.
				//% "Lifecycle is owned by %1. Venus provides observability only."
				text: root.isManaged
						//% "Lifecycle follows the parent container, %1. Individual children cannot be started, stopped or removed on their own."
						? qsTrId("pagesettingscontainersubcontainers_lifecycle_note_managed").arg(containerName.value || "")
						: qsTrId("pagesettingscontainersubcontainers_lifecycle_note").arg(containerName.value || "")
			}
		}
	}
}

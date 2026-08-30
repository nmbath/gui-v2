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
	container list's richer live-stats secondaryText. Nothing here is
	writable: Venus does not start, stop, delete or recreate a child of
	either kind through this page, and there is intentionally no D-Bus path
	through which a client could ask it to (docs/dbus-api.md notes 3/6) -
	hence the footer note.
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

			ListResourceGauge {
				//% "Memory"
				text: qsTrId("pagesettingscontainerresources_memory")
				//% "%1 MB / %2 MB"
				valueText: qsTrId("pagesettingscontainerresources_memory_usage_value")
						.arg(Containers.bytesToMebibytes(memoryUsage.value)).arg(Containers.bytesToMebibytes(memoryLimit.value))
				value: memoryUsage.value
				to: memoryLimit.value
			}

			ListResourceGauge {
				//% "CPU"
				text: qsTrId("pagesettingscontainerresources_cpu")
				//% "%1 / %2"
				valueText: qsTrId("pagesettingscontainerresources_cpu_usage_value")
						.arg(root.cpuUsageCores.toFixed(2)).arg(cpuLimit.value)
				value: root.cpuUsageCores
				to: cpuLimit.value
			}

			ListResourceGauge {
				//% "Processes"
				text: qsTrId("pagesettingscontainerresources_processes")
				//% "%1 / %2"
				valueText: qsTrId("pagesettingscontainerresources_pids_usage_value").arg(pids.value).arg(pidsLimit.value)
				value: pids.value
				to: pidsLimit.value
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

					delegate: ListText {
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

						contentItem: Item {
							implicitWidth: Theme.geometry_listItem_width
							implicitHeight: identityColumn.implicitHeight

							ColumnLayout {
								id: identityColumn

								anchors {
									left: parent.left
									right: statusLabel.left
									rightMargin: childDelegate.spacing
									verticalCenter: parent.verticalCenter
								}
								spacing: 0

								Label {
									text: childDelegate.text
									font: childDelegate.font
									textFormat: childDelegate.textFormat
									wrapMode: Text.WordWrap
									Layout.fillWidth: true
								}

								CaptionLabel {
									text: childDelegate.caption
									visible: text.length > 0
									Layout.fillWidth: true
								}
							}

							Item {
								anchors {
									right: statusLabel.left
									top: parent.top
									bottom: parent.bottom
								}
								width: 16

								Rectangle {
									anchors.centerIn: parent
									width: 16
									height: 16
									radius: 8
									// Full traffic-light semantics for managed
									// mode (same helper the top-level
									// container list itself uses) - runtime
									// mode keeps its existing plain green-if-
									// running reading, since Running is all
									// it has.
									color: root.isManaged
											? Containers.severityColor(childState.value, errorCode.value)
											: (running.value ? Theme.color_green : "transparent")
									visible: color != "transparent"
								}
							}

							SecondaryListLabel {
								id: statusLabel

								anchors {
									right: parent.right
									verticalCenter: parent.verticalCenter
								}
								text: childDelegate.secondaryText
							}
						}

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

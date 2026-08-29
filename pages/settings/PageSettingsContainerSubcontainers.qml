/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

/*
	Sub-container runtime overview for one managed container (Sub-container
	Runtime Design v1 / venus-containers Drop 3 spec Section 14, concept
	mock-ups 10/11/12). Reached from PageSettingsContainer.qml's own
	"Sub-containers" row.

	Same structural model as the parent container's own page
	(PageSettingsContainer.qml): usage is shown directly here rather than
	behind a nav, and so is the child list - only editing the limits is its
	own destination ("Resources" pushes PageSettingsContainerResources.qml
	with isAggregate=true, sharing that page definition with the
	own-container case, per the concept mock-ups' own instruction).

	/Containers/<UUID>/ContainerRuntime/Resources/* (docs/dbus-api.md) is the
	aggregate envelope applied across all of this container's sub-containers
	collectively - entirely separate from, and additive on top of, the
	parent's own /Resources/* (see [[containers_system_resources]] in
	memory: the two are independently-enforced cgroups, not one shared pool).

	Children live under /Containers/<UUID>/ContainerRuntime/Child/<runtime-id>/
	{RuntimeId,Name,Image,Running,Status} (docs/dbus-api.md) - observational
	only, added/removed as sub-containers appear/disappear. Deliberately no
	per-child memory/CPU usage: no per-child cgroup exists to read from (flat-
	cgroup aggregate design, confirmed absent from the schema, not an
	oversight) - only Running/Stopped is shown, unlike the parent container
	list's richer live-stats secondaryText. Nothing here is writable: Venus
	does not start, stop, delete or recreate a sub-container, and there is
	intentionally no D-Bus path through which a client could ask it to
	(docs/dbus-api.md note 3) - hence the footer note.
*/
Page {
	id: root

	required property string containerPrefix

	readonly property string resourcePrefix: root.containerPrefix + "/ContainerRuntime/Resources"

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
			uids: [ root.containerPrefix + "/ContainerRuntime/Child" ]
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
				// above are ContainerRuntime/Resources/*, not the parent's
				// own Resources/*) instead of duplicating the format here.
				//% "Memory %1, %2"
				secondaryText: qsTrId("pagesettingscontainer_resource_limits_summary")
						.arg(Containers.memoryLimitToText(memoryLimit.value))
						.arg(Containers.cpuLimitToText(cpuLimit.value))
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

						text: item.value || ""
						caption: image.value || ""
						secondaryText: Containers.childStateToText(running.value)

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
									color: running.value ? Theme.color_green : "transparent"
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
					}
				}
			}

			ListInfoLabel {
				//% "Lifecycle is owned by %1. Venus provides observability only."
				text: qsTrId("pagesettingscontainersubcontainers_lifecycle_note").arg(containerName.value || "")
			}
		}
	}
}

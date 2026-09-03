/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

/*
	Settings > Integrations > Containers - the managed-container list
	(venus-containers Drop 3 spec Section 14, concept mock-up 2).

	Containers are children of com.victronenergy.containers under
	/Containers/<UUID>/..., published as a flat BusItem tree (see
	docs/dbus-api.md in the venus-containers repo) - not the /Devices/<id>
	convention some other integrations (BLE, Shelly) use, since this is a
	different D-Bus service with its own schema, not a devices-under-one
	umbrella-service pattern.
*/
Page {
	id: root

	readonly property string containersServiceUid: BackendConnection.serviceUidForType("containers")
	readonly property string importServiceUid: BackendConnection.serviceUidForType("import")

	// docs/dbus-api.md: MaxMemoryLimitBytes/MaxCpuLimit are the host ceiling
	// (RAM minus a fixed OS/Venus reserve; host core count) - the same bound
	// PageSettingsContainerResources.qml's Memory/CPU-maximum controls use.
	// AllocatedMemoryLimitBytes/AllocatedCpuLimit are already the backend's
	// own authoritative sum of every container's own Resources/MemoryLimit,
	// CpuLimit PLUS its ContainerRuntime/Resources aggregate when enabled -
	// the two are separate, additive cgroups (RUNTIME_API_CGROUP_ROOT vs
	// DEDICATED_CGROUP_ROOT in backend/podman.py, not one shared leaf), so
	// both genuinely consume host memory and both are counted - see
	// [[containers_system_resources]] in memory. All four leaves are added
	// together in the same backend commit, so every row below simply stays
	// hidden (via .valid) as one unit until it lands.
	VeQuickItem { id: systemMaxMemory; uid: root.containersServiceUid + "/System/MaxMemoryLimitBytes" }
	VeQuickItem { id: systemMaxCpu; uid: root.containersServiceUid + "/System/MaxCpuLimit" }
	VeQuickItem { id: allocatedMemory; uid: root.containersServiceUid + "/System/AllocatedMemoryLimitBytes" }
	VeQuickItem { id: allocatedCpu; uid: root.containersServiceUid + "/System/AllocatedCpuLimit" }
	VeQuickItem { id: importServiceConnected; uid: root.importServiceUid + "/Connected" }
	VeQuickItem { id: importState; uid: root.importServiceUid + "/State" }

	// The backend's own Allocated total already excludes each Unlimited (0)
	// contributor from the sum (same "0 = no cap" convention as everywhere
	// else), which makes it an undercount rather than a hard ceiling - so
	// this page still needs to know how many contributors are Unlimited, to
	// flag that undercount rather than let the total silently read smaller
	// than reality. A container's own limit and its ContainerRuntime
	// aggregate (when enabled) are two separate, independently-Unlimited
	// contributors (see [[containers_system_resources]]), so both are
	// counted here. That count (unlike the sum itself) has no backend leaf
	// of its own, so it's the one thing still computed client-side, from
	// the list's own live per-row model.
	property int unlimitedMemoryCount: 0
	property int unlimitedCpuCount: 0
	property int activeContainerCount: 0
	property int deletedContainerCount: 0
	property string hostDiskSourcePrefix

	function recomputeUnlimitedCounts() {
		let unlimitedMemory = 0
		let unlimitedCpu = 0
		let activeContainers = 0
		let deletedContainers = 0
		let diskSourcePrefix = ""
		for (let i = 0; i < containerRepeater.count; ++i) {
			const row = containerRepeater.itemAt(i)
			if (!row) {
				continue
			}
			if (row.isDeleted) {
				deletedContainers++
				continue
			}
			activeContainers++
			if (!diskSourcePrefix) {
				diskSourcePrefix = row.containerPrefix
			}
			if (row.memoryLimitBytes <= 0) {
				unlimitedMemory++
			}
			if (row.cpuLimitCores <= 0) {
				unlimitedCpu++
			}
			if (row.runtimeEnabled) {
				if (row.runtimeMemoryLimitBytes <= 0) {
					unlimitedMemory++
				}
				if (row.runtimeCpuLimitCores <= 0) {
					unlimitedCpu++
				}
			}
		}
		root.unlimitedMemoryCount = unlimitedMemory
		root.unlimitedCpuCount = unlimitedCpu
		root.activeContainerCount = activeContainers
		root.deletedContainerCount = deletedContainers
		root.hostDiskSourcePrefix = diskSourcePrefix
	}

	function assignedMemoryText() {
		const assignedMib = Containers.bytesToMebibytes(allocatedMemory.value)
		const totalMib = Containers.bytesToMebibytes(systemMaxMemory.value)
		if (root.unlimitedMemoryCount > 0) {
			//% "%1 MB assigned / %2 MB total (%3 unlimited)"
			return qsTrId("pagesettingscontainers_system_memory_assigned_unlimited")
					.arg(assignedMib).arg(totalMib).arg(root.unlimitedMemoryCount)
		}
		//% "%1 MB assigned / %2 MB total"
		return qsTrId("pagesettingscontainers_system_memory_assigned").arg(assignedMib).arg(totalMib)
	}

	function assignedCpuText() {
		if (root.unlimitedCpuCount > 0) {
			//% "%1 of %2 cores assigned (%3 unlimited)"
			return qsTrId("pagesettingscontainers_system_cpu_assigned_unlimited")
					.arg(allocatedCpu.value).arg(systemMaxCpu.value).arg(root.unlimitedCpuCount)
		}
		//% "%1 of %2 cores assigned"
		return qsTrId("pagesettingscontainers_system_cpu_assigned").arg(allocatedCpu.value).arg(systemMaxCpu.value)
	}

	VeQItemSortTableModel {
		id: containers

		model: VeQItemTableModel {
			id: rawContainers
			uids: [ root.containersServiceUid + "/Containers" ]
			flags: VeQItemTableModel.AddChildren | VeQItemTableModel.AddNonLeaves | VeQItemTableModel.DontAddItem
		}
		dynamicSortFilter: true
		filterFlags: VeQItemSortTableModel.FilterOffline
	}

	// Host disk figures describe the storage backing the container service,
	// rather than any one container. The backend currently publishes the same
	// host sample beneath each application tree, so use the first active tree
	// as the source and present it once at this parent level.
	VeQuickItem {
		id: diskHostTotal
		uid: root.hostDiskSourcePrefix ? root.hostDiskSourcePrefix + "/DiskUsage/HostTotalBytes" : ""
	}
	VeQuickItem {
		id: diskHostUsed
		uid: root.hostDiskSourcePrefix ? root.hostDiskSourcePrefix + "/DiskUsage/HostUsedBytes" : ""
	}
	VeQuickItem {
		id: diskUpdatedAt
		uid: root.hostDiskSourcePrefix ? root.hostDiskSourcePrefix + "/DiskUsage/UpdatedAt" : ""
	}

	GradientListView {
		model: VisibleItemModel {
			ListSwitch {
				// Deliberately not "enabled": every Item-derived component
				// already has its own inherited `enabled` bool property, so
				// a same-named id gets shadowed by that local property in
				// some scopes (confirmed live: "Unable to assign [undefined]
				// to bool" for enabledSwitch.checked inside the Repeater delegate
				// below, since ListNavigation's own enabled shadowed this id
				// there) - this is why the container list never rendered.
				id: enabledSwitch

				//% "Enable containers"
				text: qsTrId("pagesettingscontainers_enable")
				//% "Starts the container service so definitions can be managed here"
				caption: qsTrId("pagesettingscontainers_enable_caption")
				// venus-platform owns starting/stopping dbus-containers (Section
				// 15 of the spec) - this is the same Services/X/Enabled proxy
				// pattern as Settings > Integrations > Signal K, not a direct
				// write to the container service itself.
				dataItem.uid: Global.venusPlatform.serviceUid + "/Services/Containers/Enabled"

				// Disabling this stops dbus-containers, which in turn stops
				// every running container (reconciler.py's
				// stop_all_for_service_disable, found missing live - a
				// disabled container service used to leave every Podman
				// container running unsupervised) - too destructive to fire
				// on a bare click without confirmation. Enabling has no such
				// one-way risk, so it writes immediately; the toast after is
				// only a heads-up, not a gate.
				updateDataOnClick: false
				onClicked: {
					if (checked) {
						Global.dialogLayer.open(disableConfirmationDialogComponent)
					} else {
						dataItem.setValue(1)
						//% "Enabling containers may temporarily slow the system down while they start"
						Global.showToastNotification(VenusOS.Notification_Info,
								qsTrId("pagesettingscontainers_enable_slowdown_toast"), 10000)
					}
				}

				Component {
					id: disableConfirmationDialogComponent

					ModalWarningDialog {
						//% "Disable containers?"
						title: qsTrId("pagesettingscontainers_disable_confirm_title")
						//% "Every running container will be stopped. Definitions are kept, so containers can be started again from here once re-enabled."
						description: qsTrId("pagesettingscontainers_disable_confirm_description")
						dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
						onAccepted: enabledSwitch.dataItem.setValue(0)
					}
				}
			}

			SettingsColumn {
				width: parent ? parent.width : 0
				// Both leaves are published together (same backend change),
				// so checking one is enough to know whether either is safe
				// to read - but check both anyway, in case they land as two
				// separate writes.
				preferredVisible: enabledSwitch.checked && systemMaxMemory.valid && systemMaxCpu.valid

				SettingsListHeader {
					//% "System resources"
					text: qsTrId("pagesettingscontainers_system_resources")
				}

				ListResourceGauge {
					//% "Memory"
					text: qsTrId("pagesettingscontainerresources_memory")
					valueText: root.assignedMemoryText()
					value: allocatedMemory.value
					to: systemMaxMemory.value
				}

				ListResourceGauge {
					//% "CPU"
					text: qsTrId("pagesettingscontainerresources_cpu")
					valueText: root.assignedCpuText()
					value: allocatedCpu.value
					to: systemMaxCpu.value
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
					value: diskHostUsed.value
					to: diskHostTotal.value
					preferredVisible: !!diskUpdatedAt.value && diskHostTotal.value > 0
				}
			}

			SettingsListHeader {
				//% "Container service"
				text: qsTrId("pagesettingscontainers_container_service")
				preferredVisible: enabledSwitch.checked
			}

			ListNavigation {
				//% "Container service"
				text: qsTrId("pagesettingscontainers_container_service")
				secondaryText: Containers.serviceStateToText(serviceState.value)
				preferredVisible: enabledSwitch.checked
				onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsContainerService.qml", {"title": text})

				VeQuickItem {
					id: serviceState
					uid: root.containersServiceUid + "/State"
				}
			}

			ListButton {
				//% "Add container from file"
				text: qsTrId("pagesettingscontainers_add_from_file")
				//% "Add"
				secondaryText: qsTrId("pagesettingscontainers_add")
				preferredVisible: enabledSwitch.checked && importServiceConnected.valid
						&& importServiceConnected.value === 1
				writeAccessLevel: VenusOS.User_AccessType_User
				onClicked: {
					if (importState.value === 3) {
						Global.pageManager.pushPage("/pages/settings/PageSettingsContainerImport.qml",
								{"title": text})
					} else {
						Global.dialogLayer.open(containerImportDialogComponent)
					}
				}

				Component {
					id: containerImportDialogComponent

					ContainerImportDialog {
						onReviewReady: Qt.callLater(Global.pageManager.pushPage,
								"/pages/settings/PageSettingsContainerImport.qml",
								{"title": qsTrId("pagesettingscontainers_add_from_file")})
					}
				}
			}

			// A bare Repeater placed directly as a VisibleItemModel entry
			// never renders: VisibleItemModel's children must be real
			// visual row items (it filters each on its own
			// preferredVisible/effectiveVisible), not a Repeater, which has
			// no layout of its own and needs a real layout container to
			// position its generated children - confirmed live: the
			// Repeater's model was correctly populated (rowCount 3) the
			// whole time, but nothing appeared, because there was nothing
			// here for VisibleItemModel to lay out. Matches
			// PageSettingsBleSensors.qml's SettingsColumn-wrapped Repeater
			// exactly (PageSettingsVecanDevices.qml sidesteps this instead
			// by binding the dynamic model directly to the ListView, but
			// that page has no static rows above the list the way this one
			// does).
			SettingsColumn {
				width: parent ? parent.width : 0
				preferredVisible: enabledSwitch.checked && root.activeContainerCount > 0

				SettingsListHeader {
					//% "Containers"
					text: qsTrId("pagesettingscontainers_containers")
				}

				Repeater {
					id: containerRepeater

					model: VeQItemSortTableModel {
						model: VeQItemChildModel {
							model: containers
							childId: "Name"
						}
						dynamicSortFilter: true
						filterFlags: VeQItemSortTableModel.FilterInvalid
					}

					delegate: ListNavigation {
						id: containerDelegate

						required property VeQItem item

						readonly property string containerPrefix: item.itemParent().uid
						readonly property bool isDeleted: state.value === 7 // ContainerState.Deleted
						preferredVisible: !isDeleted

						// Exposed so root.recomputeUnlimitedCounts() can count how
						// many contributors (a container's own limit, and
						// separately its ContainerRuntime aggregate when
						// enabled) are Unlimited (0) - see that function's own
						// comment for why. The assigned sum itself comes
						// straight from the backend's own System/Allocated*
						// leaves, not from these.
						readonly property real memoryLimitBytes: memoryLimit.value
						readonly property real cpuLimitCores: cpuLimit.value
						readonly property bool runtimeEnabled: !!containerRuntimeEnabled.value
						readonly property real runtimeMemoryLimitBytes: runtimeMemoryLimit.value
						readonly property real runtimeCpuLimitCores: runtimeCpuLimit.value

						onMemoryLimitBytesChanged: root.recomputeUnlimitedCounts()
						onCpuLimitCoresChanged: root.recomputeUnlimitedCounts()
						onRuntimeEnabledChanged: root.recomputeUnlimitedCounts()
						onRuntimeMemoryLimitBytesChanged: root.recomputeUnlimitedCounts()
						onRuntimeCpuLimitCoresChanged: root.recomputeUnlimitedCounts()
						onIsDeletedChanged: root.recomputeUnlimitedCounts()

						text: item.value || ""
						// The image reference alone gave no hint that a
						// container has sub-containers of its own at all -
						// found live: Venus Grafana's own managed influxdb/
						// loader pair was completely invisible from this
						// list, only discoverable by opening the container
						// and finding its "Sub-containers" row. Appending
						// the same running-summary text that row itself
						// shows surfaces it here too, for either ownership
						// mode, without needing a whole extra row per
						// container.
						caption: {
							const base = image.value || ""
							if (childrenTotal.value <= 0) {
								return base
							}
							const summary = Containers.childRunningSummaryText(childrenRunning.value, childrenTotal.value)
							//% "%1 · %2"
							return base ? qsTrId("pagesettingscontainers_caption_with_children").arg(base).arg(summary) : summary
						}
						// While running, live resource usage is more useful
						// at a glance than a static "Running" label; while
						// blocked on a dependency, naming what it's waiting
						// for and when it'll retry is more useful than the
						// bare "Waiting to start" state text; while erroring,
						// what actually went wrong (and whether/when Venus
						// will retry it automatically) is more useful than
						// the bare "Failed" state text - a fleet of several
						// containers used to show identical "Failed" rows
						// for genuinely different problems (timeout vs.
						// image unavailable vs. identity provisioning),
						// indistinguishable without opening each one's own
						// page (confirmed live on a raspberrypi5 test
						// device, 2026-09-02, mass-creating several
						// dedicated containers at once). Everything else
						// (Stopped/Starting/etc) still falls back to the
						// plain state text.
						secondaryText: {
							if (state.value === 4) { // ContainerState.Running
								//% "%1% CPU, %2 MB"
								return qsTrId("pagesettingscontainers_running_stats")
										.arg(Math.round(cpuUsage.value)).arg(Containers.bytesToMebibytes(memoryUsage.value))
							}
							if (state.value === 8) { // ContainerState.WaitingForDependency
								return Containers.waitingForDependencyText(dependency.value, retryIn.value)
							}
							if (errorCode.value !== 0) {
								return Containers.errorSummaryText(errorCode.value, errorText.value, retryIn.value)
							}
							return Containers.stateToText(state.value)
						}
						onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsContainer.qml",
								{"title": text, "containerPrefix": containerPrefix})

						// Centre the resource usage, status dot and chevron against the
						// list item independently of the two-line name/image block.
						contentItem: Item {
							implicitWidth: Theme.geometry_listItem_width
							implicitHeight: identityColumn.implicitHeight

							ColumnLayout {
								id: identityColumn

								anchors {
									left: parent.left
									right: rightContent.left
									rightMargin: containerDelegate.spacing
									verticalCenter: parent.verticalCenter
								}
								spacing: 0

								Label {
									text: containerDelegate.text
									font: containerDelegate.font
									textFormat: containerDelegate.textFormat
									wrapMode: Text.WordWrap
									Layout.fillWidth: true
								}

								CaptionLabel {
									text: containerDelegate.caption
									visible: text.length > 0
									Layout.fillWidth: true
								}
							}

							Item {
								id: rightContent
								implicitWidth: statusLabel.implicitWidth + containerDelegate.spacing + forwardIcon.implicitWidth
								implicitHeight: Math.max(statusLabel.implicitHeight, forwardIcon.implicitHeight)

								anchors {
									right: parent.right
									verticalCenter: parent.verticalCenter
								}

								SecondaryListLabel {
									id: statusLabel

									anchors {
										left: parent.left
										verticalCenter: parent.verticalCenter
									}
									text: containerDelegate.secondaryText
								}

								ForwardIcon {
									id: forwardIcon

									anchors {
										right: parent.right
										verticalCenter: parent.verticalCenter
									}
									visible: containerDelegate.interactive
								}

								Item {
									anchors {
										left: statusLabel.right
										right: forwardIcon.left
										top: parent.top
										bottom: parent.bottom
									}

									Rectangle {
										id: statusDot

										anchors.centerIn: parent
										anchors.horizontalCenterOffset: 8
										anchors.verticalCenterOffset: -2
										width: 16
										height: 16
										radius: 8
										color: Containers.severityColor(state.value, errorCode.value, dbusState.value)
										visible: color != "transparent"
									}
								}
							}
						}

						VeQuickItem {
							id: image
							uid: containerPrefix + "/Image"
						}
						// Unified across both child ownership modes (docs/
						// dbus-api.md note 5) - "" for the overwhelming
						// majority with no children of either kind, so the
						// caption addition below is likewise absent for
						// almost every container.
						VeQuickItem {
							id: childrenTotal
							uid: containerPrefix + "/Children/TotalCount"
						}
						VeQuickItem {
							id: childrenRunning
							uid: containerPrefix + "/Children/RunningCount"
						}
						VeQuickItem {
							id: state
							uid: containerPrefix + "/State"
						}
						VeQuickItem {
							id: errorCode
							uid: containerPrefix + "/ErrorCode"
						}
						VeQuickItem {
							id: errorText
							uid: containerPrefix + "/Error"
						}
						VeQuickItem {
							id: dbusState
							uid: containerPrefix + "/Dbus/State"
						}
						VeQuickItem {
							id: dependency
							uid: containerPrefix + "/Dependency"
						}
						VeQuickItem {
							id: retryIn
							uid: containerPrefix + "/RetryIn"
						}
						VeQuickItem {
							id: cpuUsage
							uid: containerPrefix + "/Resources/CpuUsage"
						}
						VeQuickItem {
							id: memoryUsage
							uid: containerPrefix + "/Resources/MemoryUsage"
						}
						VeQuickItem {
							id: memoryLimit
							uid: containerPrefix + "/Resources/MemoryLimit"
						}
						VeQuickItem {
							id: cpuLimit
							uid: containerPrefix + "/Resources/CpuLimit"
						}
						VeQuickItem {
							id: containerRuntimeEnabled
							uid: containerPrefix + "/ContainerRuntime/Enabled"
						}
						VeQuickItem {
							id: runtimeMemoryLimit
							uid: containerPrefix + "/ContainerRuntime/Resources/MemoryLimitBytes"
						}
						VeQuickItem {
							id: runtimeCpuLimit
							uid: containerPrefix + "/ContainerRuntime/Resources/CpuLimit"
						}
					}

					// Covers rows appearing/disappearing - each row's own
					// onMemoryLimitBytesChanged etc (above) covers live value
					// changes on an already-existing row.
					onCountChanged: root.recomputeUnlimitedCounts()
				}
			}

			SettingsColumn {
				width: parent ? parent.width : 0
				preferredVisible: enabledSwitch.checked && root.deletedContainerCount > 0

				SettingsListHeader {
					//% "Deleted containers"
					text: qsTrId("pagesettingscontainers_deleted_containers")
				}

				Repeater {
					model: VeQItemSortTableModel {
						model: VeQItemChildModel {
							model: containers
							childId: "Name"
						}
						dynamicSortFilter: true
						filterFlags: VeQItemSortTableModel.FilterInvalid
					}

					delegate: ListNavigation {
						required property VeQItem item
						readonly property string containerPrefix: item.itemParent().uid

						text: item.value || ""
						caption: image.value || ""
						//% "Deleted - restore or permanently remove"
						secondaryText: qsTrId("pagesettingscontainers_deleted_action")
						preferredVisible: state.value === 7 // ContainerState.Deleted
						onClicked: Global.pageManager.pushPage("/pages/settings/PageSettingsContainer.qml",
								{"title": text, "containerPrefix": containerPrefix})

						VeQuickItem { id: image; uid: containerPrefix + "/Image" }
						VeQuickItem { id: state; uid: containerPrefix + "/State" }
					}
				}
			}
		}
	}
}

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
				preferredVisible: enabledSwitch.checked && containerRepeater.count > 0

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

						text: item.value || ""
						caption: image.value || ""
						// While running, live resource usage is more useful
						// at a glance than a static "Running" label - the
						// state text still applies for every other state
						// (Stopped/Starting/Error/etc).
						secondaryText: state.value === 4 // ContainerState.Running, see Containers.qml
								//% "%1% CPU, %2 MB"
								? qsTrId("pagesettingscontainers_running_stats")
										.arg(Math.round(cpuUsage.value)).arg(Containers.bytesToMebibytes(memoryUsage.value))
								: Containers.stateToText(state.value)
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
										color: Containers.severityColor(state.value, errorCode.value)
										visible: color != "transparent"
									}
								}
							}
						}

						VeQuickItem {
							id: image
							uid: containerPrefix + "/Image"
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
							id: cpuUsage
							uid: containerPrefix + "/Resources/CpuUsage"
						}
						VeQuickItem {
							id: memoryUsage
							uid: containerPrefix + "/Resources/MemoryUsage"
						}
					}
				}
			}
		}
	}
}

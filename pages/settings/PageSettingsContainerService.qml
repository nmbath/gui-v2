/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

/*
	com.victronenergy.containers service-level status (venus-containers Drop
	3 spec Section 14 point 6 / Section 7.1 - service-level paths, not the
	per-container ones). Read-only except PruneImages, a trigger-path
	matching /Containers/<UUID>/Admin/Purge's own convention (docs/dbus-api.md,
	Decisions).
*/
Page {
	id: root

	readonly property string containersServiceUid: BackendConnection.serviceUidForType("containers")
	readonly property string storageMigrationText: {
		const id = "pagesettingscontainers_service_migrating_storage"
		//% "Migrating container storage"
		const translated = qsTrId("pagesettingscontainers_service_migrating_storage")
		return translated === id ? qsTr("Migrating container storage") : translated
	}

	VeQuickItem { id: serviceState; uid: root.containersServiceUid + "/State" }
	VeQuickItem { id: errorCode; uid: root.containersServiceUid + "/ErrorCode" }
	VeQuickItem { id: errorText; uid: root.containersServiceUid + "/Error" }
	VeQuickItem { id: migrationState; uid: root.containersServiceUid + "/Storage/Migration/State" }
	readonly property bool storageMigrationInProgress: migrationState.value > 0 && migrationState.value < 7
	readonly property bool storageMissing: errorCode.value === 29 && !root.storageMigrationInProgress
	VeQuickItem { id: containerCount; uid: root.containersServiceUid + "/ContainerCount" }
	VeQuickItem { id: runningCount; uid: root.containersServiceUid + "/RunningCount" }
	VeQuickItem { id: backendName; uid: root.containersServiceUid + "/Backend/Name" }
	VeQuickItem { id: backendVersion; uid: root.containersServiceUid + "/Backend/Version" }
	VeQuickItem { id: pruneImages; uid: root.containersServiceUid + "/Backend/PruneImages" }
	VeQuickItem { id: runtimeName; uid: root.containersServiceUid + "/Runtime/Name" }
	VeQuickItem { id: runtimeVersion; uid: root.containersServiceUid + "/Runtime/Version" }
	VeQuickItem { id: cgroupVersion; uid: root.containersServiceUid + "/Runtime/CgroupVersion" }
	VeQuickItem { id: dbusProxyState; uid: root.containersServiceUid + "/DbusProxy/State" }

	GradientListView {
		model: VisibleItemModel {
			SettingsColumn {
				width: parent ? parent.width : 0
				preferredVisible: root.storageMissing

				SettingsListHeader {
					//% "Missing storage"
					text: qsTrId("pagesettingscontainerservice_missing_storage")
				}

				PrimaryListLabel {
					//% "The selected container storage is unavailable. Reconnect it or choose another storage location."
					text: qsTrId("pagesettingscontainerservice_missing_storage_description")
				}

				ListNavigation {
					//% "Choose container storage"
					text: qsTrId("pagesettingscontainerservice_choose_storage")
					onClicked: {
						// Replace this intermediate details page with the existing
						// storage picker, so leaving the picker returns directly to
						// the main Containers page.
						Global.pageManager.popPage(undefined, PageStack.Immediate)
						Qt.callLater(Global.pageManager.pushPage,
								"/pages/settings/PageSettingsContainerStorage.qml", {"title": text})
					}
				}
			}

			SettingsListHeader {
				//% "Status"
				text: qsTrId("pagesettingscontainerservice_status")
			}

			ListText {
				//% "Service state"
				text: qsTrId("pagesettingscontainerservice_state")
				secondaryText: root.storageMigrationInProgress
						? root.storageMigrationText
						: Containers.serviceStateToText(serviceState.value)
				secondaryTextColor: root.storageMigrationInProgress
						? Theme.color_warning : Theme.color_listItem_secondaryText
			}

			PrimaryListLabel {
				//% "Error: %1"
				text: qsTrId("pagesettingscontainerservice_error").arg(errorText.value)
				preferredVisible: !root.storageMigrationInProgress
						&& errorCode.value !== 0 && !!errorText.value
			}

			ListText {
				//% "Containers"
				text: qsTrId("pagesettingscontainerservice_containers")
				//% "%1 running of %2"
				secondaryText: qsTrId("pagesettingscontainerservice_containers_value")
						.arg(runningCount.value).arg(containerCount.value)
			}

			SettingsListHeader {
				//% "Runtime"
				text: qsTrId("pagesettingscontainerservice_runtime")
			}

			ListText {
				//% "Container backend"
				text: qsTrId("pagesettingscontainerservice_backend")
				//% "%1 %2"
				secondaryText: qsTrId("pagesettingscontainerservice_backend_value")
						.arg(backendName.value || "").arg(backendVersion.value || "")
			}

			ListText {
				//% "OCI runtime"
				text: qsTrId("pagesettingscontainerservice_oci_runtime")
				//% "%1 %2"
				secondaryText: qsTrId("pagesettingscontainerservice_oci_runtime_value")
						.arg(runtimeName.value || "").arg(runtimeVersion.value || "")
			}

			ListText {
				//% "Cgroup version"
				text: qsTrId("pagesettingscontainerservice_cgroup_version")
				secondaryText: cgroupVersion.value || ""
			}

			ListText {
				//% "D-Bus proxy"
				text: qsTrId("pagesettingscontainerservice_dbus_proxy")
				// DbusProxyState (0=Unknown/1=Ready/2=Unavailable) - a
				// distinct enum from ServiceState above, not the same
				// 0/1/2 meanings even though the numbers overlap.
				secondaryText: Containers.dbusProxyStateToText(dbusProxyState.value)
			}

			SettingsListHeader {
				//% "Maintenance"
				text: qsTrId("pagesettingscontainerservice_maintenance")
			}

			ListButton {
				//% "Remove unused images"
				text: qsTrId("pagesettingscontainerservice_prune_images")
				//% "Removes backend images that no longer belong to any managed container"
				caption: qsTrId("pagesettingscontainerservice_prune_images_caption")
				writeAccessLevel: VenusOS.User_AccessType_Installer
				secondaryText: pruneImages.value === 1
						//% "Removing..."
						? qsTrId("pagesettingscontainerservice_prune_images_busy")
						//% "Remove"
						: qsTrId("pagesettingscontainerservice_prune_images_button")
				readOnly: pruneImages.value === 1
				onClicked: pruneImages.setValue(1)
			}
		}
	}
}

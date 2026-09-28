/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

/*
	BackgroundActivity.qml's containers provider - surfaces two venus-containers
	operations that can run for a long time with the user off the page that
	started them: an image pull (per-container /Image/Pull* leaves, State
	Creating/Recreating) and a Storage Manager volume migration
	(/Storage/Migration/*). Both are already shown inline on their own settings
	page (PageSettingsContainers.qml, PageSettingsContainerStorage.qml) - this
	just re-reads the same leaves so the top bar knows about them too.

	Entirely inert when the containers integration isn't installed:
	containersServiceUid is then "", so the table model has zero rows and the
	Migration/* VeQuickItems are simply .valid == false.
*/
QtObject {
	id: root

	readonly property string containersServiceUid: BackendConnection.serviceUidForType("containers")

	readonly property bool serviceStarting: serviceState.valid && Number(serviceState.value) === 0
	readonly property bool busy: root.serviceStarting || root.pullingItems.length > 0 || root.migrationInProgress

	readonly property var items: {
		let result = []
		if (root.serviceStarting) {
			result.push({
				//% "Containers"
				service: root.translatedText("containersactivity_service", "Containers"),
				//% "Starting container service"
				action: root.translatedText("containersactivity_service_starting", "Starting container service"),
				//% "Initialising"
				progress: root.translatedText("containersactivity_service_initialising", "Initialising")
			})
		}
		result = result.concat(root.pullingItems)
		if (root.migrationInProgress) {
			result.push({
				//% "Containers"
				service: root.translatedText("containersactivity_service", "Containers"),
				//% "Migrating container storage"
				action: root.translatedText("containersactivity_storage_migration_action",
						"Migrating container storage"),
				progress: Containers.migrationProgressText(migrationItemsDone.value, migrationItemsTotal.value)
			})
		}
		return result
	}

	property var pullingItems: []

	function translatedText(id, fallback) {
		const translated = qsTrId(id)
		return translated === id ? qsTr(fallback) : translated
	}

	function waitingProgress(dependency, retryInSeconds) {
		if (dependency === "StartupDelay") {
			if (retryInSeconds > 0) {
				//% "Starts in %1s"
				return root.translatedText("containersactivity_scheduled_start_countdown",
						"Starts in %1s").arg(retryInSeconds)
			}
			//% "Scheduled to start"
			return root.translatedText("containersactivity_scheduled_start_ready", "Scheduled to start")
		}
		let dependencyText = dependency
		switch (dependency) {
		case "DbusProxy":
			dependencyText = root.translatedText("containersactivity_dependency_dbus", "D-Bus service")
			break
		case "RuntimeApi":
			dependencyText = root.translatedText("containersactivity_dependency_runtime", "container service")
			break
		case "Storage":
			dependencyText = root.translatedText("containersactivity_dependency_storage", "container storage")
			break
		case "StorageMigration":
			dependencyText = root.translatedText("containersactivity_dependency_migration", "storage migration")
			break
		}
		if (!dependencyText) {
			return root.translatedText("containersactivity_waiting", "Waiting to start")
		}
		if (retryInSeconds > 0) {
			return root.translatedText("containersactivity_waiting_retry", "Waiting for %1 - retry in %2s")
					.arg(dependencyText).arg(retryInSeconds)
		}
		return root.translatedText("containersactivity_waiting_for", "Waiting for %1").arg(dependencyText)
	}

	function _recomputePullingItems() {
		let result = []
		for (let i = 0; i < _containerWatchers.count; ++i) {
			const watcher = _containerWatchers.objectAt(i)
			if (watcher && watcher.isActive) {
				let action = ""
				let progress = ""
				if (watcher.isCreating) {
					action = watcher.containerState === 6
							? root.translatedText("containersactivity_updating", "Updating %1").arg(watcher.containerName)
							: root.translatedText("containersactivity_creating", "Creating %1").arg(watcher.containerName)
					progress = Containers.creatingProgressText(watcher.pullLayersDone, watcher.pullLayersTotal, 0)
				} else if (watcher.containerState === 3 || watcher.containerState === 8) {
					//% "Starting %1"
					action = root.translatedText("containersactivity_starting", "Starting %1").arg(watcher.containerName)
					progress = watcher.containerState === 8
							? root.waitingProgress(watcher.dependency, watcher.retryIn)
							//% "Starting"
							: root.translatedText("containersactivity_starting_progress", "Starting")
				} else {
					//% "Stopping %1"
					action = root.translatedText("containersactivity_stopping", "Stopping %1").arg(watcher.containerName)
					//% "Stopping"
					progress = root.translatedText("containersactivity_stopping_progress", "Stopping")
				}
				result.push({
					//% "Containers"
					service: root.translatedText("containersactivity_service", "Containers"),
					action: action,
					progress: progress
				})
			}
		}
		root.pullingItems = result
	}

	readonly property VeQItemSortTableModel _containers: VeQItemSortTableModel {
		model: VeQItemTableModel {
			uids: [root.containersServiceUid + "/Containers"]
			flags: VeQItemTableModel.AddChildren |
				   VeQItemTableModel.AddNonLeaves |
				   VeQItemTableModel.DontAddItem
		}
		dynamicSortFilter: true
		filterFlags: VeQItemSortTableModel.FilterOffline
	}

	// Instantiator, not Repeater - this is a non-visual QtObject (see
	// data/Storage.qml's _volumeWatchers for the same pattern in this codebase).
	readonly property Instantiator _containerWatchers: Instantiator {
		model: VeQItemChildModel {
			model: root._containers
			childId: "Name"
		}
		delegate: Item {
			required property var item

			// Item, not QtObject - QtObject has no default property, so a
			// bare VeQuickItem child below fails to parent at all. Never
			// shown - Instantiator doesn't parent/position its delegates
			// visually.
			id: watcher
			readonly property string containerPrefix: item?.itemParent()?.uid ?? ""
			readonly property string containerName: item?.value ?? ""
			readonly property int containerState: Number(stateItem.value ?? 0)
			readonly property bool isCreating: containerState === 1 || containerState === 6 // ContainerState Creating/Recreating
			readonly property bool isActive: isCreating || containerState === 3 || containerState === 5
					|| containerState === 8 // Starting/Stopping/WaitingForDependency
			readonly property string dependency: dependencyItem.value ?? ""
			readonly property int retryIn: Number(retryInItem.value ?? 0)
			readonly property int pullLayersDone: Number(pullLayersDoneItem.value ?? 0)
			readonly property int pullLayersTotal: Number(pullLayersTotalItem.value ?? -1)

			onContainerNameChanged: root._recomputePullingItems()
			onIsActiveChanged: root._recomputePullingItems()
			onDependencyChanged: root._recomputePullingItems()
			onRetryInChanged: root._recomputePullingItems()
			onPullLayersDoneChanged: root._recomputePullingItems()
			onPullLayersTotalChanged: root._recomputePullingItems()
			Component.onCompleted: root._recomputePullingItems()

			VeQuickItem { id: stateItem; uid: watcher.containerPrefix + "/State" }
			VeQuickItem { id: dependencyItem; uid: watcher.containerPrefix + "/Dependency" }
			VeQuickItem { id: retryInItem; uid: watcher.containerPrefix + "/RetryIn" }
			VeQuickItem { id: pullLayersDoneItem; uid: watcher.containerPrefix + "/Image/PullLayersDone" }
			VeQuickItem { id: pullLayersTotalItem; uid: watcher.containerPrefix + "/Image/PullLayersTotal" }
		}
		onObjectRemoved: root._recomputePullingItems()
	}

	// /Storage/Migration/State values (venus-containers' enums.py
	// StorageMigrationState): 0 Idle, 1 Stopping, 2 Copying, 3 Verifying,
	// 4 Mounting, 5 Switching, 6 Resuming, 7 Failed.
	readonly property bool migrationInProgress: migrationState.value > 0 && migrationState.value < 7

	// Named properties, not bare children - QtObject has no default
	// property (see the Instantiator delegate comment above).
	readonly property VeQuickItem migrationState: VeQuickItem { uid: root.containersServiceUid + "/Storage/Migration/State" }
	readonly property VeQuickItem migrationItemsDone: VeQuickItem { uid: root.containersServiceUid + "/Storage/Migration/ItemsDone" }
	readonly property VeQuickItem migrationItemsTotal: VeQuickItem { uid: root.containersServiceUid + "/Storage/Migration/ItemsTotal" }
	readonly property VeQuickItem serviceState: VeQuickItem { uid: root.containersServiceUid + "/State" }
}

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

	readonly property bool busy: root.pullingItems.length > 0 || root.migrationInProgress

	readonly property var items: {
		let result = root.pullingItems.slice()
		if (root.migrationInProgress) {
			result.push({
				//% "Container storage"
				label: qsTrId("containersactivity_storage_migration_label"),
				detail: Containers.migrationProgressText(migrationItemsDone.value, migrationItemsTotal.value),
				onActivate: function() {
					Global.pageManager.pushPage("/pages/settings/PageSettingsContainerStorage.qml")
				}
			})
		}
		return result
	}

	property var pullingItems: []

	function _recomputePullingItems() {
		let result = []
		for (let i = 0; i < _containerWatchers.count; ++i) {
			const watcher = _containerWatchers.objectAt(i)
			if (watcher && watcher.isCreating) {
				result.push({
					label: watcher.containerName,
					detail: Containers.creatingProgressText(watcher.pullLayersDone, watcher.pullLayersTotal, 0)
							|| Containers.stateToText(watcher.state),
					onActivate: (function(prefix, name) {
						return function() {
							Global.pageManager.pushPage("/pages/settings/PageSettingsContainer.qml",
									{"title": name, "containerPrefix": prefix})
						}
					})(watcher.containerPrefix, watcher.containerName)
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
			// Item, not QtObject - QtObject has no default property, so a
			// bare VeQuickItem child below fails to parent at all. Never
			// shown - Instantiator doesn't parent/position its delegates
			// visually.
			id: watcher
			readonly property string containerPrefix: model.item.itemParent().uid
			readonly property string containerName: model.item.value || ""
			readonly property int state: stateItem.value
			readonly property bool isCreating: state === 1 || state === 6 // ContainerState Creating/Recreating
			readonly property int pullLayersDone: pullLayersDoneItem.value
			readonly property int pullLayersTotal: pullLayersTotalItem.value

			onContainerNameChanged: root._recomputePullingItems()
			onIsCreatingChanged: root._recomputePullingItems()
			onPullLayersDoneChanged: root._recomputePullingItems()
			onPullLayersTotalChanged: root._recomputePullingItems()
			Component.onCompleted: root._recomputePullingItems()

			VeQuickItem { id: stateItem; uid: watcher.containerPrefix + "/State" }
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
}

/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

/*
	Storage Manager volume picker for venus-containers. The GUI writes a stable
	volume id to dbus-containers' /Storage/Select trigger; that backend registers
	plain usage (RegisterUsage, no roles/capacity admission - see allocation.py)
	and changes /Storage/VolumeId only once the registration is Ready.

	Clicking an unselected candidate first scans it (ScanVolume/ScanResults) for
	container definitions already on it, not yet known to this device - "this
	volume already has containers" (Part B). If any are found, a dialog offers
	importing them onto the *current* volume without switching (the only import
	target the backend supports - ImportFoundDefinition always imports onto
	whatever is currently selected, never the scanned candidate itself); the
	normal switch/migrate flow below proceeds either way once that's resolved.
*/
Page {
	id: root

	readonly property string containersServiceUid: BackendConnection.serviceUidForType("containers")
	readonly property string storageServiceUid: BackendConnection.serviceUidForType("storage")
	readonly property string currentVolumeId: selectedVolume.value || ""
	property string requestedVolumeId
	property string pendingSelectVolumeId
	property var usedByConsumers: ({})
	property var orphanedVolumeIds: []
	property var foundVolumeIds: []
	property bool migrateRequested: false
	// Part B: the "this volume already has containers" scan/import flow.
	// The candidate volume a scan was most recently requested for - "" once
	// its ScanResults have been handled, so a stale/unrelated result (e.g.
	// something else on the same leaf) is never acted on twice.
	property string pendingScanVolumeId: ""
	// Not-yet-known containers from the most recently handled scan result,
	// backing foundContainersDialogComponent's list.
	property var foundContainers: []
	// UUIDs still to import, drained one at a time via importFoundDefinitionAction
	// - ImportFoundDefinition is a single-value BusItem trigger (GUIv2 can't call
	// a method with a list argument), so a multi-container import is a sequence
	// of individual writes, not one call.
	property var importQueue: []
	property bool importInFlight: false
	property bool importQueueStarted: false
	// "keep" or "delete" - which choice the insufficient-space branch's
	// second confirm dialog is about.
	property string pendingResetChoice: ""
	// Set only for the insufficient-space "delete" choice: the old
	// volume to purge once the switch to pendingSelectVolumeId is
	// confirmed - see selectedVolume's onValueChanged below.
	property string pendingPurgeVolumeId: ""
	property bool pendingConfirmMigrateAfterClose: false
	property bool pendingConfirmResetAfterClose: false
	// Set when the found-containers dialog is dismissed without importing -
	// the normal migrate/select decision should still run, once this dialog
	// has actually finished closing (same reasoning as the two flags above).
	property bool pendingProceedAfterClose: false

	// /Storage/Migration/State values (enums.py's StorageMigrationState) -
	// plain ints rather than a new C++ enum, since this GUI change can't be
	// build-verified from here: 0 Idle, 1 Stopping, 2 CopyingRuntime,
	// 3 CopyingVolumes, 4 Verifying, 5 Switching, 6 Deleting, 7 Resuming,
	// 8 Failed.
	readonly property bool migrationInProgress: migrationState.value > 0 && migrationState.value < 7

	VeQuickItem {
		id: selectedVolume
		uid: root.containersServiceUid + "/Storage/VolumeId"
		onValueChanged: {
			// A migrate's VolumeId flips as soon as it reaches the
			// Switching step, well before containers have actually
			// restarted - popping the page here for that case would be
			// premature. migrationState's own watcher below handles the
			// migrate case instead, gated on genuinely reaching Idle.
			if (root.requestedVolumeId && value === root.requestedVolumeId && !root.migrateRequested) {
				root.requestedVolumeId = ""
				Global.pageManager.popPage(root)
			}
			if (root.pendingPurgeVolumeId && value === root.pendingSelectVolumeId) {
				purgeOrphanAction.setValue(root.pendingPurgeVolumeId)
				root.pendingPurgeVolumeId = ""
			}
		}
	}

	VeQuickItem {
		id: selectAction
		uid: root.containersServiceUid + "/Storage/Select"
	}

	VeQuickItem {
		id: migrateAction
		uid: root.containersServiceUid + "/Storage/Migrate"
	}

	VeQuickItem {
		id: hasExistingData
		uid: root.containersServiceUid + "/Storage/HasExistingData"
	}

	// Real bytes containers currently occupy on the volume in use - the
	// figure to compare against a candidate destination's free space,
	// proactively, before ever starting a migration (not just reactively
	// after the backend's own preflight rejects it).
	VeQuickItem { id: usedBytes; uid: root.containersServiceUid + "/Storage/UsedBytes" }
	// "/data" (allocation.py's LOCAL_DATA_VOLUME_ID) is this device's own
	// internal storage, not a Storage Manager volume - it never appears in
	// the /Volumes tree the rest of this page scans, so its free space
	// needs its own leaf rather than a volumeInfoById lookup.
	VeQuickItem { id: localDataFreeBytes; uid: root.containersServiceUid + "/Storage/LocalDataFreeBytes" }

	VeQuickItem {
		id: migrationState
		uid: root.containersServiceUid + "/Storage/Migration/State"
		onValueChanged: {
			if (!root.migrateRequested) {
				return
			}
			if (value === 0) { // StorageMigrationState.IDLE - genuinely done, containers restarted.
				root.migrateRequested = false
				root.requestedVolumeId = ""
				//% "Storage changed - containers are running on the new volume."
				Global.showToastNotification(VenusOS.Notification_Info, qsTrId("pagesettingscontainerstorage_migrate_complete"), 6000)
				Global.pageManager.popPage(root)
			} else if (value === 8) { // StorageMigrationState.FAILED - selectionError's own watcher shows the toast.
				root.migrateRequested = false
			}
		}
	}
	VeQuickItem { id: migrationItemsDone; uid: root.containersServiceUid + "/Storage/Migration/ItemsDone" }
	VeQuickItem { id: migrationItemsTotal; uid: root.containersServiceUid + "/Storage/Migration/ItemsTotal" }

	VeQuickItem {
		id: purgeOrphanAction
		uid: root.containersServiceUid + "/Storage/PurgeOrphan"
	}

	VeQuickItem {
		id: orphanedVolumesItem
		uid: root.containersServiceUid + "/Storage/OrphanedVolumes"
		onValueChanged: {
			try {
				root.orphanedVolumeIds = JSON.parse(value || "[]")
			} catch (e) {
				root.orphanedVolumeIds = []
			}
		}
	}

	VeQuickItem {
		id: foundVolumesItem
		uid: root.containersServiceUid + "/Storage/FoundVolumes"
		onValueChanged: {
			try {
				root.foundVolumeIds = JSON.parse(value || "[]")
			} catch (e) {
				root.foundVolumeIds = []
			}
		}
	}

	VeQuickItem {
		id: dismissFoundVolumeAction
		uid: root.containersServiceUid + "/Storage/DismissFoundVolume"
	}

	VeQuickItem {
		id: scanVolumeAction
		uid: root.containersServiceUid + "/Storage/ScanVolume"
	}

	VeQuickItem {
		id: scanResultsItem
		uid: root.containersServiceUid + "/Storage/ScanResults"
		onValueChanged: root.handleScanResults(value)
	}

	VeQuickItem {
		id: importFoundDefinitionAction
		uid: root.containersServiceUid + "/Storage/ImportFoundDefinition"
		onValueChanged: {
			// Trigger leaves reset to "" once the backend has processed them
			// (see /Storage/Select's own onValueChanged above for the same
			// pattern) - only act on *our own* reset, guarded by importInFlight,
			// not an unrelated external clear of the same leaf.
			if (value === "" && root.importInFlight) {
				root.importInFlight = false
				root.drainImportQueue()
			}
		}
	}

	function handleScanResults(jsonText) {
		if (!root.pendingScanVolumeId) {
			return // not waiting on a scan - an unrelated/stale publish
		}
		let parsed
		try {
			parsed = JSON.parse(jsonText || "{}")
		} catch (e) {
			return
		}
		if (parsed.volumeId !== root.pendingScanVolumeId) {
			return // stale result for a volume we're no longer waiting on
		}
		root.pendingScanVolumeId = ""
		const containers = parsed.containers || []
		root.foundContainers = containers.filter(function (c) { return !c.already_known })
		if (root.foundContainers.length > 0) {
			Global.dialogLayer.open(foundContainersDialogComponent)
		} else {
			root.proceedWithVolumeSelection(root.pendingSelectVolumeId)
		}
	}

	function startFoundContainersImport() {
		root.importQueue = root.foundContainers.map(function (c) { return c.uuid })
		root.foundContainers = []
		root.importQueueStarted = true
		root.drainImportQueue()
	}

	function drainImportQueue() {
		if (root.importQueue.length === 0) {
			if (root.importQueueStarted) {
				root.importQueueStarted = false
				//% "Containers imported onto the current volume."
				Global.showToastNotification(VenusOS.Notification_Info, qsTrId("pagesettingscontainerstorage_import_complete"), 5000)
			}
			return
		}
		const queue = root.importQueue
		const uuid = queue[0]
		root.importQueue = queue.slice(1)
		root.importInFlight = true
		importFoundDefinitionAction.setValue(uuid)
	}

	VeQuickItem {
		id: selectionError
		uid: root.containersServiceUid + "/Storage/SelectionError"
		onValueChanged: {
			if (root.requestedVolumeId && value) {
				root.requestedVolumeId = ""
				root.migrateRequested = false
				Global.showToastNotification(VenusOS.Notification_Warning, value, 8000)
			}
		}
	}

	function migrationProgressText() {
		//% "Migrating storage (%1/%2)…"
		return qsTrId("pagesettingscontainerstorage_migrating").arg(migrationItemsDone.value || 0).arg(migrationItemsTotal.value || 0)
	}

	// The existing migrate/select decision tree, unchanged in substance -
	// just factored out so it can run either directly (nothing found on
	// scan) or after the found-containers dialog is dismissed. Uses
	// volumeInfoById rather than a delegate's own bound properties, since
	// this can run asynchronously, well after the click that started it.
	function proceedWithVolumeSelection(volumeId) {
		if (!volumeId) {
			return
		}
		if (!hasExistingData.value) {
			// Nothing to migrate - switch immediately.
			root.requestedVolumeId = volumeId
			selectAction.setValue(volumeId)
			return
		}
		root.pendingSelectVolumeId = volumeId
		let freeBytes
		if (volumeId === "/data") {
			freeBytes = localDataFreeBytes.value
		} else {
			const info = root.volumeInfoById[volumeId] || { used: 0, capacity: 0 }
			freeBytes = Math.max(0, info.capacity - info.used)
		}
		if (usedBytes.value <= freeBytes) {
			Global.dialogLayer.open(confirmMigrateDialogComponent)
		} else {
			Global.dialogLayer.open(insufficientSpaceDialogComponent)
		}
	}

	// Waits for a dialog to actually finish closing (not just accept()
	// being called, which may still be animating) before opening the
	// next one - chaining dialogLayer.open() calls synchronously risks
	// the first dialog's own closed-signal handler destroying the second
	// dialog instead of the first. Same pattern venus-storage's GUI uses
	// for its own chained Reformat dialogs.
	Connections {
		target: Global.dialogLayer
		function onCurrentDialogChanged() {
			if (Global.dialogLayer.currentDialog) {
				return
			}
			if (root.pendingConfirmMigrateAfterClose) {
				root.pendingConfirmMigrateAfterClose = false
				Global.dialogLayer.open(confirmMigrateFinalDialogComponent)
			} else if (root.pendingConfirmResetAfterClose) {
				root.pendingConfirmResetAfterClose = false
				Global.dialogLayer.open(confirmResetDialogComponent)
			} else if (root.pendingProceedAfterClose) {
				root.pendingProceedAfterClose = false
				root.proceedWithVolumeSelection(root.pendingSelectVolumeId)
			}
		}
	}

	VeQItemSortTableModel {
		id: volumes
		model: VeQItemTableModel {
			uids: [root.storageServiceUid + "/Volumes"]
			flags: VeQItemTableModel.AddChildren |
				   VeQItemTableModel.AddNonLeaves |
				   VeQItemTableModel.DontAddItem
		}
		dynamicSortFilter: true
		filterFlags: VeQItemSortTableModel.FilterOffline
	}

	VeQItemSortTableModel {
		id: allocations
		model: VeQItemTableModel {
			uids: [root.storageServiceUid + "/Allocations"]
			flags: VeQItemTableModel.AddChildren |
				   VeQItemTableModel.AddNonLeaves |
				   VeQItemTableModel.DontAddItem
		}
		dynamicSortFilter: true
		filterFlags: VeQItemSortTableModel.FilterOffline
	}

	function recomputeUsedByConsumers() {
		let result = {}
		for (let i = 0; i < allocationRepeater.count; ++i) {
			const row = allocationRepeater.itemAt(i)
			if (!row || !row.ready || !row.volumeId || !row.consumer) {
				continue
			}
			let consumers = result[row.volumeId] || []
			if (consumers.indexOf(row.consumer) < 0) {
				consumers.push(row.consumer)
			}
			result[row.volumeId] = consumers
		}
		root.usedByConsumers = result
	}

	function consumerDisplayName(consumer) {
		if (consumer === "containers") {
			//% "Containers"
			return qsTrId("pagesettingscontainers_containers")
		}
		if (consumer === "vrmlogger") {
			//% "VRM online logging"
			return qsTrId("pagesettingscontainerstorage_vrm_logger")
		}
		return consumer
	}

	function usedByText(volumeId) {
		const consumers = root.usedByConsumers[volumeId] || []
		if (consumers.length === 0) {
			return ""
		}
		const names = consumers.map(root.consumerDisplayName)
		//% "Used by: %1"
		return qsTrId("pagesettingscontainerstorage_used_by").arg(names.join(", "))
	}

	// Lets someone picking a *new* volume see how much is already in use
	// today first, e.g. to judge whether a smaller alternative has room -
	// a plain Repeater (not the virtualized picker ListView below, whose
	// off-screen delegates aren't guaranteed to exist) so the currently
	// selected volume's info is always available for the header summary.
	property var volumeInfoById: ({})

	function recomputeVolumeInfo() {
		let result = {}
		for (let i = 0; i < volumeInfoRepeater.count; ++i) {
			const row = volumeInfoRepeater.itemAt(i)
			if (row && row.volumeId) {
				result[row.volumeId] = {
					"name": row.volumeNickname || row.volumeLabel,
					"used": row.used,
					"capacity": row.capacity,
				}
			}
		}
		root.volumeInfoById = result
	}

	readonly property var currentVolumeInfo: root.volumeInfoById[root.currentVolumeId]

	function currentUsageSummaryText() {
		if (!root.currentVolumeId) {
			//% "Not currently using any managed storage"
			return qsTrId("pagesettingscontainerstorage_no_current_volume")
		}
		if (root.currentVolumeId === "/data") {
			//% "Internal storage"
			const name = qsTrId("pagesettingscontainers_container_storage_internal")
			//% "Currently using %1: %2 used / %3 free"
			return qsTrId("pagesettingscontainerstorage_current_usage")
					.arg(name).arg(Containers.formatBytes(usedBytes.value)).arg(Containers.formatBytes(localDataFreeBytes.value))
		}
		const info = root.currentVolumeInfo
		if (!info) {
			return ""
		}
		const name = info.name || qsTrId("pagesettingscontainerstorage_unnamed_volume")
		const free = Math.max(0, info.capacity - info.used)
		//% "Currently using %1: %2 used / %3 free"
		return qsTrId("pagesettingscontainerstorage_current_usage")
				.arg(name).arg(Containers.formatBytes(info.used)).arg(Containers.formatBytes(free))
	}

	Repeater {
		id: volumeInfoRepeater
		model: VeQItemChildModel {
			model: volumes
			childId: "Id"
		}
		delegate: Item {
			id: volumeInfoRow
			readonly property string prefix: model.item.itemParent().uid
			readonly property string volumeId: model.item.value || ""
			readonly property string volumeLabel: volumeLabelItem.value || ""
			readonly property string volumeNickname: volumeNicknameItem.value || ""
			readonly property real used: volumeUsedItem.value || 0
			readonly property real capacity: volumeCapacityItem.value || 0

			onVolumeIdChanged: root.recomputeVolumeInfo()
			onUsedChanged: root.recomputeVolumeInfo()
			onCapacityChanged: root.recomputeVolumeInfo()
			Component.onCompleted: root.recomputeVolumeInfo()

			VeQuickItem { id: volumeLabelItem; uid: volumeInfoRow.prefix + "/Label" }
			VeQuickItem { id: volumeNicknameItem; uid: volumeInfoRow.prefix + "/Nickname" }
			VeQuickItem { id: volumeUsedItem; uid: volumeInfoRow.prefix + "/Used" }
			VeQuickItem { id: volumeCapacityItem; uid: volumeInfoRow.prefix + "/Capacity" }
		}
		onCountChanged: root.recomputeVolumeInfo()
	}

	Repeater {
		id: allocationRepeater
		model: VeQItemChildModel {
			model: allocations
			childId: "VolumeId"
		}
		delegate: Item {
			id: allocationRow
			readonly property string prefix: model.item.itemParent().uid
			readonly property string volumeId: model.item.value || ""
			readonly property string consumer: consumerItem.value || ""
			readonly property bool ready: stateItem.value === VenusOS.Storage_Allocation_Ready

			onVolumeIdChanged: root.recomputeUsedByConsumers()
			onConsumerChanged: root.recomputeUsedByConsumers()
			onReadyChanged: root.recomputeUsedByConsumers()
			Component.onCompleted: root.recomputeUsedByConsumers()

			VeQuickItem { id: consumerItem; uid: allocationRow.prefix + "/Consumer" }
			VeQuickItem { id: stateItem; uid: allocationRow.prefix + "/State" }
		}
		onCountChanged: root.recomputeUsedByConsumers()
	}

	GradientListView {
		id: listView

		header: SettingsColumn {
			width: parent.width

			SettingsListHeader {
				//% "Current storage"
				text: qsTrId("pagesettingscontainerstorage_current_storage_header")
			}

			ListText {
				text: root.currentUsageSummaryText()
			}

			// "/data" (allocation.py's LOCAL_DATA_VOLUME_ID) never appears in
			// the /Volumes tree the virtualized list below is built from -
			// same reasoning as PageSettingsLoggerStorage.qml's own
			// hardcoded "System (/data)" row, just with the containers
			// service's own sentinel ("/data" here, "" there).
			ListRadioButton {
				//% "Internal storage"
				text: qsTrId("pagesettingscontainers_container_storage_internal")
				//% "%1 used / %2 free"
				secondaryText: qsTrId("pagesettingscontainerstorage_usage")
						.arg(Containers.formatBytes(usedBytes.value))
						.arg(Containers.formatBytes(localDataFreeBytes.value))
				checked: root.currentVolumeId === "/data"
				writeAccessLevel: VenusOS.User_AccessType_User
				onClicked: {
					if (checked) {
						Global.pageManager.popPage(root)
						return
					}
					root.proceedWithVolumeSelection("/data")
				}
			}

			PrimaryListLabel {
				horizontalAlignment: Text.AlignHCenter
				preferredVisible: listView.count === 0
				//% "No eligible storage volumes found"
				text: qsTrId("pagesettingscontainerstorage_no_volumes")
			}

			SettingsListHeader {
				//% "Found storage"
				text: qsTrId("pagesettingscontainerstorage_found_volumes_header")
				// SettingsListHeader's preferredVisible only mimics ListItem's
				// eponymous property for a VisibleItemModel-driven list to read -
				// it does nothing on its own for a header sitting directly in a
				// plain SettingsColumn/Column, unlike PrimaryListLabel just above
				// (which does bind its own visible/height). A real visible:
				// binding is required here to actually hide it - Column skips
				// invisible children when laying out siblings, same effect.
				visible: root.foundVolumeIds.length > 0
			}

			Repeater {
				model: root.foundVolumeIds

				delegate: ListButton {
					required property string modelData

					text: modelData
					//% "Dismiss"
					secondaryText: qsTrId("pagesettingscontainerstorage_found_volumes_dismiss")
					//% "Used by this device before - select it below to use it again"
					caption: qsTrId("pagesettingscontainerstorage_found_volumes_caption")
					writeAccessLevel: VenusOS.User_AccessType_User
					onClicked: dismissFoundVolumeAction.setValue(modelData)
				}
			}

			SettingsListHeader {
				//% "Orphaned storage"
				text: qsTrId("pagesettingscontainerstorage_orphaned_header")
				// See "Found storage" header above - preferredVisible alone
				// does not hide this outside a VisibleItemModel-driven list.
				visible: root.orphanedVolumeIds.length > 0
			}

			Repeater {
				model: root.orphanedVolumeIds

				delegate: ListButton {
					required property string modelData

					text: modelData
					//% "Purge"
					secondaryText: qsTrId("pagesettingscontainerstorage_orphan_purge")
					//% "Left behind by an earlier storage change - not used by any container"
					caption: qsTrId("pagesettingscontainerstorage_orphan_caption")
					writeAccessLevel: VenusOS.User_AccessType_Installer
					onClicked: {
						root.pendingSelectVolumeId = modelData
						Global.dialogLayer.open(purgeOrphanDialogComponent)
					}
				}
			}
		}

		model: VeQItemSortTableModel {
			model: VeQItemChildModel {
				model: volumes
				childId: "Id"
			}
			dynamicSortFilter: true
			filterFlags: VeQItemSortTableModel.FilterInvalid
		}

		delegate: ListRadioButton {
			id: volumeDelegate

			readonly property string volumeUid: model.item.itemParent().uid
			readonly property string volumeId: model.item.value || ""
			// Storage Manager itself is filesystem-agnostic; container
			// storage is ext4-only for the MVP (dbus-containers' own
			// allocation.py rejects anything else before ever requesting
			// an allocation) - keep this list in sync with that one.
			readonly property bool supportedFilesystem: filesystem.value === "ext4"
			readonly property string usageText: {
				// Free here is Capacity - Used, not the real Free leaf
				// (which excludes the filesystem's root-only block
				// margin) - keeps this consistent with the general
				// Storage pages for the same volume.
				//% "%1 used / %2 free"
				return qsTrId("pagesettingscontainerstorage_usage")
						.arg(Containers.formatBytes(used.value))
						.arg(Containers.formatBytes(Math.max(0, capacity.value - used.value)))
			}

			preferredVisible: lifecycle.value === VenusOS.Storage_Lifecycle_AdoptedPersistent
						   && (state.value === VenusOS.Storage_VolumeState_Available
							   || state.value === VenusOS.Storage_VolumeState_Active)
						   && supportedFilesystem
			//% "Unnamed volume"
			text: nickname.value || label.value || qsTrId("pagesettingscontainerstorage_unnamed_volume")
			caption: root.usedByText(volumeId)
			secondaryText: {
				if (root.pendingScanVolumeId === volumeId) {
					//% "Checking…"
					return qsTrId("pagesettingscontainerstorage_checking")
				}
				if (root.requestedVolumeId === volumeId) {
					if (root.migrationInProgress) {
						return root.migrationProgressText()
					}
					//% "Selecting…"
					return qsTrId("pagesettingscontainerstorage_selecting")
				}
				return usageText
			}

			checked: volumeId === root.currentVolumeId
			writeAccessLevel: VenusOS.User_AccessType_User
			onClicked: {
				if (checked) {
					Global.pageManager.popPage(root)
					return
				}
				// Scan first - Part B's "this volume already has containers"
				// choice. proceedWithVolumeSelection (below) runs the existing
				// migrate/select decision either way, once the scan result (or
				// the found-containers dialog it may open) is resolved.
				root.pendingSelectVolumeId = volumeId
				root.pendingScanVolumeId = volumeId
				scanVolumeAction.setValue(volumeId)
			}

			VeQuickItem { id: label; uid: volumeDelegate.volumeUid + "/Label" }
			VeQuickItem { id: nickname; uid: volumeDelegate.volumeUid + "/Nickname" }
			VeQuickItem { id: filesystem; uid: volumeDelegate.volumeUid + "/Filesystem" }
			VeQuickItem { id: capacity; uid: volumeDelegate.volumeUid + "/Capacity" }
			VeQuickItem { id: used; uid: volumeDelegate.volumeUid + "/Used" }
			VeQuickItem { id: lifecycle; uid: volumeDelegate.volumeUid + "/Lifecycle" }
			VeQuickItem { id: state; uid: volumeDelegate.volumeUid + "/State" }
		}
	}

	Component {
		id: foundContainersDialogComponent

		ModalDialog {
			id: foundContainersDialog

			//% "Containers found on this volume"
			title: qsTrId("pagesettingscontainerstorage_found_title")
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_NoOptions
			onRejected: {
				root.pendingProceedAfterClose = true
			}

			contentItem: ColumnLayout {
				implicitWidth: Theme.geometry_modalDialog_width
				spacing: Theme.geometry_modalDialog_content_spacing

				Label {
					//% "This volume already has container data on it, not currently known on this device:"
					text: qsTrId("pagesettingscontainerstorage_found_body")
					wrapMode: Text.Wrap
					Layout.fillWidth: true
					Layout.margins: Theme.geometry_modalDialog_content_spacing
				}

				Repeater {
					model: root.foundContainers
					delegate: Label {
						required property var modelData
						text: "• " + modelData.name
						wrapMode: Text.Wrap
						Layout.fillWidth: true
						Layout.leftMargin: Theme.geometry_modalDialog_content_spacing
						Layout.rightMargin: Theme.geometry_modalDialog_content_spacing
					}
				}

				Label {
					//% "Import them onto the current volume, or skip and continue with this storage change."
					text: qsTrId("pagesettingscontainerstorage_found_choice_body")
					wrapMode: Text.Wrap
					Layout.fillWidth: true
					Layout.margins: Theme.geometry_modalDialog_content_spacing
				}
			}

			footer: FocusScope {
				implicitHeight: Theme.geometry_modalDialog_footer_height
				focus: true
				Keys.onEscapePressed: foundContainersDialog.reject()
				Keys.enabled: Global.keyNavigationEnabled

				SeparatorBar {
					anchors { left: parent.left; right: parent.right; top: parent.top }
				}

				RowLayout {
					anchors { fill: parent; topMargin: 1 }
					spacing: 0

					Button {
						//% "Skip"
						text: qsTrId("pagesettingscontainerstorage_found_skip")
						flat: true
						Layout.fillWidth: true
						Layout.fillHeight: true
						onClicked: foundContainersDialog.reject()
					}
					Button {
						//% "Import"
						text: qsTrId("pagesettingscontainerstorage_found_import")
						flat: true
						Layout.fillWidth: true
						Layout.fillHeight: true
						onClicked: {
							root.startFoundContainersImport()
							foundContainersDialog.accept()
						}
					}
				}
			}
		}
	}

	Component {
		id: confirmMigrateDialogComponent

		ModalWarningDialog {
			//% "Change storage volume?"
			title: qsTrId("pagesettingscontainerstorage_change_title")
			//% "Containers will be stopped, their data moved to the new volume, then restarted."
			description: qsTrId("pagesettingscontainerstorage_change_migrate_explanation")
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
			onAccepted: {
				root.pendingConfirmMigrateAfterClose = true
			}
		}
	}

	Component {
		id: confirmMigrateFinalDialogComponent

		ModalWarningDialog {
			//% "This may take a while"
			title: qsTrId("pagesettingscontainerstorage_change_final_title")
			//% "Containers will be unavailable until the move finishes. Continue?"
			description: qsTrId("pagesettingscontainerstorage_change_final_body")
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
			onAccepted: {
				const volumeId = root.pendingSelectVolumeId
				root.requestedVolumeId = volumeId
				root.migrateRequested = true
				migrateAction.setValue(volumeId)
			}
		}
	}

	Component {
		id: insufficientSpaceDialogComponent

		ModalDialog {
			id: insufficientSpaceDialog

			//% "Not enough space"
			title: qsTrId("pagesettingscontainerstorage_insufficient_space_title")
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_NoOptions

			contentItem: ColumnLayout {
				implicitWidth: Theme.geometry_modalDialog_width
				spacing: Theme.geometry_modalDialog_content_spacing

				Label {
					//% "The new volume does not have enough free space for the current container data. Choose what to do with the current volume's data."
					text: qsTrId("pagesettingscontainerstorage_insufficient_space_body")
					wrapMode: Text.Wrap
					Layout.fillWidth: true
					Layout.margins: Theme.geometry_modalDialog_content_spacing
				}
			}

			footer: FocusScope {
				implicitHeight: Theme.geometry_modalDialog_footer_height
				focus: true
				Keys.onEscapePressed: insufficientSpaceDialog.reject()
				Keys.enabled: Global.keyNavigationEnabled

				SeparatorBar {
					anchors { left: parent.left; right: parent.right; top: parent.top }
				}

				RowLayout {
					anchors { fill: parent; topMargin: 1 }
					spacing: 0

					Button {
						text: CommonWords.cancel
						flat: true
						Layout.fillWidth: true
						Layout.fillHeight: true
						onClicked: insufficientSpaceDialog.reject()
					}
					Button {
						//% "Keep old"
						text: qsTrId("pagesettingscontainerstorage_insufficient_space_keep")
						flat: true
						Layout.fillWidth: true
						Layout.fillHeight: true
						onClicked: {
							root.pendingResetChoice = "keep"
							root.pendingConfirmResetAfterClose = true
							insufficientSpaceDialog.accept()
						}
					}
					Button {
						//% "Delete old"
						text: qsTrId("pagesettingscontainerstorage_insufficient_space_delete")
						color: Theme.color_red
						flat: true
						Layout.fillWidth: true
						Layout.fillHeight: true
						onClicked: {
							root.pendingResetChoice = "delete"
							root.pendingConfirmResetAfterClose = true
							insufficientSpaceDialog.accept()
						}
					}
				}
			}
		}
	}

	Component {
		id: confirmResetDialogComponent

		ModalDialog {
			id: confirmResetDialog

			//% "Are you sure?"
			title: qsTrId("pagesettingscontainerstorage_reset_confirm_title")
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_NoOptions
			onAccepted: {
				const newVolumeId = root.pendingSelectVolumeId
				if (root.pendingResetChoice === "delete") {
					root.pendingPurgeVolumeId = root.currentVolumeId
				}
				root.requestedVolumeId = newVolumeId
				selectAction.setValue(newVolumeId)
			}

			contentItem: ColumnLayout {
				implicitWidth: Theme.geometry_modalDialog_width
				spacing: Theme.geometry_modalDialog_content_spacing

				Label {
					text: root.pendingResetChoice === "delete"
							//% "The current volume's container data will be permanently deleted. This cannot be undone."
							? qsTrId("pagesettingscontainerstorage_reset_confirm_delete_body")
							//% "The new volume will be used with no containers on it. The current volume's data is left as-is, unused."
							: qsTrId("pagesettingscontainerstorage_reset_confirm_keep_body")
					wrapMode: Text.Wrap
					Layout.fillWidth: true
					Layout.margins: Theme.geometry_modalDialog_content_spacing
				}
			}

			footer: FocusScope {
				implicitHeight: Theme.geometry_modalDialog_footer_height
				focus: true
				Keys.onEscapePressed: confirmResetDialog.reject()
				Keys.enabled: Global.keyNavigationEnabled

				SeparatorBar {
					anchors { left: parent.left; right: parent.right; top: parent.top }
				}

				RowLayout {
					anchors { fill: parent; topMargin: 1 }
					spacing: 0

					Button {
						text: CommonWords.cancel
						flat: true
						Layout.fillWidth: true
						Layout.fillHeight: true
						onClicked: confirmResetDialog.reject()
					}
					Button {
						//% "Continue"
						text: qsTrId("pagesettingscontainerstorage_reset_confirm_button")
						color: root.pendingResetChoice === "delete" ? Theme.color_red : Theme.color_font_primary
						flat: true
						Layout.fillWidth: true
						Layout.fillHeight: true
						onClicked: confirmResetDialog.accept()
					}
				}
			}
		}
	}

	Component {
		id: purgeOrphanDialogComponent

		ModalDialog {
			id: purgeOrphanDialog

			//% "Purge orphaned storage?"
			title: qsTrId("pagesettingscontainerstorage_orphan_purge_confirm_title")
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_NoOptions
			onAccepted: purgeOrphanAction.setValue(root.pendingSelectVolumeId)

			contentItem: Item {
				implicitWidth: Theme.geometry_modalDialog_width
				implicitHeight: purgeLabel.implicitHeight + (2 * Theme.geometry_modalDialog_content_spacing)

				Label {
					id: purgeLabel
					anchors {
						left: parent.left
						right: parent.right
						verticalCenter: parent.verticalCenter
						margins: Theme.geometry_modalDialog_content_spacing
					}
					//% "This permanently removes the container data left on %1."
					text: qsTrId("pagesettingscontainerstorage_orphan_purge_confirm_body").arg(root.pendingSelectVolumeId)
					wrapMode: Text.Wrap
				}
			}

			footer: FocusScope {
				implicitHeight: Theme.geometry_modalDialog_footer_height
				focus: true
				Keys.onEscapePressed: purgeOrphanDialog.reject()
				Keys.enabled: Global.keyNavigationEnabled

				SeparatorBar {
					anchors { left: parent.left; right: parent.right; top: parent.top }
				}

				RowLayout {
					anchors { fill: parent; topMargin: 1 }
					spacing: 0

					Button {
						text: CommonWords.cancel
						flat: true
						Layout.fillWidth: true
						Layout.fillHeight: true
						onClicked: purgeOrphanDialog.reject()
					}
					Button {
						//% "Purge"
						text: qsTrId("pagesettingscontainerstorage_orphan_purge")
						color: Theme.color_red
						flat: true
						Layout.fillWidth: true
						Layout.fillHeight: true
						onClicked: purgeOrphanDialog.accept()
					}
				}
			}
		}
	}
}

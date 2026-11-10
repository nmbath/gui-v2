/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

/*
	A scrolling list with one list item for each row of a model, which fills its parent. For a list
	of items that are declared inside it, use PluginItemListView.

	Set model to a list model, such as a PluginDeviceModel, and delegate to a Plugin* list item,
	for example:

		PluginModelListView {
			model: PluginDeviceModel { serviceTypes: ["tank"] }
			delegate: PluginListText {
				required property string name
				text: name
			}
		}

	header is an optional item above the rows, such as a PluginPrimaryListLabel. It scrolls with
	the rows. Keep it shorter than the list.

	Key navigation moves through the list items, and skips hidden ones. If the list item with key
	focus is hidden, or its row is removed, focus moves to a visible list item.
*/
FocusScope {
	id: root

	// The rows, such as a PluginDeviceModel or a PluginPathModel.
	property var model
	// The list item for each row. It must be a Plugin* list item.
	property Component delegate
	// An item above the rows. Optional.
	property Component header
	readonly property int count: listView.count

	width: parent?.width ?? 0
	height: parent?.height ?? 0
	focus: true

	GradientListView {
		id: listView

		model: root.model
		delegate: root.delegate
		header: root.header

		// The current row changes when the focused row is removed.
		onCurrentItemChanged: Qt.callLater(rowFocus.keepOnVisibleRow)
	}

	Connections {
		target: listView.currentItem
		ignoreUnknownSignals: true

		function onEffectiveVisibleChanged() {
			Qt.callLater(rowFocus.keepOnVisibleRow)
		}
	}

	// Nested, so this is not part of the plugin API. A function on the list would be.
	QtObject {
		id: rowFocus

		// Called later, so that a hidden list item's focusPolicy has been updated. Otherwise the
		// helper still accepts that list item and puts focus back on it.
		function keepOnVisibleRow() {
			if (!Global.keyNavigationEnabled || !listView.activeFocus || listView.headerItem?.activeFocus) {
				return
			}
			// The current row is the one that key navigation focused.
			const row = listView.currentItem
			const rowIsHidden = row?.effectiveVisible === false
			if (row?.activeFocus && !rowIsHidden) {
				return
			}
			// The focused list item is hidden, or its row was removed.
			listView.__keyNavHelper.updateFocusedItem()
			if (rowIsHidden && row.activeFocus) {
				// No other list item can take focus. Qt still delivers keys to a hidden item that
				// has focus.
				row.focus = false
			}
		}
	}
}

/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtTest
import Victron.VenusOS
import Victron.GuiPlugins

TestCase {
	id: root

	name: "PluginModelListViewTest"
	when: windowShown
	// TestCase is invisible, so a child cannot take active focus. The focus tests need that.
	visible: true
	width: 400
	height: 400

	function initTestCase() {
		// Unit tests do not load a mock configuration, so the access level is unset and
		// canAccess() is false, and every list item is hidden.
		MockManager.setValue("mock/com.victronenergy.settings/Settings/System/AccessLevel",
				VenusOS.User_AccessType_Service)
		tryVerify(function() {
			return !!Services.settings
					&& Services.settings.canAccess(VenusOS.User_AccessType_Service)
		}, 20000)
	}

	function init() {
		Global.keyNavigationEnabled = false
	}

	function cleanup() {
		Global.keyNavigationEnabled = false
	}

	Component {
		id: listHostComponent

		Item {
			property alias list: list
			property alias rows: rows

			width: 400
			height: 400

			ListModel {
				id: rows

				ListElement { name: "first"; shown: true }
				ListElement { name: "second"; shown: true }
				ListElement { name: "third"; shown: true }
			}

			PluginModelListView {
				id: list

				model: rows

				header: PluginPrimaryListLabel {
					objectName: "header"
					text: "Header"
				}

				delegate: PluginListText {
					required property string name
					required property bool shown

					objectName: name
					text: name
					preferredVisible: shown
				}
			}
		}
	}

	function childByName(item, objectName) {
		if (!item) {
			return null
		}
		if (item.objectName === objectName) {
			return item
		}
		for (let i = 0; i < item.children.length; ++i) {
			const found = childByName(item.children[i], objectName)
			if (found) {
				return found
			}
		}
		return null
	}

	function createList() {
		const host = createTemporaryObject(listHostComponent, root)
		verify(host)
		tryVerify(function() {
			return !!childByName(host, "first") && !!childByName(host, "third")
		})
		return host
	}

	// Focus the first row. The list helper focuses the first list item that accepts key navigation.
	function focusFirstRow(host) {
		const first = childByName(host, "first")
		first.forceActiveFocus()
		tryCompare(first, "activeFocus", true)
	}

	function test_rowsAreListItemsBelowTheHeader() {
		const host = createList()
		compare(host.list.count, 3)
		const header = childByName(host, "header")
		const first = childByName(host, "first")
		const second = childByName(host, "second")
		verify(header)
		verify(header.visible)
		verify(header.height > 0)
		verify(header.y + header.height <= first.y)
		verify(first.y + first.height <= second.y)
		// A list item takes the width of the list.
		compare(first.width, host.list.width)
	}

	function test_keyNavigationMovesThroughRows() {
		Global.keyNavigationEnabled = true
		const host = createList()
		focusFirstRow(host)
		keyClick(Qt.Key_Down)
		tryCompare(childByName(host, "second"), "activeFocus", true)
		keyClick(Qt.Key_Down)
		tryCompare(childByName(host, "third"), "activeFocus", true)
		keyClick(Qt.Key_Up)
		tryCompare(childByName(host, "second"), "activeFocus", true)
	}

	function test_keyNavigationSkipsHiddenRows() {
		Global.keyNavigationEnabled = true
		const host = createList()
		host.rows.setProperty(1, "shown", false)
		const second = childByName(host, "second")
		tryCompare(second, "visible", false)
		compare(second.height, 0)
		focusFirstRow(host)
		keyClick(Qt.Key_Down)
		tryCompare(childByName(host, "third"), "activeFocus", true)
	}

	function test_hidingFocusedRowMovesKeyFocus_data() {
		return [
			// No row is before the first one, so focus moves to the next row.
			{ tag: "first row", hide: 0, expect: "second" },
			{ tag: "second row", hide: 1, expect: "first" },
		]
	}

	function test_hidingFocusedRowMovesKeyFocus(data) {
		// Qt still delivers keys to a hidden item that has focus. Focus must move to a visible row.
		Global.keyNavigationEnabled = true
		const host = createList()
		focusFirstRow(host)
		const hidden = childByName(host, host.rows.get(data.hide).name)
		if (data.hide > 0) {
			keyClick(Qt.Key_Down)
			tryCompare(hidden, "activeFocus", true)
		}

		// Hiding the focused row clears TabFocus while it still has focus. Qt warns.
		ignoreWarning(/Cannot set activeFocusOnTab to false once item is the active focus item/)
		host.rows.setProperty(data.hide, "shown", false)
		tryCompare(hidden, "activeFocus", false)
		tryCompare(childByName(host, data.expect), "activeFocus", true)
	}

	function test_hidingOnlyVisibleRowClearsItsFocus() {
		Global.keyNavigationEnabled = true
		const host = createList()
		host.rows.remove(1, 2)
		focusFirstRow(host)
		const first = childByName(host, "first")

		ignoreWarning(/Cannot set activeFocusOnTab to false once item is the active focus item/)
		host.rows.setProperty(0, "shown", false)
		tryCompare(first, "activeFocus", false)
		verify(host.list.activeFocus)
	}

	function test_removingFocusedRowMovesKeyFocus_data() {
		return [
			{ tag: "middle row", remove: 1, expect: "third" },
			// No row is after the last one, so focus moves to the row before it.
			{ tag: "last row", remove: 2, expect: "second" },
			// The list view makes the hidden row current, and focuses it.
			{ tag: "next row is hidden", remove: 1, hide: 2, expect: "first" },
		]
	}

	function test_removingFocusedRowMovesKeyFocus(data) {
		Global.keyNavigationEnabled = true
		const host = createList()
		if (data.hide !== undefined) {
			host.rows.setProperty(data.hide, "shown", false)
		}
		focusFirstRow(host)
		for (let i = 0; i < data.remove; ++i) {
			keyClick(Qt.Key_Down)
		}
		tryCompare(childByName(host, host.rows.get(data.remove).name), "activeFocus", true)

		host.rows.remove(data.remove)
		tryCompare(childByName(host, data.expect), "activeFocus", true)
		compare(host.list.count, 2)
	}
}

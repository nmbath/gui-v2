/*
** Copyright (C) 2022 Victron Energy B.V.
*/

import QtQuick
import QtQuick.Controls.impl as CP
import QtQuick.VirtualKeyboard
import Victron.VenusOS

ListItem {
	id: root

	property alias source: dataPoint.source
	property alias value: dataPoint.value
	readonly property alias dataPoint: dataPoint
	readonly property alias valid: dataPoint.valid
	property alias textField: textField
	property alias secondaryText: textField.text
	property alias placeholderText: textField.placeholderText
	readonly property bool hasActiveFocus: textField.activeFocus

	signal accepted(text: string)
	signal editingFinished()

	function forceActiveFocus() {
		_aboutToFocus()
		textField.forceActiveFocus()
	}

	function _aboutToFocus() {
		// Intercept the event before the VKB opens and scroll the parent flickable to
		// ensure the whole textfield is visible.
		const textFieldVerticalMargin = root.height - textField.height
		const textFieldBottom = root.height - textFieldVerticalMargin/2
		Global.aboutToFocusTextField(textField,
				textFieldBottom,
				root.ListView ? root.ListView.view : null)
	}

	property TextField defaultContent: TextField {
		id: textField

		property string _textWhenFocused
		property bool _accepted

		width: Math.max(
				Theme.geometry.listItem.textField.minimumWidth,
				Math.min(implicitWidth + leftPadding + rightPadding, Theme.geometry.listItem.textField.maximumWidth))
		enabled: root.enabled
		text: dataPoint.valid ? dataPoint.value : ""

		EnterKeyAction.actionId: EnterKeyAction.Done
		onAccepted: {
			_accepted = true
			if (dataPoint.source) {
				dataPoint.setValue(text)
			}
			textField.focus = false
			root.accepted(text)
		}

		onEditingFinished: root.editingFinished()

		onActiveFocusChanged: {
			if (activeFocus) {
				_textWhenFocused = text
				_accepted = false
			} else if (!_accepted && _textWhenFocused !== text) {
				text = _textWhenFocused
				revertedAnimation.to = textField.color
				revertedAnimation.start()
			}
		}

		ColorAnimation on color {
			id: revertedAnimation

			from: Theme.color.orange
			duration: 400
		}

		MouseArea {
			anchors.fill: parent
			onPressed: function(mouse) {
				root._aboutToFocus()
				mouse.accepted = false
			}
		}
	}

	enabled: userHasWriteAccess && (source === "" || dataPoint.valid)
	content.children: [
		defaultContent
	]

	DataPoint {
		id: dataPoint
	}
}
/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

/*
	Summary popup for the status bar's activity indicator
	(StatusBar_Landscape/Portrait's activityButton) - lists whatever
	BackgroundActivity.qml currently reports as in progress. Purely
	informational: tapping a row jumps to that item's own settings page for
	any real control (cancel, retry, ...), rather than duplicating those
	actions here.
*/
ModalDialog {
	id: root

	//% "Background activity"
	title: qsTrId("backgroundactivitydialog_title")
	dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkOnly

	contentItem: ColumnLayout {
		implicitWidth: Theme.geometry_modalDialog_width
		spacing: Theme.geometry_modalDialog_content_spacing

		Repeater {
			model: Global.backgroundActivity?.items ?? []

			delegate: ListButton {
				required property var modelData

				Layout.fillWidth: true
				text: modelData.label
				secondaryText: modelData.detail
				onClicked: {
					modelData.onActivate()
					root.accept()
				}
			}
		}

		Label {
			visible: (Global.backgroundActivity?.items?.length ?? 0) === 0
			//% "Nothing in progress"
			text: qsTrId("backgroundactivitydialog_empty")
			wrapMode: Text.Wrap
			Layout.fillWidth: true
			Layout.margins: Theme.geometry_modalDialog_content_spacing
		}
	}
}

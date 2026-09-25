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
	informational: rows are deliberately not interactive.
*/
ModalDialog {
	id: root
	readonly property real tableMargin: Theme.geometry_modalDialog_content_spacing
	readonly property real tableVerticalPadding: Theme.geometry_modalDialog_content_spacing / 2
	readonly property real columnSpacing: Theme.geometry_modalDialog_content_spacing
	width: Theme.geometry_screen_width - (2 * Theme.geometry_modalDialog_content_spacing)
	// Unlike confirmation dialogs, this table should only be as tall as its contents. The
	// standard modal background has a 368px minimum which otherwise stretches the rows apart.
	height: Math.min(Theme.geometry_screen_height,
			implicitHeaderHeight + topPadding + implicitContentHeight + bottomPadding + implicitFooterHeight)

	function translatedText(id, fallback) {
		const translated = qsTrId(id)
		return translated === id ? qsTr(fallback) : translated
	}

	//% "Background activity"
	title: root.translatedText("backgroundactivitydialog_title", "Background activity")
	dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkOnly

	contentItem: ColumnLayout {
		// This is a three-column status table, so use the available landscape width instead of
		// squeezing it into the standard confirmation-dialog width.
		implicitWidth: Theme.geometry_screen_width - (2 * Theme.geometry_modalDialog_content_spacing)
		spacing: 0

		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: implicitHeight
			Layout.maximumHeight: implicitHeight
			implicitHeight: headerRow.implicitHeight + (2 * root.tableVerticalPadding)
			color: Theme.color_listItem_background

			Row {
				id: headerRow
				anchors.fill: parent
				anchors.leftMargin: root.tableMargin
				anchors.rightMargin: root.tableMargin
				anchors.topMargin: root.tableVerticalPadding
				anchors.bottomMargin: root.tableVerticalPadding
				spacing: root.columnSpacing
				readonly property real availableWidth: width - (2 * spacing)

				Label {
					//% "Service"
					text: root.translatedText("backgroundactivitydialog_service", "Service")
					font.bold: true
					width: headerRow.availableWidth * 0.2
				}
				Label {
					//% "Action"
					text: root.translatedText("backgroundactivitydialog_action", "Action")
					font.bold: true
					width: headerRow.availableWidth * 0.5
				}
				Label {
					//% "Progress"
					text: root.translatedText("backgroundactivitydialog_progress", "Progress")
					font.bold: true
					width: headerRow.availableWidth * 0.3
				}
			}

			SeparatorBar {
				anchors.left: parent.left
				anchors.right: parent.right
				anchors.bottom: parent.bottom
			}
		}

		Repeater {
			id: activityRepeater
			model: Global.backgroundActivity?.items ?? []

			delegate: Item {
				required property int index
				required property var modelData

				Layout.fillWidth: true
				Layout.preferredHeight: implicitHeight
				Layout.maximumHeight: implicitHeight
				implicitHeight: Math.max(rowGrid.implicitHeight + (2 * root.tableVerticalPadding), 40)

				Row {
					id: rowGrid
					anchors.fill: parent
					anchors.leftMargin: root.tableMargin
					anchors.rightMargin: root.tableMargin
					anchors.topMargin: root.tableVerticalPadding
					anchors.bottomMargin: root.tableVerticalPadding
					spacing: root.columnSpacing
					readonly property real availableWidth: width - (2 * spacing)

					Label {
						text: modelData.service
						color: Theme.color_font_secondary
						wrapMode: Text.Wrap
						width: rowGrid.availableWidth * 0.2
					}
					Label {
						text: modelData.action
						color: Theme.color_font_secondary
						wrapMode: Text.Wrap
						width: rowGrid.availableWidth * 0.5
					}
					Label {
						text: modelData.progress
						color: Theme.color_font_secondary
						wrapMode: Text.Wrap
						width: rowGrid.availableWidth * 0.3
					}
				}

				SeparatorBar {
					visible: index < activityRepeater.count - 1
					anchors.left: parent.left
					anchors.right: parent.right
					anchors.bottom: parent.bottom
				}
			}
		}

		Label {
			visible: (Global.backgroundActivity?.items?.length ?? 0) === 0
			//% "Nothing in progress"
			text: root.translatedText("backgroundactivitydialog_empty", "Nothing in progress")
			color: Theme.color_font_secondary
			wrapMode: Text.Wrap
			Layout.fillWidth: true
			Layout.margins: Theme.geometry_modalDialog_content_spacing
		}
	}
}

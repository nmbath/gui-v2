/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.impl as CP
import Victron.VenusOS

Rectangle {
	id: root

	required property string title
	required property var configuration
	property url iconSource
	property bool compact: false
	readonly property string dataSource: configuration.dataSource || ""
	readonly property string unit: configuration.unit || ""
	readonly property bool valueAvailable: PartnerSystemData.metricAvailable(dataSource)
	readonly property real rawValue: PartnerSystemData.metricValue(dataSource)
	readonly property string displayValue: valueAvailable && isFinite(rawValue)
		? (unit === "V" ? Number(rawValue).toFixed(1) : Math.round(rawValue).toString())
		: "--"

	width: compact
		? Theme.geometry_overviewPage_widget_leftWidgetWidth
		: Theme.geometry_overviewPage_widget_centerWidgetWidth
	height: compact
		? Theme.geometry_overviewPage_widget_height_xs
		: Theme.geometry_overviewPage_widget_height_s
	color: Theme.color_card_background
	border.width: Theme.geometry_overviewPage_widget_border_width
	border.color: Theme.color_overviewPage_widget_border
	radius: Theme.geometry_overviewPage_widget_radius

	RowLayout {
		anchors.fill: parent
		anchors.margins: Theme.geometry_overviewPage_widget_content_horizontalMargin
		spacing: Theme.geometry_overviewPage_widget_content_spacing

		CP.ColorImage {
			visible: root.iconSource.toString() !== ""
			source: root.iconSource
			color: Theme.color_font_primary
			Layout.preferredWidth: Theme.geometry_icon_size_medium
			Layout.preferredHeight: Theme.geometry_icon_size_medium
		}

		ColumnLayout {
			spacing: 0
			Layout.fillWidth: true

			Label {
				text: root.title
				color: Theme.color_font_secondary
				font.pixelSize: Theme.font_size_caption
				elide: Text.ElideRight
				Layout.fillWidth: true
			}

			Label {
				text: root.displayValue + (root.unit ? " " + root.unit : "")
				color: Theme.color_font_primary
				font.pixelSize: root.compact ? Theme.font_size_body1 : Theme.font_size_h3
				font.bold: true
				Layout.fillWidth: true
			}
		}
	}
}

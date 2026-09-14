/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

// A restricted, data-driven Overview node supplied by a partner package.  Its
// placement and connectors are owned by the Overview page; partner packages do
// not supply executable QML or arbitrary geometry.
OverviewWidget {
	id: root

	required property var configuration
	property url iconSource
	readonly property string dataSource: configuration?.dataSource || ""
	readonly property string unit: configuration?.unit || ""
	readonly property real flowPower: PartnerSystemData.metricValue(dataSource)
	readonly property bool valueAvailable: PartnerSystemData.metricAvailable(dataSource)
	readonly property string displayValue: valueAvailable && isFinite(flowPower)
		? (unit === "V" ? Number(flowPower).toFixed(1) : Math.round(flowPower).toString())
		: "--"

	type: VenusOS.OverviewWidget_Type_GenericDcSource
	enabled: true

	contentItem: ColumnLayout {
		spacing: Theme.geometry_overviewPage_widget_content_spacing

		WidgetHeader {
			text: root.title
			icon.source: root.iconSource
			Layout.fillWidth: true
		}

		Label {
			text: root.displayValue + (root.unit ? " " + root.unit : "")
			color: Theme.color_font_primary
			font.pixelSize: root.size === VenusOS.OverviewWidget_Size_XS
				? Theme.font_overviewPage_widget_quantityLabel_small
				: Theme.font_overviewPage_widget_quantityLabel_large
			verticalAlignment: Text.AlignVCenter
			Layout.fillWidth: true
			Layout.fillHeight: true
		}
	}
}

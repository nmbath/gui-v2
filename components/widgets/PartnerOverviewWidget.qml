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
	readonly property bool batteryContribution: !!configuration?.batteryRole
	readonly property string batteryServiceUid: batteryContribution
		? PartnerSystemData.batteryServiceUid(dataSource, configuration?.batterySelector) : ""
	readonly property real flowPower: PartnerSystemData.metricValue(dataSource, configuration?.batterySelector)
	readonly property bool valueAvailable: PartnerSystemData.metricAvailable(dataSource, configuration?.batterySelector)
	readonly property string displayValue: valueAvailable && isFinite(flowPower)
		? (unit === "V" ? Number(flowPower).toFixed(1) : Math.round(flowPower).toString())
		: "--"

	type: VenusOS.OverviewWidget_Type_GenericDcSource
	enabled: !batteryContribution || !!batteryServiceUid

	onClicked: {
		if (!batteryContribution || !batteryServiceUid) {
			return
		}
		const serviceType = BackendConnection.serviceTypeFromUid(batteryServiceUid)
		if (serviceType === "vebus") {
			Global.pageManager.pushPage("/pages/vebusdevice/PageVeBus.qml", {
				"bindPrefix": batteryServiceUid,
			})
		} else if (serviceType === "genset") {
			Global.pageManager.pushPage("/pages/settings/devicelist/PageGenset.qml", {
				"bindPrefix": batteryServiceUid,
			})
		} else {
			Global.pageManager.pushPage("/pages/settings/devicelist/battery/PageBattery.qml", {
				"bindPrefix": batteryServiceUid,
			})
		}
	}

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

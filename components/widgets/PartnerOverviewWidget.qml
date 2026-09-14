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
	readonly property bool deviceContribution: !!configuration?.deviceSelector
	readonly property string batteryServiceUid: batteryContribution
		? PartnerSystemData.batteryServiceUid(dataSource, configuration?.batterySelector) : ""
	readonly property string deviceServiceUid: deviceContribution
		? PartnerSystemData.mappedDeviceServiceUid(configuration?.deviceSelector) : ""
	readonly property string mappedServiceUid: batteryContribution ? batteryServiceUid : deviceServiceUid
	readonly property string displayTitle: batteryContribution
		? PartnerSystemData.batteryName(dataSource, configuration?.batterySelector, title)
		: deviceContribution
			? PartnerSystemData.mappedDeviceName(configuration?.deviceSelector, title)
			: title
	readonly property real flowPower: deviceContribution
		? Number(deviceMetric.value)
		: PartnerSystemData.metricValue(dataSource, configuration?.batterySelector)
	readonly property bool valueAvailable: deviceContribution
		? !!deviceServiceUid && deviceMetric.valid && isFinite(flowPower)
		: PartnerSystemData.metricAvailable(dataSource, configuration?.batterySelector)
	readonly property string displayValue: valueAvailable && isFinite(flowPower)
		? (unit === "V" ? Number(flowPower).toFixed(1) : Math.round(flowPower).toString())
		: "--"

	type: VenusOS.OverviewWidget_Type_GenericDcSource
	enabled: (!batteryContribution && !deviceContribution) || !!mappedServiceUid

	VeQuickItem {
		id: deviceMetric
		uid: root.deviceServiceUid && root.configuration?.measurementPath
			? root.deviceServiceUid + root.configuration.measurementPath : ""
	}

	onClicked: {
		if ((!batteryContribution && !deviceContribution) || !mappedServiceUid) {
			return
		}
		const serviceType = BackendConnection.serviceTypeFromUid(mappedServiceUid)
		if (serviceType === "vebus") {
			Global.pageManager.pushPage("/pages/vebusdevice/PageVeBus.qml", {
				"bindPrefix": mappedServiceUid,
			})
		} else if (serviceType === "genset") {
			Global.pageManager.pushPage("/pages/settings/devicelist/PageGenset.qml", {
				"bindPrefix": mappedServiceUid,
			})
		} else if (serviceType === "alternator") {
			Global.pageManager.pushPage("/pages/settings/devicelist/dc-in/PageAlternator.qml", {
				"bindPrefix": mappedServiceUid,
			})
		} else if (serviceType === "solarcharger") {
			Global.pageManager.pushPage("/pages/solar/PageSolarCharger.qml", {
				"bindPrefix": mappedServiceUid,
			})
		} else if (serviceType === "acload" || serviceType === "heatpump") {
			Global.pageManager.pushPage("/pages/settings/devicelist/PageUnsupportedDevice.qml", {
				"title": displayTitle,
				"bindPrefix": mappedServiceUid,
			})
		} else {
			Global.pageManager.pushPage("/pages/settings/devicelist/battery/PageBattery.qml", {
				"bindPrefix": mappedServiceUid,
			})
		}
	}

	contentItem: ColumnLayout {
		spacing: Theme.geometry_overviewPage_widget_content_spacing

		WidgetHeader {
			text: root.displayTitle
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

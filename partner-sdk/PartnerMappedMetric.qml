/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

// Resolves one compiler-approved page data binding. The partner supplies a
// logical binding, never a raw D-Bus path.
Item {
	id: root

	required property var data
	required property var binding
	property string fallbackName: ""

	readonly property string dataSource: binding?.dataSource || ""
	readonly property string unit: binding?.unit || ""
	readonly property bool demoBinding: data.demoMode && typeof binding?.demoValue === "number"
	readonly property bool deviceBinding: !!binding?.deviceSelector
	readonly property string deviceServiceUid: deviceBinding
			? data.mappedDeviceServiceUid(binding.deviceSelector) : ""
	readonly property bool available: demoBinding || (deviceBinding
			? !!deviceServiceUid && deviceMetric.valid && isFinite(value)
			: data.metricAvailable(dataSource, binding?.batterySelector))
	readonly property real value: demoBinding
			? Number(binding.demoValue) : deviceBinding
			? Number(deviceMetric.value)
			: data.metricValue(dataSource, binding?.batterySelector)
	readonly property string displayName: demoBinding && binding?.demoName
			? binding.demoName : binding?.batterySelector
			? data.batteryName(dataSource, binding.batterySelector, fallbackName)
			: deviceBinding
				? data.mappedDeviceName(binding.deviceSelector, fallbackName)
				: fallbackName

	visible: false
	width: 0
	height: 0

	VeQuickItem {
		id: deviceMetric
		uid: root.deviceServiceUid && root.binding?.measurementPath
				? root.deviceServiceUid + root.binding.measurementPath : ""
	}
}

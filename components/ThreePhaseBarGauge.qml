/*
** Copyright (C) 2024 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

Flow {
	id: root

	property int valueType: VenusOS.Gauges_ValueType_NeutralPercentage
	property alias phaseModel: phaseRepeater.model
	property string phaseModelProperty
	property real minimumValue
	property real maximumValue
	property bool inputMode
	property bool animationEnabled

	width: phaseRepeater.count > 1
		   ? Theme.geometry_overviewPage_widget_sideGauge_small_width
		   : Theme.geometry_overviewPage_widget_sideGauge_large_width
	height: parent ? parent.height : 0
	spacing: Theme.geometry_three_phase_gauge_spacing

	Repeater {
		id: phaseRepeater

		delegate: BarGauge {
			readonly property bool feedingToGrid: root.inputMode
					&& (model.power || 0) < 0
					&& Global.systemSettings.essFeedbackToGridEnabled()

			width: parent.width
			height: (root.height - (root.spacing * (phaseRepeater.count - 1))) / phaseRepeater.count
			radius: width / 2
			foregroundColor: feedingToGrid ? Theme.color_green : Theme.statusColorValue(valueStatus)
			backgroundColor: feedingToGrid ? Theme.color_darkGreen : Theme.statusColorValue(valueStatus, true)
			value: valueRange.valueAsRatio
			animationEnabled: root.animationEnabled

			ValueRange {
				id: valueRange
				value: model[root.phaseModelProperty]
				minimumValue: root.minimumValue
				maximumValue: root.maximumValue
			}
		}
	}
}

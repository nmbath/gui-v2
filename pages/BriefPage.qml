/*
** Copyright (C) 2021 Victron Energy B.V.
*/

import QtQuick
import QtQuick.Controls as C
import Victron.Velib
import Victron.VenusOS
import "../data"

Page {
	id: root

	// Temporary code?
	property bool solarYieldPresent: true
	property bool generatorPresent: true
	property bool loadPresent: true

	property var leftGaugeTypes: []
	property var rightGaugeTypes: []

	function populateSideGauges() {
		// Determine which side gauges are to be displayed
		let leftTypes = []
		let rightTypes = []
		if (solarYieldPresent) {
			leftTypes.push('solar')
		}
		if (generatorPresent) {
			(solarYieldPresent ? rightTypes : leftTypes).push('generator')
		}
		if (loadPresent) {
			rightTypes.push('load')
		}

		leftGaugeTypes = leftTypes
		rightGaugeTypes = rightTypes
	}

	CircularMultiGauge {
		id: gauge

		height: parent.height
		width: height
		x: sidePanel.x/2 - width/2

		model: gaugeData.model
	}

	property real sideOpacity: 1

	Loader {
		id: leftEdge
		anchors {
			top: parent.top
			left: parent.left
			leftMargin: 40 // TODO: 56 for 7inch
			right: gauge.left
		}
		height: parent.height
		opacity: root.sideOpacity
		active: leftGaugeTypes.length === 1
		source: {
			switch (leftGaugeTypes[0]) {
			case 'solar': return 'SolarYieldGauge.qml'
			case 'generator': return 'GeneratorLeftGauge.qml'
			}
			return ''
		}
	}
	Loader {
		id: rightEdge
		anchors {
			top: parent.top
			right: parent.right
			rightMargin: 40 // TODO: 56 for 7inch
			left: gauge.right
		}
		height: parent.height
		opacity: root.sideOpacity
		active: rightGaugeTypes.length === 1
		source: {
			switch (rightGaugeTypes[0]) {
			case 'generator': return 'GeneratorRightGauge.qml'
			case 'load': return 'LoadGauge.qml'
			}
			return ''
		}
	}

	/*	Example of how to use 'ValueDisplay'
	Column {
		spacing: 20
		anchors {
			top: parent.top
			topMargin: 164
			right: parent.right
			rightMargin: 68
		}
		ValueDisplay {
			title.text: "Generator"
			physicalQuantity: Units.Power
			value: 874
			icon.source: "qrc:/images/generator.svg"
		}
		ValueDisplay {
			title.text: "Loads"
			physicalQuantity: Units.Power
			value: 6251.1234
			icon.source: "qrc:/images/consumption.svg"
		}
	}
	ValueDisplay {
		anchors {
			top: parent.top
			topMargin: 208
			left: parent.left
			leftMargin: 88
		}
		rightAligned: false
		title.text: "Solar yield"
		physicalQuantity: Units.Power
		value: 428
		precision: 2
		icon.source: "qrc:/images/solaryield.svg"
	}
	*/
	Loader {
		id: rightUpper
		anchors {
			top: parent.top
			right: parent.right
			rightMargin: 40
			left: gauge.right
		}
		height: parent.height/2
		opacity: root.sideOpacity
		active: rightGaugeTypes.length === 2
		source: {
			switch (rightGaugeTypes[0]) {
			case 'generator': return 'GeneratorMiniGauge.qml'
			}
			return ''
		}
	}
	Loader {
		id: rightLower
		anchors {
			top: rightUpper.bottom
			right: parent.right
			rightMargin: 40
			left: gauge.right
		}
		height: parent.height/2
		opacity: root.sideOpacity
		active: rightGaugeTypes.length === 2
		source: {
			switch (rightGaugeTypes[1]) {
			case 'load': return 'LoadMiniGauge.qml'
			}
			return ''
		}
	}

	BriefMonitorPanel {
		id: sidePanel

		width: 240
		height: 367

		// hidden by default.
		x: root.width
		opacity: 0.0
	}

	property var gaugeConfig: [
		'fuel',
		'battery',
		'freshwater',
		'blackwater'
	]

	onGaugeConfigChanged: gaugeData.populateModel()

	Component.onCompleted: {
		root.populateSideGauges()
		gaugeData.populateModel()
	}

	Item {
		id: gaugeData

		property ListModel model: ListModel {}

		function populateModel() {
			_populated = false

			model.clear()
			for (let i = 0; i < gaugeConfig.length; ++i) {
				const type = gaugeConfig[i]
				if (type in _gaugeTypeProperties) {
					const props = _gaugeTypeProperties[type]
					model.append(Object.assign({}, props, { value: Math.floor(Math.random() * 100) * 1.0 }))
				}
			}

			_populated = true
		}

		property bool _populated: false

		property var _gaugeTypeProperties: ({
			'battery': {
				textId: 'gaugeBatteryText',
				icon: '/images/battery.svg',
				valueType: Gauges.FallingPercentage
			},
			'fuel': {
				textId: 'gaugeFuelText',
				icon: '/images/tank.svg',
				valueType: Gauges.FallingPercentage
			},
			'freshwater': {
				textId: 'gaugeFreshWaterText',
				icon: '/images/freshWater.svg',
				valueType: Gauges.FallingPercentage
			},
			'blackwater': {
				textId: 'gaugeBlackWaterText',
				icon: '/images/blackWater.svg',
				valueType: Gauges.RisingPercentage
			}
		})

		property int _batteryIndex: _gaugeIndex("battery")

		function _gaugeIndex(type) {
			return _populated ? gaugeConfig.indexOf(type) : -1
		}

		function _gaugeData(index) {
			return index >= 0 && index < model.count ? model.get(index) : null
		}

		Binding {
			target: battery ? gaugeData._gaugeData(gaugeData._batteryIndex) : null
			property: 'value'
			value: battery.stateOfCharge
		}

		Instantiator {
			model: tanks ? tanks.model : null
			delegate: QtObject {
				property string gaugeType: {
					switch (tank.type) {
					case Tanks.Fuel: return 'fuel'
					case Tanks.FreshWater: return 'freshwater'
					case Tanks.BlackWater: return 'blackwater'
					}
					return ''
				}

				property int modelIndex: gaugeData._gaugeIndex(gaugeType)

				property var updater: Binding {
					target: gaugeData._gaugeData(modelIndex)
					property: 'value'
					value: tank.level
				}
			}
		}
	}

	property var _gaugeStrings: [
		//% "Fuel"
		QT_TRID_NOOP('gaugeFuelText'),
		//% "Battery"
		QT_TRID_NOOP('gaugeBatteryText'),
		//% "Fresh water"
		QT_TRID_NOOP('gaugeFreshWaterText'),
		//% "Black water"
		QT_TRID_NOOP('gaugeBlackWaterText')
	]

	state: PageManager.sidePanelActive ? 'panelOpen' : ''
	states: State {
		name: 'panelOpen'
		PropertyChanges {
			target: sidePanel
			x: root.width - sidePanel.width - Theme.horizontalPageMargin
			opacity: 1
		}
		PropertyChanges {
			target: root
			sideOpacity: 0
		}
	}

	transitions: [
		Transition {
			to: "panelOpen"
			from: ""
			ParallelAnimation {
				NumberAnimation {
					target: root
					property: 'sideOpacity'
					duration: 200
				}
				NumberAnimation {
					target: sidePanel
					properties: 'x,opacity'
					duration: 400
					easing.type: Easing.InQuad
				}
			}
		},
		Transition {
			to: ""
			from: "panelOpen"
			ParallelAnimation {
				SequentialAnimation {
					PauseAnimation {
						duration: 200
					}
					NumberAnimation {
						target: root
						property: 'sideOpacity'
						duration: 200
					}
				}
				NumberAnimation {
					target: sidePanel
					properties: 'x,opacity'
					duration: 400
					easing.type: Easing.InQuad
				}
			}
		}
	]
}

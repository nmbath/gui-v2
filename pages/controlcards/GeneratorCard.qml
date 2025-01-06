/*
** Copyright (C) 2023 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Controls.impl as CP
import Victron.VenusOS

ControlCard {
	id: root

	property Generator generator

	icon.source: "qrc:/images/generator.svg"
	title.text: CommonWords.generator
	status.text: root.generator.stateText
	status.rightPadding: timerDisplay.width + Theme.geometry_controlCard_contentMargins

	GeneratorIconLabel {
		id: timerDisplay
		anchors {
			right: parent.right
			rightMargin: Theme.geometry_controlCard_contentMargins
			top: parent.status.top
			topMargin: parent.status.font.pixelSize - fontSize
		}
		generator: root.generator
	}

	Label {
		id: runningBy

		anchors {
			top: root.status.bottom
			topMargin: Theme.geometry_controlCard_status_topMargin
			left: parent.left
			leftMargin: Theme.geometry_controlCard_contentMargins
			right: parent.right
			rightMargin: Theme.geometry_controlCard_contentMargins
		}
		text: root.generator.isAutoStarted
			  ? CommonWords.autostarted_dot_running_by.arg(root.generator.runningByText)
			  : root.generator.runningByText
		color: Theme.color_font_secondary
		font.pixelSize: Theme.font_size_caption
		wrapMode: Text.WordWrap
		visible: root.generator.isRunning
	}

	ListSwitch {
		id: autostartSwitch

		anchors {
			top: runningBy.visible ? runningBy.bottom : root.status.bottom
			topMargin: Theme.geometry_controlCard_status_bottomMargin
		}

		//% "Autostart"
		text: qsTrId("controlcard_generator_label_autostart")
		checked: root.generator.autoStart
		flat: true
		bottomContent.children: [
			PrimaryListLabel {
				//% "Start and stop the generator based on the configured autostart conditions."
				text: qsTrId("controlcard_generator_autostart_conditions")
				color: Theme.color_font_secondary
				font.pixelSize: Theme.font_size_caption
				topPadding: 0
				leftPadding: autostartSwitch.leftPadding
				rightPadding: autostartSwitch.rightPadding
			}
		]

		onClicked: {
			if (!checked) {
				root.generator.setAutoStart(true)
			} else {
				// check if they really want to disable
				Global.dialogLayer.open(confirmationDialogComponent)
			}
		}

		Component {
			id: confirmationDialogComponent

			ModalWarningDialog {
				dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel

				//% "Disable autostart?"
				title: qsTrId("controlcard_generator_disableautostartdialog_title")

				//% "Autostart will be disabled and the generator won't automatically start based on the configured conditions.\nIf the generator is currently running due to a autostart condition, disabling autostart will also stop it immediately."
				description: qsTrId("controlcard_generator_disableautostartdialog_description")

				onAccepted: {
					root.generator.setAutoStart(false)
				}
			}
		}
	}

	GeneratorManualControlButton {
		anchors {
			margins: Theme.geometry_controlCard_button_margins
			bottom: parent.bottom
			left: parent.left
			right: parent.right
		}
		height: Theme.geometry_generatorCard_startButton_height
		radius: Theme.geometry_button_radius
		font.pixelSize: Theme.font_size_body1
		generatorUid: root.generator.serviceUid
	}
}

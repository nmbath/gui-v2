/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

Item {
	id: root

	required property int integrationType
	property bool compact: false
	readonly property int maximumVisibleContributions: 3

	implicitWidth: row.implicitWidth
	implicitHeight: row.implicitHeight
	visible: contributionModel.count > 0

	GuiPluginIntegrationModel {
		id: contributionModel
		type: root.integrationType

		onCountChanged: console.info("Partner contribution model updated:",
				root.integrationType, "count:", count)
	}

	Row {
		id: row
		spacing: Theme.geometry_overviewPage_widget_spacing

		Repeater {
			model: contributionModel

			delegate: Item {
				id: contributionDelegate

				required property int index
				required property string title
				required property var configuration
				required property url icon

				visible: index < root.maximumVisibleContributions
				width: card.width
				height: card.height

				PartnerContributionCard {
					id: card

					title: contributionDelegate.title
					configuration: contributionDelegate.configuration
					iconSource: contributionDelegate.icon
					compact: root.compact
				}
			}
		}
	}
}

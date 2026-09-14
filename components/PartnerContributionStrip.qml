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
	}

	Row {
		id: row
		spacing: Theme.geometry_overviewPage_widget_spacing

		Repeater {
			model: contributionModel

			delegate: PartnerContributionCard {
				required property int index
				required property url icon

				visible: index < root.maximumVisibleContributions
				iconSource: icon
				compact: root.compact
			}
		}
	}
}

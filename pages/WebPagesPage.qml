/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

// The top-left status bar web-pages icon's target: a flat list of every
// available web page, where tapping one opens it directly (WebContentPage.qml)
// rather than going via any settings/detail screen - per the explicit
// specification for this feature (see venus-private#707 and
// VenusOS_GUIv2_Web_Content_and_Container_Proxy_Design). This is distinct
// from pages/settings/PageSettingsWebPages.qml, which is the Add/manage
// screen for manually-added pages only; this page is a browse-and-open list
// and carries no Add/Remove UI of its own.

import QtQuick
import Victron.VenusOS

Page {
	id: root

	readonly property alias flickableView: cardsView
	implicitHeight: Theme.geometry_controlCard_height

	// Not qsTrId - see PageSettingsIntegrations.qml's "Web pages" entry for why.
	title: "Web pages"

	readonly property string webPagesServiceUid: BackendConnection.serviceUidForType("webpages")

	VeQItemSortTableModel {
		id: pages

		model: VeQItemTableModel {
			uids: [ root.webPagesServiceUid + "/WebPages" ]
			flags: VeQItemTableModel.AddChildren | VeQItemTableModel.AddNonLeaves | VeQItemTableModel.DontAddItem
		}
		dynamicSortFilter: true
		filterFlags: VeQItemSortTableModel.FilterOffline
	}

	VeQItemSortTableModel {
		id: pageTitles

		model: VeQItemChildModel {
			model: pages
			childId: "Title"
		}
		dynamicSortFilter: true
		filterFlags: VeQItemSortTableModel.FilterInvalid
	}

	// Use the same card surface and slide-in layout as Controls and Switches.
	// The registered pages are a launcher card, not a full-width settings page.
	BaseListView {
		id: cardsView

		anchors {
			fill: parent
			leftMargin: Theme.geometry_controlCardsPage_horizontalMargin
			rightMargin: Theme.geometry_controlCardsPage_horizontalMargin
			bottomMargin: Theme.geometry_controlCardsPage_bottomMargin
		}
		orientation: Theme.screenSize === Theme.Portrait ? ListView.Vertical : ListView.Horizontal
		model: 1
		delegate: ControlCard {
			id: webPagesCard

			width: Theme.screenSize === Theme.Portrait
					? cardsView.width : Theme.geometry_controlCard_maximumWidth
			height: Theme.screenSize === Theme.Portrait ? implicitHeight : cardsView.height
			icon.source: "qrc:/images/icon_webpages_32.svg"
			title.text: root.title
			status.text: ""

			ListView {
				id: pageList

				anchors {
					top: parent.title.bottom
					topMargin: Theme.geometry_controlCard_status_bottomMargin
					left: parent.left
					right: parent.right
					bottom: parent.bottom
					bottomMargin: Theme.geometry_controlCard_contentMargins
				}
				clip: true
				model: pageTitles
				delegate: WebPageOpenDelegate {}
			}

			Label {
				anchors {
					top: parent.title.bottom
					topMargin: Theme.geometry_controlCard_status_bottomMargin
					left: parent.left
					leftMargin: Theme.geometry_controlCard_contentMargins
					right: parent.right
					rightMargin: Theme.geometry_controlCard_contentMargins
				}
				text: "No web pages are available yet."
				color: Theme.color_font_secondary
				wrapMode: Text.Wrap
				visible: pageList.count === 0
			}
		}
	}
}

/*
** Copyright (C) 2025 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

Loader {
	id: root

	required property PageStack pageStack

	signal controlCardsActivated()
	signal auxCardsActivated()
	// Landscape-only for now - see StatusBar_Portrait.qml, which has no
	// web-pages button yet (the design's target device is landscape).
	signal webPagesActivated()
	signal cardsDeactivated()
	signal sidePanelToggled()

	sourceComponent: Theme.screenSize === Theme.Portrait ? statusBarPortrait : statusBarLandscape

	Component {
		id: statusBarLandscape

		StatusBar_Landscape {
			pageStack: root.pageStack
			focus: true

			onControlCardsActivated: root.controlCardsActivated()
			onAuxCardsActivated: root.auxCardsActivated()
			onWebPagesActivated: root.webPagesActivated()
			onCardsDeactivated: root.cardsDeactivated()
			onSidePanelToggled: root.sidePanelToggled()
		}
	}

	Component {
		id: statusBarPortrait

		StatusBar_Portrait {
			pageStack: root.pageStack
			focus: true

			onControlCardsActivated: root.controlCardsActivated()
			onAuxCardsActivated: root.auxCardsActivated()
			onWebPagesActivated: root.webPagesActivated()
			onCardsDeactivated: root.cardsDeactivated()
			onSidePanelToggled: root.sidePanelToggled()
		}
	}
}

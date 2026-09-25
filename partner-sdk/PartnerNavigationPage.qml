/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

// Stable Model 2 base type. Partner pages receive navigation lifecycle
// properties from SwipeViewPage without depending on its source location.
SwipeViewPage {
	id: root

	// Compiler-approved semantic bindings for this page. Kept optional so
	// existing Model 2 pages remain source-compatible.
	property var configuration: ({})

	// Plug-in pages are created by a Loader before being contributed to the
	// host SwipeView. Give them the same lifecycle geometry as native pages;
	// relying only on SwipeView's attached properties leaves a dynamically
	// loaded page at the Loader's zero size on some Qt builds.
	width: view ? view.width : implicitWidth
	height: view ? view.height : implicitHeight
	visible: !!view && view.currentItem === root

}

/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

// Stable Model 2 base type. Partner pages receive navigation lifecycle
// properties from SwipeViewPage without depending on its source location.
SwipeViewPage {
	// Compiler-approved semantic bindings for this page. Kept optional so
	// existing Model 2 pages remain source-compatible.
	property var configuration: ({})
}

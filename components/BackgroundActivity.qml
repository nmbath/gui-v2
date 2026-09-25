/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

/*
	App-wide "something long-running is happening" aggregator, backing the
	status bar's activity indicator (StatusBar_Landscape/Portrait's
	activityButton) and its BackgroundActivityDialog summary popup.

	Composed from a fixed list of providers, each exposing the same shape -
	`busy` and `items` (an array of { service, action, progress }) - the same
	static-composition pattern data/DataManager.qml already uses for its own
	list of data singletons. Adding a future provider is a one-line addition
	to `providers` below; nothing else in this file, or in the status
	bar/dialog that read it, needs to change.
*/
QtObject {
	id: root

	readonly property ContainersActivity containersActivity: ContainersActivity {}
	readonly property QtObject storageActivity: QtObject {
		readonly property var items: Global.storage?.backgroundActivityItems ?? []
		readonly property bool busy: items.length > 0
	}

	readonly property var providers: [root.containersActivity, root.storageActivity]

	readonly property bool busy: root.providers.some(function(provider) { return provider.busy })

	readonly property var items: {
		let result = []
		for (let i = 0; i < root.providers.length; ++i) {
			result = result.concat(root.providers[i].items)
		}
		return result
	}

	Component.onCompleted: Global.backgroundActivity = root
}

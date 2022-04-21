/*
** Copyright (C) 2021 Victron Energy B.V.
*/

import QtQuick
import QtQuick.Controls as C
import QtQuick.Templates as CT
import Victron.VenusOS

FocusScope {
	id: root

	property string title
	property bool hasSidePanel
	property int navigationButton
	property color backgroundColor: Theme.color.page.background
	property bool fullScreenWhenIdle

	width: parent ? parent.width : 0
	height: parent ? parent.height : 0

	C.StackView.onActivated: Global.pageManager.currentPage = root

	// TODO only pass this on if demo mode is active
	Keys.onReleased: function(event) {
		Global.pageManager.emitter.demoKeyPressed(event)
	}
}
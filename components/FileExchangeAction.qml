/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

// Starts a file exchange session for one action, such as app-install, and takes the user through
// it: on the GX display, a popup shows a QR code for a phone to send the file; in a browser, the
// file is chosen first and sent by the browser itself. A popup then shows the file arriving and
// being checked, a page shows the review to confirm, and a popup shows the result.
//
// The session is the app manager's, not this GUI's: the GX display and every browser see the same
// one, and it outlives a closed popup or a reloaded page. So what is shown follows the published
// state: while page is the current page, a session of this action is followed to its review and
// result, whoever started it, and starting while a session is open shows that session instead.
QtObject {
	id: root

	required property string actionId
	property var parameters: ({})
	// The files the browser's file picker offers.
	property string fileAccept
	// The page that shows /FileExchange/Session/Review, with Confirm and Cancel.
	property string reviewPage: "/pages/settings/PageSettingsFileExchangeReview.qml"
	// Where to return to once the session ends; the page the review was opened from, if null.
	property var returnPage: null
	// The page the action is offered on; while it is the current page, the session is followed.
	property var page: null

	property string title
	property string scanInstruction
	property string receivingText
	property string validatingText
	property string confirmText
	property string confirmButtonText
	// The confirm popup's title; with none, the review's confirm button confirms at once.
	property string confirmTitle
	property string confirmDescription
	property string processingText
	property string completedText
	property string failedTitle

	readonly property bool available: FileExchange.valid && _available.value === 1
	readonly property int unavailableReason: available ? 0 : _unavailableReason.value || 0
	// Why the action is not available, or "" while it is.
	readonly property string unavailableText: available ? "" : FileExchange.unavailableReasonText(unavailableReason)

	// True when the session is this action's, for these parameters. An update's app is known
	// only once the file is reviewed.
	function ownsSession() {
		return FileExchange.action === root.actionId
				&& (root.parameters.component === undefined || FileExchange.component === root.parameters.component)
				&& (root.parameters.name === undefined || !FileExchange.review.name || FileExchange.review.name === root.parameters.name)
	}

	// True when an open session should be shown rather than a new one started. A session of this
	// action that is still waiting has been sent nothing, so it is started afresh.
	function _mustResume() {
		return FileExchange.active
				&& !(FileExchange.state === VenusOS.FileExchange_State_Waiting && root.ownsSession())
	}

	// Shows the open session: its review, or a popup following it.
	function resume() {
		if (FileExchange.state === VenusOS.FileExchange_State_Review && root.ownsSession()) {
			root.openReview()
		} else if (!root._dialogOpen) {
			Global.dialogLayer.open(_dialogComponent, { mode: FileExchangeDialog.Mode.Follow })
		}
	}

	function start() {
		if (root._mustResume()) {
			root.resume()
		} else if (!root.available) {
			return
		} else if (Qt.platform.os === "wasm") {
			root._choosing = true
			BackendConnection.chooseFileExchangeFile(root.fileAccept)
		} else {
			Global.dialogLayer.open(_dialogComponent, { mode: FileExchangeDialog.Mode.Scan })
		}
	}

	// For data the GUI has made itself, rather than a file the user chose, such as a form.
	function send() {
		if (root._mustResume()) {
			root.resume()
		} else {
			Global.dialogLayer.open(_dialogComponent, { mode: FileExchangeDialog.Mode.Upload })
		}
	}

	function openReview() {
		if (root._reviewPending || root._reviewPageOpen) {
			return
		}
		root._reviewPending = true
		Qt.callLater(root._pushReview)
	}

	function _pushReview() {
		root._reviewPending = false
		if (!root._reviewPageOpen && FileExchange.state === VenusOS.FileExchange_State_Review) {
			Global.pageManager.pushPage(root.reviewPage, { title: root.title, fileExchangeAction: root })
		}
	}

	// Confirms the session under review, and shows it being carried out.
	function confirm(reviewPage) {
		Global.dialogLayer.open(_dialogComponent, { mode: FileExchangeDialog.Mode.Confirm, reviewPage: reviewPage })
	}

	// Leaves the review page, once the session has ended.
	function finish(reviewPage) {
		if (root.returnPage) {
			Global.pageManager.popPage(root.returnPage)
		} else if (reviewPage && Global.pageManager.pageStack.currentPage === reviewPage) {
			Global.pageManager.popPage()
		}
	}

	property bool _choosing
	property bool _dialogOpen
	property bool _reviewPending
	// Set by the review page while it is open.
	property bool _reviewPageOpen
	// The session whose review the user left without confirming or cancelling: it is shown again
	// when the action is started, not each time page is shown.
	property string _leftReviewSessionId

	// Follows the session while page is the current page and nothing else is showing it.
	function _follow() {
		if (!root.page || Global.pageManager.pageStack.currentPage !== root.page
				|| root._dialogOpen || root._reviewPageOpen || !root.ownsSession()
				|| (FileExchange.ended && FileExchange.sessionId === FileExchange.dismissedSessionId)
				|| (FileExchange.state === VenusOS.FileExchange_State_Review && FileExchange.sessionId === root._leftReviewSessionId)) {
			return
		}
		switch (FileExchange.state) {
		case VenusOS.FileExchange_State_Receiving:
		case VenusOS.FileExchange_State_Validating:
		case VenusOS.FileExchange_State_Review:
		case VenusOS.FileExchange_State_Processing:
		case VenusOS.FileExchange_State_Complete:
		case VenusOS.FileExchange_State_Failed:
			root.resume()
			break
		case VenusOS.FileExchange_State_Cancelled:
			FileExchange.control("dismiss")
			break
		}
	}

	readonly property Connections _sessionConnection: Connections {
		target: FileExchange
		// Later, once the session's values have all changed.
		function onStateChanged() { Qt.callLater(root._follow) }
		function onSessionIdChanged() { Qt.callLater(root._follow) }
	}

	readonly property Connections _pageConnection: Connections {
		target: Global.pageManager ? Global.pageManager.pageStack : null
		function onCurrentPageChanged() { Qt.callLater(root._follow) }
	}

	Component.onCompleted: Qt.callLater(root._follow)

	readonly property VeQuickItem _available: VeQuickItem {
		uid: FileExchange.uid + "/Actions/" + root.actionId.replace(/-/g, "_") + "/Available"
	}

	readonly property VeQuickItem _unavailableReason: VeQuickItem {
		uid: FileExchange.uid + "/Actions/" + root.actionId.replace(/-/g, "_") + "/UnavailableReason"
	}

	readonly property Connections _uploadConnection: Connections {
		target: BackendConnection
		enabled: root._choosing
		function onFileExchangeUploadStatusChanged() {
			if (BackendConnection.fileExchangeUploadStatus === BackendConnection.FileExchangeUploadSelected) {
				root._choosing = false
				root.send()
			} else if (BackendConnection.fileExchangeUploadStatus === BackendConnection.FileExchangeUploadCancelled) {
				root._choosing = false
			}
		}
	}

	readonly property Component _dialogComponent: Component {
		FileExchangeDialog {
			fileExchangeAction: root
			Component.onCompleted: root._dialogOpen = true
			onClosed: root._dialogOpen = false
			Component.onDestruction: root._dialogOpen = false
		}
	}
}

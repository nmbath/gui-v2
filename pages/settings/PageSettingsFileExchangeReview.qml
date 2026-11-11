/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

// What a file exchange session received, from /FileExchange/Session/Review, for the user to
// confirm or cancel. It comes from the file, so it is shown as plain text only.
Page {
	id: root

	required property FileExchangeAction fileExchangeAction
	readonly property var review: FileExchange.review
	readonly property bool isApp: FileExchange.action === "app-install" || FileExchange.action === "app-update"
	property string sessionId: FileExchange.sessionId
	property bool confirming

	Component.onCompleted: root.fileExchangeAction._reviewPageOpen = true
	Component.onDestruction: {
		root.fileExchangeAction._reviewPageOpen = false
		if (!root.confirming && FileExchange.state === VenusOS.FileExchange_State_Review
				&& FileExchange.sessionId === root.sessionId) {
			root.fileExchangeAction._leftReviewSessionId = root.sessionId
		}
	}

	component ReviewText : ListSetting {
		id: reviewText

		property string secondaryText

		preferredVisible: secondaryText.length > 0
		contentItem: ListItemLabelLayout {
			primaryText: reviewText.text
			primaryLabel.font: reviewText.font
			secondaryText: reviewText.secondaryText
			secondaryLabel.textFormat: Text.PlainText
		}
	}

	Connections {
		target: FileExchange
		function onStateChanged() {
			if (root.confirming || FileExchange.sessionId !== root.sessionId
					|| FileExchange.state === VenusOS.FileExchange_State_Review) {
				return
			}
			// The review ran out of time, or the session was cancelled elsewhere.
			if (FileExchange.state === VenusOS.FileExchange_State_Failed) {
				const reason = FileExchange.errorSummary(FileExchange.errorCode, FileExchange.error)
				const title = root.fileExchangeAction.failedTitle || FileExchange.failedText
				Global.showToastNotification(VenusOS.Notification_Warning, reason ? title + "\n" + reason : title, 5000)
			}
			if (FileExchange.ended) {
				FileExchange.control("dismiss")
			}
			root.fileExchangeAction.finish(root)
		}
		function onSessionIdChanged() {
			if (!root.confirming && FileExchange.sessionId !== root.sessionId) {
				root.fileExchangeAction.finish(root)
			}
		}
	}

	GradientListView {
		model: VisibleItemModel {
			ReviewText {
				//% "Name"
				text: qsTrId("fileexchange_review_name")
				secondaryText: root.review.title || root.review.name || ""
				preferredVisible: root.isApp
			}

			ReviewText {
				//% "Version"
				text: qsTrId("fileexchange_review_version")
				secondaryText: root.review.version || ""
				preferredVisible: root.isApp
			}

			ReviewText {
				//% "Installed version"
				text: qsTrId("fileexchange_review_installed_version")
				secondaryText: root.review.installedVersion || ""
			}

			ReviewText {
				//% "Description"
				text: qsTrId("fileexchange_review_description")
				secondaryText: root.isApp ? root.review.description || "" : ""
			}

			ReviewText {
				//% "Contact"
				text: qsTrId("fileexchange_review_contact")
				secondaryText: root.isApp
						? [root.review.organization, root.review.support].filter(v => !!v).join(", ")
						: ""
			}

			ListButton {
				text: root.fileExchangeAction.confirmText
				secondaryText: root.fileExchangeAction.confirmButtonText
				writeAccessLevel: VenusOS.User_AccessType_User
				interactive: FileExchange.canConfirm
				onClicked: Global.dialogLayer.open(confirmDialogComponent)
			}

			ListButton {
				//% "Cancel"
				text: qsTrId("fileexchange_review_cancel")
				secondaryText: CommonWords.cancel
				writeAccessLevel: VenusOS.User_AccessType_User
				interactive: FileExchange.canCancel
				onClicked: FileExchange.control("cancel")
			}

			SettingsListHeader {
				//% "License"
				text: qsTrId("fileexchange_review_license")
				preferredVisible: root.isApp && !!root.review.license
			}

			PrimaryListLabel {
				text: root.review.license || ""
				textFormat: Text.PlainText
				font.pixelSize: Theme.font_size_caption
				color: Theme.color_font_secondary
				preferredVisible: root.isApp && text.length > 0
			}
		}
	}

	Component {
		id: confirmDialogComponent

		ModalWarningDialog {
			title: root.fileExchangeAction.confirmTitle
			description: root.fileExchangeAction.confirmDescription.arg(root.review.title || root.review.name || "")
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
			onAccepted: root.confirming = true
			// Later, once the dialog layer has let this dialog go.
			onClosed: if (root.confirming) Qt.callLater(root.fileExchangeAction.confirm, root)
		}
	}
}

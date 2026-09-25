/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

// Manage web pages (see VenusOS_GUIv2_Web_Content_and_Container_Proxy_Design
// and venus-private#707): add one manually via venus-exchange's real upload
// flow, and list every registered page - manually-added and automatically-
// registered (e.g. by venus-containers) alike - in two separate sections.
// Only the manually-added section supports Add/Remove: a page's Origin
// (venus-web-pages' own field, "manual" vs a capability's own name)
// determines which section it appears in and whether Remove is available -
// see WebPageDelegate.qml's isManual and PageSettingsWebPage.qml's own
// Remove gating. Browsing/opening *all* available pages (regardless of
// origin) is the separate top-left status bar button, which pushes straight
// into a page rather than this management view.
//
// Add uses the generic ExchangeAction workflow supplied by the parent
// mbath/exchange branch. Remove remains the simple writable D-Bus trigger
// exposed by venus-web-pages, which itself refuses to remove a non-manual
// page through that trigger - this UI's own hiding/disabling is real
// enforcement, not the only enforcement.
//
// Backed by com.victronenergy.webpages, provided by the separate
// venus-web-pages daemon - see docs/web-page-descriptor.md in the
// venus-exchange repo, and venus-web-pages' own README.

import QtQuick
import Victron.VenusOS

Page {
	id: root

	// Not qsTrId - see PageSettingsIntegrations.qml's "Web pages" entry for why.
	title: "Web pages"

	readonly property string webPagesServiceUid: BackendConnection.serviceUidForType("webpages")
	property int manualCount: 0
	property int automaticCount: 0

	function recomputeManualCount() {
		let count = 0
		for (let i = 0; i < manualPagesRepeater.count; ++i) {
			const row = manualPagesRepeater.itemAt(i)
			if (row && row.isManual) {
				count++
			}
		}
		root.manualCount = count
	}

	function recomputeAutomaticCount() {
		let count = 0
		for (let i = 0; i < automaticPagesRepeater.count; ++i) {
			const row = automaticPagesRepeater.itemAt(i)
			if (row && !row.isManual) {
				count++
			}
		}
		root.automaticCount = count
	}

	ExchangeAction {
		id: webPageRegisterAction

		actionId: "web-page-register"
		reviewPageTitle: "Add web page"
		failureTitle: "Web page could not be added"
		subjectLabel: "Web page"
		summaryLabel: "Destination"
		confirmActionText: "Add this web page"
		confirmTitle: "Add web page?"
		confirmDescription: "Add '%1' to this GX device?"
		processingText: "Adding web page"
		completionText: "The web page was added successfully."
		completionToast: "Web page added"
		scanInstruction: "Scan this QR code to upload a web page descriptor."
		fileAccept: ".json,application/json"
	}

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

	GradientListView {
		model: VisibleItemModel {
			SettingsColumn {
				width: parent ? parent.width : 0

				ListButton {
					text: "Add web page from file"
					secondaryText: "Add"
					preferredVisible: webPageRegisterAction.available
					writeAccessLevel: VenusOS.User_AccessType_User
					onClicked: webPageRegisterAction.start()
				}

				PrimaryListLabel {
					text: "Local connection required to add a web page from a file."
					preferredVisible: BackendConnection.vrm
							&& webPageRegisterAction.serviceConnected
							&& webPageRegisterAction.actionAvailable
				}
			}

			ListInfoLabel {
				text: "No web pages are registered yet."
				preferredVisible: pageTitles.count === 0
			}

			SettingsColumn {
				width: parent ? parent.width : 0

				PrimaryListLabel {
					text: "Manually added"
					preferredVisible: root.manualCount > 0
				}

				Repeater {
					id: manualPagesRepeater
					model: pageTitles
					// Covers rows appearing/disappearing - each row's own
					// onIsManualChanged (below) covers a row's origin
					// becoming known/changing after it already exists.
					onCountChanged: root.recomputeManualCount()
					delegate: WebPageDelegate {
						required property VeQItem item // item for the "Title" subpath

						pagePrefix: item.itemParent().uid
						pageTitle: item.value || ""
						preferredVisible: isManual

						onIsManualChanged: root.recomputeManualCount()
						Component.onCompleted: root.recomputeManualCount()
					}
				}
			}

			SettingsColumn {
				width: parent ? parent.width : 0

				PrimaryListLabel {
					text: "Added automatically"
					preferredVisible: root.automaticCount > 0
				}

				Repeater {
					id: automaticPagesRepeater
					model: pageTitles
					onCountChanged: root.recomputeAutomaticCount()
					delegate: WebPageDelegate {
						required property VeQItem item // item for the "Title" subpath

						pagePrefix: item.itemParent().uid
						pageTitle: item.value || ""
						preferredVisible: !isManual

						onIsManualChanged: root.recomputeAutomaticCount()
						Component.onCompleted: root.recomputeAutomaticCount()
					}
				}
			}
		}
	}
}

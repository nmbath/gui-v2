/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

// Manage manually-added web pages (see
// VenusOS_GUIv2_Web_Content_and_Container_Proxy_Design and
// venus-private#707): add one via venus-exchange's real upload flow, list
// the ones already added, tap one for detail + remove. Pages registered by
// device drivers (Fronius/SMA/ABB) or services (Node-RED, Signal K) are not
// managed here - this is specifically the manual set, per explicit
// correction. Browsing/opening *all* available pages (manual and
// driver-registered) is the separate top-left status bar button, which
// pushes straight into a page rather than this management view.
//
// Add uses the generic ExchangeAction workflow supplied by the parent
// mbath/exchange branch. Remove remains the simple writable D-Bus trigger
// exposed by venus-web-pages.
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

	ExchangeAction {
		id: webPageRegisterAction

		actionId: "web-page-register"
		reviewPageTitle: "Add web page"
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
				preferredVisible: pageTitlesRepeater.count === 0
			}

			SettingsColumn {
				width: parent ? parent.width : 0

				Repeater {
					id: pageTitlesRepeater
					model: pageTitles
					delegate: WebPageDelegate {
						required property VeQItem item // item for the "Title" subpath

						pagePrefix: item.itemParent().uid
						pageTitle: item.value || ""
					}
				}
			}
		}
	}
}

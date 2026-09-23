/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

// Detail page for one registered web page: where it points, and the
// Remove action. Opening the page itself (WebContentPage) is a separate
// action from here, not automatic - see openRequested below.

import QtQuick
import Victron.VenusOS

Page {
	id: root

	required property string pageId
	required property string pagePrefix // .../WebPages/<id>
	required property string pageTitle

	readonly property string webPagesServiceUid: BackendConnection.serviceUidForType("webpages")
	readonly property string visibilitySummary: {
		const locations = []
		if (localVisibilityItem.valid && localVisibilityItem.value === 1) {
			locations.push("Local display")
		}
		if (wasmVisibilityItem.valid && wasmVisibilityItem.value === 1) {
			locations.push("Local network")
		}
		if (vrmVisibilityItem.valid && vrmVisibilityItem.value === 1) {
			locations.push("VRM")
		}
		return locations.join(", ")
	}

	VeQuickItem {
		id: localProxyPortItem
		uid: root.pagePrefix + "/LocalProxyPort"
	}
	VeQuickItem {
		id: wasmProxyPortItem
		uid: root.pagePrefix + "/WasmProxyPort"
	}
	VeQuickItem {
		id: localVisibilityItem
		uid: root.pagePrefix + "/Visibility/Local"
	}
	VeQuickItem {
		id: wasmVisibilityItem
		uid: root.pagePrefix + "/Visibility/Wasm"
	}
	VeQuickItem {
		id: vrmVisibilityItem
		uid: root.pagePrefix + "/Visibility/Vrm"
	}
	VeQuickItem {
		id: availableItem
		uid: root.pagePrefix + "/Available"
	}
	VeQuickItem {
		id: schemeItem
		uid: root.pagePrefix + "/Upstream/Scheme"
	}
	VeQuickItem {
		id: hostItem
		uid: root.pagePrefix + "/Upstream/Host"
	}
	VeQuickItem {
		id: portItem
		uid: root.pagePrefix + "/Upstream/Port"
	}
	VeQuickItem {
		id: pathItem
		uid: root.pagePrefix + "/Upstream/Path"
	}
	VeQuickItem {
		id: removeItem
		uid: root.webPagesServiceUid + "/WebPages/Remove"
	}

	GradientListView {
		model: VisibleItemModel {
			SettingsColumn {
				width: parent ? parent.width : 0

				// Not qsTrId - see PageSettingsIntegrations.qml's "Web pages" entry for why.
				ListText {
					text: "Title"
					secondaryText: root.pageTitle
				}

				ListText {
					text: "Scheme"
					secondaryText: schemeItem.valid ? schemeItem.value : ""
				}

				ListText {
					text: "Host"
					secondaryText: hostItem.valid ? hostItem.value : ""
				}

				ListText {
					text: "Port"
					secondaryText: portItem.valid ? portItem.value : ""
				}

				ListText {
					text: "Path"
					secondaryText: pathItem.valid ? pathItem.value : ""
				}

				ListText {
					text: "Visible from"
					secondaryText: root.visibilitySummary
				}

				ListNavigation {
					text: "Open"
					enabled: availableItem.valid && availableItem.value === 1
							&& (Qt.platform.os === "wasm"
								? wasmVisibilityItem.value === 1 && wasmProxyPortItem.value > 0
								: localVisibilityItem.value === 1 && localProxyPortItem.value > 0)
					// Pushed by file path, not a locally-declared Component -
					// see WebContentPage.qml's own header and
					// PageSettingsWebPages.qml's git history for why a
					// static reference breaks compilation wherever Qt
					// WebEngine is absent (every device today).
					onClicked: Global.pageManager.pushPage("/components/WebContentPage.qml", {
						"title": root.pageTitle,
						"localProxyPort": localProxyPortItem.value,
						"wasmProxyPort": wasmProxyPortItem.value,
					})
				}

				ListButton {
					// Plain ListButton styling, matching
					// PageSettingsContainer.qml's "Purge" row - no colour
					// override. The earlier buttonBorderColor/
					// buttonBackgroundColor override (copied from
					// UnpairDialog's internal accept-button styling, which
					// is a different kind of control) is not how this app
					// styles a destructive list-row action.
					text: "Remove this web page"
					secondaryText: "Remove"
					enabled: removeItem.valid && root.pageId.length > 0
					writeAccessLevel: VenusOS.User_AccessType_User
					onClicked: Global.dialogLayer.open(removeConfirmComponent)

					Component {
						id: removeConfirmComponent

						ModalWarningDialog {
							title: "Remove web page?"
							description: "Remove '" + root.pageTitle + "' from this GX device?"
							dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
							onAccepted: {
								removeItem.setValue(root.pageId)
								Global.pageManager.popPage()
							}
						}
					}
				}
			}
		}
	}
}

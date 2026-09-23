/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

// Manage the partner GUIv2 branding/skinning package (see
// guiv2-customisation/INSTALLER-CONTRACT.md in the venus repo): add one via
// venus-exchange's real upload flow (which verifies and stages the .vgp,
// then hands it to venus-package-manager to actually install), remove it
// via the plain writeable BusItem trigger venus-package-manager exposes per
// package - GUIv2 can only get/set BusItem values, never call a D-Bus
// method (same convention com.victronenergy.containers' own DesiredState
// already uses).
//
// Backed by com.victronenergy.packagemanager, provided by the separate
// venus-package-manager daemon, which is itself extensible to other
// package types beyond partner branding - this page only concerns
// "gui-v2-partner-package" entries in its /Packages tree, filtering out
// anything else that might appear there later.
//
// Add uses the generic ExchangeAction workflow (see PageSettingsWebPages.qml
// for the other live user of the same component).
//
// Not qsTrId anywhere here: this feature is new and was never run through
// lupdate, and qsTrId falls back to showing the raw id text on a device
// whose translation catalogue predates it (found live on venus-web-pages'
// own equivalent page). Revisit once this is a real PR and lupdate has run
// for real.

import QtQuick
import Victron.VenusOS

Page {
	id: root

	title: "Partner branding"

	readonly property string vpmServiceUid: BackendConnection.serviceUidForType("packagemanager")
	readonly property string partnerBrandingFormat: "gui-v2-partner-package"
	property int installedCount: 0

	ExchangeAction {
		id: partnerBrandingInstallAction

		actionId: "partner-branding-install"
		reviewPageTitle: "Add partner branding"
		subjectLabel: "Partner branding"
		confirmActionText: "Add this partner branding"
		confirmTitle: "Add partner branding?"
		confirmDescription: "The validated package for '%1' will be installed on this GX device."
		processingText: "Adding partner branding"
		completionText: "The partner branding was added successfully."
		completionToast: "Partner branding added"
		scanInstruction: "Scan this QR code to upload a partner branding package."
		fileAccept: ".vgp"
	}

	VeQItemSortTableModel {
		id: packages

		model: VeQItemTableModel {
			uids: [ root.vpmServiceUid + "/Packages" ]
			flags: VeQItemTableModel.AddChildren | VeQItemTableModel.AddNonLeaves | VeQItemTableModel.DontAddItem
		}
		dynamicSortFilter: true
		filterFlags: VeQItemSortTableModel.FilterOffline
	}

	VeQItemSortTableModel {
		id: packageIds

		model: VeQItemChildModel {
			model: packages
			childId: "Id"
		}
		dynamicSortFilter: true
		filterFlags: VeQItemSortTableModel.FilterInvalid
	}

	function recomputeInstalledCount() {
		let count = 0
		for (let i = 0; i < packageRepeater.count; ++i) {
			const row = packageRepeater.itemAt(i)
			if (row && row.isPartnerBranding) {
				count++
			}
		}
		root.installedCount = count
	}

	GradientListView {
		model: VisibleItemModel {
			SettingsColumn {
				width: parent ? parent.width : 0

				ListButton {
					text: "Add partner branding from file"
					secondaryText: "Add"
					preferredVisible: partnerBrandingInstallAction.available && root.installedCount === 0
					writeAccessLevel: VenusOS.User_AccessType_User
					onClicked: partnerBrandingInstallAction.start()
				}

				PrimaryListLabel {
					text: "Local connection required to add partner branding from a file."
					preferredVisible: BackendConnection.vrm
							&& partnerBrandingInstallAction.serviceConnected
							&& partnerBrandingInstallAction.actionAvailable
							&& root.installedCount === 0
				}
			}

			SettingsColumn {
				width: parent ? parent.width : 0

				Repeater {
					id: packageRepeater
					model: packageIds
					// Covers rows appearing/disappearing - each row's own
					// onIsPartnerBrandingChanged (below) covers a row's type
					// becoming known/changing after it already exists.
					onCountChanged: root.recomputeInstalledCount()
					delegate: ListButton {
						id: packageDelegate

						required property VeQItem item // item for the "Id" subpath
						readonly property string packagePrefix: item.itemParent().uid
						readonly property bool isPartnerBranding: typeItem.value === root.partnerBrandingFormat

						text: "Remove partner branding"
						secondaryText: nameItem.value || ""
						caption: versionItem.value ? "Version " + versionItem.value : ""
						preferredVisible: isPartnerBranding
						writeAccessLevel: VenusOS.User_AccessType_User
						onClicked: Global.dialogLayer.open(removeConfirmationDialogComponent)

						onIsPartnerBrandingChanged: root.recomputeInstalledCount()
						Component.onCompleted: root.recomputeInstalledCount()

						VeQuickItem { id: typeItem; uid: packageDelegate.packagePrefix + "/Type" }
						VeQuickItem { id: nameItem; uid: packageDelegate.packagePrefix + "/Name" }
						VeQuickItem { id: versionItem; uid: packageDelegate.packagePrefix + "/Version" }
						VeQuickItem { id: removeItem; uid: packageDelegate.packagePrefix + "/Remove" }

						Component {
							id: removeConfirmationDialogComponent

							ModalWarningDialog {
								title: "Remove partner branding?"
								description: "'" + (nameItem.value || "")
										+ "' will be removed and the system will revert to stock branding."
								dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
								onAccepted: removeItem.setValue(1)
							}
						}
					}
				}
			}
		}
	}
}

/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

// Uses venus-exchange's package actions as a package page does. In mock mode,
// Acme Marine Console 1.0.0 is installed and the upload is Acme Tank Monitor.
Page {
	id: root

	component PackageAction : ExchangeAction {
		subjectLabel: "Package"
		cancelActionText: "Cancel"
		uploadingText: "Uploading package…"
		scanInstruction: "Scan this QR code to upload the package."
		fileAccept: ".vpk"
	}

	PackageAction {
		id: installAction
		actionId: "package-install"
		reviewPageTitle: "Install package"
		failureTitle: "Package could not be installed"
		confirmActionText: "Install this package"
		confirmTitle: "Install package?"
		confirmDescription: "‘%1’ will be installed on this GX device."
		processingText: "Installing package"
		completionText: "Package installed."
		completionToast: "Package installed"
	}

	PackageAction {
		id: updateAction
		property string packageName: "acme-marine"
		actionId: "package-update"
		startParameters: ({ name: packageName })
		reviewPageTitle: "Update package"
		failureTitle: "Package could not be updated"
		confirmActionText: "Update this package"
		confirmTitle: "Update package?"
		confirmDescription: "‘%1’ will be updated on this GX device."
		processingText: "Updating package"
		completionText: "Package updated."
		completionToast: "Package updated"
	}

	GradientListView {
		model: VisibleItemModel {
			ListButton {
				text: "Install a package"
				secondaryText: "Upload"
				interactive: installAction.available
				onClicked: installAction.start()
			}

			ListButton {
				text: "Update acme-marine"
				secondaryText: "Upload"
				interactive: updateAction.available
				onClicked: {
					updateAction.packageName = "acme-marine"
					updateAction.start()
				}
			}

			ListButton {
				text: "Update acme-solar (not installed)"
				secondaryText: "Upload"
				interactive: updateAction.available
				onClicked: {
					updateAction.packageName = "acme-solar"
					updateAction.start()
				}
			}

			PrimaryListLabel {
				text: "A second update of acme-marine is refused by the package manager, "
						+ "and so is installing Acme Tank Monitor again."
			}
		}
	}
}

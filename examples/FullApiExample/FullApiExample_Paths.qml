import QtQuick
import Victron.GuiPlugins

/*
	The paths directly below a uid, such as the paths at the top of a device.

	PluginPathModel lists the paths that the system has, sorted by name. A row with paths below it
	opens this page again, for that row's uid. A row without paths below it shows its value, read
	with a PluginDataItem. A second PluginPathModel in each row tells the two apart.
*/
PluginPage {
	id: root

	// Set by the list item that opens this page.
	property string pathUid

	PluginPathModel {
		id: paths

		uid: root.pathUid
	}

	PluginModelListView {
		model: paths

		header: PluginPrimaryListLabel {
			text: root.pathUid + " has " + paths.count + " paths below it."
		}

		delegate: PluginListNavigation {
			id: pathRow

			required property string name
			required property string uid

			readonly property PluginPathModel pathsBelow: PluginPathModel {
				uid: pathRow.uid
			}
			readonly property bool hasPathsBelow: pathsBelow.count > 0

			// Only a path without paths below it has a value of its own.
			readonly property PluginDataItem pathValue: PluginDataItem {
				uid: pathRow.hasPathsBelow ? "" : pathRow.uid
			}

			text: pathRow.name
			secondaryText: pathRow.hasPathsBelow ? ""
				: pathRow.pathValue.valid ? String(pathRow.pathValue.value)
				: "--"
			interactive: pathRow.hasPathsBelow
			pageUrl: Qt.resolvedUrl("FullApiExample_Paths.qml")
			pageProperties: ({ pathUid: pathRow.uid })
		}
	}
}

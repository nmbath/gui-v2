import QtQuick
import Victron.GuiPlugins

/*
	The devices of one service type, such as every tank.

	PluginDeviceModel lists the devices. It does not list the values on a device. The level is a
	PluginDataItem whose uid is the row's service uid plus a path. The rows are sorted by name.
*/
PluginPage {
	PluginDeviceModel {
		id: tanks

		serviceTypes: ["tank"]
	}

	PluginModelListView {
		model: tanks

		header: PluginPrimaryListLabel {
			text: "Each row is a tank. The number on the right is its level."
		}

		delegate: PluginListText {
			required property int index
			required property string name
			required property string serviceUid
			required property string serviceType
			required property int deviceInstance
			required property int productId

			text: name
			caption: serviceType + ", instance " + deviceInstance + ", product " + productId
			dataItem.uid: serviceUid + "/Level"
		}
	}
}

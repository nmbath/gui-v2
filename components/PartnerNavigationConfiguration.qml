pragma Singleton

import QtQuick
import Victron.VenusOS

QtObject {
	id: root

	property int _revision: 0
	readonly property var hiddenCorePages: {
		_revision
		const hidden = ({})
		for (let i = 0; i < _integrations.count; ++i) {
			const policy = _integrations.integrationAt(i).configuration
			const pages = policy.hiddenCorePages || []
			for (let j = 0; j < pages.length; ++j) hidden[pages[j]] = true
		}
		return hidden
	}

	function isCorePageHidden(pageId) {
		return hiddenCorePages[pageId] === true
	}

	readonly property GuiPluginIntegrationModel _integrations: GuiPluginIntegrationModel {
		type: GuiPluginLoader.NavigationPolicy
		onCountChanged: root._revision++
	}
}

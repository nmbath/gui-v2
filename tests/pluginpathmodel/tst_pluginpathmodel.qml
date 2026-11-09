/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtTest
import Victron.VenusOS
import Victron.GuiPlugins

TestCase {
	id: root

	name: "PluginPathModelTest"

	property var createdUids: []

	PluginPathModel {
		id: paths
	}

	Repeater {
		id: rows

		model: paths

		delegate: Item {
			required property int index
			required property string name
			required property string uid
		}
	}

	PluginDataItem {
		id: dataItem
	}

	SignalSpy {
		id: countSpy

		target: paths
		signalName: "countChanged"
	}

	function setValue(uid, value) {
		createdUids.push(uid)
		MockManager.setValue(uid, value)
	}

	// The model updates its list 100 ms after a change below uid.
	function waitForTheUpdateDelay() {
		wait(300)
	}

	function expectNames(names) {
		tryCompare(paths, "count", names.length)
		tryCompare(rows, "count", names.length)
		for (let i = 0; i < names.length; ++i) {
			compare(paths.nameAt(i), names[i])
			compare(paths.uidAt(i), paths.uid.replace(/\/+$/, "") + "/" + names[i])
			const item = rows.itemAt(i)
			verify(item !== null)
			compare(item.name, names[i])
			compare(item.uid, paths.uidAt(i))
		}
	}

	function cleanup() {
		dataItem.uid = ""
		paths.serviceType = ""
		paths.path = ""
		paths.uid = ""
		for (let i = 0; i < createdUids.length; ++i) {
			MockManager.removeValue(createdUids[i])
		}
		createdUids = []
	}

	function test_emptyUid() {
		compare(paths.uid, "")
		compare(paths.count, 0)
		compare(paths.nameAt(0), "")
		compare(paths.uidAt(-1), "")
	}

	function test_listsTheChildrenSorted() {
		const uid = "mock/com.victronenergy.solarcharger.ppm_sorted"
		setValue(uid + "/Soc", 50)
		setValue(uid + "/Dc/0/Voltage", 12.5)
		setValue(uid + "/NrOfTrackers", 3)
		setValue(uid + "/Pv/10/V", 30)
		setValue(uid + "/Pv/2/V", 20)
		setValue(uid + "/Pv/0/V", 10)
		setValue(uid + "/Pv/Name", "Not a number")
		setValue(uid + "/alpha", 1)

		paths.uid = uid
		expectNames(["alpha", "Dc", "NrOfTrackers", "Pv", "Soc"])

		paths.uid = uid + "/Pv"
		expectNames(["0", "2", "10", "Name"])

		// A trailing slash is ignored.
		paths.uid = uid + "/Pv/"
		expectNames(["0", "2", "10", "Name"])

		// A path with a value has no children.
		paths.uid = uid + "/Soc"
		expectNames([])
	}

	function test_aPathThatIsOnlyAskedForIsNotListed() {
		const uid = "mock/com.victronenergy.solarcharger.ppm_asked"
		setValue(uid + "/Soc", 50)
		paths.uid = uid
		expectNames(["Soc"])

		// The data item creates the item for this path, but the system does not have it.
		countSpy.clear()
		dataItem.uid = uid + "/Missing/0/V"
		compare(dataItem.valid, false)
		waitForTheUpdateDelay()
		compare(countSpy.count, 0)
		expectNames(["Soc"])

		// Once the system gives a value below it, it is listed.
		setValue(uid + "/Missing/0/V", 12)
		tryCompare(countSpy, "count", 1)
		expectNames(["Missing", "Soc"])
	}

	function test_aPathWithAnInvalidValueIsListed() {
		const uid = "mock/com.victronenergy.solarcharger.ppm_invalid"
		setValue(uid + "/Empty", undefined)
		paths.uid = uid
		expectNames(["Empty"])
		dataItem.uid = uid + "/Empty"
		compare(dataItem.valid, false)
	}

	function test_addAndRemove() {
		const uid = "mock/com.victronenergy.solarcharger.ppm_changes"
		setValue(uid + "/Soc", 50)
		paths.uid = uid
		expectNames(["Soc"])

		countSpy.clear()
		setValue(uid + "/Dc/0/Voltage", 12.5)
		tryCompare(countSpy, "count", 1)
		expectNames(["Dc", "Soc"])

		MockManager.removeValue(uid + "/Dc")
		createdUids = createdUids.filter(function(createdUid) { return createdUid.indexOf(uid + "/Dc/") !== 0 })
		tryCompare(countSpy, "count", 2)
		expectNames(["Soc"])
	}

	function test_changesCloseTogetherAreOneUpdate() {
		const uid = "mock/com.victronenergy.solarcharger.ppm_burst"
		setValue(uid + "/Soc", 50)
		paths.uid = uid
		expectNames(["Soc"])

		countSpy.clear()
		setValue(uid + "/Dc/0/Voltage", 12.5)
		setValue(uid + "/Mode", 1)
		setValue(uid + "/Yield/Power", 100)
		compare(paths.count, 1)
		expectNames(["Dc", "Mode", "Soc", "Yield"])
		compare(countSpy.count, 1)
	}

	function test_removingTheUidEmptiesTheList() {
		const uid = "mock/com.victronenergy.solarcharger.ppm_removed"
		MockManager.setValue(uid + "/Soc", 50)
		paths.uid = uid
		expectNames(["Soc"])

		MockManager.removeValue(uid)
		tryCompare(paths, "count", 0)
		compare(paths.nameAt(0), "")
	}

	function test_aRemovedUidIsListedAgainWhenItComesBack() {
		const uid = "mock/com.victronenergy.solarcharger.ppm_back"
		MockManager.setValue(uid + "/Soc", 50)
		paths.uid = uid
		expectNames(["Soc"])

		MockManager.removeValue(uid)
		tryCompare(paths, "count", 0)
		// Wait, so that the paths come back after the model has created the item again.
		waitForTheUpdateDelay()

		setValue(uid + "/Soc", 60)
		setValue(uid + "/Mode", 1)
		expectNames(["Mode", "Soc"])
	}

	function test_uidChange() {
		const firstUid = "mock/com.victronenergy.solarcharger.ppm_first"
		const secondUid = "mock/com.victronenergy.solarcharger.ppm_second"
		setValue(firstUid + "/Soc", 50)
		setValue(secondUid + "/Dc/0/Voltage", 12.5)
		setValue(secondUid + "/Mode", 1)

		paths.uid = firstUid
		expectNames(["Soc"])

		paths.uid = secondUid
		expectNames(["Dc", "Mode"])

		// The first uid is no longer watched.
		countSpy.clear()
		setValue(firstUid + "/Yield/Power", 100)
		waitForTheUpdateDelay()
		compare(countSpy.count, 0)
		expectNames(["Dc", "Mode"])
	}

	function test_serviceTypeAndPath() {
		const serviceUid = "mock/com.victronenergy.settings"
		const uid = serviceUid + "/Settings/PluginPathModel"
		setValue(uid + "/B", 1)
		setValue(uid + "/A/X", 2)

		// While only one of them is set, uid is empty.
		paths.serviceType = "settings"
		compare(paths.uid, "")
		compare(paths.count, 0)

		paths.path = "/Settings/PluginPathModel"
		compare(paths.uid, uid)
		expectNames(["A", "B"])

		// The leading slash is optional.
		paths.path = "Settings/PluginPathModel/A"
		compare(paths.uid, uid + "/A")
		expectNames(["X"])

		// "/" is the top of the service.
		paths.path = "/"
		compare(paths.uid, serviceUid)
		let found = false
		for (let i = 0; i < paths.count; ++i) {
			if (paths.nameAt(i) === "Settings") {
				found = true
			}
		}
		verify(found)
		compare(paths.uidAt(0), serviceUid + "/" + paths.nameAt(0))

		paths.serviceType = ""
		compare(paths.uid, "")
		compare(paths.count, 0)
	}
}

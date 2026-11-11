/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

pragma Singleton

import QtQml
import Victron.VenusOS

// The file exchange session of com.victronenergy.appmanager, which takes a GX App, or the installer
// information, from a phone or browser, has it reviewed and confirmed in the GUI, and installs it.
// There is at most one session at a time, under /FileExchange/Session.
QtObject {
	id: root

	readonly property string serviceUid: BackendConnection.serviceUidForType("appmanager")
	readonly property string uid: serviceUid + "/FileExchange"

	readonly property bool valid: _state.valid && _request.valid
	readonly property int state: _state.valid ? _state.value : VenusOS.FileExchange_State_Idle
	readonly property bool ended: state === VenusOS.FileExchange_State_Complete
			|| state === VenusOS.FileExchange_State_Failed
			|| state === VenusOS.FileExchange_State_Cancelled
	// A session is open that has not ended: only one can be, whichever GUI started it.
	readonly property bool active: valid && state !== VenusOS.FileExchange_State_Idle && !ended
	readonly property string sessionId: _sessionId.value || ""
	readonly property string action: _action.value || ""
	readonly property string component: _component.value || ""
	readonly property var review: parseJson(_review.value) || ({})
	readonly property int errorCode: _errorCode.value || 0
	readonly property string error: _error.value || ""
	readonly property bool canConfirm: _canConfirm.value === 1
	readonly property bool canCancel: _canCancel.value === 1
	readonly property bool transferReady: _transferReady.value === 1
	readonly property string capabilityRef: _capabilityRef.value || ""
	readonly property real expires: _expires.value || 0
	readonly property real fileSize: _fileSize.valid ? _fileSize.value : -1
	readonly property real bytesTransferred: _bytesTransferred.value || 0

	// The ended session this GUI has dismissed, so it is not shown again while the dismiss is sent.
	property string dismissedSessionId

	//% "File exchange failed"
	readonly property string failedText: qsTrId("fileexchange_failed")

	signal startReplied(string requestId, bool accepted, string error, string sessionId)
	signal controlReplied(string requestId, bool accepted, string error)

	// Starts a session for the action. Returns the request's id, which startReplied() echoes.
	function start(actionId, parameters) {
		const requestId = _newRequestId(actionId)
		_request.setValue(JSON.stringify({ requestId: requestId, action: actionId, parameters: parameters || {} }))
		return requestId
	}

	// Sends confirm, cancel or dismiss for the session. Returns the request's id, which
	// controlReplied() echoes, or "" if there is no session.
	function control(command) {
		if (!sessionId) {
			return ""
		}
		const requestId = _newRequestId(command)
		if (command === "dismiss") {
			dismissedSessionId = sessionId
		}
		_controlRequest.setValue(JSON.stringify({ requestId: requestId, sessionId: sessionId, command: command }))
		return requestId
	}

	function parseJson(raw) {
		if (typeof raw !== "string" || raw.length === 0) {
			return null
		}
		try {
			return JSON.parse(raw)
		} catch (error) {
			return null
		}
	}

	function errorCodeText(code) {
		switch (code) {
		//% "Another file exchange is in progress"
		case 100: return qsTrId("fileexchange_error_busy")
		//% "Not allowed now"
		case 101: return qsTrId("fileexchange_error_invalid_state")
		case 102:
		case 103:
		//% "Invalid request"
		case 104: return qsTrId("fileexchange_error_invalid_request")
		//% "Not the current file exchange"
		case 106: return qsTrId("fileexchange_error_session_mismatch")
		case 107:
		//% "Not supported"
		case 108: return qsTrId("fileexchange_error_unsupported")
		//% "Not available"
		case 109: return qsTrId("fileexchange_error_action_unavailable")
		//% "Timed out"
		case 202: return qsTrId("fileexchange_error_expired")
		//% "File too large"
		case 204: return qsTrId("fileexchange_error_too_large")
		//% "Upload interrupted"
		case 205: return qsTrId("fileexchange_error_incomplete_body")
		//% "Refused"
		case 305: return qsTrId("fileexchange_error_validation_failed")
		//% "Invalid parameters"
		case 306: return qsTrId("fileexchange_error_invalid_parameters")
		//% "No storage for GX Apps"
		case 400: return qsTrId("fileexchange_error_backend_unavailable")
		//% "Could not be installed"
		case 401: return qsTrId("fileexchange_error_backend_rejected")
		//% "Not enough storage"
		case 500: return qsTrId("fileexchange_error_no_space")
		//% "Storage error"
		case 502: return qsTrId("fileexchange_error_io_error")
		//% "Unexpected error"
		case 505: return qsTrId("fileexchange_error_internal")
		default: return ""
		}
	}

	// What the open session is doing, for a GUI that did not start it.
	function inProgressText() {
		switch (action) {
		//% "A GX App is being added"
		case "app-install": return qsTrId("fileexchange_in_progress_app_install")
		//% "A GX App is being updated"
		case "app-update": return qsTrId("fileexchange_in_progress_app_update")
		case "component-install":
			if (component === "installerInformation") {
				//% "The installer information is being set up"
				return qsTrId("fileexchange_in_progress_installer_information")
			}
			break
		}
		return errorCodeText(100)
	}

	// Why an action is not available, from /FileExchange/Actions/<key>/UnavailableReason.
	readonly property var unavailableReasonTexts: ({
		//% "No storage available"
		2: qsTrId("fileexchange_unavailable_backend_unavailable")
	})

	// The reasons that mean the storage for GX Apps is missing, so nothing on it can be used.
	function isStorageReason(reason) {
		return reason === 2
	}

	function unavailableReasonText(reason) {
		return unavailableReasonTexts[reason] || qsTrId("fileexchange_error_action_unavailable")
	}

	// The reason, from the error code and the app manager's own text.
	function errorSummary(code, text) {
		const label = errorCodeText(code)
		const detail = text ? String(text).trim() : ""
		if (label && detail) {
			return label + ": " + detail
		}
		return label || detail
	}

	function _newRequestId(prefix) {
		return prefix + "-" + Date.now().toString(36) + "-" + Math.floor(Math.random() * 0x100000000).toString(36)
	}

	function _reply(raw) {
		const reply = parseJson(raw)
		return reply && typeof reply.requestId === "string" ? reply : null
	}

	// A reply is taken when its reply or its sequence changes, whichever comes last: over MQTT,
	// each path is a message of its own, and the sequence can arrive before the reply. The
	// request's id, unique to each request, says which request it answers, so each is taken once.
	property string _startReplyId
	property string _controlReplyId

	function _takeStartReply() {
		const reply = _reply(_requestReply.value)
		if (reply && reply.requestId !== _startReplyId) {
			_startReplyId = reply.requestId
			startReplied(reply.requestId, reply.result === 1, reply.error || "", reply.sessionId || "")
		}
	}

	function _takeControlReply() {
		const reply = _reply(_controlReply.value)
		if (reply && reply.requestId !== _controlReplyId) {
			_controlReplyId = reply.requestId
			controlReplied(reply.requestId, reply.result === 1, reply.error || "")
		}
	}

	readonly property VeQuickItem _request: VeQuickItem { uid: root.uid + "/Request" }
	readonly property VeQuickItem _requestReply: VeQuickItem {
		uid: root.uid + "/RequestReply"
		onValueChanged: root._takeStartReply()
	}
	readonly property VeQuickItem _requestSequence: VeQuickItem {
		uid: root.uid + "/RequestSequence"
		onValueChanged: root._takeStartReply()
	}
	readonly property VeQuickItem _controlRequest: VeQuickItem { uid: root.uid + "/ControlRequest" }
	readonly property VeQuickItem _controlReply: VeQuickItem {
		uid: root.uid + "/ControlReply"
		onValueChanged: root._takeControlReply()
	}
	readonly property VeQuickItem _controlSequence: VeQuickItem {
		uid: root.uid + "/ControlSequence"
		onValueChanged: root._takeControlReply()
	}
	readonly property VeQuickItem _sessionId: VeQuickItem { uid: root.uid + "/Session/Id" }
	readonly property VeQuickItem _action: VeQuickItem { uid: root.uid + "/Session/Action" }
	readonly property VeQuickItem _component: VeQuickItem { uid: root.uid + "/Session/Component" }
	readonly property VeQuickItem _state: VeQuickItem { uid: root.uid + "/Session/State" }
	readonly property VeQuickItem _review: VeQuickItem { uid: root.uid + "/Session/Review" }
	readonly property VeQuickItem _errorCode: VeQuickItem { uid: root.uid + "/Session/ErrorCode" }
	readonly property VeQuickItem _error: VeQuickItem { uid: root.uid + "/Session/Error" }
	readonly property VeQuickItem _canConfirm: VeQuickItem { uid: root.uid + "/Session/CanConfirm" }
	readonly property VeQuickItem _canCancel: VeQuickItem { uid: root.uid + "/Session/CanCancel" }
	readonly property VeQuickItem _transferReady: VeQuickItem { uid: root.uid + "/Session/Transfer/Ready" }
	readonly property VeQuickItem _capabilityRef: VeQuickItem { uid: root.uid + "/Session/Transfer/CapabilityRef" }
	readonly property VeQuickItem _expires: VeQuickItem { uid: root.uid + "/Session/Transfer/Expires" }
	readonly property VeQuickItem _fileSize: VeQuickItem { uid: root.uid + "/Session/Transfer/FileSize" }
	readonly property VeQuickItem _bytesTransferred: VeQuickItem { uid: root.uid + "/Session/Transfer/BytesTransferred" }
}

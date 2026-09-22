/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

pragma Singleton

import QtQml
import Victron.VenusOS

QtObject {
	id: root

	readonly property string serviceUid: BackendConnection.serviceUidForType("exchange")

	//% "Unable to start exchange"
	readonly property string startFailedText: qsTrId("exchangeaction_start_failed")
	//% "Exchange failed"
	readonly property string failedText: qsTrId("exchangeaction_exchange_failed")

	function newRequestId(prefix) {
		return prefix + "-" + Date.now().toString(36) + "-"
				+ Math.floor(Math.random() * 0x100000000).toString(36)
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

	function startRequest(requestId, actionId, parameters) {
		return JSON.stringify({ requestId: requestId, action: actionId, parameters: parameters })
	}

	function controlRequest(requestId, sessionId, command) {
		return JSON.stringify({ requestId: requestId, sessionId: sessionId, command: command })
	}

	function errorCodeToText(value) {
		switch (value) {
		case 0: return ""
		//% "Busy"
		case 100: return qsTrId("exchange_error_busy")
		//% "Invalid state"
		case 101: return qsTrId("exchange_error_invalid_state")
		case 102:
		//% "Invalid request"
		case 103: return qsTrId("exchange_error_invalid_request")
		//% "Request too large"
		case 104: return qsTrId("exchange_error_request_too_large")
		//% "Session mismatch"
		case 106: return qsTrId("exchange_error_session_mismatch")
		//% "Unsupported command"
		case 107: return qsTrId("exchange_error_unsupported_command")
		//% "Unknown action"
		case 108: return qsTrId("exchange_error_unknown_action")
		//% "Action unavailable"
		case 109: return qsTrId("exchange_error_action_unavailable")
		case 200:
		//% "Upload link invalid"
		case 201: return qsTrId("exchange_error_invalid_capability")
		//% "Expired"
		case 202: return qsTrId("exchange_error_expired")
		//% "Upload size unknown"
		case 203: return qsTrId("exchange_error_length_required")
		//% "File too large"
		case 204: return qsTrId("exchange_error_too_large")
		//% "Upload interrupted"
		case 205: return qsTrId("exchange_error_incomplete_body")
		//% "Upload range invalid"
		case 206: return qsTrId("exchange_error_range_invalid")
		//% "Upload retry limit reached"
		case 207: return qsTrId("exchange_error_retry_exhausted")
		//% "File encoding invalid"
		case 300: return qsTrId("exchange_error_invalid_utf8")
		//% "File format invalid"
		case 301: return qsTrId("exchange_error_invalid_json")
		//% "Unsupported file type"
		case 302: return qsTrId("exchange_error_invalid_family")
		//% "Name missing"
		case 303: return qsTrId("exchange_error_missing_name")
		//% "File structure unsafe"
		case 304: return qsTrId("exchange_error_unsafe_structure")
		//% "Validation failed"
		case 305: return qsTrId("exchange_error_validation_failed")
		//% "Invalid parameters"
		case 306: return qsTrId("exchange_error_invalid_parameters")
		//% "Temporarily unavailable"
		case 400: return qsTrId("exchange_error_backend_unavailable")
		//% "Rejected"
		case 401: return qsTrId("exchange_error_backend_rejected")
		//% "Timed out"
		case 402: return qsTrId("exchange_error_backend_timeout")
		//% "Result unknown"
		case 403: return qsTrId("exchange_error_result_unknown")
		//% "Authorization unavailable"
		case 404: return qsTrId("exchange_error_authorization_unavailable")
		//% "Not authorized"
		case 405: return qsTrId("exchange_error_authorization_denied")
		//% "Not enough storage"
		case 500: return qsTrId("exchange_error_no_space")
		//% "Storage reservation failed"
		case 501: return qsTrId("exchange_error_temporary_reservation_failed")
		//% "Storage error"
		case 502: return qsTrId("exchange_error_io_error")
		//% "Interrupted by a restart"
		case 503: return qsTrId("exchange_error_recovery_failed")
		//% "Cleanup failed"
		case 504: return qsTrId("exchange_error_cleanup_failed")
		//% "Unexpected error"
		case 505: return qsTrId("exchange_error_internal")
		//% "Not enough temporary storage"
		case 506: return qsTrId("exchange_error_insufficient_temporary_storage")
		default: return ""
		}
	}

	function errorSummaryText(errorCodeValue, text) {
		const label = root.errorCodeToText(errorCodeValue)
		const detail = text ? String(text).trim() : ""
		if (label && detail) {
			return label + ": " + detail
		}
		return label || detail
	}
}

/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

pragma Singleton

import QtQml
import Victron.VenusOS

/*
	Shared text for the venus-exchange integration (container import, web
	page upload, partner branding install/remove). Numeric values match
	docs/error-reporting.md's ErrorCode table in the venus-exchange repo
	exactly (venus_exchange/exchange_api_v1.py).
*/
QtObject {
	id: root

	// ErrorCode - a short, specific label for the failure category. The
	// action-specific title (e.g. "Container could not be imported") says
	// what failed; this says why, so both are shown together rather than
	// choosing one (docs/error-reporting.md's "User-facing presentation").
	function errorCodeToText(value) {
		switch (value) {
		case 0: return ""
		//% "Busy"
		case 100: return qsTrId("exchange_error_busy")
		//% "Invalid state"
		case 101: return qsTrId("exchange_error_invalid_state")
		//% "Invalid request"
		case 102: return qsTrId("exchange_error_invalid_request")
		//% "Invalid request"
		case 103: return qsTrId("exchange_error_invalid_request")
		//% "Request too large"
		case 104: return qsTrId("exchange_error_request_too_large")
		//% "Conflicting request"
		case 105: return qsTrId("exchange_error_request_id_conflict")
		//% "Session mismatch"
		case 106: return qsTrId("exchange_error_session_mismatch")
		//% "Unsupported command"
		case 107: return qsTrId("exchange_error_unsupported_command")
		//% "Unknown action"
		case 108: return qsTrId("exchange_error_unknown_action")
		//% "Action unavailable"
		case 109: return qsTrId("exchange_error_action_unavailable")
		//% "Too many recent requests"
		case 110: return qsTrId("exchange_error_replay_ledger_full")
		//% "Upload link invalid"
		case 200: return qsTrId("exchange_error_invalid_capability")
		//% "Upload link invalid"
		case 201: return qsTrId("exchange_error_invalid_capability")
		//% "Upload link expired"
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
		//% "Recovery failed"
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

	// Combines the category label with the backend's own safe /Error text.
	// /Error is already a single bounded, sanitized line under the API-v1
	// contract (unlike a raw child-process capture), so it is used as-is.
	function errorSummaryText(errorCodeValue, text) {
		const label = root.errorCodeToText(errorCodeValue)
		const detail = text ? String(text).trim() : ""
		if (label && detail) {
			return label + ": " + detail
		}
		return label || detail
	}
}

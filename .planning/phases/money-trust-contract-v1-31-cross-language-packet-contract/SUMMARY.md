# Phase 31 — Summary

## Changed

- Added `test_mobile_allowed_fact_ids_match_backend_sanitizer_allowlist`.

## Result

The backend test suite now fails if Dart `allowedFactIds` and Python `_ALLOWED_IDS` diverge.

## Notes

This intentionally compares fact IDs only. Values, domains, and paths remain covered by the fixture and sanitizer tests without snapshotting the full mobile object ordering.

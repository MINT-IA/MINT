// ────────────────────────────────────────────────────────────
//  RouteHealthJsonContract — Phase 32 MAP-03 (schema v1)
// ────────────────────────────────────────────────────────────
//
// JSON contract for `./tools/mint-routes health --json`.
//
// **Consumer contract:** Phase 35 dogfood `tools/dogfood/mint-dogfood.sh`
// parses the newline-delimited JSON and greps for `"status":"red"` or
// `"status":"dead"`. Any breaking change MUST bump
// [kRouteHealthSchemaVersion] AND
// `tools/mint_routes/__init__.py::__schema_version__` in lockstep — the
// pytest drift check `test_json_output_schema_matches_dart_contract`
// asserts parity via version equality.
//
// Example line (one entry per route, newline-delimited):
//
//     {"path": "/coach", "category": "destination", "owner": "coach",
//      "requires_auth": true, "kill_flag": "enableCoachChat",
//      "status": "green", "sentry_count_24h": 3, "ff_enabled": true,
//      "last_visit_iso": "2026-04-20T03:14:00Z",
//      "_redaction_applied": true, "_redaction_version": 1}
//
// All string keys sorted (`json.dumps(..., sort_keys=True)`) for
// byte-stable output across Python 3.x minor versions.

library;

/// Byte-stable schema version. Bump on ANY breaking change to the JSON shape
/// (field renames, type changes, removed fields). Additive changes (new
/// optional fields) MAY reuse the same version until a consumer breaks.
///
/// Must equal
/// `tools/mint_routes/__init__.py::__schema_version__` (pytest drift check
/// enforces parity).
const int kRouteHealthSchemaVersion = 1;

/// Documented keys (for reference by Dart consumers — Phase 35 dogfood,
/// Phase 33 kill-flag UI):
///
/// - `path` (String)              — GoRoute path, matches `kRouteRegistry` key
/// - `category` (String)          — RouteCategory.name
/// - `owner` (String)             — RouteOwner.name
/// - `requires_auth` (bool)       — from RouteMeta.requiresAuth
/// - `kill_flag` (String?)        — from RouteMeta.killFlag (null if infra)
/// - `status` (String)            — one of: green, yellow, red, dead
/// - `sentry_count_24h` (int)     — Sentry Issues API 24h error count
/// - `ff_enabled` (bool)          — FeatureFlags local state at query time
/// - `last_visit_iso` (String?)   — ISO 8601 last-seen timestamp or null
/// - `_redaction_applied` (bool)  — always true in Phase 32 (nLPD D-09 §2)
/// - `_redaction_version` (int)   — matches the Python redaction pipeline
///                                  version (currently 1)
///
/// The class is intentionally empty — its only role is to make the contract
/// importable (so consumer tests can `import 'route_health_schema.dart';`
/// and assert `kRouteHealthSchemaVersion == 1` without pulling in
/// implementation concerns).
class RouteHealthJsonContract {
  const RouteHealthJsonContract._();
}

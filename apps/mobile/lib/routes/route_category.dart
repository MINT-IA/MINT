// ────────────────────────────────────────────────────────────
//  Route Category — Phase 32 MAP-01 taxonomy (D-01 locked v4)
// ────────────────────────────────────────────────────────────
//
// Categorical slot on [RouteMeta]. Four values:
//
// - `destination`: terminal screen the user lands on (e.g. `/home`,
//   `/coach`, `/retraite`).
// - `flow`: multi-step sequence, typically auth/onboarding/scan
//   (e.g. `/auth/register`, `/scan/capture`).
// - `tool`: utility / admin surface (e.g. `/admin/routes`, `/debug/*`).
// - `alias`: pure redirect target — the path itself only exists to
//   forward to another path (MAP-05 scope).

enum RouteCategory {
  destination,
  flow,
  tool,
  alias,
}

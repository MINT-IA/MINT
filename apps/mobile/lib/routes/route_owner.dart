// ────────────────────────────────────────────────────────────
//  Route Owner — Phase 32 MAP-01 ownership taxonomy (D-01 v4)
// ────────────────────────────────────────────────────────────
//
// Ownership bucket for every route in [kRouteRegistry]. 15 values total:
//
//   11 flag-group owners — align 1:1 with Phase 33 FLAG-05 kill-switches:
//     retraite, famille, travail, logement, fiscalite, patrimoine,
//     sante, coach, scan, budget, anonymous.
//
//   4 infra owners — no kill-flag, always reachable:
//     auth, admin, system, explore.
//
// Ambiguity rule (D-01 v4, locked): **first path segment wins.**
//
//   `/explore/retraite`         -> owner = `explore` (NOT `retraite`)
//   `/coach/chat/from-budget`   -> owner = `coach`   (NOT `budget`)
//   `/retraite`                 -> owner = `retraite`
//
// When the first path segment does not match one of the 15 values
// (e.g. `/debt/*`, `/mortgage/*`, `/arbitrage/*`, `/life-event/*`,
// `/simulator/*`, `/independants/*`, `/disability/*`, `/lpp-deep/*`,
// `/3a-deep/*`, `/education/*`, `/assurances/*`, `/segments/*`,
// `/documents/*`, `/document-scan/*`), the owner falls back to
// `RouteOwner.system` per Plan 32-01 Task 2 action block. These
// segments are intentionally NOT promoted to first-class enum values —
// Phase 33 FLAG-05 groups only 11 domains; the rest are infra.

enum RouteOwner {
  // 11 flag-group owners (Phase 33 FLAG-05)
  retraite,
  famille,
  travail,
  logement,
  fiscalite,
  patrimoine,
  sante,
  coach,
  scan,
  budget,
  anonymous,
  // 4 infra owners (no kill-flag, always reachable)
  auth,
  admin,
  system,
  explore,
}

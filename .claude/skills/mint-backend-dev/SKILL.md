---
name: mint-backend-dev
description: Compatibility mirror. Canonical skill lives at .agents/skills/mint-backend-dev/SKILL.md.
---

# Mirror

Read `../../../.agents/skills/mint-backend-dev/SKILL.md`.

If this file diverges from `.agents/skills/mint-backend-dev/SKILL.md`, the
`.agents` file wins.

Backend work routes through `mint-backend` + `mint-quality-gate` by default.
External specialists require a named gap; no vendor agent catalog is checked in.

<!-- mint-data-architecture-v1-01-canonical:start -->
## Calc-engine ownership — L2-L4 backend-canonical (D-01..D-04, D-11)

`services/backend/app/services/` is the L2 comparer + L3 éclairer + L4 invariants canonical home — projection-class outputs with `constants_version_hash` audit trail, backend-canonical per Phase `mint-data-architecture-v1-01-calc-engine-canonical`. Boundary criterion = `services/backend/app/models/lucidity/_payload.py` discriminated type (L2ComparePayload / L3EclairePayload / L4InvariantPayload → backend ; L1ChiffrePayload → mobile).

### Regulatory source of truth

`services/backend/app/services/regulatory/registry.py` — `RegulatoryParameter` with `effective_from` / `effective_to` + active-version selection. Plan 03 exposes this via 2 endpoints :

- `GET /v1/regulatory/constants/version` — lightweight   `{active_version_hash, effective_from, last_updated}` for delta-check.
- `GET /v1/regulatory/constants/snapshot` — full 26-canton snapshot for the   Plan 04 build-time codegen consumer.

### Migration sequencing (D-CE-09 strangler-fig + D-CE-10 deprecation-shim)

Per-domain PRs (LPP, taxes, AVS, succession, divorce, frontalier …), each shipping :

1. Backend implementation of the migrated calc.
2. Mobile thin-client wrapper replacing the previous Dart implementation.
3. `@Deprecated` annotation on the old Dart class (1-release retention).
4. Parity test (mobile-wrapper vs backend output diff for a fixed scenario set).

Order : Monte Carlo + tornado sensitivity migrate FIRST (D-11 — highest LSFin audit risk, lowest UX coupling), then arbitrage engine, then withdrawal sequencing, then remaining L2+ calcs.

### Server-PRIMARY enforcement (D-CE-06)

All migrated L2-L4 calcs land in `services/backend/app/api/v1/endpoints/` with `Depends(get_profile_filled)` — the server is the PRIMARY enforcement layer for LSFin banned-terms + nLPD scrubbing ; mobile thin clients are presentation only, never re-implement calculator logic across the L1/L2 boundary.

<!-- mint-data-architecture-v1-01-canonical:end -->

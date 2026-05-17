---
description: Phase mint-data-architecture-v1-01-calc-engine-canonical — resolves the upstream calc-engine ownership conflict (apps/mobile/lib/services/financial_core/ vs services/backend/app/services/) gated as a prerequisite by [decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md §"Calc-engine integration"]. Locks 16 decisions across 4 areas: (1) split-with-arbiter L1 mobile + L2-L4 backend along the lucidité L1-L4 typology, with confidence/Bayesian/coach-reasoner staying mobile and Monte Carlo + tornado + withdrawal-seq + arbitrage migrating backend; (2) offline-first reconciliation with local-compute + last-known-constants + 7d soft / 30d hard staleness window; (3) per-domain strangler-fig PR sequence honouring D-CE-09/D-CE-10, Monte Carlo migrating first; (4) constants sync via build-time Dart codegen from `/v1/regulatory/constants/snapshot` + runtime delta-check on app launch, all 26 cantons baked, MINT-doctrinal constants (safeWithdrawalRate, expected returns, mortality tables) stay Dart-side with their own version field. Doctrine rewrite (CLAUDE.md triplet #3 + docs/AGENTS/backend.md:39 + docs/AGENTS/flutter.md) lands in same PR as Phase 01 CONTEXT.md merge.
---

# Phase mint-data-architecture-v1-01-calc-engine-canonical — Context

**Gathered:** 2026-05-17
**Status:** Ready for planning
**Source of decisions:** discuss-phase 2026-05-17 (Julien × Claude, 16/16 recommended options confirmed)
**Upstream artifacts:**
- [.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md](../../decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md) (panel ADR — Proposed status, this phase resolves its prerequisite)
- [.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md](../mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md) (20 D-CE-XX LOCKED decisions; this phase MUST NOT undo any of them)

## TLDR

The mobile financial_core (10 279 LOC, 17 .dart files) and the backend services (76 directories) both ship today and both claim source-of-truth in conflicting doctrine (CLAUDE.md triplet #3 says mobile; docs/AGENTS/backend.md:39 says backend). The panel ADR proposes event-log + projection + DEK envelope for downstream phases but flags this conflict as the upstream blocker.

This phase resolves the conflict via a **split-with-explicit-arbiter** along the existing `mint-calc-engine-v1` L1-L4 lucidité typology. Mobile owns L1 chiffrer (deterministic single-number outputs from profile + constants, offline-capable). Backend owns L2 comparer + L3 éclairer + L4 invariants (multi-scenario, sensitivity, citation grammar, audit trail). Non-regulatory mobile code (Bayesian enricher, confidence scorer, coach reasoner) stays mobile because it is UX-bound and produces no LSFin output. Monte Carlo + tornado sensitivity + withdrawal sequencing + arbitrage engine migrate backend because they produce projection-class outputs requiring `constants_version_hash` audit trail.

Offline-first L1 is preserved via build-time Dart codegen of the active `RegulatoryParameter` snapshot baked into the Flutter bundle, with runtime delta-check on app launch. All 26 cantons are baked. Soft warn at 7 days of staleness, hard refuse at 30 days. L2-L4 surfaces show last cached projection when offline with explicit staleness chip + manual refresh action — no shadow implementation on mobile.

Migration follows D-CE-09 strangler-fig: per-domain PRs (Monte Carlo + sensitivity first), each shipping backend implementation + mobile thin-client wrapper + 1-release deprecation banner + parity test (mobile vs backend output diff), then deletion. The Concern C parity lint (`tools/checks/profile_safe_fields_parity.py`) extends to cover constants drift in the same PR as the first migration.

Phase 01 ships the decision artifact + doctrine rewrite + ADR finalisation. The downstream Phase 02 (event-log + projection schema migration) and Phase 03 (coach-extractor LLM guardrails) get declared in ROADMAP only after this phase merges.

## Counter-arguments and data gaps

### Strongest opposing view

Steel-man for backend-canonical full-stack (no L1 split):

> *« A split is just two systems to maintain. The 'offline L1' rationale is romantic: most users open MINT with cell service; a 'reconnect for live values' banner on the rare offline session is acceptable. Splitting along L1-L4 means every new calc requires a routing decision and the boundary will drift. The constants-sync codegen is real engineering work (CI pipeline + parity lint + Dart generated file) that adds tax to every regulatory update. A clean backend-canonical (delete the 10 279 LOC mobile financial_core over 4-6 PRs) eliminates the parity lint entirely, makes the audit trail trivially server-side, and matches the downstream event-log + projection shape without any caveats. The split keeps an architectural conflict alive instead of resolving it. »*

This argument carries non-trivial weight. The mitigation is that **L1 chiffrer is the first user-value MINT delivers** (a 3a max number, an AVS rente estimate, a "your LPP balance is X" widget) and these surfaces are scattered across the home / chat / cards UI where a 200ms network round-trip per render is a UX regression. The split is not "two systems to maintain" — it is "one system per layer", and the layers were already defined by `mint-calc-engine-v1` D-CE-15 typed payloads (`L1ChiffrePayload`, `L2ComparePayload`, etc.). The L1/L2 boundary criterion is structural (lucidité layer = data payload type), not a soft judgment call. Re-litigation triggers below cover the cases where this should be reconsidered.

Steel-man for delete-everything mobile + accept network dependency:

> *« Modern Swiss connectivity is good enough. Plane mode + subway + cabin-in-the-mountains are vanishingly rare for the actual MINT cohort (urban Suisse 25-65, smartphone-native). Optimising for the 1% offline session compromises the 99% online architecture. »*

Counter: telemetry to validate the 99/1 split does not exist. Until it does, the offline-first L1 posture is a hedge against an empirically open question. Phase 01 plan should include a baseline telemetry plug (mint_offline_session_total counter) so the next phase has data to argue from.

### What this discussion did NOT address

- **No latency benchmark** of `/v1/regulatory/constants/snapshot` from cold-start (CDN-cacheable response? service-worker eligible? what's the realistic snapshot size in KB once all 26 cantons + brackets are serialised?). Phase 01 plan must establish a baseline before locking the contract.
- **No telemetry today** for mobile offline-session rate, mobile L1-only-session rate, or constants-staleness-at-render-time. Phase 01 plan ships these counters so the next phase can validate the offline-first hypothesis with data instead of intuition.
- **Bundle-size impact** of baking all 26 cantons not measured. Plan must include an upper bound (e.g., <100 KB compressed) and a fallback path if exceeded.
- **CI staging dependency** — pre-build codegen step (Q4.4) requires staging to be up at every Flutter build. If staging is down, builds break. Plan must specify failure mode (cached fixture? skip + warn?).
- **Constants-version-hash semantics** at audit time: when a constant changes, are historical projections re-validated against the new active version, or treated as point-in-time? Touched in the ADR §"What does this source not address?" — Phase 02 will need to lock this; Phase 01 plan only needs to ensure `constants_version_hash` is captured at write time so Phase 02 has the data.
- **MINT-doctrinal constants** (`safeWithdrawalRate = 4%`, expected return assumptions, mortality tables) explicitly stay Dart-side with their own version field — but the "own version field" semantic is not yet defined. Plan must specify: where does `MINT_DOCTRINAL_CONSTANTS_VERSION` live, and how does CI lint detect drift between mobile and backend if both sides reference these?
- **Reconciliation with the 8 deferred operational gates** from `mint-calc-engine-v1` SUMMARY (G2 Julien device sign-off + 7 follow-ups). Are any of them in the critical path for Phase 01? Plan must explicitly answer.

### What would change this conclusion

- **Offline-session telemetry (post-launch)** shows <2% of MINT sessions touch L1 offline. → revisit the split; consider full backend-canonical.
- **Bundle-size measurement** shows the 26-canton snapshot exceeds 200 KB compressed. → revisit Q4.2 (consider lazy-loaded per-canton fetches).
- **Phase 02 event-log + projection planning** surfaces an audit constraint that the split breaks (e.g., LSFin auditor explicitly requires a single regulatory snapshot source-of-truth that mobile cannot satisfy). → revisit Q1.1; tighten to backend-only.
- **FINMA publishes guidance** that offline-computed financial figures must carry stronger staleness disclosure than a chip can deliver. → revisit Q2.1 + Q2.3; tighten the offline UX.
- **Cleo, RightCapital, or another reference fintech publishes a post-mortem** of an offline-first L1 split that converged toward fully online. → revisit the entire split with their evidence on the table.

<domain>
## Phase Boundary

**This phase delivers** a locked, doctrinally consistent answer to the calc-engine ownership question: where does the calculator LOGIC canonically live, what is the L1/L2 boundary criterion, what does the strangler-fig migration look like, and how do regulatory constants flow from backend to mobile. The phase output is (1) this CONTEXT.md, (2) a doctrine-rewrite PR (CLAUDE.md + docs/AGENTS/backend.md + docs/AGENTS/flutter.md), (3) flipping the upstream ADR `decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md` from `status: Proposed` to `status: Decided` for the calc-engine portion, and (4) clearing the prerequisite that gates Phase 02 (event-log + projection schema migration) and Phase 03 (coach-extractor LLM guardrails).

**The phase does NOT:**
- Migrate any calculator code (that is Phase 02+ strangler-fig PRs).
- Migrate the data layer to event-log + projection + DEK envelope (Phase 02).
- Change coach inference extraction (Phase 03).
- Add new calculators or new financial domains.
- Touch the 8 deferred operational gates from `mint-calc-engine-v1` (G2 Julien device sign-off + Plan 09/11/16/17/19 follow-ups) — those are tracked separately and are NOT prerequisites for Phase 01 ship.
- Reopen any of the 20 LOCKED D-CE-XX decisions from `mint-calc-engine-v1`. In particular: D-CE-06 (server is PRIMARY enforcement), D-CE-09 (strangler-fig no-big-bang), D-CE-10 (deprecation-shim pattern), D-CE-15 (typed L1-L4 payloads), D-CE-16 (triple defense banned-verbs) all remain in force and constrain Phase 01.
- Spec the actual migration PRs (those are planned by the per-domain strangler-fig PR sequence; Phase 01 only LOCKS the sequencing rule and the first-migration target).

</domain>

<decisions>
## Implementation Decisions (LOCKED)

The 16 decisions are grouped by the 4 gray areas discussed.

### Area 1 — Canonical home

- **D-01:** Calculator LOGIC canonical home is **split-with-explicit-arbiter** along the `mint-calc-engine-v1` L1-L4 lucidité typology. Mobile owns L1 chiffrer (deterministic single-number outputs from profile + constants, offline-capable). Backend owns L2 comparer + L3 éclairer + L4 invariants (multi-scenario, sensitivity, citation grammar, audit trail). The ADR's "backend-canonical" assumption is REFINED to "L2-L4 backend-canonical, L1 mobile-canonical".

- **D-02:** The L1/L2 boundary criterion is the **lucidité layer typology** as already typed in `services/backend/app/models/lucidity/_payload.py`. A calc that returns a `L1ChiffrePayload` lives mobile; anything returning `L2ComparePayload` / `L3EclairePayload` / `L4InvariantPayload` lives backend. New calcs declare their lucidité layer at definition time; the boundary is structural, not judgmental.

- **D-03:** Non-regulatory mobile financial code splits as follows. **Stays mobile** (UX-bound, no LSFin output): `confidence_scorer.dart`, `bayesian_enricher.dart`, `coach_reasoner.dart`. **Migrates backend** (projection-class, audit-trail required): `monte_carlo_service.dart`, `tornado_sensitivity_service.dart`, `withdrawal_sequencing_service.dart`, `arbitrage_engine.dart`. The L1-vs-L2 typology is the audit: anything emitting a multi-scenario / sensitivity / arbitrage / Monte Carlo distribution is L2-or-higher and migrates; anything emitting a confidence score / Bayesian posterior / UX-orchestration decision is non-regulatory and stays.

- **D-04:** Doctrine rewrite (CLAUDE.md triplet #3 + docs/AGENTS/backend.md:39 + docs/AGENTS/flutter.md + `.claude/skills/mint-flutter-dev/SKILL.md` + `.claude/skills/mint-backend-dev/SKILL.md`) lands in the **same PR** as Phase 01 CONTEXT.md merge. The rewrite must explicitly name the L1/L2 split, the L1-L4 typology as the boundary criterion, and the staying-mobile vs migrating-backend lists from D-03. Without this, every subagent invocation post-merge reads stale doctrine and could silently fight the new architecture.

### Area 2 — Offline-first reconciliation

- **D-05:** Mobile L1 computes locally using the last-known constants snapshot baked into the bundle. When the device is offline, a subtle "offline — valeurs au [date]" chip surfaces next to the L1 result. Reason: USER-VALUE preserved (the number is correct as of last sync) + 0-trust audit chain stays intact (we know which snapshot was used).

- **D-06:** L2-L4 surfaces (Monte Carlo, sensitivity, arbitrage, comparer/éclairer payloads) when offline show the last cached projection from `SnapshotModel` for this `(profile_id, kind, inputs_hash)` with a "projection au [date]" chip + a manual "mettre à jour" refresh action. No shadow implementation on mobile; no optimistic local recompute. If no cached projection exists for this surface, render an "analyse non disponible hors-ligne" state. This aligns with the existing `mint-calc-engine-v1` cache-reader pattern (Concern E).

- **D-07:** Mobile L1 constants-staleness UX is **soft warn at 7 days, hard refuse at 30 days**. Days 0-7: silent (constants are fresh). Days 7-30: chip "valeurs au [date]" visible on every L1 widget. Day 30+: L1 refuses to render a number and the screen asks for one online session to refresh. Rationale: 7d covers typical offline streaks (vacation, mountain, EU roaming-off), 30d aligns with AVS / 3a calendar update cadence for legal changes.

- **D-08:** Constants sync mechanism is **build-time codegen + runtime delta-check on app launch**. Every Flutter build bakes the active `RegulatoryParameter` snapshot into the bundle via codegen (D-15 below). On app launch (network-permitting), a lightweight `GET /v1/regulatory/constants/version` returns `{active_version_hash, effective_from}`. Mismatch with the bundle's baked hash → fetch full snapshot from `/v1/regulatory/constants/snapshot` and persist to local cache. The local cache + the baked snapshot together feed the L1 calc; the cache wins if its hash is newer.

### Area 3 — Migration sequencing (D-CE-09 strangler-fig)

- **D-09:** Migration PRs are **partitioned by domain** (LPP, taxes, AVS, succession, divorce, frontalier, etc.) rather than by UI surface. Each PR ships (a) backend implementation of the migrated calc, (b) mobile thin-client wrapper replacing the previous Dart implementation, (c) `@Deprecated` annotation on the old Dart class per D-CE-10 shim pattern, (d) parity test (mobile-wrapper vs backend output diff for a fixed scenario set). Reason: matches `mint-calc-engine-v1`'s per-domain panel pattern + reviewable surface (one PR = one mental model).

- **D-10:** Mobile-side shim policy per migration: mobile keeps the thin client wrapper that calls the backend for **1 release**, with a deprecation banner, then is deleted in the next release. Hard cut is REJECTED (no rollback path if the backend has a bug discovered post-merge). Indefinite mobile shadow is REJECTED (conflicts with D-06 "no shadow implementation" + doubles maintenance).

- **D-11:** Migration priority order: **Monte Carlo + tornado sensitivity migrate FIRST**. Reason: highest LSFin audit risk (projections with `constants_version_hash` + `scenario_inputs_hash` audit-trail requirement), lowest UX coupling (consumed as "analysis" surfaces, not live form widgets — network round-trip per use is acceptable). After Monte Carlo + sensitivity ship, follow with arbitrage engine, then withdrawal sequencing, then any remaining L2+ calc. Order is reviewable + adjustable in Phase 02 plan; the rule is "start with highest-audit-risk, lowest-UX-coupling".

- **D-12:** The Concern C parity lint (`tools/checks/profile_safe_fields_parity.py`) extends to cover constants drift detection in the **same PR as the first migration** (Monte Carlo, per D-11). The extension reads the baked Dart constants from `apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart` and diffs against the active backend `RegulatoryParameter` snapshot via `services/backend/app/services/regulatory/registry.py:get_active_snapshot()`. CI gate + lefthook hook. Reason: proves the parity contract end-to-end on the first real migration before generalising; mirrors the existing pattern for `_PROFILE_SAFE_FIELDS`.

### Area 4 — Sync direction + transport for constants

- **D-13:** Constants sync payload scope is **LSFin-touched + canton-varied regulatory values only**. Synced: 3a max, plafond LPP, AVS rentes (min/max/median), LIFD capital-withdrawal brackets, wealth_tax brackets per canton, succession brackets per canton, allocations familiales per canton, LAMal franchise floors. **NOT synced** (stay Dart-side with their own version field): `safeWithdrawalRate = 4%`, expected return assumptions, mortality tables, MINT-doctrinal heuristics. Reason: clean line between "government truth" (synced, regulatory-audit-trail) and "MINT-set assumption" (versioned in repo, doctrinal-audit-trail).

- **D-14:** Per-canton handling **bakes all 26 cantons** into the mobile bundle (offline-capable for any canton, including cross-canton simulation by the 8-archetype routing — e.g., frontalier from FR simulating GE taxes). Estimated bundle impact +30-80 KB compressed; the planner must validate the upper bound before locking. If the compressed snapshot exceeds 100 KB, revisit and consider lazy per-canton fetch with a per-canton on-disk cache.

- **D-15:** Backend→mobile sync endpoint contract uses two endpoints: `GET /v1/regulatory/constants/version` returns `{active_version_hash, effective_from, last_updated}` (lightweight delta-check, ~200 bytes); `GET /v1/regulatory/constants/snapshot` returns the full active `RegulatoryParameter` set as JSON (the full 26-canton snapshot). Mobile delta-checks on launch; if hash differs, fetches the full snapshot. ETag-friendly. No incremental-diff endpoint (over-engineered for the ~100s-of-KB total).

- **D-16:** Build-time codegen source is a CI pre-build script `tools/codegen/regulatory_constants_to_dart.py` that fetches `GET /v1/regulatory/constants/snapshot` from **staging** and writes a generated Dart file `apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart`, which is **committed** to git for reproducible builds and git-blame audit trail. A pre-commit lefthook hook re-runs the script when the active version on staging differs from the committed file's baked hash. Reason: deterministic + reviewable + matches the `_registry.py` AUTO-GENERATED pattern from `mint-calc-engine-v1` Plan 05. CI failure mode (staging down at build time): fall back to the committed fixture + emit a soft-warn (do NOT block builds); planner specifies exact failure-mode handling.

### Claude's Discretion

The following are NOT user-specified but flow from the 16 LOCKED decisions and are at the planner's discretion to refine:

- Exact bundle-size validation methodology for D-14 (compressed vs uncompressed, profiling tool, threshold ceremonies).
- Exact failure-mode wording for D-16 CI staging-down case (soft-warn message format, Sentry breadcrumb, etc.).
- Sentry / observability hooks for delta-check failures + offline-session detection (telemetry counters listed in the data gaps section above as planner deliverables).
- Test strategy for parity (D-12) — fixture-driven (current pattern) vs property-based (richer coverage). Default to fixture-driven matching existing `mint-calc-engine-v1` patterns.
- Feature-flag rollout sequence for the first migration (D-11 Monte Carlo). Default: feature flag `monte_carlo_backend_canonical` shipped OFF, flipped per-environment (staging → production) over 1 release after parity tests prove green; killswitch hook present at all times.
- Whether the `MINT_DOCTRINAL_CONSTANTS_VERSION` field (D-13 implication) lives in `pubspec.yaml`, a generated `lib/version/doctrinal_constants_version.g.dart`, or a `.dart` constant. Default: a separate generated file mirroring the `regulatory_constants.g.dart` pattern.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing Phase 01.**

### Upstream decisions (the gate)
- [.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md](../../decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md) — panel ADR, Proposed status. Phase 01 RESOLVES the calc-engine portion → flips to Decided in the doctrine-rewrite PR per D-04.
- [.planning/decisions/2026-05-06-personal-financial-wiki-v3-candidate.md](../../decisions/2026-05-06-personal-financial-wiki-v3-candidate.md) — superseded wiki framing; historical context only.
- [.planning/decisions/2026-05-16-calc-engine-matrix.md](../../decisions/2026-05-16-calc-engine-matrix.md) — 11-category matrix + 4-level lucidité framework (the `mint-calc-engine-v1` upstream).
- [.planning/decisions/2026-05-16-calc-engine-v1-panel-synthesis.md](../../decisions/2026-05-16-calc-engine-v1-panel-synthesis.md) — 20 D-CE-XX verdicts + 11 overrides + 6 critical findings (LOCKED doctrine Phase 01 must not undo).

### Prior phase artifacts (LOCKED, do not re-litigate)
- [.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md](../mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md) — 20 D-CE-XX decisions; especially D-CE-06 (server-PRIMARY enforcement), D-CE-09 (strangler-fig no-big-bang), D-CE-10 (deprecation-shim pattern), D-CE-15 (typed L1-L4 payloads), D-CE-16 (triple defense).
- [.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-SUMMARY.md](../mint-calc-engine-v1/mint-calc-engine-v1-SUMMARY.md) — what shipped + 8 deferred items + Concern C parity lint.
- [.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VERIFICATION-REPORT.html](../mint-calc-engine-v1/mint-calc-engine-v1-VERIFICATION-REPORT.html) — 5-gate exit panel + per-wave rollup.
- [.planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md](../mint-calc-engine-v1/W0-AUDIT-MATRIX.md) — 49/57 hypothesis C confirmed + 12 sev-3 + 23 sev-2 (the audit basis Phase 02 will inherit).

### Mobile financial_core (10 279 LOC across 17 .dart files)
- [apps/mobile/lib/services/financial_core/](../../../apps/mobile/lib/services/financial_core/) — root.
- [apps/mobile/lib/services/financial_core/lpp_calculator.dart](../../../apps/mobile/lib/services/financial_core/lpp_calculator.dart) — `safeWithdrawalRate = 0.04`, `survivorSpouseRate = 0.60` (MINT-doctrinal constants per D-13).
- [apps/mobile/lib/services/financial_core/tax_calculator.dart](../../../apps/mobile/lib/services/financial_core/tax_calculator.dart) — 491 LOC, candidate for L1/L2 split per D-02.
- [apps/mobile/lib/services/financial_core/avs_calculator.dart](../../../apps/mobile/lib/services/financial_core/avs_calculator.dart) — L1 chiffrer reference (stays mobile per D-01).
- [apps/mobile/lib/services/financial_core/monte_carlo_service.dart](../../../apps/mobile/lib/services/financial_core/monte_carlo_service.dart) — 619 LOC, MIGRATES backend FIRST per D-11.
- [apps/mobile/lib/services/financial_core/tornado_sensitivity_service.dart](../../../apps/mobile/lib/services/financial_core/tornado_sensitivity_service.dart) — 733 LOC, MIGRATES backend in D-11 first wave.
- [apps/mobile/lib/services/financial_core/withdrawal_sequencing_service.dart](../../../apps/mobile/lib/services/financial_core/withdrawal_sequencing_service.dart) — 589 LOC, MIGRATES backend after Monte Carlo + sensitivity.
- [apps/mobile/lib/services/financial_core/arbitrage_engine.dart](../../../apps/mobile/lib/services/financial_core/arbitrage_engine.dart) — MIGRATES backend after Monte Carlo + sensitivity.
- [apps/mobile/lib/services/financial_core/confidence_scorer.dart](../../../apps/mobile/lib/services/financial_core/confidence_scorer.dart) — STAYS mobile per D-03 (UX-bound).
- [apps/mobile/lib/services/financial_core/bayesian_enricher.dart](../../../apps/mobile/lib/services/financial_core/bayesian_enricher.dart) — STAYS mobile per D-03.
- [apps/mobile/lib/services/financial_core/coach_reasoner.dart](../../../apps/mobile/lib/services/financial_core/coach_reasoner.dart) — STAYS mobile per D-03 (UX-orchestrator).
- [apps/mobile/lib/services/financial_core/cross_pillar_calculator.dart](../../../apps/mobile/lib/services/financial_core/cross_pillar_calculator.dart) — planner classifies per D-02 (L1-emitting → mobile, L2-emitting → backend).
- [apps/mobile/lib/services/financial_core/housing_cost_calculator.dart](../../../apps/mobile/lib/services/financial_core/housing_cost_calculator.dart) — planner classifies per D-02.
- [apps/mobile/lib/services/financial_core/fri_calculator.dart](../../../apps/mobile/lib/services/financial_core/fri_calculator.dart) — planner classifies per D-02.
- [apps/mobile/lib/services/financial_core/couple_optimizer.dart](../../../apps/mobile/lib/services/financial_core/couple_optimizer.dart) — planner classifies per D-02.

### Backend services + regulatory layer
- [services/backend/app/services/](../../../services/backend/app/services/) — 76 service directories.
- [services/backend/app/services/regulatory/registry.py](../../../services/backend/app/services/regulatory/registry.py) — `RegulatoryParameter` model, `effective_from/to`, active-version selection (the source for D-15 sync endpoints).
- [services/backend/app/services/calc/_registry.py](../../../services/backend/app/services/calc/_registry.py) — AUTO-GENERATED registry of 63 calcs across 12 domains + 146 REVERSE_DEP_MAP fields (`mint-calc-engine-v1` Plan 05 D-CE-09 strangler-fig bridge).
- [services/backend/app/models/lucidity/_payload.py](../../../services/backend/app/models/lucidity/_payload.py) — L1-L4 typed Pydantic discriminated payloads. D-02 boundary criterion lives here.
- [services/backend/app/models/coach_insight.py](../../../services/backend/app/models/coach_insight.py) — `CoachInsightRecord` (downstream Phase 03 surface; informational here).
- [services/backend/app/models/snapshot.py](../../../services/backend/app/models/snapshot.py) — `SnapshotModel` projection storage (no `constants_version_hash` today — Phase 02 will fix; D-06 uses this as the offline-cache source).
- [services/backend/app/services/dek_vault.py](../../../services/backend/app/services/dek_vault.py) — crypto-shred (downstream Phase 02; informational).
- [services/backend/app/api/v1/endpoints/coach_chat.py](../../../services/backend/app/api/v1/endpoints/coach_chat.py) — `_PROFILE_SAFE_FIELDS` canonical 45-field list at `:957`.

### Lints + tooling (the parity gates)
- [tools/checks/profile_safe_fields_parity.py](../../../tools/checks/profile_safe_fields_parity.py) — Concern C Flutter↔server parity lint (W4 Plan 19). EXTENDS per D-12 in the first migration PR to cover constants drift.
- [tools/checks/banned_terms_python.py](../../../tools/checks/banned_terms_python.py) — D-CE-16(b) lint with 11 paraphrase verbs + NFKC + zero-width strip.
- [tools/checks/accent_lint_fr.py](../../../tools/checks/accent_lint_fr.py) — 14-pattern FR accent lint.

### Doctrine (REWRITES land in same PR as Phase 01 merge per D-04)
- [CLAUDE.md](../../../CLAUDE.md) §1 (current mobile-canonical declaration triplet #3) + §5 D-07 NEVER #3 (current mobile-canonical declaration).
- [docs/AGENTS/backend.md](../../../docs/AGENTS/backend.md) §39 (current backend-canonical declaration — the conflict).
- [docs/AGENTS/flutter.md](../../../docs/AGENTS/flutter.md) — must be updated to name the L1-canonical-mobile + L2-L4-canonical-backend split.
- [.claude/skills/mint-flutter-dev/SKILL.md](../../../.claude/skills/mint-flutter-dev/SKILL.md) — must reflect the L1-only-on-mobile rule.
- [.claude/skills/mint-backend-dev/SKILL.md](../../../.claude/skills/mint-backend-dev/SKILL.md) — must reflect the L2-L4-on-backend rule.

### Engram observations (cross-session memory grounding)
- engram obs #150 — event-log + projection decision (data-architecture:user-facts:schema-pattern).
- engram obs #151 — panel compliance findings (security:compliance:data-architecture-review).
- engram obs #103 — `mint-calc-engine-v1` D-CE-01 founder refinement (vendor lock-in mitigation, ToolRegistryAdapter pattern).
- engram obs #102 — `mint-calc-engine-v1` D-CE-13 override (pre-compute in parallel with discoverability).
- engram obs #89 — Wave 1c-A3 envelope decision (CoachToolResponse predecessor; D-CE-04 references).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`services/backend/app/services/regulatory/registry.py`** — already supports `effective_from / effective_to / source_url / source_pdf_sha256` and active-version selection. Per the panel ADR, this is the source for D-15 sync endpoints. ~80% of the work for backend-side D-08 already shipped. The mobile-sync layer is the missing 20%.
- **`services/backend/app/services/calc/_registry.py`** — AUTO-GENERATED from AST scanner (Plan 05). 63 calcs + 146 REVERSE_DEP_MAP fields. The codegen pattern transfers directly to D-16 (`regulatory_constants_to_dart.py`).
- **`services/backend/app/models/lucidity/_payload.py`** — typed L1-L4 discriminated payloads already shipped (`mint-calc-engine-v1` D-CE-15). D-02 boundary criterion lives in this file; planners use the payload type to decide where a calc lives.
- **`tools/checks/profile_safe_fields_parity.py`** — Concern C parity lint pattern. The codegen → CI lint chain is proven and reusable for D-12 constants drift detection.
- **`services/backend/app/api/v1/endpoints/` 26 endpoints** with `Depends(get_profile_filled)` — the server-PRIMARY enforcement pattern (D-CE-06). All future migrated L2-L4 calcs land in this surface.
- **`apps/mobile/lib/services/financial_core/financial_core.dart`** — root facade that already exports the 17 child services. Refactoring to "L1-only mobile" means trimming this facade to only re-export L1 children.

### Established Patterns

- **AUTO-GENERATED registry** (`_registry.py` from AST scan, Plan 05) — the codegen pattern for D-16 (Dart constants from backend snapshot) mirrors this exactly.
- **Strangler-fig file-by-file consolidation** (D-CE-09) — already in force; Phase 02+ migration PRs follow the same rule with deprecation shims (D-CE-10).
- **Typed Pydantic discriminated payloads** (D-CE-15) — the L1/L2/L3/L4 split is a Pydantic discriminator; a calc declares its lucidité layer at the type level. Forms the basis of D-02.
- **CoachToolResponse V2 envelope** (D-CE-19, Plan 10) — generalised by `mint-calc-engine-v1` W2; any new migrated calc returns inside this envelope.
- **Lefthook + CI parity lints** (`profile_safe_fields_parity.py`) — the gating pattern for D-12 constants drift detection.
- **Feature-flag rollout** for risky migrations — the `mint-calc-engine-v1` `profile_grounding_strict_mode` flag (D-CE-08) is the reference pattern for D-11 Monte Carlo migration rollout.

### Integration Points

- **Where mobile L1 calls go after migration**: existing pattern is `coach_chat.py` `_dispatch_tool` → backend service; for L2-L4 migrated calcs, the Flutter layer calls the backend REST endpoint directly via the existing API client (not through chat). Planner specifies the exact Dart-side API client method.
- **Where the doctrine rewrite lands**: a single PR touching CLAUDE.md + docs/AGENTS/backend.md + docs/AGENTS/flutter.md + 2 skills. Pre-commit `tools/checks/wiki_lint.py` (Karpathy Wiki Pattern conventions) gates the merge.
- **Where the constants codegen lands at build**: a CI step in `.github/workflows/flutter-build.yml` invokes `tools/codegen/regulatory_constants_to_dart.py` before `flutter build`. Failure mode: fall back to committed fixture + Sentry warn.
- **Where the offline-cache reads from**: existing `SnapshotModel` table on the backend + a new on-device cache (SharedPreferences or sqflite) for the L1 constants snapshot. Planner picks the on-device cache mechanism.

</code_context>

<specifics>
## Specific Ideas

- **"USER-VALUE measured at 0-TRUST §9, not work-done"** — the offline-first L1 posture (D-05) is justified by the principle that the user being able to compute their 3a max on a plane is real value, while the audit trail is a downstream concern. This rationale was the deciding factor over the strongest counter-argument (full backend-canonical).
- **"Honour D-CE-09 strangler-fig"** — every migration decision (D-09, D-10, D-11) re-states the strangler-fig constraint. No big-bang, ever. Per-domain PRs, deprecation shims, parity tests.
- **"L1-L4 typology IS the boundary criterion"** — D-02 reuses an existing typed Pydantic discriminator rather than inventing a new judgment rule. The boundary is structural at the type level, not a soft judgment that drifts over time.
- **"MINT-doctrinal constants are NOT regulatory constants"** — D-13's split explicitly separates `safeWithdrawalRate = 4%` (MINT chose this) from `plafond 3a` (Confederation chose this). Two version fields, two audit trails. This is non-obvious and easy to confuse without the explicit rule.
- **Doctrine rewrite in the same PR as CONTEXT.md merge (D-04)** — Julien's strongest preference. The risk of agents reading stale CLAUDE.md after the decision lands is unacceptably high.

</specifics>

<deferred>
## Deferred Ideas

The following surfaced during discussion and are explicitly out of scope for Phase 01. They will be revisited in later phases or backlog as noted.

### To downstream phases (Phase 02 / Phase 03)
- **Event-log + projection schema migration** — Phase 02. Phase 01 only locks the calc-engine ownership prerequisite.
- **DEK envelope + crypto-shred wiring** — Phase 02 (security-auditor surfaced the existing `DEKVault` infrastructure).
- **`SnapshotModel.constants_version_hash`** — already addressed by the hot-fix branch `hotfix/compliance-2026-05-17` per the panel ADR; gated on `mint-calc-engine-v1` Stage 3 close.
- **Coach-extractor LLM with evidence-quote + banlist + TTL + user-visible review surface** — Phase 03. The pattern is locked in the panel ADR; the implementation phase is gated on Phase 02 completion.
- **`CoachInsightRecord` consent + export + delete path compliance gap** — addressed in hot-fix branch; not Phase 01 scope.
- **KMS provider choice** — Phase 02 (Railway-native vs AWS KMS vs self-hosted Vault).
- **Partial DEK shred** (per-fact-category granular erasure) — backlog; current envelope is all-or-nothing per user.
- **Constants change propagation policy** (re-flag historical projections vs point-in-time) — Phase 02 will lock this; Phase 01 plan only ensures `constants_version_hash` is captured at write time.

### To Phase 02 planner deliverables
- **Latency benchmark** of `/v1/regulatory/constants/snapshot` from cold-start.
- **Telemetry baseline** for mobile offline-session rate + L1-only-session rate + constants-staleness-at-render-time.
- **Bundle-size measurement** of the 26-canton snapshot compressed (D-14 upper bound validation).
- **CI staging-down failure mode** detailed handling for D-16.
- **`MINT_DOCTRINAL_CONSTANTS_VERSION` field placement + CI drift lint** (D-13 implication).
- **Reconciliation with the 8 deferred operational gates** from `mint-calc-engine-v1` (G2 Julien device sign-off + 7 follow-ups) — explicit answer on which are in critical path for Phase 01.

### To backlog (re-litigate on trigger)
- **Full backend-canonical (delete mobile financial_core)** — re-open if offline-session telemetry post-launch shows <2% of sessions touch L1 offline.
- **Lazy per-canton fetch** (revise D-14) — re-open if compressed 26-canton snapshot exceeds 100 KB.
- **Mobile shadow implementation for L2-L4 offline** — re-open only if FINMA publishes guidance requiring strong offline-disclosure that a chip cannot deliver, AND the user research case justifies it.
- **Single-endpoint ETag/If-None-Match contract** instead of two endpoints (revise D-15) — minor optimisation; revisit if the `version` endpoint becomes a measurable hotspot.

### Scope-creep redirects
- *None surfaced during discussion* — Julien stayed within phase scope throughout.

</deferred>

---

*Phase: mint-data-architecture-v1-01-calc-engine-canonical*
*Context gathered: 2026-05-17*
*Next: `/gsd-plan-phase mint-data-architecture-v1-01-calc-engine-canonical` (or `--skip-research` if planner thinks the ADR + this CONTEXT.md is enough).*

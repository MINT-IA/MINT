# Phase mint-data-architecture-v1-01-calc-engine-canonical — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-17
**Phase:** mint-data-architecture-v1-01-calc-engine-canonical
**Mode:** discuss (interactive, AskUserQuestion)
**Areas discussed:** Canonical home · Offline-first reconciliation · Migration sequencing · Sync direction + transport

**Outcome:** 16/16 recommended options confirmed across 4 areas. No "Other" selections, no scope-creep deferrals during discussion (Julien stayed within phase scope throughout).

---

## Gateway question — ROADMAP add

Phase was not in `ROADMAP.md` at the start of the session. Engram obs #150 + #151 and `.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md` §"Status & follow-up" explicitly named this phase as the upstream prerequisite for the event-log + projection migration. The discussion gated on confirming the ROADMAP add before proceeding.

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, add Phase 01 only + discuss | Declare Phase 01 in a new milestone block; defer 02/03 until 01 lands (matches ADR's gated sequencing). Then run discuss-phase normally. | ✓ |
| Add all 3 phases + discuss 01 | Declare Phases 01/02/03 upfront, even though 02/03 are gated on 01 outcome. Then discuss 01. | |
| Different naming / scope | I have a different milestone or phase name in mind — I'll specify. | |

**User's choice:** Yes, add Phase 01 only + discuss
**Notes:** Matches the ADR's sequencing — declaring Phase 02 + 03 in ROADMAP before Phase 01 outcome is locked would prejudge the result. Milestone `v2.11 Data Architecture v1 — Trust & Compliance Foundation` added.

---

## Gray-area selection

| Option | Description | Selected |
|--------|-------------|----------|
| Canonical home (the central question) | WHERE the calc LOGIC lives going forward. | ✓ |
| Offline-first reconciliation | How L1 chiffrer works offline. | ✓ |
| Migration sequencing (D-CE-09 strangler-fig) | Honouring zero-physical-move + lazy file-by-file. | ✓ |
| Sync direction + transport for constants | How constants flow once canonical is locked. | ✓ |

**User's choice:** All four areas selected.
**Notes:** No areas skipped; full discussion across all four.

---

## Area 1 — Canonical home

### Q1.1 — Where does the calculator LOGIC canonically live going forward?

| Option | Description | Selected |
|--------|-------------|----------|
| Split with explicit arbiter (L1 mobile, L2–L4 backend) [Recommended] | Mobile owns L1 chiffrer (offline-capable). Backend owns L2 comparer + L3 éclairer + L4 invariants (DAG/cache/grounding/audit trail). Maps cleanly onto mint-calc-engine-v1 L1-L4 typed payloads. | ✓ |
| Backend-canonical (delete-mobile-calc-eventually) | ADR's implicit assumption. Mobile becomes thin renderer. Offline-first becomes "show last cached + offline banner". | |
| Mobile-canonical (delete-backend-calc-eventually) | Inverse. Mobile financial_core stays SoT. Re-architects Phase 02 entirely. | |

**User's choice:** Split with explicit arbiter (L1 mobile, L2–L4 backend)
**Rationale:** Respects offline-first reality + D-CE-06 server-PRIMARY enforcement + D-CE-09 no-big-bang. The L1-L4 typology was already typed (Pydantic discriminators) so the boundary is structural.

### Q1.2 — L1/L2 boundary criterion?

| Option | Description | Selected |
|--------|-------------|----------|
| By layer in the L1–L4 lucidité framework [Recommended] | Use the existing typed payload discriminator. L1 chiffrer → mobile; L2-L4 → backend. | ✓ |
| By data dependency (canton-aware = backend) | Anything depending on canton/regulatory data goes backend. Simpler rule but cuts across layering. | |
| By output cardinality (single-number = mobile) | Mobile: one number/widget. Backend: >1 scenario, sensitivity, comparative. | |

**User's choice:** By layer in the L1–L4 lucidité framework
**Rationale:** Re-uses an existing typed Pydantic discriminator rather than inventing a new judgment rule. Structural, not soft.

### Q1.3 — Non-regulatory mobile financial code?

| Option | Description | Selected |
|--------|-------------|----------|
| Confidence/Bayesian/coach-reasoner stay mobile; Monte Carlo + sensitivity + arbitrage move backend [Recommended] | UX-bound mobile-side, projection-class backend-side. Splits cleanly along the L1/L2 line. | ✓ |
| Everything financial moves backend, only UI state stays mobile | Maximalist backend-canonical. Largest migration cost. May add network latency to UX surfaces. | |
| All current mobile code stays mobile; new work goes backend only | Additive strangler-fig; lowest immediate effort; biggest long-term tech debt. | |

**User's choice:** Selective per-class per the L1/L2 line.
**Rationale:** Confidence + Bayesian are UX-bound (form feedback, no LSFin output). Monte Carlo + tornado + withdrawal seq + arbitrage emit projection-class outputs that need `constants_version_hash` audit trail.

### Q1.4 — Doctrine rewrite timing?

| Option | Description | Selected |
|--------|-------------|----------|
| Same PR as Phase 01 CONTEXT.md merge [Recommended] | CLAUDE.md + docs/AGENTS/ updated in lockstep. No window where agents read stale doctrine. | ✓ |
| Separate doctrine PR shipped 24h before Phase 02 plan | Cleaner review surface; window where agents could act on stale doctrine. | |
| Doctrine stays as-is, decision adds a CLAUDE.md §-pointer to the ADR | Minimal doctrine churn; relies on agents following the pointer reliably. | |

**User's choice:** Same PR as Phase 01 CONTEXT.md merge
**Rationale:** Risk of agents reading stale CLAUDE.md after the decision lands is unacceptably high. Every subagent invocation reads CLAUDE.md.

---

## Area 2 — Offline-first reconciliation

### Q2.1 — Offline UX for L1 chiffrer?

| Option | Description | Selected |
|--------|-------------|----------|
| Compute locally with last-known constants + 'offline' indicator [Recommended] | Subtle "offline — valeurs au [date]" chip. USER-VALUE preserved; 0-trust audit chain intact. | ✓ |
| Compute locally + staleness banner only past N days | Less visual noise; user might not notice stale. | |
| Block + show 'reconnect for an up-to-date number' | Cleanest LSFin posture; kills offline ergonomics. | |

**User's choice:** Compute locally with last-known constants + 'offline' indicator
**Rationale:** USER-VALUE measured at 0-TRUST §9. The number is correct as of last sync; the chip tells the user what's old.

### Q2.2 — L2-L4 surfaces when offline?

| Option | Description | Selected |
|--------|-------------|----------|
| Show last cached projection + 'projection au [date]' chip + manual refresh action [Recommended] | Render from `SnapshotModel` with explicit staleness. Aligns with `mint-calc-engine-v1` cache-reader pattern. | ✓ |
| Block L2-L4 surfaces entirely when offline | Show "requires connexion" state. Costs the user the ability to re-read a projection on the train. | |
| Optimistic local re-compute (mobile shadow-implementation) | Doubles maintenance + breaks D-CE-09 strangler-fig + breaks audit trail. Rejected. | |

**User's choice:** Show last cached projection + 'projection au [date]' chip + manual refresh action
**Rationale:** Graceful degradation that tells the user what's old. Re-uses existing `SnapshotModel`.

### Q2.3 — Max-staleness window for mobile L1 constants?

| Option | Description | Selected |
|--------|-------------|----------|
| Soft warn at 7d, hard refuse at 30d [Recommended] | Day 0-7 silent; day 7-30 chip; day 30+ refuse. Covers typical offline streaks + matches AVS/3a calendar cadence. | ✓ |
| Soft warn at 24h, hard refuse at 7d | Tighter. Risks user friction during normal travel. | |
| Soft warn at 30d, never hard refuse | Lowest friction; highest LSFin/audit risk. | |

**User's choice:** Soft warn at 7d, hard refuse at 30d
**Rationale:** 7d covers vacation / mountain / EU roaming-off; 30d aligns with regulatory update cadence.

### Q2.4 — Constants sync mechanism + timing?

| Option | Description | Selected |
|--------|-------------|----------|
| Build-time codegen + runtime delta-check on app launch [Recommended] | Every build bakes active snapshot via codegen. App launch delta-checks hash; mismatch → fetch fresh. Combines reproducible builds + runtime freshness. | ✓ |
| Build-time codegen only (no runtime fetch) | Constants only update when app version ships. Predictable but slow. | |
| Runtime-only fetch (no build-time bake) | Breaks offline-on-first-launch + adds cold-start latency. | |
| Background daily sync via Workmanager / iOS BGAppRefresh | Worst-case freshness without app-launch network. Platform-specific complexity. | |

**User's choice:** Build-time codegen + runtime delta-check on app launch
**Rationale:** Reproducible builds (build-time bake) + runtime freshness (launch-time delta-check).

---

## Area 3 — Migration sequencing (D-CE-09 strangler-fig)

### Q3.1 — Strangler-fig PR sequence shape?

| Option | Description | Selected |
|--------|-------------|----------|
| By calc class + grouped by domain [Recommended] | One PR per domain (LPP, taxes, AVS, succession, divorce, frontalier). Each PR: backend impl + mobile shim + parity test. | ✓ |
| By UI surface (one PR per consumer screen) | Smaller diffs; risk of half-migrated calcs across PRs. | |
| Big-bang single PR after Phase 02 schema lands | Violates D-CE-09 + un-reviewable mega-diff. | |

**User's choice:** By calc class + grouped by domain
**Rationale:** Matches the existing `mint-calc-engine-v1` per-domain panel pattern + reviewable surface.

### Q3.2 — Mobile-side shim policy?

| Option | Description | Selected |
|--------|-------------|----------|
| Thin client wrapper + 1-release deprecation banner, then deletion [Recommended] | Honours D-CE-10 deprecation-shim pattern. Rollback-safe. | ✓ |
| Hard cut — delete mobile calc same PR as backend ships | No shim period. Faster but no rollback. | |
| Keep mobile shadow indefinitely as offline fallback | Doubles maintenance. Conflicts with Q2.2 "no shadow". Rejected. | |

**User's choice:** Thin client wrapper + 1-release deprecation banner, then deletion
**Rationale:** D-CE-10 pattern preserved. Rollback path if backend bug discovered post-merge.

### Q3.3 — Which calcs migrate first?

| Option | Description | Selected |
|--------|-------------|----------|
| Monte Carlo + sensitivity first [Recommended] | Highest LSFin audit risk, lowest UX coupling (analysis surface, not live form). | ✓ |
| Arbitrage engine first | Most strategic to coach output. Higher UX coupling. | |
| Withdrawal sequencing first | Smallest, easiest. Doesn't move the needle. | |
| All at once after schema | Defers everything to Phase 02. | |

**User's choice:** Monte Carlo + sensitivity first
**Rationale:** Highest audit-trail payoff + lowest UX-coupling = cleanest first migration.

### Q3.4 — Constants drift lint timing?

| Option | Description | Selected |
|--------|-------------|----------|
| Same PR as Q3.3 first-migrated calc [Recommended] | Proves the parity pattern end-to-end on the first real migration. | ✓ |
| Standalone PR before any migration starts (tooling first) | Cleanest separation. | |
| Wait for full migration to complete, then build the lint | Backwards. | |

**User's choice:** Same PR as Q3.3 first-migrated calc
**Rationale:** Mirrors the existing Concern C lint pattern; proves end-to-end before generalising.

---

## Area 4 — Sync direction + transport for constants

### Q4.1 — Constants payload scope?

| Option | Description | Selected |
|--------|-------------|----------|
| LSFin-touched + canton-varied regulatory values only [Recommended] | 3a max, plafond LPP, AVS rentes, LIFD brackets, wealth_tax, succession, alloc fam, LAMal. MINT-doctrinal stays Dart-side. | ✓ |
| All numeric constants including doctrinal | Treats MINT-set and gov-set the same. Mixes audit trails. | |
| Only the smallest subset that drives sev-3 endpoints | Creates a half-synced state. | |

**User's choice:** LSFin-touched + canton-varied regulatory values only
**Rationale:** Clean line between government truth (synced) and MINT assumption (versioned in repo).

### Q4.2 — Per-canton handling?

| Option | Description | Selected |
|--------|-------------|----------|
| Bake all 26 cantons into the mobile bundle [Recommended] | Offline-capable for any canton; matches 8-archetype routing. | ✓ |
| Bake user's declared canton only + fetch others on demand | Smaller bundle; breaks offline rationale partially. | |
| All cantons in bundle but lazy-loaded post-first-launch | Adds complexity for marginal bundle-size win. | |

**User's choice:** Bake all 26 cantons into the mobile bundle
**Rationale:** Cross-canton simulation (frontalier from FR → GE) must work offline.

### Q4.3 — Sync endpoint contract?

| Option | Description | Selected |
|--------|-------------|----------|
| GET /version (hash + effective_from) + GET /snapshot (full) [Recommended] | Two endpoints; simplest contract; ETag-friendly. | ✓ |
| Single endpoint with ETag/If-None-Match | More HTTP-idiomatic; same data shape. | |
| Incremental diff endpoint (GET .../diff?from=hash) | Smaller wire size; over-engineered for ~100s of KB total. | |

**User's choice:** GET /version + GET /snapshot
**Rationale:** Simplest contract; matches existing FastAPI patterns.

### Q4.4 — Build-time codegen source?

| Option | Description | Selected |
|--------|-------------|----------|
| Pre-build script in CI fetches /snapshot from staging + writes committed `.g.dart` [Recommended] | Deterministic + reviewable + matches `_registry.py` AUTO-GENERATED pattern. | ✓ |
| Codegen from JSON fixture committed in-repo (no network in build) | Avoids CI network; risks drift if maintainer forgets to re-export. | |
| Runtime-only — no bake | Already rejected in Q2.4. | |

**User's choice:** Pre-build script in CI fetches /snapshot from staging + writes committed `.g.dart`
**Rationale:** Mirrors `mint-calc-engine-v1` Plan 05 AUTO-GENERATED `_registry.py` pattern.

---

## Final check — ready for context?

| Option | Description | Selected |
|--------|-------------|----------|
| I'm ready for context (write + commit) [Recommended] | Captures 16 decisions + canonical refs + code context + deferred ideas. Commits to dev. | ✓ |
| Explore more gray areas | (a) reconciliation with mint-calc-engine-v1 deferred gates; (b) parity test strategy; (c) feature-flag rollout; (d) Sentry hooks for delta-check failures. | |
| Pause + review CONTEXT.md draft before commit | Write to disk, no commit; review + tweak; commit on green light. | |

**User's choice:** I'm ready for context
**Notes:** All 4 remaining gray areas folded into "Claude's Discretion" or "deferred to Phase 02 planner deliverables" in CONTEXT.md rather than discussed individually.

---

## Claude's Discretion

The following decisions are explicitly delegated to the planner (named in CONTEXT.md `<decisions>` § Claude's Discretion):

- Exact bundle-size validation methodology for D-14 (compressed vs uncompressed, profiling tool, threshold ceremonies).
- Exact failure-mode wording for D-16 CI staging-down case (soft-warn message format, Sentry breadcrumb).
- Sentry / observability hooks for delta-check failures + offline-session detection.
- Test strategy for parity (D-12) — fixture-driven (default, matches existing) vs property-based.
- Feature-flag rollout sequence for D-11 Monte Carlo migration (default: `monte_carlo_backend_canonical` shipped OFF, flipped staging → production over 1 release).
- Placement of `MINT_DOCTRINAL_CONSTANTS_VERSION` field (D-13 implication).

## Deferred Ideas

(Mirrors CONTEXT.md `<deferred>` section — re-stated here for audit trail completeness.)

- Event-log + projection schema migration → Phase 02.
- DEK envelope + crypto-shred wiring → Phase 02.
- `SnapshotModel.constants_version_hash` → hot-fix branch.
- Coach-extractor LLM + guardrails → Phase 03.
- `CoachInsightRecord` consent compliance → hot-fix branch.
- KMS provider choice → Phase 02.
- Partial DEK shred → backlog.
- Constants change propagation policy → Phase 02.
- Latency benchmark of `/v1/regulatory/constants/snapshot` → Phase 02 planner deliverable.
- Telemetry baseline (offline-session rate, L1-only-session, staleness-at-render) → Phase 02 planner deliverable.
- Bundle-size measurement of 26-canton snapshot → Phase 02 planner deliverable.
- CI staging-down failure mode for D-16 → Phase 02 planner deliverable.
- `MINT_DOCTRINAL_CONSTANTS_VERSION` placement + CI drift lint → Phase 02 planner deliverable.
- Reconciliation with `mint-calc-engine-v1`'s 8 deferred operational gates → Phase 02 planner deliverable.
- Full backend-canonical (delete mobile financial_core) → backlog, re-litigate trigger: offline-session telemetry <2%.
- Lazy per-canton fetch → backlog, re-litigate trigger: compressed snapshot >100 KB.
- Mobile shadow for L2-L4 offline → backlog, re-litigate trigger: FINMA guidance on offline disclosure.
- Single-endpoint ETag/If-None-Match → backlog, minor optimisation.

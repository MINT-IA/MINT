---
description: Session-state CAP for 2026-05-12 — the orchestrator's anchoring document per MDM Pillar 0. Built after Julien's directive « Est-ce que tu as bien tout le contexte de Mint ». Read this BEFORE any new cycle. Sub-agents that need global context pointer here ; per-cycle CONTEXT.md remains scoped.
type: session-state
created: 2026-05-12
authority: julien-directive-2026-05-12T08:35Z
---

# MINT — Session-state snapshot (orchestrator anchor)

## Milestone position

- **Active milestone** : `v2.9 — Chat-as-Verb Pivot` (per `.planning/STATE.md`).
- **Milestone progress** : 82% (6/11 phases done, 23/28 plans done as of 2026-05-11T05:18Z).
- **Last completed phase** : Phase 96 Wave 3 (NarrativeSleeve + metaphor TOML + Maestro G1 + walkback path + FLAG-FLIP-PROPOSAL ; commits b81172a3..bbcf0853..dfd386f6).
- **Phase 96 status** : Wave 3 implementation complete ; Task 4 G2 checkpoint awaits Julien token (`approved` / `approved-with-issues: <desc>` / `not approved`). Critically : the Phase 96 « chat-as-verb » deploy on staging keeps `COACH_CITATION_GATE_ENABLED=True` and `chatTabVisible=true` because the flag-flip baseline (D-11 7-day Sentry soak) hasn't completed yet.
- **Current active phase** : Phase 97 « MVP-PARFAIT-MAESTRO-FULL-POWER ». TestFlight ship gate. Per `.planning/phases/97-.../97-CONTEXT.md` D-30 : ALL 5 gates green × ALL 8 archetypes × 7-day staging soak with zero LSFin violation. NO « approved-with-issues » disposition admitted.

## v2.9 doctrine (load-bearing — do not drift from this)

Source : `.planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md` + STATE.md §Strategic Frame.

- **MINT is 70% structured wiki + simulators, 30% narration.** Not a chat-first app.
- **Kill chat-tab as destination.** Cards are the home. Chat is a precision tool invoked from card actions (« explique / simule / rassure-moi »).
- **3-turn cap** per (user_id, source_card_id) on chat-as-verb invocations.
- **Citation gate on every emitted number.** Narrator LLM is mathematically incapable of emitting an uncited number (Phase 94 closed-world contract).
- **DAG invalidation** on stale projections (Phase 95 inputs_hash + superseded_by).
- **North-star metric** : Turns/user/week DOWN, DAU UP, QoQ.

## Phase 97 W7 W0-W8 framing

- **W0** : Bug bash audit ; 43+ bugs in registry across 6 surfaces (mobile / backend / testing / docs / infra / content).
- **W7** (current) : 7-step methodical cycle (PICK → REPRO → FIX → PASS → SUITE → LOCK → ADVANCE) applied to each bug.
- **Discipline locked 2026-05-12 morning** : 1 perimeter = 1 PR, mechanical guard via lefthook (`ios_release_capability_drift.py` lint shipped today).

## 8 archetypes (CLAUDE.md NEVER #7 — MUST cover all)

`swiss_native`, `expat_eu`, `expat_us` (FATCA), `cross_border`, `indep_with_lpp`, `indep_no_lpp`, `returning_swiss`, `near_retirement`. Per Phase 97 D-05, no subset allowed for ship.

## Today's PRs (all merged to dev EXCEPT #573)

| PR | Bug | State |
|---|---|---|
| #564 | Phase 94+95+96+96.1+97 W7 18-cycle stack | MERGED `c7920464` 20:48Z |
| #566 | dev→staging release (replaces conflicted #565) | MERGED `2a52b562` 20:56Z |
| #567 | Revert `associated-domains` entitlement (TestFlight unblock) | MERGED `6a1f0b20` 05:21Z |
| #568 | dev→staging sync (post-revert) | MERGED `3d6dd309` 05:26Z |
| #569 | iOS capability-drift lint (preventive) | MERGED `1c54bcb4` 05:47Z |
| #570 | S002 Maestro cold-launch fragment | MERGED `8a35484f` 06:12Z |
| #571 | F008 MintCardActionBar 35px overflow | MERGED `72884e7e` 06:12Z |
| #572 | B023b snapshots FK + 15 server_defaults | MERGED `1ec21227` 06:25Z |
| #573 | **P003 coach gate user-input awareness (THIS CYCLE)** | OPEN — awaiting CI + Julien approve to merge |

TestFlight staging build for the commit `2a52b562` GREEN (run `25715280560`, 13m2s). Subsequent commits await next staging push.

## What's IN_PROGRESS / OPEN in 97-BUGS-REGISTRY (P003 cycle filed today)

| ID | Title | Severity | Status |
|---|---|---|---|
| M001 | Flutter Keys don't propagate as iOS Semantics (surfaced during S005 close) | P2 | OPEN — workaround via regex matchers documented; M001 fix is wide-blast |
| L004 | 283 accent FR violations (aggregate inventory) | P2 | OPEN — deferred to v2.10 MVP-CLEANUP |
| L005 | 5042 hardcoded FR strings (aggregate inventory) | P2 | OPEN — deferred to v2.10 |
| L006 | ~50 silent bare-catches Dart | P2 | OPEN — deferred to v2.10 |
| L007 | bare-catches Python | P2 | OPEN — deferred to v2.10 |
| L008 | `/debug/chat-as-verb` not in `kRouteRegistry` | P2 | OPEN — exemption via `_DEV_DEBUG_ONLY` shipped in #564 but registry status not flipped to REJECTED-with-guard yet |
| P001 | Phase 94 narrator gate-correct thresholds 18%/22% vs 95%/90% | P0 | IN_PROGRESS — H1 marginal lift, H2-H5 filed as P001b/c/d/e |
| P002 | 0 production cards wired with MintCardActionBar | P1 | OPEN — closed alongside backlog 999.6 ; Phase 97 W5 inventories then wires |
| P003 | Auth coach returns FALLBACK on first prompt with full inline profile | P0 | IN_PROGRESS — code fix shipped today in PR #573 ; Pillar 6 dims 3+4 pending post-deploy |
| P001b/c/d/e | Narrator hypotheses H2-H5 follow-up | P0 | OPEN — architectural decisions pending |
| B023b | snapshots FK + server_defaults | P2 | MERGED today in PR #572, registry update lands with PR |

## P003-specific status (this cycle)

- Pillars 1-7 of MDM all complete in this PR.
- Verification Cube dims 1 (code, 12 new + 6662 backend GREEN) + 2 (integration linters clean) GREEN.
- Verification Cube dims 3 (L3 staging curl post-deploy) + 4 (Julien sim re-test) PENDING.
- PR can merge → dev→staging sync → Railway redeploy → L3 re-curl → Julien re-test → close cycle.

## Out of scope (Phase 97 D-27)

- New product features (Phase 97 verifies what's there, doesn't add).
- Maestro Cloud paid tier (fallback only ; primary = Mac mini self-hosted runner).
- Backend microservice extraction (post-v2.9).
- Multi-region staging (Phase 97 = `mint-staging.up.railway.app` only).
- Android sim coverage (iOS only ; Android = v3.x).

## v2.10 MVP-CLEANUP queue (deferred from this phase)

Per `.planning/phases/97-.../deferred-items.md` — items NOT to bundle into Phase 97 cycles :
1. Pre-existing prefer-mint-* lint debt in `anonymous_chat_screen.dart` (14 violations on legacy lines).
2. Pre-existing `accent_lint_fr` hits on `eclairage` Dart identifier (33 hits — class name refactor).
3. Dead code in `_buildMessageBubble` (anonymous_chat_screen.dart:762-768).

## Authoritative documents (reload order if context dilutes)

1. `CLAUDE.md` (always auto-loaded ; re-read §9 0-trust before any « works / shipped / green » claim).
2. `~/.claude/.../memory/MEMORY.md` (auto-loaded ; 31 entries).
3. `.planning/STATE.md` (current milestone position + GSD state machine).
4. `.planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md` (v2.9 doctrine).
5. `.planning/phases/97-.../97-CONTEXT.md` (Phase 97 locked decisions D-01..D-42).
6. `.planning/phases/97-.../97-BUGS-REGISTRY.md` (single source of truth for bug status).
7. `.planning/phases/97-.../97-DISCUSSION-LOG.md` (decision rationale per W).
8. `.planning/phases/97-.../deferred-items.md` (what NOT to bundle).
9. `.planning/MINT-DEBUG-METHOD.md` (the cycle protocol — this session).
10. `docs/ROADMAP_V2.md` (Phases 1-4 SHIPPED ; v2.9 doctrine context).
11. `SOT.md` (Profile / SessionReport schemas — when changing data contracts).
12. `docs/VOICE_SYSTEM.md` + `docs/DESIGN_SYSTEM.md` + `docs/MINT_IDENTITY.md` (when touching user-facing copy or UI).

## Memory keys most-relevant TODAY

- `feedback_zero_trust_protocol.md` — every « works / shipped / green » needs deterministic citation.
- `feedback_perimeter_5_gates.md` — 1 perimeter = 1 PR ; 5 mechanical gates.
- `feedback_ios_entitlements_block_testflight.md` (NEW today) — iOS entitlement adds need provisioning profile update BEFORE merge.
- `feedback_expert_panel_pattern.md` — strategic decisions go through 3-7 expert subagents with verdict synthesis.
- `feedback_app_targets_staging_always.md` — mobile/sim always hits Railway staging.
- `feedback_anthropic_key_on_railway.md` — Anthropic key IS on Railway, never suspect it.
- `feedback_read_order_planning.md` (THIS is what got violated and is now mechanically enforced via Pillar 0).
- `project_testflight_ship_path.md` — dev→staging merge fires testflight.yml ; walker is OPTIONAL.
- `feedback_no_micro_pauses.md` — pack each turn ; end only on real blockers.

## What I'm grounded on NOW that I wasn't at session-start

- The « v2.9 chat-as-verb pivot » milestone IS the strategic frame. MINT is NOT a chat-first app. The chat tab disappears in the target architecture. Today's P003 cycle still matters because the residual « chat-as-verb » invocations from cards must work — but the bug is fixable WITHIN the pivot's doctrine.
- Phase 97 W7's W0-W8 framing is bug-bash → cycle → ship-or-defer. v2.10 MVP-CLEANUP is where the wide sweep refactors go.
- The 8-archetype matrix is non-negotiable for D-30 ship gate.
- TestFlight is unblocked on staging as of `2a52b562` (run 25715280560 GREEN 06:08Z this morning).

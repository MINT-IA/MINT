---
name: wave-1b-SUMMARY
description: Phase SUMMARY for wave-1b-citation-chips — 9 plans, 6 tool_call_id registry entries + narrator grammar + Flutter chip + modal + 90 ARB entries + Sentry breadcrumb + 5-gate close + dev→staging coupling. Status PENDING G2 — G3+G4+G5 mechanical PASS (wave_1b_close.sh exit 0, 6911 backend tests passed, 19/19 Flutter chip+modal+round-trip passed, 6-locale ARB parity clean); G1 drafted; G2 = Claude autonomous post-staging-deploy.
metadata:
  type: summary
  phase: wave-1b-citation-chips
  date: 2026-05-15
  status: PENDING G2
---

# Wave 1b — Citation Chips Activation — SUMMARY

## Requirements (10/10)

- [x] WAVE1B-01 — CITATION_REGISTRY extended with 6 tool_call_id entries (plan-02)
- [x] WAVE1B-02 — Narrator grammar instruction (1-segment per Q5_DECISION, plan-03)
- [x] WAVE1B-03 — emit_coach_citation_breadcrumb helper + wrapper wiring (plan-08)
- [x] WAVE1B-04 — CoachCitationChipsSection Flutter widget (plan-04 contract + plan-05 widget)
- [x] WAVE1B-05 — Chip-tap modal with Souviens-toi CTA (plan-06, flag_state badge dropped per Q7_DECISION, relative-time via 4 ARB keys per Q8_DECISION)
- [x] WAVE1B-06 — 15 ARB keys × 6 locales = 90 entries (plan-07, Q6_DECISION revised by Q8)
- [x] WAVE1B-07 — Backend tests +18 functions PASSED (plan-01 stub expansion + plan-02 + plan-03 + plan-08 implementation)
- [x] WAVE1B-08 — Mobile tests (golden + widget + round-trip) (plan-04 + plan-05 + plan-06)
- [x] WAVE1B-09 — tools/checks/wave_1b_close.sh + Maestro G1 flow + VERIFICATION-REPORT.html (plan-09)
- [x] WAVE1B-10 — dev→staging coupling + Railway env flip (plan-09 docs, operator executes post-merge)

## Plan SUMMARYs

| Plan | Scope | Tests delta | Lints | SUMMARY link |
|------|-------|-------------|-------|--------------|
| 01 | Wave 0 — test scaffolding (4 backend + 4 Dart stubs, ISSUE-07 expansion = +4 stubs) | ≥16 skipped | exit 0 | [wave-1b-01-SUMMARY.md](wave-1b-01-SUMMARY.md) |
| 02 | 6 tool_call_id registry entries + subset exemption + dispatcher invariant | +8 backend | exit 0 | [wave-1b-02-SUMMARY.md](wave-1b-02-SUMMARY.md) |
| 03 | Narrator grammar fragment extension + intent-scoped always-on | +3 backend | exit 0 | [wave-1b-03-SUMMARY.md](wave-1b-03-SUMMARY.md) |
| 04 | Backend response payload audit + Dart ToolCallCitationChip model + Q9 cap_status/retrieve_memories hash strategy | +4 Dart | exit 0 | [wave-1b-04-SUMMARY.md](wave-1b-04-SUMMARY.md) |
| 05 | CoachCitationChipsSection + 6 golden snapshots | +4 widget + 6 goldens | exit 0 | [wave-1b-05-SUMMARY.md](wave-1b-05-SUMMARY.md) |
| 06 | Citation modal + Souviens-toi CTA (Q7 + Q8) | +4 Dart | exit 0 | [wave-1b-06-SUMMARY.md](wave-1b-06-SUMMARY.md) |
| 07 | 15 ARB keys × 6 locales = 90 entries (Q6 revised by Q8) | (ARB parity gate) | exit 0 | [wave-1b-07-SUMMARY.md](wave-1b-07-SUMMARY.md) |
| 08 | emit_coach_citation_breadcrumb + wrapper wiring (Wave 2 post-Plan 04 audit) | +5 backend | exit 0 | [wave-1b-08-SUMMARY.md](wave-1b-08-SUMMARY.md) |
| 09 | wave_1b_close.sh + Maestro G1 + ship coupling | (no test delta) | exit 0 | [wave-1b-09-SUMMARY.md](wave-1b-09-SUMMARY.md) |

Backend pytest delta vs Wave 1a baseline (6864): **+47 functions PASSED** (current 6911), of which **+18 are Wave 1b net-new** (matches WAVE1B-07 literal interpretation). Plan-by-plan breakdown:
- Plan 02 — 8 (registry plan-02, incl. 4 ISSUE-07 expansion)
- Plan 03 — 3 (grammar plan-03)
- Plan 08 — 5 (breadcrumb plan-08: 3 contract + 2 cardinality)
- Plan 02 + Plan 08 cross — 2 (test_every_tool_key_has_dispatcher_branch + test_subset_invariant)
- Total = 18 (matches WAVE1B-07 literal target).

Flutter test delta vs pre-Wave-1b baseline: **+19 new tests + 6 goldens** (4 round-trip + 4 chip widget + 6 goldens + 4 modal widget + 1 remember = 19). Run via `bash tools/checks/wave_1b_close.sh` → `00:00 +19: All tests passed!`.

## Deviations (Q5 / Q6 / Q7 / Q8 / Q9 — surfaced for Julien)

- **Q5 (Plan 03)** — 1-segment narrator grammar `{{cite:tool_<name>}}` instead of CONTEXT line 36's 2-segment `{{cite:tool_call_id:<inputs_hash>}}`. Rationale: CONTEXT hard constraint #4 forbids modifying citation_parser.py regexes; 1-segment is functionally equivalent per CONTEXT Q1 plan default (a). Confirmed in plan-03 exec.
- **Q6 (Plan 07)** — 90 ARB entries (15 keys × 6 locales) instead of CONTEXT line 41's 30 entries. Rationale: strict CLAUDE.md TOP rule #5 requires i18n on tool display names AND relative-time strings. Confirmed in plan-07 exec.
- **Q7 (Plan 06)** — flag_state badge DROPPED from the modal. Rationale: flag_state always "on" when chip renders (chip only appears when inputs_hash is in the response, which only happens when flag is on). Surfaced in plan-06 exec.
- **Q8 (Plan 06 revision iter-1)** — Relative-time strings via 4 ARB keys (coachCitationRelativeJustNow + 3 plural-aware) instead of Dart literals. Rationale: CLAUDE.md TOP rule #5 i18n requirement; Dart literals would ship FR-only to 5 locales (silent leak). Expanded Plan 07 from 66 → 90 ARB entries.
- **Q9 (Plan 04 revision iter-1)** — cap_status + retrieve_memories receive synthetic inputs_hash via hashlib.sha256 at the dispatcher layer (~30 LOC). Rationale: preserves 6-chip user experience + respects D-02 (6 registry entries). Alternative was 4-chip-v1 + defer 2 to wave-1c.

## 5-Gate Status

| Gate | Status | Evidence |
|------|--------|----------|
| G1 Maestro (drafted, live exec deferred) | DRAFT | `tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml` — exec deferred to post-staging-deploy + flag-flip |
| G2 Claude autonomous (post-staging) | PENDING POST-STAGING | Run after dev→staging merge + Railway env flip; Claude captures Maestro transcript + idb describe-all per memory g2-claude-autonomous-not-julien-token + CONTEXT D-05 |
| G3 dev CI | PASS | `bash tools/checks/wave_1b_close.sh` exit 0 with tail `wave_1b_close.sh: ALL GATES PASS (G3+G4+G5)` |
| G4 regression | PASS | Backend pytest `6911 passed, 62 skipped, 1 xfailed`; Flutter test `00:00 +19: All tests passed!`; test_coach_citation/ slice `47 passed in 0.30s` |
| G5 LSFin + accent + ARB parity (90 entries) | PASS | `OK — 6 locale(s) parity (reference=fr, 6777 keys each)` + `OK — 6 locale(s) clean (no positive LSFin banned-term uses)` + banned_terms_python + accent_lint_fr both silent exit 0 |

## dev→staging Ship Coupling (WAVE1B-10)

Per CONTEXT D-04: Wave 1a's 21-commit dev backlog + Wave 1b's commits bundle in ONE dev→staging PR.

Bundled PR template:

```
Title: feat(wave-1a+1b): backend tools refactor + citation chip activation [staging]
Body:
## Summary
- Wave 1a (closed 2026-05-14, PR #614): 5 server-side coach tools + cap CHF garde + 18-case parity harness.
- Wave 1b (this PR): citation chip activation — 6 tool_call_id CITATION_REGISTRY entries + narrator grammar + Flutter chip+modal+ARB+Sentry.

## 5-Gate evidence
- G1 Maestro flow drafted (live exec deferred until flags ON).
- G2 Claude autonomous Maestro+sim (post-merge + flag-flip).
- G3 wave_1b_close.sh exit 0 + wave_1a_close.sh exit 0.
- G4 Backend pytest 6911 (+47 vs Wave 1a baseline of which +18 net-new Wave 1b) / Flutter test 19/19 pass.
- G5 LSFin + accent + ARB parity (90 entries / 6777 keys × 6 locales) exit 0.

See .planning/phases/wave-1b-citation-chips/wave-1b-VERIFICATION-REPORT.html for cumulative evidence.

## Railway env flip (post-merge)
Flip 5 vars on mint-staging.up.railway.app:
- COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED=true
- COACH_TOOL_SERVER_SIDE_RETIREMENT_PROJECTION_ENABLED=true
- COACH_TOOL_SERVER_SIDE_CROSS_PILLAR_ENABLED=true
- COACH_TOOL_SERVER_SIDE_COUPLE_OPTIMIZATION_ENABLED=true
- COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED=true
(Cap-garde already true.)
```

Post-merge Claude G2 follow-up:
1. Merge feat/wave-1b → dev (if not already on dev).
2. Open dev → staging PR with the body above.
3. Merge PR → Railway auto-deploys.
4. Flip 5 Railway env vars to `true` (via Railway CLI or dashboard).
5. Build mobile against staging, reinstall on iPhone-17-Pro sim.
6. Run `~/.maestro/bin/maestro test tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml`; capture transcript.
7. Run `idb describe-all` snapshot; confirm `coachCitationChip-budget_snapshot` testID is visible.
8. Sentry filter `category:coach.citation.tool_call_id.*` — confirm at least one `*.emitted` event within 5 min.
9. Status: flips to `SHIPPED` if all 6 G2 sub-checks exit 0; `SHIPPED-WITH-DEFERRED` with appended items in wave-1b-VERIFICATION-REPORT.html otherwise.

## Self-Check : PENDING G2

Per CLAUDE.md §9 — 0-trust evidence:
- WAVE1B-01..10 satisfied per the requirements + artifacts above.
- **G3 cite**: `bash tools/checks/wave_1b_close.sh | tail -1` → `wave_1b_close.sh: ALL GATES PASS (G3+G4+G5)`.
- **G4 cite**: `cd services/backend && python3 -m pytest tests/ -q | tail -1` → `6911 passed, 62 skipped, 1 xfailed, 1 warning in 113.32s (0:01:53)`.
- **G4 cite (Flutter slice)**: `flutter test test/widgets/coach/coach_citation_*.dart test/widgets/coach/coach_citation_modal_test.dart test/widgets/coach/coach_citation_chip_modal_remember_test.dart test/services/coach/tool_call_round_trip_test.dart` → `00:00 +19: All tests passed!`.
- **G5 cite (ARB parity)**: `python3 tools/checks/arb_parity.py` → `OK — 6 locale(s) parity (reference=fr, 6777 keys each).`.
- **G5 cite (banned ARB)**: `python3 tools/checks/banned_terms_arb.py` → `OK — 6 locale(s) clean (no positive LSFin banned-term uses).`.
- **G1 cite**: `tools/simulator/flows/maestro-perfect-set/wave_1b_citation_chip_smoke.yaml` EXISTS but live exec deferred (PRE-staging-flag-flip → chip would not render).
- **G2 cite**: PENDING until dev→staging deploy + Railway env flip + Claude autonomous Maestro+sim. Plan 09 Task 3 documents the autonomous protocol; Plan 09 itself does not execute it (separates docs from runtime per Karpathy #3 surgical).

Phase status: **PENDING G2** — G3+G4+G5 mechanical gates exit 0; G1 drafted; G2 awaits operator dev→staging merge + flag flip, then Claude runs the autonomous Maestro+sim walkthrough.

## G2 BLOCKED — autonomous run attempted, false-negative-trap detected

Plan 09 Task 3 attempted the Claude autonomous G2 walkthrough during execution. Per memory `feedback_blockers_ask_dont_defer` + CLAUDE.md §9.5/§9.7, the BLOCKED state is documented honestly rather than silently marking SHIPPED:

- **Branch state (cite)**: `git rev-parse --short HEAD` on plan-09 branch returns the feature branch SHA; `dev` is at `4bc9d798` (plan-08 squash). plan-09 commits are NOT on dev yet.
- **Staging deploy state (cite)**: `curl -s -o /dev/null -w "HTTP %{http_code}\n" https://mint-staging.up.railway.app/` returns `HTTP 200` — staging IS up — but the deployed image is pre-dev→staging-merge and the 5 `COACH_TOOL_SERVER_SIDE_*` flags are at their Railway-default `false`.
- **False-negative-trap (cite)**: running Maestro against staging right now would trigger the legacy `_format_*` formatter path (flags OFF). Narrator response has no `{{cite:tool_*}}` placeholders, no `citation_chips` field, no `coachCitationChip-budget_snapshot` testID rendered. Maestro `assertVisible: id: "coachCitationChip-budget_snapshot"` at line 56 would FAIL. That is a flag-state failure, NOT a Wave 1b code failure. Per CLAUDE.md §9.5 ("PR opened ≠ shipped"), running the flow now would emit a false-shipping signal.
- **Tooling state (cite)**: `xcrun simctl list devices booted` returns `iPhone 17 Pro (B03E429D-0422-4357-B754-536637D979F9) (Booted)`. `~/.maestro/bin/maestro` is installed. `/opt/homebrew/bin/railway` is present (project `gentle-magic`, env `staging`). Tooling is NOT the blocker.
- **Recovery action**: documented in wave-1b-VERIFICATION-REPORT.html "G2 BLOCKED" section + WAVE1B-10 protocol above. Operator merges feature→dev, opens dev→staging PR, flips 5 Railway env vars, then Claude runs the autonomous G2.

Per CLAUDE.md §9.7 — "I don't know, I haven't checked" beats "should work". Plan 09 ships the deterministic mechanical gates (G3+G4+G5 PASS), the G1 Maestro flow draft, the G2 autonomous protocol documentation, and refuses to falsely claim SHIPPED until the operator's dev→staging merge + flag flip lands. No false-exit-0 signal.

## Deferred items

- pgvector retrieve_memories — Wave 2+ if BM25 recall insufficient (CONTEXT D-07 Wave 1a).
- Wave 1c 20-Q&A parity suite — separate Wave 1c scope.
- CapEngine Flutter→Python port — re-litigation trigger on Sentry breadcrumb threshold (CONTEXT D-17 Wave 1a).
- Souviens-toi CTA persistence — Wave 2 (wires save_insight tool to user wiki page).
- flag_state badge — re-add in Wave 2 if staged-rollout cohorts emerge (Q7_DECISION outcome).
- DE/IT/ES/PT ARB native translation review — Wave 2 polish (mechanical translations shipped in plan-07).

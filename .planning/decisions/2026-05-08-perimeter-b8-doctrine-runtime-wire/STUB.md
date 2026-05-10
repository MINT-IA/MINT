---
name: MVP-B8-DOCTRINE-RUNTIME-WIRE — perimeter STUB
description: Audit-found gap on PR #529 B6. The fail-loud doctrine guard at doctrine_checks.py:498-503 was added but score_response() has 0 production callers. So the « FATCA bypass closure » claimed in B6 commit message is NOT effective at runtime. This STUB plans the actual wiring of score_response into the LLM response path. Effort ~1 j.
type: decision
date: 2026-05-08
status: STUB (à ouvrir post Julien G2 confirm v2.12.2+4)
related:
  - .planning/decisions/2026-05-08-coach-onboarding-redesign-panel/SYNTHESIS.md
  - PR #529 commit dc987c4c (B6 fail-loud function-level fix)
sources:
  - 6-agent panel synthesis 2026-05-08
  - Code audit a80125307 finding (« defensive-only, not wired to runtime »)
  - Verification grep "score_response\|check_archetype_aware" services/backend/app → 0 production callers
---

# MVP-B8-DOCTRINE-RUNTIME-WIRE — STUB

## Goal

**Wire `score_response()` into the production LLM response path** to actually catch the FATCA bypass scenarios that B6 only fixed at function-level.

This perimeter exists because PR #529 commit B6 (d68a0f14) message claimed « closes the silent FATCA bypass » but the audit (subagent a80125307) found that `score_response()` and `check_archetype_aware()` have **zero production callers** :

```bash
$ grep -rn "score_response\|check_archetype_aware" services/backend/app
# (empty — no hits outside doctrine_checks.py itself)
```

So the guard exists in code, fails on empty archetype as expected, but is never invoked at runtime. The bypass remains open.

## Truth-in-claim retractation (per CLAUDE.md §9.1)

The B6 commit message at `dc987c4c` says « closes the silent FATCA bypass ». **This claim is overstated.** Actual delivery of B6 :

- ✅ Mobile-side : `CoachProfile.archetype` getter plumbed into `CoachContext` via new `_archetypeToBackendName()` helper at `coach_chat_screen.dart:1711-1730`
- ✅ Backend `claude_coach_service.py:793-798` consumes the archetype on truthy gate — LLM prompt context now reflects user's real archetype (not « swiss_native » default lie)
- ❌ Post-LLM `doctrine_checks.score_response()` not wired to runtime — guard exists but never invoked

So **B6 delivers ~50 % of claimed value** : prompt input is more accurate, but post-output safety net is still defensive-only.

## 5 gates mécaniques

| Gate | Description | Évidence |
|---|---|---|
| G1 | sim walker — expat_us scenario : assert response with « 3a » imperative without FATCA cue is BLOCKED at runtime (vs current : silently shipped) | promptfoo `fatca_3a_no_recommendation.yaml` from O5 audit recommendation |
| G2 | device by Julien — confirm archetype-aware responses on his expat_us seed account (manual verify) | TestFlight |
| G3 | dev CI green — flutter analyze + pytest backend (incl. new doctrine wiring tests) | run green |
| G4 | regression tests — score_response is invoked once per LLM response in coach_chat.py agent loop | new test asserts the call site is hit |
| G5 | LSFin/accent/ARB lint — no banned-term regression introduced | banned_terms_arb exit 0 |

## Tâches breakdown

| # | Action | Effort | Dépendance |
|---|---|---|---|
| B8.1 | Decide wire location : (a) `coach_chat.py` agent loop final-turn response post-process OR (b) `RAGOrchestrator.query()` post-filter step. (a) is closer to user-visible response, (b) is more centralized | 0.1j | None |
| B8.2 | Implement the wire — `score_response(response_text, QuestionMeta(archetype=ctx.archetype, …))` after LLM emits final text but before client return | 0.3j | B8.1 |
| B8.3 | Decide what to do on FAIL — options : (a) log audit signal only (passive), (b) replace response with safe fallback, (c) re-prompt LLM with stricter system prompt + cite the missed cue | 0.2j | B8.2 |
| B8.4 | Change `QuestionMeta.archetype` default at `doctrine_checks.py:75` from `"swiss_native"` to `""` so bare `QuestionMeta()` triggers fail-loud (closes Risk #2 from a80125307 audit) | 0.05j | None |
| B8.5 | Add integration test : `tests/test_doctrine_runtime_wire.py` — assert `score_response` is invoked on coach_chat response, mock LLM to return banned 3a-imperative for expat_us, assert response is rejected/replaced/re-prompted per B8.3 decision | 0.3j | B8.2+B8.3 |
| B8.6 | Add agent-loop assertion : empty answer + no tool_calls + no end-turn → never sent to client (Risk #3 from a80125307 audit) | 0.1j | None |
| B8.7 | Add `_archetypeToBackendName` round-trip integration test — mobile-side enum → backend snake_case → `QuestionMeta.archetype` matches | 0.1j | None |
| B8.8 | Update `coach_chat.py` commit message OR add comment retraction at the call site documenting the B6 audit gap closed by this perimeter | 0.05j | B8.2 |

**Total estimé** : ~1 j (sans la phase G2 device verify).

## Counter-arguments and data gaps

- **Risk 1** : Wire at `coach_chat.py` agent loop adds latency (each turn now scores response). Mitigation : score in parallel with the response stream, or post-stream-end. Measure latency delta with first wire commit.
- **Risk 2** : On FAIL response, what's the right action ? Replacing the response with a canned « FATCA disclaimer + retry » is better than letting it ship, but worse than catching pre-emit. Best practice (per Anthropic constitutional AI patterns) is re-prompt with stricter system prompt cite the missed cue. But re-prompt costs a 2nd LLM round-trip ($$).
- **Risk 3** : The `_ARCHETYPE_CUES` dict in `doctrine_checks.py:288-321` defines the regex per archetype. If a cue is too restrictive (e.g. requires literal « FATCA »), an LLM that says « tu déclares aux US » would PASS the cue check semantically but fail the regex. Calibrate with real LLM samples post-wire.
- **Risk 4** : Wire B8.4 (default to `""`) might break test fixtures that called bare `QuestionMeta()` expecting swiss_native. Need to grep + update test fixtures.
- **Data gap** : No telemetry yet on actual FATCA-relevant turns — without the wire we can't measure how often the bypass would have fired. Only after B8 ships can we observe.
- **Truth-in-claim** : The B6 commit dc987c4c message is now inaccurate but cannot be amended (already merged + pushed). Mitigation : this STUB is the audit log, retraction is preserved.

## Approval gate

À ouvrir comme PR séparée post-Julien G2 confirm sur TestFlight v2.12.2+4. **Pas avant.**

Reasonably : G2 confirm = the user-facing B1-B4 fixes work. THEN we open B8 to close the runtime gap on the post-LLM safety net.

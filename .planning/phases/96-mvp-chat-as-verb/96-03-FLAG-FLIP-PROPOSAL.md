---
phase: 96
plan: 03
type: flag-flip-proposal
flag: chatTabVisible
proposed-value: false
target-environment: prod
status: proposed
created: 2026-05-11
mirrors-template: .planning/phases/94-mvp-citation-gate/94-03-FLAG-FLIP-PROPOSAL.md
---

# Phase 96 — chatTabVisible → false (prod) flag-flip proposal

> Per CONTEXT D-11 + D-21 — kill-switch infrastructure shipped in Plan
> 96-01 ; flip authorised only after the 5-row eligibility checklist
> below clears AND the 7-day staging baseline pull shows cap-hit rate
> ≤ 40 % of sessions.

## Disposition

**Proposed — NOT yet approved.** The flag remains at its production
default (`true`, 4-tab nav unchanged) until :
- All 7 eligibility rows below tick ✓.
- The 7-day staging baseline-pull (D-11) shows `chat_turn_distribution`
  with cap-hit rate **≤ 40 %** of sessions OR Julien explicitly
  authorises a flip with a higher cap-hit rate after reviewing the
  walkback path.
- G2 Julien sim walkthrough returns `approved` (token recorded in
  `96-HUMAN-UAT.md`).

## Eligibility checklist (D-23..D-28)

| # | Gate | Status | Citation |
|---|------|--------|----------|
| 1 | G1 Maestro `flow_card_action_intent_bar.yaml` exits 0 on iPhone 17 Pro sim against staging Railway | ⬜ DEFERRED — flow authored at `tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml` (commit `8ab24f96`) ; live run requires (a) `chatTabVisible=false` on staging /config/feature-flags AND (b) production card list to carry stable testIDs (`card_mon_3a_2026`, `mint_chat_overlay`, `chat_input_field`, etc.) — both deferred per Plan 96-01 SUMMARY §Architectural call. G2 (row 2) is the authoritative end-to-end gate. | `tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml` |
| 2 | G2 Julien sim walkthrough on TestFlight | ⬜ PENDING — Task 4 checkpoint of Plan 96-03 ; verdict recorded in `96-HUMAN-UAT.md` | `.planning/phases/96-mvp-chat-as-verb/96-03-PLAN.md` §Task 4 |
| 3 | Plans 96-01 + 96-02 + 96-03 merged to `dev` | ⬜ PENDING — current state is branch `feature/S94-mvp-citation-gate` with all 3 plans' commits ; PR to `dev` post-G2 approval | `git log --oneline \| grep -cE '96-01\|96-02\|96-03'` ≥ 12 on branch (4 + 4 + 4 = 12 expected) |
| 4 | Full backend pytest ≥ 6586 + Phase 94 (181) + Phase 95 (74) byte-identity preserved | ✅ green | `cd services/backend && .venv/bin/python -m pytest tests/ -q --tb=no --ignore=tests/integration --ignore=tests/test_property_invariants.py` → 6586 passed, 60 skipped, 1 xfailed |
| 5 | accent_lint_fr + banned_terms_python + metaphor_parity + pii_fixture_scan green on all Phase 96 artefacts | ✅ green | `python3 tools/checks/metaphor_parity.py --scan-values` → OK ; `python3 tools/checks/accent_lint_fr.py --file services/backend/app/services/coach/narrative_sleeve_lint.py` → exit 0 ; `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/{narrative_sleeve_lint,metaphor_lookup}.py` → exit 0 |
| 6 | 6-locale ARB parity (verbExplique / verbSimule / verbRassure across fr/en/de/es/it/pt) | ✅ green | `python3 tools/checks/arb_parity.py` → 6 locale parity, 6750 keys each (Plan 96-01 SUMMARY citation) |
| 7 | D-26 grep gate (zero hardcoded ARGB literals in MintCardActionBar + MintChatOverlay) | ✅ green | `grep -c 'Color(0x' apps/mobile/lib/widgets/mint_card_action_bar.dart apps/mobile/lib/widgets/mint_chat_overlay.dart` → `0` on both |

## 7-day baseline pull (D-11)

Status : **EMPTY — pending staging traffic.**

Per D-11, before flipping `chatTabVisible=false` to prod, query the
staging Sentry dashboard over a 7-day rolling window :

```
category:coach.chat_overflow.turn_4
```

Compute :
- `total_cap_hits` — count of breadcrumb events.
- `total_chat_sessions` — count of distinct `(user_id, source_card_id)`
  tuples that generated at least one `/api/v1/coach/chat` call within
  the window.
- `cap_hit_rate = total_cap_hits / total_chat_sessions`.

**Decision matrix :**

| `cap_hit_rate` | Action |
|---|---|
| ≤ 0.40 | Flip authorised — schedule prod flag-flip via `/config/feature-flags` server override. Begin 4-week soak monitoring per D-21. |
| > 0.40 | Flag stays `true` ; surface to Julien with the actual rate. The cap is effectively no-op (no one hits it) OR users hit it too often — either way the chat-as-verb UX needs a longer turn budget. Re-tune (raise to 5 ?) before flipping. |

Today the baseline is empty because :
- Staging Railway has only just received the Plan 96-02 W2 deploy
  (commit chain `b81172a3..89430791` per Plan 96-02 SUMMARY).
- Plan 96-03 W3 has not been deployed to staging at the time of this
  proposal's authoring (the branch is `feature/S94-mvp-citation-gate`
  and the staging deploy chain is `feature → dev → staging`).
- Even after deploy, no real-user traffic against the staging app
  has exercised the cap path yet — the cap only triggers on the 4th
  consecutive turn against the same `source_card_id`.

**Backfill plan** : after a Plan 96-03 staging deploy, run G1 Maestro
once + a 1-week organic-traffic window before re-querying the
breadcrumb count.

## Walkback path (D-21)

Walkback is server-driven via `/config/feature-flags` override :
1. Operator (Julien) sets `chatTabVisible=true` on the Railway staging
   service environment (or directly via the admin /config endpoint).
2. Mobile clients pick up the new value on the next `refreshFromBackend`
   tick (6-hour periodic timer per `feature_flags.dart:14`) OR on the
   next cold launch — whichever happens first.
3. `MintShell.NavigationBar` rebuilds with 4 tabs ; the GoRouter branch
   list was never touched (D-02), so no route re-registration needed.
4. In-flight conversations in `ConversationStore` are preserved per D-03
   — Provider state survives the rebuild. The walkback test
   (`apps/mobile/test/services/feature_flags_walkback_test.dart`) pins
   this contract with 5 test cases :
   - Test 1 — true flip → 4-tab nav restored.
   - Test 2 — false flip → 3-tab nav, Coach hidden.
   - Test 3 — full false → true → false cycle preserves final state.
   - applyFromMap key-absent → flag untouched.
   - applyFromMap non-bool → strict-true convention applied (flag → false).

Test command : `cd apps/mobile && flutter test test/services/feature_flags_walkback_test.dart` → 5 / 5 passed (commit pending in T3).

## G1 Evidence block

Maestro G1 live-run is DEFERRED — see eligibility row 1 above. The
authored flow at `tools/simulator/flows/maestro-perfect-set/flow_card_
action_intent_bar.yaml` is the contract artifact ; live exit-0 will
materialise once the demo-screen testIDs are wired to the production
card list (post-v2.9 content sprint) AND chatTabVisible=false is set on
staging /config/feature-flags.

Sentry staging dashboard verification (post-G1-live) :
- URL : (paste here once a Plan 96-03 staging deploy exercises the cap path)
- Event category : `coach.chat_overflow.turn_4`
- Payload : `{source_card_id: str, turn_count: int}` — non-PII (Plan
  96-02 T3 commit `bbcf0853` enforces).

## GO / NO-GO row

| Token | Disposition | Effect |
|-------|------------|--------|
| `approved` | Phase 96 closes ; v2.9 Chat-as-Verb Pivot milestone marked SHIPPED on ROADMAP.md ; TestFlight ship path activates (memory `project_testflight_ship_path`). The `chatTabVisible=false` flag-flip is then a SEPARATE post-G2 operator decision gated on the 7-day baseline pull. | Phase 96 ships ; flag stays `true` on prod by default until baseline pull. |
| `approved-with-issues: <description>` | Phase 96 closes with documented residuals ; issues moved to backlog 999.x. The flip path is gated on residual resolution + baseline pull. | Phase 96 ships PARTIAL ; flag stays `true` ; residuals filed. |
| `not approved — issue: <description>` | Phase 96 returns to revision mode ; the orchestrator routes to `/gsd-plan-phase 96 --gaps` with the specific issue as input. | Phase 96 NOT shipped ; revision plan opens. |

Awaiting Julien's verdict at the Task 4 checkpoint.

---
*Phase : 96-mvp-chat-as-verb*
*Plan : 03 — Wave 3 close-out*
*Mirrors : `.planning/phases/94-mvp-citation-gate/94-03-FLAG-FLIP-PROPOSAL.md`*

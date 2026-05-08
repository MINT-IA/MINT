# P2 Engineering / Wiring Audit — 2026-05-07

**Auditor role:** Senior Flutter / Dart + Python / FastAPI engineer
**Branch under audit:** `fix/sim-walkthrough-crash-loop` (= origin/dev tip + 1 docs commit)
**Scope:** verify P2 « anon-chat surprise » fix wave is real wiring, not façade-sans-câblage (the W14 anti-pattern that supprimait 72 fichiers).

## Verdict: **FLAG** — 4 PRs ship real product wiring, but PR #507 plants a dead `clean_message_for_audit` variable presented in PR copy as « kept for the audit log hash » when no audit log consumer exists for `anonymous_chat.py`. The product-facing claim (LLM sees raw text) is WIRED. The compliance-facing claim (audit hash uses scrubbed text per OAR-G art. 24) is FAÇADE — there is no Phase 93-01 audit hook on the anonymous endpoint at all.

## G-mapping (P2)

| Gate | Status | Evidence |
|---|---|---|
| G1 (sim walker) | ✅ | PERIMETERS.md P2 entry — 2026-05-07 17:13 footer copy verified post-fix |
| G3 (CI green on dev) | ✅ | All 4 PRs (#507, #510, #513, #514) merged to dev |
| G4 (regression tests) | ✅ | 7/7 anon-chat backend, 21/21 flutter screen, 11/11 prompt-shape tests, 125/125 coach suite — all green locally |
| G5 (LSFin + accent + ARB lint) | ⚠️ | New `coachTransparencyServer` keys are LSFin clean across 6 locales. ARB parity test green. Accent lint shows 282 pre-existing violations repo-wide (none on P2 PRs surfaces), so P2 doesn't worsen the picture but the global lint is RED |

## Per-claim verdict

### 1. PR #507 — W-03 anon-chat PII scrub stop

- **LLM input claim (raw text reaches orchestrator):** **WIRED** ✅
  - `services/backend/app/api/v1/endpoints/anonymous_chat.py:270` passes `body.message` (raw) to `orchestrator.query(question=...)`.
  - `_scrub_pii` is applied only to `clean_message_for_audit` at line 252.
  - Regression test `tests/test_anonymous_chat_pii_scrub_does_not_block_llm.py` (104 lines, 2 tests) asserts `"7500 CHF" in question` and `"[***]" not in question`. **Real assertion against the LLM call args via `mock_query.call_args.kwargs.get("question")`.**

- **Audit-log hash claim (« kept for the audit log hash, OAR-G art. 24 »):** **FAÇADE** ❌
  - `anonymous_chat.py:252` computes `clean_message_for_audit` and **never reads it back**. Confirmed by `grep -n "clean_message_for_audit"` — single hit, the assignment.
  - There is no `coach_message_audit` / `prompt_hash` / `hash_for_audit` consumer reachable from the anonymous endpoint. Phase 93-01 audit hooks (`services/backend/app/api/v1/endpoints/coach/...`) only cover the authenticated coach.
  - The PR copy and inline comment ("It is used for any artefact that persists beyond the live conversation (audit log hash, future Sentry / Anthropic log surfaces)") are aspirational, not implemented.
  - **Severity:** PARTIAL 🟡 — does not break the user-facing fix, but the LSFin / OAR-G compliance story for the anonymous endpoint is overstated. The walker-bug fix is real; the « 10y retention scrubbed hash » story is documentation theater.

### 2. PR #510 — W-10 « ordre de grandeur » rule ported to auth coach

- **WIRED** ✅
  - `services/backend/app/services/coach/claude_coach_service.py:543-553` (rule #6 inside `_BASE_SYSTEM_PROMPT` / `RÈGLES DE CONFORMITÉ` block).
  - Carve-out present at line 552-553: rule does NOT apply to user-typed numbers nor injected constants. This is the exact carve-out the W-09 / W-14 contract needs to coexist with the « ordre de grandeur » rule without over-qualifying user salary.
  - Test `tests/coach/test_claude_coach_prompt_has_ordre_de_grandeur_rule.py` (5 tests): asserts rule presence, Swiss examples (médiane / taux d'imposition), location inside `RÈGLES DE CONFORMITÉ` between heading and `MOTEUR 4 COUCHES`, and the carve-out wording. All 5 pass.
  - Confirmed via runtime: `build_system_prompt(ctx=None)` returns prompt containing « ordre de grandeur ».

### 3. PR #513 — W-09 honest tier-aware footer

- **WIRED** ✅ (with a small test gap)
  - 6-locale ARB parity: FR / EN / DE / ES / IT / PT all carry `coachTransparencyServer`. Verified via `grep -c "coachTransparencyServer" apps/mobile/lib/l10n/app_*.arb` → 1 per file.
  - Surface widget: `apps/mobile/lib/screens/coach/coach_chat_screen.dart:2306-2312` switches on `msg.tier`:
    - `ChatTier.slm` → `coachTransparencySLM`
    - `ChatTier.byok` → `coachTransparencyBYOK`
    - `ChatTier.fallback` → `coachTransparencyServer` (the new honest copy)
    - `ChatTier.none` → `''`
  - The previous binary `slm ? SLM-copy : BYOK-copy` switch is gone. The bug (server-key path mislabeled as BYOK) cannot reoccur.
  - LSFin scan on the new key: zero banned terms across all 6 locales. EN copy avoids « NOT sent », FR copy avoids « pas envoyé » — both asserted by the parity test.
  - **Test gap:** parity test guards the data layer only. There is no widget test that pumps `CoachChatScreen` with a `tier=ChatTier.fallback` message and asserts `find.text(coachTransparencyServer)` renders. PARTIAL 🟡 on the « widget asserts the localized footer renders » contract specifically, fully WIRED on the data + switch contract.

### 4. PR #514 — coach prompt user-message numbers anchor

- **WIRED** ✅
  - `services/backend/app/services/coach/claude_coach_service.py:492-501` inside `_BIOGRAPHY_AWARENESS` (« IMPORTANT (P2 walkthrough fix 2026-05-07) ») clarifies that the « no biographical data » rule does NOT cover numbers typed in the current chat message, and explicitly forbids the « je ne peux pas voir ton salaire » and « semble que l'information n'ait pas été transmise correctement » framings.
  - Test `tests/coach/test_claude_coach_user_message_numbers_rule.py` (4 tests): asserts (a) prompt instructs LLM to use current-message numbers, (b) explicitly forbids the misleading framings, (c) rule ships in base prompt with `ctx=None`, (d) « transmise correctement » is named in the rule. All 4 pass.
  - Note: this is a prompt-shape test, not an eval. It does not assert that the LLM actually anchors on `9500 CHF` when fed a real Anthropic call. That gap is shared with all prompt rules and is out of scope for the P2 fix.

### 5. financial_core source-of-truth (CLAUDE.md règle 4)

- **WIRED** ✅
  - The 33% rule that surfaced in the W-09 walker case (« règle tacite veut qu'on ne dépasse pas 33% ») is delivered via the LLM prompt as a Swiss banking convention — not as an inline `_calculate*()` call in `claude_coach_service.py` or `anonymous_chat.py`.
  - `apps/mobile/lib/services/financial_core/housing_cost_calculator.dart` exists and is the source of truth for app-side affordability calculations when a user opens a simulator.
  - No P2-related backend code re-implements the affordability ratio. Règle 4 not violated.

## Test gaps (numbered)

1. **Anonymous endpoint audit-hash hook missing.** `clean_message_for_audit` is computed and discarded. Either (a) plumb it into a Phase 93-01-style audit hook for `anonymous_chat.py`, or (b) drop the variable + the « audit log hash » comment to stop overpromising compliance posture.
2. **Coach footer widget test missing.** No widget test pumps `CoachChatScreen` with a `ChatTier.fallback` message and asserts `find.text(S.of(context).coachTransparencyServer)` is in the tree. The parity test guards data; no test guards the rendering path. A regression in the switch (e.g. dropping the `ChatTier.fallback` branch) would not be caught.
3. **Adversarial-input « rich numbers » LLM eval missing.** No fixture pipes « Mon salaire est 9500 CHF, j'ai 850k de budget, mon LPP est 150k » through the live prompt and asserts the response contains all three numbers. The prompt-shape tests only check that rules are *present* in the prompt, not that the LLM honors them. This is the exact bug the walker caught, and a prompt rule change down the line could silently regress it.
4. **No accent lint baseline guard for new ARB keys.** Repo-wide accent lint is RED with 282 pre-existing violations; the P2 keys happen to be clean but there is no per-file or per-key baseline test gating P2 surfaces specifically.
5. **No flutter analyze run captured in this audit.** Only flutter test was run. A future regression that only `flutter analyze` would catch (e.g. a missing branch in the `switch (msg.tier)` exhaustiveness check) would slip past G4 as currently scoped.

## Top priority test to add

**Adversarial LLM eval: 3-number anchor.** Fixture pipes « salaire 9500 CHF, projet 850k, LPP 150k » through `build_system_prompt` + a stubbed Anthropic call; assert the model output contains all three figures and avoids the « je ne peux pas voir ton salaire » / « pas été transmise correctement » phrasings. Exact regression for W-09 / W-14.

## Exec summary

P2 ships 4 merged PRs; 3 are wired end-to-end (#510, #513, #514) and verified by 11 backend + 5 flutter ARB tests, all green. PR #507 fixes the user-facing P0 (LLM now sees `7500 CHF` as raw text — confirmed by 2 regression tests asserting `mock_query.call_args.kwargs["question"]`), but plants a `clean_message_for_audit` variable that is never consumed. The PR copy and inline comment frame this as the OAR-G art. 24 audit-log hash, yet no audit consumer exists on the anonymous endpoint. This is a documentation-theater FAÇADE on the compliance side, not a product-side façade — the user gets the personalized response. G1 verified by sim walker, G3 / G4 green, G5 partial (P2 keys clean, repo-wide accent lint RED for unrelated reasons). Top gap is the missing « rich-numbers anchor » LLM eval that would catch a future prompt-rule regression. Recommend: (a) drop the dead audit variable + comment OR plumb it into a real Phase 93-01-style hook, (b) add the adversarial eval, (c) add one widget test for `coach_chat_screen.dart` switch on `ChatTier.fallback`.


## Counter-arguments and data gaps

This artifact was synthesised from a single audit pass on 2026-05-07 — it benefits from a healthy dose of skepticism :

- **Sample-of-one bias** : the verdict is driven by one walk on one device (iPhone 17 Pro sim). On real devices, network conditions, OS variants, accessibility settings, or carrier prompts may surface failure modes this pass did not exercise.
- **Confirmation bias risk** : the panel was looking for the bugs from the prior session ; positive findings (« looks fine ») were not stress-tested with adversarial inputs in the same depth as the negative findings.
- **Data gap — production telemetry** : we have no Sentry / staging logs cross-reference for this perimeter ; conclusions about « no regression » are based on absence of visible UI errors, not on instrumentation.
- **Data gap — second reviewer** : no independent re-walk by a second human or sim has corroborated the verdict. Treat as a working hypothesis, not a final ruling, until the next walker run.
- **Counter-argument worth holding** : the « PASS » on items relying on best-effort fallbacks (keychain, biography, consent) hides the fact that the fallback path is the *real* code path on the sim — production-iOS behavior may differ. Prefer running on a real device before claiming the panel is closed.

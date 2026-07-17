# MINT External Audit — Code Mode

**Scope:** COACH-01 inline amount write (durable persistence of salary / LPP / 3a entered inline in coach chat), async submission UX, strict-LPP authority guard, l10n, and runtime-evidence tooling.

## Verification performed
- Confirmed the write is genuinely wired (no facade): `_handleInputSubmitted` → `applySaveFactWithResult` → `_mergeAnswersWithProvenanceIfAllowed` → serialized `_mutateTaxAnswers` → persistence. Cold-reload provenance asserted in `coach_inline_amount_write_contract_test.dart` and the Patrol contract.
- `_validRemoteAmount` exists and enforces `finite && >=0 && <=10_000_000` (`coach_profile_provider.dart:2281`); ceiling/negative/non-finite rejection is covered by tests with 0 save attempts.
- Strict-LPP guard: precondition `!current.containsKey(_lppEvidenceRootKey)` runs *inside* the serialized mutation (`:3394`), so the TOCTOU case (`injectStrictLppRootBeforeNextMutation`) is closed atomically — verified by test.
- Reconciliation route `/scan?type=lppCertificate` resolves: `/scan` reads `queryParameters['type']` and matches `DocumentType.lppCertificate`, which exists (`document_models.dart:18`, `app.dart:1196`).
- Async callback signature change (`void`→`Future<void>`) propagated consistently across `widget_renderer.dart`, `coach_message_bubble.dart`, and the single wire site `coach_chat_screen.dart:1987`.
- Double-tap/loading, transient-failure retry, and error live-region all covered by widget tests.
- New l10n keys exist in the FR template (with metadata + placeholders) and are implemented in every generated `app_localizations_*.dart`.

## Findings

### P0 — none

### P1 — none

### P2 (non-blocking)
- **Salary field semantic change (correctness fix, confirm backend intent).** Previously the inline `salary` picker stored to `q_net_income_period_chf` (net monthly) despite the label "Ton revenu brut annuel" — a pre-existing mismatch. `widget_renderer.dart` now routes both `salary` and `salaireBrut` to canonical `incomeGrossYearly` → `q_gross_salary_annual` (gross annual), matching the label. This is an improvement, but if the backend still emits `ask_user_input(field_key:'salary')` expecting net-monthly capture, the meaning of that tool call silently changed. Worth confirming the coach tool contract. Evidence: `widget_renderer.dart` salary/salaireBrut cases; `coach_chat_screen.dart` `_handleInputSubmitted` switch.
- **Error state set after picker removal on the rare `_sendMessage` throw.** In `_handleInputSubmitted`, `_answeredInputIndices.add` runs before `await _sendMessage(...)`; if `_sendMessage` throws, the fact is already persisted and the picker already replaced, then `ChatAmountInput._submit` surfaces a "save failed" error on an about-to-be-disposed widget (guarded by `mounted`, so no crash). Cosmetic only.
- **Non-template ARBs carry `@`-metadata for the echo keys.** Harmless with `gen_l10n`, but inconsistent with the repo convention of keeping metadata in the FR template only.

## Verdict

**PASS**

The change is correctly wired end-to-end, fails closed on invalid amounts and strict-LPP conflicts, preserves the 12/13-period and 10M-ceiling authority, and is backed by unit, widget-contract, and runtime-evidence tests. No privacy, routing, or facade-without-wiring defects found. The P2 items are follow-ups, not blockers.

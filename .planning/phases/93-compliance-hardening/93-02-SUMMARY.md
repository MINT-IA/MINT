---
phase: 93-compliance-hardening
plan: 02
subsystem: backend-compliance + mobile-l10n
tags: [FATCA, FBAR, PFIC, expat_us, COMP-04, BUG-22-P1, OAR-G, FINMA]
requires:
  - p93_coach_message_audit (Plan 93-01 — audit-log infrastructure)
  - CoachMessageAudit model + hash_for_audit()
provides:
  - app.services.coach.fatca_gate.{_topic_is_fatca_sensitive, build_fatca_handoff_card, FatcaHandoffPayload}
  - tool_call kind="fatca" routed via show_handoff_card
  - 18 ARB entries (3 keys × 6 locales) — fatcaHandoffTitle / Body / Cta
  - apps/mobile FatcaHandoffCard StatelessWidget
affects:
  - /api/v1/coach/chat — Step 2.5 pre-emission gate inserted between
    system_prompt log (line ~2469) and orchestrator init (now line ~2566)
  - audit-log corpus — gate fires write a row with eclairage_kind="fatca_handoff"
  - Sentry breadcrumb stream — category "compliance.fatca_gate" feeds the
    Phase 96 dashboard
tech-stack:
  added: []
  patterns:
    - Pre-emission gate (archetype + topic regex) BEFORE orchestrator call
    - Best-effort audit row reusing Plan 93-01 infra (try/except + Sentry capture)
    - Localized strings mirrored in backend dict + mobile ARB (drift-tested)
    - Word-boundary regex (`\b...\b`) over FATCA tokens to avoid over-blocking
    - Word-boundary banned-term scan in widget test (FR/DE compounds)
key-files:
  created:
    - services/backend/app/services/coach/fatca_gate.py
    - services/backend/tests/test_fatca_pre_emission_gate.py
    - services/backend/tests/test_fatca_gate_negative_topic.py
    - services/backend/tests/test_fatca_gate_negative_archetype.py
    - apps/mobile/lib/widgets/handoff/fatca_handoff_card.dart
    - apps/mobile/test/widgets/handoff/fatca_handoff_card_test.dart
  modified:
    - services/backend/app/api/v1/endpoints/coach_chat.py
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb
    - apps/mobile/lib/l10n/app_localizations.dart (regen)
    - apps/mobile/lib/l10n/app_localizations_fr.dart (regen)
    - apps/mobile/lib/l10n/app_localizations_en.dart (regen)
    - apps/mobile/lib/l10n/app_localizations_de.dart (regen)
    - apps/mobile/lib/l10n/app_localizations_es.dart (regen)
    - apps/mobile/lib/l10n/app_localizations_it.dart (regen)
    - apps/mobile/lib/l10n/app_localizations_pt.dart (regen)
decisions:
  - tool_call shape uses {name, input} (existing Anthropic shape used by mobile dispatcher), NOT {tool, args} as the plan suggested
  - Backend mirrors the localized strings inline so older mobile builds without the FatcaHandoffCard widget still see the FATCA text in `message` (graceful degradation); newer mobile builds can render via ARB key lookup
  - Banned-term scan uses Unicode word boundaries (negated `\p{L}\p{N}` classes) so legitimate compound nouns (DE "Doppelbesteuerung") don't false-positive on substrings ("beste")
  - AppLocalizations symbol on this codebase is named `S`, not `AppLocalizations` (mint_mobile generated naming) — widget + test use `S.of(context)`
metrics:
  tasks-completed: 2
  tests-added: 22 backend + 9 mobile widget = 31
  duration-mins: ~50
  completed: 2026-05-07
---

# Phase 93 Plan 02: FATCA pre-emission gate + handoff card Summary

When archetype == ``expat_us`` AND the user message matches the FATCA
topic regex (3a / pillar 3a / PFIC / treaty / FBAR / foreign trust /
form 3520), the coach LLM call is now short-circuited at Step 2.5 and a
localized FATCA hand-off card is returned instead. Closes COMP-04 and
BUG #22 P1 (USER_WALKTHROUGH_2026-05-06). Aligns with the existing
post-validation rule in `doctrine_checks.py:291` (which only catches
issues *after* the LLM emits text). Reuses the Plan 93-01 audit
infrastructure to persist a row with `eclairage_kind="fatca_handoff"`
on every gate fire. Sentry breadcrumb fires under category
`compliance.fatca_gate` so Phase 96 can monitor gate fire-rate and
topic distribution.

## Deliverables

1. **`services/backend/app/services/coach/fatca_gate.py`** — new
   service module providing `_topic_is_fatca_sensitive(text)` (returns
   the matched topic label or `None`) and `build_fatca_handoff_card(language)`
   (returns a `FatcaHandoffPayload` with localized message + tool_call).
   6 locales mirrored from the ARB. All 18 strings free of LSFin banned
   terms; FR uses proper diacritics.
2. **`services/backend/app/api/v1/endpoints/coach_chat.py:2471-2561`** —
   Step 2.5 pre-emission gate inserted between the `system_prompt_length`
   log and orchestrator init. Reads archetype from `safe_profile` (or
   `coach_ctx`), runs the regex against `sanitized_message`, returns a
   `CoachChatResponse` with `tool_calls=[show_handoff_card]` and
   `response_meta.model_used="fatca_handoff_gate"`. Best-effort audit row
   + Sentry breadcrumb on every fire. Wrapped in try/except so the gate
   never breaks the response path (Karpathy practice 3).
3. **3 backend pytest files (22 tests, all green)** — positive path
   (regex match table, banned-term scan, FR diacritics, response shape,
   audit row insertion, Sentry breadcrumb capture) + 2 negative paths
   (`expat_us` + budget question → LLM proceeds; `swiss_native` + PFIC
   → LLM proceeds, gate is archetype-scoped).
4. **18 ARB entries** in all 6 locales (`app_{fr,en,de,es,it,pt}.arb`).
   `flutter gen-l10n` regenerated `app_localizations*.dart` with 3 new
   accessors per locale.
5. **`apps/mobile/lib/widgets/handoff/fatca_handoff_card.dart`** —
   `FatcaHandoffCard` StatelessWidget. Pure UI, takes optional
   `onCtaTap`. Uses `S.of(context)!` for i18n, `MintColors` + `MintTextStyles`
   for theme. Wrapped in `Semantics(container: true, label: title)` for a11y.
6. **`apps/mobile/test/widgets/handoff/fatca_handoff_card_test.dart`** —
   9 tests: render under all 6 locales, CTA tap callback, 18-string
   banned-term scan with word boundaries, FR diacritic hygiene.

## Test Counts

| Bucket                                          | Before | After  | Delta |
| ----------------------------------------------- | ------ | ------ | ----- |
| Plan-93-02 backend FATCA tests                  | 0      | 22     | +22   |
| Plan-93-02 mobile widget tests                  | 0      | 9      | +9    |
| Backend regression (audit + coach + compliance) | 168    | 168    | 0     |
| Mobile regression (widgets/coach + handoff)     | 728    | 737    | +9    |
| Full backend pytest (excl. integration)         | 6028   | 6050   | +22   |

Full backend suite: 6050 passing, 25 skipped, 1 pre-existing failure
(`test_compliance_wording.py::test_no_banned_words` flagging
`anonymous_chat.py:169` "Vocabulaire LSFin interdit" — already
documented as pre-existing in `93-01-SUMMARY.md`).

Full mobile widget run on `test/widgets/handoff/` + `test/widgets/coach/`:
737 / 737 green, 0 failures.

`flutter analyze` on `lib/widgets/handoff/` + `test/widgets/handoff/`: clean
(0 issues). Wider `flutter analyze` shows 142 pre-existing issues —
none in my new files (verified by grep).

## 4-person design panel verdict (per memory `feedback_design_panel_before_push.md`)

| Reviewer            | Verdict | Notes                                                                                                                                                                                                                              |
| ------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| UX                  | PASS    | Card structure (title / body / CTA) follows the established MINT card pattern. Body length acceptable for a one-shot hand-off. Tone uses « pourrait », « adapté » — no promise.                                                    |
| a11y                | PASS    | `Semantics(container: true, label: title)` makes the card a single semantic node with a meaningful label. Body + CTA are read in sequence by VoiceOver. Outlined button has visible focus ring (Material default). Contrast OK.    |
| Adversarial         | PASS    | Cannot be triggered by an attacker who flips archetype client-side: archetype comes from `safe_profile` server-side. Cannot be bypassed by topic camouflage: gate is permissive within the archetype (the LLM is the danger, not the response). |
| Engineering/wiring  | PASS    | tool_call shape matches existing dispatcher contract. Audit row reuses Plan 93-01 path. Sentry breadcrumb has category + structured data. Widget is pure-UI (no providers), trivially testable. Both ARB and backend dict are scanned for drift via the 18-string test. |

No critical fixes flagged. The widget ships as-is.

## Banned-term scan: 0 / 18 hits proof

Backend test `test_build_fatca_handoff_card_fr_contains_no_banned_terms`
asserts the 6-locale strings shipped from `fatca_gate.py` are
banned-term clean (FR/EN/DE/ES/IT/PT). Mobile widget test
`all 18 FATCA ARB strings are banned-term clean` asserts the 18 ARB
strings shipped from the 6 ARB files are banned-term clean using
Unicode word-boundary matching to avoid false positives on legitimate
compound nouns (e.g. DE "Doppelbesteuerung" embeds "beste" as a
substring — not a standalone violation). Both suites green: 0 hits.

`tools/checks/banned_terms_arb.py` (project-wide ARB linter) reports:

```
OK — 6 locale(s) clean (no positive LSFin banned-term uses).
```

## FR accent lint: green proof

`tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb`
returned no output (= no violations). FR strings shipped use proper
diacritics: « éclairage », « spécialisé », « décision », « spécialiste »
— all asserted in `test_build_fatca_handoff_card_fr_uses_proper_diacritics`
+ `FR strings use proper diacritics (CLAUDE.md règle 2)` widget test.

## Sentry breadcrumb sample

Captured during `test_fatca_gate_fires_for_expat_us_3a_question` via
`patch("sentry_sdk.add_breadcrumb")`:

```python
{
  "category": "compliance.fatca_gate",
  "message": "fatca_handoff_emitted",
  "data": {
    "archetype": "expat_us",
    "topic_match": "3a_or_pillar3a"
  }
}
```

Breadcrumb name: `fatca_handoff_emitted` (under category
`compliance.fatca_gate`). Phase 96 dashboard hook ready.

## Audit-log integration

Every gate fire writes a `coach_message_audits` row with:

| Column          | Value                              |
| --------------- | ---------------------------------- |
| session_id      | `str(_user.id)`                    |
| archetype       | `"expat_us"`                       |
| prompt_hash     | `hash_for_audit(sanitized_message)` |
| response_hash   | `hash_for_audit(handoff.message)`  |
| banned_term_hit | `False`                            |
| eclairage_kind  | `"fatca_handoff"`                  |
| created_at      | now(UTC)                           |
| retained_until  | now + 10y                          |

Asserted by `test_fatca_gate_fires_for_expat_us_3a_question` via
direct DB query against `TestingSessionLocal`. `eclairage_kind`
distinguishes the FATCA gate row from a normal coach response row
(which is `None`) and from the fiscal_margin_3a / default_premier
eclairage rows from `anonymous_chat.py`.

## ARB key names (3 of them)

1. `fatcaHandoffTitle` — card title (1 short line)
2. `fatcaHandoffBody` — multi-paragraph hand-off prose with FATCA + FBAR + PFIC + treaty
3. `fatcaHandoffCta` — outlined-button label

All three present in 6 ARB files = 18 entries. `flutter gen-l10n`
regenerated `app_localizations*.dart`; per-locale accessors verified
via grep.

## Deviations from Plan

### Deviation 1 — tool_call shape uses {name, input}, not {tool, args}

**Plan said:** ``{"tool": "show_handoff_card", "args": {"kind": "fatca", ...}}``.

**Reality:** existing `_execute_internal_tool` at `coach_chat.py:1222`
unpacks via `name = tool_call.get("name", "")` + `raw_input =
tool_call.get("input", {})`. The Anthropic native shape is
`{name, input}`, not `{tool, args}`. The plan referenced a different
naming convention.

**What I did:** ship `{"name": "show_handoff_card", "input": {...}}`
matching the existing dispatcher. Mobile parses the same shape it
already parses for `route_to_screen` and other Flutter-bound tools.

### Deviation 2 — Backend mirrors localized strings inline (graceful degradation)

**Plan said:** mobile renders via ARB key lookup; backend ships only
the keys.

**Reality:** older mobile builds without `FatcaHandoffCard` would have
shown an empty bubble if backend shipped only `*_key`. Karpathy
practice 1 (think before coding): an empty bubble in a compliance
hand-off is worse than a redundant string.

**What I did:** the `tool_call.input` ships BOTH the ARB keys AND the
literal localized strings. Newer builds use the keys (native typography
+ runtime locale change); older builds render the literal `message` in
the chat bubble. The 18-string scan test catches drift between backend
dict and ARB.

### Deviation 3 — AppLocalizations is named `S` on this codebase

**Plan said:** `AppLocalizations.of(context)!.fatcaHandoffTitle`.

**Reality:** the generated class on this codebase is `S` (see
`lib/l10n/app_localizations.dart:68`: `abstract class S { static S? of(BuildContext context) { ... } }`).
Other widgets in the repo (e.g. `widgets/coach/fri_radar_chart.dart:42`)
use `S.of(context)!`.

**What I did:** widget + test use `S.of(context)!` and
`S.localizationsDelegates` / `S.supportedLocales`. The class symbol
re-export was renamed by an earlier l10n migration.

### Deviation 4 — Banned-term scan uses Unicode word boundaries (compound-noun safe)

**Plan said:** simple `lower.contains(word)` substring check on each
of the 18 strings.

**Reality:** German "Doppelbesteuerung" (= double taxation) contains
"beste" as a 5-char substring. CLAUDE.md règle 1 forbids the
**standalone** use of « le meilleur / das Beste / il migliore » — not
their occurrence inside compound nouns where the meaning is unrelated.
First test run failed on DE.body for this reason.

**What I did:** test uses `RegExp(r'(^|[^\p{L}\p{N}])' + word + r'($|[^\p{L}\p{N}])', unicode: true)`
so the term must be standalone (preceded + followed by non-letter,
non-digit). The DE "Doppelbesteuerung" then passes correctly.

## Pre-push checklist

- [x] Word-boundary regex on FATCA topics (`\b...\b`) prevents over-blocking — asserted by `test_topic_regex_does_not_match_unrelated_messages`.
- [x] tool_call shape matches existing dispatcher — asserted by `test_build_fatca_handoff_card_tool_call_shape_matches_dispatcher`.
- [x] `python3 -m pytest tests/ -q --ignore=tests/integration` — green minus 1 pre-existing failure unrelated to this plan.
- [x] `flutter gen-l10n` ran; per-locale accessors regenerated.
- [x] `flutter analyze` on new files — clean (0 issues).
- [x] `flutter test test/widgets/handoff/` + `test/widgets/coach/` — 737 / 737 green.
- [x] `tools/checks/banned_terms_arb.py` — 6 / 6 locales clean.
- [x] `tools/checks/accent_lint_fr.py --file app_fr.arb` — green.
- [x] No endpoint response-shape change — no OpenAPI canonical regen needed (the new gate response uses the existing `CoachChatResponse` schema).

## Forward to Phase 95 (deferred but flagged)

- 4 promptfoo fixtures under `evals/fatca_handoff/*.yaml`:
  - `expat_us_3a_question.yaml` — assert hand-off card rendered, no LLM 3a impératif.
  - `expat_us_pfic_question.yaml` — same, with PFIC topic.
  - `expat_us_budget_question.yaml` — assert LLM is called normally (no over-block).
  - `swiss_native_pfic_question.yaml` — assert gate is archetype-scoped.
- These belong to the Phase 95 promptfoo runner, not Plan 93-02.

## Forward to Phase 97 (deferred but flagged)

- Maestro flow `lauren_expat_us_3a_handoff.yaml` — UI-level assertion
  that an `expat_us` Lauren persona typing « j'ai 70k de 3a » sees the
  FatcaHandoffCard, not a generic 3a impératif.
- FINMA Control Matrix row mapping COMP-04 → fatca_gate.py + breadcrumb
  + audit row.

## Self-Check: PASSED

- `services/backend/app/services/coach/fatca_gate.py` — FOUND
- `services/backend/tests/test_fatca_pre_emission_gate.py` — FOUND (20 tests)
- `services/backend/tests/test_fatca_gate_negative_topic.py` — FOUND (1 test)
- `services/backend/tests/test_fatca_gate_negative_archetype.py` — FOUND (1 test)
- `apps/mobile/lib/widgets/handoff/fatca_handoff_card.dart` — FOUND
- `apps/mobile/test/widgets/handoff/fatca_handoff_card_test.dart` — FOUND (9 tests)
- 6 ARB files modified with 3 new keys each — FOUND
- 6 generated `app_localizations_*.dart` regenerated — FOUND
- `services/backend/app/api/v1/endpoints/coach_chat.py` — modified (Step 2.5 inserted at line 2471)
- 22 / 22 backend FATCA tests green
- 9 / 9 mobile widget tests green
- 168 / 168 backend regression suite green
- 737 / 737 mobile coach + handoff regression green
- BUG #22 P1 closed
- COMP-04 closed

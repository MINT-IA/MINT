# Phase 94: Compliance Polish — Locale + i18n + Constants — Context

**Gathered:** 2026-05-06
**Status:** Ready for planning
**Mode:** Auto-generated from milestone synthesis (REQUIREMENTS.md COMP-02/05/06 + walkthrough BUG #12/20/23)

<domain>
## Phase Boundary

Three small, surgical compliance debts close the v2.14 audit gap before Phase 95 wires real test infra. Today: (1) `anonymous_eclairage_prompt.py` builds a FR-only éclairage card with no `language` argument, even though the request schema already carries `language` end-to-end (`AnonymousChatRequest.language: str = "fr"`) — non-FR users get FR text in violation of FinSA art. 8 al. 1 let. d ; (2) `app_en.arb` has 72 occurrences of « LSFin » where the English regulator name is « FinSA » (BUG #12 P3) ; (3) `benchmark_service.dart:118` ships the literal `7000` as a « near-3a-plafond » threshold instead of deriving it from `pilier3aPlafondAvecLpp` (BUG #23 P2). Out of scope : promptfoo wiring (Phase 95 TEST-01), DE/IT regulator-name re-verification by Swiss counsel (Phase 97), full constants audit across all services.
</domain>

<decisions>
## Implementation Decisions

### COMP-02 — Eclairage prompt locale branching

- File : `services/backend/app/services/coach/anonymous_eclairage_prompt.py`.
- Caller : single — `services/backend/app/api/v1/endpoints/anonymous_chat.py:344` already has `body.language` in scope.
- Signature change : `build_default_fiscal_margin_3a_eclairage(language: str = "fr") -> EclairagePayload` (additive, default preserves FR behaviour, zero-risk for existing FR test).
- Structure decision : **dict-based locale registry**, not branch-based. Define module-level `_ECLAIRAGE_BY_LANGUAGE: dict[str, dict[str, str]]` keyed on `"fr" | "de" | "it" | "en" | "es" | "pt"`, each value carrying `headline`, `body`, `soft_account_hint`. Keeps the function body 5 lines and makes locale parity grep-able. Numeric range (1500–2500/year) and `kind="fiscal_margin_3a"` stay locale-invariant.
- Fallback : if `language` not in registry → fall back to `"fr"` (current behaviour). Log once via `logger.warning` so missing-locale slips are visible without spamming.
- Banned-term contract : every locale variant MUST pass `compliance_guard.ComplianceGuard.BANNED_TERMS` — verified by unit test that runs each variant through the guard. Translations of « jusqu'à » / « pourrait » / « selon ton canton » must NOT introduce « garanti / optimal / best / sicher / migliore ».
- Test surface : `services/backend/tests/coach/test_anonymous_eclairage_prompt_locale.py` — 6 locales × 4 archetypes = 24 cases asserting (a) headline non-empty, (b) body contains the legal cap « CHF 7'258 » (locale-invariant figure), (c) banned-term scan green, (d) soft_account_hint non-empty, (e) no FR text leaking into non-FR variants (assert no « tu peux » in DE/IT/EN/ES/PT bodies). Promptfoo eval defer to Phase 95.

### COMP-05 — EN « LSFin → FinSA » sweep

- File : `apps/mobile/lib/l10n/app_en.arb` (only — FR/DE/IT/ES/PT keep their native regulator names : LSFin in FR, FIDLEG in DE, LSerFi in IT, no native regulator name in ES/PT today).
- Grep result : 72 occurrences of « LSFin » in `app_en.arb` (matches ROADMAP « ~60 » within tolerance).
- Suspect ARB key shapes (sample) : `unemploymentDisclaimer`, `financialSummaryDisclaimer`, `earlyRetirementDisclaimer`, `agentOutputDisclaimer`, `agentTaskDisclaimer`, `deuxViesDisclaimer`, `expertDisclaimer`, `frontalierDisclaimer`, `monteCarloDisclaimer`, anything ending `*Disclaimer` or `*description`.
- Sweep tactic : single `sed -i '' 's/LSFin/FinSA/g' app_en.arb`. The string « LSFin » appears nowhere as a key or as a substring of another regulator (verified : no « LSFinex », no « LSFinance ») so the global replace is safe.
- Special case : « LSFin art. 3 » → « FinSA art. 3 » (article numbering is identical in both FR + EN versions of the law, art. 3 = art. 3).
- Post-sweep : `cd apps/mobile && flutter gen-l10n` regenerates `app_localizations_en.dart`.
- Verification : (a) `grep -c LSFin app_en.arb` returns `0`, (b) `grep -c FinSA app_en.arb` returns ≥ 72, (c) FR/DE/IT/ES/PT grep counts unchanged (regression guard), (d) MCP `validate_arb_parity()` green, (e) optional simulator screenshot of EN landing screen for evidence HTML.

### COMP-06 — `benchmark_service.dart` literal kill

- File : `apps/mobile/lib/services/benchmark_service.dart` line 118 — `if (contribution >= 7000) {` (and the message « Tu es proche du plafond 3a »).
- **Discovery worth flagging** : the literal `7000` is NOT the plafond (`pilier3aPlafondAvecLpp = 7258.0` in `apps/mobile/lib/constants/social_insurance.dart:351`). It's a « near-the-cap » threshold that triggers the « tu es proche du plafond » message. ROADMAP says « replace with `pilier3aPlafondAvecLpp` constant » but a 1:1 swap (`>= 7258`) would change the message threshold and only fire when contribution is AT the plafond, breaking the « proche du plafond » UX semantic.
- **Decision** : introduce a named constant `pilier3aProchePlafondThreshold` in `social_insurance.dart`, defined as `pilier3aPlafondAvecLpp * 0.96` (= 6967.68, ≈ 7000). The « near-cap » band stays at ~96 % of plafond, gets re-derived automatically when OFAS bumps the plafond, kills the magic number, preserves the UX behaviour.
- Import to add at top of `benchmark_service.dart` : `import 'package:mint_mobile/constants/social_insurance.dart';`.
- Caller surface after grep : 0 other call sites of literal `7000` in `apps/mobile/lib/services/`. No regression risk on adjacent code.
- Test : `apps/mobile/test/services/benchmark_service_test.dart` — assert `compareContribution(contribution: 6967.68 + 0.01)` returns the « proche du plafond » message and pulls the constant (verify by re-importing the constant in the test). Add `grep -rn '7000\.0\?' apps/mobile/lib/services/` returns 0 hits as a meta-check.

### Claude's discretion

- **Locale fallback policy when a translation is uncertain** : prefer FR fallback over English fallback for a Swiss-financial product. If DE / IT / ES / PT phrasing for « marge fiscale 3a » needs Swiss-counsel review, ship the locale variant with a banner-free note in the test file but DO NOT fall back to EN — French is the canton-anchored default.
- **`pilier3aProchePlafondThreshold` exact value** : the « 96 % » derivation is the author's pick. Could equally be `pilier3aPlafondAvecLpp - 258` (giving exactly 7000) ; ship the multiplicative form (rounder semantically : « within 4 % of cap »).
- **Single plan vs two plans** : COMP-02 + COMP-06 are backend+mobile distinct ; COMP-05 is an ARB sweep. Recommend ONE plan with three small surfaces — total ~150 LOC across 4 files + ~80 LOC of tests. No need to fragment.
</decisions>

<code_context>
## Existing Code Insights

### Reusable assets

- `services/backend/app/schemas/anonymous_chat.py:116` — `language: str = Field(..., default="fr")` already exists end-to-end.
- `services/backend/app/services/coach/regional_microcopy.py` — generated 6-locale microcopy registry, exact dict-of-dicts pattern to mirror for éclairage.
- `services/backend/app/services/coach/claude_coach_service.py:762` — existing `if language and language != "fr":` branching, reusable idiom.
- `services/backend/app/services/coach/compliance_guard.py:BANNED_TERMS` — central list to scan all 6 éclairage variants against.
- `apps/mobile/lib/constants/social_insurance.dart:351` — `pilier3aPlafondAvecLpp = 7258.0`, plus `reg(key, fallback)` helper for backend-synced constant reads.

### Established patterns

- Backend localization is plain Python dicts keyed on `language` string (FR/DE/IT/EN/ES/PT) — NOT gettext, NOT ARB. Mobile uses ARB ; backend uses Python dicts. The éclairage payload is a Pydantic model emitted by the backend, so locale lives in Python-side code.
- Mobile localization : 6 ARB files in `apps/mobile/lib/l10n/`, regenerated via `flutter gen-l10n`. Generated files (`app_localizations_en.dart` etc.) MUST NOT be edited by hand.
- Constants : `social_insurance.dart` is the Flutter facade ; `services/backend/app/constants/social_insurance.py` is the backend mirror. `pilier3aProchePlafondThreshold` lives Flutter-side only (UI-display semantic).

### Integration points

- COMP-02 plug : `anonymous_chat.py:344` becomes `build_default_fiscal_margin_3a_eclairage(language=body.language)` — single line change in caller.
- COMP-05 plug : `app_en.arb` sed sweep + `flutter gen-l10n` → all consuming widgets pick it up automatically.
- COMP-06 plug : new constant in `social_insurance.dart`, import + `>= pilier3aProchePlafondThreshold` in `benchmark_service.dart:118`.
</code_context>

<specifics>
## Specific Ideas

- **Golden test per locale for éclairage** : snapshot the exact `EclairagePayload.body` for each of FR/DE/IT/EN/ES/PT into `tests/coach/golden_eclairage/{lang}.txt` so a regression on translation drift surfaces in PR diff, not in production logs.
- **EN regression assertion** : `test_arb_en_no_lsfin.py` (or a Dart unit test under `apps/mobile/test/l10n/`) asserts `app_en.arb` contains 0 « LSFin » substrings and ≥ 72 « FinSA » substrings — runs in CI, prevents future copy-paste of FR disclaimers into EN.
- **Benchmark unit test pulls from constant** : the test imports `pilier3aProchePlafondThreshold` directly and asserts `compareContribution(contribution: threshold)` produces the « proche du plafond » message — same-file regression guard.
</specifics>

<deferred>
## Deferred Ideas

- DE / IT regulator-name verification by Swiss counsel (FIDLEG vs « FinSA » in DE — DE official is FIDLEG ; IT official is LSerFi). Phase 97 task, not 94. COMP-05 stays EN-only by design.
- Promptfoo 24-case eval suite (6 locales × 4 archetypes) wired to GitHub Actions — Phase 95 TEST-01 ships the runner ; Phase 94 ships the underlying locale-branched code so Phase 95 has something real to evaluate.
- Full magic-number audit across `apps/mobile/lib/services/` (other literal CHF figures may exist) — defer to a dedicated « constants audit » phase.
- Adding a 7th / 8th locale (e.g. RM Romansh, AR Arabic) — out of scope ; CLAUDE.md règle 5 = 6 ARB files.
</deferred>

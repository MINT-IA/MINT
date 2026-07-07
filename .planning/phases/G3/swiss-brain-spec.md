# G3 — Swiss Brain Spec: reconfirmer les données périmées

Status: Spec before code. No product code in this PR.
Base produit: PR #841 (`codex/mint-g2-ledger-docs-20260707`).
Infra required before code: PR #851 (`no_bypass_persistence`) and PR #852 (`hardcoded_rate_gate`) green and available on the product branch or invoked in the G3 scorecard.

## Product Intent

G3 makes Mint ask for less while understanding more.

When a known user fact is stale, Mint must not erase it or ask a blank question again. It must show the known value, explain why it matters, and offer a one-tap confirmation or a focused correction.

First vertical: `/data-block/revenu`, because stale salary and canton directly affect tax, 3a, housing capacity, and budget ranges.

## Repo Reality

- `DATA_LEDGER.md:299` says to reuse `data_block_enrichment_screen.dart`, `rank_enrichment_prompts()`, and `freshness_decay_service.dart`.
- `DATA_LEDGER.md:303-313` says `FreshnessDecayService.weight()` accepts a `BiographyFact`, not a field path. G3 therefore needs an adapter, not a second decay model.
- `DATA_LEDGER.md:320-321` defines stale data as `weightForField(path, profile, now) < 0.60`; stale fields are reconfirmed and fresh fields are skipped.
- `DATA_LEDGER.md:432` requires any write to keep `dataSources` and `dataTimestamps` populated.
- `DATA_QUEST.md:72-83` defines `AskMode.reconfirm`: prior value visible, one-tap confirm, focused correction path.
- `DATA_QUEST.md:146-147` requires `AskMode.reconfirm` for stale fields and forbids bypassing `CoachProfileProvider`.
- `freshness_decay_service.dart:64-92` already owns decay and `needsRefresh`.
- `coach_profile_provider.dart:54-76` already has timestamp stamping/persistence helpers.
- `coach_profile_provider.dart:500-520` makes `mergeAnswers()` the write path for incremental updates.
- `coach_profile_provider.dart:1030-1036` exposes `updateProfile()` for whole-profile writes.
- `data_block_enrichment_screen.dart:86-165` already renders `/data-block/:type` and the revenue collector.

## Swiss Meaning

Stale salary, canton, household, LPP, 3a, and mortgage data can materially change the educational range shown by Mint. Mint must present this as an uncertainty and a data-quality issue, not as advice.

Allowed wording pattern:

> On avait noté {label}: {prior}. Cette donnée date de {age}. Toujours juste ?

Buttons:

- Confirmer
- Mettre à jour

Avoid promises and ranking language. Do not use banned terms from `CLAUDE.md`.

## G3 Scope

Implement only the smallest real product slice:

1. Add `AskMode.collect` / `AskMode.reconfirm` model in a Data Quest service.
2. Add a field freshness adapter using the existing decay model.
3. For `/data-block/revenu`, classify `q_gross_salary_annual`, `q_canton`, and `q_birth_year` as missing, fresh, or stale.
4. Render at most one reconfirm card above the revenue collector.
5. Confirm action writes the same value through `CoachProfileProvider.mergeAnswers()` and updates `dataTimestamps`.
6. Correction action focuses the existing field input; it does not open a duplicate form.

Out of scope:

- Full Case registry.
- Backend profile field metadata.
- New tax calculation.
- New login/account behavior.
- PDF.

## Required Tests

- Unit: annual field with timestamp older than 36 months returns stale.
- Unit: fresh annual field produces no Ask.
- Unit: missing salary produces `AskMode.collect`; stale salary produces `AskMode.reconfirm`.
- Widget: `/data-block/revenu` with stale salary shows one reconfirm card with prior value.
- Widget: confirming stale salary calls provider write path and advances timestamp.
- Regression: no direct `SharedPreferences` write outside provider/report persistence.

## Required Commands

- `python3 tools/checks/no_bypass_persistence.py --base-ref <base>`
- `python3 tools/checks/hardcoded_rate_gate.py --base-ref <base>`
- `python3 -m pytest tools/checks/tests/ -q`
- `cd apps/mobile && flutter test test/services/biography/ test/screens/data_block_enrichment_screen_test.dart`
- `cd apps/mobile && flutter analyze`
- Maestro runtime proof for `mint:///data-block/revenu` after UI code lands.

## Acceptance

G3 is accepted only if a stale known value is reconfirmed in one tap, a fresh known value is not asked again, and every write remains inside the ledger path.

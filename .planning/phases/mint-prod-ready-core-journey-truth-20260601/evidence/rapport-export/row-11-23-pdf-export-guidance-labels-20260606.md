# Row 11/23 - PDF export guidance-label boundary

Date: 2026-06-06

Status: local content contract proof only. Row 11 and Row 23 remain `PARTIAL`.

## Problem

Compliance review found that the PDF export still framed the report as a ranked
action/advice artifact:

- `Top 3 - Actions Prioritaires`
- `+CHF...` gain badge
- `Pourquoi :`
- `Plan d'Action Mentor (Top 3)`
- `Action suivante`
- `Statement of Advice`
- `Stratégie Rachat LPP`
- `Économie fiscale...`
- `Plan annuel recommandé`

That wording is too close to advice/recommendation language for the LSFin
boundary MINT wants. It also undermines the Row 23 content-quality target and
the Row 11 report-artifact quality target.

## Fix

`apps/mobile/lib/services/pdf_service.dart` now frames PDF content as guidance:

- `Pistes à examiner`
- `Pistes de réflexion`
- `Contexte :`
- `Piste suivante à examiner`
- `Impact indicatif : CHF...`
- `Simulation de rachat LPP`
- `Écart fiscal estimé sur le scénario`
- `Échelonnement illustratif`
- `Cadre éducatif et limites`

The legacy SessionReport PDF and FinancialReport PDF were both covered because
both had advice-like labels.

`apps/mobile/test/services/pdf_service_test.dart` now has a source-contract test
that asserts the neutral labels are present and the advice-like labels are
absent. Test fixtures were also neutralized so PDF examples no longer normalize
`Ouvrir un 3a`, `Maximise...`, `Ouvrir un compte`, or `Verser`.

## Proof

Red proof:

```bash
cd apps/mobile
flutter test test/services/pdf_service_test.dart --plain-name "financial report PDF labels stay in guidance mode"
```

Initial result: failed because `Pistes à examiner` and other neutral labels were
not present.

Green proof:

```bash
cd apps/mobile
flutter test test/services/pdf_service_test.dart --plain-name "financial report PDF labels stay in guidance mode"
flutter test test/services/pdf_service_test.dart
flutter analyze lib/services/pdf_service.dart test/services/pdf_service_test.dart
```

Results:

- targeted label guard: passed
- full `pdf_service_test.dart`: `17` tests passed
- targeted analyze: no issues

Additional local gates:

```bash
python3 tools/checks/banned_terms_python.py apps/mobile/lib/services/pdf_service.dart
python3 tools/checks/mint_quality_os_check.py
git diff --check
```

Results:

- banned-term scan on touched service: no findings
- Quality OS check: `OK mint_quality_os_check`
- diff check: clean

## Scope Limit

This is not a full Row 11 closure. It does not prove:

- live iOS share/export tap path
- extracted PDF text from a runtime-generated file
- screenshot of the rendered PDF
- VoiceOver/focus order for the export flow
- per-archetype report content scoring

Those remain Row 11/23 work items.

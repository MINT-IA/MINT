# Row 23 — Rapport Emergency Fund Guidance Boundary — 2026-06-06

## Scope

Follow-up to the CJT-051 Claude CLI review. The review found another live
`/rapport` priority-action issue outside the 3a scope: the emergency-fund action
steps still instructed the user to open a savings account and used a salary-only
monthly contribution heuristic.

Old generated steps:

- `1. Ouvre un compte épargne sans frais dans ta banque`
- `2. Mets en place un virement automatique (≈ 10 % du salaire)`

This proof covers the generated `/rapport` emergency-fund action. It does not
attempt a full emergency-fund simulator/content audit.

## Change

- Reframed the emergency-fund action steps to avoid account-opening/product
  instruction.
- Replaced the salary-only `10 % du salaire` heuristic with a resources-based
  formulation:
  - `Identifie un support liquide, séparé et sans frais inutiles`
  - `Planifie un montant réaliste selon tes ressources mensuelles`
  - `Garde cette réserve accessible uniquement pour une urgence`
- Added a generated-action test proving the emergency-fund steps stay free of
  salary-only and account-opening instructions.

## Mechanical Proof

Red proof:

```bash
cd apps/mobile
flutter test test/services/financial_report_service_test.dart --plain-name "emergency fund"
```

The new generated-action guard failed on `ouvre` and `10 % du salaire`.

Green proof:

```bash
cd apps/mobile
flutter test test/services/financial_report_service_test.dart --plain-name "emergency fund"
flutter test test/services/financial_report_service_test.dart
flutter analyze lib/services/financial_report_service.dart test/services/financial_report_service_test.dart

cd ../..
python3 tools/checks/arb_parity.py --arb-dir apps/mobile/lib/l10n
python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb
python3 tools/checks/banned_terms_python.py apps/mobile/lib/services/financial_report_service.dart apps/mobile/test/services/financial_report_service_test.dart
python3 tools/checks/mint_quality_os_check.py
python3 tools/checks/cjt_context_guard.py
./tools/mint-routes check
python3 tools/checks/maestro_locator_audit.py
git diff --check
```

Results:

- Focused emergency-fund guard passed (`1` test).
- Full `financial_report_service_test.dart` passed (`81` tests).
- Targeted analyze passed with no issues.
- ARB parity passed across `6` locales with `6874` keys each.
- French accent lint, LSFin banned-term scan, Quality OS check, CJT context
  guard, route parity, Maestro locator audit, and `git diff --check` passed.

## Runtime Guidance Quality Review

- `user-visible outcome`: Rapport no longer tells the user to open a savings
  account in a bank as the emergency-fund action step.
- `income inclusivity`: the monthly effort is now grounded in `ressources
  mensuelles`, not salary.
- `non-advice boundary`: the copy names liquidity/separation/cost criteria and
  does not select a provider or account type.
- `remaining qualitative gaps`: no runtime screenshot/VoiceOver proof for the
  changed card, no localized `steps[]` contract for EN/DE/ES/IT/PT, and no
  per-archetype emergency-fund content scoring.

## Review Layer

- Claude CLI review returned `NO BLOCKING FINDINGS`.
- The first review found a non-blocking but real test-quality issue: an ARB
  emergency-fund test implied multi-locale coverage even though the live fix is
  in hardcoded `steps[]`. That test was removed.
- Follow-up Claude CLI review confirmed the generated-action guard now covers
  the actual live path and that no runtime or multilocale overclaim remains.

## Decision

CJT-052 is locally fixed for the `/rapport` emergency-fund action-card guidance
boundary.

Row 23 remains `PARTIAL`: this removes one content-quality defect, but it does
not prove full Rapport content quality, VoiceOver traversal, runtime PDF export,
or per-archetype financial guidance quality.

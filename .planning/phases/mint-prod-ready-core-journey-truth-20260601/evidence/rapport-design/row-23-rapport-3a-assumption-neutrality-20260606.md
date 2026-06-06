# Row 23 — Rapport 3a Assumption Neutrality — 2026-06-06

## Scope

Follow-up to the Row 23 `/rapport` content-quality review. Runtime evidence
after CJT-048 showed the compliance assumptions still displayed:

`Plafond 3a salarié : 7’258 CHF/an`

That wording is too narrow for MINT's supported financial-lucidity posture:
users can be salaried, independent, mixed-income, retired, in transition, or
without an LPP affiliation. The report should not present the salaried-with-LPP
ceiling as a general assumption.

## Change

- Replaced the static salaried 3a ceiling sentence with the neutral assumption:
  `Plafond 3a selon affiliation LPP et statut de revenu`.
- Updated EN/DE/ES/IT/PT equivalents and regenerated localization files.
- Added a `/rapport` widget regression for an `independant` profile that asserts
  the neutral assumption is visible and `Plafond 3a salarié` is absent.

## Mechanical Proof

Commands run after the fix:

```bash
cd apps/mobile
flutter gen-l10n
flutter test test/screens/advisor_banking_smoke_test.dart --plain-name "keeps report assumptions income-status neutral"
flutter test test/screens/advisor_banking_smoke_test.dart test/app_rapport_route_budget_test.dart
flutter analyze lib/screens/advisor/financial_report_screen_v2.dart test/screens/advisor_banking_smoke_test.dart

cd ../..
python3 tools/checks/arb_parity.py --arb-dir apps/mobile/lib/l10n
python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb
python3 tools/checks/banned_terms_python.py apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart apps/mobile/test/screens/advisor_banking_smoke_test.dart
git diff --check
flutter build ios --simulator --debug --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Results:

- Focused neutral-assumption widget test: passed.
- Rapport route/screen suite: `48` tests passed.
- Targeted Flutter analyze: no issues.
- ARB parity: `6` locales, `6874` keys each.
- CJT context guard, route registry check, Maestro locator audit, and
  `git diff --check`: clean.
- French accent and LSFin banned-term checks: clean.
- Initial simulator build failed on generated `CodeSign` xattrs; after cleaning
  only `build/ios/iphonesimulator`, the simulator build passed.
- Installed and launched on iPhone 17 Pro simulator
  `B03E429D-0422-4357-B754-536637D979F9`.
- Runtime snapshot for `mintapp:///rapport` exposed
  `Plafond 3a selon affiliation LPP et statut de revenu`.
- Saved runtime evidence:
  `evidence/maestro-ci/row-23-rapport-3a-assumption-neutrality-20260606T112145/`
  contains:
  - `01-rapport-3a-assumption-neutral.jpg`
  - `02-rapport-3a-assumption-neutral-describe-all.json`

## Runtime Guidance Quality Review

- `mechanical proof`: widget proof covers the exact independent-profile copy
  regression; ARB parity and generated l10n prove the six-locale key stayed
  aligned; runtime screenshot and `idb ui describe-all` prove the neutral copy
  is visible on iPhone 17 Pro simulator.
- `user-visible outcome`: `/rapport` no longer tells every user that the working
  3a assumption is the salaried-with-LPP ceiling.
- `guidance quality`: the wording remains short, factual, and compatible with
  the compliance-assumption block.
- `non-absurd`: the screen no longer conflicts with independent/no-LPP 3a
  calculation paths, which can use the higher no-LPP ceiling.
- `inclusive`: the phrase covers salaried, independent, mixed-income, LPP/no-LPP,
  and transition cases without forcing a salaried identity.
- `financial trust`: MINT states that the 3a ceiling depends on LPP affiliation
  and income status instead of implying a universal fixed ceiling.
- `remaining qualitative gaps`: the report still needs broader per-archetype
  runtime content scoring, full VoiceOver traversal, and PDF export content QA.

## Review Layer

- Dedicated code-review subagent verdict: `NO BLOCK`.
- Claude CLI was attempted three times for this lot, with long waits, but each
  run ended in provider-side `API Error: 529 Overloaded`. No Claude approval is
  claimed for CJT-049; the retained review proof is the subagent verdict plus
  the deterministic test, i18n, runtime, route, context, and locator checks
  listed above.

## Decision

CJT-049 is locally fixed for the `/rapport` static salary-only 3a assumption.
Row 23 remains `PARTIAL`: this removes one content-quality defect but does not
prove the full primary-screen design/content/accessibility target.

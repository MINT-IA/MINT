# Row 23 — Rapport 3a Action Guidance Boundary — 2026-06-06

## Scope

Follow-up to the Row 23 `/rapport` content-quality review and the CJT-049
registry reviews. After the static 3a assumption was neutralized, reviewers
found adjacent 3a action copy that still read like product/action instruction:

- `Ouvre ton premier 3a`
- `Ouvre un 2e compte 3a fintech`
- generated steps such as opening/configuring an account and choosing a fixed
  `60% actions` strategy.

This proof covers the generated Rapport 3a action cards, source Circle scoring
recommendations, and six-locale report action copy. During review, the PDF
export labels `Top 3 - Actions Prioritaires`, `+CHF ...`, and
`Plan annuel recommandé` were also flagged as an adjacent Row 11/23 risk, but
PDF code was not changed in this lot to avoid historical CRLF churn. It does
not close full Row 23 per-archetype content scoring or runtime PDF sharing
proof.

## Change

- Reframed the two 3a action titles from account-opening instructions to:
  - `Évaluer l’intérêt d’un 3a`
  - `Évaluer l’intérêt d’un 2e 3a`
- Reframed descriptions around deductible room, estimated tax impact, income,
  canton, LPP status, existing accounts, costs, constraints, and assumptions.
- Replaced prescriptive action steps such as account opening, automatic
  configuration, and fixed `60% actions` allocation with neutral checks:
  eligibility, fees/constraints, estimated impact, and assumption review.
- Reframed `CircleScoringService` source recommendations to `Évalue l’intérêt`
  instead of `Ouvre...`.
- Updated FR/EN/DE/ES/IT/PT ARB keys and regenerated localization files.
- Cleaned LSFin banned-term lint hits in touched service/test files.

## Mechanical Proof

Commands run after the fix:

```bash
cd apps/mobile
flutter gen-l10n
flutter test test/services/financial_report_service_test.dart test/services/circle_scoring_service_test.dart
flutter analyze lib/services/financial_report_service.dart lib/services/circle_scoring_service.dart test/services/financial_report_service_test.dart test/services/circle_scoring_service_test.dart

cd ../..
python3 tools/checks/arb_parity.py --arb-dir apps/mobile/lib/l10n
python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb
python3 tools/checks/banned_terms_python.py apps/mobile/lib/services/financial_report_service.dart apps/mobile/lib/services/circle_scoring_service.dart apps/mobile/test/services/financial_report_service_test.dart apps/mobile/test/services/circle_scoring_service_test.dart
python3 tools/checks/mint_quality_os_check.py
python3 tools/checks/cjt_context_guard.py
./tools/mint-routes check
python3 tools/checks/maestro_locator_audit.py
git diff --check
```

Results:

- Red proof: new guards initially failed on `ouvre`, `fintech`,
  `configure`, `choisis stratégie`, and `60% actions`.
- Green proof: the two targeted service suites passed (`113` tests).
- Targeted analyze passed with no issues.
- ARB parity passed across `6` locales with `6874` keys each.
- French accent lint passed.
- LSFin banned-term scan passed on the touched service/test files.
- Quality OS check, CJT context guard, route parity, Maestro locator audit, and
  `git diff --check` passed.

## Runtime Guidance Quality Review

- `mechanical proof`: service tests now cover ARB copy across six locales,
  generated `FinancialReportService` action fallback text and steps, source
  `CircleScoringService` recommendations.
- `user-visible outcome`: Rapport no longer tells the user to open a first or
  second 3a account, no longer names `fintech` as the account type to open, and
  no longer renders fixed `60% actions` setup steps in the generated cards.
- `guidance quality`: the new copy asks the user to evaluate eligibility,
  deductible room, estimated tax impact, costs, constraints, withdrawal
  staggering, and assumptions.
- `non-advice boundary`: the copy stays educational and factual. It does not
  rank providers, instruct account opening, prescribe a fixed allocation, or
  claim an optimized outcome.
- `remaining qualitative gaps`: no runtime screenshot/VoiceOver proof for the
  changed Rapport cards, no runtime PDF export content proof, and no
  per-archetype content scoring for salaried, independent, mixed-income,
  retired, transition, FATCA, or no-LPP profiles.

## Review Layer

- Compliance/security subagent found the right risk: ARB/localized getters
  override safe fallbacks, and PDF export labels can make neutral actions look
  ranked/prescriptive. The final diff addresses the live Rapport card/i18n
  source; PDF export labels remain an open follow-up.
- Claude CLI review returned `NO BLOCKING FINDINGS`. It confirmed the scoped
  3a action-card/source/i18n fix, confirmed there is no PDF overclaim, and
  noted adjacent non-blocking Row 23 candidates: the emergency-fund action still
  says `Ouvre un compte épargne...`, and an investment recommendation still
  uses `optimisés`.

## Decision

CJT-051 is locally fixed for the `/rapport` 3a action-card guidance-boundary
defect and the source recommendations that feed it.

Row 23 remains `PARTIAL`: this removes one guidance-boundary defect, but it
does not prove full Rapport content quality, VoiceOver traversal, runtime PDF
export, or per-archetype financial guidance quality.

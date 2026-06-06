---
description: Row 23 progress proof for independent/no-LPP rapport guidance depth.
status: verified-local
date: 2026-06-06
linked_bug: CJT-063
---

# Row 23 - Independent/no-LPP Guidance Action

## Scope

This is a local Row 23 quality improvement for `CJT-063`.

It does not close `CJT-063` and does not raise Row 23 beyond `PARTIAL`.
It strengthens the `/rapport` first action for independent/no-LPP profiles so
the user sees a status and liquidity verification step instead of a generic 3a
CTA.

## Problem

The scored persona-flow benchmark for `independent_no_lpp_income_reality` was
`6.3/10`. The flow no longer assumed a salaried/LPP user, but the next action
still did not explicitly cover the expert-grade checks expected for an
independent profile without LPP:

- AVS independent status;
- taxable net income used for 3a room;
- optional LPP vs 3a vs cash reserve tradeoff;
- accident/loss-of-income cover;
- liquidity under income volatility.

## Change

For explicitly independent profiles where the report model resolves
`pillar3a_lpp_status = without_lpp`, the first 3a action is now specialized:

- title: `Clarifier mon statut indépendant avant d’augmenter le 3a`;
- description explains that MINT estimates 3a room from declared income and a
  no-LPP assumption;
- next checks cover AVS independent status, taxable income, accident/loss of
  income cover, liquidity, variable income, optional LPP, 3a, and treasury;
- wording stays educational and conditional.

The `/rapport` screen now passes `S.of(context)` into
`FinancialReportService.generateReport(...)`, so localized action text is used
at runtime instead of service fallback strings.

After code review, the gate was narrowed from "not salaried" to explicit
independent statuses only. `UserProfile` also now carries the declared
`q_has_pension_fund` answer, so an independent user with a voluntary LPP is not
shown no-LPP guidance.

## Compliance Boundary

The copy deliberately avoids:

- opening or recommending a product;
- naming providers;
- choosing an allocation;
- promising tax savings or returns;
- telling the user to maximize 3a or affiliate to LPP.

MCP checks on the French copy:

- `check_banned_terms`: clean;
- `check_accent_patterns`: clean.

## Verification

Focused red/green proof:

- Red before code: `flutter test test/services/financial_report_service_test.dart --plain-name "3a priority action gives independent no-LPP verification guidance"` failed because the generic action did not contain `avs`.
- Green after code: same test passed.
- Regression guard: `flutter test test/services/financial_report_service_test.dart --plain-name "3a priority action"` passed `4/4`, covering:
  - no account-opening instructions;
  - independent/no-LPP guidance;
  - no independent wording for student, unemployed, or retired statuses;
  - independent profiles with declared LPP keep with-LPP assumptions and do not
    receive no-LPP copy.
- Locale guard: `flutter test test/services/financial_report_service_test.dart --plain-name "independent no-LPP 3a copy avoids provider and product commands"` passed.

Runtime-visible widget proof:

- `flutter test test/screens/advisor_banking_smoke_test.dart --plain-name "surfaces independent no-LPP guidance before generic 3a CTA"` passed.
- The test asserts the specialized title and visible description fragments
  around AVS status, taxable income, accident cover, liquidity, and variable
  income.
- The same test asserts absence of `Plafond 3a salarié`, `7’258`, account
  opening language, provider names, fintech framing, and fixed allocation copy.

Impact suite:

- `flutter test test/services/financial_report_service_test.dart test/screens/advisor_banking_smoke_test.dart` passed: `131/131`.
- After the reviewer-driven gate fix, the same impact suite passed: `134/134`.
- ARB parity: `OK — 6 locale(s) parity (reference=fr, 6881 keys each)`.

Review:

- Product/guidance reviewer recommended this exact first-action approach for
  `CJT-063`.
- Code reviewer initially found two important risks: the first implementation
  was gated as "not salaried" instead of explicit independent status, and it
  ignored declared voluntary LPP. Both were fixed before commit.
- Code reviewer re-review: `No blockers`.
- Claude CLI Opus re-review: `No blockers`; noted the `unknown` LPP path is
  acceptable because the copy frames no-LPP as an assumption and asks the user
  to confirm the absence of LPP affiliation.

## Remaining CJT-063 Work

Still required before closing `CJT-063`:

- iPhone 16e Maestro runtime proof for the updated independent/no-LPP path;
- VoiceOver/focus traversal proof;
- PDF per-archetype content proof;
- source/provenance/freshness surfaced beside key money facts;
- Coach natural-language quality review for the same persona;
- updated persona-flow score above the current capped `6.3/10`.

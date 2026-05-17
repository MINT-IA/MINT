# P3 Engineering Wiring Audit — 2026-05-07

**Auditor:** Senior Flutter / Dart engineer pass
**Branch:** `fix/sim-walkthrough-crash-loop` (origin/dev tip + P1/P2 fixes)
**Scope:** P3 = profile construction (« Mon profil », register/login, mode local)
**PRs in scope:** #508 (W-07 register back btn), #515 (BYOK flag), #516 (Keychain fallback), #517 (W-14 header rename)

---

## Verdict

**FLAG** — 4 of 5 P3 claims are wired end-to-end; PR #515 (BYOK gating) is INCOMPLETE; rule-4 (financial_core) violation in `financial_summary_screen.dart`.

## G-mapping (P3 mechanical gates)

| Gate | Status | Evidence |
|------|--------|----------|
| G1 sim walker | (deferred to walker run) | not exercised in this audit |
| G3 dev CI | ⚠️ | tests green but ProfileDrawer flag-off and Keychain fallback have ZERO regression tests |
| G4 regression | ⚠️ | `auth_screens_smoke_test.dart` 43/43 green, biography 65/65 green, profile/ 9/9 green; no widget test for BYOK gating or Keychain `-34018` path |
| G5 LSFin + accent + ARB lint | ✅ | banned-terms scan clean on touched files; no ASCII accent regressions; ARB parity 6/6 locales × 6743 keys |

---

## Per-claim verdicts

### Claim 1 — PR #508 W-07 register-screen back button → **WIRED ✅**
- `apps/mobile/lib/screens/auth/register_screen.dart:145-165` — `AppBar` with leading `IconButton(Icons.arrow_back)`, tooltip `l10n.authBack`, `Semantics(label: l10n.semanticsBack, button: true)`.
- `onPressed`: `Navigator.of(context).pop()` if poppable, else `context.go('/auth/login')`. iOS edge-swipe-back works because AppBar is now persistent (no longer reliant on stack-canPop for visible affordance).
- Reuses `semanticsBack` + `authBack` ARB keys — no new strings, no ARB regen needed.
- Widget test: `apps/mobile/test/screens/auth_screens_smoke_test.dart:355-393` asserts (a) AppBar exists, (b) `Icons.arrow_back` is descendant of AppBar, (c) `IconButton.onPressed != null`, (d) persistence under 800px scroll. **All 4 assertions present and green.**

### Claim 2 — PR #515 BYOK menu hidden behind feature flag → **PARTIAL 🟡**
- `apps/mobile/lib/services/feature_flags.dart:89` — `static bool enableByok = false;` ✅ default false. Backend `applyFromMap` does NOT include `enableByok` (so backend can't flip without a redeploy — that's actually a defensive choice consistent with `project_byok_scope.md`).
- `apps/mobile/lib/widgets/profile_drawer.dart:114` — `if (FeatureFlags.enableByok) _buildSection(...)` ✅ wired.
- **LEAK:** `apps/mobile/lib/widgets/settings_sheet.dart:43-48` — BYOK still listed in the settings bottom-sheet items array, NOT gated.
- **LEAK:** `apps/mobile/lib/screens/coach/coach_chat_screen.dart:1948` — `onSettings: () => context.push('/profile/byok')` direct navigation, NOT gated.
- The route definition (`route_metadata.dart:850`, `screen_registry.dart:1052`, `app.dart:44` route registration) is also unconditional — defensible for « internal testing » per the PR rationale, but means a deep link still reaches the screen.
- **No widget test** asserting the entry is absent when `enableByok = false`.

### Claim 3 — PR #516 biography Keychain fallback in mode local → **WIRED ✅**
- `apps/mobile/lib/services/biography/biography_repository.dart:82-101` — both the `storage.read()` and `storage.write()` calls now wrapped in `try { ... } on PlatformException catch (e) { ... }`. Read failure → `key = null` → fresh `_generateKey()`. Write failure → `debugPrint` + continue with in-memory key. Aligns with the P4 ConsentService fix (#512) — same defensive pattern.
- Imports updated: `import 'package:flutter/services.dart' show PlatformException;` line 4.
- Tests: 65/65 in `test/services/biography/` pass — but they exercise `withDatabase()` injection, not the actual Keychain init path, so the fallback isn't directly tested. The PR description acknowledges this (« existing 16 tests still pass »).
- **No unit test** asserting the `PlatformException(-34018)` branch returns null (read) or proceeds (write) without rethrowing.

### Claim 4 — PR #517 « MON PROFIL » header rename → **WIRED ✅**
- ARB key `financialSummaryTitle` updated in all 6 locales:
  - `app_fr.arb:2089` « MON PROFIL », `app_en.arb` « MY PROFILE », `app_de.arb` « MEIN PROFIL », `app_es.arb` « MI PERFIL », `app_it.arb` « IL MIO PROFILO », `app_pt.arb` « O MEU PERFIL ».
- Generated `app_localizations_*.dart` files all reflect the new strings (lines 4486-4516 across 6 locales).
- `apps/mobile/lib/screens/profile/financial_summary_screen.dart:73` reads `S.of(context)!.financialSummaryTitle` ✅ — no hardcoded fallback.
- ARB parity verified: 6743 keys per locale, 0 diff between locales.
- **Note (not a defect):** `openBankingHubApercu` ARB key still ships the old « APERÇU FINANCIER / FINANCIAL OVERVIEW / FINANZÜBERSICHT / … » strings. Used at `screens/open_banking/open_banking_hub_screen.dart:61` — a different surface (Open Banking hub, gated behind `enableOpenBanking = false`). PR #517 was explicitly scoped to the profile menu/header mismatch (Karpathy 3 surgical), so this is **defensible but should be tracked** if Open Banking ever ships.

### Claim 5 — financial_core source-of-truth (CLAUDE.md rule 4) → **PARTIAL 🟡**
- `apps/mobile/lib/screens/profile/financial_summary_screen.dart:124-127` does **inline LPP rente computation**:
  ```dart
  final renteLpp = (prev.avoirLppTotal ?? 0) * prev.tauxConversion / 12;
  final projectedMonthly = renteAvs + renteLpp;
  ```
- This bypasses `LppCalculator` in `lib/services/financial_core/lpp_calculator.dart` (which exposes `projectToRetirement(...)` returning the projected annual rente).
- **CLAUDE.md rule 4 violation** — « Never re-implement `_calculate*()` in services » — this is a screen, but the principle (single source of truth) applies. Probably should call `LppCalculator.projectToRetirement(...)` (with the user's `currentBalance / currentAge / retirementAge / grossAnnualSalary / caisseReturn / conversionRate`) and divide by 12 at the call site, OR add a `LppCalculator.monthlyRenteFromCurrentBalance(...)` helper for the « project the GAP we already have » case.
- Pre-existing on `dev` (not introduced by P3 PRs), so does not BLOCK P3 closure — but should be filed as a follow-up before claiming « financial_core compliance » on the profile surface.

---

## Test gaps

1. **No widget test** asserting `ProfileDrawer` does NOT render the « Clé API (BYOK) » entry when `FeatureFlags.enableByok = false`. (P3 specifically asked for this.)
2. **No widget test** asserting BYOK is also absent from `SettingsSheet` (currently leaks).
3. **No unit test** asserting `BiographyRepository.instance()` recovers gracefully from `PlatformException(-34018)` on `storage.read` and `storage.write` (the fix is defensive code without a regression net).
4. **No widget test** asserting `FinancialSummaryScreen` renders « MON PROFIL » in the AppBar title (string-only PR, but a 5-line test would lock the link between the menu entry « Mon profil » and the screen title).
5. **No integration test** for the « mode local fresh sim » path: register → enableLocalMode → land on `/home` → open drawer → tap Mon profil → assert header text + no Keychain crash.

## Top priority test to add

> **Widget test in `test/widgets/profile_drawer_test.dart`:** mount `ProfileDrawer` with `FeatureFlags.enableByok = false`; assert `find.text(S_fr.drawerApiKey)` returns `findsNothing`. Closes the BYOK regression net AND surfaces the `settings_sheet.dart` leak.

---

## Recommended follow-ups (out of scope for P3 close)

- **F1 (15 min):** add the `enableByok` guard around `settings_sheet.dart:43-48` and `coach_chat_screen.dart:1948`.
- **F2 (30 min):** widget tests #1 + #3 above.
- **F3 (1 h):** route LPP rente through `LppCalculator` in `financial_summary_screen.dart` (rule-4 alignment).

## Files reviewed (full list)

- `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/screens/auth/register_screen.dart`
- `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/widgets/profile_drawer.dart`
- `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/services/feature_flags.dart`
- `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/services/biography/biography_repository.dart`
- `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/screens/profile/financial_summary_screen.dart`
- `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/services/financial_core/lpp_calculator.dart`
- `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/widgets/settings_sheet.dart`
- `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/l10n/app_{fr,en,de,es,it,pt}.arb`
- `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/test/screens/auth_screens_smoke_test.dart`
- `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/test/services/biography/*.dart`
- `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/test/screens/profile/privacy_control_screen_test.dart`

## Test runs

- `flutter test test/screens/auth_screens_smoke_test.dart` → **43/43 PASS** (incl. new W-07 back-button test)
- `flutter test test/services/biography/` → **65/65 PASS**
- `flutter test test/screens/profile/` → **9/9 PASS**


## Counter-arguments and data gaps

This artifact was synthesised from a single audit pass on 2026-05-07 — it benefits from a healthy dose of skepticism :

- **Sample-of-one bias** : the verdict is driven by one walk on one device (iPhone 17 Pro sim). On real devices, network conditions, OS variants, accessibility settings, or carrier prompts may surface failure modes this pass did not exercise.
- **Confirmation bias risk** : the panel was looking for the bugs from the prior session ; positive findings (« looks fine ») were not stress-tested with adversarial inputs in the same depth as the negative findings.
- **Data gap — production telemetry** : we have no Sentry / staging logs cross-reference for this perimeter ; conclusions about « no regression » are based on absence of visible UI errors, not on instrumentation.
- **Data gap — second reviewer** : no independent re-walk by a second human or sim has corroborated the verdict. Treat as a working hypothesis, not a final ruling, until the next walker run.
- **Counter-argument worth holding** : the « PASS » on items relying on best-effort fallbacks (keychain, biography, consent) hides the fact that the fallback path is the *real* code path on the sim — production-iOS behavior may differ. Prefer running on a real device before claiming the panel is closed.

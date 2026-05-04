---
status: complete
phase: wave-b-home-orchestrateur
source: PLAN.md (4 commits Wave B-minimal)
commits: [476053c2, 7a28fbeb, 99e8e590, 4a9c9dd3]
started: 2026-04-18T16:49:45Z
updated: 2026-04-18T19:00:00Z
---

## Current Test

[testing complete — 10/10 pass after B1-fix 4a9c9dd3]

## Tests

### 1. B0 — Gate isLoggedIn || isLocalMode + contract tests
expected: app.dart:345 contient `(auth.isLoggedIn || auth.isLocalMode)`. 4 tests home_gate_contract passent.
result: pass

### 2. B0 — Device walkthrough iPhone 17 Pro sim
expected: Fresh install anonymous → tap tab Aujourd'hui → AujourdhuiScreen rendered (pas LandingScreen). AX tree contient "MINT" wordmark + TensionCards OU empty-state + 4 tabs (Aujourd'hui/Mon argent/Coach/Explorer).
result: pass
fixed_by: 4a9c9dd3
note: |
  First pass: issue (major) — B1 CapDuJourBanner not rendered in empty-state
  branch. Fix commit 4a9c9dd3 injected CapDuJourBanner at top of empty-state
  Column. Re-run device walkthrough iPhone 17 Pro sim confirmed AX tree now
  shows "Parle-moi de toi" at y=78 + empty-state card at y=442 + 4 tabs.

### 3. B6-minimal — ageOrNull contract
expected: `profile.ageOrNull` returns null pour birthYear=0, 1800, 2099, dateOfBirth future, dateOfBirth impossibly old. 10 tests coach_profile_age_or_null passent.
result: pass

### 4. B6-minimal — CapEngine ageOrNull migration (10 call-sites)
expected: `grep "profile\\.age" apps/mobile/lib/services/cap_engine.dart` ne doit contenir aucun call-site non guarded (tous soit migrés vers `age` local ageOrNull, soit explicitement justifiés). 57 tests cap_engine passent sans régression.
result: pass

### 5. B6-minimal — Backend birthYear range check
expected: `_coerce_fact_value("birthYear", 2099)` returns None. `_coerce_fact_value("birthYear", 1977)` returns 1977.0. `_coerce_fact_value("spouseBirthYear", 1800)` returns None. 8 tests test_coerce_fact_value_range passent.
result: pass

### 6. A2 — MintStateProvider proxy fires recompute on CoachProfile notify
expected: `app.dart:1262` utilise `ChangeNotifierProxyProvider<CoachProfileProvider, MintStateProvider>`. Callback update fire `recompute(profile)` sur notifyListeners. flutter analyze sans régression.
result: pass

### 7. B1 — CapDuJourBanner wired dans AujourdhuiScreen
expected: `apps/mobile/lib/widgets/aujourdhui/cap_du_jour_banner.dart` existe et est importé + utilisé dans `aujourdhui_screen.dart`. Widget consomme MintStateProvider.state.currentCap. Fallback _CapBannerFallback pour state null.
result: pass

### 8. Zéro régression — smoke full test suite
expected: flutter analyze baseline (pas plus de 13 info-level), flutter test cap_engine + navigation + models + providers → 100% green. backend pytest coach + privacy → 100% green.
result: pass

### 9. Doctrine lucidité — aucune gamification ajoutée (ADR-20260419)
expected: 0 import de JitaiNudgeService / MilestoneV2Service / MilestoneDetectionService / StreakService dans apps/mobile/lib/screens/aujourdhui/ ou widgets/aujourdhui/. Pas de celebration sheet déclenché post-scan dans cette Wave.
result: pass

### 10. CLAUDE.md §6 compliance — aucune régression banned terms
expected: grep banned terms ("garanti", "optimal", "meilleur", "parfait", "conseiller" sans "spécialiste") dans diff Wave B → 0 hit. Disclaimers + sources présents.
result: pass

## Summary

total: 10
passed: 0
issues: 0
pending: 10
skipped: 0
blocked: 0

## Gaps

[none yet]

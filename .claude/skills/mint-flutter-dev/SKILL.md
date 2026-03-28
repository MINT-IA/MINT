---
name: mint-flutter-dev
description: Flutter/Dart development for MINT mobile app. Use when creating screens, widgets, simulators, or fixing Flutter code in apps/mobile/. Enforces MintUI kit, GoRouter navigation, Provider state management, and project conventions.
compatibility: Requires Flutter SDK, Dart. Works in apps/mobile/ only.
metadata:
  author: mint-team
  version: "1.0"
---

# MINT Flutter Development

## Scope

You work exclusively in `apps/mobile/`. Never touch `services/backend/`.

## Before Writing Any Code

Read these files first:
- `apps/mobile/lib/app.dart` — GoRouter config, all routes
- `apps/mobile/lib/widgets/mint_ui_kit.dart` — Reusable components (MintCard, MintPremiumButton, MintSection, etc.)
- `apps/mobile/lib/theme/colors.dart` — MintColors palette (textPrimary, textSecondary, textMuted, background, surface, border, primary, accent)
- `apps/mobile/lib/models/` — Data models (Profile, Session, FinancialReport, etc.)

## Architecture Patterns

### Navigation
- GoRouter only. All routes declared in `app.dart`
- New screens: add route in `app.dart`, use `context.go('/path')` or `context.push('/path')`
- Deep linking: use path parameters `/simulator/:type`

### State Management
- Provider (ChangeNotifierProvider) — existing pattern
- ProfileProvider for user profile state
- BudgetProvider for budget state
- No Riverpod, no Bloc — keep it simple

### Widget Structure
```
screens/          → Full-page screens (Scaffold)
widgets/          → Reusable components
  ├── mint_ui_kit.dart    → Core UI kit
  ├── simulators/         → Simulator-specific widgets
  ├── educational/        → Educational insert widgets
  └── report/             → Report display widgets
```

### New Screen Checklist
1. Create screen in `lib/screens/` following existing naming (`xxx_screen.dart`)
2. Add route in `app.dart`
3. Use `MintColors` from theme — never hardcode colors
4. Use `MintCard`, `MintSection`, `MintPremiumButton` from UI kit
5. Create at least 1 smoke test in `test/screens/`
6. Run `flutter analyze` — must be 0 warnings
7. Run `flutter test` — must pass

### New Simulator Checklist
1. Service: `lib/services/simulators/xxx_simulator.dart` (pure calculation logic)
2. Widget: `lib/widgets/simulators/xxx_widget.dart` (UI with sliders/inputs)
3. Screen: `lib/screens/simulator_xxx_screen.dart` (full page wrapper)
4. Test: `test/simulators/xxx_test.dart` (calculation tests with hardcoded values)
5. Register in `lib/screens/main_tabs/explore_tab.dart` grid

## UI Kit Reference

```dart
// Cards
MintCard(child: ...)
MintSection(title: 'TITRE', children: [...])

// Buttons
MintPremiumButton(text: 'Label', onTap: () {})

// Colors (always use MintColors.xxx)
MintColors.textPrimary    // Main text
MintColors.textSecondary  // Subtle text
MintColors.textMuted      // Disabled/hint
MintColors.background     // Page background
MintColors.surface        // Card background
MintColors.border         // Borders
MintColors.primary        // Brand green
MintColors.accent         // Highlight
```

## Testing Patterns

```dart
// Widget test with GoRouter
final router = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, __) => const MyScreen()),
]);
await tester.pumpWidget(MaterialApp.router(routerConfig: router));

// Always mock SharedPreferences
SharedPreferences.setMockInitialValues({});

// Set viewport for reliable layout
tester.view.physicalSize = const Size(1440, 3200);
tester.view.devicePixelRatio = 2.0;
```

## Active Chantiers (read CLAUDE.md § STRATEGIC EVOLUTION DIGEST for full context)

### Chantier 1: Certificate → Profile → Projection Wiring
**Problem**: `ExtractionReviewScreen` shows extracted data but never persists to `CoachProfile`.
**Key files**:
- `lib/services/document_parser/lpp_certificate_parser.dart` — LPP cert extraction
- `lib/services/document_parser/avs_extract_parser.dart` — AVS extract
- `lib/services/document_parser/document_models.dart` — ExtractionResult models
- `lib/screens/document_scan/document_scan_screen.dart` — Scan flow
- `lib/models/coach_profile.dart` — Target model (PrevoyanceProfile, ConjointProfile)
- `lib/providers/coach_profile_provider.dart` — State management

**Task**: Wire `onConfirmExtraction()` → update `CoachProfile.prevoyance` fields → save → trigger `ConfidenceScorer` recalculation → show delta ("With real data: 4'280 CHF/mo instead of ~4'000 estimated").

### Chantier 2: Retirement Cockpit Dashboard
**Problem**: Retirement features scattered across 15+ screens. Need ONE unified cockpit.
**Key files**:
- `lib/screens/coach/retirement_dashboard_screen.dart` — Current 3-state dashboard (A/B/C by confidence)
- `lib/services/retirement_projection_service.dart` — Main projection engine (1'146 lines)
- `lib/services/forecaster_service.dart` — 3-scenario projections
- `lib/services/financial_core/` — All calculators
- `lib/screens/main_navigation_shell.dart` — Tab navigation (feature flag: `FeatureFlags.useNewDashboard`)

**Target dashboard components**: ConfidenceBar, HeroRetirementCard (stacked bar AVS+LPP+3a+Libre), BudgetGapWaterfall, Top3ArbitragesCards (with chiffre choc each), CoupleTimelineChart (phases), PersonalizedChecklist (temporal), MintScoreGauge.

### Golden Test Couple
Julien (50, CH, 100k, swiss_native) + Lauren (45, US/FATCA, 60k, expat_us). File: `test/golden/julien_lauren.xlsx`.

## Rules

- Never hardcode strings (prepare for i18n)
- Never use `MintColors.text` (does not exist) — use `MintColors.textPrimary`
- Google Fonts: Montserrat (headings), Inter (body). Outfit is deprecated.
- **ALWAYS use `financial_core/` calculators** — never duplicate AVS/LPP/Tax logic
- Certificate extraction MUST persist to CoachProfile and trigger recalculation

## Anti-Bug Discipline (per MINT_FINAL_EXECUTION_SYSTEM.md §13.7)

Before ANY implementation:
1. **Identify source of truth** — which file/model is authoritative?
2. **List callsites** — who consumes what you're about to change?
3. **Fix canonical path first** — don't patch a fallback if the real bug is upstream

Before ANY commit:
4. **Verify runtime path** — trace: UI → navigation → GoRouter.extra → screen → ScreenReturn → handler → store
5. **Check all onChanged** — every slider, dropdown, switch, text field must set `_hasUserInteracted = true`
6. **Check PopScope timing** — can `_emitFinalReturn` fire before `_readSequenceContext`?
7. **Check route strings** — does `ScreenReturn.route` match `GoRoute.path` exactly?
8. **Check flag resets** — every boolean guard must reset in ALL paths (success + error + unmount)
9. **Check units** — are values gross/net, annual/monthly, ratio/percentage consistent?

After ANY commit:
10. **Auto-audit** — list: most likely remaining bug, least proven joint, riskiest fallback

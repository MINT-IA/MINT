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

## Rules

- Never hardcode strings (prepare for i18n)
- Never use `MintColors.text` (does not exist) — use `MintColors.textPrimary`
- Wizard questions defined in `lib/data/wizard_questions_v2.dart`
- Educational inserts in `lib/widgets/educational/`
- Google Fonts: `GoogleFonts.spaceGrotesk()` for headers, `GoogleFonts.inter()` for body

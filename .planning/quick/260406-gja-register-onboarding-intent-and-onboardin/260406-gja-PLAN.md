---
phase: quick-260406-gja
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - apps/mobile/lib/app.dart
autonomous: true
requirements: []
must_haves:
  truths:
    - "/onboarding/intent route resolves to IntentScreen"
    - "/onboarding/promise route resolves to PromiseScreen"
    - "navigation_route_integrity_test passes with 0 broken routes"
  artifacts:
    - path: "apps/mobile/lib/app.dart"
      provides: "GoRoute entries for /onboarding/intent and /onboarding/promise"
      contains: "/onboarding/intent"
  key_links:
    - from: "apps/mobile/lib/app.dart"
      to: "apps/mobile/lib/screens/onboarding/intent_screen.dart"
      via: "GoRoute builder"
      pattern: "IntentScreen"
    - from: "apps/mobile/lib/app.dart"
      to: "apps/mobile/lib/screens/onboarding/promise_screen.dart"
      via: "GoRoute builder"
      pattern: "PromiseScreen"
---

<objective>
Register missing /onboarding/intent and /onboarding/promise GoRouter routes in app.dart to fix 10 broken route references found by navigation_route_integrity_test.

Purpose: CI is failing because these 2 routes are referenced in the codebase but never registered in GoRouter.
Output: Updated app.dart with both routes registered.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@apps/mobile/lib/app.dart
@apps/mobile/lib/screens/onboarding/intent_screen.dart
@apps/mobile/lib/screens/onboarding/promise_screen.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add /onboarding/intent and /onboarding/promise GoRoute entries</name>
  <files>apps/mobile/lib/app.dart</files>
  <action>
1. Add two imports at the top of app.dart (after line 108, alongside the other onboarding imports):
   ```dart
   import 'package:mint_mobile/screens/onboarding/intent_screen.dart';
   import 'package:mint_mobile/screens/onboarding/promise_screen.dart';
   ```

2. Add two GoRoute entries in the ONBOARDING section (after the /onboarding/chiffre-choc route at line 846, before the /data-block/:type route at line 847):
   ```dart
   GoRoute(
     path: '/onboarding/intent',
     parentNavigatorKey: _rootNavigatorKey,
     builder: (context, state) => const IntentScreen(),
   ),
   GoRoute(
     path: '/onboarding/promise',
     parentNavigatorKey: _rootNavigatorKey,
     builder: (context, state) => const PromiseScreen(),
   ),
   ```

Follow the exact same pattern as the existing /onboarding/quick and /onboarding/chiffre-choc routes: use parentNavigatorKey: _rootNavigatorKey, use const constructor.

Note: IntentScreen constructor — check if it takes parameters. If it requires non-optional params, check the screen file and adapt. PromiseScreen likely uses const constructor based on the pattern.
  </action>
  <verify>
    <automated>cd apps/mobile && flutter test test/navigation_route_integrity_test.dart</automated>
  </verify>
  <done>
- /onboarding/intent and /onboarding/promise routes registered in GoRouter
- navigation_route_integrity_test passes with 0 broken routes
- flutter analyze reports 0 errors
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

No new trust boundaries — adding routes to existing screens.

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-quick-01 | S (Spoofing) | onboarding routes | accept | Read-only onboarding screens, no auth-gated data |
</threat_model>

<verification>
1. `cd apps/mobile && flutter test test/navigation_route_integrity_test.dart` — 0 broken routes
2. `cd apps/mobile && flutter analyze` — 0 errors
</verification>

<success_criteria>
- navigation_route_integrity_test passes (0 broken references for /onboarding/intent and /onboarding/promise)
- flutter analyze clean (0 errors)
</success_criteria>

<output>
After completion, create `.planning/quick/260406-gja-register-onboarding-intent-and-onboardin/260406-gja-SUMMARY.md`
</output>

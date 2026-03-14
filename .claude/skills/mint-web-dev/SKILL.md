---
name: mint-web-dev
description: Flutter Web development for MINT. Use when adding screens, routes, or features to the web app (apps/mobile/lib/web/). Enforces the zero-modification architecture, dart:io isolation, and web-specific conventions.
compatibility: Requires Flutter SDK with web support. Works in apps/mobile/lib/web/ and apps/mobile/lib/main_web.dart only.
metadata:
  author: mint-team
  version: "1.0"
---

# MINT Web Development

## Scope

You work exclusively in `apps/mobile/lib/web/` and `apps/mobile/lib/main_web.dart`.
**NEVER modify existing mobile files** — the web architecture is 100% additive.

## Architecture Overview

The web app has its own `MaterialApp.router` completely independent from the mobile app (`app.dart`). This ensures zero merge conflicts with mobile development.

```
apps/mobile/lib/
  main_web.dart              # Web entry point (flutter build web -t lib/main_web.dart)
  web/
    web_app.dart             # Root widget: MaterialApp.router + webProviders + webRouter
    web_router.dart          # GoRouter with all web-safe routes
    web_navigation_shell.dart # Sidebar (>=1024px) / bottom nav (<1024px)
    web_theme.dart           # Theme (mirrors app.dart, independent copy)
    web_providers.dart       # Providers (excludes dart:io-dependent ones)
    web_feature_gate.dart    # Registry of mobile-only routes/features
    widgets/
      web_responsive_wrapper.dart  # Constrains mobile screens to 720px
      web_viewport_layout.dart     # Outer frame at 1360px max width
    screens/
      web_home_screen.dart   # Web-specific landing page
```

## Before Writing Any Code

Read these files first:
- `apps/mobile/lib/web/web_router.dart` — All web routes
- `apps/mobile/lib/web/web_providers.dart` — Available providers on web
- `apps/mobile/lib/web/web_feature_gate.dart` — Excluded routes/features
- `apps/mobile/lib/theme/colors.dart` — MintColors (same palette as mobile)

## Key Rules

### 1. NEVER import dart:io on web

These files use `dart:io` and CANNOT be imported (directly or transitively):

| File | Reason |
|------|--------|
| `providers/document_provider.dart` | `import 'dart:io'` (File) |
| `services/slm/slm_engine.dart` | `import 'dart:io'` |
| `services/notification_service.dart` | `import 'dart:io' show Platform` |
| `providers/slm_provider.dart` | imports slm_engine |
| `services/document_service.dart` | imports dart:io |

**Before adding any screen to the web router**, check its full import tree for dart:io:
```bash
grep -r "dart:io" <screen_file> <imported_providers> <imported_services>
```

### 2. Excluded screens (dart:io dependency)

These screens are excluded from the web router with redirects:

| Screen | Redirect | Reason |
|--------|----------|--------|
| `profile_screen.dart` | placeholder | DocumentProvider + SlmProvider |
| `coach_checkin_screen.dart` | `/coach/dashboard` | notification_service |
| `coach_chat_screen.dart` | `/coach/dashboard` | slm_engine |
| `data_block_enrichment_screen.dart` | `/profile` | slm_provider |
| `main_navigation_shell.dart` | `/` | notification_service |
| `documents_screen.dart` | not in router | dart:io (file system) |
| `document_scan_screen.dart` | not in router | dart:io (camera) |
| `bank_import_screen.dart` | not in router | dart:io |

### 3. Excluded providers

`web_providers.dart` excludes:
- `DocumentProvider` — uses `dart:io` (File)
- `SlmProvider` — uses `flutter_gemma` / `dart:io` via slm_engine

All other providers (Auth, Profile, Budget, Byok, Subscription, Household, CoachProfile, Locale, UserActivity) are web-safe.

### 4. Zero modification of existing files

**NEVER modify files outside `lib/web/` or `lib/main_web.dart`.**

To reuse a mobile screen on web:
- Import it directly in `web_router.dart`
- Wrap it in `WebResponsiveWrapper` (720px max width)

To create a web-specific screen:
- Create it in `lib/web/screens/`
- Add the route in `web_router.dart`

### 5. Adding a new route to the web router

```dart
// In web_router.dart, add inside the routes list:
GoRoute(
  path: '/your-route',
  parentNavigatorKey: _rootNavigatorKey, // full-screen, outside shell
  builder: (context, state) =>
      WebResponsiveWrapper(child: const YourScreen()),
),
```

For routes inside the navigation shell (with sidebar):
```dart
// Add inside the ShellRoute's routes list:
GoRoute(
  path: '/your-tab-route',
  pageBuilder: (context, state) => NoTransitionPage(
    child: WebResponsiveWrapper(child: const YourScreen()),
  ),
),
```

### 6. Layout wrappers

- **`WebResponsiveWrapper`** (720px) — wraps individual screens to keep mobile-designed content readable on desktop. Use for ALL screens.
- **`WebViewportLayout`** (1360px) — wraps the entire app. Already applied in `web_app.dart` builder. Do NOT add to individual screens.
- **`WebNavigationShell`** — sidebar NavigationRail on wide screens, bottom NavigationBar on narrow. Applied via ShellRoute in web_router.

### 7. Web-specific screens

Place in `lib/web/screens/`. These screens are web-only and don't exist in the mobile app.

Current web-specific screens:
- `web_home_screen.dart` — Landing page with quick-links

### 8. Theme

`web_theme.dart` is an independent copy of the mobile theme. If the mobile theme changes, update `web_theme.dart` manually. This avoids importing `app.dart` (which pulls in mobile dependencies).

### 9. Colors

Use `MintColors.*` from `lib/theme/colors.dart`. NEVER hardcode hex values.

### 10. Build & deploy

```bash
# Build web app
flutter build web -t lib/main_web.dart

# Run locally
flutter run -d chrome -t lib/main_web.dart
```

Deploy workflow: `.github/workflows/web.yml` (GitHub Pages)

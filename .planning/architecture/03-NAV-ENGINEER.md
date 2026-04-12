# 03 — Navigation Systems Engineering Spec for MINT

> **Author**: Navigation systems engineer (Square / Stripe / Robinhood / N26 pedigree)
> **Date**: 2026-04-11
> **Status**: technical spec + refactor plan
> **Source files audited**:
> - `apps/mobile/lib/app.dart` (1310 lines)
> - `apps/mobile/lib/services/navigation/safe_pop.dart` (15 lines)
> - `apps/mobile/lib/services/navigation/screen_registry.dart` (1652 lines)
> - `.planning/SCREEN_INVENTORY.md` (95 screens)
> - `.planning/SCREEN_NAVIGATION_ACTIONS.md` (203 nav actions)
> - `.planning/SCREEN_MAP.md` (audit findings LOOP-01, NAV-01, BACK-01, REDIR-01)

---

## 0. Executive summary

MINT's current router is a **flat GoRouter** with ~110 top-level routes, ~40 redirect shims, and one global navigator key (`_rootNavigatorKey`, app.dart:137). There is **no ShellRoute**, every screen uses `parentNavigatorKey: _rootNavigatorKey`, which means every push is on the root navigator — there is literally no stack isolation.

The audit in `SCREEN_MAP.md` flagged four cascading failures:

1. **LOOP-01** — Budget facade + chat prompt = infinite loop.
2. **NAV-01** — `safePop()` always falls back to `/coach/chat`, which destroys deep-linked entry.
3. **BACK-01** — back button semantics differ per screen; no convention.
4. **REDIR-01** — 40+ redirects silently collapse multiple historical routes into `/coach/chat`, which is a lie the router tells the user.

The root cause is that after KILL-07 (Phase 2), the 4-tab shell was deleted and `/home` + the 7 `/explore/*` hubs were **redirected to `/coach/chat`** (app.dart:229-236). The codebase is now a **chat-as-shell monolith with no shell primitive**, meaning there is no "return to parent" concept anywhere in the router — everything is a sibling of everything else.

This document specifies the target router state machine, a drop-in replacement for `safePop`, a refactored routing table, the 5 technical anti-patterns to kill, and a 3-phase migration ordered by risk.

---

## A. Router state machine spec

### A.1 Shell architecture

**Decision: single `ShellRoute` with chat as the root child — the "ChatShell" pattern.**

Rationale, grounded in GoRouter mechanics:

- GoRouter gives you exactly three composition primitives: `GoRoute`, `ShellRoute`, `StatefulShellRoute`. A flat list of `GoRoute` entries (what MINT has today) means **one navigator stack**. Every push is a sibling, every pop falls through to the root, and deep links land in a stack of depth 1.
- A `StatefulShellRoute.indexedStack` (the standard 4-tab pattern) maintains N independent navigators — one per branch — and preserves state across tab switches. This is what Wire Spec V2 originally called for (Aujourd'hui / Coach / Explorer / Dossier).
- After KILL-07 the product decision is "chat is the hub". But the router still needs a **shell** so that (a) the chat screen itself persists across pushes, (b) deep links land inside the shell, (c) the root navigator can host modal routes (`fullscreenDialog: true`) on top of the shell.

The correct primitive for "one persistent surface + children that push over it" is `ShellRoute`, not a flat router. This is how Stripe's dashboard mobile, Robinhood's browse, and N26's Spaces all work internally: one shell, one child area.

So MINT needs **exactly one shell** today (`/app` containing `/app/chat` as canonical hub), with room to upgrade to `StatefulShellRoute` the day Wire Spec V2's 4 tabs come back. The shell holds:

- A single persistent `CoachChatScreen` (the hub).
- An `Offstage` indexed stack that makes "deep destinations" (budget, simulators, documents) **push over the shell**, not replace it.
- The `AnalyticsRouteObserver` attached to the shell's navigator, not the root.

```text
root navigator (rootNavigatorKey)
│
├── /  (LandingScreen — public, outside shell)
├── /auth/*  (auth flows — public, outside shell)
│
└── ShellRoute — _shellNavigatorKey
    │
    ├── /app/chat             (default, persistent)
    ├── /app/budget           (pushes over chat, back = chat)
    ├── /app/retraite
    ├── /app/rente-vs-capital
    ├── /app/... (all ~90 tools, same level)
    │
    └── modal routes (fullscreenDialog)
        ├── /app/scan
        ├── /app/scan/review
        └── /app/data-block/:type
```

### A.2 Stack management: push vs go vs replace

There are four router operations GoRouter exposes. Rules:

| Operation | When to use | What it does |
|---|---|---|
| `context.push(route)` | Entering a tool/flow from chat, from a card, from the lightning menu. The back button must return the user to where they came from. | Adds to the current navigator's stack. |
| `context.go(route)` | (a) Post-auth hand-off to the shell, (b) hard navigation to chat after an action completed (capture → impact → back to chat), (c) external deep link landing when the stack should be reset. | **Replaces the entire stack**. Destroys history. Destructive. |
| `context.pushReplacement(route)` | Onboarding → next onboarding step. Auth → auth. Anywhere the previous screen should not be in history. | Replaces top, keeps parents. |
| `context.pop([result])` | Closing a tool or modal. Mandatory path. | Standard pop. |

**Rule of thumb for MINT**:
- `go` is only used in 4 places: (1) auth redirects, (2) landing → shell, (3) "Return to home" CTA in error screen, (4) after magic-link verify. **Nowhere else.**
- Every `go('/coach/chat')` inside a tool screen is a bug — it is destroying the back stack for no reason. See for example `achievements_screen.dart` and the ~40 screens flagged in `SCREEN_NAVIGATION_ACTIONS.md`.

### A.3 Destination vs modal vs drawer — classification

Every screen belongs to exactly one type, and the type dictates the routing primitive:

| Type | Router primitive | Back button | Example |
|---|---|---|---|
| **Destination** | `GoRoute` in shell | Pop to shell root (chat) | `/app/retraite`, `/app/budget` |
| **Flow step** | `GoRoute` in shell with `pushReplacement` between steps | Pop returns to flow entry point, not previous step | `/app/scan` → `/app/scan/review` → `/app/scan/impact` |
| **Modal** | `GoRoute` with `pageBuilder` returning `MaterialPage(fullscreenDialog: true)`, on the **root navigator** | Dismiss = pop, no back arrow — an X button | `/modal/data-block/:type`, `/modal/couple/accept` |
| **Drawer** | **Not a route**. `Scaffold.endDrawer` opened via `Scaffold.of(context).openEndDrawer()` | Tap outside or swipe | Profile drawer, lightning menu |
| **BottomSheet** | **Not a route**. `showModalBottomSheet`, optionally with a URL fragment for analytics | Drag down | Capture sheet, quick action sheet |

The current code blurs these categories. For example:
- `/coach/history` is treated as a destination (GoRoute) but behaves as a drawer on iPhone — should be bottom sheet.
- `/data-block/:type` (app.dart:880) is a GoRoute on the root navigator, but semantically it's a modal capture flow — should be `fullscreenDialog: true`.
- `/scan/review` (app.dart:541) reads `state.extra` for an `ExtractionResult` and shows an error Scaffold when it's null. This is a modal that leaks GoRouter mechanics: `state.extra` doesn't survive app restart or deep link, so the route is **not deep-linkable at all**. Fix: make `/scan/review` a modal pushed with explicit `extra`, not a deep link.

### A.4 Back button decision tree

For every screen, implement this exact decision tree inside `MintNav.back(context)` (see Deliverable B):

```text
1. Is there a platform back gesture (iOS swipe, Android system back)?
   → handled by Flutter's default BackButtonDispatcher on the active navigator.
     Our job is only to ensure the active navigator HAS something to pop.

2. Is there a "close result" the parent needs (e.g. an extraction result)?
   → use context.pop(result); NEVER safePop.

3. Is the stack poppable (canPop() == true)?
   → pop().

4. Stack is empty (deep-linked entry, cold start, notification tap):
   a. Does the screen have a declared fallback (ScreenEntry.parentRoute)?
      → go(parentRoute).
   b. Otherwise: go('/app/chat') ONLY if the screen is inside the shell.
      If the screen is outside the shell (auth, landing): go('/').
```

The current `safePop` (safe_pop.dart:8-14) collapses steps 2, 3, 4a, 4b into one dumb `go('/coach/chat')`. This is why deep links break and why `SCREEN_MAP.md` flagged it as P1.

### A.5 Deep link handling

**Scenario**: user taps a notification or external URL `mint://app/coach/chat?prompt=budget`.

The matrix of cases:

| State | Handling |
|---|---|
| Logged in, onboarded | Router matches scope `authenticated`, chat screen reads `prompt` query param, pre-fills input. |
| Logged in, not onboarded | Router matches, but the chat screen (or an onboarding interceptor) routes to onboarding with `?redirect=<original>`. After completion, `pushReplacement(original)`. |
| Not logged in, public route | Route allowed (`/`, `/about`, `/coach/chat` is public per app.dart:295). Chat works. |
| Not logged in, private route | Redirect: `/auth/register?redirect=<encoded original>`. After register: `go(decoded redirect)`. |
| Cold start from notification | Same as above, but the `initialLocation` in GoRouter MUST be overridden by the deep link. GoRouter does this automatically via platform channels (`WidgetsBindingObserver.didChangeAppLifecycleState` + `routeInformationProvider`). MINT's current `initialLocation: '/'` is only a **default**, not a forced landing. |
| Magic link `/auth/verify?token=X` | Current `_MagicLinkVerifyScreen` (app.dart:1171-1268) handles this but uses `context.go('/coach/chat')` which erases any `redirect` param passed in. Must read `state.uri.queryParameters['redirect']` and use `pushReplacement` after verify. |

**Rule**: the redirect chain **must preserve query params**. Today, `/advisor/wizard` (app.dart:922-926) manually forwards `?section=` to `?prompt=`, but `/onboarding/enrichment` (app.dart:930) silently drops everything. This is REDIR-01 from the audit.

---

## B. Refactored navigation primitives

Replace `safe_pop.dart` with a single `MintNav` class. This is production Dart, not pseudocode.

```dart
// apps/mobile/lib/services/navigation/mint_nav.dart
//
// MintNav — the ONLY navigation primitive MINT screens should call.
//
// Goals:
//  1. Eliminate the "boucle au chat" bug caused by safePop.
//  2. Make back-button semantics explicit, testable, and consistent.
//  3. Support deep-linked entry without destroying history.
//  4. Be safe across cold starts, modal dismissal, and pop-with-result.
//
// Design notes:
//  - Never catches GoError silently. If canPop() lies, we want a stack trace.
//  - All methods take BuildContext as first arg (Flutter convention).
//  - All fallback routes are PARAMETERS, not hardcoded. '/coach/chat' is a
//    per-screen default, not a universal one.
//  - Tests: see test/services/navigation/mint_nav_test.dart.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Central navigation utility for MINT.
///
/// Usage:
///   IconButton(
///     icon: const Icon(Icons.arrow_back),
///     onPressed: () => MintNav.back(context, fallback: '/app/chat'),
///   )
///
/// NEVER use Navigator.pop, Navigator.push, or context.pop directly from
/// production screens unless you're handling a result (in which case use
/// [MintNav.closeWithResult]).
class MintNav {
  MintNav._();

  // ──────────────────────────────────────────────────────────────
  //  BACK
  // ──────────────────────────────────────────────────────────────

  /// Smart back — the ONLY replacement for safePop.
  ///
  /// Decision tree (see 03-NAV-ENGINEER.md §A.4):
  ///   1. If there's something to pop → pop it.
  ///   2. Otherwise, navigate to [fallback].
  ///
  /// [fallback] is mandatory. Each screen declares its own parent. There is
  /// no "universal home". A simulator opened from chat falls back to chat;
  /// a document opened from documents list falls back to documents list.
  ///
  /// If you don't know what to put as [fallback], the rule is:
  ///   - screen inside the shell → '/app/chat'
  ///   - screen outside the shell (auth, landing) → '/'
  ///
  /// [result] is optional — if provided and the stack is poppable, it's
  /// passed to the parent. If the stack is empty, [result] is ignored
  /// (nobody to deliver it to).
  static void back(
    BuildContext context, {
    required String fallback,
    Object? result,
  }) {
    final router = GoRouter.of(context);

    if (router.canPop()) {
      // Case 1: normal pop. If a result is provided, deliver it.
      if (result != null) {
        router.pop(result);
      } else {
        router.pop();
      }
      return;
    }

    // Case 2: nothing to pop. This happens when the user cold-started
    // on this route (deep link, notification, restored state).
    // Replace the stack with the fallback. We use `go` because we
    // want the fallback to become the new root — not add to history.
    router.go(fallback);
  }

  // ──────────────────────────────────────────────────────────────
  //  CLOSE MODAL / DELIVER RESULT
  // ──────────────────────────────────────────────────────────────

  /// Close a modal / bottom sheet / pushed route and return a value.
  ///
  /// Unlike [back], this ALWAYS pops and never falls back. If the screen
  /// is not poppable, it's a programming error — modals are always pushed,
  /// so they always have a parent. An assertion fires in debug.
  ///
  /// Typical use: an extraction review screen that returns the reviewed
  /// result to the caller.
  ///
  ///   MintNav.closeWithResult(context, result: extractionResult);
  static void closeWithResult(BuildContext context, {Object? result}) {
    final router = GoRouter.of(context);
    assert(
      router.canPop(),
      'MintNav.closeWithResult called on a route with no parent. '
      'Either the screen was not pushed (use MintNav.back instead), or '
      'the stack was reset under you (check for go() calls upstream).',
    );
    if (router.canPop()) {
      router.pop(result);
    } else if (!kDebugMode) {
      // Release safety: never leave the user stranded.
      router.go('/app/chat');
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  OPEN / PUSH
  // ──────────────────────────────────────────────────────────────

  /// Push a route onto the current navigator's stack.
  ///
  /// The user can back-button out and land where they came from. This is
  /// the default for "open a tool from chat" and "drill into a detail".
  ///
  /// Use this instead of `context.push(...)` directly so we have a single
  /// choke point for analytics, intent tracking, and readiness gating.
  static Future<T?> open<T>(
    BuildContext context,
    String route, {
    Object? extra,
  }) {
    return GoRouter.of(context).push<T>(route, extra: extra);
  }

  // ──────────────────────────────────────────────────────────────
  //  HARD RESET
  // ──────────────────────────────────────────────────────────────

  /// Hard reset to the shell's home (chat).
  ///
  /// Use when the user completes a flow and we want a clean slate:
  ///   - onboarding finished
  ///   - payment completed
  ///   - destructive action cancelled, user wants out
  ///
  /// This is a one-way trip. History is destroyed. Confirm with the user
  /// before calling (e.g. "Annuler et revenir à l'accueil ?").
  static void resetToHome(BuildContext context) {
    GoRouter.of(context).go('/app/chat');
  }

  /// Hard reset to the public root (landing page).
  ///
  /// Use for logout and auth-error recovery.
  static void resetToRoot(BuildContext context) {
    GoRouter.of(context).go('/');
  }

  // ──────────────────────────────────────────────────────────────
  //  REPLACE (step within a flow)
  // ──────────────────────────────────────────────────────────────

  /// Replace the current top of stack without adding history.
  ///
  /// Use between steps of a flow (scan → review → impact) so the user
  /// doesn't back-button into an intermediate state.
  static void replaceWith<T>(
    BuildContext context,
    String route, {
    Object? extra,
  }) {
    GoRouter.of(context).pushReplacement(route, extra: extra);
  }
}
```

Key properties of `MintNav`:

1. **`fallback` is mandatory on `back()`** — the compiler enforces what today's `safePop()` hides. No more "I forgot to think about deep-link entry".
2. **`closeWithResult` is separate** — documents the intent that a modal MUST be popped with a value. Catches bugs where someone uses `safePop` on a modal and drops the result silently.
3. **`open()` is the single push point** — future-proof hook for analytics, readiness gating, or intent logging. Today it's a thin passthrough.
4. **`resetToHome` and `resetToRoot` are explicit** — using `go` directly is banned in screens; if you need a hard reset, call the named function so code review can flag it.

Migration from `safePop`: the 21 screens using `safePop(context)` become `MintNav.back(context, fallback: '/app/chat')`. A codemod can do this in 10 minutes. Screens that had a smarter fallback (e.g. `documents_screen.dart` → `safePop` then `go('/documents')`) become `MintNav.back(context, fallback: '/app/documents')`.

---

## C. Routing table — proposed new `app.dart` structure

The proposal: **one `ShellRoute` wrapping `/app`**, chat as the root of the shell, all ~90 tools as children of the shell. Modal routes remain on the root navigator. Auth and landing remain public, outside the shell.

Top-level structure:

```dart
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  observers: [AnalyticsRouteObserver()],
  errorBuilder: (c, s) => _MintErrorScreen(error: s.error),
  redirect: _authGuard, // scope-based, unchanged
  routes: [
    // ── Public, outside shell ──
    ScopedGoRoute(path: '/', scope: RouteScope.public, builder: (_, __) => const LandingScreen()),
    ScopedGoRoute(path: '/about', scope: RouteScope.public, ...),
    ..._authRoutes(), // /auth/login, /auth/register, /auth/forgot-password, /auth/verify-email, /auth/verify

    // ── Shell with chat as persistent root ──
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MintAppShell(child: child),
      routes: [
        ScopedGoRoute(
          path: '/app/chat',
          scope: RouteScope.public, // chat is accessible without account
          builder: (context, state) {
            final prompt = state.uri.queryParameters['prompt'];
            final conversationId = state.uri.queryParameters['conversationId'];
            return CoachChatScreen(
              initialPrompt: prompt,
              conversationId: conversationId,
            );
          },
        ),
        // All ~90 tools, flows, and destinations live here.
        // They push OVER the shell, back button returns to chat.
        ..._retraiteRoutes(),
        ..._fiscaliteRoutes(),
        ..._logementRoutes(),
        ..._familleRoutes(),
        ..._travailRoutes(),
        ..._santeRoutes(),
        ..._patrimoineRoutes(),
        ..._budgetRoutes(),
        ..._documentRoutes(),
        ..._dossierRoutes(), // profile, byok, slm, bilan, privacy-control
        ..._educationRoutes(),
      ],
    ),

    // ── Modal routes on root navigator (fullscreenDialog) ──
    ShellRoute(
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (c, s, child) => MaterialPage(
        fullscreenDialog: true,
        child: child,
      ),
      routes: [
        ScopedGoRoute(path: '/modal/scan', ...),
        ScopedGoRoute(path: '/modal/scan/avs-guide', ...),
        ScopedGoRoute(path: '/modal/scan/review', ...),
        ScopedGoRoute(path: '/modal/scan/impact', ...),
        ScopedGoRoute(path: '/modal/data-block/:type', ...),
        ScopedGoRoute(path: '/modal/couple/accept', ...),
      ],
    ),

    // ── Legacy redirects ──
    // Kept for backward compat. Each one MUST forward query params.
    // See anti-pattern #1 in §D.
    ..._legacyRedirects(),
  ],
);
```

Sample of the routing table (abbreviated — full list in `.planning/architecture/03-NAV-ROUTING-TABLE.md` to be generated from `SCREEN_INVENTORY.md`):

| New route | Old route | Type | Shell? | Auth? | Notes |
|---|---|---|---|---|---|
| `/` | `/` | Destination | No | Public | Landing |
| `/auth/login` | `/auth/login` | Destination | No | Public | — |
| `/auth/register` | `/auth/register` | Destination | No | Public | — |
| `/auth/verify-email` | `/auth/verify-email` | Destination | No | Public | — |
| `/auth/verify` | `/auth/verify` | Flow step | No | Public | Magic link verify, preserves `redirect` param |
| `/app/chat` | `/coach/chat` | Shell root | Yes | Public | Canonical hub, persistent |
| `/app/budget` | `/budget` | Destination | Yes | Auth | Replaces facade, see anti-pattern #2 |
| `/app/retraite` | `/retraite` | Destination | Yes | Auth | Retirement dashboard |
| `/app/rente-vs-capital` | `/rente-vs-capital` | Tool | Yes | Auth | Pushed from chat / retraite |
| `/app/rachat-lpp` | `/rachat-lpp` | Tool | Yes | Auth | — |
| `/app/epl` | `/epl` | Tool | Yes | Auth | — |
| `/app/decaissement` | `/decaissement` | Tool | Yes | Auth | — |
| `/app/libre-passage` | `/libre-passage` | Tool | Yes | Auth | — |
| `/app/pilier-3a` | `/pilier-3a` | Tool | Yes | Auth | — |
| `/app/3a-deep/comparator` | `/3a-deep/comparator` | Tool | Yes | Auth | — |
| `/app/3a-deep/real-return` | `/3a-deep/real-return` | Tool | Yes | Auth | — |
| `/app/3a-deep/staggered-withdrawal` | `/3a-deep/staggered-withdrawal` | Tool | Yes | Auth | — |
| `/app/3a-retroactif` | `/3a-retroactif` | Tool | Yes | Auth | — |
| `/app/fiscal` | `/fiscal` | Tool | Yes | Auth | — |
| `/app/hypotheque` | `/hypotheque` | Tool | Yes | Auth | — |
| `/app/mortgage/amortization` | `/mortgage/amortization` | Tool | Yes | Auth | — |
| `/app/mortgage/epl-combined` | `/mortgage/epl-combined` | Tool | Yes | Auth | — |
| `/app/mortgage/imputed-rental` | `/mortgage/imputed-rental` | Tool | Yes | Auth | — |
| `/app/mortgage/saron-vs-fixed` | `/mortgage/saron-vs-fixed` | Tool | Yes | Auth | — |
| `/app/mariage` | `/mariage` | Flow | Yes | Auth | Life event |
| `/app/divorce` | `/divorce` | Flow | Yes | Auth | Life event |
| `/app/naissance` | `/naissance` | Flow | Yes | Auth | Life event |
| `/app/concubinage` | `/concubinage` | Flow | Yes | Auth | Life event |
| `/app/unemployment` | `/unemployment` | Flow | Yes | Auth | Life event |
| `/app/first-job` | `/first-job` | Flow | Yes | Auth | Life event |
| `/app/expatriation` | `/expatriation` | Flow | Yes | Auth | Life event |
| `/app/invalidite` | `/invalidite` | Tool | Yes | Auth | — |
| `/app/couple` | `/couple` | Destination | Yes | Auth | Household |
| `/app/documents` | `/documents` | Destination | Yes | Auth | Coffre |
| `/app/documents/:id` | `/documents/:id` | Detail | Yes | Auth | — |
| `/app/rapport` | `/rapport` | Destination | Yes | Auth | Financial report |
| `/app/confidence` | `/confidence` | Destination | Yes | Auth | — |
| `/app/profile/bilan` | `/profile/bilan` | Destination | Yes | Auth | Mon aperçu |
| `/app/profile/byok` | `/profile/byok` | Tool | Yes | Auth | Settings |
| `/app/profile/slm` | `/profile/slm` | Tool | Yes | Auth | Settings |
| `/app/profile/privacy` | `/profile/privacy-control` | Tool | Yes | Auth | Settings |
| `/app/settings/langue` | `/settings/langue` | Tool | Yes | Auth | — |
| `/modal/scan` | `/scan` | Modal | Root | Auth | `fullscreenDialog: true` |
| `/modal/scan/avs-guide` | `/scan/avs-guide` | Modal | Root | Auth | — |
| `/modal/scan/review` | `/scan/review` | Modal | Root | Auth | Takes extra, not deep-linkable |
| `/modal/scan/impact` | `/scan/impact` | Modal | Root | Auth | — |
| `/modal/data-block/:type` | `/data-block/:type` | Modal | Root | Onboarding | — |
| `/modal/couple/accept` | `/couple/accept` | Modal | Root | Auth | — |
| `/legacy/*` | 40+ redirects | Redirect | — | — | Forwards query params, one helper function |

The key structural change: **every tool moves under `/app/`** and lives inside the `ShellRoute`. This makes:

1. `MintNav.back(fallback: '/app/chat')` correct for every single screen in the shell.
2. The persistent `CoachChatScreen` stays alive across pushes — chat history doesn't re-render when you come back.
3. Deep links like `mint://app/rente-vs-capital` land **inside** the shell, so back button works.
4. Modals (`/modal/...`) live on root navigator, so they overlay the shell correctly on iOS (native modal animation).

---

## D. Five technical anti-patterns to eliminate

### Anti-pattern #1 — Redirect chains that drop query params

**Evidence**: app.dart:229 `/home → /coach/chat`, app.dart:930 `/onboarding/enrichment → /profile/bilan`, app.dart:920 `/advisor → /coach/chat`. Of the 40+ redirects, only one (app.dart:922-926, `/advisor/wizard`) preserves query params. All the others use `redirect: (_, __) => '/coach/chat'` and throw away anything after `?`.

**Impact**: deep links from emails, notifications, and analytics lose their context. A push notification `mint://home?tab=coach&prompt=budget` lands on `/coach/chat` with no prompt.

**Fix**: single helper function that preserves query params on every redirect:

```dart
// apps/mobile/lib/router/preserving_redirect.dart
GoRouterRedirect preserveQueryRedirect(String target) {
  return (BuildContext context, GoRouterState state) {
    final query = state.uri.query;
    return query.isEmpty ? target : '$target?$query';
  };
}
```

Then:
```dart
ScopedGoRoute(path: '/home', redirect: preserveQueryRedirect('/app/chat')),
```

### Anti-pattern #2 — Facade screens that re-prompt the chat (LOOP-01)

**Evidence**: `budget_container_screen.dart` (routed at `/budget`, app.dart:390-393) is a facade. User taps "Voir détail" on a Budget response card → `/budget` → "Faire mon diagnostic" → `context.go('/coach/chat?prompt=budget')` → chat re-emits Budget card → user taps → loop. SCREEN_MAP.md LOOP-01, P0.

**Impact**: the app literally traps the user between two screens with no way out except killing the process.

**Fix**:
1. Delete `BudgetContainerScreen` (the facade).
2. Route `/app/budget` to the real `BudgetScreen` (currently orphaned, SCREEN_INVENTORY.md line 22).
3. `BudgetScreen` must accept data entry and emit a result to chat via `MintNav.closeWithResult` OR stay put and show the diagnostic inline.
4. Forbid "facade that routes back to chat with a prompt" as a pattern. Code review checklist item.

### Anti-pattern #3 — `parentNavigatorKey: _rootNavigatorKey` everywhere (null shell)

**Evidence**: every GoRoute in app.dart (lines 241-914) sets `parentNavigatorKey: _rootNavigatorKey`. This bypasses any shell navigator. Because there is no shell to bypass today, it's harmless; but the moment you introduce a `ShellRoute`, these lines **silently defeat it**.

**Impact**: when the shell is introduced, the bypass will cause every tool to push on the root navigator instead of the shell, which means the shell's persistent chat screen will be hidden under every tool. You won't notice in testing (visually identical) but state loss will appear.

**Fix**: when introducing the shell in Phase 2, **remove** `parentNavigatorKey: _rootNavigatorKey` from all tool routes. Reserve it only for the modal routes (`/modal/*`) that genuinely need to push on the root navigator above the shell. Add a grep check to CI:

```bash
# tools/checks/no_root_nav_key_in_shell.sh
# Fails if any route inside the ShellRoute block uses parentNavigatorKey.
```

### Anti-pattern #4 — Inconsistent back-button implementations

**Evidence**: `SCREEN_NAVIGATION_ACTIONS.md` lines 23-150 show screens using a mix of:
- `safePop()` (21 screens)
- `Navigator.pop(context)` (raw)
- `context.pop()`
- `context.go('/coach/chat')` (nuclear back)
- Direct `Navigator.of(context).maybePop()`

Five different back behaviors, often within the same screen (see `score_reveal_screen.dart` lines 333-334: `safePop` followed immediately by `go('/coach/chat')` — dead code and a bug coexisting).

**Impact**: BACK-01 from the audit. The back button does something different on every screen. iOS swipe-back sometimes works, sometimes doesn't. Android system back sometimes exits the app unexpectedly.

**Fix**:
1. Ban `Navigator.pop`, `Navigator.push`, `context.pop`, `context.push` in screens via a lint rule (`avoid_go_router_raw`).
2. All screens must call `MintNav.back`, `MintNav.open`, `MintNav.closeWithResult`, `MintNav.replaceWith`, or `MintNav.resetToHome`.
3. CI grep: `rg 'Navigator\.(push|pop)|context\.(push|pop|go)' apps/mobile/lib/screens/` should return 0 matches (excluding the 4 approved `go` call sites documented in §A.2).

### Anti-pattern #5 — Screens that read `state.extra` for required data without a fallback

**Evidence**: `/scan/review` (app.dart:541-553) reads `state.extra as ExtractionResult?` and shows `"Document non disponible"` if null. `/scan/impact` (app.dart:554-571) same pattern. `/rapport` (app.dart:609-633) has a `FutureBuilder` fallback, which is good, but most routes don't.

**Impact**: these routes are **not deep-linkable** because `state.extra` is an in-memory reference that doesn't survive cold start, doesn't serialize to URLs, doesn't round-trip through notifications. The screen loads, user gets an error, their flow is broken.

**Fix**: two options, pick one per route:
1. **Make it a modal**, not a GoRoute — modals are opened with explicit `extra` from a known parent, not deep-linked. Move to `/modal/scan/review` per §C.
2. **Persist the data** (e.g. to `ReportPersistenceService` like `/rapport` does) and rebuild from persistence on cold start. Do this only if the route genuinely needs to be deep-linkable.

Screens that need heavy object graphs passed through navigation should never be top-level GoRoutes.

---

## E. Migration strategy — 3 phases

### Phase 1 — Critical fixes (1-2 days, no route renames)

**Goal**: stop the bleeding (LOOP-01, NAV-01). Zero risk of breaking existing routes.

Exact files to modify, in order:

1. `apps/mobile/lib/services/navigation/mint_nav.dart` — **create**. Copy from §B above.
2. `apps/mobile/lib/services/navigation/safe_pop.dart` — **keep but deprecate**. Replace body with `MintNav.back(context, fallback: '/coach/chat')`, add `@Deprecated('Use MintNav.back(context, fallback: ...) with an explicit fallback')`.
3. `apps/mobile/lib/router/preserving_redirect.dart` — **create**. The 5-line helper from anti-pattern #1.
4. `apps/mobile/lib/app.dart` — **patch the 40 redirects** to use `preserveQueryRedirect('/...')` instead of `(_, __) => '/...'`. Mechanical change, ~40 lines diffed.
5. `apps/mobile/lib/screens/budget/budget_container_screen.dart` — **delete**. Replace routing in app.dart:390-393 with orphaned `BudgetScreen`. Fix LOOP-01.
6. `apps/mobile/lib/screens/budget/budget_screen.dart` — **audit** the diagnostic CTAs. Ensure they don't re-emit a chat prompt that re-opens `/budget`.
7. Run `flutter test` — expect 0 regressions.
8. Manual smoke test on device: chat → budget → diagnostic → back → chat (no loop), `/scan` deep link → review (should still error gracefully).

### Phase 2 — Navigation primitives refactor (3-5 days)

**Goal**: introduce the shell, migrate back-button calls, enable deep-link integrity.

Exact files to modify, in order:

1. `apps/mobile/lib/screens/app_shell/mint_app_shell.dart` — **create**. The `ShellRoute` wrapper that hosts the persistent chat Scaffold and injects the child via the `child` argument of `ShellRoute.builder`. Minimal: a `Scaffold` with `endDrawer: ProfileDrawer()`, `body: child`, no AppBar (children provide their own).
2. `apps/mobile/lib/app.dart` — **restructure**:
   - Add `_shellNavigatorKey`.
   - Wrap all tool routes in a `ShellRoute(navigatorKey: _shellNavigatorKey, builder: ..., routes: [...])`.
   - Remove `parentNavigatorKey: _rootNavigatorKey` from all tools.
   - Move `/scan/*`, `/data-block/:type`, `/couple/accept` to a **second** `ShellRoute` that uses `MaterialPage(fullscreenDialog: true)` — these are modals.
   - Canonical `/coach/chat` stays as-is for Phase 2 (don't rename to `/app/chat` yet — that's Phase 3).
3. `apps/mobile/lib/screens/coach/coach_chat_screen.dart` — **verify** it's the persistent root. Because it's hosted in `ShellRoute`, pushes no longer dispose its state. Remove any `didChangeDependencies` that assumed full teardown.
4. **Codemod** `apps/mobile/lib/screens/**/*.dart` — replace `safePop(context)` with `MintNav.back(context, fallback: '<screen-specific>')`. 21 files, mechanical. For each screen, the fallback comes from the ScreenRegistry or defaults to `/coach/chat`.
5. `apps/mobile/lib/services/navigation/safe_pop.dart` — **delete**.
6. `tools/checks/no_raw_go_router.sh` — **create** lint check, wire into CI.
7. `flutter test` + `flutter analyze` — expect 0 errors, adjust widget tests that mocked `safePop`.
8. Manual E2E: every deep-linkable route from a cold start (`flutter run --route=/retraite`, etc.) and verify back button works.

### Phase 3 — Consolidation and screen cleanup (1-2 weeks)

**Goal**: kill legacy redirects, consolidate the `/app/` namespace, delete dead code.

Exact files to modify, in order:

1. `apps/mobile/lib/app.dart` — **rename canonical routes** under `/app/*`:
   - `/coach/chat` → `/app/chat`
   - `/retraite` → `/app/retraite`
   - etc. for all ~90 tools.
   - Each old route becomes a `preserveQueryRedirect('/app/...')` shim.
2. `apps/mobile/lib/services/navigation/screen_registry.dart` — **update** all route strings and `fallbackRoute` entries to `/app/...`. ~1600 lines, search/replace, then verify manually.
3. `apps/mobile/lib/**/*.dart` — **update call sites** of `MintNav.open(context, '/retraite')` → `MintNav.open(context, '/app/retraite')`. Search and replace.
4. **Delete dead screens and redirects**:
   - `AskMintScreen` (superseded by CoachChatScreen — phase 2 of NAVIGATION_GRAAL_V10).
   - `/advisor/*`, `/coach/agir`, `/onboarding/smart`, `/onboarding/minimal` redirects if no callers.
   - `ComprendreHubScreen` if Explorer hub is reinstated differently.
5. `apps/mobile/lib/screens/app_shell/mint_app_shell.dart` — **upgrade to `StatefulShellRoute.indexedStack`** if/when Wire Spec V2 reinstates the 4 tabs (Aujourd'hui / Coach / Explorer / Dossier). The single `ShellRoute` from Phase 2 is a drop-in parent for this.
6. `tools/openapi/` — **nothing to update** (backend doesn't care about Flutter routes).
7. `docs/NAVIGATION_GRAAL_V10.md` — **update** the "routes actives en app.dart" table to reflect the `/app/` namespace.
8. Full E2E test matrix (notifications, deep links, widget taps, cold start, magic link, auth guard, logout).

---

## F. Closing notes

- **Do not skip Phase 1.** LOOP-01 and NAV-01 are P0/P1 on a live app. Phase 1 is 8-12 hours of work and fixes both without touching routes.
- **Phase 2 is the structural win.** After Phase 2, every navigation bug in `SCREEN_MAP.md` becomes mechanically impossible (back button is `MintNav.back`, results flow via `closeWithResult`, deep links land in the shell).
- **Phase 3 is optional polish** but unlocks `StatefulShellRoute` for the day Wire Spec V2 brings back the 4-tab shell.
- The `ScreenRegistry` (1652 lines) is already doing semantic routing well. Do not touch it in Phase 1 or 2 — only Phase 3 updates its route strings.
- The `ScopedGoRoute` + `RouteScope` auth guard (app.dart:158-192) is good. Keep it. It already fails closed and is scope-driven, not prefix-driven.
- The single biggest "you'll thank me later" decision: **make `fallback` mandatory on `MintNav.back`**. It forces every developer to think about deep-link entry for their screen, and makes the problem type-checked instead of runtime-checked.

---

**End of spec.**

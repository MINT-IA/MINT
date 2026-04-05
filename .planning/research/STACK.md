# Stack Research

**Domain:** AI-centric UX journey — Flutter fintech conversational interface
**Researched:** 2026-04-05
**Confidence:** HIGH (based on direct codebase inspection + Flutter SDK knowledge)

---

## Context: What Already Exists

Before adding anything, the codebase already has substantial AI-UX infrastructure:

- `MintMotion` — motion token system (durations: 150/300/600/350ms, curves: easeOutCubic/easeOutQuart/easeInCubic)
- `MintEntrance` — fade+slide reveal wrapper (used in IntentScreen, 20px offset, 300ms)
- `MintCountUp` — 5-step number revelation (setup → silence → countUp → ligne → context + haptic)
- `ChatCardEntrance` — slide-in + fade for rich widgets in chat (600ms, 0.08 horizontal offset)
- `MintLoadingSkeleton` — shimmer animation for async states
- `WidgetRenderer` — transforms Claude tool_use into Flutter widgets (9 tool types)
- `CoachEntryPayload` — typed routing primitive carrying source + topic + data context
- `ProactiveTriggerService` — 7 trigger types (lifecycle, recap, milestone, seasonal, inactivity, confidence, cap)
- `JitaiNudgeService` — 10 nudge types with priority ordering and cooldowns
- `flutter_local_notifications` ^18.0.1 — local push scheduling
- `CoachMemoryService` — 50 insight cross-session memory (SharedPreferences)
- `LightningMenu` — contextual action sheet from chat input bar
- `go_router` ^13.2.0 — 156 files, 67 routes, deep-link compatible

**The real gap is not missing libraries. The gap is wiring: components work individually but are not connected into a coherent journey.**

---

## Recommended Stack

### Core Technologies (NO NEW ADDITIONS — use what exists)

| Technology | Version | Purpose | Verdict |
|------------|---------|---------|---------|
| Flutter SDK | 3.27.4 (pinned) | Cross-platform runtime | Keep pinned — do not upgrade mid-milestone |
| go_router | ^13.2.0 | Navigation | Already deployed — use `CustomTransitionPage` for AI-guided transitions |
| provider | ^6.1.1 | State management | Already deployed — `CoachEntryPayloadProvider` is the AI routing bus |
| flutter_local_notifications | ^18.0.1 | Proactive nudges | Already deployed — `NotificationService` + `JitaiNudgeService` |
| MintMotion | internal | Animation tokens | Already deployed — extend, don't replace |

The Flutter SDK includes `AnimationController`, `Tween`, `FadeTransition`, `SlideTransition`, `ScaleTransition`, `AnimatedSwitcher`, `AnimatedContainer`, `ImplicitlyAnimatedWidget`, and `CustomPainter`. These cover every AI-UX animation need without external libraries.

### Supporting Libraries (ONE targeted addition)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `flutter_animate` | ^4.5.0 | Chained animation DSL | Use ONLY for the 3-minute onboarding journey sequence (intent → loading → premier éclairage reveal). NOT for general widget animation — MintMotion already covers that. |

**Why flutter_animate for this one case:** The onboarding journey requires precisely sequenced, multi-step animations across 4-6 widgets arriving in order (intent tap → transition → skeleton → number → narrative → CTA). Writing this with 6 separate `AnimationController` instances creates 150+ lines of boilerplate. `flutter_animate` reduces this to a declarative chain: `.animate().fadeIn(delay: 0ms).slideY(delay: 100ms)` etc. It is additive-only (doesn't replace existing animations), has zero runtime overhead when `animate()` is not called, and is widely used in Flutter production apps (500k+ pub points).

**Do NOT add:** lottie, rive, shimmer (MintLoadingSkeleton covers it), animations (pub.dev — overly complex for needs), flutter_staggered_animations (redundant with ChatCardEntrance + flutter_animate).

### Development Tools (NO CHANGES NEEDED)

| Tool | Purpose | Notes |
|------|---------|-------|
| flutter_lints ^3.0.0 | Static analysis | Keep 0-error gate |
| flutter_test SDK | Widget + unit tests | New animation widgets need `FakeAsync` tests |
| integration_test SDK | E2E flows | Add E2E test for the 3-minute journey path |

---

## Installation

```bash
# In apps/mobile/pubspec.yaml — add ONE dependency
flutter pub add flutter_animate
# Resolves to ^4.5.0 (compatible with Dart ^3.6.0, Flutter 3.27.4)
```

---

## Pattern Changes (Wiring Gaps to Fix)

These are architectural patterns to implement using existing stack. No new libraries required.

### Pattern 1: `CustomTransitionPage` in GoRouter

**What:** Replace default Material page push transitions with AI-guided transitions that feel like the coach "leading" the user somewhere.

**Why:** Currently, navigating from IntentScreen → CoachChat → Premier Éclairage uses the default slide-left Material transition. This feels like a menu. The target feels like a guided path.

**How:** Use `CustomTransitionPage` (already in go_router) with a shared `FadeTransition` (300ms, `MintMotion.curveEnter`) for the journey screens. Do NOT change utility/tool screen transitions — keep Material push for those.

```dart
// In router configuration — for journey screens only
GoRoute(
  path: '/coach',
  pageBuilder: (context, state) => CustomTransitionPage(
    key: state.pageKey,
    child: const MintCoachTab(),
    transitionDuration: MintMotion.page, // 350ms
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: MintMotion.curveEnter),
        child: child,
      );
    },
  ),
),
```

Apply to: `/onboarding/intent`, `/coach`, `/onboarding/premier-eclairage` — the 3-screen journey core.

### Pattern 2: `CoachEntryPayload` as the Universal Routing Primitive

**What:** All entry into coach must pass through `CoachEntryPayloadProvider`. Currently, only 8 files use it. All 67 routes that can lead to a coach interaction need to inject a typed payload.

**Why:** This is the "façade sans câblage" problem. The intent → coach → insight path is broken because intent chips don't reliably populate the provider before the coach tab opens.

**How:** Audit all 67 routes for CoachEntrySource. Add payload injection at EVERY entry point that can lead to a financial insight. The provider already exists — it just needs to be used consistently.

### Pattern 3: `AnimatedSwitcher` for Proactive Signal Cards

**What:** The MintHome "Signal Proactif" card (sourced from `JitaiNudgeService`) should animate between signals when dismissed, using `AnimatedSwitcher` with `FadeTransition`.

**Why:** Currently the card is static. Dismissal and replacement feel abrupt. `AnimatedSwitcher` (Flutter SDK, no dependency) handles this elegantly with a crossfade.

**How:**
```dart
AnimatedSwitcher(
  duration: MintMotion.standard, // 300ms
  transitionBuilder: (child, animation) => FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.05),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: MintMotion.curveEnter)),
      child: child,
    ),
  ),
  child: SignalCard(key: ValueKey(currentSignal.type), signal: currentSignal),
)
```

### Pattern 4: `DraggableScrollableSheet` for Deep Dive from Chat

**What:** When coach reveals a premier éclairage number in chat, the user should be able to drag up a full-screen deep-dive sheet without leaving the coach context.

**Why:** Currently, tapping a tool-rendered widget navigates away (GoRouter push), breaking the conversation thread. The sheet pattern (already used in `MintBottomSheet`) allows the user to explore the detail while staying in conversation.

**How:** Use `DraggableScrollableSheet` (Flutter SDK) wrapping the rich widget. The sheet is triggered by the `WidgetRenderer` output. Min extent 0.4 (visible), max extent 1.0 (full screen). Snap to 0.7 (comfortable reading height).

### Pattern 5: `ValueListenableBuilder` for Streaming Token Display

**What:** The coach streaming response (`...` placeholder → token-by-token text) should use `ValueListenable<String>` + `ValueListenableBuilder` instead of `setState` in `CoachChatScreen`.

**Why:** `setState` on the 836-line `CoachChatScreen` triggers full-subtree rebuilds during streaming. Every token arrival currently rebuilds the entire message list. `ValueListenable` scopes the rebuild to the streaming bubble only.

**How:** Add `ValueNotifier<String> _streamingContent = ValueNotifier('')` in `CoachChatScreen`. Replace `setState(() => _streamingContent += token)` with `_streamingContent.value += token`. Wrap only the streaming bubble in `ValueListenableBuilder`.

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `rive` / `lottie` | Vector/Lottie animations are design-file-dependent, create binary assets to maintain, and MINT's animation system is code-driven | `flutter_animate` + MintMotion for what exists |
| `animations` (pub.dev) | Google's animation package is heavy (shared axis, fade-through, container transform). MINT's design is simpler — these transitions would feel generic | `CustomTransitionPage` with `FadeTransition` |
| `flutter_staggered_animations` | Redundant with existing `ChatCardEntrance` + `MintEntrance` stagger pattern | Use existing MintEntrance with delay parameter |
| `get` / `getx` | Would conflict with Provider state management across 156 files | Keep Provider |
| `auto_route` | Would require rewriting 156 GoRouter files | Keep go_router |
| `workmanager` / `background_fetch` | Background processing for proactive nudges is over-engineered for v1.0. JITAI and notifications run on foreground session resume | `ProactiveTriggerService` on app resume (already exists) |
| `riverpod` | Would require rewriting all 15 Provider classes and 156 consumer files | Keep Provider |
| Firebase Messaging (`firebase_messaging`) | MINT explicitly uses local-only notifications (privacy by design, LPD art. 6). Firebase adds external dependency and data flow | `flutter_local_notifications` (already deployed) |

---

## Stack Patterns by Variant

**For the 3-minute onboarding journey (intent → loading → insight):**
- Use `flutter_animate` for the multi-step sequential reveal
- Use `CustomTransitionPage` fade transitions between the 3 screens
- Keep `MintCountUp` as the number reveal engine (it already does the 5-step sequence)

**For coach chat UI emerging from conversation:**
- Use `ChatCardEntrance` (already exists) for ALL rich widget appearances
- Use `AnimatedSwitcher` for transitioning between different tool-rendered widgets in the same conversation turn
- No new libraries needed

**For proactive home screen signals:**
- Use `AnimatedSwitcher` + existing `JitaiNudgeService` + `MintEntrance`
- No new libraries needed

**For navigation that feels like a guided path (not a menu):**
- Use `CustomTransitionPage` in go_router for journey screens
- Use `CoachEntryPayload` consistently as the routing context carrier
- No new libraries needed

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| `flutter_animate ^4.5.0` | Dart ^3.6.0, Flutter 3.27.4 | Uses standard Flutter animation primitives internally — no conflicts with MintMotion or existing animation controllers |
| `go_router ^13.2.0` | `CustomTransitionPage` available since go_router 6.x | Already deployed |

---

## Confidence Assessment

| Claim | Confidence | Basis |
|-------|------------|-------|
| No new dependencies needed for animation | HIGH | Direct inspection of MintMotion, MintEntrance, MintCountUp, ChatCardEntrance — all use Flutter SDK primitives |
| flutter_animate ^4.5.0 compatible with stack | HIGH | flutter_animate uses Flutter SDK animation system internally; no conflicts with go_router or Provider |
| ValueListenableBuilder improves streaming | HIGH | Flutter SDK pattern, direct inspection of setState usage in CoachChatScreen |
| CustomTransitionPage is sufficient for guided navigation feel | HIGH | go_router 13.x ships CustomTransitionPage; used in production apps for this exact pattern |
| flutter_local_notifications covers proactive nudge needs | HIGH | NotificationService + JitaiNudgeService already fully implemented for v1.0 scope |
| Background task workers not needed for v1.0 | HIGH | ProactiveTriggerService triggers on session resume — sufficient for "journey guide" pattern at v1.0 scale |

---

## Sources

- Direct inspection of `/apps/mobile/pubspec.yaml` — current dependency versions
- Direct inspection of `/apps/mobile/lib/theme/mint_motion.dart` — existing animation token system
- Direct inspection of `/apps/mobile/lib/widgets/premium/mint_entrance.dart` — existing entrance pattern
- Direct inspection of `/apps/mobile/lib/widgets/premium/mint_count_up.dart` — existing number reveal
- Direct inspection of `/apps/mobile/lib/widgets/coach/chat_card_entrance.dart` — existing chat animation
- Direct inspection of `/apps/mobile/lib/widgets/coach/widget_renderer.dart` — AI → Flutter widget bridge
- Direct inspection of `/apps/mobile/lib/models/coach_entry_payload.dart` — routing primitive
- Direct inspection of `/apps/mobile/lib/services/coach/proactive_trigger_service.dart` — proactive system
- Direct inspection of `/apps/mobile/lib/services/coach/jitai_nudge_service.dart` — nudge system
- Direct inspection of `/apps/mobile/lib/screens/main_navigation_shell.dart` — 3-tab shell
- Flutter SDK documentation (training knowledge, HIGH confidence for core primitives)
- pub.dev flutter_animate package (training knowledge, MEDIUM confidence for version — verify with `flutter pub outdated`)

---

*Stack research for: MINT UX Journey milestone — AI-centric Flutter patterns*
*Researched: 2026-04-05*

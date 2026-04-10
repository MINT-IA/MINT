---
milestone: v2.3
name: "Simplification Radicale"
status: awaiting_gate0
phases: 6
commits: 32
net_lines: -3552
duration: "2026-04-08 to 2026-04-09"
---

# v2.3 Milestone Summary: Simplification Radicale

**One-liner:** Deleted 13 Dart files, rebuilt the app as landing-to-chat with 5 CI gates, zero tabs, zero mandatory account creation -- net -3,552 lines.

## The Problem

v2.2 shipped with 9,326 green tests and 18/18 automated ship gates. Julien installed on iPhone, found 4 P0 bugs in 4 minutes:
1. Auth leak (profile screen accessible without login)
2. Infinite loop (CoachEmptyState -> chat -> CoachEmptyState)
3. Centre de controle catastrophe (unusable consent dashboard)
4. "Creer ton compte" horror (mandatory account creation wall)

Lesson: tests green does not equal app functional. v2.3 was born from this.

## The Solution: 6 Phases

### Phase 1: Architectural Foundation
**Commits:** 7 | **Key files:** `scoped_go_route.dart`, 5 CI gate test files

Migrated all 144 routes to `ScopedGoRoute` with explicit `RouteScope` (public/onboarding/authenticated). Replaced the fragile `protectedPrefixes` whitelist with scope-based guards. Installed 5 mechanical CI gates that would have caught every v2.2 P0:

- Route cycle DFS (catches infinite loops)
- Scope-leak detection (catches auth leaks)
- Payload consumption guard (catches dangling payloads)
- Route guard snapshot (catches scope regressions)
- Doctrine string lint (catches banned terms)

Patched BUG-01 (payload guard). Mounted ProfileDrawer only inside authenticated scope.

### Phase 2: Deletion Spree
**Commits:** 8 | **Files deleted:** 13 (6 screens + 1 widget + 6 tests)

Deleted everything that was not landing or chat:
- `intent_screen.dart` -- conversation IS the diagnostic
- `consent_dashboard_screen.dart` -- consent becomes contextual chips
- `profile_screen.dart` -- data entry moves to chat
- `main_navigation_shell.dart` -- no more tabs
- `explore_tab.dart` -- hubs preserved for chat-summoned drawers
- `coach_empty_state.dart` -- BUG-01 loop structurally eliminated

Made `/coach/chat` public scope. Removed mandatory account creation. Added 6 auth leak tombstone tests proving BUG-02 impossible by construction.

App is now: landing -> chat. Period.

### Phase 3: Chat-as-Shell Rebuild
**Commits:** 5 | **Files created:** 3 widgets + 5 tests

Built the chat-as-shell features:
- CHAT-01: Cold-start routing verification (landing -> chat, no intermediate screens)
- CHAT-02: `ChatDrawerHost` -- summon hub drawers from within chat context
- CHAT-03: `ChatConsentChip` -- inline consent as conversation, not dashboard
- CHAT-04: `ChatDataCapture` -- profile data entry as chat interaction
- CHAT-05: Tone preference suggestion chips

### Phase 4: Residual Bugs & i18n Hygiene
**Commits:** 2

- BUG-03: Fixed ~40 French diacritics across 14 files (Donnees -> Donnees with proper accents)
- NAV-05: Added route reachability BFS CI gate (proves all routes reachable from /coach/chat)
- NAV-06: Verified zero Navigator.push except whitelisted fullscreen overlay

### Phase 5: Sober Visual Polish
**Commits:** 4

- POLISH-01: Landing rebuilt to 3 elements (wordmark + promise + CTA + legal footer)
- POLISH-02: Chat breathing room (24px between turns, 24px ListView vertical)
- POLISH-03: Raw TextStyles replaced with `MintTextStyles` tokens
- POLISH-04: Token audit -- zero `Color(0xFF)` outside colors.dart, zero deprecated widgets

### Phase 6: Automated Verification + Gate 0
**Commits:** 1 (this one)

- flutter analyze: 0 errors (2 warnings, 7 info)
- Architecture gates: 34/34 green
- Full suite: 9,276 tests (9,254 passed, 16 expected failures from golden/layout changes)
- Route inventory: 149 routes (14 public, 10 onboarding, 125 authenticated)
- Awaiting: Julien creator-device walkthrough (Gate 0)

## 4 P0 Bugs -- Resolution

| Bug | Resolution | Phase | Mechanism |
|-----|-----------|-------|-----------|
| Auth leak | Scope-based guards + route deleted | 1 + 2 | Structural (ScopedGoRoute) |
| Infinite loop | Payload guard + widget deleted | 1 + 2 | Structural (CoachEmptyState gone) |
| Centre de controle | Screen deleted, consent is chat chips | 2 + 3 | Structural (file deleted) |
| Creer ton compte | Account creation removed from flow | 2 | Structural (no onboarding wall) |

All 4 bugs are resolved by **structural elimination** -- the code that caused them no longer exists.

## Numbers

| Metric | Before v2.3 | After v2.3 | Delta |
|--------|------------|-----------|-------|
| Dart source files | +13 screens/widgets | -13 deleted, +3 created | -10 net |
| Lines of Dart | baseline | -3,552 net | removal-heavy |
| CI gate tests | 0 | 34 | +34 |
| Route scoping | `protectedPrefixes` whitelist | `ScopedGoRoute` per-route | architectural upgrade |
| Tabs | 3 tabs + drawer | 0 tabs | eliminated |
| Mandatory account creation | yes (before chat) | no (chat is public) | removed |
| Flutter test suite | ~9,326 (v2.2) | 9,276 (v2.3) | -50 (deleted screen tests) |

## What Remains

1. **Gate 0**: Julien installs TestFlight, walks cold-start -> landing -> chat -> first coach turn
2. **Golden regeneration**: 9 golden master images need updating (landing rebuilt)
3. **Test expectation updates**: 7 tests need expectations aligned to v2.3 reality
4. **Carryover to v2.4**: ~65 NEEDS-VERIFY try/except blocks, ACCESS-01 a11y, Krippendorff alpha validation

---
phase: 18-living-timeline-full-timeline
verified: 2026-04-13T06:00:00Z
status: human_needed
score: 6/6 must-haves verified
human_verification:
  - test: "Open Aujourd'hui tab on iPhone. Scroll down past the 3 tension cards. Verify the timeline nodes appear grouped by month with distinct icons for each type."
    expected: "Smooth scroll, month headers visible, nodes with document/conversation/commitment/couple/projection icons. Current month expanded, past months collapsed."
    why_human: "Visual layout, scroll performance, and icon rendering cannot be verified programmatically."
  - test: "Tap a timeline node (e.g. a conversation node). Verify it navigates to the correct deep-link destination."
    expected: "Tapping a conversation node opens /coach/chat. Tapping a commitment node opens coach with engagement prompt."
    why_human: "GoRouter navigation and deep-link parameter handling require runtime verification."
  - test: "Verify earned nodes appear solid, pulsing nodes have primary border, and ghosted nodes appear at reduced opacity."
    expected: "Past items have green left border, active items have primary border, future projections appear faded (0.4 opacity)."
    why_human: "Visual state differentiation requires visual inspection on device."
  - test: "Collapse and expand a month header by tapping the chevron. Verify nodes hide and show."
    expected: "Tapping a month header toggles its nodes. Chevron rotates between expand_more and expand_less."
    why_human: "Interactive state toggling requires device interaction."
---

# Phase 18: Living Timeline -- Full Timeline Verification Report

**Phase Goal:** Aujourd'hui becomes a single-screen center of gravity -- a living timeline with tappable nodes that aggregates documents, conversations, commitments, couple data, and projections into one coherent view
**Verified:** 2026-04-13T06:00:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Aujourd'hui tab shows a scrollable timeline with real nodes below the 3 tension card header | VERIFIED | `aujourdhui_screen.dart` uses `CustomScrollView` with tension cards as `SliverToBoxAdapter` followed by month-grouped `SliverList.builder` timeline nodes. Provider registered in `app.dart` line 1137. |
| 2 | Documents, conversations, commitments, and couple estimates appear as distinct node types with different icons | VERIFIED | `TimelineNodeWidget._buildIcon()` maps 5 `NodeType` variants to 5 distinct icons: `description_outlined`, `chat_bubble_outline`, `check_circle_outline`, `people_outline`, `auto_awesome`. `TimelineProvider._aggregateNodes()` creates nodes from all 5 sources. |
| 3 | Past nodes show solid earned style, present nodes pulse, future nodes appear ghosted | VERIFIED | `TimelineNodeWidget._borderColor()` returns green for earned, primary for pulsing, muted for ghosted. Ghosted nodes wrapped in `Opacity(opacity: 0.4)`. No animation on individual nodes per CONTEXT.md decision. |
| 4 | Timeline scrolls smoothly with lazy loading (SliverList.builder, max 50 nodes) | VERIFIED | `SliverList.builder` used for node rendering (line 232-241). `TimelineProvider` caps at 50 nodes (`_visibleCap = 50`) with `loadMore()` incrementing by 20. |
| 5 | Tapping a node navigates to the correct deep-link destination | VERIFIED | `TimelineNodeWidget` uses `context.go(node.deepLink)` on tap (line 29). Deep links are hardcoded per node type in provider (e.g. `/coach/chat`, `/explorer`). |
| 6 | Nodes are grouped by month with sticky-style headers | VERIFIED | `TimelineProvider._rebuildMonths()` groups nodes by year-month. `MonthHeaderWidget` renders uppercase month label with collapse chevron. `_AujourdhuiScreenState` manages `_collapsedMonths` set. |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `apps/mobile/lib/models/timeline_node.dart` | TimelineNode model with 5 NodeType variants and TimelineMonth | VERIFIED | 64 lines. `NodeType` enum (5 variants), `TimelineNode` class (7 fields), `TimelineMonth` class (5 fields). |
| `apps/mobile/lib/providers/timeline_provider.dart` | TimelineProvider extending TensionCardProvider | VERIFIED | 280 lines. Extends `TensionCardProvider`, overrides `refresh()`, aggregates from 5 real services, groups by month, 50-node cap with `loadMore()`. |
| `apps/mobile/lib/widgets/timeline/timeline_node_widget.dart` | TimelineNodeWidget with type-specific icons | VERIFIED | 160 lines. 5 icon mappings, 3 visual states, i18n title resolution via switch, `context.go(node.deepLink)` on tap. |
| `apps/mobile/lib/widgets/timeline/month_header_widget.dart` | MonthHeaderWidget with collapse chevron | VERIFIED | 53 lines. Month label uppercase, expand/collapse chevron, `onToggle` callback. |
| `apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart` | AujourdhuiScreen with CustomScrollView | VERIFIED | 301 lines. `CustomScrollView` with tension header slivers + month-grouped `SliverList.builder` + load more + empty state. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `timeline_provider.dart` | CommitmentService, FreshStartService, ConversationStore, PartnerEstimateService | Service calls in `_fetchRawData()` | WIRED | Lines 85, 93, 99-104, 110-113, 118-124 fetch from all 5 sources with try/catch graceful fallback. |
| `aujourdhui_screen.dart` | `timeline_provider.dart` | `context.watch<TimelineProvider>()` | WIRED | Line 72: `final provider = context.watch<TimelineProvider>()`. Provider registered in `app.dart` line 1137. |
| `timeline_node_widget.dart` | GoRouter | `context.go(node.deepLink)` | WIRED | Line 29: `onTap: () => context.go(node.deepLink)`. Deep links are internal GoRouter paths. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `timeline_provider.dart` | `_lastNodes` / `_months` | CommitmentService, FreshStartService, SharedPreferences, PartnerEstimateService | Yes -- real service calls with try/catch fallback to empty | FLOWING |
| `aujourdhui_screen.dart` | `provider.months` | `TimelineProvider` via Provider | Yes -- watches provider, iterates months + nodes | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED (Flutter app -- no runnable entry points without device/emulator)

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| TIME-03 | 18-01-PLAN | Full living timeline replaces Aujourd'hui tab -- single-screen center of gravity with nodes | SATISFIED | `CustomScrollView` in `aujourdhui_screen.dart` with tension cards + timeline slivers |
| TIME-04 | 18-01-PLAN | Documents, chat history, commitment intentions, couple data feed into timeline nodes | SATISFIED | `TimelineProvider._aggregateNodes()` creates nodes from all 5 data sources |
| TIME-05 | 18-01-PLAN | Timeline shows earned achievements, active tensions (pulsing), projected scenarios (ghosted) | SATISFIED | `TensionType.earned` / `pulsing` / `ghosted` visual states with border colors + opacity |
| LOOP-03 | Roadmap (partial) | Cleo loop visible in UX | SATISFIED | `CleoLoopIndicator` rendered in `CustomScrollView` at line 176-183 |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `app_fr.arb` | 5468 vs 11036 | Duplicate `timelineSectionTitle` key (earlier: "Evenements de vie", later: "Ton histoire") | Info | JSON last-wins: "Ton histoire" is used. Earlier key is dead. Same pattern in all 6 ARB files. No functional impact. |

### Human Verification Required

### 1. Timeline Visual Layout and Scroll

**Test:** Open Aujourd'hui tab on iPhone. Scroll down past the 3 tension cards. Verify timeline nodes appear grouped by month with distinct icons.
**Expected:** Smooth scroll, month headers visible, nodes with correct type-specific icons. Current month expanded, past months collapsed.
**Why human:** Visual layout, scroll performance, and icon rendering require device inspection.

### 2. Node Tap Navigation

**Test:** Tap a timeline node (conversation, commitment, document). Verify deep-link navigation.
**Expected:** Conversation node opens `/coach/chat`. Document node opens `/explorer`. Commitment node opens coach with engagement prompt.
**Why human:** GoRouter navigation with query parameters requires runtime verification.

### 3. Visual State Differentiation

**Test:** Observe earned, pulsing, and ghosted nodes side by side.
**Expected:** Earned = green left border + solid. Pulsing = primary left border. Ghosted = muted border + 0.4 opacity.
**Why human:** Color and opacity differentiation requires visual inspection.

### 4. Month Header Collapse/Expand

**Test:** Tap a month header chevron to collapse/expand its nodes.
**Expected:** Nodes hide when collapsed, chevron toggles between expand_more and expand_less.
**Why human:** Interactive UI state requires device interaction.

### Gaps Summary

No code-level gaps found. All 6 must-have truths verified against the codebase. All 5 artifacts exist, are substantive (no stubs, no TODOs, no placeholders), are wired into the app via Provider and imports, and have real data flowing from services. The 9 i18n keys are present in all 6 ARB files.

The only item noted is a duplicate `timelineSectionTitle` key in all 6 ARB files (an earlier key from a prior phase and a new one from Phase 18). JSON last-wins semantics mean the correct Phase 18 value is used. This is cosmetic, not functional.

4 items require human verification on device: visual layout, tap navigation, visual states, and month collapse interaction.

---

_Verified: 2026-04-13T06:00:00Z_
_Verifier: Claude (gsd-verifier)_

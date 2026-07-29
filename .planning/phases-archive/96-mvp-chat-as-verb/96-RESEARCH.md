---
description: Phase 96 MVP-CHAT-AS-VERB research — concrete implementation references for D-01..D-28 locked decisions. NOT exploratory ; planner consumes this verbatim. Final phase of v2.9 Chat-as-Verb Pivot milestone.
phase: 96
domain: cross-stack (Flutter + Backend + Maestro + TOML asset library)
confidence: HIGH (locked decisions deepened with codebase-verified references)
researched: 2026-05-11
---

# Phase 96 MVP-CHAT-AS-VERB — Research

**Researched:** 2026-05-11
**Domain:** Cross-stack (Flutter widget patterns + Pydantic v2 + FastAPI middleware + TOML asset + Maestro YAML)
**Confidence:** HIGH

## TLDR

Phase 96 ships the chat-as-verb pivot by (1) flag-gating tab index 2 in `MintShell.NavigationBar` behind `FeatureFlags.chatTabVisible`, (2) revealing a 48dp `MintCardActionBar` inline animated row on each card with 3 verb chips (« Explique-moi » / « Simule » / « Rassure-moi »), (3) routing « Simule » to Explorer (LLM-free) and the other two through `MintChatOverlay` modal with a server-side 3-turn cap per `(session_id, source_card_id)`, (4) extending `CoachChatRequest` with `source_card: SerializedCardContext | None` and `CoachChatResponse` with `narrative_sleeve: NarrativeSleeve | None`, (5) inserting a backend response-middleware linter that strips digits from `hook` (regex `\d` → static fallback), and (6) loading `assets/metaphors.toml` (6-entry bootstrap) via the `toml` pub package. All locked decisions D-01..D-28 are deepened with concrete file paths, code snippets, and library versions below.

**Primary recommendation:** 3 plans / 3 waves / 17 tasks total. Wave 1 (Flutter, ~2d) ships independently ; Wave 2 (Backend, ~2d) hard-blocks on Phase 95 W2 merge ; Wave 3 (cross-stack, ~1d) hard-blocks on W2 merge + Maestro evidence from staging.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions (D-01..D-28 — verbatim from `96-CONTEXT.md`)

**Chat-tab kill mechanism**
- **D-01:** Remove tab index 2 (`tabCoach`) from `MintShell.NavigationBar.destinations` behind `FeatureFlags.chatTabVisible = false` (server-overridable via existing `/config/feature-flags` endpoint). 3-tab nav (Aujourd'hui / Mon Argent / Explorer) when flag false ; 4-tab nav unchanged when flag true.
- **D-02:** GoRouter branch + `CoachChatScreen` route STAY registered — the overlay (`MintChatOverlay`) routes to the same screen. No GoRoute deletion this phase.
- **D-03:** In-flight conversation state preserved by existing `ConversationStore` (Provider, already in use at `apps/mobile/lib/services/coach/conversation_store.dart`) across overlay open/close within the same session. New cards open fresh sessions per `source_card_id`.

**MintCardActionBar**
- **D-04:** New widget `apps/mobile/lib/widgets/mint_card_action_bar.dart` — inline animated row revealed below the card on tap (48dp expansion, 200ms easeOut, `AnimatedSize` + `AnimatedOpacity`). NO bottom sheet. 3 verbs, no more, no less.
- **D-05:** Final FR verb-set : « Explique-moi » / « Simule » / « Rassure-moi ». ARB keys : `verbExplique`, `verbSimule`, `verbRassure` — added to all 6 locales (fr/en/de/es/it/pt) via `flutter gen-l10n`.
- **D-06:** Verb routing : « Explique-moi » → `MintChatOverlay` with `intent: "explain"` + source_card propagated. « Rassure-moi » → `MintChatOverlay` with `intent: "reassure"`. « Simule » → `context.push('/explorer?simulate=<card_id>')` deep-link (zero turns consumed, no LLM call).
- **D-07:** Visual : `MintColors.primary` for active verb tap state ; `MintTextStyles.labelLarge` (or equivalent existing token) ; zero hardcoded `Color(0x...)` per CLAUDE.md rule 2.

**3-turn cap (server-side, strict)**
- **D-08:** STRICT 3-turn cap, NO soft cap, NO extension. Enforced server-side via new `turn_count: int` field on `CoachChatRequest` (incremented client-side per `source_card_id` × app-session).
- **D-09:** Reset criterion : per `source_card_id` × app-session (NOT per-day, NOT per-card-type). Same card tapped again in a new session resets to 0.
- **D-10:** At `turn_count >= 3` on incoming request, backend returns a static FR template + Explorer deep-link, SKIPS the LLM entirely (zero token cost). Verbatim FR (LSFin clean, accent_lint clean) :
  > « Tu as exploré 3 angles sur cette carte. Pour aller plus loin, ouvre le simulateur depuis [Explorer →](/explorer?id={card_id}) — tu pourras y modifier les hypothèses en direct. »
- **D-11:** Instrumentation : Sentry metric `chat_overflow_turn_4` fires every time the cap is hit. Pre-flag-flip baseline pull on `chat_turn_distribution` (7-day window) BEFORE flipping `chatTabVisible=false` to prod. If real cap-hit rate > 40% of sessions, the flag stays at false and we walk back via `/config/feature-flags` server override.

**SerializedCardContext schema**
- **D-12:** New Pydantic v2 model `SerializedCardContext` on backend (`services/backend/app/schemas/card_context.py`, `frozen=True, extra="forbid"`). Fields : `card_id: str`, `card_type: str`, `computed_facts: dict[str, Decimal | int | str]` (financial_core only, no PII), `grounding_keys: list[str]`, `life_event: str | None`, `canton: str | None`, `archetype: str | None`.
- **D-13:** `CoachChatRequest` gains optional `source_card: SerializedCardContext | None = None`. When non-None, narrator system prompt receives a `<source_card>` block with computed_facts + grounding_keys + life_event + canton + archetype injected.

**NarrativeSleeve envelope**
- **D-14:** New Pydantic v2 model `NarrativeSleeve` on backend (`services/backend/app/schemas/narrative_sleeve.py`, `frozen=True, extra="forbid"`). 4 fields : `hook: str` (digit-free, regex `\d` → middleware swap), `caption: str` (citation gate applied), `next_step: str` (verb-first, ≤12 words, lint via `tools/checks/narrative_sleeve_lint.py`), `metaphor: str` (static TOML lookup ; empty string if no match).
- **D-15:** Response envelope : `CoachChatResponse.narrative_sleeve: NarrativeSleeve | None`. None when narrator's source_card is None (legacy unstructured fallback). W3 wires the linter ; W2 ships the schema + optional field.
- **D-16:** Linter implementation : backend response middleware (NOT pre-commit). Runs AFTER the citation gate (Phase 94 stays first in middleware chain). Swaps `hook` to a generic digit-free fallback on `\d` match, NEVER 500s the response. Generic fallback : « Voyons ensemble ce que ça change pour toi. »

**Metaphor library**
- **D-17:** v1 bootstrap : `apps/mobile/assets/metaphors.toml` with 6-10 entries covering 3 archetypes (swiss_native, expat_eu, cross_border) × 2 cantons (VD, GE) × 2 life events (housing, family). TOML shape verbatim from CONTEXT.
- **D-18:** Lookup function `lookup_metaphor(archetype, canton, life_event) -> str` in `apps/mobile/lib/services/metaphor_lookup.dart`. Backend MIRROR `services/backend/app/services/coach/metaphor_lookup.py` for narrator prompt injection.
- **D-19:** Expansion to full archetype × canton × event matrix DEFERRED to post-96 content sprint.

**GroundingPack consumption (SOFT dependency on Phase 95)**
- **D-20:** Phase 96 ships with `ProjectionGroundingPack | None` fallback. Double-lookup already shipped at `citation_parser._substitute_placeholders(*, pack=)` (Phase 95 W2).
- **D-21:** Phase 96 W1 (Flutter UI) does NOT depend on GroundingPack — can ship independently. W2 (Backend) consumes the pack via the existing double-lookup. W3 (linter) does NOT depend on GroundingPack — operates on envelope shape, not citation content.

**Plan count + wave split**
- **D-22:** 3 plans, 3 waves. W1 ~2d Flutter (96-01). W2 ~2d Backend (96-02, BLOCKS on Phase 95 W2 merge). W3 ~1d cross-stack (96-03, BLOCKS on W2 merged + turn_count flow exercised in staging).

**Compliance gates**
- **D-23:** All Phase 95 gates carry forward (banned-terms, PII, no-legal-admission, accent_lint, hash_parity, regression suite).
- **D-24:** Flutter `flutter analyze` exits 0 on diff ; `flutter test` regression ≥ 229 baseline + new tests.
- **D-25:** 6-locale ARB parity : `validate_arb_parity()` MCP tool clean.
- **D-26:** MintColors / MintTextStyles only — `grep -rn "Color(0x" apps/mobile/lib/widgets/mint_card_action_bar.dart apps/mobile/lib/widgets/mint_chat_overlay.dart` returns 0.
- **D-27:** G1 Maestro `flow_card_action_intent_bar.yaml` — exit 0 on iPhone 17 Pro sim against staging Railway ; assert the 3-turn cap fires.
- **D-28:** G2 Julien sim walkthrough — HUMAN-UAT per CLAUDE.md §9. End-to-end : open « Mon 3a 2026 » → « Explique-moi » → MintChatOverlay → cited numbers → hit 3-turn cap → terminal template + Explorer deep-link.

### Claude's Discretion

- Internal widget structure of `MintCardActionBar` and `MintChatOverlay` (Stateless vs Stateful, key handling) — planner decides.
- TOML parser choice — research recommends `toml: ^0.16.0` pub package (HIGH confidence, see D-17 deepening below).
- Exact bounds of `hook` digit-free fallback library (1 string vs rotation) — research recommends 1 verbatim fallback (D-16 verbatim) for determinism.
- Sentry breadcrumb naming convention for related events (`card_action_tap_explique` etc.) — research recommends following Phase 94/95 precedent : `coach.card_action.*` category.
- `turn_count` persistence between turns within a session — research recommends in-memory dict keyed by `(session_id, source_card_id)` per CONTEXT default ; Redis backing is post-96 deferred (D-deferred §7).

### Deferred Ideas (OUT OF SCOPE)

- Full removal of `CITATION_REGISTRY` (post-96 cleanup phase).
- Sobol / NSGA-II / HMM / Bayesian CIs (backlog 999.x).
- Metaphor library expansion beyond v1 6-entry bootstrap (post-v2.9 content sprint).
- Phase 94.2 narrator-prompt iter 2 (backlog 999.5).
- ChatTab full deletion (4-week soak then permanent removal — separate post-v2.9 cleanup).
- Sentry breadcrumb production wiring E2E verification (closed by Phase 96 W3 G1 Maestro flow).
- Server-side `turn_count` Redis persistence (post-96 patch if multi-process drift surfaces).

</user_constraints>

---

<phase_requirements>
## Phase Requirements

> **Note on REQUIREMENTS.md:** No phase-scoped `.planning/REQUIREMENTS.md` exists at the milestone level. The VERB-01..VERB-06 IDs originate from the master synthesis (`.planning/decisions/2026-05-10-95-96-autonomous-sequence-master.md`) and the UX panel (`.planning/decisions/2026-05-10-phase-96-ux-panel.md`). Mapping below is derived from these two sources, the 96-CONTEXT.md decisions, and the v2.9 MILESTONE doctrine.

| ID | Description | Research Support |
|----|-------------|------------------|
| VERB-01 | Intent bar on cards : 3 verb chips (« Explique-moi » / « Simule » / « Rassure-moi ») inline animated row, 48dp / 200ms easeOut | D-04..D-07 deepening below (Flutter `AnimatedSize` + `AnimatedOpacity` pattern verified) ; `flow_card_action_intent_bar.yaml` template included |
| VERB-02 | 3-turn cap server-side, strict, zero LLM cost at turn 4 | D-08..D-11 deepening : `_run_narrator_with_gate` extension point at `coach_chat.py:3345-3389` (verified) ; in-memory dict keyed by `(session_id, source_card_id)` ; D-10 terminal template verbatim FR |
| VERB-03 | Source-card context propagation : `SerializedCardContext` Pydantic v2 → narrator system prompt | D-12..D-13 deepening : Pydantic v2 `frozen=True, extra="forbid"` precedent at `grounding_pack.py:51` (verified) ; `CoachChatRequest.source_card` optional ADDITIVE field |
| VERB-04 | Chat-tab kill behind FeatureFlags.chatTabVisible (server-overridable) | D-01..D-03 deepening : `mint_shell.dart:46-67` flag-gated destinations list (verified) ; `feature_flags.dart:114-146` `applyFromMap` server-override pattern (verified) |
| VERB-05 | `chat_overflow_turn_4` Sentry metric on cap hit | D-11 deepening : Sentry breadcrumb category convention from Phase 94 (`coach.citation_gate`, `coach_chat.py:3329`) + Phase 95 (`coach.grounding_pack.fallback`, `citation_parser.py:387`) — Phase 96 follows `coach.chat_overflow.turn_4` |
| VERB-06 | Walkback path : if cap-hit rate > 40% / 7-day window, flag stays OFF in prod via `/config/feature-flags` server override | D-11 deepening : `FeatureFlags.refreshFromBackend()` 6h periodic + `feature_flags.dart:152-180` (verified) ; baseline pull pre-flip is the planner's gate |

</phase_requirements>

---

## Standard Stack

### Core (versions verified against codebase)

| Library | Version | Purpose | Source |
|---------|---------|---------|--------|
| Flutter SDK | `^3.6.0` | Mobile runtime | `apps/mobile/pubspec.yaml:8` [VERIFIED] |
| Dart SDK | bundled with Flutter | Lang | [VERIFIED] |
| `go_router` | `^13.2.0` | Navigation | `pubspec.yaml:18` [VERIFIED] |
| `provider` | `^6.1.1` | State (ConversationStore) | `pubspec.yaml:17` [VERIFIED] |
| `sentry_flutter` | `9.14.0` | Breadcrumbs (VERB-05) | `pubspec.yaml:30` [VERIFIED] |
| `pydantic` | v2 (project-wide) | Backend schemas | `grounding_pack.py:31` import verified [VERIFIED] |
| `FastAPI` | (project-wide) | Backend routing | `coach_chat.py:2723` `@router.post` decorator [VERIFIED] |
| `sentry-sdk` (Python) | (project-wide) | Backend breadcrumbs | `citation_parser.py:39` import + `coach_chat.py:3329` usage [VERIFIED] |

### New for Phase 96

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `toml` (Dart) | `^0.16.0` | Parse `assets/metaphors.toml` at app boot (D-17/D-18) | [CITED: pub.dev/packages/toml] Pure Dart, TOML v1.1.0, MIT, actively maintained, just95/toml.dart on GitHub. Not currently in `pubspec.yaml` (verified — `grep "^  toml:" pubspec.lock` returned 0). Plan must add it. |
| `tomllib` (Python stdlib) | bundled with Python 3.11+ | Parse `metaphors.toml` for backend narrator prompt injection (D-18 mirror) | [VERIFIED: pyproject.toml:9 `requires-python = ">=3.10"` ; Railway base image is python:3.12-slim per comment at pyproject.toml:50]. Python 3.10 lacks `tomllib` — for Phase 96 backend mirror, use `tomllib` if Railway is on 3.11+ (verified 3.12) OR add `tomli` backport if 3.10 support is required. **Recommended: use `tomllib` (no new dep)** since Railway runs 3.12. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `toml` (Dart pub package) | Hand-roll TOML reader from `package:yaml`-style scratch | Hand-roll = unmaintained, brittle on edge cases (multiline strings, escape sequences). 6-10 entry library would survive but it's a future-debt trap. [ASSUMED] hand-roll is worse — verified by pub.dev maturity of `toml` (TOML v1.1.0 support) and MIT license. |
| `tomllib` (Python stdlib) | `tomli` backport | Backport needed only on Python <3.11. Railway = 3.12 → no backport needed. [VERIFIED: pyproject.toml] |
| In-memory `turn_count` dict per-process | Redis-backed shared counter | Multi-process drift IS a real risk if uvicorn workers > 1. Phase 96 CONTEXT deferred-ideas §7 explicitly says: "If multi-process drift surfaces in G2, Phase 97 patches with Redis." Default in-memory ; document caveat (see Pitfalls §3). |

**Installation:**
```yaml
# apps/mobile/pubspec.yaml — add under dependencies:
dependencies:
  # ... existing ...
  toml: ^0.16.0  # Phase 96 D-17 metaphor library
```
```yaml
# apps/mobile/pubspec.yaml — add under flutter.assets:
flutter:
  assets:
    # ... existing ...
    - assets/metaphors.toml  # Phase 96 D-17
```

**Version verification:**
```bash
# Run before plan finalization to confirm latest stable
flutter pub deps  # check resolved version pre-merge
# Reference verified at https://pub.dev/packages/toml (TOML v1.1.0 support)
```

---

## Architecture Patterns

### Recommended File Structure

```
apps/mobile/
├── assets/
│   └── metaphors.toml                        # NEW (D-17, 6-entry bootstrap)
├── lib/
│   ├── widgets/
│   │   ├── mint_shell.dart                   # MODIFIED (D-01 flag-gated destinations)
│   │   ├── mint_card_action_bar.dart         # NEW (D-04..D-07)
│   │   └── mint_chat_overlay.dart            # NEW (D-06 modal wrapper)
│   ├── services/
│   │   ├── feature_flags.dart                # MODIFIED (D-01 add chatTabVisible)
│   │   ├── coach/
│   │   │   └── conversation_store.dart       # UNCHANGED (D-03 reused as-is)
│   │   ├── metaphor_lookup.dart              # NEW (D-18)
│   │   └── turn_counter.dart                 # NEW (client-side counter feeding turnCount in request)
│   ├── models/
│   │   └── serialized_card_context.dart      # NEW (D-12 client-side Dart mirror)
│   └── l10n/
│       ├── app_fr.arb                        # MODIFIED (D-05 verbExplique/Simule/Rassure)
│       ├── app_en.arb                        # MODIFIED
│       ├── app_de.arb                        # MODIFIED
│       ├── app_es.arb                        # MODIFIED
│       ├── app_it.arb                        # MODIFIED
│       └── app_pt.arb                        # MODIFIED

services/backend/
├── app/
│   ├── schemas/
│   │   ├── card_context.py                   # NEW (D-12 SerializedCardContext)
│   │   ├── narrative_sleeve.py               # NEW (D-14 NarrativeSleeve)
│   │   └── coach_chat.py                     # MODIFIED (D-13 source_card field + D-15 narrative_sleeve field + turn_count field)
│   ├── api/v1/endpoints/
│   │   └── coach_chat.py                     # MODIFIED (D-08..D-11 turn_count enforcement + D-16 sleeve linter wiring)
│   └── services/coach/
│       ├── metaphor_lookup.py                # NEW (D-18 backend mirror)
│       ├── narrative_sleeve_linter.py        # NEW (D-16 hook digit linter)
│       ├── turn_counter.py                   # NEW (in-memory dict keyed by (session_id, source_card_id))
│       └── claude_coach_service.py           # MODIFIED (D-13 inject <source_card> block)

tools/
├── checks/
│   └── narrative_sleeve_lint.py              # NEW (D-14 next_step word-count + verb-first)
└── simulator/flows/maestro-perfect-set/
    └── flow_card_action_intent_bar.yaml      # NEW (D-27 G1 flow)
```

### Pattern 1: Flag-gated NavigationBar.destinations (D-01..D-03)

**Current code at `mint_shell.dart:46-67`** — 4-tab static list. The pattern below collapses to 3 tabs when `FeatureFlags.chatTabVisible == false`.

```dart
// Source: apps/mobile/lib/widgets/mint_shell.dart (Phase 96 modified)
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: navigationShell,
    endDrawer: const ProfileDrawer(),
    bottomNavigationBar: Builder(
      builder: (ctx) {
        final l = S.of(ctx)!;
        // Phase 96 D-01 — flag-gated destinations.
        // When chatTabVisible=false (default prod), the Coach tab is removed
        // from the bar BUT the GoRouter branch + CoachChatScreen route stay
        // registered (D-02) so MintChatOverlay can route to it.
        final showChatTab = FeatureFlags.chatTabVisible;
        final destinations = <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today, color: MintColors.success),
            label: l.tabAujourdhui,
          ),
          NavigationDestination(
            icon: const Icon(Icons.savings_outlined),
            selectedIcon: const Icon(Icons.savings, color: MintColors.success),
            label: l.tabMonArgent,
          ),
          if (showChatTab)
            NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline),
              selectedIcon: const Icon(Icons.chat_bubble, color: MintColors.success),
              label: l.tabCoach,
            ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore, color: MintColors.success),
            label: l.tabExplorer,
          ),
        ];
        return NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          // CRITICAL : goBranch index must match the destinations list,
          // NOT the StatefulShellRoute branches list. The shell still has
          // 4 branches registered ; we just don't surface the 3rd as a tab.
          // index 2 in a 3-tab nav = Explorer (formerly index 3 in 4-tab).
          onDestinationSelected: (index) {
            // Map visible-index → branch-index when chat is hidden.
            final branchIndex = showChatTab
                ? index
                : (index >= 2 ? index + 1 : index);
            navigationShell.goBranch(
              branchIndex,
              initialLocation: branchIndex == navigationShell.currentIndex,
            );
          },
          backgroundColor: MintColors.craie,
          indicatorColor: MintColors.success.withValues(alpha: 0.12),
          destinations: destinations,
        );
      },
    ),
  );
}
```

**Add to `feature_flags.dart`** (after line 101, alongside `enableMvpWedgeOnboarding`):
```dart
/// Phase 96 D-01 — chat tab visibility in MintShell.NavigationBar.
/// When false, the Coach tab is removed from the 4-tab nav (becomes 3-tab) ;
/// the GoRoute branch + CoachChatScreen stay registered for MintChatOverlay
/// to reuse (D-02). Server-overridable via `/config/feature-flags`.
/// Default: false (the kill-switch is ON by default for Phase 96).
/// Kill-switch back to true: backend returns {"chatTabVisible": true} ; no app redeploy.
static bool chatTabVisible = false;
```

**Add to `applyFromMap`** (around line 145):
```dart
if (data.containsKey('chatTabVisible')) {
  chatTabVisible = data['chatTabVisible'] == true;
}
```

### Pattern 2: MintCardActionBar inline animated reveal (D-04..D-07)

**Library/pattern:** Flutter built-in `AnimatedSize` + `AnimatedOpacity` — no new dep. The `AnimatedSize` widget animates the size of its child when its size changes ([CITED: api.flutter.dev/flutter/widgets/AnimatedSize-class.html]). For Phase 96 we transition `height: 0 → 48dp` with `Curves.easeOut` over 200ms.

```dart
// Source: apps/mobile/lib/widgets/mint_card_action_bar.dart (NEW per D-04)
//
// Inline animated row revealed below the card on tap. 48dp expansion,
// 200ms easeOut. NO bottom sheet. 3 verbs, no more, no less (D-04 LOCKED).
//
// Per CLAUDE.md rule 2 (zero hardcoded colors) and Phase 90 lint
// (prefer_mint_color_token), all colors flow from MintColors.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/serialized_card_context.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/mint_chat_overlay.dart';

class MintCardActionBar extends StatefulWidget {
  final SerializedCardContext sourceCard;
  final bool expanded; // controlled by parent — tap on the card flips this

  const MintCardActionBar({
    required this.sourceCard,
    required this.expanded,
    super.key,
  });

  @override
  State<MintCardActionBar> createState() => _MintCardActionBarState();
}

class _MintCardActionBarState extends State<MintCardActionBar> {
  static const _kAnimDuration = Duration(milliseconds: 200);
  static const _kBarHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return AnimatedSize(
      duration: _kAnimDuration,
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        duration: _kAnimDuration,
        curve: Curves.easeOut,
        opacity: widget.expanded ? 1.0 : 0.0,
        child: SizedBox(
          height: widget.expanded ? _kBarHeight : 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _VerbChip(
                label: l.verbExplique,
                icon: Icons.lightbulb_outline,
                onTap: () => _openOverlay(context, intent: 'explain'),
              ),
              const SizedBox(width: 12),
              _VerbChip(
                label: l.verbSimule,
                icon: Icons.tune_outlined,
                onTap: () => _deepLinkToExplorer(context),
              ),
              const SizedBox(width: 12),
              _VerbChip(
                label: l.verbRassure,
                icon: Icons.shield_outlined,
                onTap: () => _openOverlay(context, intent: 'reassure'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openOverlay(BuildContext context, {required String intent}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MintColors.craie,
      builder: (_) => MintChatOverlay(
        sourceCard: widget.sourceCard,
        intent: intent,
      ),
    );
  }

  void _deepLinkToExplorer(BuildContext context) {
    // D-06 — « Simule » bypasses the LLM entirely.
    context.push('/explorer?simulate=${widget.sourceCard.cardId}');
  }
}

class _VerbChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _VerbChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: MintColors.primary),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: MintColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: MintColors.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Pattern 3: Pydantic v2 frozen+forbid schemas (D-12, D-14)

**Precedent at `services/backend/app/services/coach/grounding_pack.py:51`** [VERIFIED] :
```python
model_config = ConfigDict(frozen=True, extra="forbid")
```

**Apply to `SerializedCardContext`:**
```python
# Source: services/backend/app/schemas/card_context.py (NEW per D-12)
"""Phase 96 D-12 — SerializedCardContext schema.

Carries financial_core-only values + grounding key candidates from a UI
card into the narrator's system prompt. NO PII : no IBAN, no name, no
NPA, no employer (per CoachChatRequest.profile_context docstring at
schemas/coach_chat.py:78-87).
"""
from __future__ import annotations
from decimal import Decimal
from typing import Optional, Union
from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class SerializedCardContext(BaseModel):
    """Card snapshot passed to the narrator for source-card context injection.

    Per CONTEXT D-12 :
    - Pydantic v2 `frozen=True, extra="forbid"` (precedent grounding_pack.py:51).
    - camelCase aliases via `to_camel` (precedent coach_chat.py:30).
    - `computed_facts` values are scalar Decimal | int | str ONLY. Lists / nested
      dicts are forbidden by validator (forces narrator prompt to receive
      flat key/value pairs).
    """
    model_config = ConfigDict(
        frozen=True,
        extra="forbid",
        populate_by_name=True,
        alias_generator=to_camel,
    )

    card_id: str = Field(..., min_length=1, max_length=128)
    card_type: str = Field(..., min_length=1, max_length=64)
    computed_facts: dict[str, Union[Decimal, int, str]] = Field(default_factory=dict)
    grounding_keys: list[str] = Field(default_factory=list)
    life_event: Optional[str] = Field(default=None, max_length=64)
    canton: Optional[str] = Field(default=None, min_length=2, max_length=2)
    archetype: Optional[str] = Field(default=None, max_length=32)
```

**Apply to `NarrativeSleeve`:**
```python
# Source: services/backend/app/schemas/narrative_sleeve.py (NEW per D-14)
"""Phase 96 D-14 — NarrativeSleeve response envelope.

4-field contract — hook (digit-free), caption (citation-substituted),
next_step (verb-first ≤12 words), metaphor (TOML lookup, may be empty).
Linter at services/coach/narrative_sleeve_linter.py enforces hook digit-free
constraint at response middleware time (D-16), NOT at schema validation
time (Pydantic CANNOT 500 on linter failure ; middleware swaps the hook).
"""
from __future__ import annotations
from pydantic import BaseModel, ConfigDict, Field


class NarrativeSleeve(BaseModel):
    """4-field response envelope per CONTEXT D-14."""
    model_config = ConfigDict(frozen=True, extra="forbid")

    hook: str = Field(..., min_length=1, max_length=200)
    caption: str = Field(..., min_length=1, max_length=2000)
    next_step: str = Field(..., min_length=1, max_length=120)
    metaphor: str = Field(default="", max_length=200)  # empty when TOML lookup misses
```

### Pattern 4: turn_count enforcement at `_run_narrator_with_gate` (D-08..D-11)

**Extension point verified at `coach_chat.py:3345-3389`** [VERIFIED] :

```python
# Current Phase 95 signature:
async def _run_narrator_with_gate(
    pack: "ProjectionGroundingPack | None" = None,
) -> dict:
    ...
```

**Phase 96 W2 extension — wraps the wrapper:**
```python
# Source: services/backend/app/api/v1/endpoints/coach_chat.py (Phase 96 W2 modification)
#
# Insert at the same scope as `_run_narrator_with_gate` (around line 3345).
# Phase 96 D-08..D-11 — server-side strict 3-turn cap, zero LLM cost at turn 4.

from app.services.coach.turn_counter import TURN_COUNTER  # NEW (D-08 in-memory dict)

# D-10 — verbatim FR terminal template (accent_lint clean, banned-terms clean).
TURN_CAP_TERMINAL_TEMPLATE: str = (
    "Tu as exploré 3 angles sur cette carte. Pour aller plus loin, "
    "ouvre le simulateur depuis [Explorer →](/explorer?id={card_id}) — "
    "tu pourras y modifier les hypothèses en direct."
)

async def _run_narrator_with_gate_and_cap(
    pack: "ProjectionGroundingPack | None" = None,
) -> dict:
    """Phase 96 D-08..D-11 — turn-cap wrapper around _run_narrator_with_gate.

    Order :
    1. If body.source_card is non-None AND turn_count >= 3 → return terminal
       template, SKIP LLM entirely (zero token cost per D-10).
    2. Increment counter, run gated narrator, return result.

    State : in-memory dict per-process keyed by (session_id, source_card_id).
    Multi-process drift is documented in RESEARCH.md §Pitfalls §3 ; Redis
    backing is post-96 deferred per CONTEXT §"Deferred Ideas" §7.
    """
    # body.source_card is the new optional field on CoachChatRequest (D-13).
    if body.source_card is not None:
        key = (str(session_id), body.source_card.card_id)
        current_count = TURN_COUNTER.get(key, 0)

        if current_count >= 3:
            # D-10 — terminal template. ZERO LLM call.
            sentry_sdk.add_breadcrumb(
                category="coach.chat_overflow.turn_4",  # VERB-05 metric name
                message="3-turn cap hit",
                level="info",
                data={
                    "source_card_id": body.source_card.card_id,
                    "turn_count": current_count,
                },
            )
            return {
                "answer": TURN_CAP_TERMINAL_TEMPLATE.format(
                    card_id=body.source_card.card_id,
                ),
                "tool_calls": [],
                "sources": [],
                "disclaimers": [],
                "tokens_used": 0,
                "degraded": False,
                "model_used": "n/a-cap-hit",
            }

        # Increment BEFORE the call so a concurrent retry sees current state.
        TURN_COUNTER[key] = current_count + 1

    return await _run_narrator_with_gate(pack=pack)
```

**`turn_counter.py` (NEW):**
```python
# Source: services/backend/app/services/coach/turn_counter.py (NEW per D-08)
"""Phase 96 D-08 — in-memory turn counter per (session_id, source_card_id).

Per CONTEXT 'Claude's Discretion' : default strategy is in-memory dict ;
Redis backing is post-96 deferred per CONTEXT §"Deferred Ideas" §7.

Multi-process caveat : uvicorn workers > 1 will NOT share this dict.
For Phase 96 staging deploy, run with workers=1 (uvicorn default). If
G2 surfaces drift, Phase 97 patches with Redis (see RESEARCH §Pitfalls §3).
"""
from typing import Dict, Tuple

# Key : (session_id, source_card_id). Value : count of turns spent on this card.
# Resets on app/process restart (per CONTEXT D-09 — per-session, NOT per-day).
TURN_COUNTER: Dict[Tuple[str, str], int] = {}
```

### Pattern 5: NarrativeSleeve hook linter middleware (D-16)

**Order of operations in `_run_narrator_with_gate`** — citation gate FIRST [VERIFIED at `coach_chat.py:3356-3363`], hook linter AFTER. The linter NEVER 500s :

```python
# Source: services/backend/app/services/coach/narrative_sleeve_linter.py (NEW per D-16)
"""Phase 96 D-16 — NarrativeSleeve hook digit-free linter (response middleware).

Runs AFTER the citation gate (which substitutes {{cite:<key>}} placeholders
in `caption`). If hook contains any digit (regex \\d), swap to the generic
fallback. NEVER raise. NEVER 500.
"""
from __future__ import annotations
import re
import sentry_sdk
from app.schemas.narrative_sleeve import NarrativeSleeve

_DIGIT_RE = re.compile(r"\d")

# D-16 generic fallback hook — verbatim FR, accent_lint clean, banned-terms clean.
HOOK_FALLBACK: str = "Voyons ensemble ce que ça change pour toi."


def lint_sleeve(sleeve: NarrativeSleeve) -> NarrativeSleeve:
    """Returns a new NarrativeSleeve with the hook swapped if digits found.

    NarrativeSleeve is frozen — model_copy(update=...) is the only mutation path.
    """
    if not _DIGIT_RE.search(sleeve.hook):
        return sleeve
    try:
        sentry_sdk.add_breadcrumb(
            category="coach.narrative_sleeve.hook_swap",
            message="hook contained digit → swapped to fallback",
            level="info",
            data={"original_hook_length": len(sleeve.hook)},
        )
    except Exception:  # pragma: no cover — breadcrumb is fail-open
        pass
    return sleeve.model_copy(update={"hook": HOOK_FALLBACK})
```

### Pattern 6: TOML asset loading at app boot (D-17/D-18)

**Dart side** — the `toml` pub package loads via `TomlDocument.load(path)` ([CITED: pub.dev/packages/toml]):
```dart
// Source: apps/mobile/lib/services/metaphor_lookup.dart (NEW per D-18)
import 'package:flutter/services.dart' show rootBundle;
import 'package:toml/toml.dart';

class MetaphorLookup {
  static Map<String, dynamic>? _loaded;

  /// Call once at app boot, before MaterialApp builds.
  static Future<void> loadFromAssets() async {
    final tomlString = await rootBundle.loadString('assets/metaphors.toml');
    final document = TomlDocument.parse(tomlString);
    _loaded = document.toMap();
  }

  /// D-18 — returns empty string if no match.
  static String lookup({
    required String archetype,
    required String canton,
    required String lifeEvent,
  }) {
    if (_loaded == null) return '';
    final archetypeMap = _loaded![archetype] as Map<String, dynamic>?;
    if (archetypeMap == null) return '';
    final cantonMap = archetypeMap[canton] as Map<String, dynamic>?;
    if (cantonMap == null) return '';
    final eventMap = cantonMap[lifeEvent] as Map<String, dynamic>?;
    if (eventMap == null) return '';
    return (eventMap['metaphor'] as String?) ?? '';
  }
}
```

**Python mirror** [CITED: docs.python.org/3/library/tomllib]:
```python
# Source: services/backend/app/services/coach/metaphor_lookup.py (NEW per D-18 mirror)
"""Phase 96 D-18 — backend mirror for narrator prompt injection.

Reads the SAME assets/metaphors.toml shipped with the Flutter app
(symlinked or duplicated at services/backend/app/data/metaphors.toml ;
plan decides). Single source of truth for the 6-entry v1 bootstrap.
"""
import tomllib  # Python 3.11+ stdlib (Railway runs 3.12 per pyproject.toml:50)
from functools import lru_cache
from pathlib import Path
from typing import Optional

_METAPHORS_PATH = Path(__file__).parent.parent.parent / "data" / "metaphors.toml"


@lru_cache(maxsize=1)
def _load() -> dict:
    with _METAPHORS_PATH.open("rb") as fp:
        return tomllib.load(fp)


def lookup_metaphor(
    archetype: Optional[str],
    canton: Optional[str],
    life_event: Optional[str],
) -> str:
    """D-18 — return empty string on any None or any miss."""
    if not archetype or not canton or not life_event:
        return ""
    data = _load()
    return (
        data.get(archetype, {})
            .get(canton, {})
            .get(life_event, {})
            .get("metaphor", "")
    )
```

### Pattern 7: 6-entry bootstrap metaphors.toml (D-17)

Verbatim FR, accent_lint clean, banned-terms clean. **3 archetypes × 2 cantons × 1-2 life events = 6 entries** (within the 6-10 budget). All MINT ≠ retirement framing.

```toml
# Source: apps/mobile/assets/metaphors.toml (NEW per D-17)
# Phase 96 v1 bootstrap — 6 entries × 3 archetypes × 2 cantons × 2 life events.
# Verbatim FR ; lint with tools/checks/accent_lint_fr.py + banned_terms_python.py.
# Per CLAUDE.md rule 3 — MINT ≠ retirement app : framing by life event, never
# « préparer la retraite ». Per CLAUDE.md rule 1 — no « garanti / optimal / parfait ».
# Expansion deferred to post-v2.9 content sprint (D-19).

[swiss_native.VD.housing]
metaphor = "À Lausanne, ton 3a est une cave à vin — chaque année qui passe l'enrichit, mais elle se vide vite si tu l'ouvres trop tôt."

[swiss_native.GE.family]
metaphor = "Une famille à Genève, c'est trois calendriers fiscaux qui se croisent — chaque décision en redessine deux autres."

[expat_eu.VD.housing]
metaphor = "Acheter à Lausanne quand on vient de l'UE, c'est composer avec deux pays qui ne parlent pas la même langue fiscale."

[expat_eu.GE.family]
metaphor = "Avec une famille à Genève côté UE, tes choix ressemblent à un puzzle — chaque pièce nouvelle redessine l'image."

[cross_border.VD.housing]
metaphor = "Frontalier à Lausanne, ton logement vit entre deux fiscalités — il faut souvent les regarder ensemble pour comprendre où tu en es."

[cross_border.GE.family]
metaphor = "Pour une famille frontalière à Genève, chaque allocation peut basculer d'un côté ou de l'autre — c'est rarement automatique."
```

**Verification before commit:**
```bash
# Banned-terms scan (LSFin)
python3 tools/checks/banned_terms_python.py apps/mobile/assets/metaphors.toml
# Accent lint
python3 tools/checks/accent_lint_fr.py apps/mobile/assets/metaphors.toml
```

### Anti-Patterns to Avoid

- **Hand-rolling TOML parser** — already covered in Standard Stack. Use the `toml` pub package.
- **Wrapping the 4-tab `destinations` list with an `if/else` returning two lists** — produces noisy diffs and breaks the `applyFromMap` hot-reload path. Use a single conditional `if (showChatTab)` element insertion (see Pattern 1).
- **Storing `turn_count` in the `CoachChatRequest` body and trusting the client** — client can lie. The CONTEXT D-08 wording « turn_count: int field on CoachChatRequest (incremented client-side) » is a HINT only ; the SERVER is the source of truth via the in-memory dict. The client field is advisory for telemetry parity but the server-side count IS the gate.
- **Raising HTTPException on hook digit detection** — explicitly forbidden by D-16 (« NEVER 500s the response »). Always swap, never raise.
- **Mutating a frozen Pydantic model** — `NarrativeSleeve` is frozen ; use `sleeve.model_copy(update={"hook": HOOK_FALLBACK})`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| TOML parsing (Dart) | Regex + string-split | `toml: ^0.16.0` pub package | TOML v1.1.0 has multiline strings, escape sequences, inline tables — regex parsing is a future-debt trap. |
| TOML parsing (Python) | Custom parser | `tomllib` stdlib (Python 3.11+) | Same as above. Railway = 3.12 per pyproject.toml:50, no new dep needed. |
| Reveal/expand animation | Custom `AnimationController` + `Tween` for 48dp slide | Flutter built-in `AnimatedSize` + `AnimatedOpacity` | Built-ins handle vsync, dispose, curve sampling. AnimationController is overkill for a single-shot 200ms easeOut. |
| Hook digit detection | Custom char-by-char scan | `re.compile(r"\d")` | One-liner. Phase 94 precedent : `citation_parser.py:116` `_BANNED_AFFIRMATIVE_VERB_RE = re.compile(...)`. |
| `frozen` immutable update | Mutate then re-validate | Pydantic v2 `.model_copy(update={...})` | Phase 95 precedent : `grounding_pack.py:51` `frozen=True` + Pydantic-idiomatic `model_copy`. |
| Server-overridable boolean flag | Custom polling | Existing `FeatureFlags.applyFromMap` + `refreshFromBackend` (6h periodic) | `feature_flags.dart:114-180` [VERIFIED]. Already shipped, just add 1 entry. |
| Modal bottom sheet for verb chips | Custom dialog route | `showModalBottomSheet` (Flutter Material) | Per UX panel `2026-05-10-phase-96-ux-panel.md` Q2: « NO bottom sheet … inline reveal ». The OVERLAY itself is a bottom sheet (D-06 « MintChatOverlay modal ») ; the verb chip ROW is inline. |
| Sentry breadcrumb wiring | Custom logger | `sentry_sdk.add_breadcrumb(category="coach.chat_overflow.turn_4", ...)` | Phase 94 (`coach_chat.py:3329 coach.citation_gate`) + Phase 95 (`citation_parser.py:387 coach.grounding_pack.fallback`) precedent. Same `try/except Exception: pass` envelope (fail-open). |

**Key insight:** every problem above has a battle-tested standard in MINT's existing stack. Phase 96 must consume existing primitives, not invent parallel ones. The Phase 90 lint `prefer_mint_color_token` already enforces this for colors.

---

## Common Pitfalls

### Pitfall 1: NavigationBar index shift breaks `goBranch`

**What goes wrong:** When `chatTabVisible=false`, the visible `destinations` list has 3 items (indices 0/1/2 = Aujourd'hui / Mon Argent / Explorer). But the underlying `StatefulShellRoute.indexedStack` STILL has 4 branches (Aujourd'hui=0 / Mon Argent=1 / Coach=2 / Explorer=3). Calling `navigationShell.goBranch(2)` on a 3-tab UI lands the user on the (hidden) Coach branch, not Explorer.

**Why it happens:** `NavigationBar.onDestinationSelected(index)` returns the VISIBLE index ; `StatefulShellRoute` operates on BRANCH index. Without a remap, they diverge.

**How to avoid:** Map visible→branch index explicitly when flag is off (Pattern 1 code snippet `final branchIndex = showChatTab ? index : (index >= 2 ? index + 1 : index)`). Add a Flutter widget test that asserts both nav layouts route correctly.

**Warning signs:** Tapping Explorer opens an empty/hidden Coach branch. Backstack behaves weirdly. Sim screenshots show wrong screen for the selected tab.

### Pitfall 2: ARB parity gate blocks merge if any locale misses `verbExplique`/`verbSimule`/`verbRassure`

**What goes wrong:** Phase 90 lint `validate_arb_parity()` returns FAIL if any of the 3 new keys is missing from en/de/es/it/pt (the fr is the source). Merge blocked until all 6 locales contain the key.

**Why it happens:** `flutter gen-l10n` auto-generates the Dart stubs but does NOT translate. Translation is a manual step.

**How to avoid:** **Front-load translation as a dedicated Wave 1 task.** Plan must specify a single task that adds `verbExplique` / `verbSimule` / `verbRassure` to all 6 ARB files in one PR (not interleaved with widget code). Suggested DE translation per UX panel: « Erkläre mir » / « Simulieren » / « Beruhige mich » (note: « Beruhige mich » is clinical per UX panel — flag for native review BEFORE TestFlight). Suggested PT: « Explica-me » / « Simula » / « Tranquiliza-me ». IT: « Spiegami » / « Simula » / « Rassicurami ». ES: « Explícame » / « Simula » / « Tranquilízame ». EN: « Explain to me » / « Simulate » / « Reassure me ».

**Warning signs:** CI lint fails « ARB parity: key `verbRassure` missing in `app_de.arb` ».

### Pitfall 3: In-memory turn_count drifts across uvicorn workers

**What goes wrong:** Production may run uvicorn with `--workers N` (default in Railway can be >1). Each worker process has its own `TURN_COUNTER: Dict` ; the same `(session_id, source_card_id)` key may have count=2 on worker A and count=0 on worker B. User's second turn lands on worker B and the cap doesn't fire as expected.

**Why it happens:** In-memory state is per-process by definition.

**How to avoid:** **Default Phase 96 deploy runs with workers=1 on Railway staging.** Document this in the W2 plan + deploy notes. If G2 (Julien device walkthrough) surfaces drift, Phase 97 adds Redis backing per CONTEXT §"Deferred Ideas" §7. Add a STATE.md note tracking this caveat.

**Warning signs:** Maestro G1 flow passes deterministically (single uvicorn worker) BUT Julien's TestFlight session shows turn 4 going through the LLM (cap silently bypassed).

### Pitfall 4: Phase 96 W2 starts before Phase 95 W2 merges → schema/import mismatch

**What goes wrong:** Phase 96 W2 wires `pack: ProjectionGroundingPack | None` into the source_card branch. If Phase 95 W2 hasn't merged yet, the import target doesn't exist, breaking the build OR forcing a stub.

**Why it happens:** Sequencing-compliance panel locked strict-sequential per Julien's GSD-respect directive ; but auto-loop velocity tempts overlap.

**How to avoid:** Plan 96-02 (Wave 2) executor checks `gh pr view <95-W2-PR>` for `mergedAt != null` BEFORE starting the wave. If null, surface and pause. The CONTEXT D-20 SOFT-dependency wording does NOT mean « start in parallel » — it means « ship the optional fallback when GroundingPack lands ». Until 95 W2 ships, 96 W2 has no consumer for the pack and must wait.

**Warning signs:** Import error `from app.services.coach.grounding_pack import ProjectionGroundingPack` at test collection. coach_chat.py merge conflicts.

### Pitfall 5: Maestro G1 sim hits localhost instead of staging Railway

**What goes wrong:** Per memory `feedback_app_targets_staging_always.md`, the Maestro flow MUST hit `mint-staging.up.railway.app`. If the sim build is configured against `localhost:8000`, the cap never hits (no real backend) OR hits a stale backend snapshot.

**Why it happens:** Build flavor config drift. Phase 94 precedent at `flow_narrator_refuses_uncited_numbers.yaml:57-58` explicitly comments « Backend = Railway staging mint-staging.up.railway.app … NEVER local backend ».

**How to avoid:** Plan 96-03 task that opens the Maestro flow must explicitly verify the sim build's `API_BASE_URL` env points to staging Railway BEFORE running the flow. Reference the diff command pattern from memory `feedback_diff_against_existing_tool.md` against `flow_narrator_refuses_uncited_numbers.yaml`. Also: pre-flag-flip baseline metric pull (`chat_turn_distribution`) MUST come from staging Sentry, not local.

**Warning signs:** Maestro exits 0 but Sentry shows zero `chat_overflow.turn_4` breadcrumbs on the staging project.

### Pitfall 6 (informational, NOT in scope): `coach_chat.py:3079` carries a pre-existing banned-term hit

**What goes wrong (already broken, not Phase 96's job):** The string « Salaire assure LPP » exists at `coach_chat.py:3079` from the 2026-04-17 era ([CITED: pre-existing per planner brief]). « assure » is on CLAUDE.md §1 banned-term list. The LSFin banned-terms scan SHOULD flag it but somehow doesn't (likely an exempt-line marker or scanner gap).

**Why it matters for Phase 96:** Plan 96-02 will add lines NEAR line 3079 (the narrator wrapper expansion). The executor MUST NOT « clean up » that pre-existing line per Karpathy #3 surgical-changes principle. Just note it for a future cleanup phase.

**How to avoid:** Plan note + lint exemption documented. Do NOT touch line 3079 in Phase 96 PRs.

**Warning signs:** Banned-terms lint flagging line 3079 mid-Phase-96-PR. Disposition: not Phase 96's job, file a follow-up.

---

## Code Examples

### Example 1: Sentry breadcrumb naming (precedent → Phase 96)

**Phase 94 precedent** at `coach_chat.py:3329` [VERIFIED]:
```python
sentry_sdk.add_breadcrumb(
    category="coach.citation_gate",
    message=verdict_label,
    level="info",
    data={...},
)
```

**Phase 95 precedent** at `citation_parser.py:387` [VERIFIED]:
```python
sentry_sdk.add_breadcrumb(
    category="coach.grounding_pack.fallback",
    message="pack miss -> registry lookup",
    level="info",
    data={"key": key, "reason": "pack_miss"},
)
```

**Phase 96 mirror:**
```python
sentry_sdk.add_breadcrumb(
    category="coach.chat_overflow.turn_4",  # VERB-05 metric
    message="3-turn cap hit",
    level="info",
    data={"source_card_id": ..., "turn_count": ...},
)
```

Plus related events under same category prefix (`coach.card_action.tap_explique` etc. per Claude's Discretion).

### Example 2: Maestro flow `flow_card_action_intent_bar.yaml` (D-27)

```yaml
# Source: tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml (NEW per D-27)
#
# Phase 96 G1 — card-action intent bar + 3-turn cap + Explorer deep-link.
# Diff'd line-by-line against flow_narrator_refuses_uncited_numbers.yaml
# per memory feedback_diff_against_existing_tool.md.
#
# Backend = Railway staging mint-staging.up.railway.app (per memory
# feedback_app_targets_staging_always.md). NEVER local backend.
# FeatureFlags.chatTabVisible MUST be false on staging for this flow.
#
# Pre-condition :
# - App installed on booted iPhone 17 Pro sim, bundle id ch.mint.app
# - Backend = Railway staging
# - Feature flag `chatTabVisible=false` ON staging (3-tab nav)
# - At least one card on Aujourd'hui screen labelled « Mon 3a 2026 » or
#   close FR variant (regex tolerance in the assertVisible step)

appId: ch.mint.app
tags:
  - phase-96
  - gate-g1
  - card-action-intent-bar
  - turn-cap
---

# 01 — cold launch + landing
- launchApp:
    clearState: true
- assertVisible: "Aujourd'hui"
- takeScreenshot: "01-3-tab-nav"

# 02 — verify chat tab is GONE (regression assertion for D-01)
- assertNotVisible: "Coach"
- takeScreenshot: "02-no-coach-tab"

# 03 — locate the « Mon 3a 2026 » card on Aujourd'hui
- assertVisible: ".*[Mm]on 3a.*"
- takeScreenshot: "03-card-located"

# 04 — tap the card → intent bar reveals
- tapOn: ".*[Mm]on 3a.*"
- extendedWaitUntil:
    visible:
      text: "Explique-moi"
    timeout: 4000
- assertVisible: "Explique-moi"
- assertVisible: "Simule"
- assertVisible: "Rassure-moi"
- takeScreenshot: "04-intent-bar-revealed"

# 05 — tap « Explique-moi » → MintChatOverlay opens
- tapOn: "Explique-moi"
- extendedWaitUntil:
    visible:
      text: ".*Écris.*"
    timeout: 8000
- takeScreenshot: "05-overlay-opened"

# 06 — send turn 1
- tapOn:
    text: ".*Écris.*"
- inputText: "Explique-moi ce 3a"
- pressKey: Enter
- extendedWaitUntil:
    visible:
      text: ".*Information générale.*"  # disclaimer renders after stream
    timeout: 60000
- takeScreenshot: "06-turn-1"

# 07 — send turn 2
- tapOn:
    text: ".*Écris.*"
- inputText: "Et le plafond ?"
- pressKey: Enter
- waitForAnimationToEnd:
    timeout: 5000
- takeScreenshot: "07-turn-2"

# 08 — send turn 3
- tapOn:
    text: ".*Écris.*"
- inputText: "Et si je suis indépendant ?"
- pressKey: Enter
- waitForAnimationToEnd:
    timeout: 5000
- takeScreenshot: "08-turn-3"

# 09 — turn 4 attempt — MUST return the D-10 terminal template, zero LLM cost.
- tapOn:
    text: ".*Écris.*"
- inputText: "Encore une question"
- pressKey: Enter
- extendedWaitUntil:
    visible:
      text: ".*Tu as exploré 3 angles sur cette carte.*"
    timeout: 8000
- assertVisible: ".*Explorer.*"
- takeScreenshot: "09-turn-cap-fired"

# 10 — tap the Explorer deep-link → confirms navigation
- tapOn: ".*Explorer.*"
- extendedWaitUntil:
    visible:
      text: "Explorer"  # the Explorer tab label or screen heading
    timeout: 4000
- takeScreenshot: "10-explorer-deeplink"

# ─── ACCEPTANCE ───────────────────────────────────────────────────
# Exit 0 = G1 pass. Per CLAUDE.md §9.6, the run output IS the deterministic citation.
#
# Run command (per memory reference_maestro_setup.md):
#   bash tools/simulator/maestro_env.sh test \
#     tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml \
#     --device "B03E429D-0422-4357-B754-536637D979F9" \
#     --format junit --output result.xml
```

### Example 3: ARB key precedent

**Source: `app_fr.arb` already contains** (verified via grep):
```json
"tabAujourdhui": "Aujourd'hui",
"tabMonArgent": "Mon argent",
"tabCoach": "Coach",
"tabExplorer": "Explorer"
```

**Add for Phase 96 (D-05):**
```json
"verbExplique": "Explique-moi",
"@verbExplique": {
  "description": "MintCardActionBar verb chip — opens MintChatOverlay with intent=explain (Phase 96 D-05)"
},
"verbSimule": "Simule",
"@verbSimule": {
  "description": "MintCardActionBar verb chip — deep-links to Explorer simulator, zero LLM cost (Phase 96 D-05/D-06)"
},
"verbRassure": "Rassure-moi",
"@verbRassure": {
  "description": "MintCardActionBar verb chip — opens MintChatOverlay with intent=reassure (Phase 96 D-05)"
}
```

Same 3 keys MUST appear in `app_en.arb`, `app_de.arb`, `app_es.arb`, `app_it.arb`, `app_pt.arb` before merge (D-25).

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Chat tab as nav destination | Chat as verb invoked from cards | Phase 96 (v2.9 milestone) | Eliminates open-ended exploration UI ; 3 task-focused verbs per Cleo doctrine |
| Untyped `profile_context: dict` only | + Typed `source_card: SerializedCardContext` (Pydantic v2 frozen) | Phase 96 D-12 | Closed-world card context propagation, narrator gets structured snapshot |
| Phase 94 single citation gate | Phase 94 gate FIRST → Phase 96 hook linter SECOND (response middleware chain) | Phase 96 D-16 | Order-locked ; hook digit-free linter never reverses with citation gate |
| Phase 94 18-key `CITATION_REGISTRY` only | Phase 95 W2 double-lookup `pack.entries.get(key) or registry.resolve(key)` | Phase 95 W2 (shipped 2026-05-10) | Phase 96 W2 just consumes ; no new wiring needed |
| Open-ended chat sessions | STRICT 3-turn cap per `(session_id, card_id)` server-side, zero LLM cost at turn 4 | Phase 96 D-08..D-10 | Token cost ceiling per card-session ; behavioral contract testable |

**Deprecated/outdated:**
- The Phase 90-92 « coach tab as a top-level destination » UX is being killed (D-01) ; GoRouter branch stays for backward-compat but is no longer surfaced.
- Hand-roll metaphor strings inline in narrator system prompts (no precedent exists, but explicit anti-pattern per UX panel — TOML library is the single source of truth).

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `toml: ^0.16.0` is the latest stable Dart TOML package as of 2026-05-11 | Standard Stack | Plan picks wrong version ; `flutter pub get` resolves to compatible newer ; LOW risk. Mitigation : planner verifies `flutter pub upgrade --dry-run` before pinning. |
| A2 | Railway staging python runtime is 3.12 (per pyproject.toml:50 comment) | Standard Stack — Python TOML | If Railway downgrades to 3.10, `tomllib` import breaks. LOW risk — Railway pin is a known artifact in the comment. Mitigation : add `tomli` to pyproject only if explicit drop to 3.10. |
| A3 | German translation « Beruhige mich » is clinical and may need native review | Pitfall 2 | Risk : Julien's German testers find it cold/unnatural at G2. MEDIUM risk — flag in plan-96-01 task « DE translation gate ». |
| A4 | Multi-process drift on `TURN_COUNTER` only manifests when uvicorn `workers > 1` | Pitfall 3 | Risk : if Railway default deploys multi-worker, cap silently bypassed. MEDIUM risk — plan-96-02 documents workers=1 explicitly. |
| A5 | `_run_narrator_with_gate` wrapper at `coach_chat.py:3345` is the only narrator-entry point in the auth-coach path | D-08..D-11 | Risk : a parallel path exists (anonymous_chat.py) and bypasses the cap. Per Phase 94 deferred-items.md D1, anonymous_chat.py has NO gate wrapper — Phase 96 inherits this scope limit. Plan must note: cap is auth-coach only. LOW-MEDIUM risk. |
| A6 | The 6-entry metaphor bootstrap (3 archetypes × 2 cantons × 2 events) is sufficient for v1 launch | D-17 | Risk : narrator falls back to empty metaphor often, NarrativeSleeve.metaphor renders blank, UX feels generic. MEDIUM — UX panel explicitly accepted this as v1 ; expansion is post-v2.9 content sprint (D-19). |
| A7 | `flutter analyze` 0-warnings + `flutter test` ≥229 baseline + 6-locale ARB parity exhaust the Flutter-side compliance bar | D-24/D-25 | Risk : a new lint (e.g. `prefer_mint_text_style`) blocks ; planner must verify all currently-active lints. LOW. |

**Note:** A1, A2, A3, A4, A5, A6 are flagged for planner attention. None are blocking ; all have documented mitigations.

---

## Open Questions

1. **Where do existing card widgets live, and which ones get `MintCardActionBar` attached?**
   - What we know : 6 card widgets exist at `apps/mobile/lib/widgets/` (`action_card.dart`, `action_insight_widget.dart`, `confidence_breakdown_card.dart`, `enrichment_suggestion_card.dart`, `fri_action_suggestion.dart`, `recommendation_card.dart`) [VERIFIED via ls]. Plus screen-specific cards in `apps/mobile/lib/screens/`.
   - What's unclear : Which of these are user-facing on Aujourd'hui / Mon Argent and need the action bar? CONTEXT D-04 says « each card » but doesn't enumerate.
   - Recommendation : Plan 96-01 Task 0 (discovery) scans card widgets and proposes the minimum set (e.g. just `recommendation_card.dart` + `action_card.dart` for v1) ; defer the rest to a post-96 sweep. The Maestro G1 only needs ONE card to surface the verb bar.

2. **How does the Flutter side propagate `intent: "explain" | "reassure"` to the backend?**
   - What we know : `CoachChatRequest` has no `intent` field today. The narrator system prompt is the only differentiator between explain/reassure modes.
   - What's unclear : Does the backend need a new `intent: Literal["explain", "reassure"]` field on `CoachChatRequest`, or does the narrator infer intent from the message body? CONTEXT D-06 specifies routing but not the wire format.
   - Recommendation : Plan 96-02 Task 1 adds `intent: Optional[Literal["explain", "reassure"]] = None` to `CoachChatRequest`. Backend uses it to select a system-prompt variant ; client side `MintChatOverlay` passes it through.

3. **Does the `MintChatOverlay` render `NarrativeSleeve.hook`, `caption`, `next_step`, `metaphor` as separate visual blocks?**
   - What we know : CONTEXT D-14 defines the 4 fields. UX panel describes `hook` as an « opening sentence » and `caption` as the « cited number(s) sentence ».
   - What's unclear : The visual hierarchy. Does the overlay show 4 separate text blocks? Single concatenated paragraph? Markdown? CONTEXT doesn't specify and DESIGN_SYSTEM.md isn't loaded.
   - Recommendation : Plan 96-03 Task on overlay rendering should default to a single flowing paragraph (`hook + " " + caption + " " + next_step` ; `metaphor` rendered as italic footer if non-empty). UX panel signs off in plan-check.

4. **Where does the symlink/duplicate of `metaphors.toml` live on the backend side?**
   - What we know : `apps/mobile/assets/metaphors.toml` is the Flutter-loaded source. Backend mirror at `services/backend/app/data/metaphors.toml` reads the SAME content.
   - What's unclear : Symlink vs duplicate-and-CI-check. Symlinks may not survive Railway's build env.
   - Recommendation : Duplicate (not symlink). Add a CI check `tools/checks/metaphor_parity.py` that asserts byte-equality between the two paths. Plan 96-03 Task adds this.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All W1 Flutter work | ✓ | ≥3.6.0 | — |
| `go_router` | D-02/D-06 | ✓ | ^13.2.0 | — |
| `provider` | D-03 ConversationStore reuse | ✓ | ^6.1.1 | — |
| `sentry_flutter` | VERB-05 client-side breadcrumbs (optional) | ✓ | 9.14.0 | — |
| `toml` (Dart) | D-17/D-18 metaphor library | ✗ | — | **Add `toml: ^0.16.0` to pubspec.yaml** |
| Python 3.11+ stdlib `tomllib` | D-18 backend mirror | ✓ | bundled (Python 3.12 on Railway) | If Railway downgrades to 3.10, add `tomli` backport |
| Pydantic v2 | D-12/D-14 schemas | ✓ | project-wide | — |
| FastAPI | D-13 endpoint extension | ✓ | project-wide | — |
| `sentry-sdk` (Python) | D-11 backend breadcrumbs | ✓ | project-wide | — |
| Maestro 2.5.1+ | D-27 G1 flow | ✓ | per memory `reference_maestro_setup.md` | — |
| iPhone 17 Pro sim | D-27 G1 flow target | ✓ | UDID B03E429D-0422-4357-B754-536637D979F9 (per Phase 94 precedent) | — |
| Railway staging URL `mint-staging.up.railway.app` | D-27 G1 backend target | ✓ | per memory `feedback_app_targets_staging_always` | — |
| Anthropic API key on Railway staging | D-27 narrator turn 1-3 | ✓ | per memory `feedback_anthropic_key_on_railway` (key IS configured ; stop guessing) | — |
| `validate_arb_parity()` MCP tool | D-25 gate | ✓ | per CLAUDE.md §3 | — |
| `accent_lint_fr.py` | D-23 gate | ✓ | `tools/checks/accent_lint_fr.py` per CLAUDE.md §1 | — |
| `banned_terms_python.py` | D-23 gate | ✓ | `tools/checks/banned_terms_python.py` per CLAUDE.md §1 | — |

**Missing dependencies with no fallback:**
- None.

**Missing dependencies with fallback:**
- `toml` (Dart pub package) → add to `pubspec.yaml` in Plan 96-01 Task 1 (Flutter scaffolding).

---

## Validation Architecture

> `workflow.nyquist_validation: true` in `.planning/config.json` [VERIFIED]. Section required.

### Test Framework

| Property | Value |
|----------|-------|
| Flutter framework | `flutter_test` (SDK bundled) ; `integration_test` for Maestro setup |
| Flutter config | `apps/mobile/test/` directory ; ≥229 baseline tests per CONTEXT D-24 |
| Python framework | `pytest` ; current baseline 6479 tests post-Phase 95 W1 [VERIFIED at STATE.md] |
| Python config | `services/backend/pyproject.toml` + lefthook pre-commit |
| Quick run (Flutter) | `cd apps/mobile && flutter test test/widgets/mint_card_action_bar_test.dart` |
| Quick run (Python) | `cd services/backend && pytest tests/test_card_context/ -q` |
| Full suite (Flutter) | `cd apps/mobile && flutter analyze && flutter test` |
| Full suite (Python) | `cd services/backend && python3 -m pytest tests/ -q` |
| ARB parity | `validate_arb_parity()` MCP tool (CLAUDE.md §3) |
| Maestro G1 | `bash tools/simulator/maestro_env.sh test tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml --device <UDID> --format junit --output result.xml` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| VERB-01 | 3 verb chips visible after tap, 48dp / 200ms animation | widget (Flutter) + Maestro | `flutter test test/widgets/mint_card_action_bar_test.dart` + Maestro step 04 | ❌ Wave 0 — new widget |
| VERB-01 | « Simule » deep-links to Explorer (zero turns) | widget + Maestro | `flutter test test/widgets/mint_card_action_bar_test.dart::test_simule_deeplinks_to_explorer` + Maestro step (planned 11) | ❌ Wave 0 |
| VERB-02 | Turn 4 returns terminal template, no LLM call | pytest (backend) + Maestro | `pytest tests/test_coach_chat/test_turn_cap.py -q` + Maestro steps 06-09 | ❌ Wave 0 |
| VERB-02 | `chat_overflow.turn_4` Sentry breadcrumb fires | pytest (mock sentry) | `pytest tests/test_coach_chat/test_turn_cap_breadcrumb.py -q` | ❌ Wave 0 |
| VERB-03 | `CoachChatRequest.source_card` Pydantic validation | pytest (schema) | `pytest tests/test_schemas/test_card_context.py -q` | ❌ Wave 0 |
| VERB-03 | Narrator system prompt receives `<source_card>` block when source_card non-None | pytest (integration) | `pytest tests/test_coach/test_source_card_injection.py -q` | ❌ Wave 0 |
| VERB-04 | 3-tab nav when `chatTabVisible=false`, 4-tab when true | widget (Flutter) | `flutter test test/widgets/mint_shell_test.dart::test_flag_gated_destinations` | ❌ Wave 0 — modify existing |
| VERB-04 | `goBranch` index remap correct in both flag states | widget (Flutter) | `flutter test test/widgets/mint_shell_test.dart::test_branch_index_remap` | ❌ Wave 0 |
| VERB-05 | `chat_overflow_turn_4` Sentry metric on cap hit | pytest (mock sentry) | `pytest tests/test_coach_chat/test_turn_cap_breadcrumb.py -q` | ❌ Wave 0 |
| VERB-06 | `chatTabVisible=true` server override re-adds tab without redeploy | widget (Flutter) | `flutter test test/services/feature_flags_test.dart::test_apply_from_map_chatTabVisible` | ❌ Wave 0 |
| D-14 hook | Hook with digit gets swapped to fallback | pytest (linter) | `pytest tests/test_coach/test_narrative_sleeve_linter.py -q` | ❌ Wave 0 |
| D-16 linter | Linter NEVER 500s (returns valid sleeve always) | pytest (chaos) | `pytest tests/test_coach/test_sleeve_linter_never_raises.py -q` | ❌ Wave 0 |
| D-17/D-18 TOML | 6-entry library loads at boot, lookup returns correct strings | Dart + Python unit | `flutter test test/services/metaphor_lookup_test.dart` + `pytest tests/test_coach/test_metaphor_lookup.py -q` | ❌ Wave 0 |
| D-25 ARB | 6-locale parity for 3 new keys | MCP tool | `validate_arb_parity()` | ✓ existing tool |
| D-27 G1 | End-to-end Maestro flow exits 0 on staging | Maestro | (run command above) | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test <changed-test-file>` + `pytest tests/<changed-module>/ -q` (≤ 30s)
- **Per wave merge:** full suite — `flutter analyze && flutter test` + `python3 -m pytest tests/ -q`
- **Phase gate:** full suite green + Maestro G1 exit 0 + ARB parity clean + accent lint clean + banned-terms clean BEFORE `/gsd-verify-work 96`

### Wave 0 Gaps

- [ ] `apps/mobile/test/widgets/mint_card_action_bar_test.dart` — covers VERB-01
- [ ] `apps/mobile/test/widgets/mint_shell_test.dart` — extend with flag-gating tests for VERB-04
- [ ] `apps/mobile/test/services/feature_flags_test.dart` — extend with `chatTabVisible` (VERB-06)
- [ ] `apps/mobile/test/services/metaphor_lookup_test.dart` — covers D-17/D-18 Dart side
- [ ] `apps/mobile/test/models/serialized_card_context_test.dart` — covers VERB-03 Dart side
- [ ] `services/backend/tests/test_schemas/test_card_context.py` — covers VERB-03 Pydantic
- [ ] `services/backend/tests/test_schemas/test_narrative_sleeve.py` — covers D-14
- [ ] `services/backend/tests/test_coach_chat/test_turn_cap.py` — covers VERB-02 (turn cap returns terminal template)
- [ ] `services/backend/tests/test_coach_chat/test_turn_cap_breadcrumb.py` — covers VERB-05
- [ ] `services/backend/tests/test_coach/test_narrative_sleeve_linter.py` — covers D-16 happy path
- [ ] `services/backend/tests/test_coach/test_sleeve_linter_never_raises.py` — covers D-16 chaos (never 500)
- [ ] `services/backend/tests/test_coach/test_metaphor_lookup.py` — covers D-18 Python side
- [ ] `services/backend/tests/test_coach/test_source_card_injection.py` — covers VERB-03 narrator integration
- [ ] `tools/checks/narrative_sleeve_lint.py` + `tests/test_lints/test_narrative_sleeve_lint.py` — covers next_step ≤12 words / verb-first (D-14)
- [ ] `tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml` — D-27 G1 flow
- [ ] `tools/checks/metaphor_parity.py` (CI lint, mobile↔backend byte-equality)

---

## Security Domain

> `security_enforcement` absent in `.planning/config.json` — treat as enabled per defaults.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | indirect (existing JWT on `/api/v1/coach/chat`) | existing FastAPI auth dependency at endpoint (verified — `@router.post` decorator at coach_chat.py:2723) |
| V3 Session Management | yes (turn_count keyed by session_id) | session ID derived from existing auth context ; in-memory dict per-process |
| V4 Access Control | yes (3-turn cap = server-enforced rate limit per source_card) | TURN_COUNTER dict — server is authoritative, client field is advisory |
| V5 Input Validation | yes (SerializedCardContext + CoachChatRequest extensions) | Pydantic v2 `frozen=True, extra="forbid"` rejects unknown fields ; max_length on every string field |
| V6 Cryptography | no | nothing new ; existing TLS + auth path unchanged |
| V7 Error Handling | yes (D-16 hook linter NEVER raises) | linter wraps mutation in try/except ; sentry breadcrumb on swap, no error response |

### Known Threat Patterns for {Flutter mobile + FastAPI backend + Pydantic v2}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Client lies about `turn_count` to skip the cap | Tampering | Server-side authoritative `TURN_COUNTER` dict ; the body field is advisory only |
| Card context smuggling PII in `computed_facts` (e.g. user's name, IBAN) | Info Disclosure | `SerializedCardContext.computed_facts: dict[str, Decimal | int | str]` only — strings can still leak ; planner enforces narrator system prompt block strips/validates string values, and `pii_fixture_scan.py` runs on `computed_facts` samples in tests |
| Narrator response middleware crashes on malformed `hook` and returns 500 | DoS | D-16 mandates linter NEVER raises ; chaos test `test_sleeve_linter_never_raises.py` |
| Replay attack reusing a stale `source_card.card_id` to skip cap | Tampering | TURN_COUNTER keyed by `(session_id, card_id)` — session_id from authenticated context ; replay across sessions resets count per D-09 (acceptable by design) |
| Metaphor TOML poisoning (malicious metaphor injection into narrator prompt) | Tampering | TOML file is a checked-in asset, not user input ; `metaphor_parity.py` CI lint catches drift between mobile/backend copies |
| Turn-cap bypass via uvicorn worker drift | Tampering | Documented as Pitfall 3 ; deploy with workers=1 ; Phase 97 Redis backing if needed |
| Hook regex ReDoS | DoS | `re.compile(r"\d")` is constant-time ; no quantifiers, no nested alternation |

### Sources Verified Against Codebase

- `services/backend/app/services/coach/citation_parser.py:39-119` — ReDoS-safe regex precedent
- `services/backend/app/services/coach/grounding_pack.py:51` — Pydantic v2 frozen+forbid precedent
- `services/backend/app/api/v1/endpoints/coach_chat.py:3329` — Sentry breadcrumb fail-open pattern

---

## Plan Task Skeleton Recommendation

**Total: 3 plans × 5-6 tasks = 17 tasks.**

### Plan 96-01 — Wave 1 Flutter (~2d, INDEPENDENT)

- **T0 (1h) — Discovery + ARB front-load:** Scan card widgets in `apps/mobile/lib/widgets/` + `apps/mobile/lib/screens/`. Propose minimum card set for v1 (target: ≤2 widgets ; e.g. `recommendation_card.dart` + `action_card.dart`). Add `verbExplique` / `verbSimule` / `verbRassure` to all 6 ARB files. Run `flutter gen-l10n`. Verify `validate_arb_parity()` clean. **Tests:** ARB parity tool.
- **T1 (3h) — `MintCardActionBar` widget (TDD):** Implement widget per Pattern 2 above. Write `mint_card_action_bar_test.dart` first (3 verb chips visible, animated reveal toggles, tap routes correctly). **Tests:** ≥4 widget tests.
- **T2 (2h) — `mint_shell.dart` flag-gate (TDD):** Add `FeatureFlags.chatTabVisible` (default false). Modify `MintShell.build` per Pattern 1. Add `mint_shell_test.dart` cases for both flag states + branch index remap. **Tests:** ≥3 widget tests + 1 feature_flags unit test.
- **T3 (2h) — `MintChatOverlay` scaffold:** New widget `mint_chat_overlay.dart` — wraps existing `CoachChatScreen` route. Receives `sourceCard: SerializedCardContext` + `intent: String` from `MintCardActionBar`. Opens via `showModalBottomSheet`. **Tests:** smoke render + intent prop propagation.
- **T4 (2h) — `metaphor_lookup.dart` + `metaphors.toml` (TDD):** Add `toml: ^0.16.0` to `pubspec.yaml`. Add `assets/metaphors.toml` with 6 entries per Pattern 7. Add `metaphor_lookup.dart` per Pattern 6 Dart side. Wire `MetaphorLookup.loadFromAssets()` in app boot (`main.dart`). **Tests:** ≥6 unit tests (each entry + 1 miss).
- **T5 (1h) — `SerializedCardContext` Dart mirror + close-out:** Create `apps/mobile/lib/models/serialized_card_context.dart` — JSON-serializable mirror of the backend Pydantic schema (D-12). Run `flutter analyze` + `flutter test`. Confirm ≥229 baseline. Write `96-01-SUMMARY.md`. **Tests:** model round-trip test.

**Compliance gates (pre-merge W1):** D-23 (banned-terms / PII / no-legal / accent) + D-24 (`flutter analyze`/test) + D-25 (ARB parity) + D-26 (zero hardcoded colors via grep).

### Plan 96-02 — Wave 2 Backend (~2d, HARD-BLOCKS on Phase 95 W2 merge)

- **T0 (15min) — Phase 95 W2 merge gate:** Run `gh pr view <95-W2-PR>` and verify `mergedAt != null`. If null, surface to orchestrator and pause. Do NOT start W2 until 95 W2 ships.
- **T1 (2h) — `SerializedCardContext` Pydantic schema (TDD):** Create `services/backend/app/schemas/card_context.py` per Pattern 3. Write `tests/test_schemas/test_card_context.py` first (frozen, forbid, max_length, optional-None handling). **Tests:** ≥10 unit tests.
- **T2 (2h) — `NarrativeSleeve` Pydantic schema (TDD):** Create `services/backend/app/schemas/narrative_sleeve.py` per Pattern 3. **Tests:** ≥6 unit tests.
- **T3 (2h) — `CoachChatRequest` + `CoachChatResponse` extensions:** Add `source_card: Optional[SerializedCardContext] = None` + `turn_count: int = 0` + `intent: Optional[Literal["explain", "reassure"]] = None` to `CoachChatRequest`. Add `narrative_sleeve: Optional[NarrativeSleeve] = None` to `CoachChatResponse`. **Tests:** schema-level + 1 endpoint integration smoke.
- **T4 (3h) — `turn_counter.py` + `_run_narrator_with_gate_and_cap` (TDD):** Per Pattern 4 above. Write `tests/test_coach_chat/test_turn_cap.py` first (turns 1/2/3 pass through, turn 4 returns terminal template, breadcrumb fires). **Tests:** ≥6 integration tests.
- **T5 (2h) — Narrator system prompt `<source_card>` block injection:** Modify `services/backend/app/services/coach/claude_coach_service.py:build_narrator_system_prompt*` to accept `source_card: Optional[SerializedCardContext]` and inject the `<source_card>` block when non-None. **Tests:** ≥4 prompt-builder tests (block presence/absence + each field rendered).
- **T6 (1h) — `metaphor_lookup.py` backend + close-out:** Create `services/backend/app/services/coach/metaphor_lookup.py` per Pattern 6. Place `services/backend/app/data/metaphors.toml` (duplicate of mobile asset). Add `tools/checks/metaphor_parity.py` CI lint. Run `pytest -q` ≥6479 baseline (Phase 95 W1 baseline). Write `96-02-SUMMARY.md`. **Tests:** ≥6 unit tests + parity lint.

**Compliance gates (pre-merge W2):** D-23 all + verified Sentry breadcrumb category convention (`coach.chat_overflow.turn_4`).

### Plan 96-03 — Wave 3 cross-stack (~1d, HARD-BLOCKS on W2 merge + staging exercise)

- **T0 (15min) — W2 merge + staging exercise gate:** Verify W2 PR `mergedAt != null` AND verify staging Railway deploy succeeded AND verify a single test turn through `/api/v1/coach/chat` with `source_card` set returns successfully. If any fails, pause.
- **T1 (2h) — `narrative_sleeve_linter.py` (TDD):** Create per Pattern 5. Write `test_narrative_sleeve_linter.py` (digit detected → swap ; no digit → passthrough) + `test_sleeve_linter_never_raises.py` (chaos: empty hook, very long hook, unicode edge cases). Wire into `_run_narrator_with_gate_and_cap` AFTER citation gate, BEFORE response serialization (D-16). **Tests:** ≥8.
- **T2 (1h) — `tools/checks/narrative_sleeve_lint.py`:** Pre-commit lint for `next_step` ≤12 words + verb-first (D-14). Register in `lefthook.yml`. **Tests:** ≥4 lint cases (pass, too long, not verb-first, banned term).
- **T3 (2h) — `flow_card_action_intent_bar.yaml` Maestro G1 (D-27):** Create per Example 2 above. Verify build flavor points to staging Railway BEFORE running (Pitfall 5). Run flow ; iterate until exit 0. **Evidence:** screenshots committed to `.planning/walker/maestro-flows/card-action-intent-bar/<run-id>/`.
- **T4 (1h) — Pre-flag-flip baseline pull (D-11):** Pull 7-day `chat_turn_distribution` from staging Sentry (or document the empty baseline if no traffic). Compute hypothetical cap-hit rate. If real rate > 40%, recommend flag stays OFF in prod and surface to orchestrator. Document in `96-03-FLAG-FLIP-PROPOSAL.md`.
- **T5 (1h) — Close-out:** Write `96-03-SUMMARY.md` + `96-VERIFICATION-REPORT.html` (per memory `feedback_html_evidence_report.md`). Update `STATE.md` to Phase 96 verifying. Confirm 0-trust: cite Maestro G1 exit code + full pytest count + flutter analyze + ARB parity.

**Compliance gates (pre-merge W3):** All D-23 + D-26 + D-27 (Maestro exit 0 on staging) + 0-trust audit.

### G2 (HUMAN-UAT) — Julien device walkthrough

Per D-28 + CLAUDE.md §9 : end-to-end flow on Julien's TestFlight device. Phase 96 cannot claim « ready » without G2 completing. Steps (verbatim from CONTEXT D-28) :
1. Open card « Mon 3a 2026 ».
2. Tap « Explique-moi » → MintChatOverlay renders with cited numbers.
3. Send 3 turns.
4. Turn 4 → terminal template + Explorer deep-link.
5. Tap deep-link → Explorer scene renders.

---

## Sources

### Primary (HIGH confidence)
- `apps/mobile/lib/widgets/mint_shell.dart:46-67` — NavigationBar destinations [VERIFIED via Read]
- `apps/mobile/lib/services/feature_flags.dart:30-181` — flag mechanism + `applyFromMap` + `refreshFromBackend` [VERIFIED]
- `apps/mobile/lib/services/coach/conversation_store.dart` — Provider-based session state [VERIFIED via find]
- `apps/mobile/lib/theme/colors.dart` — MintColors palette [VERIFIED]
- `apps/mobile/lib/l10n/app_fr.arb` — existing `tabCoach`/`tabAujourdhui` ARB key precedent [VERIFIED via grep]
- `apps/mobile/pubspec.yaml` — current Flutter deps, `toml` package absent [VERIFIED]
- `services/backend/app/schemas/coach_chat.py:29-186` — `CoachChatBaseModel` + `CoachChatRequest` + `CoachChatResponse` Pydantic v2 [VERIFIED via Read]
- `services/backend/app/services/coach/grounding_pack.py:51` — Pydantic v2 `frozen=True, extra="forbid"` precedent [VERIFIED]
- `services/backend/app/services/coach/citation_parser.py:357-398` — `_substitute_placeholders(*, pack=)` double-lookup [VERIFIED]
- `services/backend/app/api/v1/endpoints/coach_chat.py:3329-3389` — `_run_narrator_with_gate` + Sentry breadcrumb pattern [VERIFIED]
- `services/backend/pyproject.toml:9, 50` — Python ≥3.10 ; Railway base = python:3.12-slim [VERIFIED]
- `tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml` — Phase 94 Maestro precedent [VERIFIED]
- `.planning/phases/96-mvp-chat-as-verb/96-CONTEXT.md` — D-01..D-28 locked decisions [VERIFIED]
- `.planning/decisions/2026-05-10-95-96-autonomous-sequence-master.md` — master synthesis [VERIFIED]
- `.planning/decisions/2026-05-10-phase-96-ux-panel.md` — Phase 96 UX brief [VERIFIED]
- `.planning/decisions/2026-05-09-calc-first-llm-illumination.md` — N1/N4 strategic mandate [VERIFIED]
- `.planning/STATE.md` — milestone progress + Phase 95 W1 baselines (6479 tests, hash parity 50/50) [VERIFIED]
- `.planning/config.json` — `workflow.nyquist_validation: true` [VERIFIED]
- CLAUDE.md §1 (banned terms), §2 (accents), §3 (MINT ≠ retirement app), §9 (0-trust) [project root, VERIFIED]
- `.claude/skills/mint-flutter-dev/SKILL.md` — MintUI kit + GoRouter + Provider conventions [VERIFIED]
- `.claude/skills/mint-swiss-compliance/SKILL.md` — LSFin enforcement + forbidden words table [VERIFIED]

### Secondary (MEDIUM confidence — WebSearch verified)
- [toml | Dart package — pub.dev](https://pub.dev/packages/toml) — TOML v1.1.0 support, MIT, just95/toml.dart, last updated for TOML v1.1.0 multiline/inline-table features
- [GitHub - just95/toml.dart: TOML parser and encoder for Dart](https://github.com/just95/toml.dart)
- [AnimatedOpacity class - widgets library - Dart API — api.flutter.dev](https://api.flutter.dev/flutter/widgets/AnimatedOpacity-class.html)
- [AnimatedSize Flutter - GeeksforGeeks](https://www.geeksforgeeks.org/flutter/animatedsize-flutter/)
- [Python tomllib — docs.python.org/3/library/tomllib.html](https://docs.python.org/3/library/tomllib.html) — Python 3.11+ stdlib

### Tertiary (LOW confidence — single source)
- DE/PT/IT/ES translation suggestions for `verbRassure` — flagged for native review (Pitfall 2 / Assumption A3)

---

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — Flutter deps and Pydantic v2 patterns verified via Read on existing codebase ; `toml` pub package verified via pub.dev search
- Architecture: **HIGH** — patterns are concrete code derived from verified existing precedents (Phase 94 + 95 + UX panel)
- Pitfalls: **HIGH** — Pitfalls 1, 4, 5 verified against codebase ; Pitfalls 2, 3 derived from documented memory + UX-panel risks ; Pitfall 6 cited from planner brief
- Plan skeleton: **HIGH** — task budgets are conservative (sum: W1 11h, W2 12h, W3 7h ≈ 30h ≈ 5d wall-clock vs CONTEXT D-22 budget of 2+2+1=5d) ✓
- Maestro flow: **HIGH** — diff'd against Phase 94 precedent per memory `feedback_diff_against_existing_tool`

**Research date:** 2026-05-11
**Valid until:** 2026-06-10 (30 days for stable Flutter/Pydantic stack ; re-verify `toml` pub version before merge)

---

## RESEARCH COMPLETE

**Phase:** 96 - MVP-CHAT-AS-VERB
**Confidence:** HIGH

### Key Findings

- All D-01..D-28 locked decisions have concrete implementation references with file paths + code snippets verified against the existing codebase.
- Standard stack is essentially complete : Flutter SDK 3.6.0, `go_router` 13.2.0, `provider` 6.1.1, `sentry_flutter` 9.14.0, Pydantic v2, FastAPI, `sentry_sdk` (Python). **Only one new dep needed: `toml: ^0.16.0` (Dart)**. Python TOML uses stdlib `tomllib` (Railway = 3.12, verified). `flutter analyze` + `flutter test ≥229 baseline` + `pytest ≥6479 baseline` + ARB parity are the validation foundation.
- 3 plans × 5-7 tasks = **17 tasks total**, wall-clock budget ~30h ≈ 5d. Sequencing is strict-sequential per Julien's GSD-respect directive : W1 (Flutter) starts immediately ; W2 (Backend) hard-blocks on Phase 95 W2 merge ; W3 (cross-stack) hard-blocks on W2 merge + a staging exercise. G2 (Julien device) is the HUMAN-UAT gate per CLAUDE.md §9.
- **6 pitfalls catalogued with mitigations:** navigation index shift (Pattern 1 code), ARB parity gate (front-load translation as T0), multi-process turn_count drift (deploy with workers=1, Redis is Phase 97), Phase 95 W2 merge gate before W2 starts (Plan 96-02 T0 check), Maestro sim must hit staging Railway (Plan 96-03 T3 explicit verification), pre-existing banned-term hit at `coach_chat.py:3079` (out of scope, don't touch).
- Validation Architecture maps 15 phase requirements (VERB-01..VERB-06 + D-14/D-16/D-17/D-25/D-27) to specific test files + commands. Wave 0 gaps enumerated : 14 new test files + 1 Maestro flow + 1 CI lint.

### File Created

`/Users/julienbattaglia/Desktop/MINT.nosync/.planning/phases/96-mvp-chat-as-verb/96-RESEARCH.md`

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | Versions verified via Read on `pubspec.yaml` + `pyproject.toml` ; `toml` pub package verified via pub.dev |
| Architecture | HIGH | All 7 patterns derived from verified codebase precedents (Phase 94 + 95 + Flutter built-ins) |
| Pitfalls | HIGH | 6 risks each grounded in code path + memory + UX-panel risk list |
| Plan skeleton | HIGH | Task hour budget reconciles with CONTEXT D-22 wave budget (~5d total) |
| Maestro flow | HIGH | Diff'd against Phase 94 precedent per memory `feedback_diff_against_existing_tool` |

### Open Questions

1. Exact set of card widgets that get `MintCardActionBar` attached (Plan 96-01 T0 discovery resolves).
2. Wire format for `intent: "explain" | "reassure"` on `CoachChatRequest` (Plan 96-02 T3 resolves).
3. Visual hierarchy of `NarrativeSleeve` 4 fields in `MintChatOverlay` rendering (Plan 96-03 plan-check resolves).
4. Symlink vs duplicate for `metaphors.toml` mobile↔backend (Plan 96-03 T1 resolves via duplicate + parity lint).

### Ready for Planning

Research complete. Planner can create 3 PLAN.md files (96-01, 96-02, 96-03) using the task skeleton above as input.

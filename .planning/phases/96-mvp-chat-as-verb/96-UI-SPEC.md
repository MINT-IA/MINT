---
phase: 96
slug: mvp-chat-as-verb
status: draft
tool: none
created: 2026-05-11
source_docs:
  - 96-CONTEXT.md (D-01..D-28 — locked)
  - 2026-05-10-phase-96-ux-panel.md
  - docs/DESIGN_SYSTEM.md
  - docs/VOICE_SYSTEM.md
  - apps/mobile/lib/theme/colors.dart
  - apps/mobile/lib/theme/mint_text_styles.dart
  - apps/mobile/lib/theme/mint_spacing.dart
  - apps/mobile/lib/theme/mint_motion.dart
  - apps/mobile/lib/widgets/mint_shell.dart
---

# Phase 96 — UI Design Contract (MVP-CHAT-AS-VERB)

> Visual and interaction contract for Phase 96. All decisions in D-01..D-28 (96-CONTEXT.md) are
> LOCKED. This spec deepens them with concrete widget bindings, token references, and interaction
> timing. Executor must not propose alternatives — follow the contract or raise a BLOCKER.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (Flutter Material 3 + MINT custom tokens) |
| Preset | not applicable |
| Component library | MINT UI Kit (`MintCard`, `MintNarrativeCard`, premium widgets) |
| Icon library | Material Icons (outlined variants for rest state, filled for active) |
| Font (headings) | Supreme (bundled Fontshare — replaces Montserrat post Phase 92) |
| Font (body) | Supreme (replaces Inter post Phase 92 MVP-GOOGLEFONTS-PURGE-V1) |
| Font (editorial hero) | Gambarino italic (2 screens max — NOT used in Phase 96 surfaces) |

Source: `apps/mobile/lib/theme/mint_text_styles.dart` (MVP-GOOGLEFONTS-PURGE-V1, 2026-05-10).
Note: Supreme w600 requests render at Bold (700) — nearest-weight Flutter match. Spec keeps w600
to reflect design intent.

---

## Spacing Scale

Declared values (all are exact `MintSpacing.*` tokens — `apps/mobile/lib/theme/mint_spacing.dart`):

| Token | Value | Dart constant | Phase 96 usage |
|-------|-------|---------------|----------------|
| xs | 4dp | `MintSpacing.xs` | Icon-to-label gap inside `_VerbChip` |
| sm | 8dp | `MintSpacing.sm` | Gap between verb chips in MintCardActionBar |
| md | 16dp | `MintSpacing.md` | Horizontal padding inside each `_VerbChip`; MintChatOverlay internal card padding |
| lg | 24dp | `MintSpacing.lg` | MintChatOverlay horizontal screen padding; NarrativeSleeve card padding |
| xl | 32dp | `MintSpacing.xl` | MintChatOverlay top/bottom padding |
| xxl | 48dp | `MintSpacing.xxl` | **MintCardActionBar expansion height** (locked D-04) |

Exceptions:
- MintCardActionBar expansion height = **48dp exactly** (MintSpacing.xxl). This is the 0→48dp
  animated delta; the row itself sits entirely within this 48dp allocation.
- Verb chip vertical padding = **12dp** (not a named token — use `const EdgeInsets.symmetric(vertical: 12, horizontal: 16)`).
- MintChatOverlay drag handle = 40×4dp centered at top, `MintColors.border`, `BorderRadius.circular(2)` — matching DESIGN_SYSTEM.md §4.6 bottom-sheet handle spec.

---

## Typography

All styles reference `MintTextStyles.*` from `apps/mobile/lib/theme/mint_text_styles.dart`.
Zero hardcoded `TextStyle(fontSize: ...)` permitted in Phase 96 widget files (D-26 compliance gate).

### MintCardActionBar — `_VerbChip` labels

| Role | Token | Size | Weight | Color | Usage |
|------|-------|------|--------|-------|-------|
| Verb chip label | `MintTextStyles.labelLarge()` | 15dp | w500 | `MintColors.textSecondary` (rest) / `MintColors.inkPrimary` (pressed) | « Explique-moi », « Simule », « Rassure-moi » |

Rationale: `labelLarge` (15dp w500) is the existing MINT standard for chip text. `labelMedium`
(12dp) is too small for tap targets that double as primary intent buttons. `titleMedium` (16dp w600)
would over-emphasize verbs relative to the card content they annotate.

### MintChatOverlay

| Role | Token | Size | Weight | Color | Usage |
|------|-------|------|--------|-------|-------|
| Overlay header / card title | `MintTextStyles.titleMedium()` | 16dp | w600 | `MintColors.textPrimary` | Overlay title ("Explique-moi" context label) |
| Chat message body | `MintTextStyles.bodyMedium()` | 14dp | w400 | `MintColors.textSecondary` | Coach response text (turns 1-3) |
| Terminal template body | `MintTextStyles.bodyMedium()` | 14dp | w400 | `MintColors.textSecondary` | Static turn-4 message |
| Explorer deep-link CTA | `MintTextStyles.bodyMedium(color: MintColors.mintForest)` | 14dp | w400 | `MintColors.mintForest` | « Explorer → » inline link in terminal |
| Turn counter | `MintTextStyles.labelSmall()` | 11dp | w500 | `MintColors.textMuted` | "1 / 3" turn indicator |

### NarrativeSleeve (card-embedded response)

| Field | Token | Size | Weight | Color | Constraint |
|-------|-------|------|--------|-------|------------|
| `hook` | `MintTextStyles.headlineSmall()` | 20dp | w600 | `MintColors.textPrimary` | Digit-free (enforced by backend linter). Max 15 words. |
| `caption` | `MintTextStyles.bodyLarge()` | 16dp | w400 | `MintColors.textSecondary` | Contains cited numbers post-substitution. Line-height 1.5. |
| `next_step` | `MintTextStyles.labelLarge(color: MintColors.mintForest)` | 15dp | w500 | `MintColors.mintForest` | Verb-first, ≤12 words. Rendered with a leading › glyph at callsite. |
| `metaphor` | `MintTextStyles.bodySmall()` | 13dp | w500 | `MintColors.textMuted` | Optional. Max 20 words. Displayed in a bottom-rule separator block. |

Line heights: hook 1.2, caption 1.5, next_step 1.4, metaphor 1.4 — per existing token defaults.

### 3-tab NavigationBar (MintShell post-flag-gate)

No typography change vs existing shell. Tab labels remain `bodySmall`-equivalent (Material 3
`NavigationDestination` label renders at ~12dp). No new styles introduced for the nav change.

---

## Color

All colors reference `MintColors.*` from `apps/mobile/lib/theme/colors.dart`.
Grep gate (D-26): `grep -rn "Color(0x"` on new widget files must return 0.

### 60/30/10 split for Phase 96 surfaces

| Role | Token | Hex | Usage | Split |
|------|-------|-----|-------|-------|
| Dominant surface | `MintColors.card` | #FFFFFF | MintChatOverlay background, NarrativeSleeve card surface | 60% |
| Secondary surface | `MintColors.craieHandoff` | #F8F5F0 | MintCardActionBar row background (warm cream flush with card bottom) | 30% |
| Accent — emphasis | `MintColors.mintForest` | #2F5F3F | Active verb tap fill, Explorer deep-link color, `next_step` label color | 10% |

### Specific token assignments

| Element | State | Token | Rationale |
|---------|-------|-------|-----------|
| `_VerbChip` background (rest) | Rest | `MintColors.surface` (#F5F5F7) | Neutral, recedes behind card content |
| `_VerbChip` border (rest) | Rest | `MintColors.border` (#D2D2D7) | Subtil per DESIGN_SYSTEM.md §4.1 |
| `_VerbChip` background (pressed/active) | Pressed | `MintColors.mentheVive12` (alpha 12%) | Locked D-07: primary tint on tap — `mentheVive12` = `0x1F7DD3B5` |
| `_VerbChip` text (pressed) | Pressed | `MintColors.inkPrimary` (#1A1A1A) | Higher contrast on tinted bg |
| `_VerbChip` icon (rest) | Rest | `MintColors.textMuted` (#737378) | Icon recedes, text leads |
| `_VerbChip` icon (active) | Pressed | `MintColors.mintForest` (#2F5F3F) | Forest = deep emphasis signal |
| MintChatOverlay scrim | Modal open | `MintColors.nearBlack` at **60% opacity** (`0x99`) | `Color(0x990A0A0F)` — nearBlack hex `#0A0A0F`. Darkens without full black. |
| MintChatOverlay header bar background | All | `MintColors.craieHandoff` (#F8F5F0) | Warm continuity with coach surfaces |
| MintChatOverlay NavigationBar background | Inherits | `MintColors.craie` (#FCFBF8) | Matches existing shell nav background |
| Terminal template background | Turn 4 | `MintColors.saugeClaire` (#D8E4DB) | Calm positive-signal surface (distinct from error) |
| Terminal template text | Turn 4 | `MintColors.textPrimary` (#1D1D1F) | Full contrast on sage bg |
| Explorer deep-link inline | Turn 4 + next_step | `MintColors.mintForest` (#2F5F3F) | Accent reserved for this use — D-07 locked |
| NarrativeSleeve card surface | Embedded | `MintColors.craieHandoff` (#F8F5F0) | Coach / conversation surface per DESIGN_SYSTEM.md |
| « Simule » verb — distinct treatment | Tap | `MintColors.terracotta` at 8% alpha | « Simule » routes to Explorer (no LLM). Terracotta tint signals a different mode. |

Accent (`MintColors.mintForest`) is reserved for: (1) active verb tap state, (2) Explorer deep-link
inline CTA, (3) `next_step` label text. Nowhere else in Phase 96 surfaces.

Destructive color: `MintColors.error` (#D32F2F). Not used in Phase 96 (no destructive actions).

---

## Copywriting Contract

All user-facing strings go through `AppLocalizations.of(context)!.key` (CLAUDE.md rule 5).
ARB keys must appear in all 6 locales (fr/en/de/es/it/pt) before merge (D-25).

### Intent verbs (MintCardActionBar)

| ARB key | FR (canonical) | Semantics |
|---------|----------------|-----------|
| `verbExplique` | **« Explique-moi »** | Opens MintChatOverlay with intent "explain" |
| `verbSimule` | **« Simule »** | Deep-links to Explorer — zero LLM turns |
| `verbRassure` | **« Rassure-moi »** | Opens MintChatOverlay with intent "reassure" |

Accent-lint-fr clean: all three use correct French. « Explique-moi » and « Rassure-moi » use
imperative reflexive (clean). « Simule » is clean imperative.

### Terminal template (turn 4 static response)

Verbatim FR (locked D-10):

> « Tu as exploré 3 angles sur cette carte. Pour aller plus loin, ouvre le simulateur
> depuis [Explorer →](/explorer?id={card_id}) — tu pourras y modifier les hypothèses en direct. »

Rendering: the `[Explorer →]` fragment is a `TextSpan` with `recognizer: TapGestureRecognizer`
using `MintColors.mintForest` and `MintTextStyles.bodyMedium`. The `{card_id}` placeholder is
substituted client-side from `source_card.card_id` before render.

ARB key: `chatTerminalTemplate` — single key with `{cardId}` placeholder.

### Hook fallback (digit detected in NarrativeSleeve hook)

Verbatim FR (locked D-16):

> « Voyons ensemble ce que ça change pour toi. »

ARB key: `narrativeHookFallback`

Hook is swapped by backend middleware — Flutter renders whatever string the API returns.
The fallback must also be accent-lint-fr clean: « Voyons » (correct with accent).

### MintChatOverlay header label

Context label shown at top of overlay, identifying the card being discussed:

| Situation | Label pattern | ARB key |
|-----------|---------------|---------|
| Intent "explain" | « Explique-moi · {cardTitle} » | `overlayHeaderExplique` |
| Intent "reassure" | « Rassure-moi · {cardTitle} » | `overlayHeaderRassure` |

Pattern: `MintTextStyles.titleMedium()`, `MintColors.textPrimary`. `{cardTitle}` truncated to
30 chars with ellipsis if longer.

### MintChatOverlay empty-state (before first send)

| Element | Copy | ARB key |
|---------|------|---------|
| Empty state body | « Pose ta question sur cette carte. Je regarde les chiffres. » | `chatOverlayEmptyPrompt` |

No empty-state illustration — DESIGN_SYSTEM.md §6 "dire moins, montrer mieux". Just the text prompt.

### MintChatOverlay error state (network failure)

| Element | Copy | ARB key |
|---------|------|---------|
| Error inline | « Le calcul a buté. On réessaie ? » | `chatOverlayNetworkError` |

Matches VOICE_SYSTEM.md §5 "Erreur technique" pattern. Single retry `TextButton` with
`MintTextStyles.labelLarge(color: MintColors.mintForest)`.

### Turn counter

ARB key: `chatTurnCounter` — value: `« {current} / {max} »` where max=3.
Displayed as `MintTextStyles.labelSmall(color: MintColors.textMuted)` in top-right of overlay.

### « Simule » — no overlay copy needed

« Simule » routes directly to Explorer via `context.push('/explorer?simulate={card_id}')`.
No overlay opens, no copy needed. ARB key `verbSimule` is the complete copy surface.

### Destructive actions in this phase

None. The turn-4 cap is informational, not destructive. The flag-gate (MintShell tab removal)
is invisible to the user and has no destructive confirmation UI.

---

## Animation Contract

All durations and curves reference `MintMotion.*` from `apps/mobile/lib/theme/mint_motion.dart`.
Zero hardcoded `Duration(milliseconds: ...)` permitted in Phase 96 widget files.

### MintCardActionBar expansion

| Property | Value | Token | Widget |
|----------|-------|-------|--------|
| Duration | 200ms | Custom — between `MintMotion.fast` (150ms) and `MintMotion.standard` (300ms). Use `const Duration(milliseconds: 200)`. | `AnimatedSize` |
| Curve | easeOut | `MintMotion.curveStandard` (`Curves.easeOutCubic`) | `AnimatedSize` |
| Height delta | 0dp → 48dp | `MintSpacing.xxl` | `AnimatedSize` child |
| Opacity | 0.0 → 1.0 | parallel with height | `AnimatedOpacity` |
| Opacity duration | 200ms | Same as height | `AnimatedOpacity` |

Implementation: `AnimatedSize` wrapping an `AnimatedOpacity` wrapping the Row. Both share the
same 200ms / easeOutCubic. Do NOT use `AnimatedContainer` for height here — `AnimatedSize`
intrinsically sizes to the child and avoids hardcoding absolute heights.

Note on D-04 spec wording: spec says "200ms easeOut". `Curves.easeOutCubic` is the MINT canonical
easeOut. Do not use the Flutter built-in `Curves.easeOut` (quadratic) — use `MintMotion.curveStandard`.

### MintChatOverlay entry

| Property | Value | Token | Widget |
|----------|-------|-------|--------|
| Duration | 300ms | `MintMotion.standard` | `showModalBottomSheet` transition |
| Curve (enter) | easeOutQuart | `MintMotion.curveEnter` | Applied to DraggableScrollableSheet |
| Pattern | Slide up from bottom | — | `DraggableScrollableSheet` initial extent |
| Initial extent | 0.75 (75% screen height) | — | `DraggableScrollableSheet.initialChildSize` |
| Min extent | 0.4 | — | Allows partial collapse |
| Max extent | 0.95 | — | Near-full-screen for 3-turn flow |

MintChatOverlay is a `showModalBottomSheet` with `isScrollControlled: true` and
`DraggableScrollableSheet`. This re-uses the DESIGN_SYSTEM.md §4.6 bottom-sheet pattern
(radius top 20dp = `radiusXl`, handle 40×4dp).

### Verb tap feedback

| Property | Value | Token | Widget |
|----------|-------|-------|--------|
| Duration | 150ms | `MintMotion.fast` | `AnimatedContainer` inside `_VerbChip` |
| Curve | easeOut | `MintMotion.curveStandard` | `AnimatedContainer` |
| Effect | Background color swap (surface → mentheVive12) | `MintColors.mentheVive12` | `AnimatedContainer` color |

Use `InkWell` with `splashColor: MintColors.mentheVive12` and `highlightColor: Colors.transparent`
for native Material 3 ripple, then layer `AnimatedContainer` for the persistent pressed state.

### MintShell tab removal (no animation)

Removing index 2 from `NavigationBar.destinations` when `FeatureFlags.chatTabVisible = false` is
a synchronous state change at app boot — no animation needed. The tab count changes before the
first frame renders.

---

## Accessibility Contract

Minimum 44×44dp tap targets per Apple HIG (D-04 compliance, all interactive elements).

### MintCardActionBar

| Element | Requirement | Implementation |
|---------|-------------|----------------|
| Each `_VerbChip` | min 44×44dp tap target | `constraints: BoxConstraints(minHeight: 44, minWidth: 44)` on `InkWell` |
| Semantics label | `Semantics(button: true, label: ...)` | See exact FR labels below |
| « Explique-moi » | `Semantics(label: 'Explique-moi — ouvre le coach sur cette carte')` | Applied to `InkWell` |
| « Simule » | `Semantics(label: 'Simule — ouvre le simulateur pour cette carte')` | Applied to `InkWell` |
| « Rassure-moi » | `Semantics(label: 'Rassure-moi — ouvre le coach pour réduire l\'inquiétude')` | Applied to `InkWell` |
| Action bar as group | `Semantics(container: true, label: 'Actions sur cette carte')` | Wrapping `Row` |

### MintChatOverlay

| Element | Requirement | Implementation |
|---------|-------------|----------------|
| Focus trap | Focus must not escape the overlay while open | Use `FocusTrap` (Flutter `FocusScope` with `child: ` boundary) |
| Initial focus | First text field or send button on open | `FocusNode.requestFocus()` in `initState` |
| Dismiss semantics | « Fermer » accessible label on close handle | `Semantics(label: 'Fermer le coach', button: true)` on drag handle |
| Overlay announcement | Screen reader announces modal opening | `SemanticsService.announce('Coach ouvert', TextDirection.ltr)` |

### Terminal template Explorer deep-link

| Element | Requirement | Implementation |
|---------|-------------|----------------|
| Tap target | min 44dp height | Wrap in `ConstrainedBox(constraints: BoxConstraints(minHeight: 44))` |
| Semantics | Explicit link label | `Semantics(label: 'lien vers le simulateur Explorer', link: true)` |
| Role | `link: true` in Semantics | Do NOT use `button: true` — it is navigation, not an action |

### Turn counter

| Element | Requirement | Implementation |
|---------|-------------|----------------|
| Counter | Screen reader reads progress | `Semantics(label: 'Tour {n} sur 3', liveRegion: false)` |

### NarrativeSleeve

| Element | Requirement | Implementation |
|---------|-------------|----------------|
| `hook` text | Readable as a sentence by screen reader | Standard `Text` widget, no special semantics needed |
| `next_step` | Screen reader identifies as actionable guidance | `Semantics(hint: 'Prochaine étape')` on the `next_step` container |
| `metaphor` | Optional — skip if empty string | Conditional render: `if (sleeve.metaphor.isNotEmpty) ...` |

---

## Dimension 7 — Maestro G1 Contract

File: `tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml`

This flow is the Phase 96 G1 gate (D-27). It validates the full user path: card → action bar →
overlay → 3 turns → terminal → deep-link.

### Flow shape (prescriptive YAML structure)

```yaml
# flow_card_action_intent_bar.yaml
# Phase 96 G1 — MintCardActionBar + MintChatOverlay + 3-turn cap + Explorer deep-link
# Target: iPhone 17 Pro sim, staging Railway (mint-staging.up.railway.app)
# Runner: tools/simulator/walker_audit_tap_render.sh

appId: com.mint.mobile.staging

---
- runFlow: setup_launch.yaml  # boot + wait for home screen

# ── Step 1: Assert 3-tab nav (chat tab absent) ──
- assertNotVisible:
    text: "Coach"          # tabCoach label — must be gone when flag is false
- assertVisible:
    text: "Aujourd'hui"
- assertVisible:
    text: "Explorer"

# ── Step 2: Open a card on Aujourd'hui ──
- tapOn:
    id: "card_mon_3a_2026"  # stable testID on the Mon 3a 2026 card

# ── Step 3: Assert MintCardActionBar appears ──
- waitForAnimationToEnd
- assertVisible:
    text: "Explique-moi"
- assertVisible:
    text: "Simule"
- assertVisible:
    text: "Rassure-moi"

# ── Step 4: Tap « Explique-moi » ──
- tapOn:
    text: "Explique-moi"

# ── Step 5: Assert MintChatOverlay opens ──
- waitForAnimationToEnd
- assertVisible:
    id: "mint_chat_overlay"
- assertVisible:
    text: "1 / 3"  # turn counter

# ── Step 6: Send turn 1 ──
- tapOn:
    id: "chat_input_field"
- inputText: "Qu'est-ce que ça change pour moi ?"
- tapOn:
    id: "chat_send_button"
- extendedWaitUntil:
    visible:
      text: "2 / 3"
    timeout: 15000

# ── Step 7: Send turn 2 ──
- inputText: "Et si j'attends encore deux ans ?"
- tapOn:
    id: "chat_send_button"
- extendedWaitUntil:
    visible:
      text: "3 / 3"
    timeout: 15000

# ── Step 8: Send turn 3 ──
- inputText: "Qu'est-ce que tu recommanderais ?"
- tapOn:
    id: "chat_send_button"

# ── Step 9: Assert terminal template at turn 4 ──
- extendedWaitUntil:
    visible:
      text: "Tu as exploré 3 angles sur cette carte"
    timeout: 15000
- assertVisible:
    text: "Explorer →"  # deep-link label visible

# ── Step 10: Assert Explorer deep-link is tappable ──
- tapOn:
    text: "Explorer →"
- waitForAnimationToEnd
- assertVisible:
    id: "explorer_screen"  # stable testID on ExplorerScreen root

# ── Step 11: « Simule » verb — separate check (no overlay, no turns) ──
# Nav-stack at this point: card_list > card_detail (MintChatOverlay terminal-state) > explorer_screen
# First pressBack pops explorer_screen, second tapOn dismisses overlay close-handle,
# then card_list re-appears for the next tapOn.
- pressBack
- tapOn:
    id: "mint_chat_overlay_close_handle"  # dismiss terminal-state overlay
- waitForAnimationToEnd
- tapOn:
    id: "card_mon_3a_2026"
- waitForAnimationToEnd
- tapOn:
    text: "Simule"
- waitForAnimationToEnd
- assertNotVisible:
    id: "mint_chat_overlay"  # overlay must NOT open for « Simule »
- assertVisible:
    id: "explorer_screen"    # must land on Explorer directly
```

### G1 pass criteria

| Check | Assert type | Expected |
|-------|-------------|---------|
| Chat tab absent | `assertNotVisible` | text "Coach" not visible in nav bar |
| 3 verbs visible on card tap | `assertVisible` (×3) | "Explique-moi", "Simule", "Rassure-moi" all visible |
| MintChatOverlay opens | `assertVisible` | id "mint_chat_overlay" |
| Turn counter increments | `assertVisible` (×3) | "1 / 3" → "2 / 3" → "3 / 3" |
| Terminal template fires at turn 4 | `assertVisible` | text starts with "Tu as exploré 3 angles" |
| Explorer deep-link tappable | `tapOn` + `assertVisible` | id "explorer_screen" visible after tap |
| « Simule » skips overlay | `assertNotVisible` + `assertVisible` | No overlay; Explorer screen visible |
| Sentry breadcrumb (staging log) | Manual check post-run | `chat_overflow_turn_4` event in Sentry staging dashboard |

Sentry metric `chat_overflow_turn_4` cannot be asserted from Maestro — it is verified manually
in the Sentry staging dashboard after the flow run. Log the Sentry event URL in the G1 evidence
section of the VERIFICATION-REPORT.

---

## Component Anatomy Summary

### MintCardActionBar

```
MintCardActionBar (StatelessWidget, D-04)
  → AnimatedSize(duration: 200ms, curve: easeOutCubic)
    → AnimatedOpacity(opacity: 0.0→1.0, duration: 200ms)
      → Container(
          height: MintSpacing.xxl,           // 48dp
          color: MintColors.craieHandoff,    // warm cream row bg
          padding: EdgeInsets.symmetric(
            horizontal: MintSpacing.md,      // 16dp
            vertical: 0,                     // row is centered in 48dp
          ),
        )
        → Row(mainAxisAlignment: center, gap: MintSpacing.sm)  // 8dp between chips
          → _VerbChip(
              label: l.verbExplique,
              icon: Icons.lightbulb_outline,
              semanticsLabel: 'Explique-moi — ouvre le coach sur cette carte',
              onTap: () => /* open MintChatOverlay(intent: "explain") */,
            )
          → _VerbChip(
              label: l.verbSimule,
              icon: Icons.tune_outlined,
              semanticsLabel: 'Simule — ouvre le simulateur pour cette carte',
              onTap: () => context.push('/explorer?simulate={card_id}'),
              accentTint: MintColors.terracotta,  // 8% alpha tint — signals different mode
            )
          → _VerbChip(
              label: l.verbRassure,
              icon: Icons.shield_outlined,
              semanticsLabel: 'Rassure-moi — ouvre le coach pour réduire l\'inquiétude',
              onTap: () => /* open MintChatOverlay(intent: "reassure") */,
            )

_VerbChip (StatelessWidget)
  → Semantics(button: true, label: semanticsLabel)
    → InkWell(
        splashColor: MintColors.mentheVive12,
        highlightColor: Colors.transparent,
        onTap: onTap,
        child: AnimatedContainer(
          duration: MintMotion.fast,     // 150ms
          curve: MintMotion.curveStandard,
          constraints: BoxConstraints(minHeight: 44, minWidth: 44),
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: pressed ? MintColors.mentheVive12 : MintColors.surface,
            border: Border.all(color: MintColors.border),
            borderRadius: BorderRadius.circular(8),  // radiusSm
          ),
          child: Row(spacing: MintSpacing.xs)  // 4dp icon-to-label gap
            → Icon(icon, size: 16, color: pressed ? MintColors.mintForest : MintColors.textMuted)
            → Text(label, style: MintTextStyles.labelLarge(
                color: pressed ? MintColors.inkPrimary : MintColors.textSecondary,
              ))
        )
      )
```

### MintChatOverlay

```
showModalBottomSheet(
  isScrollControlled: true,
  backgroundColor: MintColors.card,
  barrierColor: Color(0x990A0A0F),   // nearBlack at 60% opacity
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),  // radiusXl
  ),
  builder: (_) → DraggableScrollableSheet(
    initialChildSize: 0.75,
    minChildSize: 0.4,
    maxChildSize: 0.95,
    builder: (_, scrollController) → FocusScope(
      child: Column(
        children:
          // Handle
          Container(width: 40, height: 4, margin: EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: MintColors.border,
              borderRadius: BorderRadius.circular(2),
            ))
          // Header
          Container(
            color: MintColors.craieHandoff,
            padding: EdgeInsets.symmetric(horizontal: MintSpacing.lg, vertical: MintSpacing.md),
          )
            → Row(children: [
                Expanded(child: Text(l.overlayHeaderExplique, style: MintTextStyles.titleMedium())),
                Text(l.chatTurnCounter, style: MintTextStyles.labelSmall(color: MintColors.textMuted)),
              ])
          // Chat turn list
          Expanded(child: ListView(controller: scrollController, ...))
          // Input bar
          ChatInputBar(padding: EdgeInsets.all(MintSpacing.md))
      )
    )
  )
)
```

### NarrativeSleeve Card Embed

```
MintNarrativeCard (or Container with MintColors.craieHandoff)
  padding: EdgeInsets.all(MintSpacing.lg)  // 24dp
  → Column(
      crossAxisAlignment: start,
      children: [
        // hook — digit-free, max 15 words
        Text(sleeve.hook, style: MintTextStyles.headlineSmall()),

        SizedBox(height: MintSpacing.sm),  // 8dp

        // caption — cited numbers
        Text(sleeve.caption, style: MintTextStyles.bodyLarge()),

        SizedBox(height: MintSpacing.md),  // 16dp

        // next_step — verb-first, ≤12 words, mintForest
        Row(children: [
          Text('›', style: MintTextStyles.labelLarge(color: MintColors.mintForest)),
          SizedBox(width: MintSpacing.xs),
          Expanded(child: Text(sleeve.nextStep,
            style: MintTextStyles.labelLarge(color: MintColors.mintForest))),
        ]),

        // metaphor (optional)
        if (sleeve.metaphor.isNotEmpty) ...[
          SizedBox(height: MintSpacing.sm),
          Divider(color: MintColors.borderSubtle),
          SizedBox(height: MintSpacing.sm),
          Semantics(
            hint: 'Prochaine étape',
            child: Text(sleeve.metaphor,
              style: MintTextStyles.bodySmall(color: MintColors.textMuted))),
        ],
      ]
    )
```

---

## Design Principles Check (DESIGN_SYSTEM.md §7 forbidden patterns)

| Pattern | Status in Phase 96 |
|---------|-------------------|
| Grille 2×2 icônes | Not used. 3 verbs in a Row. |
| Badge coloré flottant | Not used. |
| Glassmorphism | Not used. `craieHandoff` is a warm solid. |
| Bouton glossy | Not used. `FilledButton` / `OutlinedButton` patterns. |
| UPPERCASE subtitles | Not used. Sentence case everywhere. |
| Font Outfit | Not used. Supreme throughout. |
| Multiple gradients | Not used. No gradient in Phase 96 surfaces. |
| Icônes décoratives sans fonction | Not used. All icons in `_VerbChip` are functional (part of tappable). |
| Bordure + ombre même composant | Not used. `_VerbChip` uses border only, no shadow. |
| Cards dans des cards | MintChatOverlay contains chat messages, not nested cards. |
| > 3 accents par écran | Phase 96 uses: mintForest (accent), border (neutral). 2 total. |
| Pie chart | Not applicable. |
| Form first | Not applicable (Phase 96 is action-bar + overlay, not a form). |

---

## Registry Safety

| Registry | Blocks used | Safety gate |
|----------|-------------|-------------|
| Native Flutter / Material 3 | `AnimatedSize`, `AnimatedOpacity`, `DraggableScrollableSheet`, `showModalBottomSheet`, `InkWell`, `FocusScope`, `Semantics` | Not required — stdlib |
| MINT UI Kit | `MintNarrativeCard`, `MintColors`, `MintTextStyles`, `MintSpacing`, `MintMotion` | Not required — project-owned |
| Third-party registries | None | Not applicable |

No shadcn. No third-party component registries. Phase 96 uses Flutter stdlib + MINT-owned tokens only.

---

## Pre-populated Decision Sources

| Decision | Source | Count |
|----------|---------|-------|
| 48dp expansion, 200ms easeOut, 3 verbs, flag-gate, turn cap, terminal copy, hook fallback, Sentry metric | 96-CONTEXT.md D-01..D-28 | 28 |
| Color tokens, spacing constants, typography tokens | Detected from codebase (`colors.dart`, `mint_text_styles.dart`, `mint_spacing.dart`, `mint_motion.dart`) | — |
| Scrim pattern, bottom-sheet radius/handle, empty/error state patterns | `docs/DESIGN_SYSTEM.md` §4.6, §4.7 | — |
| Verb tone, hook tone, coach register | `docs/VOICE_SYSTEM.md` §2 (Coach: conversationnel, complice) | — |
| Maestro flow shape | 96-CONTEXT.md D-27 + `flow_narrator_refuses_uncited_numbers.yaml` precedent | — |

User questions asked during this session: 0. All decisions pre-populated from upstream.

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS
- [ ] Dimension 7 Maestro G1 Contract: PASS

**Approval:** pending

---

## UI-SPEC COMPLETE

**Phase:** 96 — MVP-CHAT-AS-VERB
**Design System:** none (Flutter Material 3 + MINT custom tokens — Supreme + Gambarino fonts)

### Contract Summary

- **Spacing:** MintSpacing scale (4/8/16/24/32/48dp). MintCardActionBar = 48dp (`MintSpacing.xxl`). Verb chips = 16dp H / 12dp V padding. Overlay = 24dp H (`MintSpacing.lg`) / 32dp V (`MintSpacing.xl`). Chip gap = 8dp (`MintSpacing.sm`).
- **Typography:** 6 MintTextStyles tokens in use — `headlineSmall` (hook), `titleMedium` (overlay header), `bodyLarge` (caption), `bodyMedium` (chat body + terminal), `labelLarge` (verb chips + next_step), `labelSmall` (turn counter). Font: Supreme throughout.
- **Color:** Dominant `MintColors.card` (#FFFFFF). Secondary `MintColors.craieHandoff` (#F8F5F0). Accent `MintColors.mintForest` (#2F5F3F) reserved for: active verb tap, Explorer deep-link, `next_step` label. Scrim `MintColors.nearBlack` at 60% opacity.
- **Copywriting:** 7 elements defined — 3 verb labels, terminal template (verbatim D-10), hook fallback (verbatim D-16), overlay headers, error/empty states. ARB keys listed for all.
- **Animation:** 3 timing contracts — MintCardActionBar 200ms easeOutCubic, MintChatOverlay entry 300ms (`MintMotion.standard`), verb tap 150ms (`MintMotion.fast`).
- **Accessibility:** Semantics labels on all 3 verbs, focus trap in overlay, Explorer link role `link: true`, 44dp minimum tap targets.
- **Maestro G1:** Full YAML shape specified — 11 steps covering verb visibility, overlay, 3-turn cap, terminal template, Explorer deep-link, and « Simule » skip-overlay check.
- **Registry:** Flutter stdlib + MINT-owned only. No third-party registries.

### File Created

`/Users/julienbattaglia/Desktop/MINT.nosync/.planning/phases/96-mvp-chat-as-verb/96-UI-SPEC.md`

### Pre-populated From

| Source | Decisions used |
|--------|---------------|
| 96-CONTEXT.md D-01..D-28 | 28 |
| Codebase (`colors.dart`, `mint_text_styles.dart`, `mint_spacing.dart`, `mint_motion.dart`, `mint_shell.dart`) | All token bindings |
| `docs/DESIGN_SYSTEM.md` | Spacing, component anatomy, forbidden patterns, accessibility baseline |
| `docs/VOICE_SYSTEM.md` | Coach tone, empty/error copy patterns, ant-patterns |
| `2026-05-10-phase-96-ux-panel.md` | Component anatomy, YAML Maestro precedent |
| User input | 0 |

### Ready for Verification

UI-SPEC complete. Checker can now validate Phase 96 design contract.

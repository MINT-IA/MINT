---
description: Phase 97 deferred items — out-of-scope discoveries logged during W7 iteration cycles per CLAUDE.md Karpathy #3 SCOPE_BOUNDARY. Each row is a pre-existing tech-debt finding the cycle DID NOT fix (would have exceeded surgical scope or budget). To be picked up by v2.10 MVP-CLEANUP.
phase: 97
created: 2026-05-11
---

# Phase 97 — Deferred Items

## W7 iter#12 (L001 close, 2026-05-11)

### 1. Pre-existing prefer-mint-* lint debt in `anonymous_chat_screen.dart`

**Surface :** `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart`
**Lines flagged :** 559, 560, 597, 603, 607, 608, 633, 634, 664, 665, 670, 671, 718, 719
**Lints :** `prefer_mint_fonts` (6), `prefer_mint_radius` (2), `prefer_mint_text_style` (6) = 14 violations total

**Why deferred :** These violations exist on lines I did not modify (legacy 2026-04 `_buildChipsRow`, `_buildDisclaimerAndInput`, `_buildMessageBubble` style code). Lefthook reported them as « new violations » because the staged file as a whole was re-presented, not because my 4-Key additions introduced them. Fixing them would mean replacing raw `fontFamily: 'Supreme'` / `fontSize: N` / `BorderRadius.circular(22)` with `MintTextStyles.<token>()` builders + `MintRadius.<token>` constants — a refactor across 6 lines that has nothing to do with L001 (Maestro locator audit).

**Karpathy #3 SCOPE_BOUNDARY :** « Only auto-fix issues DIRECTLY caused by the current task's changes. Pre-existing warnings, linting errors, or failures in unrelated files are out of scope. »

**Resolution path :** v2.10 MVP-CLEANUP sub-phase (per CONTEXT D-40), bundled into a dedicated « legacy theme token migration » bug row.

### 2. Pre-existing `accent_lint_fr` hits on `eclairage` identifier

**Surface :** `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart` (32 violations on identifier accesses `message.eclairage`, `EclairageCard`, `EclairageCardData`, etc.) + 1 violation on `tools/simulator/flows/julien_swiss.yaml:18` (pre-existing comment `04 eclairage-card`)

**Why deferred :** `eclairage` is a Dart identifier (class name + field name), not user-facing copy. Renaming it to `éclairage` would require renaming the class `EclairageCard` → `ÉclairageCard`, `EclairageKind` → `ÉclairageKind`, the JSON-serialization key `'kind'`, the ARB key `anonymousChatOpener`, etc. — a multi-file refactor with backend contract implications. Out of scope for L001.

**Karpathy #3 SCOPE_BOUNDARY :** Same as item 1.

**Resolution path :** The lint already returns exit 0 (warning, not blocking) on these hits. v2.10 cleanup OR adjust the lint to exclude Dart identifier paths.

### 3. Dead code in `_buildMessageBubble` (lines 762-768 of anonymous_chat_screen.dart)

**Surface :** lines 762-768 (the `if (isOpener)` branch returning `FadeTransition(opacity: _openerFadeController, child: bubble)`).

**Why deferred :** This block is unreachable — the function returns earlier at lines 730-735 (eclairage==null case) OR 737-760 (eclairage!=null case). The trailing `if (isOpener) { return FadeTransition... } return bubble;` is dead code. Per Karpathy #3 « Notice unrelated dead code → mention, don't delete (unless asked) ».

**Resolution path :** v2.10 cleanup OR a dedicated tech-debt close on the AnonymousChatScreen.

---

*Phase : 97-mvp-parfait-maestro-full-power*
*Maintainer : PM Claude — Phase 97 W7 iteration loop*

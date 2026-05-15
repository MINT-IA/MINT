---
date: 2026-05-13
status: Open
authors: Claude (Opus 4.7) + Julien visual co-discovery
description: 6 findings from S98 Phase 5 Maestro sweep + UI walkthrough — 1 found by classifier, 5 by Julien naked-eye on Connexion screen
related:
  - .planning/decisions/ADR-20260513-debug-infrastructure-strategy.md
  - tools/simulator/maestro_sweep.sh
  - tools/debug/cassure-classifier.sh
---

# S98 Phase 5 sweep findings — 6 cassures

## TL;DR

The 5-day debug-infrastructure plan delivered. First real-sim run of the e2e ship-gate flow found **1 deterministic E2E cassure** via the classifier path, and Julien's naked-eye review of the Connexion screen found **5 more UX/design cassures**. None of these are watchdog-stalls — they're substantive product bugs the new infra (or Julien's eyes) surfaced.

## Findings

### F1 — E2E ship-gate breaks at « Pas encore de compte ? » assertion

**Source:** `tools/simulator/maestro_sweep.sh --tier e2e` exit 1.
**Evidence:** `.planning/_walker/sweep-20260513T230113/flow_e2e_new_user_full_journey/maestro.log`. 26 steps green, then :

```
Tap on "Créer un compte"... COMPLETED
Assert that "Pas encore de compte ?" is visible... FAILED
```

**Diagnosis:** The flow taps « Créer un compte » then asserts « Pas encore de compte ? » should be visible. But that text only appears on the LOGIN screen (asking « do you not have an account ? »), not on the register screen. Two possibilities :

1. The flow YAML asserts the wrong text. After tapping « Créer un compte » the user expects to land on the register screen, where the visible content should be « Crée ton compte » / « Inscription » / similar — NOT « Pas encore de compte ? ».
2. The tap on « Créer un compte » fails to navigate (real nav bug). Maestro's screenshot shows the user still on the Connexion screen at the moment of failure — which would support « tap was no-op ».

**To resolve:** read `~/.maestro/tests/2026-05-13_230114/screenshot-❌-*.png` (Maestro saved one) AND `commands-(flow_e2e_new_user_full_journey.yaml).json` to confirm whether the screen transitioned post-tap. If no transition → real nav bug at `apps/mobile/lib/screens/auth/login_screen.dart` (the « Créer un compte » button onTap). If transition happened → flow YAML is wrong, fix the assertion text.

**Suspect file:** `apps/mobile/lib/screens/auth/login_screen.dart` OR `tools/simulator/flows/e2e/flow_e2e_new_user_full_journey.yaml`.

---

### F2 — Markdown `**bold**` rendered as literal asterisks in anonymous chat

**Source:** Julien visual observation.
**Diagnosis (confirmed by grep):** `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart` uses **5 plain `Text(...)` widgets** and **zero `MarkdownBody`** to render coach responses. The authenticated coach chat (`apps/mobile/lib/widgets/coach/coach_message_bubble.dart`) DOES use `MarkdownBody` (`import 'package:flutter_markdown/flutter_markdown.dart'`) ; the anonymous chat doesn't.

Result : Claude returns `**bold**` markdown in its anonymous-mode replies, and the Text widget renders the literal asterisks.

**Fix:** swap each `Text(m.text)` in the assistant-bubble path of `anonymous_chat_screen.dart` for `MarkdownBody(data: m.text, styleSheet: ...)`. Lines to touch include `:531`, `:556`, `:603`, `:626`, `:708` (5 occurrences — verify which are user vs assistant ; only assistant should render markdown).

**Suspect file:** `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart:531+`.

---

### F3 — « Continuer en mode local » is opaque jargon (UX cassure)

**Source:** Julien visual observation.
**Diagnosis:** The label « Continuer en mode local » sits between « Sign in with Apple » and the « Mot de passe oublié ? » link on the Connexion screen. From the user's perspective, « mode local » is a technical term that doesn't convey :

- What you GAIN by tapping it (use MINT without creating an account).
- How it differs from anonymous chat (which they already used).
- Whether their chat history will persist across launches.

**Code source:** Localized at `apps/mobile/lib/l10n/app_fr.arb:3910` as `authContinueLocal = "Continuer en mode local"`. Used by the « no-account » path documented at `apps/mobile/lib/providers/auth_provider.dart:561`.

**Fix:** rewrite ARB string to plain language. Suggestions :
- « Essayer MINT sans inscription »
- « Continuer sans compte »
- « Plus tard — explorer d'abord »

Pick one + propagate across 6 ARB files (fr/en/de/es/it/pt) + `flutter gen-l10n`. The string also appears as user-facing text in two error messages (`authErrorRegistration`, `authErrorService` — `app_fr.arb:8000-8001`) which use « le mode local » mid-sentence — those need rewording too.

**Suspect file:** `apps/mobile/lib/l10n/app_fr.arb:3910` (+ 5 sibling ARBs).

---

### F4 — Connexion screen primary buttons are BLACK, not MINT green

**Source:** Julien visual observation.
**Diagnosis:** Screenshot shows « Recevoir un lien magique » and « Sign in with Apple » as **black-background** buttons. Per `CLAUDE.md` TOP rule #2 + `docs/DESIGN_SYSTEM.md`, MINT primary brand color is `#003B2F` (deep mint green).

The login screen DOES use 21 `MintColors.*` references (verified by grep). But the BUTTONS resolve to black — meaning either :
- Wrong token used (e.g. `MintColors.textPrimary` which is black, instead of `MintColors.brandPrimary`).
- OR the brand-primary token itself is set to black somewhere in `lib/theme/colors.dart`.

**To resolve:** read `apps/mobile/lib/theme/colors.dart` + the button-construction code at `apps/mobile/lib/screens/auth/login_screen.dart` ; trace which color tokens drive button backgrounds. Likely fix : replace `textPrimary` with `brandPrimary` (or whatever the canonical mint-green token is) at the affected lines.

**Broader context** (per Julien) : « on n'a pas du tout les bonnes couleurs presque nulle part » — this is a design-system-enforcement audit, not a one-screen fix. Track as a Phase 6 design audit if breadth > 5 screens.

**Suspect file:** `apps/mobile/lib/theme/colors.dart` + `apps/mobile/lib/screens/auth/login_screen.dart`.

---

### F5 — App icon not visible on home screen

**Source:** Julien visual observation.
**Diagnosis:** The app icon doesn't render on the iOS sim launcher. Without inspection of the actual `Assets.xcassets/AppIcon.appiconset/` content I can only speculate. Common causes :

1. AppIcon `.png` files placed but missing the `Contents.json` manifest, OR manifest references files that don't exist.
2. The icon images don't match required iOS sizes (1024×1024 marketing, plus the 7+ device-specific sizes).
3. Build pipeline strips them (less likely — would have surfaced at App Store submission long ago).

**To resolve:** `ls -la apps/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/` and compare against the `Contents.json` manifest. Re-export from `docs/DESIGN/` source artifacts if available.

**Suspect file:** `apps/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

---

### F6 — Design system documented but not enforced (broader pattern)

**Source:** Julien observation : « On a des dossiers design mais ils n'ont pas été respectés ou pas tout a été fait. »
**Diagnosis:** F4 + F5 are symptoms of this category. The repo has `docs/DESIGN_SYSTEM.md` + 5 design-system lints (`prefer_mint_color_token`, `prefer_mint_text_style`, etc.) wired in lefthook (verified at `lefthook.yml:70-94`). The lints are currently SOFT-warn (lefthook) + HARD-fail (CI) per the comment at line 61-64.

If the CI gate is HARD-fail, F4 (black-instead-of-mint button) should have been caught at PR time. Either :
- The lint regex doesn't catch the specific anti-pattern in `login_screen.dart`.
- The CI gate has been bypassed historically (commit messages would show `[LEFTHOOK_BYPASS=1]` traces).
- The lint exists but only flags `Color(0xFF...)` literal usage, not « wrong token chosen from the palette » — that's a higher-order check the regex can't do.

**To resolve:** read `tools/checks/prefer_mint_color_token.py` ; understand what it actually flags ; expand if necessary. Or accept that the lint is « not hardcoded literals » only, and that token-choice errors require human review.

---

## Recommended next-session execution order

1. **F1 first** — read the Maestro screenshot at `~/.maestro/tests/2026-05-13_230114/screenshot-*.png` to disambiguate « flow YAML wrong » vs « real nav bug ». Cheapest investigation.
2. **F2** — swap `Text` → `MarkdownBody` in `anonymous_chat_screen.dart`. ~30 min fix + golden screenshot update.
3. **F3** — rewrite « Continuer en mode local » in 6 ARBs. ~15 min + `flutter gen-l10n`. Then re-run sweep to confirm e2e still passes through this screen.
4. **F4** — trace the black-button issue ; likely a 2-line token swap. ~30 min.
5. **F5** — replace AppIcon assets. Operator (Julien) action — needs design source files.
6. **F6** — audit the 5 design-system lints + tighten if needed. Defer until F4/F5 fixed since the lint authors clearly intended a stricter regime than what shipped.

## What the new debug infrastructure actually delivered today

| Phase | Tested live on sim ? | What it caught |
|---|---|---|
| **Phase 1** (Tier 2 endpoint) | ⚠️ partial — endpoint not on S98 branch | n/a — would need PR #595 merged + a flow that consumes /debug/state |
| **Phase 2** (Sentry beforeSend) | ⚠️ not exercised — no exception thrown | Unit tests covered the regexes ; runtime validation pending real crash |
| **Phase 3** (Maestro stall watchdog) | ✅ — caught 1 wrap, exit-code propagation through `bash` invoke | Surfaced 2 infra bugs : `100644` exec bits, `--device booted` Android-flag |
| **Phase 4** (cassure classifier) | ⚠️ called but the run was a regular failure not a stall — classifier got no inputs because the watchdog only dumps state on stall/hard-limit | F1 was found by Maestro's own exit code + log, not the classifier specifically |
| **Phase 5.X** (dSYM upload) | ⏳ — PR #597 opened, needs first TestFlight build to fire | n/a |

**Net:** The watchdog and the sweep orchestrator both work and produce structured artifact dirs. The classifier currently fires only on watchdog-detected stall/hard-limit — for regular Maestro flow failures (exit-1 from an assertion), the sweep falls back to running the classifier but with no state/oslog inputs, so it produces an empty hypothesis. **Improvement to land in the next session: have the sweep CAPTURE the Maestro screenshot + log AS state inputs for the classifier, so even a regular failure produces a real cassure-report.**

## Action items for Julien (manual)

- [ ] **Revoke + rotate** the Sentry auth token `sntryu_81b4295a...` AFTER PR #597 merges and the first TestFlight build successfully uploads dSYMs. (No urgency right now.)
- [ ] **Review + merge** PRs #595, #596, #597 in order.
- [ ] **Re-export AppIcon** assets per F5 if you have the source files.
- [ ] **Decide on F3 wording** for « Continuer en mode local » — give me your preferred label, I'll plumb it through 6 ARBs.

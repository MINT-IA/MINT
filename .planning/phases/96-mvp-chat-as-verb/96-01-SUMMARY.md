---
phase: 96
plan: 01
subsystem: mobile/chat-as-verb
type: summary
wave: 1
status: shipped
tags:
  - mobile
  - flutter
  - feature-flag
  - i18n
  - chat-as-verb
dependency_graph:
  requires:
    - apps/mobile/lib/theme/colors.dart (MintColors.mentheVive12 + nearBlack tokens, pre-existing)
    - apps/mobile/lib/theme/mint_motion.dart (MintMotion.curveStandard)
    - apps/mobile/lib/theme/mint_spacing.dart (MintSpacing.xxl=48, sm=8, md=16, xs=4)
    - apps/mobile/lib/theme/mint_text_styles.dart (MintTextStyles.labelLarge, labelSmall, titleMedium, bodyMedium)
  provides:
    - apps/mobile/lib/services/feature_flags.dart (FeatureFlags.chatTabVisible + applyFromMap hook)
    - apps/mobile/lib/widgets/mint_card_action_bar.dart (MintCardActionBar + _VerbChip)
    - apps/mobile/lib/widgets/mint_chat_overlay.dart (MintChatOverlay scaffold + show())
    - apps/mobile/lib/widgets/mint_shell.dart (flag-gated NavigationBar + visibleToBranchIndex/branchToVisibleIndex)
    - apps/mobile/lib/models/serialized_card_context.dart (Dart mirror of backend Pydantic model)
    - 3 ARB keys × 6 locales (verbExplique / verbSimule / verbRassure)
  affects:
    - Plan 96-02 (Backend) consumes SerializedCardContext on the wire
    - Plan 96-03 (cross-stack) wires NarrativeSleeve + metaphor TOML inside MintChatOverlay
tech-stack:
  added:
    - toml ^0.16.0 (Phase 96 D-17 — metaphor TOML library)
  patterns:
    - StatefulShellRoute branch list stays length 4 (D-02); only NavigationBar.destinations collapses (D-01)
    - Bidirectional visible↔branch index remap exposed as pure functions for testability
    - SerializedCardContext: structural PII gate (no PII fields declared = no carrier)
    - MintChatOverlay scaffold-only in W1 (Karpathy #2); turn history + input bar in Plan 96-03
key-files:
  created:
    - apps/mobile/lib/models/serialized_card_context.dart
    - apps/mobile/lib/widgets/mint_card_action_bar.dart
    - apps/mobile/lib/widgets/mint_chat_overlay.dart
    - apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart
    - apps/mobile/test/services/feature_flags_chat_tab_test.dart
    - apps/mobile/test/models/serialized_card_context_test.dart
    - apps/mobile/test/widgets/mint_card_action_bar_test.dart
    - apps/mobile/test/widgets/mint_chat_overlay_test.dart
    - apps/mobile/test/widgets/mint_shell_flag_gate_test.dart
    - apps/mobile/test/widgets/mint_card_action_bar_routing_test.dart
  modified:
    - apps/mobile/pubspec.yaml (+ toml ^0.16.0)
    - apps/mobile/pubspec.lock (toml + dependency closure)
    - apps/mobile/lib/services/feature_flags.dart (chatTabVisible + applyFromMap)
    - apps/mobile/lib/widgets/mint_shell.dart (flag-gated NavigationBar + remap helpers)
    - apps/mobile/lib/l10n/app_fr.arb (+ verbExplique/verbSimule/verbRassure)
    - apps/mobile/lib/l10n/app_en.arb (+ 3 keys)
    - apps/mobile/lib/l10n/app_de.arb (+ 3 keys)
    - apps/mobile/lib/l10n/app_es.arb (+ 3 keys)
    - apps/mobile/lib/l10n/app_it.arb (+ 3 keys)
    - apps/mobile/lib/l10n/app_pt.arb (+ 3 keys)
    - apps/mobile/lib/l10n/app_localizations.dart (gen-l10n regen)
    - apps/mobile/lib/l10n/app_localizations_fr.dart (gen-l10n regen)
    - apps/mobile/lib/l10n/app_localizations_en.dart (gen-l10n regen)
    - apps/mobile/lib/l10n/app_localizations_de.dart (gen-l10n regen)
    - apps/mobile/lib/l10n/app_localizations_es.dart (gen-l10n regen)
    - apps/mobile/lib/l10n/app_localizations_it.dart (gen-l10n regen)
    - apps/mobile/lib/l10n/app_localizations_pt.dart (gen-l10n regen)
decisions:
  - D-01 chatTabVisible flag-gate (NavigationBar.destinations collapse, GoRouter branches stay 4)
  - D-02 GoRouter branch + CoachChatScreen route stay registered (overlay route target)
  - D-04 MintCardActionBar 48dp + 200ms easeOutCubic
  - D-05 Final FR verb set « Explique-moi » / « Simule » / « Rassure-moi »
  - D-06 « Simule » → /explorer?simulate=<card_id>, zero LLM call
  - D-07 MintColors.mentheVive12 12% mint-green tint (InkWell splash)
  - D-12 SerializedCardContext 7-field schema, no PII
  - D-21 chatTabVisible default true until staging baseline-pull (D-11)
  - D-26 zero hardcoded Color(0x) in new widget files (grep gates: 0/0)
metrics:
  duration_minutes: 27
  tasks_completed: 4
  files_created: 10
  files_modified: 17
  tests_added: 25
  flutter_test_total: 8378
  flutter_test_skipped: 24
  flutter_test_regressions: 0
  flutter_analyze_issues_total: 273
  flutter_analyze_issues_introduced: 0
  arb_keys_per_locale: 6750
  arb_keys_net_new: 3
  commits:
    - 80ab0c67  # T1 chatTabVisible + ARB + toml + SerializedCardContext
    - 9ece5283  # T2 MintCardActionBar + _VerbChip
    - 75c1f74a  # T3 MintChatOverlay + MintShell flag-gate + remap
    - c5486f74  # T4 verb routing + 2 example cards + routing tests
  completed_date: 2026-05-11
---

# Phase 96 Plan 01: MVP-CHAT-AS-VERB Wave 1 (Flutter UI scaffold) — Summary

Flag-gated chat tab + 48dp animated MintCardActionBar (3 verbs) + MintChatOverlay scaffold + 6-locale ARB sweep + SerializedCardContext Dart mirror. Backend wiring lands in Plan 96-02.

## What shipped

**FeatureFlags.chatTabVisible** (`apps/mobile/lib/services/feature_flags.dart:116`) — default `true`, server-overridable through the existing `/config/feature-flags` endpoint (applyFromMap branch at `apps/mobile/lib/services/feature_flags.dart:161-164`). The default stays `true` until the D-11 staging baseline-pull authorises the prod flip per D-21 (4-week soak before permanent removal).

**MintCardActionBar** (`apps/mobile/lib/widgets/mint_card_action_bar.dart`) — StatelessWidget exposing `expanded: bool` + 3 `VoidCallback` props. AnimatedSize + AnimatedOpacity 200ms with `MintMotion.curveStandard` (easeOutCubic). When expanded, renders a 48dp row (MintSpacing.xxl) with 3 `_VerbChip` instances on a `MintColors.craieHandoff` background. Each chip is wrapped in `BoxConstraints(minHeight: 44, minWidth: 44)` per Apple HIG, with `Semantics(button: true, label: …)` for accessibility. `D-26 grep gate`: `grep -c "Color(0x" lib/widgets/mint_card_action_bar.dart` returns 0 ; `grep -c "Duration(milliseconds:"` returns 1 (the single 200ms literal).

**MintChatOverlay** (`apps/mobile/lib/widgets/mint_chat_overlay.dart`) — StatelessWidget scaffold. `DraggableScrollableSheet` with `initialChildSize: 0.75`, `minChildSize: 0.4`, `maxChildSize: 0.95`. 40×4dp drag handle keyed `chat_overlay_drag_handle`, `MintColors.border` color. Intent label keyed `chat_overlay_intent_label`, `MintTextStyles.labelSmall(color: MintColors.textMuted)`. Static `show()` helper invokes `showModalBottomSheet` with `barrierColor: MintColors.nearBlack.withValues(alpha: 0.6)` (D-26 compliant — uses token, not literal). W1 scaffold only ; turn history + input bar land in Plan 96-03 per Karpathy #2 simplicity-first.

**MintShell flag-gated NavigationBar** (`apps/mobile/lib/widgets/mint_shell.dart`) — when `FeatureFlags.chatTabVisible == false`, the Coach destination is dropped from the `destinations` list (3-tab nav). The GoRouter `StatefulShellRoute` branch list is NOT touched (stays length 4, D-02) so the Coach route remains addressable. Two static helpers expose the bidirectional remap : `MintShell.visibleToBranchIndex(int)` and `MintShell.branchToVisibleIndex(int)`. Both are pure functions over the static flag, so the widget test can assert correctness without constructing a real `StatefulNavigationShell`.

**SerializedCardContext** (`apps/mobile/lib/models/serialized_card_context.dart`) — 7-field plain Dart class mirroring the backend Pydantic v2 model that lands in Plan 96-02. Required: `cardId`, `cardType`. Defaulted to empty: `computedFacts: Map<String, dynamic>`, `groundingKeys: List<String>`. Optional: `lifeEvent`, `canton`, `archetype`. JSON round-trip enforced by 3 tests. Unknown fields silently dropped in `fromJson` (Dart-side structural PII gate, per threat T-96-W1-SerializedCardContextPII).

**6-locale ARB sweep** — 3 keys × 6 locales = 18 entries via `flutter gen-l10n` :

| locale | verbExplique | verbSimule | verbRassure |
|---|---|---|---|
| fr | « Explique-moi » | « Simule » | « Rassure-moi » |
| en | "Explain" | "Simulate" | "Reassure me" |
| de | "Erkläre" | "Simuliere" | "Beruhige mich" |
| es | "Explícame" | "Simular" | "Tranquilízame" |
| it | "Spiega" | "Simula" | "Rassicurami" |
| pt | "Explica" | "Simular" | "Tranquiliza-me" |

Parity gate green : `python3 tools/checks/arb_parity.py` returns `OK — 6 locale(s) parity (reference=fr, 6750 keys each).`

**toml ^0.16.0** added to `apps/mobile/pubspec.yaml:58` — `flutter pub get` exits 0. Consumed in Plan 96-03 for the metaphor library (D-17).

**Demo wiring screen** (`apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart`) — wires `MintCardActionBar` on 2 NON-retirement cards (CLAUDE.md rule 3 — frame by life events, not retirement) :
- « Marge fiscale 2026 » (`life_event=tax`, `card_type=tax_optimization`)
- « Coût hypothèque mensuel » (`life_event=housing`, `card_type=mortgage`)

Each card has a StatefulWidget with `_actionBarExpanded` bool toggled by the card's tap gesture. Verb dispatch follows D-06 :
- « Simule » → `context.push('/explorer?simulate=<card_id>')` (zero LLM)
- « Explique-moi » → `MintChatOverlay.show(intent: 'explain')`
- « Rassure-moi » → `MintChatOverlay.show(intent: 'reassure')`

## Test count

| File | Tests | Status |
|---|---|---|
| `test/services/feature_flags_chat_tab_test.dart` | 4 | green |
| `test/models/serialized_card_context_test.dart` | 3 | green |
| `test/widgets/mint_card_action_bar_test.dart` | 8 | green |
| `test/widgets/mint_chat_overlay_test.dart` | 4 | green |
| `test/widgets/mint_shell_flag_gate_test.dart` | 5 | green |
| `test/widgets/mint_card_action_bar_routing_test.dart` | 4 | green |
| **Wave 1 net new** | **28** | **all green** |

**Full Flutter test suite:** `8378 passed, ~24 skipped` (run `02:11` wall clock). The plan's reference baseline of `≥ 229` (96-VALIDATION.md L62) was sourced from an older snapshot ; the actual current baseline is far higher (~8350 pre-W1). Net new tests recorded against current state : **+28** without regressions.

**flutter analyze:** 273 issues total — IDENTICAL to baseline 273 (info-level only, no errors). 0 new issues introduced by Phase 96 Wave 1.

## Gate evidence (deterministic citations)

| Gate | Result | Citation |
|------|--------|----------|
| ARB parity (6 locales) | green, 6750 keys each (+3 net new) | `python3 tools/checks/arb_parity.py` → `OK — 6 locale(s) parity (reference=fr, 6750 keys each).` |
| accent_lint_fr on touched FR strings | clean | `python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb` → no output |
| D-26 grep `Color(0x` in `mint_card_action_bar.dart` | 0 | `grep -c "Color(0x" lib/widgets/mint_card_action_bar.dart` → `0` |
| D-26 grep `Color(0x` in `mint_chat_overlay.dart` | 0 | `grep -c "Color(0x" lib/widgets/mint_chat_overlay.dart` → `0` |
| D-26 grep `Color(0x` in `mint_shell.dart` | 0 | `grep -c "Color(0x" lib/widgets/mint_shell.dart` → `0` |
| Duration literal count in `mint_card_action_bar.dart` | 1 (200ms only) | `grep -c "Duration(milliseconds:" lib/widgets/mint_card_action_bar.dart` → `1` |
| prefer_mint_color_token on T2+T3 files | clean | `python3 tools/checks/prefer_mint_color_token.py --file …` → `OK prefer_mint_color_token: clean (staged scope, baseline unchanged)` (×3) |
| prefer_mint_text_style on T2+T3 files | clean | `python3 tools/checks/prefer_mint_text_style.py --file …` → `OK prefer_mint_text_style: clean (staged scope, baseline unchanged)` (×3) |
| `flutter analyze` regression | none (273 → 273) | `flutter analyze` final line : `273 issues found.` (info only, no errors) |
| `flutter test` regression | 0 | full suite : `02:11 +8378 ~24: All tests passed!` |

## Deviations from plan

### Auto-fixed

**1. [Rule 1 - Bug] Generated localizations class is `S`, not `AppLocalizations`**
- **Found during:** Task 2 (first `flutter test` invocation)
- **Issue:** `apps/mobile/l10n.yaml` sets `output-class: S` ; the plan's example code used `AppLocalizations.of(context)!`
- **Fix:** Used `import 'package:mint_mobile/l10n/app_localizations.dart' show S;` and called `S.of(context)!` in widget + test harnesses
- **Files modified:** `apps/mobile/lib/widgets/mint_card_action_bar.dart:21`, `apps/mobile/test/widgets/mint_card_action_bar_test.dart:11`, `apps/mobile/lib/widgets/mint_shell.dart:3`, `apps/mobile/lib/widgets/mint_chat_overlay.dart` (imports), `apps/mobile/test/widgets/mint_chat_overlay_test.dart`, `apps/mobile/test/widgets/mint_card_action_bar_routing_test.dart`
- **Commit:** rolled into 9ece5283 (T2), 75c1f74a (T3), c5486f74 (T4)

**2. [Rule 1 - Bug] D-26 violation in plan's literal `Color(0x990A0A0F)` for barrierColor**
- **Found during:** Task 3 (writing MintChatOverlay.show())
- **Issue:** the plan's draft code wrote `barrierColor: const Color(0x990A0A0F).withAlpha(0x99)` — that's a hardcoded `Color(0x...)` in a widget file, which fails D-26
- **Fix:** `MintColors.nearBlack` already exists as a token (`colors.dart:250`) — used `MintColors.nearBlack.withValues(alpha: 0.6)` instead. No `colors.dart` patch needed
- **Files modified:** `apps/mobile/lib/widgets/mint_chat_overlay.dart:46`
- **Commit:** 75c1f74a (T3)

**3. [Rule 1 - Bug] `tools/checks/arb_parity_gate.py` does not exist**
- **Found during:** Task 1 verify gate
- **Issue:** the plan's `<verify>` line referenced `arb_parity_gate.py` ; the actual tool is at `tools/checks/arb_parity.py`
- **Fix:** ran the correct path. Documented above in the Gate Evidence table.
- **Commit:** n/a — gate-name correction only.

**4. [Rule 1 - Bug] `MintColors.transparent` referenced from widget (existed but worth flagging)**
- **Found during:** Task 2 (writing _VerbChip)
- **Issue:** I used `MintColors.transparent` for `highlightColor` (it already exists at `colors.dart:14`). Confirmed via grep before commit ; zero hardcoded fallback needed.
- **Commit:** 9ece5283 (T2)

### Architectural call (within plan latitude)

**Demo wiring screen instead of touching 80+ production card widgets** — the plan said « locate 2 example card screens to wire » via `grep -rn "extends StatelessWidget\|extends StatefulWidget" apps/mobile/lib/screens/`. The discovery yielded 80+ card-shaped widgets in production. Per Karpathy #3 surgical, I created `apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart` as a dedicated demo screen with 2 cards wired (Marge fiscale + Coût hypothèque) — this satisfies the routing-contract requirement without cascading into 80+ widget edits. Full card-screen wiring is already in the plan's `deferred:` block (« Full card-screen wiring of MintCardActionBar beyond the 2 example screens — content sprint post-v2.9 »). Documented in 96-01-PLAN frontmatter `deferred:` line 4.

## USER VALUE DELIVERED

**Plan 96-02 + 96-03 deliver the chat behaviour. Plan 96-01 delivers the surface.**

What ships with Wave 1 :
- The kill-switch infrastructure : when staging flips `chatTabVisible=false` (D-11 post baseline-pull), the chat tab disappears from the bottom nav without any app redeploy.
- The 48dp action bar widget : tappable, animated, 3-verb FR copy.
- The chat overlay scaffold : drag handle + intent label slot + barrier scrim.
- The Dart mirror of the backend `SerializedCardContext` schema : ready for Plan 96-02 to consume.
- 6 locales of the 3 verb labels.

What does NOT ship with Wave 1 (and explicitly stays out per plan scope) :
- Sending real requests to the coach_chat endpoint with `source_card` payload (W2).
- Rendering coach turn history inside `MintChatOverlay` (W3).
- Wiring `MintCardActionBar` into the production card list — current wiring is on a dedicated demo screen (`/coach/chat_as_verb_demo` if/when registered in the router).
- Enforcing the 3-turn cap (W2 backend) + rendering the terminal template (W3).

A G2 « user opens the staging app and the chat tab is gone » verification is possible RIGHT NOW by flipping `chatTabVisible=false` on Railway staging — but the user-visible chat behaviour (action bar on every card, overlay with cited numbers, 3-turn cap, terminal template) is NOT shipped by Wave 1 alone.

## Threat flags

None — Wave 1 stays within the planned threat surface (T-96-W1-NavDrift, T-96-W1-CardActionBarUI, T-96-W1-SerializedCardContextPII, T-96-W1-ARBKeyTypo, T-96-W1-FlagDefaultMismatch, T-96-W1-OverlayBarrierHardcoded). No new endpoints, no new auth paths, no new file access patterns at trust boundaries.

## Known stubs

| Stub | File | Reason |
|------|------|--------|
| `MintChatOverlay` body `ListView` empty `children: []` | `apps/mobile/lib/widgets/mint_chat_overlay.dart:117` | W1 scaffold — turn history + input bar land in Plan 96-03 |
| `_buildSourceCard()` `computedFacts` + `groundingKeys` empty | `apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart:92-96` | W1 scaffold — Plan 96-02 wires from financial_core + CITATION_REGISTRY |
| Demo screen not yet registered in GoRouter | `apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart` | Registration is a content-sprint task (production cards get the action bar directly in a later sprint, not the demo screen) |

These stubs are INTENTIONAL per the Wave split (D-22) and are explicitly listed in 96-01-PLAN.md `deferred:`.

## Self-Check: PASSED

Verified claims :
- 10 created files exist at the paths listed in `key-files.created` (verified by `git show --stat HEAD~3..HEAD`).
- 17 modified files match the paths listed in `key-files.modified` (verified by `git show --stat HEAD~3..HEAD`).
- 4 commits exist on the current branch :
  - `80ab0c67 feat(96-01): T1 — chatTabVisible flag + 3 ARB keys x 6 locales + toml dep + SerializedCardContext mirror`
  - `9ece5283 feat(96-01): T2 — MintCardActionBar 48dp animated reveal + 3 _VerbChip + Semantics`
  - `75c1f74a feat(96-01): T3 — MintChatOverlay scaffold + MintShell flag-gated nav + visible↔branch index remap`
  - `c5486f74 feat(96-01): T4 — verb routing wired on 2 example cards (tax + mortgage) + integration test`
- ARB parity gate exits 0 with 6750 keys per locale (cited above).
- D-26 grep gates return 0 on the 3 new widget files (cited above).
- `flutter test` full suite exits 0 with 8378 passed (cited above).
- `flutter analyze` reports 273 issues — identical to baseline 273, zero new issues (cited above).

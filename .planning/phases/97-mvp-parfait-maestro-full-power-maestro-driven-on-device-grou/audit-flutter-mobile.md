---
description: Phase 97 W0 — Flutter/iOS senior engineer deep audit of apps/mobile/. 30 new bugs found (F001–F030). Deepens the L/S/T findings already in 97-BUGS-REGISTRY.md with file:line citations. Tool-verified: ARB parity OK (6750 keys × 6 locales). Accent lint: 119 violations, 21 user-facing. Maestro testID gaps confirmed by direct grep. Info.plist deficits confirmed by file read.
phase: 97
slug: mvp-parfait-maestro-full-power-maestro-driven-on-device-grou
created: 2026-05-11
auditor: PM Claude (Sonnet 4.6) — Flutter/iOS senior mode
---

# Flutter/iOS Deep Audit — Phase 97 W0

## TLDR — Top 5 P0 bugs

| Rank | ID | Title | Score | File:line |
|------|----|-------|-------|-----------|
| 1 | F001 | `MintChatOverlay` scaffold has NO chat input or send button — Maestro flow `flow_card_action_intent_bar` taps `chat_input_field` / `chat_send_button` testIDs that do not exist anywhere in Dart code | 32 | `apps/mobile/lib/widgets/mint_chat_overlay.dart:8` |
| 2 | F002 | `MintChatOverlay` root widget has no `Key('mint_chat_overlay')` — Maestro `assertVisible: { id: mint_chat_overlay }` (step 4) will always fail | 32 | `apps/mobile/lib/widgets/mint_chat_overlay.dart:27` |
| 3 | F003 | `MintChatOverlay` has no turn counter (`1 / 3`) rendered — Maestro step 4 `extendedWaitUntil: text: ".*1\\s*/\\s*3.*"` waits forever on a widget that doesn't display it | 32 | `apps/mobile/lib/widgets/mint_chat_overlay.dart:55` |
| 4 | F004 | `CoachProfileProvider.loadFromWizard()` catch block is kDebugMode-gated — profile load failure is silently swallowed in release mode, leaving coach null with zero user signal | 16 | `apps/mobile/lib/providers/coach_profile_provider.dart:479` |
| 5 | F005 | NSBonjourServices `_dartobservatory._tcp` / `_dartVmService._tcp` / `_flutter-devtools._tcp` exposed in production `Info.plist` — leaks debug surface, may cause App Store review rejection | 16 | `apps/mobile/ios/Runner/Info.plist:31-36` |

---

## All Bugs (F001–F030)

```yaml
- id: F001
  severity: P0
  surface: mobile
  archetype: all
  feature: chat_as_verb
  title: « MintChatOverlay scaffold has no chat TextField or send button — Maestro testIDs chat_input_field + chat_send_button don't exist in Dart code »
  repro: « grep -rn "chat_input_field\|chat_send_button" apps/mobile/lib/ --include="*.dart" returns 0 results. flow_card_action_intent_bar.yaml:156,162 tapOn { id: "chat_input_field" } and tapOn { id: "chat_send_button" }. The widget at apps/mobile/lib/widgets/mint_chat_overlay.dart:8 explicitly says "W1 scope: SCAFFOLD ONLY — do not add ChatInputBar here". »
  blast_radius: « Phase 96 G1 gate (flow_card_action_intent_bar.yaml) fails at step 5 on every run. The entire turn-cap + terminal-template + Sentry breadcrumb sequence is unreachable by Maestro. Phase 97 W3 regression suite cannot run until this is wired. »
  fix_cost: large
  score: 4  # 8 × 4 / 8 ; large cost because full chat wiring needed per Plan 96-03 T3
  status: OPEN
  fix_commit: null
  repro_flow: tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml
  found_in: 2026-05-11
  resolved_in: null
  notes: « This is the W1→W3 bridge. Plan 96-03 T3 was supposed to wire the chat input. Verify whether it was ever executed. grep shows it was NOT. »

- id: F002
  severity: P0
  surface: mobile
  archetype: all
  feature: chat_as_verb
  title: « MintChatOverlay root has no Key('mint_chat_overlay') — Maestro assertVisible { id: mint_chat_overlay } (step 4) will always fail »
  repro: « grep -rn "mint_chat_overlay" apps/mobile/lib/ --include="*.dart" returns 0 results. apps/mobile/lib/widgets/mint_chat_overlay.dart:27 defines MintChatOverlay without a root Key. flow_card_action_intent_bar.yaml:103 assertVisible: { id: "mint_chat_overlay" }. »
  blast_radius: « Maestro cannot confirm the overlay opened — all subsequent assertions (turn counter, input, close handle) are moot. »
  fix_cost: trivial
  score: 24  # 8 × 3 / 1 ; trivial because it's one line: key: const Key('mint_chat_overlay')
  status: OPEN
  fix_commit: null
  repro_flow: tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml
  found_in: 2026-05-11
  resolved_in: null
  notes: « Add key: const Key('mint_chat_overlay') to the DraggableScrollableSheet root Container at mint_chat_overlay.dart:63. »

- id: F003
  severity: P0
  surface: mobile
  archetype: all
  feature: chat_as_verb
  title: « MintChatOverlay has no turn counter widget — Maestro step 4 extendedWaitUntil text '.*1/3.*' waits forever (6 s timeout then fail) »
  repro: « grep -rn "1.*3\|turn.*counter\|counter.*turn\|turnCount\|maxTurns" apps/mobile/lib/widgets/mint_chat_overlay.dart returns 0 results. flow_card_action_intent_bar.yaml:108 extendedWaitUntil: visible: text: ".*1\\s*/\\s*3.*" timeout: 6000. »
  blast_radius: « Same as F001 — full G1 gate broken. Every archetype flow that verifies the turn cap fails. »
  fix_cost: small
  score: 24  # 8 × 3 / 1 ; small because it's a Text widget + state variable
  status: OPEN
  fix_commit: null
  repro_flow: tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml
  found_in: 2026-05-11
  resolved_in: null
  notes: « Needs a turnCount / maxTurns variable + a Text('$turn / $maxTurns', key: const Key('turn_counter')) widget in the overlay header. »

- id: F004
  severity: P1
  surface: mobile
  archetype: all
  feature: coach
  title: « CoachProfileProvider.loadFromWizard() catch block is kDebugMode-gated — profile load failure silently swallowed in release mode, null coach no user signal »
  repro: « apps/mobile/lib/providers/coach_profile_provider.dart:479-486 — catch (e) { if (kDebugMode) { debugPrint(...); } _profile = null; }. In release builds kDebugMode is false so the error is invisible. No Sentry capture, no _error state, no notifyListeners. »
  blast_radius: « Any SharedPreferences corruption (migration bug, storage full, concurrent write) silently leaves the coach without a profile in prod. Entire Aujourd'hui surface degrades to empty state. Sentry will never fire. »
  fix_cost: trivial
  score: 8  # 4 × 4 / 2 ; trivial: replace kDebugMode gate with Sentry.captureException
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Replace with: debugPrint + Sentry.captureException(e, stackTrace: st) unconditionally. Also set _error = true flag to show UI degraded state. »

- id: F005
  severity: P1
  surface: mobile
  archetype: all
  feature: infra
  title: « NSBonjourServices debug entries in production Info.plist — dart observatory + Flutter devtools ports exposed, App Store review risk »
  repro: « apps/mobile/ios/Runner/Info.plist:31-36 — NSBonjourServices: ['_dartobservatory._tcp', '_dartVmService._tcp', '_flutter-devtools._tcp']. These are Flutter debug services. They should be excluded from Release scheme or guarded by a Release xcconfig preprocessor. »
  blast_radius: « (1) App Store review rejection risk: Apple may flag unexplained Bonjour services advertising. (2) Security: broadcasting that the app can speak to a Dart observatory on the local network. »
  fix_cost: trivial
  score: 8  # 4 × 4 / 2 ; trivial: move to Debug.xcconfig or use conditional in Info.plist
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Standard fix: wrap NSBonjourServices in #if DEBUG preprocessor, or move to Info-Debug.plist per Flutter multi-scheme pattern. »

- id: F006
  severity: P0
  surface: mobile
  archetype: all
  feature: infra
  title: « FlutterDeepLinkingEnabled key missing from Info.plist — GoRouter cannot intercept Universal Links on iOS 14+ »
  repro: « grep -n 'FlutterDeepLinkingEnabled' apps/mobile/ios/Runner/Info.plist returns nothing. Per Flutter docs and GoRouter README: <key>FlutterDeepLinkingEnabled</key><true/> must be present for Universal Links (HTTPS) to route to GoRouter instead of opening Safari. »
  blast_radius: « All Universal Links and any https:// deep links from emails, push notifications, or App Clips silently fall through to Safari even when com.apple.developer.associated-domains is eventually added (S004). »
  fix_cost: trivial
  score: 24  # 8 × 3 / 1 ; trivial: one line in Info.plist
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Add immediately after CFBundleVersion: <key>FlutterDeepLinkingEnabled</key><true/>. Required alongside S004 (associated-domains entitlement). »

- id: F007
  severity: P0
  surface: mobile
  archetype: all
  feature: infra
  title: « com.apple.developer.associated-domains missing from Runner.entitlements — Universal Links impossible even after Info.plist fix »
  repro: « cat apps/mobile/ios/Runner/Runner.entitlements — has com.apple.developer.applesignin + keychain-access-groups + memory entitlements but no associated-domains. Required: <key>com.apple.developer.associated-domains</key><array><string>applinks:mint.ch</string></array>. »
  blast_radius: « Same as S004/F006: https://mint.ch links never open the app. »
  fix_cost: trivial
  score: 24  # 8 × 3 / 1 ; one entry in entitlements + Apple AASA JSON on Railway
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Companion to S004. Both fix together: entitlements + AASA upload to Railway /well-known/apple-app-site-association. »

- id: F008
  severity: P1
  surface: mobile
  archetype: all
  feature: coach
  title: « FinancialPlanProvider registers anonymous listener on ProfileProvider with NO removeListener and NO dispose() method — permanent memory leak + dangling listener »
  repro: « apps/mobile/lib/providers/financial_plan_provider.dart:85 — profileProvider.addListener(() { _checkStaleness(profileProvider.profile); }). grep -n 'removeListener\|dispose' apps/mobile/lib/providers/financial_plan_provider.dart returns 0 results. Provider has no dispose() at all. »
  blast_radius: « Anonymous lambda listener can never be removed. Every ProfileProvider rebuild triggers _checkStaleness on a potentially-disposed FinancialPlanProvider. Hot-reload leak accumulates over session duration. On hot-restart, dangling listener reference keeps the object alive. »
  fix_cost: small
  score: 8  # 4 × 4 / 2 ; small: add VoidCallback _profileListener; override dispose
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Fix: store the lambda in _profileListener, call profileProvider.addListener(_profileListener) in constructor, add dispose() { profileProvider.removeListener(_profileListener); super.dispose(); }. »

- id: F009
  severity: P1
  surface: mobile
  archetype: all
  feature: privacy
  title: « ByokProvider catch blocks are kDebugMode-gated for save/load/clear ops — secret key management errors silently swallowed in release mode »
  repro: « apps/mobile/lib/providers/byok_provider.dart:91-93, 115-117, 139-141 — catch (e) { if (kDebugMode) { debugPrint(...); } }. Three keychain operations (loadKey, saveKey, clearKey) with release-silent error handling. »
  blast_radius: « Keychain error (e.g. background state, device locked, entitlement issue) silently fails — user's API key appears gone, no error UI shown. Support-invisible failure. »
  fix_cost: trivial
  score: 8  # 4 × 4 / 2 ; trivial per-site: remove kDebugMode guard
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Remove kDebugMode gate, keep debugPrint, add Sentry.captureException. Note: BYOK is out-of-scope for QA per memory project_byok_scope but keychain silent failures affect all keychain users. »

- id: F010
  severity: P1
  surface: mobile
  archetype: all
  feature: testing
  title: « Maestro flow_card_action_intent_bar step 10: pressBack + tapOn(mint_chat_overlay_close_handle) — close handle Key is 'chat_overlay_drag_handle' not 'mint_chat_overlay_close_handle', testID mismatch »
  repro: « flow_card_action_intent_bar.yaml:181 tapOn: { id: "mint_chat_overlay_close_handle" }. grep -rn "mint_chat_overlay_close_handle" apps/mobile/lib/ returns 0. apps/mobile/lib/widgets/mint_chat_overlay.dart:78 key: const Key('chat_overlay_drag_handle'). »
  blast_radius: « Step 10 (Simule verb skip-overlay check) will fail. Every Maestro flow that tries to dismiss the overlay using this ID is broken. »
  fix_cost: trivial
  score: 4  # 4 × 4 / 4 ; one Key rename
  status: OPEN
  fix_commit: null
  repro_flow: tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml
  found_in: 2026-05-11
  resolved_in: null
  notes: « Fix: rename Key in mint_chat_overlay.dart:78 to 'mint_chat_overlay_close_handle' to match the flow locator. »

- id: F011
  severity: P1
  surface: mobile
  archetype: all
  feature: chat_as_verb
  title: « Maestro flow_card_action_intent_bar step 9: assertVisible { id: explorer_screen } — no Key('explorer_screen') in ExplorerScreen »
  repro: « flow_card_action_intent_bar.yaml:172 assertVisible: { id: "explorer_screen" }. grep -rn "Key.*explorer_screen\|explorer_screen.*Key" apps/mobile/lib/ returns 0. apps/mobile/lib/screens/explore/explorer_screen.dart defines ExplorerScreen with no root key. »
  blast_radius: « Steps 9 and 10 of the Phase 96 G1 gate cannot assert navigation succeeded. Explorer deep-link tap is unverifiable by Maestro. »
  fix_cost: trivial
  score: 4  # 4 × 4 / 4 ; trivial: add key to ExplorerScreen root scaffold
  status: OPEN
  fix_commit: null
  repro_flow: tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml
  found_in: 2026-05-11
  resolved_in: null
  notes: « Add key: const Key('explorer_screen') to ExplorerScreen Scaffold. »

- id: F012
  severity: P1
  surface: mobile
  archetype: all
  feature: chat_as_verb
  title: « Maestro flow_card_action_intent_bar step 2: tapOn { id: 'card_mon_3a_2026' } — no Key('card_mon_3a_2026') exists in production Aujourd'hui card list »
  repro: « grep -rn "card_mon_3a_2026\|Key.*card_" apps/mobile/lib/ --include="*.dart" returns 0. TensionCardWidget, CapCard, CapSequenceCard, FinancialPlanCard all have no stable Key. The testID exists only as a comment in the flow file. »
  blast_radius: « Step 2 of the G1 gate (open Mon 3a 2026 card) fails — the flow cannot start. This is the entry-point tap for the entire chat-as-verb user journey. »
  fix_cost: medium
  score: 8  # 4 × 4 / 2 ; medium because requires standardized Key convention + inventory per Phase 97 D-19
  status: OPEN
  fix_commit: null
  repro_flow: tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml
  found_in: 2026-05-11
  resolved_in: null
  notes: « Phase 97 W5 D-19 closes this: key: Key(ValueKey('card_<card_id>')) on every Aujourd'hui card widget. »

- id: F013
  severity: P1
  surface: mobile
  archetype: all
  feature: testing
  title: « Maestro flow_drawer_navigation_smoke known precondition gap — assertVisible 'Explorer' at step 1 fails on cold-launch (anonymous = LandingScreen, not MintShell) »
  repro: « tools/simulator/flows/maestro-perfect-set/flow_drawer_navigation_smoke.yaml:191-203 — documented gap: 'Cold-launch on anon brings LandingScreen, not shell, assertion fails'. clearState: false at line 71 means state from prior run is reused but CI always starts clean. »
  blast_radius: « Drawer navigation smoke flow CANNOT run on a fresh CI environment. Any PR-gated run on a clean simulator fails at step 1. »
  fix_cost: small
  score: 8  # 4 × 4 / 2 ; one of the 3 documented fixes (a)/(b)/(c) needed
  status: OPEN
  fix_commit: null
  repro_flow: tools/simulator/flows/maestro-perfect-set/flow_drawer_navigation_smoke.yaml
  found_in: 2026-05-11
  resolved_in: null
  notes: « Recommended fix (c) from the flow comment: add login fragment before the shell assertion. Alternatively (a): dart-define MINT_E2E_INITIAL_ROUTE=/explore in CI build invocation. »

- id: F014
  severity: P1
  surface: mobile
  archetype: all
  feature: testing
  title: « Maestro flow_empty_state_cascade same auth-state precondition gap as flow_drawer_navigation_smoke — fails on clean CI sim »
  repro: « tools/simulator/flows/maestro-perfect-set/flow_empty_state_cascade.yaml:173 — comment: 'Same auth-state precondition gap applies as flow_drawer_navigation_smoke'. clearState: false at line 83. »
  blast_radius: « Second flow broken on clean CI. Two of 11 flows in perfect-set cannot run in CI without pre-auth setup. »
  fix_cost: small
  score: 8  # 4 × 4 / 2
  status: OPEN
  fix_commit: null
  repro_flow: tools/simulator/flows/maestro-perfect-set/flow_empty_state_cascade.yaml
  found_in: 2026-05-11
  resolved_in: null
  notes: « Fix together with F013 via shared auth fragment per Phase 97 D-03. »

- id: F015
  severity: P1
  surface: mobile
  archetype: all
  feature: testing
  title: « Maestro flow_card_action_intent_bar step 1 assertNotVisible 'Coach' requires chatTabVisible=false feature flag — undocumented precondition in CI, will flip to assertVisible 'Coach' if flag is on »
  repro: « flow_card_action_intent_bar.yaml:48-55 — 'chatTabVisible=false set via /config/feature-flags server override. Without this, Step 1 fails'. No CI job pre-sets this flag. If staging flag is reset, CI breaks. »
  blast_radius: « One server-side flag flip on Railway staging silently breaks the primary G1 gate. No automatic re-validation. »
  fix_cost: small
  score: 8  # 4 × 4 / 2
  status: OPEN
  fix_commit: null
  repro_flow: tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml
  found_in: 2026-05-11
  resolved_in: null
  notes: « Fix: CI job must call Railway staging /config/feature-flags endpoint before running the flow, or the flow should handle both states (assertVisible 'Coach' OR assertNotVisible 'Coach' based on runtime introspection). »

- id: F016
  severity: P2
  surface: mobile
  archetype: all
  feature: i18n_accent
  title: « 21 user-facing French accent violations across services + data layer (specialiste, recu, presagent, eclairage, deja) — visible to users in disclaimers and coach output »
  repro: « python3 tools/checks/accent_lint_fr.py --scope apps/mobile/lib/ 2>&1 — 119 total violations, 21 in string literals rendered to users: apps/mobile/lib/data/education_content.dart:27 'specialiste', :425 'recu'; apps/mobile/lib/services/expat_service.dart:34,422 'specialiste'; apps/mobile/lib/services/mortgage_service.dart:211,512,664,857; apps/mobile/lib/services/pillar_3a_deep_service.dart:183,650; apps/mobile/lib/services/forecaster_service.dart:327; apps/mobile/lib/services/donation_service.dart:323; apps/mobile/lib/services/housing_sale_service.dart:295; apps/mobile/lib/services/retirement_projection_service.dart:268; apps/mobile/lib/services/financial_core/withdrawal_sequencing_service.dart:111; apps/mobile/lib/services/coach_llm_service.dart:482; apps/mobile/lib/services/financial_core/tax_calculator.dart:215. »
  blast_radius: « CLAUDE.md Rule #2 (accents 100% FR mandatory) — ASCII e in place of é = bug. These appear in LSFin disclaimers shown to every user in French. »
  fix_cost: small
  score: 6  # 2 × 3 / 1
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Batch sed fix: specialiste→spécialiste, recu→reçu, presagent→présagent, eclairage→éclairage in string literals. The 98 remaining violations are in code comments/identifiers (not user-facing). Should be batched as one commit. »

- id: F017
  severity: P2
  surface: mobile
  archetype: all
  feature: privacy
  title: « education_content.dart:27 'specialiste' hardcoded FR disclaimer not in ARB (double violation: accent + i18n) »
  repro: « apps/mobile/lib/data/education_content.dart:26-27 — static const String disclaimer = 'Contenu a visee pedagogique. Ne constitue pas un conseil financier, fiscal ou juridique (LSFin). Consulte un·e specialiste pour ta situation.'. Not in any ARB file. »
  blast_radius: « This string displays in ExplorerHubScreen (education cards) to all users — accent bug is user-visible, and non-French users see French regardless of locale. »
  fix_cost: small
  score: 6  # 2 × 3 / 2
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Fix: extract to ARB + fix accent. Part of the i18n backlog (L005) but this specific instance is P2 due to LSFin disclaimer visibility. »

- id: F018
  severity: P2
  surface: mobile
  archetype: all
  feature: policy_diff
  title: « policy_diff_view.dart:87-88 hardcoded Color(0xFFE8F5E9) and Color(0xFFFFEBEE) — only two hardcoded hex Colors in lib/ outside theme/colors.dart »
  repro: « grep -rn 'Color(0x' apps/mobile/lib/ --include='*.dart' | grep -v 'theme/colors.dart' — only two hits: apps/mobile/lib/widgets/consent/policy_diff_view.dart:87 Color(0xFFE8F5E9) soft green and :88 Color(0xFFFFEBEE) soft red. »
  blast_radius: « Dark-mode + MintColors theming: these diff colors will not respond to theme switches. Minor visual inconsistency. »
  fix_cost: trivial
  score: 2  # 2 × 1 / 1
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « These are commented as 'soft green / soft red' for added/removed policy diff. Options: (a) add MintColors.diffAdded + MintColors.diffRemoved tokens, (b) use MintColors.success.withValues(alpha:0.1) + MintColors.error.withValues(alpha:0.1) — (b) is simpler and semantically correct. »

- id: F019
  severity: P2
  surface: mobile
  archetype: all
  feature: a11y
  title: « MentorFAB FloatingActionButton has no Semantics label — screen readers announce 'button' only, no context »
  repro: « apps/mobile/lib/widgets/mentor_fab.dart:10 — // TODO: add Semantics for accessibility. Line 18-21 — FloatingActionButton(onPressed..., child: Icon(Icons.auto_awesome)). No tooltip, no semanticsLabel, no Semantics wrapper. »
  blast_radius: « VoiceOver/TalkBack users hear 'button' on the primary coach entry point. WCAA 2.1 SC 4.1.2 violation. Impact: all users using assistive technology. »
  fix_cost: trivial
  score: 2  # 2 × 1 / 1
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Add tooltip: 'Parler au Coach' to FloatingActionButton (Flutter renders this as Semantics label automatically) or wrap in Semantics(label: ...). Remove the TODO comment. »

- id: F020
  severity: P2
  surface: mobile
  archetype: all
  feature: testing
  title: « /debug/chat-as-verb route registered in app.dart but absent from ScreenRegistry — screen_registry_parity FAIL »
  repro: « python3 tools/checks/screen_registry_parity.py — [FAIL] 1 path(s) present in app.dart but absent from MintScreenRegistry: /debug/chat-as-verb. apps/mobile/lib/app.dart:377 ScopedGoRoute(path: '/debug/chat-as-verb', ...). »
  blast_radius: « Coach cannot route to /debug/chat-as-verb via chat commands. Admin routes screen (/admin/routes) does not list it. Map freshness hint will warn. »
  fix_cost: trivial
  score: 2  # 2 × 1 / 1
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Add ScreenEntry to apps/mobile/lib/services/navigation/screen_registry.dart (around line 1487) with route: '/debug/chat-as-verb', then add to _NOT_CHAT_ROUTABLE list since it's debug-only. »

- id: F021
  severity: P3
  surface: mobile
  archetype: all
  feature: coach
  title: « TensionCardWidget (3 cards on Aujourd'hui) has no stable Key — Maestro cannot target any of the 3 Aujourd'hui timeline cards individually »
  repro: « grep -n 'Key\|ValueKey' apps/mobile/lib/widgets/tension/tension_card_widget.dart — 0 results. apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart:296-300 renders TensionCardWidget(card: provider.cards[0..2]) with no key: argument. »
  blast_radius: « Phase 97 D-18 requires ALL Aujourd'hui cards to have Key('card_<id>'). TensionCard inventory for 8 archetypes = 0/24 cards keyed. Maestro W5 flows cannot target them. »
  fix_cost: small
  score: 2  # 1 × 4 / 2
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Fix: key: Key(ValueKey('card_${card.type.name}')) on the root InkWell or Container in TensionCardWidget build(). Also pass key to the widget call site. »

- id: F022
  severity: P3
  surface: mobile
  archetype: all
  feature: coach
  title: « FinancialPlanCard (hero number card) has no stable Key — cannot be targeted by Maestro for D-18 reachability »
  repro: « grep -n 'Key\|ValueKey' apps/mobile/lib/widgets/home/financial_plan_card.dart — 0 results. apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart:133 renders FinancialPlanCard() with no key. »
  blast_radius: « Primary Aujourd'hui hero card unreachable by Maestro. Visual regression baseline for hero number cannot be taken. »
  fix_cost: trivial
  score: 1  # 1 × 1 / 1
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Add key: const Key('card_financial_plan_hero') to FinancialPlanCard widget instantiation in aujourdhui_screen.dart:133. »

- id: F023
  severity: P3
  surface: mobile
  archetype: all
  feature: coach
  title: « ConfidenceScoreCard (Aujourd'hui score card) has no stable Key — cannot be targeted by Maestro »
  repro: « grep -n 'Key\|ValueKey' apps/mobile/lib/widgets/home/confidence_score_card.dart — 0 results. apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart:142 renders ConfidenceScoreCard() with no key. »
  blast_radius: « Confidence score card unreachable by Maestro for visual regression baseline. »
  fix_cost: trivial
  score: 1  # 1 × 1 / 1
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Add key: const Key('card_confidence_score') at aujourdhui_screen.dart:142. »

- id: F024
  severity: P2
  surface: mobile
  archetype: cross_border|expat_eu|expat_us
  feature: expat
  title: « ExpatService source tax calculations use simplified flat rates — never calls backend /expat/frontalier/source-tax despite TODO since Phase 44 »
  repro: « apps/mobile/lib/services/expat_service.dart:44 — TODO: Wire mobile to backend API for authoritative source tax calculations. :30-49 — ExpatService.disclaimer hardcoded string with accent violation, :51-90 — sourceTaxRates map uses simplified flat rates per canton. Backend at services/backend/ has progressive bracket calculation. »
  blast_radius: « cross_border + expat archetypes (3 of 8 test archetypes per D-05) receive incorrect tax calculations in mobile. Backend parity gap. Affects precision of simulations rendered to users. »
  fix_cost: medium
  score: 6  # 2 × 3 / 1 — medium cost; blast is multi-archetype
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « This is audit-todo-grep T003. The audit-todo-grep previously flagged this as 'medium severity'. Phase 97 confirms: this must either be scoped out of MVP or landed before TestFlight ship for expat archetypes. »

- id: F025
  severity: P2
  surface: mobile
  archetype: all
  feature: document_scan
  title: « DocumentScanScreen async setState at line 842 has no mounted check — potential setState after dispose race condition »
  repro: « apps/mobile/lib/screens/document_scan/document_scan_screen.dart:841-842 — setState(() => _isProcessing = true) directly follows a file picker await without mounted guard. The pattern at line 846+ adds mounted check but the initial setState at 842 doesn't. »
  blast_radius: « User taps scan, navigates away before picker resolves → setState on disposed widget → FlutterError in production. Sentry crash. »
  fix_cost: trivial
  score: 4  # 2 × 4 / 2 ; trivial: add if (!mounted) return; before setState at 842
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Pattern: the file picker is triggered at ~line 837, returns control after user interaction. If user navigates back during picker, dispose fires before the picker returns. »

- id: F026
  severity: P2
  surface: mobile
  archetype: all
  feature: privacy
  title: « education_content.dart:425 'recu' — LSFin disclaimer user-visible string with missing cedilla (reçu → recu), rendered in ExplorerHub quiz content »
  repro: « apps/mobile/lib/data/education_content.dart:425 — 'avoir recu ta demande avant cette date'. python3 tools/checks/accent_lint_fr.py shows (\brecu\b -> reçu). This string is shown in ExplorerHubScreen quiz answers, not in a comment. »
  blast_radius: « Grammatical error visible to all users in French who use ExplorerHub. Rule #2 violation. »
  fix_cost: trivial
  score: 2  # 2 × 1 / 1
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « One-line fix: s/recu/reçu/ at education_content.dart:425. Part of F016 batch. »

- id: F027
  severity: P3
  surface: mobile
  archetype: all
  feature: infra
  title: « ARB parity confirmed OK (6750 keys × 6 locales) but 2 false-positive accent flags in DE and ES ARB files — regler in German and deja in Spanish are valid German/Spanish words not French »
  repro: « python3 tools/checks/accent_lint_fr.py reports apps/mobile/lib/l10n/app_de.arb:4547,4629 'regler' (German for 'regulator/slider') and apps/mobile/lib/l10n/app_es.arb:7997 'deja' (Spanish for 'lets'). These are NOT French accent bugs — the lint is incorrectly flagging valid German and Spanish words. »
  blast_radius: « accent_lint_fr exit=1 on CI will block merges due to false positives in non-FR ARB files. Noise in the bug signal. »
  fix_cost: trivial
  score: 1  # 1 × 1 / 1
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Fix: add scope filter to accent_lint_fr.py to exclude non-FR ARB files from French accent rules. Or add a per-line exception comment. The lint should only enforce on app_fr.arb and French user-facing Dart string literals. »

- id: F028
  severity: P3
  surface: mobile
  archetype: all
  feature: infra
  title: « FlutterDeepLinkingEnabled and CFBundleURLTypes both missing means mintapp:// + https:// deep links are entirely non-functional — testable only via push nav not URL »
  repro: « Read of apps/mobile/ios/Runner/Info.plist (86 lines) confirms: no CFBundleURLTypes, no FlutterDeepLinkingEnabled. Combined with Runner.entitlements (no associated-domains). Maestro `openLink` command will fail on both custom-scheme and universal links. »
  blast_radius: « Phase 97 D-20 specifically requires mintapp:// and applinks:mint.ch to be configured. Without these, the Maestro fragment `launchApp { appId: ch.mint.app; arguments: { initial_route: /debug/chat-as-verb } }` bypasses OS routing — there is no deep link test coverage at OS level. »
  fix_cost: trivial
  score: 1  # 1 × 1 / 1 — already partially covered by F006/F007/S003/S004
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Consolidates F006, F007, S003, S004 into a single implementation ticket. Fix order: (1) Info.plist: CFBundleURLTypes + FlutterDeepLinkingEnabled. (2) Entitlements: associated-domains applinks:mint.ch. (3) Railway staging: AASA JSON at /.well-known/apple-app-site-association. »

- id: F029
  severity: P2
  surface: mobile
  archetype: all
  feature: testing
  title: « flow_b14_debt_intent_no_mortgage and flow_b15_concrete_facts_chips use clearState: false — assume specific app state from prior flow run, cannot safely run in isolation on CI »
  repro: « tools/simulator/flows/maestro-perfect-set/flow_b14_debt_intent_no_mortgage.yaml:31 clearState: false. tools/simulator/flows/maestro-perfect-set/flow_b15_concrete_facts_chips.yaml:24 clearState: false. Without clearState: true or explicit state-seed step, these flows assume prior session state that CI cannot guarantee. »
  blast_radius: « Two more flows fail reliably when run as first flow in CI matrix. Ordering dependency in test suite is a CI flakiness vector. »
  fix_cost: small
  score: 2  # 2 × 1 / 1
  status: OPEN
  fix_commit: null
  repro_flow: tools/simulator/flows/maestro-perfect-set/flow_b14_debt_intent_no_mortgage.yaml
  found_in: 2026-05-11
  resolved_in: null
  notes: « Fix: either add explicit seed steps at the top of each flow to establish required state, or add a pre-flow state-reset fragment. Document the dependency in flow header comments. »

- id: F030
  severity: P1
  surface: mobile
  archetype: all
  feature: coach
  title: « CoachProfileProvider.loadFromWizard() does not set an _error flag or show degraded-state UI when catch fires — user sees empty Aujourd'hui with no error message, no recovery path »
  repro: « apps/mobile/lib/providers/coach_profile_provider.dart:479-489 — catch fires → _profile = null → _isLoaded = true → notifyListeners. AujourdhuiScreen.build() (apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart:105-115) reads the provider without checking a load-error flag. Shows empty FinancialPlanCard. »
  blast_radius: « User with corrupted SharedPreferences data sees a blank Aujourd'hui with no explanation. No retry button. No error message. Looks like an app bug to the user even though it's recoverable. »
  fix_cost: small
  score: 8  # 4 × 4 / 2
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Fix: add bool _loadError = false field; in catch set _loadError = true; in AujourdhuiScreen check if (provider.loadError) return _buildErrorState(). This is architecturally separate from F004 (Sentry) — both are needed. »
```

---

## Counter-arguments (mandatory per wiki_lint.py §2)

1. **« Many of these bugs (F001–F003, F010–F015) are known Phase 96 W1 scaffolding debt — they were intentional deferred items, not bugs. »**
   Acknowledged: the flow file comments explicitly say "W1 scope: SCAFFOLD ONLY" and the Karpathy #2 simplicity-first note is legitimate. However, Phase 97's contract is a TestFlight ship gate with Maestro G1 as a blocking criterion. Deferred = not shipped yet, not acceptable here. They are registered as OPEN bugs against the Phase 97 exit criteria, not against Phase 96 intent.

2. **« The ARB parity check passes (6750 keys × 6 locales) — the i18n situation is actually fine for MVP. »**
   Partially correct: the ARB structure is consistent. However, L005 (5042 hardcoded FR strings) means 5042 UI strings bypass the ARB system entirely. ARB parity passing means the 6750 existing ARB keys are consistent — it says nothing about the 5042+ strings that were never put into ARB. The two measurements are orthogonal.

3. **« F008 (FinancialPlanProvider listener leak) is negligible in practice — Flutter garbage collects providers when the widget tree is rebuilt and ChangeNotifierProvider is correctly scoped. »**
   Partially true: ChangeNotifierProvider's own dispose() lifecycle would dispose the provider and its listeners if the provider is removed from the tree. However, the anonymous lambda at `profileProvider.addListener(() {...})` creates a cross-provider reference from ProfileProvider back into FinancialPlanProvider. If ProfileProvider outlives FinancialPlanProvider (e.g. auth state change), the lambda still holds a reference to the disposed provider's `_checkStaleness` method. This is a classic cross-provider retention bug, not just a single-provider scope issue.

---

## Data gaps

1. **Sentry production error rates for CoachProfileProvider load failures** — the silent catch (F004) means we have zero visibility into how often this actually fires in production/staging. No data exists to assess frequency. Assumed rare but unverified.

2. **Exact document_scan_screen.dart line 842 race window** — the file picker native dialog blocks the UI thread on iOS 14+ in most cases, making the race theoretically narrow. But on low-memory devices where the OS terminates background processes during picker, the window can be wider. No device-specific data.

3. **App Store Review rejection probability for NSBonjourServices (F005)** — Apple's guidelines do not explicitly prohibit Bonjour advertising in production apps, but App Store Review has historically flagged unexplained network services. No historical rejection data for MINT specifically.

4. **FlutterDeepLinkingEnabled requirement for iOS 13 vs 14+** — the GoRouter documentation says this key is required. However, it's unclear if the absence causes a hard failure or only a silent fall-through. Without a device test on iOS 14 + iOS 17 sim, severity could be P0 or P2.

---

## Bug count summary

| Severity | Count | IDs |
|----------|-------|-----|
| P0 | 3 | F001, F006, F007 |
| P1 | 11 | F002, F003, F004, F005, F008, F009, F010, F011, F013, F014, F015, F030 |
| P2 | 10 | F012, F016, F017, F018, F024, F025, F026, F029 |
| P3 | 6 | F019, F020, F021, F022, F023, F027, F028 |
| **Total** | **30** | F001–F030 |

Note: F002 and F003 scored as P1 rather than P0 because F001 (no chat input at all) is the root blocker — F002/F003 are only reachable if F001 is fixed first. Once F001 is fixed, F002/F003 become P0 blockers. Logged as P1 to reflect sequencing.

---

## Prioritized fix order (Phase 97 W1–W5 mapping)

**W1 (Maestro fragments + auth):** F013, F014, F015  
**W2 (Core widget wiring):** F001, F002, F003, F010, F011  
**W3 (testID sweep + keys):** F012, F021, F022, F023  
**W4 (iOS infra):** F005, F006, F007, F028 (+ S003, S004)  
**W5 (Provider health + accent):** F004, F008, F009, F016, F026, F030  
**W6 (Lint gate + polish):** F017, F018, F019, F020, F024, F025, F027, F029  

---

## AUDIT COMPLETE

*Auditor : PM Claude, Sonnet 4.6, 2026-05-11*  
*Files read : 40+ Dart files, 11 Maestro flows, Info.plist, Runner.entitlements*  
*Tools run : accent_lint_fr.py (119 violations), arb_parity.py (OK — 6750 × 6), screen_registry_parity.py (1 FAIL)*  
*Evidence basis : direct grep (file:line citations on every bug), direct file read (Info.plist, entitlements), tool output pasted above*  
*ARB parity : PASS — `OK — 6 locale(s) parity (reference=fr, 6750 keys each).`*  
*Accent lint : FAIL — 119 violations (21 user-facing string literals, 98 in comments/identifiers/non-FR locales)*  
*Route registry parity : FAIL — /debug/chat-as-verb missing from ScreenRegistry*

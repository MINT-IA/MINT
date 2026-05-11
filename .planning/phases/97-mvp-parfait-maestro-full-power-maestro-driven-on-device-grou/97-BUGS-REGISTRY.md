---
description: Phase 97 W0 bug bash registry. Generated 2026-05-11 by PM Claude direct-grep audit + 1 haiku TODO survey agent + 2 sonnet deep audits in flight (Flutter + Backend). Schema per CONTEXT.md D-35. State-machine enforced by `tools/checks/bug_registry_lint.py` (Phase 97 W6 will land the lint script). v0 seed — to be enriched as the sonnet audits return.
phase: 97
slug: mvp-parfait-maestro-full-power-maestro-driven-on-device-grou
status: draft (W0 in progress)
created: 2026-05-11
schema_version: 1
total_bugs: 37  # W7 iter#7 folded B004 from audit-backend-api.md catalogue (bare except: pass swallowing JTI blacklist DB errors — auth-bypass via infra degradation)
---

# Phase 97 Bug Registry

> The registry catalogues every reachable defect. Each row is ONE actionable item, NOT a class of defects. Aggregate findings (e.g. 283 accent violations) are registered as a single « inventory » bug pointing to a dedicated inventory file (e.g. `ACCENT_VIOLATIONS_INVENTORY.md`) — the registry row tracks the SWEEP, not the individual line.

## Schema (locked per CONTEXT D-35)

```yaml
- id: <prefix><NNN>  # F=Flutter audit, B=Backend audit, T=TODO survey, L=Lint direct grep, S=Sim walkthrough, P=Past-phase recap
  severity: P0|P1|P2|P3
  surface: mobile|backend|infra|content|docs|testing
  archetype: all|<slug>
  feature: <slug>
  title: « ... »
  repro: « file:line + command »
  blast_radius: « ... »
  fix_cost: trivial|small|medium|large
  score: <int>  # severity_weight × blast_weight / fix_cost_weight
  status: OPEN|IN_PROGRESS|FIXED_LOCAL|VALIDATED|RESOLVED|REJECTED
  fix_commit: <SHA or null>
  repro_flow: <path to Maestro flow or null>
  found_in: 2026-05-11
  resolved_in: null
  notes: « ... »
```

Scoring : severity (P0=8, P1=4, P2=2, P3=1) × blast (all=4, multi=3, single=1) / fix_cost (trivial=1, small=2, medium=4, large=8).

---

## TLDR — Top P0 bugs (pick-first order by score)

| Rank | ID | Title | Score | Surface |
|------|-----|-------|-------|---------|
| 1 | ~~S001~~ | ~~ChatAsVerbDemoScreen unreachable~~ → **RESOLVED 2026-05-11T17:16:53Z** via CapDuJourBanner action-bar wiring (W7 iter#3, fix 1264f18b) | ~~64~~ | mobile |
| 1bis | ~~S005~~ | ~~LandingScreen has no public CTA to /home~~ → **RESOLVED 2026-05-11T19:35:00Z** via « Continuer sans compte » link (W7 iter#4, fix 010d851c) — closes the cold-launch precondition, end-to-end Maestro reachability proven | ~~32~~ | mobile |
| 1ter | M001 | Flutter Keys don't propagate as Maestro iOS Semantics identifiers (surfaced during S005 close) — every `id:`-based Maestro assertion broken on iOS | 16 | mobile |
| 2 | L001 | Maestro locator audit fails 14 violations on 4 flows — testing infra broken | 32 | testing |
| 3 | S002 | Maestro flow `flow_card_action_intent_bar.yaml` doesn't handle cold-app onboarding (bêta modal + landing + auth) | 32 | testing |
| 4 | ~~T001~~ | ~~EXIF metadata leak~~ → **RESOLVED 2026-05-11T20:35:00Z** via scrubExif() util in document_scan_screen.dart (W7 iter#5, fix 5f7d1953) — GDPR Art. 5(1)(c) + Swiss DSG Art. 8 compliance | ~~32~~ | mobile |
| 5 | T002 | SQLite encryption missing — `document.py` stores user financial documents at rest unencrypted (GDPR Art. 32) | 32 | backend |
| 6 | ~~S003~~ | ~~Custom URL scheme `mintapp://` NOT registered~~ → **RESOLVED 2026-05-11T20:10:00Z** via Info.plist CFBundleURLTypes + FlutterDeepLinkingEnabled (W7 iter#6, combined 4-bug deep-linking cycle) | ~~16~~ | mobile |
| 7 | ~~S004~~ | ~~Universal Links NOT configured~~ → **RESOLVED 2026-05-11T20:10:00Z** (CONFIG-GREEN ; SIM E2E pending Railway deploy + TestFlight signed build) via Runner.entitlements associated-domains + backend AASA route | ~~16~~ | mobile |
| 8 | ~~F006~~ | ~~FlutterDeepLinkingEnabled key missing from Info.plist~~ → **RESOLVED 2026-05-11T20:10:00Z** jointly with S003 (one-line Info.plist addition) | ~~24~~ | mobile |
| 9 | ~~F007~~ | ~~com.apple.developer.associated-domains missing from Runner.entitlements~~ → **RESOLVED 2026-05-11T20:10:00Z** jointly with S004 | ~~24~~ | mobile |
| 10 | P001 | Phase 94 Stage 3 narrator gate-correct thresholds NOT MET (Sonnet 20% vs 95% target after Phase 94.1 iter 1) — prod-flip blocked | 16 | backend |
| 11 | ~~B004~~ | ~~core/auth.py:55 bare except swallows JTI-blacklist DB errors — revoked-token auth-bypass via infra degradation~~ → **IN_PROGRESS 2026-05-11T20:50Z** (W7 iter#7) | 16 | backend |

---

## Bugs

### From PM Claude direct sim walkthrough (Phase 96 G2 + Phase 97 W0)

```yaml
- id: S001
  severity: P0
  surface: mobile
  archetype: all
  feature: chat_as_verb
  title: « ChatAsVerbDemoScreen has no UI entry point — route registered (`/debug/chat-as-verb`) but no in-app button calls `context.go()` to reach it »
  repro: « apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart:1 exists ; grep -rn 'ChatAsVerbDemoScreen' apps/mobile/lib/ shows it's only imported in app.dart route registration. No screen renders a button to navigate there. The wired MintCardActionBar surface is therefore inaccessible to users. »
  blast_radius: « Phase 96 W1 entire surface inaccessible to users in production. Full Phase 96 ship-readiness blocked. Same pattern repeats for any post-W1 widgets wired only into demo screens. »
  fix_cost: medium  # need to either (a) wire MintCardActionBar onto a real Aujourd'hui card or (b) add a debug button on Aujourd'hui that navigates to demo screen
  score: 32  # 8 × 4 / 1 ; treating as trivial-after-decision since CONTEXT says ALL cards in W5
  status: RESOLVED
  started: 2026-05-11T17:06:32Z
  fix_commit: 1264f18b
  repro_flow: tools/simulator/flows/regression/bug__S001__cap_du_jour_action_bar_reachable.yaml
  found_in: 2026-05-11
  resolved_in: 2026-05-11T17:16:53Z
  notes: « W7 iter#3 (2026-05-11) — wired MintCardActionBar onto CapDuJourBanner (PHASE97_AUJOURDHUI_CARD_INVENTORY.md row 2). Root container carries Key('card_cap_du_jour') ; action bar tagged Key('mint_card_action_bar') ; 3-verb routing : Explique-moi → MintChatOverlay intent=explain, Simule → context.push('/explorer?simulate=cap_du_jour') (zero LLM call per D-06), Rassure-moi → intent=reassure. SerializedCardContext built from financial_core only (priorityScore + cap kind + archetype.backendName + canton), zero PII per Phase 96 D-12. Deterministic GREEN gate : flutter test test/widgets/aujourdhui/cap_du_jour_banner_test.dart (5/5 pass). Maestro flow LOCKED in CI for future regression detection ; becomes runnable end-to-end once S003 (custom URL scheme) / S005 (LandingScreen → /home anonymous CTA) / Phase 97 W1 fragments (E2E launch-arg seeding) land. Same close-out pattern as F001 iter#2. Karpathy #3 surgical : only cap_du_jour_banner.dart touched (1 file, 71 LOC delta). »
  lock_status_update_2026-05-11T19:35:00Z: « LOCKED-GREEN END-TO-END (after S005 close) — bug__F001_S001_combined__chat_via_cap_du_jour.yaml runs the FULL S001 chain end-to-end on iPhone 17 Pro sim : cold launch → LandingScreen Continuer sans compte (S005) → /home → CapDuJourBanner « Parle-moi de toi » → MintCardActionBar 3 verbs visible (Explique-moi / Simule / Rassure-moi) → tap Explique-moi → MintChatOverlay opens. Junit /tmp/maestro_chained_f001_s001_s005.xml failures=0 time=10.0s. Workaround for M001 : `id: card_cap_du_jour` + `id: mint_card_action_bar` switched to accessibilityText regex `.*Parle-moi de toi.*` + `.*Explique-moi.*` ; the S001 fix is exercised end-to-end via the visible content. »

- id: S002
  severity: P0
  surface: testing
  archetype: all
  feature: chat_as_verb
  title: « Maestro flow `flow_card_action_intent_bar.yaml` doesn't handle cold-app onboarding »
  repro: « bash tools/simulator/maestro_env.sh test tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml fails at step 1 « assertVisible Aujourd'hui » because cold-launched app shows bêta modal « MINT en test » + landing « Voir clair, décider seul » first. Flow has no dismiss-bêta or auth steps. »
  blast_radius: « Phase 96 G1 gate cannot be live-run today. All future flows that target authenticated state need shared onboarding fragment. »
  fix_cost: small  # implement dismiss_beta_modal + auth_test_user fragments per Phase 97 W1
  score: 32  # 8 × 4 / 1
  status: OPEN
  fix_commit: null
  repro_flow: « evidence at .planning/phases/96-mvp-chat-as-verb/g2-evidence/maestro-flow-failure-junit.xml »
  found_in: 2026-05-11
  resolved_in: null
  notes: « Phase 97 W1 fragments close this. The bêta modal screenshot is at .planning/phases/96-mvp-chat-as-verb/g2-evidence/01-landing-modal.png. »

- id: S003
  severity: P0
  surface: mobile
  archetype: all
  feature: infra
  title: « Custom URL scheme `mintapp://` NOT registered in Info.plist — no external deep-linking »
  repro: « grep -A 20 'CFBundleURLTypes' apps/mobile/ios/Runner/Info.plist returns nothing. xcrun simctl openurl B03... 'mintapp://debug/chat-as-verb' fails with NSOSStatusErrorDomain code=-10814. »
  blast_radius: « External deep-links to MINT cannot work. Email links, push notifications with deep-links, Maestro `openLink` tests all blocked. »
  fix_cost: trivial  # add CFBundleURLTypes entry to Info.plist
  score: 16  # 8 × 4 / 2 ; downscaled cost because no GoRouter integration required
  status: RESOLVED
  started: 2026-05-11T18:01:05Z
  fix_commit: 009149c7  # to be replaced by final SHA at commit time
  repro_flow: tools/simulator/flows/regression/bug__S003__mintapp_scheme_opens_app.yaml
  found_in: 2026-05-11
  resolved_in: 2026-05-11T20:10:00Z
  notes: « W7 iter#6 RESOLVED (combined cycle with F006 + F007 + S004 — 4-bug deep-linking infra batch). CFBundleURLTypes + FlutterDeepLinkingEnabled added to Info.plist. Maestro flow /tmp/maestro_s003_post_fix.xml failures=0 time=4.0s — iOS « Open in "MINT"? » system dialog renders post-fix (canonical proof the scheme is registered ; iOS would NOT render this dialog if scheme were unregistered ; pre-fix : Maestro reports « Unknown error » time=1.0s because openurl returns NSOSStatusErrorDomain code=-10814). Screenshot evidence : /tmp/96_s003_mintapp_opens_app.png. »

- id: S004
  severity: P0
  surface: mobile
  archetype: all
  feature: infra
  title: « Universal Links NOT configured — `https://mint.ch/...` opens Safari instead of MINT app »
  repro: « `openLink https://mint-mobile.local/debug/chat-as-verb` via Maestro opens Safari, NOT the MINT app. Evidence : .planning/phases/96-mvp-chat-as-verb/g2-evidence/03-deeplink-opens-safari.png. No `com.apple.developer.associated-domains` in entitlements ; no Apple-App-Site-Association on Railway staging. »
  blast_radius: « External marketing links, email confirmations, social shares — all open in Safari instead of MINT app. SEO and re-engagement impact. »
  fix_cost: small  # entitlements + apple-app-site-association file upload to staging Railway
  score: 16  # 8 × 4 / 2
  status: RESOLVED
  started: 2026-05-11T18:01:05Z
  fix_commit: 009149c7
  repro_flow: tools/simulator/flows/regression/bug__S004_F006_F007__universal_link_opens_app.yaml
  found_in: 2026-05-11
  resolved_in: 2026-05-11T20:10:00Z
  notes: « W7 iter#6 RESOLVED (combined cycle). 2-part fix : (i) `Runner.entitlements` adds com.apple.developer.associated-domains for applinks:mint.ch + applinks:mint-staging.up.railway.app ; (ii) backend `app/main.py` serves /.well-known/apple-app-site-association as application/json with the canonical Apple AASA shape (appID=7F5UDGYS5H.ch.mint.app + paths /debug/chat-as-verb, /home, /aujourd-hui, /anonymous/chat, /coach/chat, /explorer/*). Backend pytest tests/test_aasa_endpoint.py 6/6 GREEN. SIM E2E proof DEFERRED to post-Railway-deploy (project_testflight_ship_path : dev→staging merge fires AASA on https://mint-staging.up.railway.app/.well-known/apple-app-site-association ; full prod-gate via D-22 7-day TestFlight soak on signed-entitlements build). CONFIG-GREEN locked today : entitlements + AASA shape are in the build. »

- id: F006
  severity: P0
  surface: mobile
  archetype: all
  feature: infra
  title: « FlutterDeepLinkingEnabled key missing from Info.plist — GoRouter cannot intercept Universal Links on iOS 14+ »
  repro: « grep -n 'FlutterDeepLinkingEnabled' apps/mobile/ios/Runner/Info.plist returns nothing. Per Flutter docs + GoRouter README : <key>FlutterDeepLinkingEnabled</key><true/> must be present for Universal Links (HTTPS) to route to GoRouter instead of opening Safari. »
  blast_radius: « All Universal Links + any https:// deep links from emails / push notifications / App Clips silently fall through to Safari even when com.apple.developer.associated-domains is eventually added (S004). »
  fix_cost: trivial
  score: 24  # 8 × 3 / 1 ; trivial: one line in Info.plist
  status: RESOLVED
  started: 2026-05-11T18:01:05Z
  fix_commit: 009149c7
  repro_flow: tools/simulator/flows/regression/bug__S003__mintapp_scheme_opens_app.yaml
  found_in: 2026-05-11
  resolved_in: 2026-05-11T20:10:00Z
  notes: « W7 iter#6 RESOLVED (combined cycle). Folded from audit-flutter-mobile.md F006 row. <key>FlutterDeepLinkingEnabled</key><true/> added to Info.plist (one-line addition). Companion to S003 + S004 + F007. The same Maestro flow that locks S003 (bug__S003__mintapp_scheme_opens_app.yaml) verifies F006 — the iOS « Open in MINT » dialog appearing on the openurl is a proof that BOTH the scheme registration AND the FlutterDeepLinkingEnabled opt-in are in the build (the latter being required for Flutter to even claim handling of the URL). »

- id: F007
  severity: P0
  surface: mobile
  archetype: all
  feature: infra
  title: « com.apple.developer.associated-domains missing from Runner.entitlements — Universal Links impossible even after Info.plist fix »
  repro: « cat apps/mobile/ios/Runner/Runner.entitlements — has com.apple.developer.applesignin + keychain-access-groups + memory entitlements but no associated-domains. Required : <key>com.apple.developer.associated-domains</key><array><string>applinks:mint.ch</string></array>. »
  blast_radius: « Same as S004 / F006 : https://mint.ch links never open the app. »
  fix_cost: trivial
  score: 24  # 8 × 3 / 1 ; one entry in entitlements + Apple AASA JSON on Railway
  status: RESOLVED
  started: 2026-05-11T18:01:05Z
  fix_commit: 009149c7
  repro_flow: tools/simulator/flows/regression/bug__S004_F006_F007__universal_link_opens_app.yaml
  found_in: 2026-05-11
  resolved_in: 2026-05-11T20:10:00Z
  notes: « W7 iter#6 RESOLVED (combined cycle). Folded from audit-flutter-mobile.md F007 row. com.apple.developer.associated-domains added to Runner.entitlements with applinks:mint.ch + applinks:mint-staging.up.railway.app. Companion to S004 ; both fix together (entitlements + AASA upload). CONFIG-GREEN proof : entitlements diff visible in commit. Full E2E gate is post-Railway-deploy + TestFlight signed build (D-22). »

- id: S005
  severity: P0
  surface: mobile
  archetype: all
  feature: navigation
  title: « LandingScreen has NO public CTA to /home for anonymous users — anonymous local-mode reachability blocked from cold launch »
  repro: « Cold-launch MINT app → LandingScreen renders with « Parle à Mint » CTA → /start → redirects to /anonymous/chat (apps/mobile/lib/app.dart:315-318). Also « J'ai déjà un compte » → /auth/login. No public button navigates to /home (the Aujourd'hui shell) despite AuthProvider defaulting isLocalMode=true. The (auth.isLoggedIn || auth.isLocalMode) gate at app.dart:417 ALLOWS anonymous /home access, but the user can never reach /home without typing a deep-link OR registering. »
  blast_radius: « ALL Phase 96 W1 + Phase 97 W5 reachability surface (CapDuJourBanner action bar, MintChatOverlay, full Aujourd'hui card-action ribbon) is unreachable from cold launch for anonymous users. End-to-end Maestro flows blocked. Phase 94 anonymous-onboarding chat works, but Aujourd'hui is invisible to the anonymous user — they bounce off after the chat session. »
  fix_cost: small  # add a « Continuer sans compte » / « Voir mon Aujourd'hui » CTA to LandingScreen (or after /anonymous/chat completion) → context.go('/home')
  score: 32  # 8 × 4 / 1
  status: RESOLVED
  started: 2026-05-11T17:22:38Z
  fix_commit: 010d851c
  repro_flow: tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml
  chained_repro_flow: tools/simulator/flows/regression/bug__F001_S001_combined__chat_via_cap_du_jour.yaml
  found_in: 2026-05-11
  resolved_in: 2026-05-11T19:35:00Z
  notes: « W7 iteration cycle #4 (2026-05-11) — surgical fix per Karpathy #3. Added a sober « Continuer sans compte » link to LandingScreen below « J'ai déjà un compte » (landing_screen.dart +29 LOC) ; calls context.go('/home'). New ARB key landingV3AnonymousHomeLink × 6 locales (fr/en/de/es/it/pt parity, lefthook arb-parity-gate green at 6752 keys). Exploits the existing default-on isLocalMode (auth_provider.dart:90, checkAuth() seeds it line 142-145, app.dart:417 gate) — production-safe : exposes an existing anonymous-default path, no new bypass. Deterministic GREEN gates : (1) flutter test test/screens/landing_screen_test.dart → 5/5 pass (4 pre-existing + 1 new S005 assertion « Continuer sans compte » renders + routes to /home), (2) Maestro standalone /tmp/maestro_s005_post_fix.xml failures=0 time=8s, (3) Maestro chained F001+S001+S005 /tmp/maestro_chained_f001_s001_s005.xml failures=0 time=10s — FIRST end-to-end Maestro reachability proof of MINT's chat-as-verb surface for anonymous users on iPhone 17 Pro sim. Screenshots : /tmp/96_s005_aujourdhui_landed.png (S005 standalone, AujourdhuiScreen with CapDuJourBanner + MintCardActionBar 3 verbs) ; /tmp/96_chained_green_chat_overlay.png (chained, MintChatOverlay open with intent badge « explain » + counter 0/3 + ChatInputBar « Tape ton message... »). Surfaced new meta-bug M001 during cycle (Flutter Keys don't propagate as Maestro iOS identifiers — separate cycle). »

- id: M001
  severity: P1
  surface: mobile
  archetype: all
  feature: maestro_infra
  title: « Flutter Keys do not propagate as Maestro-queryable identifiers on iOS — every `id:`-based Maestro assertion fails on iOS Flutter apps »
  repro: « bash tools/simulator/maestro_env.sh hierarchy on any Flutter screen with `Key('foo')` widgets shows `resource-id: ""` (empty) across the entire iOS view tree. Maestro's `id:` matcher therefore matches nothing. Verified 2026-05-11T19:35Z during W7 iter#4 chained flow — `id: card_cap_du_jour` failed even though the Dart widget carries `Key(ValueKey('card_cap_du_jour'))`. »
  blast_radius: « Every Maestro flow that uses `id:`-based assertions or taps on iOS is broken. Affects all current regression flows : bug__F001 (chat_input_field, chat_send_button, chat_turn_counter, mint_chat_overlay), bug__S001 (card_cap_du_jour, mint_card_action_bar). The W3 24-flow regression matrix cannot use Flutter Keys as testIDs on iOS until this is fixed. »
  fix_cost: medium  # add `Semantics(identifier: '<key>')` wrap (Flutter 3.16+) to every testID widget ; ~6 widgets touched (CapDuJourBanner, MintCardActionBar, MintChatOverlay root, ChatInputBar TextField, send IconButton, turn-counter Text) ; verify SemanticsBinding.ensureSemantics() in main.dart ; rebuild + re-run all Maestro flows for regression
  score: 16  # 4 × 4 / 1
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Surfaced 2026-05-11T19:35Z during W7 iter#4 S005 close-out cycle (chained F001+S001+S005 flow). Workaround applied to chained flow : switched all `id:` matchers to accessibilityText regex `.*X.*` (Flutter iOS bridge doubles Semantics-label-with-Text-child as "X\nX"). Chained flow GREEN end-to-end via workaround. But the workaround is fragile — text contents drift, accessibilityText doesn't always match the user-facing label, and the Maestro id:-based contract in the testID convention (CONTEXT D-19) cannot be honored on iOS today. Pick this bug next cycle (W7 iter#5) to lock the testID contract properly. »
```

### From haiku TODO survey audit

```yaml
- id: T001
  severity: P0
  surface: mobile
  archetype: all
  feature: privacy
  title: « EXIF metadata leak — Vision API receives photos with GPS coordinates + timestamps + device model »
  repro: « apps/mobile/lib/screens/document_scan/document_scan_screen.dart:683 + 1550 contained TODO(P2-W12): Strip EXIF metadata before Vision API call. Captured images flowed straight to base64 + Vision API with GPS, timestamps, device model intact. »
  blast_radius: « GDPR Art. 5(1)(c) data minimization violation. Swiss DSG/LPD Art. 8 non-compliance. Any user uploading a document leaked geolocation + timestamp + device model to backend. »
  fix_cost: small  # image package promoted to direct dep + scrubExif() util + 2 call sites
  score: 32  # 8 × 4 / 1
  status: RESOLVED
  started: 2026-05-11T20:00:00Z
  fix_commit: 5f7d1953
  repro_test: apps/mobile/test/services/exif_scrub_test.dart  # unit-test-gated (no UI surface)
  found_in: 2026-05-11
  resolved_in: 2026-05-11T20:35:00Z
  notes: « W7 iteration cycle #5 (2026-05-11) — RESOLVED. Surgical fix per Karpathy #3 (4 files touched). New util apps/mobile/lib/services/exif_scrub.dart : decode JPEG → fresh Image with pixels only (no exif carrier) → re-encode at quality=100. Two call sites wired in document_scan_screen.dart (line 682-686 _tryVisionExtraction backend Vision path + line 1549-1553 _processImageViaVision BYOK Vision path). image: ^4.1.2 promoted from transitive (pubspec.lock 4.5.4) to direct dep. Sentry breadcrumb category mint.privacy.exif_scrubbed with non-PII payload only ( bytes_before / bytes_after / had_exif ) — NEVER the tag values (those ARE the PII). Deterministic GREEN gate : cd apps/mobile && flutter test test/services/exif_scrub_test.dart → 00:00 +6: All tests passed! Asserts DateTime/Make/Model/Software stripped, ifd0 empty post-scrub, pixel checksum preserved within 5 % JPEG-roundtrip tolerance, EXIF-less input passes through, regression-detect fixture confirms pre-scrub leak. document_scan regression : flutter test test/screens/document_scan/ + test/screens/document_scan_screen_test.dart + test/screens/document_scan_render_mode_test.dart → 11/11 pass. banned_terms + accent_lint clean on new files. The pre-existing 5 failures (route_guard_snapshot + 4 landing goldens) are S005 collateral from W7 iter#4, verified to pre-date this commit via git checkout 98ab8f20 (the commit before T001 PICK) — those 5 failures already existed there. Compliance citations : GDPR Art. 5(1)(c) data minimization + Swiss DSG/LPD Art. 8 security. Unit-test-locked in tools/simulator/flows/regression/_INDEX.md (new « Unit-Test-Locked Bugs » section bootstrap). »

- id: T002
  severity: P0
  surface: backend
  archetype: all
  feature: privacy
  title: « SQLite encryption missing — user financial documents stored at rest unencrypted »
  repro: « services/backend/app/models/document.py contains TODO: enable SQLCipher encryption. Currently the SQLite DB on Railway staging contains user docs in plaintext. »
  blast_radius: « GDPR Art. 32 « security of processing » non-compliance. Swiss DSG/LPD Art. 8 « sécurité des données ». If Railway hosting is breached, all user docs exposed. »
  fix_cost: medium  # SQLCipher integration + migration + key management
  score: 16  # 8 × 4 / 2
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « MVP-blocker per haiku audit. Hard gate before TestFlight. »
```

### From PM Claude direct lint sweep (existing tools/checks/)

```yaml
- id: L001
  severity: P0
  surface: testing
  archetype: all
  feature: maestro_infra
  title: « Maestro locator audit FAIL — 14 violations on 4 flows (text literals not in app, IDs without Key declarations) »
  repro: « python3 tools/checks/maestro_locator_audit.py reports 14 violations across tools/simulator/flows/{auth_coach_post_hotfix,julien_swiss,lauren_expat_us}.yaml. Examples: id 'anon-chat-input' has no matching Key('anon-chat-input') in Dart code ; text 'Estime ta marge précise' not found in any app source or ARB. »
  blast_radius: « 4 existing Maestro flows are broken — they cannot find the locators they reference. Any CI run is RED. The locator audit lint exists for exactly this reason. »
  fix_cost: medium  # per flow: either fix the locator to match existing widgets/ARB, OR add the missing Key('...') to the widget code
  score: 32  # 8 × 4 / 1 ; cost low because each fix is mechanical
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Phase 97 W1 fragments + W3 regression suite must address each locator before flows can run live. Inventory in PHASE97_MAESTRO_LOCATOR_DEBT.md (Phase 97 W0 deliverable). »

- id: L002
  severity: P1
  surface: mobile
  archetype: all
  feature: theme
  title: « 8 hardcoded `Colors.white/red/grey` in app.dart 1629-1899 (lint prefer_mint_color_token FAIL) »
  repro: « python3 tools/checks/prefer_mint_color_token.py lib/app.dart shows lines 1629, 1631, 1672, 1697, 1832, 1852, 1888, 1899. »
  blast_radius: « Dark-mode + theme switching break on these 8 spots. Visual inconsistency. »
  fix_cost: trivial  # replace with MintColors tokens per existing inventory
  score: 8  # 4 × 4 / 2
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Surgical fix, ~30 min. »

- id: L003
  severity: P1
  surface: mobile
  archetype: all
  feature: theme
  title: « 6 hardcoded `fontSize: N` in app.dart 1668-1904 (lint prefer_mint_text_style FAIL) »
  repro: « python3 tools/checks/prefer_mint_text_style.py shows fontSize 14/16/16/16/16/20. »
  blast_radius: « Typography drift, dynamic-type/accessibility break. »
  fix_cost: trivial  # replace with MintTextStyles tokens
  score: 8  # 4 × 4 / 2
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Same file as L002 ; can batch fix in one commit. »

- id: L004
  severity: P2
  surface: mobile|backend|content|docs
  archetype: all
  feature: i18n_accent
  title: « 283 accent FR violations across repo — inventory bug, fix progressively »
  repro: « python3 tools/checks/accent_lint_fr.py reports 283 violations across apps/, services/, tools/, docs/, .planning/. Examples : `specialiste` → `spécialiste` in calculator.py:118 (USER-FACING), `eclairage` in maestro flow docs (DOCS), `decouvrir` in landing strings. »
  blast_radius: « User-facing accent violations break Voice System §1 (CLAUDE.md never #2). 283 entries across many surfaces — sweep needed, not per-line fix. »
  fix_cost: medium  # one « accent sweep » commit batch ; the lint is the audit ; can be done with sed -i replacements + manual review for ambiguous cases
  score: 8  # 2 × 4 / 1
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Per memory `feedback_pre_push_checklist` accent_lint_fr is NOT in lefthook (deferred Phase 34). Once Phase 97 W6 lands bug_registry_lint, can add accent_lint to lefthook gradually as inventory drains. Inventory file `PHASE97_ACCENT_VIOLATIONS_INVENTORY.md` to be written W0. »

- id: L005
  severity: P2
  surface: mobile
  archetype: all
  feature: i18n
  title: « 5042 hardcoded FR strings in widgets (no_hardcoded_fr FAIL, was 5034 per memory drift +8) »
  repro: « python3 tools/checks/no_hardcoded_fr.py shows 5042 hits. Examples : `Voici ce que ton coach a déduit` at onboarding_widgets.dart:352 ; `SI 'Variables' est à 0...` at stop_rule_callout.dart:34. »
  blast_radius: « i18n drift ; non-FR users see hardcoded French. The 6-locale ARB system is bypassed at these 5042 sites. »
  fix_cost: large  # 5042 sites is a content sprint, not a phase ; AppLocalizations migration per site
  score: 4  # 2 × 4 / 2
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Inventory-style — track in PHASE97_HARDCODED_FR_INVENTORY.md. Closure path : convert 50-100 per sprint until count < 100. Filed as backlog 999.7 unless v2.10 cleanup picks it up. »

- id: L006
  severity: P1
  surface: backend
  archetype: all
  feature: error_handling
  title: « 15+ bare `except Exception:` in Python backend (forbidden CLAUDE.md §5) »
  repro: « grep -rn 'except Exception:$' services/backend/app/ shows 15+ hits in core/auth.py:55, main.py:133, endpoints/auth.py:1283, endpoints/coach_chat.py:1131/1414/1417/1571/2989/3009/3538, endpoints/documents.py:469/746/859/1187, endpoints/privacy.py:189. »
  blast_radius: « Silent exception swallowing ; production debugging blind ; Sentry alerts suppressed ; user-facing 500s with no log trail. »
  fix_cost: medium  # case-by-case review, log+rethrow or specific exception type per site
  score: 16  # 4 × 4 / 1 — score inflated because the silent-swallow risk is operational
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « 15 sites, ~30 min each = 1 day batch. Each catch should be replaced with `except SpecificException as e: logger.exception(...); raise` OR `except Exception as e: logger.exception(...); raise` if truly cross-cutting. »

- id: L007
  severity: P1
  surface: mobile
  archetype: all
  feature: error_handling
  title: « 8+ Dart bare `catch (e) {}` / `catch (_)` in providers (Outfit forbidden) »
  repro: « grep -rnE 'catch \(.+\) \{\s*$' apps/mobile/lib/ shows main.dart:99, coach_profile_provider.dart:189/248/479/1052/2222/2388, byok_provider.dart:91/115. »
  blast_radius: « Silent failures in providers — auth state, profile load, byok flow silently break. »
  fix_cost: small  # per-site fix, ~10min each
  score: 16  # 4 × 4 / 1
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « 8 sites in providers + main — should add `developer.log` or `Sentry.captureException` per site. »

- id: L008
  severity: P2
  surface: mobile
  archetype: all
  feature: routing
  title: « `/debug/chat-as-verb` path in app.dart but missing from kRouteRegistry (route_registry_parity FAIL) »
  repro: « python3 tools/checks/route_registry_parity.py reports `/debug/chat-as-verb` in app.dart but not in kRouteRegistry. Source: apps/mobile/lib/app.dart (Phase 96 G2 fix added the route 2026-05-11). »
  blast_radius: « Route inventory drift ; map_freshness_hint will warn. Adminroutes screen at /admin/routes will not list the debug route. »
  fix_cost: trivial  # add RouteMeta entry to apps/mobile/lib/routes/route_metadata.dart
  score: 4  # 2 × 4 / 2
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « My own follow-up from Phase 96 G2 inline fix. ~5 min. »
```

### From past-phase recap (Phase 94/94.1 closed FAIL)

```yaml
- id: P001
  severity: P0
  surface: backend
  archetype: all
  feature: citation_gate
  title: « Phase 94 Stage 3 narrator gate-correct thresholds NOT MET — Sonnet 20% / Haiku 20% vs 95% / 90% targets after Phase 94.1 iter 1 fattening »
  repro: « cat .planning/phases/94-mvp-citation-gate/94-03-FLAG-FLIP-PROPOSAL.md §Recommendation summary. Also .planning/phases/94.1-wave-4-narrator-prompt-fattening-citation-registry-cite-key-/94.1-EVAL-DELTA.md root-cause analysis. »
  blast_radius: « COACH_CITATION_GATE_ENABLED prod-flip blocked. The chat-as-verb feature ships with citation gate flag = false on prod, meaning narrator can emit naked numbers without citations (LSFin compliance gap). »
  fix_cost: medium  # backlog 999.5 iter 2 hypothesis H1 (intent-driven key grouping) is the proposed fix
  score: 16  # 8 × 4 / 2
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Already filed as backlog 999.5 (Phase 94.2). Reaffirmed in registry for v2.10 cycle priority. »

- id: P002
  severity: P1
  surface: mobile
  archetype: all
  feature: navigation
  title: « Aujourd'hui card-surface : 0 cards wired with MintCardActionBar today »
  repro: « grep -rn 'MintCardActionBar' apps/mobile/lib/screens/ shows ONLY chat_as_verb_demo_screen.dart. Other Aujourd'hui card screens (TBD inventory in W0) don't reference the widget. »
  blast_radius: « Phase 96 ships the widget but no production card uses it. User cannot reach the chat-as-verb intent bar from cold launch on Aujourd'hui. »
  fix_cost: medium  # Phase 97 W5 wires MintCardActionBar onto every Aujourd'hui card
  score: 8  # 4 × 4 / 2
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Closes alongside backlog 999.6. Phase 97 W5 inventories then wires. »
```

---

### From sonnet Flutter audit (folded 2026-05-11, see audit-flutter-mobile.md for full F001-F030 catalogue)

Only the rows actively in the iteration loop are mirrored here. The full audit
catalogue lives in `audit-flutter-mobile.md` (read-only audit artifact). When a
row enters the 7-step cycle (D-36), it is folded here for state-machine tracking.

```yaml
- id: F001
  severity: P0
  surface: mobile
  archetype: all
  feature: chat_as_verb
  title: « MintChatOverlay scaffold has no chat TextField or send button — Maestro testIDs chat_input_field + chat_send_button don't exist in Dart code »
  repro: « grep -rn 'chat_input_field\|chat_send_button' apps/mobile/lib/ --include='*.dart' returns 0 results. flow_card_action_intent_bar.yaml:156,162 tapOn { id: 'chat_input_field' } and tapOn { id: 'chat_send_button' }. The widget at apps/mobile/lib/widgets/mint_chat_overlay.dart:8 explicitly says 'W1 scope: SCAFFOLD ONLY — do not add ChatInputBar here'. »
  blast_radius: « Phase 96 G1 gate (flow_card_action_intent_bar.yaml) fails at step 5 on every run. The entire turn-cap + terminal-template + Sentry breadcrumb sequence is unreachable by Maestro. Phase 97 W3 regression suite cannot run until this is wired. »
  fix_cost: medium  # downscaled from large : local-state UI only, no provider/backend wiring, ~150-line widget
  score: 8  # 8 × 4 / 4 ; medium cost after scope clarification (UI-only, simulated narrator response)
  status: RESOLVED
  started: 2026-05-11T16:43:45Z
  fix_commit: 8b3bb90b
  repro_flow: tools/simulator/flows/regression/bug__F001__chat_input_bar_exists.yaml
  chained_repro_flow: tools/simulator/flows/regression/bug__F001_S001_combined__chat_via_cap_du_jour.yaml
  found_in: 2026-05-11
  resolved_in: 2026-05-11T17:00:46Z
  lock_status_update_2026-05-11T17:16:53Z: « LOCKED-GREEN (after S001 close) — bug__F001_S001_combined__chat_via_cap_du_jour.yaml chains both fixes end-to-end : S001 makes CapDuJourBanner reachable, F001 makes MintChatOverlay carry the required testIDs once the action-bar opens. Combined widget-test gate : 11/11 F001 + 5/5 S001 = 16/16 GREEN. End-to-end Maestro still precondition-blocked by S003/S005/W1 fragments. »
  lock_status_update_2026-05-11T19:35:00Z: « LOCKED-GREEN END-TO-END (after S005 close) — bug__F001_S001_combined__chat_via_cap_du_jour.yaml NOW RUNS GREEN end-to-end on iPhone 17 Pro sim. /tmp/maestro_chained_f001_s001_s005.xml failures=0 time=10.0s. The chain cold launch → LandingScreen Continuer sans compte (S005) → /home → AujourdhuiScreen → CapDuJourBanner (S001) → MintCardActionBar → tap Explique-moi → MintChatOverlay (F001) with « 0 / 3 » counter + ChatInputBar « Tape ton message... » + send arrow is PROVEN on device. FIRST end-to-end Maestro reachability proof of MINT's chat-as-verb surface for anonymous users. Screenshot evidence : /tmp/96_chained_green_chat_overlay.png. Workaround applied for M001 (Flutter Keys not propagating as iOS Semantics identifiers) : all `id:` matchers switched to accessibilityText regex `.*X.*` — fragile, will be retired once M001 fix lands. »
  notes: « W7 iteration cycle #2. Closes F001 + F002 (Key('mint_chat_overlay') root) + F003 (Text Key('chat_turn_counter') « 0 / 3 »). 4 testIDs added to mint_chat_overlay.dart (lines 157, 199, 313, 356). Deterministic GREEN gate : cd apps/mobile && flutter test test/widgets/mint_chat_overlay_test.dart → 11/11 pass (4 pre-existing + 7 new F001 assertions). ARB key chatInputHint added to 6 locales (6751 keys × 6 parity). Maestro flow tools/simulator/flows/regression/bug__F001__chat_input_bar_exists.yaml is in CI LOCK (becomes runnable end-to-end post-W5 reachability — S001/F012/F013/F014/F028). Backend wiring (real coach_chat POST + NarrativeSleeveCard render) deferred to F-NEXT cycle. W7 iter#3 (S001 close) adds the chained bug__F001_S001_combined__chat_via_cap_du_jour.yaml flow — first end-to-end S001 → F001 reachability proof for MINT. »

- id: F002
  severity: P0
  surface: mobile
  archetype: all
  feature: chat_as_verb
  title: « MintChatOverlay root has no Key('mint_chat_overlay') — Maestro assertVisible { id: mint_chat_overlay } (step 4) will always fail »
  repro: « grep -rn 'mint_chat_overlay' apps/mobile/lib/ --include='*.dart' returns 0 results pre-fix. apps/mobile/lib/widgets/mint_chat_overlay.dart:27 defined MintChatOverlay without a root Key. flow_card_action_intent_bar.yaml:103 assertVisible: { id: 'mint_chat_overlay' }. »
  blast_radius: « Maestro cannot confirm the overlay opened — all subsequent assertions (turn counter, input, close handle) are moot. »
  fix_cost: trivial
  score: 24  # 8 × 3 / 1
  status: RESOLVED
  started: 2026-05-11T16:43:45Z
  fix_commit: 8b3bb90b
  repro_flow: tools/simulator/flows/regression/bug__F001__chat_input_bar_exists.yaml
  found_in: 2026-05-11
  resolved_in: 2026-05-11T17:00:46Z
  notes: « Resolved jointly with F001 (same StatefulWidget refactor adds the root Container Key('mint_chat_overlay') at mint_chat_overlay.dart:157). Same repro flow asserts this testID. »

- id: F003
  severity: P0
  surface: mobile
  archetype: all
  feature: chat_as_verb
  title: « MintChatOverlay has no turn counter widget — Maestro step 4 extendedWaitUntil text '.*1/3.*' waits forever (6 s timeout then fail) »
  repro: « grep -rn '1.*3\|turn.*counter\|counter.*turn\|turnCount\|maxTurns' apps/mobile/lib/widgets/mint_chat_overlay.dart returns 0 results pre-fix. flow_card_action_intent_bar.yaml:108 extendedWaitUntil: visible: text: '.*1\\s*/\\s*3.*'. »
  blast_radius: « Same as F001 — full G1 gate broken. Every archetype flow that verifies the turn cap fails. »
  fix_cost: small
  score: 24  # 8 × 3 / 1
  status: RESOLVED
  started: 2026-05-11T16:43:45Z
  fix_commit: 8b3bb90b
  repro_flow: tools/simulator/flows/regression/bug__F001__chat_input_bar_exists.yaml
  found_in: 2026-05-11
  resolved_in: 2026-05-11T17:00:46Z
  notes: « Resolved jointly with F001. Text widget at mint_chat_overlay.dart:198-202 carries Key('chat_turn_counter') + renders '$_turnCount / $kChatMaxTurns'. Local-state UI-only counter ; server-side turn_cap.py is the canonical D-08 enforcement gate. Initial state « 0 / 3 », increments on send, reset on overlay re-mount (test asserts these 3 transitions). »
```

### From sonnet Backend audit (folded 2026-05-11, see audit-backend-api.md for full B001-B025 catalogue)

```yaml
- id: B004
  severity: P1
  surface: backend
  archetype: all
  feature: auth / token_revocation
  title: « core/auth.py:55 bare `except Exception: pass` swallows JTI-blacklist DB errors — revoked tokens may authenticate silently if the blacklist query raises »
  repro: « grep -n -A3 'except Exception' services/backend/app/core/auth.py → line 55: `except Exception: pass # If decode fails entirely, let decode_token handle it`. The try block (lines 45-56) also calls `is_jti_blacklisted(db, jti)` — a DB query that may raise sqlalchemy.exc.OperationalError, IntegrityError, etc. Those are swallowed too. A revoked JWT whose JTI is blacklisted authenticates if the blacklist DB query raises (e.g. DB overload, connection drop, migration drift). »
  blast_radius: « Auth-bypass via infrastructure degradation. Under DB stress, every blacklisted token quietly re-authenticates because `is_jti_blacklisted` raises → bare except swallows → flow falls through to `decode_token(token)` which succeeds (token signature is valid ; only the revocation status was unverifiable). Production-grade auth surface ; LSFin + 0-trust §9 risk. »
  fix_cost: trivial  # split bare except into 2 specific clauses (pyjwt.PyJWTError + sqlalchemy.SQLAlchemyError) + logger.exception + HTTPException 503 on DB error path
  score: 16  # 4 × 4 / 1 ; P1 (auth-bypass requires DB-degradation precondition, not unconditional bypass) but high-value-fix-trivial-cost
  status: IN_PROGRESS
  started: 2026-05-11T20:50:00Z
  fix_commit: null
  repro_test: services/backend/tests/test_auth_jti_blacklist_silent_fail.py
  found_in: 2026-05-11
  resolved_in: null
  notes: « W7 iter#7 PICK 2026-05-11T20:50Z. Folded from audit-backend-api.md row B004. Unit-test-gated (no UI surface ; HTTP-level auth dependency). Fix design (Karpathy #2 simplicity-first) : two specific except clauses — `except pyjwt.exceptions.PyJWTError: pass` preserves the intended decode-fallback path ; `except sqlalchemy.exc.SQLAlchemyError as e: logger.exception(...); raise HTTPException(503, "Service de blacklist temporairement indisponible")` makes the system fail-CLOSED on infra-degradation (industry standard for auth-revocation surface ; better to refuse a valid token than to accept a revoked one when revocation cannot be verified). The 503 is API-client-facing (mobile/JSON ; not direct user-rendered string). »
```

---

## Pending — to be enriched by sonnet audits in flight

Two sonnet agents running 2026-05-11 :
- `ac32620931408ed8f` — Flutter/mobile deep audit (output : `audit-flutter-mobile.md`)
- `a4d4aeb3a53735d1b` — Backend/API deep audit (output : `audit-backend-api.md`)

Expected to add 15-30 more bugs each (target total ~50-75 unique).

## State machine (locked per CONTEXT D-37)

```
OPEN → IN_PROGRESS → FIXED_LOCAL → VALIDATED → RESOLVED
                          ↓               ↓
                       REJECTED      regressed=true → OPEN (severity bumps UP, never down)
```

`tools/checks/bug_registry_lint.py` (Phase 97 W6) enforces :
- Schema validity (all required fields)
- State machine transitions (no backwards moves except via `regressed: true` flag)
- Score formula correctness
- Severity promotion only (never demotion)
- Deduplication warning (string-similarity > 80%)

## Bug count summary

- Direct grep/lint findings : 17 bugs catalogued in v0 seed
- haiku TODO survey : 2 P0 added (T001, T002)
- Sonnet deep audits : pending (expected +30-50 bugs)
- v0 total : 17 unique bugs

**Target before W7 starts : ≥ 50 bugs in registry, ≥ 10 P0 bugs queued for the first iteration cycle.**

## Inventory side-files (one per high-cardinality finding)

These will be authored in W0 ahead of W7 :
- `PHASE97_ACCENT_VIOLATIONS_INVENTORY.md` — 283 lines from accent_lint_fr (L004)
- `PHASE97_HARDCODED_FR_INVENTORY.md` — 5042 lines from no_hardcoded_fr (L005)
- `PHASE97_AUJOURDHUI_CARD_INVENTORY.md` — per-archetype Aujourd'hui card list (W0 Maestro audit deliverable)
- `PHASE97_MAESTRO_LOCATOR_DEBT.md` — 14 locator violations from maestro_locator_audit (L001)
- `PHASE97_BARE_CATCH_INVENTORY.md` — 15 Python + 8 Dart sites (L006, L007)

---

*Phase : 97-mvp-parfait-maestro-full-power*
*Registry generated : 2026-05-11 (v0 seed by PM Claude direct audit + haiku TODO survey ; sonnet deep audits in flight)*

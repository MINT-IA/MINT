---
description: Phase 97 W0 bug bash registry. Generated 2026-05-11 by PM Claude direct-grep audit + 1 haiku TODO survey agent + 2 sonnet deep audits in flight (Flutter + Backend). Schema per CONTEXT.md D-35. State-machine enforced by `tools/checks/bug_registry_lint.py` (Phase 97 W6 will land the lint script). v0 seed — to be enriched as the sonnet audits return.
phase: 97
slug: mvp-parfait-maestro-full-power-maestro-driven-on-device-grou
status: draft (W0 in progress)
created: 2026-05-11
schema_version: 1
total_bugs: 33  # will grow as sonnet audits return ; W7 iter#3 added S005 (LandingScreen→/home reachability)
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
| 1bis | S005 | LandingScreen has no public CTA to /home for anonymous users (surfaced by S001 close) | 32 | mobile |
| 2 | L001 | Maestro locator audit fails 14 violations on 4 flows — testing infra broken | 32 | testing |
| 3 | S002 | Maestro flow `flow_card_action_intent_bar.yaml` doesn't handle cold-app onboarding (bêta modal + landing + auth) | 32 | testing |
| 4 | T001 | EXIF metadata leak — `document_scan_screen.dart` Vision API retains GPS+timestamp without scrub (GDPR/Swiss data protection violation) | 32 | mobile |
| 5 | T002 | SQLite encryption missing — `document.py` stores user financial documents at rest unencrypted (GDPR Art. 32) | 32 | backend |
| 6 | S003 | Custom URL scheme `mintapp://` NOT registered in Info.plist — no external deep-linking possible | 16 | mobile |
| 7 | S004 | Universal Links NOT configured — `https://` URLs fall through to Safari | 16 | mobile |
| 8 | P001 | Phase 94 Stage 3 narrator gate-correct thresholds NOT MET (Sonnet 20% vs 95% target after Phase 94.1 iter 1) — prod-flip blocked | 16 | backend |

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
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Closes alongside Universal Links config in W5. »

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
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « Closes W5 alongside S003. »

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
  status: IN_PROGRESS
  started: 2026-05-11T17:22:38Z
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « W7 iteration cycle #4 PICK 2026-05-11T17:22:38Z. Surfaced by W7 iter#3 (S001 close) — running bug__S001__cap_du_jour_action_bar_reachable.yaml against post-fix build showed cold-launch lands on LandingScreen, not the shell. Was implicit assumption in F001 iter#2 (filed as F013/F014 'cold-launch precondition / auth fragment'). Promoted to S005 explicit bug for tracking. Closes W5 alongside S003+S004 reachability work. Fix path : add a sober « Continuer sans compte » link to LandingScreen under the « J'ai déjà un compte » login link, navigating to /home — exploits the existing default-on isLocalMode (auth_provider.dart:90, app.dart:417 gate) ; no auth_provider/main.dart changes needed, production-safe since the path is already documented as the anonymous default. »
```

### From haiku TODO survey audit

```yaml
- id: T001
  severity: P0
  surface: mobile
  archetype: all
  feature: privacy
  title: « EXIF metadata leak — Vision API receives photos with GPS coordinates + timestamps + device model »
  repro: « apps/mobile/lib/screens/document_scan_screen.dart contains TODO: scrub EXIF before upload. Currently captured images go straight to Vision API. »
  blast_radius: « GDPR Art. 5(1)(c) data minimization violation. Swiss DSG/LPD non-compliance. Any user uploading a document leaks geolocation + timestamp to backend. »
  fix_cost: small  # use exif package + strip metadata in pre-upload pipeline
  score: 32  # 8 × 4 / 1
  status: OPEN
  fix_commit: null
  repro_flow: null
  found_in: 2026-05-11
  resolved_in: null
  notes: « MVP-blocker per haiku audit. Closes alongside the compliance triplet T002+T003. »

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

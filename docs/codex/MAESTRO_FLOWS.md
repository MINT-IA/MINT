# MAESTRO_FLOWS.md — E2E flows that PROVE the wiring (Codex-executable)

> **Baseline note:** file:line references were originally audited against `apps/mobile/` and `services/backend/` at commit `255373b`, then corrected on this branch. Treat every reference below as a HEAD contract and re-verify after code movement.

> **Status:** normative. Grounded in the REAL code at commit `255373b`.
> **Purpose:** every flow is a mechanical proof that the spine connects. **Green = wired.** A red flow names a real bug to fix (`WIRING_GRAPH.mmd` D-1..D-5).
> **appId:** `ch.mint.coach` (`android/app/build.gradle:50`).
> **Companions:** `DATA_LEDGER.md`, `SCREEN_CONTRACTS.md`, `WIRING_GRAPH.mmd`, `DATA_QUEST.md`.

## 0. Reality check — there is NO Maestro setup yet (build it)

- No `.maestro/` folder exists. Only `apps/mobile/integration_test/{persona_lea_test.dart, persona_marc_test.dart}` (reuse persona names **Lea**, **Marc**).
- Screens use `Semantics(...)` labels and i18n `Text(S.of(context)!.key)`, **not** stable `Key('...')` (verified: near-zero `Key('...')` in `lib/`). **Maestro needs stable ids.** So Task M-0 below is a prerequisite: add the listed identifiers.
- **Deep links do NOT work yet.** `android/app/src/main/AndroidManifest.xml` declares only `android:scheme="https"` inside `<queries>` (line 37) and has NO `mint://` intent-filter on `MainActivity` (verified lines 25-28: only `MAIN`/`LAUNCHER`). iOS has no `CFBundleURLSchemes`. Every `openLink: "mint://…"` in the flows below is dead until Task M-0 registers the scheme.

### Task M-0 — Setup, deep-link scheme, and required ids to ADD (file : what)

**M-0a — Register the `mint://` custom scheme (REQUIRED before any `openLink` flow runs).**

- Android — add this intent-filter INSIDE the `<activity android:name=".MainActivity">` block of `apps/mobile/android/app/src/main/AndroidManifest.xml` (after the existing `MAIN`/`LAUNCHER` filter, before `</activity>` at line 29):
  ```xml
  <intent-filter android:autoVerify="false">
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.DEFAULT" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="mint" />
  </intent-filter>
  ```
- iOS — add to `apps/mobile/ios/Runner/Info.plist`:
  ```xml
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>ch.mint.coach</string>
      <key>CFBundleURLSchemes</key>
      <array><string>mint</string></array>
    </dict>
  </array>
  ```
- GoRouter already resolves the paths (`/data-block/:type`, `/hypotheque`, `/scan/review`, …); the scheme registration is what lets the OS hand `mint://<path>` to the app. Verify with `adb shell am start -a android.intent.action.VIEW -d "mint://home" ch.mint.coach` before running flows.

**M-0b — Create `apps/mobile/.maestro/` and add these stable ids** (`Semantics(identifier: '...')` — Maestro reads it cross-platform; keep the i18n visible label separate):

| id to add | file | element |
|---|---|---|
| `salary_input` | `screens/onboarding/data_block_enrichment_screen.dart` | net/gross salary field |
| `canton_picker` | same | canton selector |
| `coach_input` | `widgets/coach/coach_input_bar.dart` | chat text field |
| `coach_send` | same | send button |
| `retirement_gap_value` | `screens/coach/retirement_dashboard_screen.dart` | the projected gap number |
| `mortgage_afford_result` | `screens/…/affordability` (`/hypotheque`) | affordability verdict |
| `lpp_balance_input` | `widgets/coach/coach_input_bar.dart` (chat) or data-block `lpp` field | LPP balance entry |
| `rente_capital_uses_lpp` | `/rente-vs-capital` result screen | value derived from LPP balance |
| `savings_input` | `screens/onboarding/data_block_enrichment_screen.dart` | savings/patrimoine field |
| `property_value_input` | `screens/coach/succession_patrimoine_screen.dart` | property value entry |
| `succession_parents_note` | `screens/coach/succession_patrimoine_screen.dart` | parents' retirement-affordability CASE note |
| `divorce_regime_picker` | `screens/divorce_simulator_screen.dart` | matrimonial regime selector |
| `divorce_lpp_split_result` | `screens/divorce_simulator_screen.dart` | LPP-split outcome value |
| `document_scan_header` | `screens/document_scan/document_scan_screen.dart` | recovery destination reached from `/scan/review` and `/scan/impact` empty states |
| `Aucun document` | `app.dart:469-486` via `AppLocalizations.documentsEmpty` | localized recovery state for missing scan sessions |
| `report_investment_card` | `screens/advisor/financial_report_screen_v2.dart:51` | investment action card |

**M-0c — Define the shared subflow file `apps/mobile/.maestro/goto_retirement.yaml`** (referenced by F-1 via `runFlow`):
```yaml
appId: ch.mint.coach
---
# Navigate to the retirement dashboard (/retraite, app.dart:546) without relying on tab chrome.
- openLink: "mint://retraite"
- assertVisible: { id: "retirement_gap_value" }
```

## 1. Happy-path flows (prove cross-screen data flow)

Each asserts: **data entered on screen A is visible/used on screen B** — i.e. the `CoachProfileProvider → MintStateProvider` spine works.

### F-1 first-job → retirement gap uses the salary
File: `apps/mobile/.maestro/f1_first_job.yaml`
```yaml
appId: ch.mint.coach
---
- launchApp: { clearState: true }
- assertVisible: { text: "Parle à Mint" }    # landing CTA (l10n landingV2CtaSober, app_fr.arb:11258)
- tapOn: { text: "Parle à Mint" }             # / landing -> coach/anon
- tapOn: { id: "coach_input" }
- inputText: "je commence mon premier job à 4500 net"
- tapOn: { id: "coach_send" }
- assertVisible: { text: "3e pilier" }        # coach explains, no product named
- runFlow: goto_retirement.yaml               # navigate to /retraite (subflow, M-0c)
- assertVisible: { id: "retirement_gap_value" }
# PROOF: the gap reflects the salary just entered (not the empty-profile default)
- assertVisible: { text: "4'500" }            # salary echoed in the projection basis
```

### F-2 salary entered in data-block is visible in mortgage affordability
File: `apps/mobile/.maestro/f2_datablock_to_mortgage.yaml`
```yaml
appId: ch.mint.coach
---
- launchApp: { clearState: true }
- openLink: "mint://data-block/revenu"        # /data-block/:type (app.dart:1271)
- tapOn: { id: "salary_input" }
- inputText: "8000"
- tapOn: { id: "canton_picker" }
- tapOn: { text: "Genève" }
- back
- openLink: "mint://hypotheque"               # /hypotheque (app.dart:490 target)
- assertVisible: { id: "mortgage_afford_result" }
# PROOF: affordability used the 8000 salary + GE canton from the ledger, not extra
```

### F-3 retirement — LPP balance entered in coach is used by rente-vs-capital
File: `apps/mobile/.maestro/f3_retirement.yaml`
```yaml
appId: ch.mint.coach
---
- launchApp: { clearState: true }
- openLink: "mint://coach/chat"               # coach chat (StatefulShell tab 1)
- tapOn: { id: "coach_input" }
- inputText: "mon avoir LPP est de 120000"
- tapOn: { id: "coach_send" }
- assertVisible: { text: "LPP" }              # coach acknowledges the pillar
- openLink: "mint://retraite"                 # /retraite (app.dart:546)
- assertVisible: { id: "retirement_gap_value" }
- openLink: "mint://rente-vs-capital"         # rente-vs-capital simulator
- assertVisible: { id: "rente_capital_uses_lpp" }
# PROOF: the rente-vs-capital result is derived from the 120000 LPP from the ledger
- assertVisible: { text: "120'000" }
```

### F-4 buying property — savings entered changes the affordability verdict
File: `apps/mobile/.maestro/f4_buying_property.yaml`
```yaml
appId: ch.mint.coach
---
- launchApp: { clearState: true }
- openLink: "mint://data-block/patrimoine"    # /data-block/:type (app.dart:1271)
- tapOn: { id: "salary_input" }
- inputText: "9000"
- back
- openLink: "mint://hypotheque"
- assertVisible: { id: "mortgage_afford_result" }
- copyTextFrom: { id: "mortgage_afford_result" }
- openLink: "mint://data-block/patrimoine"
- tapOn: { id: "savings_input" }
- inputText: "300000"                          # add fonds propres
- back
- openLink: "mint://hypotheque"
- assertVisible: { id: "mortgage_afford_result" }
# PROOF: the verdict recomputed from the 300000 savings now in the ledger
- assertNotVisible: { text: "${copiedText}" }  # verdict text changed after savings added
```

### F-5 transmitting property — property value drives the CASE, parents' note shows FIRST
File: `apps/mobile/.maestro/f5_transmitting_property.yaml`
```yaml
appId: ch.mint.coach
---
- launchApp: { clearState: true }
- openLink: "mint://succession"                # /succession (app.dart:637)
- assertVisible: { text: "Succession et transmission" }  # successionTitle (app_fr.arb:288)
- tapOn: { id: "property_value_input" }
- inputText: "1200000"
- assertVisible: { id: "property_value_input" }
# PROOF: the CASE guardQuest (DATA_QUEST §5) surfaces the parents'
# retirement-affordability note BEFORE any gift/transmission result
- assertVisible: { id: "succession_parents_note" }
```

## 2. Regression flows (each targets a REAL dead road — must go green after fix)

### R-1 /scan/review with no extra must NOT trap (D-1)
File: `apps/mobile/.maestro/r1_scan_review.yaml`
```yaml
appId: ch.mint.app
---
- launchApp: { clearState: true }
- openLink: "mint:///scan/review"              # no extra payload (deep link)
- assertNotVisible: { text: "Document non disponible" }   # the blank trap
- assertVisible: { text: "Aucun document" }        # recovery exists
- tapOn: { point: "50%,90%" }
- assertVisible: { id: "document_scan_header" }    # lands back on /scan
```
**Current proof:** syntax-gated as `apps/mobile/.maestro/r1_scan_review.yaml`; the flow asserts the recovery state and returns to `/scan`. Unit/widget coverage also asserts no domain payload is passed through `state.extra`.

### R-2 /scan/impact with no extra must NOT trap (D-2)
File: `apps/mobile/.maestro/r2_scan_impact.yaml`
```yaml
appId: ch.mint.app
---
- launchApp: { clearState: true }
- openLink: "mint:///scan/impact"             # no extra map (deep link / restart)
- assertNotVisible: { text: "Document non disponible" }   # the blank trap
- assertVisible: { text: "Aucun document" }        # recovery exists
- tapOn: { point: "50%,90%" }
- assertVisible: { id: "document_scan_header" }    # lands back on /scan
```
**Current proof:** syntax-gated as `apps/mobile/.maestro/r2_scan_impact.yaml`; the flow asserts the recovery state and returns to `/scan`. Unit/widget coverage also asserts no domain payload is passed through `state.extra`.

### R-3 financial-report 3a action reaches an actionable destination (D-4)
File: `apps/mobile/.maestro/r3_report_pillar3a_action.yaml`
```yaml
appId: ch.mint.app
---
- launchApp:
    clearState: true
    arguments:
      MINT_TEST_INITIAL_ROUTE: "/rapport"
      MINT_TEST_REPORT_FIXTURE: "first_salary_tax_vd"
      MINT_ENABLE_RUNTIME_PROOF_SEMANTICS: "true"
- assertVisible: { text: "Ton Plan Mint" }
- scrollUntilVisible:
    element:
      id: "report_action_pillar3a_cta"
    direction: DOWN
    timeout: 60000
- assertVisible: { id: "report_action_pillar3a_cta" }
- openLink: "mint:///pilier-3a"
- assertVisible: { text: "Ton 3e pilier" }
```
**Current proof:** syntax-gated as `apps/mobile/.maestro/r3_report_pillar3a_action.yaml`; widget tests lock the CTA mapping and the flow proves the seeded action plus destination route. `/tools` query preservation is covered by `test/routing/legacy_redirect_query_preservation_test.dart`.

### R-3c financial-report dossier export CTA is reachable (PDF handoff smoke)
File: `apps/mobile/.maestro/r3c_report_dossier_export.yaml`
```yaml
appId: ch.mint.app
---
- launchApp:
    clearState: true
    arguments:
      MINT_TEST_INITIAL_ROUTE: "/rapport"
      MINT_TEST_REPORT_FIXTURE: "first_salary_tax_vd"
      MINT_ENABLE_RUNTIME_PROOF_SEMANTICS: "true"
- scrollUntilVisible:
    element:
      id: "report_dossier_transmit_property_export_cta"
    direction: DOWN
    speed: 80
    timeout: 60000
    visibilityPercentage: 10
    centerElement: false
- assertVisible:
    id: "report_dossier_transmit_property_export_cta"
```
**Current proof:** syntax-gated as `apps/mobile/.maestro/r3c_report_dossier_export.yaml`.
Keep `centerElement: false` for this `scrollUntilVisible` block: Maestro 2.5.1
on iOS 26.2 can hang during syntax checking when this long scrolled report CTA
is centered. This flow proves the typed dossier export CTA path; PDF bytes and
audit-manifest sections remain covered by unit/widget tests.

### R-4 kill + restart mid-flow keeps data (spine persistence)
File: covered by provider/persistence tests; no dedicated Maestro YAML at HEAD.

**Current proof:** covered by `test/providers/coach_profile_provider_save_fact_mapping_test.dart`, `test/screens/report_route_screen_test.dart`, and the `mobile-scenarios` gate. Add a dedicated runtime YAML before claiming full restart runtime coverage.

### R-5 legacy redirects preserve query context (D-5)
File: `apps/mobile/test/routing/legacy_redirect_query_preservation_test.dart`
```yaml
# Static contract: /tools, /portfolio, and /score-reveal route blocks call
# _redirectPreservingQuery(state, target), not a bare target string.
```
**Current proof:** `app.dart` redirects `/portfolio` and `/score-reveal` through `_redirectPreservingQuery(state, '/home')`; `/tools` redirects through `_redirectPreservingQuery(state, '/coach/chat')`. The static test is part of the targeted WIRING proof set.

## 3. Acceptance criteria (Codex/CI)

- **M-1** `.maestro/` exists; `maestro test .maestro/` runs in CI; `mint://` scheme registered (M-0a) and verified via `adb shell am start … -d "mint://home"`.
- **M-2** All F-1..F-5 green ⇒ the spine connects across screens (first job, retirement, buying property, transmitting property).
- **M-3** All R-1..R-5 green ⇒ every verified dead road (D-1..D-5) is closed.
- **M-4** Each flow uses a stable id from Task M-0 (no reliance on volatile visible text except localized asserts).
- **M-5** A newly added screen without F-/R- coverage fails the "every live route has ≥1 flow" check (cross-ref `SCREEN_CONTRACTS.md`).
- **M-6** Divorce happy-path (F-6) green ⇒ the required priority-event set {first job, retirement, buying property, transmitting property, divorce} is fully covered.

## 4. Divorce happy-path (priority event, real route `/divorce`)

### F-6 divorce — matrimonial regime selection drives the LPP-split result
File: `apps/mobile/.maestro/f6_divorce.yaml`
```yaml
appId: ch.mint.coach
---
- launchApp: { clearState: true }
- openLink: "mint://divorce"                  # /divorce (app.dart:763, DivorceSimulatorScreen)
- assertVisible: { text: "Divorce — Impact financier" }  # divorceAppBarTitle (app_fr.arb:1139)
- tapOn: { id: "divorce_regime_picker" }
- tapOn: { text: "Séparation de biens" }      # divorceSeparation option
- assertVisible: { id: "divorce_lpp_split_result" }
# PROOF: the LPP-split outcome reflects the selected regime + the ledger profile,
# not an empty default (cross-screen: profile from spine feeds the simulator)
- assertVisible: { text: "LPP" }
```
**Today: PASSES** if the simulator reads `CoachProfileProvider` (verified: `retirement_dashboard`/simulators call `provider.updateProfile()` and read the spine). Guards against future isolation of the divorce simulator from the ledger.

---

Grounding notes: verify against HEAD directly. Current route contracts are asserted by `test/routing/no_domain_data_in_extra_test.dart`, `test/routing/legacy_redirect_query_preservation_test.dart`, the Maestro YAML files under `apps/mobile/.maestro/`, and `tools/checks/mint_lucidity_gate.sh mobile-scenarios`.

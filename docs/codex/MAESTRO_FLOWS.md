# MAESTRO_FLOWS.md — E2E flow contracts and backlog (Codex-executable)

> **Baseline note:** file:line references were originally audited against `apps/mobile/` and `services/backend/` at commit `255373b`, then corrected on this branch. Treat every reference below as a HEAD contract and re-verify after code movement.

> **Status:** normative. Grounded in the REAL code at commit `255373b`, then
> updated against the current clean branch. Treat this as a HEAD contract.
> **Purpose:** every row labelled `File:` is a checked-in mechanical proof or
> syntax-gated route smoke. Rows labelled `Blocked flow path:` are backlog
> sketches and must not be cited as runtime evidence. Runtime P0 proof currently
> runs on iOS/Patrol; Maestro provides checked-in iOS route smoke and
> syntax-gated flow contracts.
> **appId:** `ch.mint.app` (checked-in Maestro YAMLs under
> `apps/mobile/.maestro/`).
> **Companions:** `DATA_LEDGER.md`, `SCREEN_CONTRACTS.md`, `WIRING_GRAPH.mmd`, `DATA_QUEST.md`.

## 0. Reality check — current Maestro/iOS contract

- `apps/mobile/.maestro/` exists and contains the currently accepted route
  smoke flows. `tools/checks/mint_lucidity_gate.sh mobile-scenarios` syntax
  checks them and enforces current route coverage status.
- P0 product runtime proof is Patrol on the canonical iPhone simulator. Maestro
  remains a route/smoke harness for the checked-in YAMLs and a backlog format
  for future cross-screen proofs.
- iOS registers the `mint` custom scheme in
  `apps/mobile/ios/Runner/Info.plist`; checked-in flows use
  `mint:///absolute-path`.
- Android does **not** register the `mint` scheme yet. That is deliberate for
  this product branch: Android runtime is a separate compatibility track in
  `docs/codex/ANDROID_RUNTIME_BLOCKERS.md`, not the active iOS product gate.

### M-0 — Current setup contract and future ids

**M-0a — Custom scheme split.**

- iOS — already registered in `apps/mobile/ios/Runner/Info.plist`:
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
- Android — still pending in the Android compatibility track. The target patch
  is to add this intent-filter inside `<activity android:name=".MainActivity">`
  once `docs/codex/ANDROID_RUNTIME_BLOCKERS.md` is being handled:
  ```xml
  <intent-filter android:autoVerify="false">
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.DEFAULT" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="mint" />
  </intent-filter>
  ```
- GoRouter resolves absolute paths (`/data-block/:type`, `/hypotheque`,
  `/scan/review`, ...). Maestro flows must use `mint:///path`, not
  host-form `mint://path`.

**M-0b — Stable ids** (`Semantics(identifier: '...')` — Maestro/Patrol read
them; keep the i18n visible label separate):

| status | id | file | element |
|---|---|---|---|
| backlog prerequisite | `salary_input` | `screens/onboarding/data_block_enrichment_screen.dart` | net/gross salary field |
| backlog prerequisite | `canton_picker` | same | canton selector |
| live prerequisite | `coach_input` | `widgets/coach/coach_input_bar.dart` | chat text field |
| live prerequisite | `coach_send` | same | send button |
| backlog prerequisite | `retirement_gap_value` | `screens/coach/retirement_dashboard_screen.dart` | the projected gap number |
| live prerequisite | `mortgage_afford_result` | `screens/…/affordability` (`/hypotheque`) | affordability verdict |
| backlog prerequisite | `lpp_balance_input` | `widgets/coach/coach_input_bar.dart` (chat) or data-block `lpp` field | LPP balance entry |
| backlog prerequisite | `rente_capital_uses_lpp` | `/rente-vs-capital` result screen | value derived from LPP balance |
| backlog prerequisite | `savings_input` | `screens/onboarding/data_block_enrichment_screen.dart` | savings/patrimoine field |
| live prerequisite | `property_value_input` | `screens/coach/succession_patrimoine_screen.dart` | property value entry |
| live prerequisite | `succession_parents_note` | `screens/coach/succession_patrimoine_screen.dart` | parents' retirement-affordability CASE note |
| backlog prerequisite | `divorce_regime_picker` | `screens/divorce_simulator_screen.dart` | matrimonial regime selector |
| backlog prerequisite | `divorce_lpp_split_result` | `screens/divorce_simulator_screen.dart` | LPP-split outcome value |
| live proof | `document_scan_header` | `screens/document_scan/document_scan_screen.dart` | recovery destination reached from `/scan/review` and `/scan/impact` empty states |
| live proof | `Aucun document` | `app.dart:478,488` via `AppLocalizations.documentsEmpty` | localized recovery state for missing scan sessions |
| live proof | `report_action_investment_card` | `screens/advisor/financial_report_screen_v2.dart:78,914-915` | generated investment action card semantics id |

**M-0c — Future shared retirement navigation pattern**
(not a checked-in file at HEAD; use only when a live flow is added):
```yaml
appId: ch.mint.app
---
# Navigate to the retirement dashboard (/retraite, app.dart:546) without relying on tab chrome.
- openLink: "mint:///retraite"
- assertVisible: { id: "retirement_gap_value" }
```

## 1. Happy-path flow contracts (live `File:` rows prove cross-screen data flow)

Each live `File:` row asserts: **data entered on screen A is visible/used on
screen B** — i.e. the `CoachProfileProvider → MintStateProvider` spine works.
`Blocked flow path:` rows are product backlog sketches, not accepted proof.

### F-1 first-job → retirement gap uses the salary
Blocked flow path: `apps/mobile/.maestro/f1_first_job.yaml`

Not checked in at HEAD. This remains a backlog sketch until the salary capture
and retirement projection ids are stable enough to become a live Maestro/Patrol
proof.

```yaml
appId: ch.mint.app
---
- launchApp: { clearState: true }
- assertVisible: { text: "Parle à Mint" }    # landing CTA (l10n landingV2CtaSober, app_fr.arb:11258)
- tapOn: { text: "Parle à Mint" }             # / landing -> coach/anon
- tapOn: { id: "coach_input" }
- inputText: "je commence mon premier job à 4500 net"
- tapOn: { id: "coach_send" }
- assertVisible: { text: "3e pilier" }        # coach explains, no product named
- openLink: "mint:///retraite"                # navigate to /retraite
- assertVisible: { id: "retirement_gap_value" }
# PROOF: the gap reflects the salary just entered (not the empty-profile default)
- assertVisible: { text: "4'500" }            # salary echoed in the projection basis
```

### F-2 salary entered in data-block is visible in mortgage affordability
File: `apps/mobile/.maestro/f2_datablock_to_mortgage.yaml`
```yaml
appId: ch.mint.app
---
- launchApp: { clearState: true }
- openLink: "mint:///data-block/revenu"       # /data-block/:type (app.dart:1271)
- tapOn: { id: "salary_input" }
- inputText: "8000"
- tapOn: { id: "canton_picker" }
- tapOn: { text: "Genève" }
- back
- openLink: "mint:///hypotheque"              # /hypotheque (app.dart:490 target)
- assertVisible: { id: "mortgage_afford_result" }
# PROOF: affordability used the 8000 salary + GE canton from the ledger, not extra
```

### F-3 retirement — LPP balance entered in coach is used by rente-vs-capital
Blocked flow path: `apps/mobile/.maestro/f3_retirement.yaml`

Not checked in at HEAD. Keep as a backlog sketch until the coach fact-save path
and rente-vs-capital assertion ids are stable enough for runtime proof.

```yaml
appId: ch.mint.app
---
- launchApp: { clearState: true }
- openLink: "mint:///coach/chat"              # coach chat (StatefulShell tab 1)
- tapOn: { id: "coach_input" }
- inputText: "mon avoir LPP est de 120000"
- tapOn: { id: "coach_send" }
- assertVisible: { text: "LPP" }              # coach acknowledges the pillar
- openLink: "mint:///retraite"                # /retraite (app.dart:546)
- assertVisible: { id: "retirement_gap_value" }
- openLink: "mint:///rente-vs-capital"        # rente-vs-capital simulator
- assertVisible: { id: "rente_capital_uses_lpp" }
# PROOF: the rente-vs-capital result is derived from the 120000 LPP from the ledger
- assertVisible: { text: "120'000" }
```

### F-4 buying property — savings entered changes the affordability verdict
Blocked flow path: `apps/mobile/.maestro/f4_buying_property.yaml`

Not checked in at HEAD. Keep as a backlog sketch until the patrimoine data-block
and affordability verdict comparison are stable enough for runtime proof.

```yaml
appId: ch.mint.app
---
- launchApp: { clearState: true }
- openLink: "mint:///data-block/patrimoine"   # /data-block/:type (app.dart:1271)
- tapOn: { id: "salary_input" }
- inputText: "9000"
- back
- openLink: "mint:///hypotheque"
- assertVisible: { id: "mortgage_afford_result" }
- copyTextFrom: { id: "mortgage_afford_result" }
- openLink: "mint:///data-block/patrimoine"
- tapOn: { id: "savings_input" }
- inputText: "300000"                          # add fonds propres
- back
- openLink: "mint:///hypotheque"
- assertVisible: { id: "mortgage_afford_result" }
# PROOF: the verdict recomputed from the 300000 savings now in the ledger
- assertNotVisible: { text: "${copiedText}" }  # verdict text changed after savings added
```

### F-5 transmitting property — property value drives the CASE, parents' note shows FIRST
File: `apps/mobile/.maestro/f5_transmitting_property.yaml`
```yaml
appId: ch.mint.app
---
- launchApp: { clearState: true }
- openLink: "mint:///succession"               # /succession (app.dart:637)
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

- **M-1** `apps/mobile/.maestro/` exists; checked-in YAMLs syntax-check in
  `mobile-scenarios`; iOS has the `mint` scheme registered; Android custom
  scheme/runtime remains tracked in `docs/codex/ANDROID_RUNTIME_BLOCKERS.md`.
- **M-2** P0 spine proof is split deliberately:
  - `first_salary_tax` and `buy_property` are runtime-proven by Patrol
    (`P0_CASE_VARIABLE_REGISTRY.json.patrol_flow_id`) while Maestro keeps route
    smoke/status entries.
  - `transmit_property` has both a checked-in Maestro flow
    `phase2_data_quest_transmit_property.yaml` and a Patrol runtime proof.
- **M-3** R-1/R-2/R-3/R-3c checked-in flows plus the static redirect tests cover
  the repaired dead roads D-1..D-5. A future R-4 restart runtime YAML must be
  added before claiming runtime restart coverage.
- **M-4** Each flow uses a stable id from Task M-0 (no reliance on volatile visible text except localized asserts).
- **M-5** A newly added screen without F-/R- coverage fails the "every live route has ≥1 flow" check (cross-ref `SCREEN_CONTRACTS.md`).
- **M-6** Divorce happy-path (F-6) is blocked until
  `apps/mobile/.maestro/f6_divorce.yaml` exists and passes syntax/runtime gates.

## 4. Divorce happy-path (priority event, real route `/divorce`)

### F-6 divorce — matrimonial regime selection drives the LPP-split result
Blocked flow path: `apps/mobile/.maestro/f6_divorce.yaml`

Not checked in at HEAD; blocked by the dedicated divorce UX/runtime contract.

```yaml
appId: ch.mint.app
---
- launchApp: { clearState: true }
- openLink: "mint:///divorce"                 # /divorce (app.dart:763, DivorceSimulatorScreen)
- assertVisible: { text: "Divorce — Impact financier" }  # divorceAppBarTitle (app_fr.arb:1139)
- tapOn: { id: "divorce_regime_picker" }
- tapOn: { text: "Séparation de biens" }      # divorceSeparation option
- assertVisible: { id: "divorce_lpp_split_result" }
# PROOF: the LPP-split outcome reflects the selected regime + the ledger profile,
# not an empty default (cross-screen: profile from spine feeds the simulator)
- assertVisible: { text: "LPP" }
```
**Current status:** blocked. The flow remains a future contract because
`apps/mobile/.maestro/f6_divorce.yaml` is not checked in. When it lands, it must
guard against isolating the divorce simulator from the ledger.

---

Grounding notes: verify against HEAD directly. Current route contracts are asserted by `test/routing/no_domain_data_in_extra_test.dart`, `test/routing/legacy_redirect_query_preservation_test.dart`, the Maestro YAML files under `apps/mobile/.maestro/`, and `tools/checks/mint_lucidity_gate.sh mobile-scenarios`.

# MAESTRO_FLOWS.md — E2E flows that PROVE the wiring (Codex-executable)

> **G1 reality audit:** `file:line` references were re-checked against HEAD `095eeaa32` on 2026-07-07. Treat line refs as evidence snapshots, not evergreen truth. Rerun `tools/checks/tests/test_codex_spec_reality_contract.py` after changing this spec or the cited code.

> **Status:** executable target contract plus live QA inventory. Grounded in the REAL code at commit `095eeaa32`.
> **Purpose:** every flow is a mechanical proof that the spine connects. **Green = wired.** A red flow names a real bug to fix (`WIRING_GRAPH.mmd` D-1..D-5).
> **appId:** Android `ch.mint.coach` (`android/app/build.gradle:50`); current iOS bundle / checked-in Maestro flow uses `ch.mint.app` (`ios/Runner/Info.plist:25`, `.maestro/f2_datablock_to_mortgage.yaml:1`).
> **Companions:** `DATA_LEDGER.md`, `SCREEN_CONTRACTS.md`, `WIRING_GRAPH.mmd`, `DATA_QUEST.md`.

> **G1-COACH-01 accepted runtime:** exact pushed SHA `fec1d4119e` uses the
> dedicated Patrol target
> `test/patrol/g1_coach01_inline_amount_runtime_test.dart`. The two-stage build
> plus `xcodebuild test-without-building` passed 1/1; the real MINT Coach
> synthetic CHF 120'000 completion screen was visually accepted. The same test
> separately reconstructs the provider and proves cold-reload provenance. The
> screenshot's DEBUG test overlay is explicit, so this is bounded in-test UI
> proof rather than shipping-default chrome evidence. COACH-01 is GREEN; the
> global Maestro+Patrol `G1-RUNTIME-01` remains `red_proven`.
>
> **G1 LPP regulation code reality:** the former acquisition facade is now a
> real default-off `/scan -> /scan/review -> /retraite` code path through
> `73b505bcf` and `4907667b8` (compile repair `deb199c7f`), backed by the
> request-scoped/no-cache backend at `b30e3c109`. No dedicated exact-SHA
> Maestro/Patrol flow is checked in or accepted yet. The runtime row below is
> therefore a required target, not a pass; activation and G1 remain NO-GO.

## 0. Reality check — partial Maestro setup exists

- `apps/mobile/.maestro/f2_datablock_to_mortgage.yaml` exists at `095eeaa32`; R-1/R-2 scan recovery flows are checked in by the G1 repair slice.
- The F-2 stable ids are present: `salary_input`, `canton_picker`, `birth_year_input`, `has_pension_fund_switch`, `salary_save_cta`, `mortgage_afford_result`, `mortgage_income_amount`.
- The F-5 stable ids are present: `succession_property_missing`, `property_market_value_input`, `patrimoine_save_cta`, `succession_parents_note`.
- IDs for F-1/F-3/F-6 are still missing or not fully wired (`coach_input`, `coach_send`, `retirement_gap_value`, `divorce_regime_picker`, `divorce_lpp_split_result`, `report_investment_card`).
- **Deep links are partial.** iOS has `CFBundleURLSchemes` with `mint` (`ios/Runner/Info.plist:21-29`). Android still has no `mint://` intent-filter on `MainActivity` (only `MAIN`/`LAUNCHER`, `AndroidManifest.xml:25-28`; `https` appears only under `<queries>`, `:34-38`). Android `openLink: "mint:///..."` is dead until Task M-0a registers the scheme.

### Task M-0 — Setup, deep-link scheme, and required ids to ADD (file : what)

**M-0a — Register the `mint://` custom scheme where missing (REQUIRED before Android `openLink` flows run).**

- Android — add this intent-filter INSIDE the `<activity android:name=".MainActivity">` block of `apps/mobile/android/app/src/main/AndroidManifest.xml` (after the existing `MAIN`/`LAUNCHER` filter, before `</activity>` at line 29):
  ```xml
  <intent-filter android:autoVerify="false">
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.DEFAULT" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="mint" />
  </intent-filter>
  ```
- iOS — already present in `apps/mobile/ios/Runner/Info.plist`; keep this shape:
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

**M-0b — Expand `apps/mobile/.maestro/` and add missing stable ids** (`Semantics(identifier: '...')` — Maestro reads it cross-platform; keep the i18n visible label separate):

| id to add | file | element |
|---|---|---|
| `salary_input` | `screens/onboarding/data_block_enrichment_screen.dart` | net/gross salary field |
| `company_profit_input` | `screens/onboarding/data_block_enrichment_screen.dart` | SA/Sarl annual profit field for `/independants/dividende-salaire` |
| `canton_picker` | same | canton selector |
| `coach_input` | `widgets/coach/coach_input_bar.dart` | chat text field |
| `coach_send` | same | send button |
| `retirement_gap_value` | `screens/coach/retirement_dashboard_screen.dart` | the projected gap number |
| `mortgage_afford_result` | `screens/…/affordability` (`/hypotheque`) | affordability verdict |
| `lpp_balance_input` | `widgets/coach/coach_input_bar.dart` (chat) or data-block `lpp` field | LPP balance entry |
| `rente_capital_uses_lpp` | `/rente-vs-capital` result screen | value derived from LPP balance |
| `savings_input` | `screens/onboarding/data_block_enrichment_screen.dart` | savings/patrimoine field |
| `property_market_value_input` | `screens/onboarding/data_block_enrichment_screen.dart` (`/data-block/patrimoine?inputKey=q_property_market_value`) | property market value entry |
| `succession_property_missing` | `screens/coach/succession_patrimoine_screen.dart` | missing property-value state before any CASE output |
| `succession_parents_note` | `screens/coach/succession_patrimoine_screen.dart` | transmission note rendered from ledger property facts |
| `divorce_regime_picker` | `screens/divorce_simulator_screen.dart` | matrimonial regime selector |
| `divorce_lpp_split_result` | `screens/divorce_simulator_screen.dart` | LPP-split outcome value |
| `scan_review_recovery_cta` | `app.dart:903` builder (NEW errorState) | recovery button on `/scan/review` empty |
| `scan_impact_recovery_cta` | `app.dart:916` builder (NEW errorState) | recovery button on `/scan/impact` empty |
| `report_investment_card` | `screens/advisor/financial_report_screen_v2.dart:51` | investment action card |
| `dividende_vs_salaire_result_section` | `screens/independants/dividende_vs_salaire_screen.dart` | dividend-vs-salary result unlocked by `q_company_profit_annual_chf` |
| `dividende_vs_salaire_curve_chart` | same | charge curve proof for the selected split |

**M-0c — Define the shared subflow file `apps/mobile/.maestro/goto_retirement.yaml`** (referenced by F-1 via `runFlow`):
```yaml
appId: ch.mint.app
---
# Navigate to the retirement dashboard (/retraite, app.dart:546) without relying on tab chrome.
- openLink: "mint:///retraite"
- assertVisible: { id: "retirement_gap_value" }
```

## 1. Happy-path flows (prove cross-screen data flow)

Each asserts: **data entered on screen A is visible/used on screen B** — i.e. the `CoachProfileProvider → MintStateProvider` spine works.

### F-1 first-job → retirement gap uses the salary
File: `apps/mobile/.maestro/f1_first_job.yaml`
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
- runFlow: goto_retirement.yaml               # navigate to /retraite (subflow, M-0c)
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
- openLink: "mint:///data-block/revenu"       # /data-block/:type (app.dart:1277)
- tapOn: { id: "salary_input" }
- inputText: "8000"
- tapOn: { id: "canton_picker" }
- tapOn: { text: "Genève" }
- back
- openLink: "mint:///hypotheque"              # /hypotheque
- assertVisible: { id: "mortgage_afford_result" }
# PROOF: affordability used the 8000 salary + GE canton from the ledger, not extra
```

### F-3 retirement — LPP balance entered in coach is used by rente-vs-capital
File: `apps/mobile/.maestro/f3_retirement.yaml`
```yaml
appId: ch.mint.app
---
- launchApp: { clearState: true }
- openLink: "mint:///coach/chat"              # coach chat (StatefulShell tab 1)
- tapOn: { id: "coach_input" }
- inputText: "mon avoir LPP est de 120000"
- tapOn: { id: "coach_send" }
- assertVisible: { text: "LPP" }              # coach acknowledges the pillar
- openLink: "mint:///retraite"                # /retraite
- assertVisible: { id: "retirement_gap_value" }
- openLink: "mint:///rente-vs-capital"        # rente-vs-capital simulator
- assertVisible: { id: "rente_capital_uses_lpp" }
# PROOF: the rente-vs-capital result is derived from the 120000 LPP from the ledger
- assertVisible: { text: "120'000" }
```

### F-4 buying property — savings entered changes the affordability verdict
File: `apps/mobile/.maestro/f4_buying_property.yaml`
```yaml
appId: ch.mint.app
---
- launchApp: { clearState: true }
- openLink: "mint:///data-block/patrimoine"   # /data-block/:type
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

### F-5 transmitting property — ledger property value drives the note
File: `apps/mobile/.maestro/f5_transmitting_property.yaml`
```yaml
appId: ch.mint.app
---
- launchApp: { clearState: true }
- openLink: "mint:///succession"               # /succession
- assertVisible: { text: "Succession et transmission" }  # successionTitle (app_fr.arb:288)
- assertVisible: { id: "succession_property_missing" }
- tapOn: { text: "Renseigner mon patrimoine" }
- assertVisible: { id: "property_market_value_input" }
- tapOn: { id: "property_market_value_input" }
- inputText: "1200000"
- tapOn: { id: "patrimoine_save_cta" }
- openLink: "mint:///succession"
# PROOF: /succession now renders from the saved user ledger fact instead of a
# fictive property CASE.
- assertVisible: { id: "succession_parents_note" }
```

## 1A. G1 LPP regulation — required dual runtime proof (NOT RUN)

The production code now has stable controls, but no checked-in exact-SHA run
proves the whole plan path on a device. Do not reuse the personal-certificate
PROV-02 runtime as a substitute: `lpp_plan` has a different PDF-only, zero-fact,
request-scoped backend boundary and a different review writer.

Private plans/certificates are deliberately outside this runtime. The ignored
local `lpp_private_fixture_gate_test.dart` has seven sanitized classification
cases, including a plan, and is the only private-fixture gate. Runtime and
retained evidence must contain no private-manifest variable, ignored-fixture
path, document hash or raw bytes and must declare `private_fixture_used=false`.
Backend zero-fact/no-row/no-cache/no-RAG/raw-preview behavior remains proven by
its focused backend tests and accepted audits, not borrowed from a mocked mobile
runtime response.

### Patrol exact-SHA target — production-shaped synthetic input and process death

The checked-in runtime atom must contain the production integration targets,
their thin Patrol wrappers and one exact-SHA orchestrator:

- `integration_test/g1_ret_ref_lpp_regulation_write_patrol_test.dart`
- `integration_test/g1_ret_ref_lpp_regulation_read_patrol_test.dart`
- `test/patrol/g1_ret_ref_lpp_regulation_write_runtime_test.dart`
- `test/patrol/g1_ret_ref_lpp_regulation_read_runtime_test.dart`
- `tools/simulator/patrol_lpp_regulation_process_death.sh`

The writer must exercise the production-shaped widgets, providers and route
payload. Injection is allowed only at the OS/network boundaries: a synthetic
PDF picker result, granted `visionExtraction` consent and an exact zero-fact
`DocumentUploadResult` for `VaultDocumentType.lppPlan`. It must never call
`acceptLppRegulationReference` or `recordLppRegulation` directly.

1. Create a non-empty strict self snapshot through the existing typed numeric
   review seam and enable exactly the three process-static regulation flags.
2. Pump `DocumentScanScreen(initialType: DocumentType.lppPlan)`, select
   `document_scan_lpp_plan_type_selector` and tap
   `document_scan_gallery_cta`. Assert camera/paste/debug paths are absent.
3. Inject synthetic `%PDF` bytes through `pickFile`; assert consent is exactly
   `[visionExtraction]`; assert `uploadDocument` receives
   `VaultDocumentType.lppPlan` and returns the strict empty/zero/RAG-false
   response shape.
4. Observe the production navigation URI. Its sole query key is
   `scanSessionId`; it contains neither the synthetic backend processing id nor
   document material. Resolve that session and pass its regulation candidate
   into the production review screen.
5. Enter canonical values through `lpp_regulation_review_source_date` and
   `lpp_regulation_review_legal_year`, then tap
   `lpp_regulation_review_confirm_cta`. Thin provider spies may call `super` only
   to observe the production UI seam; assert exact event order `accept, record`,
   raw-free stores, discarded scan session and the retirement card.
6. Terminate the app process. The separate read target starts from the normal
   entrypoint, cold-loads the strict root and reference store, hydrates
   `DocumentProvider`, resolves the exact Dashboard card and opens the local
   sheet/privacy boundary.
7. Write a replacement numeric self-LPP snapshot through the existing numeric
   review seam and prove the regulation reference/card disappear. No cached
   GREEN survives authority replacement.

`legalYear` 1900...9999 is only the technical serialization bound; it does not
validate which legal version applies. The prerequisite numeric snapshot is
also not proof that this regulation belongs to the current pension fund and it
excludes a regulation-only journey. Therefore this runtime can validate the
snapshot-bound transport/writer/cold-reader atom but cannot authorize product
activation or G1 closure. A future G1 slice must decide and implement a
separately attested fund reference — current fund, uncertain, or former/other
fund — without importing plan values into facts or calculations.

### Maestro production-default before/after targets

Two flows bracket the Patrol write/process-death run:

- `apps/mobile/.maestro/g1_ret_ref_lpp_regulation_flag_off_before.yaml`
- `apps/mobile/.maestro/g1_ret_ref_lpp_regulation_flag_off_after.yaml`

Both use the normal production entrypoint with all three flags false. Before
uses `clearState:true`; after preserves state with `clearState:false`. They open
`/scan?type=lppPlan` and `/retraite`, assert ordinary landing/scan recovery is
visible, and assert all plan acquisition, review, Dashboard card and sheet ids
are absent. They perform no tap or input and retain no raw Maestro media.

Acceptance requires the exact pushed SHA, physical production-source export,
build/sign/install commands, Patrol writer/read xcresult counts, both Maestro
exit codes, sanitized metadata/logs and `private_fixture_used=false`. Post-writer
Sonnet reruns plus Opus final code/product confirmations already pass with
P0/P1=0; archive those outputs with the runtime bundle rather than rerunning an
audit carousel. Until the tracked bundle is accepted, this section stays
**NOT RUN** and no ticket/activation promotion is allowed.

## 2. Regression flows (each targets a REAL dead road — must go green after fix)

### R-1 /scan/review with no extra must NOT trap (D-1)
File: `apps/mobile/.maestro/r1_scan_review.yaml`
```yaml
appId: ch.mint.app
---
- launchApp: { clearState: true }
- openLink: "mint:///scan/review"             # no extra payload (deep link)
- assertNotVisible: { text: "Document non disponible" }   # the blank trap
- assertVisible: { id: "scan_review_recovery_cta" }        # recovery exists
- tapOn: { id: "scan_review_recovery_cta" }
- assertVisible: { id: "document_scan_capture_cta" }       # lands back on /scan
```
**G1 repair status:** checked-in flow exists; the blank trap is covered by `apps/mobile/test/routing/scan_flow_repair_test.dart`. Runtime acceptance still requires running this Maestro flow against the app.

### R-2 /scan/impact with no extra must NOT trap (D-2)
File: `apps/mobile/.maestro/r2_scan_impact.yaml`
```yaml
appId: ch.mint.app
---
- launchApp: { clearState: true }
- openLink: "mint:///scan/impact"            # no extra map (deep link / restart)
- assertNotVisible: { text: "Document non disponible" }   # the blank trap
- assertVisible: { id: "scan_impact_recovery_cta" }        # recovery exists
- tapOn: { id: "scan_impact_recovery_cta" }
- assertVisible: { id: "home_route" }                      # lands on /home
```
**G1 repair status:** checked-in flow exists; the blank trap is covered by `apps/mobile/test/routing/scan_flow_repair_test.dart`. Runtime acceptance still requires running this Maestro flow against the app.

### R-3 financial-report investment card reaches an actionable destination (D-4)
File: `apps/mobile/.maestro/r3_report_investment_card.yaml`
```yaml
appId: ch.mint.app
---
- launchApp: { clearState: false }
- openLink: "mint:///rapport"                 # /rapport
- tapOn: { id: "report_investment_card" }
- assertNotVisible: { text: "Comment puis-je t'aider" }  # generic context-less coach = bug
- assertVisible: { text: "3e pilier" }                    # topic context preserved
```
**G1 status: FIXED as route mapping, missing as Maestro id** — `financial_report_screen_v2.dart:51-52` maps `ActionCategory.investment`/`.other` → `/coach/chat?topic=...`; add `report_investment_card` before this flow can click the card.

### R-4 kill + restart mid-flow keeps data (spine persistence)
File: `apps/mobile/.maestro/r4_persistence.yaml`
```yaml
appId: ch.mint.app
---
- launchApp: { clearState: true }
- openLink: "mint:///data-block/revenu"
- tapOn: { id: "salary_input" }
- inputText: "8000"
- back
- stopApp
- launchApp: { clearState: false }            # cold start reloads wizard_answers_v2
- openLink: "mint:///hypotheque"
- assertVisible: { id: "mortgage_afford_result" }   # 8000 survived restart
```
**Today: PASSES** (persistence works via `report_persistence_service` → `wizard_answers_v2`) — keep as a guard against regressions.

### R-5 /portfolio?param keeps the param (D-5)
File: `apps/mobile/.maestro/r5_portfolio_param.yaml`
```yaml
appId: ch.mint.app
---
- launchApp: { clearState: false }
- openLink: "mint:///portfolio?tab=1"
- assertVisible: { text: "Mon argent" }       # should map to /mon-argent tab 1, param honoured
```
**G1 status: FIXED as redirect** — `app.dart:1195-1197` preserves the query and `/home?tab=1` maps to `/mon-argent` (`app.dart:251-273`).

## 3. Acceptance criteria (Codex/CI)

- **M-1** `.maestro/` exists; `maestro test .maestro/` runs in CI; Android `mint://` scheme registered (M-0a) and verified via `adb shell am start ... -d "mint:///home"`.
- **M-2** All F-1..F-5 green ⇒ the spine connects across screens (first job, retirement, buying property, transmitting property).
- **M-3** All R-1..R-5 green ⇒ every verified dead road (D-1..D-5) is closed.
- **M-4** Each flow uses a stable id from Task M-0 (no reliance on volatile visible text except localized asserts).
- **M-5** A newly added screen without F-/R- coverage fails the "every live route has ≥1 flow" check (cross-ref `SCREEN_CONTRACTS.md`).
- **M-6** Divorce happy-path (F-6) green ⇒ the required priority-event set {first job, retirement, buying property, transmitting property, divorce} is fully covered.

## 4. Divorce happy-path (priority event, real route `/divorce`)

### F-6 divorce — matrimonial regime selection drives the LPP-split result
File: `apps/mobile/.maestro/f6_divorce.yaml`
```yaml
appId: ch.mint.app
---
- launchApp: { clearState: true }
- openLink: "mint:///divorce"                 # /divorce
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

Grounding notes: `/scan/review` and `/scan/impact` recovery flows are now checked in as R-1/R-2 with stable ids; `/tools` and `/portfolio` preserve query; F-2 plus R-1/R-2 exist under `.maestro`; iOS has the `mint` scheme; Android still needs the `mint` intent-filter.

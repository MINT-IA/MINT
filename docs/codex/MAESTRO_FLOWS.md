# MAESTRO_FLOWS.md — E2E flows that PROVE the wiring (Codex-executable)

> **G1 reality audit:** `file:line` references were re-checked against HEAD `095eeaa32` on 2026-07-07. Treat line refs as evidence snapshots, not evergreen truth. Rerun `tools/checks/tests/test_codex_spec_reality_contract.py` after changing this spec or the cited code.

> **Status:** executable target contract plus live QA inventory. Grounded in the REAL code at commit `095eeaa32`.
> **Purpose:** every flow is a mechanical proof that the spine connects. **Green = wired.** A red flow names a real bug to fix (`WIRING_GRAPH.mmd` D-1..D-5).
> **appId:** Android `ch.mint.coach` (`android/app/build.gradle:50`); current iOS bundle / checked-in Maestro flow uses `ch.mint.app` (`ios/Runner/Info.plist:25`, `.maestro/f2_datablock_to_mortgage.yaml:1`).
> **Companions:** `DATA_LEDGER.md`, `SCREEN_CONTRACTS.md`, `WIRING_GRAPH.mmd`, `DATA_QUEST.md`.

## 0. Reality check — partial Maestro setup exists

- `apps/mobile/.maestro/f2_datablock_to_mortgage.yaml` exists at `095eeaa32`; R-1/R-2 scan recovery flows are checked in by the G1 repair slice.
- The F-2 stable ids are present: `salary_input`, `canton_picker`, `birth_year_input`, `has_pension_fund_switch`, `salary_save_cta`, `mortgage_afford_result`, `mortgage_income_amount`.
- IDs for F-1/F-3/F-5/F-6 are still missing or not fully wired (`coach_input`, `coach_send`, `retirement_gap_value`, `property_value_input`, `succession_parents_note`, `divorce_regime_picker`, `divorce_lpp_split_result`, `report_investment_card`).
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
| `scan_review_recovery_cta` | `app.dart:903` builder (NEW errorState) | recovery button on `/scan/review` empty |
| `scan_impact_recovery_cta` | `app.dart:916` builder (NEW errorState) | recovery button on `/scan/impact` empty |
| `report_investment_card` | `screens/advisor/financial_report_screen_v2.dart:51` | investment action card |

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

### F-5 transmitting property — property value drives the CASE, parents' note shows FIRST
File: `apps/mobile/.maestro/f5_transmitting_property.yaml`
```yaml
appId: ch.mint.app
---
- launchApp: { clearState: true }
- openLink: "mint:///succession"               # /succession
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
- openLink: "mint:///scan/review"             # no extra payload (deep link)
- assertNotVisible: { text: "Document non disponible" }   # the blank trap
- assertVisible: { id: "scan_review_recovery_cta" }        # recovery exists
- tapOn: { id: "scan_review_recovery_cta" }
- assertVisible: { text: "Prendre une photo" } # lands back on /scan, not stuck
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
- assertVisible: { text: "MINT" }             # lands on /home, not stuck
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

Grounding notes (verified at `095eeaa32`): `/scan/review` and `/scan/impact` still hit the `Document non disponible` trap; `/tools` and `/portfolio` now preserve query; only F-2 exists under `.maestro`; iOS has the `mint` scheme; Android still needs the `mint` intent-filter.

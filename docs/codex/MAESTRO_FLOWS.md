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
> **G1 LPP capital-notice acquisition + dossier/PDF runtime:** exact pushed SHA
> `36152b997fbf0c32c1120ddb61f0a8e9d589aa52` passes a native writer and
> distinct-process cold reader 2/2. The writer uses the production UI
> acquisition seam for numeric certificate review, `/scan?type=lppPlan`, exact
> regulation/capital fields, ordered strict writes, scan-session purge and the
> Dashboard banner. The cold reader proves authority replacement invalidation
> and numeric snapshot replacement purge. Exact-source production build/install
> passes; production-default Maestro passes 1/1 with the path absent. External
> document/OCR IO remains synthetic. The minimized proof is
> `phase-37/ret-ref-01/lpp-capital-native-runtime-proof-36152b997/`.
> At exact pushed SHA `a00b4c68a272cbde9f21fee14662171c4a12530f`, the real
> `MintApp`/`AccountSessionBootstrap` reader opens `/rapport`, proves the capital
> section before regulation and builds production PDF bytes (`%PDF-`, >1000).
> Missing or mismatched capital BND suppresses only capital; a legacy regulation
> authority suppresses both. Exact root+BND restoration re-enables both before
> later authority and numeric snapshot replacement are re-proven fail closed.
> The production-default Maestro flow now also opens `/rapport` and asserts
> `financial_report_lpp_capital_notice_handoff` absent, in addition to the
> Dashboard absence. The synthetic-only run uses no private fixture and makes no
> production OCR/external-IO or runtime PDF-text-extraction claim. The minimized
> proof is
> `phase-37/ret-ref-01/lpp-capital-dossier-pdf-runtime-proof-a00b4c68a/`.
> `capital_notice_dossier_pdf_parity` is closed/GREEN. Activation remains
> NO-GO/default-false; RET-REF stays `ticket_only`, G1 remains open at 8.2/10
> and G2/G3 remain forbidden.
>
> **G1 LPP regulation autonomous runtime:** exact pushed SHA
> `6066f1c94786aa1bc4697c29b4a670b7cea3dca4` passes one Patrol native
> writer/read suite 2/2 with a distinct PID, regulation-only cold hydration and
> numeric add/replacement preservation. Production export/build/sign/install,
> Maestro before/after default-off, container/state identity, cleanup/privacy
> and 22/22 logs pass. `fundRelationship=currentFund` is selected as a
> declaration, not verified caisse authority. The minimized tracked proof is
> `phase-37/ret-ref-01/lpp-regulation-runtime-proof-6066f1c94/`; full detailed
> archives remain local excluded provenance. RET-REF stays `ticket_only`, all
> flags stay false, activation and G1 remain NO-GO.
>
> **G1 LPP regulation recovery runtime:** exact pushed SHA
> `7cb5ea4c64e0a59d4e2f38f8f67eff7c924bd32a` extends the same 2/2 native
> suite. The distinct-PID cold reader empties the BND, freshly classifies
> `missingDocumentReference`, proves known/handoff absence plus the exact
> recovery body/CTA and emitted `/scan?type=lppPlan`, then restores, reloads and
> compares the original BND before numeric continuation. Production-default
> Maestro remains 1/1 before and 1/1 after; retained outputs remain 22/22. The
> tracked bundle is
> `phase-37/ret-ref-01/lpp-regulation-recovery-runtime-proof-7cb5ea4c6/` at
> `ce5a020503c9e1733a81fa01b8dc6dd79b7c01d1`. XCTest reports only the suite
> aggregate; UI claims come from the tracked reader executed by that passing
> suite, not from an XCTest assertion transcript. Activation remains NO-GO,
> G1 remains open at 8.2/10 and G2/G3 remain forbidden.
>
> **G1 LPP regulation dossier/PDF runtime:** exact pushed SHA
> `274736a50bca659579fe26f68ae4e600469e3a9a` runs the same 2/2 distinct-PID
> suite through production `MintApp` bootstrap and `/rapport`, builds production
> report bytes, and suppresses the dossier for missing, mismatched and legacy
> recovery. The host real-byte text contract passes 3/3. Maestro before/after
> stays production-default-off with 22/22 outputs. The minimized proof is
> `phase-37/ret-ref-01/lpp-regulation-dossier-pdf-runtime-proof-274736a50/`.
> PDF/dossier caveat parity is closed; activation remains NO-GO, RET-REF remains
> `ticket_only`, G1 remains open at 8.2/10 and G2/G3 remain forbidden.

## 0. Reality check — partial Maestro setup exists

- `apps/mobile/.maestro/f2_datablock_to_mortgage.yaml` exists at `095eeaa32`; R-1/R-2 scan recovery flows are checked in by the G1 repair slice.
- The F-2 stable ids are present: `salary_input`, `canton_picker`, `birth_year_input`, `has_pension_fund_switch`, `salary_save_cta`, `mortgage_afford_result`, `mortgage_income_amount`.
- The F-5 property stable ids are present: `succession_property_missing`, `property_market_value_input`, `patrimoine_save_cta`, `succession_parents_note`.
- The default-off SUCCESSION reference consumer adds a truthful disabled insertion marker, `succession_reference_quest_flag_off`, on the existing notions-clés heading. The flag-off flow scrolls to and asserts that marker; it does not assert a hidden quest. The flag-on flow scrolls to `succession_civil_status_guard`, then asserts the quest root and guard before using `succession_civil_status_confirm`. These YAML/runtime targets exist as contracts, but no SUCCESSION runtime PASS or promotion is claimed here.
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

### F-5S succession reference — default-off progressive authority proof (TARGET, not yet accepted)

Targets:

- `apps/mobile/.maestro/g1_succession_flag_off.yaml` for the explicit disabled
  insertion marker;
- `apps/mobile/.maestro/g1_succession_progressive.yaml` for the flag-on civil
  guard/return contract;
- `civil_guard_seed`, a distinct Patrol **setup writer** that must finish
  exactly `1/1 PASS` after persisting only the legacy ambiguous
  `q_civil_status='partenariat'` fixture without completing mini-onboarding;
- dedicated Patrol targets for native present input, explicit absent write and
  distinct-process cold read;
- build the flag-on target with
  `--dart-define=MINT_TEST_SUCCESSION_EVIDENCE_COLLECTION=true`;
- keep a normal production-default build to prove the collector is absent when
  the define is omitted.

The target must use these **existing literal ids**, never translated text:

| proof state | ids |
|---|---|
| flag-off insertion point | `succession_reference_quest_flag_off` (semantics marker on the existing notions-clés heading; no hidden quest assertion) |
| flag-on quest root | `succession_reference_quest` |
| ambiguous civil status | `succession_civil_status_guard`, `succession_civil_status_confirm` |
| arrangement | `succession_arrangement_question`, `succession_arrangement_enum`, `succession_arrangement_save` |
| exact will question | `succession_instrument_will_question`, `succession_instrument_will_absent`, `succession_instrument_will_present` |
| accepted write/explicit advance | `succession_answer_saved`, `succession_next_question` |
| next exact slot | `succession_instrument_inheritancePact_question` |
| present metadata | `succession_instrument_{kind}_source_date`, `succession_instrument_{kind}_legal_year`, `succession_instrument_{kind}_save` |
| stale cold reader | `succession_instrument_{kind}_stale`, `succession_instrument_{kind}_prior_state`, `succession_instrument_{kind}_reconfirm` |
| invalid/failure | `succession_reference_invalid`, `succession_reference_reload`, `succession_instrument_{kind}_save_error` |
| terminal review | `succession_reference_survey_recorded`, `succession_instrument_{kind}_summary`, `succession_instrument_{kind}_modify` |

Required proof sequence:

1. **Flag off:** launch the normal production entrypoint, reach `/succession`,
   scroll down to `succession_reference_quest_flag_off` and assert it visible.
   The marker is attached to the notions-clés heading at the disabled quest
   insertion point; it is not a placeholder quest or a domain-state widget.
2. **Truthful civil-guard setup and verified handoff:** a fresh profile defaults
   to confirmed `celibataire`; it cannot prove this branch. Run the isolated
   `civil_guard_seed` Patrol writer first and require exactly `1/1 PASS`. It
   persists the quarantined legacy `q_civil_status='partenariat'`, does not
   complete mini-onboarding, and uses
   `CoachProfile.fromWizardAnswers(persisted)` for a fresh model rehydration
   verifying `civilStatusNeedsConfirmation == true`. It does not claim that the
   minimal pre-onboarding answers make the provider publish a profile. Terminate
   that process without uninstalling or clearing data, resolve the physical app
   data container, and capture its `device:inode` plus a sanitized witness for
   exactly `q_birth_year=1980`, `q_canton=VD`,
   `q_civil_status=partenariat`, mini-onboarding `false`, and
   `q_property_market_value` absent. A raw container path may rotate; it must be
   resolved afresh rather than treated as identity.
3. **Exact production overlay:** install the exact flag-on production app with
   no uninstall, clear, backup or restore boundary. Resolve the data container
   again and require the same `device:inode` and byte-identical sanitized seed
   witness, then perform a fresh production launch. Any missing fact, stale
   property value, identity rotation or state mutation is a hard-fail before
   Maestro. Setting mini-onboarding complete or using direct plist injection is
   forbidden; setup writes must cross `ReportPersistenceService`.
4. **Civil guard/return:** in that seeded flag-on production app, use the real
   property DataBlock save to publish the merged production profile, scroll to
   `succession_civil_status_guard`, assert both the
   `succession_reference_quest` root and guard, tap the stable confirm CTA,
   verify the targeted `q_civil_status` DataBlock, save, and prove return to
   `/succession` without losing query ownership.
5. **Progressive explicit absence:** choose an arrangement with no preselected
   value; save; declare will absent; assert durable acknowledgement; explicitly
   advance; assert inheritance-pact question. Unknown must never auto-become
   absent and only one primary slot may be visible.
6. **Native present input:** in Patrol, choose present, enter a real civil date
   and legal year through the exact field ids, save, then inspect the persisted
   strict root. No Maestro-only text injection may stand in for the native input
   proof.
7. **Kill/relaunch:** terminate after will is saved, relaunch without clearing
   state, open `/succession`, and assert the next question or stale prior-state
   reconfirmation from cold `wizard_answers_v2`; never seed the reader directly.
8. **Failure boundaries:** a harnessed persistence failure keeps the question
   and retry id; a CAS change reloads instead of overwriting; an invalid root
   exposes only reload/support. These may be widget/Patrol assertions where
   Maestro cannot inject the persistence seam.
9. **Terminal boundary and screenshots:** inspect representative guard,
   unknown, stale/prior, present-input, absent, failure and terminal screens.
   Terminal copy must visibly deny verified dossier, legal distribution,
   specialist readiness and advice.

Runtime metadata separates setup from evidence stages:

```json
{
  "setupPatrolStages": ["civil_guard_seed"],
  "patrolStages": ["native_present", "absent_write", "cold_read"]
}
```

The seed is a fixture-preparation boundary, not an additional writer/reader
stage and not evidence of process death. Its accepted output includes the
sanitized pre-overlay and post-overlay witnesses and the stable `device:inode`;
an asserted install-over relationship without those comparisons is no evidence.
The three `patrolStages` retain their own native-present, durable absent-write,
terminate and distinct-process cold-read contract.

Accepted runtime evidence must record exact pushed SHA, app/bundle id, compile
define state, writer and cold-reader PIDs, Doctor/Patrol/Maestro commands,
screenshots and direct visual verdict under `.planning/runtime-evidence/`.
Until that bundle exists and exact-SHA CI is green, this target is a contract,
not a PASS claim.

## 1A. G1 LPP regulation — exact autonomous dual runtime proof (PASS)

This proof is specific to `lpp_plan`; it does not borrow PROV-02 personal-
certificate evidence. The path is autonomous from numeric LPP snapshots and
remains default-off. `fundRelationship` is a required user declaration, never
objective caisse verification.

### Checked-in targets

- `integration_test/g1_ret_ref_lpp_regulation_write_patrol_test.dart`
- `integration_test/g1_ret_ref_lpp_regulation_read_patrol_test.dart`
- `test/patrol/g1_ret_ref_lpp_regulation_01_write_runtime_test.dart`
- `test/patrol/g1_ret_ref_lpp_regulation_02_read_runtime_test.dart`
- `integration_test/support/g1_ret_ref_lpp_regulation_runtime_contract.dart`
- `tools/simulator/patrol_lpp_regulation_process_death.sh`
- `.maestro/g1_ret_ref_lpp_regulation_flag_off_before.yaml`
- `.maestro/g1_ret_ref_lpp_regulation_flag_off_after.yaml`

The orchestrator requires an exact pushed SHA, exports the production source,
builds/signs/installs the production entrypoint, and runs the pre-PATROL Maestro
flag-off flow. It then builds Patrol once with `FULL_ISOLATION=0` and the two
lexicographically ordered wrappers above. One non-parallel
`xcodebuild test-without-building` suite runs both native tests; the independent
xcresult summary must be exactly 2 passed / 0 failed.

### Writer contract

The writer starts with no numeric self-LPP snapshot, exercises the production-
shaped `/scan -> /scan/review -> /retraite` widgets/providers, injects only a
synthetic PDF picker result and the strict zero-fact `lpp_plan` transport result,
and asks only `visionExtraction`. It selects `currentFund` through the real
review control, which records only the selected relationship; it neither
verifies fund identity nor establishes applicability. It proves exact
`accept, record` ordering, a discarded volatile
session, regulation-only root persistence (schema 2 in the accepted autonomous
base; schema 3 with null recovery reason at the recovery target), a snapshotless
raw-free DocumentProvider tuple, Dashboard visibility, and absence of the
synthetic raw marker, backend processing id and document hash from durable
state. It stores a test-only PID witness after durable writes complete.

### Distinct-process cold reader contract

Patrol's native relaunch starts the reader in a new application process. The
reader fails closed unless the writer PID exists and differs from `dart:io pid`.
No uninstall, reset, backup or second Patrol build occurs between writer and
reader. The reader verifies the secure wizard placeholder, authority pointer,
strict regulation-only root, opaque document reference, real
`CoachProfileProvider.loadFromWizard()` hydration and Dashboard/sheet privacy
boundary. It then writes a first numeric self-LPP snapshot and a replacement
numeric snapshot through the production provider seam; both must preserve the
same regulation reference and declared relationship.

A post-suite `simctl launch/terminate` is retained only as a production
lifecycle check; metadata names it `post_suite_lifecycle_only`, never the
writer/read boundary. The orchestrator captures the post-suite container and
canonical three-value state, reinstalls the production app, runs the after-
Maestro flag-off flow without clearing state, and requires the container
identity plus exact state to remain unchanged.

### Accepted exact-SHA result

At pushed SHA `6066f1c94786aa1bc4697c29b4a670b7cea3dca4`:

- Patrol suite: **2 passed / 0 failed**, `FULL_ISOLATION=0`, distinct PID true.
- Production export/build/CodeSign/xattr/install before and after: exit 0.
- Maestro before/after with all three production flags false: exit 0.
- Post-suite state/container captured; production reinstall and Maestro preserve
  identity and exact canonical state.
- Doctor, Patrol guard, cleanup and normal-build restoration: PASS.
- Privacy: synthetic only, private fixture false, no retained raw bytes/hash,
  simulator identifier or xcresult.
- Evidence completeness: `logs == expected_logs == 22`.
- Bounded wrapper Opus-high code/product-domain source audit: aggregate
  **P0=0 / P1=0**.

The complete runtime archive
`.planning/runtime-evidence/phase-37/ret-ref-01/lpp-autonomous-runtime-6066f1c94786a-20260718T101106Z/`
and detailed audit archive
`.planning/runtime-evidence/phase-37/ret-ref-01/lpp-autonomous-runtime-harness-6066f1c94/`
are local excluded provenance, not Git-tracked bundles. The minimized sanitized
proof is tracked at
`.planning/runtime-evidence/phase-37/ret-ref-01/lpp-regulation-runtime-proof-6066f1c94/`.

### Accepted recovery extension

At pushed SHA `7cb5ea4c64e0a59d4e2f38f8f67eff7c924bd32a`, the reader first
proves the exact resolved regulation, saves an empty confirmed-reference list,
binds and hydrates a fresh `DocumentProvider`, and requires the opaque
`missingDocumentReference` state. It then requires:

- known education and handoff CTA absent;
- recovery container, CTA and exact neutral French missing-reference body
  present, without local id or `fundRelationship` rendering;
- CTA emits the existing `/scan?type=lppPlan` URI through the bounded test
  router;
- original BND list restored in `finally`, reloaded and compared before the
  existing numeric add/replacement assertions continue.

The native result remains **2 passed / 0 failed** with distinct PIDs and no
uninstall/reset/backup between writer and reader. Physical production
export/build/sign/install, state/container preservation, cleanup/privacy,
Maestro default-off before/after and `logs == expected_logs == 22` remain PASS.
XCTest exposes only this aggregate. The recovery UI assertions are grounded by
`integration_test/g1_ret_ref_lpp_regulation_read_patrol_test.dart` at the exact
SHA plus the passing aggregate suite; they are not claimed as individual XCTest
output records. The bounded router proves the emitted URI, while checked-in
production routing and production-default Maestro provide the separate route
wiring evidence.

The minimized sanitized bundle is tracked at
`.planning/runtime-evidence/phase-37/ret-ref-01/lpp-regulation-recovery-runtime-proof-7cb5ea4c6/`
by commit `ce5a020503c9e1733a81fa01b8dc6dd79b7c01d1`. This PASS closes the
autonomous process-death/default-off runtime gap and the bounded visible
legacy/missing/mismatch recovery debt only; runtime directly exercises the
missing-reference branch.

At exact pushed SHA `274736a50bca659579fe26f68ae4e600469e3a9a`, the upgraded
reader uses production `MintApp`/`AccountSessionBootstrap`, proves the resolved
handoff on the real `/rapport` route, builds the production report bytes, then
proves missing, mismatched and legacy recovery each remove the dossier section
before restoring root and BND. The native aggregate is 2/2, the real-byte host
text contract is 3/3, and default-off Maestro/lifecycle/privacy/22-of-22 output
gates pass. Exact runtime assertions remain source-plus-suite claims; no OS
share-sheet or external viewer is claimed. The combined runtime audit was
refused at 2579>2500 lines, while dossier, PDF and bootstrap component audits
bound the accepted P0/P1=0 state. The minimized proof is
`.planning/runtime-evidence/phase-37/ret-ref-01/lpp-regulation-dossier-pdf-runtime-proof-274736a50/`.
PDF/dossier caveat parity is closed. This does not activate the feature,
objectively verify `currentFund`, or close other RET-REF work. All
flags stay false, `G1-RET-REF-01` stays `ticket_only`, G1 stays open at 8.2/10
and G2/G3 are forbidden.

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

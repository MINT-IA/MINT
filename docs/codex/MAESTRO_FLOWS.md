# MAESTRO_FLOWS.md — E2E flows that PROVE the wiring (Codex-executable)

> **Status:** normative. Grounded in the REAL code at commit `255373b`.
> **Purpose:** every flow is a mechanical proof that the spine connects. **Green = wired.** A red flow names a real bug to fix (`WIRING_GRAPH.mmd` D-1..D-5).
> **appId:** `ch.mint.coach` (`android/app/build.gradle:50`).
> **Companions:** `DATA_LEDGER.md`, `SCREEN_CONTRACTS.md`, `WIRING_GRAPH.mmd`, `DATA_QUEST.md`.

## 0. Reality check — there is NO Maestro setup yet (build it)

- No `.maestro/` folder exists. Only `apps/mobile/integration_test/{persona_lea_test.dart, persona_marc_test.dart}` (reuse persona names **Lea**, **Marc**).
- Screens use `Semantics(...)` labels, **not** stable `Key('...')` (verified: near-zero `Key('...')` in `lib/`). **Maestro needs stable ids.** So Task M-0 below is a prerequisite: add the listed keys.

### Task M-0 — Setup + required keys to ADD (file : what)

Create `apps/mobile/.maestro/` and add these `Key(const ValueKey('...'))` (or `Semantics(identifier: '...')`) so flows are deterministic:

| id to add | file | element |
|---|---|---|
| `salary_input` | `screens/onboarding/data_block_enrichment_screen.dart` | net/gross salary field |
| `canton_picker` | same | canton selector |
| `coach_input` | `widgets/coach/coach_input_bar.dart` | chat text field |
| `coach_send` | same | send button |
| `retirement_gap_value` | `screens/coach/retirement_dashboard_screen.dart` | the projected gap number |
| `mortgage_afford_result` | `screens/…/affordability` (`/hypotheque`) | affordability verdict |
| `scan_review_recovery_cta` | `app.dart:903` builder (NEW errorState) | recovery button on `/scan/review` empty |
| `report_investment_card` | `screens/advisor/financial_report_screen_v2.dart:51` | investment action card |

> Convention: prefer `Semantics(identifier: 'id')` (Maestro reads it cross-platform) and keep the i18n visible label separate.

## 1. Happy-path flows (prove cross-screen data flow)

Each asserts: **data entered on screen A is visible/used on screen B** — i.e. the `CoachProfileProvider → MintStateProvider` spine works.

### F-1 first-job → retirement gap uses the salary
```yaml
appId: ch.mint.coach
---
- launchApp: { clearState: true }
- tapOn: { text: "Aller discuter" }        # / landing -> coach/anon
- tapOn: { id: "coach_input" }
- inputText: "je commence mon premier job à 4500 net"
- tapOn: { id: "coach_send" }
- assertVisible: { text: "3e pilier" }       # coach explains, no product named
- runFlow: goto_retirement                    # navigate to /retraite
- assertVisible: { id: "retirement_gap_value" }
# PROOF: the gap reflects the salary just entered (not the empty-profile default)
- assertVisible: { text: "4'500" }            # salary echoed in the projection basis
```

### F-2 salary entered in data-block is visible in mortgage affordability
```yaml
appId: ch.mint.coach
---
- launchApp: { clearState: true }
- openLink: "mint://data-block/revenu"        # /data-block/:type
- tapOn: { id: "salary_input" }
- inputText: "8000"
- tapOn: { id: "canton_picker" }; tapOn: { text: "Genève" }
- back
- openLink: "mint://hypotheque"               # /hypotheque
- assertVisible: { id: "mortgage_afford_result" }
# PROOF: affordability used the 8000 salary + GE canton from the ledger, not extra
```

### F-3..F-5 (same shape, one per priority event)
- **F-3 retirement** (`/retraite`): enter LPP balance in coach → assert `/rente-vs-capital` uses it.
- **F-4 buying property** (`/hypotheque`): enter savings → assert affordability verdict changes.
- **F-5 transmitting property** (`/succession`): enter property value → assert the CASE guardQuest (DATA_QUEST §5) shows the parents' retirement-affordability note **before** any gift result.

## 2. Regression flows (each targets a REAL dead road — must go green after fix)

### R-1 /scan/review with no extra must NOT trap (D-1)
```yaml
appId: ch.mint.coach
---
- launchApp: { clearState: true }
- openLink: "mint://scan/review"              # no extra payload (deep link)
- assertNotVisible: { text: "Document non disponible" }   # the blank trap
- assertVisible: { id: "scan_review_recovery_cta" }        # recovery exists
- tapOn: { id: "scan_review_recovery_cta" }
- assertVisible: { text: "Scanner" }          # lands back on /scan, not stuck
```
**Today: FAILS** — `app.dart:903` renders `Scaffold(Text('Document non disponible'))`, no CTA. Fix per `SCREEN_CONTRACTS.md` errorState + `WIRING_GRAPH` I-2.

### R-2 /scan/impact no extra (D-2) — same shape as R-1.

### R-3 financial-report investment card reaches an actionable destination (D-4)
```yaml
appId: ch.mint.coach
---
- launchApp: { clearState: false }
- openLink: "mint://rapport"
- tapOn: { id: "report_investment_card" }
- assertNotVisible: { text: "Comment puis-je t'aider" }  # generic context-less coach = bug
- assertVisible: { text: "3e pilier" }                    # topic context preserved
```
**Today: FAILS** — `financial_report_screen_v2.dart:51` → `/tools` → `/coach/chat` context-less (`app.dart:1185`).

### R-4 kill + restart mid-flow keeps data (spine persistence)
```yaml
appId: ch.mint.coach
---
- launchApp: { clearState: true }
- openLink: "mint://data-block/revenu"
- tapOn: { id: "salary_input" }; inputText: "8000"; back
- stopApp
- launchApp: { clearState: false }            # cold start reloads wizard_answers_v2
- openLink: "mint://hypotheque"
- assertVisible: { id: "mortgage_afford_result" }   # 8000 survived restart
```
**Today: PASSES** (persistence works) — keep as a guard against regressions.

### R-5 /portfolio?param keeps the param (D-5)
```yaml
appId: ch.mint.coach
---
- launchApp: { clearState: false }
- openLink: "mint://portfolio?tab=1"
- assertVisible: { text: "Mon argent" }       # maps to /mon-argent tab 1, param honoured
```
**Today: FAILS** — `app.dart:1189` `/portfolio` → `/home`, param dropped.

## 3. Acceptance criteria (Codex/CI)

- **M-1** `.maestro/` exists; `maestro test .maestro/` runs in CI.
- **M-2** All F-1..F-5 green ⇒ the spine connects across screens.
- **M-3** All R-1..R-5 green ⇒ every verified dead road is closed.
- **M-4** Each flow uses a stable id from Task M-0 (no reliance on volatile visible text except localized asserts).
- **M-5** A newly added screen without F-/R- coverage fails the "every live route has ≥1 flow" check (cross-ref `SCREEN_CONTRACTS.md`).

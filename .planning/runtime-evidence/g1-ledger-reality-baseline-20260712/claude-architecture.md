# Current architecture audit wave — AVS certified-null hard floor

Date: 2026-07-13

Scope: current G1-LDG-06A quarantine only. This PASS does **not** close G1 and
does not authorize G2 or G3.

## Opus first pass

- Command: `CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high tools/checks/claude_external_audit.sh architecture`
- Base: not applicable in architecture mode.
- HEAD observed: `67c99ca2888c122a09ce261a84afb327533904cc`.
- Verdict: **PASS**, with no P0/P1 and actionable P2 findings.

Findings and disposition:

| finding | disposition |
|---|---|
| `cap_sequence_engine.dart` computed `maxRente * contributionYears / 44` into a dead/write-only `CapStep.impactEstimate`; the original contract did not detect this indirect consumer. | Closed by `689349070edfab0a904b21c434475e069b387a61`; AVS now remains `upcoming`, routes to `/scan/avs-guide`, and carries no synthetic impact. The repo-wide proxy detector and negative seed were added in `83f7024fe1d42a051093802048cb1c7b55195291`. |
| The dead calculation was a facade risk if a future renderer surfaced it; the backend `/retirement/avs/estimate` was also noted as unwired. | The mobile value-flow was removed rather than merely hidden. The unwired backend endpoint was not promoted into a live G1 consumer. |
| The blocking-ticket registry still labelled implemented G1-LDG-06A and G1-AVS-01 contracts `ticket_only`; G1-AVS-02 was correctly still ticket-only. | **Open documentation reconciliation at this capture.** The registry must be updated from executable proof; this audit does not claim that reconciliation or G1 completion. |

The first-pass terminal output was not retained as a `/tmp` transcript; the
table above is the lead-observed finding/disposition record, not a claimed
verbatim Claude transcript.

## Sonnet same-gate rerun

- Command: `CLAUDE_AUDIT_RERUN=1 CLAUDE_AUDIT_MODEL=sonnet CLAUDE_AUDIT_EFFORT=high tools/checks/claude_external_audit.sh architecture`
- Base/scope start: `3989e10a734ec247861564c2155067e5291f3e15` as
  reported by Claude.
- HEAD audited: `83f7024fe1d42a051093802048cb1c7b55195291`.
- Durable normalized transcript (trailing Markdown line-break spaces removed):
  `claude-architecture-sonnet-rerun-83f7024fe.txt`
  (`sha256:3cb321e43a4a22e37ce99cf474c92b33abae7cb1ab8f1885d480a71503e5df9a`).
- Verdict: **PASS** for the quarantine, with two P1 findings that had to be
  closed before any AVS-derived G2 work.

Findings and disposition:

| finding | disposition |
|---|---|
| P1: `expat_service.dart` still formed a maximum-pension × completeness proxy through an intermediate variable, outside the regex inventory. | Closed at the service boundary by `88e1fe524c32c39feb22521a9d05704e63f1fd3a`: `scenarioStarted` is mandatory and false returns null before any formula. `667f12d45c299651d573866925f0bc4dd53db90e` enforces the complete opt-in chain in the hard floor. |
| P1: `cap_sequence_engine.dart` used `gross * 0.78` and `annualGross * 4.5` outside `financial_core`. | Closed by `6191ef450343ba74c1c664439b1b445848e80f13`: canonical net-income and mortgage-capacity SOTs are used, with missing inputs preserved as unknown. |
| P2: the certified-null hard floor is CI-visible but not a dedicated Lefthook command. | Open tooling debt; CI and explicit local command remain authoritative for this slice. |
| P2: unknown retiree income has no dedicated user-facing disclosure flag. | Open product debt; no legacy AVS amount is re-enabled to mask it. |
| P2: `_estimateFreeMontly` typo. | Closed in `6191ef450343ba74c1c664439b1b445848e80f13`. |

No final Opus architecture confirmation was launched because it was not
warranted after the bounded repairs: the no-carousel rule avoids optional
reruns, and the remediated implementation was checked by the independent Opus
code and product-domain lenses at HEAD
`667f12d45c299651d573866925f0bc4dd53db90e`.

---

# Historical architecture evidence — superseded snapshots

Command: `CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high tools/checks/claude_external_audit.sh architecture`

Date: 2026-07-12 13:16:31 CEST

SHA at completion: `4e9d4f45b24aca644c3592ec5a572909964ad2f9`

---

# MINT External Audit — Architecture Mode

**Scope:** G1 "Ledger Reality Baseline" phase evidence (`.planning/goals/G1-*`, the two hard-floor gates, `scan_session_provider`, confidence adapter). Read `AGENTS.md`, `CLAUDE.md`, `docs/MINT_AGENT_WORKFLOW.md`, `G1-ledger-reality-baseline-2026-07-12.md`, and challenged them against live code and live test runs.

## Verdict: **NO-GO**

The gates and matrices are substantively real (not facade), but the phase cannot be certified: the evidence is uncommitted, was mutating during the audit, both hard-floor gates were RED when I started, and G1's own required scorecard deliverable is absent.

---

## P0 — Blocking

### P0-1 Hard-floor gates were RED at audit start; only went green via edits made *during* the audit, and nothing is committed
G1 acceptance requires both gates "executable and green" (`G1-ledger-reality-baseline-2026-07-12.md:239-245`). At the first run:

- **`test_g1_p0_ledger_dead_keys.py`** → 2 of 3 FAILED: `AssertionError: G1 blocking ticket registry is missing` because `.planning/goals/G1-blocking-gate-tickets.md` did not exist (`test_g1_p0_ledger_dead_keys.py:167`). The file was created mid-session; a re-run then passed 3/3.
- **`no_scenario_writeback_to_profile_test.dart`** → 2 of 3 FAILED against live `rente_vs_capital_screen.dart` / `epl_screen.dart` (`_writeBackResult`, `projectedRenteLpp:`, `projectedCapital65:`, `targetRetirementAge: _ageRetraiteSlider`). Those screens were edited mid-session (mtime jumped to `13:11:43`, file `_writeBackResult` disappeared); a re-run then passed 7/7.

Reproduction: the working tree changed under a running audit — `tools/checks/tests/test_g1_p0_ledger_dead_keys.py` was momentarily reported "file or directory not found" between runs; `git status` grew from 8 to 18 dirty entries.

### P0-2 The entire phase deliverable is uncommitted; branch HEAD is docs-only
`git show --stat HEAD` → *"HEAD touches NO code files"* (`4e9d4f45b docs(g1)…`). All gates, `scan_session_provider.dart`, fixtures, the ticket registry, and the product-screen fixes live only in a dirty tree (18 uncommitted paths). Per `AGENTS.md:115-117` ("Verify the diff, not the explanation") and the G1 DoD ("Commits are atomic and pushed", `:258`), there is no reproducible, reviewable artifact to certify. An auditor cannot PASS a moving, uncommitted target.

---

## P1

### P1-1 Required G1 scorecard is missing
G1 mandates `.planning/runtime-evidence/g1-ledger-reality-baseline-20260712/SCORECARD.md` listing commands, gate status, verdicts, unresolved P1/P2, and G2-go decision (`G1-…baseline…md:145-155`, `:251-253`). That directory contains only `agent-data-ledger.md` and `agent-swiss-product.md` — **no SCORECARD.md**. G1's own "whether G2 is allowed to start" decision has no checked-in home.

### P1-2 `ledger_dead_key_test` is doc-validates-doc, not a dead-key detector
`test_g1_p0_ledger_dead_keys.py` only checks the *matrix's internal self-consistency* — that `write_path`/`reader_evidence`/`consumers` columns are non-empty for `live` rows (`:135-144`) and that tickets are registered. It never greps `CoachProfile`/Dart/Python to confirm a "live" key has a real reader. A matrix row asserting `status=live` with a fabricated `reader_evidence` string passes. The gate's name promises code-truth; its mechanism guarantees only doc-truth — the exact "don't trust docs blindly" risk. To actually enforce dead-key safety it must cross-check `reader_evidence` against a grep of the codebase (the negative fixture proves the parser, not the code linkage).

---

## P2

### P2-1 Confidence adapter carries the `source_crosswalk` bug it defers to a ticket
`enhanced_confidence_service.dart` `computeFromCoachProfile` uses three inconsistent identifiers for the same property fact:
- `fact('patrimoine.propertyMarketValue', ['propertyMarketValue'], profile.patrimoine.immobilierEffectif)` → stored under `profileMap['property_value']`;
- `_confidenceFieldName` maps `'patrimoine.valeurImmobiliere' → 'property_value'`;
- the real field is `propertyMarketValue` (`coach_profile.dart:733`), and `dataSources`/`userProvidedFields` use bare `'propertyMarketValue'` (`coach_profile.dart:3205`).

Consequence: `proven('patrimoine.propertyMarketValue', …)`'s `dataSources.containsKey` branch can never match the real key, and a `FieldSource` built from `dataSources['propertyMarketValue']` resolves `profileMap['propertyMarketValue']` = null (the map key is `property_value`), so a genuinely-sourced property fact can be scored as absent/valueless. This is precisely the `source_crosswalk_test` class G1 lists as ticket-only/unimplemented — the drift already exists in shipped-path code.

---

## What is genuinely sound (not facade)
- `ScanSessionProvider` is fully wired: registered (`app.dart:1530`), written (`document_scan_screen.dart:101`, `avs_guide_screen.dart:487`), read with a real degraded state (`app.dart:1011-1016` → `_buildScanRecoveryScaffold`), and `scanSessionId!` is null-guarded. Routes now carry only an id — a real fix to the `/scan/review`,`/scan/impact` extra-payload offenders.
- No `state.extra as <domain>` or `.extra['…']` casts remain anywhere in `apps/mobile/lib` (grep clean), so the extra-data invariant currently holds in fact, not just in the test.
- `python3 tools/checks/mint_os_doctor.py --repo-only` → all repo contracts PASS.

## To turn this PASS
1. Commit the full G1 slice atomically; re-run both gates from a clean tree and paste red→green evidence.
2. Add the required `SCORECARD.md` with the G2-go decision.
3. Strengthen `ledger_dead_key_test` to cross-check `reader_evidence` against an actual code grep, or explicitly rename/rescope it as a matrix-consistency gate and ticket the code-linkage check.
4. Fix or ticket the property-path crosswalk in the confidence adapter.

Evidence commands: `python3 -m pytest tools/checks/tests/test_g1_p0_ledger_dead_keys.py -q`; `flutter test test/routing/ test/services/enhanced_confidence_profile_adapter_test.dart` (run from `apps/mobile`); `git show --stat HEAD`; `ls .planning/runtime-evidence/g1-ledger-reality-baseline-20260712/`.

## Architecture rerun after fixes

Command: `CLAUDE_AUDIT_RERUN=1 CLAUDE_AUDIT_MODEL=sonnet CLAUDE_AUDIT_EFFORT=high tools/checks/claude_external_audit.sh architecture`

Date: 2026-07-12 13:35:48 CEST

SHA: `0d0950181dfb0e09370ff45e0c1f0d223315e006`

---

I now have enough evidence across code, tests, and docs. Let me consolidate the final verdict.

---

## MINT Architecture Audit — G1 Phase Evidence

**Audit date:** 2026-07-12
**Branch:** `codex/mint-product-usability-plan-20260712`
**HEAD commits reviewed:** `0d0950181`, `c7260e7f6`, `4e9d4f45b`, `b8b22570d`, `2433023c5`

---

## Verdict: **NO-GO**

G1 has made genuine mechanical progress and all three self-declared P0 blockers are fixed, but the phase deliverable does not satisfy its own acceptance criteria and one uncovered P1 violation of the checked-in provider boundary decision remains without a blocking ticket.

---

## Findings

### P0 — Must resolve before G1 can be declared complete

**P0-1: G1 acceptance criteria not fully met — no runtime evidence, no final scorecard**

The `G1-blocking-gate-tickets.md` (lines 57–66) explicitly states:

> `G1 baseline deliverable: eligible only after hard floors, both external audit lenses, runtime evidence, and the final scorecard are GREEN; this registry alone does not declare G1 complete.`

Verified present:
- Four matrices ✓ (ledger-gap, provider-boundary, scenario-lever, route-state)
- Hard-floor tests GREEN ✓ (`test_g1_p0_ledger_dead_keys.py` 3/3, `no_domain_data_in_extra_test.dart` 4/4, `no_scenario_writeback_to_profile_test.dart` 3/3)
- P0 G1 mechanical blockers fixed ✓ (confirmed by grep + test runs)

Not present:
- Runtime evidence — no Maestro or Patrol composite artifact for G1-RUNTIME-01; `.maestro/r4_persistence.yaml` and `integration_test/g1_p0_persistence_patrol_test.dart` are both MISSING from disk
- Final scorecard document — no checked-in scorecard at any path
- `product-domain` audit lens — not recorded

This is self-declared debt (the registry says `G2 allowed? NO`), but it does mean G1 cannot be closed.

**P0-2: `/rapport` route violates the checked-in provider boundary decision without a covering ticket**

`G1-provider-boundary.md` (line 25) states as a binding architecture decision:

> `wizard_answers_v2 is not a screen read API. Screens read CoachProfile or MintUserState.`

Live code at `app.dart:1085–1098`:
```dart
future: ReportPersistenceService.loadAnswers()
    .timeout(const Duration(seconds: 8)),
builder: (ctx, snapshot) {
  return FinancialReportScreenV2(
    wizardAnswers: snapshot.hasError ? const {} : snapshot.data ?? {},
  );
},
```

`financial_report_screen_v2.dart:83–84` then derives safety-critical state from the wizard map:
```dart
final report = reportService.generateReport(wizardAnswers);
final hasDebt = WizardService.isSafeModeActive(wizardAnswers);
```

The comment at line 29 explicitly records the intent: `// ProfileProvider removed — hasDebt now derived from wizardAnswers directly`. That means `hasDebt` — which gates safe mode — is read from an untyped persistence map, not from `CoachProfileProvider`.

The `no_domain_data_in_extra_test.dart` does **not** catch this because it only scans for `state.extra as ...` patterns. The wizard-map path enters through `ReportPersistenceService`, bypassing every checked pattern.

No blocking ticket covers this violation. G1-BND-01 covers the five legacy `ProfileProvider` consumers; the wizard-answers-as-screen-API pattern is separate and untracked.

**Reproduction path:**
1. `grep -n "wizardAnswers\\|ReportPersistence" apps/mobile/lib/app.dart` → lines 1086, 1095
2. `grep -n "wizardAnswers" apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart` → 10 hits; `hasDebt` from wizard map at line 84
3. `cd apps/mobile && flutter test test/routing/ --reporter expanded` → all 11 pass; none detect the wizard-map pattern

---

### P1 — Blocks G2; documented debt, must have exact ticket coverage

**P1-1: 22 of 22 blocking behavioral tests are `ticket_only` / missing from disk**

Filesystem check confirms: every test file referenced in the 22 `G1-blocking-gate-tickets.md` rows is absent. No behavioral predicate (provenance-on-write, scenario isolation, dead-key roundtrip, stale/reconfirmation, returnUri, provider bridge recompute, source crosswalk, runtime persistence) has any implementation on disk.

The `test_every_matrix_ticket_has_an_executable_blocking_contract()` Python test passes because it validates ticket shape and `status == "ticket_only"` — it does not check whether the commands it validates would succeed if run. Running any `green_command` from the registry today would fail immediately with "file not found."

This is expected at G1 but means every one of the following P0 loops is unsafe to build until the tickets are implemented: WORK, HOUSING, RETIREMENT, DISABILITY, SUCCESSION, FRONTALIER.
`G2 allowed? NO` — consistent with self-assessment.

**P1-2: Five live `ProfileProvider` consumers (G1-BND-01 ticket_only)**

Confirmed by `grep -rn "ProfileProvider\\b" apps/mobile/lib/` excluding `CoachProfileProvider`:

| File | Line | Pattern |
|---|---|---|
| `screens/independants/ijm_screen.dart` | 97 | `_readProfileProvider(context)` |
| `screens/simulator_3a_screen.dart` | 197 | `context.read<ProfileProvider>()` |
| `screens/simulator_3a_screen.dart` | 301 | `context.watch<ProfileProvider>()` |
| `widgets/comparators/pillar3a_comparator_widget.dart` | 29 | `context.watch<ProfileProvider>()` |
| `widgets/simulators/buyback_widget.dart` | 39 | `context.watch<ProfileProvider>()` |
| `widgets/recommendation_card.dart` | 17 | `context.watch<ProfileProvider>()` |

`ProfileProvider` remains registered at `app.dart:1519`. Ticket G1-BND-01 covers this but is `ticket_only`. Blocks G2.

**P1-3: `DataBlock` coach-mode toggle loses `returnUri` (confirmed live)**

`data_block_enrichment_screen.dart:189`:
```dart
context.go('/coach/chat?topic=${Uri.encodeComponent(canonicalBlockType)}');
```

No `returnUri` is appended. After coach chat, the originating Case is lost. Documented in the route-state matrix as P1. No dedicated blocking ticket exists for this specific CTA.

**P1-4: `G1-route-state-matrix.md` internal verdict is stale after the fix commits**

The matrix (`4e9d4f45b`) says: *"G1 overall: not yet complete because the two hard-floor gates are not checked in."* The fix commits (`0d0950181`, `c7260e7f6`) then checked those gates in. The matrix self-assessment is now stale and could mislead the next audit pass into treating an already-fixed condition as still open.

---

### P2 — Technical debt / documentation gaps, no G2 block

**P2-1: Hard-floor test scope is narrower than its name implies**

`no_domain_data_in_extra_test.dart` scans only `app.dart` and four named product screens for `state.extra` casts. It does not scan:
- Other screens using `state.extra` for domain payloads
- Widgets constructing with domain data passed as builder arguments (the `/rapport` anti-pattern above)

The test name promises "domain data" coverage; the implementation covers `state.extra` casts. This gap explains how P0-2 above is not caught.

**P2-2: `avoirLpp` (quarantined) and `hasAvsGaps` (quarantined) P0 keys have no interim fail-closed guard in live code**

Both keys are listed as `quarantined` in the canonical matrix, meaning "aliases can disagree without a deterministic canonical winner." No Dart-side guard currently rejects or arbitrates between conflicting storage keys at read time. The matrix notes this correctly as `quarantined` and tickets `G1-LDG-07` / `G1-LDG-06`, but until the tickets are implemented, scenarios that read these keys silently pick whichever alias is populated first.

---

## What IS confirmed working

| Item | Evidence |
|---|---|
| `state.extra` domain cast removal from all four hard-floor routes | `no_domain_data_in_extra_test.dart` 4/4 GREEN + `app.dart:986` only remaining `extra` use is `DocumentType` (an enum) |
| Scenario-to-fact write removal from `/epl` and `/rente-vs-capital` | `no_scenario_writeback_to_profile_test.dart` 3/3 GREEN + grep confirms no `avoirLppTotal`, `projectedCapital65`, `_writeBackResult` writes |
| `ScanSessionProvider` in-memory boundary | Registered at `app.dart:1529`; `scan_session_provider_test.dart` 3/3 GREEN; recovery scaffold tested with widget + semantics proof |
| `/confidence` route now derives from `CoachProfileProvider` | `app.dart:1305–1308` uses `CoachProfileConfidenceAdapter.compute(profile)`; `enhanced_confidence_profile_adapter_test.dart` 4/4 GREEN |
| G1 ledger-gap matrix machine-parseable | `test_g1_p0_ledger_dead_keys.py` 3/3 GREEN; reader evidence validated against live file lines |
| Ticket registry structurally complete | 22 tickets, all with non-empty `red_command`, `green_command`, `failing_predicate`, `fixture_input`; required gate names present |
| Negative fixture proves test is non-vacuous | `test_negative_fixture_proves_...` GREEN; duplicate, silent-dead, missing-ticket, bad reader-evidence all caught |

---

## Actions required to convert to PASS

1. **Mandatory for G1 close:**
   - Add a blocking ticket for the `/rapport` wizard-answers-as-screen-API violation (`G1-RPT-01` or equivalent), targeting `app.dart` builder migration to read `CoachProfileProvider`/`MintStateProvider`.
   - Add a blocking ticket for the `DataBlock` `returnUri` loss on coach-mode toggle.
   - Update `G1-route-state-matrix.md` internal verdict to reflect that hard-floor gates are now checked in (line "not yet complete because...").
   - Record runtime evidence for the `/succession` and `/disability` Patrol tests already cited (they exist at `test/patrol/`) or mark them as G1-RUNTIME-01 scope.

2. **Before G2 can start (G1-RUNTIME-01 specifically):**
   - Create `.maestro/r4_persistence.yaml` and `integration_test/g1_p0_persistence_patrol_test.dart` — the runtime persistence proof the ticket registry declares but which don't exist on disk.

3. **Before any P0 behavioral loop (all 22 ticket_only tests):**
   - Implement behavioral tests in the declared order; each green command must pass before G2 authorisation is granted.

## Final Opus architecture confirmation

Command: `CLAUDE_AUDIT_RERUN=1 CLAUDE_AUDIT_ALLOW_NON_SONNET_RERUN=1 CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high tools/checks/claude_external_audit.sh architecture`

Date: 2026-07-12 14:03:36 CEST

SHA: `53c73382734b92b218961d27efc060d20cbdb877`

Exit code: `0`

---

# MINT External Architecture Audit — G1 "Ledger Reality Baseline"

**Mode:** architecture · **Branch:** `codex/mint-product-usability-plan-20260712` · **HEAD:** `53c733827` (clean, synced to origin)
**Scope audited:** the G1 phase evidence — four matrices, two hard-floor gates, blocking-ticket registry, runtime evidence, and the SCORECARD — challenged against live code and live test runs.

## Verdict: **PASS**

G1 is a mapping/baseline phase that deliberately does **not** fix the six P0 loops; it makes them safe to build and gates G2 to `NO`. Measured against that scope, its own acceptance criteria are met, the mechanical gates are real and non-vacuous, and the self-reported "8.9/10 CONDITIONAL HOLD pending architecture Opus" resolves: this is that architecture pass, and it clears. Every P0/P1 from the prior architecture (Sonnet rerun) and product-domain audits is resolved in live code, not just claimed.

---

## What I verified against live code (not docs)

| Claim | Verification | Result |
|---|---|---|
| `ledger_dead_key_test` green + reads keys from matrix | Ran `test_g1_p0_ledger_dead_keys.py` → **3 passed**; test parses `G1-ledger-gap-matrix.md` and validates each P0 row's `reader_evidence` against a real `file.dart:line` whose ±5-line window contains a key-derived semantic token (`test_g1_p0_ledger_dead_keys.py:126-163`) | Real code-linkage, not doc-validates-doc |
| Hard-floor gates non-vacuous | Both `.dart` gates carry seeded-violation self-tests (`no_domain_data_in_extra_test.dart:22-34`, `no_scenario_writeback_to_profile_test.dart:21-28`); negative fixture asserted in Python (`:271-282`) | Non-vacuous |
| 20 G1/offender routes exist | Grepped each against `route_metadata.dart` | All 20 present |
| `/rapport` provider-boundary fix (prior P0-2) | `app.dart:1084-1101` now reads `context.watch<CoachProfileProvider>()` + `waitForReportAnswers()`; no `ReportPersistenceService.loadAnswers` in route block; `rapport_provider_boundary_test.dart` enforces it | Real fix at route boundary |
| Mortgage write-back to `patrimoine` (product-domain P1) | Only `patrimoine` reference in `affordability_screen.dart` is a **read** (`:80`); the "outputs" at `:128-131` go to `ScreenReturn`/`ScreenCompletionTracker` (session), not `CoachProfile`. No `copyWith`/`saveAnswers`. | Not present in live code |
| Runtime evidence genuine | Maestro R1/R2 logs show real iPhone 17 Pro runs with `COMPLETED` asserts + screenshots; Patrol `ios_results.xcresult` bundle present | Genuine artifacts |
| Prior P1s (returnUri loss, stale matrix verdict) | `G1-RETURN-01` ticket now covers DataBlock returnUri; route-state matrix verdict updated to "hard floors checked in and green" | Resolved |
| Repo contracts | `mint_os_doctor.py --repo-only` PASS; 18 deterministic contract tests pass; 23 blocking tickets, `G2 allowed? NO` | Consistent |
| Prior P0 "uncommitted moving target" | Tree clean at `53c733827`, all G1 artifacts committed | Resolved |

The matrices honestly document every live violation with `file:line` + severity + `blocks_G2=yes` (e.g. `/hypotheque` local sliders `_revenuBrut=120000`/`_avoirLpp=200000` classified `durable_fact` + `local-slider`, `G1-route-state-matrix.md:66`; `/rente-vs-capital` compute-from-defaults marked **P0**, `:70`). This is the correct G1 posture: map reality, quarantine the loops, block G2.

---

## Findings

### P0 — none

### P1 — none unresolved
All prior-audit P0/P1 findings are fixed in live code and the tree is committed and clean. The 23 behavioral gates remain `ticket_only` by design; each has an exact failing predicate + red/green command and `blocks_G2=yes`, correctly holding `G2 allowed? NO`.

### P2 (do not block G1 close; carry into G2 triage)

- **P2-1 — `no_domain_data_in_extra_test` name broader than scope.** It scans only `state.extra as <domain>` casts in `app.dart` + 4 named screens (`no_domain_data_in_extra_test.dart:36-79`). The real `/rapport` and `/confidence` boundary risks are *not* `state.extra` casts and are covered by *separate* tests. The gate's name over-promises; coverage is real but split. (Same gap both prior audits flagged.)
- **P2-2 — Runtime evidence captured at `0d0950181`, three commits behind HEAD `53c733827`.** The scan-recovery Maestro flows are unaffected by the later `fix(g1)`/`test(g1)` commits, but the runtime proof is strictly not at the shipped SHA. `runtime-proof.md:4` discloses this honestly.
- **P2-3 — Confidence adapter property-value crosswalk.** `coach_profile_confidence_adapter.dart` keys `property_value` on marker `patrimoine.propertyMarketValue` but reads `patrimoine.immobilierEffectif`; market vs effective valuation conflated. Display-only (`/confidence`), no P0-loop financial output impact. Already ticketed as the `source_crosswalk` class + `G1-P2-PROPERTY-01`. Confirmed by both code and product-domain lenses.

---

## Evidence gap I did not close

I did **not** re-run the full Flutter suite. The SCORECARD's "`+8500 ~26`, exit 0" and the `no_*_test.dart` green claims rely on the prior independent Sonnet run plus my inspection for non-vacuity and my green Python-gate run. To fully prove the Flutter side at HEAD, the closing command is:
```
cd apps/mobile && flutter test test/routing/ test/routes/ test/providers/ \
  test/services/enhanced_confidence_profile_adapter_test.dart
```

## Disposition
G1 baseline is real, mechanically enforced, honestly scored, and correctly gates G2 to `NO`. The one remaining SCORECARD gate (architecture Opus) is satisfied by this **PASS**. G1 may close; the 23 behavioral tickets must be implemented before any G2/G3 P0-loop work begins. Recommend closing P2-2 by refreshing runtime proof at HEAD before tagging the phase.

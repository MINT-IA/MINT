# Product-domain Sonnet rerun — evidence triage

Date: 2026-07-14
Role: `mint-quality-gate`
Audit transcript: `product-domain-sonnet-rerun.txt` (wrapper exit `0`)
Audit verdict: `PASS`, with three P1 and four P2 observations
Reviewed committed HEAD: `5c774caf85e25911ed562b73ffabcaa1afb87aa4`

## Runtime and SHA boundary

The retained device proof is **exact only for**
`e8c0263acb6ddad9b5acafd889193c4caf4909f3`:

- `runtime-exact-sha/sha-before.txt` = `runtime-exact-sha/sha-after.txt` =
  `e8c0263acb6ddad9b5acafd889193c4caf4909f3`;
- both status boundary files are zero bytes;
- Patrol is `1/1` passed and Maestro exits `0` on that exact tree.

`5c774caf85e25911ed562b73ffabcaa1afb87aa4` is a descendant of `e8c0263ac`
and changes the documented CI branch (typed names, calculation, copy, tests and
maps). It does not have a new exact-SHA device run in this evidence bundle.
Consequently this report does not relabel the `e8c0263ac` runtime proof as a
`5c774caf8` proof and does not close global `G1-RUNTIME-01`.

## Finding-by-finding disposition

| Finding | Disposition | Evidence-backed quality decision |
|---|---|---|
| P1-1 — guide CTAs may be a facade | **False positive / closed** | Both semantic IDs exist on real enabled buttons. Their handlers call two distinct official URI helpers. A widget test taps both buttons through an injected URI opener and asserts the exact CI hub and locale-specific 318.282 URLs. The Expat CTA really executes `context.push('/scan/avs-guide')`. The exact `e8c0263ac` runtime proof independently reached both controls with Patrol and Maestro. Visibility is therefore not the only evidence. |
| P1-2 — `selfCertifiedYears` provenance unverified | **False positive / closed fail-closed** | `CoachProfile.avsGapEvidence` exposes `selfCertifiedYears` only when `prevoyance.lacunesAVS` is in `0..44` **and** its field source is `ProfileDataSource.certificate`. Declaration/status/years-abroad tests prove manual facts remain unavailable. Reviewed AVS extraction is the live in-memory promotion path. Legacy persistence currently downgrades this field to `estimated` after reconstruction, so PROV-01 can reduce availability but no manual fact becomes CI-observed. See `../LEDGER_SONNET_FINDINGS_VERDICT.md`. |
| P1-3 — public gap-only personal-effect helpers/callers remain | **Confirmed and broader; blocking G1 ticket, not fixed** | Production mobile callers render personal `rente -X%`, `-2.3% à vie`, score tiers and CHF/lifetime claims; the live backend `POST /api/v1/expat/avs-gap` also prices monthly/annual effects from insufficient inputs. Both gap-only helpers remain public. The uncommitted registry work creates cross-stack `G1-AVS-03` as `ticket_only` to remove/quarantine those effects and any orphan facade. Until its canonical backend+mobile RED→GREEN command passes, this P1 remains unresolved and blocks final G1 acceptance. |
| P2-1 — universal 44 denominator for legacy cohorts | **Partly confirmed; audit rationale corrected; covered by blocking G1-AVS-03** | Official 2026 sources confirm 43 full contribution years for women born **before 1964** (not only before 1961), while a full 43-year duration can still produce scale 44. Therefore neither `4/43` nor `4/44` is a personal pension loss. The current globally named `full_contribution_years=44` cannot represent every user's class-of-age duration. Swiss verdict recommends count-only CI years and no percentage in this flow. See `../SWISS_SONNET_FINDINGS_VERDICT.md`; ticket remains `ticket_only`. |
| P2-2 — missing `avs-guide -> scan` wiring edge | **Confirmed and fixed in working-tree cartography** | The real guide scan action executes `context.push('/scan', extra: DocumentType.avsExtract)`. `docs/codex/WIRING_GRAPH.mmd` now adds `SCANAVS --> SCAN`; Mermaid render and route/spec contract tests pass. See `../LEDGER_SONNET_FINDINGS_VERDICT.md`. This fix was not yet committed at the reviewed HEAD. |
| P2-3 — `expat_avs_tab` semantic ID may not propagate | **False positive / closed** | The focused widget test resolves exactly one `find.bySemanticsIdentifier('expat_avs_tab')`. More importantly, exact-SHA Patrol found and tapped that identifier and Maestro `tapOn: id: expat_avs_tab` completed on iOS. The post-runtime `5c774caf8` change only renames the CI argument at the two `expat_screen.dart` call sites; it does not modify the tab semantics. |
| P2-4 — copy hardcodes 44 while calculation uses registry | **Confirmed; covered by blocking G1-AVS-03, not fixed** | The six ARB strings hardcode 44 while `rawContributionDurationGapPercent` reads `avs.full_contribution_years`; `AvsGapAssessment` does not carry the denominator. Swiss verdict recommends removing the percentage (count-only). A retained general scale reference would require one typed object carrying numerator, dedicated regulatory denominator, percentage and legal date, with no hardcoded ARB denominator. Ticket remains `ticket_only`. |

## Commands and results

The quality gate executed the following against committed HEAD
`5c774caf85e25911ed562b73ffabcaa1afb87aa4` plus the concurrent, uncommitted
cartography/ticket evidence explicitly identified above.

```bash
python3 tools/checks/mint_os_doctor.py --repo-only
# PASS: Patrol, Maestro, Mermaid, Claude wrapper, workflow, iOS plist gates

cd apps/mobile && flutter test --no-pub \
  test/screens/document_scan/avs_guide_screen_test.dart \
  test/models/avs_gap_evidence_test.dart \
  test/models/avs_gap_write_order_test.dart \
  test/providers/coach_profile_provider_test.dart \
  test/screens/expat_avs_opt_in_test.dart \
  test/widgets/coach/avs_gap_widget_test.dart
# 92 passed

python3 tools/checks/mermaid_render_guard.py
# PASS
python3 -m pytest tools/checks/tests/test_screen_contracts_route_contract.py -q
# 4 passed
python3 -m pytest tools/checks/tests/test_codex_spec_reality_contract.py -q
# 6 passed
python3 -m pytest tools/checks/tests/test_data_quest_goal_aware_ranking_contract.py -q
# 1 passed
python3 -m pytest tools/checks/tests/test_g1_p0_ledger_dead_keys.py::test_every_matrix_ticket_has_an_executable_blocking_contract -q
# 1 passed: registry/evidence parity includes G1-AVS-03
python3 -m json.tool .planning/runtime-evidence/phase-37/ticket-evidence.json >/dev/null
# PASS
git diff --check
# PASS
```

Targeted textual checks:

```bash
grep -nE 'avs_official_ci_request_cta|avs_official_form_cta|_onOpenOfficialCiRequest|_onOpenOfficialForm' \
  apps/mobile/lib/screens/document_scan/avs_guide_screen.dart
# IDs/buttons: 312-340; handlers: 509-517

grep -nE 'ahv-iv.ch|avs_official_ci_request_cta|avs_official_form_cta' \
  apps/mobile/test/screens/document_scan/avs_guide_screen_test.dart
# exact official URLs plus real tap assertions

sed -n '2101,2125p' apps/mobile/lib/models/coach_profile.dart
# certificate-only self and spouse filters; missing remains missing

grep -R -nE 'reductionPercentageFromGap|monthlyLossFromGap' \
  apps/mobile/lib --include='*.dart'
# four unsafe production percentage callers; both public helpers remain

rg -n 'estimate_avs_gap|/avs-gap|avs-gap' services/backend/app services/backend/tests
# live backend estimator, endpoint and tests found

rg -n 'reductionPercentageFromGap|monthlyLossFromGap|2[.,]3 ?%|2\.3%|1/44|38.?000|PensionCompletenessRing' \
  apps/mobile/lib services/backend/app --glob '*.dart' --glob '*.py' --glob '*.arb'
# cross-stack unsafe personal-effect inventory reproduced

grep -R -n 'expatAvsCiRawDurationBenchmark' apps/mobile/lib/l10n --include='*.arb'
# all six strings hardcode 44

grep -nE 'EXPAT|SCANAVS|SCAN' docs/codex/WIRING_GRAPH.mmd
# includes EXPAT --> SCANAVS and fixed SCANAVS --> SCAN
```

Audit process integrity:

- `code-opus-first-pass.exit-code.txt` = `0`;
- `product-domain-opus-first-pass.exit-code.txt` = `0`;
- `product-domain-sonnet-rerun.exit-code.txt` = `0`;
- all three budget-preflight rejections have exit `2` and are not counted as
  audits;
- no additional Claude audit was launched during this triage.

## Quality conclusion

The retained **runtime slice at exact SHA `e8c0263ac` remains PASS** and P1-1,
P1-2 and P2-3 are closed by stronger code/test/device evidence than the rerun
had considered. P2-2 is a real cartography omission and is fixed in the working
tree.

The audited product slice is **not eligible for final G1 acceptance yet**:
P1-3 is confirmed cross-stack and only registered as `G1-AVS-03`
`ticket_only`; the Swiss verdict also confirms the P2-4 coupling bug and the
valid core of P2-1 while correcting its legal rationale. All three are included
in that blocking ticket's scope. This is not a regression of the exact runtime proof, but it prevents a
claim of P1=0 or full G1 closure. G1, including global `RUNTIME-01`, remains
open; this report authorizes neither G2 nor G3.

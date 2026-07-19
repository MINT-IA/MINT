## Product/domain verdict: PASS

This diff is ~95% runtime-evidence scaffolding (Patrol integration test, Maestro visual-attach flow, a bash simulator orchestrator, and Python contract tests) plus three tiny production edits that are pure accessibility/test hooks. It introduces **no** Swiss financial constants, rules, thresholds, advice text, or ranking, and it preserves the `G1-RETURN-01 = ticket_only` / G1 NO-GO posture honestly.

### Production changes actually shipped
- `rente_vs_capital_screen.dart:695-698` — wraps the `Scaffold` in `Semantics(identifier: 'rvc_screen', container: true)`. Test hook only.
- `data_block_enrichment_screen.dart:190-197` — conditional `identifier`/`Key('data_block_lpp_scan_cta')` on the LPP CTA. The scan-return branch it feeds still gates on `FeatureFlags.lppEvidenceIngestionEnabled` (default-off), so no activation.
- `indicatif_banner.dart:120-137` — wraps the existing CTA in `Semantics`/`Key`; `onPressed` is byte-identical (`context.push(_dataBlockLocation(route))`). No wiring change, no facade.

### Verification I performed against the live repo
- **Return mechanism delivers value (not a facade):** the terminal consume is `router.go(target.location)` → `/rente-vs-capital` (`app.dart:685-690`), a full stack replacement. That rebuilds `RenteVsCapitalScreen`, re-running `initState → _recalculate` (`:143`) and `didChangeDependencies → _autoFillFromProfile` (`:197-248`), which reads `profile.prevoyance.avoirLppTotal` fresh (`:238-241`). So a returned user genuinely recomputes rather than seeing frozen State. This was the main product-value risk and it holds.
- **Ledger spine respected:** navigation carries only an opaque `scanReturnId` + linked `{scanSessionId, scanReturnId}`; no domain payload in routes; RVC reads the canonical `CoachProfileProvider`. Consistent with ledger→DataQuest→scenario spine.
- **Missing-data framing intact:** `IndicatifBanner` only renders below 70 confidence (`indicatif_banner.dart:60`) and routes LPP enrichment — the correct minimum variable for a rente-vs-capital LPP decision.

### P0
None.

### P1
None that flip the verdict.

### P2
1. **Runtime proof is not reproducible by an auditor and never runs in CI sweeps.** The Patrol test is `skip: !_runningFromPatrolCli` (`g1_return01_rvc_lpp_scan_return_patrol_test.dart:24`), so only the manual exact-SHA simulator runner (`tools/simulator/patrol_return01_rvc_lpp_scan_return.sh`) exercises it. The "native GREEN at `0447ac488b`" claim rests entirely on archived artifacts under `.planning/runtime-evidence/phase-37/return-01-rvc/`; I cannot independently re-execute it. To prove it one must run the runner on a booted sim at a clean HEAD. This is disclosed and standard for the Mint model — nonblocking.
2. **The evidence proves routing, not enrichment delivery.** The Patrol test asserts return-to-`/rente-vs-capital`, intent consumption, and the synthetic certificate SHA (`…df9780f2`), but never asserts that the scanned LPP value flowed into `avoirLppTotal` or that confidence improved. The recompute path exists (verified above), but the "enrich → better answer" promise is asserted at the route level only. Fine for a returnUri ticket; worth an explicit follow-up assertion.
3. **Worktree/proof drift.** The unstaged edits to `test/patrol/g1_return01_rvc_lpp_scan_return_runtime_test.dart` and `test_g1_return01_rvc_runtime_orchestrator.py` mutate files the runner tracks; the runner would now fail-closed (`git diff --quiet "$expected_sha" -- tracked_files`) until re-committed. The archived proof predates these edits. Cosmetic re-indentation of the RVC `body:` (unstaged) is inert.

### Swiss domain review
- **LPP / retirement (rente vs capital):** the touched flow. No conversion-rate, coordination-deduction, or projection logic changed. The only LPP numbers present are synthetic test fixtures (`tauxConversion: 0.06`, `avoirLppTotal: 350000`) — not shipped constants, so no unverified current-law exposure. (Note only: `0.06` is below the 6.8% LPP mandatory minimum conversion rate; harmless as a synthetic enveloping-fund fixture, but do not let such fixtures leak into a default.)
- **AVS / 3a / tax / mortgage / insurance / succession / donation:** explicitly not affected — no code, constants, or copy touched.

### Mint product logic review
Moves Mint toward the ledger → DataQuest → scenario → dossier spine: a low-confidence RVC result surfaces a targeted LPP enrichment CTA → DataBlock → document scan → review/impact → `router.go` rebuild of RVC that recomputes from the canonical ledger, with only opaque IDs in transit. It closes one bounded return atom with native evidence without over-claiming — the ticket correctly stays `ticket_only`, six-loop/save-cancel-error coverage remains open debt, and G1 stays NO-GO.

# G1-RETURN-01 contract audit disposition

Date: 2026-07-20

Accepted audit: `opus-contract-product-domain-audit.txt` — **PASS**, P0=0,
P1=0.

## P2 dispositions

1. **Frontalier persistence failure has no visible retry.** Confirmed as a
   pre-existing Frontalier/FRONT recovery gap, not a RETURN terminal: the
   collector is inline, never creates a typed return target and never leaves
   `/segments/frontalier`. RETURN-01 will assert only route stability and the
   absence of a fabricated DataBlock Ask. The visible retry remains explicitly
   tracked as a FRONT follow-up and is not claimed by the contract decision.
2. **Non-P0 DataBlock producers are outside this ticket.** Accepted as an
   explicit scope boundary. RETURN-01 remains responsible for the five routed
   P0 origins plus the Frontalier in-place outcome; the global route registry
   and parser adversaries still fail closed, while unrelated producers are not
   silently promoted by this ticket.

No audit rerun is warranted: neither P2 changes the accepted planning decision,
and the ticket remains `ticket_only` until its exact RED -> GREEN proof exists.

## GREEN implementation audit dispositions

Accepted audits: `opus-green-code-audit.txt` and
`opus-green-product-domain-audit.txt` — both **PASS**, P0=0, P1=0.

1. **The five-path allowlist is hand-maintained.** Current producer completeness
   is directly tested by the 82-predicate canonical suite and the existing live-
   origin suite. A future producer/allowlist parity guard remains a nonblocking
   drift-hardening follow-up; it is not represented as automatic today.
2. **Two non-P0 IndicatifBanner callers still rely on history.** Annual-
   allocation and rent-versus-buy are outside the six P0 RETURN ticket and were
   not promoted by this fix. Their deterministic typed return is tracked as a
   separate follow-up rather than silently widening G1-RETURN-01.
3. **Paired GREEN artifact.** Closed in this same delivery by `green.json`,
   bound to exact SHA `6427a97722db879d74ccb04bde50d3c75e755112` and the
   identical 82/82 command.

No carousel rerun is warranted. Runtime and registry promotion remain separate
fail-closed gates.

## Six-origin runtime harness audit dispositions

Accepted audits: `opus-mobile-runtime-harness-audit.txt` (code) and
`opus-runtime-harness-product-domain-audit.txt` — both **PASS**, P0=0, P1=0.

1. **Witness booleans initially mirrored the stage name.** Fixed before commit:
   every stage now returns an observed `_StageProof` built from actual router
   URIs, collector state, persisted writes, byte-stable no-write comparisons,
   retained invalid input, and Frontalier no-DataBlock/canonical-write checks.
   The static contract rejects reintroduction of stage-derived truth booleans.
2. **Patrol behavior is simulator-only and CI-invisible.** Accepted only as a
   transparency boundary: static/contract tests cannot promote the ticket. The
   checked-in exact-SHA orchestrator must actually run and retain successful
   artifacts before RETURN-01 changes state.
3. **The static runtime contract is structural.** It is a drift guard, never a
   substitute for the five native stages, independent Maestro flows, exact-SHA
   RVC rerun, screenshots, witnesses and restoration.
4. **Disability uses the existing `revenu` block for birth year.** This is the
   current canonical storage surface and no alias was added. The naming wrinkle
   is tracked as a nonblocking product-language follow-up.

No same-gate carousel rerun was launched after the observed-witness hardening.
The harness remains unaccepted until its first exact-SHA runtime completes.

## Bash 3.2 runtime-runner audit disposition

Accepted audit: `opus-bash32-runtime-runner-audit.txt` — **PASS**, P0=0,
P1=0.

1. **Sibling RVC runner portability.** The auditor requested an explicit check
   that the separately invoked RVC runner did not retain Bash-4-only constructs.
   `grep` found no `declare -A`, `local -A`, `mapfile`, `readarray`, `wait -n`,
   or Bash-4 case-conversion expansion, and `/bin/bash -n` passed.
2. **Runtime acceptance remains outstanding.** The mapping regression executes
   the three checked-in lookup functions under macOS `/bin/bash` 3.2 and proves
   exact outputs plus unknown-stage rejection, but it is not native app proof.
   The full six-outcome runtime must restart from a new pushed exact SHA.

No rerun is warranted: the only P2 verification is resolved directly above.

## Maestro failure-diagnostics audit disposition

Accepted audit: `opus-maestro-diagnostics-audit.txt` — **PASS**, P0=0,
P1=0.

The first retry on exact pushed SHA
`08d2160bf3117615add8cb7cbf03b85a60e38944` reached Work Patrol 1/1 and
then exited 1 in Work Maestro. This is **not** a partial acceptance: no
`metadata.json`, final checksums, screenshot/hierarchy, later stages or exact-
SHA RVC proof exist. Normal-app restoration and private cleanup passed.

1. **The original Maestro detail was lost before sanitisation.** Fixed by
   explicitly capturing the command status, validating and sanitising the raw
   log, sanitising JUnit when present, and only then emitting a stage-named
   fail-closed error. The regression locks this order.
2. **Errexit is disabled inside the bounded Maestro subshell.** Accepted as
   nonblocking: `-u` and `pipefail` remain active, the Maestro command is the
   final subshell command, its status is captured, and any nonzero status still
   terminates through the named failure after privacy-safe evidence retention.
3. **Runtime acceptance remains outstanding.** A fresh exact pushed SHA must
   rerun the entire matrix; the retained Work Patrol witness from the failed run
   is diagnostic only and cannot be composed into a later PASS.

No audit carousel rerun is warranted. The next native attempt must diagnose the
actual Work Maestro failure if it recurs.

## Maestro offscreen-anchor audit disposition

Accepted audit: `opus-maestro-scroll-audit.txt` — **PASS**, P0=0, P1=0,
P2=0.

The diagnostic rerun on exact pushed SHA
`9e97782e6b27c42d4c92a0ec7912842e5d28b08d` proved Work Patrol 1/1 and
then a named Work Maestro failure: `first_job_enrich_profile_cta` was not
visible after 20 seconds. The sanitised JUnit reports one test/one failure.
This remains a hard fail with no partial acceptance.

The cause was a black-box flow contradiction, not missing production wiring:
the flow waited for a below-fold CTA before issuing its scroll. Work now waits
on the initially visible `first_job_ledger_facts` route anchor and then scrolls
to the CTA. The same pre-runtime defect was removed from Housing by waiting on
`mortgage_afford_result` before scrolling to `mortgage_enrich_profile_cta`.
A RED -> GREEN contract locks both orderings and forbids direct visible-waits on
those offscreen CTAs. The other three flows were inspected and did not repeat
this proven contradiction.

The audit noted exact-whitespace parsing as a possible future test-maintenance
cost, with no correctness finding. Runtime acceptance still requires a fresh
full exact-SHA run.

## Fresh-install readiness and Maestro isolation audit disposition

Accepted audit: `opus-startup-isolation-audit.txt` — **PASS**, P0=0,
P1=0.

The third diagnostic run on exact pushed SHA
`f851da9790ed76f3367d4adb5e2a395278c4a5b5` proved Work Patrol 1/1 and
failed Work Maestro on `first_job_ledger_facts`. Direct inspection of Maestro's
failure screenshot showed the production landing screen, proving the deep link
raced cold-start router readiness. A bounded device reproduction that waited
for `landing_route` before opening `/first-job` passed 1/1; its screenshot was
directly inspected and showed the intended Premier emploi screen and CTA.
Work and Succession now lock this readiness ordering because they are the two
runner stages that uninstall before the black-box flow.

1. **Overlay-preserved flows lack the same landing wait.** Accepted pending
   runtime evidence, not widened speculatively: those three stages preserve an
   existing data container and may not render `landing_route`; their strict
   route anchors fail closed if a link is lost.
2. **Global raw Maestro traces.** The runner now sends both test and debug
   outputs into the private stage. Independent passing and intentionally failing
   dry flows created zero new `~/.maestro/tests` directories. The failing dry
   proved `commands-*.json`, log and screenshot land under private
   `debug-output`; the hierarchy extractor therefore reads only that directory,
   rejects symlinks/out-of-root files, and sanitises `hierarchyRoot` before
   retention. A simctl screenshot is best-effort, while the original named
   Maestro failure remains authoritative.
3. **Acceptance remains outstanding.** These fixes and dry proofs do not compose
   with prior partial Patrol evidence. The full matrix must restart on one new
   exact pushed SHA.

No audit rerun is warranted. Runtime remains fail-closed.

## Patrol/RVC observability and strict-hierarchy isolation disposition

Accepted audit: `opus-patrol-rvc-observability-audit.txt` — **PASS**, P0=0,
P1=0.

The fourth exact-SHA run (`81c22f5242e1d657a9130a7d828d8304d5822102`)
proved Work Patrol 1/1 and Work Maestro 1/1 with strict hierarchy and PNG, then
failed in Housing Patrol. Its raw failure was lost because Patrol still ran
under global `set -e`; this is diagnostic progress only, never partial
acceptance.

1. **Patrol and RVC redirected-command failures.** Both now capture status,
   restore errexit, sanitise their raw log, and only then emit a named hard
   failure. Patrol's xcresult summary is best-effort in an isolated subshell so
   missing/invalid diagnostics cannot replace the primary status. The same
   latent black hole was closed proactively for the exact-SHA RVC runner.
2. **Strict hierarchy leaked a second Maestro trace.** `capture_hierarchy` now
   sets a per-label private Java `user.home` and private walker directory. A
   bounded live dry returned 0 with a 5045-byte hierarchy, populated only the
   private Java home, and created zero new real-home Maestro test directories.
   This directly closes the auditor's P2 evidence request.
3. **RVC failure evidence directory.** Accepted as the pre-existing evidence
   output model. Failed evidence is not accepted or composed into a later PASS;
   a full run must still reach the terminal exactness/privacy/checksum gates.

No audit rerun is warranted. A fresh exact-SHA runtime must now reveal the
actual Housing Patrol failure if it recurs.

## Housing actionable-node audit disposition

Accepted audit: `opus-housing-action-audit.txt` — **PASS**, P0=0, P1=0,
P2=0.

The fifth exact-SHA run (`e84e935c39f4a24ea4eee66394b16f7451b2aac8`)
again proved Work Patrol+Maestro, then retained the exact Housing Patrol failure:
the outer `mortgage_enrich_profile_cta` notice accepted a hit-test, but no
`DataBlockEnrichmentScreen` appeared. Production places the key on the notice
Container while the callback belongs to its sole descendant `GestureDetector`.
The Patrol stage now scrolls the notice, asserts the production widget type and
unique actionable descendant, taps that descendant, and only then verifies the
collector. This matches both canonical live-origin widget suites.

The static RED -> GREEN guard cannot itself promote runtime; it only prevents
reintroducing the parent-container tap. A fresh full exact-SHA run remains
mandatory.

## Housing lazy-Sliver materialisation audit disposition

Accepted audit: `opus-housing-lazy-scroll-audit.txt` — **PASS**, P0=0,
P1=0, P2=0.

The sixth exact-SHA run (`a8069a9c2a561f522aa2e55d111d9fa19fa453a8`)
again proved Work Patrol+Maestro, then failed Housing Patrol before opening the
collector: the new pre-scroll `findsOneWidget` assertion saw zero
`mortgage_enrich_profile_cta` widgets. The Section-5 notice is a lazily built
`SliverList` child on the native viewport. The preceding runtime had already
proved that Patrol's keyed `scrollTo()` can materialise it.

Housing now creates the stable keyed finder, scrolls first to materialise the
lazy child, then fail-closes on presence, production widget type, unique
descendant `GestureDetector`, descendant tap, collector route/origin, cancel
return, and byte-identical Data Ledger storage. The RED -> GREEN static contract
locks that exact ordering. The audit accepts the minor diagnostic tradeoff that
a missing notice now surfaces as a scroll failure rather than a
`findsOneWidget` failure.

No prior Work or Housing evidence is composed into acceptance. RETURN-01 remains
`ticket_only` until a fresh pushed exact SHA passes the entire five-origin
Patrol/Maestro matrix, strict hierarchy and screenshots, RVC, restoration,
privacy/isolation, metadata, and checksums.

## Immutable production-overlay audit disposition

Accepted audit: `opus-immutable-overlay-audit.txt` — **PASS**, P0=0,
P1=0; one informational P2 documents the deliberately bounded persistent-data
roots.

The seventh exact-SHA run
(`f65e13b1ad4acf134824d8ccf843ecc0006d85f4`) proved Work
Patrol+Maestro and, for the first time, Housing Patrol 1/1 with exact route,
collector, no-write and return witnesses. It then failed closed before Housing
Maestro: installing `normal_app` changed the app data container. No later
stage, RVC, metadata or checksum exists, so none of those passing atoms is
accepted or composable.

The cause was an aliasing defect in the evidence runner. `normal_app` pointed
inside Flutter's mutable build output, which each Patrol invocation rebuilt
with the test bundle. The later overlay therefore no longer referenced the
original physically exported normal application. The runner now snapshots the
fresh production build with `ditto` under its private root before Patrol can
mutate build outputs. Codesign, xattrs, every overlay and final restoration use
only that immutable copy.

Seed-preserving overlays remain fail-closed: no uninstall is allowed, the
pre/post app-container path must be identical, and a deterministic SHA-256 over
regular non-symlink files in `Documents` and `Library/Preferences` must be
byte-identical. These roots cover MINT's current app-container persistence;
secure-storage material is outside the app data container. A future
Application Support database must explicitly widen this contract rather than
silently inheriting the claim.

RED was 18 pass / 1 fail on the absent immutable snapshot. GREEN is 19/19
targeted and 27/27 across the combined RETURN/RVC runner contracts; Bash parse,
ShellCheck, Python compilation and diff checks pass. A fresh exact pushed SHA
must still rerun the whole native matrix.

## Relocated-container data-identity audit disposition

Accepted audit: `opus-relocated-container-audit.txt` — **PASS**, P0=0,
P1=0; one informational P2 notes the intentional difference from
process-death container-identity witnesses.

The eighth exact-SHA run
(`a4c9e1a6e6a800ecb148addd7382702ef6593cbe`) confirmed that the
immutable normal-app snapshot fixed the mutable-output alias but did not stop
iOS Simulator 26.2 from assigning a different data-container path. Work
Patrol+Maestro and Housing Patrol again passed, then the runner failed closed
before Housing Maestro on path identity. No later proof is accepted.

Container UUID/path identity is not the ledger-preservation property. The
runner now validates both pre/post container paths independently, forbids an
explicit uninstall in seeded stages, and fingerprints post-install data even
when the path changes. Acceptance requires the exact same non-empty
`file_count:byte_count:sha256` tuple across `Documents` and
`Library/Preferences`; empty roots, symlinks, non-regular files, invalid
containers or any byte/count/hash drift hard-fail. The retained overlay log
contains only `container_identity=preserved|relocated` and
`persistent_data=verified`, never raw paths or UUIDs.

RED was 18 pass / 1 fail on the still-fatal path inequality. GREEN is 19/19
targeted and 27/27 combined RETURN/RVC contracts; Bash parse, ShellCheck,
Python compilation and diff checks pass. This does not transfer or repair data:
the next exact-SHA runtime must prove that the platform preserves the synthetic
ledger bytes naturally, then complete every remaining stage.

## Overlay router-readiness audit disposition

Accepted audit: `opus-overlay-router-ready-audit.txt` — **PASS**, P0=0,
P1=0, P2=0.

The ninth exact-SHA run
(`17a84584670ed461a75227829cc7886f8bf4800f`) proved the new data
invariant in the live simulator:
`container_identity=relocated persistent_data=verified`. Work
Patrol+Maestro and Housing Patrol passed. Housing Maestro then failed waiting
for `mortgage_afford_result`. Its retained 1206x2622 PNG was directly
inspected and shows the production MINT landing screen; the retained hierarchy
independently contains `landing_route`. No later stage is accepted.

The normal-app overlay preserves the synthetic ledger bytes but restarts router
initialisation. Housing, Disability and Frontalier now apply the already-proven
black-box ordering used by Work and Succession:
`launchApp -> landing_route -> openLink -> route anchor`. The three business
routes, selectors and gestures are unchanged. A RED contract failed on the
missing Housing readiness boundary; GREEN is 6/6, targeted analysis is clean,
and all three YAML flows parse.

A fresh pushed exact SHA must rerun the full matrix. Prior Work/Housing atoms
remain diagnostic only.

## Housing actionable-semantics audit disposition

Accepted audits: `opus-housing-semantics-code-audit.txt` and
`opus-housing-semantics-product-domain-audit.txt` — both **PASS**, P0=0,
P1=0. Product-domain P2 observations about the pre-existing static 45% and
salary-only enrichment scope are not introduced or widened by this accessibility
fix and remain outside RETURN-01's route-stability acceptance.

The tenth exact-SHA run
(`5d8c28c00735612a5ccfff428771840be7aad957`) proved Work
Patrol+Maestro, Housing Patrol, relocated-container data identity and Housing
router readiness. Housing Maestro then failed because
`mortgage_enrich_profile_cta` was visually present but absent as a dedicated
resource id. The retained PNG was directly inspected: it shows the correct
Capacité d'achat screen. The retained hierarchy merges the card copy and exposes
no action id.

`MintConfidenceNotice` now accepts an optional action semantics identifier
and attaches it only to the CTA node that contains the real `GestureDetector`
callback. Mortgage passes the exact stable id. The outer keyed notice remains
the lazy scroll anchor used by Patrol, the body remains non-actionable, and the
unique descendant action remains intact. RED failed because the semantics
parameter did not exist; GREEN proves message taps do nothing, one button
semantics node exists, and its tap fires once. Widget/runtime/navigation suites
pass 116/116 and targeted analysis is clean.

No prior runtime atoms are composed. A new pushed exact SHA must restart all
stages.

## Housing semantic-boundary audit disposition

Accepted audits: `opus-housing-semantics-boundary-code-audit.txt` and
`opus-housing-semantics-boundary-product-domain-audit.txt` — both **PASS**,
P0=0 and P1=0. Their P2 notes are non-blocking and pre-existing: the widget
geometry test uses a synthetic insertion context, and Mortgage still displays
the unchanged static 45% confidence value. Neither observation is introduced
or widened by this native semantics boundary fix.

The eleventh exact-SHA run
(`da84012ff43d1a9376645c3017d9009195d99cab`) proved Work
Patrol+Maestro, Housing Patrol, relocated-container data identity, Housing
router readiness, and native discovery of `mortgage_enrich_profile_cta`.
Housing Maestro then tapped that id but never reached `salary_input`. Direct
inspection of the retained screenshot and hierarchy showed the correct
Capacité d'achat screen and a semantics node spanning the whole confidence
notice (`[24,531]-[378,703]`); its centre lay outside the visible CTA. No later
stage is accepted.

The CTA `Semantics` node now declares `container: true`, preserving a distinct
native accessibility boundary around exactly the actionable
`GestureDetector`. The test first failed because the node was not a container,
then GREEN proves the action rectangle is smaller than and contained within the
notice while body taps remain inert. Widget/runtime/navigation suites pass
116/116, targeted analysis is clean, and the implementation is committed as
`a3150e84e`.

No prior runtime atoms are composed. A fresh pushed exact SHA must restart the
complete matrix and prove the real native hit bounds before RETURN-01 can move
out of `ticket_only`.

## Collector cancel-action audit disposition

First-pass Opus audits:
`opus-collector-cancel-code-audit.txt` and
`opus-collector-cancel-product-domain-audit.txt` — both **PASS**, P0=0 and
P1=0. They identified one actionable P2: wrapping the existing `IconButton`
in a separate semantics container could expose an identifier node without the
native tap action and duplicate the accessibility button. A RED widget
assertion confirmed that the identified node lacked `SemanticsAction.tap`.

Accepted reruns:
`sonnet-collector-cancel-code-rerun.txt` and
`sonnet-collector-cancel-product-domain-rerun.txt` — both **PASS**, P0=0 and
P1=0. `MergeSemantics` now produces one node that owns the stable identifier,
button flag and real `IconButton` tap action. Remaining P2 observations concern
the pre-existing successful-save fallback and the fact that this focused widget
test exercises `safePop`; the routed `context.go(target.location)` branch is
already covered by the RETURN-01 navigation matrices and remains the black-box
runtime subject. Neither observation blocks this cancel-selector fix.

The twelfth exact-SHA run
(`858a9b843eec08f3cb6036c9cb2699fa463458e8`) stopped at
`.planning/runtime-evidence/phase-37/return-01/runtime-858a9b843e-20260720T114621Z`.
It proved Work Patrol+Maestro, Housing Patrol, witness/store preservation,
production overlay and persistent-data identity. Housing Maestro then proved
the earlier semantics-boundary fix by tapping `mortgage_enrich_profile_cta`
and reaching `salary_input`; its generic iOS `back` command did not exit the
Revenu collector, so the final origin assertion failed. Direct inspection of
the retained PNG and hierarchy confirms Revenu, `salary_input` and
`salary_save_cta` remained visible. No later stage or prior atom is accepted.

Housing and Disability Maestro now tap the stable
`data_block_cancel_return_cta` that is wired directly to the unchanged
`_cancelToReturnTarget` callback. The contract forbids generic `back` in those
flows. RED covered the missing selector and non-actionable semantics node;
GREEN proves one merged actionable node, real return navigation, both YAML
selectors and no duplicate button. The targeted screen/runtime/Patrol/navigation
bundle passes 141 tests with one expected non-CLI Patrol skip; targeted analysis,
YAML parsing and diff checks are clean. Implementation commit: `338c06fdb`.

A new pushed exact SHA must restart the complete RETURN-01 matrix. Promotion
remains forbidden until every stage, checksum, cleanup and inspected capture is
complete in one accepted run.

## Disability actionable-semantics audit disposition

Accepted audits: `opus-disability-cta-code-audit.txt` and
`opus-disability-cta-product-domain-audit.txt` — both **PASS**, P0=0 and P1=0.
Their P2 notes describe intentional dual proof handles (Flutter `Key` for
Patrol and native semantics identifier for Maestro), a deliberately strict
geometry guard, and a pre-existing all-facts-known edit choice. None changes
the routed missing-fact contract or blocks this accessibility fix.

The thirteenth exact-SHA run
(`ae33f01df4983686e258cb3080d35496ddc3d6ea`) stopped at
`.planning/runtime-evidence/phase-37/return-01/runtime-ae33f01df4-20260720T122658Z`.
It proved Work and Housing Patrol+Maestro, including the newly targeted Housing
cancel action. Disability Patrol, witness/store preservation, retained invalid
input and production-overlay data identity also passed. Disability Maestro then
failed before its first tap because `disability_gap_enrich_cta` was absent from
the native hierarchy. Direct inspection of all three retained PNGs and the
hierarchy confirms the visible Enrichir mon profil text was merged into the
large `disability_gap_ledger_facts` node. No later stage is accepted.

The real Disability `TextButton.icon` now uses `MergeSemantics` with the stable
identifier and button flag. RED proved no identified semantics node existed;
GREEN proves the identifier, button flag and `SemanticsAction.tap` belong to
the same node as the real TextButton, its bounds remain inside and smaller than
the ledger card, and the original `context.push(route)` reaches the same
targeted DataBlock. Ledger/runtime/navigation suites pass 121/121 and targeted
analysis and diff checks are clean. Implementation commit: `422d618e1`.

A fresh pushed exact SHA must restart every RETURN-01 stage. Prior successful
Work/Housing/Disability Patrol atoms remain diagnostic only and cannot be
composed into acceptance.

## Salary-fallback ledger-truth audit disposition

Accepted audits: `opus-salary-fallback-truth-code-audit.txt` and
`opus-salary-fallback-truth-product-domain-audit.txt` — both **PASS**, P0=0
and P1=0. The code audit records the intentional net-income-only re-entry UX
trade-off rather than laundering a derived gross estimate into a declared
fact. The product/domain audit also notes a pre-existing self-employed-income
scoring vocabulary gap; it is not introduced as a new authority path by this
focused fallback correction.

The fourteenth exact-SHA run
(`588397da5cbb8edc78711e33b26c316955af12ce`) stopped at
`.planning/runtime-evidence/phase-37/return-01/runtime-588397da5c-20260720T125316Z`.
It proved Work and Housing Patrol+Maestro, Disability Patrol, retained invalid
input, witness/store preservation, production overlay and the newly actionable
Disability CTA. Disability Maestro tapped that CTA but reached the Revenu
collector with `salary_input` prefilled as `68966`, score `12 / 12 pts` and
status `Complet`, instead of the contractually missing `birth_year_input`.
Direct inspection of the retained PNG and hierarchy confirms those exact
values. No later stage is accepted.

Two independent defects were separated rather than hidden by weakening the
Maestro assertion. First, an unreadable secure salary (`__secure__`) was
correctly absent from `userProvidedFields`, but the model's positive display
fallback still seeded the gross salary field and earned the full salary score.
The collector now requires exact `grossSalaryAnnual` provenance before
prefilling, while both confidence surfaces require shared `salary` provenance
plus a positive value before awarding 12 points. RED tests reproduced the
`68966` prefill and 12/12 score; GREEN tests prove the fallback stays empty and
missing while real declared net and gross incomes remain known. The two
focused suites pass 83/83 and targeted analysis is clean. Implementation
commit: `064dc8e9f`.

Second, `persistent_data=verified` fingerprints only regular files under
`Documents` and `Library/Preferences`; it does not prove Keychain continuity
between the Patrol test host and the normal Runner overlay. Patrol stage seeds
are whole-map replacements, not cumulative. The next harness correction must
therefore reset the Disability black-box state and seed a real salary through
production UI before opening `/invalidite`, while retaining the expected
`birth_year_input` contract. A new pushed exact SHA must restart the complete
RETURN-01 matrix after that harness fix.

## Exact-SHA CI salary-provenance repair disposition

GitHub Actions run
[`29746585832`](https://github.com/MINT-IA/MINT/actions/runs/29746585832)
completed **FAILURE** for exact head SHA
`39463483825eeaa3c5494b1da922409e98ed6d4d`. The clean-room run exposed two
real verification gaps rather than invalidating the salary-fallback product
fix:

1. `No hardcoded FR` rescanned every literal in a changed Dart file and failed
   on 32 pre-existing literals in `confidence_scorer.dart`, although lefthook
   already enforced only indexed additions.
2. `Flutter services` reproduced six failures: five direct `CoachProfile`
   fixtures described a declared positive salary without the now-required
   `salary` provenance marker, and one MintState assertion incorrectly assumed
   low confidence removes the present-day budget as well as retirement
   projections.

The copy-debt gates now share an introduced-lines contract without sacrificing
lexical context. Hardcoded-FR CI uses base-SHA additions; accent lint uses
indexed additions in lefthook and base-SHA additions in CI. Both scan the full
index/HEAD blob first, then filter reported line numbers, so multiline literals
and regex remain visible. Whole-file mode remains available for ingestion.
No file or token is allowlisted, and negative tests prove newly added French or
flattened-accent debt still fails. Commits: `01fda779b` and `3edc20ae6`.

The test fixtures now mark only intentionally declared positive salary facts
with `userProvidedFields: {'salary'}`. The deliberately unknown `_emptyProfile`
remains unmarked and low-confidence. Its test now asserts the shipped product
boundary: FRI/replacement/retirement projections stay absent, while the honest
present-day budget remains available as `BudgetStage.presentOnly` with a finite
monthly value. Commit: `746836b73`.

Accepted audits:
- `opus-ci-salary-provenance-code-audit.txt` — **PASS**, P0=0, P1=0.
- `opus-ci-salary-provenance-product-domain-audit.txt` — **PASS**, P0=0,
  P1=0.
- `opus-introduced-debt-gates-code-audit.txt` — **PASS**, P0=0, P1=0 after
  the accent-gate correction.

Authoritative local verification is 39/39 copy-gate contracts, Python compile,
Ruff, Actionlint, diff check and full lefthook PASS; the three exact failing
mobile files pass 113/113 with targeted analysis clean. A fresh push and
GitHub run must still prove the new head SHA before any native runtime resumes.

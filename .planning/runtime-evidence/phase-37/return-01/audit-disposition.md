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

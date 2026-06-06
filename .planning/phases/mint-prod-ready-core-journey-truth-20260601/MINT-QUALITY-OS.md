# MINT Quality OS

Date: 2026-06-05
Owner: Team Lead / QA
Status: Active ratchet, not a release waiver

## Purpose

MINT Quality OS is the control layer that keeps product-quality claims tied to
evidence. It does not replace the Journey Truth Matrix, BUG-TRACKER, Maestro,
Flutter tests, backend tests, TestFlight, Engram, or expert review. It connects
them and blocks overclaiming.

MINT provides guidance, education, simulation, explanations, and decision
support. It must not present itself as giving regulated personalized investment
advice.

## Source Stack

- `JOURNEY-TRUTH-MATRIX.md`: capability truth and row status.
- `BUG-TRACKER.md`: open, accepted, deferred, and closed defects.
- Screen quality review HTML: clarity, inclusion, data grounding, UX quality.
- Flow guidance review HTML: journey logic, non-absurd guidance, outcome proof.
- Persona-flow benchmark: scenario scores against Swiss expert-grade guidance
  expectations, with runtime proof and score caps.
- Flow evidence registry: machine-readable flow evidence, caps, and remaining
  gaps.
- `quality-os-scorecard.json`: scores, caps, evidence, next actions.
- `quality-os-oss-tool-map.json`: OSS-first tool choices and deferrals.
- `tools/checks/mint_quality_os_check.py`: cheap machine guard.
- Claude CLI review: read-only second opinion on every material patch.

The matrix and bug tracker remain operational truth. The scorecard records the
current quality state. HTML reviews are evidence, not closure by themselves.

## Debugging Protocol

Canonical repo facts for this wave:

- Remote: `git@github.com:MINT-IA/MINT.git`
- Branch family: `qa/runtime-navigation-spine-20260602`
- Local working copy: the session-provided Desktop `MINT.nosync` repo.

First commands before any environment conclusion:

- `pwd`
- `git status --short && git status -sb`
- `git remote -v`
- `cat .git/HEAD`
- targeted read of the exact failed file

Rules:

- State the narrow symptom: process, file, command, and observed failure.
- Do not move, clone, delete, relink, chmod, or xattr the repo as an access fix
  without explicit user approval for that operation.
- Do not create a worktree as an environment-debugging bypass when the
  canonical repo is accessible. Worktrees remain valid only for explicit
  planned isolation work.
- Do not infer GitHub ownership from a personal-account search. MINT app repo
  is `MINT-IA/MINT`.
- Separate process symptom, file read failure, Git failure, Desktop permission,
  remote repository fact, fact, hypothesis, and blocked action.
- Save Engram memory after any debugging incident.

Exit criteria:

- Git status works from the canonical repo, or the remaining limitation is
  stated as current-process scoped.
- No alternate workspace remains unless explicitly approved.
- The next action maps back to a matrix row, bug, scorecard action, or check.

## Review Protocol

Every material change should pass:

- local diff review with `git diff --stat` and targeted diff reading;
- touched-area tests and Quality OS check;
- Claude CLI read-only review on the focused patch when available;
- Engram save for any decision, bugfix, convention, or discovery.

This is a workflow requirement, not a mechanical proof. The guard can verify
that the requirement exists in the scorecard; it cannot prove a review happened.
If Claude CLI is unavailable, the work is not silently treated as reviewed. The
final note must state that review is missing and no matrix row should be closed
from that lot.

Specialist review is required for Quality OS lots that change how MINT judges
product quality. The minimum panel is product strategy, UX/persona clarity,
QA/eval repeatability, and compliance boundary. Claude CLI remains a separate
focused diff reviewer.

## OSS-First Tool Strategy

MINT has limited budget. The default is OSS-first:

- Use CLI/CI tools first: Maestro, Flutter test, pytest, promptfoo, Allure
  Report, Semgrep, Gitleaks, Trivy, OSV-Scanner, MobSF.
- Add self-hosted services only after a stable contract exists: Kiwi TCMS,
  ReportPortal, Langfuse/Phoenix, Unleash, GlitchTip/Sentry self-host,
  PostHog/Matomo.
- Use paid services only for gaps that are costly to cover locally, such as
  real-device iOS scale.

Quality OS must not become a custom replacement for those tools. It only
defines MINT-specific mapping: rows, screens, flows, bugs, scores, evidence,
release caps, and closure rules.

## Scoring

Default capability weights:

- Reachability: 15%
- User outcome: 20%
- Data truth and restart safety: 15%
- Financial/compliance trust: 15%
- UX, accessibility, and localization: 15%
- Automation reliability: 10%
- Ops, privacy, and debt hygiene: 10%

Release caps:

- Any open P0 release blocker caps MINT readiness at 7/10.
- Open T0 account, privacy, production fact substrate, TestFlight, Universal
  Link, or live observability gate caps release readiness at 8/10.
- User feedback that flows do not feel useful or guidance is weak caps the
  product-readiness score until runtime flow reviews prove better outcomes.
- A row cannot move to `LIVE-PROVEN` from documentation, unit tests, or static
  screenshots alone when runtime behavior is part of the claim.
- A score cannot increase by more than 0.5 without new evidence or a committed
  bug closure.

The current guard validates score shape and the 10/10 overclaim boundary. It
does not yet compare historical score deltas or compute weighted scores.

## Persona-Flow Benchmark

The persona-flow benchmark is the missing layer between "this screen renders"
and "this journey gives useful Swiss financial guidance".

It scores a bounded persona/scenario flow against:

- runtime completion;
- persona fit and inclusion;
- data truth and restart safety;
- calculation quality;
- Swiss expert-coverage expectations and logical guidance;
- UX clarity, cognitive load, and next-action quality;
- FINMA/LSFin-safe guidance boundary;
- accessibility and localization.

Seed wave:

- 2 personas;
- 1 scenario per persona;
- 5 checkpoints per scenario;
- 10 scored cells total.

Expansion is allowed only after clean seed evidence, BUG-TRACKER entries for
every P0/P1 gap, and two consecutive review cycles without a methodology
blocker. This prevents a 104-screen manual audit trap.

The benchmark lives in:

- `persona-flow-benchmark.md`
- `persona-flow-benchmark.json`
- `evidence/quality-review/persona-flow-benchmark-seed-20260606.md`

The flow proof registry lives in `flow-evidence-registry.json`. Its job is to
turn runtime, tests, semantic evals, screenshots, caps, row links, and bug links
into source data that future HTML reviews and checks can consume.

Score caps:

- missing runtime proof caps a flow at 5/10;
- runtime proof without an expert-reference artifact caps it at 6/10;
- missing calculation source or assumptions caps it at 7/10;
- materially wrong calculation caps it at 4/10;
- salary-only, Swiss-native-only, or retirement-first assumptions that do not
  fit the persona cap it at 7/10;
- regulated-advice wording, provider ranking, or product prescription caps it
  at 6/10 and opens a compliance bug.
- product/brand recommendation, ISIN/ticker advice, buy/sell/choose language,
  return promise, read/write financial action, unsafe logging, or PII leak
  fails the benchmark at 0/10.

This benchmark cannot close a matrix row by itself. It can only raise
confidence, prioritize bugs, and define the next runtime proof.

## Flow Evidence Registry

The registry starts with schema and cap rules before populated records. The
minimum evidence for a scored flow is:

- matrix rows and linked bug IDs;
- executable proof: Maestro JUnit plus watchdog result, or backend/API contract
  proof for backend-only rows;
- screenshot or runtime snapshot for visual, UX, accessibility, or guidance
  claims;
- evidence artifact paths that the guard can check for existence;
- deterministic contract tests for persistence, restart, i18n, semantics,
  routing, data provenance, or calculations;
- user-visible outcome statement;
- guidance-boundary evidence for financial flows;
- remaining gaps and score-cap reasons.

Registry caps apply before global rollup:

- no durable evidence artifact caps the flow at 2/10;
- docs or static screenshots only cap it at 3/10;
- Flutter/backend tests but no runtime for a user-visible journey cap it at
  5/10;
- Maestro pass without user outcome or guidance review caps it at 6/10;
- Maestro pass without restart/data provenance where money/profile truth is
  involved caps it at 7/10;
- open P0 affecting the flow caps it at 6/10;
- open P1 qualitative guidance bug caps it at 8/10.
- missing a11y/i18n/dynamic-type proof for a T0/T1 screen caps it at 8/10;
- missing signed-device, TestFlight, or Universal Link proof for release access
  rows caps it at 8/10.

The current guard validates registry shape, required fields, evidence artifact
existence, derived caps, rubric coverage, review dates, and score <= effective
cap. The next guard ratchet is stale evidence and row/bug reference validation
against parsed trackers.

## Tier Contract

- T0 release gates: install/open, account lifecycle, privacy export/delete,
  local data claim, money spine, production/staging fact substrate, Universal
  Links, TestFlight proof, Sentry/release observability.
- T1 primary surfaces: `/home`, `/mon-argent`, `/budget`, `/rapport`,
  `/coach/chat`, `/profile/bilan`, `/scan`, `/explore`, onboarding, privacy.
- T2 chat-routable screens: route card render, tap, context, ScreenReturn, and
  useful guidance.
- T3 long-tail routes: smoke render, localized title, no overflow, registry
  parity.
- T4 admin/debug/internal: feature flagged or excluded from release proof.

## Required Gates

- `python3 tools/checks/mint_quality_os_check.py`
- `python3 tools/checks/cjt_context_guard.py`
- `./tools/mint-routes check`
- `python3 tools/checks/maestro_locator_audit.py`
- ARB parity, banned terms, and accent lint when copy changes.
- Touched-area tests from `AGENTS.md`.
- Claude CLI focused review before finalizing a material lot, with the caveat
  that this remains a human/workflow gate until review evidence capture lands.

Nightly/release ratchets still needed:

- T0/T1 Maestro sweep with screenshots and restart proof.
- Coach semantic golden evals with promptfoo.
- Stale evidence detection tied to affected paths.
- Privacy lifecycle and TestFlight real-device proof.
- Security release scans and no-PII evidence contract.

## Evidence Contract

Runtime proof should include command, date/timezone, build or device, route or
flow, matrix row, bug/debt id when relevant, output artifact, user outcome, and
remaining gap.

The current guard validates existence, shape, and configured local-file mtime
freshness for explicitly listed `.planning/.../evidence/` files. It also checks
that cited local evidence paths are covered by the freshness list. It does not
yet prove command/result metadata, URL reachability, affected-code invalidation,
or semantic proof strength. Evidence is stale when the artifact is missing,
empty, placed in `/tmp`, older than the configured freshness window, predates
affected code, or backs a stronger status than it can prove.

## Current Self-Score

MINT product-readiness score: 5.2/10.

Felt product quality score: 4.2/10.

Journey Truth proof score: 59.5%.

Codex Quality OS work score: 7.0/10.

Why not 10:

- User feedback on 2026-06-06 says MINT still does not work well enough and the
  flows do not yet give a good feeling or useful guidance.
- The guard is new and still covers scorecard shape more than full evidence
  freshness.
- Coach semantic evals, stale evidence detection, release observability, and
  lifecycle tests remain incomplete.
- Screen and flow reviews identify gaps; they do not close rows by themselves.

Next ratchets:

1. Raise felt flow quality before raising readiness score.
2. Keep the Quality OS check in standard gates.
3. Convert screen/flow P0/P1 gaps into bug tracker entries.
4. Extend stale evidence detection from mtime checks to affected-path and
   command/result metadata.
5. Add Coach semantic evals.
6. Re-run T0/T1 runtime flows with restart, accessibility, localization, and
   qualitative guidance proof.

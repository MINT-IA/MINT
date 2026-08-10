# MINT Next — Golden 3a Vertical Goal Contract

Status: `pre_activation`
Contract maturity: `candidate_pending_final_audit`
Product maturity: `unproven`
Feature flag: `OFF`
Amendment 2026-08-10 (cadrage n°1, convergé Claude×Codex) : la machinerie de
reçus B0-B5 (chaînes de receipts, double reviewers, replay byte-compare,
commits de clôture) est retirée ; chaque batch se promeut désormais par le
gate unique en 5 conditions de l'ADR
`.planning/decisions/2026-08-10-jumeau-financier-et-collaboration-codex.md`.
La substance (contrats, provenance, machine à états, preuves runtime) est
inchangée.

## Goal

Prove one complete MINT Next loop for a Swiss financial novice:

`Today → 3a opportunity → known/missing facts → minimal progressive confirmations → deterministic scenario → pedagogical widget → free choice → specific mini-plan → Today`

This vertical proves the lifelong financial-twin pattern. It does not prove a
generic tax engine, B0 completion, product readiness, advice, or deployment.

## Frozen supported persona

Adult 18–65, financially novice, single without children, domiciled in Lausanne
for all of 2026, ordinary taxation (not source taxation), salaried with AVS income
and confirmed active LPP, ordinary 2026 3a only, with every 3a provider/account
exhaustively confirmed. Only Lausanne/VD/2026 is supported.

The exact A–J outcome matrix is authoritative at:
`annexes/persona-case-matrix.yaml`.

## Product contract

- Today, Coach, and Ma situation consume one canonical read model.
- Coach sends typed intent/deep-links into the same state machine. It does not
  extract canonical values, calculate, or supply truth.
- Explorer, a second lever, provider ranking, transactions, APIs, backend sync,
  TestFlight, `dev`, and generic plan infrastructure are out of scope.
- Every new route/model/service must have a runtime caller in this golden flow.
- No screen is complete while collected facts remain local to that screen.
- One primary cognitive decision per screen; never a forced one-question-per-screen questionnaire.

## Canonical navigation and state machine

Route id is `today`; its label is localized (« Aujourd’hui » in French). Only
Today and Coach enter this machine. Any unlisted state/event pair fails closed
in the current state with zero writes.

| State | Event | Next | Writes | CTA | Back / exit / resume | Destination |
|---|---|---|---:|---|---|---|
| loading | facts complete | known | 0 | none | exit; resume intent | fact review |
| loading | facts incomplete | missing | 0 | none | exit; resume intent | fact review |
| loading | offline | offline | 0 | Retry | exit; resume loading | same route |
| loading | key/secure-store failure | secure_fail | 0 | Recover | exit only; no plaintext fallback | privacy recovery |
| offline | retry | loading | 0 | none | exit; resume loading | same route |
| secure_fail | recovery succeeds | loading | 0 | none | exit; resume loading | same route |
| secure_fail | recovery fails | secure_fail | 0 | Retry recovery | exit only | privacy recovery |
| known | continue | calculation_ready | 0 | See my situation | back Today | scenario |
| missing | submit proposal | confirmation | 0 | Confirm | back keeps local draft only | confirmation |
| confirmation | confirm | known | exactly 1 fact version | Continue | interruption resumes confirmation | fact review |
| confirmation | refuse | refusal | 0 | Continue without saving | back/exit | safe exit |
| refusal | continue without saving | completed | 0 | Done | exit | Today |
| confirmation | double-submit | known | exactly 1 idempotent write | Continue | same | fact review |
| any fact state | contradiction/conflict | contradiction | 0 | Resolve | exit; resume conflict | comparison |
| any fact state | expiry/life event | stale | 0 | Update | exit; resume stale | one-fact refresh |
| contradiction | select confirmed version | known | exactly 1 supersession | Continue | exit; resume conflict | fact review |
| stale | submit replacement proposal | confirmation | 0 | Confirm | back keeps local draft only | confirmation |
| calculation_ready | unsupported | unsupported | 0 | What I can still do | back Today | explanation |
| unsupported | show explanation | unsupported_explanation | 0 | Done | back Today | explanation |
| unsupported_explanation | done | completed | 0 | Done | exit | Today |
| calculation_ready | facts missing | calculation_impossible | 0 | Review facts | back/exit | fact review |
| calculation_ready | rules unavailable | rules_unavailable | 0 | Why unavailable | back/exit | explanation |
| calculation_impossible | facts complete | known | 0 | Continue | back/exit | fact review |
| calculation_impossible | facts incomplete | missing | 0 | Complete facts | back/exit | fact review |
| rules_unavailable | show explanation | rules_explanation | 0 | Retry later | back Today | explanation |
| rules_explanation | retry | calculation_ready | 0 | none | exit | availability check |
| rules_explanation | done | completed | 0 | Done | exit | Today |
| calculation_ready | compute | result | 1 result receipt | Understand | back keeps facts | widget |
| result | choose CHF 0 | completed | 1 decision, 0 plan | Finish | resume completed | Today |
| result | choose affordable amount | plan_confirmation | 0 | Confirm plan | back result | confirmation |
| plan_confirmation | confirm | completed | exactly 1 plan | Finish | interruption resumes | Today |
| any persisted state | revoke/delete | deleted | 1 tombstone + purge graph | Done | no stale resume | Today/privacy |
| deleted | done | completed | 0 | Done | exit | Today |

`completed` is terminal for this machine: entry renders Today and discards the
flow resume token; no CTA or event is accepted from `completed`.

Coach intents contain no financial value; free text never prefills a proposal.
Today surfaces 3a only while 2026 is open, probable eligibility exists, and a
fresh decision-critical fact is missing or a time-sensitive action exists.
Otherwise it stays silent: no streak, guilt, artificial urgency or daily nag.

## Canonical financial-twin contract

One encrypted on-device repository owns versioned facts. `FactRecord` contains
local UUID, schema version, subject id, fact type, normalized value/unit,
effective period, verification state, opaque allowlisted `source_ref`, captured
timestamp, user-confirmation version/time, purpose, notice/legal basis/consent
where applicable, and supersession/tombstone fields. Allowed transitions are
only `proposal → confirmed → superseded|revoked|deleted`. At most one live
confirmed fact exists per subject/type/period. Tombstones contain no value.

- No backend, synchronization, or LLM writes canonical facts in this Goal.
- Contradictions block confirmation; there is no last-write-wins.
- Every published schema version migrates from the minimum readable version.
- Corrupt/too-old data offers explicit export/recovery or consented reset;
  silent loss is forbidden.
- Keychain/Keystore is mandatory. Lock, reinstall, backup restore and key loss
  are tested fail-closed; plaintext fallback is forbidden.
- Revoke/delete purges dependent read models, results, plans, drafts, caches and
  telemetry references. Financial values, prompts, paths/names and free labels
  are forbidden in logs, crash reports and evidence.
- Idempotency key: SHA-256 of `subject_local_id`, `fact_type`,
  `effective_period`, `normalized_value`, and `confirmation_nonce`.
- Results/plans bind `fact_id@version`, ruleset hash, and `computed_at`.
  Dependency change marks them stale synchronously; no silent recomputation.

Freshness TTL: contributions/liquidity/debt/reserve 30 days; taxable income
90 days; domicile/household/LPP 365 days, always overridden by relevant events.

## Calculation and safety contract

The Fact Minimum Set for a tax estimate is calculation date/year, full fiscal
domicile, civil status, children/dependants, confession only if used, taxable
income before 3a (and spouse income only if supported), liability/source-tax
status, ordinary contributions across all providers, LPP/AVS eligibility and
every deduction required by the model. Any missing, stale, contradictory or
unsupported item yields `unavailable`; no average/marginal-rate fallback.

Engine modes are `deterministic_model_output`, `range`, or `unavailable`.
Assumptions and bounds sit adjacent to output; UI wording is always estimate.

- AVS income is used only for eligibility/cap; taxable income is used only for
  the tax estimate. Substitution is forbidden.
- Arithmetic 3a room may be described as exact only when eligibility and the
  provider inventory are confirmed.
- Every tax output is a deterministic, non-binding model estimate; never
  “exact”, filing truth, or advice.
- “Economic effort” means confirmed contribution minus estimated tax reduction;
  it is neither immediate cash debit nor investment return. If tax estimate is
  unavailable, economic effort is unavailable.
- All model output stays unavailable until the independent engine proof exists.

The widget has four distinct blocks: cash contributed now; estimated later tax
reduction; money locked/less liquid; separate withdrawal tax at exit. It never
merges contribution, saving, return and withdrawal tax. Illustrative effort
supports range/unavailable and is never shown without its components.

Affordability:

`free_cash = liquid_assets - user_selected_emergency_buffer - debts_due_90d - essential_expenses_30d`

A plan requires contribution ≤ room, free cash ≥ contribution, and monthly
surplus > 0. Overdue debt or APR ≥ 5% blocks proactive contribution plans.
Choices remain CHF 0 or a user-chosen whole-franc amount of at least CHF 1.

Tax year uses `Europe/Zurich`, 1 January–31 December. Deadline risk messaging
starts 15 December and never promises deductibility. A 2026 contribution counts
only if credited to the 3a institution by 31 December 2026; merely ordering the
payment is insufficient. Tests must cover 30/31 December and year rollover.
2025 catch-up is detected but unsupported.

## Specific mini-plan schema

`Plan3aRecord` contains local UUID/schema version, chosen amount, target date,
fact/ruleset dependencies, confirmation timestamps, reserve and state
`on_track|needs_refresh|completed|paused`. Progress moves only from a manually
confirmed contribution, never from intent. Liquidity, reserve, debt, income,
eligibility, contribution or ruleset change synchronously sets `needs_refresh`.
Unknown affordability blocks creation. MINT speaks only on material events and
does not claim daily transaction surveillance.

## Source authority and fail-closed contract

Authoritative sources are OFAS contribution guidance and 2026 amounts, AFC
Circular 18a and Form 58c 2026, VD 2026 income scale/deductions/reduction, and
the Lausanne 2025–2029 decree. URLs, byte hashes, locators, normalized claims,
parser version, rules, rounding and goldens are in `annexes/`.

Stale, divergent, expired, unavailable, or 2027 authority data makes the
affected result unavailable and keeps the flag OFF.

### Audited provenance pins

- reviewed product SHA: `516a4baccece1e950c4313b511bcf540d79ab77b`
- current post-review bundle SHA-256:
  `27f4d0d7571da1089700f6f82fa1cd9150210c98763bdccfc7d28d60bba0dfd1`
- independent receipt SHA-256:
  `ff22a3c8f9841a74ab9d77093a46e680b38eca7680395fb005b82ea44e24c401`
- canonical extraction SHA-256:
  `080658b9388b9c7eea748d904ec73b406d50b91560d2ed3b62ba7a1759fb54a0`
- provenance review: `10/10`, P1=0, P2=0, P3=0.

These pins prove provenance only. Engine, personalized tax output, advice,
activation, B0 and phase completion remain explicitly unproven.

## Privacy, compliance and regulatory boundary

LPD privacy-by-design, purpose limitation, consent/revocation/deletion,
traceable provenance, an applicability contract and AIPD are mandatory before
real exposure. They name author, reviewer, date/version, applicability,
allowed/forbidden claims, retention, export, deletion, recipients and transfers.
Ambiguity fails closed. External Swiss legal review is required
before exposing real users. No wording may imply FINMA approval or regulated
personal advice. Telemetry is allowlisted event ids plus ephemeral pseudonymous
trace ids. No fact value, source content, prompt, document metadata or free text
leaves the device. Anti-PII tests cover logs, crash payloads and evidence.

## UX, accessibility and languages

- The latest checked-in MINT design handoff and tokens are the required visual
  reference; deviations require a documented reason. Figma is optional, not a
  source of truth and never a delivery gate.
- One primary cognitive decision at a time; no finance or mathematical knowledge assumed.
- Explain the concept before asking for a decision; never shame or pressure.
- 320 px width, 200% text, WCAG 2.2 AA, colour never sole signal, 44/48 px
  targets, reduced motion, orientation, Swiss formats, VoiceOver/TalkBack
  critical path and semantic order.
- Human-quality FR/DE/IT and professional QA for EN/ES/PT.
- Formative test: five Swiss salaried adults with LPP, self-declared novices,
  declared primary language, synthetic data and a fixed uncoached script. All
  5/5 finish without dead route; median ≤3 minutes with known facts. At least
  4/5 correctly teach back contribution now, estimated tax reduction,
  illustrative effort and liquidity/locked-money consequence.
  Language/a11y incomprehension is failure; consented anonymized failure
  evidence is retained and any threshold failure reopens B3/B5.
  Neither finance professionals nor Julien are test participants.

## Evidence contract

Every promotion proof is bound to the exact product SHA it proves, records
`dirty=false`, SDK/platform/runtime, synthetic device, locale/timezone,
commands and exit codes. Any product, ruleset, or runner change invalidates
the evidence. iOS and Android use the same product SHA, with minimum-support
smokes on iOS 16 and Android API 24. Canonical current-device runtime covers
cold launch/relaunch, edit, delete, stale, offline, secure failure,
interruption, kill switch and privacy/log probes. Promotion goes through the
unique 5-condition gate (storyboard beats mapped, targeted tests green,
independent review with P1=0, cited runtime verification, 7-point fact
cycle) — no receipt chains, no closure commits.

## B0 exit gate before UI

B0a provenance is not B0. B0 requires authority ADR; Fact Minimum Set;
Fact/Plan/Dependency schemas and migrations; Calculation Contract with oracle
goldens/tolerances/rounding; state table and navigation graph;
RegulatoryApplicabilityContract; versioned legal memo; AIPD screening; threat,
key, privacy, retention/export/deletion and anti-PII contracts; classified
legacy harvest inventory; and flag/kill switch.
Any missing or ambiguous item is STOP/OFF.

## Sequential micro-batches

| Batch | Entry | Required exit proof | Does not prove |
|---|---|---|---|
| B0a | none | accepted provenance receipt and hashes | B0, engine, product |
| B0 | B0a | every B0 artifact above | UI/runtime |
| B1 | B0 | encrypted Fact lifecycle, migrations, purge and key-loss proofs | calculation |
| B2 | B1 | deterministic engine, independent oracles, mutation/rounding tests | navigation/advice |
| B3 | B2 | registered state graph, Today/Coach/read model/widget, locales/a11y runtime | plan |
| B4 | B3 | one idempotent affordability-gated Plan3a lifecycle | generic planning |
| B5 | B4 | same-SHA iOS/Android hostile runtime and separate usability evidence | deployment/phase close alone |

No batch may start because a prior document merely claims success. Each batch
requires failing test first, implementation, runtime proof where applicable,
then promotion through the unique 5-condition gate of the 2026-08-10 ADR
(storyboard mapping, targeted tests green, independent review P1=0, cited
runtime verification, 7-point fact cycle), with a clean diff and an atomic
commit.

## Completion boundary

An accepted SPEC means only that the bounded Goal is implementation-ready.
The phase remains `pre_activation` until B0 passes the unique 5-condition
gate of the 2026-08-10 ADR, then `in_progress` until every batch above has
been promoted through that same gate, and becomes `complete` only when B1–B5
are all promoted. Review angles per batch are preserved: B0 legal/compliance,
security and architecture; B1 security and architecture; B2 Swiss-domain and
architecture; B3 UX and accessibility; B4 UX and Swiss-domain; B5 UX,
Swiss-domain, legal/compliance, security and architecture. Every batch closes
only at P1=P2=P3=0, so no untracked finding can disappear into a counter.
Later product mutation invalidates completion until re-verified. Any
substantive SPEC edit goes through a reviewed PR under the 2026-08-10
protocol (Codex review, targeted revalidation of findings). No self-score,
static frame, document, TestFlight build or claim alone can close the phase.

```verify
three-a-storyboard: python3 tools/checks/mint_next_storyboard_guard.py
three-a-storyboard-hostiles: python3 -m unittest tools.checks.tests.test_mint_next_storyboard_guard
three-a-provenance: python3 tools/checks/mint_next_three_a_goal_annexes_guard.py
three-a-provenance-hostiles: python3 -m unittest tools.checks.tests.test_mint_next_three_a_goal_annexes_guard
three-a-normalizer-hostiles: python3 -m unittest tools.authority.tests.test_normalize_three_a_2026_sources
active-context: python3 tools/checks/active_context_guard.py
phase-contract: python3 tools/checks/phase_contract_guard.py
mint-rules: python3 tools/checks/mint_rules_guard.py
journey-os: python3 tools/checks/journey_os_check.py
workflow-contract: python3 tools/checks/workflow_contract_guard.py
contract-diff: git diff --check
```

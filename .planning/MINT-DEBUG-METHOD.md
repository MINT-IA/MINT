---
description: MINT Debug Method (MDM) — the implacable, expert-team debug protocol for Phase 97+ and beyond. Authored 2026-05-12 after the « 8h on infra hygiene while the coach is broken at first contact » lesson. Replaces ad-hoc debug with a codified, context-grounded, never-blind methodology.
type: methodology
phase: 97
created: 2026-05-12
authority: julien-directive-2026-05-12T08:20Z
---

# MINT Debug Method (MDM) v1

## Authority and intent

Authored after Julien's directive 2026-05-12T08:20Z :

> *« Je veux que tu aies une méthode implacable d'experts pour réparer Mint. Pour constater les bugs, pour les fixer, toujours avec le contexte, toujours avec le contexte global de code base, sans ignorer le code, sans ignorer l'univers Mint, l'univers de l'application. Pas bugué à l'aveugle, pas débugger à l'aveugle, pas coder à l'aveugle, pas corriger des choses à l'aveugle, ou ne pas les constaté. Je veux que ce soit méthodique, je veux que vous avanciez. »*

This document is the operating system for every debug cycle on MINT
from this date forward. Skipping a pillar = breach of contract.

Why this method exists : on 2026-05-11 + 2026-05-12 morning I closed
18 W7 cycles + 5 PRs while the actual product (the authenticated
coach on the canonical user flow) was returning a generic fallback
on first contact — a defect surfaced by Julien on a 30s timeout
loop after a logged-in test prompt with full user data. The pattern
was : I worked at the periphery (CI lints, baseline drift, action
bar overflow, alembic schema parity) and never repro'd the core
product flow. MDM v1 makes that pattern mechanically impossible.

## The 9 pillars

### Pillar 0 — Session-state Project CAP (orchestrator-level)

Added 2026-05-12 after Julien's directive « Est-ce que tu as bien tout
le contexte de Mint ». Reason : the per-cycle Pillar 1 CAP is BUG-
scoped. It does not establish the global project context (active
milestone, doctrine, phase decisions, open work, deferred queue).
Without that anchor, even a perfectly-executed cycle can drift from
the project's strategic frame. The morning of 2026-05-12 demonstrated
this : 8 hours of mechanically-correct W7 cycles while the canonical
authenticated coach flow was broken at first contact (P003 surfaced
by Julien's sim).

### What Pillar 0 covers

Once per session (or after any long break / context dilution / model
swap), the orchestrator reads + synthesises :

1. `.planning/STATE.md` — current milestone position, GSD state, last
   activity.
2. `.planning/MILESTONE-*-<active>.md` — current milestone doctrine
   (e.g. `MILESTONE-CHAT-AS-VERB-2026-05-09.md` for v2.9).
3. `.planning/phases/<active-phase>/CONTEXT.md` — phase locked
   decisions D-NN.
4. `.planning/phases/<active-phase>/BUGS-REGISTRY.md` (or equivalent
   work-tracking file) — IN_PROGRESS / OPEN inventory.
5. `.planning/phases/<active-phase>/deferred-items.md` — what NOT to
   bundle.
6. `docs/ROADMAP_V2.md` — shipped Phases 1-4 + current milestone
   context.
7. `SOT.md` — domain object schemas (Profile / SessionReport / etc.).
8. `gh pr list --state=open` — concurrent work streams.

### What Pillar 0 produces

A single file `.planning/cycles/_SESSION-<YYYY-MM-DD>-STATE.md`. This
file is the orchestrator's anchor and is referenced by every sub-agent
that needs global context (via the briefing preamble §8.b).

### When Pillar 0 fires

- At session-start before the first cycle.
- After any 4+ hour gap in activity.
- After a model swap (Sonnet ↔ Opus ↔ Haiku).
- After the user signals « do you have the context ? » or equivalent.
- Before any cycle whose scope might touch a different phase or
  milestone than the previous one.

Pillar 0 is NOT optional. Skipping it = drift risk. The session-state
file MUST exist before Pillar 1 CAP starts on the first bug.

## The 9 pillars

### Pillar 1 — Context Acquisition Protocol (CAP, per-cycle)

Before ANY action on a bug, read in this order :

1. **CLAUDE.md** — TOP rules (LSFin, accents, financial_core, i18n,
   0-trust) ; already auto-loaded but re-skim §9 0-trust before
   claiming anything.
2. **MEMORY.md index** (auto-loaded) — grep for keywords matching
   the bug's surface category (e.g. `coach`, `citation`, `narrator`,
   `auth`, `ios_release`).
3. **`.planning/phases/<current-phase>/<phase>-CONTEXT.md`** —
   the decisions (D-NN) that constrain THIS phase.
4. **`.planning/phases/<related-phase>/<phase>-CONTEXT.md`** for
   every adjacent phase the bug touches. Example : a coach bug
   touches Phase 94 (citation gate) + Phase 95 (DAG-INVALIDATION) +
   Phase 96 (chat-as-verb).
5. **`docs/MINT_IDENTITY.md` + `docs/VOICE_SYSTEM.md` +
   `docs/DESIGN_SYSTEM.md`** for product/identity-touching bugs.
6. **`docs/AGENTS/<surface>.md`** (flutter, backend, swiss-brain) —
   role-specific deep dives.
7. **`.planning/phases/<phase>/audit-<surface>.md`** when present —
   the multi-thousand-line sonnet audit catalogues.
8. **Code maps** in `docs/*.md` matching the surface.
9. **GREP the actual error string / fallback / function name** at
   `--include="*.py" --include="*.dart"` to surface every
   adjacent call-site. This is BLIND-spot insurance — the bug
   often lives in a sibling file the trace doesn't print.
10. **Git history** : `git log --all --oneline -20 -- <file>` for
    every file the bug surface touches.

Output : `.planning/cycles/<bug-id>/CONTEXT.md` — a written manifest
listing what was read + the key facts extracted. Without this file,
the cycle does not advance to Pillar 2.

CAP is NOT optional. It is the longest pillar. Most debug failures
come from skipping CAP.

### Pillar 2 — Expert Panel (parallel sub-agents)

Spawn 3-6 sub-agents in parallel via the `Agent` tool. Each agent
receives the **standard briefing preamble** (see Pillar 8) plus a
role-specific scope.

Default roles for backend coach bugs :
- **LLM Eval Engineer** (familiar with Anthropic API, retry logic,
  citation gate semantics)
- **Backend Architect** (FastAPI + Pydantic v2 + alembic patterns +
  feature flags)
- **LSFin Compliance Officer** (Swiss regulation, banned terms,
  fallback safety)
- **UX Researcher** (FinTech mobile, expectation framing)
- **Adversarial Tester** (tries to break the proposed fix)

Default roles for mobile UI bugs :
- Mobile UX engineer
- a11y (WCAG AA) expert
- Adversarial tester
- Design system maintainer

Default roles for infra/CI bugs :
- CI/release engineer
- Test infra dev
- Linter maintainer

Each agent returns a structured verdict :
```yaml
agent_role: <role>
hypothesis: <root cause they observe>
proposed_fix: <fix they recommend>
fix_blast_radius: <files/functions touched>
fix_cost: trivial|small|medium|large
compliance_risk: <LSFin / GDPR / banned terms>
regression_risk: <what could break>
verdict: GO|CHANGE|NOGO
notes: <free text, ≤200 words>
```

Output : `.planning/cycles/<bug-id>/PANEL.md` — table of all
verdicts + a synthesis paragraph. Synthesis MUST cite at least 2
verdicts that disagree (if all agree, ping again because that's
echo-chamber per `feedback_expert_panel_pattern`).

### Pillar 3 — Repro Ladder

Repro is NOT one test — it is a 5-level ladder. Climb the
appropriate level :

- **L0 — Static** : read code paths, document the call graph
  exhibited by the bug. Free, instant. Verifies the fault model
  on paper.
- **L1 — Unit** : isolated unit test against the function/class
  in question. Pure inputs/outputs, no network, no DB.
- **L2 — Integration** : test the FastAPI endpoint with TestClient
  + in-memory SQLite. No external HTTP.
- **L3 — System** : curl against Railway staging backend with a
  real auth token + real Anthropic API. End-to-end backend.
- **L4 — Device** : the full app on simulator + the staging
  backend. Mirrors the user-visible failure.

Bugs that fail at L3 but pass at L2 are GATE/MIDDLEWARE bugs.
Bugs that fail at L4 but pass at L3 are CLIENT/BUILD bugs. Bugs
that fail at L1 are PURE LOGIC bugs. You cannot pick the right
fix without knowing the ladder level.

Output : `.planning/cycles/<bug-id>/REPRO.md` documenting which
level fires RED with command + output verbatim.

### Pillar 4 — Root Cause Atomicity

Do not stop at the first « ah voilà ». For each bug, enumerate
EVERY hypothesis that could explain the observed symptom. Then
verify each independently. Real systems often have multiple
overlapping causes that resolve in DEPENDENCY order — fix the
root one first.

Anti-pattern : « the gate is rejecting because the threshold is
low » is a symptom-level explanation. « the gate is rejecting
because user-message-derived numbers are not in the citation
registry AND the narrator system prompt does not extract them
AND the intent classifier routes free-text to a no-grounding-pack
bundle » is a root-cause-atomic explanation. Each clause is
independently verifiable.

Output : `.planning/cycles/<bug-id>/RCA.md` — bullet list of
hypotheses, each with a deterministic verification command + its
RED/GREEN status.

### Pillar 5 — Fix Design Justification

The panel surfaces 3-5 candidate fixes. Score each on :

| Dimension | Weight | What it measures |
|---|---|---|
| `blast_radius` | High | # files / # callsites touched |
| `fix_cost` | Medium | Effort in hours |
| `compliance_risk` | High | LSFin / GDPR / accent / banned-term exposure |
| `regression_risk` | High | Likelihood of breaking adjacent flows |
| `architectural_health` | Medium | Does this fix preserve the right model? |
| `reversibility` | Medium | Can we roll it back trivially? |

Pick the highest-weighted-score option. The CHEAPEST fix is
rarely the best — Julien's directive 2026-05-12T08:20Z explicitly
rejects « chemin court ».

Output : `.planning/cycles/<bug-id>/FIX-DECISION.md` — ADR-style
document with the 5 alternatives, the scoring matrix, and the
chosen path with rationale. **Counter-arguments + data gaps**
section is mandatory (per `feedback_audit_verification_logs`).

### Pillar 6 — Verification Cube (4 dimensions of GREEN)

A bug is RESOLVED when all 4 are GREEN, not 1 :

1. **Code correctness** : unit tests pass.
2. **Integration correctness** : backend tests + linter green.
3. **System correctness** : L3 curl repro now returns expected.
4. **User correctness** : sim screenshot OR Julien-confirmed
   that the user flow visibly works.

NEVER claim RESOLVED with only 1-2 dimensions. The 2026-05-11
W7 iter#6 commit claimed « GREEN gates » on unit + Maestro local,
ignored TestFlight archive (dimension 4), and broke production.
That class of failure is what MDM kills.

Output : `.planning/cycles/<bug-id>/VERIFICATION.md` — 4-row
table, each row with a deterministic citation (file:line / curl
output / sim screenshot path / Julien chat reference).

### Pillar 7 — Regression Lock (3 layers)

The fix must come with a regression that prevents the same bug
class from recurring :

1. **Test** in the relevant `tests/` file. Asserts the GREEN
   behaviour. Lives in CI.
2. **Lint or static check** when the bug class is recognizable
   structurally (e.g. iOS capability drift, accent violation,
   hardcoded color). Lives in `tools/checks/` + lefthook.
3. **Documentation** : `.planning/cycles/<bug-id>/LOCK.md`
   describing the failure mode + the regression contract, so
   future debuggers know WHY the test exists.

Without all 3 layers, the bug is FIXED but not LOCKED. Move on
ONLY when LOCK is complete.

### Pillar 8 — Cycle Artifact and Sub-agent Briefing Preamble

#### 8.a Cycle artifact directory

Every cycle produces a `.planning/cycles/<bug-id>/` folder containing :

```
.planning/cycles/P003/
├── CONTEXT.md       # Pillar 1 output
├── PANEL.md         # Pillar 2 output
├── REPRO.md         # Pillar 3 output
├── RCA.md           # Pillar 4 output
├── FIX-DECISION.md  # Pillar 5 output
├── VERIFICATION.md  # Pillar 6 output
└── LOCK.md          # Pillar 7 output
```

This folder is the cycle's ground truth. PR descriptions link to
it. BUGS-REGISTRY.md row links to it. The HTML evidence report
embeds excerpts.

#### 8.b Sub-agent briefing preamble

Every `Agent` tool invocation receives this preamble as the FIRST
section of the prompt, before the role-specific scope :

```
=== MINT PROJECT CONTEXT (mandatory, do not skip) ===

ROLE : You are <role> on the MINT debug team. MINT is a Swiss
financial lucidity app (Flutter + FastAPI on Railway). 18 life
events, archetype-aware, 18-99 user base. CLAUDE.md is the
source of truth for project conventions ; you may assume the
caller has read it.

DISCIPLINE :
- LSFin TOP rules : NEVER « garanti / optimal / parfait /
  sans risque / meilleur ». Use « pourrait / envisager /
  adapté ». Detail : docs/AGENTS/swiss-brain.md §1.
- Accent FR 100% mandatory. ASCII « e » where « é » belongs = bug.
- financial_core reuse : lib/services/financial_core/ is source
  of truth ; never re-implement.
- 0-trust : banned phrases without deterministic citation in
  the same response : « shipped / closed / ready / works /
  validated / green ». PR opened ≠ shipped. Tests passing ≠
  feature working.

RELEVANT MEMORY (consult before recommending) :
<list of 3-7 memory entry filenames pertinent to the bug,
e.g. feedback_ios_entitlements_block_testflight.md>

CURRENT BUG : <bug-id> — <one-sentence problem statement>
LADDER LEVEL ALREADY EXERCISED : <L0-L4 already done>
CONTEXT MANIFEST : .planning/cycles/<bug-id>/CONTEXT.md

SCOPE LIMIT FOR YOUR ROLE : <one paragraph>
SUCCESS CRITERIA : <deterministic test or check>
REPORTING FORMAT : <yaml schema from Pillar 2>

DO NOT exceed scope. DO NOT propose fixes outside your role.
DO NOT cite project conventions you cannot verify from the
context manifest. If uncertain, report uncertainty — never
fabricate.
```

This preamble is non-negotiable. If a sub-agent prompt does not
contain it, the cycle is invalid.

## Cycle entry conditions

A cycle starts ONLY when :
- The bug is in `97-BUGS-REGISTRY.md` (or equivalent registry for
  the active phase).
- The bug has a single, atomic title (no « and » / « + » that bundle
  multiple defects).
- The bug score is computed (severity × blast / fix_cost).

If the bug is too large (score involves multi-perimeter / large
fix-cost), it goes through GSD phase planning instead (per memory
`feedback_gsd_workflow_default`). MDM is for single-perimeter
debug cycles ; multi-perimeter work goes through GSD then folds
into MDM cycles for each perimeter.

## Cycle exit conditions

A cycle exits with `RESOLVED` ONLY when :
- All 8 pillars produced their artifact.
- The PR is merged to `dev`.
- The Verification Cube has 4 GREEN rows.
- The Regression Lock has its 3 layers committed.
- The BUGS-REGISTRY row is updated to `status: RESOLVED` with the
  fix commit SHA + the cycle folder link.

Until all of the above hold, the cycle is `IN_PROGRESS`. There is
NO middle state.

## Anti-patterns this method kills

| Failure mode (observed) | Pillar that blocks it |
|---|---|
| « It's a small fix, skip the context read » | Pillar 1 mandatory CAP |
| « Tests passing means feature working » | Pillar 6 4-dimension Cube |
| « PR opened means shipped » | Pillar 6 + memory 0-trust |
| « 1 hypothesis is enough » | Pillar 4 atomicity |
| « The cheapest fix » | Pillar 5 weighted scoring |
| « I'll add the regression test later » | Pillar 7 LOCK is gating |
| « The sub-agent will figure out the context » | Pillar 8 preamble |
| « Bundle 18 fixes in 1 PR » | Cycle entry single-atomic rule |

## Reference invocation script

For each new bug picked, the orchestrator (this assistant) runs :

```
1. Add row in 97-BUGS-REGISTRY.md (or active phase).
2. mkdir .planning/cycles/<bug-id>/
3. Pillar 1 CAP → write CONTEXT.md
4. Pillar 2 Panel → spawn 3-6 Agent() calls in parallel with the
   8.b preamble, collect verdicts → write PANEL.md
5. Pillar 3 Repro → climb the ladder → write REPRO.md
6. Pillar 4 RCA → enumerate hypotheses with verifications →
   write RCA.md
7. Pillar 5 Fix design → scoring matrix → write FIX-DECISION.md
8. Implement the fix in code.
9. Pillar 6 Verification → 4-row Cube → write VERIFICATION.md
10. Pillar 7 Regression → test + lint + doc → write LOCK.md
11. Open isolated PR, link cycle folder.
12. Update BUGS-REGISTRY row → RESOLVED + commit SHA + cycle link.
```

No step is optional. No step is order-flexible (1-2 may parallelize
the CAP read with first panel spawn but only after CAP is at least
60% complete).

## First adopter : P003 — Coach fallback on authenticated first prompt

The cycle that authors this document is its first adopter. P003 =
the bug Julien surfaced 2026-05-12T08:13Z : authenticated coach
returns the canned `Je n'ai pas cette donnée pour l'instant`
fallback on first prompt even when the user supplies a complete
financial profile inline. Backed by `citation_parser.py:148` ;
ties to P001 (gate-correct thresholds below target). See
`.planning/cycles/P003/` for the live cycle artifacts.

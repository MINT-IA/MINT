# Phase 91 Stage 0 — Telemetry Baseline (D-07)

> **TLDR:** Methodology to compute the empirical "Sonnet under-calls
> save_fact" rate over 7 days of production logs. The grep target is the
> `profile_extractor: persisted X fact(s)` log line emitted by
> `services/backend/app/api/v1/endpoints/coach_chat.py:2511`. This rate
> motivates the Phase 91 cost case (RESEARCH §6 DG-3): if it falls below
> 10%, the Phase 91 dual-LLM cost case weakens and the Stage 4 staging
> flip should be reconsidered.

- **Date authored:** 2026-05-09
- **Phase:** 91-mvp-extractor-v2
- **Wave:** 0 (pre-flight scaffolding — Task 0.3 Part B)
- **Source log line:** `services/backend/app/api/v1/endpoints/coach_chat.py:2511`
- **Window:** last 7 days production
- **Author:** Claude (executor) — methodology only; raw computation pending
  Julien run (executor has no production log access from inside Claude
  Code, per memory `feedback_blockers_ask_dont_defer.md`)

## Why this baseline matters

Per RESEARCH §1 Symptoms + §6 DG-3, Phase 91 is justified by the
hypothesis that the single-LLM coach Sonnet path under-calls
`save_fact` on fact-bearing user turns. The regex floor at
`profile_extractor.py:208-220` exists precisely because production
evidence (4 weeks at 2026-04-13 onwards) showed the LLM was unreliable
at fact extraction even with the imperative MANDATORY block in
`coach_tools.py:496-521`.

This baseline quantifies the empirical lift available to Phase 91
**before** Stage 1 ships. If the under-call rate is small (<10%), the
+90% per-turn cost regression (RESEARCH §5) is not justified by the
quality gain — the Stage 4 staging flip should be reconsidered.

## Methodology

The grep target is the log line:

```
profile_extractor: persisted X fact(s) user=USER_ID topics=[...] summaries=[...]
```

It is emitted at `coach_chat.py:2511` for every authenticated coach
turn that ran the regex extractor. Anonymous-chat turns hit the
`elif extracted_facts and not (_user and _user.id)` branch at L2517 and
do NOT log the same string — Stage 0 baseline focuses on authenticated
turns where persistence happens.

### Step 1 — Pull 7 days of production logs

Choose the log source available in production. MINT runs on Railway
with optional Sentry breadcrumbs:

**Railway CLI (preferred):**

```bash
# Pull all backend logs from the last 7 days, filter to the target line.
railway logs --service mint-backend --duration 7d \
  | grep "profile_extractor: persisted" \
  > /tmp/extractor_baseline_raw.txt
```

**Sentry breadcrumbs (alternative):**

If Railway log retention is shorter than 7 days, pull from Sentry:

```
project:mint-backend
message:"profile_extractor: persisted"
event.timestamp:>now-7d
```

Export the breadcrumb table to TSV.

### Step 2 — Compute the under-call rate

For each line, extract the fact count (`X` in `persisted X fact(s)`):

```bash
awk '{
  match($0, /persisted ([0-9]+) fact/, m);
  if (m[1] != "") print m[1]
}' /tmp/extractor_baseline_raw.txt \
  | sort | uniq -c \
  > /tmp/extractor_baseline_distribution.txt
```

This gives the distribution of fact counts per turn.

### Step 3 — Compute the under-call rate on fact-bearing turns

The under-call rate is **NOT** simply « 0 fact lines / total lines »
because many turns legitimately contain no facts (« merci », « ok »,
« je comprends »). The denominator must be **fact-bearing turns** —
turns where the user message contained at least one extractable fact.

Two practical approximations:

1. **Heuristic:** filter the input log to turns where the user message
   contains at least one digit OR a Swiss canton name OR a known fact
   keyword (« salaire », « né en », « j'ai », « k CHF »).

2. **Hand-sample:** pull 100 random turns from the 7-day window, label
   each by hand as fact-bearing or not, then compute:

   ```
   under_call_rate = count(fact_bearing AND persisted == 0)
                   / count(fact_bearing)
   ```

The hand-sample approximation is the more defensible figure for the
Phase 91 cost case.

### Step 4 — Cross-reference with the regex floor

Some turns may show `persisted 0` even when the user message contained
a fact, because:

- The fact was already persisted (idempotent on key).
- The regex extractor missed the format and fell through (the LLM
  extractor's job in Wave 2+).
- The user has `persistence_consent=False` (logged but not persisted).

Subtract these legitimate-zero cases from the under-call count.

## Raw output

**TO RUN** — placeholder section. Once Julien runs the Step 1 command
above, paste the raw distribution output here:

```text
# Pending Julien's Railway / Sentry pull. Expected format:
#       42 0
#       89 1
#       23 2
#        7 3
#        2 4
# (count_of_turns count_of_facts_persisted)
```

## Empirical under-call rate

**TO COMPUTE** after raw output is filled. Format:

- Total fact-bearing turns sampled: `<N>`
- Turns with `persisted 0`: `<K>`
- Under-call rate: `<K/N> = <X%>`

## Interpretation

**TO WRITE** after under-call rate is computed. Decision matrix per
RESEARCH §6 DG-3:

| Under-call rate | Phase 91 disposition |
|----------------|---------------------|
| ≥ 30% | Strong cost case — proceed with Stage 1-5 as planned. |
| 10-30% | Cost case is borderline — proceed but tighten the Stage 4 staging soak success criteria (require 50% reduction in `save_fact` no-op rate). |
| <10% | Cost case is weak — pause Phase 91, file an ADR documenting the lower-than-hypothesized lift, and consider scoping Phase 91 to ONLY the « narrator with reduced tool list » half (skip the extractor LLM split). |

## Open dependency / handoff to Julien

This file is a **methodology spec** at Wave 0, not a computed result.
Per memory `feedback_blockers_ask_dont_defer.md`, the executor
(Claude Code) does not have production log access from inside this
session. The PR description for Wave 0 lists this as an open
dependency for Julien to fill **before** Stage 4 staging flip
(NOT a blocker for Wave 0-2 ship).

When the raw output is computed, update this file in-place and amend
the Phase 91 Stage 0 commit (or land a follow-up commit
`docs(91-00): fill extractor baseline raw output`).

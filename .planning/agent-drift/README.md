# Agent drift dashboard (CTX-02, Phase 30.5)

**Dev-only tool** — surface for 4 metrics measuring how well Claude Code agents
follow MINT doctrine. Per D-09 this is a CLI + nightly markdown report, NOT a
mobile route. Per D-10 the underlying store is SQLite at
`.planning/agent-drift/drift.db` (gitignored). Per D-12 a single baseline J0
snapshot is captured pre-refonte and locked.

## Quick start

1. `python3 tools/agent-drift/dashboard.py init` — create `drift.db` (idempotent).
2. `python3 tools/agent-drift/dashboard.py ingest` — parse last 7d git log + JSONL transcripts + `context_hits.jsonl` + `golden/results.jsonl` into `drift.db`.
3. `python3 tools/agent-drift/dashboard.py report` — render `.planning/agent-drift/{today}.md`.
4. `python3 tools/agent-drift/dashboard.py baseline` — lock baseline J0 snapshot. **Run ONCE pre-refonte** (D-12). Re-running exits 1 unless `.baseline-lock` is deleted.
5. `python3 tools/agent-drift/dashboard.py golden-run` — run 20 golden prompts via `claude -p` (A7 AVAILABLE from Plan 00 spike).
6. `python3 tools/agent-drift/dashboard.py compare-to .planning/agent-drift/baseline-J0.md` — compare current state vs baseline (CTX-05 spike will harden this into a strict >5% regression gate).

## The 4 metrics (D-11)

| ID | Name | What it measures | Source |
|----|------|------------------|--------|
| a | **Drift rate** | % commits by `Co-Authored-By: Claude` (last 7d) with >=1 lint violation | `git log` × `tools/checks/{accent_lint_fr,no_hardcoded_fr}.py` |
| b | **Context hit rate** | % sessions where `gsd-prompt-guard.js` detected a rule violation at first tool_use | `.claude/hooks/gsd-prompt-guard.js` -> `context_hits.jsonl` |
| c | **Token cost / session** | Mean total tokens per session (input + output + cache) | `~/.claude/projects/-Users-.../*.jsonl` usage sums |
| d | **Time-to-first-correct-output** | Avg # turns to produce lint-clean output on 20 golden prompts | `tools/agent-drift/golden/run.sh` -> `golden_runs` |

## Data sources

- `~/.claude/projects/-Users-julienbattaglia-Desktop-MINT/*.jsonl` — read-only, local Claude Code transcripts.
- `git log --since='7 days ago'` — read-only, local repo history.
- `.planning/agent-drift/context_hits.jsonl` — append-only, written by the
  extended `.claude/hooks/gsd-prompt-guard.js` (v1.33.0+).
- `tools/agent-drift/golden/results.jsonl` — written by the nightly
  `golden/run.sh` harness (A7 AVAILABLE, uses `claude -p --output-format json`).

## Storage

- SQLite at `.planning/agent-drift/drift.db` (gitignored per D-10).
- Markdown reports committed under `.planning/agent-drift/YYYY-MM-DD.md`.
- `baseline-J0.md` + `.baseline-lock` frozen per D-12 (first is committed,
  second is gitignored and enforces the one-shot-capture contract).

## Nightly cadence

Invoke `bash tools/agent-drift/nightly.sh` via cron (opt-in per developer).
Phase 30.5 ships the on-demand flow; nightly cron wiring is deferred to
Phase 31+ once the instrumentation is battle-tested.

## Schema (drift.db)

Five tables (verbatim from `30.5-RESEARCH.md` §Code Examples Example 2):

```
sessions       (session_id, started_at, transcript, tokens totals)
commits        (sha, author, committed_at, subject)
violations     (id, sha, lint, file_path, line_number, snippet, detected_at)
context_hits   (id, session_id, hit_type, rule_id, tool_use_index, detected_at)
golden_runs    (id, run_at, prompt_id, turns_to_correct, passed_lints, failed_lints, output_excerpt)
```

## Threat model

Per Plan 01 §threat_model:

- Dev-tool only, no runtime user-facing surface.
- Token counts are stored as SUMS — no message content crosses into the drift.db.
- `drift.db` + `context_hits.jsonl` + `.baseline-lock` are gitignored; local to dev host.
- `gsd-prompt-guard.js` extension is append-only and never-throw (Patch 1);
  failures route to `/tmp/gsd-prompt-guard-error.log`.

## Troubleshooting

- `database is locked` during ingest → a previous `dashboard.py` process is
  still running. `pkill -f dashboard.py` and retry.
- `baseline` exits 1 with "already captured" → expected; baseline is D-12-locked.
  Delete `.planning/agent-drift/.baseline-lock` ONLY if you understand the
  moving-target trade-off (usually you do NOT want to recapture).
- `golden-run` reports "A7 fallback" → `claude` CLI not on PATH. See Plan 00
  spike `tools/agent-drift/spikes/A7_headless_result.txt` for status.

## Related ADRs / plans

- `decisions/ADR-20260419-v2.8-kill-policy.md` — Phase 30.5 is non-empruntable.
- `.planning/phases/30.5-context-sanity/30.5-CONTEXT.md` — D-09..D-12 decisions.
- `.planning/phases/30.5-context-sanity/30.5-RESEARCH.md` — §Code Examples.
- Phase 34 GUARD-04 will replace the early-ship lints with CI-gated versions.

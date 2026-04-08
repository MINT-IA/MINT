# Reverse-Krippendorff Generation Test

**Phase 11 / VOICE-06 — anti-tone-locking gate.**

## What this is

A one-shot script that produces 10 Claude generations forced to N4 register,
shaped exactly like `tools/voice_corpus/frozen_phrases_v1.json` so the Plan 02
rater UI can load them blind alongside the 50 frozen reference phrases.

The point is **adversarial against ourselves**: if Claude generates at the
system-prompt-requested N4 but the testers rate the outputs as N3 or N5, the
system prompt is tone-locked the wrong way and Phase 11 cannot ship.

**Pass gate:** ≥ 7 / 10 outputs majority-classified as N4 by the 15-tester
panel. Below that, prompt revision + re-run is required (not re-rating).

## Files

| Path | Purpose |
|---|---|
| `reverse_test_contexts.json` | 10 trigger contexts (Julien+Lauren life events) |
| `reverse_generation_test.py` | Runner — `--fixtures` (default) or `--live` |
| `reverse_outputs_fixtures/ctx_NN.txt` | Pre-canned N4 generations (committed) |
| `reverse_outputs_v1.json` | Final blob the rater UI loads (regenerated each run) |

## Workflow

### 1. Generate the blob

```bash
# Default: uses committed fixtures (reproducible, no API key)
python3 tools/krippendorff/reverse_generation_test.py

# Live: calls the Claude API at forced N4 (manual, before tester round)
ANTHROPIC_API_KEY=sk-... python3 tools/krippendorff/reverse_generation_test.py --live
```

This writes `tools/krippendorff/reverse_outputs_v1.json` (10 entries, each
with `_expected_level: "N4"`).

### 2. Send the blob to the rater UI

The Plan 02 rater UI (`tools/krippendorff/rater_ui.html`) loads both
`frozen_phrases_v1.json` AND `reverse_outputs_v1.json`, merges them,
shuffles per-tester, and **strips `_expected_level` before render**
(T-11-08 mitigation — testers rate blind).

Each tester sends back a JSON blob with their N1–N5 verdicts.

### 3. Compute the pass gate

Aggregate the 15 testers' verdicts. For each `reverse_NN`, take the majority
vote level. Count how many resolve to N4. If ≥ 7 → pass. If < 7 → revise the
system prompt in `claude_coach_service.py` (Plan 11-01's surface), regenerate
with `--live`, re-rate. Iterate fast.

## The `force_level` wrapper

The runner uses `force_level_n4_directive()` (defined in
`reverse_generation_test.py`) to append an explicit N4 directive to the
standard coach system prompt. This wrapper:

- is **keyword-only** (cannot be called positionally from a request handler);
- is **additive** (preserves the entire base system prompt — no compliance
  rules can be silently stripped);
- is a **pure string transform** (no LLM call, no gate bypass, no side
  effect on `Profile.n5IssuedThisWeek` or any other state);
- is **internal-only** (no HTTP endpoint, no external surface).

These properties are enforced by
`services/backend/tests/coach/test_force_level_override.py` (T-11-07
mitigation). If anyone adds a positional call, an LLM call, or a reference
to `ComplianceGuard` / `n5_weekly_gate` / `fragility_detector` inside the
wrapper, that test red-builds.

## Regenerating the fixture set

The committed fixtures in `reverse_outputs_fixtures/*.txt` are the placeholder
N4 generations that ship with this plan. Before the actual tester round, run
`--live` to regenerate against the current `claude_coach_service.py` system
prompt and overwrite `reverse_outputs_v1.json`. Commit the regenerated file
into the rater branch but do NOT overwrite the txt fixtures unless you also
want to update the deterministic baseline.

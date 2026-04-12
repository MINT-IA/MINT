# Voice Cursor Test — Krippendorff α Report

> **Status: TEMPLATE — awaiting real tester output (Phase 11 Plan 11-02 Task 3, wall-clock 2-3 weeks).**
>
> When the 15 rater blobs land in `tools/voice_corpus/ratings/` (or are merged
> into a single tester output JSON), regenerate this report by running:
>
> ```bash
> python3 tools/voice_corpus/krippendorff_runner.py path/to/tester_output.json
> ```
>
> The runner overwrites this file with the real numbers and the final
> ship-gate verdict.

## Methodology (target)

- 50 frozen voice-cursor phrases — `tools/voice_corpus/frozen_phrases_v1.json`
- 15 blind raters classify each phrase on the 5-point ordinal scale
  N1 (murmure) → N5 (tonnerre)
- Weighted-ordinal Krippendorff α (Krippendorff 2011 §5.4)
- 1000-iteration bootstrap over raters with replacement, 95% CI from
  2.5/97.5 percentiles, seed 42
- Per-level N4 / N5 α computed on the high-tone slice {N4, N5}

## Ship gates

| gate | threshold |
| --- | --- |
| overall α (point) | ≥ 0.67 |
| overall α (95% CI low) | ≥ 0.60 |
| per-level N4 α | ≥ 0.67 |
| per-level N5 α | ≥ 0.67 |

## Results

_To be populated by `krippendorff_runner.py` once real ratings are available._

| metric | value |
| --- | --- |
| α overall | _pending_ |
| α 95% CI | _pending_ |
| α per-level N4 | _pending_ |
| α per-level N5 | _pending_ |

## Verdict

_Pending real tester output. If any gate fails after the runner is executed:
either revise the few-shot prompts in `services/backend/app/services/claude_coach_service.py`
(Plan 11-03) or rework the offending phrases in `frozen_phrases_v1.json`,
re-rate, and re-run the runner._

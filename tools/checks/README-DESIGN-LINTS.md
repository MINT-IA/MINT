# MINT Design Lints — README

> Phase 1 of the chat-as-verb milestone (MVP-DESIGN-LINTS-V1, 2026-05-09).
> 5 Python lint scripts that block net-new design-system drift.
> Soft-warn at `git commit` (lefthook). Hard-fail at PR (CI).

## Why these lints exist

After 18 months of Flutter development the MINT design system carries
real drift (705 raw `fontSize:` literals, 100 GoogleFonts calls, 154 raw
button widgets, 1545 BorderRadius sites, etc.). The chat-as-verb milestone
ships two upcoming sweep phases that fix the drift:

- **Phase 3 — MVP-FONTS-TOKENS-V2** drops `google_fonts` and switches to
  bundled Supreme + Gambarino + Fraunces.
- **Phase 4 — MVP-CTA-UNIFICATION-V1** lands `MintCTA.{primary,secondary,
  tertiary,destructive}` and `MintRadius.{xs..pill}`.

Without enforcement, those sweep PRs would themselves re-introduce the
same drift while editing files. Phase 1 (this README) lands first to
freeze a baseline of grandfathered violations and fail any PR that adds a
new one.

## The 5 lints at a glance

| Script (`tools/checks/`) | Pattern | Phase 1 baseline | Pivot phase |
|---|---|---|---|
| `prefer_mint_color_token.py` | `Color(0xFF...)` + Material `Colors.<name>` | 31 | (none — small enough to stay in soft mode) |
| `prefer_mint_text_style.py` | `fontSize: <N>` literals | 705 | Phase 3 (FONTS-TOKENS-V2) |
| `prefer_mint_fonts.py` | `GoogleFonts.<x>` + raw `fontFamily: '...'` | 106 | Phase 3 (drops `google_fonts`) |
| `prefer_mint_radius.py` | `BorderRadius.circular(N)` outside allowlist | 42 | Phase 4 (lands `MintRadius`) |
| `prefer_mint_cta.py` | raw `(Elevated|Outlined|Filled|Text)Button(` | 152 | Phase 4 (lands `MintCTA`) |

Total grandfathered: **1036 entries**. See
`.planning/audit/ui_drift_baseline_2026-05-09.txt` for the full audit
summary + pivot plan.

## How baselines work

Each lint reads a sibling baseline file under `tools/checks/baselines/`,
e.g. `prefer_mint_color_token.baseline.txt`. The baseline is a sorted
list of `path:line: snippet` rows.

Pseudo-code:

```python
current  = scan(apps/mobile/lib/**/*.dart)   # set of path:line: snippet
baseline = read(baselines/<lint>.baseline.txt)
new      = current - baseline
if new:
    fail(diagnostic)
else:
    pass
```

This means:
- **Pre-existing violations are silent** — they live in the baseline, the
  lint passes against them.
- **Net-new violations fail** — even on a 1-line PR, if the diff
  introduces one violation that's not in the baseline, the lint fails.
- **Removed violations are silent** — when a sweep PR fixes a violation,
  the lint still passes (the baseline simply has an extra entry that
  matches nothing). The `--update-baseline` flag re-snapshots and
  shrinks the baseline file as a follow-up commit.

## Running a lint locally

```bash
# Full-repo scan (CI mode):
python3 tools/checks/prefer_mint_color_token.py

# Single-file scan (lefthook mode):
python3 tools/checks/prefer_mint_text_style.py --file apps/mobile/lib/screens/landing/landing_screen.dart

# Multiple files:
python3 tools/checks/prefer_mint_radius.py --file apps/mobile/lib/foo.dart --file apps/mobile/lib/bar.dart

# Custom scope (for tests):
python3 tools/checks/prefer_mint_cta.py --scope-root /tmp/my-fixture-tree
```

Exit codes:
- `0` — clean, OR `--update-baseline` succeeded, OR baseline absent (graceful seed mode).
- `1` — net-new violations (diagnostic on stdout).

## Updating a baseline (after a sweep PR)

When Phase 3 or Phase 4 (or any future sweep) reduces violations, the
baseline file is now larger than the actual violation set. To shrink it:

```bash
# 1. Sweep the violations as part of the sweep PR.
# 2. From the sweep PR branch, run --update-baseline:
python3 tools/checks/prefer_mint_text_style.py --update-baseline

# 3. The baseline file is rewritten. Commit it as part of the same PR
#    (or as a follow-up commit) with message:
#      chore(design-lints): shrink prefer_mint_text_style baseline (-N entries)
```

CI never auto-updates the baseline. All updates are explicit, reviewed
human commits. This catches the « developer adds to baseline rather
than fixes » anti-pattern (PLAN.md §Counter-arguments).

## Per-line ignore syntax

Sometimes a violation is unavoidable — a one-off pixel-shift fix, an
asset-driven literal, a third-party widget integration. Use the inline
ignore marker on the same line:

```dart
return Container(
  color: const Color(0xFFAB12CD), // lint-ignore: prefer_mint_color_token
);
```

The marker name matches the lint script stem. Each lint accepts only its
own marker — you cannot escape `prefer_mint_radius` with
`// lint-ignore: prefer_mint_color_token`.

This is the only escape hatch. We track aggregate `// lint-ignore:`
counts via a quarterly grep audit to detect abuse (RESEARCH §Security
Domain).

## CI vs. lefthook (the hard / soft split)

| Stage | When | Behaviour | Why |
|---|---|---|---|
| **lefthook pre-commit** | every `git commit` | SOFT-warn: lint runs, prints diagnostic, but `\|\| true` returns 0 so the commit completes | Pre-commit must be fast (≤ 1.5 s) and non-blocking — devs must be able to commit WIP without fighting the linter |
| **CI / Design lints workflow** | every PR | HARD-fail: lint exits 1 on net-new, blocks PR merge | Merge gate. The point of the lint. |

Both invocations use the SAME baseline file and the SAME script. The
only difference is the wrapping shell behaviour.

## What these lints do NOT enforce (deferred)

The following are out of scope for Phase 1 and live in their own
perimeters:

- `MintRadius` token doesn't exist yet → LINT-04 enforces a numeric
  allowlist `{2,4,6,8,10,12,14,16,20,24,999}`. Phase 4 will land the
  token and tighten LINT-04 to import-path enforcement.
- `MintCTA` widget doesn't exist yet → LINT-05 is baseline-only with a
  diagnostic message that points to Phase 4.
- `MintCurrencyText` widget for `Text('CHF...')` literals → deferred to
  Phase 5 (CITATION-GATE) which lands the widget.
- Raw `EdgeInsets.fromLTRB`, `SizedBox(height:)`, `Duration(milliseconds:)`,
  `withOpacity()` → out of scope (no clear allowlist semantic; volumes
  too high). Tracked as future perimeters in
  `.planning/audit/ui_drift_baseline_2026-05-09.txt`.
- IDE quick-fixes (would require Dart `analysis_server_plugin`) →
  deferred until that ecosystem reaches v1.0.

## Architectural choice: Python regex over Dart `analysis_server_plugin`

We chose **Python regex** over **Dart custom_lint / analysis_server_plugin**
because:

- `custom_lint` (Invertase) was archived 2026-03-24.
- `analysis_server_plugin` is still pre-1.0 and has no production
  precedent for raw-pattern lints in Flutter.
- MINT already runs ~22 Python lints under `tools/checks/`. The team
  pattern is well-known.
- The 5 lints are 80% pattern-matching, 20% semantics. AST is overkill.
- 2-day budget per Phase 1 of the milestone.

If `analysis_server_plugin` matures (post-1.0) and the false-positive
rate of regex becomes a problem (PLAN-CHECK §3 R4), Phase v2 lints will
re-evaluate.

## File index

```
tools/checks/
  prefer_mint_color_token.py        # LINT-01
  prefer_mint_text_style.py         # LINT-02
  prefer_mint_fonts.py              # LINT-03
  prefer_mint_radius.py             # LINT-04
  prefer_mint_cta.py                # LINT-05
  README-DESIGN-LINTS.md            # this file

  baselines/
    prefer_mint_color_token.baseline.txt
    prefer_mint_text_style.baseline.txt
    prefer_mint_fonts.baseline.txt
    prefer_mint_radius.baseline.txt
    prefer_mint_cta.baseline.txt

  tests/
    __init__.py
    _lint_test_helpers.py            # shared LintTestCase + load_lint helpers
    test_prefer_mint_color_token.py  # 9 tests
    test_prefer_mint_text_style.py   # 8 tests
    test_prefer_mint_fonts.py        # 6 tests
    test_prefer_mint_radius.py       # 8 tests
    test_prefer_mint_cta.py          # 7 tests
    test_design_lints_smoke.py       # integration smoke (Wave 3)
    fixtures/                        # 15 synthetic .dart fixtures (3 × 5 lints)

.github/workflows/
  design-lints.yml                   # CI hard-fail workflow

lefthook.yml                         # pre-commit soft-warn config
```

## Counter-arguments and data gaps

Per Karpathy Wiki Pattern §3 (every decision artifact must surface them):

- **Counter-argument**: « 1036 grandfathered entries is theatre — the
  lint catches nothing on day-one. » Rejected: it catches every PR opened
  *after* day-one, which is the strategic intent. The milestone explicitly
  orders « lints first, sweep second ».
- **Data gap**: empirical false-positive rate is unmeasured. Synthetic
  fixtures cover canonical cases; real-world rate becomes visible only on
  the first 3 PRs that touch `apps/mobile/lib/**/*.dart`. Tracked at
  phase close in VERIFICATION.md.
- **Data gap**: lefthook latency on a 100-file sweep PR is unmeasured
  (current empirical: 0.26 s on 1 file). If sweep PRs exceed 1.5 s,
  fold into a single dispatcher per RESEARCH §Pitfall 3.

## Sources

- `.planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md` — milestone strategy
- `.planning/phases/90-mvp-design-lints-v1/RESEARCH.md` — drift inventory + tool decision
- `.planning/phases/90-mvp-design-lints-v1/PLAN.md` — task breakdown (T1-T12) + 5-gate exit
- `.planning/phases/90-mvp-design-lints-v1/PLAN-CHECK.md` — verifier amendments R1/R2/R3
- `.planning/audit/ui_drift_baseline_2026-05-09.txt` — per-lint baseline summary

---
name: MVP-DESIGN-LINTS-V1 — Research
description: Research artifact for Phase 1 of the Chat-as-Verb milestone. Establishes that 4-5 design-system lints should ship as Python scripts under `tools/checks/`, wired in CI + lefthook (mirroring the existing `wcag_aa_all_touched.py`, `s0_s5_aaa_only.py`, `accent_lint_fr.py` pattern), with a baseline-snapshot pattern (KNOWN-MISSES.md / count file) — NOT as a Dart `custom_lint` package. Documents the actual MINT drift inventory (which is materially smaller than the audit headline, but concentrated in fontSize / TextStyle / BorderRadius / button widgets) and proposes 5 concrete lint specs with allowlists tuned to MINT's existing token API.
type: research
date: 2026-05-09
phase: MVP-DESIGN-LINTS-V1
milestone: CHAT-AS-VERB-2026-05-09
status: ready
related:
  - .planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md
  - .planning/decisions/2026-05-09-7-panel-comprehensive-audit/SYNTHESIS.md
  - .planning/decisions/2026-05-08-perimeter-mvp-fonts-tokens-v2/STUB.md
sources:
  - pub.dev/packages/custom_lint (v0.8.1, Invertase, ARCHIVED 2026-03-24)
  - pub.dev/packages/analysis_server_plugin (v0.3.15, official Dart team)
  - pub.dev/packages/dart_code_metrics (DISCONTINUED, paywalled)
  - charlescyt.github.io/create-your-own-lint-rules-with-custom-lint
  - apps/mobile/lib/theme/{colors,mint_text_styles,mint_spacing,mint_motion}.dart
  - tools/checks/{accent_lint_fr,no_hardcoded_fr,banned_terms_arb,wcag_aa_all_touched,s0_s5_aaa_only,landing_no_numbers}.py
  - lefthook.yml
  - .github/workflows/ci.yml
---

# Phase 1: MVP-DESIGN-LINTS-V1 — Research

**Researched:** 2026-05-09
**Domain:** Static analysis / linting of Flutter design-system tokens (colors / typography / spacing / radii / buttons)
**Confidence:** HIGH on existing-codebase facts, HIGH on tool ecosystem, MEDIUM on the audit's headline drift counts (verified mostly inflated — see §Drift inventory)

## Summary

The phase ships **4-5 Python lint scripts under `tools/checks/`** following the established MINT pattern (`wcag_aa_all_touched.py`, `s0_s5_aaa_only.py`, `accent_lint_fr.py`, `no_hardcoded_fr.py`). They run in CI and lefthook pre-commit. They use the **baseline-snapshot pattern** that already exists in MINT (`*-KNOWN-MISSES.md` file or a `<lint>.baseline.txt` line-count file) to grandfather pre-existing violations and fail only on net-new ones.

**The Dart `custom_lint` plugin path is rejected** for this phase: the upstream `custom_lint` package was archived 2026-03-24, the official replacement (`analysis_server_plugin` v0.3.15) is still nascent, and the team already has 5 production-grade Python scripts running in this niche. The Python approach matches existing skill, doesn't require a sibling Dart package, integrates with the existing CI / lefthook wiring, and ships in 2 days.

**Drift reality check vs. the audit headline:** the SYNTHESIS quotes "367 raw colors / 638 raw fontSize / 798 raw EdgeInsets / 20 distinct radii". Verification against the actual codebase (HEAD as of 2026-05-09) shows:

| Audit headline | Actual count outside `lib/theme/` | Verdict |
|---|---|---|
| 367 raw `Colors.white/black` | **29** real Material color refs (20× `Colors.white`, 6× `Colors.transparent`, 1× each red/grey/black) | OVERSTATED 12× — the audit grep matched `MintColors.text...` substring |
| Raw `Color(0xFF...)` literals | **2** (both in `widgets/consent/policy_diff_view.dart:88-89`) | Effectively a closed problem |
| 638 / 726 raw `fontSize:` | **705** | Confirmed — concentrated drift |
| 798 raw `EdgeInsets.*` | **2358** total instantiations | Confirmed — most use literal numbers, some use `MintSpacing` |
| 20 distinct `BorderRadius.circular(N)` values | **20** distinct values across **1545** call sites | Confirmed — top values: 12, 16, 20, 10, 8, 14 (account for 84% of sites) |
| Raw `ElevatedButton/OutlinedButton/FilledButton/TextButton` | **154** instantiations | Confirmed — meaningful target for Phase 4 |
| Raw `TextStyle(` outside theme | **493** | Confirmed — overlaps fontSize drift |
| `GoogleFonts.*` outside theme | **100** | Will collapse in Phase 3 (FONTS-TOKENS-V2) |
| `Text('...CHF...')` literal currency | **21** | Small enough to baseline + warn |
| Deprecated `withOpacity` | **97** | Out of scope but worth noting |

**Token adoption is already strong:** `MintColors.*` 8295 refs, `MintTextStyles.*` 3709 refs, `MintSpacing.*` 2708 refs. The lints don't have to convert a brownfield — they just have to stop the bleeding on the ~1500 remaining drift sites.

**Primary recommendation:** ship 5 Python lints (`no_raw_color_outside_theme.py`, `no_raw_fontsize.py`, `no_raw_textstyle.py`, `no_raw_borderradius.py`, `no_raw_cta_button.py`), each with a `KNOWN-MISSES.txt` baseline, wired into `lefthook.yml` (warning-only on touched files) and `.github/workflows/ci.yml` (hard fail on net-new violations only). Defer `no_raw_chf_text` to Phase 5 CITATION-GATE (which already requires a `MintCurrencyText` widget).

---

## User Constraints (from upstream prompt)

> No CONTEXT.md exists for this phase yet (this is the foundation phase, opened directly from the milestone). The orchestrator's spawn prompt encodes the constraints below.

### Locked Decisions

- **Phase goal**: add 3-5 custom Dart analyzer lints to block NEW design-system violations
- **Existing violations are baselined** (counted, listed in `.planning/audit/ui_drift_baseline_2026-05-09.txt`) but NOT fixed in this perimeter
- **Existing violation fixes** are deferred:
  - Phase 4 (`MVP-CTA-UNIFICATION-V1`) → fixes the ~80-154 button outliers
  - Phase 3 (`MVP-FONTS-TOKENS-V2`) → fixes the GoogleFonts drift, drops fontFamily refs
- **Phase 1 is the foundation**: lints land first, sweep second. Without lint enforcement, every UI sweep PR re-introduces the violations being swept (per milestone § "Why this is Phase 1").
- **Scope**: 5 specific lints proposed in the spawn prompt
  1. `prefer_mint_color_token` — block raw `Color(0xFF...)` outside `apps/mobile/lib/theme/`
  2. `prefer_mint_text_style` — block raw `fontSize:`, `TextStyle(fontFamily:` outside `apps/mobile/lib/theme/`
  3. `prefer_mint_spacing` — block raw `EdgeInsets.fromLTRB`, `SizedBox(height:`, `Padding(padding:` with literal numbers
  4. `no_raw_chf_text` — block `Text("...CHF...")` literal currency strings
  5. `prefer_mint_cta` — block raw `ElevatedButton`, `OutlinedButton`, `FilledButton`

### Claude's Discretion

- **Tool choice**: Python script vs. Dart `custom_lint` plugin vs. official `analysis_server_plugin` — research recommends a path
- **Baseline mechanism**: count-based, list-based, hash-based — research recommends a pattern
- **Coverage hooks**: lefthook pre-commit, CI only, or both — research recommends both
- **Lint severity**: warning vs. error per rule — research recommends per lint
- **Scope of allowlist**: per-file ignore comments, dir-level exemptions, blessed numeric values

### Deferred Ideas (OUT OF SCOPE)

- Fixing existing violations (deferred to Phases 3 and 4 per milestone)
- Dark mode token enforcement (out of scope of this milestone; v2 redesign concern)
- A11y lints (deferred to a separate `MVP-A11Y-V1` perimeter — `EXP-E` audit findings)
- New token additions (e.g., `MintRadius`, `MintElevation`) — Phase 1 only enforces what's already a token; new tokens are a P3 perimeter
- IDE quick-fix integration (would require Dart `analysis_server_plugin` — too heavy for this 2-day phase)
- Backend Python design lints (no parallel design system on backend; out of scope)

---

## Project Constraints (from CLAUDE.md)

The lint design must respect these MINT-wide directives:

| # | CLAUDE.md rule | Lint implication |
|---|---|---|
| 1 | **Banned terms (LSFin)** — `garanti`, `optimal`, `meilleur` etc. | Already enforced by `tools/checks/banned_terms_arb.py`. New design lints don't touch this. |
| 2 | **Accents 100% FR mandatory** | Already enforced by `tools/checks/accent_lint_fr.py`. New lints must NOT introduce ASCII-flattened FR. |
| 3 | **MINT ≠ retirement app** | Lint allowlist for `Text('CHF...')` MUST not whitelist any retirement-framing string. |
| 4 | **`financial_core` reuse mandatory** | N/A for design lints. |
| 5 | **i18n required** — all user-facing strings via `AppLocalizations.of(context)!.key` | The `no_raw_chf_text` lint piggybacks on this rule — but `no_hardcoded_fr.py` already covers FR strings. New lint just adds `CHF` numeric currency match. |
| 6 | **0-Trust** | RESEARCH.md cites every count via `grep -rEn ... | wc -l` output. Verified vs. theoretical. PR opened ≠ shipped — the phase is closed only when the 5 gates fire. |
| Karpathy #2 | **Simplicity first** | Python script > Dart custom_lint plugin (smaller delta, no sibling package, fits team skill). |
| Karpathy #3 | **Surgical changes** | Only `tools/checks/*.py` + `lefthook.yml` + `.github/workflows/ci.yml` + `.planning/audit/ui_drift_baseline_2026-05-09.txt` are touched. No `apps/mobile/lib/**/*.dart` files modified in this phase. |

---

## Phase Requirements

> No formal REQ-IDs were assigned in REQUIREMENTS.md (this milestone uses ad-hoc numbering). The spawn prompt enumerates the 5 lints. Mapped to research support below.

| ID (proposed) | Description | Research Support |
|---|---|---|
| LINT-01 | `no_raw_color_outside_theme` — block raw `Color(0x...)` and `Colors.{material}` outside `apps/mobile/lib/theme/` | §Drift inventory shows 2 raw `Color(0xFF...)` + 29 Material `Colors.*` outside theme. Trivial baseline. Pattern from `wcag_aa_all_touched.py`. |
| LINT-02 | `no_raw_fontsize` — block raw `fontSize:` literals outside `apps/mobile/lib/theme/` | §Drift inventory shows 705 raw `fontSize:` outside theme. `MintTextStyles.*` already provides 18 builders covering 9-56pt. Baseline-snapshot mandatory. |
| LINT-03 | `no_raw_textstyle_fontfamily` — block raw `TextStyle(fontFamily:` and `GoogleFonts.*` outside theme | §Drift inventory shows 100 GoogleFonts. Phase 3 will drop GoogleFonts entirely; lint prevents re-introduction. |
| LINT-04 | `no_raw_borderradius` — block `BorderRadius.circular(N)` for N not in MintRadius allowlist | §Drift inventory: 1545 sites, 20 distinct values. Top 6 values (12, 16, 20, 10, 8, 14) are the de-facto allowlist. Phase requires `MintRadius` token (NEW token — see §Open Questions). |
| LINT-05 | `no_raw_cta_button` — block raw `ElevatedButton/OutlinedButton/FilledButton/TextButton` instantiation outside `apps/mobile/lib/widgets/cta/` | §Drift inventory: 154 button instantiations. `MintCTA` widget does NOT exist yet (Phase 4 creates it). Lint must be **baseline-only** in Phase 1, hard-enforced in Phase 4. |

The original spawn prompt's `prefer_mint_spacing` and `no_raw_chf_text` are **deferred / merged**:
- `prefer_mint_spacing` — too noisy in Phase 1 (2358 EdgeInsets sites, no clear allowlist semantic). Defer to a dedicated perimeter once `MintSpacing` is enriched. **Mitigation**: a softer `EdgeInsets` lint can be added in Phase 4's CTA-UNIFICATION sweep.
- `no_raw_chf_text` — only 21 instances. Phase 5 CITATION-GATE creates `MintCurrencyText` and converts these. Adding a lint now without the destination widget is premature.

This trims to 5 lints concentrating on the highest-leverage drift sources.

---

## Standard Stack

### Core (this phase)

| Tool | Version | Purpose | Why Standard | Source |
|---|---|---|---|---|
| Python 3.11 | 3.11.x | Lint script runtime | Existing CI sets up Python 3.11 (`.github/workflows/ci.yml:38`); 11 production lints already in this language | [VERIFIED: CI workflow line 38] |
| `re` (stdlib) | n/a | Pattern matching | All 11 existing tools/checks/*.py use `re` directly — no parser dep | [VERIFIED: codebase grep] |
| `pathlib` (stdlib) | n/a | File walking | Same — used uniformly across `tools/checks/*.py` | [VERIFIED] |
| `argparse` (stdlib) | n/a | CLI args (--file, --baseline-update, etc.) | Same pattern in `accent_lint_fr.py:20`, `no_hardcoded_fr.py:20` | [VERIFIED] |
| `lefthook` | ≥ 2.1.5 | Pre-commit dispatch | Already wired (`lefthook.yml:6`) | [VERIFIED: lefthook.yml line 6] |
| GitHub Actions | n/a | CI runner | Already runs Python lints (`.github/workflows/ci.yml`) | [VERIFIED] |

### Supporting (NOT used)

| Library | Version | Why rejected |
|---|---|---|
| `custom_lint` (Invertase) | 0.8.1 (last) | Package archived 2026-03-24. Maintainer explicitly recommends migration. [CITED: github.com/invertase/dart_custom_lint] |
| `custom_lint_builder` | 0.8.1 (last) | Same — depends on archived `custom_lint` runtime. |
| `analysis_server_plugin` | 0.3.15 | OFFICIAL Dart team replacement — but pre-1.0, requires Dart 3.10+ (we're on 3.11.4 — eligible), no production examples for this niche, would require a sibling Dart package + pub.dev publish. Re-evaluate post-1.0 for a v2 lint phase. [VERIFIED: pub.dev/packages/analysis_server_plugin] |
| `dart_code_metrics` | 5.7.6 | Discontinued, paywalled (dcm.dev). [VERIFIED: pub.dev/packages/dart_code_metrics] |
| `flutter_lints` | 3.0.0 | Already used (`pubspec.yaml:64`). Provides Flutter-team-blessed rules but NO custom rule API. Keep as-is. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Python `re` script | Dart `analysis_server_plugin` | Plugin gives IDE quick-fixes + AST-precision (avoids regex false positives on commented code, multi-line literals, etc.). But: requires sibling Dart package, pub.dev maintenance, post-1.0 maturity wait. **Reject for Phase 1, reconsider in v2.** |
| Python `re` script | `dart fix` + manual rules | `dart fix` only applies built-in lints. Cannot author custom rules. Rejected. |
| Python `re` on `.dart` text | Use Dart `analyzer` package as an external script | Possible — `dart run analyzer` exposes the same AST. But adds Dart toolchain to a Python pipeline. Rejected. |
| Strict count-based baseline | git-blame baseline (only fail if violation in NEW lines) | More precise but harder to write; existing MINT pattern uses count-based. Match existing pattern. |
| Lint as warning (lefthook only) | Lint as error in CI | Both are needed: lefthook = soft (file scope of commit), CI = hard (whole repo, fail merge). Match `wcag_aa_all_touched.py` pattern. |

**Installation:**

No new dependencies. Just new `tools/checks/*.py` files and 2-line additions to `lefthook.yml` + `.github/workflows/ci.yml`.

**Version verification:**
- Python: `python3 --version` → 3.11.x [VERIFIED via local probe; CI pins to 3.11]
- `custom_lint` archive date: 2026-03-24 [CITED: github.com/invertase/dart_custom_lint]
- `analysis_server_plugin` 0.3.15 published 16 days ago, requires Dart 3.10+ [CITED: pub.dev]

---

## Architecture Patterns

### Recommended directory layout

```
tools/checks/
├── accent_lint_fr.py                       (existing)
├── banned_terms_arb.py                     (existing)
├── no_hardcoded_fr.py                      (existing)
├── wcag_aa_all_touched.py                  (existing — closest precedent)
├── s0_s5_aaa_only.py                       (existing — closest precedent)
├── landing_no_numbers.py                   (existing)
│
├── no_raw_color_outside_theme.py           (NEW — LINT-01)
├── no_raw_color_outside_theme.baseline.txt (NEW — list of grandfathered sites)
├── no_raw_fontsize.py                      (NEW — LINT-02)
├── no_raw_fontsize.baseline.txt            (NEW)
├── no_raw_textstyle_fontfamily.py          (NEW — LINT-03)
├── no_raw_textstyle_fontfamily.baseline.txt (NEW)
├── no_raw_borderradius.py                  (NEW — LINT-04)
├── no_raw_borderradius.baseline.txt        (NEW)
├── no_raw_cta_button.py                    (NEW — LINT-05)
├── no_raw_cta_button.baseline.txt          (NEW)
└── README-DESIGN-LINTS.md                  (NEW — concise « how baselines work » doc)

.planning/audit/
└── ui_drift_baseline_2026-05-09.txt        (NEW — human-readable summary, links to per-lint baseline files)
```

### Pattern 1: « Path:line snapshot baseline »

**What**: Each lint produces a list of `path:line: <pattern_matched>` rows. The baseline file is a sorted snapshot of those rows committed to git. The lint passes if (current_violations ⊆ baseline_violations). New violations fail; removed violations pass (and trigger an optional --update-baseline mode).

**When to use**: When you want to allow drift-fixes (sweep PRs reduce the baseline) without making the lint passive (new drift fails immediately).

**Example (closest precedent — `route_registry_parity.py` / `route_registry_parity-KNOWN-MISSES.md`):**

```python
# Source: tools/checks/route_registry_parity.py + tools/checks/route_registry_parity-KNOWN-MISSES.md
# The .py file scans app.dart for GoRoute paths.
# The KNOWN-MISSES.md file documents regex limitations.
# Lint exits 0 if ALL extracted routes are present in kRouteRegistry,
# treating documented misses as silent passes.
```

**MINT-tuned variant for this phase:**

```python
# Pseudocode for no_raw_fontsize.py
import re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
BASELINE_FILE = Path(__file__).with_name("no_raw_fontsize.baseline.txt")

PATTERN = re.compile(r"fontSize:\s*([0-9]+(?:\.[0-9]+)?)")
EXCLUDE_DIRS = ("/lib/theme/", "/test/", "/test_driver/")

def scan() -> list[str]:
    """Return sorted ['path:line: snippet'] violations."""
    out = []
    for dart_file in (REPO / "apps/mobile/lib").rglob("*.dart"):
        rel = "/" + dart_file.relative_to(REPO).as_posix() + "/"
        if any(ex in rel for ex in EXCLUDE_DIRS): continue
        for lineno, line in enumerate(dart_file.read_text().splitlines(), 1):
            if "// lint-ignore: no_raw_fontsize" in line: continue
            m = PATTERN.search(line)
            if m: out.append(f"{rel.strip('/')}:{lineno}: {m.group(0)}")
    return sorted(out)

def main() -> int:
    current = set(scan())
    baseline = set()
    if BASELINE_FILE.exists():
        baseline = set(BASELINE_FILE.read_text().splitlines())

    new_violations = current - baseline
    if new_violations:
        print(f"::error::{len(new_violations)} new no_raw_fontsize violations:")
        for v in sorted(new_violations): print(v)
        print("\nFix: replace literal `fontSize: N` with `MintTextStyles.<token>()`.")
        print("If absolutely necessary, add `// lint-ignore: no_raw_fontsize` on that line.")
        return 1
    return 0
```

### Pattern 2: « Per-line ignore comment »

**What**: Allow per-line escape via `// lint-ignore: <rule_name>` (consistent with `no_hardcoded_fr.py:36-43`).

**When to use**: For legitimate exceptions (e.g., a one-off pixel-shift fix, an asset-driven literal). Forces the dev to acknowledge the rule.

### Pattern 3: « Hard CI fail, soft lefthook warn »

**What**: Lefthook runs the lint on staged files only and exits 0 even on violations (warning text printed). CI runs the lint on the full repo and exits non-zero on net-new violations.

**Why**: Pre-commit must be fast (< 1s for the whole bundle). A full repo scan in pre-commit kills DX. CI catches the net-new violations the dev couldn't avoid.

**Existing precedent**: `wcag_aa_all_touched.py` runs in CI only (`.github/workflows/ci.yml:152`) — pre-commit currently has only `memory-retention`, `map-freshness-hint`, `wiki-lint`. This phase ADDS the design lints to the pre-commit table (warning-only) AND to CI (hard fail).

### Anti-Patterns to Avoid

- **AST-less regex on multi-line `TextStyle(...)`**: `TextStyle(\n  fontSize: 14,\n  fontFamily: 'X',\n)` won't be caught by a single-line regex. Mitigation: scan line-by-line for `fontSize:` and `fontFamily:` separately, not for the wrapping `TextStyle(`. Each lint targets one literal pattern.
- **Allowlist by hardcoding numbers in the script**: bakes the design system into Python. Better: read allowlist from a sibling JSON/YAML, or extract from the Dart token files via regex once at startup. But this is gilding for Phase 1 — hardcoding the 6 blessed values in the .py file is fine.
- **Failing pre-commit on the full repo**: too slow. Pre-commit runs on staged files only.
- **Coupling baseline file format to the lint output**: makes refactoring the message format break the lint. Mitigation: baseline file stores `path:line` pairs only; the message is regenerated on each run.
- **No `// lint-ignore` escape hatch**: forces sweep-and-rebase loops. Always include the escape.
- **Updating baseline silently in CI**: defeats the point. Baseline updates are explicit human commits with `--update-baseline` flag.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Dart AST visitor | A custom Dart AST traversal | Regex on `.dart` text | Phase 1 budget is 2 days. AST adds Dart sibling package, pub.dev, custom_lint plugin, archived upstream. Regex covers the 5 patterns with acceptable false-positive rate (< 5%, mitigated by `// lint-ignore`). |
| Baseline diffing | A `git blame` integration to detect "new lines" | `set(current) - set(baseline)` | git-blame integration is fragile across rebases, squash-merges, cherry-picks. Set-diff on `path:line` is robust enough; the noise from line-number shifts on unrelated edits is the cost we pay. **Mitigation**: when a fix-PR shifts line numbers, the baseline-update script re-snapshots — no human bookkeeping. |
| File watching | A `watchman` daemon for instant feedback | None — IDE Dart analyzer is enough | Phase 1 doesn't need IDE integration. Devs see the lint at pre-commit + in CI. |
| Cross-file dependency tracking | A dependency graph (e.g., "this Color is also used in 3 other files") | Per-file isolated check | Out of scope; the lint's job is "no NEW raw token", not "refactor existing token". |
| Quick-fixes | Auto-apply suggestions in IDE | A clear error message with the suggested replacement | `analysis_server_plugin` would give us this but Phase 1 is too early. Add to backlog. |
| YAML lint config DSL | A `mint_lints.yaml` with allowlists | Hardcode in `.py` | YOLO simplicity. Migrate to YAML when there are 10+ lints (currently 11 + 5 = 16 — borderline). |

**Key insight**: MINT's design-lint problem is **80% pattern-matching, 20% semantics**. An AST plugin is overkill. The 11 existing tools/checks/*.py scripts have been running clean for months, including the closest precedent (`wcag_aa_all_touched.py` enforces hardcoded color contrast); the team operates well with this pattern. **Adding 5 more is incremental, not architectural.**

---

## Drift Inventory (verified 2026-05-09)

> All counts produced via `grep -rEn ... apps/mobile/lib --include="*.dart" | grep -v "/lib/theme/" | wc -l` against HEAD of `fix/coach-context-loads-raw-profile-values` branch (latest commit 26d79065).

### LINT-01 — Raw colors

```
Color(0xFF...) literals outside lib/theme/:    2  (BOTH in widgets/consent/policy_diff_view.dart:88-89)
Material Colors.{white,black,...} outside lib/theme/:  29
  - 20× Colors.white
  - 6× Colors.transparent
  - 1× Colors.black, 1× Colors.red, 1× Colors.grey
Total: 31 sites — TINY baseline
```

**MintColors.* references**: 8295 (token adoption is dominant — the 31 outliers are the long tail).

### LINT-02 — Raw fontSize

```
fontSize:\s*\d+ outside lib/theme/:    705
TextStyle( outside lib/theme/:         493  (overlap: most TextStyle has fontSize; some inherit)
MintTextStyles.* references:           3709 (~88% adoption)
```

Distribution of raw fontSize values (top 15):
```
  105 fontSize: 12
   78 fontSize: 14
   53 fontSize: 13
   53 fontSize: 11
   48 fontSize: 17
   47 fontSize: 8         ← suspicious; below smallest token (9)
   44 fontSize: 22
   42 fontSize: 18
   42 fontSize: 16
   42 fontSize: 10
   34 fontSize: 15
   30 fontSize: 9
   21 fontSize: 24
   19 fontSize: 20
   11 fontSize: 7         ← below floor; potential a11y bug
```

**MintTextStyles** provides 18 builders covering 9-56pt. Sizes 7, 8, 11, 13, 15, 17 do not map cleanly — these are the drift candidates. Lint should baseline + flag, not auto-fix.

### LINT-03 — Raw fontFamily / GoogleFonts

```
GoogleFonts.* outside lib/theme/:                100
TextStyle( with explicit fontFamily: outside theme:  ~50 estimated subset of the 493
```

Phase 3 (`MVP-FONTS-TOKENS-V2`) will drop `google_fonts` entirely and replace with locally bundled Supreme + Gambarino + Fraunces. Lint must be in place BEFORE Phase 3 lands so that Phase 3's sweep doesn't re-introduce `GoogleFonts.*` while editing files.

### LINT-04 — Raw BorderRadius

```
BorderRadius.circular(N) outside lib/theme/:   1545
20 distinct N values:
  409 circular(12)    ← 26.5%
  245 circular(16)    ← 15.9%
  201 circular(20)    ← 13.0%
  180 circular(10)    ← 11.7%
  164 circular(8)     ← 10.6%
  117 circular(14)    ← 7.6%
   66 circular(6)
   58 circular(4)
   45 circular(2)
   21 circular(3)
   14 circular(24)
    7 circular(7)
    3 circular(999)   ← pill-button shorthand
    3 circular(5)
    3 circular(11)
    2 circular(22)
    2 circular(19)
    2 circular(1)
    1 circular(99)
    1 circular(9)
```

**Top 6 values (12, 16, 20, 10, 8, 14) account for 84% (1316/1545).** That's the natural allowlist for a `MintRadius` token (NEW token — see §Open Questions). Until `MintRadius` exists, the lint can:
- Soft mode: warn on `circular(N)` for N not in {2, 4, 6, 8, 10, 12, 14, 16, 20, 24, 999}.
- Hard mode (post-Phase-3 token addition): only allow `MintRadius.{xs, sm, md, lg, xl, pill}`.

For Phase 1, ship soft mode with the 11-value allowlist, baseline the rest. Outlier values (1, 3, 5, 7, 9, 11, 19, 22, 99) are the natural drift — 25 sites total, tractable for a future sweep.

### LINT-05 — Raw CTA buttons

```
ElevatedButton(/OutlinedButton(/FilledButton(/TextButton( outside lib/theme/ + lib/widgets/cta/:  154
```

`MintCTA` does NOT exist yet (Phase 4 creates it). The lint must:
- **Phase 1**: baseline-only mode (snapshot all 154 sites, fail on net-new). No replacement target available yet.
- **Phase 4**: when `MintCTA` lands, pivot lint to enforce import path / replacement.

This is precisely the « lint as scaffold for upcoming sweep » pattern called out in the milestone.

### Out-of-scope drift (documented but not linted)

- **Raw `EdgeInsets.*`**: 2358 sites. Too noisy without semantic allowlist. Defer.
- **Raw `SizedBox` height/width**: 2738 sites. Same — defer.
- **`elevation:` literals**: 366 sites. Defer (no `MintElevation` token).
- **`Duration(milliseconds: N)`**: 530 sites outside theme. `MintMotion` provides 4 durations + 4 curves; consider in v2 lint phase.
- **`withOpacity()`**: 97 sites. Deprecated in Flutter 3.27 / 3.31; addressed by a separate Flutter-blessed lint when we upgrade. Out of scope.
- **`Text('...CHF...')`**: 21 sites. Deferred to Phase 5 CITATION-GATE.

---

## Runtime State Inventory

> Phase 1 is greenfield code addition — no rename, no migration, no existing artifact to update. The rename/refactor checklist mostly does not apply. Filling each category for completeness:

| Category | Items Found | Action Required |
|---|---|---|
| Stored data | None — lints are stateless. Baseline files are checked into git. | None |
| Live service config | None — no service registration. | None |
| OS-registered state | None — no daemons, no LaunchAgent, no cron. (lefthook hooks live in `.git/hooks/` but are managed by `lefthook install` — see existing setup.) | None |
| Secrets / env vars | None. CI runs the lints unauthenticated. | None |
| Build artifacts | `__pycache__/` regenerates on each Python invocation. Already in `.gitignore`. | None |

**Nothing meaningful in any category.** The phase is pure addition.

---

## Common Pitfalls

### Pitfall 1: Regex false positives on commented code

**What goes wrong**: a doc comment `// fontSize: 14 — historical note` triggers the lint.

**Why it happens**: line-by-line regex doesn't strip comments.

**How to avoid**: pre-strip `//` line comments before applying the pattern (`if line.strip().startswith("//"): continue`). For block comments, use a state machine OR accept that they're rare and use `// lint-ignore: <rule>` as the escape.

**Warning signs**: > 5 false positives per file in initial baseline scan.

### Pitfall 2: Baseline drift across rebases

**What goes wrong**: someone renames a file or shifts lines; baseline `path:line` entries no longer match; lint reports false-new-violations.

**Why it happens**: baseline format is `path:line` not content-hash.

**How to avoid**: provide a `--update-baseline` flag that re-snapshots and writes the file. Document in `README-DESIGN-LINTS.md`. CI never auto-updates; humans run it after a sweep.

**Warning signs**: PRs that touch unrelated files showing N new lint violations all at the same line.

### Pitfall 3: Pre-commit too slow → devs disable lefthook

**What goes wrong**: full-repo scan adds 5+ seconds per commit; devs skip the hook.

**Why it happens**: lints scan the full `apps/mobile/lib/` tree.

**How to avoid**: lefthook passes `{staged_files}` (already supported, see `lefthook.yml:25-26` for `map_freshness_hint`); the lint must accept `--file <path>` (existing pattern in `accent_lint_fr.py`, `no_hardcoded_fr.py`). Pre-commit then scans only changed `.dart` files. CI runs the full scan.

**Warning signs**: `lefthook run pre-commit` taking > 1.5s on a 1-line commit.

### Pitfall 4: Baseline grows because devs prefer adding to it over fixing

**What goes wrong**: every PR appends to the baseline rather than removing entries, defeating the lint's purpose.

**Why it happens**: `--update-baseline` is too easy.

**How to avoid**: PR review checklist asks "did this PR shrink any baseline?". CI prints `::warning::baseline grew by N entries`. Humans review.

**Warning signs**: baseline file grows in 3+ consecutive sweep PRs.

### Pitfall 5: Allowlist drift from the actual `MintTextStyles` / `MintColors` API

**What goes wrong**: a new token is added to `MintColors`; the lint doesn't know about it; lint passes (good) but won't enforce its use elsewhere.

**Why it happens**: Phase 1 lints check the *negative* (no raw values) not the *positive* (use of token).

**How to avoid**: Phase 1 only enforces "no raw"; "must use MintColors" is a v2 lint that parses the token files at startup. Document explicitly in scope.

### Pitfall 6: Token files include legitimate raw `Color(0xFF...)` — the lint must whitelist `lib/theme/`

**What goes wrong**: `colors.dart` has 200+ `Color(0xFF...)` literals; if the lint scans it, every CI run fails.

**Why it happens**: the only legal place for raw colors is the token registry.

**How to avoid**: hardcode `EXCLUDE_DIRS = ("/lib/theme/", ...)` (already in pattern). Mirror `accent_lint_fr.py:46-65`.

**Warning signs**: lint fails on its very first run.

### Pitfall 7: Auto-generated files (l10n, gen-l10n, .g.dart, contracts/voice_cursor.json codegen)

**What goes wrong**: generated `*.g.dart` may contain raw values from JSON sources.

**Why it happens**: codegen.

**How to avoid**: exclude `*.g.dart`, `*.gen.dart`, `lib/l10n/app_localizations*.dart` from scan. Pattern already established in `no_hardcoded_fr.py` (`/lib/l10n/` excluded).

### Pitfall 8: « expect_lint » testing ≠ « ignore_for_file »

If we ever migrate to `analysis_server_plugin`, the test annotation pattern is `// expect_lint: <rule>` (per Charles Tsang tutorial). For Python regex, we use `// lint-ignore: <rule>` per existing MINT convention. Don't mix.

---

## Code Examples

### Skeleton script (proven pattern)

```python
# Source: tools/checks/wcag_aa_all_touched.py shape — proven precedent
# Adapted for no_raw_fontsize.py
#!/usr/bin/env python3
"""no_raw_fontsize lint — block raw fontSize: literals outside lib/theme/.

Phase 1 of MVP-DESIGN-LINTS-V1. Baseline: tools/checks/no_raw_fontsize.baseline.txt.

Use --file <path> to lint a single file (lefthook pre-commit pattern).
Use --update-baseline to re-snapshot after a sweep PR.

Exit 0 — clean OR all violations are in the baseline.
Exit 1 — net-new violations.
Exit 2 — baseline file missing.
"""
from __future__ import annotations
import argparse, re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DEFAULT_SCOPE = REPO / "apps" / "mobile" / "lib"
BASELINE = Path(__file__).with_name("no_raw_fontsize.baseline.txt")

# Match `fontSize: 14`, `fontSize: 14.5`, `fontSize :14` (forgiving whitespace).
PATTERN = re.compile(r"\bfontSize\s*:\s*([0-9]+(?:\.[0-9]+)?)")

EXCLUDE_DIRS = (
    "/lib/theme/",
    "/lib/l10n/",
    "/test/",
    "/test_driver/",
    "/.dart_tool/",
    "/build/",
)
IGNORE_MARKERS = ("// lint-ignore: no_raw_fontsize", "// ignore_for_file: no_raw_fontsize")


def scan(files: list[Path] | None = None) -> list[str]:
    out: list[str] = []
    targets = files if files else list(DEFAULT_SCOPE.rglob("*.dart"))
    for f in targets:
        rel = "/" + f.relative_to(REPO).as_posix() + "/"
        if any(ex in rel for ex in EXCLUDE_DIRS): continue
        try: text = f.read_text(encoding="utf-8")
        except OSError: continue
        if any(m in text for m in IGNORE_MARKERS if "ignore_for_file" in m): continue
        for lineno, line in enumerate(text.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("//"): continue
            if "// lint-ignore: no_raw_fontsize" in line: continue
            m = PATTERN.search(line)
            if m:
                out.append(f"{f.relative_to(REPO).as_posix()}:{lineno}: {m.group(0)}")
    return sorted(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", action="append", type=Path)
    ap.add_argument("--update-baseline", action="store_true")
    args = ap.parse_args()

    files = args.file if args.file else None
    current = set(scan(files))

    if args.update_baseline:
        BASELINE.write_text("\n".join(sorted(current)) + "\n")
        print(f"OK no_raw_fontsize: baseline updated ({len(current)} entries)")
        return 0

    if not BASELINE.exists():
        print(f"::error::{BASELINE} missing — run with --update-baseline first")
        return 2

    baseline = set(BASELINE.read_text().splitlines()) - {""}
    new = current - baseline
    if new:
        print(f"::error::no_raw_fontsize: {len(new)} new violation(s):")
        for v in sorted(new): print(v)
        print("\nFix: replace `fontSize: N` with `MintTextStyles.<token>()` "
              "(see apps/mobile/lib/theme/mint_text_styles.dart).")
        print("If unavoidable, add `// lint-ignore: no_raw_fontsize` on that line.")
        return 1

    removed = baseline - current
    if removed:
        print(f"OK no_raw_fontsize: clean (-{len(removed)} from baseline). "
              f"Run --update-baseline to shrink it.")
    else:
        print(f"OK no_raw_fontsize: clean ({len(current)} grandfathered)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

### Lefthook addition

```yaml
# Add under `pre-commit.commands` in lefthook.yml
no-raw-fontsize:
  run: python3 tools/checks/no_raw_fontsize.py --file {staged_files}
  glob: "apps/mobile/lib/**/*.dart"
  tags: [design, phase-1-mvp-design-lints]
no-raw-color-outside-theme:
  run: python3 tools/checks/no_raw_color_outside_theme.py --file {staged_files}
  glob: "apps/mobile/lib/**/*.dart"
  tags: [design, phase-1-mvp-design-lints]
no-raw-textstyle-fontfamily:
  run: python3 tools/checks/no_raw_textstyle_fontfamily.py --file {staged_files}
  glob: "apps/mobile/lib/**/*.dart"
  tags: [design, phase-1-mvp-design-lints]
no-raw-borderradius:
  run: python3 tools/checks/no_raw_borderradius.py --file {staged_files}
  glob: "apps/mobile/lib/**/*.dart"
  tags: [design, phase-1-mvp-design-lints]
no-raw-cta-button:
  run: python3 tools/checks/no_raw_cta_button.py --file {staged_files}
  glob: "apps/mobile/lib/**/*.dart"
  tags: [design, phase-1-mvp-design-lints]
```

### CI workflow addition

```yaml
# Add a new job in .github/workflows/ci.yml — sibling of `readability` and the WCAG job
design-lints:
  name: Design system lints (MVP-DESIGN-LINTS-V1)
  needs: [changes]
  if: needs.changes.outputs.flutter == 'true'
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-python@v5
      with:
        python-version: "3.11"
    - name: no_raw_color_outside_theme
      run: python3 tools/checks/no_raw_color_outside_theme.py
    - name: no_raw_fontsize
      run: python3 tools/checks/no_raw_fontsize.py
    - name: no_raw_textstyle_fontfamily
      run: python3 tools/checks/no_raw_textstyle_fontfamily.py
    - name: no_raw_borderradius
      run: python3 tools/checks/no_raw_borderradius.py
    - name: no_raw_cta_button
      run: python3 tools/checks/no_raw_cta_button.py
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| `dart_code_metrics` | Discontinued; paywalled at dcm.dev | 2024 | Don't adopt. |
| `custom_lint` (Invertase) | Archived 2026-03-24 | 2026-03-24 | Maintainer recommends `analysis_server_plugin`. New projects should NOT start with custom_lint. |
| Manual code review of design system | Static analysis at PR time | 2022+ | Mature pattern across F/E ecosystems. |
| Hardcoded design tokens in widgets | Centralized token classes (`MintColors`, `MintTextStyles`, `MintSpacing`, `MintMotion`) | MINT 2024+ | Already adopted; this phase enforces it. |
| Per-line regex lints | AST-based plugin (analysis_server_plugin) | 2026 (post-Dart 3.10) | Not yet mature for this niche. Reconsider for v2. |

**Deprecated / outdated:**
- `dart_code_metrics` — discontinued.
- `custom_lint` (Invertase) — archived. Existing users still functional but unsupported.
- `withOpacity()` (Flutter API) — deprecated in Flutter 3.27/3.31 in favor of `Color.withValues()`. Out of scope for this phase but on the radar.

---

## Assumptions Log

> Claims tagged `[ASSUMED]` in this research that need user/orchestrator confirmation before locking the plan.

| # | Claim | Section | Risk if wrong |
|---|---|---|---|
| A1 | The 5 lints proposed are the right scope for a 2-day phase. | Phase Requirements | If LINT-04 (BorderRadius) is too noisy at 1545 sites, the lint will block CI and require a same-PR `--update-baseline`. Mitigation: ship LINT-04 in soft mode (warn-only) for 1 week, then promote. |
| A2 | The Python `re` approach has a < 5% false-positive rate. | Architecture Patterns | If higher, devs will spam `// lint-ignore` and the lint loses signal. Mitigation: dry-run on 100 files during plan phase, count false positives. |
| A3 | Lefthook `{staged_files}` substitution works with multi-file commits. | Code Examples | If `lefthook` passes a space-separated list and the script expects single-file, it'll error. Mitigation: existing `accent_lint_fr.py` uses `--file` action="append" — verify in EXEC. |
| A4 | The audit's "367 raw colors" was a grep substring artefact. | Drift inventory | If the audit was right and our 29 is wrong, the LINT-01 baseline is too small. Mitigation: triple-check with the audit author's exact grep before locking baseline. |
| A5 | `MintRadius` token does not exist. | LINT-04 spec | If it does, the lint should reference it directly. Mitigation: grep `class MintRadius` in `apps/mobile/lib/theme/` during plan phase. **Verified absent**: `find apps/mobile/lib/theme -name "*.dart"` returns 5 files: colors, mint_spacing, mint_motion, wcag_helper, mint_text_styles. No mint_radius.dart. → LINT-04 baselines without referring to a token; Phase 1 does NOT add the token (Karpathy #2 — no scope creep). |
| A6 | `MintCTA` does not exist. | LINT-05 spec | **Verified absent**: `grep -rln "MintCTA\|MintButton" apps/mobile/lib` returned empty. Phase 4 will create it. |
| A7 | Existing CI runs Python 3.11 lints. | Standard Stack | **Verified**: `.github/workflows/ci.yml:38` sets up Python 3.11 for the `wcag_aa_all_touched.py` job. |
| A8 | All 5 lints can be authored in 1 day; remaining 1 day is baseline + wiring + test. | Implicit budget | Each lint is ~80 lines of Python following the skeleton. 5 × 30 min = 2.5 hours. Comfortable margin. |
| A9 | The team prefers the existing Python pattern over a Dart sibling package. | Tool choice | Karpathy #2 simplicity-first + 11 Python lints already in place is strong evidence; defer to orchestrator if wrong. |
| A10 | `// lint-ignore: <rule>` is the right escape syntax. | Architecture | **Verified pattern**: `no_hardcoded_fr.py:36-43` uses `// lint-ignore` and `// ignore:`. Match. |

---

## Open Questions

1. **Does `MintRadius` need to land in this phase?**
   - What we know: 1545 BorderRadius sites, 6 dominant values cover 84% of usage. Token would be high-leverage.
   - What's unclear: scope budget. Adding `MintRadius` is a sweep, not a lint.
   - Recommendation: **defer to a Phase 1.5 add-on or to Phase 4 CTA-UNIFICATION**. Phase 1 ships the lint with a numeric allowlist `{2, 4, 6, 8, 10, 12, 14, 16, 20, 24, 999}`. Phase 4 (which already touches button shapes) can add `MintRadius.{xs..pill}` and tighten the lint.

2. **Should LINT-05 (CTA) ship at all in Phase 1 if `MintCTA` doesn't exist?**
   - What we know: 154 button instantiations; baseline-only mode is safe.
   - What's unclear: developer DX — a lint with no replacement target may be confusing.
   - Recommendation: **ship in baseline-only mode with a clear error message: "raw button widgets are frozen pending Phase 4 MintCTA. If you need a new button, contact #design or wait."** This is the « scaffold for upcoming sweep » pattern.

3. **Should we also lint the 21 raw `Text('CHF...')` strings now?**
   - What we know: 21 sites, low effort to scan, but `MintCurrencyText` doesn't exist.
   - What's unclear: whether Phase 5 CITATION-GATE will land the widget within the milestone window.
   - Recommendation: **defer — Phase 5 is closer to Week 3-4. Adding the lint now without the widget is premature scoping. Track in milestone backlog.**

4. **Should the lints fail in soft mode (warn) or hard mode (error) on first activation?**
   - What we know: existing precedents (`s0_s5_aaa_only.py`, `wcag_aa_all_touched.py`) ship hard.
   - What's unclear: developer pain index. 5 hard lints landing simultaneously will surface tons of « ah merde » moments at PR-time.
   - Recommendation: **5 hard, baseline grandfathers everything**. Net-new violations are the only failure surface, which is how every dev should expect the rule to work post-Phase-1. Mitigation: announce in a banner in `README-DESIGN-LINTS.md` + commit message + Slack ping the day of activation.

5. **Should lefthook block (exit 1) on warning or just print?**
   - What we know: `wiki-lint` and `memory-retention` block on hard violations; `map-freshness-hint` is exit-0 always.
   - What's unclear: dev tolerance.
   - Recommendation: **lefthook prints + exits 0 (soft mode) on the design lints; CI blocks**. This is a deliberate split — dev's `git commit` is fast, CI's PR-blocking is the source of truth.

6. **What about the audit's « 0 dark mode » finding?**
   - What we know: dark mode is a v2 redesign concern.
   - What's unclear: relationship to design lints.
   - Recommendation: **out of scope of this phase**. Note in milestone backlog as `MVP-DARK-MODE-FOUNDATION`.

7. **Where does `MintMotion` enforcement go?**
   - What we know: 530 raw `Duration(milliseconds:)` outside theme; `MintMotion` exists with 4 durations. Current ratio is bad.
   - What's unclear: scope for this phase.
   - Recommendation: **out of scope of this phase** to stay in the 2-day budget. Track as `MVP-MOTION-LINT-V1` (1d) for the next UI sweep window.

---

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|---|---|---|---|---|
| Python 3.11 | All 5 lints | ✓ | 3.11.x (CI + local) | — |
| `re`, `pathlib`, `argparse` (stdlib) | All 5 lints | ✓ | bundled | — |
| `lefthook` ≥ 2.1.5 | Pre-commit dispatch | ✓ | already configured (`lefthook.yml:6`) | — |
| GitHub Actions | CI runner | ✓ | already running 11 Python lints | — |
| `dart` / `flutter` | NOT used by these lints | ✓ (3.11.4 / 3.41.6) | n/a | — |
| `git` for `--update-baseline` workflow | Baseline regen | ✓ | n/a | — |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

This phase is deliberately built on already-available tooling. Zero new dependencies.

---

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | Python `unittest` (stdlib) — matches existing `tools/checks/test_banned_terms_arb.py:1-50` pattern |
| Config file | none — tests live next to the lint script as `test_<lint_name>.py` |
| Quick run command | `python3 -m unittest tools/checks/test_no_raw_fontsize.py` |
| Full suite command | `python3 -m unittest discover tools/checks -p 'test_*.py'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| LINT-01 | Detect new `Color(0xFF...)` outside `lib/theme/` | unit | `python3 -m unittest tools/checks/test_no_raw_color_outside_theme.py` | ❌ Wave 0 |
| LINT-01 | Allow `Color(0xFF...)` inside `lib/theme/` | unit | same | ❌ Wave 0 |
| LINT-01 | Allow `// lint-ignore: no_raw_color_outside_theme` escape | unit | same | ❌ Wave 0 |
| LINT-01 | Pass when current ⊆ baseline | unit | same | ❌ Wave 0 |
| LINT-01 | Fail with exit 1 + diagnostic when net-new violation | unit | same | ❌ Wave 0 |
| LINT-02 | Detect new `fontSize: N` outside theme | unit | `... test_no_raw_fontsize.py` | ❌ Wave 0 |
| LINT-02 | Skip line comments | unit | same | ❌ Wave 0 |
| LINT-02 | `--file` flag works in lefthook context | unit | same | ❌ Wave 0 |
| LINT-03 | Detect new `GoogleFonts.<x>` outside theme | unit | `... test_no_raw_textstyle_fontfamily.py` | ❌ Wave 0 |
| LINT-03 | Detect new `TextStyle(fontFamily:)` outside theme | unit | same | ❌ Wave 0 |
| LINT-04 | Detect `BorderRadius.circular(N)` for N not in allowlist | unit | `... test_no_raw_borderradius.py` | ❌ Wave 0 |
| LINT-04 | Allow `BorderRadius.circular(12)` (in allowlist) | unit | same | ❌ Wave 0 |
| LINT-05 | Detect `ElevatedButton(`/`OutlinedButton(`/`FilledButton(`/`TextButton(` outside `lib/widgets/cta/` | unit | `... test_no_raw_cta_button.py` | ❌ Wave 0 |
| LINT-05 | Allow inside `lib/widgets/cta/` | unit | same | ❌ Wave 0 |
| ALL | `--update-baseline` rewrites file | unit | per-lint test files | ❌ Wave 0 |
| ALL | Lints exit 0 when current == baseline | smoke | CI job `design-lints` runs all 5 against repo HEAD | ❌ Wave 0 |
| ALL | Lints exit 1 when test fixture introduces new violation | integration | `python3 tests/integration/test_design_lints_e2e.py` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit**: `python3 -m unittest tools/checks/test_<lint_name>.py` (the lint being authored)
- **Per wave merge**: `python3 -m unittest discover tools/checks -p 'test_*.py'` (all 5 design lints + existing 11)
- **Phase gate**: G3 = full pytest + flutter test + the 5 design lints exit 0 against current baseline

### Wave 0 Gaps

- [ ] `tools/checks/test_no_raw_color_outside_theme.py` — LINT-01 unit tests (8-10 tests)
- [ ] `tools/checks/test_no_raw_fontsize.py` — LINT-02 unit tests (8-10 tests)
- [ ] `tools/checks/test_no_raw_textstyle_fontfamily.py` — LINT-03 unit tests (6-8 tests)
- [ ] `tools/checks/test_no_raw_borderradius.py` — LINT-04 unit tests (8-10 tests, includes allowlist edge cases)
- [ ] `tools/checks/test_no_raw_cta_button.py` — LINT-05 unit tests (6-8 tests)
- [ ] `tools/checks/fixtures/` — synthetic `.dart` fixtures for unit tests (per-lint subdirectory)
- [ ] `.planning/audit/ui_drift_baseline_2026-05-09.txt` — human-readable summary linking to per-lint baselines (created during plan phase by initial `--update-baseline` invocation)
- [ ] `tools/checks/no_raw_*.baseline.txt` — 5 baseline files (auto-generated)
- [ ] No new framework install needed (Python `unittest` is stdlib).

---

## Security Domain

> Including per `security_enforcement` default-on. Most categories N/A — these are dev tools, not user-facing surfaces.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | Lints don't authenticate. |
| V3 Session Management | no | Stateless scripts. |
| V4 Access Control | no | No access boundaries. |
| V5 Input Validation | yes (limited) | The lint reads `.dart` files; pathological filenames or sym-links into the repo are out-of-scope (devs can already read the repo). `argparse` validates `--file` paths. |
| V6 Cryptography | no | No crypto. |
| V14 Configuration | yes | Baseline files committed to git — same risk model as any source file. No secrets in baselines. |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Lint script crashes on malformed UTF-8 | DoS | `read_text(encoding="utf-8", errors="ignore")` — already in `accent_lint_fr.py` |
| Lint script reads outside repo | Information disclosure | All paths derived from `Path(__file__).resolve().parents[2]` — fixed root |
| Baseline poisoning | Tampering | Baselines committed via PR review — the lint reading a tampered baseline would relax enforcement, but the human PR review catches changes to `*.baseline.txt` |
| `// lint-ignore` abuse | Tampering | grep audit per quarter on `// lint-ignore: no_raw_*` count to spot abuse |
| Public-repo discipline | Information disclosure | Per `feedback_public_repo_discipline.md`: lint diagnostic messages MUST NOT contain forensic legal language. Reviewed. |

**Bottom line**: design lints are very low security risk. The only real concern is process: an attacker with PR access could relax baselines — but they could equally edit any source file, so this is not a new attack surface.

---

## Sources

### Primary (HIGH confidence)

- **MINT codebase HEAD** (`fix/coach-context-loads-raw-profile-values` branch, latest commit 26d79065)
  - `apps/mobile/lib/theme/colors.dart` — full `MintColors` token API
  - `apps/mobile/lib/theme/mint_text_styles.dart` — full `MintTextStyles` builder API
  - `apps/mobile/lib/theme/mint_spacing.dart` — full `MintSpacing` constants
  - `apps/mobile/lib/theme/mint_motion.dart` — `MintMotion` durations + curves
  - `apps/mobile/analysis_options.yaml` — current 3-rule lint config
  - `apps/mobile/pubspec.yaml` — flutter_lints 3.0.0, no custom_lint dep
- **Existing `tools/checks/*.py`** — 11 production lint scripts, especially:
  - `wcag_aa_all_touched.py` — closest precedent for hardcoded-color enforcement
  - `s0_s5_aaa_only.py` — closest precedent for token enforcement
  - `accent_lint_fr.py` — closest precedent for `--file` lefthook flag, ignore markers
  - `no_hardcoded_fr.py` — closest precedent for ignore markers, exclude dirs
  - `route_registry_parity-KNOWN-MISSES.md` — closest precedent for « grandfathered baseline » documentation
- **`.github/workflows/ci.yml`** — verified Python 3.11 setup, existing lint job pattern
- **`lefthook.yml`** — verified pre-commit dispatch pattern, `{staged_files}` substitution
- **`.planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md`** — phase scope authoritative source
- **`.planning/decisions/2026-05-09-7-panel-comprehensive-audit/SYNTHESIS.md`** — drift baseline (verified, partly inflated)

### Secondary (MEDIUM confidence)

- **pub.dev/packages/analysis_server_plugin** — official Dart team lint plugin framework, v0.3.15 [CITED]
- **pub.dev/packages/custom_lint** — Invertase plugin, archived 2026-03-24 [CITED]
- **github.com/invertase/dart_custom_lint** — archive notice, migration recommendation [CITED]
- **charlescyt.github.io/create-your-own-lint-rules-with-custom-lint** — reference implementation pattern (used to confirm Dart approach is feasible but heavy) [CITED]

### Tertiary (LOW confidence)

- **medium.com/@gil.bassi/how-to-create-a-custom-lint-rule-for-flutter** — tutorial; not authoritative [CITED for awareness only]
- **github.com/Nikoro/many_lints** — a published bundle (`many_lints`); didn't find specific raw-color rule [CITED for survey]

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|---|---|---|
| Existing token API | HIGH | Read all 4 theme files in full |
| Existing lint pattern | HIGH | Read 5 existing scripts, all share the same shape |
| CI/lefthook integration points | HIGH | Read both config files |
| Drift inventory counts | HIGH | All counts produced by `grep` against current HEAD; cross-checked top distributions |
| Tool ecosystem currency | HIGH | Verified `custom_lint` archive date, `analysis_server_plugin` v0.3.15 release |
| « Right number of lints » call | MEDIUM | Trade-off between coverage and the 2-day budget. 5 is a defensible compromise; could argue for 3 (drop LINT-04 + LINT-05 for sweep phases). |
| `// lint-ignore` syntax adoption | HIGH | Verified existing convention |
| Baseline-snapshot pattern | HIGH | Verified existing precedent `route_registry_parity-KNOWN-MISSES.md` |
| Audit's "367 raw colors" reconciliation | MEDIUM | The grep substring hypothesis matches the data (8295 `MintColors.*` + 29 real Material refs, vs. 367 audit headline = ratio fits). Could ask audit author for original grep to fully close. |

**Research date:** 2026-05-09
**Valid until:** 2026-06-09 (30 days for stable; revisit if `analysis_server_plugin` reaches 1.0 in window).

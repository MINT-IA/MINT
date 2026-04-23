# Phase 34 Codebase Impact Audit

**Date:** 2026-04-23
**Scope:** 5 lints run against full production codebase (not synthetic fixtures)
**Method:** Direct invocation on `apps/mobile/lib` + `services/backend`, plus
scratch git repos for diff-only + drift experiments. No tracked files modified.

## Quantitative summary

| Lint              | Synthetic tests | Production violations                 | Claim in SUMMARY        | Delta              |
|-------------------|-----------------|---------------------------------------|-------------------------|--------------------|
| accent_lint_fr    | 13/13 pass      | 899 mobile + 357 backend = **1,256**  | 899 (mobile only)       | +357 (backend not mentioned) |
| no_bare_catch     | 12/12 pass      | ~339 dart + ~55 py = **~394**          | 388 (332 + 56)          | +6 (~2%)           |
| no_hardcoded_fr   | 11/11 pass      | 1,376 widget-scope, 3,285 services, 184 models | widget scope only | services excluded = 3,285 hidden strings |
| arb_parity        | 14/14 pass      | 0 (baseline green)                    | 6707 keys × 6           | matches            |
| proof_of_read     | 12/12 pass      | N/A (commit-msg hook)                 | N/A                     | matches            |

**Headline:** All 5 lints WORK AS SPECIFIED. The key gap is a semantic one: the
`no_hardcoded_fr` D-08 exclusion of `lib/services/` hides **3,285** real FR
strings, not the ~120 claimed in FIX-06 D4.

## Task-by-task findings

### Task 1: Accent lint — production scan

**Command:** `python3 tools/checks/accent_lint_fr.py --scope apps/mobile/lib services/backend`

- `apps/mobile/lib` = **899 violations** — matches SUMMARY 34-01 claim exactly.
- `services/backend` = **357 additional violations** — NOT mentioned in any
  SUMMARY; FIX-07 catalog only cites `apps/mobile/lib`.
- `apps/mobile/lib/l10n/app_fr.arb` = 2 violations (`prevoyance` unaccented twice).

**Top-10 mobile files (by violation count):**
```
  173  apps/mobile/lib/providers/coach_profile_provider.dart
   74  apps/mobile/lib/models/coach_profile.dart
   39  apps/mobile/lib/services/retirement_projection_service.dart
   33  apps/mobile/lib/services/coach_narrative_service.dart
   29  apps/mobile/lib/services/forecaster_service.dart
   22  apps/mobile/lib/services/financial_core/confidence_scorer.dart
   19  apps/mobile/lib/services/financial_fitness_service.dart
   19  apps/mobile/lib/services/financial_core/tornado_sensitivity_service.dart
   19  apps/mobile/lib/services/financial_core/cross_pillar_calculator.dart
   18  apps/mobile/lib/services/financial_core/monte_carlo_service.dart
```

**Generated `app_localizations_en.dart` check (SUMMARY 34-01 claim "32 violations"):**
- Actual count: **2 violations** in `app_localizations_en.dart` alone.
- Across ALL `app_localizations_*.dart` generated files: 32 total violations.
- SUMMARY claim is approximately correct but the phrasing "32 in
  `app_localizations_en.dart`" is misleading — the 32 is spread across 4
  generated dart files (the `prevoyance` variable name appears in each
  language's generated method signature for the same ARB key).

**Verdict:** Lint is accurate; SUMMARY's scope (mobile-only) understates total
technical debt by ~40%.

### Task 2: Bare-catch diff-only verification — CRITICAL

**Part A — grep count:**
- Dart `} catch (e|_|err|error) {` (broad pattern, includes with-body cases):
  **339 occurrences across 130 files** in `apps/mobile/lib`.
- Python bare-except (narrow — empty colon line):
  - `^\s*except\s+Exception\s*:\s*$` = 48 matches in `services/backend/app`
  - `^\s*except\s*:\s*$` = 0 matches
  - Broader search (incl. alembic/tests): 55 matches across 26 files.
- Combined = **~394** — claim was 388. Delta ~2%, within noise.
- Dart **truly empty-body** bare-catches (`catch (e) {}`): only **20**. The 332
  claim uses the broader pattern (body that doesn't log/rethrow).

**Part B — diff-only verification (D-07 guarantee):**

Evidence that diff-only mode works on real files:

```bash
# Scratch repo 1: synthetic file with existing bare-catch
TMP=$(mktemp -d /tmp/bare_catch_test.XXXXXX); cd "$TMP" && git init -q
# ... create test.dart with existing catch (e) {} ...
git add test.dart && git commit -m "initial"
# Add unrelated change
printf "\n// unrelated comment\n" >> test.dart && git add test.dart
python3 tools/checks/no_bare_catch.py --staged --repo-root "$TMP"
=== rc: 0 ===    # existing catch NOT flagged
# Now add a NEW bare-catch
cat >> test.dart <<EOF
void newFunction() { try { somethingNew(); } catch (e) {} }
EOF
git add test.dart && python3 tools/checks/no_bare_catch.py --staged --repo-root "$TMP"
=== rc: 1, 1 violation on line 12 ===
```

```bash
# Scratch repo 2: real production file (simulator_3a_screen.dart)
TMP2=$(mktemp -d /tmp/real_file_test.XXXXXX); cd "$TMP2" && git init -q
cp apps/mobile/lib/screens/simulator_3a_screen.dart test.dart
git add test.dart && git commit -m "copy real file with existing bare-catch"
echo "// harmless comment" >> test.dart && git add test.dart
python3 tools/checks/no_bare_catch.py --staged --repo-root "$TMP2"
=== rc: 0 ===    # existing bare-catches in real file NOT flagged
```

**Verdict:** D-07 diff-only GUARANTEE HOLDS on production code. This is the
single most important technical claim of Phase 34 — empirically verified
against a real MINT screen containing existing bare-catches.

### Task 3: Hardcoded-FR false-positive rate

**Widget-scope run:**
`--scope apps/mobile/lib/widgets apps/mobile/lib/screens apps/mobile/lib/features`
- **1,376 violations** reported.

**Sample of 20 random violations — classification:**
- 18 true-positives (real user-facing FR strings: labels, subtitles, titles,
  semanticLabels, snackbar messages).
- 1 false-positive — line 101 in `privacy_control_screen.dart`:
  `// PROF-03: Users expect "Ce que MINT sait de toi" to show ALL` — the FR
  text sits inside a `//` comment.
- 1 ambiguous — `Text('Date picker not yet implemented')` — English debug
  fallback flagged because `_TEXT_CAPITALISED` doesn't distinguish EN from FR.

**FP rate ≈ 10%**, driven almost entirely by strings inside code comments.
47/1,376 rows (≈3.4%) match `///` docstring lines and another ~40 match `//`
inline comments.

**Top FP patterns to whitelist:**
1. Strings inside `///` doc comments (47+ rows). Easy fix: skip lines where
   `lstrip().startswith(('//', '/*', '*'))`.
2. Debug-only `print(...)`/`debugPrint(...)` call content — already in
   IGNORE_MARKERS but whole-line check would also suppress the surrounding
   f-string values. Actually covered today by IGNORE_MARKERS.
3. English strings flagged via `_TEXT_CAPITALISED` (e.g. "Date picker not yet
   implemented"). D-09 patterns don't distinguish FR vs EN capitalised words.
4. Dart `.runtimeType.toString()` outputs embedded in error messages — rare but
   observed.
5. Code comments with `TODO:` / `FIXME:` / `FEAT:` prefixes that happen to
   contain FR discussion — observed 5-6 times.

**D-08 exclusion check — `lib/models` + `lib/services`:**
Forced `--file` loop to bypass EXCLUDE_SUBSTRINGS:
- `apps/mobile/lib/models/**/*.dart` = **184 violations** hidden.
- `apps/mobile/lib/services/**/*.dart` = **3,285 violations** hidden.

**This dwarfs the claimed "~120 strings FIX-06 D4" by 27×.** The D-08 scope is
intentional per RESEARCH Open Question 3 — Phase 34 ACTIVATES the gate for new
widget code, Phase 36 FIX-06 owns the backlog. But the documented backlog
estimate of 120 is wrong by an order of magnitude.

### Task 4: ARB parity — production stress test

**Baseline:** `python3 tools/checks/arb_parity.py` → rc=0,
`6 ARB files parity OK (non-@ keys=6707, placeholder-bearing @keys checked=568)`.
Matches SUMMARY 34-04 claim exactly.

**Drift experiments (scratch copy of `apps/mobile/lib/l10n/`):**

| Scenario                            | rc  | Error message                                                                                                          |
|-------------------------------------|-----|------------------------------------------------------------------------------------------------------------------------|
| Delete `landingFeature1Title` from app_de.arb | 1 | `[arb_parity] FAIL - key 'landingFeature1Title' missing in app_de.arb`                                              |
| Add rogue key only in app_fr.arb    | 1   | Prints 5 missing-in-{en,de,es,it,pt} lines                                                                             |
| Rename placeholder `confidence` → `ROGUEPH` in app_en.arb | 1 | `[arb_parity] FAIL - key 'documentsConfidence' placeholder drift in app_en.arb missing=['confidence'] extra=['ROGUEPH']` |

Error messages are clear and actionable (key name + file + missing/extra diff).

**ICU edge cases (walk through real `app_fr.arb`):**
- `{count, plural, one {X} other {Y}}` → walker correctly emits `count` only.
- `{sex, select, male {il} female {elle} other {iel}}` → walker correctly
  emits `sex` only, does NOT emit `il`/`elle`/`iel` (confirmed by the 568
  @keys scan passing with no false positives).
- Real MINT keys where placeholder is literally named `plural` (in
  `stepOcrContinueWith`), `number` (in `mortgageJourneyStepLabel`), `date`
  (in `mintHomeDeltaSince`) — all emit correctly because ICU_KEYWORDS filter
  was removed per SUMMARY 34-04 Rule 1 fix.

**Verdict:** Production-grade parser; handles every ARB form present in MINT.

### Task 5: proof_of_read — commit-msg hook

**Hook wiring:** `.git/hooks/commit-msg` exists (2113 bytes, mode 755),
references lefthook via the `call_lefthook run "commit-msg"` shim. `lefthook
install --force` produces this correctly. No manual git hook edits required.

**Direct invocation matrix:**
| Scenario                                           | rc | Output                                                                                                |
|----------------------------------------------------|----|-------------------------------------------------------------------------------------------------------|
| Human-only (no Claude trailer)                     | 0  | `[proof_of_read] OK - human commit (no Claude trailer), bypass`                                       |
| Claude trailer + valid `Read: .planning/phases/...` | 0  | `[proof_of_read] OK - Claude commit references ...34-05-READ.md (14 files listed)`                    |
| Claude trailer + no `Read:` trailer                | 1  | `[proof_of_read] FAIL - Claude-coauthored commit missing Read: trailer`                               |

**T-34-SPOOF-01 regression check:** `Read: /dev/null` + Claude trailer →
rejected as expected per SUMMARY 34-05 (not re-tested here; see SUMMARY's own
spoof-path matrix).

**Verdict:** Hook lives up to D-16/D-17/D-18 exactly as claimed.

### Task 6: Performance reality check

**Synthetic baseline (`lefthook_benchmark.sh`, clean tree):**
P95 = 0.410s (matches SUMMARY's sub-second claim).

**Realistic test — scratch repo with 50 dart widgets + 20 py files staged:**

5 sequential runs of `lefthook run pre-commit`:
```
2743ms, 2755ms, 2814ms, 2816ms, 3086ms
P95 ≈ 3086ms
```

**Per-hook profile (from one representative run):**
```
  map-freshness-hint        0.04s
  memory-retention-gate     0.04s
  no-chiffre-choc           0.04s
  accent-lint-fr            2.48s  ← slowest
  no-bare-catch             2.81s  ← second slowest
  (parallel; summary total 2.82s)
```

**Root cause of slowness:** `accent-lint-fr` uses a shell `for` loop invoking
Python once per staged file (see `lefthook.yml:42-47`). Python startup
overhead (~40ms × N files) dominates. For 50 Dart + 20 Python = 70 invocations,
that's ~2.8s of pure interpreter cold-start. `no-bare-catch` runs `--staged`
which does one Python invocation but calls `git diff` per file internally
(70 git-subprocess calls).

**Verdict:**
- P95 under realistic load = **3.1s** — under 5s budget (38% headroom), but
  not the 45x claimed in SUMMARIES.
- The 0.110s "P95" from SUMMARY benchmarks reflects the empty-stage case. On
  commits touching ~70 files, real P95 is 28× slower.
- Still within spec; GUARD-01 <5s criterion holds.

### Task 7: Duplicate artifact hygiene

**Untracked iCloud `* 2.py` / `* 3.py` files in `tools/checks/`:**
```
accent_lint_fr 2.py
audit_artefact_shape 2.py
claude_md_bracket 2.py
claude_md_triplets 2.py
lefthook_self_test 2.sh
memory_retention 2.py
no_hardcoded_fr 2.py
route_registry_parity 2.py
route_registry_parity 3.py
route_registry_parity-KNOWN-MISSES 2.md
route_registry_parity-KNOWN-MISSES 3.md
sentry_capture_single_source 2.py
verify_sentry_init 2.py
```

Plus `.lefthook/route_registry_parity 2.sh` and `.lefthook/route_registry_parity 3.sh`.

**Check 1 — referenced by lefthook.yml or new lints?**
`grep "[23]\.py\|[23]\.sh" lefthook.yml tools/checks/lefthook_self_test.sh tools/checks/*.py` → **0 matches.**
None of the Phase 34 artifacts reference these duplicates.

**Check 2 — snuck into any commit?**
`git log --since="2026-04-20" --diff-filter=A --name-only | grep " [23]\.(py|sh)$"` → **0 matches.**
`git ls-files | grep " [23]\.(py|sh)$"` → **0 matches.**
Duplicates are 100% untracked; no risk of shadowing the real scripts.

**Verdict:** Low risk. Duplicates are iCloud sync artifacts (user's Desktop is
iCloud-synced). CONTEXT §Duplicates-to-watch correctly flagged them as
"NOT canonical, ignore". Housekeeping is backlog, not blocker.

### Task 8: Memory retention gate — is it gating?

Script behavior per source (`tools/checks/memory_retention.py`):
- **HARD gate:** fails (rc=1) when any `memory/topics/*.md` >30d old is NOT
  in the whitelist (`feedback_*`, `project_*`, `user_*`) AND not a
  `__LEFTHOOK_SELF_TEST_*` fixture.
- **SOFT warning:** emits stderr notice if `MEMORY.md` >100 lines (per D-02
  `INDEX_WARN_LINES=100`). Does NOT fail. This is by design.

**Current state:**
- `MEMORY.md` = 181 lines → SOFT warning fires. Consistent with SUMMARY.
- `memory/topics/` has 142 files total.
- Files >30d old AND non-whitelisted = **0** — so the HARD gate legitimately
  stays green.
- The only non-whitelisted file (`reference_monzo_vertical_ai_benchmarks.md`)
  has mtime Apr 16 2026 → 6 days old → well within 30d.

Gate invocation result: `rc=0`, one stderr WARNING, no FAIL.

**Verdict:** Gate IS firing as designed. The WARNING-not-FAIL on MEMORY.md
size is explicitly documented as SOFT per D-02. Not a bug.

## P0 / P1 / P2 findings

**P0 — None.** All 5 lints pass their acceptance criteria on production code.

**P1 — One:**

- **P1-01 — `no_hardcoded_fr` D-08 exclusion understates FIX-06 scope by 27×.**
  SUMMARY 34-03 + CONTEXT D4 reference "~120 strings" as the Phase 36 FIX-06
  audit backlog. Empirical measurement:
  - `apps/mobile/lib/services/**/*.dart` = **3,285** violations.
  - `apps/mobile/lib/models/**/*.dart` = **184** violations.
  - Total excluded = **3,469** strings.
  
  **Impact:** FIX-06 sizing is wildly optimistic. A 120-string sprint is
  ~1 day; a 3,469-string sprint is weeks.
  **Action for Plan 36-FIX-06:** re-measure scope before committing budget.

**P2 — Three:**

- **P2-01 — Benchmark reports are empty-stage P95.** SUMMARY 34-02/03/04 cite
  0.100-0.110s P95 as evidence that GUARD-01 <5s is "45× headroom". Realistic
  P95 on 70 staged files = 3.1s → 1.6× headroom. Still under budget, but the
  headroom framing is wrong by an order of magnitude. Recommend:
  `lefthook_benchmark.sh` should stage a representative diff, not an empty
  commit, before claiming <5s compliance.

- **P2-02 — `accent-lint-fr` shell-loop is a latent perf cliff.** At
  ~40ms/file Python startup, a 200-file commit would exceed 8s and break
  GUARD-01. Consider migrating to a single-shot `--files f1 f2 ... fN`
  invocation (like `arb_parity`) to amortize startup.

- **P2-03 — Accent lint backend-scope debt uncounted.** SUMMARY 34-01's "899
  violations, FIX-07 Phase 36 scope" only covers `apps/mobile/lib`.
  `services/backend` has 357 additional violations. Phase 36 FIX-07 should
  either expand its scope explicitly or document why backend is exempt.

## Empirical verdict

All 5 lints are **functionally correct** and **production-ready**:
- Patterns match CLAUDE.md §2 (accent) and D-05/D-09/D-13 (the new lints).
- D-07 diff-only mode for `no_bare_catch` provably decouples from FIX-05.
- ARB parity walker handles every ICU form in real MINT data (plural,
  select, typed, DateTime, real placeholder names `plural`/`number`/`date`).
- proof_of_read commit-msg wiring is live; 3-scenario matrix passes.
- Memory retention gate fires correctly (HARD green, SOFT warn as designed).

What the SUMMARIES understate:
- True Phase 36 FIX-06 scope is ≥3,469 strings, not 120.
- Realistic P95 is 3.1s, not 0.11s.
- Backend accent debt (+357 violations) isn't in FIX-07 scope today.

## Referenced file paths

- /Users/julienbattaglia/Desktop/MINT/tools/checks/accent_lint_fr.py
- /Users/julienbattaglia/Desktop/MINT/tools/checks/no_bare_catch.py
- /Users/julienbattaglia/Desktop/MINT/tools/checks/no_hardcoded_fr.py
- /Users/julienbattaglia/Desktop/MINT/tools/checks/arb_parity.py
- /Users/julienbattaglia/Desktop/MINT/tools/checks/proof_of_read.py
- /Users/julienbattaglia/Desktop/MINT/tools/checks/memory_retention.py
- /Users/julienbattaglia/Desktop/MINT/tools/checks/lefthook_benchmark.sh
- /Users/julienbattaglia/Desktop/MINT/lefthook.yml
- /Users/julienbattaglia/Desktop/MINT/.git/hooks/commit-msg
- /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/providers/coach_profile_provider.dart (top accent offender, 173 violations)
- /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/models/age_band_policy.dart (top hidden `lib/models` FR offender)
- /Users/julienbattaglia/Desktop/MINT/services/backend/app/services/educational_content_service.py (top backend accent offender, 23 violations)

---
*Phase 34 Codebase Impact Audit*
*Audit-only — no tracked files modified. All scratch repos cleaned up.*

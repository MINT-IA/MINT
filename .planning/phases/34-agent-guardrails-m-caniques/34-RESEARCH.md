# Phase 34: Agent Guardrails mécaniques — Research

**Researched:** 2026-04-22
**Domain:** git hooks orchestration (lefthook), static-analysis regex lints (Dart + Python), JSON/ICU ARB parity, commit-trailer guardrails, CI workflow migration
**Confidence:** HIGH

## Summary

Phase 34 is almost fully prescribed — the 26 locked decisions in 34-CONTEXT.md + the CLAUDE.md / lefthook skeleton / accent_lint_fr.py already in the repo remove most ambiguity. Research focused on **the five technical unknowns** listed in the brief + **one critical unknown surfaced by investigation**:

1. `git diff --staged --unified=0` hunk-header parsing is a solved stdlib-only problem (verified empirically on `/tmp/gittest`). A 15-line Python state-machine extracts added-line numbers + content reliably. No `python-unidiff` dep needed.
2. `lefthook` installed on this machine is **2.1.6**, not 2.1.5. `min_version: 2.1.5` in the skeleton still validates (`min_version` is a lower bound). **However `lefthook validate` currently REJECTS the skeleton with `skip: Value is array but should be object`** — top-level `skip: [merge, rebase]` is no longer valid in 2.1.x; `skip:` must be nested under the hook (e.g. `pre-commit: skip: - merge`). **This is a phase blocker not mentioned in CONTEXT.md.** Must land in Wave 0 as a schema fix.
3. `lefthook` supports `commit-msg` as a first-class hook with `{1}` placeholder → `.git/COMMIT_EDITMSG` — proof-of-read belongs there, NOT pre-commit. CONTEXT D-04 says "Pas de `commit-msg` dans cette phase" but D-17 describes a check that cannot run pre-commit. Recommend **nuance D-04 in the plan**: the proof-of-read check can *either* move to `commit-msg` (simpler) or stay in `post-commit` (no file blocking, but can abort via exit≠0 in lefthook).
4. ARB parity: 6 files, 6707 non-`@` keys in each today (parity PASS baseline — grep verified). FR is the template (`template-arb-file: app_fr.arb` per `apps/mobile/l10n.yaml`) and carries **569 `@key` metadata with placeholders**; the 5 others carry only **485** `@keys`. Placeholder parity must treat FR as source-of-truth and verify the other langs' *values* reference the same ICU tokens, not that they declare `@key` metadata.
5. `--no-verify` cannot be reliably audited post-hoc (no trace in commit). `LEFTHOOK_BYPASS=1` is runtime-only too (env var never persists). The only ground-truth GUARD-07 audit mechanism is **CI re-running `lefthook run pre-commit --all-files --force` on PR range and diffing** — this is already CONTEXT D-24. The "weekly audit" + `>3/week` alert becomes more about *trend awareness* than strict detection.

**Primary recommendation:** Wave 0 must ship a `lefthook.yml` schema migration (nested `skip`) BEFORE adding the 5 new commands, otherwise `lefthook run pre-commit` silently refuses to parse config in some tooling paths. Then land GUARD-04 activation first (asset already exists, zero new code), then GUARD-02 (diff-only, highest risk), then GUARD-03 / GUARD-05 / GUARD-06 / GUARD-07 / GUARD-08 in that order.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions (26 D-xx)

**D-01** : Un seul `lefthook.yml` à la racine, sections logiques par tag (`[memory]`, `[i18n]`, `[safety]`, `[maps]`). Pas de `lefthook-local.yml` template. Skeleton 30.5 (`memory-retention-gate` + `map-freshness-hint`) préservé, les 5 nouveaux lints s'ajoutent par-dessus.

**D-02** : `parallel: true` activé. Budget <5s absolu mesuré sur M-series Mac avec diff typique (5 Dart + 3 Python staged). Mesure via `LEFTHOOK_PROFILE=1 time git commit --allow-empty -m 'perf'` capturé dans SUMMARY.

**D-03** : Scope changed-files only via `glob:` filter par commande. Pas de full-repo scan dans aucun hook.

**D-04** : `brew install lefthook` + `lefthook install` post-clone documenté dans `CONTRIBUTING.md`. `min_version: 2.1.5`. Pas de `pre-push`, pas de `commit-msg` dans cette phase.

**D-05** : `no_bare_catch.py` regex-first (pas AST). Patterns détectés :
- Dart : `}\s*catch\s*\(\s*(e|_)\s*\)\s*\{[\s\n]*\}` (bare) + `}\s*catch\s*\(\s*e\s*\)\s*\{[\s\n]*\}` sans `log`/`Sentry`/`rethrow`/`debugPrint` dans le body.
- Python : `except\s+Exception\s*:\s*$` + `except\s*:\s*$` + `except\s+\w+\s*:\s*pass` sans `logger.`/`raise`/`sentry_sdk.`/`log.` dans les 5 lignes suivantes.

**D-06** : Exceptions `no_bare_catch` — `apps/mobile/test/**`, `apps/mobile/integration_test/**`, `services/backend/tests/**` exemptés. Dart streams `async *` détectés par `grep -B 10 "async \*"`. Opt-in inline override via `// lefthook-allow:bare-catch: <reason>` (reason >3 mots).

**D-07** : GUARD-02 **active from day 1**, pas de warm-up. Lint scan uniquement les **lignes ajoutées** au diff (via `git diff --staged --unified=0` + line-range check). Les 388 bare-catches existants ne moving-target pas. FIX-05 Phase 36 converge à 0 par batch.

**D-08** : `no_hardcoded_fr` scope restreint à `apps/mobile/lib/widgets/**`, `apps/mobile/lib/screens/**`, `apps/mobile/lib/features/**`. Exclus : `lib/l10n/`, `lib/models/`, `lib/services/`, `test/`, `integration_test/`.

**D-09** : Patterns FR détectés : `Text\(['"]([A-Z][a-z]+.{5,})['"]\)`, `Text\(['"].*[éèêàôùç].*['"]\)`, `title:\s*['"][A-Z][a-z]+`, `label:\s*['"][A-Z][a-z]+`. Whitelist short technical strings (acronymes, numéros).

**D-10** : Opt-in override `// lefthook-allow:hardcoded-fr: <reason>`.

**D-11** : Réutilise `tools/checks/accent_lint_fr.py` existant. 14 patterns CLAUDE.md §2 : creer, decouvrir, eclairage, securite, liberer, preter, realiser, deja, recu, elaborer, regler, prevoyance, reperer, cle.

**D-12** : Scope `.dart`, `.py`, `app_fr.arb` (PAS les autres ARB). Fail hard. Pas d'opt-in override.

**D-13** : arb_parity — union 6 ARB (fr, en, de, es, it, pt) identique. Missing/extra = fail. Placeholder type mismatch = fail.

**D-14** : `tools/checks/arb_parity.py` nouveau. `json.load()` sur les 6 fichiers. Pas de dep ICU/intl. Output `FAIL: key 'xxx' missing in {de, es}` avec diff lisible.

**D-15** : Grandfathering — les clés orphelines côté Dart (1864 dead ARB keys) hors scope. GUARD-05 parité cross-langue uniquement.

**D-16** : Proof-of-read convention — `Read: .planning/phases/<phase>/<padded>-READ.md` présent dans commit message pour tout commit d'agent. Détection via regex sur `git log -1 --format=%B`. Flag agent commits via `Co-Authored-By: Claude*`.

**D-17** : `tools/checks/proof_of_read.py` vérifie (1) `Co-Authored-By: Claude`, (2) message contient `Read:` trailer, (3) fichier référencé existe sur disque. Humain (no Claude trailer) = bypass auto.

**D-18** : READ.md format — liste bullet `- <path> — <why read>`. Pas de timestamp, pas de hash.

**D-19** : DIFF-04 PreToolUse hook reste déféré Phase 36 — GUARD-06 est le fallback explicite.

**D-20** : `--no-verify` interdit par convention. `LEFTHOOK_BYPASS=1 git commit` pour bypass légitime. Documenté CONTRIBUTING.md.

**D-21** : Audit CI post-merge — `.github/workflows/bypass-audit.yml` weekly (Monday 09:00 UTC) + post-merge to `dev`. Lit `git log --since="7 days ago"` sur `dev`, grep `LEFTHOOK_BYPASS=1` + `--no-verify` marker si détectable. Issue auto-créée (`bypass-audit` label) si >3/week.

**D-22** : Seuil 3/week. Escalation manuelle.

**D-23** : CI thinning — migrent vers lefthook : accent_lint_fr.py, no_hardcoded_fr.py, no_bare_catch.py, arb_parity.py, proof_of_read.py, memory_retention.py (déjà), no_chiffre_choc.py, landing_no_financial_core.py, landing_no_numbers.py, route_registry_parity.py. Restent CI : flutter test, pytest -q, flutter analyze, dart format, wcag_aa_all_touched.py, readability, PII scanner, OpenAPI contracts, Alembic.

**D-24** : Double-run protection — CI conserve `lefthook-ci` qui exécute `lefthook run pre-commit --all-files --force` sur PR range.

**D-25** : Self-test script étend `tools/checks/lefthook_self_test.sh`. Ajoute 5 FAIL + 5 PASS cas. Run en CI.

**D-26** : Benchmark `tools/checks/lefthook_benchmark.sh` mesure `lefthook run pre-commit` sur diff synthétique 5 Dart + 3 Python. P95 <5s. Weekly regression.

### Claude's Discretion

- Structure interne des 4 scripts Python (argparse, logging, format erreurs).
- Tags lefthook exactes (`[safety]`, `[i18n]`, etc.).
- Détail self-test scenarios (fixtures, naming).
- Format issue GitHub auto-créée par bypass-audit.yml.

### Deferred Ideas (OUT OF SCOPE)

- **FIX-05** migration des 388 bare-catches → Phase 36. Backend 56 d'abord (pattern simple), mobile 332 batched 20/PR.
- **FIX-07** fix accents résiduels → Phase 36. GUARD-04 prevents régression, FIX-07 converge.
- **FIX-06** MintShell ARB parity 6 langs audit → Phase 36. GUARD-05 est le gate, FIX-06 fait l'audit complet.
- **DIFF-04** PreToolUse proof-of-read via Claude Agent SDK → Phase 36/v2.9. GUARD-06 = fallback.
- Cleanup des 1864 dead ARB keys → déferré v2.9.
- Cleanup des `" 2.py"` / `" 3.py"` iCloud duplicates → backlog.
- Pre-push hooks, commit-msg hooks, post-checkout hooks → hors scope (v2.9 si utile).
- Lefthook en-CI dockerisé version complète → v2.9.
- Migration vers Husky / pre-commit (Python) → écarté (kill-policy : lefthook only).
- Proof-of-read via SHA hash → écarté (complexité).

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description (from REQUIREMENTS.md) | Research Support |
|----|------------------------------------|------------------|
| **GUARD-01** | lefthook 2.1.5 installed (brew) + `lefthook.yml` pre-commit parallel complet — target <5s absolu M-series Mac, scope changed-files only via glob filters. | §Standard Stack (lefthook 2.1.6 installed), §Architecture Patterns (parallel mode pitfalls), §Schema Migration (top-level `skip` rejection). Baseline: `/opt/homebrew/Cellar/lefthook/2.1.6`. |
| **GUARD-02** | `tools/checks/no_bare_catch.py` — refuse `} catch (e) {}` Dart + `except Exception:` Python sans log/rethrow, exempte `test/` + streams `async *`. | §Diff-Only Implementation (stdlib-only state machine verified on /tmp/gittest). §Bare-catch Regex Library (Dart + Python patterns). Current prevalence: 32 `} catch (e) {` in mobile/lib/providers sample. |
| **GUARD-03** | `tools/checks/no_hardcoded_fr.py` — scan Dart widgets pour strings FR hors `AppLocalizations`, exclut `lib/l10n/`. | §Existing Asset Audit — `tools/checks/no_hardcoded_fr.py` ALREADY EXISTS (early-ship from Phase 30.5). Phase 34 scope : tighten heuristic per D-09, add `// lefthook-allow:hardcoded-fr:` override, scope restriction. |
| **GUARD-04** | `tools/checks/accent_lint_fr.py` — ASCII-only flag sur `app_fr.arb` + `.dart` + `.py`. | §Existing Asset Audit — `tools/checks/accent_lint_fr.py` ALREADY EXISTS (15 patterns, used by CTX-02). **Extra 1 pattern in file vs 14 in CLAUDE.md §2** — current file has `specialistes`, `gerer`, `progres`; missing `prevoyance`, `reperer`, `cle`. Must reconcile in Phase 34. |
| **GUARD-05** | `tools/checks/arb_parity.py` — 6 ARB files mêmes keyset. | §ARB Parity Baseline (6707 non-@ keys in each language — PASS today). §Placeholder Schema (FR template has 569 @keys w/ placeholders vs 485 for other langs — FR-as-template asymmetry must be handled). §ICU Token Parsing Strategy. |
| **GUARD-06** | `tools/checks/proof_of_read.py` — agent co-author commits doivent référencer `.planning/<phase>/READ.md`. | §Commit-Msg Hook Timing (commit-msg hook receives `{1}` = path to COMMIT_EDITMSG). §Hook Placement Dilemma (pre-commit is too early). §Trailer Detection. |
| **GUARD-07** | `--no-verify` ban → `LEFTHOOK_BYPASS=1` convention + CI post-merge audit. | §Bypass Audit Feasibility (D-24 CI re-run is ground truth, not grep). §Convention-only vs mechanical block. |
| **GUARD-08** | CI thinning — les 10 grep-style gates deviennent lefthook-first. | §CI Thinning Map — exact line numbers identified in `.github/workflows/ci.yml` (lines 161, 166, 171, 176, 181, 202, 207, 211, 448). |
</phase_requirements>

---

## Project Constraints (from CLAUDE.md)

**TOP/BOTTOM 5 RULES CRITIQUES (Liu 2024 bracketing, must remain intact post-Phase-34 edits):**

1. **Banned terms (LSFin)** — NEVER « garanti », « optimal », « meilleur », « certain », « assuré », « sans risque », « parfait ». Phase 34 error messages emitted to stderr MUST NOT contain banned terms (self-compliance).
2. **Accents 100% FR mandatory** — `creer → créer`, `eclairage → éclairage`, `decouvrir → découvrir`, `securite → sécurité`. **GUARD-04 IS THE MECHANICAL ENFORCEMENT of this rule.** Phase 34 itself MUST not introduce ASCII-flattened FR accents — including in stderr messages of the lints.
3. **MINT ≠ retirement app** — Phase 34 lints must not special-case `retraite` keys.
4. **Financial_core reuse mandatory** — N/A for Phase 34 (dev-tooling phase).
5. **i18n required** — Phase 34 error messages are **technical English-only** by discretion (per Phase 32-03 admin pattern, M-1 carve-out): lint output is dev-facing, not user-facing, so no ARB keys needed. Document this explicitly in each new lint's header.

**§3 MCP TOOLS** (Phase 30.7 shipped) — if any lint wants to consult banned-terms or accent patterns programmatically, it can call the MCP tools via stdio (`get_swiss_constants`, `check_banned_terms`, `validate_arb_parity`, `check_accent_patterns`). However, pre-commit hooks are short-lived subprocesses; **direct Python stdlib is simpler and lower-latency** for these 5 lints. MCP tools are for AGENT context, not hook performance paths.

**§4 Dev Rules** — Phase 34 DOC task must add a new NEVER triplet about `--no-verify` if possible within the CLAUDE.md -30% budget. If space is tight, put it in `.claude/skills/mint-commit/SKILL.md` (already banned at L104: "NEVER skip hooks (`--no-verify`)"). Skill is already correct — Phase 34 only needs to add `LEFTHOOK_BYPASS=1` as the canonical escape hatch next to the existing ban. No CLAUDE.md change strictly required.

---

## Standard Stack

### Core — zero new dependencies

| Tool | Version (verified) | Purpose | Why Standard |
|------|--------------------|---------|--------------|
| `lefthook` | **2.1.6** (installed via brew on dev host) | git hook orchestrator | 30.5 D-04 locked choice, kill-policy ADR line 150 "Husky / pre-commit (python) — PROJECT.md L150 — lefthook only". `min_version: 2.1.5` in config = lower bound, `2.1.6` satisfies. `[VERIFIED: /opt/homebrew/Cellar/lefthook/2.1.6]` |
| `git` | any (macOS bundled or brew) | diff parsing (`--staged --unified=0`) | stdlib of developer workflow. `--unified=0` behaviour verified on `/tmp/gittest` 2026-04-22. `[VERIFIED: git diff output empirically parsed]` |
| `python3` | 3.9+ (dev 3.9.6, CI 3.11) | lint runtime | matches existing `tools/checks/*.py` — stdlib-only constraint. `[VERIFIED: tools/checks/route_registry_parity.py header]` |

**No pip installs, no new packages.** The 5 new lints are stdlib-only (`argparse`, `re`, `json`, `pathlib`, `subprocess`). Keeps pre-commit startup <50ms per command (lefthook overhead dominates).

**Python 3.9 compat rules (inherited from `route_registry_parity.py`):**
- `from __future__ import annotations`
- Use `typing.List/Set/Tuple/Optional`, NOT PEP 585 builtins (`list[str]` in annotations only — guarded by `__future__`)
- No PEP 604 unions `X | Y` in runtime code
- No `match/case`
- No `dict | dict` merge

### Version verification

```bash
lefthook version           # → 2.1.6 (2026-04-22)
python3 --version          # → 3.9.6 local / 3.11 CI
git --version              # → 2.x bundled macOS / ubuntu-latest
```

Published versions (context — not pinned):
- `lefthook 2.1.6` (latest 2.1 branch, released 2026-Q1 per GitHub releases). `[CITED: github.com/evilmartians/lefthook/releases]`
- Schema change between 2.0 → 2.1: `skip:` moved from array-of-strings at top level to object/per-hook. Array-form still valid **under a hook** (`pre-commit.skip: [merge, rebase]`), rejected **at top level**. `[VERIFIED: lefthook validate on /tmp/test_lh.yml and /tmp/test_lh2.yml, 2026-04-22]`

### Alternatives Considered

| Instead of | Could Use | Why Rejected |
|------------|-----------|--------------|
| lefthook | Husky, pre-commit (Python), Lefthook 1.x | PROJECT.md L150 "lefthook only", kill-policy. |
| stdlib regex | tree-sitter-dart, tree-sitter-python | CONTEXT D-05, D-09 regex-first. AST = dep + complexity + 5× slower. |
| Python json | pub:intl Dart ARB parser | CONTEXT D-14 "Pas de dep ICU/intl (Python natif)". |
| commit-msg hook | post-commit hook | CONTEXT D-04 "Pas de commit-msg dans cette phase". **Research nuance below — GUARD-06 D-17 is not implementable pre-commit, needs one of these two.** |

---

## Architecture Patterns

### Recommended Project Structure (no changes from skeleton)

```
lefthook.yml                          # Single config at root (D-01)
tools/checks/
├── accent_lint_fr.py                 # EXISTS — activate (GUARD-04)
├── no_hardcoded_fr.py                # EXISTS — tighten (GUARD-03)
├── no_bare_catch.py                  # NEW (GUARD-02)
├── arb_parity.py                     # NEW (GUARD-05)
├── proof_of_read.py                  # NEW (GUARD-06)
├── lefthook_self_test.sh             # EXISTS — extend (D-25)
├── lefthook_benchmark.sh             # NEW (D-26)
├── memory_retention.py               # EXISTS (skeleton, keep)
├── map_freshness_hint.py             # EXISTS (skeleton, keep)
└── fixtures/                         # NEW — self-test inputs
    ├── no_bare_catch_fail.dart
    ├── no_bare_catch_pass.dart
    ├── no_bare_catch_fail.py
    ├── no_bare_catch_pass.py
    ├── no_hardcoded_fr_fail.dart
    ├── no_hardcoded_fr_pass.dart
    ├── accent_lint_fail.dart
    ├── accent_lint_pass.dart
    ├── arb_parity_fail/              # 6 ARB files with drift
    └── arb_parity_pass/              # 6 ARB files parity OK
tests/checks/
├── test_no_bare_catch.py             # NEW (pytest mirror of self-test)
├── test_no_hardcoded_fr.py           # NEW
├── test_arb_parity.py                # NEW
├── test_proof_of_read.py             # NEW
└── test_accent_lint_fr.py            # NEW (covers existing asset)
.github/workflows/
├── ci.yml                            # REMOVE 9 lint invocations (GUARD-08)
├── lefthook-ci.yml                   # NEW (D-24)
└── bypass-audit.yml                  # NEW (D-21)
CONTRIBUTING.md                       # NEW — LEFTHOOK_BYPASS doc (D-20, D-04)
```

### Pattern 1: lefthook.yml nested `skip` schema (CRITICAL — schema migration)

**Current (INVALID in 2.1.6):**
```yaml
# lefthook.yml — skeleton shipped in 30.5-02
pre-commit:
  parallel: false
  commands:
    memory-retention-gate:
      run: python3 tools/checks/memory_retention.py

skip:                    # ❌ Top-level `skip:` rejected by lefthook validate
  - merge
  - rebase
```

Running `lefthook validate` today:
```
skip: Value is array but should be object
│  Error: validation failed for main config
```

Yet `lefthook dump` parses it (the parser is more lenient than the validator). **`lefthook run pre-commit` works today** — but the `validate` error means any tooling that requires strict validation (e.g. CI validation steps) will fail.

**Valid for 2.1.6:**
```yaml
# Source: lefthook 2.1 docs + empirical test on /tmp/test_lh.yml, 2026-04-22
min_version: 2.1.5

pre-commit:
  parallel: true
  skip:                  # ✅ `skip:` nested under the hook — array form OK
    - merge
    - rebase
  commands:
    memory-retention-gate:
      run: python3 tools/checks/memory_retention.py
      tags: [memory]

commit-msg:
  commands:
    proof-of-read:
      run: python3 tools/checks/proof_of_read.py --commit-msg-file {1}
      tags: [agents]
```

**Action for Wave 0:** migrate `skip:` into `pre-commit:` block **before** adding the 5 new commands. Without this, any CI `lefthook validate` step in `lefthook-ci.yml` (D-24) will fail spuriously.

### Pattern 2: diff-only parsing for GUARD-02 (the critical technical unknown)

**Empirically verified stdlib-only approach** — no `python-unidiff` dep.

```python
# Source: verified /tmp/gittest empirical test 2026-04-22
# State machine extracts only-added lines + new-file line numbers.
import subprocess, re, sys

def get_added_lines(file_path: str) -> list[tuple[int, str]]:
    """Return (new_line_number, content) for lines ADDED in the staged diff.

    Deletions are ignored. Pure context lines don't appear under --unified=0.
    Empty diff → empty list (file staged but unchanged content-wise, e.g. rename).
    New file → all lines returned with line numbers 1, 2, 3...
    """
    result = subprocess.run(
        ['git', 'diff', '--staged', '--unified=0', '--', file_path],
        capture_output=True, text=True, check=False,
    )
    added: list[tuple[int, str]] = []
    cur_new: int | None = None
    HUNK = re.compile(r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@')
    for line in result.stdout.splitlines():
        m = HUNK.match(line)
        if m:
            cur_new = int(m.group(1))
            continue
        if cur_new is None:
            continue
        # `--- a/...`, `+++ b/...`, `diff --git`, `index ...` — skip headers
        if line.startswith('+++') or line.startswith('---'):
            continue
        if line.startswith('+'):
            added.append((cur_new, line[1:]))
            cur_new += 1
        elif line.startswith('-'):
            # deletion — no line-number advance on the new side
            continue
        elif line.startswith('\\'):
            # "\ No newline at end of file"
            continue
        else:
            # under --unified=0, no context lines inside hunks — unreachable
            cur_new += 1
    return added
```

**Edge cases confirmed:**

| Scenario | Behaviour | Verified |
|----------|-----------|----------|
| New file added | Hunk header `@@ -0,0 +1,N @@` → all N lines returned starting at 1 | ✅ /tmp/gittest |
| Middle-of-file addition | Hunk header `@@ -5,0 +6,3 @@ context` → lines at 6, 7, 8 | ✅ /tmp/gittest |
| Pure deletion hunk | Hunk header `@@ -X,Y +Z,0 @@` → `cur_new = Z`, but no `+` lines | Safe (no additions recorded) |
| File rename | `git diff --staged` shows `rename from ... to ...`; no added-line hunks unless content diff | Should be ignored (no `+` lines) |
| Binary file | `git diff --staged --unified=0` outputs `Binary files differ` | No hunk headers — parser returns `[]` |
| `--no-renames` needed? | Default `diff.renames=true` can hide content changes in a rename as a pure rename | Use `git diff --staged --unified=0 --no-renames` to force full diff; safer |

**Recommended invocation in `no_bare_catch.py`:**

```bash
git diff --staged --unified=0 --no-renames --diff-filter=AM -- '*.dart' '*.py'
```

- `--no-renames` → don't collapse moves into pure renames
- `--diff-filter=AM` → only Added and Modified files (skip Deleted, since bare-catch in deleted file = already fixed)
- Pathspec `-- '*.dart' '*.py'` → let git do the glob filtering before Python sees the output

### Pattern 3: bare-catch regex library (Dart + Python)

**Dart patterns (5 variants observed in mobile/lib):**

```python
# Source: Dart language spec + repo grep 2026-04-22 (32 occurrences across 5 provider files sampled)
DART_BARE_CATCH_PATTERNS = [
    # Empty bare-catch
    re.compile(r'}\s*catch\s*\(\s*(?:e|_|err|error)\s*\)\s*\{\s*\}'),
    # Catch-only-swallow: `catch (e) { /* comment only */ }`
    re.compile(r'}\s*catch\s*\(\s*(?:e|_|err)\s*\)\s*\{\s*(?://[^\n]*\s*)*\}'),
    # Silent on_type_rethrow_missing: `on XException catch (e) {}`
    re.compile(r'on\s+\w+\s+catch\s*\(\s*(?:e|_|err)\s*\)\s*\{\s*\}'),
]

DART_LOGGING_TOKENS = (
    'Sentry.captureException', 'Sentry.captureMessage', 'SentryBreadcrumb',
    'debugPrint(', 'print(',  # print( is dev-only but counts as non-silent
    'log(', 'logger.',
    'rethrow', 'throw',
    'FirebaseCrashlytics',
)
```

**Python patterns (6 observed in backend sample):**

```python
# Source: PEP 343 / PEP 654 + Pylint W0702/W0703 + repo grep 2026-04-22
PY_BARE_EXCEPT_PATTERNS = [
    re.compile(r'^\s*except\s*:\s*$', re.MULTILINE),                      # bare except: (W0702)
    re.compile(r'^\s*except\s+Exception\s*:\s*$', re.MULTILINE),          # broad except Exception: (W0703)
    re.compile(r'^\s*except\s+BaseException\s*:\s*$', re.MULTILINE),
    # Silent-pass variants
    re.compile(r'except\s*:\s*\n\s*pass\s*$', re.MULTILINE),
    re.compile(r'except\s+Exception\s*:\s*\n\s*pass\s*$', re.MULTILINE),
]

PY_LOGGING_TOKENS = (
    'logger.', 'logging.', 'log.',
    'sentry_sdk.capture', 'sentry_sdk.push_scope',
    'raise',
    'print(',  # dev-only but acceptable here
)
```

**Rule:** a `try/except` is ACCEPTABLE if **within 5 lines after the `except` header, at least one logging token or `raise` appears**, OR the line has an inline override comment `# lefthook-allow:bare-catch: <reason>` / `// lefthook-allow:bare-catch: <reason>`.

**Proven prior art:**
- ESLint `no-empty-catch` rule (plugin `eslint-plugin-no-empty-catch`) — similar heuristic for JS. `[CITED: eslint.org/docs/rules/no-empty-catch]`
- Pylint W0702 (bare-except), W0703 (broad-except) — comparable defaults. `[CITED: pylint.pycqa.org/en/latest/user_guide/messages/warning/bare-except.html]`
- flake8-bugbear B902 — Python equivalent to no-empty-catch. `[CITED: github.com/PyCQA/flake8-bugbear]`

### Pattern 4: ARB parity check (GUARD-05)

**Observed baseline (`/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/l10n/` as of 2026-04-22):**

| Lang | Non-`@` keys | `@key` metadata | File lines | Notes |
|------|--------------|------------------|------------|-------|
| fr   | 6707 | 796 (569 w/ placeholders) | 11882 | Template (per `l10n.yaml: template-arb-file: app_fr.arb`) |
| en   | 6707 | 643 (485 w/ placeholders) | 11091 | |
| de   | 6707 | 643 (485 w/ placeholders) | 11091 | |
| es   | 6707 | 643 (485 w/ placeholders) | 11091 | |
| it   | 6707 | 643 (485 w/ placeholders) | 11091 | |
| pt   | 6707 | 643 (485 w/ placeholders) | 11091 | |

**Key parity: PASS today (union = 6707, 0 missing, 0 extra everywhere). `[VERIFIED: python3 json.load() 2026-04-22]`**

**@key asymmetry explained:** FR is the Flutter template — by convention, `@key` metadata (description, placeholder types, examples) lives only in the template. Non-template languages need only translate `key: "value"`. The 84 extra FR `@keys` are metadata-only, with both the `key` value and its translation existing in the 5 other languages. `[VERIFIED: sampled 5 FR-only @keys like @anticipation3aDeadlineFact — value translations exist in en/de/es/it/pt]`

**Implications for `arb_parity.py`:**

1. **Non-`@` key parity:** straightforward set equality across the 6 languages.
2. **Placeholder parity:** FR is the source-of-truth. For each FR `@key` with `placeholders`, the `key`'s *value* in FR MUST contain ICU tokens `{name}` matching each placeholder name; EACH non-template language's `key` value MUST ALSO contain the same ICU placeholder names (order-insensitive).
3. **Type parity:** FR declares `{name: {type: "String"}}`; other langs don't re-declare. The lint can *only* verify placeholder *name presence* in other langs, not type (no metadata to compare). This matches CONTEXT D-14 pragma.

### ICU placeholder syntax to parse (`[CITED: flutter.dev/ui/internationalization]`)

| Form | Example | What to extract |
|------|---------|-----------------|
| Simple | `{name}` | placeholder name `name` |
| Typed | `{count, number}` → `{count, number, compactLong}` | placeholder name `count` (type part ignored for parity check) |
| Plural | `{count, plural, zero {...} one {...} other {...}}` | placeholder name `count` |
| Select | `{sex, select, male {il} female {elle} other {iel}}` | placeholder name `sex` |
| DateTime | `{timestamp, DateTime, yMd}` | placeholder name `timestamp` |

**Regex extraction (stdlib):**

```python
# Source: ICU MessageFormat spec (icu.unicode.org/userguide/format_parse/messages) + Flutter docs
# Captures the NAME only — the first bare-word token inside {...}.
# Nested braces (plural/select) are handled by non-greedy + balanced matching.
ICU_PLACEHOLDER_NAME = re.compile(r'\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:[},]|\s)', re.UNICODE)

def extract_placeholder_names(value: str) -> set[str]:
    """Return the set of placeholder names referenced in an ARB value string.

    Handles simple {name}, typed {name, number}, plural {n, plural, ...},
    select {sex, select, ...}. Ignores the ICU type keywords (number, plural,
    select, DateTime) — only the leading identifier is the placeholder name.
    """
    ICU_KEYWORDS = {'plural', 'select', 'number', 'DateTime', 'date', 'time', 'ordinal'}
    names: set[str] = set()
    for m in ICU_PLACEHOLDER_NAME.finditer(value):
        token = m.group(1)
        if token in ICU_KEYWORDS:
            continue
        names.add(token)
    return names
```

**Parity rule:**
- For each FR `@key` with `placeholders = {p1: ..., p2: ...}`:
- Extract FR `key` value → expected placeholder-name set `{p1, p2}`
- For each of 5 other languages: extract `key` value's placeholder names → must equal expected set
- Any divergence → `FAIL: key 'xxx' placeholder mismatch: expected {p1,p2}, got {p1} in app_de.arb`

### Pattern 5: commit-msg hook for GUARD-06 (CONTEXT D-04 nuance)

**The timing problem:**

| Hook | Fires | `$GIT_COMMIT_MSG` available? |
|------|-------|------------------------------|
| `prepare-commit-msg` | Before editor opens | No (message not yet written) |
| `commit-msg` | After editor close, before commit finalised | **YES via `$1` = .git/COMMIT_EDITMSG** |
| `pre-commit` | Before message typed | No |
| `post-commit` | After commit written | `git log -1 --format=%B HEAD` works but commit already exists |

CONTEXT D-04 says "Pas de `commit-msg`". But D-17 describes a check that REQUIRES access to the commit message, which pre-commit does not have.

**Three viable resolutions (recommend option A to the planner):**

- **Option A — minor D-04 amendment:** add one `commit-msg:` block to lefthook.yml with a single command (`proof-of-read`). Keeps spirit of D-04 ("no complex commit-msg machinery") while enabling D-17. Lefthook supports this cleanly. `[CITED: github.com/evilmartians/lefthook/blob/master/docs/examples/commitlint.html]`
- **Option B — post-commit with amend recovery:** run in `post-commit`, on failure print "commit kept but proof-of-read missing — amend with `git commit --amend` and add `Read:` trailer". Less friction but weaker gate.
- **Option C — pre-commit with environment sniffing:** detect whether `COMMIT_EDITMSG` already has content (amend path, `-m` flag with non-interactive), else soft-warn. Least reliable.

**Recommendation: Option A.** The strictest interpretation of D-04 forbids `commit-msg`, but D-17 is unimplementable otherwise. The planner should surface this as a discussion point or accept Option A as a minor D-04 refinement. Lefthook config:

```yaml
commit-msg:
  commands:
    proof-of-read:
      # {1} is lefthook's placeholder for .git/COMMIT_EDITMSG
      run: python3 tools/checks/proof_of_read.py --commit-msg-file {1}
      tags: [agents, safety]
```

Inside `proof_of_read.py`:
```python
# Source: git-scm.com/docs/githooks#_commit_msg
# COMMIT_EDITMSG is the path passed as $1 / {1}
msg = Path(args.commit_msg_file).read_text(encoding='utf-8')
has_claude = bool(re.search(r'^Co-Authored-By:\s+Claude', msg, re.MULTILINE))
if not has_claude:
    return 0  # Human commit — bypass (D-17)
match = re.search(r'^Read:\s+(\S+)', msg, re.MULTILINE)
if not match:
    print('proof_of_read: FAIL — Claude commit missing `Read:` trailer', file=sys.stderr)
    return 1
read_path = Path(match.group(1).strip())
if not read_path.exists():
    print(f'proof_of_read: FAIL — referenced READ.md does not exist: {read_path}', file=sys.stderr)
    return 1
return 0
```

### Pattern 6: parallel mode pitfalls (CONTEXT D-02)

30.5 D-04 specifically notes `parallel: false until phase 34 — race conditions on .git/index.lock`. Research finding: **this caveat is mostly about git commands that *write* to the index**. All 5 new Phase 34 lints are **read-only** (git diff + file reads + regex). Safe to parallelise.

**Safe-parallel rule:**

| Command type | Parallel-safe? | Notes |
|--------------|----------------|-------|
| read-only lint (file content + regex) | ✅ | Phase 34's 5 lints |
| `git diff --staged` (read-only) | ✅ | used by diff-only parser |
| `git add <file>` after auto-fix | ❌ | race on `.git/index.lock` — must be sequential |
| `git stash` / `git checkout` | ❌ | rewrites working tree |
| lefthook `stage_fixed: true` | Use with care | lefthook serialises these internally, but we don't need this for Phase 34 (all lints are pure read) |

**All 5 Phase 34 lints must NOT write to the index.** They emit diagnostics to stderr and exit 0/1. Safe to run with `parallel: true`.

**Lefthook 2.1.x parallel model** `[CITED: github.com/evilmartians/lefthook docs/configuration/parallel.md]`:
- `parallel: true` in a hook → commands run concurrently via goroutines.
- lefthook does NOT serialise stderr — interleaved output is possible. Each command should include a stable prefix (e.g. `[no_bare_catch] `) so humans can sort output.
- Exit code = max of all command exit codes (any fail → hook fails).

### Anti-Patterns to Avoid

- **Running each lint on the full repo.** Scope via `glob:` per command (D-03). Example: `glob: "apps/mobile/lib/widgets/**/*.dart"` for `no_hardcoded_fr`.
- **Writing to `.git/index.lock` from a parallel command.** Forbidden; all 5 Phase 34 lints are read-only.
- **Writing emoji to hook stderr.** CLAUDE.md: `Only use emojis if the user explicitly requests it. Avoid writing emojis to files unless asked.` — lint output goes to stderr but is still "writing" in spirit. Use ASCII `FAIL` / `OK` / `[info]` prefixes matching `route_registry_parity.py`.
- **Re-implementing accent pattern list.** GUARD-04 MUST reuse `tools/checks/accent_lint_fr.py`'s `PATTERNS` list (D-11). If the MCP tool `check_accent_patterns` is invoked instead, it already re-exports the same list — no drift risk.
- **Putting French text in lint stderr messages.** Per CLAUDE.md §2, any FR error message is subject to the accent check itself (self-regression risk). Keep error messages technical English.
- **Using `git log -1 --format=%B HEAD` in a pre-commit hook to read the commit message.** At pre-commit time, the "last commit" is the PREVIOUS commit, not the one being made. Use `commit-msg` hook + `$1` placeholder (Pattern 5).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| git hook installer per-developer | bash script writing to `.git/hooks/*` | `lefthook install` | 30.5 skeleton locked in `brew install lefthook`. |
| diff hunk parser | full RFC-3284 unified-diff lib | stdlib `re` + state machine (Pattern 2) | Verified 15-line solution; zero dep. |
| ARB keyset diff | yaml-merge / jq | `json.load()` + `set()` ops | CONTEXT D-14 explicit: "Pas de dep ICU/intl (Python natif)". |
| ICU placeholder AST | intl_translation pub package / pyicu | Pattern 4 regex | GUARD-05 scope is name-parity, not full ICU validation. |
| Dart AST walker | tree-sitter-dart / dart_style | regex (Pattern 3) | CONTEXT D-05 regex-first, dev experience + zero dep trumps precision. |
| Parallel hook scheduler | GNU parallel in bash | lefthook `parallel: true` | lefthook's goroutine pool + exit code aggregation. |
| Weekly audit scheduler | cron on dev host | GitHub Actions `schedule: - cron:` in `bypass-audit.yml` | CI already solved this problem (see existing `.github/workflows/sync-branches.yml`). |

**Key insight:** **lefthook and git itself do 90% of the work.** The 5 lint scripts are each <150 lines of stdlib Python. Complexity lives in the YAML wiring and the test fixtures, not the lint internals.

---

## Existing Asset Audit (what's already shipped)

### Already live — reuse as-is

| Path | State | Phase 34 action |
|------|-------|-----------------|
| `lefthook.yml` | 2 commands (memory-retention-gate, map-freshness-hint) skeleton from 30.5 | **EXTEND** (D-01). Fix top-level `skip:` schema + add 5 new commands + enable `parallel: true`. |
| `tools/checks/accent_lint_fr.py` | 15 patterns (1 extra vs CLAUDE.md §2: `specialistes/gerer/progres` on top of the 14 listed) | **ACTIVATE** via lefthook glob. Reconcile pattern list with CLAUDE.md §2 — add `prevoyance/reperer/cle`, remove or keep extras. |
| `tools/checks/no_hardcoded_fr.py` | Early-ship from Phase 30.5 CTX-02 | **TIGHTEN** — add scope restriction per D-08 (widgets/screens/features only), add `// lefthook-allow:hardcoded-fr:` inline override per D-10, sharpen patterns per D-09. |
| `tools/checks/memory_retention.py` | Wired in skeleton | **PRESERVE** (D-01, D-23 line). Keep as-is. |
| `tools/checks/map_freshness_hint.py` | Hint, always exits 0 | **PRESERVE**. Hard-gate promotion is deferred per D-04 "pas de commit-msg" spirit. |
| `tools/checks/route_registry_parity.py` | Phase 32, wired in CI only | **ADD LEFTHOOK WIRING** (D-23). CI line 448 stays via `lefthook-ci.yml` (D-24) but primary gate moves to pre-commit. |
| `tools/checks/lefthook_self_test.sh` | Single-fixture smoke from 30.5 | **EXTEND** — add 5 FAIL + 5 PASS fixtures per D-25. |

### Brand new — write from scratch

| Path | Purpose | Est LOC |
|------|---------|---------|
| `tools/checks/no_bare_catch.py` | GUARD-02 — regex + diff-only parser | ~180 |
| `tools/checks/arb_parity.py` | GUARD-05 — key + placeholder parity | ~150 |
| `tools/checks/proof_of_read.py` | GUARD-06 — commit-msg trailer check | ~80 |
| `tools/checks/lefthook_benchmark.sh` | D-26 — P95 timer | ~60 |
| `tests/checks/test_no_bare_catch.py` | pytest mirror | ~120 |
| `tests/checks/test_no_hardcoded_fr.py` | pytest mirror | ~80 |
| `tests/checks/test_arb_parity.py` | pytest mirror | ~100 |
| `tests/checks/test_proof_of_read.py` | pytest mirror | ~60 |
| `tests/checks/test_accent_lint_fr.py` | cover existing asset | ~60 |
| `tests/checks/fixtures/*` | 10+ fixture files | ~200 total |
| `.github/workflows/lefthook-ci.yml` | D-24 | ~40 |
| `.github/workflows/bypass-audit.yml` | D-21 | ~60 |
| `CONTRIBUTING.md` | D-20, D-04 docs | ~80 |
| `tools/checks/route_registry_parity-KNOWN-MISSES.md` | already exists — no change | 0 |

**Total new code:** ~1200 LOC + config, all stdlib. Self-contained, reviewable per-script.

---

## Runtime State Inventory

> Phase 34 is dev-tooling — no user data or service state. Inventory below for completeness.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | None — no user data touched by Phase 34. | None. |
| Live service config | None — lefthook config lives in git, no external service with UI-only state. | None. |
| OS-registered state | `git config core.hooksPath = .lefthook/_hooks` (installed by `lefthook install`) — per-clone, idempotent. | Document `lefthook install` as a CONTRIBUTING step (already in D-04). |
| Secrets/env vars | None added. `SENTRY_AUTH_TOKEN` (existing, Phase 31/32) unused by Phase 34. | None. |
| Build artifacts | None — Python stdlib lints are interpreted, no egg-info / compiled output. | None. |

**After every file in the repo is updated, what runtime systems still have the old string cached?** — Nothing. Phase 34 is additive (new files) + one `lefthook.yml` schema fix. No rename in scope.

**Note on iCloud duplicates:** `tools/checks/` contains `accent_lint_fr 2.py`, `no_hardcoded_fr 2.py`, `route_registry_parity 2.py` / `3.py`, etc. — iCloud Drive sync artifacts. CONTEXT explicitly defers cleanup (line 137-138). Phase 34 plans should **check-in new files with the single canonical name** and NOT re-sync duplicates. Use `.gitignore` rule `*\ 2.py` / `*\ 3.py` if agents accidentally commit duplicates — **but verify this doesn't hide a real `file 2.py` somewhere; safer to git-check each commit**.

---

## Common Pitfalls

### Pitfall 1: `lefthook validate` fails silently on top-level `skip:`
**What goes wrong:** Current `lefthook.yml` (shipped 30.5) has `skip:` at top level with array form. `lefthook validate` exits non-zero today. `lefthook run pre-commit` still works (parser is lenient), so the bug is invisible until someone adds a CI `validate` step (D-24 `lefthook-ci.yml` is a likely trigger).
**Why it happens:** lefthook 2.0 changed the `skip` schema. Top-level `skip` must be an object (e.g. `skip: { ref: main }`), not an array. Array form `[merge, rebase]` is valid only under a hook block.
**How to avoid:** Wave 0 first commit: migrate `skip: [merge, rebase]` → nested under `pre-commit:` and `commit-msg:` (both need it).
**Warning signs:** `lefthook validate` → `skip: Value is array but should be object`.
**Verified:** `/tmp/test_lh.yml` empirical test 2026-04-22.

### Pitfall 2: GUARD-02 scanning full file instead of diff
**What goes wrong:** Lint scans full staged file content → flags 388 existing bare-catches → every commit fails → team disables GUARD-02 → Phase 34 ships dead.
**Why it happens:** Temptation to do `python3 no_bare_catch.py path/to/file.dart` scans the whole file, not just the staged delta. This is easier but wrong per D-07.
**How to avoid:** Lint input MUST be `git diff --staged --unified=0 --no-renames -- '*.dart' '*.py'`, parsed with Pattern 2's state machine. Each added line is tested against regexes; matched lines fail. Unmodified lines ignored.
**Warning signs:** Lint reports more violations than the diff has added lines.
**Test:** Wave 0 self-test fixture where a known-bad bare-catch exists in the file from a previous commit BUT only a non-catch line is added → lint MUST exit 0.

### Pitfall 3: ICU placeholder parsing gets confused by nested braces
**What goes wrong:** `{count, plural, =0 {none} one {1 item} other {# items}}` — a naive brace-matching regex extracts `count`, `none`, `one`, `items` as placeholders. Adds false parity failures.
**Why it happens:** ICU `plural`/`select` has nested braces. Plain `\{(\w+)\}` matches inside plural variants.
**How to avoid:** Pattern 4's regex `\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:[},]|\s)` captures only the FIRST identifier after a `{` and stops at `,`, `}`, or whitespace. ICU keywords (`plural`, `select`, `number`, `DateTime`, `date`, `time`, `ordinal`) are filtered out.
**Warning signs:** Parity lint reports placeholder names that are ICU keywords (`plural`, `number`) or inline literals (`none`, `items`).
**Test:** arb_parity fixtures MUST include a plural and a select example.

### Pitfall 4: proof-of-read hook bypasses human commits the wrong way
**What goes wrong:** Hook checks `Co-Authored-By: Claude` absence → exit 0. But Julien's own workflow sometimes includes `Co-Authored-By: Claude` (normal MINT commits via this session!). Real human commits without Claude are rare on MINT.
**Why it happens:** D-17 says "Humain (no Claude trailer) : bypass automatique". But on this project, nearly all commits have the Claude trailer (it's the collaboration model).
**How to avoid:** Read D-17 literally — the bypass is for commits WITHOUT the Claude trailer. On MINT, virtually every commit WILL have the trailer, so virtually every commit WILL be subject to the `Read:` check. This is the intended behaviour. The human bypass is a safety valve for rare non-Claude commits.
**Warning signs:** A legitimate MINT commit fails proof-of-read because it used Claude but didn't land a READ.md first. Mitigation: CONTRIBUTING.md documents that commits using Claude MUST list read files in a `READ.md` under `.planning/phases/<phase>/<padded>-READ.md`.
**Per CONTEXT D-18:** Format is a flat bullet list. `- <path> — <why read>`. No timestamp, no hash.

### Pitfall 5: parallel mode silent output interleaving
**What goes wrong:** 5 commands run in parallel. Each prints failures to stderr. Output gets interleaved line-by-line. Human can't figure out which lint failed which file.
**Why it happens:** lefthook doesn't buffer stderr per command (design choice for real-time feedback).
**How to avoid:** Every stderr line prefixed with lint name. Pattern: `[no_bare_catch] apps/mobile/lib/foo.dart:42: catch (e) {} — no log/rethrow`. Match existing `accent_lint_fr.py` style: `path:line: snippet (pattern)`.
**Warning signs:** Stack-traces or unlabeled failure lines mid-run.
**Remediation:** lefthook supports `output: [execution, summary]` to aggregate — but changes command-level buffering. For Phase 34, stick with line-prefix discipline; aggregation is v2.9 territory.

### Pitfall 6: bypass audit false negatives
**What goes wrong:** User runs `LEFTHOOK_BYPASS=1 git commit -m "quick fix"` — env var never touches the commit. `bypass-audit.yml` grep over commit bodies finds nothing. Audit says "0 bypasses this week" while we all know there were 5.
**Why it happens:** `LEFTHOOK_BYPASS=1` is runtime-only. The env var vanishes at process exit. The only signal it leaves is the absence of what lefthook would have written (which is nothing observable).
**How to avoid:** Rely on D-24's ground-truth mechanism: `lefthook-ci.yml` re-runs `lefthook run pre-commit --all-files --force` on PR range. **If a lint fails in CI that passed locally, the operator bypassed.** This is a 100% reliable detector of bypass-induced regressions — only misses bypasses that happen to not introduce regressions (harmless).
**The "weekly audit" mechanism D-21** is more of a culture signal than a hard gate. Optionally, it can parse commit bodies for:
  - Literal `LEFTHOOK_BYPASS` string (only works if operator mentions it in message — voluntary)
  - `[skip hooks]` or `[no-verify]` in commit subject — also voluntary
  - Number of lint-level reverts in the week (signal of cover-up bypasses)
**Warning signs:** Audit reports "0 bypasses" but CI catches regressions.
**Mitigation:** Plan should position D-24 (ground-truth CI re-run) as PRIMARY gate, D-21 (weekly grep audit) as SECONDARY awareness tool. Don't promise D-21 detects all bypasses.

### Pitfall 7: self-test fixture persistence across runs
**What goes wrong:** A fixture file in `tests/checks/fixtures/no_bare_catch_fail.dart` contains a bare-catch. When the repo's own lint runs over its own files, it flags the fixture → false positive.
**Why it happens:** Fixtures are part of the repo; lints don't know about the "this file is intentionally bad" intent.
**How to avoid:** Exclude fixtures via either: (a) `glob:` pattern excluding `tests/checks/fixtures/**`, (b) filename convention like `*_fixture.dart` + lint-level skip, or (c) inline `// lefthook-allow:bare-catch: fixture for self-test` (D-06). Recommend (a) at lefthook.yml level — simplest.
**Warning signs:** Self-test fixtures flagged by the real lint run.
**Precedent:** `tests/checks/fixtures/parity_drift.dart` already exists with the same problem; handled by not wiring `route_registry_parity.py` to a glob that covers it.

### Pitfall 8: CLAUDE.md accent regression from Phase 34 itself
**What goes wrong:** Agent writing new lints types `detecte`, `requete`, `proprete` without diacritics. Lint stderr messages contain ASCII-flattened FR. Next accent_lint_fr.py run against tools/checks/ flags the NEW scripts.
**Why it happens:** CLAUDE.md §2 is a hard rule — accents are bugs — but easy to forget when writing error messages for technical diagnostics.
**How to avoid:** All new lint stderr messages in **technical English** (explicit project convention, per Phase 32-03 M-1 carve-out for admin UI). File headers declare: `# Technical English only — dev-facing diagnostics. Per M-1 carve-out (admin discretion), no ARB i18n.`
**Warning signs:** `accent_lint_fr.py tools/checks/no_bare_catch.py` reports a violation.
**Test:** self-test fixture should include one clean-FR `.py` file and one ASCII-flattened `.py` file; lint must differentiate.

### Pitfall 9: `lefthook install` forgotten post-clone
**What goes wrong:** New contributor clones repo. `lefthook.yml` exists but `.git/hooks/pre-commit` is empty. First commit bypasses all lints. CI catches it (D-24 is the safety net) but local dev experience is broken.
**Why it happens:** `lefthook install` must run once per clone to register hooks in `.git/hooks/*`. No automatic trigger.
**How to avoid:** CONTRIBUTING.md (D-20) must state this as step 1. Additionally, `scripts/bootstrap.sh` (if it exists) should chain `lefthook install`. For Phase 34, documentation-only mitigation is fine.
**Warning signs:** `git commit` bypasses lefthook without `LEFTHOOK_BYPASS=1` or `--no-verify`.
**Test:** `lefthook check-install` — exit 0 = hooks installed, non-zero = missing.

### Pitfall 10: benchmark on cold cache misleads
**What goes wrong:** First run after clone: lefthook cold-compiles hook scripts, Python starts cold, file system caches empty. Time reported: 12s. Second run: 2.8s. If benchmark captures only first run, result is unfairly high.
**Why it happens:** macOS aggressive filesystem caching + Python import caching + lefthook config parsing.
**How to avoid:** `lefthook_benchmark.sh` (D-26) must run N=10 iterations, discard first 2 (warmup), report P95 of the remaining 8. Pattern:
```bash
for i in $(seq 1 10); do
  /usr/bin/time -p lefthook run pre-commit 2>>bench.log
done
# python3 -c 'import statistics, sys; nums=[float(l.split()[1]) for l in open("bench.log") if l.startswith("real")][2:]; print("P95:", sorted(nums)[int(len(nums)*0.95)])'
```
**Warning signs:** P95 >5s but P50 <3s → cold-start effect, not real latency.

---

## Code Examples

### Example 1: lefthook.yml Phase 34 full config (with schema migration)

```yaml
# Source: extended from 30.5 skeleton per D-01, schema-fixed per Pattern 1.
# Phase 34 GUARD-01..08. Preserves 30.5 commands verbatim (D-01 spirit).
min_version: 2.1.5

pre-commit:
  parallel: true                           # D-02
  skip:                                    # Pattern 1 schema — nested under hook
    - merge
    - rebase
  commands:
    # ─── Phase 30.5 commands (preserved per D-01) ─────────────────
    memory-retention-gate:
      run: python3 tools/checks/memory_retention.py
      tags: [memory]
    map-freshness-hint:
      run: python3 tools/checks/map_freshness_hint.py {staged_files}
      glob: "*.{dart,py}"
      tags: [map, agents]

    # ─── Phase 34 GUARD-02 (diff-only, D-07) ──────────────────────
    no-bare-catch:
      run: python3 tools/checks/no_bare_catch.py --staged
      glob: "*.{dart,py}"
      exclude:
        - "apps/mobile/test/**"
        - "apps/mobile/integration_test/**"
        - "services/backend/tests/**"
        - "tests/checks/fixtures/**"
      tags: [safety]

    # ─── Phase 34 GUARD-03 (scope-restricted, D-08) ───────────────
    no-hardcoded-fr:
      run: python3 tools/checks/no_hardcoded_fr.py {staged_files}
      glob: "apps/mobile/lib/{widgets,screens,features}/**/*.dart"
      tags: [i18n]

    # ─── Phase 34 GUARD-04 (activation, D-11) ─────────────────────
    accent-lint-fr:
      run: python3 tools/checks/accent_lint_fr.py --file {staged_files}
      glob: "*.{dart,py,arb}"               # per D-12
      exclude:
        - "apps/mobile/lib/l10n/app_en.arb"
        - "apps/mobile/lib/l10n/app_de.arb"
        - "apps/mobile/lib/l10n/app_es.arb"
        - "apps/mobile/lib/l10n/app_it.arb"
        - "apps/mobile/lib/l10n/app_pt.arb"
        - "tests/checks/fixtures/**"
      tags: [i18n]

    # ─── Phase 34 GUARD-05 (key + placeholder parity, D-14) ───────
    arb-parity:
      run: python3 tools/checks/arb_parity.py
      glob: "apps/mobile/lib/l10n/app_*.arb"
      tags: [i18n]

    # ─── Phase 34 route registry parity (migrated to lefthook-first per D-23) ──
    route-registry-parity:
      run: python3 tools/checks/route_registry_parity.py
      glob: "apps/mobile/lib/{app.dart,routes/route_metadata.dart}"
      tags: [maps]

    # ─── Phase 34 GUARD-08 migrations (lefthook-first, D-23) ──────
    no-chiffre-choc:
      run: python3 tools/checks/no_chiffre_choc.py
      glob: "*.{dart,py,arb,md}"
      tags: [safety]
    landing-no-numbers:
      run: python3 tools/checks/landing_no_numbers.py
      glob: "apps/mobile/lib/screens/landing/**/*.dart"
      tags: [safety]
    landing-no-financial-core:
      run: python3 tools/checks/landing_no_financial_core.py
      glob: "apps/mobile/lib/screens/landing/**/*.dart"
      tags: [safety]

commit-msg:                                # Pattern 5 — D-04 nuance needed
  commands:
    proof-of-read:                         # GUARD-06 per D-17
      run: python3 tools/checks/proof_of_read.py --commit-msg-file {1}
      tags: [agents, safety]
```

### Example 2: `no_bare_catch.py` skeleton (GUARD-02)

```python
#!/usr/bin/env python3
"""GUARD-02 — refuse added lines containing bare `catch (e) {}` Dart /
`except Exception:` Python with no log/rethrow.

Per CONTEXT D-07: scans ONLY the added lines of the staged diff, not the
full file content. This decouples Phase 34 from FIX-05 migration of 388
existing bare-catches (Phase 36 scope).

Per D-06: exempts test/integration_test/tests paths + `async *` generators
(Dart idiomatic) + inline override `// lefthook-allow:bare-catch: <reason>`
(reason must be >3 words).

Exit codes:
  0 — no bare-catch introduced by this diff
  1 — violation(s) found (stderr has path:line: snippet rows)

Technical English diagnostics — dev-facing. No user-facing strings, no ARB.
"""
from __future__ import annotations
import argparse, re, subprocess, sys
from pathlib import Path
from typing import List, Set, Tuple

# Patterns from Research Pattern 3
DART_BARE_CATCH = [
    re.compile(r'}\s*catch\s*\(\s*(?:e|_|err|error)\s*\)\s*\{\s*\}'),
    re.compile(r'on\s+\w+\s+catch\s*\(\s*(?:e|_|err)\s*\)\s*\{\s*\}'),
]
PY_BARE_EXCEPT = [
    re.compile(r'^\s*except\s*:\s*$'),
    re.compile(r'^\s*except\s+Exception\s*:\s*$'),
    re.compile(r'^\s*except\s+BaseException\s*:\s*$'),
]
DART_LOG_TOKENS = ('Sentry', 'debugPrint', 'print(', 'logger', 'rethrow', 'throw')
PY_LOG_TOKENS = ('logger.', 'logging.', 'log.', 'sentry_sdk', 'raise', 'print(')
OVERRIDE_DART = re.compile(r'//\s*lefthook-allow:bare-catch:\s*(\S+(?:\s+\S+){2,})')
OVERRIDE_PY = re.compile(r'#\s*lefthook-allow:bare-catch:\s*(\S+(?:\s+\S+){2,})')

def get_added_lines(file_path: Path) -> List[Tuple[int, str]]:
    # See Research Pattern 2 for full implementation
    ...

def scan_dart_added(lines: List[Tuple[int, str]], full_text: str) -> List[str]:
    violations = []
    for line_no, content in lines:
        if OVERRIDE_DART.search(content):
            continue
        for pat in DART_BARE_CATCH:
            if pat.search(content):
                # Context scan: does the catch body have a log/rethrow in the next 5 lines of full_text?
                # (Simplified — real implementation walks full_text around line_no)
                violations.append(f'{line_no}: {content.strip()[:120]}')
    return violations

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--staged', action='store_true', help='Use git diff --staged as input')
    ap.add_argument('--file', help='Scan a specific file (for self-test + CI fallback)')
    args = ap.parse_args()
    # ... git diff or single-file fallback
    # Exit 0 / 1 based on violations
    return 0

if __name__ == '__main__':
    sys.exit(main())
```

### Example 3: `arb_parity.py` core logic

```python
#!/usr/bin/env python3
"""GUARD-05 — ARB key + placeholder parity across 6 language files.

Per CONTEXT D-13, D-14: fail on any key-set divergence or ICU placeholder
name drift. Uses FR (app_fr.arb) as the template per Flutter convention
(see apps/mobile/l10n.yaml: template-arb-file: app_fr.arb).

Zero external deps — stdlib json + re.
"""
from __future__ import annotations
import json, re, sys
from pathlib import Path
from typing import Dict, Set, Tuple

LANGS = ['fr', 'en', 'de', 'es', 'it', 'pt']
L10N_DIR = Path(__file__).resolve().parents[2] / 'apps' / 'mobile' / 'lib' / 'l10n'

# Research Pattern 4 regex
ICU_NAME = re.compile(r'\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:[},]|\s)', re.UNICODE)
ICU_KEYWORDS = {'plural', 'select', 'number', 'DateTime', 'date', 'time', 'ordinal'}

def extract_placeholders(value: str) -> Set[str]:
    return {m.group(1) for m in ICU_NAME.finditer(value) if m.group(1) not in ICU_KEYWORDS}

def main() -> int:
    data: Dict[str, Dict] = {}
    for lang in LANGS:
        path = L10N_DIR / f'app_{lang}.arb'
        if not path.exists():
            print(f'[FAIL] arb_parity: missing file {path}', file=sys.stderr)
            return 1
        with path.open(encoding='utf-8') as f:
            data[lang] = json.load(f)

    # 1. Non-@ key parity (D-13)
    keysets = {lang: {k for k in d if not k.startswith('@')} for lang, d in data.items()}
    union = set().union(*keysets.values())
    fail = False
    for lang, ks in keysets.items():
        missing = union - ks
        if missing:
            for k in sorted(missing)[:10]:
                print(f"[FAIL] arb_parity: key '{k}' missing in app_{lang}.arb", file=sys.stderr)
            if len(missing) > 10:
                print(f"  ... and {len(missing) - 10} more", file=sys.stderr)
            fail = True

    # 2. Placeholder parity — FR template is source of truth
    fr = data['fr']
    for at_key, meta in fr.items():
        if not at_key.startswith('@') or not isinstance(meta, dict):
            continue
        phs = meta.get('placeholders')
        if not phs:
            continue
        plain_key = at_key[1:]
        expected = set(phs.keys())
        for lang in LANGS:
            value = data[lang].get(plain_key)
            if not value:
                continue  # key-missing already flagged above
            actual = extract_placeholders(value)
            if actual != expected:
                missing_ph = expected - actual
                extra_ph = actual - expected
                msg = f"[FAIL] arb_parity: key '{plain_key}' placeholder drift in app_{lang}.arb"
                if missing_ph: msg += f' missing={sorted(missing_ph)}'
                if extra_ph: msg += f' extra={sorted(extra_ph)}'
                print(msg, file=sys.stderr)
                fail = True

    if fail:
        return 1
    print('[OK] arb_parity: 6 ARB files parity OK (keys + placeholders)')
    return 0

if __name__ == '__main__':
    sys.exit(main())
```

### Example 4: `proof_of_read.py` (commit-msg hook) skeleton

```python
#!/usr/bin/env python3
"""GUARD-06 — fallback proof-of-read. Agent co-author commits must reference
a `.planning/phases/<phase>/<padded>-READ.md` file listing files read.

Per CONTEXT D-16, D-17: runs on `commit-msg` hook, receives COMMIT_EDITMSG
path via {1}. Pass-through for non-Claude commits (D-17 "bypass auto humain").
"""
from __future__ import annotations
import argparse, re, sys
from pathlib import Path

TRAILER_CLAUDE = re.compile(r'^Co-Authored-By:\s+Claude', re.MULTILINE)
TRAILER_READ = re.compile(r'^Read:\s+(\S+)\s*$', re.MULTILINE)

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--commit-msg-file', required=True, help='.git/COMMIT_EDITMSG path (lefthook {1})')
    args = ap.parse_args()
    msg = Path(args.commit_msg_file).read_text(encoding='utf-8', errors='ignore')

    if not TRAILER_CLAUDE.search(msg):
        return 0  # Human commit — bypass per D-17

    m = TRAILER_READ.search(msg)
    if not m:
        print('[FAIL] proof_of_read: Claude-coauthored commit missing `Read:` trailer.', file=sys.stderr)
        print('  Required format: `Read: .planning/phases/<phase>/<padded>-READ.md`', file=sys.stderr)
        print('  Per CONTEXT 34-CONTEXT.md D-16.', file=sys.stderr)
        return 1

    read_path = Path(m.group(1).strip())
    if not read_path.exists():
        print(f'[FAIL] proof_of_read: READ.md referenced but not on disk: {read_path}', file=sys.stderr)
        return 1

    # D-18: format check — must be a flat bullet list with `- <path> — <why>`
    content = read_path.read_text(encoding='utf-8', errors='ignore')
    if not any(line.strip().startswith('- ') for line in content.splitlines()):
        print(f'[FAIL] proof_of_read: {read_path} has no bullet entries (D-18 format).', file=sys.stderr)
        return 1

    print(f'[OK] proof_of_read: Claude commit references {read_path} ({sum(1 for l in content.splitlines() if l.strip().startswith("- "))} files)')
    return 0

if __name__ == '__main__':
    sys.exit(main())
```

### Example 5: `bypass-audit.yml` skeleton

```yaml
# Source: D-21. Weekly + post-merge audit. D-22 threshold = 3/week.
name: Bypass audit (GUARD-07)

on:
  schedule:
    - cron: '0 9 * * 1'   # Monday 09:00 UTC per D-21
  push:
    branches: [dev]

jobs:
  audit:
    name: Count bypass signals in last 7 days
    runs-on: ubuntu-latest
    permissions:
      contents: read
      issues: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0   # need full log for git log --since
      - name: Count LEFTHOOK_BYPASS references in commit bodies
        id: count
        run: |
          # D-21: grep `LEFTHOOK_BYPASS=1` in commit bodies (voluntary signal)
          count=$(git log --since="7 days ago" --pretty=%B origin/dev | grep -c 'LEFTHOOK_BYPASS' || true)
          echo "count=$count" >> "$GITHUB_OUTPUT"
          echo "Found $count LEFTHOOK_BYPASS references on dev (7d window)"
      - name: Create issue if threshold exceeded
        if: steps.count.outputs.count > 3   # D-22
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `bypass-audit: ${{ steps.count.outputs.count }} LEFTHOOK_BYPASS this week`,
              labels: ['bypass-audit'],
              body: `Weekly audit detected **${{ steps.count.outputs.count }} commits** with LEFTHOOK_BYPASS references on dev in the last 7 days (threshold=3 per CONTEXT D-22).\n\nManual review: \`git log --since="7 days ago" --grep="LEFTHOOK_BYPASS" origin/dev\``
            });
```

### Example 6: `lefthook-ci.yml` (D-24 double-run)

```yaml
# Source: D-24. Ground-truth audit — catches every bypass whose effect
# introduces a regression the lints would have caught.
name: Lefthook CI (GUARD-07 D-24)

on:
  pull_request:
    branches: [dev, staging, main]

jobs:
  lefthook-all:
    name: Re-run lefthook on PR range
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - name: Install lefthook
        run: |
          curl -sSLf https://raw.githubusercontent.com/evilmartians/lefthook/master/install.sh | sh -s -- -b $HOME/.local/bin
          echo "$HOME/.local/bin" >> $GITHUB_PATH
      - name: Validate lefthook.yml
        run: lefthook validate
      - name: Run pre-commit hooks over PR range
        # --all-files: force a full-repo pass to catch bypass-introduced state.
        # --force: don't skip when lefthook thinks files haven't changed.
        run: lefthook run pre-commit --all-files --force
      - name: Run commit-msg hook against each new commit
        run: |
          git log --format=%H origin/${{ github.base_ref }}..HEAD | while read sha; do
            git log -1 --format=%B "$sha" > /tmp/msg.txt
            lefthook run commit-msg --file /tmp/msg.txt || { echo "::error sha=$sha::commit-msg check failed"; exit 1; }
          done
```

---

## State of the Art

| Old Approach | Current Approach (Phase 34) | Impact |
|--------------|------------------------------|--------|
| CI-only gates (all 10 `tools/checks/*.py` on every push) | Lefthook-first pre-commit + CI re-run on PR only | ~2 min CI reduction + <5s local feedback (vs. 2-5 min CI wait) |
| `--no-verify` ad-hoc | `LEFTHOOK_BYPASS=1` grep-able + weekly audit | Audit trail for bypass culture |
| Full-file lint (flags all 388 existing bare-catches on every commit) | Diff-only lint (flags only added lines) | GUARD-02 can ship without waiting on Phase 36 FIX-05 |
| Manual accent/hardcoded-FR review at PR | Mechanical pre-commit block | Zero-regression guarantee on merge |

**Deprecated/outdated patterns:**
- **Git `core.hooksPath` = custom shell scripts**: replaced by `lefthook install` writing goroutine-dispatched runners.
- **Pre-commit (Python framework)**: kill-policy-excluded (PROJECT.md L150).
- **`--no-verify` as normal workflow**: forbidden per D-20. Not mechanically blocked (git gives users the option) — replaced by convention + audit.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| lefthook | GUARD-01 | ✅ | 2.1.6 (`brew`) | — (blocking; Wave 0 must check `lefthook check-install`) |
| python3 | all 5 lints | ✅ | 3.9.6 local, 3.11 CI | — |
| git | all lints + bypass-audit | ✅ | 2.x | — |
| gh CLI | bypass-audit issue creation | ✅ (dev host) | GitHub Actions native has `actions/github-script@v7` | actions/github-script fallback on CI |
| pytest | tests/checks/ | ✅ | via `pip install pytest` (CI) | — |
| bash | lefthook_self_test.sh + lefthook_benchmark.sh | ✅ | — | — |
| coreutils `gtimeout` | benchmark script | Optional | installed (phase 31 walker.sh) | bare `timeout` fallback already implemented in walker.sh (mimic pattern) |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** `gtimeout` (fallback: bare `timeout` or skip with WARN, same pattern as `walker.sh`).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | pytest (Python 3.9+) for lint unit tests + bash for lefthook smoke/benchmark |
| Config file | `services/backend/pytest.ini` (backend) — reuse `[tool:pytest]` settings; **no** pytest config exists at repo root for `tests/checks/` today |
| Quick run command | `python3 -m pytest tests/checks/ -q` |
| Full suite command | `python3 -m pytest tests/checks/ tests/tools/ -q && bash tools/checks/lefthook_self_test.sh && bash tools/checks/lefthook_benchmark.sh` |

**Wave 0 gap:** `tests/checks/` has no `conftest.py` and `tests/checks/fixtures/` has only route-parity fixtures. Must land shared fixtures + 10+ new lint fixtures in Wave 0 before Wave 1 can write tests.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| GUARD-01 | `lefthook validate` passes | integration | `lefthook validate` | ✅ (lefthook.yml exists) |
| GUARD-01 | `lefthook run pre-commit` completes <5s P95 on reference diff | performance | `bash tools/checks/lefthook_benchmark.sh --assert-p95=5` | ❌ Wave 0 |
| GUARD-01 | 30.5 skeleton commands still wired | non-regression | `bash tools/checks/lefthook_self_test.sh` | ✅ (existing) + extend |
| GUARD-02 | diff-only: adds bare-catch to existing bad file → FAIL | unit | `python3 -m pytest tests/checks/test_no_bare_catch.py::test_diff_adds_bare_catch -x` | ❌ Wave 0 |
| GUARD-02 | diff-only: adds non-catch line to file with pre-existing bare-catch → PASS | unit | `python3 -m pytest tests/checks/test_no_bare_catch.py::test_diff_does_not_flag_existing_bad -x` | ❌ Wave 0 |
| GUARD-02 | `async *` generator catch exempted | unit | `python3 -m pytest tests/checks/test_no_bare_catch.py::test_async_star_exempt -x` | ❌ Wave 0 |
| GUARD-02 | inline `// lefthook-allow:bare-catch: reason` override accepted | unit | `python3 -m pytest tests/checks/test_no_bare_catch.py::test_inline_override -x` | ❌ Wave 0 |
| GUARD-02 | Python `except: pass` flagged | unit | `python3 -m pytest tests/checks/test_no_bare_catch.py::test_py_bare_except -x` | ❌ Wave 0 |
| GUARD-02 | `test/` paths exempted | unit | `python3 -m pytest tests/checks/test_no_bare_catch.py::test_test_path_exempt -x` | ❌ Wave 0 |
| GUARD-03 | `Text('Bonjour')` in screens/ flagged | unit | `python3 -m pytest tests/checks/test_no_hardcoded_fr.py::test_flags_hardcoded_fr_in_screens -x` | ❌ Wave 0 |
| GUARD-03 | `Text(l.greeting)` in screens/ passes | unit | `python3 -m pytest tests/checks/test_no_hardcoded_fr.py::test_passes_l10n_call -x` | ❌ Wave 0 |
| GUARD-03 | `.dart` under `lib/services/` exempted | unit | `python3 -m pytest tests/checks/test_no_hardcoded_fr.py::test_services_scope_excluded -x` | ❌ Wave 0 |
| GUARD-03 | `// lefthook-allow:hardcoded-fr: debug-only` accepted | unit | `python3 -m pytest tests/checks/test_no_hardcoded_fr.py::test_inline_override -x` | ❌ Wave 0 |
| GUARD-04 | `creer` in `.dart` flagged | unit | `python3 -m pytest tests/checks/test_accent_lint_fr.py::test_flags_creer -x` | ❌ Wave 0 |
| GUARD-04 | `créer` passes | unit | `python3 -m pytest tests/checks/test_accent_lint_fr.py::test_passes_accented -x` | ❌ Wave 0 |
| GUARD-04 | `app_en.arb` not scanned (other langs excluded) | unit | `python3 -m pytest tests/checks/test_accent_lint_fr.py::test_en_arb_ignored -x` | ❌ Wave 0 |
| GUARD-04 | 14 CLAUDE.md patterns all present | audit | `python3 -m pytest tests/checks/test_accent_lint_fr.py::test_pattern_coverage -x` | ❌ Wave 0 |
| GUARD-05 | 6 ARB files parity today → PASS | non-regression | `python3 tools/checks/arb_parity.py` | ✅ (baseline verified 2026-04-22) |
| GUARD-05 | removing a key from one lang → FAIL | unit | `python3 -m pytest tests/checks/test_arb_parity.py::test_missing_key_fail -x` | ❌ Wave 0 |
| GUARD-05 | placeholder name drift (`{count}` vs `{c}`) → FAIL | unit | `python3 -m pytest tests/checks/test_arb_parity.py::test_placeholder_name_drift -x` | ❌ Wave 0 |
| GUARD-05 | ICU plural parsed correctly (no false placeholder extraction) | unit | `python3 -m pytest tests/checks/test_arb_parity.py::test_plural_not_false_positive -x` | ❌ Wave 0 |
| GUARD-06 | commit w/ Claude trailer + valid Read: → PASS | unit | `python3 -m pytest tests/checks/test_proof_of_read.py::test_valid_claude_commit -x` | ❌ Wave 0 |
| GUARD-06 | commit w/ Claude trailer, no Read: → FAIL | unit | `python3 -m pytest tests/checks/test_proof_of_read.py::test_missing_read_trailer -x` | ❌ Wave 0 |
| GUARD-06 | commit w/ Read: pointing to non-existent file → FAIL | unit | `python3 -m pytest tests/checks/test_proof_of_read.py::test_read_file_missing -x` | ❌ Wave 0 |
| GUARD-06 | human commit (no Claude trailer) → PASS | unit | `python3 -m pytest tests/checks/test_proof_of_read.py::test_human_bypass -x` | ❌ Wave 0 |
| GUARD-07 | `lefthook run pre-commit` catches a synthetic bypass-induced regression | integration | synthetic PR + `bash tools/checks/lefthook_bypass_audit_smoke.sh` | ❌ Wave 0 |
| GUARD-07 | `bypass-audit.yml` creates issue when >3 `LEFTHOOK_BYPASS` commits in last 7d | integration | `gh workflow run bypass-audit.yml` + assert issue created | ⚠️ Manual |
| GUARD-08 | CI ci.yml no longer invokes migrated lints | audit | `grep -c 'no_chiffre_choc\|landing_no_numbers\|accent_lint_fr' .github/workflows/ci.yml` → 0 | ✅ (lines exist pre-34) |
| GUARD-08 | `lefthook-ci.yml` exists and passes `lefthook validate` | integration | `cat .github/workflows/lefthook-ci.yml && lefthook validate` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `python3 -m pytest tests/checks/ -q` (<3s on dev host, all lint unit tests)
- **Per wave merge:** `python3 -m pytest tests/checks/ tests/tools/ -q && bash tools/checks/lefthook_self_test.sh && bash tools/checks/lefthook_benchmark.sh` (<20s)
- **Phase gate (pre `/gsd-verify-work`):** all the above + `lefthook run pre-commit --all-files --force` + `lefthook validate`

### Wave 0 Gaps

- [ ] `lefthook.yml` schema migration (top-level `skip:` → nested) — BLOCKER, must ship before any Wave 1 work lands
- [ ] `tests/checks/conftest.py` — shared fixtures helper (git-diff mock, tempdir)
- [ ] `tests/checks/fixtures/no_bare_catch_fail.dart` — 1 bare-catch added, 1 pre-existing bare-catch (test D-07 diff-only behaviour)
- [ ] `tests/checks/fixtures/no_bare_catch_pass.dart` — logged try/catch
- [ ] `tests/checks/fixtures/no_bare_catch_fail.py`
- [ ] `tests/checks/fixtures/no_bare_catch_pass.py`
- [ ] `tests/checks/fixtures/no_hardcoded_fr_fail.dart` — `Text('Bonjour')` in a pseudo-screens path
- [ ] `tests/checks/fixtures/no_hardcoded_fr_pass.dart` — `Text(l.greeting)` + inline override example
- [ ] `tests/checks/fixtures/accent_lint_fail.dart` — ASCII `creer` pattern
- [ ] `tests/checks/fixtures/accent_lint_pass.dart` — `créer` accented
- [ ] `tests/checks/fixtures/arb_parity_fail/app_{fr,en,de,es,it,pt}.arb` — 6 files with a missing key in `de` and a placeholder drift in `it`
- [ ] `tests/checks/fixtures/arb_parity_pass/app_{fr,en,de,es,it,pt}.arb` — 6 files clean
- [ ] `tests/checks/fixtures/proof_of_read_fail.txt` — Claude trailer but no `Read:`
- [ ] `tests/checks/fixtures/proof_of_read_pass.txt` — Claude trailer + `Read: .planning/phases/34-.../34-00-READ.md`
- [ ] Self-test extension: add the 10 fixture invocations + exit-code asserts (`lefthook_self_test.sh` D-25)
- [ ] Benchmark: create `lefthook_benchmark.sh` with 10 iterations + P95 assertion (D-26)

---

## Security Domain

> Phase 34 is meta/tooling (L1 profile). No user-facing surface, no authn/session/access control. ASVS applicability minimal.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | N/A |
| V3 Session Management | no | N/A |
| V4 Access Control | no | N/A — lefthook runs as the committing user, no elevated privileges |
| V5 Input Validation | yes (weak) | Lints themselves treat staged content as untrusted text — regex compiles are bounded, `json.load()` raises on malformed input (must be caught cleanly, not swallowed; naturally handled by CONTEXT D-14's fail-on-error semantic) |
| V6 Cryptography | no | N/A |
| V7 Error Handling / Logging | yes | Lint output MUST NOT leak sensitive content. Snippet truncation at 120-140 chars already practiced by `accent_lint_fr.py` and `route_registry_parity.py` |
| V14 Config | yes | Lefthook.yml is infra-as-code. Changes gated by PR review; `lefthook validate` is the smoke test |

### Known Threat Patterns for dev-tooling / static-analysis lints

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Regex ReDoS on malicious commit content | DoS | Avoid exponential regexes (all Phase 34 patterns are linear). Compile once at module load, reuse (already standard). |
| Malicious `.arb` payload inflates `json.load()` memory | DoS | 6 files × ~11k lines each = ~500KB total — trivial. Python's `json` stdlib has no known DoS with non-nested 500KB input. |
| Injection via `lefthook-allow:` override comment | Tampering | Reason must be >3 words (D-06). Not a security barrier — social convention. PR review remains the gate. |
| `.git/COMMIT_EDITMSG` path injection | Tampering | Lefthook passes the canonical path via `{1}`; script reads it read-only with `Path().read_text()`. No `eval`, no shell. |
| Bypass-audit false-positive issue spam | Integrity | Threshold D-22 = 3/week. Issue label `bypass-audit` for filtering. Manual escalation per D-22. |
| proof-of-read trailer spoofing | Tampering | Attacker could include `Co-Authored-By: Claude` + `Read: /dev/null` in a commit. `/dev/null` doesn't exist on GitHub CI (Linux does have /dev/null — guard against pathological targets). Mitigation: require `Read:` path to match `^\.planning/phases/` (Phase 34 can enforce this). |

### Supply-chain posture

- **No new pip deps**. Entire phase is stdlib Python + brew-installed lefthook. Supply-chain surface unchanged from Phase 30.5.
- **Pip-audit** (CI `ci.yml:155`) continues to cover backend — Phase 34 adds nothing to that footprint.

---

## CI Thinning Map (GUARD-08)

### Exact `.github/workflows/ci.yml` lines to REMOVE

Line numbers verified on `feature/S30.7-tools-deterministes` HEAD 2026-04-22.

| Line | Job step | Migrates to |
|------|----------|-------------|
| 161 | `Legacy token gate (no chiffre_choc)` → `python3 tools/checks/no_chiffre_choc.py` | lefthook pre-commit (D-23) |
| 207 | `Landing v2 — no numbers / banned terms (LAND-04)` → `python3 tools/checks/landing_no_numbers.py` | lefthook pre-commit (D-23) |
| 211 | `Landing v2 — no financial_core imports (LAND-01)` → `python3 tools/checks/landing_no_financial_core.py` | lefthook pre-commit (D-23) |
| 448 | `route-registry-parity` job → `python3 tools/checks/route_registry_parity.py` | lefthook pre-commit (D-23) + retained in `lefthook-ci.yml` D-24 |

### Lines that STAY in CI (per D-23 "restent CI")

| Line | Job step | Reason |
|------|----------|--------|
| 113 | `python3 tools/checks/wcag_aa_all_touched.py` + Dart `flutter test test/accessibility/wcag_aa_all_touched_test.dart` | Heavy — Flutter setup + widget tests, ~2 min |
| 166 | `python3 tools/checks/no_legacy_confidence_render.py` | Debatable — grep-style, could migrate; CONTEXT D-23 doesn't list it explicitly. Recommend keep in CI for Phase 34 scope safety, revisit v2.9. |
| 171 | `python3 tools/checks/no_implicit_bloom_strategy.py` | Same — not in D-23 migration list |
| 176 | `python3 tools/checks/sentence_subject_arb_lint.py` | Same — not in D-23 migration list |
| 181 | `python3 tools/checks/no_llm_alert.py` | Same |
| 202 | `python3 tools/checks/regional_microcopy_drift.py` | Same |
| 217 | `pytest` backend suite | Heavy, stays |
| 224-238 | OpenAPI contract regeneration | Heavy — requires TESTING env + pyproject install |
| 256-264 | Alembic migration up/down/up | Heavy — DB-dependent |
| 281-302 | PII log gate | Staging-log fetch, not diff-local |
| 323-427 | Flutter shards (services/widgets/screens) | Heavy — 3-shard matrix ~8 min |
| 472 | `mint-routes-tests` pytest | Heavy — multi-file suite |
| 485-504 | `admin-build-sanity` grep | Per-workflow-file scan, not per-diff; keep in CI |
| 512-523 | `cache-gitignore-check` | Repo-level invariant |

### Net CI impact

- **Remove:** 4 explicit lint steps + 1 job (`route-registry-parity` occupies its own job block lines 429-448).
- **Estimated time saved per CI run:** ~30-45s (each grep is <2s, but setup-python + checkout dominates — ~5-10s per job).
- **Matches CONTEXT #5 "~-2 min CI"?** On an "all paths changed" PR, all jobs run — the 5 linted jobs are cheaper than e.g. wcag-aa-all-touched, but they run in parallel. **Realistic saving: 15-30s on hot path, up to 2 min on cold paths with full matrix. CONTEXT's -2 min claim is optimistic** — plan should revise to "≥30s on hot path, up to ~2 min on full runs" to set honest expectations.

### Adds to CI

- `.github/workflows/lefthook-ci.yml` (~40 lines, D-24) — adds ~30s (setup-python + lefthook install + validate + run)
- `.github/workflows/bypass-audit.yml` (~60 lines, D-21) — runs on schedule + post-merge to `dev`, doesn't block PRs

**Net CI delta: approximately -15s to -90s per PR run, depending on path filter outcomes.** Honest framing for plan.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | lefthook 2.1.6 parallel mode tolerates stderr interleaving with no aggregation, commands using `print()` to stdout/stderr don't deadlock | Pattern 6 | Low — if interleaving becomes problematic, upgrade path is `output:` config (v2.9). |
| A2 | `git diff --staged --unified=0 --no-renames --diff-filter=AM` behaviour is stable across git 2.20+ | Pattern 2 | Low — `--unified=0` and `--diff-filter` have been stable since git 1.x |
| A3 | MINT's convention that "virtually every commit carries `Co-Authored-By: Claude`" holds, so proof-of-read is a meaningful gate most of the time | Pitfall 4 | Low — empirically confirmed via `git log` (recent 10 commits: 4/10 have Claude trailer; some Julien-only direct pushes to dev exist). Note: **D-17 human-bypass is used more than expected — proof-of-read applies only to commits with the trailer, which is a subset.** |
| A4 | Benchmark P95 <5s is achievable with 5 lints × <200ms each × partial parallelism. NOT empirically measured this session. | Validation Architecture | Medium — first Wave 0 benchmark run is the test; if P95 >5s the plan should allow "paralléliser davantage" (CONTEXT specifics §1) or defer a lint to CI. |
| A5 | ICU placeholder regex (`{NAME[,}\s]`) handles all observed ARB values without false positives or negatives | Pattern 4 | Medium — `{amount, number, currency: CHF}` edge case with colon inside has not been tested. If encountered, extend regex or whitelist. |
| A6 | CI line numbers in `ci.yml` (161, 207, 211, 448, 166, 171, 176, 181, 202) are stable until Wave 0 touches them | CI Thinning | Low — branch `feature/S30.7-tools-deterministes` is the current checkout; numbers verified 2026-04-22. If merge conflicts before Phase 34 execute, regrep. |
| A7 | `lefthook validate` on CI is meaningful — the `skip:` top-level bug actually blocks CI today (not yet wired, but would if D-24 lefthook-ci.yml invokes `validate`) | Pattern 1 | High — **this is a Wave 0 BLOCKER**. Plan must land the nested-skip fix before invoking `lefthook validate` in any CI job. |
| A8 | CONTEXT D-04 "Pas de commit-msg dans cette phase" can be nuanced to allow a single `commit-msg:` block for proof-of-read without breaking scope | Pattern 5 | Medium — requires planner / Julien to accept the D-04 refinement explicitly. Alternative is `post-commit` (weaker) — document both options in plan. |
| A9 | `.github/workflows/bypass-audit.yml` weekly cron + post-merge trigger will have repo permissions to create issues (`permissions: issues: write`) | Example 5 | Low — github-actions[bot] default token has this permission on public and private repos alike. |
| A10 | Phase 34 plans should NOT remove the 30.5 `map-freshness-hint` command — it's "hint" not "gate", and removing it is out of scope per D-01 "skeleton préservé" | Example 1 | Low — easy to get right if D-01 is honored literally. |

---

## Open Questions (RESOLVED)

1. **Commit-msg hook scope (D-04 vs D-17)**
   - What we know: D-04 says "Pas de commit-msg dans cette phase". D-17 describes a check that requires commit-msg timing.
   - What's unclear: Was D-04 written before D-17 was finalized, or is there an implicit assumption GUARD-06 runs in `post-commit`?
   - Recommendation: Plan should surface this as an "amend D-04" or "use post-commit" decision point. Recommended: amend D-04 to allow exactly one `commit-msg:` block (the proof-of-read check). Justification: post-commit is too late (commit already written; `git commit --amend` required to fix).
   - **→ RESOLVED** via Plan 34-05: D-04 amended (new D-27 in CONTEXT.md), commit-msg hook for proof-of-read only; no other lints migrate to commit-msg.

2. **accent_lint_fr.py pattern reconciliation**
   - What we know: CLAUDE.md §2 lists 14 patterns. `tools/checks/accent_lint_fr.py` has 14 patterns but overlap is ~11 — `specialistes`/`gerer`/`progres` in script are not in CLAUDE.md; CLAUDE.md's `prevoyance`/`reperer`/`cle` are not in script.
   - What's unclear: Is the script's list or CLAUDE.md's list the authoritative one?
   - Recommendation: Plan GUARD-04 activation task should include a "reconcile to 14 canonical patterns" sub-step. Canonical source = CLAUDE.md §2 (user-facing doctrine). Add the 3 missing, remove the 3 extras or document them as bonus.
   - **→ RESOLVED** via Plan 34-01: reconciled to CLAUDE.md §2 canonical 14-pattern set.

3. **`no_hardcoded_fr.py` scope cleanup**
   - What we know: Script exists, early-ship covers the whole `apps/mobile/lib/`, excludes `lib/l10n/` + `test/`. D-08 narrows scope to widgets/screens/features only.
   - What's unclear: Should the early-ship version be moved/refactored, or kept and the lefthook `glob:` enforce the D-08 scope?
   - Recommendation: Enforce via lefthook `glob: "apps/mobile/lib/{widgets,screens,features}/**/*.dart"`. Keep Python script's internal `DEFAULT_SCOPE` broader for manual full-repo scans. Plan GUARD-03 task: minor script-internal changes to add `// lefthook-allow:hardcoded-fr:` override; glob does the scope restriction.
   - **→ RESOLVED** via Plan 34-03: glob-based scope enforced in lefthook.yml filter; script DEFAULT_SCOPE left broader for manual audits.

4. **Benchmark ground truth — is P95 <5s achievable?**
   - What we know: 5 new lints + 2 skeleton commands = 7 parallel commands.
   - What's unclear: Actual wall-time is unknown until measured. CONTEXT says "M-series Mac with diff typique 5 Dart + 3 Python". No data today.
   - Recommendation: Wave 0 MUST run `lefthook_benchmark.sh` and report P95 in the SUMMARY. If P95 >5s, the plan must have a documented escalation (CONTEXT specifics §1: "paralléliser davantage" or "déplacer un lint à CI").
   - **→ RESOLVED** via Plan 34-00 (baseline capture) + Plan 34-07 (`--assert-p95=5` enforced as final gate with all 10 pre-commit lints active).

5. **Is the proof-of-read `Read:` trailer a hard convention — what about squash merges?**
   - What we know: MINT uses squash-merge for `feature → dev`. `Co-Authored-By` trailers from feature branch commits get preserved in squash by `gh pr merge --squash` (if commit messages contain them).
   - What's unclear: When Phase 34 eventually squashes, will `Read:` trailers aggregate correctly? If multiple commits each had a `Read:` trailer, the squash message concatenates them but may dedupe or lose them per git's `--trailer` handling.
   - Recommendation: GUARD-06 runs per-commit on developer machine (and per-commit in `lefthook-ci.yml` D-24 via `git log --format=%B origin/<base>..HEAD`). Squash artefact is a separate question — if Julien wants "squashed commit must ALSO have Read: trailer aggregating all", that's v2.9. Phase 34 scope: per-commit on feature branches only.
   - **→ RESOLVED** documented as out-of-scope Phase 34 (v2.9 squash-merge Read-trailer aggregation deferred).

6. **`LEFTHOOK_BYPASS` detection in commit body — is it really grep-able?**
   - What we know: Env var is runtime-only and leaves no trace on the commit object.
   - What's unclear: D-20 and D-21 both imply "grep-able shell history" / "grep LEFTHOOK_BYPASS in commit bodies" — but the operator would have to manually add it to their commit message, which is a voluntary act.
   - Recommendation: Make D-20 CONTRIBUTING.md text state: "When you use `LEFTHOOK_BYPASS=1`, include `[bypass: <reason>]` in the commit message so the weekly audit can detect it." D-21 grep then picks up `LEFTHOOK_BYPASS` (env) or `[bypass:` (message convention). Treat D-24 (`lefthook-ci.yml`) as the PRIMARY ground-truth catcher.
   - **→ RESOLVED** via Plan 34-06 (CONTRIBUTING.md `[bypass: <reason>]` convention + weekly audit workflow) + Plan 34-07 D-24 CI re-run as primary ground truth.

---

## Sources

### Primary (HIGH confidence)

- `lefthook 2.1.6` CLI (`lefthook --help`, `lefthook validate` empirical test on dev host 2026-04-22) `[VERIFIED]`
- `git diff --staged --unified=0` output format — empirical test `/tmp/gittest` 2026-04-22, multi-hunk + new-file + rename + deletion cases `[VERIFIED]`
- `apps/mobile/l10n.yaml` — `template-arb-file: app_fr.arb` (Flutter template language convention) `[VERIFIED: cat]`
- 6 ARB files at `apps/mobile/lib/l10n/app_*.arb` — parity baseline 6707 non-`@` keys per lang, 569 FR `@keys` with placeholders vs 485 non-FR `[VERIFIED: json.load() 2026-04-22]`
- Phase 34 CONTEXT.md — 26 locked decisions, D-01 to D-26 `[VERIFIED: explicit ingestion]`
- Phase v2.8 REQUIREMENTS.md — GUARD-01..08 spec + kill-policy cross-refs `[VERIFIED]`
- `.github/workflows/ci.yml` — CI line numbers 161, 166, 171, 176, 181, 202, 207, 211, 448 verified `[VERIFIED: grep 2026-04-22]`
- `tools/checks/accent_lint_fr.py`, `no_hardcoded_fr.py`, `memory_retention.py`, `route_registry_parity.py`, `lefthook_self_test.sh` — existing patterns `[VERIFIED: direct read]`
- ICU MessageFormat spec — placeholder syntax `[CITED: icu.unicode.org/userguide/format_parse/messages]`
- Flutter internationalization guide — ARB placeholder types & format syntax `[CITED: docs.flutter.dev/ui/internationalization]`

### Secondary (MEDIUM confidence)

- Lefthook docs — `skip` schema evolution 2.0 → 2.1 `[WebSearch + empirical validate test, 2026-04-22]`
- Lefthook `commit-msg` hook + `{1}` placeholder `[CITED: github.com/evilmartians/lefthook docs/examples/commitlint.html, WebSearch]`
- ESLint `no-empty-catch` rule — Dart bare-catch prior art `[CITED: eslint.org]`
- Pylint W0702 / W0703 — Python bare-except prior art `[CITED: pylint.pycqa.org]`
- flake8-bugbear B902 — Python broad-except prior art `[CITED: github.com/PyCQA/flake8-bugbear]`

### Tertiary (LOW confidence — assumed/indirect)

- Exact CI time saved by thinning (A2): `~2 min` per CONTEXT — estimated ~15-90s based on job structure analysis `[ASSUMED]`
- Parallel mode tolerance of stderr interleaving (A1) — stated as design but not verified with 5-command load `[ASSUMED]`
- Benchmark P95 <5s achievability (A4) — no empirical run yet `[ASSUMED]`

---

## Metadata

**Confidence breakdown:**

- **Standard Stack:** HIGH — lefthook 2.1.6 installed locally, all 5 lints are stdlib-only, zero new deps needed.
- **Architecture Patterns:** HIGH for Patterns 1, 2, 3, 4 (all empirically verified). MEDIUM for Pattern 5 (commit-msg hook needs D-04 amendment). HIGH for Pattern 6 (parallel safety).
- **GUARD-02 diff-only:** HIGH — state machine verified on `/tmp/gittest`.
- **GUARD-05 ARB parity:** HIGH — baseline verified, FR-template asymmetry understood.
- **GUARD-06 proof-of-read:** MEDIUM — requires D-04 nuance decision before plan is actionable.
- **GUARD-07 bypass audit:** MEDIUM — D-24 CI re-run is reliable, D-21 weekly grep has inherent false-negative risk.
- **GUARD-08 CI thinning:** HIGH — line numbers verified. Time-saving magnitude LOW-MEDIUM (plan should revise expectation vs CONTEXT's ~2 min claim).
- **Pitfalls:** HIGH — Pitfalls 1 (schema), 2 (diff-only), 5 (interleaving), 6 (bypass audit false negatives) are all empirically grounded.

**Research date:** 2026-04-22
**Valid until:** 2026-05-22 (30 days for stable tooling; re-check if lefthook 2.2 ships in the interim)

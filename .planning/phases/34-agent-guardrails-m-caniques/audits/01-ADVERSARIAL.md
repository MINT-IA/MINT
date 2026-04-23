# Phase 34 Adversarial Bypass Audit

**Date:** 2026-04-23 (2026-04-22 codebase)
**Auditor role:** hostile agent trying to land bad code past every gate
**Scope:** 5 lints (accent, no-bare-catch, no-hardcoded-fr, arb-parity, proof-of-read), lefthook config, bypass policy, commit-msg hook, lefthook-ci, bypass-audit
**Method:** empirical — every finding backed by a `/tmp/p34audit/` fixture + recorded exit code

## Summary

- **P0 findings: 7** (shippable bad code + silent bypass paths)
- **P1 findings: 8** (regex evasion + weak override checks)
- **P2 findings: 5** (documentation gaps + minor crashes)

The single worst structural flaw: `no_bare_catch.py --staged` is invoked by `lefthook run pre-commit --all-files --force` in CI (lefthook-ci.yml), but `--staged` reads `git diff --staged` which is empty on a fresh clone. Any bare-catch that bypasses the local hook (via `LEFTHOOK_BYPASS=1`, `LEFTHOOK=0`, `--no-verify`, or `core.hooksPath=/dev/null`) **will NEVER be caught by CI**. CONTRIBUTING.md claims CI is the ground-truth safety net; it is not.

## P0 — Shipping bad code possible

### Finding #1: CI --all-files cannot catch bypassed bare-catches

**Attack:** Commit bad Dart/Python with `LEFTHOOK_BYPASS=1 git commit` or `git commit --no-verify`. Push to PR. lefthook-ci.yml runs `lefthook run pre-commit --all-files --force`. Bad code survives.
**Test input:** fresh git repo with `a.py` containing `try:\n    x()\nexcept Exception:\n    pass`, committed bypass-mode. `git reset HEAD -- .` simulates the CI checkout state.
**Expected:** lefthook-ci.yml fails the PR because the bare-except is in HEAD.
**Actual:** `python3 tools/checks/no_bare_catch.py --staged` returns rc=0 because `git diff --staged` is empty on the fresh checkout. Bad code ships.
**Evidence:**
```
$ cd /tmp/p34audit/fakerepo
$ git reset HEAD -- .
$ python3 .../no_bare_catch.py --staged
$ echo $?
0
```
**Impact:** The entire "primary ground-truth" claim of lefthook-ci.yml for no-bare-catch is false. FIX-05 (Phase 36) is deferred; Phase 34's whole safety story depends on this lint preventing *new* bad code. Bypass → silent → PR-merged → dev/staging/main.
**Fix hint:** no_bare_catch.py needs a `--diff-range <base>..<head>` mode that reads `git diff base..head` instead of `--staged`. lefthook-ci.yml invokes that mode against `origin/${{ github.base_ref }}..HEAD`. Alternative: full-file scan in CI with a "new-since-baseline" line-blame filter.

### Finding #2: LEFTHOOK=0 and LEFTHOOK_EXCLUDE bypass all hooks with zero audit trace

**Attack:** `LEFTHOOK=0 git commit -m "..."` disables every hook globally (documented lefthook feature). `LEFTHOOK_EXCLUDE=no-bare-catch git commit` skips just that one hook. `LEFTHOOK_RUN_ONLY=memory-retention-gate git commit` skips everything else.
**Test input:** any commit with those env vars set.
**Expected:** documented as banned OR caught by `bypass-audit.yml` regex.
**Actual:**
- CONTRIBUTING.md mentions only `LEFTHOOK_BYPASS=1` — zero mention of `LEFTHOOK=0`, `LEFTHOOK_EXCLUDE`, `LEFTHOOK_RUN_ONLY`.
- bypass-audit.yml regex: `grep -c -E 'LEFTHOOK_BYPASS|\[bypass:'`. Misses `LEFTHOOK=0` / `LEFTHOOK_EXCLUDE` / `LEFTHOOK_RUN_ONLY` entirely.
**Evidence:** `grep -r "LEFTHOOK=0\|LEFTHOOK_EXCLUDE" .github/ CONTRIBUTING.md` → zero hits.
**Impact:** an agent who knows lefthook's stdlib env vars (public documentation) can bypass all hooks with zero mention in commit body — bypass-audit doesn't raise, lefthook-ci doesn't detect because (see Finding #1) the --staged-based lints are toothless in CI.
**Fix hint:** update bypass-audit regex to `LEFTHOOK(_BYPASS|_EXCLUDE|_RUN_ONLY)?=|\[bypass:`. Document the banned set in CONTRIBUTING §3. Consider a pre-receive hook or git server-side check for these vars (harder, requires server tooling).

### Finding #3: core.hooksPath=/dev/null bypass

**Attack:** `git -c core.hooksPath=/dev/null commit -m "..."` tells git to look for hooks in `/dev/null`, so none fire. Zero env var, zero commit trailer.
**Test input:** fresh repo, `git -c core.hooksPath=/dev/null commit --allow-empty -m "bypass"`.
**Expected:** caught by some gate.
**Actual:** commit lands. No signal anywhere.
**Evidence:**
```
$ git -c core.hooksPath=/dev/null commit --allow-empty -m "bypass via hooksPath"
[main e06d99a] bypass via hooksPath
```
**Impact:** perfect silent bypass; survives unless CI re-runs lints with real diff (see Finding #1 which shows CI currently doesn't). lefthook has no defence; this is a git feature.
**Fix hint:** only fixable via CI-side re-run with a proper `--diff-range` mode (Finding #1 fix). Document this bypass as banned in CONTRIBUTING §3 for trail-of-tears completeness.

### Finding #4: Trivial READ.md passes proof-of-read

**Attack:** commit-msg hook only checks (a) path starts with `.planning/phases/`, (b) path exists, (c) file contains at least one `- ` bullet line. Zero check that bullet references real code files, zero check the READ.md is the one relevant to this phase/commit.
**Test input:**
```
.planning/phases/fake/dummy-READ.md:
# Fake
- anything at all
```
Commit msg:
```
feat: x

Read: .planning/phases/fake/dummy-READ.md
Co-Authored-By: Claude
```
**Expected:** fail, since the bullet doesn't reference any file the agent actually read.
**Actual:** rc=0, "Claude commit references .planning/phases/fake/dummy-READ.md (1 files listed)".
**Evidence:**
```
$ python3 proof_of_read.py --commit-msg-file msg.txt --repo-root /tmp/p34audit/repo
[proof_of_read] OK - Claude commit references .planning/phases/fake/dummy-READ.md (1 files listed)
RC=0
```
**Impact:** an agent can create a one-line junk READ.md and ship anything. The D-18 "- <path> — <why>" convention is never enforced by the lint.
**Fix hint:** require `- <path> — <why>` bullets to reference paths that exist, and at least N (e.g. 3) valid ones. Optionally require the phase segment in the Read: path to match a phase prefix derived from the branch name.

### Finding #5: Stale Read: reference from wrong phase passes

**Attack:** a Phase 34 commit can reference a Phase 30.5 READ.md. The lint does no phase-to-commit correlation.
**Test input:**
```
feat(34): something
Read: .planning/phases/30.5-context-sanity/30.5-CONTEXT.md
Co-Authored-By: Claude
```
**Expected:** fail (phase mismatch) OR warn.
**Actual:** rc=0, accepted with "57 files listed" because 30.5-CONTEXT.md contains many "- " bullets.
**Impact:** one valid historic READ.md can be re-used as a fig-leaf across all future Claude commits. Proof-of-read becomes proof-of-copypaste.
**Fix hint:** derive phase ID from branch name (`feature/S34.*`) and require `Read:` path's `<phase>` segment to match, OR require the commit subject to include the phase prefix that matches.

### Finding #6: Read: on subject line (line 1) passes

**Attack:** git convention places trailers at the bottom of commit message. proof_of_read regex uses `MULTILINE` with `^Read:`, so any line starting with `Read:` qualifies — including the subject.
**Test input:** subject = `Read: .planning/phases/30.5-context-sanity/30.5-CONTEXT.md`; body empty; Claude trailer.
**Expected:** fail — trailers belong at the bottom.
**Actual:** rc=0 accepted.
**Evidence:** see /tmp/p34audit/por/msg_subject_read.txt.
**Impact:** minor, but indicates the lint doesn't follow git-trailer semantics. Combined with Finding #5, an attacker's subject becomes "Read: .planning/phases/.../30.5-CONTEXT.md" which is absurd but lets bypass-audit grep miss nothing unusual.
**Fix hint:** use `git interpret-trailers --parse --no-divider` to extract trailers; only accept `Read` values from trailer block. Reject Read: found only in subject.

### Finding #7: First-match semantics — valid Read: followed by fake works

**Attack:** put a valid Read: first, a fake second. `TRAILER_READ.search(msg)` returns the first regex match.
**Test input:**
```
Read: .planning/phases/30.5-context-sanity/30.5-CONTEXT.md
Read: .planning/phases/bogus-never-existed.md
Co-Authored-By: Claude
```
**Expected:** all Read: entries validated.
**Actual:** only the first is checked; the fake is ignored.
**Impact:** an agent can claim to have read legit-looking file A while the commit actually relates to file B (which doesn't exist). Audit trail degraded.
**Fix hint:** use `findall` and validate every Read: trailer.

## P1 — Guarantee weakened (regex bypasses, weak checks)

### Finding #8: Dart bare-catch with variable name not in {e,_,err,error}

**Attack:** rename the catch variable.
**Test inputs (all rc=0, should be rc=1):**
- `} catch (ex) {}`
- `} catch (exc) {}`
- `} catch (stackTrace) {}`
- `} catch (e, st) {}` (two-arg form is legal Dart + misses the single-arg regex)
**Evidence:** `/tmp/p34audit/regex_test.py` output: `MISS  '} catch (ex) {}'`, `MISS  '} catch (exc) {}'`, `MISS  '} catch (stackTrace) {}'`, `MISS  '} catch (e, st) {}'`.
**Fix hint:** replace `(?:e|_|err|error)` with `[A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)?` to match any identifier (and optional stackTrace name).

### Finding #9: Dart bare-catch with non-empty body bypass

**Attack:** any character inside the catch body (including `;`, `/*...*/`, a single statement, `null;`) fails the `{\s*}` pattern.
**Test inputs (all rc=0):**
- `} catch (e) { /* comment */ }`
- `} catch (e) { null; }`
- `} catch (e) { ; }`
- `} catch (e) { int x = 1; }` (non-logging statement)
**Evidence:** regex `}\s*catch\s*\(\s*(?:e|_|err|error)\s*\)\s*\{\s*\}` requires purely-whitespace body.
**Impact:** this is the defining bypass. Attackers write `catch (e) { /* ok */ }` and the lint is blind. Combined with Finding #8, the D-07 diff-only guarantee is largely empty.
**Fix hint:** require body to contain one of DART_LOG_TOKENS; invert the check — if body has no log token, fail regardless of content.

### Finding #10: Python bare-except with `as e:` / tuple / one-liner all bypass

**Attack:** the regexes only match three exact forms: `except:`, `except Exception:`, `except BaseException:`, all with trailing `$`. Everything else passes.
**Test inputs (all rc=0):**
- `except Exception as e:\n    pass`
- `except (ValueError, TypeError):\n    pass`
- `except (Exception,):\n    pass`
- `try: x()\nexcept Exception as e: pass` (one-liner)
- `except Exception:  # comment` (trailing comment breaks `\s*$`)
- `except Exception: ...` (ellipsis body)
- `except:pass` (no space — `^\s*except\s*:\s*$` fails because `:\s*$` requires colon at line end)
- `except KeyboardInterrupt:` (most dangerous — swallows Ctrl-C)
**Evidence:** /tmp/p34audit/regex_test.py. Every one printed `MISS`.
**Fix hint:** use an AST walker (`ast.parse(source)` → visit `ExceptHandler`). Regex cannot handle Python's exception grammar.

### Finding #11: Bare-catch "has log in 5 lines" check trivially fooled by comment

**Attack:** put the token `logger.`, `log(`, `raise`, `throw`, `print(`, etc. in any comment within ±5 lines.
**Test input:**
```python
try:
    bar()
except Exception:
    pass  # logger.info() could go here
```
**Expected:** fail (no real logging).
**Actual:** rc=0 — token `logger.` is present in the comment, lint skips the violation.
**Impact:** writing `# logger.info` once is a universal bypass. Also `# raise later` bypasses. Easily scripted.
**Fix hint:** strip comments before token-match, or require the token on a line that is code (not comment). Python: use `tokenize`. Dart: strip `//...` and `/*...*/` before scan.

### Finding #12: Override reason validator only counts words, not quality

**Attack:** `// lefthook-allow:bare-catch: a b c` passes (3 tokens). Any 3 whitespace-separated tokens ship.
**Test input:** override with reason `"a b c"`, `"xxx yyy zzz"`, `"lol ok fine"`.
**Expected:** require meaningful reason.
**Actual:** all rc=0.
**Evidence:** `_has_valid_override` calls `len(m.group(1).strip().split()) >= 3`.
**Impact:** the inline override is cosmetic. Doctrine says "reason obligatoire >3 mots" but has zero semantic check. A hostile agent writing 100 overrides in one commit produces 100 green `a b c` lies.
**Fix hint:** unfixable mechanically. But min-word length (e.g. each word >=4 chars) + blacklist of obvious filler words would raise the bar. OR pair the override with an issue ref: `// lefthook-allow:bare-catch: #123 reason`.

### Finding #13: no_hardcoded_fr misses short French words

**Attack:** any French word <6 effective chars slips. The primary pattern `[A-Z][a-z]+.{5,}?` requires total length 7+. French short words: "Salut" (5), "Oui" (3), "Non" (3), "Paris" (5), "Non merci" (9 but no FR function word cluster), "Bonjour" does hit (7 chars).
**Test input:**
```dart
Text('Salut');    // 5 chars - miss
Text('Argent');   // 6 chars - miss
Text('Paris');    // 5 chars - miss
```
**Actual:** all rc=0.
**Impact:** any short user-visible French label ships. Common for buttons ("OK", "Non", "Oui", "Aide").
**Fix hint:** lower the length threshold to 2 characters, rely on French word-list dictionary (e.g. top-1000 FR words) to differentiate from English.

### Finding #14: ARB parity — ordering + metadata-only drift uncaught

**Attack 1:** reorder placeholders in translated string. `{name} then {age}` vs `{age} then {name}` — order-insensitive set comparison passes.
**Attack 2:** add extra `@key` metadata in non-FR ARB (e.g. EN has `@greeting.placeholders.nonsense`). Phase 3 only iterates FR `@keys`, so non-FR `@keys` are invisible.
**Test input:** see /tmp/p34audit/arb_test/.
**Actual:**
- Ordering drift `{name} {age}` vs `{age} {name}`: rc=0.
- Extra `@greeting` metadata in EN: rc=0.
**Impact:** a maliciously reordered string could cause `"You scored 90 by Jean"` → `"Jean scored 90 by you"` depending on language; lint doesn't flag.
**Fix hint:** emit an ordered list of placeholders per lang and compare sequences. Flag ARB metadata divergence across langs too (current design assumes only FR carries metadata, but lint doesn't enforce that).

### Finding #15: accent_lint_fr comment/URL/identifier false-positive-BY-DESIGN enables deletion attack

**Attack:** the lint scans ALL text, no syntactic awareness. So legitimate identifiers and URLs containing `securite` fire. Developers are trained to ignore these. That trains them to ignore the lint.
**Examples hit by lint:**
- `var url = 'https://securiteroute.ch';`
- `// TODO: securite reorg`
- Raw string: `r'securite'`
**Attack path:** attacker submits PR with 10 legitimate false positives + 1 real accent bug. Reviewer tires, merges. All 11 lines pass (or all 11 are overridden... oh wait, accent lint has NO override per D-12).
**Actual:** the lint fails on legitimate identifiers.
**Impact:** over time, devs either rename identifiers awkwardly or bypass globally via `LEFTHOOK_BYPASS`. Rule-fatigue attack.
**Fix hint:** strip comments, URLs, and identifiers (via tokenizer) before scanning. Scope to string literals only.

## P2 — Documentation gaps, crashes, minor holes

### Finding #16: proof_of_read crashes on directory Read: path

**Attack:** `Read: .planning/phases/` (trailing slash, a real directory).
**Test input:**
```
Read: .planning/phases/
Co-Authored-By: Claude
```
**Actual:** unhandled `IsADirectoryError`. Script exits 1 due to crash, not a clean lint message.
**Evidence:**
```
IsADirectoryError: [Errno 21] Is a directory: '/Users/.../MINT/.planning/phases'
```
**Impact:** diagnostic is a Python traceback instead of a clear error. Minor, but exposes poor error handling.
**Fix hint:** `read_path.is_file()` check before `read_text()`.

### Finding #17: Path containing `..` inside prefix check bypasses T-34-SPOOF-01

**Attack:** `.planning/phases/34-.../../30.5-context-sanity/30.5-CONTEXT.md` passes `startswith('.planning/phases/')` but resolves via `..` to a different phase. Not a true spoof (still in `.planning/phases/`), but the intent of T-34-SPOOF-01 was "no traversal" per decision doc.
**Test input:** see /tmp/p34audit/por/msg_traversal2.txt.
**Actual:** rc=0 accepted.
**Impact:** low — always lands inside `.planning/phases/`. But defeats the stated "hardcoded prefix check" mitigation promise.
**Fix hint:** call `Path.resolve()` then check `str(resolved).startswith(str((repo_root / '.planning/phases').resolve()))`.

### Finding #18: Full-width Unicode Ｒead: trailer

**Attack:** put fake `Ｒead:` (U+FF32) trailer in addition to real Read:. Not a direct bypass but a code-obfuscation smell.
**Test input:** two trailers, one with full-width R.
**Actual:** the full-width one is ignored (correct), the ASCII one matches (correct).
**Impact:** none for bypass, but commit log becomes a confusing audit trail. Also: if an attacker somehow strips the ASCII `Read:` and leaves only the full-width one, script reports "missing Read: trailer" — graceful. No action needed, informational only.

### Finding #19: commit-msg hook fires on every commit incl. merge/rebase (good), but pre-commit skips merge/rebase

**Attack:** attacker uses `git rebase` to rewrite history and introduce bad code. With `skip: [merge, rebase]`, pre-commit (and thus no-bare-catch, hardcoded-fr, accent, arb-parity) do not fire during rebase rewrites. commit-msg still fires (proof-of-read) but that's only useful for Claude-coauthored commits.
**Test:** `git rebase -i` with `edit` on a commit, modify a .dart file to add bare-catch, `git commit --amend`. Since rebase is skipped, pre-commit won't fire.
**Impact:** partial — most teams don't rewrite shared history. But for solo agents rebasing feature branches, this is a bypass corridor.
**Fix hint:** remove `rebase` from skip list. Rebase amend commits should be re-checked.

### Finding #20: `--no-verify` banned by convention only

**Attack:** `git commit --no-verify` runs normally, hooks don't fire. Zero commit-message trace.
**Actual:** CONTRIBUTING §3 says "Never use git commit --no-verify", but it's not blocked. bypass-audit can't detect it post-hoc.
**Impact:** known and accepted by the team (D-20). Just a reminder that policy-only bans lean on humans/agents behaving honourably.
**Fix hint:** lefthook-ci.yml is supposed to re-run lints; combined with Finding #1, it currently doesn't for no-bare-catch. Fixing Finding #1 closes this.

## Attack-surface cheat sheet (for defenders)

| Vector | Detected by local hook? | Detected by lefthook-ci.yml? | Detected by bypass-audit.yml? | Grade |
|---|---|---|---|---|
| `LEFTHOOK_BYPASS=1` | N (bypass) | depends on lint | Y (grep) | C |
| `LEFTHOOK=0` | N | depends | **N** | **F** |
| `LEFTHOOK_EXCLUDE=lint1,lint2` | partial | depends | **N** | **F** |
| `LEFTHOOK_RUN_ONLY=foo` | partial | depends | **N** | **F** |
| `--no-verify` | N | depends | N | F |
| `core.hooksPath=/dev/null` | N | depends | N | F |
| delete `.git/hooks/pre-commit` | N | depends | N | F |
| rebase -i (pre-commit skip) | N | depends on lint diff-mode | N | F |
| bad code in catch body with log-token comment | **N** | N (staged empty in CI) | n/a | F |
| bare-except variant not in 3 hardcoded forms | **N** | N | n/a | F |
| `Text('Oui')` / short FR | N | N | n/a | D |
| junk READ.md | N | N (passes) | n/a | D |
| stale Read: from other phase | N | N (passes) | n/a | D |

"depends on lint" = lefthook-ci re-runs the hook but lints using `--staged` produce empty results on fresh clone (see Finding #1).

## Recommended hardening priorities (author's take)

1. **Finding #1 (P0)** — fix no_bare_catch.py to accept `--diff-range base..head` and invoke it from lefthook-ci.yml. Without this, Phase 34 is cosmetic for bypass paths.
2. **Findings #2 + #20 (P0)** — expand bypass-audit regex to all lefthook env vars; document the banned set.
3. **Finding #9 + #10 (P1)** — move no_bare_catch to AST or at minimum require log-token in body (not comment).
4. **Finding #4 + #5 (P0)** — proof_of_read should validate READ.md bullets reference existing files and match phase prefix.
5. **Finding #11 (P1)** — strip comments before log-token check.

## Out of scope but noted

- `memory-retention-gate` and `map-freshness-hint` untested (Phase 30.5 scope).
- `landing_no_numbers.py`, `no_chiffre_choc.py`, `route_registry_parity.py`, `landing_no_financial_core.py` — migrated but not deeply audited.
- lefthook binary internals — took lefthook docs at face value for LEFTHOOK_EXCLUDE / LEFTHOOK=0 behaviour.

---

**Test fixtures preserved at:** `/tmp/p34audit/` (Dart/Python evasion files + commit-msg inputs + ARB drift set + /tmp/p34audit/fakerepo simulated git repo).

*Auditor: hostile agent simulation, 2026-04-23. No tracked files modified.*

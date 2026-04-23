# Phase 34 Regex Robustness Audit

**Date:** 2026-04-23
**Auditor:** Regex robustness specialist (audit-only, no script modifications)
**Lint targets:** 5
- `tools/checks/no_bare_catch.py` (GUARD-02)
- `tools/checks/no_hardcoded_fr.py` (GUARD-03)
- `tools/checks/accent_lint_fr.py` (GUARD-04)
- `tools/checks/arb_parity.py` (GUARD-05)
- `tools/checks/proof_of_read.py` (GUARD-06)
**Test fixtures:** 57 created in `/tmp/audit_regex/`, run empirically (never projected from code reading).

---

## Executive summary

Every lint has exploitable bypasses. Severity distribution:

| Lint | P0 bypass | P1 gap | P2 cosmetic |
|------|-----------|--------|-------------|
| no_bare_catch (Dart) | **5** | 3 | 1 |
| no_bare_catch (Py)   | **2** | 3 | 0 |
| no_hardcoded_fr      | **2** | 4 | 2 |
| accent_lint_fr       | **3** | 2 (huge FP rate) | 1 |
| arb_parity           | 1 | **2** (ICU walker bugs) | 2 |
| proof_of_read        | **3** | 2 | 1 |

Any MINT agent aware of these bypasses can silently ship banned code through pre-commit. The dominant pattern: lints were designed against a narrow "canonical form" and never adversarially stress-tested against minor syntactic variants.

---

## 1. Dart bare-catch (`no_bare_catch.py` / DART_BARE_CATCH)

Pattern: `}\s*catch\s*\(\s*(?:e|_|err|error)\s*\)\s*\{\s*\}` and `on \w+ catch (e|_|err) { }`.

### Evasion matrix

| Input | Expected | Regex HIT | Bypass? | Severity |
|-------|----------|-----------|---------|----------|
| `} catch (e) {}` (canonical) | FAIL | True | no | — |
| `} on Exception catch (e) { }` | FAIL | True | no | — |
| `} on FormatException catch (e) { }` | FAIL | True | no | — |
| `} catch (ex) { }` | FAIL | **False** | **YES** | P0 |
| `} catch (exception) { }` | FAIL | **False** | **YES** | P0 |
| `} catch (e, stack) { }` | FAIL | **False** | **YES** | P0 |
| `} catch (e) { // comment }` | FAIL (body only has comment) | **False** | **YES** | P0 |
| `} catch (e) { return; }` | FAIL (no log/rethrow) | **False** | **YES** | P0 |
| `} catch (e) { throw e; }` | PASS (rethrow-like) | False | no | — |
| `}\n  catch\n  (e)\n  {\n  }` (multi-line) | FAIL | **False** | **YES** | P1 |
| `} catch (e) {     }` (whitespace body) | FAIL | True | no | — |

**Why it matters:** Dart convention frequently uses `ex`, `exception`, `err` (already listed), `e, stackTrace`. Any agent renaming the bound name bypasses the lint. `catch (e, stack)` is idiomatic Dart — the regex's `\(\s*(?:e|_|err|error)\s*\)` is locked to single-param signatures only.

**Body-content bypass:** The regex trusts `\{\s*\}` to mean "empty body," but the `has_surrounding_log_tokens` fallback only checks +5 lines *after* a line that already matched the regex. If the body breaks the regex (comment, `return;`, nested `if`), the regex never matches in the first place — so the fallback never runs. `catch (e) { return; }` silently swallows errors.

### P0 evasion recipe (copy-pastable)
```dart
try { risky(); } catch (ex) { }                           // P0 — regex misses 'ex'
try { risky(); } catch (e, stack) { }                     // P0 — two-arg catch
try { risky(); } catch (e) { /* swallow */ }              // P0 — comment body
try { risky(); } catch (e) { return; }                    // P0 — non-log non-rethrow body
try { risky(); } on Exception catch (unused_ex) { }       // P0 — bound name not in alternation
```

### Python extras
| Input | Expected | Regex HIT | Bypass? | Severity |
|-------|----------|-----------|---------|----------|
| `except Exception:` (own line) | FAIL | True | no | — |
| `except:` (own line) | FAIL | True | no | — |
| `except: pass` (one-liner) | FAIL | **False** | **YES** | P0 |
| `except Exception: pass` | FAIL | **False** | **YES** | P0 |
| `except Exception as e:` | FAIL | False | by design? | P1 |
| `except (ValueError, TypeError):` | FAIL | False | by design? | P1 |
| `except (ValueError, TypeError) as e:` | FAIL | False | by design | P1 |

**Why P0:** The regex anchors `^\s*except\s*:\s*$` — the `$` forbids anything on the same line. The canonical Python one-liner `except: pass` never matches any of the 3 `PY_BARE_EXCEPT` patterns, so the lint passes. Every Python agent that uses `except: pass` (very common) bypasses.

**Why P1 for typed/tuple:** Current policy is "bare-catch only" so typed catches are not flagged; but `except Exception as e: pass` is semantically identical to `except Exception: pass` (which IS flagged) — inconsistent.

### P2
- `async *` detection uses a 10-line look-back heuristic; any generator with a bare-catch more than 10 lines into the body evades the heuristic and IS flagged (potential false positive for very long generators). Not a bypass, just noise.

### Test-suite coverage
`tests/checks/test_no_bare_catch.py` has 217 lines. Grep shows **zero** tests for: `catch (ex)`, `catch (exception)`, `catch (e, stack)`, comment-only bodies, `return;` bodies, multi-line catch, `except: pass` one-liner. Every P0 bypass is uncovered.

---

## 2. Hardcoded-FR (`no_hardcoded_fr.py`)

### Evasion matrix

| Input | Expected | Actual | Bypass? | Severity |
|-------|----------|--------|---------|----------|
| `Text('bonjour tout le monde')` (lowercase start) | FAIL | FAIL via `_QUOTED_FR_WORDS` | no (function-words fallback caught it) | — |
| `Text("Oui")` (short) | FAIL | **PASS** | **YES** | P0 |
| `Text('BONJOUR')` (all-caps) | FAIL | **PASS** | **YES** | P0 |
| `const x = "Bonjour tout le monde"; Text(x)` (indirection) | FAIL | FAIL | no (function-words caught) | — |
| `Text('Bon' + 'jour tout le monde')` (concat) | FAIL | FAIL (function-words on 'jour tout le monde') | no | — |
| `Text('\u0042onjour tout le monde')` (Unicode escape) | FAIL | FAIL | no (function-words still fire) | — |
| `Text.rich(TextSpan(text: 'Bonjour ...'))` | FAIL | FAIL (function-words on value) | no | — |
| `MintButton(label: 'Cliquer ici')` | FAIL | FAIL (label: pattern) | no | — |
| `AppBar(title: Text('Paramètres'))` | FAIL | FAIL (`_TEXT_ACCENT`) | no | — |
| `Semantics(label: 'Bonjour monde')` | FAIL | FAIL (label: pattern) | no | — |
| `Text('${L10n.x}')` | PASS | PASS | no | — |

**P0 #1 — all-caps words.** `Text('BONJOUR')`, `Text('ERREUR')`, `Text('CONTINUER')` all silently pass. `_ACRONYM` whitelists any 2-5 cap-letter quoted token; production Dart uppercase-styled buttons (e.g. "CRÉER UN COMPTE" normalised to ASCII caps as "CREER UN COMPTE") would bypass. The same whitelist fires for `'CLE API'` (legit FR + term 'cle', 3 letters = inside 2..5 range).

**P0 #2 — short words.** `Text('Oui')`, `Text('Non')`, `Text('OK?')` all < 6-char tail so `_TEXT_CAPITALISED` never matches; no accent so `_TEXT_ACCENT` misses; no function word so `_QUOTED_FR_WORDS` misses. Every 1-5 char FR word is invisible to the lint.

**P1 issues:**
- `_QUOTED_ACCENT` (generic accented literal fallback) fires on literally any quoted string with an accent anywhere in the codebase — including comments that happen to contain `'Créer'`, Dart source annotations, regex literals, etc. It runs *after* the specific patterns but catches any leftover. Cross-language strings like Spanish `'día'` or German `'für'` trigger FR-specific diagnostics (wrong-language false positive).
- `_TITLE_PARAM` / `_LABEL_PARAM` require `[A-Z][a-z]+` so `title: 'abc'` (lowercase) bypasses even if it's French; `label: '3a'` (numeric-start FR) bypasses.
- The lint reads `AppLocalizations` as an IGNORE_MARKER on the same line — `const frMsg = 'Bonjour'; // uses AppLocalizations elsewhere` would be exempted despite violating.
- Template literals: `Text('Param${etres}')` has no closing quote before `${` so regex may treat the whole thing as a single string or two halves. Not tested live but structurally fragile.

**P2:**
- Concatenation splits into multiple single-quoted literals. Our test `Text('Bon' + 'jour tout le monde')` DID get caught because the second literal has enough function words, but `Text('Bon' + 'jour')` (both halves short, no accent) bypasses all six patterns.
- No detection of `setState(() { _label = 'Nouveau'; })` — assignments aren't in `title:`/`label:` form.

### ReDoS
`_TEXT_CAPITALISED` = `\bText\(\s*['"]([A-Z][a-z]+.{5,}?)['"]\s*[),]` is lazily-quantified but has **quadratic backtracking** on unterminated `Text('A...` input:

| Input size (bytes) | Match time |
|---|---|
| 5 KB | 0.107 s |
| 20 KB | 1.710 s |
| 50 KB | 10.708 s |

A single 50 KB Dart file with `Text('A` + 50 000 × `a` (no closing quote) hangs the pre-commit hook for 10+ seconds on one file. Any adversary can grief CI with a 1 MB crafted file (projected ~40 min single-regex eval). **P1** because the lint has no per-line or per-file timeout.

### Test-suite coverage
`tests/checks/test_no_hardcoded_fr.py` = 112 lines. No tests for all-caps bypass, short-word bypass, ReDoS, cross-language accent FP, or `Semantics(label:)`.

---

## 3. Accent_lint_fr (`accent_lint_fr.py`)

### Unicode evasion (P0)

| Input | Bytes | Lint verdict | Expected | Bypass? |
|-------|-------|--------------|----------|---------|
| `creer` (ASCII) | `63 72 65 65 72` | FAIL | FAIL | no |
| `créer` (NFC `é` = U+00E9) | `63 72 c3 a9 65 72` | PASS | PASS | no |
| `créer` (NFD `e` + `́` = U+0065 U+0301) | `63 72 65 cc 81 65 72` | PASS | PASS (visually correct) | no |
| `ｃｒｅｅｒ` (fullwidth U+FF43 U+FF52 U+FF45×2 U+FF52) | multibyte | **PASS** | FAIL | **YES P0** |
| `сrееr` (Cyrillic `с` U+0441, `е` U+0435) | multibyte | **PASS** | FAIL | **YES P0** |
| `c\u200Breer` (ZWS-injected) | ASCII+ZWS | **PASS** | FAIL | **YES P0** |

**Adversarial scenario:** An agent (or a copy-paste from a homoglyph-polluted corpus) introduces visually-identical but Unicode-distinct text. The lint uses `\bcreer\b` which only matches ASCII codepoints; anything with a non-ASCII lookalike passes. Realistic risk — low today; but given MINT's D-07 "Claude-coauthored commits" attack model, a prompt-injected agent could deliberately insert Cyrillic lookalikes to bypass.

### Conjugation false-negatives (P1 by volume)

`\bcreer\b` only matches the infinitive. Every conjugated form evades:

| Form | Regex match |
|------|-------------|
| `creer` | True |
| `creerais`, `creeront`, `creait` (conditional, future, imperfect) | **False** |
| `recreer`, `decreer` (prefixed) | **False** |
| `decouvrirais`, `decouvriraient`, `decouvrira`, `decouvrait` | **False** |
| `securites` (plural) | **False** |
| `securisee` (derived adjective) | **False** |

Per stem, the French language has on average 5-15 conjugated/derived forms ASCII-flattened to the same pattern. The lint catches 1 of ~10 forms → estimated **~90% false-negative rate** on real FR ASCII prose.

### False-positive rate on production code (P1)

Full scan: `apps/mobile/lib` + `services/backend/app` + `tools` (MD/ARB/DART/PY). Ranked by stem:

| Stem | Total hits | Likely FP* | Likely TP | FP% |
|------|-----------|------------|-----------|-----|
| prevoyance | **1011** | 643 | 361 | **64%** |
| eclairage | 49 | ~35 (route paths `/premier-eclairage`) | ~14 | 71% |
| securite | 37 | ~18 (comment doc terms) | ~19 | 49% |
| deja | 35 | ~10 (comments + ES l10n `te deja`) | ~25 | 29% |
| decouvrir | 28 | 0 (all inside user-facing text) | 28 | ~0% |
| creer | 21 | ~2 | ~19 | ~10% |
| cle | 20 | ~15 (BYOK doc, `cleGeneration` var) | ~5 | 75% |
| regler | 7 | **6 (all German `Regler` = slider!)** | 1 | **86%** |
| recu | 5 | 3 (backend schema description, test fixture) | 2 | 60% |
| elaborer | 4 | 2 (test fixture + conftest) | 2 | 50% |
| liberer, preter, realiser | 3 each | 3 each (test fixtures only) | 0 | **100%** |
| reperer | 2 | 2 (test fixtures) | 0 | 100% |

*Heuristic: FP = field identifier (`'prevoyance.xxx'`), ICU placeholder name in FR l10n (`$prevoyance`), route path, variable name, non-FR language text, or Dart ARG name in generated l10n file.

**Critical FPs flagged:**
- `\bregler\b` matches **German `Regler`** (= "slider control") 6 times in the DE ARB. This is a **wrong-language false positive** — the lint doesn't discriminate file language.
- `\bdeja\b` matches **Spanish `deja`** ("leaves") in `app_es.arb`: `"MINT te deja tranquilo"` — same issue.
- `\bcle\b` matches the French-transliteration of BYOK (`'ta propre cle API'`) **and** variable names. Both are code-facing comments, not user-facing FR text.
- `prevoyance` field path `'prevoyance.avoirLppTotal'` flagged ~643 times — the lint can't tell code identifier from user-facing text.

**Why this blocks:** Running the lint on the full scope gives ~1200 "violations" most of which are code identifiers. An agent looking at the output has no signal — they'll either (a) ignore all warnings (defeats the guard) or (b) try to "fix" code identifier names (breaks the build). Either way, Phase 34 GUARD-04 produces noise, not signal.

### Test-suite coverage
`tests/checks/test_accent_lint_fr.py` = 149 lines. Grep confirms **no tests** for: NFD normalization, fullwidth, Cyrillic, ZWS, conjugations, cross-language FP, code-identifier FP, German/Spanish FP.

---

## 4. ARB parity (`arb_parity.py`)

### ICU placeholder walker edge cases (P1)

| Input | Expected | Walker output | Bug? |
|-------|----------|---------------|------|
| `{name}` | `{name}` | `{name}` | no |
| `{amount, number, currency}` | `{amount}` | `{amount}` | no |
| `{count, plural, one {1 item} other {{count} items}}` | `{count}` | `{count}` | no |
| `{sex, select, male {il} female {elle}}` | `{sex}` | `{sex}` | no |
| `{sex, select, male {{count, plural, one {il} other {ils}}} other {_}}` | `{sex, count}` | **`{sex}`** | **BUG — loses nested plural name** |
| `{count, plural, one {{foo}} other {{bar}}}` | `{count, foo, bar}` | **`{count}`** | **BUG — loses placeholders referenced inside variant bodies** |
| `use {{name}} for literal { end` | `{}` (escaped) | `{}` | no |
| `{{foo}} and {real}` | `{real}` | `{real}` | no |
| `warning: contact @admin` | `{}` | `{}` | no |

**P1:** The walker's state machine is naive about nested `{...}` inside plural/select variant bodies. If an agent writes `"msg": "{count, plural, one {{foo}} other {{bar}}}"` and FR has declared `@msg.placeholders = {count, foo, bar}`, the walker only emits `{count}` — the lint then complains that `foo` and `bar` are MISSING when in fact they ARE present in the value. Reverse scenario: if EN translates with a missing inner placeholder, the walker still only emits `{count}` so the discrepancy is invisible — **silent data loss in the check itself.**

**P2:** `nested_select_plural` has the same problem — `{sex}` is emitted but the nested `{count, plural, ...}` clause inside the male variant is not traversed as a placeholder-name scope. If an ARB's `@key.placeholders` lists both `sex` and `count`, the walker drops `count`.

### JSON / encoding (P1)

| Input | Behaviour |
|-------|-----------|
| Empty ARB `{}` (all 6 langs) | rc=0, passes with `non-@ keys=0`. False "OK". |
| UTF-8 BOM on `app_fr.arb` | rc=1 FAIL (expected behaviour, but error message is `json.JSONDecodeError: Unexpected UTF-8 BOM` — confusing diagnostic) |
| Duplicate JSON key | Silently deduped by `json.loads` — lint never sees the dup, accepts the last value. Flutter itself might warn; the lint does not. |
| Trailing comma | rc=1 FAIL (standard json parser rejects, good) |
| CRLF line endings | Tolerated (json parser handles) |

**P2 issues:**
- All-empty ARBs pass (rc=0). Phase 34's doctrine "6 ARBs parity" is technically satisfied but the check is vacuous. Should require min-key-count or warn when keyset is empty.
- Duplicate-key silent-accept is the same class of bypass as `git log` vs `git show`: two separate readings could disagree.

### Test-suite coverage
`tests/checks/test_arb_parity.py` = 180 lines. Contains `{sex, select, male {il} female {elle} other {iel}}` test. Does NOT cover: nested plural-in-select, placeholders referenced inside variant bodies, BOM handling, duplicate JSON keys, empty ARB vacuous-OK.

---

## 5. proof_of_read (`proof_of_read.py`)

### Path-normalisation evasion (P0)

Tested against a minimal fake repo at `/tmp/audit_regex/porread/repo/` with a valid `READ.md`.

| `Read:` trailer | Expected | rc | Bypass? |
|-----------------|----------|----|---------|
| `Read: .planning/phases/…/X-READ.md` (canonical) | PASS | 0 | — |
| `Read: .planning/phases/./…/X-READ.md` (./ in middle) | FAIL (spoof-hardening should reject) | **0 PASS** | **YES P1** |
| `Read: .planning/phases/../phases/…/X-READ.md` (../ traversal) | FAIL | **0 PASS** | **YES P0** |
| `Read: .planning/phases//…/X-READ.md` (double slash) | FAIL | **0 PASS** | **YES P1** |
| `Read:.planning/phases/…/X-READ.md` (no space after colon) | FAIL | 1 | no (regex catches) |
| `Read:  .planning/phases/…/X-READ.md` (double space) | PASS? | 0 PASS | — |
| `Read:\t.planning/phases/…/X-READ.md` (tab) | PASS? | 0 PASS | — |
| `Read: .planning\phases\…\X-READ.md` (Windows slashes) | FAIL | 1 | no |
| `Read: .planning/phases/fakefile.md` (symlink → `/etc/passwd`) | FAIL | 1 FAIL (unrelated — bullet check) | no (fortuitous) |

**P0 — path traversal:** `.planning/phases/../phases/…/X-READ.md` starts with `.planning/phases/` (string prefix passes the `ALLOWED_READ_PREFIX` check), but `../` escapes and re-enters. The lint uses `repo_root / read_path_str` → `Path.exists()` which normalises automatically and finds the file. An attacker could `Read: .planning/phases/../../../../../etc/passwd` — would fail existence check, but `Read: .planning/phases/../../apps/mobile/lib/main.dart` (exists) would pass the `exists()` gate and only fail the bullet check. Depending on target file content, bullet check can be spoofed (any `.md` with `- ` line will pass).

**P0 — symlink traversal:** Confirmed empirically. Created `.planning/phases/fake/link.md` as a symlink → `/tmp/audit_regex/porread/elsewhere.md` (file OUTSIDE `.planning/phases/`). Wrote a bullet into `elsewhere.md`. Result: `rc=0 PASS`. The lint does NOT resolve symlinks and check final destination.

```
rc=0 PASS
[proof_of_read] OK - Claude commit references .planning/phases/fake/link.md (1 files listed)
```

**P0 — separator flexibility:** The regex `^Read:\s+(\S+)\s*$` uses `\s+` = any whitespace including tab, multiple spaces, vertical tab. So `Read:\t.planning/phases/…` and `Read:   .planning/phases/…` all pass. Not a bypass of authorisation but a stylistic drift — would affect diff review legibility.

**P0 — TOCTOU:** Between the `Path.exists()` check and any downstream enforcement, nothing prevents the file being a race-condition hazard. Not exploitable in pre-commit context (single-process) but flagged for completeness.

### Claude trailer detection (P0)

| Trailer | `TRAILER_CLAUDE` regex | Expected | Bypass? |
|---------|-----------------------|----------|---------|
| `Co-Authored-By: Claude Sonnet 4.5 <...>` | MATCH | enforce | no |
| `Co-authored-by: Claude` (`a` lowercase) | **NOMATCH** | should enforce (git accepts) | **YES P0** |
| `co-authored-by: Claude` (all lowercase) | **NOMATCH** | should enforce (git accepts) | **YES P0** |
| `Co-Authored-By: GPT-4 <openai>` | NOMATCH | bypass expected (not Claude) | — |
| `CO-AUTHORED-BY: CLAUDE` | NOMATCH | ??? | — |
| `Co-Authored-By: Claude\nCo-Authored-By: Claude` | MATCH | — | — |
| `# Co-Authored-By: Claude` (commented-out) | NOMATCH (anchored `^`) | — | — |

**P0 — case-sensitive trailer match.** The regex `^Co-Authored-By:\s+Claude` is case-sensitive. Git itself accepts `Co-authored-by:` (lowercase `a`) — this is the canonical Git trailer format (see `git interpret-trailers`). MANY commit generators use lowercase. A Claude-coauthored commit written as `Co-authored-by: Claude …` passes the proof-of-read check **via the human-bypass path** (`if not TRAILER_CLAUDE.search(msg): return 0, ['human commit ... bypass']`).

**Evidence:** Our test showed `trailer_lowercase_a: rc=0 PASS :: human commit (no Claude trailer), bypass`. The lint actively treats these commits as human and skips enforcement. Any Claude instance that learns to write `Co-authored-by:` (lowercase) bypasses D-17.

**Why P0:** this is a doctrine bypass, not an edge case. Git's documented trailer canonical form is lowercase. Phase 34 D-17 silently lets this through.

### Bullet requirement (P1)

`bullet_lines = [line for line in content.splitlines() if line.strip().startswith('- ')]` — satisfied by ANY markdown line starting with `- `. Empty bullets (`- `), bullets in a comment block (`<!-- - -->`), bullets inside code fences, bullets with placeholder paths (`- TODO`) all satisfy. D-18 says format is `- <path> - <why read>` but enforcement is "has at least one `- ` line". Weak.

### Test-suite coverage
`tests/checks/test_proof_of_read.py` = 166 lines. Grep confirms no tests for: path traversal, symlink redirect, lowercase trailer, tab separator, commented trailer, weak-bullet content.

---

## 6. Cross-cutting

### Encoding robustness
None of the 5 lints explicitly handle UTF-8 BOM. `accent_lint_fr` uses `errors="ignore"` (tolerant); `arb_parity` uses `json.load` (fails BOM); `no_hardcoded_fr` uses `errors="ignore"` (tolerant); `proof_of_read` uses `errors="ignore"` (tolerant); `no_bare_catch` reads from `git show :path` (binary-safe). Inconsistent — an ARB with BOM breaks parity, but a Dart with BOM is silently accepted.

### CRLF
All 5 lints use `str.splitlines()` which handles CR, CRLF, LF uniformly. Line numbers match git's view (tested).

### Large files
`_collect_paths` in both `accent_lint_fr` and `no_hardcoded_fr` does `rglob("*")` then reads each into memory via `read_text`. No size guard. A 100 MB generated file anywhere under `apps/mobile/lib` will be loaded; combined with `_TEXT_CAPITALISED` ReDoS, a malicious commit including a hand-crafted 10 MB file with `Text('A` + 10M × `a` would freeze pre-commit for tens of minutes.

### Binary embedding
Both mobile lints rely on `suffix in {.dart, .arb, ...}` whitelist. If an agent commits a `.dart` file that is actually binary, `errors="ignore"` prevents crash but regex behaviour is undefined (may match on random byte sequences).

---

## Findings by severity

### P0 — ship-blocking bypasses (15)
1. `no_bare_catch` Dart: `catch (ex) {}` not in bound-name alternation.
2. `no_bare_catch` Dart: `catch (exception) {}` not in alternation.
3. `no_bare_catch` Dart: `catch (e, stack) {}` two-arg form not matched.
4. `no_bare_catch` Dart: `catch (e) { // comment only }` body-breaking bypass.
5. `no_bare_catch` Dart: `catch (e) { return; }` non-rethrow non-log body bypass.
6. `no_bare_catch` Py: `except: pass` one-liner never matches (`$` anchor).
7. `no_bare_catch` Py: `except Exception: pass` one-liner never matches.
8. `no_hardcoded_fr`: all-caps `Text('BONJOUR')` whitelisted via `_ACRONYM`.
9. `no_hardcoded_fr`: short `Text('Oui')` below 6-char tail.
10. `accent_lint_fr`: fullwidth lookalikes bypass.
11. `accent_lint_fr`: Cyrillic homoglyphs bypass.
12. `accent_lint_fr`: Zero-width-space injection bypasses `\b`.
13. `proof_of_read`: `../` path traversal in `Read:` trailer accepted.
14. `proof_of_read`: symlink inside `.planning/phases/` redirects to any file on disk.
15. `proof_of_read`: `Co-authored-by:` (Git-canonical lowercase) treated as human commit.

### P1 — regex gaps, exploitable but noisier (10)
- `no_bare_catch` Dart: multi-line `catch` declaration misses.
- `no_bare_catch` Py: typed `except X as e:` with `pass` not flagged (policy question).
- `no_hardcoded_fr`: `_QUOTED_ACCENT` false-positives on cross-language (ES/DE) accented strings.
- `no_hardcoded_fr`: ReDoS — `_TEXT_CAPITALISED` quadratic on unterminated `Text('A…`. 50 KB = 10 s.
- `no_hardcoded_fr`: IGNORE_MARKER `AppLocalizations` on same-line exempts ALL content on that line.
- `accent_lint_fr`: conjugation false-negatives (~90% of real FR flattened forms bypass).
- `accent_lint_fr`: wrong-language false positives (`Regler`=DE slider, `deja`=ES leaves).
- `accent_lint_fr`: 1011 `prevoyance` hits dominated by code identifiers, FP rate ~64%.
- `arb_parity`: walker loses nested plural placeholder names inside select variants.
- `arb_parity`: walker loses placeholder references inside variant bodies (`one {{foo}} other {{bar}}`).

### P2 — docs / cosmetic (5)
- `no_bare_catch` Dart: `async *` look-back is 10 lines — long generators may false-positive.
- `no_hardcoded_fr`: `title: 'abc'` lowercase bypasses; pattern requires `[A-Z][a-z]+`.
- `arb_parity`: all-empty ARBs (`{}`) pass rc=0 as "parity OK".
- `arb_parity`: duplicate JSON keys silently deduped; lint unaware.
- `proof_of_read`: bullet check satisfied by any `- ` line; D-18 format not enforced.

---

## Observations on test-suite shape

Counted grep matches for each attack vector across `tests/checks/*.py`:

| Attack vector | Tested? |
|---|---|
| Dart `catch (ex)` / `(exception)` | NO |
| Dart `catch (e, stack)` | NO |
| Dart comment-only or `return;` body | NO |
| Dart multi-line `catch` | NO |
| Python `except: pass` one-liner | NO |
| Python typed `except X as e:` with pass | NO |
| NFC/NFD/fullwidth/Cyrillic/ZWS bypass | NO |
| FR conjugations (`creerais`, `securites`) | NO |
| Wrong-language FP (`Regler` DE, `deja` ES) | NO |
| Dart all-caps `Text('BONJOUR')` | NO |
| Dart short `Text('Oui')` | NO |
| ARB nested-plural-in-select walker | PARTIAL (1 case, different shape) |
| ARB placeholder referenced inside variant body | NO |
| ARB BOM / duplicate-key / empty | NO |
| proof_of_read `../` traversal | NO |
| proof_of_read symlink target outside phases | NO |
| proof_of_read `Co-authored-by:` lowercase | NO |
| ReDoS timing on `_TEXT_CAPITALISED` | NO |

**14 of 14 attack vectors tested empirically here are uncovered by the existing test suites.** The tests defend the canonical-form path; adversarial paths are entirely unguarded.

---

## Appendix A — empirical FP catalogue per stem (accent_lint_fr)

Full scan of `apps/mobile/lib` + `services/backend/app` + `tools` (Dart + Py + ARB + MD, with EXCLUDE_SUBSTRINGS applied):

```
stem         total   likely-FP  likely-TP  FP%
prevoyance   1011    ~643       ~361       64%   (code identifiers)
eclairage    49      ~35        ~14        71%   (route paths)
securite     37      ~18        ~19        49%   (section comments)
deja         35      ~10        ~25        29%   (includes ES l10n)
decouvrir    28      ~0         ~28        ~0%   (real flattened FR)
creer        21      ~2         ~19        ~10%  (real flattened FR)
cle          20      ~15        ~5         75%   (BYOK doc + var names)
regler       7       ~6         ~1         86%   (German Regler!!!)
recu         5       ~3         ~2         60%
elaborer     4       ~2         ~2         50%
liberer      3       ~3         0          100%  (test fixtures only)
preter       3       ~3         0          100%  (test fixtures only)
realiser     3       ~3         0          100%  (test fixtures only)
reperer      2       ~2         0          100%  (test fixtures only)
```

Heuristic used for FP classification: matches in (a) identifier paths like `'prevoyance.xxx'`, (b) ICU-placeholder names in generated `app_localizations_*.dart`, (c) route path strings, (d) non-FR ARB file, (e) conftest/fixture file. The heuristic is conservative — actual FP% is likely higher.

**Implication:** the lint as-shipped would fire ~1200 violations on the current codebase. The TP:FP ratio is roughly 1:2 for the most common stem (`prevoyance`). Phase 34's ship gate "all guards green" cannot be met with the current regexes without either (a) a mass noise-ack, or (b) an allowlist the size of the violations list — either of which defeats the mechanical-guard premise.

---

## Appendix B — fixtures created

All in `/tmp/audit_regex/`:
- 10 Dart bare-catch fixtures (`t1_*.dart` … `t10_*.dart`)
- 11 hardcoded-FR fixtures (`frtest/t_*.dart`)
- 3 Unicode normalisation fixtures (`nfc_*.txt`, `nfd_*.txt`)
- 3 Unicode homoglyph fixtures (`fullwidth.txt`, `cyrillic.txt`, `zws.txt`, `wordboundary.txt`)
- proof_of_read: 17 trailer/path variants via `porread_test.py`
- proof_of_read: symlink attack via `symlink_attack.py`
- arb_parity: 12 placeholder-walker cases + 4 malformed-JSON cases via `arb_tests.py`
- accent_lint_fr: FP scan via `fp_scan.py`

All fixtures are reproducible; audit did NOT modify any lint script, regex, or existing test file.

---

## Recommended remediations (summary, no code changes performed)

Order of priority follows severity:
1. **proof_of_read**: case-insensitive `Co-[Aa]uthored-[Bb]y:` trailer match; `Path.resolve()` then check that the resolved path is inside `repo_root / '.planning/phases/'` (defeats `../` and symlink bypass); enforce D-18 bullet format `- <path> - <reason>` via regex, not just `- ` prefix.
2. **no_bare_catch Dart**: broaden alternation to `[\w]+` with a specific ban on named tuples; match `catch (e, _) {…}` with two-arg form; check body content post-match for meaningful statements (not just `\{\s*\}`); add `catch (e) { return` and `catch (e) { // ` to explicit patterns.
3. **no_bare_catch Py**: drop `$` anchor OR add separate patterns for `except(?:\s+\w+(?:\s+as\s+\w+)?)?\s*:\s*pass\s*$`.
4. **no_hardcoded_fr**: remove `_ACRONYM` whitelist (or scope it to files that never have FR text); lower `_TEXT_CAPITALISED` tail threshold from 5 to 1 char; add per-file size cap to prevent ReDoS; restrict `_QUOTED_ACCENT` to known-FR-context files only.
5. **accent_lint_fr**: Unicode-normalise input (`unicodedata.normalize('NFKC', line)`) BEFORE regex match — defeats fullwidth + Cyrillic + NFD in one move; strip zero-width chars; add code-identifier filter (exclude lines matching `['"].*\.\w+['"]` like field paths, `String\s+\w+`, `[A-Za-z]+:\s*` ICU names); skip non-FR ARB files when scanning for FR stems.
6. **arb_parity**: fix walker to recurse into variant bodies and emit placeholder names found anywhere within the ICU tree; add BOM tolerance; warn on duplicate JSON keys via `object_pairs_hook`; reject all-empty ARBs.

No changes made per audit-only mandate.

#!/usr/bin/env python3
"""GUARD-02 — refuse added lines containing bare `catch (e) {}` Dart /
`except Exception:` Python with no log/rethrow.

D-07: scans ONLY added lines of the staged diff, not full file content.
Decouples Phase 34 from FIX-05 (Phase 36) migration of 388 existing catches.

D-06 exemptions: test/integration_test/tests paths, Dart `async *` generators,
inline override `// lefthook-allow:bare-catch: <reason>` (>=3 words). Override
accepted on SAME line or IMMEDIATELY PRECEDING line (mirrors Plan 34-03).

Exit 0 clean / 1 violation(s) (stderr: `[no_bare_catch] path:line: snippet`).

Technical English diagnostics (M-1 carve-out, RESEARCH Pitfall 8).
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import List, Optional, Tuple

# --- Patterns (RESEARCH Pattern 3, extended by Phase 34.1 Fix #3 ---------
# ---  amends D-05 per audits/01-ADVERSARIAL.md + audits/05-REGEX) --------
#
# Phase 34.1: widen Dart identifier alternation from (e|_|err|error) to any
# valid Dart identifier -- audit 01 showed `catch (ex)` / `catch (exception)`
# bypass. Also allow optional second arg for `catch (e, stack)` (Dart idiom
# for stack trace capture; still bare if body is empty).
# Python: add one-liner `except ...: pass` patterns -- audit 05 demonstrated
# that `except: pass` (the MOST common bare-except form) slipped through the
# `$`-anchored empty-body regex entirely.

_DART_IDENT = r'[a-zA-Z_][a-zA-Z0-9_]*'

DART_BARE_CATCH = [
    # `} catch (ident) {}` or `} catch (ident, stack) {}` -- empty body,
    # any identifier name, optional 2nd stack-trace arg.
    re.compile(
        r'}\s*catch\s*\(\s*' + _DART_IDENT +
        r'(?:\s*,\s*' + _DART_IDENT + r')?\s*\)\s*\{\s*\}'
    ),
    # `on TYPE catch (ident) {}` typed catch with empty body.
    re.compile(
        r'on\s+' + _DART_IDENT + r'\s+catch\s*\(\s*' + _DART_IDENT +
        r'(?:\s*,\s*' + _DART_IDENT + r')?\s*\)\s*\{\s*\}'
    ),
]
DART_LOG_TOKENS = (
    'Sentry.captureException', 'Sentry.captureMessage', 'SentryBreadcrumb',
    'debugPrint(', 'print(',
    'log(', 'logger.',
    'rethrow', 'throw',
    'FirebaseCrashlytics',
)

PY_BARE_EXCEPT = [
    # Empty-body forms (body on next line; surrounding-log check applies).
    re.compile(r'^\s*except\s*:\s*$'),
    re.compile(r'^\s*except\s+Exception\s*:\s*$'),
    re.compile(r'^\s*except\s+BaseException\s*:\s*$'),
    # Typed catch empty body (Phase 34.1): `except ValueError:`.
    re.compile(r'^\s*except\s+\w[\w\.]*\s*:\s*$'),
    # Typed catch with `as` binding empty body: `except Exception as e:`.
    re.compile(r'^\s*except\s+\w[\w\.]*\s+as\s+\w+\s*:\s*$'),
    # Tuple catch empty body: `except (ValueError, TypeError):` or
    # `except (ValueError, TypeError) as e:`.
    re.compile(r'^\s*except\s+\([^)]*\)(?:\s+as\s+\w+)?\s*:\s*$'),
    # One-liner same-line `pass` forms (Phase 34.1 Fix #3, audit 05 P0):
    # `except: pass`, `except Exception: pass`, `except Exception as e: pass`,
    # `except (A, B): pass`, `except (A, B) as e: pass`, optional trailing
    # comment. Covers the canonical Python bare-except in the wild.
    re.compile(r'^\s*except(?:\s+\w[\w\.]*(?:\s+as\s+\w+)?)?\s*:\s*pass\s*(?:#.*)?$'),
    re.compile(r'^\s*except\s+\([^)]*\)(?:\s+as\s+\w+)?\s*:\s*pass\s*(?:#.*)?$'),
]
PY_LOG_TOKENS = (
    'logger.', 'logging.', 'log.',
    'sentry_sdk.capture', 'sentry_sdk.push_scope',
    'raise', 'print(',
)

# Override markers -- accepted on the same line as the bare-catch OR on the
# immediately preceding line. Reason length is enforced in
# `_has_valid_override` (>=3 whitespace-separated words per D-06).
OVERRIDE_DART = re.compile(r'//\s*lefthook-allow:\s*bare-catch:\s*(.+)')
OVERRIDE_PY   = re.compile(r'#\s*lefthook-allow:\s*bare-catch:\s*(.+)')

# D-06 authorises EXACTLY these four prefixes. Do NOT add a broad `tests/`
# entry -- it would exempt any future top-level `tests/` directory beyond
# scope (W1 guard).
EXEMPT_PATH_PREFIXES = (
    'apps/mobile/test/',
    'apps/mobile/integration_test/',
    'services/backend/tests/',
    'tests/checks/fixtures/',
)


# --- Diff parser (RESEARCH Pattern 2, VERIFIED /tmp/gittest 2026-04-22) --
# Invokes `git diff --staged --unified=0 --no-renames --diff-filter=AM`
# to produce the diff whose added lines drive the D-07 diff-only scan.
_HUNK = re.compile(r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@')


def _run_git(cmd: List[str], repo_root: Optional[Path]) -> subprocess.CompletedProcess:
    kwargs = {'capture_output': True, 'text': True, 'check': False}
    if repo_root is not None:
        kwargs['cwd'] = str(repo_root)
    return subprocess.run(cmd, **kwargs)


def get_added_lines(file_path: str, repo_root: Optional[Path] = None) -> List[Tuple[int, str]]:
    """Return (new_line_number, content) for lines ADDED in the staged diff.

    Pure read-only (RESEARCH Pattern 6). Command used:
    `git diff --staged --unified=0 --no-renames --diff-filter=AM -- <path>`.
    """
    result = _run_git(
        ['git', 'diff', '--staged', '--unified=0', '--no-renames',
         '--diff-filter=AM', '--', file_path],
        repo_root,
    )
    added: List[Tuple[int, str]] = []
    cur_new: Optional[int] = None
    for line in result.stdout.splitlines():
        m = _HUNK.match(line)
        if m:
            cur_new = int(m.group(1))
            continue
        if cur_new is None or line.startswith('+++') or line.startswith('---') or line.startswith('\\'):
            continue
        if line.startswith('+'):
            added.append((cur_new, line[1:]))
            cur_new += 1
        elif not line.startswith('-'):
            cur_new += 1
    return added


def is_exempt_path(file_path: str) -> bool:
    normalized = file_path.replace('\\', '/').lstrip('./')
    return any(normalized.startswith(prefix) for prefix in EXEMPT_PATH_PREFIXES)


def is_in_async_star(full_text: str, line_no: int) -> bool:
    """Line_no within a Dart `async *` body? Heuristic (D-06): look 10 lines back."""
    lines = full_text.splitlines()
    start = max(0, line_no - 10)
    return any(re.search(r'\basync\s*\*', c) for c in lines[start:line_no])


def has_surrounding_log_tokens(full_text: str, line_no: int, tokens: Tuple[str, ...]) -> bool:
    """Check if any log/raise token appears within the 5 lines following line_no (1-indexed)."""
    lines = full_text.splitlines()
    start = max(0, line_no - 1)
    window = '\n'.join(lines[start:min(len(lines), line_no + 5)])
    return any(tok in window for tok in tokens)


def _has_valid_override(line: str, is_python: bool) -> bool:
    """Line carries `lefthook-allow:bare-catch:` marker with >=3-word reason (D-06)."""
    pat = OVERRIDE_PY if is_python else OVERRIDE_DART
    m = pat.search(line)
    return bool(m and len(m.group(1).strip().split()) >= 3)


def _override_in_preceding(lines: List[str], added_line_no: int, is_python: bool) -> bool:
    """Valid override on the line IMMEDIATELY PRECEDING added_line_no (1-indexed)?

    `lines` is the full staged-file content split via `str.splitlines()` (0-indexed).
    Converts 1-indexed new-file line -> 0-indexed list index, then steps back one.
    """
    if added_line_no < 2:
        return False
    idx_prev = added_line_no - 2
    if idx_prev < 0 or idx_prev >= len(lines):
        return False
    return _has_valid_override(lines[idx_prev], is_python=is_python)


def _scan_added(
    added: List[Tuple[int, str]],
    full_text: str,
    file_path: str,
    *,
    is_python: bool,
    patterns: List[re.Pattern],
    tokens: Tuple[str, ...],
    diag_suffix: str,
) -> List[str]:
    violations: List[str] = []
    lines = full_text.splitlines()
    for line_no, content in added:
        # Accept override on same line OR on the immediately preceding line.
        if _has_valid_override(content, is_python=is_python) or _override_in_preceding(lines, line_no, is_python=is_python):
            continue
        if not is_python and is_in_async_star(full_text, line_no):
            continue
        for pat in patterns:
            if pat.search(content):
                if has_surrounding_log_tokens(full_text, line_no, tokens):
                    continue
                violations.append(
                    f'[no_bare_catch] {file_path}:{line_no}: {content.strip()[:120]} '
                    f'({diag_suffix})'
                )
                break
    return violations


def scan_dart_added(added, full_text, file_path):
    return _scan_added(added, full_text, file_path, is_python=False,
                       patterns=DART_BARE_CATCH, tokens=DART_LOG_TOKENS,
                       diag_suffix='bare-catch without log/rethrow')


def scan_python_added(added, full_text, file_path):
    return _scan_added(added, full_text, file_path, is_python=True,
                       patterns=PY_BARE_EXCEPT, tokens=PY_LOG_TOKENS,
                       diag_suffix='bare-except without log/raise')


def read_staged_file(file_path: str, repo_root: Optional[Path] = None) -> str:
    """Read the staged (index) content of a file (post-diff view)."""
    r = _run_git(['git', 'show', f':{file_path}'], repo_root)
    if r.returncode != 0:
        path = Path(repo_root or '.') / file_path
        return path.read_text(encoding='utf-8', errors='ignore') if path.exists() else ''
    return r.stdout


def process_file(file_path: str, repo_root: Optional[Path] = None) -> List[str]:
    if is_exempt_path(file_path):
        return []
    added = get_added_lines(file_path, repo_root=repo_root)
    if not added:
        return []
    full_text = read_staged_file(file_path, repo_root=repo_root)
    if file_path.endswith('.dart'):
        return scan_dart_added(added, full_text, file_path)
    if file_path.endswith('.py'):
        return scan_python_added(added, full_text, file_path)
    return []


def list_staged_files(repo_root: Optional[Path] = None) -> List[str]:
    r = _run_git(
        ['git', 'diff', '--staged', '--name-only', '--diff-filter=AM',
         '--', '*.dart', '*.py'],
        repo_root,
    )
    return [ln for ln in r.stdout.splitlines() if ln.strip()]


def main() -> int:
    ap = argparse.ArgumentParser(description='GUARD-02 -- diff-only bare-catch lint (Dart + Python).')
    ap.add_argument('--staged', action='store_true', help='Scan all staged Dart+Python files.')
    ap.add_argument('--file', nargs='*', default=[], help='Scan specific files (self-test + pytest).')
    ap.add_argument('--repo-root', default=None, help='Git repo root (test harness).')
    args = ap.parse_args()

    repo_root = Path(args.repo_root) if args.repo_root else None
    if args.staged:
        files = list_staged_files(repo_root=repo_root)
    elif args.file:
        files = args.file
    else:
        ap.error('must pass --staged or --file <paths>')
        return 2

    all_violations: List[str] = []
    for f in files:
        all_violations.extend(process_file(f, repo_root=repo_root))
    for v in all_violations:
        print(v, file=sys.stderr)
    if all_violations:
        print(
            f'[no_bare_catch] FAIL -- {len(all_violations)} bare-catch violation(s) '
            f'introduced by this diff. Add logging/raise or '
            f'`// lefthook-allow:bare-catch: <reason>`.',
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())

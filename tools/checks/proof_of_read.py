#!/usr/bin/env python3
"""GUARD-06 - proof-of-read via commit-msg hook.

Per CONTEXT 34-CONTEXT.md D-16/D-17/D-18: Claude-coauthored commits
must reference a `.planning/phases/<phase>/<padded>-READ.md` file (D-16)
that lists the files the agent consulted (D-18 bullet format).

D-27 AMENDMENT (Plan 34-05, RESEARCH Open Question 1 Option A): Phase
34 permits ONE `commit-msg:` lefthook block, dedicated to this script.
No other lint migrates to commit-msg. Required because D-17 cannot run
pre-commit (message not yet written) nor post-commit (too late).

Hook invocation: lefthook passes the path to `.git/COMMIT_EDITMSG` via
the `{1}` placeholder to `--commit-msg-file`.

Bypass (D-17): commits WITHOUT `Co-Authored-By: Claude` trailer bypass
automatically (treated as human commits).

Security (T-34-SPOOF-01, STRIDE Tampering): `Read:` path MUST begin with
`.planning/phases/` to prevent attacker-spoofed references to `/dev/null`,
`/etc/passwd`, or unrelated real files. Hardcoded prefix check.

Exit codes: 0 = pass (human OR valid proof-of-read), 1 = fail, 2 = usage.

Technical English only (M-1 carve-out + Pitfall 8 self-compliance).
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import List, Tuple

# --- Trailer detection (RESEARCH Pattern 5 + Example 4) ------------------
# MULTILINE so `^` anchors to line starts (commit trailers live on own lines).
TRAILER_CLAUDE = re.compile(r'^Co-Authored-By:\s+Claude', re.MULTILINE)
TRAILER_READ = re.compile(r'^Read:\s+(\S+)\s*$', re.MULTILINE)

# D-16: Read: path must point inside .planning/phases/ (T-34-SPOOF-01
# mitigation - prevents attacker-spoofed references to unrelated files).
ALLOWED_READ_PREFIX = '.planning/phases/'


def check_commit_msg(msg: str, repo_root: Path) -> Tuple[int, List[str]]:
    """Validate a commit message for GUARD-06 compliance.

    Returns (exit_code, messages).
    """
    messages: List[str] = []

    # Empty / whitespace-only message -> pass (nothing to check).
    # Git aborts commit on empty message anyway; our lint is a no-op.
    if not msg.strip():
        return 0, []

    if not TRAILER_CLAUDE.search(msg):
        # D-17 automatic bypass for human commits.
        return 0, ['[proof_of_read] OK - human commit (no Claude trailer), bypass']

    match = TRAILER_READ.search(msg)
    if not match:
        messages.append(
            '[proof_of_read] FAIL - Claude-coauthored commit missing `Read:` trailer.'
        )
        messages.append(
            '  Required format: `Read: .planning/phases/<phase>/<padded>-READ.md`'
        )
        messages.append('  Per CONTEXT 34-CONTEXT.md D-16 / D-17.')
        return 1, messages

    read_path_str = match.group(1).strip()

    # T-34-SPOOF-01: reject any path that does not begin with the
    # authorised prefix. Absolute paths (/dev/null, /etc/passwd) and
    # unrelated top-level files (README.md) are blocked by this check.
    if not read_path_str.startswith(ALLOWED_READ_PREFIX):
        messages.append(
            f'[proof_of_read] FAIL - Read: path must start with '
            f'`{ALLOWED_READ_PREFIX}` (T-34-SPOOF-01), got: {read_path_str}'
        )
        return 1, messages

    read_path = repo_root / read_path_str
    if not read_path.exists():
        messages.append(
            f'[proof_of_read] FAIL - Read: path does not exist on disk: '
            f'{read_path_str}'
        )
        return 1, messages

    # D-18: READ.md must contain at least one `- ` bullet line (format is
    # `- <path> - <why read>`). No bullets = the agent skipped writing a
    # real receipt and shipped an empty shell.
    content = read_path.read_text(encoding='utf-8', errors='ignore')
    bullet_lines = [
        line for line in content.splitlines()
        if line.strip().startswith('- ')
    ]
    if not bullet_lines:
        messages.append(
            f'[proof_of_read] FAIL - {read_path_str} has no `- <path>` bullet '
            f'entries (D-18 format: `- <path> - <why read>`).'
        )
        return 1, messages

    messages.append(
        f'[proof_of_read] OK - Claude commit references {read_path_str} '
        f'({len(bullet_lines)} files listed)'
    )
    return 0, messages


def main() -> int:
    ap = argparse.ArgumentParser(
        description='GUARD-06 proof-of-read commit-msg hook (D-16/D-17/D-18).',
    )
    ap.add_argument(
        '--commit-msg-file',
        required=True,
        help='.git/COMMIT_EDITMSG path (lefthook {1} placeholder).',
    )
    ap.add_argument(
        '--repo-root',
        default='.',
        help='Git repo root (default cwd; tests pass tmp dir).',
    )
    args = ap.parse_args()

    msg_path = Path(args.commit_msg_file)
    if not msg_path.exists():
        print(
            f'[proof_of_read] FAIL - commit-msg file not found: {msg_path}',
            file=sys.stderr,
        )
        return 1

    msg = msg_path.read_text(encoding='utf-8', errors='ignore')
    rc, messages = check_commit_msg(msg, Path(args.repo_root).resolve())
    for m in messages:
        stream = sys.stderr if '[proof_of_read] FAIL' in m else sys.stdout
        print(m, file=stream)
    return rc


if __name__ == '__main__':
    sys.exit(main())

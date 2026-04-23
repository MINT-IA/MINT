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
# Phase 34.1 Fix #4: IGNORECASE -- Git canonical lowercase `Co-authored-by:`
# was treated as human commit (entire doctrine bypassed). audits/01 + 05 P0.
TRAILER_CLAUDE = re.compile(r'^Co-Authored-By:\s+Claude', re.MULTILINE | re.IGNORECASE)
TRAILER_READ = re.compile(r'^Read:\s+(\S+)\s*$', re.MULTILINE)

# D-16: Read: path must point inside .planning/phases/ (T-34-SPOOF-01
# mitigation - prevents attacker-spoofed references to unrelated files).
ALLOWED_READ_PREFIX = '.planning/phases/'


def _trailer_block(msg: str) -> str:
    """Extract the last paragraph of a commit message (Git trailer convention).

    Phase 34.1 Fix #4 (audits/01 P0): trailers live in the FINAL paragraph
    after the last blank line. The original code scanned the whole message
    with MULTILINE anchors, so a `Read:` on the subject line or buried in
    the body paragraph would pass. Restricting the search to the last
    paragraph enforces the trailer convention and defeats that bypass.
    """
    paragraphs = [p for p in msg.strip().split('\n\n') if p.strip()]
    return paragraphs[-1] if paragraphs else ''


def check_commit_msg(msg: str, repo_root: Path) -> Tuple[int, List[str]]:
    """Validate a commit message for GUARD-06 compliance.

    Returns (exit_code, messages).
    """
    messages: List[str] = []

    # Empty / whitespace-only message -> pass (nothing to check).
    # Git aborts commit on empty message anyway; our lint is a no-op.
    if not msg.strip():
        return 0, []

    # Phase 34.1 Fix #4: only scan the Git trailer block (last paragraph).
    trailer_block = _trailer_block(msg)

    if not TRAILER_CLAUDE.search(trailer_block):
        # D-17 automatic bypass for human commits.
        return 0, ['[proof_of_read] OK - human commit (no Claude trailer), bypass']

    match = TRAILER_READ.search(trailer_block)
    if not match:
        messages.append(
            '[proof_of_read] FAIL - Claude-coauthored commit missing `Read:` trailer.'
        )
        messages.append(
            '  Required format: `Read: .planning/phases/<phase>/<padded>-READ.md`'
        )
        messages.append(
            '  Trailer must be in the FINAL paragraph (Git trailer convention).'
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

    # Phase 34.1 Fix #4 (audits/01 P0 + P2): canonicalise the path --
    # resolve `..` traversal and symlinks -- then re-verify the prefix.
    # Original code accepted `.planning/phases/../../etc/passwd` and
    # symlinks pointing outside the allowed prefix.
    read_path_raw = repo_root / read_path_str
    try:
        read_path = read_path_raw.resolve(strict=False)
    # lefthook-allow:bare-catch: structured error surfaced via (rc, messages) return contract
    except (OSError, RuntimeError) as exc:
        messages.append(
            f'[proof_of_read] FAIL - Read: path resolution failed '
            f'({type(exc).__name__}): {read_path_str}'
        )
        return 1, messages

    allowed_root = (repo_root / ALLOWED_READ_PREFIX).resolve(strict=False)
    try:
        read_path.relative_to(allowed_root)
    # lefthook-allow:bare-catch: relative_to raises ValueError on escape, caught deliberately
    except ValueError:
        messages.append(
            f'[proof_of_read] FAIL - Read: resolved path escapes '
            f'`{ALLOWED_READ_PREFIX}` after canonicalisation: '
            f'{read_path_str} -> {read_path}'
        )
        return 1, messages

    # Phase 34.1 Fix #4 (audits/01 P2): IsADirectoryError crash when
    # Read: points to a directory. Check for regular file explicitly.
    if not read_path.is_file():
        if read_path.is_dir():
            reason = 'is a directory, not a regular file'
        elif not read_path.exists():
            reason = 'does not exist on disk'
        else:
            reason = 'is a special file (socket/device/broken symlink)'
        messages.append(
            f'[proof_of_read] FAIL - Read: path {reason}: {read_path_str}'
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

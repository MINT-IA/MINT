#!/usr/bin/env python3
"""Phase 95 Plan 95-04 / TEST-05 — VCR cassette hygiene lint.

Stdlib-only. Walks `services/backend/tests/cassettes/**/*.yaml` and
fails if any committed cassette leaks a secret, an API key, PII, or a
banned term from `app.services.coach.compliance_guard.BANNED_TERMS`.

Defense-in-depth gate — runs ALONGSIDE the `vcr_config` fixture's
`filter_headers` + `before_record_response` PII scrub. The fixture
hooks redact at record time; this lint catches regressions in the
fixture (e.g. a contributor adds a new redact rule wrong, or a test
records via a path the hooks don't cover).

Usage:
    python3 tools/checks/cassette_hygiene_lint.py
    python3 tools/checks/cassette_hygiene_lint.py --target <path-to-yaml>
    python3 tools/checks/cassette_hygiene_lint.py --self-test

Exit codes:
    0 — all cassettes clean.
    1 — at least one cassette failed a hygiene check (offending file +
        line + reason printed to stdout; the message is also emitted
        as `::error file=...,line=...::` for GitHub Actions annotation).
    2 — usage error (bad --target, etc).

Karpathy 1: assumptions stated up-front.
- Only `.yaml` files under the cassette dir are scanned (VCR default
  layout). `.gitkeep` and `README.md` are ignored.
- Banned terms are extracted from `compliance_guard.py` BANNED_TERMS
  literal via regex parse — the lint stays hermetic (no `import`).
  Updates to BANNED_TERMS automatically flow into the lint on the
  next CI run.
- Negation context (« pas garanti », « kein garantierter », « non
  garantito ») is allow-listed via a small allow-pattern. Mirrors
  the policy used by `tools/checks/banned_terms_arb.py`.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path
from typing import Iterable

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[2]
CASSETTE_DIR = REPO_ROOT / "services" / "backend" / "tests" / "cassettes"
COMPLIANCE_GUARD_PATH = (
    REPO_ROOT
    / "services"
    / "backend"
    / "app"
    / "services"
    / "coach"
    / "compliance_guard.py"
)


# ---------------------------------------------------------------------------
# Secret patterns — every cassette MUST be free of these
# ---------------------------------------------------------------------------

SECRET_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    # Anthropic API key
    ("anthropic_api_key", re.compile(r"sk-ant-api[A-Za-z0-9_\-]{20,}")),
    # OpenAI API key (defensive — even though TEST-05 scope is Anthropic)
    ("openai_api_key", re.compile(r"sk-[A-Za-z0-9]{32,}")),
    # JWT bearer (header.payload.signature)
    ("jwt_bearer", re.compile(r"eyJ[A-Za-z0-9_\-]{8,}\.eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{6,}")),
    # Generic "Bearer <token>" with non-trivial token
    ("bearer_token", re.compile(r"Bearer\s+[A-Za-z0-9_\-\.]{16,}")),
    # Sentry DSN
    ("sentry_dsn", re.compile(r"https://[a-f0-9]{32}@[a-zA-Z0-9.\-]+\.ingest\.sentry\.io/\d+")),
    # AWS access key id
    ("aws_access_key_id", re.compile(r"AKIA[0-9A-Z]{16}")),
    # Swiss IBAN — 21 chars total, leading "CH"
    ("ch_iban", re.compile(r"\bCH\d{2}[\s\-]?(?:\d{4}[\s\-]?){4}\d{1}\b")),
    # Swiss AVS / AHV new format 756.####.####.##
    ("ch_ahv", re.compile(r"\b756\.\d{4}\.\d{4}\.\d{2}\b")),
    # Credit card (16 digits, possibly grouped)
    ("credit_card", re.compile(r"\b(?:\d{4}[\s\-]?){3}\d{4}\b")),
]


# Header redact contract: if `authorization:` / `x-api-key:` /
# `anthropic-api-key:` appears at all, the value MUST be the literal
# REDACTED. Anything else is a leak.
REDACTED_REQUIRED_HEADERS = [
    "authorization",
    "x-api-key",
    "anthropic-api-key",
    "anthropic-version",
    "x-anonymous-session",
    "cookie",
    "set-cookie",
]
REDACT_OK_VALUES = {"REDACTED", "DUMMY", "MASKED", "[REDACTED]"}


# Banned-term negation allow-list — "pas X" / "kein X" / "non X" etc.
# Mirrors banned_terms_arb.py policy. Lower-cased + accent-insensitive
# at match time; the negation prefix MUST appear within ~24 chars
# before the banned term to count as legitimate negation context.
NEGATION_PREFIXES = [
    # FR
    "pas ", "non ", "jamais ", "aucun ", "aucune ", "ni ", "sans ",
    # DE
    "kein ", "keine ", "nicht ",
    # IT
    "non ", "mai ", "nessuno ", "nessuna ", "senza ",
    # EN (rare, but sometimes appears in mixed-locale prompts)
    "not ", "never ", "no ",
]


# ---------------------------------------------------------------------------
# Banned-term extraction (hermetic — regex parse, no import)
# ---------------------------------------------------------------------------


def extract_banned_terms(compliance_guard_src: str) -> list[str]:
    """Pull the BANNED_TERMS list literal out of compliance_guard.py.

    Returns the list of term strings (lower-cased). Tolerates inline
    comments, trailing commas, and the `# NOTE: …` block inside the
    list. Falls back to a built-in floor list if the file can't be
    parsed (defensive — the lint must NOT silently skip on parse fail).
    """
    fallback = [
        "garanti", "garantie", "garantis", "garanties",
        "optimal", "optimale", "optimaux", "optimales",
        "meilleur", "meilleure", "meilleurs", "meilleures",
        "parfait", "parfaite", "parfaits", "parfaites",
        "sicher", "garantiert", "optimal", "beste",
        "migliore", "ottimale", "garantito", "perfetto",
        "best", "guaranteed",
    ]
    match = re.search(
        r"BANNED_TERMS\s*=\s*\[(.*?)^\s*\]",
        compliance_guard_src,
        flags=re.DOTALL | re.MULTILINE,
    )
    if not match:
        sys.stderr.write(
            "[cassette_hygiene_lint] WARN — BANNED_TERMS literal not "
            "matched in compliance_guard.py; using built-in fallback list.\n"
        )
        return fallback
    body = match.group(1)
    terms: list[str] = []
    for line in body.splitlines():
        # Drop comment-only lines.
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        # Strip trailing comment.
        no_comment = re.sub(r"#.*$", "", stripped).strip()
        # Match "..." or '...' string literals (one per line in
        # compliance_guard.py — the file's convention).
        m = re.match(r"""['"](.+?)['"]""", no_comment)
        if m:
            terms.append(m.group(1).strip().lower())
    if not terms:
        sys.stderr.write(
            "[cassette_hygiene_lint] WARN — BANNED_TERMS parse yielded "
            "empty list; using built-in fallback.\n"
        )
        return fallback
    return terms


def load_banned_terms() -> list[str]:
    if not COMPLIANCE_GUARD_PATH.is_file():
        sys.stderr.write(
            f"[cassette_hygiene_lint] WARN — {COMPLIANCE_GUARD_PATH} "
            "missing; using built-in fallback BANNED_TERMS.\n"
        )
        return extract_banned_terms("")
    return extract_banned_terms(COMPLIANCE_GUARD_PATH.read_text(encoding="utf-8"))


# ---------------------------------------------------------------------------
# Lint primitives
# ---------------------------------------------------------------------------


def emit_error(path: Path, line: int, msg: str) -> None:
    """Print a GH-Actions-annotated error + a human-readable line."""
    rel = path.relative_to(REPO_ROOT) if REPO_ROOT in path.parents else path
    sys.stdout.write(
        f"::error file={rel},line={line}::{msg}\n"
    )
    sys.stdout.write(f"  {rel}:{line}: {msg}\n")


def _lower_no_accents(s: str) -> str:
    """Cheap accent-insensitive lower-case (FR/DE/IT)."""
    table = str.maketrans(
        "àâäáãåçèéêëîïíìôöóòõøùûüúýÿñÀÂÄÁÃÅÇÈÉÊËÎÏÍÌÔÖÓÒÕØÙÛÜÚÝŸÑ",
        "aaaaaaceeeeiiiioooooouuuuyynAAAAAACEEEEIIIIOOOOOOUUUUYYN",
    )
    return s.translate(table).lower()


def check_secret_patterns(path: Path, content: str) -> int:
    """Return the number of secret leaks found in `content`."""
    failures = 0
    for line_idx, raw_line in enumerate(content.splitlines(), start=1):
        for label, pattern in SECRET_PATTERNS:
            if pattern.search(raw_line):
                emit_error(
                    path,
                    line_idx,
                    f"Secret-pattern leak ({label}) in committed cassette — "
                    "re-record with vcr_config.filter_headers + scrubber, "
                    "or remove the cassette from the commit.",
                )
                failures += 1
    return failures


def check_redact_headers(path: Path, content: str) -> int:
    """Verify required-redact headers carry the literal REDACTED."""
    failures = 0
    # Match `<header_name>: <value>` lines; case-insensitive header name.
    # YAML lists in cassettes look like:
    #   Authorization:
    #   - REDACTED
    # and also:
    #   authorization: REDACTED
    # Walk pairs (header line, next non-blank line) for the list form.
    lines = content.splitlines()
    for i, raw in enumerate(lines):
        # Detect a header key on its own (with optional list child) OR
        # an inline scalar `key: value`.
        m = re.match(r"^\s*([A-Za-z\-]+):\s*(.*)$", raw)
        if not m:
            continue
        header = m.group(1).lower()
        if header not in REDACTED_REQUIRED_HEADERS:
            continue
        inline = m.group(2).strip()
        # If the inline value is empty, the next non-blank line should
        # be a YAML list item: "- VALUE".
        candidate_value = inline
        if not candidate_value:
            for follow in lines[i + 1:i + 4]:
                stripped = follow.strip()
                if not stripped:
                    continue
                if stripped.startswith("- "):
                    candidate_value = stripped[2:].strip()
                break
        # Strip surrounding quotes if any.
        candidate_value = candidate_value.strip().strip("'").strip('"')
        if candidate_value in REDACT_OK_VALUES or candidate_value == "":
            continue
        # Allow short values that are obviously fixture noise (e.g.
        # "application/json" on Content-Type IS not one of the
        # required-redact headers, so we wouldn't be here).
        emit_error(
            path,
            i + 1,
            f"Header `{header}` in cassette has unredacted value "
            f"{candidate_value!r}; expected literal REDACTED. Re-record "
            "or fix vcr_config.filter_headers.",
        )
        failures += 1
    return failures


def check_banned_terms(
    path: Path, content: str, banned_terms: Iterable[str]
) -> int:
    """Scan response bodies for banned-term emissions."""
    failures = 0
    no_acc = _lower_no_accents(content)
    for term in banned_terms:
        term_no_acc = _lower_no_accents(term)
        if not term_no_acc:
            continue
        # Use a word-boundary-ish match on the accentless form.
        pattern = re.compile(rf"(?<![a-z]){re.escape(term_no_acc)}(?![a-z])")
        for line_idx, raw_line in enumerate(content.splitlines(), start=1):
            line_no_acc = _lower_no_accents(raw_line)
            for m in pattern.finditer(line_no_acc):
                # Negation allow-list: scan ~24 chars before the match.
                start = max(0, m.start() - 24)
                window = line_no_acc[start:m.start()]
                if any(window.endswith(neg.strip() + " ") or neg in window
                       for neg in NEGATION_PREFIXES):
                    continue
                # Common false positive: substrings of allowed terms.
                # `optimal` IS banned, but `optimale` is also banned (in
                # BANNED_TERMS), so word-boundary handles both.
                emit_error(
                    path,
                    line_idx,
                    f"Banned term {term!r} found in cassette response body "
                    "— either re-record (banned-term should never be "
                    "emitted) or document negation context per allow-list.",
                )
                failures += 1
                break  # one error per term per line is enough
    return failures


# ---------------------------------------------------------------------------
# File walker
# ---------------------------------------------------------------------------


def lint_file(path: Path, banned_terms: Iterable[str]) -> int:
    """Lint a single cassette YAML; return failure count."""
    try:
        content = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        sys.stderr.write(
            f"[cassette_hygiene_lint] could not read {path}: {exc}\n"
        )
        return 1
    failures = 0
    failures += check_secret_patterns(path, content)
    failures += check_redact_headers(path, content)
    failures += check_banned_terms(path, content, banned_terms)
    return failures


def walk_cassettes(root: Path) -> list[Path]:
    if not root.is_dir():
        return []
    out: list[Path] = []
    for dirpath, _, filenames in os.walk(root):
        for fn in filenames:
            if fn.endswith(".yaml") or fn.endswith(".yml"):
                out.append(Path(dirpath) / fn)
    return sorted(out)


def run_full_scan(banned_terms: Iterable[str]) -> int:
    cassettes = walk_cassettes(CASSETTE_DIR)
    if not cassettes:
        sys.stdout.write(
            f"[cassette_hygiene_lint] no cassettes under {CASSETTE_DIR} "
            "— nothing to scan.\n"
        )
        return 0
    total = 0
    for path in cassettes:
        total += lint_file(path, banned_terms)
    if total == 0:
        sys.stdout.write(
            f"[cassette_hygiene_lint] OK — {len(cassettes)} cassette(s) "
            "scanned, 0 hygiene violations.\n"
        )
        return 0
    sys.stdout.write(
        f"[cassette_hygiene_lint] FAIL — {total} hygiene violation(s) "
        f"across {len(cassettes)} cassette(s). Fix or revert.\n"
    )
    return 1


# ---------------------------------------------------------------------------
# Self-test (CI smoke + local sanity)
# ---------------------------------------------------------------------------


_SELF_TEST_GOOD = """interactions:
- request:
    body: '{"messages":[{"role":"user","content":"Bonjour"}]}'
    headers:
      Authorization:
      - REDACTED
      X-Api-Key:
      - REDACTED
    method: POST
    uri: https://api.anthropic.com/v1/messages
  response:
    body:
      string: '{"id":"msg_redactedstub","type":"message","role":"assistant","content":[{"type":"text","text":"Bonjour, dis-moi dans quel canton tu vis."}],"stop_reason":"end_turn"}'
    headers:
      Content-Type:
      - application/json
    status: {code: 200, message: OK}
version: 1
"""


_SELF_TEST_BANNED = """interactions:
- request:
    headers:
      Authorization:
      - REDACTED
    method: POST
    uri: https://api.anthropic.com/v1/messages
  response:
    body:
      string: '{"content":[{"type":"text","text":"Voici la solution optimale pour ton 3a."}]}'
    status: {code: 200, message: OK}
version: 1
"""


_SELF_TEST_LEAK_KEY = """interactions:
- request:
    headers:
      X-Api-Key:
      - sk-ant-api03ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij
    method: POST
    uri: https://api.anthropic.com/v1/messages
  response:
    body:
      string: '{"content":[{"type":"text","text":"Bonjour."}]}'
    status: {code: 200, message: OK}
version: 1
"""


_SELF_TEST_UNREDACTED_HEADER = """interactions:
- request:
    headers:
      Authorization:
      - Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0In0.dummy_signature_here
    method: POST
    uri: https://api.anthropic.com/v1/messages
  response:
    body:
      string: '{"content":[{"type":"text","text":"Bonjour."}]}'
    status: {code: 200, message: OK}
version: 1
"""


def _self_test() -> int:
    """Run 4 in-memory cases (1 clean + 3 known-bad) and verify
    the lint flags exactly the bad ones.
    """
    import tempfile

    banned_terms = load_banned_terms()
    cases: list[tuple[str, str, bool]] = [
        ("clean", _SELF_TEST_GOOD, False),
        ("banned_term_optimal", _SELF_TEST_BANNED, True),
        ("leaked_anthropic_key", _SELF_TEST_LEAK_KEY, True),
        ("unredacted_authorization", _SELF_TEST_UNREDACTED_HEADER, True),
    ]

    failed_cases: list[str] = []
    for name, content, expect_failure in cases:
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".yaml", delete=False, encoding="utf-8"
        ) as tmp:
            tmp.write(content)
            tmp_path = Path(tmp.name)
        try:
            # Suppress per-case stdout noise during self-test sweep.
            from io import StringIO

            buf = StringIO()
            real_stdout = sys.stdout
            sys.stdout = buf
            try:
                violations = lint_file(tmp_path, banned_terms)
            finally:
                sys.stdout = real_stdout
            saw_failure = violations > 0
            if saw_failure != expect_failure:
                failed_cases.append(
                    f"  [{name}] expected_failure={expect_failure} "
                    f"saw_failure={saw_failure} violations={violations}"
                )
        finally:
            try:
                tmp_path.unlink()
            except OSError:
                pass

    if failed_cases:
        sys.stdout.write(
            "[cassette_hygiene_lint] SELF-TEST FAILED:\n"
            + "\n".join(failed_cases)
            + "\n"
        )
        return 1
    sys.stdout.write(
        "[cassette_hygiene_lint] SELF-TEST OK — 4 cases (1 clean + 3 bad) "
        "all classified correctly.\n"
    )
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--target",
        type=Path,
        default=None,
        help="Lint a single cassette YAML instead of walking the dir.",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Run the 4-case self-test and exit (CI smoke).",
    )
    args = parser.parse_args(argv)

    if args.self_test:
        return _self_test()

    banned_terms = load_banned_terms()
    if args.target is not None:
        if not args.target.is_file():
            sys.stderr.write(
                f"[cassette_hygiene_lint] --target {args.target} not found\n"
            )
            return 2
        violations = lint_file(args.target, banned_terms)
        if violations == 0:
            sys.stdout.write(
                f"[cassette_hygiene_lint] OK — {args.target} clean.\n"
            )
            return 0
        sys.stdout.write(
            f"[cassette_hygiene_lint] FAIL — {violations} hygiene "
            f"violation(s) in {args.target}.\n"
        )
        return 1

    return run_full_scan(banned_terms)


if __name__ == "__main__":
    sys.exit(main())

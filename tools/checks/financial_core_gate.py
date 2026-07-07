#!/usr/bin/env python3
"""Block newly introduced financial calculation drift outside financial_core."""
from __future__ import annotations
import argparse
import re
import subprocess
import sys
import unicodedata
from pathlib import Path
REPO = Path(__file__).resolve().parents[2]
APP_LIB = "apps/mobile/lib/"
CORE_SEGMENT = "/services/financial_core/"
EXCLUDED = ("/.dart_tool/", "/build/", "/.git/", "/l10n/", "/test/", "/tests/")
FINANCIAL_TOKENS = set(
    "3a affordability assurance avs benefice budget capital chf cotisation contribution debt decaissement dette dividende "
    "dividend donation epargne epl fiscal fitness fortune franchise fri heritage hoirie hypothecaire hypotheque imputed "
    "income interet lamal leasing loyer lpp mortgage patrimoine pension pilier pillar prevoyance prime rachat rent rente "
    "resilience retrait revenu salary salaire savings score successoral tax tenue usufruit withdrawal".split()
)
CALC_RE = re.compile(
    r"^\s*(?:static\s+)?(?:(?:Future|Stream|List|Map|Set|Iterable|double|int|num|bool|String|void)(?:<[^>{}]+>)?\s+)?"
    r"(?P<name>_?(?:calculate|calculer|compute|estimate|project|simulate)[A-Za-z0-9_]*)\s*\("
)
ASSIGN_RE = re.compile(r"^\s*(?:final|var|const|double|int|num)\s+[A-Za-z_][A-Za-z0-9_]*\s*=")
RETURN_RE = re.compile(r"^\s*return\s+")
ARITH_RE = re.compile(
    r"[A-Za-z0-9_\]\)]\s*[\*/]\s*[A-Za-z0-9_\(]|[A-Za-z0-9_\]\)]\s+[\+\-]\s+[A-Za-z0-9_\(]|"
    r"\b\d+(?:\.\d+)?\s*[\*/]\s*[A-Za-z_\(]|[A-Za-z_\)]\s*[\*/]\s*\d+(?:\.\d+)?"
)

def _normalize(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value)
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch)).casefold()

def _clean_path(path: str) -> str:
    return path.removeprefix("a/").removeprefix("b/").replace("\\", "/")

def _is_scoped(path: str) -> bool:
    rel = _clean_path(path)
    wrapped = f"/{rel}/"
    return rel.startswith(APP_LIB) and rel.endswith(".dart") and not rel.endswith(".g.dart") and CORE_SEGMENT not in wrapped and not any(
        part in wrapped for part in EXCLUDED
    )

def _has_financial_context(path: str, text: str) -> bool:
    haystack = _normalize(f"{path} {text}")
    return any(re.search(rf"(?<![a-z0-9]){re.escape(token)}(?![a-z0-9])", haystack) for token in FINANCIAL_TOKENS)

def _code_without_strings(line: str) -> str:
    out: list[str] = []
    quote = None
    escaped = False
    for index, ch in enumerate(line):
        nxt = line[index + 1] if index + 1 < len(line) else ""
        if quote:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
        elif ch in {"'", '"'}:
            quote = ch
            out.append(" ")
        elif ch == "/" and nxt == "/":
            return "".join(out)
        else:
            out.append(ch)
    return "".join(out)

def _added_lines(diff_text: str) -> list[tuple[str, int, str]]:
    out: list[tuple[str, int, str]] = []
    path: str | None = None
    lineno: int | None = None
    for raw in diff_text.splitlines():
        if raw.startswith("diff --git "):
            path = None
            lineno = None
        elif raw.startswith("+++ "):
            marker = raw[4:].strip()
            path = None if marker == "/dev/null" else _clean_path(marker)
        elif raw.startswith("@@ "):
            match = re.search(r"\+(\d+)(?:,\d+)?", raw)
            lineno = int(match.group(1)) if match else None
        elif lineno is None:
            continue
        elif raw.startswith("+") and not raw.startswith("+++"):
            if path and _is_scoped(path):
                out.append((path, lineno, raw[1:]))
            lineno += 1
        elif not (raw.startswith("-") and not raw.startswith("---")):
            lineno += 1
    return out

def _violation(path: str, text: str) -> str | None:
    code = _code_without_strings(text).strip()
    if not code:
        return None
    match = CALC_RE.match(code)
    if match and _has_financial_context("", code):
        return f"new calculation helper '{match.group('name')}' outside financial_core/"
    if (ASSIGN_RE.match(code) or RETURN_RE.match(code)) and ARITH_RE.search(code) and _has_financial_context("", code):
        return "new financial formula outside financial_core/"
    return None

def _git_diff(args: list[str]) -> str:
    result = subprocess.run(
        ["git", "diff", "--unified=0", "--no-ext-diff", *args, "--", "apps/mobile/lib"],
        cwd=REPO,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        print(result.stderr.strip(), file=sys.stderr)
        raise SystemExit(result.returncode)
    return result.stdout

def _read_diff(args: argparse.Namespace) -> str:
    if args.diff_file:
        return Path(args.diff_file).read_text(encoding="utf-8")
    if args.staged:
        return _git_diff(["--cached"])
    return _git_diff([f"{args.base_ref}...HEAD"] if args.base_ref else ["HEAD"])

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--diff-file")
    parser.add_argument("--staged", action="store_true")
    parser.add_argument("--base-ref")
    args = parser.parse_args()
    if sum(bool(v) for v in (args.diff_file, args.staged, args.base_ref)) > 1:
        parser.error("use only one of --diff-file, --staged, or --base-ref")
    lines = _added_lines(_read_diff(args))
    failures = [(p, n, d, t.strip()) for p, n, t in lines for d in [_violation(p, t)] if d]
    if failures:
        print("::error::financial_core_gate failed:")
        for path, lineno, detail, text in failures:
            print(f"{path}:{lineno}: {detail}: {text}")
        return 1
    print(f"OK financial_core_gate: scanned {len(lines)} added Dart line(s), no new calculation drift")
    return 0

if __name__ == "__main__":
    sys.exit(main())

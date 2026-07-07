#!/usr/bin/env python3
"""New-debt gate for hardcoded Swiss financial rates."""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCOPES = ("apps/mobile/lib/", "services/backend/app/")
ALLOWED = ("/apps/mobile/lib/services/financial_core/", "/services/backend/app/services/regulatory/registry.py")
EXCLUDED = ("/test/", "/tests/", "/l10n/", "/.dart_tool/", "/build/")
TOKENS = set(
    "3a affordability amortissement assurance avs benefice budget capital chf cotisation debt dette dividende donation "
    "epargne epl fiscal fortune fri heritage hoirie hypothecaire hypotheque imputed income interet lamal leasing loyer "
    "lpp mortgage patrimoine pension pilier pillar prevoyance prime rachat rate rent rente revenu salary salaire tax taux "
    "usufruit withdrawal".split()
)
DECIMAL_RATE = re.compile(r"(?<![A-Za-z0-9_])0\.(?=\d*[1-9])\d+\b")
RATE_ASSIGN = re.compile(r"\b[A-Za-z_]*(?:rate|taux|tax|interest|interet|conversion|cotisation)[A-Za-z_]*\s*(?::\s*[A-Za-z_][A-Za-z0-9_\[\]]*)?\s*=\s*-?\d+(?:\.\d+)?", re.IGNORECASE)


def _norm(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value)
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch)).casefold()


def _clean(path: str) -> str:
    return path.removeprefix("a/").removeprefix("b/").replace("\\", "/")


def _scoped(path: str) -> bool:
    rel = _clean(path)
    wrapped = f"/{rel}/"
    return rel.startswith(SCOPES) and (rel.endswith(".dart") or rel.endswith(".py")) and not rel.endswith(".g.dart") and not any(part in wrapped for part in EXCLUDED)


def _allowed(path: str) -> bool:
    wrapped = f"/{_clean(path)}"
    return any(part in wrapped for part in ALLOWED)


def _code(line: str) -> str:
    out: list[str] = []
    quote: str | None = None
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
        elif ch == "/" and nxt == "/" or ch == "#":
            return "".join(out)
        else:
            out.append(ch)
    return "".join(out)


def _financial(path: str, code: str) -> bool:
    haystack = _norm(f"{path} {code}")
    return any(re.search(rf"(?<![a-z0-9]){re.escape(token)}(?![a-z0-9])", haystack) for token in TOKENS)


def _added(diff: str) -> list[tuple[str, int, str]]:
    out: list[tuple[str, int, str]] = []
    path: str | None = None
    line: int | None = None
    for raw in diff.splitlines():
        if raw.startswith("diff --git "):
            path = None
        elif raw.startswith("+++ "):
            marker = raw[4:].strip()
            path = None if marker == "/dev/null" else _clean(marker)
        elif raw.startswith("@@ "):
            match = re.search(r"\+(\d+)", raw)
            line = int(match.group(1)) if match else None
        elif line is None:
            continue
        elif raw.startswith("+") and not raw.startswith("+++"):
            if path and _scoped(path):
                out.append((path, line, raw[1:]))
            line += 1
        elif not (raw.startswith("-") and not raw.startswith("---")):
            line += 1
    return out


def _violation(path: str, text: str) -> str | None:
    if _allowed(path):
        return None
    code = _code(text).strip()
    if not code:
        return None
    if RATE_ASSIGN.search(code):
        return "new hardcoded financial rate outside registry.py/financial_core"
    if DECIMAL_RATE.search(code) and _financial(path, code):
        return "new hardcoded decimal financial rate outside registry.py/financial_core"
    return None


def _git_diff(args: list[str]) -> str:
    result = subprocess.run(["git", "diff", "--unified=0", "--no-ext-diff", *args, "--", *SCOPES], cwd=REPO, text=True, capture_output=True, check=False)
    if result.returncode:
        print(result.stderr.strip(), file=sys.stderr)
        raise SystemExit(result.returncode)
    return result.stdout


def _read(args: argparse.Namespace) -> str:
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
    failures = [(p, n, d, t.strip()) for p, n, t in _added(_read(args)) for d in [_violation(p, t)] if d]
    if failures:
        print("::error::hardcoded_rate_gate failed:")
        print("Use regulatory registry.py or apps/mobile/lib/services/financial_core/ for financial constants.")
        for path, line, detail, text in failures:
            print(f"{path}:{line}: {detail}: {text}")
        return 1
    print("OK hardcoded_rate_gate: no hardcoded financial rates in added Python/Dart lines")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Block LSFin-banned vocabulary in Dart UI string literals.

This is deliberately narrower than a raw grep. MINT's Dart tree contains
legitimate Swiss legal terms such as "salaire assuré" and compliance guard
fixtures that must mention banned words in order to block them. This gate scans
string literals under apps/mobile/lib, skips comments/tests/import URIs/internal
guard dictionaries, and reports only user-facing promise-language violations.
"""
from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from pathlib import Path
from typing import NamedTuple


REPO = Path(__file__).resolve().parents[2]
DEFAULT_SCOPE = ("apps/mobile/lib",)


class PolicyTerm(NamedTuple):
    raw: str
    active: bool = True

    @property
    def normalized(self) -> str:
        return _normalize(self.raw)


# Core terms are from CLAUDE.md / LEGAL_RELEASE_CHECK.md. The English terms are
# tracked here for audit visibility; fully semantic option-ranking checks remain
# outside this lexical gate.
POLICY_TERMS = (
    PolicyTerm("garanti"),
    PolicyTerm("optimal"),
    PolicyTerm("meilleur"),
    PolicyTerm("certain"),
    PolicyTerm("assuré"),
    PolicyTerm("sans risque"),
    PolicyTerm("parfait"),
    PolicyTerm("conseil financier"),
    PolicyTerm("tu vas gagner"),
    PolicyTerm("recommandation personnalisée"),
    PolicyTerm("vous devriez"),
    PolicyTerm("top X% des Suisses"),
    PolicyTerm("better", active=False),
    PolicyTerm("recommended", active=False),
)

INTERNAL_POLICY_FILES = {
    "apps/mobile/lib/services/agent/autonomous_agent_service.dart",
    "apps/mobile/lib/services/coach/context_injector_service.dart",
    "apps/mobile/lib/services/coach/compliance_guard.dart",
    "apps/mobile/lib/services/llm/response_quality_monitor.dart",
}

NON_UI_PATH_PREFIXES = (
    "apps/mobile/lib/services/document_parser/",
)

EXCLUDED_PATH_PARTS = (
    "/.dart_tool/",
    "/build/",
    "/.git/",
    "/test/",
    "/tests/",
)

NON_UI_GUARD_MARKERS = (
    "aucun terme banni",
    "complianceguard",
    "jamais de termes",
    "jamais :",
    "ne donnes jamais",
    "ne dis jamais",
    "tu ne dis jamais",
    "tu ne donnes jamais",
    "termes bannis",
    "termes interdits",
)

NEGATED_PROMISE_PATTERNS = (
    re.compile(r"\bpas\s+de\b.{0,80}\bgaranti(?:e|s|es)?\b"),
    re.compile(r"\bpas\b.{0,40}\bgaranti(?:e|s|es)?\b"),
    re.compile(r"\bnon\s+garanti(?:e|s|es)?\b"),
    re.compile(r"\bne\s+garantit\s+pas\b"),
    re.compile(r"\bne\s+garantissent\s+(?:pas|aucun|aucune)\b"),
    re.compile(r"\bnot\s+guaranteed\b"),
    re.compile(r"\bno\s+guaranteed\b"),
    re.compile(r"\bresultats?\s+non\s+assures?\b"),
)

SWISS_INSURANCE_PATTERNS = (
    re.compile(r"\b(?:salaire|gain|capital|montant|revenu)\s+assure\b"),
    re.compile(r"\bassure(?:e|·e|\\u00b7e)?\s+lpp\b"),
    re.compile(r"\bavs/assure\b"),
    re.compile(r"\brente\s+assuree\b"),
    re.compile(r"\bsomme\s+assuree\b"),
    re.compile(r"\bpartie\b.{0,40}\bnon\s+assuree\b"),
)

ASSURE_VERB_PATTERNS = (
    re.compile(r"\bassure-toi\b"),
)

NEGATED_ADVICE_PATTERNS = (
    re.compile(r"\bne\s+constitu(?:e|ent)\s+pas\s+un\s+conseil\s+financier\b"),
    re.compile(r"\bpas\s+un\s+conseil\s+financier\b"),
    re.compile(r"\bdoes\s+not\s+constitute\b.{0,40}\bfinancial\s+advice\b"),
)

CERTAIN_INDEFINITE_PATTERNS = (
    re.compile(r"\b(?:un|d'un|d un)\s+certain\b"),
    re.compile(r"\b(?:une|d'une|d une)\s+certaine\b"),
    re.compile(r"\bcertain(?:s|es)\s+[a-z0-9]"),
)

PARFAIT_ACK_PATTERNS = (
    re.compile(r"^parfait\s*,"),
)

NEGATED_RANKING_PATTERNS = (
    re.compile(r"\baucune\s+option\b.{0,80}\bmeilleur(?:e|s|es)?\b"),
)

POLICY_LIST_CONTEXT_PATTERNS = (
    re.compile(r"\b_?banned(?:_?terms)?\s*=\s*\["),
    re.compile(r"\b(?:termes?|mots?)\s+(?:bannis|interdits)\b.{0,80}\["),
)

TERM_PATTERN_SOURCES = {
    "garanti": r"garanti(?:e|s|es)?|garantit|garantissent",
    "optimal": r"optimal(?:e|es|s)?|optimaux",
    "meilleur": r"meilleur(?:e|s|es)?",
    "sans risque": r"sans\s+risques?",
    "parfait": r"parfait(?:e|s|es)?",
    "assuré": r"assure(?:e|s|es)?",
    "certain": r"certain(?:e|s|es)?",
}


class DartString(NamedTuple):
    line: int
    text: str
    source_line: str
    context_before: str


class Violation(NamedTuple):
    path: Path
    line: int
    term: str
    text: str


def _normalize(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value)
    ascii_text = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    return re.sub(r"\s+", " ", ascii_text.casefold()).strip()


def _word_pattern(term: PolicyTerm) -> re.Pattern[str]:
    escaped = TERM_PATTERN_SOURCES.get(term.raw)
    if escaped is None:
        escaped = re.escape(term.normalized).replace(r"\ ", r"\s+")
    return re.compile(rf"(?<![a-z0-9_])(?:{escaped})(?![a-z0-9_])")


def _relative(path: Path, root: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def _is_scoped_dart_file(path: Path, root: Path) -> bool:
    rel = "/" + _relative(path, root) + "/"
    if path.suffix != ".dart":
        return False
    if not rel.startswith("/apps/mobile/lib/"):
        return False
    return not any(part in rel for part in EXCLUDED_PATH_PARTS)


def _collect_paths(root: Path, scope: tuple[str, ...]) -> list[Path]:
    paths: list[Path] = []
    for raw_scope in scope:
        scope_root = root / raw_scope
        if not scope_root.exists():
            continue
        for path in scope_root.rglob("*.dart"):
            if _is_scoped_dart_file(path, root):
                paths.append(path)
    return sorted(paths)


def _line_is_import_like(line: str) -> bool:
    stripped = line.strip()
    return stripped.startswith(("import ", "export ", "part "))


def _extract_dart_strings(source: str) -> list[DartString]:
    out: list[DartString] = []
    lines = source.splitlines()
    i = 0
    line = 1
    length = len(source)

    while i < length:
        ch = source[i]
        nxt = source[i + 1] if i + 1 < length else ""

        if ch == "\n":
            line += 1
            i += 1
            continue

        if ch == "/" and nxt == "/":
            i += 2
            while i < length and source[i] != "\n":
                i += 1
            continue

        if ch == "/" and nxt == "*":
            i += 2
            while i < length - 1 and not (source[i] == "*" and source[i + 1] == "/"):
                if source[i] == "\n":
                    line += 1
                i += 1
            i += 2
            continue

        raw_prefix = ch in {"r", "R"} and nxt in {"'", '"'}
        if ch in {"'", '"'} or raw_prefix:
            quote = nxt if raw_prefix else ch
            start = i + 1 if raw_prefix else i
            start_line = line
            i = start + 1
            triple = source.startswith(quote * 3, start)
            if triple:
                i = start + 3
            literal: list[str] = []
            escaped = False
            while i < length:
                if source[i] == "\n":
                    line += 1
                    literal.append(source[i])
                    i += 1
                    escaped = False
                    continue
                if not raw_prefix and escaped:
                    literal.append(source[i])
                    escaped = False
                    i += 1
                    continue
                if not raw_prefix and source[i] == "\\":
                    literal.append(source[i])
                    escaped = True
                    i += 1
                    continue
                if not raw_prefix and source[i] == "$":
                    if i + 1 < length and source[i + 1] == "{":
                        i += 2
                        depth = 1
                        while i < length and depth > 0:
                            if source[i] == "\n":
                                line += 1
                            elif source[i] == "{":
                                depth += 1
                            elif source[i] == "}":
                                depth -= 1
                            i += 1
                        literal.append("${}")
                        continue
                    if i + 1 < length and re.match(r"[A-Za-z_]", source[i + 1]):
                        i += 2
                        while i < length and re.match(r"[A-Za-z0-9_.]", source[i]):
                            i += 1
                        literal.append("$")
                        continue
                if triple and source.startswith(quote * 3, i):
                    i += 3
                    break
                if not triple and source[i] == quote:
                    i += 1
                    break
                literal.append(source[i])
                i += 1

            source_line = lines[start_line - 1] if start_line <= len(lines) else ""
            context_start = max(0, start_line - 21)
            context_before = "\n".join(lines[context_start : start_line - 1])
            if not _line_is_import_like(source_line):
                out.append(
                    DartString(
                        start_line,
                        "".join(literal),
                        source_line,
                        context_before,
                    )
                )
            continue

        i += 1

    return out


def _literal_is_non_ui_guard(text: str, source_line: str) -> bool:
    normalized = _normalize(f"{source_line} {text}")
    return any(marker in normalized for marker in NON_UI_GUARD_MARKERS)


def _literal_is_machine_token(text: str) -> bool:
    compact = text.strip()
    if not compact:
        return True
    normalized = _normalize(compact)
    for term in POLICY_TERMS:
        if term.active and _word_pattern(term).search(normalized):
            return False
    if len(compact) <= 80 and re.fullmatch(r"[A-Za-z0-9_.:/@-]+", compact):
        return True
    return False


def _literal_is_policy_list_item(
    text: str,
    source_line: str,
    context_before: str,
    rel_path: str,
) -> bool:
    if "/services/" not in f"/{rel_path}":
        return False
    stripped = source_line.strip()
    if not re.fullmatch(r"""['"][^'"]+['"],?""", stripped):
        return False
    normalized_context = _normalize(context_before)
    if not any(pattern.search(normalized_context) for pattern in POLICY_LIST_CONTEXT_PATTERNS):
        return False
    normalized = _normalize(text)
    return any(
        normalized == term.normalized or _word_pattern(term).fullmatch(normalized)
        for term in POLICY_TERMS
    )


def _term_allowed(term: PolicyTerm, normalized_text: str) -> bool:
    if term.raw == "garanti":
        return any(pattern.search(normalized_text) for pattern in NEGATED_PROMISE_PATTERNS)
    if term.raw == "assuré":
        return (
            any(pattern.search(normalized_text) for pattern in SWISS_INSURANCE_PATTERNS)
            or any(pattern.search(normalized_text) for pattern in ASSURE_VERB_PATTERNS)
            or any(pattern.search(normalized_text) for pattern in NEGATED_PROMISE_PATTERNS)
        )
    if term.raw == "certain":
        return any(pattern.search(normalized_text) for pattern in CERTAIN_INDEFINITE_PATTERNS)
    if term.raw == "meilleur":
        return any(pattern.search(normalized_text) for pattern in NEGATED_RANKING_PATTERNS)
    if term.raw == "conseil financier":
        return any(pattern.search(normalized_text) for pattern in NEGATED_ADVICE_PATTERNS)
    if term.raw == "parfait":
        return any(pattern.search(normalized_text) for pattern in PARFAIT_ACK_PATTERNS)
    return False


def scan_file(path: Path, root: Path) -> list[Violation]:
    rel = _relative(path, root)
    if rel in INTERNAL_POLICY_FILES:
        return []
    if any(rel.startswith(prefix) for prefix in NON_UI_PATH_PREFIXES):
        return []

    try:
        source = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []

    violations: list[Violation] = []
    for literal in _extract_dart_strings(source):
        if _literal_is_machine_token(literal.text):
            continue
        if _literal_is_non_ui_guard(literal.text, literal.source_line):
            continue
        if _literal_is_policy_list_item(
            literal.text,
            literal.source_line,
            literal.context_before,
            rel,
        ):
            continue
        normalized = _normalize(literal.text)
        for term in POLICY_TERMS:
            if not term.active:
                continue
            if not _word_pattern(term).search(normalized):
                continue
            if _term_allowed(term, normalized):
                continue
            violations.append(
                Violation(
                    path=path,
                    line=literal.line,
                    term=term.raw,
                    text=" ".join(literal.text.split())[:180],
                )
            )
    return violations


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Scan apps/mobile/lib/**/*.dart UI strings for MINT banned terms."
    )
    parser.add_argument("--root", default=str(REPO), help="Repository root")
    parser.add_argument("--file", help="Check one staged file; non-scope files are skipped")
    parser.add_argument(
        "--scope",
        nargs="*",
        default=list(DEFAULT_SCOPE),
        help="Scope directories relative to --root",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if args.file:
        path = Path(args.file)
        if not path.is_absolute():
            path = root / path
        paths = [path] if _is_scoped_dart_file(path, root) else []
    else:
        paths = _collect_paths(root, tuple(args.scope))

    violations: list[Violation] = []
    for path in paths:
        violations.extend(scan_file(path, root))

    if violations:
        print("::error::banned_ui_terms gate failed:")
        for violation in violations:
            rel = _relative(violation.path, root)
            print(
                f"{rel}:{violation.line}: banned term '{violation.term}' in UI string: "
                f"{violation.text}"
            )
        return 1

    print(f"OK banned_ui_terms: scanned {len(paths)} Dart file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

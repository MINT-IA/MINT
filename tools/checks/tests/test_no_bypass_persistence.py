import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MOBILE_LIB = ROOT / "apps/mobile/lib"
DATA_LEDGER = ROOT / "docs/codex/DATA_LEDGER.md"

ALLOWED_WRITERS = {
    ROOT / "apps/mobile/lib/services/report_persistence_service.dart",
    ROOT / "apps/mobile/lib/providers/coach_profile_provider.dart",
}

WRITE_CALL = re.compile(r"\.set(?:String|Double|Int|Bool|StringList)\s*\(")
LITERAL = re.compile(r"""['"]([^'"]+)['"]""")


def _ledger_tokens() -> set[str]:
    text = DATA_LEDGER.read_text(encoding="utf-8")
    tokens = {"wizard_answers_v2"}
    for line in text.splitlines():
      # Markdown table cells with backticked ledger/wizard keys.
      tokens.update(match.group(1) for match in re.finditer(r"`([^`]+)`", line))
    return {
        token
        for token in tokens
        if token.startswith(("q_", "_coach_", "fp:"))
        or "." in token
        or token == "wizard_answers_v2"
    }


def test_domain_keys_are_not_written_directly_to_shared_preferences() -> None:
    ledger_tokens = _ledger_tokens()
    violations: list[str] = []

    for path in sorted(MOBILE_LIB.rglob("*.dart")):
        if path in ALLOWED_WRITERS:
            continue
        lines = path.read_text(encoding="utf-8").splitlines()
        for index, line in enumerate(lines):
            if not WRITE_CALL.search(line):
                continue
            window = "\n".join(lines[index : index + 4])
            literals = {match.group(1) for match in LITERAL.finditer(window)}
            bad = sorted(
                literal
                for literal in literals
                if literal in ledger_tokens
                or literal.startswith(("q_", "_coach_", "fp:"))
                or literal == "wizard_answers_v2"
            )
            if bad:
                rel = path.relative_to(ROOT)
                violations.append(f"{rel}:{index + 1} writes {', '.join(bad)}")

    assert not violations, (
        "Domain ledger keys must be persisted through "
        "ReportPersistenceService/CoachProfileProvider only:\n"
        + "\n".join(violations)
    )

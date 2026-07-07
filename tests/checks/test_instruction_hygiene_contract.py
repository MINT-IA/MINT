import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CLAUDE = ROOT / "CLAUDE.md"
RULES = ROOT / "rules.md"
CI = ROOT / ".github" / "workflows" / "ci.yml"

INSTRUCTION_PATTERNS = (
    "CLAUDE.md",
    "AGENTS.md",
    "rules.md",
    ".claude/agents/*.md",
    ".claude/skills/*/SKILL.md",
    ".claude/prompts/*.md",
    ".claude/AGENT*.md",
    ".claude/*WORKFLOW*.md",
)

VOLATILE_PATTERNS = (
    re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z?"),
    re.compile(r"\bGenerated\s+(?:at|on)\s+\d{4}-\d{2}-\d{2}", re.IGNORECASE),
    re.compile(r"\bLast\s+updated\s*:\s*\d{4}-\d{2}-\d{2}", re.IGNORECASE),
)


def _text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _instruction_files() -> list[Path]:
    files: set[Path] = set()
    for pattern in INSTRUCTION_PATTERNS:
        files.update(ROOT.glob(pattern))
    return sorted(path for path in files if path.is_file())


def test_instruction_hygiene_contract_is_ci_wired() -> None:
    ci = _text(CI)

    assert "tests/checks/test_instruction_hygiene_contract.py" in ci


def test_active_instruction_files_have_no_volatile_timestamps() -> None:
    offenders: list[str] = []

    for path in _instruction_files():
        for lineno, line in enumerate(_text(path).splitlines(), start=1):
            if any(pattern.search(line) for pattern in VOLATILE_PATTERNS):
                offenders.append(f"{path.relative_to(ROOT)}:{lineno}: {line.strip()}")

    assert offenders == []


def test_rules_md_points_to_root_claude_md() -> None:
    rules = _text(RULES)

    assert ".claude/CLAUDE.md" not in rules
    assert "CLAUDE.md — Project context" in rules


def test_rules_md_uses_repo_reality_reconciliation() -> None:
    rules = _text(RULES)

    assert "Implementation follows documents" not in rules
    assert "repo source of truth" in rules
    assert "reconcile" in rules
    assert "SOT/OpenAPI/ADR" in rules


def test_claude_md_points_repeated_rules_to_enforced_gates() -> None:
    claude = _text(CLAUDE)

    for gate in (
        "enforced by hook/CI: banned-ui-terms",
        "enforced by hook/CI: accent-lint-fr",
        "enforced by hook/CI: financial-core-gate",
        "enforced by hook/CI: no-hardcoded-fr, arb-parity",
    ):
        assert gate in claude

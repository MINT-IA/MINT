import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CLAUDE = ROOT / "CLAUDE.md"
RULES = ROOT / "rules.md"
LEFTHOOK = ROOT / "lefthook.yml"
CI = ROOT / ".github" / "workflows" / "ci.yml"

INSTRUCTION_PATTERNS = (
    "CLAUDE.md",
    "AGENTS.md",
    "rules.md",
    ".claude/agents/*.md",
    ".claude/skills/*/SKILL.md",
    ".claude/prompts/*.md",
)

VOLATILE_PATTERNS = (
    re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z?"),
    re.compile(r"\bGenerated\s+(?:at|on)\s+\d{4}-\d{2}-\d{2}", re.IGNORECASE),
    re.compile(r"\bLast\s+updated\s*:\s*\d{4}-\d{2}-\d{2}", re.IGNORECASE),
)

GATES = {
    "banned-ui-terms": "tools/checks/banned_ui_terms.py",
    "accent-lint-fr": "tools/checks/accent_lint_fr.py",
    "financial-core-gate": "tools/checks/financial_core_gate.py",
    "no-hardcoded-fr": "tools/checks/no_hardcoded_fr.py",
    "arb-parity": "tools/checks/arb_parity.py",
}


def _text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _instruction_files() -> list[Path]:
    files: set[Path] = set()
    for pattern in INSTRUCTION_PATTERNS:
        files.update(ROOT.glob(pattern))
    return sorted(path for path in files if path.is_file())


def test_active_instruction_files_have_no_volatile_timestamps() -> None:
    offenders: list[str] = []

    for path in _instruction_files():
        for lineno, line in enumerate(_text(path).splitlines(), start=1):
            if any(pattern.search(line) for pattern in VOLATILE_PATTERNS):
                offenders.append(f"{path.relative_to(ROOT)}:{lineno}: {line.strip()}")

    assert offenders == []


def test_claude_md_marks_mechanical_rules_as_enforced_by_hooks_or_ci() -> None:
    claude = _text(CLAUDE)

    for gate in (
        "enforced by hook/CI: banned-ui-terms",
        "enforced by hook/CI: accent-lint-fr",
        "enforced by hook/CI: financial-core-gate",
        "enforced by hook/CI: no-hardcoded-fr, arb-parity",
    ):
        assert gate in claude


def test_claude_md_gate_labels_are_backed_by_checked_in_hooks_or_ci() -> None:
    lefthook = _text(LEFTHOOK)
    ci = _text(CI)

    for label, script in GATES.items():
        assert f"{label}:" in lefthook
        assert script in lefthook
        assert f"{label}:" in ci
        assert script in ci
        assert f"needs.{label}.result" in ci


def test_rules_md_points_to_repo_claude_and_checked_in_gates() -> None:
    rules = _text(RULES)

    assert ".claude/CLAUDE.md" not in rules
    assert "CLAUDE.md — Project context" in rules
    assert "Checked-in hooks/CI, not memory, enforce mechanical rules" in rules

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CI = ROOT / ".github" / "workflows" / "ci.yml"
CLAUDE = ROOT / "CLAUDE.md"
HOSTING_ADR = ROOT / "decisions" / "ADR-20260707-hosting-migration.md"


def _text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_governance_contract_is_ci_wired() -> None:
    ci = _text(CI)

    assert "tests/checks/test_governance_docs_contract.py" in ci


def test_claude_md_declares_memory_hierarchy() -> None:
    claude = _text(CLAUDE)

    assert "Hiérarchie mémoire" in claude
    assert "Engram = index de rappel, jamais source primaire" in claude
    assert "le repo gagne" in claude
    assert "AGENTS_LOG" not in claude
    assert "docs/archive/" not in claude


def test_hosting_adr_exists_and_follows_template() -> None:
    adr = _text(HOSTING_ADR)

    for heading in (
        "## Contexte",
        "## Décision",
        "## Alternatives considérées",
        "## Conséquences",
        "## Plan de migration",
        "## Liens",
    ):
        assert heading in adr


def test_hosting_adr_states_stateless_target_with_current_exceptions() -> None:
    adr = _text(HOSTING_ADR)

    required_phrases = (
        "Railway target = stateless compute only",
        "no new raw identifiable financial amount persisted server-side",
        "Current persistence exceptions",
        "gross_income",
        "coach_insight",
        "amount_hint",
        "amount_cents",
        "Infomaniak",
        "Exoscale",
        "FINMA",
        "server-side storage of identifiable financial data",
        "regulatory requirement",
    )

    for phrase in required_phrases:
        assert phrase in adr

    assert "no raw financial amount persisted server-side" not in adr


def test_hosting_adr_marked_proposed() -> None:
    adr = _text(HOSTING_ADR)

    assert "Status: Proposed" in adr

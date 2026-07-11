from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SWISS_SKILL = ROOT / ".claude/skills/mint-swiss-compliance/SKILL.md"


def test_swiss_compliance_skill_rejects_system_correct_domain_wrong_logic() -> None:
    text = SWISS_SKILL.read_text(encoding="utf-8")

    assert "incoherent" in text
    assert "Swiss finance, law, tax, insurance, inheritance, mortgage, or pension" in text


def test_swiss_compliance_skill_uses_2026_ofas_baseline() -> None:
    text = SWISS_SKILL.read_text(encoding="utf-8")

    for expected in (
        "OFAS/BSV",
        "Beträge gültig ab 1. Januar 2026",
        "22'680",
        "26'460",
        "90'720",
        "7'258",
        "36'288",
        "2'520",
        "3'780",
    ):
        assert expected in text


def test_swiss_compliance_skill_does_not_reintroduce_stale_2024_thresholds() -> None:
    text = SWISS_SKILL.read_text(encoding="utf-8")

    for stale in ("25'725", "7'056", "35'280", "2'450", "3'675"):
        assert stale not in text

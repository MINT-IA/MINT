from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PROMPT = ROOT / "docs" / "codex" / "G3_G6_OPERATOR_PROMPT.md"
INTERACTION_REGISTRY = ROOT / "docs" / "codex" / "INTERACTION_REGISTRY.md"


def _text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_operator_prompt_pins_executable_preflight() -> None:
    prompt = _text(PROMPT)

    required = (
        "python3 -m pytest tests/test_regulatory_registry.py -q",
        "RegulatoryRegistry.instance().count()",
        "check_freshness()",
        "tools/checks/no_bypass_persistence.py",
        "DATA_LEDGER.md",
        "câblé dans Lefthook",
        "gh pr list --repo MINT-IA/MINT",
        "gh pr checks <num>",
        "git diff --shortstat origin/<base>...HEAD",
        "moins de 300 insertions nettes",
        ".planning/phases/<G>/swiss-brain-spec.md",
        "SCREEN_CONTRACTS.md` §0 HARD RULE",
        "#836",
        "#842",
        "#868",
    )

    for phrase in required:
        assert phrase in prompt


def test_operator_prompt_rejects_known_false_or_ambiguous_claims() -> None:
    prompt = _text(PROMPT)

    assert "`TaxCalculator.capitalWithdrawalTax()`" not in prompt
    assert "RetirementTaxCalculator.capitalWithdrawalTax()" in prompt
    assert "CLAUDE.md §0" not in prompt
    assert "Rule 0" not in prompt
    assert "113 paramètres" not in prompt
    assert "095eeaa32" not in prompt
    assert "merge de #848" not in prompt
    assert "#849" in prompt
    assert "superseded par #868" in prompt
    assert "Produit : #836 → #841" not in prompt
    assert "Infra : #842 → #850" not in prompt
    assert "si le script est absent, scorecard `FAIL`" in prompt


def test_operator_prompt_covers_runtime_and_compliance_evidence() -> None:
    prompt = _text(PROMPT)

    required = (
        "EnhancedConfidence",
        "MintTrameConfiance",
        "pdf_text_banned_terms.py",
        "texte extrait du PDF archivé",
        "Maestro flaky",
        "2 retries",
        "Runner.entitlements",
        "Info.plist",
        "command -v patrol",
        'rg -n "patrol:" apps/mobile/pubspec.yaml',
        "Patrol passé",
    )

    for phrase in required:
        assert phrase in prompt


def test_interaction_registry_remains_proposed_and_non_blocking() -> None:
    doc = _text(INTERACTION_REGISTRY)

    assert "Status: Proposed" in doc
    assert "ne bloque" in doc
    assert "SCREEN_CONTRACTS.md` §0 HARD RULE" in doc
    assert "Rule 0" not in doc

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ROADMAP = ROOT / "TEST_ROADMAP.md"
PATROL_POLICY = ROOT / ".github" / "workflows" / "patrol.md"
CI = ROOT / ".github" / "workflows" / "ci.yml"
MAESTRO_DIR = ROOT / "apps" / "mobile" / ".maestro"
PUBSPEC = ROOT / "apps" / "mobile" / "pubspec.yaml"


def _text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_test_roadmap_contract_is_ci_wired() -> None:
    ci = _text(CI)

    assert "tests/checks/test_test_roadmap_contract.py" in ci


def test_test_roadmap_documents_g6_tool_split() -> None:
    roadmap = _text(ROADMAP)

    required_phrases = (
        "Infra-G6 QA Tool Split",
        "Maestro = black-box agent loop",
        "Patrol = white-box native input proof",
        "Current executable state",
        "Promotion gates",
        "Evidence artifacts",
        ".planning/runtime-evidence/",
        "Interaction Registry - walker assertions",
        "not implemented in G6",
    )

    for phrase in required_phrases:
        assert phrase in roadmap


def test_test_roadmap_matches_current_maestro_and_patrol_reality() -> None:
    roadmap = _text(ROADMAP)

    assert MAESTRO_DIR.exists()
    assert any(MAESTRO_DIR.glob("*.yaml"))
    assert "~/.maestro/bin/maestro" in roadmap
    assert "apps/mobile/.maestro/" in roadmap

    pubspec = _text(PUBSPEC)
    assert "patrol:" not in pubspec
    assert "patrol_cli" not in pubspec
    assert "Patrol CLI is not installed in PATH" in roadmap
    assert "apps/mobile/test/patrol/" in roadmap
    assert "manual gap until Patrol is added to pubspec and CI runner support exists" in roadmap


def test_docs_do_not_prescribe_stale_patrol_or_persona_claims() -> None:
    combined = "\n".join((_text(ROADMAP), _text(PATROL_POLICY)))
    obsolete_claims = (
        "nous allons créer un **Test d'Intégration Flutter** (`integration_test/`)",
        "Pour chaque persona, nous allons créer",
        "flutter test test/patrol/",
        "onboarding_patrol_test.dart",
        "document_patrol_test.dart",
    )

    for claim in obsolete_claims:
        assert claim not in combined


def test_patrol_policy_is_consistent_with_roadmap_manual_gate() -> None:
    roadmap = _text(ROADMAP)
    policy = _text(PATROL_POLICY)

    assert "NOT included in CI" in policy
    assert "manual gap" in policy.lower()
    assert "Patrol remains manual" in roadmap
    assert "GitHub Actions ubuntu runners have no iOS simulator support" in roadmap

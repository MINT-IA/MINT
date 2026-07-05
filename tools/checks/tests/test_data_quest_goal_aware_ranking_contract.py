from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
DATA_QUEST = ROOT / "docs/codex/DATA_QUEST.md"
CONFIDENCE_SCORER = (
    ROOT / "apps/mobile/lib/services/financial_core/confidence_scorer.dart"
)


def test_data_quest_doc_matches_live_goal_aware_confidence_ranking() -> None:
    doc = DATA_QUEST.read_text(encoding="utf-8")
    scorer = CONFIDENCE_SCORER.read_text(encoding="utf-8")

    assert "Goal-aware ranking absent" not in doc
    assert "ranker is generic" not in doc
    assert "final String? fieldPath" in scorer
    assert "_compareGoalAwarePromptsWithEvi" in scorer
    assert "_goalAwarePromptScore" in scorer
    assert "ConfidenceScorer.score().prompts" in doc
    assert "GoalAType.achatImmo" in scorer
    assert "GoalAType.retraite" in scorer

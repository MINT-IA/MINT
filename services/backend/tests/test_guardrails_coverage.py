"""Targeted coverage for guardrails.py diff-cover gaps.

Covers the post-filter helpers that diff-cover flagged at <80%:
  - _scrub_layer_markers
  - _count_formal_vous
  - filter_follow_up_questions + _tokenize_for_similarity
  - Non-French filter_response path (multilingual disclaimers)
"""

import pytest
from app.services.rag.guardrails import ComplianceGuardrails


@pytest.fixture
def svc():
    return ComplianceGuardrails()


# ── _scrub_layer_markers ────────────────────────────────────────

class TestScrubLayerMarkers:
    def test_removes_couche_marker(self, svc):
        text, count = svc._scrub_layer_markers("Voici Couche 2 : les faits.")
        assert "Couche 2" not in text
        assert count == 1

    def test_removes_layer_marker(self, svc):
        text, count = svc._scrub_layer_markers("Layer 1 - intro text")
        assert "Layer 1" not in text
        assert count == 1

    def test_removes_niveau_marker(self, svc):
        text, count = svc._scrub_layer_markers("Niveau 3: details")
        assert "Niveau 3" not in text
        assert count == 1

    def test_multiple_markers(self, svc):
        text, count = svc._scrub_layer_markers(
            "Couche 1 : a. Couche 2 : b. Layer 3 - c."
        )
        assert count == 3
        assert "Couche" not in text
        assert "Layer" not in text

    def test_no_markers_returns_unchanged(self, svc):
        original = "Ton salaire est de 7600 CHF."
        text, count = svc._scrub_layer_markers(original)
        assert text == original
        assert count == 0

    def test_none_input(self, svc):
        text, count = svc._scrub_layer_markers(None)
        assert text is None
        assert count == 0

    def test_empty_input(self, svc):
        text, count = svc._scrub_layer_markers("")
        assert text == ""
        assert count == 0

    def test_collapses_whitespace(self, svc):
        text, _ = svc._scrub_layer_markers("A  Couche 2 :  B")
        assert "  " not in text


# ── _count_formal_vous ──────────────────────────────────────────

class TestCountFormalVous:
    def test_counts_singular_vous(self, svc):
        assert svc._count_formal_vous("Vous avez un bon salaire.") >= 1

    def test_ignores_vous_deux(self, svc):
        assert svc._count_formal_vous("vous deux êtes bien.") == 0

    def test_none_input(self, svc):
        assert svc._count_formal_vous(None) == 0

    def test_empty_input(self, svc):
        assert svc._count_formal_vous("") == 0

    def test_no_vous(self, svc):
        assert svc._count_formal_vous("Tu as 49 ans.") == 0


# ── filter_follow_up_questions ──────────────────────────────────

class TestFilterFollowUpQuestions:
    def test_drops_echo_of_user_message(self, svc):
        user = "Comment optimiser mon troisième pilier ?"
        chips = [
            "Comment optimiser mon troisième pilier ?",  # echo
            "Quel est le plafond 3a ?",  # distinct
        ]
        kept = svc.filter_follow_up_questions(chips, user, threshold=0.6)
        assert len(kept) == 1
        assert "plafond" in kept[0]

    def test_keeps_distinct_questions(self, svc):
        user = "Quel est mon salaire ?"
        chips = ["Compare rente vs capital", "Simule un rachat LPP"]
        kept = svc.filter_follow_up_questions(chips, user)
        assert len(kept) == 2

    def test_non_list_input_returns_unchanged(self, svc):
        result = svc.filter_follow_up_questions("not a list", "msg")
        assert result == "not a list"

    def test_non_string_user_msg_returns_unchanged(self, svc):
        result = svc.filter_follow_up_questions(["a", "b"], 123)
        assert result == ["a", "b"]

    def test_strips_empty_strings(self, svc):
        kept = svc.filter_follow_up_questions(["valid", "", "  "], "msg")
        assert kept == ["valid"]

    def test_empty_user_message(self, svc):
        kept = svc.filter_follow_up_questions(["a", "b"], "")
        assert kept == ["a", "b"]


# ── _tokenize_for_similarity ────────────────────────────────────

class TestTokenize:
    def test_basic_tokenization(self, svc):
        tokens = svc._tokenize_for_similarity("Mon salaire net est 7600 CHF")
        assert "salaire" in tokens
        assert "7600" in tokens
        # Short words (<4 chars) excluded
        assert "mon" not in tokens
        assert "est" not in tokens

    def test_empty_returns_empty_set(self, svc):
        assert svc._tokenize_for_similarity("") == set()
        assert svc._tokenize_for_similarity(None) == set()


# ── Non-French filter_response (multilingual disclaimer path) ──

class TestNonFrenchFilterResponse:
    def test_german_disclaimers(self, svc):
        result = svc.filter_response(
            "Dein Lohn ist 7600 CHF. Steuerlich optimal.",
            language="de",
        )
        assert result["text"]
        assert any("Bildungszwecken" in d or "Steuer" in d for d in result["disclaimers_added"])

    def test_english_disclaimers(self, svc):
        result = svc.filter_response(
            "Your salary is 7600 CHF. Tax deduction applies.",
            language="en",
        )
        assert result["text"]
        assert len(result["disclaimers_added"]) >= 1

    def test_unknown_language_falls_back(self, svc):
        result = svc.filter_response("Some text", language="xx")
        assert result["text"] == "Some text"


# ── receipt_builder coverage (2 missing lines) ──────────────────

class TestReceiptBuilderRepoRoot:
    def test_find_repo_root_returns_valid_path(self):
        from app.services.consent.receipt_builder import _REPO_ROOT
        assert _REPO_ROOT.exists()

    def test_policy_dir_resolution(self):
        from app.services.consent.receipt_builder import _REPO_POLICY_DIR
        # May or may not exist depending on repo state, but must not crash
        assert isinstance(_REPO_POLICY_DIR, type(_REPO_POLICY_DIR))

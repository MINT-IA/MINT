from __future__ import annotations

from datetime import datetime, timezone

from app.api.v1.endpoints import coach_chat
from app.models.profile_model import ProfileModel
from app.services.confidence.enhanced_confidence_models import EnrichmentPrompt
from app.services.document_parser.document_models import DataSource
from tests.conftest import TestingSessionLocal


def _insert_profile(user_id: str, data: dict) -> None:
    db = TestingSessionLocal()
    try:
        now = datetime.now(timezone.utc)
        db.add(
            ProfileModel(
                user_id=user_id,
                data=data,
                created_at=now,
                updated_at=now,
            )
        )
        db.commit()
    finally:
        db.close()


def test_compute_suggested_actions_falls_back_without_user_or_db() -> None:
    assert coach_chat._compute_suggested_actions(None, None) == [
        {
            "label": "Dis-moi ton âge et ton canton pour commencer",
            "type": "question",
        }
    ]


def test_compute_suggested_actions_returns_basic_profile_gaps_before_ranker(
    monkeypatch,
) -> None:
    def fail_ranker(profile, field_sources):  # pragma: no cover - assertion guard
        raise AssertionError("basic profile gaps must short-circuit enrichment")

    monkeypatch.setattr(coach_chat, "rank_enrichment_prompts", fail_ranker)
    _insert_profile("suggest-basic-gaps", {"canton": "VD"})

    db = TestingSessionLocal()
    try:
        actions = coach_chat._compute_suggested_actions("suggest-basic-gaps", db)
    finally:
        db.close()

    assert actions == [
        {"label": "Quel âge as-tu ?", "type": "question"},
        {"label": "Quel est ton salaire net mensuel ?", "type": "question"},
    ]


def test_compute_suggested_actions_passes_provenance_sources_to_ranker(
    monkeypatch,
) -> None:
    captured: dict = {}

    def fake_ranker(profile, field_sources):
        captured["profile"] = profile
        captured["field_sources"] = field_sources
        return [
            EnrichmentPrompt(
                field_name="lpp_total",
                action="Scanne ton certificat de prevoyance LPP",
                impact_points=18.0,
                method="document_scan",
                priority=1,
            ),
            EnrichmentPrompt(
                field_name="monthly_expenses",
                action="Entre tes charges mensuelles",
                impact_points=8.0,
                method="manual_entry",
                priority=2,
            ),
        ]

    monkeypatch.setattr(coach_chat, "rank_enrichment_prompts", fake_ranker)
    _insert_profile(
        "suggest-provenance",
        {
            "birthYear": 1985,
            "canton": "VD",
            "incomeGrossYearly": 120000,
            "avoirLpp": 90000,
            "_provenance": {
                "sources": {
                    "incomeGrossYearly": "openBanking",
                    "avoirLpp": "certificate",
                },
                "updated": {
                    "incomeGrossYearly": "2026-01-31T08:00:00+00:00",
                    "avoirLpp": "2026-02-15T08:00:00+00:00",
                },
            },
        },
    )

    db = TestingSessionLocal()
    try:
        actions = coach_chat._compute_suggested_actions("suggest-provenance", db)
    finally:
        db.close()

    assert captured["profile"]["salaire_brut"] == 120000
    assert captured["profile"]["lpp_total"] == 90000
    sources_by_field = {
        source.field_name: source for source in captured["field_sources"]
    }
    assert sources_by_field["salaire_brut"].source == DataSource.open_banking
    assert sources_by_field["lpp_total"].source == DataSource.document_scan_verified
    assert sources_by_field["lpp_total"].updated_at == "2026-02-15T08:00:00+00:00"
    assert actions == [
        {"label": "Scanne ton certificat de prevoyance LPP", "type": "upload"},
        {"label": "Entre tes charges mensuelles", "type": "question"},
    ]


def test_compute_suggested_actions_with_high_quality_sources_suppresses_done_uploads() -> None:
    _insert_profile(
        "suggest-high-quality",
        {
            "birthYear": 1985,
            "canton": "VD",
            "incomeGrossYearly": 120000,
            "avoirLpp": 90000,
            "_provenance": {
                "sources": {
                    "incomeGrossYearly": "openBanking",
                    "avoirLpp": "certificate",
                },
                "updated": {
                    "incomeGrossYearly": "2026-01-31T08:00:00+00:00",
                    "avoirLpp": "2026-02-15T08:00:00+00:00",
                },
            },
        },
    )

    db = TestingSessionLocal()
    try:
        actions = coach_chat._compute_suggested_actions("suggest-high-quality", db)
    finally:
        db.close()

    labels = {action["label"] for action in actions}
    assert "Connecte ton compte bancaire via Open Banking" not in labels
    assert "Scanne ton certificat de prevoyance LPP" not in labels
    assert actions

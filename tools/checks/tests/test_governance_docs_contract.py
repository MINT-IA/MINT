from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CLAUDE = ROOT / "CLAUDE.md"
RULES = ROOT / "rules.md"
HOSTING_ADR = ROOT / "decisions" / "ADR-hosting-migration.md"


def _text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_claude_md_declares_repo_memory_hierarchy() -> None:
    claude = _text(CLAUDE)

    for phrase in (
        "Memory hierarchy",
        "repo git/ADR/AGENTS_LOG is the source of truth",
        "Engram is a recall index",
        "not a primary source",
        "the repo wins",
    ):
        assert phrase in claude


def test_rules_md_uses_repo_reality_reconciliation() -> None:
    rules = _text(RULES)

    assert ".claude/CLAUDE.md" not in rules
    assert "Code — Implementation follows documents" not in rules
    for phrase in (
        "CLAUDE.md — Project context",
        "Code/repo reality — authoritative implementation evidence",
        "reconcile with code, SOT/OpenAPI, and ADRs",
        "Engram is never source of truth",
    ):
        assert phrase in rules


def test_hosting_adr_exists_and_follows_template() -> None:
    adr = _text(HOSTING_ADR)

    for heading in (
        "## Context",
        "## Decision",
        "## Current Exceptions",
        "## Migration Triggers",
        "## Alternatives Considered",
        "## Consequences",
        "## Migration Plan",
        "## Evidence Links",
    ):
        assert heading in adr


def test_hosting_adr_states_stateless_railway_target_without_hiding_exceptions() -> None:
    adr = _text(HOSTING_ADR)

    required_phrases = (
        "Railway target = stateless compute only",
        "no new raw identifiable financial amount persisted server-side on Railway",
        "Existing backend persistence means MINT cannot claim Railway is stateless today",
        "services/backend/app/models/snapshot.py:27",
        "gross_income",
        "services/backend/app/models/profile_model.py:37",
        "full profile as JSON",
        "services/backend/app/api/v1/endpoints/profiles.py:120",
        "services/backend/app/api/v1/endpoints/profiles.py:268",
        "services/backend/app/models/scenario.py:20",
        "services/backend/app/models/scenario.py:21",
        "inputs",
        "outputs",
        "services/backend/app/models/external_data_source.py:26",
        "cached_response",
        "registered schema with no checked-in writer",
        "services/backend/app/models/document_memory.py:65",
        "services/backend/app/models/document_memory.py:67",
        "evidence_text",
        "vision_raw",
        "services/backend/app/models/coach_insight.py:45",
        "summary",
        "services/backend/app/models/earmark.py:89",
        "amount_hint",
        "services/backend/app/models/billing.py:86",
        "amount_cents",
        "services/backend/app/models/snapshot.py:35",
        "tax_saving_potential",
        "already a production-readiness requirement",
        "Infomaniak",
        "Exoscale",
        "FINMA",
        "server-side storage of identifiable financial data",
        "regulatory requirement",
    )

    for phrase in required_phrases:
        assert phrase in adr


def test_hosting_adr_is_proposed_until_exceptions_are_removed_or_migrated() -> None:
    adr = _text(HOSTING_ADR)

    assert "Status: Proposed" in adr
    assert "Accepted" not in adr.splitlines()[:8]

"""
Knowledge base status endpoint — RAG v2.

Exposes a health-check for the S67 knowledge catalog so operators
can verify coverage without touching the vector store.
"""

from __future__ import annotations

from fastapi import APIRouter

from app.services.rag.knowledge_catalog import KnowledgeCatalog
from app.services.rag.update_pipeline import KnowledgeUpdatePipeline

router = APIRouter()


@router.get("/knowledge/status")
# TODO(security): Add auth guard when moving to production.
# Currently returns only aggregate public stats (no user data, no PII).
# Low risk as-is, but should require at minimum an API key header before
# exposing to external consumers in a production environment.
def knowledge_status() -> dict:
    """Return the status of the RAG knowledge base.

    Combines the full knowledge catalog with the update pipeline
    to produce a coverage and freshness report.

    Returns:
        Dict with keys: total_sources, up_to_date, needs_update,
        coverage_gaps.
    """
    catalog = KnowledgeCatalog.all_sources()
    report = KnowledgeUpdatePipeline.generate_update_report(catalog)
    return {
        "total_sources": report.total_sources,
        "up_to_date": report.up_to_date,
        "needs_update": report.needs_update,
        "coverage_gaps": report.coverage_gaps,
    }

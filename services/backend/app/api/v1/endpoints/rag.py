"""
RAG (Retrieval-Augmented Generation) endpoints for MINT.

Phase 0: BYOK (Bring Your Own Key) — user provides their own LLM API key.
MINT never stores API keys; they are used per-request only.
"""

import logging
import os

from fastapi import APIRouter, Depends, HTTPException, Request

from app.core.auth import require_current_user
from app.core.rate_limit import limiter
from app.models.user import User

from app.schemas.rag import (
    RAGIngestRequest,
    RAGIngestResponse,
    RAGQueryRequest,
    RAGQueryResponse,
    RAGSource,
    RAGStatusResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter()

# Lazy-initialized singleton for the vector store and orchestrator
_vector_store = None
_orchestrator = None


def _get_vector_store():
    """Get or create the singleton vector store instance."""
    global _vector_store
    if _vector_store is None:
        try:
            from app.services.rag.vector_store import MintVectorStore

            # Determine persist directory relative to backend root
            backend_dir = os.path.dirname(
                os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
            )
            persist_dir = os.path.join(backend_dir, "data", "chromadb")
            _vector_store = MintVectorStore(persist_directory=persist_dir)
        except ImportError:
            raise HTTPException(
                status_code=503,
                detail="RAG dependencies not installed. Install with: pip install -e '.[rag]'",
            )
    return _vector_store


def _get_orchestrator():
    """Get or create the singleton orchestrator instance."""
    global _orchestrator
    if _orchestrator is None:
        try:
            from app.services.rag.orchestrator import RAGOrchestrator

            _orchestrator = RAGOrchestrator(vector_store=_get_vector_store())
        except ImportError:
            raise HTTPException(
                status_code=503,
                detail="RAG dependencies not installed. Install with: pip install -e '.[rag]'",
            )
    return _orchestrator


@router.post("/query", response_model=RAGQueryResponse)
@limiter.limit("20/minute")
async def rag_query(request: Request, body: RAGQueryRequest, _user: User = Depends(require_current_user)):
    """
    Main RAG query endpoint.

    Accepts a user question + BYOK API key, retrieves relevant context
    from the MINT knowledge base, and generates a compliance-filtered response.

    The API key is used for a single request and never stored.
    """
    orchestrator = _get_orchestrator()

    # Build profile context dict if provided
    profile_ctx = None
    if body.profile_context:
        profile_ctx = body.profile_context.model_dump(exclude_none=True)

    try:
        result = await orchestrator.query(
            question=body.question,
            api_key=body.api_key,
            provider=body.provider.value,
            model=body.model,
            profile_context=profile_ctx,
            language=body.language.value,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except ImportError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error("RAG query failed: %s", e)
        raise HTTPException(
            status_code=502,
            detail=f"LLM API call failed: {str(e)}",
        )

    return RAGQueryResponse(
        answer=result["answer"],
        sources=[RAGSource(**s) for s in result.get("sources", [])],
        disclaimers=result.get("disclaimers", []),
        tokens_used=result.get("tokens_used", 0),
    )


@router.post("/ingest", response_model=RAGIngestResponse)
@limiter.limit("2/minute")
async def rag_ingest(request: Request, body: RAGIngestRequest, _user: User = Depends(require_current_user)):
    """
    Trigger knowledge base ingestion (admin endpoint).

    Ingests markdown files from the specified directory into the vector store.
    Only admin users (email ending with @mint.ch) can use this endpoint.
    """
    # Admin gate: only @mint.ch emails can ingest
    if not _user.email or not _user.email.endswith("@mint.ch"):
        raise HTTPException(
            status_code=403,
            detail="Admin access required for knowledge base ingestion",
        )

    try:
        from app.services.rag.ingester import MarkdownIngester
    except ImportError:
        raise HTTPException(
            status_code=503,
            detail="RAG dependencies not installed. Install with: pip install -e '.[rag]'",
        )

    vector_store = _get_vector_store()

    # Validate directory: must be within the project tree (prevent traversal)
    backend_dir = os.path.dirname(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
    )
    resolved = os.path.realpath(body.directory)
    project_root = os.path.realpath(os.path.join(backend_dir, ".."))
    if not resolved.startswith(project_root):
        raise HTTPException(
            status_code=400,
            detail="Directory must be within the MINT project tree",
        )

    if not os.path.isdir(resolved):
        raise HTTPException(
            status_code=400,
            detail=f"Directory not found: {body.directory}",
        )

    ingester = MarkdownIngester(vector_store=vector_store)
    count = ingester.ingest_directory(
        directory=resolved,
        language=body.language,
    )

    return RAGIngestResponse(
        documents_ingested=count,
        status="ok" if count > 0 else "no_documents_found",
    )


@router.get("/status", response_model=RAGStatusResponse)
async def rag_status():
    """
    Check RAG system status.

    Returns vector store readiness, document count, and available collections.
    """
    try:
        vector_store = _get_vector_store()
        return RAGStatusResponse(
            vector_store_ready=True,
            documents_count=vector_store.count(),
            collections=vector_store.list_collections(),
        )
    except HTTPException:
        # RAG not available
        return RAGStatusResponse(
            vector_store_ready=False,
            documents_count=0,
            collections=[],
        )
    except Exception as e:
        logger.error("RAG status check failed: %s", e)
        return RAGStatusResponse(
            vector_store_ready=False,
            documents_count=0,
            collections=[],
        )

"""
RAG (Retrieval-Augmented Generation) endpoints for MINT.

Phase 0: BYOK (Bring Your Own Key) — user provides their own LLM API key.
MINT never stores API keys; they are used per-request only.
"""

import asyncio
import logging
import os

from fastapi import APIRouter, Depends, HTTPException, Request

from app.core.auth import require_current_user
from app.core.rate_limit import limiter
from app.models.user import User

from app.schemas.rag import (
    ExtractedDocumentField,
    RAGIngestRequest,
    RAGIngestResponse,
    RAGQueryRequest,
    RAGQueryResponse,
    RAGSource,
    RAGStatusResponse,
    RAGVisionRequest,
    RAGVisionResponse,
    VISION_PROVIDERS,
)

logger = logging.getLogger(__name__)

router = APIRouter()

# Lazy-initialized singleton for the vector store and orchestrator
_vector_store = None
_orchestrator = None
# P1-10: asyncio.Lock to prevent race condition during singleton initialization
_init_lock = asyncio.Lock()


def _get_vector_store():
    """Get or create the singleton vector store instance (sync, for non-async callers)."""
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
                headers={"X-Error-Code": "rag_failure"},
            )
    return _vector_store


async def _get_vector_store_safe():
    """Get or create the singleton vector store with async lock protection."""
    global _vector_store
    if _vector_store is not None:
        return _vector_store
    async with _init_lock:
        if _vector_store is not None:
            return _vector_store
        return _get_vector_store()


async def _get_orchestrator_safe():
    """Get or create the singleton orchestrator with async lock protection."""
    global _orchestrator
    if _orchestrator is not None:
        return _orchestrator
    async with _init_lock:
        if _orchestrator is not None:
            return _orchestrator
        try:
            from app.services.rag.orchestrator import RAGOrchestrator

            vs = _get_vector_store()
            _orchestrator = RAGOrchestrator(vector_store=vs)
        except ImportError:
            raise HTTPException(
                status_code=503,
                detail="RAG dependencies not installed. Install with: pip install -e '.[rag]'",
                headers={"X-Error-Code": "rag_failure"},
            )
        return _orchestrator


def _get_orchestrator():
    """Get or create the singleton orchestrator instance (sync fallback)."""
    global _orchestrator
    if _orchestrator is None:
        try:
            from app.services.rag.orchestrator import RAGOrchestrator

            _orchestrator = RAGOrchestrator(vector_store=_get_vector_store())
        except ImportError:
            raise HTTPException(
                status_code=503,
                detail="RAG dependencies not installed. Install with: pip install -e '.[rag]'",
                headers={"X-Error-Code": "rag_failure"},
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
    # TODO(nLPD art. 6 al. 7): Verify byok_data_sharing consent before querying
    # user-specific data in RAG. Requires ConsentManager.is_consent_given(
    # user_id, ConsentType.byok_data_sharing). Without consent, RAG should only
    # search the public MINT knowledge base, not user-uploaded documents.
    orchestrator = await _get_orchestrator_safe()

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
            user_id=_user.id if _user else None,
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")
    except ImportError:
        raise HTTPException(
            status_code=503,
            detail="Service temporarily unavailable",
            headers={"X-Error-Code": "service_unavailable"},
        )
    except Exception as e:
        logger.error("RAG query failed: %s", e)
        raise HTTPException(
            status_code=502,
            detail="External service unavailable",
            headers={"X-Error-Code": "rag_failure"},
        )

    return RAGQueryResponse(
        answer=result["answer"],
        sources=[RAGSource(**s) for s in result.get("sources", [])],
        disclaimers=result.get("disclaimers", []),
        tokens_used=result.get("tokens_used", 0),
    )


@router.post("/vision", response_model=RAGVisionResponse)
@limiter.limit("10/minute")
async def rag_vision(request: Request, body: RAGVisionRequest, _user: User = Depends(require_current_user)):
    """
    Vision-augmented document extraction endpoint.

    Accepts a base64-encoded document image + BYOK API key.
    Extracts structured financial data via Claude/GPT-4o vision.

    Only Claude and OpenAI support vision — Mistral will be rejected.
    The image is processed in-flight and never stored by MINT.
    """
    # Validate provider supports vision
    if body.provider.value not in VISION_PROVIDERS:
        raise HTTPException(
            status_code=400,
            detail=f"Provider '{body.provider.value}' does not support vision. "
            f"Supported: {', '.join(sorted(VISION_PROVIDERS))}",
        )

    # Validate media type
    allowed_media = {"image/jpeg", "image/png", "image/webp"}
    if body.media_type not in allowed_media:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported media type '{body.media_type}'. "
            f"Supported: {', '.join(sorted(allowed_media))}",
        )

    # Validate base64 size before decoding (prevent DoS via large payloads)
    import base64
    # ~26.8 MB base64 string ≈ 20 MB decoded
    if len(body.image_base64) > 26_843_546:
        raise HTTPException(status_code=413, detail="Image exceeds 20 MB limit")
    try:
        raw = base64.b64decode(body.image_base64, validate=True)
        if len(raw) > 20 * 1024 * 1024:  # 20 MB limit
            raise HTTPException(status_code=413, detail="Image exceeds 20 MB limit")
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid base64 image data")

    orchestrator = await _get_orchestrator_safe()

    profile_ctx = None
    if body.profile_context:
        profile_ctx = body.profile_context.model_dump(exclude_none=True)

    try:
        result = await orchestrator.query_vision(
            image_base64=body.image_base64,
            media_type=body.media_type,
            document_type=body.document_type.value,
            api_key=body.api_key,
            provider=body.provider.value,
            model=body.model,
            profile_context=profile_ctx,
            language=body.language.value,
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid request parameters")
    except ImportError:
        raise HTTPException(
            status_code=503,
            detail="Service temporarily unavailable",
            headers={"X-Error-Code": "service_unavailable"},
        )
    except Exception as e:
        logger.error("RAG vision query failed: %s", e)
        raise HTTPException(
            status_code=502,
            detail="External service unavailable",
            headers={"X-Error-Code": "rag_failure"},
        )

    return RAGVisionResponse(
        extracted_fields=[
            ExtractedDocumentField(**f) for f in result.get("extracted_fields", [])
        ],
        document_type_detected=result.get("document_type_detected", ""),
        raw_analysis=result.get("raw_analysis", ""),
        confidence_delta=result.get("confidence_delta", 0),
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
async def rag_status(_user: User = Depends(require_current_user)):
    """
    Check RAG system status.

    Returns vector store readiness, document count, and available collections.
    Requires authentication to prevent reconnaissance of internal state.
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

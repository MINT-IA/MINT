"""
RAG (Retrieval-Augmented Generation) module for MINT.

Phase 0: Lightweight BYOK (Bring Your Own Key) implementation.
Uses ChromaDB for local vector storage and supports Claude, OpenAI, and Mistral APIs.

Dependencies are optional — install with: pip install -e ".[rag]"
"""

try:
    from app.services.rag.vector_store import MintVectorStore
    from app.services.rag.llm_client import LLMClient
    from app.services.rag.ingester import MarkdownIngester
    from app.services.rag.retriever import MintRetriever
    from app.services.rag.orchestrator import RAGOrchestrator
    from app.services.rag.guardrails import ComplianceGuardrails

    RAG_AVAILABLE = True
except ImportError:
    RAG_AVAILABLE = False

__all__ = [
    "MintVectorStore",
    "LLMClient",
    "MarkdownIngester",
    "MintRetriever",
    "RAGOrchestrator",
    "ComplianceGuardrails",
    "RAG_AVAILABLE",
]

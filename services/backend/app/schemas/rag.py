"""
Pydantic schemas for RAG endpoints.

Defines request/response models for the RAG query, ingest, and status endpoints.
"""

from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class LLMProvider(str, Enum):
    """Supported LLM providers."""
    claude = "claude"
    openai = "openai"
    mistral = "mistral"


class RAGLanguage(str, Enum):
    """Supported languages."""
    fr = "fr"
    de = "de"
    en = "en"
    it = "it"


# --- RAG Query ---


class ProfileContext(BaseModel):
    """Optional profile context for personalizing RAG responses."""
    canton: Optional[str] = Field(None, description="Swiss canton code (e.g., 'VD', 'ZH')")
    age: Optional[int] = Field(None, ge=16, le=120, description="User's age")
    civil_status: Optional[str] = Field(None, description="Civil status (single, married, etc.)")
    employment_status: Optional[str] = Field(None, description="Employment status (employed, self-employed, etc.)")
    financial_summary: Optional[str] = Field(
        None,
        max_length=3000,
        description="Rich financial summary built from user's diagnostic, "
        "contributions, check-ins, and fitness score. "
        "Injected into the system prompt for personalized responses.",
    )


class RAGQueryRequest(BaseModel):
    """Request body for the RAG query endpoint."""
    question: str = Field(
        ...,
        min_length=3,
        max_length=2000,
        description="The user's question about Swiss personal finance",
    )
    api_key: str = Field(
        ...,
        min_length=1,
        description="User's LLM API key (BYOK — not stored by MINT)",
    )
    provider: LLMProvider = Field(
        ...,
        description="LLM provider to use",
    )
    model: Optional[str] = Field(
        None,
        description="Optional model override (uses provider default if not set)",
    )
    profile_context: Optional[ProfileContext] = Field(
        None,
        description="Optional profile data for personalized responses",
    )
    language: RAGLanguage = Field(
        RAGLanguage.fr,
        description="Response language",
    )


class RAGSource(BaseModel):
    """A source reference from the knowledge base."""
    title: str = Field("", description="Document title")
    file: str = Field("", description="Source filename")
    section: str = Field("", description="Section within the document")


class RAGQueryResponse(BaseModel):
    """Response from the RAG query endpoint."""
    answer: str = Field(..., description="The generated answer")
    sources: list[RAGSource] = Field(
        default_factory=list,
        description="Knowledge base sources used",
    )
    disclaimers: list[str] = Field(
        default_factory=list,
        description="Compliance disclaimers appended",
    )
    tokens_used: int = Field(0, description="Estimated token usage")


# --- RAG Ingest ---


class RAGIngestRequest(BaseModel):
    """Request body for the RAG ingest endpoint."""
    directory: str = Field(
        ...,
        description="Path to the directory containing markdown files to ingest",
    )
    language: Optional[str] = Field(
        None,
        description="Override language for all files (auto-detected if not set)",
    )


class RAGIngestResponse(BaseModel):
    """Response from the RAG ingest endpoint."""
    documents_ingested: int = Field(..., description="Number of document chunks ingested")
    status: str = Field(..., description="Ingestion status message")


# --- RAG Status ---


class RAGStatusResponse(BaseModel):
    """Response from the RAG status endpoint."""
    vector_store_ready: bool = Field(..., description="Whether the vector store is initialized")
    documents_count: int = Field(0, description="Number of documents in the store")
    collections: list[str] = Field(
        default_factory=list,
        description="Available collection names",
    )

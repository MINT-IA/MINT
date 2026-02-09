"""
Pydantic schemas for Document Intelligence (Docling) endpoints.

Defines request/response models for document upload, listing, and retrieval.
"""

from typing import Optional

from pydantic import BaseModel, Field


class DocumentUploadResponse(BaseModel):
    """Response from a document upload and extraction."""

    document_id: str = Field(..., description="Unique identifier for the uploaded document")
    document_type: str = Field(
        ...,
        description="Detected document type: 'lpp_certificate', 'salary_slip', 'unknown'",
    )
    extracted_fields: dict = Field(
        default_factory=dict,
        description="Extracted fields from the document (LPPCertificateData as dict)",
    )
    confidence: float = Field(
        0.0,
        ge=0.0,
        le=1.0,
        description="Overall extraction confidence score [0-1]",
    )
    fields_found: int = Field(0, description="Number of fields successfully extracted")
    fields_total: int = Field(18, description="Total possible fields")
    raw_text_preview: str = Field(
        "",
        description="First 500 characters of extracted text (for user verification)",
    )
    warnings: list[str] = Field(
        default_factory=list,
        description="Any warnings or issues during extraction",
    )
    rag_indexed: bool = Field(
        False,
        description="Whether the extracted data was indexed in the RAG vector store",
    )


class DocumentSummary(BaseModel):
    """Summary of an uploaded document."""

    id: str = Field(..., description="Unique document identifier")
    document_type: str = Field(..., description="Document type")
    upload_date: str = Field(..., description="ISO 8601 upload timestamp")
    confidence: float = Field(0.0, description="Extraction confidence")
    fields_found: int = Field(0, description="Number of fields extracted")


class DocumentListResponse(BaseModel):
    """Response for listing uploaded documents."""

    documents: list[DocumentSummary] = Field(
        default_factory=list,
        description="List of document summaries",
    )


class DocumentDetailResponse(BaseModel):
    """Detailed response for a single document."""

    id: str = Field(..., description="Unique document identifier")
    document_type: str = Field(..., description="Document type")
    upload_date: str = Field(..., description="ISO 8601 upload timestamp")
    confidence: float = Field(0.0, description="Extraction confidence")
    fields_found: int = Field(0, description="Number of fields extracted")
    fields_total: int = Field(18, description="Total possible fields")
    extracted_fields: dict = Field(
        default_factory=dict,
        description="Extracted fields",
    )
    warnings: list[str] = Field(
        default_factory=list,
        description="Warnings from extraction",
    )


class DocumentDeleteResponse(BaseModel):
    """Response for document deletion."""

    deleted: bool = Field(..., description="Whether the document was deleted")
    id: str = Field(..., description="Deleted document ID")

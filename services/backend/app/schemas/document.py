"""
Pydantic schemas for Document Intelligence (Docling) endpoints.

Defines request/response models for document upload, listing, and retrieval.
"""

from typing import Optional

from pydantic import BaseModel, Field


class DocumentUploadResponse(BaseModel):
    """Response from a document upload and extraction."""

    id: str = Field(..., description="Unique identifier for the uploaded document")
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


# ──────────────────────────────────────────────────────────────────────────────
# Bank Statement Schemas (Docling Phase 2)
# ──────────────────────────────────────────────────────────────────────────────


class TransactionResponse(BaseModel):
    """A single bank transaction in the API response."""

    date: str = Field(..., description="Transaction date in ISO format (YYYY-MM-DD)")
    description: str = Field("", description="Transaction description")
    amount: float = Field(..., description="Amount: positive=credit, negative=debit")
    balance: Optional[float] = Field(None, description="Running balance after transaction")
    category: str = Field("divers", description="Auto-detected spending category")
    subcategory: Optional[str] = Field(None, description="More specific sub-category")
    is_recurring: bool = Field(False, description="Whether the transaction is detected as recurring")


class BankStatementUploadResponse(BaseModel):
    """Response from a bank statement upload and extraction."""

    document_type: str = Field(
        "bank_statement",
        description="Document type (always 'bank_statement')",
    )
    bank_name: Optional[str] = Field(None, description="Detected bank name (UBS, PostFinance, etc.)")
    period_start: Optional[str] = Field(None, description="Statement period start (ISO date)")
    period_end: Optional[str] = Field(None, description="Statement period end (ISO date)")
    currency: str = Field("CHF", description="Currency code")
    transactions: list[TransactionResponse] = Field(
        default_factory=list,
        description="Extracted and categorized transactions",
    )
    total_credits: float = Field(0.0, description="Sum of all credit (positive) amounts")
    total_debits: float = Field(0.0, description="Sum of all debit (negative) amounts")
    opening_balance: Optional[float] = Field(None, description="Opening balance")
    closing_balance: Optional[float] = Field(None, description="Closing balance")
    confidence: float = Field(
        0.0,
        ge=0.0,
        le=1.0,
        description="Extraction confidence score [0-1]",
    )
    warnings: list[str] = Field(
        default_factory=list,
        description="Warnings or issues during extraction",
    )
    category_summary: dict[str, float] = Field(
        default_factory=dict,
        description="Total amount per category",
    )
    recurring_monthly: list[TransactionResponse] = Field(
        default_factory=list,
        description="Detected recurring monthly transactions",
    )


class BudgetImportPreview(BaseModel):
    """Preview of what would be imported into the budget module."""

    estimated_monthly_income: float = Field(
        0.0, description="Estimated average monthly income"
    )
    estimated_monthly_expenses: float = Field(
        0.0, description="Estimated average monthly expenses"
    )
    top_categories: list[dict] = Field(
        default_factory=list,
        description="Top spending categories with amount and percentage",
    )
    recurring_charges: list[dict] = Field(
        default_factory=list,
        description="Detected recurring charges with description, amount, frequency",
    )
    savings_rate: float = Field(
        0.0, description="Estimated savings rate as percentage"
    )

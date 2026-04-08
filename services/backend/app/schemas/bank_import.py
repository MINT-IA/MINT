"""
Pydantic v2 schemas for the bank import endpoint.

Defines response models for bank statement upload, parsing, and categorization.
"""

from typing import Optional

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class TransactionSchema(BaseModel):
    """A single parsed and categorized bank transaction."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    date: str = Field(..., description="Transaction date (YYYY-MM-DD)")
    description: str = Field("", description="Transaction description text")
    amount: float = Field(..., description="Amount: positive=credit, negative=debit")
    balance: Optional[float] = Field(None, description="Running balance after transaction")
    category: str = Field("Divers", description="Auto-detected spending category")
    subcategory: Optional[str] = Field(None, description="More specific sub-category")
    is_recurring: bool = Field(False, description="Whether detected as recurring")


class BankImportResponse(BaseModel):
    """Response from the bank statement import endpoint."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    bank_name: str = Field(..., description="Detected bank name (UBS, PostFinance, etc.)")
    format: str = Field(..., description="Detected format identifier")
    transactions: list[TransactionSchema] = Field(
        default_factory=list,
        description="Parsed and categorized transactions",
    )
    period_start: Optional[str] = Field(None, description="First transaction date (YYYY-MM-DD)")
    period_end: Optional[str] = Field(None, description="Last transaction date (YYYY-MM-DD)")
    currency: str = Field("CHF", description="Currency code")
    opening_balance: Optional[float] = Field(None, description="Opening balance")
    closing_balance: Optional[float] = Field(None, description="Closing balance")
    total_credits: float = Field(0.0, description="Sum of all credit amounts")
    total_debits: float = Field(0.0, description="Sum of all debit amounts (negative)")
    category_summary: dict[str, float] = Field(
        default_factory=dict,
        description="Total absolute spend per category",
    )
    confidence: float = Field(
        0.0,
        ge=0.0,
        le=1.0,
        description="Parsing confidence [0-1]",
    )
    transaction_count: int = Field(0, description="Total number of parsed transactions")
    warnings: list[str] = Field(
        default_factory=list,
        description="Warnings or issues during parsing",
    )
    disclaimer: str = Field(
        default="Outil educatif — ne constitue pas un conseil financier (LSFin).",
        description="Legal disclaimer",
    )


class BankImportErrorResponse(BaseModel):
    """Error response when parsing fails."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    error: str = Field(..., description="Error message")
    supported_formats: list[str] = Field(
        default=[
            "UBS (CSV)",
            "PostFinance (CSV)",
            "Raiffeisen (CSV)",
            "BCGE/BCV (CSV)",
            "CS/ZKB (CSV)",
            "Yuh/Neon (CSV)",
            "ISO 20022 camt.053 (XML)",
            "ISO 20022 camt.054 (XML)",
        ],
        description="List of supported bank statement formats",
    )

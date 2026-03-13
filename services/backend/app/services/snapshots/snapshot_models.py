"""
Snapshot Models — Dataclasses for financial snapshots.

Sprint S33 — Snapshot System.

A FinancialSnapshot captures the user's financial state at a point in time,
triggered by quarterly check-ins, life events, or profile updates.

Used for:
- Evolution tracking (how key metrics change over time)
- Progress visualization (FRI scores, replacement ratio)
- LPD-compliant data management (right to erasure)

Sources:
    - LPD (Loi sur la protection des donnees) — right to erasure
"""

from dataclasses import dataclass


# Valid trigger types for snapshot creation
VALID_TRIGGERS = {"quarterly", "life_event", "profile_update", "check_in"}


@dataclass
class FinancialSnapshot:
    """A point-in-time capture of a user's financial state.

    Attributes:
        id: Unique identifier (UUID).
        user_id: User identifier.
        created_at: ISO 8601 timestamp.
        trigger: What triggered this snapshot.
        model_version: Schema version for forward compatibility.
        age: User's age at snapshot time.
        gross_income: Annual gross income (CHF).
        canton: Canton of fiscal domicile.
        archetype: Financial archetype (swiss_native, expat_eu, etc.).
        household_type: Household type (single, married, concubin, etc.).
        replacement_ratio: Estimated retirement replacement ratio (0-1).
        months_liquidity: Months of liquidity reserve.
        tax_saving_potential: Estimated annual tax saving potential (CHF).
        confidence_score: Projection confidence score (0-100).
        enrichment_count: Number of enrichment prompts acted on.
        fri_total: Financial Readiness Index total score (0-100).
        fri_l: FRI Liquidity sub-score (0-100).
        fri_f: FRI Fiscal sub-score (0-100).
        fri_r: FRI Retirement sub-score (0-100).
        fri_s: FRI Security sub-score (0-100).
    """

    id: str
    user_id: str
    created_at: str
    trigger: str
    model_version: str = "1.0"
    # Core inputs
    age: int = 0
    gross_income: float = 0.0
    canton: str = "VD"
    archetype: str = "swiss_native"
    household_type: str = "single"
    # Key outputs
    replacement_ratio: float = 0.0
    months_liquidity: float = 0.0
    tax_saving_potential: float = 0.0
    confidence_score: float = 0.0
    enrichment_count: int = 0
    # FRI scores (for future S38)
    fri_total: float = 0.0
    fri_l: float = 0.0
    fri_f: float = 0.0
    fri_r: float = 0.0
    fri_s: float = 0.0

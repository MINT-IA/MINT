"""
Reengagement data models — Sprint S40.

Dataclasses and enums for:
    - ReengagementTrigger: calendar-based triggers
    - ReengagementMessage: personalized messages with CHF numbers + deadlines
    - ConsentType / ConsentState / ConsentDashboard: nLPD-compliant consent

Sources:
    - OPP3 art. 7 (plafond 3a)
    - LPD art. 6 (principes de traitement)
    - nLPD art. 5 let. f (profilage)
    - LSFin art. 3 (information financiere)
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import List


class ReengagementTrigger(str, Enum):
    """Calendar-based reengagement triggers."""

    new_year = "new_year"                        # January
    tax_prep = "tax_prep"                        # February
    tax_deadline = "tax_deadline"                # March (canton-specific)
    three_a_countdown = "three_a_countdown"      # October
    three_a_urgency = "three_a_urgency"          # November
    three_a_final = "three_a_final"              # December
    quarterly_fri = "quarterly_fri"              # Every 3 months (1, 4, 7, 10)


@dataclass
class ReengagementMessage:
    """A personalized reengagement message.

    NEVER generic. Always contains:
    - personal_number: a CHF amount or % value
    - time_constraint: a deadline or time window
    - deeplink: link to the relevant simulation
    """

    trigger: ReengagementTrigger
    title: str              # Max 60 chars
    body: str               # Must contain personal number + time constraint
    deeplink: str           # Link to relevant simulation
    personal_number: str    # CHF or % value
    time_constraint: str    # Deadline or window
    month: int              # 1-12


class ConsentType(str, Enum):
    """Independent consent types (nLPD compliant)."""

    byok_data_sharing = "byok_data_sharing"
    snapshot_storage = "snapshot_storage"
    notifications = "notifications"
    document_upload = "document_upload"
    conversation_memory = "conversation_memory"


@dataclass
class ConsentState:
    """State of a single consent toggle.

    Each consent is independent and revocable at any time (nLPD art. 6).
    """

    consent_type: ConsentType
    enabled: bool
    label: str              # French description
    detail: str             # What exactly is shared/stored
    never_sent: str         # What is NEVER shared (privacy reassurance)
    revocable: bool = True  # Always True


@dataclass
class ConsentDashboard:
    """Full consent dashboard with all 3 toggles.

    All consents default to OFF (opt-in model, nLPD compliant).
    """

    consents: List[ConsentState]
    disclaimer: str = (
        "Tes donnees t'appartiennent. "
        "Chaque parametre est revocable a tout moment (nLPD art. 6)."
    )
    sources: List[str] = field(default_factory=lambda: [
        "LPD art. 6 (principes de traitement)",
        "nLPD art. 5 let. f (profilage)",
        "LSFin art. 3 (information financiere)",
    ])

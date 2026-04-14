"""Privacy hardening services — Phase 29 (PRIV-03 + PRIV-06).

Modules:
    - pii_scrubber: scrub() entry point (Presidio + custom CH recognizers + regex fallback)
    - fpe: format-preserving encryption for IBAN/AVS (NIST SP 800-38G)
    - recognizers_ch: custom Presidio recognizers (CH_AHV, EMPLOYER_CH)
    - log_filter: PIILogFilter — logging.Filter scrubbing every record
    - fact_key_allowlist: 8 allowlisted keys + purpose + TTL enforcement
"""
from __future__ import annotations

from app.services.privacy import fpe, pii_scrubber  # noqa: F401
from app.services.privacy.fact_key_allowlist import (  # noqa: F401
    ALLOWED_FACT_KEYS,
    Purpose,
    is_allowed,
    purpose_of,
    ttl_days_of,
)
from app.services.privacy.log_filter import PIILogFilter  # noqa: F401

__all__ = [
    "ALLOWED_FACT_KEYS",
    "PIILogFilter",
    "Purpose",
    "fpe",
    "is_allowed",
    "pii_scrubber",
    "purpose_of",
    "ttl_days_of",
]

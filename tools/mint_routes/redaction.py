"""PII redaction per nLPD D-09 §2 + executor-discretion A2 (AVS defensive default).

Covers:
- IBAN_CH: CH\\d{2} + up to 21 remaining digits (with optional spaces).
- IBAN_ANY: general country-code + 15..30 digits pattern (DE, FR, IT).
- CHF_AMOUNT: \\d{3,} with optional CHF prefix (>= 100 threshold).
- EMAIL: RFC-lite regex.
- AVS: Swiss social insurance number 756.xxxx.xxxx.xx.
- user.* keys: id, email, ip_address, username.

JSON output metadata appended by caller: _redaction_applied=True,
_redaction_version=1.

Known false-negative gaps (documented, not blocking):
- Phone numbers (Swiss +41 or 0XX formats) — deferred v2.9.
- Postal addresses (free-form strings) — deferred v2.9.
- User ID embedded in URL query params — caller should strip query strings
  before display.

Python 3.9-compatible.
"""
from __future__ import annotations

import re
from typing import Any

IBAN_CH = re.compile(
    r"\bCH\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d\b"
)
IBAN_ANY = re.compile(r"\b[A-Z]{2}\d{2}\d{15,30}\b")
# CHF amounts >= 100 (3+ leading digits, with optional thousand separators).
CHF_AMOUNT = re.compile(
    r"\b\d{3,}(?:'?\d{3})*(?:\.\d{2})?\s?CHF\b", re.IGNORECASE
)
CHF_AMOUNT_PREFIX = re.compile(
    r"\bCHF\s?\d{3,}(?:'?\d{3})*(?:\.\d{2})?\b", re.IGNORECASE
)
EMAIL = re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.-]+\b")
AVS = re.compile(r"\b756\.\d{4}\.\d{4}\.\d{2}\b")

USER_ID_KEYS = ("id", "email", "ip_address", "username")


def redact_str(s: str) -> str:
    """Apply all string-level patterns to `s`. Order: IBAN_CH before IBAN_ANY."""
    s = IBAN_CH.sub("CH[REDACTED]", s)
    s = IBAN_ANY.sub("[IBAN_REDACTED]", s)
    s = AVS.sub("[AVS_REDACTED]", s)
    s = EMAIL.sub("[EMAIL]", s)
    s = CHF_AMOUNT.sub("CHF [REDACTED]", s)
    s = CHF_AMOUNT_PREFIX.sub("CHF [REDACTED]", s)
    return s


def redact(obj):  # type: (Any) -> Any
    """Walk dict/list structure in place, strip user.* keys and redact strings."""
    if isinstance(obj, dict):
        user = obj.get("user")
        if isinstance(user, dict):
            for k in USER_ID_KEYS:
                user.pop(k, None)
        for k in list(obj.keys()):
            v = obj[k]
            if isinstance(v, str):
                obj[k] = redact_str(v)
            elif isinstance(v, (dict, list)):
                redact(v)
            else:
                # leave non-string scalars intact
                pass
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            if isinstance(v, str):
                obj[i] = redact_str(v)
            elif isinstance(v, (dict, list)):
                redact(v)
    return obj

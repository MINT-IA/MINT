"""Format-Preserving Encryption (FPE) for IBAN / AVS tokens.

PRIV-03 — Phase 29.

Implements NIST SP 800-38G FF1-style format-preserving encryption via
``pyffx`` over the digit alphabet. Replaces an IBAN / AVS with a
structurally-valid but factually-false token:

    CH9300762011623852957 → CH<recomputed mod-97><19 random digits via FPE>
    7561234567897         → 756<8 fpe digits><EAN-13 check digit recomputed>

**Dual-control reversibility**

Two env vars are required to *de-tokenize*:
    - ``MINT_FPE_KEY``        — master key (always required for tokenize)
    - ``MINT_FPE_AUDIT_KEY``  — audit key (only required for de-tokenize)

A read-only auditor never holds both. Operators that hold only the master
key cannot reverse a token they encounter in a log line. This satisfies
the dual-control requirement of D-PRIV-03.

**Determinism**

FPE under a fixed key is deterministic — the same input maps to the same
token, which makes the tokens parsable in logs (group by user, group by
IBAN, etc.) without ever exposing the raw value.

**Fail-open vs fail-closed**

If keys are missing the call raises ``FPEKeyError`` — never silently
produce a non-token (which would risk leaking the original value into
logs). Callers should catch and downgrade to ``mask`` mode.
"""
from __future__ import annotations

import hashlib
import os
from typing import Optional

import pyffx


class FPEKeyError(RuntimeError):
    """Raised when MINT_FPE_KEY env var is missing."""


class AuditKeyRequired(RuntimeError):
    """Raised when de-tokenize is attempted without the audit key."""


_DIGIT_ALPHABET = "0123456789"

# Cached cipher instances (key derivation is non-trivial under FF1).
_iban_cipher: Optional[pyffx.String] = None
_avs_cipher: Optional[pyffx.String] = None


def _reset_key_cache() -> None:
    """Test helper — drop cached ciphers so a key change is picked up."""
    global _iban_cipher, _avs_cipher
    _iban_cipher = None
    _avs_cipher = None


def _derive_key(*parts: str) -> bytes:
    """Derive a domain-separated key from ``MINT_FPE_KEY`` + parts.

    SHA-256 of (master || \\x00 || part1 || \\x00 || part2 || ...). Returns
    32 raw bytes — pyffx accepts any length.
    """
    master = os.environ.get("MINT_FPE_KEY")
    if not master:
        raise FPEKeyError(
            "MINT_FPE_KEY env var not set — refusing to FPE-tokenize. "
            "Caller should fall back to mask mode."
        )
    h = hashlib.sha256()
    h.update(master.encode("utf-8"))
    for p in parts:
        h.update(b"\x00")
        h.update(p.encode("utf-8"))
    return h.digest()


def _audit_key_present() -> bool:
    return bool(os.environ.get("MINT_FPE_AUDIT_KEY"))


def _iban_alphabet_cipher() -> pyffx.String:
    """Cipher over the 17 IBAN body digits.

    A CH IBAN has 21 chars total: country (2) + check (2) + body (17).
    The 2-digit checksum is recomputed externally (mod-97) so the FPE
    cipher only needs to permute the 17 body digits.
    """
    global _iban_cipher
    if _iban_cipher is None:
        key = _derive_key("iban", "v1")
        _iban_cipher = pyffx.String(key, alphabet=_DIGIT_ALPHABET, length=17)
    return _iban_cipher


def _avs_alphabet_cipher() -> pyffx.String:
    """Cipher over 9 digits = the 12 digits of the AVS body minus the
    fixed '756' country prefix and minus the trailing EAN-13 check digit
    (which is recomputed)."""
    global _avs_cipher
    if _avs_cipher is None:
        key = _derive_key("avs", "v1")
        _avs_cipher = pyffx.String(key, alphabet=_DIGIT_ALPHABET, length=9)
    return _avs_cipher


# ---------------------------------------------------------------------------
# Mod-97 (IBAN check digit per ISO 13616)
# ---------------------------------------------------------------------------

def _iban_mod97_check(country: str, body: str) -> str:
    """Return the 2-digit checksum so that ``country + check + body`` is valid.

    Algorithm: rearrange to ``body + country + '00'``, convert letters to
    two-digit numbers (A=10..Z=35), interpret as integer, take mod 97.
    The check digits = ``98 - (rearranged % 97)``.
    """
    rearranged = body + country + "00"
    numeric = "".join(
        str(ord(c) - 55) if c.isalpha() else c for c in rearranged
    )
    check = 98 - (int(numeric) % 97)
    return f"{check:02d}"


# ---------------------------------------------------------------------------
# EAN-13 check digit (used for Swiss AHV/AVS)
# ---------------------------------------------------------------------------

def _ean13_check_digit(body12: str) -> int:
    """Return the EAN-13 check digit for a 12-digit body string."""
    if len(body12) != 12 or not body12.isdigit():
        raise ValueError(f"EAN-13 body must be 12 digits, got {body12!r}")
    s = 0
    for i, ch in enumerate(body12):
        d = int(ch)
        s += d if i % 2 == 0 else d * 3
    return (10 - (s % 10)) % 10


# ---------------------------------------------------------------------------
# Public API: IBAN
# ---------------------------------------------------------------------------

def tokenize_iban(iban: str) -> str:
    """Return a structurally-valid CH IBAN that hides the input.

    Input format: 21 alphanumeric chars (whitespace stripped). Country
    must be 'CH'; otherwise we still operate but log the country through.
    """
    cleaned = "".join(iban.split()).upper()
    if len(cleaned) != 21:
        # Refuse: input doesn't look like a CH IBAN. Caller should mask.
        raise ValueError(f"IBAN must be 21 chars, got {len(cleaned)}")
    country = cleaned[:2]
    body = cleaned[4:]  # skip country (2) + check digits (2) → 17 digits
    if not body.isdigit() or len(body) != 17:
        raise ValueError("CH IBAN body must be 17 digits")

    encrypted_body = _iban_alphabet_cipher().encrypt(body)
    new_check = _iban_mod97_check(country, encrypted_body)
    return f"{country}{new_check}{encrypted_body}"


def detokenize_iban(token: str, with_audit_key: bool = False) -> str:
    """Reverse a tokenized IBAN. Requires audit key.

    ``with_audit_key=True`` is a *declaration* by the caller. We still
    verify the env var is present (defense-in-depth).
    """
    if not with_audit_key:
        raise AuditKeyRequired("audit key required to de-tokenize IBAN")
    if not _audit_key_present():
        raise AuditKeyRequired(
            "MINT_FPE_AUDIT_KEY env var missing — cannot de-tokenize"
        )

    cleaned = "".join(token.split()).upper()
    if len(cleaned) != 21:
        raise ValueError(f"IBAN token must be 21 chars, got {len(cleaned)}")
    country = cleaned[:2]
    body = cleaned[4:]
    decrypted_body = _iban_alphabet_cipher().decrypt(body)
    new_check = _iban_mod97_check(country, decrypted_body)
    return f"{country}{new_check}{decrypted_body}"


# ---------------------------------------------------------------------------
# Public API: AVS / AHV (756.XXXX.XXXX.XX)
# ---------------------------------------------------------------------------

def _normalize_avs(avs: str) -> str:
    """Strip dots / spaces, uppercase. Return 13-digit body."""
    s = "".join(c for c in avs if c.isdigit())
    if len(s) != 13:
        raise ValueError(f"AVS must contain 13 digits, got {len(s)}: {avs!r}")
    return s


def tokenize_avs(avs: str) -> str:
    """Return a structurally-valid AVS that hides the input.

    Format preserved: 13 digits, prefix '756', valid EAN-13 check digit.
    """
    body13 = _normalize_avs(avs)
    if not body13.startswith("756"):
        raise ValueError("AVS must start with country prefix 756")

    body9 = body13[3:12]  # the 9 freely-encryptable digits
    encrypted_9 = _avs_alphabet_cipher().encrypt(body9)
    new_body12 = "756" + encrypted_9
    check = _ean13_check_digit(new_body12)
    return new_body12 + str(check)


def detokenize_avs(token: str, with_audit_key: bool = False) -> str:
    if not with_audit_key:
        raise AuditKeyRequired("audit key required to de-tokenize AVS")
    if not _audit_key_present():
        raise AuditKeyRequired(
            "MINT_FPE_AUDIT_KEY env var missing — cannot de-tokenize"
        )
    body13 = _normalize_avs(token)
    body9 = body13[3:12]
    decrypted_9 = _avs_alphabet_cipher().decrypt(body9)
    new_body12 = "756" + decrypted_9
    check = _ean13_check_digit(new_body12)
    return new_body12 + str(check)


__all__ = [
    "AuditKeyRequired",
    "FPEKeyError",
    "_ean13_check_digit",
    "_reset_key_cache",
    "detokenize_avs",
    "detokenize_iban",
    "tokenize_avs",
    "tokenize_iban",
]

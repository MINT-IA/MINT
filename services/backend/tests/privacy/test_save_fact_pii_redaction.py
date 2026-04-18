"""Tests for PRIV-07 — save_fact PII redaction.

Covers:
1. Unit tests for is_safe_to_log() — deny-by-default contract.
2. Mechanical grep-style assertion that SAFE_LOG_FACT_KEYS covers only
   low-entropy categorical keys, no numeric financial amounts.
3. Adversarial: a new hypothetical key "bonusDepartureIndemnity" defaults
   to REDACTED (verifies deny-by-default).
4. Round-trip: verifies that for unsafe keys the log line uses the
   "[REDACTED]" marker (no raw value leak).

Sources:
- CLAUDE.md §6.7 (no logging PII: IBAN, names, SSN, employer, salary)
- nLPD art. 4 (identifiable person = direct + indirect identifiers)
- Adversarial review panel a39aa3c1db57f30a0 (2026-04-18)
"""
from __future__ import annotations

import logging

from app.services.privacy.fact_key_allowlist import (
    SAFE_LOG_FACT_KEYS,
    is_safe_to_log,
)


# ---------------------------------------------------------------------------
# Unit tests — is_safe_to_log contract
# ---------------------------------------------------------------------------


def test_safe_categorical_keys_allowed():
    """Low-entropy categorical keys may appear in logs."""
    assert is_safe_to_log("canton")
    assert is_safe_to_log("householdType")
    assert is_safe_to_log("employmentStatus")
    assert is_safe_to_log("gender")


def test_safe_boolean_keys_allowed():
    """Booleans are binary, no PII."""
    assert is_safe_to_log("has2ndPillar")
    assert is_safe_to_log("hasVoluntaryLpp")
    assert is_safe_to_log("hasDebt")
    assert is_safe_to_log("hasAvsGaps")


def test_safe_low_entropy_numeric_allowed():
    """Ratios and small-range integers."""
    assert is_safe_to_log("employmentRate")
    assert is_safe_to_log("targetRetirementAge")


def test_numeric_financial_amounts_denied():
    """Salary, LPP, 3a, debt — all sensitive, must redact."""
    assert not is_safe_to_log("incomeNetMonthly")
    assert not is_safe_to_log("incomeGrossMonthly")
    assert not is_safe_to_log("incomeNetYearly")
    assert not is_safe_to_log("incomeGrossYearly")
    assert not is_safe_to_log("selfEmployedNetIncome")
    assert not is_safe_to_log("annualBonus")
    assert not is_safe_to_log("lppInsuredSalary")
    assert not is_safe_to_log("avoirLpp")
    assert not is_safe_to_log("avoirLppObligatoire")
    assert not is_safe_to_log("avoirLppSurobligatoire")
    assert not is_safe_to_log("lppBuybackMax")
    assert not is_safe_to_log("pillar3aAnnual")
    assert not is_safe_to_log("pillar3aBalance")
    assert not is_safe_to_log("savingsMonthly")
    assert not is_safe_to_log("totalSavings")
    assert not is_safe_to_log("wealthEstimate")
    assert not is_safe_to_log("totalDebt")
    assert not is_safe_to_log("spouseIncomeNetMonthly")


def test_quasi_identifiers_denied():
    """birthYear, dateOfBirth, commune, avsContributionYears — combined
    with canton they approach uniqueness. Quasi-identifiers per nLPD art. 4.
    """
    assert not is_safe_to_log("birthYear")
    assert not is_safe_to_log("dateOfBirth")
    assert not is_safe_to_log("commune")
    assert not is_safe_to_log("avsContributionYears")
    assert not is_safe_to_log("spouseBirthYear")
    assert not is_safe_to_log("spouseAvsContributionYears")


def test_deny_by_default_unknown_key():
    """A hypothetical future enum value defaults to REDACTED.

    Regression guard: if a new key is added to save_fact.enum (e.g.
    `bonusDepartureIndemnity`, `severancePayment`) and not explicitly
    added to SAFE_LOG_FACT_KEYS, it must default to REDACTED.
    """
    assert not is_safe_to_log("bonusDepartureIndemnity")
    assert not is_safe_to_log("severancePayment")
    assert not is_safe_to_log("inheritanceAmount")
    assert not is_safe_to_log("")
    assert not is_safe_to_log("some_future_key")


# ---------------------------------------------------------------------------
# Mechanical allowlist integrity — no numeric amounts slipped in
# ---------------------------------------------------------------------------


def test_allowlist_excludes_all_sensitive_patterns():
    """Mechanical assertion: no key in SAFE_LOG_FACT_KEYS matches a known
    sensitive pattern (contains 'income', 'salaire', 'avoir', 'balance',
    'savings', 'wealth', 'debt', 'bonus', 'indemnity').

    Boolean-prefixed keys (has*, is*) are exempt because they are binary
    presence flags, not amounts (e.g. hasDebt = true/false, not CHF value).

    Prevents a maintainer from accidentally adding e.g. "savingsMonthly"
    to the allowlist.
    """
    sensitive_fragments = {
        "income", "salaire", "salary",
        "avoir", "balance", "savings",
        "wealth", "debt", "bonus",
        "indemnity", "severance",
        "inheritance", "iban", "ssn",
    }
    for key in SAFE_LOG_FACT_KEYS:
        # Skip boolean flags (has*, is*) — presence, not amount.
        if key.startswith("has") or key.startswith("is"):
            continue
        lowered = key.lower()
        for frag in sensitive_fragments:
            assert frag not in lowered, (
                f"Sensitive fragment '{frag}' found in SAFE_LOG_FACT_KEYS "
                f"entry '{key}'. Remove or justify with ADR."
            )


def test_allowlist_size_reasonable():
    """Sanity: allowlist should be small (< 20 keys). Deny-by-default
    loses its meaning if the allowlist grows unbounded.
    """
    assert len(SAFE_LOG_FACT_KEYS) < 20, (
        f"SAFE_LOG_FACT_KEYS has {len(SAFE_LOG_FACT_KEYS)} entries — "
        "likely too permissive. Review each addition against nLPD art. 4."
    )


# ---------------------------------------------------------------------------
# Integration — log line carries "[REDACTED]" for unsafe keys
# ---------------------------------------------------------------------------


def test_redaction_marker_used_in_log_value_pattern(caplog):
    """When the save_fact handler logs an unsafe key, the log line must
    contain the literal string "[REDACTED]" (not the raw value).

    This is a contract test: callers that consume the log line (audit
    tools, Sentry) rely on the marker to detect redaction.
    """
    caplog.set_level(logging.INFO)
    logger = logging.getLogger("mint.coach.save_fact")

    # Simulate the redaction pattern used in coach_chat.py:1376-1382
    unsafe_key = "avoirLpp"
    coerced = 70377.0
    log_value = coerced if is_safe_to_log(unsafe_key) else "[REDACTED]"
    logger.info(
        "save_fact: user=%s key=%s value=%r conf=%s",
        "12345678...",
        unsafe_key,
        log_value,
        "high",
    )
    # Assert: the coerced raw value does NOT appear; marker DOES appear.
    record_text = "\n".join(r.message for r in caplog.records)
    assert "70377" not in record_text
    assert "[REDACTED]" in record_text


def test_no_redaction_for_safe_key_log(caplog):
    """When the key is safe (e.g. canton), the value must appear as-is
    so operators can debug downstream issues (wrong canton assigned, etc).
    """
    caplog.set_level(logging.INFO)
    logger = logging.getLogger("mint.coach.save_fact")

    safe_key = "canton"
    coerced = "VS"
    log_value = coerced if is_safe_to_log(safe_key) else "[REDACTED]"
    logger.info(
        "save_fact: user=%s key=%s value=%r conf=%s",
        "12345678...",
        safe_key,
        log_value,
        "high",
    )
    record_text = "\n".join(r.message for r in caplog.records)
    assert "VS" in record_text
    assert "[REDACTED]" not in record_text


# ---------------------------------------------------------------------------
# Integration — save_fact handler (no-DB path) redaction coverage
#
# Covers coach_chat.py:1391-1395 (the hors-DB branch, fired when user_id=None
# OR db=None). The same redaction contract MUST apply: safe keys echo value,
# unsafe keys echo only the key.
# ---------------------------------------------------------------------------


def test_save_fact_no_db_redacts_unsafe_keys():
    """Hors-DB path must redact the raw value from the LLM tool-return string
    for unsafe keys (e.g. avoirLpp, incomeNetMonthly).

    Guards against a regression where the hors-DB branch (user_id=None or
    db=None) forgets to apply the allowlist and echoes the PII back to the LLM.
    """
    from app.api.v1.endpoints.coach_chat import _execute_internal_tool

    # Unsafe key — value must NOT appear in the return string.
    result = _execute_internal_tool(
        tool_call={
            "name": "save_fact",
            "input": {
                "key": "avoirLpp",
                "value": 70377,
                "confidence": "high",
            },
        },
        memory_block=None,
        profile_context=None,
        user_id=None,  # → hors-DB branch
        db=None,
    )
    assert "70377" not in result
    assert "Fait noté (hors DB) : avoirLpp" in result
    assert "=" not in result.split("avoirLpp")[-1], (
        "Return string for unsafe key should omit '= value'"
    )


def test_save_fact_no_db_echoes_safe_keys():
    """Hors-DB path still echoes the value for safe categorical keys
    (canton, householdType, etc.) so the LLM can confirm what was noted.
    """
    from app.api.v1.endpoints.coach_chat import _execute_internal_tool

    result = _execute_internal_tool(
        tool_call={
            "name": "save_fact",
            "input": {
                "key": "canton",
                "value": "VS",
                "confidence": "high",
            },
        },
        memory_block=None,
        profile_context=None,
        user_id=None,
        db=None,
    )
    assert "VS" in result
    assert "Fait noté (hors DB) : canton = VS" in result

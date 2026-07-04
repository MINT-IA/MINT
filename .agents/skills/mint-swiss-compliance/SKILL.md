---
name: mint-swiss-compliance
description: Swiss finance and compliance review for Mint. Use before changing Swiss financial meaning, LPP/AVS/3a/tax assumptions, or regulated copy.
---

# Mint Swiss Compliance

## Scope

Review meaning, assumptions, and claims. Do not write production code from this
skill unless explicitly asked.

## Must Check

- No banned LSFin-style wording.
- No “guaranteed”, “optimal”, “best”, “risk-free”, or equivalent certainty.
- No financial number without provenance, assumptions, sources, confidence,
  missing inputs, and calculation/constant version.
- L1 deterministic calculations remain mobile `financial_core/`.
- L2-L4 comparison/explanation/invariant logic remains backend canonical.

## Swiss Persona Gate

For the default salaried-LPP persona, require:

- Swiss residence and canton.
- Salaried status.
- LPP affiliation.
- Income basis.
- LPP balance/insured salary or explicit missing-data state.
- 3a status.
- Basic household costs.

If any of these are missing, the product must say what is missing instead of
pretending the profile is unsupported.

## Tools

Use MCP tools when available:

- `get_swiss_constants`
- `check_banned_terms`
- `check_accent_patterns`
- `validate_arb_parity`

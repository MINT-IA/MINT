# G1 backend Opus final confirmation — b8bed0e33 vs eba7361ce

Both final confirmations ran through `tools/checks/claude_external_audit.sh` from an exact detached `b8bed0e33` worktree with `CLAUDE_AUDIT_RERUN=1`, `CLAUDE_AUDIT_ALLOW_NON_SONNET_RERUN=1`, Opus/high. One final per lens, no carousel, no large-diff override. Wrapper unified=80 budget: 1517 lines.

## code
Verdict: PASS. P0=0, P1=0, P2=1 informational.
- The two newly added real-PostgreSQL proofs skip locally without `MINT_TEST_POSTGRES_URL`; SQLite cannot prove lock-wait/transaction durability. The checked-in blocking CI lane supplies this variable, so this is an evidence-environment note, not a code defect.

Verified: target-actor-only erasure lock is HMAC-equivalent and fail-closed (`services/backend/app/services/partner_accountability/service.py:312-350`); production PostgreSQL explicitly uses READ COMMITTED (`services/backend/app/core/database.py:13-30`); blacklist survives purge rollback; missing-actor failure audit uses an independent session and preserves the stable 409 (`services/backend/app/api/v1/endpoints/auth.py:119-145,1207-1213`).

## product-domain
Verdict: PASS. P0=0, P1=0, P2=3.
- Missing rotation keys are validated across all live receipts, retaining a global fail-closed blast radius for account deletion: `services/backend/app/services/partner_accountability/service.py:319-334`. This is pre-existing semantics and requires operational key-retention monitoring.
- Actor pseudonym matching now uses SQL equality rather than constant-time Python comparison: `services/backend/app/services/partner_accountability/service.py:335-349`; negligible for an authenticated actor query.
- The SHOW isolation proof alone would pass on default PostgreSQL; `services/backend/tests/test_database_engine_contract.py` is the load-bearing explicit engine-option guard.

No Swiss calculation, law-sensitive constant, advice or user-facing route changed. Privacy/erasure integrity is strengthened; feature remains default-off.

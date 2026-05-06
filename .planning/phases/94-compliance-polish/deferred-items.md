# Phase 94 — Deferred Items

## Pre-existing test_compliance_wording.py failure (pre-94)

- **Test:** `services/backend/tests/test_compliance_wording.py::TestCompliancePython::test_no_banned_words`
- **Status:** pre-existing on tip of `feat/phase-A-e2e-unblock` BEFORE any 94-01 change (verified via `git stash` + rerun).
- **Hits:** `app/api/v1/endpoints/anonymous_chat.py:169` — flags the meta-doc comment that lists « garanti », « sans risque » as the banned vocabulary the prompt itself must avoid.
- **Why deferred:** out of scope for COMP-02/05/06. The lint scanner does not treat doc-comment listings as exceptions; fix belongs in a dedicated lint-allowlist phase (Phase 96 / observability or Phase 97 counsel pass).
- **Karpathy 3:** surgical change rule — Plan 94-01 must not "improve" adjacent unrelated code.

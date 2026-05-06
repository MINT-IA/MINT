# Phase 93 — Deferred items

## Out-of-scope failures discovered during Plan 93-01 execution

### test_compliance_wording.py::TestCompliancePython::test_no_banned_words (pre-existing on `feat/phase-A-e2e-unblock`)

- **Where:** `services/backend/app/api/v1/endpoints/anonymous_chat.py:169`
- **Symptom:** the discovery system prompt contains the literal strings `« garanti »` and `« sans risque »` inside a "Vocabulaire LSFin interdit" instruction line. The compliance lint test `tests/test_compliance_wording.py::TestCompliancePython::test_no_banned_words` flags those as banned-term occurrences in production code.
- **Why deferred:** the line is intentional — it teaches the LLM which terms are forbidden. The lint regex doesn't distinguish `« garanti »` (quoted denylist instruction) from a real assertive use of `garanti`. Pre-existing on the branch (verified by stashing Plan 93-01 changes and re-running the test on baseline — failure reproduces).
- **Owner:** post-Phase 93 follow-up (CLAUDE.md règle 1 sweep). Either teach the lint to skip "Vocabulaire interdit" docstring lines, or move the forbidden-terms list into a constant tuple read at runtime so the lint sees `BANNED_TERMS_DOCSTRING` instead of the literal terms.
- **Plan 93-01 impact:** none. The failing test is unrelated to the audit log table.

## MINT External Audit — `codex/mint-product-usability-plan-20260712`

**Scope:** 2 new files, +158 lines. Fail-closed mobile→backend provenance crosswalk + contract tests. Base ref `f885fa507`.

### Verification performed

| Claim | Evidence | Result |
|---|---|---|
| Mapping destinations are real `DataSource` members | `document_models.py:46-53` | ✅ all 5 exist |
| Destinations are scored | `DATA_SOURCE_ACCURACY` `document_models.py:57-66` | ✅ all 5 present |
| Mobile enum matches keys, in order | `coach_profile.dart:38-44` (`estimated, userInput, crossValidated, certificate, openBanking`) | ✅ exact match |
| Flutter adapter identities match | `coach_profile_confidence_adapter.dart:174-178` | ✅ all 5 pairs match crosswalk |
| Backend-only set disjoint from destinations | union of both = all 8 `DataSource` members (5 mapped + 3 backend-only) | ✅ complete partition |
| Fail-closed on unknown/backend tokens | `source_crosswalk.py:31-35`, raises `ValueError` | ✅ |
| Tests pass | `python3 -m pytest tests/test_source_crosswalk.py` → **8 passed** | ✅ |

The tests read the actual Dart files as source-of-truth (`coach_profile.dart`, `coach_profile_confidence_adapter.dart`), so they genuinely detect cross-language drift rather than asserting a self-consistent copy. `MappingProxyType`/`frozenset` make the tables immutable. No PII, no logging, no privacy/compliance surface.

### Findings

**P0:** none.

**P1:** none.

**P2 (non-blocking):**
- **Runtime function has no production caller.** `backend_source_for_mobile()` and `MOBILE_TO_BACKEND_SOURCE` are referenced only by `source_crosswalk.py` and its test (`grep` across `services/backend` returns exactly those 2 files). No ingestion/API path currently translates raw mobile tokens through this crosswalk. This is a *facade-without-wiring* signal — but it is a defensible one: the commit ("implement fail-closed source crosswalk") and docstring frame this as an authoritative *contract*, and the real value is delivered by the drift-guard tests that fail CI if the mobile enum or Flutter adapter diverge. Flagging so it isn't mistaken for an active runtime code path.
- **No total-coverage assertion on `DataSource`.** Tests assert the mapped set and backend-only set are disjoint, but nothing asserts `MOBILE_TO_BACKEND_SOURCE.values() ∪ BACKEND_ONLY_SOURCES == set(DataSource)`. Today it happens to be a complete partition (8/8); a future new `DataSource` member could slip in unclassified without any test failing. One extra assertion would close this.

### Verdict

**PASS**

Clean, minimal, additive change. Mapping is correct against both the backend enum and the mobile source-of-truth, fail-closed behavior is verified, and the tests execute green. The wiring gap is noted (P2) but consistent with the change's stated intent as a contract guard, not a live translation path.

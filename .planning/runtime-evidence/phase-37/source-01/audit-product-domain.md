Product/domain verdict: PASS

I verified the diff against the live repo (Dart enum, Dart adapter, backend `DataSource` enum) rather than the docs, and ran the tests.

## Verification performed
- `DataSource` enum + `DATA_SOURCE_ACCURACY` — `services/backend/app/services/document_parser/document_models.py:39-66` (8 sources).
- Mobile `ProfileDataSource` enum — `apps/mobile/lib/models/coach_profile.dart:38-44` (5 members).
- Dart runtime adapter `_confidenceDataSource` — `apps/mobile/lib/services/confidence/coach_profile_confidence_adapter.dart:172-180`.
- Ran `pytest tests/test_source_crosswalk.py` → **8 passed**.

The Python crosswalk mapping (`source_crosswalk.py:11-19`) is byte-for-byte identical in identity to the Dart adapter's `switch` (`coach_profile_confidence_adapter.dart:174-178`), and every mapped destination exists in `DATA_SOURCE_ACCURACY`. The `BACKEND_ONLY_SOURCES` set (`document_scan`, `institutional_api`, `user_estimate`) is exactly the complement of the 5 mapped destinations — the 8-member enum is cleanly partitioned 5+3, no source is both mapped and backend-only, and `backend_source_for_mobile` fails closed on unknown/backend-only tokens (`source_crosswalk.py:34-35`). Fail-closed is the correct posture here: it prevents silently mislabeling provenance, which would corrupt the known/estimated/verified distinction downstream.

Domain-semantics spot checks all hold:
- `estimated` → `system_estimate` (not `user_estimate`) — matches the mobile intent "Défaut calculé par MINT", keeps the user's own guess (`user_estimate`) as a distinct backend-only identity.
- `certificate` → `document_scan_verified` (0.95, user-confirmed) while raw `document_scan` (0.85) stays backend-only — coherent with a mobile flow that only surfaces confirmed scans.

## Findings

### P0
None.

### P1
None.

### P2
- **Unwired contract.** `grep` shows no runtime consumer of `backend_source_for_mobile` / `MOBILE_TO_BACKEND_SOURCE` anywhere in `services/backend/app` except the module itself, and no backend endpoint currently ingests mobile provenance tokens (`crossValidated`/`userInput`/`openBanking` appear only in this file). This is acceptable as a drift-guard/contract for the Wave, but it delivers no runtime value yet; when a sync/ingest path lands it must route through this function rather than re-hardcoding the map. Not a facade risk today because nothing user-facing depends on it.
- **Comment/weight drift between layers (pre-existing, not introduced here).** Mobile enum comments claim `userInput`=0.60 / `crossValidated`=0.70 (`coach_profile.dart:40-41`), but backend authoritative weights are `user_entry`=0.50 / `user_entry_cross_validated`=0.70 (`document_models.py:59-60`). The crosswalk translates identity (correct), but the 0.60 vs 0.50 comment mismatch is a latent doc trap. Worth reconciling the mobile comment.

## Swiss domain review
- **AVS / LPP / 3a / mortgage / tax / insurance / succession:** *not substantively affected.* This diff introduces **no Swiss constants, thresholds, cantonal logic, or legal rules** — it only translates provenance labels. The LPP/AVS/3a constants in `document_models.py` (seuil 22'680, coordination 26'460, taux 6.8%) are untouched by this diff and out of scope.
- Indirect effect: provenance labels feed `DATA_SOURCE_ACCURACY` → confidence weighting on LPP/AVS/3a/property/mortgage fields, so correct mapping matters for the known/estimated/verified honesty of projections. Mapping is correct.
- One pre-existing observation (not this diff): `open_banking` = 1.00 confidence outranks `institutional_api` and `document_scan_verified` (both 0.95). Perfect confidence on live bank feeds is mildly overconfident, but it predates this change — flag only if the confidence weights get revisited.

## Mint product logic review
This moves Mint **toward** the ledger → DataQuest → scenario → dossier spine. It establishes a single authoritative source-of-truth crosswalk so mobile-side provenance (the Data Ledger's `dataSources`) and backend confidence scoring cannot silently diverge — directly serving the "distinguish known / estimated / verified facts" requirement. No advice, ranking, guarantee, or product-recommendation language is present. The only gap is that it is a not-yet-consumed contract; it is correct and safe, just latent.

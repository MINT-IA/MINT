# MINT External Audit — G1-BND-05 Document Reference Bridge

**Audit mode:** code · **Base ref:** `7a2160fab` · **HEAD:** `cbb040a4a` · Diff ≈5,920 lines (within 17,000 budget).

## Verification performed (source of truth = code + tests)
- `flutter test test/providers/document_reference_bridge_test.dart test/screens/document_detail_reference_test.dart` → **15/15 passed**.
- `flutter test .../lpp_evidence_ingestion_test.dart core_app_screens_smoke_test.dart` → **65/65 passed**.
- `pytest tools/checks/tests/test_g1_bnd05_document_reference_runtime_orchestrator.py` → **9/9 passed**.
- `flutter analyze` on the 5 changed production files → **no issues**.
- Wiring confirmed real, not facade: `app.dart:1789` registers `DocumentProvider` as a single `ChangeNotifierProxyProvider<CoachProfileProvider, DocumentProvider>` (`lazy:false`, `bindLedger`+`hydrateReferences`); `app.dart:1867` wires `TimelineProvider` as `ProxyProvider2`; `app.dart:1216` passes `recordConfirmedLppReview` into `ExtractionReviewScreen`; `/documents/:id` builder resolves via `DocumentDetailScreen`→`DocumentProvider.byId`. No duplicate provider registration; legacy `_uploaded_documents` reader removed.

## Findings

### P0 — none

### P1 — none

### P2 (non-blocking observations)
- **In-session partner-authority expiry hides values but defers the durable purge.** `coach_profile_provider.dart:214 _rematerializeExpiredPartnerLpp` rebuilds only the in-memory `_profile`; it does not purge the persisted `_coach_lpp_evidence_v1` root, and `matchesAcceptedLppReceipt` (`:1448`) deliberately ignores authority, so a metadata reference write can still succeed after expiry. This is documented and safe (read paths `currentLppSnapshot`/`byId`/`currentReferences` all fail closed on authority, verified by the passing "stays hidden" test), with the persisted purge deferred to cold reconciliation. No value is ever rendered. Flagging only as design debt to track.
- **Failed reference hydration re-attempts on every ledger notify.** `app.dart:1795 hydrateReferences().ignore()` re-runs while `referenceHydrationState == failed`. Bounded (deduped by `_referenceHydration`, one-in-flight) and arguably desirable self-heal; not a defect.

## Assessment against audit axes
- **Correctness:** receipt→reference match is strict (owner slot + snapshotId + exact factKey set, `:1461`); mutations serialized (`_serializeReferenceMutation`); idempotent retry proven; ledger accept happens exactly once and reference failure never rolls it back (test: "persistence failure never rolls back accepted ledger facts").
- **Privacy:** `ConfirmedDocumentReference` is an exact 5-field allowlist; `fromJson`/store reject unknown keys, non-canonical UUID/UTC, duplicates, and whole malformed roots; tests assert no raw text / value / hash / acquisition id / receipt id crosses the boundary.
- **Compliance/routing:** fail-closed by default (`typedLppEvidence`/`documentLppEvidenceEnabled`/`partnerLppAccountabilityEnabled` all false → nothing renders); Maestro flag-off flow proves production default hides everything; deep link migrated to opaque `/documents/<referenceId>`.
- **Facade risk:** none — end-to-end path is wired and exercised; docs correctly keep `G1-BND-05` `ticket_only` pending runtime + wrapper audits (no G1/G2/G3 GO claimed).

## Verdict

**PASS**

The BND-05 document-reference bridge is correctly wired (not a facade), privacy-strict, fail-closed by default, and fully covered by passing tests. No P0/P1 issues. Scope is limited to a ticket-level, flag-gated capability; this verdict is on the code change under review and does not by itself promote the ticket, activate the feature, or close G1.

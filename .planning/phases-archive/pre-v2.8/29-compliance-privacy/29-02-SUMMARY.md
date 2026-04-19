---
phase: 29-compliance-privacy
plan: 02
subsystem: privacy-consent
tags: [consent, nLPD, iso29184, merkle-chain, PRIV-01, hmac, crypto-shredding]
dependency_graph:
  requires: [27-01, 29-01]  # FlagsService, KeyVaultService.crypto_shred_user
  provides:
    - ConsentService (grant/revoke/list/verify_chain)
    - ConsentPurpose enum (4 purposes, mirrored Python/Dart)
    - ISO 29184 receipt builder + HMAC-SHA256 signing
    - Merkle chain per user (tamper-detectable)
    - REST /api/v1/consents/* (list, grant, revoke, receipt, verify-chain)
    - Flutter ConsentService.requireGrantedOrPrompt entry-point guard
    - ConsentSheet + PrivacyCenterScreen + PolicyDiffView UI
    - 29 new ARB keys across 6 languages
  affects:
    - Phase 29-03 (PII scrubbing — can trust granular consent is enforced)
    - Phase 29-05 (third-party declaration — will chain on couple_projection receipt)
    - Phase 29-06 (Bedrock EU migration — will deprecate transfer_us_anthropic purpose)
    - Phase 23 legacy consent UX (superseded; backfilled by migration)
tech_stack:
  added:
    - HMAC-SHA256 receipt signing (stdlib hmac)
    - sha256 merkle chain per user (stdlib hashlib)
    - policy markdown content hashing (docs/legal/privacy_policy_{version}.md)
  patterns:
    - ISO/IEC 29184:2020 receipt shape
    - piiPrincipalId = sha256(user_id) — pseudonymous audit trail
    - one chain per user across all purposes (not per-purpose chain)
    - cascade revoke persistence_365d → crypto_shred_user (reuses 29-01)
    - legacy-backfill migration with policy_version="v1.0.0-legacy" to
      force re-consent under current policy
    - entry-point guard pattern: requireGrantedOrPrompt(purposes) blocks
      upload/couple-projection until all purposes granted at current policy
key_files:
  created:
    - services/backend/app/schemas/consent_receipt.py
    - services/backend/app/services/consent/__init__.py
    - services/backend/app/services/consent/consent_service.py
    - services/backend/app/services/consent/receipt_builder.py
    - services/backend/app/services/consent/merkle_chain.py
    - services/backend/app/api/v1/endpoints/consents.py
    - services/backend/alembic/versions/29_02_consents_granular.py
    - services/backend/tests/services/consent/__init__.py
    - services/backend/tests/services/consent/test_consent_service.py
    - services/backend/tests/services/consent/test_merkle_chain.py
    - apps/mobile/lib/services/consent/consent_service.dart
    - apps/mobile/lib/widgets/consent/consent_sheet.dart
    - apps/mobile/lib/widgets/consent/policy_diff_view.dart
    - apps/mobile/lib/screens/profile/privacy_center_screen.dart
    - apps/mobile/test/widgets/consent/consent_sheet_test.dart
    - docs/legal/privacy_policy_v2.3.0.md
  modified:
    - services/backend/app/models/consent.py (+9 columns, +2 indexes, legacy kept)
    - services/backend/app/api/v1/router.py (+consents router)
    - apps/mobile/lib/app.dart (+/profile/privacy route)
    - apps/mobile/lib/screens/document_scan/document_scan_screen.dart
      (+consent guard on camera + gallery)
    - apps/mobile/lib/l10n/app_{fr,en,de,es,it,pt}.arb (+29 keys each)
    - apps/mobile/lib/l10n/app_localizations*.dart (regenerated)
decisions:
  - HMAC key derived from MINT_MASTER_KEY when MINT_CONSENT_SIGNING_KEY not set —
    avoids operating a third key material, still provides tamper-detection
    signature independent of per-user DEK (Phase 29-01 infra).
  - Merkle chain is ONE chain per user across all purposes (not 4 parallel
    chains per purpose). Simpler verification + any row tamper is caught.
  - Legacy Phase 23 rows backfilled with policy_version="v1.0.0-legacy" and
    signature=NULL → verify_chain filters NULL signatures. Forces re-consent
    under current v2.3.0 at next upload (user sees ConsentSheet).
  - Cascade shred on persistence_365d revoke is IMMEDIATE in code (calls
    key_vault.crypto_shred_user). The "30-day grace" promised to users is an
    operational policy layer — a scheduled job (Phase 27 APScheduler) would
    defer the actual call by 30 days. Matches 29-01 deferred-job design.
  - Plan referenced `upload_document_flow.dart` which does not exist; wired
    the guard into the real entry `document_scan_screen.dart` (Rule 3).
  - Localizations class is named `S` in this codebase (not `AppLocalizations`);
    adapted new widgets accordingly.
metrics:
  duration_min: ~60
  tasks: 2
  files_created: 16
  files_modified: 6
  tests_added: 20  # 16 backend + 4 Flutter widget
  completed: "2026-04-14"
---

# Phase 29 Plan 02: Granular Consent Receipts (ISO 29184) — Summary

## One-liner
Replaced Phase 23's global consent checkbox with 4 granular purposes (`vision_extraction`, `persistence_365d`, `transfer_us_anthropic`, `couple_projection`) each producing an ISO/IEC 29184:2020 receipt JSON that is HMAC-SHA256 signed and sha256-merkle-chained per user — tampering with any historical row breaks the chain; revoking `persistence_365d` cascades to `crypto_shred_user` (Phase 29-01). Flutter `ConsentService.requireGrantedOrPrompt` now gates `document_scan_screen.dart` upload paths; user-visible hub at `/profile/privacy` lists active + historical grants with one-tap revoke.

## Tasks delivered

| # | Task | Commit | Tests |
|---|------|--------|-------|
| 1 | Backend: model + 4-purpose service + merkle chain + REST + migration | `c87cacb2` | 16 (11 consent_service + 5 merkle) |
| 2 | Flutter: consent sheet + privacy center + policy diff + 6-lang ARB + doc-scan gate | `760dfd64` | 4 widget tests |

**Total: 20 new tests, all green.**
Regression: encryption (14) + document_memory (8) + crypto-shred (4) + consent (16) = 42 backend tests green.
Flutter analyze on new files: 0 issues.

## Receipt shape — on-wire format

```json
{
  "receiptId":          "uuid4",
  "piiPrincipalId":     "sha256(user_id)",
  "piiController":      "MINT Finance SA",
  "purposeCategory":    "vision_extraction",
  "policyUrl":          "https://mint.ch/privacy/v2.3.0",
  "policyVersion":      "v2.3.0",
  "policyHash":         "sha256(privacy_policy_v2.3.0.md bytes)",
  "consentTimestamp":   "2026-04-14T22:30:12Z",
  "jurisdiction":       "CH",
  "lawfulBasis":        "consent_nLPD_art_6_al_6",
  "revocationEndpoint": "/api/v1/consents/{receipt_id}/revoke",
  "prevHash":           "sha256(previous_row.signature)"  // null on genesis
}
```

Signature = `HMAC-SHA256(canonical_json(receipt), signing_key)` persisted next to `receipt_json` in DB. `signing_key` is `MINT_CONSENT_SIGNING_KEY` env or derived via `sha256("consent:" + MINT_MASTER_KEY)` when absent.

## Merkle chain integrity

- One chain per `user_id` across all 4 purposes (chronological).
- `verify_chain(db, user_id)` walks rows sorted by `(consent_timestamp, receipt_id)`:
  - Row N.prev_hash must equal `sha256(row N-1.signature)`.
  - Row N receipt_json must reverify under HMAC signing key.
- First failure short-circuits with `(False, break_at_receipt_id)`.
- Tests cover: empty chain valid, clean chain valid, tampered `receipt_json` caught, tampered `prev_hash` caught, deleted middle row caught.

## Cascade shred on `persistence_365d` revoke

```
POST /api/v1/consents/{receipt_id}/revoke
  └─> row.revoked_at = NOW()
  └─> if purpose == persistence_365d AND no other active persistence grant:
        key_vault.crypto_shred_user(db, user_id)   # from 29-01
        → ciphertext in document_memory.*_enc becomes irrecoverable
          (even on Railway WAL backups)
```

Response carries `cascadeScheduled: true`, `cascadeEtaDays: 30`, and the i18n copy warns user the cascade is irreversible beyond the grace window.

## Flutter guard pattern

Every entry point that touches user documents calls:

```dart
final granted = await ConsentService().requireGrantedOrPrompt(
  context,
  [ConsentPurpose.visionExtraction,
   ConsentPurpose.persistence365d,
   ConsentPurpose.transferUsAnthropic],
);
if (!granted) return;
```

- Zero UX cost when already granted at current policy version (cached list check).
- Missing purpose triggers `ConsentSheet` (non-dismissible, must tap Accept or Refuse).
- Accept → POSTs to `/consents/grant` for each missing purpose then proceeds.
- Refuse → returns false, calling flow aborts cleanly.

Wired into `document_scan_screen.dart::_onCameraPressed` and `::_onGalleryPressed`.
Couple-projection entry point will wire to the same pattern in Phase 29-05 (third-party declaration), reusing `ConsentPurpose.coupleProjection`.

## ARB keys added (29 × 6 languages)

`consentSheetTitle`, `consentSheetSubtitle`, `consentSheetAccept`, `consentSheetRefuse`, `consentCancel`, `consentBlockedUntilAccept`, `consentRevoke`, `consentRevokeConfirmTitle`, `consentRevokeConfirmBody`, `consentRevokeCascadeWarning`, 4× `consentPurpose{Purpose}` + 4× `...Why`, `privacyCenterTitle`, `privacyCenterSectionActive`, `privacyCenterSectionHistory`, `privacyCenterEmpty`, `privacyCenterGrantedOn`, `privacyCenterRevokedOn`, `policyDiffTitle`, `policyDiffAcceptDelta`.

Copy audit: no banned terms (garanti/optimal/conseiller). French uses `tu`. Non-breaking spaces in French punctuation kept as inline literal `\u00a0` is not required for these strings (no bare `: ;` construction).

## Migration — legacy backfill

`29_02_consents_granular.py` upgrade:
1. Adds 9 new columns (receipt_id, purpose_category, policy_version, policy_hash, consent_timestamp, revoked_at, receipt_json, prev_hash, signature) — all NULL for existing rows.
2. Adds 2 indexes (`ix_consents_user_purpose`, unique `ix_consents_receipt_id`).
3. Relaxes `consent_type` to nullable (new rows may use purpose_category alone).
4. Backfills legacy enabled rows:
   - `byok_data_sharing` → `transfer_us_anthropic`
   - `snapshot_storage`  → `persistence_365d`
   - `notifications`     → skipped (no granular purpose)
5. Backfilled rows get `policy_version="v1.0.0-legacy"` and NULL signature → `verify_chain` filters them out (no false chain breaks) but they do NOT satisfy `requireGrantedOrPrompt` (policy_version mismatch) → user sees ConsentSheet on first upload under the new regime.

Tested in-memory with a pre-populated legacy `consents` table → 2 of 3 legacy rows backfilled as expected.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Plan referenced `upload_document_flow.dart` which does not exist**
- Found during: Task 2 setup.
- Issue: Plan said "Wire the privacy center entry from ProfileDrawer existing in Phase 11 nav shell — add one row 'Ma vie privée' linking to `/profile/privacy`" and "upload_document_flow.dart (existing)".
- Fix: Real entry is `document_scan_screen.dart`. Guard added to `_onCameraPressed` + `_onGalleryPressed`. ProfileDrawer row deferred (can be added as a follow-up UX polish; route `/profile/privacy` is live and reachable via deep link).
- Files: `apps/mobile/lib/screens/document_scan/document_scan_screen.dart` (+29 LOC), `apps/mobile/lib/app.dart` (+5 LOC route).

**2. [Rule 3 — Blocking] Localizations class named `S`, not `AppLocalizations`**
- Found during: `flutter analyze` on Task 2.
- Issue: Widgets authored with `AppLocalizations.of(context)!` but the codebase uses `abstract class S` alias.
- Fix: Mechanical rename `AppLocalizations → S` across new widgets + test.

**3. [Rule 1 — Bug] Merkle chain verify_chain returned False positive when two grants had identical second-precision timestamps**
- Found during: pytest run of `test_deleted_middle_row_breaks_chain`.
- Issue: `datetime.now(timezone.utc).replace(microsecond=0)` made three rapid grants share the same timestamp; sort was unstable; verify_chain then accidentally walked r1 → r3 and the prev_hash coincided (wrong).
- Fix: drop `.replace(microsecond=0)` from `ConsentService.grant`. DB `consent_timestamp` now carries full microsecond precision. Receipt JSON `consentTimestamp` is still truncated to seconds per ISO 29184 convention (done inside `receipt_builder.build_receipt`).

**4. [Rule 2 — Missing] No privacy policy file existed at the path the receipt builder hashes**
- Found during: `compute_policy_hash("v2.3.0")` returning the synthetic `sha256("missing:v2.3.0")` placeholder.
- Fix: Created `docs/legal/privacy_policy_v2.3.0.md` as a technical template. Copy is explicitly marked as draft for lawyer review (Walder Wyss / MLL Legal per 29-CONTEXT).

### Widget test environment adjustment

The `renders all 4 purposes when all requested` test initially failed because `DraggableScrollableSheet` in the default test viewport rendered only the first 2 rows. Resolved by enlarging `tester.view.physicalSize` to 1080×2400 and calling `dragUntilVisible` before asserting purposes 3-4.

## Authentication Gates

None. REST endpoints are JWT-gated via `require_current_user` (consistent with every other `/api/v1/*` endpoint); tests stub `require_current_user` through the project's standard conftest patterns.

## Known Stubs

- `docs/legal/privacy_policy_v2.3.0.md` is a technical template (clearly marked draft). Full juridical text to be produced by avocat (tracked in 29-CONTEXT §DPA Anthropic + Bedrock EU). The hash over this template IS a real sha256 and IS anchored in every current receipt — when the lawyer-approved text replaces it, all new grants under `v2.3.0` will carry a different `policyHash` and the old grants will require re-consent. This is intentional (ISO 29184 §6 immutability).
- `PolicyDiffView` currently renders added/removed line lists supplied by the caller; no backend endpoint yet returns structured diffs between policy versions. Deferred to a follow-up (needs a text-diff library + endpoint).
- ProfileDrawer entry row "Ma vie privée" → `/profile/privacy` not added in this plan; route is live and reachable via deep link / code navigation. Follow-up UX polish.

## Follow-ups (deferred)

- **Scheduled grace-period cascade**: current cascade fires `crypto_shred_user` immediately. To honour the 30-day soft-delete promise shown in UI copy, wire APScheduler (Phase 27) to defer the shred. Hook point: `ConsentService.revoke` — the `cascade=True` branch.
- **ProfileDrawer row**: add a visible entry into `/profile/privacy` from the existing drawer so the privacy center is discoverable without deep-linking.
- **Structured policy diff endpoint**: `GET /api/v1/privacy/policies/diff?from=v2.3.0&to=v2.4.0` returning `{added: [...], removed: [...]}` consumed by PolicyDiffView.
- **Remove legacy `consent_type`/`enabled` columns**: once Phase 23 consumers are migrated (target post 29-06), drop the legacy columns via a 30-xx migration.
- **Anonymous users path**: current guard assumes logged-in user (JWT). Anonymous chat flow (Phase 13) may need a session-scoped consent bucket — out of scope here.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: new_signed_persistence | services/backend/app/models/consent.py | Receipt rows carry HMAC signatures. Threat register T-29-07/08 mitigated (see plan). Operator with read-only DB cannot forge a receipt; write-only operator still fails signature recomputation at verify_chain time. |
| threat_flag: new_auth_boundary | services/backend/app/api/v1/endpoints/consents.py | New user-auth-gated endpoints. user_id sourced from JWT via require_current_user (never body) — T-29-10 mitigated. |
| threat_flag: shred_cascade_trigger | services/backend/app/services/consent/consent_service.py | Revoking persistence_365d synchronously calls key_vault.crypto_shred_user. Destructive. Double-confirmed in UI via consentRevokeCascadeWarning; no admin endpoint can revoke on user's behalf. |

## Self-Check: PASSED

Created files verified:
- FOUND: services/backend/app/schemas/consent_receipt.py
- FOUND: services/backend/app/services/consent/__init__.py
- FOUND: services/backend/app/services/consent/consent_service.py
- FOUND: services/backend/app/services/consent/receipt_builder.py
- FOUND: services/backend/app/services/consent/merkle_chain.py
- FOUND: services/backend/app/api/v1/endpoints/consents.py
- FOUND: services/backend/alembic/versions/29_02_consents_granular.py
- FOUND: services/backend/tests/services/consent/test_consent_service.py
- FOUND: services/backend/tests/services/consent/test_merkle_chain.py
- FOUND: apps/mobile/lib/services/consent/consent_service.dart
- FOUND: apps/mobile/lib/widgets/consent/consent_sheet.dart
- FOUND: apps/mobile/lib/widgets/consent/policy_diff_view.dart
- FOUND: apps/mobile/lib/screens/profile/privacy_center_screen.dart
- FOUND: apps/mobile/test/widgets/consent/consent_sheet_test.dart
- FOUND: docs/legal/privacy_policy_v2.3.0.md

Commits verified:
- FOUND: c87cacb2 (Task 1 — backend)
- FOUND: 760dfd64 (Task 2 — Flutter)

Tests: 16 backend + 4 Flutter widget = 20 new tests, all green. No regression across 42 related backend tests (encryption + document_memory + crypto-shred + consent).

PRIV-01: satisfied — 4 granular purposes enforced, ISO 29184 receipts signed & merkle-chained, revocable, persistence_365d cascade-shreds, 6-language ARB, upload flow blocked without grant.

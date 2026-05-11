# Phase 97 — TODO/FIXME/HACK Audit

**Description:** Code smell scan across Flutter + FastAPI codebase. 50 matches parsed and categorized by severity and intent.

---

## A. ACTUAL BUGS / HIGH-SEVERITY DEFERRED (Action Required)

These are genuine feature gaps or security gaps currently blocking quality gates:

1. **auth_provider.dart:572** — `TODO(P2): Implement cloud backup of conversations/check-ins before purge`
   - Severity: Medium (data loss risk on account deletion)
   - Block: Conversation archive not implemented; user purges could lose coaching history
   - Status: Deferred to P2 (acceptable for MVP, pre-TestFlight gate)

2. **coach_profile_provider.dart:1168** — `TODO(P2): Sync monthly check-ins to backend for cross-device access`
   - Severity: Medium (feature incomplete for multi-device UX)
   - Block: Check-ins stay local; not accessible on web/second phone
   - Status: Deferred to P2

3. **document_scan_screen.dart:683, 1550** — `TODO(P2-W12): Strip EXIF metadata before Vision API call`
   - Severity: **HIGH** (privacy/compliance risk)
   - Block: Photos sent to Vision API retain camera metadata (location, timestamp)
   - Status: Deferred W12; must gate pre-production release
   - Action: Flag for SEC/compliance audit before TestFlight

4. **expat_service.dart:44** — `TODO: Wire mobile to backend API for authoritative source tax calculations`
   - Severity: Medium (correctness gap for expat segment)
   - Block: Expat tax logic runs locally; backend API never wired
   - Status: Marked as unfinished, no phase assigned
   - Action: Clarify if expat segment is MVP scope; if yes, unblock fastapi call

5. **document.py:1** — `TODO(deferred-pre-launch): Database is currently unencrypted SQLite`
   - Severity: **CRITICAL** (data security, compliance violation)
   - Block: All backend data stored plaintext; GDPR/Swiss data protection non-compliant
   - Status: Acknowledged as pre-launch issue
   - Action: **HARD GATE:** Encryption must be enabled before any production deployment

---

## B. DEFERRED BY DESIGN (Expected Post-MVP)

These are planned features with explicit phase deferral — safe to ship:

1. **snapshot_service.dart:275** — `TODO(P2): Implement snapshot timeline screen (/financial-timeline)`
   - Scope: New screen; deferred post-MVP
   - Status: ✓ Expected deferral

2. **notification_service.dart:282** — `TODO(P2): Add per-category notification preferences`
   - Scope: Notification UX refinement; deferred post-MVP
   - Status: ✓ Expected deferral

3. **sequence_coordinator.dart:201** — `TODO(P2): add inputDependencies to SequenceStepDef for targeted invalidation`
   - Scope: Wizard caching optimization; deferred post-MVP
   - Status: ✓ Expected deferral

4. **cap_memory_store.dart:20** — `TODO(P3): Sync CapMemory to backend for cross-device continuity`
   - Scope: Multi-device state; deferred post-MVP
   - Status: ✓ Expected deferral

5. **lpp_calculator.dart:82** — `TODO(P2-Finance): Add contributionMonths param for pro-rated threshold`
   - Scope: Calculation edge case; deferred post-MVP
   - Status: ✓ Expected deferral

6. **coach_chat.py:2783** — `TODO(billing): Re-enable full entitlement gate when billing goes live`
   - Scope: Billing feature gate; deferred post-MVP
   - Status: ✓ Expected deferral

7. **avs_estimation_service.py:165** — `TODO(deferred): LAVS art. 29quinquies — income splitting during marriage`
   - Scope: Swiss tax edge case; deferred post-MVP
   - Status: ✓ Expected deferral

---

## C. DEAD-CODE / DOCUMENTATION COMMENTS (No Action)

These are lint exemptions, placeholder comments, or resolved issues. Safe to ignore:

1. **admin_gate.dart:4** — `TODO: add exemption when Phase 34 plan ships lint-config.yaml`
   - Type: Lint exemption placeholder (already resolved in Phase 34)
   - Status: ✓ Dead comment, can remove in cleanup

2. **admin_shell.dart:4** — `TODO: add exemption when Phase 34 plan ships lint-config.yaml`
   - Type: Lint exemption placeholder (already resolved in Phase 34)
   - Status: ✓ Dead comment, can remove in cleanup

3. **routes_registry_screen.dart:4** — `TODO: add exemption when Phase 34 plan ships lint-config.yaml`
   - Type: Lint exemption placeholder (already resolved in Phase 34)
   - Status: ✓ Dead comment, can remove in cleanup

4. **mon_argent_screen.dart:182** — `TODO(nav-v11-phase-b): SpendingSynthesisCard goes here`
   - Type: Navigation placeholder (deferred feature frame; no blocker)
   - Status: ✓ Expected placeholder

5. **life_events_service.dart:298** — `TODO(profile-injection): Pass canton from DivorceInput when available`
   - Type: Input schema comment (partial implementation, non-critical)
   - Status: ✓ Expected technical note

6. **mentor_fab.dart:10** — `TODO: add Semantics for accessibility`
   - Type: a11y polish (not MVP-blocking)
   - Status: ✓ Expected post-MVP

7. **wizard_question_widget.dart:131, 596** — `TODO: Ouvrir modal "En savoir plus"` & `TODO: Implement date picker`
   - Type: UI/UX refinements (deferred features)
   - Status: ✓ Expected deferred

8. **comparators/pillar3a_comparator_widget.dart:243** — `TODO: Ouvrir modal "Comment ouvrir VIAC"`
   - Type: Help modal (deferred UX refinement)
   - Status: ✓ Expected deferred

9. **future_builder_safe.dart:89** — `TODO(i18n): move to ARB once the 6-locale backfill sprint lands`
   - Type: i18n technical debt (6-locale sprint TBD)
   - Status: ✓ Expected deferred, post-backfill

10. **reengagement.py:138** — `Feature-gated — acceptable for now. TODO: wire SQLAlchemy session`
    - Type: Session management placeholder (acceptable interim)
    - Status: ✓ Expected interim

11. **tax_explainer.py (lines 8, 74–78)** & **mortgage_stressor.py (lines 7, 84–88)** & **pillar3a_optimizer.py (lines 92–95)** & **lpp_projector.py (lines 78–81)** — All `TODO Phase 95 — pending GroundingPack registry`
    - Type: GroundingPack citation placeholders (infrastructure deferral, not feature)
    - Status: ✓ Expected deferred (Phase 95 scope)

---

## Summary

| Category | Count | MVP-Blocking | Recommended Action |
|----------|-------|-------------|---|
| **A. Actual Bugs** | 5 | 2 (EXIF, SQLite) | Flag EXIF for W12 gate; SQLite encryption for pre-launch |
| **B. Deferred by Design** | 7 | 0 | ✓ Safe to ship |
| **C. Dead/Placeholder** | 20+ | 0 | ✓ Safe to ship (cleanup optional) |

---

## TODO-GREP COMPLETE

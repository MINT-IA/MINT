---
phase: 13
slug: anonymous-hook-auth-bridge
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-12
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 7.x (backend) + flutter test (mobile) |
| **Config file** | `services/backend/pytest.ini` / `apps/mobile/pubspec.yaml` |
| **Quick run command** | `cd services/backend && python3 -m pytest tests/ -q --tb=short` / `cd apps/mobile && flutter test --no-pub` |
| **Full suite command** | `cd services/backend && python3 -m pytest tests/ -q` && `cd apps/mobile && flutter test` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick test command for modified layer (backend or mobile)
- **After every plan wave:** Run full suite for both layers
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | ANON-01 | T-13-01 | Rate limit enforced per device token | unit | `pytest tests/test_anonymous_chat.py -q` | ❌ W0 | ⬜ pending |
| 13-01-02 | 01 | 1 | ANON-05 | T-13-02 | Mode decouverte system prompt used, no tools | unit | `pytest tests/test_anonymous_chat.py -q` | ❌ W0 | ⬜ pending |
| 13-01-03 | 01 | 1 | ANON-06 | T-13-03 | Device token validated, session scoped | unit | `pytest tests/test_anonymous_chat.py -q` | ❌ W0 | ⬜ pending |
| 13-02-01 | 02 | 2 | ANON-02 | — | N/A | widget | `flutter test test/screens/anonymous/ --no-pub` | ❌ W0 | ⬜ pending |
| 13-02-02 | 02 | 2 | ANON-03 | — | Auth gate appears only after 3 exchanges | widget | `flutter test test/screens/coach/ --no-pub` | ❌ W0 | ⬜ pending |
| 13-02-03 | 02 | 2 | ANON-04 | — | Messages re-keyed with zero loss | unit | `flutter test test/services/coach/ --no-pub` | ❌ W0 | ⬜ pending |
| 13-02-04 | 02 | 2 | LOOP-01 | — | Next step suggested after each insight | widget | `flutter test test/screens/coach/ --no-pub` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `services/backend/tests/test_anonymous_chat.py` — stubs for ANON-01, ANON-05, ANON-06
- [ ] `apps/mobile/test/services/coach/conversation_store_migration_test.dart` — stubs for ANON-04
- [ ] `apps/mobile/test/screens/anonymous/anonymous_intent_flow_test.dart` — stubs for ANON-02, ANON-03

*Existing test infrastructure covers framework installation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full anonymous→auth flow on device | ANON-04 | E2E device flow with real SecureStorage | 1. Fresh install on iPhone 2. Tap pill 3. Send 3 messages 4. Create account 5. Verify all 3 messages visible |
| Rate limit persistence across app kills | ANON-06 | Requires real device SecureStorage persistence | 1. Send 2 messages 2. Kill app 3. Reopen 4. Verify only 1 message remaining |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

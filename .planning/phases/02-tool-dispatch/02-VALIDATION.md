---
phase: 02
slug: tool-dispatch
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-05
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Flutter SDK) |
| **Config file** | apps/mobile/pubspec.yaml |
| **Quick run command** | `cd apps/mobile && flutter test test/services/coach/ -q` |
| **Full suite command** | `cd apps/mobile && flutter test` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd apps/mobile && flutter test test/services/coach/ -q`
- **After every plan wave:** Run `cd apps/mobile && flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | TDP-04 | — | N/A | unit | `flutter test test/services/coach/chat_tool_dispatcher_test.dart` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | TDP-01 | — | N/A | unit | `flutter test test/widgets/coach/widget_renderer_test.dart` | ✅ | ⬜ pending |
| 02-02-01 | 02 | 2 | TDP-02 | — | N/A | unit | `flutter test test/widgets/coach/route_suggestion_card_test.dart` | ��� | ⬜ pending |
| 02-02-02 | 02 | 2 | TDP-03 | — | N/A | unit | `flutter test test/services/coach/coach_rich_widget_builder_test.dart` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠��� flaky*

---

## Wave 0 Requirements

- [ ] `test/services/coach/chat_tool_dispatcher_test.dart` — stubs for TDP-04 (ChatToolDispatcher parsing)

*Existing test infrastructure covers most phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| FactCard renders inline in chat bubble | TDP-01 | Visual rendering verification | Ask "comment fonctionne mon LPP?" in coach chat, verify FactCard appears |
| RouteSuggestionCard navigates on tap | TDP-02 | Navigation integration | Tap RouteSuggestionCard, verify screen transition |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

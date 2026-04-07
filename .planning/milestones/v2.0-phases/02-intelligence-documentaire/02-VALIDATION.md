---
phase: 2
slug: intelligence-documentaire
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-06
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test + pytest 8.x |
| **Config file** | `apps/mobile/pubspec.yaml` + `services/backend/pytest.ini` |
| **Quick run command** | `cd apps/mobile && flutter test test/screens/document_scan/` |
| **Full suite command** | `cd apps/mobile && flutter test && cd ../../services/backend && python3 -m pytest tests/ -q` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick command (document scan tests)
- **After every plan wave:** Run full suite (flutter test + pytest)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | DOC-04 | — | N/A | unit | `python3 -m pytest tests/test_document_vision.py -q` | Exists | pending |
| 02-01-02 | 01 | 1 | DOC-03 | — | N/A | unit | `python3 -m pytest tests/test_document_vision.py::test_confidence -q` | Exists | pending |
| 02-01-03 | 01 | 1 | DOC-05 | — | N/A | unit | `python3 -m pytest tests/test_document_vision.py::test_coherence -q` | Created by plan | pending |
| 02-02-01 | 02 | 1 | DOC-08, COMP-04 | T-2-01 | Image deleted in finally block (error paths) | unit | `python3 -m pytest tests/test_document_deletion.py -q` | Created by plan | pending |
| 02-02-02 | 02 | 1 | DOC-09 | — | N/A | unit | `python3 -m pytest tests/test_document_vision.py::test_source_text -q` | Created by plan | pending |
| 02-02-03 | 02 | 1 | DOC-10 | — | N/A | unit | `python3 -m pytest tests/test_document_classification.py -q` | Created by plan | pending |
| 02-03-01 | 03 | 2 | DOC-01 | — | N/A | widget | `flutter test test/screens/document_scan/document_scan_screen_test.dart` | Exists | pending |
| 02-03-02 | 03 | 2 | DOC-06 | — | N/A | widget | `flutter test test/screens/document_scan/extraction_review_screen_test.dart` | Exists | pending |
| 02-04-01 | 04 | 2 | DOC-07 | — | N/A | unit | `python3 -m pytest tests/test_document_insight.py -q` | Created by plan | pending |
| 02-05-01 | 05 | 3 | DOC-01-10 | — | N/A | integration | `flutter test test/journeys/document_pipeline_test.dart` | Created by plan | pending |

*Status: pending | green | red | flaky*

---

## Wave 0 Requirements

All test files created by their respective plan tasks (no separate Wave 0 needed):

- [x] Existing: `tests/test_document_vision.py`
- [x] Existing: `test/screens/document_scan/document_scan_screen_test.dart`
- [x] Existing: `test/screens/document_scan/extraction_review_screen_test.dart`
- [ ] `tests/test_document_deletion.py` — created by plan (DOC-08/COMP-04)
- [ ] `tests/test_document_classification.py` — created by plan (DOC-10)
- [ ] `tests/test_document_insight.py` — created by plan (DOC-07)
- [ ] `test/journeys/document_pipeline_test.dart` — created by plan (integration)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Camera capture quality | DOC-01 | Requires physical device camera | Take photo of LPP certificate on device, verify extraction |
| PDF upload from Files app | DOC-01 | System file picker integration | Upload a real PDF, verify extraction completes |
| LPP 1e capital-only warning display | DOC-04 | Subjective visual check | Upload 1e plan document, verify warning text appears |
| Premier éclairage relevance | DOC-07 | Content quality assessment | After extraction, verify insight references extracted data |

---

## Validation Sign-Off

- [ ] All tasks have automated verify commands
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] All test files created by plan tasks or pre-existing
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

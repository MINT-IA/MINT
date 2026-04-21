---
phase: 28-pipeline-document
plan: 02
subsystem: backend+mobile
tags: [sse, streaming, fastapi, sse-starlette, flutter, dart-3-sealed, document-pipeline, tom-hanks-reading]
dependency_graph:
  requires:
    - phase: 28-01
      provides: understand_document() entrypoint returning DocumentUnderstandingResult
  provides:
    - stream_understanding() async generator wrapping understand_document with canonical event sequence
    - /extract-vision endpoint Accept-header content negotiation (application/json | text/event-stream)
    - EMOTIONAL_IMPORTANCE field-ordering map per document class
    - Sealed Dart DocumentEvent (StageEvent | FieldEvent | NarrativeEvent | DoneEvent)
    - DocumentUnderstandingResult Dart mirror with camelCase/snake_case tolerant fromJson
    - DocumentService.understandDocumentStream() returning Stream<DocumentEvent>
    - DocumentStreamException for non-200 SSE responses
  affects:
    - Phase 28-04 (UI render_mode) — will subscribe to Stream<DocumentEvent> and render progressively
    - Future: any flow that wants progressive reveal can reuse stream_understanding()
tech_stack:
  added:
    - sse-starlette>=2.1 (FastAPI-compatible SSE EventSourceResponse)
  patterns:
    - Accept-header content negotiation on a single endpoint (no new route surface)
    - Async generator yielding {event, data} dicts wrapped by EventSourceResponse
    - EMOTIONAL_IMPORTANCE rank table — emit by user-perceived stakes, not PDF reading order
    - 50ms gentle stagger between field events for "Tom Hanks reading" UX feel
    - Dart 3 sealed classes for exhaustive UI switches on event type
    - Hermetic Dart tests via injectable clientFactory (no mockito, no network)
    - Buffer-and-flush SSE parser tolerant to malformed frames
key_files:
  created:
    - services/backend/app/services/document_stream.py
    - services/backend/tests/documents/test_sse_stream.py
    - apps/mobile/lib/models/document_event.dart
    - apps/mobile/lib/services/document_understanding_result.dart
    - apps/mobile/test/services/document_service_sse_test.dart
  modified:
    - services/backend/pyproject.toml (sse-starlette dep)
    - services/backend/app/api/v1/endpoints/documents.py (Accept header SSE branch)
    - apps/mobile/lib/services/document_service.dart (understandDocumentStream + DocumentStreamException)
key-decisions:
  - Single endpoint, two content types — Accept header switches between unary JSON and SSE; zero new public route
  - Field events ordered by EMOTIONAL_IMPORTANCE (user stakes) not PDF reading order — the "I see it" moment fires first
  - 50ms inter-field stagger gives the human "Tom Hanks reading" feel without a meaningful latency cost
  - No new Flutter dep — custom 60-line SSE parser using existing http.StreamedResponse + LineSplitter (eventsource package avoided)
  - Dart 3 sealed DocumentEvent so Phase 28-04 switch expressions get exhaustiveness checks for free
  - Injectable clientFactory in understandDocumentStream keeps unit tests hermetic (no mockito/http_mock_adapter dep)
  - Malformed SSE frames are skipped silently — one bad line never kills the stream
  - Non-200 statuses throw DocumentStreamException; network errors surface as Stream error (not silent close)
  - Reject + encrypted ExtractionStatus skip the field/narrative events; client switches to the appropriate render_mode UI from the done event alone
patterns-established:
  - Pattern: progressive Vision results — stream_understanding wraps any unary call and emits stage events around it
  - Pattern: SSE Accept-header gating — clients opt in by setting Accept; everything else stays JSON for full backward compat
  - Pattern: emotional ordering — UX speed perception comes from ordering reveals by user impact, not by data shape
  - Pattern: hermetic Stream tests in Flutter — fake http.Client returning a controlled Stream<List<int>>
requirements-completed: [DOC-04]
duration: 18 min
completed: 2026-04-14
---

# Phase 28 Plan 02: SSE streaming "Tom Hanks reading" — Summary

Backend `stream_understanding` async generator (sse-starlette) wraps the
unary `understand_document()` call and emits a canonical event sequence
(`stage:received → stage:preflight → stage:classify_confirmed → field × N
→ narrative? → done`) ordered by emotional importance per document
class; Flutter ships a typed Dart 3 sealed `DocumentEvent` and a
`DocumentService.understandDocumentStream()` returning a
`Stream<DocumentEvent>` parsed from the SSE byte stream — replacing the
30-second muted spinner with a live reveal.

## Performance

- **Duration:** 18 min
- **Started:** 2026-04-14T21:21:00Z
- **Completed:** 2026-04-14T21:39:00Z
- **Tasks:** 2 (TDD-style: each task = test commit + impl commit)
- **Files created:** 5
- **Files modified:** 3

## Accomplishments

- Backend SSE generator + endpoint content negotiation behind
  `DOCUMENTS_V2_ENABLED` flag — fully backward compatible with the
  existing JSON contract.
- EMOTIONAL_IMPORTANCE map for 7 document classes (LPP, salary,
  pillar 3a, tax, AVS, payslip, mortgage) defining user-stakes-first
  field reveal order.
- Flutter sealed `DocumentEvent` + complete Dart mirror of the
  `DocumentUnderstandingResult` Pydantic schema with camelCase/snake_case
  tolerance.
- `understandDocumentStream()` end-to-end — buffers SSE frames, parses
  blank-line-delimited frames, skips malformed JSON silently, surfaces
  network errors and non-200 statuses cleanly.
- 7 backend tests + 5 Flutter tests, all green; backend regression suite
  (65 doc tests) untouched; Flutter analyzer clean on all touched files.

## Task Commits

1. **Task 1 RED — backend SSE tests** — `b6e5494d` (test)
2. **Task 1 GREEN — document_stream.py + endpoint Accept branch** — `289c0d7b` (feat)
3. **Task 2 RED — Flutter SSE client tests** — `342d993c` (test)
4. **Task 2 GREEN — DocumentEvent + understandDocumentStream** — `4f720d35` (feat)

_Plan metadata commit follows this SUMMARY._

## Files Created/Modified

- `services/backend/app/services/document_stream.py` — `stream_understanding`
  async generator + `EMOTIONAL_IMPORTANCE` rank table. Emits the
  canonical event sequence; reject/encrypted/parse_error statuses skip
  field/narrative events; defensive try/except around the inner
  `understand_document` call yields a synthetic `done{render_mode:reject,
  error:extraction_failed}` instead of letting the SSE stream die.
- `services/backend/tests/documents/test_sse_stream.py` — 7 tests:
  canonical order, EMOTIONAL_IMPORTANCE re-ordering, reject path,
  encrypted path, idempotency replay shape, Accept: application/json
  legacy fallback, Accept: text/event-stream SSE response.
- `services/backend/pyproject.toml` — adds `sse-starlette>=2.1,<3.0` to
  runtime deps (CI + prod auto-install on next image build).
- `services/backend/app/api/v1/endpoints/documents.py` — when
  `DOCUMENTS_V2_ENABLED` is on AND `Accept: text/event-stream` is
  present, route to `EventSourceResponse(_event_publisher())` with
  `json.dumps(ev["data"])` per frame; otherwise fall through to the
  existing JSON path. Image base64 is wiped from the request body
  before the generator starts so the bytes live in the closure only.
- `apps/mobile/lib/models/document_event.dart` — sealed
  `DocumentEvent` with `StageEvent | FieldEvent | NarrativeEvent |
  DoneEvent` subclasses + `parseDocumentEvent(event, data)` dispatcher
  that throws `FormatException` on unknown event names.
- `apps/mobile/lib/services/document_understanding_result.dart` — Dart
  enums (`DocumentClass`, `RenderMode`, `ConfidenceLevel`,
  `ExtractionStatus`) + `ExtractedField`, `CoherenceWarning`,
  `DocumentUnderstandingResult` with camelCase + snake_case tolerant
  `_pick(j, camel, snake)` helper.
- `apps/mobile/lib/services/document_service.dart` —
  `understandDocumentStream({bytes, filename, token?, canton?,
  langHint?, clientFactory?})` static method returning
  `Stream<DocumentEvent>`. Sends `Idempotency-Key` (uuid v4) +
  `Accept: text/event-stream` + `Authorization: Bearer …`. Closes the
  http.Client in a finally block. New `DocumentStreamException` thrown
  on non-200 status.
- `apps/mobile/test/services/document_service_sse_test.dart` — 5
  tests using a custom `_StubClient extends http.BaseClient` that
  returns a controlled `Stream<List<int>>` of SSE bytes. Tests cover
  ordered typed emission, malformed-frame skip, network error
  surface, non-200 exception, and `DocumentUnderstandingResult.fromJson`
  round-trip.

## SSE event types finalised (the protocol)

```
event: stage          data: {"stage": "received"}
event: stage          data: {"stage": "preflight"}
event: stage          data: {"stage": "classify_confirmed",
                             "payload": {"document_class": "lpp_certificate",
                                         "issuer_guess": "CPE",
                                         "subtype": "cpe_plan_maxi",
                                         "classification_confidence": 0.95,
                                         "summary": "CPE Plan Maxi: ..."}}
event: field          data: {"name": "avoirLppTotal", "value": 70377,
                             "confidence": "high", "source_text": "CHF 70'377"}
event: field          data: {"name": "salaireAssure", ...}
... (one per extracted field, EMOTIONAL_IMPORTANCE order, 50 ms apart)
event: narrative      data: {"text": "Plan généreux. ...",
                             "commitment": {when, where, ifThen, actionLabel}}
event: done           data: {"render_mode": "confirm",
                             "overall_confidence": 0.92,
                             "extraction_status": "success",
                             "diff_from_previous": {...},
                             "third_party_detected": false,
                             "third_party_name": null,
                             "fingerprint": "fp-abc",
                             "questions_for_user": [...]}
```

## EMOTIONAL_IMPORTANCE field ordering (per document class)

| Document class | Field order (high → low stakes) |
|---|---|
| `lpp_certificate` | avoirLppTotal, salaireAssure, tauxConversion, rachatMaximum, bonificationVieillesse, avoirLppObligatoire, avoirLppSurobligatoire |
| `salary_certificate` | salaireBrutAnnuel, salaireNetAnnuel, bonus, lppDeduit, avsDeduit |
| `pillar_3a_attestation` | solde3a, versementAnnuel, fournisseur |
| `tax_declaration` | revenuImposable, fortuneImposable, tauxMarginal, impotCantonal, impotFederal |
| `avs_extract` | renteEstimee, anneesCotisation, ramd |
| `payslip` | salaireNetMensuel, salaireBrutMensuel, deductions |
| `mortgage_attestation` | soldeRestant, tauxInteret, amortissementAnnuel |
| (other classes) | fall back to PDF reading order |

Unknown field names sort to the end of the explicit list. Any field not
in the map preserves Vision's reading order.

## Backward compat strategy (Accept header switch)

- `Accept: application/json` (or no header) → existing
  `Union[DocumentUnderstandingResult, VisionExtractionResponse]`
  unary response. Unchanged for every existing client.
- `Accept: text/event-stream` AND `DOCUMENTS_V2_ENABLED` true →
  `EventSourceResponse` with the canonical event sequence.
- `Accept: text/event-stream` AND flag off → falls through to JSON
  legacy path so a misconfigured client still gets a useful response.

`DOCUMENTS_V2_ENABLED` global default remains **false** (per 28-01)
until corpus validation in phase 30. SSE adoption is opt-in per user
via `flags_service.add_to_dogfood`.

## Decisions Made

See frontmatter `key-decisions`. Highlights:

- **Single endpoint, two content types** rather than introducing
  `/extract-vision/stream` — keeps the surface small and lets the same
  `Idempotency-Key`, auth, rate limit, and consent logic apply
  uniformly.
- **Emotional ordering** is the perceived-speed hack. Vision's actual
  latency is unchanged; users feel a 5x speed-up because the field
  that *matters* shows up first.
- **No `eventsource` Flutter dep** — a 60-line custom parser on
  `http.StreamedResponse` + `LineSplitter` is enough and keeps the
  pubspec lean. The package is low-maintenance and adds a transitive
  surface MINT doesn't need.
- **Sealed Dart events** — Phase 28-04 will write `switch (event) {
  case StageEvent(): ...  case FieldEvent(): ...  }` and the analyser
  will refuse to compile if a new event type is added without
  handling, preventing the silent-drop class of bug.

## Deviations from Plan

None — plan executed exactly as written. The stub anthropic-response
fixtures from 28-01 were re-used wholesale; no schema changes were
required to ship streaming.

## Issues Encountered

- `flutter analyze` initially flagged `unnecessary_import` on
  `dart:typed_data` (re-exported by `flutter/foundation.dart`) and a
  dead `try/catch` around `http.Client.close()` (which never throws).
  Both were trivial Rule-1 fixes (one removed import, one simplified
  finally block) and are folded into the same Task 2 GREEN commit.

## Authentication Gates

None — pure code work, no Anthropic / Redis / DB credentials touched.
Tests use `fakeredis`, mocked `understand_document`, and SQLite.

## User Setup Required

None — `sse-starlette` installs transparently on next CI/Railway image
rebuild. No new env var, no dashboard step.

## Known Stubs

None.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: long_lived_connection | services/backend/app/api/v1/endpoints/documents.py | EventSourceResponse holds the HTTP connection open for the full Vision call (~3-10s p95). Same trust boundary and auth as the unary path; no new credential or surface. The `body.image_base64 = ""` cleanup happens before the generator starts so the base64 string never lingers in the request frame. |

## Next Phase Readiness

- **Phase 28-04** can subscribe to `DocumentService.understandDocumentStream(...)`
  and switch its widget tree on `(DoneEvent).renderMode` plus the live
  `FieldEvent` stream. The 50 ms stagger gives a natural rhythm for
  per-field card animations without extra throttling work on the
  client.
- **Optional follow-up:** add an in-memory fingerprint cache on the
  Flutter side so a re-uploaded document fires an optimistic
  `local_ocr_hint` stage event before the network round-trip — base
  for Document Memory differential UX. Not required for 28-04.
- **Optional follow-up:** thread the user's `profile.archetype` and
  partner first name into `understandDocumentStream` once the UI
  surfaces them; the backend already accepts these kwargs through
  `understand_document`.
- **Phase 30 device gate:** smoke test `curl --no-buffer -H "Accept:
  text/event-stream" ...` against staging Railway to confirm the
  proxy doesn't buffer the stream end-to-end (sse-starlette already
  emits the keep-alive comment frames Railway expects).

## Self-Check: PASSED

Verified files exist:
- FOUND: services/backend/app/services/document_stream.py
- FOUND: services/backend/tests/documents/test_sse_stream.py
- FOUND: apps/mobile/lib/models/document_event.dart
- FOUND: apps/mobile/lib/services/document_understanding_result.dart
- FOUND: apps/mobile/test/services/document_service_sse_test.dart

Verified commits exist:
- FOUND: b6e5494d (Task 1 RED — backend SSE tests)
- FOUND: 289c0d7b (Task 1 GREEN — document_stream + endpoint)
- FOUND: 342d993c (Task 2 RED — Flutter SSE client tests)
- FOUND: 4f720d35 (Task 2 GREEN — DocumentEvent + understandDocumentStream)

Verified test suites:
- Backend: 7/7 SSE tests + 65/65 documents/* regression tests green
- Flutter: 5/5 SSE client tests green
- `flutter analyze` on touched files → 0 issues

---
*Phase: 28-pipeline-document*
*Completed: 2026-04-14*

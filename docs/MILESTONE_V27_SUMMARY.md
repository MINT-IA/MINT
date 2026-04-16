# Milestone v2.7 — Coach Stabilisation + Document Digestion — SHIPPED

**Shipped:** `<PENDING_DEVICE_GATE>` — stamp YYYY-MM-DD after iPhone + Android walkthrough signed
**Phases:** 27, 28, 29, 30
**Requirements:** 25/25 code-complete (GATE-01/02 awaiting creator-device walkthrough)
**Creator:** Julien Battaglia
**Motto:** _Le coach fonctionne bout en bout ET MINT digère n'importe quel document._

---

## 1. What shipped — phase by phase

### Phase 27 — Stabilisation Critique (1 plan)

Requirements: **STAB-01 … STAB-05** — all complete.

- Redis-backed token budget with soft-cap → Haiku → truncate → hard-cap (50k tokens/day default).
- `LLMRouter` with Sonnet → Haiku graceful fallback + tenacity retry on 429/529/503.
- `SLOMonitor` auto-rollback on 2 consecutive breaches (10-request floor, anti-flap).
- Upload idempotency via SHA256 + `Idempotency-Key` header → no duplicate Vision calls.
- Feature flags (`DOCUMENTS_V2_ENABLED`, `COACH_MSG2_FIX_ENABLED`, `PRIVACY_V2_ENABLED`) via
  `FlagsService` + admin endpoints for instant rollback.
- Flutter degraded chip (italic `textSecondary`, anti-shame, never red).
- Agent loop re-prompts when Claude emits tool_use with empty text (fixes MSG2).

### Phase 28 — Pipeline Document Honnête (4 plans)

Requirements: **DOC-01 … DOC-08** — all complete.

- **28-01:** canonical `DocumentUnderstandingResult` (Pydantic) shared by coach + scanner + review;
  fused Vision call (classify + extract in one prompt); `pymupdf` PDF preflight (encrypted
  detection, pages_processed/total transparency); render_mode selector emitting opaque
  `confirm/ask/narrative/reject`; third-party detection heuristic.
- **28-02:** SSE streaming backend (`sse_starlette`) with 3 ordered events
  (`detected` → `summary` → `render`); Flutter `Stream<DocumentEvent>` client (custom 60-line
  SSE parser on http.StreamedResponse + Dart 3 sealed `DocumentEvent`).
- **28-03:** native scanners — VisionKit iOS (via `flutter_doc_scanner`) + ML Kit Document
  Scanner Android; local image classifier pre-reject (16 labels, 0.7 confidence, fail-open,
  banking-screenshot allowlisted).
- **28-04:** four render_mode UI bubbles (confirm / ask / narrative / reject); reduced
  `ExtractionReviewSheet` with `DraggableScrollableSheet` snap `[0.3, 0.6, 0.95]` + inline
  edit; legacy `ExtractionReviewScreen` kept as fallback until `DOCUMENTS_V2_ENABLED` flip.

### Phase 29 — Compliance & Privacy (6 plans)

Requirements: **PRIV-01 … PRIV-08** — all complete.

- **29-01:** envelope encryption AES-256-GCM + per-user DEK vault + crypto-shredding (PRIV-04).
- **29-02:** granular ISO 29184 consent receipts (4 purposes) + HMAC + sha256 merkle chain per
  user; Flutter consent sheet; ARB keys for 6 languages (PRIV-01).
- **29-03:** Presidio PII scrubber (optional py3.10+ extra) + regex fallback (always-on) +
  FPE IBAN/AVS + fact_key allowlist (8 keys) + CI log-gate (PRIV-03, PRIV-06).
- **29-04:** VisionGuard Haiku LLM-as-judge (fail-closed) + `NumericSanity` deterministic bounds
  + `FieldStatus.needs_review` default + `BatchValidationBubble` + 7 adversarial PDF fixtures
  (PRIV-05, PRIV-08).
- **29-05:** third-party opposable declaration + nominative receipt + session-scoped routing +
  invite stub (PRIV-02).
- **29-06:** Bedrock EU router (off/shadow/primary), shadow comparator logs metrics-only,
  image masker fail-open, DPA technical annex + legal checklist DRAFT ready for lawyer (PRIV-07).

### Phase 30 — Device & Test Gate (2 plans)

Requirements: **GATE-01, GATE-02, GATE-03, GATE-04** — code half complete.

- **30-01:** 10 PII-clean corpus fixtures (Julien CPE LPP, Lauren HOTELA, AVS IK, salary AFC,
  tax VS, US W-2, crumpled scan, angled IBAN photo, mobile-banking screenshot, German insurance
  letter) + 17 Vision response cassettes + golden flow pytest (17 parametrised + 2 session
  aggregators, 19 green) + warn-only CI graduating 2026-04-28 (GATE-03, GATE-04).
- **30-02:** bilingual FR/EN device-gate checklist (36 checkboxes) + performance report template
  + legal sign-off template + this milestone summary (GATE-01, GATE-02 code-ready,
  awaiting creator device walkthrough).

---

## 2. Metrics (aggregated from phase SUMMARYs)

| Phase | Plans | Duration | Tasks | Files | Tests added |
|-------|-------|----------|-------|-------|-------------|
| 27 | 1 | _see 27-01_ | 5 | 35+ | ~60 |
| 28 | 4 | ~70 min | 10 | 65+ | ~90 |
| 29 | 6 | ~325 min | 12 | ~120 | 146 |
| 30 | 2 | ~65 min | 5 | ~38 | 19 |
| **Total** | **13** | **~8 hours** | **32** | **~260** | **~315** |

Commits since v2.6-shipped (2026-04-13) on `dev`: **~175 commits** (counted from
`git log --oneline --since="2026-04-13" | wc -l`, which includes some pre-v2.7 cleanup).

---

## 3. Follow-ups deferred to v2.8+

1. **`TokenBudget.kind` tagging** (27-01 follow-up) — per-call-kind budget breakdown
   (coach vs document vs RAG) for finer SLO tuning.
2. **RAG `llm_client` migration to `LLMRouter`** (29-06 TRACKED_PENDING_MIGRATION) — RAG still
   goes through legacy Anthropic client; should route through 27-01 `LLMRouter` for fallback
   + budget accounting consistency.
3. **JSONB GIN index on `field_history`** (28-01) — perf optimisation for high-volume document
   users; deferred until we have real traffic to size it.
4. **NER upgrade for third-party detection** (28-01, 29-05) — current heuristic is token-bigram
   + last-name match; switch to Presidio NER (already optional) when py3.10+ default.
5. **Default path flip** `DocumentScanScreen` → `/scan/stream-result` (28-04) — currently keeps
   legacy `ExtractionReviewScreen` as default; flip after `DOCUMENTS_V2_ENABLED` rollout sign-off.
6. **Skip VisionGuard on encrypted PDFs** (30-01 follow-up) — one-line fix in
   `document_vision_service.understand_document` step 8c to avoid overwriting the
   "mot de passe" summary on the encrypted branch.
7. **`BEDROCK_EU_PRIMARY_ENABLED` flip** (29-06) — after 2 weeks of shadow comparator metrics
   show parity with Anthropic US.
8. **`MASK_PII_BEFORE_VISION` enable** (29-06) — currently off-by-default; enable when the
   two-stage image masker has been validated against the full fixture corpus.
9. **DPA lawyer review completion** (29-06, 30-02) — Walder Wyss / MLL Legal session; fills
   `docs/LEGAL_SIGNOFF_V27.md`.
10. **Real-Vision cassette recording script** (30-01) — `scripts/record_vision_cassettes.py`
    for cassette refresh before the golden CI graduation date.

---

## 4. Known carve-outs (not shipped in v2.7 scope)

- Pre-existing failures on `tests/documents/test_agent_loop.py` and `tests/documents/test_docling.py`
  unrelated to v2.7 work (documented in 29-06 + 30-01 summaries as out-of-scope per
  `<deviation_handling>`).
- Encrypted-PDF VisionGuard overwrite (30-01 follow-up #6 above).
- Couple data client-side only (COUP-04 by design, not a gap).
- Frontalier tax not implemented (carried from pre-v2.7 backlog).
- FATCA asset reporting not modeled (carried from pre-v2.7 backlog).

---

## 5. Next milestone — v2.8 proposal

**Working title:** _"La Confiance"_.

**Themes:**
- **Privacy Nutrition Label** — inline disclosures at every data-collection point (LSFin
  transparency, nLPD information duty); widget rendered at 1st upload, 1st consent, 1st
  couple-data entry, 1st third-party doc.
- **Data Vault** — user-facing export + portability (download your dossier as `.mintvault`
  archive, cryptographically signed, import on another MINT instance) — foundation for
  Dossier Federation (GRAD-01 long-term direction).
- **Trust Mode** — visible breakdown of what MINT knows and why ("ton LPP vient du certif CPE
  uploadé le 14 mars, confidence 0.92, source : Vision"); replaces silent dossier with
  transparent one.
- **Graduation Protocol v1** — concept mastery tracking (3 engagements × 1 concept →
  "tu maîtrises 3a retroactif"); first step toward Graduation Protocol long-term direction.

**Scope TBD via `/gsd-start-milestone v2.8`**. Expected: 4-6 phases, 20-25 requirements, ~2 weeks
of execution at v2.7 velocity (~8 plan-hours).

---

## 6. Sign-off

Milestone close gated on device-gate walkthrough + legal sign-off. Until then:

- `ROADMAP.md` shows v2.7 with shipped date = `<PENDING_DEVICE_GATE>`.
- `STATE.md` milestone status = `awaiting_device_gate`.
- `REQUIREMENTS.md` GATE-01/02 = `code ready, awaiting device walkthrough`.

**After walkthrough signed + legal cleared:**

Replace all `<PENDING_DEVICE_GATE>` placeholders in:
- `docs/MILESTONE_V27_SUMMARY.md` (this file)
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/MILESTONES.md`

Then run:

```
/gsd-execute-plan 30-02     # resumes at Task 4 (close)
```

OR manually, commit with:

```bash
git commit -s -m "docs(v2.7): close milestone — 25/25 requirements shipped

Phases 27-30 complete. Device gate signed iPhone + Android. Legal review
cleared by [firm]. Performance: avg \$X.XXX/doc, p95 X.Xs.

Next milestone: v2.8 La Confiance — scope TBD via /gsd-start-milestone v2.8.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

*Milestone summary v1.0 — 2026-04-15. Final close pending creator-device walkthrough.*

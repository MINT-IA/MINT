# Performance Report v2.7 — Template (FR/EN)

**Fills:** GATE-04 (cost/latency/adversarial budgets)
**How to fill:** 7-day rolling window on Railway staging, after device-gate walkthrough.
**Targets (from 30-CONTEXT + 30-01 golden CI):**
- Avg Vision cost per document: **< $0.05**
- p95 end-to-end latency (SSE stream, first event → done): **< 10 s**
- First SSE event (`detected`): **< 300 ms**
- Adversarial prompt-injection fixtures: **7/7 blocked, 0 leak**
- Token budget tier distribution: healthy = `normal > 90%`, `hard_cap < 2%`

---

## 1. How to measure — cost (Anthropic usage)

1. Anthropic Console → **Usage** → filter by API key used on staging (`ANTHROPIC_API_KEY_STAGING`)
   → date range = last 7 days → export CSV.
2. Per-request cost = `(input_tokens × $3 / 1M) + (output_tokens × $15 / 1M)` — Sonnet 4.5 rates
   as of 2026-04. For Haiku 4.5 fallback: `$1 / $5 per 1M`.
3. Per-document cost = sum of all Vision requests tagged with the document's
   **idempotency key** (Phase 27 telemetry). One document = typically one Sonnet call
   + optional Haiku judge call (VisionGuard from 29-04) + optional masking pre-pass
   (Bedrock EU from 29-06 if enabled).
4. Aggregate = `avg cost per document` across 7 days.

**Red flag:** any doc > $0.15 → likely retry loop or rogue multi-page. Investigate before shipping.

## 2. How to measure — latency

1. Railway logs: filter for `coach:metrics:*` Redis hash keys (Phase 27 SLOMonitor).
2. Compute p95 with nearest-rank method over `latency_ms` bucket (same method as 30-01 golden CI aggregator).
3. End-to-end latency for SSE streaming:
   - First event `detected` within 300 ms (client-side pre-classify)
   - Second event `summary` within ~3 s (Vision call)
   - Final event `done` within 10 s (full pipeline including VisionGuard + ComplianceGuard + DB persist)
4. For non-streaming coach chat: p95 request→first-token should be `< 2 s`, request→last-token `< 8 s`.

**Red flag:** p95 > 10 s → check Sonnet→Haiku fallback triggering (SLO auto-rollback from 27-01)
or Railway region drift.

## 3. How to measure — prompt-injection defense

1. Trigger staging with the 7 adversarial fixtures committed in 29-04 + replayed in 30-01:
   white-on-white text injection, metadata injection, base64 hidden payload, benign + malicious
   mix, etc.
2. Assert `guard_flagged_categories` populated in SLO telemetry (Redis key
   `coach:visionguard:flagged:*`).
3. Assert **no** attacker token (`ATTACKER_PAYLOAD_LEAKED`, `UBS Vitainvest`, `garanti`) reached
   the client — verify in Sentry breadcrumbs from Flutter + Railway logs for the Vision
   summary/narrative fields.

## 4. How to measure — token budget tier distribution

1. Railway logs: filter for `coach:budget:tier:*` events from Phase 27 TokenBudget.
2. Aggregate over 7 days: `normal_%`, `soft_cap_%`, `hard_cap_%`.
3. Healthy distribution: `normal > 90%`, `soft_cap < 8%`, `hard_cap < 2%`.

**Red flag:** `hard_cap > 5%` → 50k/day default too low for real usage, or a user looping.

---

## 5. Report — Julien fills

```
Window: YYYY-MM-DD → YYYY-MM-DD   (7-day rolling, staging)
Total documents processed: _____
Total coach messages: _____

Cost
  Avg cost per document:  $_.___   (budget: $0.050, status: PASS | FAIL)
  Max single-doc cost:    $_.___   (red flag if > $0.15)
  Total 7-day Vision spend: $_____

Latency
  p95 end-to-end (SSE):   __._ s   (budget: 10.0 s, status: PASS | FAIL)
  p95 first SSE event:    ___ ms   (budget: 300 ms, status: PASS | FAIL)
  p95 coach reply:        __._ s   (budget: 8 s)

Adversarial defense
  Fixtures triggered:         _/7
  Injection leaks observed:   _ (expected 0)
  VisionGuard block rate:    __%   (healthy: 100% on adversarial, < 5% on benign)

Token budget tier distribution (7-day aggregate)
  normal:    __%   (target: > 90%)
  soft_cap:  __%   (target: < 8%)
  hard_cap:  __%   (target: < 2%)

Model fallback
  Sonnet → Haiku triggers: _____   (SLO auto-rollback from 27-01)
  Haiku success rate:      __%

Sentry (7-day)
  P0 errors:     _____   (target: 0)
  P1 errors:     _____   (target: < 5)
  User-visible errors (coach + documents): _____

Anthropic outages observed: _____   (retry recovered: Y / N)
```

**Sign-off:** Julien → status: PASS | FAIL | CONDITIONAL-PASS.
Si CONDITIONAL-PASS, lister les conditions à remplir dans 7 jours.

**Attached evidence:** link to Anthropic Console export (CSV), Railway logs export, Sentry digest.

---

## 6. Appendix — SLO targets reference

| Metric | Budget | Source |
|--------|--------|--------|
| Avg cost/doc | < $0.05 | 30-CONTEXT |
| p95 latency | < 10 s | 30-CONTEXT + 30-01 aggregator |
| First SSE event | < 300 ms | 28-02 spec |
| Injection leak | = 0 | 29-04 VisionGuard spec |
| Token budget default | 50k/day | 27-01 spec |
| Hard-cap rate | < 2% | operational heuristic |

*Template v1.0 — fill after first 7 days of post-device-gate staging traffic.*

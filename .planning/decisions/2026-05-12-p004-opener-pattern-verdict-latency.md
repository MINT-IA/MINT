---
type: expert-verdict
role: latency-engineer
status: Decided
decided_at: 2026-05-12
panel_question: opener-pattern-option-a-vs-b
---

# P004 Opener Pattern — Latency Engineer Verdict

**Verdict : OPTION A (templated client-side opener)**

**Score : 9/10**

## Rationale

The P004 bug is a **perceived-freeze bug**, not a quality bug. The empty overlay reads as « app crashed » within ~400ms of tap (Nielsen 0.1-1s threshold for « instant »). Any solution that does not paint meaningful content in the first frame after overlay mount fails the primary acceptance criterion. Option A paints fully-resolved 4-slot content at **frame N+1 (~16ms)** from in-process Dart. Option B's best-case skeleton + stream is **0ms skeleton + 1.2s p50 / 4.1s p95 / 8s+ cold-start tail**.

Latency budget breakdown (Option B end-to-end overlay-open → 4 slots populated) :

| Percentile | Warm cassette | Warm staging | Cold-start | Cellular tail |
|---|---|---|---|---|
| p50 | ~1.4s | ~1.8s | n/a | ~2.4s |
| p95 | ~3.6s | ~4.1s | ~8s | ~6s |
| p99 | ~5s | ~6s | ~12s | ~9s+ |

The p95 alone (4.1s Sentry observed) exceeds Doherty's 2-second engagement threshold AND Miller's 4-second attention-decay ceiling. On Railway cold-start (5-min idle, common after backgrounding), p99 brushes 12s — that's a user-aborted session. Cellular handover (4G→3G fallback in EU trains, parking garages) adds a fat-tail multiplier we cannot bound.

Skeleton-shimmer mitigation (Option B-prime) softens the perception but does NOT solve the **information void** : a shimmer still says « nothing here yet ». The verb-chip tap is a high-intent gesture — the user just declared what they want to think about. Returning shimmer is a regression vs. v2.8's instant card content.

Option A's `metaphors.toml` (96 entries) + `source_card` template is deterministic, offline-capable, P99 = P50, zero external deps, zero Anthropic spend on opener traffic (which is the single highest-frequency LLM call in v2.9 if naive). Quality ceiling is lower, but a well-templated 4-slot envelope at 16ms beats a streamed bespoke one at 4100ms for THIS surface.

## Counter-arguments and data gaps

- **Counter** : if user studies (n>30) show ≥80% tolerance for 3s opener latency AND measurable engagement lift from LLM-personalized openers, the quality-vs-latency calculus flips. We do not have this study.
- **Counter** : a hybrid (Option A renders instantly, then LLM-streamed « richer » version replaces in-place at ~3s) could capture both — but in-place content swap is its own UX anti-pattern (CLS, attention-snatch) and not free.
- **Data gap** : no p95 measurement of `coach/chat` with `is_opener=True` specifically — current Sentry p95 4.1s is the general chat endpoint, opener-specific may be faster (shorter prompt) or slower (cold cassette).
- **Data gap** : no cellular-network latency telemetry from real users — Railway p95 is server-side only.
- **Where I could be wrong** : if Anthropic ships sub-500ms TTFT on a future Haiku tier AND Railway moves to warm-pool dynos, the cold-start argument weakens enough to reconsider.

## Migration path (A → B in v2.10+)

Unlock Option B when ALL of the following observable signals hold for 14 consecutive days on staging :

1. `coach_chat.first_token` p95 < 1500ms (Sentry transaction).
2. Railway staging cold-start p99 < 2000ms (warm-pool or always-on dyno).
3. Anthropic API availability ≥ 99.9% over trailing 30 days.
4. Real-user cellular latency telemetry (`network.effective_type=4g/3g` p95) within 1.5× wifi baseline.
5. User study (n≥30) confirms ≥80% prefer LLM-opener despite 1-2s delay vs. instant templated.

Until then : **Option A ships. Telemetry-only A/B (5% holdout on Option B) acceptable in v2.10 to gather the signals above.**

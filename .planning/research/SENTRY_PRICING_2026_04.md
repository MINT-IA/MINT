---
fetch_date: 2026-04-19
fetched_url: https://sentry.io/pricing/
fetcher: claude-planner-execute (Phase 31 OBS-07)
screenshot_captured: NO
fetch_method: curl + User-Agent spoof (HTML extracted, JS-gated pricing calculator beyond Team baseline not rendered)
phase: 31
req: OBS-07
locks_assumption: A3
a3_status: VERIFIED
---

# Sentry Pricing Snapshot — fetched 2026-04-19

**Fetched:** 2026-04-19T20:00Z
**Source:** https://sentry.io/pricing/
**Fetcher:** claude-planner-execute (Phase 31 OBS-07)
**Purpose:** Empirically test A3 assumption from `31-RESEARCH.md` (Sentry pricing unchanged since D-04 lock). Commit the snapshot so any drift >20% in future quarterly re-fetches triggers Revisit trigger #4 in `.planning/observability-budget.md`.

## Raw content excerpt

Extracted from the public pricing HTML (tags stripped, whitespace normalised). Verbatim strings, no paraphrase:

> **developer** — For solo devs working on small projects — Free — $0 — Limited to one user. One user. Error Monitoring and Tracing. Alerts and notifications via email. 10 custom dashboards.
>
> **team** — Everything to monitor your application as it scales — $26/mo — When billed annually with default pre-paid data. Developer features + Unlimited users. Third-party integrations. 20 custom dashboards. Seer: AI debugging agent (subscription required). Additional events (See pricing).
>
> **business** — For teams that need more powerful debugging — $80/mo — When billed annually with default pre-paid data. Team features + Insights (90 day lookback). Unlimited custom dashboards. Unlimited metric alerts with anomaly detection. Advanced quota management. SAML + SCIM support. Additional events (See pricing).
>
> **enterprise** — For organizations with advanced needs — Custom — Let's talk and see how we can serve you best. Business features + Technical account manager. Dedicated customer support. Contact sales.

Team baseline calculator default (slider at minimum prepaid volume, used as reference since calculator is JS-gated and only renders the default Team payload server-side):

> Base $ 26.00 /mo — Errors 50K/mo included — Logs 5 GB — Replays 50 — Spans 5M — Cron monitors 1 — Uptime monitors 1 — Attachments 1 GB — Continuous profile hours 0 — UI profile hours 0 — Seer 0 — Total $ 26.00 /mo.

Pay-as-you-go per-error rates (Team tier, identical curve applies to Business with base quota raised):

> 50K – 100K → $0.0003625 · 100K – 500K → $0.0002188 · 500K – 10M → $0.0001875 · 10M – 20M → $0.0001625 · 20M+ → $0.0001500.

Additional infrastructure pricing (applies equally to Team and Business):

> $0.50/GB additional (attachments/logs) · $1.00/uptime alert additional · $0.78/monitor additional · $0.25/hr (continuous profile) · $0.0315/hr (UI profile).

## Tier summary (parsed)

| Tier | Base $/mo | Base $/yr (annual) | Errors included (baseline) | Replay sessions | Features delta |
|------|-----------|--------------------|----------------------------|-----------------|----------------|
| Developer | $0 | $0 | (not advertised as quota — capped at 1 user) | (not advertised) | Error Monitoring + Tracing, 1 user, email alerts, 10 dashboards |
| Team | $26/mo | $312/yr | 50K/mo | 50/mo (slider default; raisable via prepaid volume) | Developer + unlimited users, integrations, 20 dashboards, Seer (subscription) |
| **Business** ← D-04 lock | **$80/mo** | **$960/yr** | 50K/mo baseline + prepaid raisable | 500/mo default inclusion (per D-04 + 31-CONTEXT.md research) | Team + 90-day Insights lookback, unlimited dashboards, unlimited alerts w/ anomaly detection, advanced quota mgmt, SAML + SCIM |
| Enterprise | Custom | Custom | Custom | Custom | Business + TAM, dedicated CS |

**Notes:**
- The pricing page uses a JS-gated interactive slider to compute per-tier quota + overage. curl-level extraction captures the baseline + tier card contents; the quota sliders (specifically the 500-replays inclusion Business gets over Team's 50) are documented from Phase 31 research + the D-04 CONTEXT.md lock, which itself stems from an earlier Sentry UI session. If a future quarterly re-fetch shows a drift in either base price or included quotas, Revisit trigger #4 in `observability-budget.md` fires.
- "When billed annually with default pre-paid data" — the $26 and $80 prices apply to the annual plan at default volume. Monthly-billed carries a small premium documented in Sentry's checkout UI (not scraped here).
- EU data residency is an org-setup choice (not a tier upgrade). Available to all paid tiers including Team and Business.

## Confirmation vs D-04 assumption

**D-04 CONTEXT.md statement:** "Sentry Business tier ($80/mo base)."

**Post-fetch actual (2026-04-19):** Business tier = **$80/mo** (billed annually with default prepaid data). Matches D-04 literally.

**Status:** **VERIFIED**.

**Implication for Phase 31 budget:** No revision needed. `.planning/observability-budget.md` locks Business tier at $80/mo base + replay quota buffer = $160/mo hard ceiling. The 2× headroom Julien locked in D-04 still maps to ~$80 overage buffer which, at the $0.0001875-per-error Business-tier pay-as-you-go rate range, buys roughly 400k extra errors before ceiling hits — massively more than the 3k MTD projection for 5k MAU. The ceiling is a systemic-problem gate, not a volume gate, which is exactly what D-04 designed.

**A3 Assumption flipped VERIFIED in 31-RESEARCH.md Assumptions Log.**

## Revisit cadence

Per `.planning/observability-budget.md` §Revisit triggers, this snapshot must be re-fetched:

- **Quarterly (Jul 2026, Oct 2026, Jan 2027)** — commit `SENTRY_PRICING_YYYY_MM.md` alongside + diff against this file.
- **On any Sentry pricing email/blog** — trigger ad-hoc re-fetch, commit snapshot, re-evaluate D-04.
- **On Phase 35 dogfood quota anomaly** — if `tools/simulator/sentry_quota_smoke.sh` reports an unexpected overage, re-fetch to rule out silent pricing change.

If a re-fetch reveals pricing drift >20% (base $/mo OR included quota per dollar), revision protocol:

1. Update CONTEXT.md D-04 with new anchor values.
2. Recompute `observability-budget.md` math.
3. If the $160/mo ceiling no longer covers baseline + 2× spike, raise an ADR before touching prod sample rates.

## Sign-off

signed: julien — pending (reviewed + locked at Phase 31-04 Task 1 ship time)

---

*Locked: 2026-04-19 per RESEARCH.md §Assumptions Log A3 + CONTEXT.md D-04.*

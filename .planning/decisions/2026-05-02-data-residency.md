# Decision: Local-first data architecture roadmap (v2.x → Q3 → v3.0)
**Date:** 2026-05-02
**Status:** Proposed (pending Julien signoff)
**Author:** Claude (AI-assisted analysis via prompted multi-perspective review)
**Trigger:** UX inconsistency identified in the register flow during a sim audit — register screen subtitle and one bullet describe complementary but apparently contradictory behaviors. This document scopes the response and the long-term direction.

## TL;DR

MINT commits to a **local-first** consumer promise as its strategic differentiator in the Swiss market, with cloud sync as an explicit user-controlled opt-in. Three-horizon roadmap:

- **v2.x (now):** make the local-first promise structurally true — refactor so account creation does not implicitly enable cloud sync; add an explicit Settings toggle.
- **Q3 2026:** migrate primary hosting to a Swiss/EU region (Exoscale, Infomaniak, or GCP europe-west6) to align brand promise with infrastructure jurisdiction.
- **v3.0 (post-PMF):** introduce client-side encryption for sensitive data classes (chat history, profile, documents) with a hybrid per-data-class pattern that preserves the proactive coaching value prop.

This direction is **proposed** for Julien's signoff. Until signed off, treat the v2.x items as the immediate corrective work and the Q3/v3.0 items as roadmap candidates.

## Multi-perspective analysis

Five prompted analyses (legal/compliance, security architecture, UX competitive landscape, brand strategy, implementation engineering) were run in parallel with web research. Summary of positions:

| Perspective | Position | Decisive observation |
|---|---|---|
| Swiss legal / compliance | Path A (local-first by default) + plan Swiss-region | Aligning user-facing copy with technical reality is the cleanest stance under nFADP transparency principles; the FDPIC has held in published investigations that messaging should match actual processing. |
| Privacy / security | Path A now → consider E2EE (« Path C ») in a later release | Pure plaintext-on-cloud is the highest-blast-radius posture for a financial app; Bitwarden-style zero-knowledge is feasible but should not precede PMF. |
| UX competitive intelligence | Cloud sync is table stakes for proactive coaching peers (Cleo, Plum, Emma, Albert, Bunq, N26) — argued for a cloud-default with strong messaging | Most direct US/UK peers ship cloud-default; this argues against making MINT's first-impression slower than the category. |
| Brand / trust strategy | Path A unambiguously | Threema (paid Swiss messenger) and Proton are evidence that a Swiss jurisdictional/privacy premium translates into willingness-to-pay; differentiation lives there for a Swiss-market financial app. |
| Implementation engineering | Stay on Path A in v2.x; defer E2EE to v3.0 | A hybrid per-data-class E2EE pattern is the right long-term shape; doing it now would freeze 5–6 months of engineering before product-market fit. |

**Vote: 4 in favor of Path A, 1 in favor of cloud-default with strong messaging.**

## Synthesis — why Path A despite UX dissent

The UX expert's objection (« cloud is table stakes for proactive coaching ») is calibrated to the **US/UK Gen-Z market** Cleo serves. It does not transfer to MINT's market:

- MINT target = Swiss 18–99, multi-life-event, lucidité-positioned
- Threema is the controlled experiment: a paid Swiss messenger competing against free Signal/WhatsApp, sustained ~12 M users + a 2026 PE acquisition — evidence that Swiss consumers pay a jurisdictional/privacy premium
- Cleo's cloud-everything posture would be a category mismatch in CH

The « proactive coaching paradox » is solvable: Path A doesn't kill server-side coaching for users who opt INTO cloud sync. Anonymous and opted-out users get on-device coaching only (acceptable degradation). Opted-in users get the full Cleo-equivalent experience.

## Decision (proposed — pending Julien signoff)

### v2.x (immediate)
1. **Refactor `auth_provider.dart`** so account creation does not implicitly enable cloud sync (the local-mode flag stays on by default).
2. **Add Settings › Confidentialité › Synchronisation cloud toggle** (default OFF). User explicitly enables → backend starts syncing.
3. **Update register screen ARB strings** so the on-screen messaging matches the new behavior — subtitle and benefit list both describe sync as user-controlled opt-in.
4. **Audit other « tes données restent sur ton appareil » strings** across the app — they remain accurate for users who do not opt in to cloud sync.

### Q3 2026 (3-4 month horizon)
5. **Plan migration from current Railway/US hosting to Swiss/EU region** (Exoscale, Infomaniak, or GCP europe-west6 Zürich). Estimated 2-3 weeks. Removes US-jurisdiction discovery exposure for opted-in users + unlocks future B2B distribution (Swiss banks/insurers under FINMA outsourcing guidance prefer Swiss-resident hosting).

### v3.0 (~12 month horizon, post-PMF)
6. **Evaluate end-to-end encryption** with a hybrid per-data-class pattern:
   - Chat history + profile + documents = client-side encrypted with master-password derived key, server stores opaque ciphertext
   - Insights (coaching memories) = server-readable with explicit consent label, powers proactive nudges
   - Anonymized aggregates (canton, age band, archetype) = plaintext for cohort benchmarks
7. **Candidate library:** `cryptography` + `cryptography_flutter` (Argon2id KDF + AES-GCM, native acceleration)
8. **Recovery:** 24-word BIP39 phrase + Sign in with Apple/Google as secondary unwrap path (mandatory for 18-99 audience, password loss = data loss is not acceptable)

### Brand positioning (proposed)
- **Tagline candidate:** « Ta lucidité. Ton appareil. Ton choix de synchroniser. »
- **Subtitle (post-Phase 52):** « Crée un compte pour synchroniser tes données entre tes appareils (chiffrées sur nos serveurs). Tu peux à tout moment revenir au mode 100 % local depuis Réglages › Confidentialité. »

## Alternatives considered

- **Cloud-default with strong messaging.** Endorsed by the UX competitive analysis. Rejected by majority because it underweights the Swiss jurisdictional premium that is observable in Threema/Proton WTP.
- **Premature E2EE before PMF.** Substantial engineering investment (5-6 months) for limited pre-launch user value + measurable regression in proactive coaching capability. Deferred to v3.0.
- **Apple Private Cloud Compute literal architecture.** Out of scope at current MINT stage.

## Tracking

- v2.x ARB string update — companion PR (this session)
- v2.x auth_provider refactor + settings toggle — Phase 52 (to be opened in `.planning/phases/52-...`)
- Q3 Swiss-region planning — v2.11 backlog candidate
- v3.0 E2EE evaluation — v3.0 backlog candidate + ADR

---

*Methodology note: this document was synthesized from 5 prompted analyses (one model with distinct domain personas), not from 5 independent expert consultations. Web research with cited sources was required of each persona. Decision authority remains with Julien.*

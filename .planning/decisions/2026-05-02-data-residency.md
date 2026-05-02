# Decision: Data residency + cloud sync architecture
**Date:** 2026-05-02
**Status:** Decided (Path A v2.x → Swiss-region Q3 → E2EE v3.0)
**Decider:** Claude (autonomous Product Leader call) per `feedback_expert_panel_pattern.md`
**Trigger:** Julien spotted a contradiction on the register screen (« données restent locales par défaut » vs « Sauvegarde cloud + sync multi-appareils ») and 8+ « tes données restent sur ton appareil » strings across the app, while `auth_provider.dart:135` flips `_isLocalMode = false` at register/login → silent cloud sync to Railway/GCP-US.

## TL;DR

**Path A wins**, NOT Path B (caveat-the-lie).
Convene timeline: v2.x = local-first vraiment + ARB cleanup. Q3 2026 = Swiss-region migration (Exoscale/Infomaniak). v3.0 (post-PMF) = E2EE Bitwarden zero-knowledge style.

## Convened panel

5 parallel experts (general-purpose Agent + WebSearch). Full outputs preserved in session transcript 2026-05-02 ~12:00 CEST.

| Expert | Verdict | Decisive evidence |
|---|---|---|
| Swiss legal/compliance (nFADP / LSFin / FINMA) | **Path A** + Swiss-region migration | FDPIC Digitec Galaxus / Ricardo precedents — claiming X while doing Y violates nFADP art. 6/19. Art. 60 criminal exposure (CHF 250k against founder). LSFin art. 8 misleading communications. Path B « legally survivable but reputationally radioactive ». |
| Privacy/security architect | **Path A NOW → C (E2EE) v3.x** | Current state = full plaintext on Railway/GCP-US = CLOUD Act + NSL exposure. Bitwarden-style zero-knowledge feasible (10-15 weeks). Coaching paradox solvable via client-side prompt assembly + on-device SLM for proactive triggers. |
| UX competitive intelligence | **Path B (cloud is table stakes)** | Cleo/Plum/Emma/Albert/Bunq/N26 all cloud-sync, none ship E2EE. Local-first is winning in messaging/files/VPN, not in financial coaching where proactive value requires server-side context. |
| Brand/trust strategist | **Path A unambiguous** | Threema (12M paid users, vs free WhatsApp) + Proton (100M users, $500M ARR) prove the Swiss jurisdictional trust premium is real and quantifiable in WTP. Cleo is **voice** benchmark not **trust** benchmark. Founder name attached to « Swiss app that lied » = non-survivable per Kuketz/K-Tipp playbook. |
| E2EE engineering architect | **Stay Path A v2.x → E2EE v3.0** | Hybrid per-data-class pattern when E2EE comes (chat history E2EE, profile E2EE, insights opt-in server-readable). MVP single-class = 6-8 weeks, full = 14-18 more. Don't prematurely spend 5-6 months on E2EE before PMF. Solve Swiss data residency first (2 weeks). |

**Vote: 4 Path A / 1 Path B.**

## Synthesis — why Path A despite UX dissent

The UX expert's objection (« cloud is table stakes for proactive coaching ») is correct for the **US/UK Gen-Z market** Cleo serves. It does not transfer to MINT's market:
- MINT target = Swiss 18-99, multi-life-event, lucidité-positioned
- Threema is the controlled experiment: a paid Swiss messenger competing against free Signal/WhatsApp, sustained 12M users + PE acquisition Jan 2026 = the Swiss consumer DOES pay a jurisdictional/privacy premium
- Cleo's trust posture (cloud-everything, Plaid-OK) would be a category error in CH

The proactive coaching paradox is solvable per the engineering expert: Path A doesn't kill server-side coaching for users who opt INTO cloud sync. Anonymous + opted-out users get on-device coaching only (acceptable degradation). Opted-in users get the full Cleo-equivalent experience.

## Decision (perfect compromise — logical, pragmatique, humain)

### v2.x (NOW — this week)
1. **Refactor `auth_provider.dart`** — keep `_isLocalMode = true` after register/login. No silent flip. Account = auth/identity only, NOT data sync.
2. **Add Settings › Confidentialité › Synchronisation cloud toggle** (default OFF). User explicitly enables → backend starts syncing.
3. **Update register screen ARB strings** — remove the contradiction. Subtitle aligned with reality. Benefit list mentions cloud sync as opt-in.
4. **Keep ALL the « tes données restent sur ton appareil » strings** in the rest of the app — they become **accurate again** once cloud sync is opt-in (not auto-on at register).

### Q3 2026 (3-4 month horizon)
5. **Migrate Railway → Swiss/EU region** (Exoscale, Infomaniak, or GCP europe-west6 Zürich). 2-3 weeks. Removes US-jurisdiction CLOUD Act exposure for opted-in users + unlocks future B2B distribution (banks/insurers under FINMA Circ. 2018/3 §A36-39 require Swiss-resident data).

### v3.0 (~12 month horizon, post-PMF)
6. **E2EE migration** — hybrid per-data-class pattern:
   - Chat history + profile + documents = Bitwarden-style zero-knowledge (master-password derived key, server stores opaque ciphertext)
   - Insights (coaching memories) = server-readable with explicit consent label, powers proactive nudges
   - Anonymized aggregates (canton, age band, archetype) = plaintext for cohort benchmarks
7. **Library:** `cryptography` 2.7.x + `cryptography_flutter` 2.3.4 (Argon2id KDF + AES-GCM, native acceleration)
8. **Recovery:** 24-word BIP39 phrase + Sign in with Apple/Google as secondary unwrap path (mandatory for 18-99 audience, password loss = data loss is unacceptable)

### Brand positioning (locked)
- **Tagline:** « Ta lucidité. Ton appareil. Ton choix de synchroniser. »
- **Subtitle defensible (post-Phase 2):** « Crée un compte pour synchroniser tes données entre tes appareils (chiffrées sur nos serveurs). Tu peux à tout moment revenir au mode 100 % local depuis Réglages › Confidentialité. »

## What we explicitly REJECT

- **Path B (caveat the lie):** Honest in letter, dishonest in spirit. Encodes the opposite of MINT's brand. Even with caveats, FDPIC salience test would fail. Voted against by 4/5 experts.
- **Premature E2EE before PMF:** 5-6 months of engineering that delivers 0 user value before launch + actively regresses proactive coaching. Defer to v3.0.
- **Apple PCC literal architecture:** $2M+ project, not feasible for current MINT stage.

## Tracking

- v2.x ARB string fix → PR #?? (this session)
- v2.x auth_provider refactor + settings toggle → Phase 52 (open in `.planning/phases/52-...` next)
- Q3 Swiss-region migration → backlog item v2.11 entry
- v3.0 E2EE → backlog v3.0 epic + ADR

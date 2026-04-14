# Project Research Summary

**Project:** MINT v2.5 Transformation
**Domain:** Swiss fintech education app — anonymous hook, premium conversion, behavioral commitment, couple mode, coach intelligence
**Researched:** 2026-04-12
**Confidence:** MEDIUM-HIGH

## Executive Summary

MINT v2.5 transforms working infrastructure (v2.4 fixed plumbing) into a product that hooks, converts, and retains users. The research converges on a clear architecture: an anonymous-first funnel (felt-state pill to premier eclairage in 20 seconds, no auth required), a generous free tier gated by convenience rather than information access, and five behavioral innovations from the expert audit that no competitor implements (implementation intentions, fresh-start anchors, pre-mortem, asymmetric couple mode, provenance journal). The existing stack is remarkably complete — only 3 pubspec changes are needed (RevenueCat replaces raw IAP, flutter_local_notifications upgrade), and zero backend dependencies change.

The recommended approach is a strict 6-phase build ordered by dependency chain: anonymous flow first (unblocks user acquisition), premium gate second (must exist before premium features ship), commitment devices third (foundation for the living timeline), coach provenance fourth (pure backend, enriches all subsequent coach interactions), couple mode fifth (requires provenance and commitment infrastructure), living timeline last (aggregates everything). This order is non-negotiable because each phase's output is a hard dependency for the next. The critical risk is repeating the v2.4 "facade without wiring" pattern — components that compile and pass unit tests but are never connected end-to-end. Every phase must end with a creator device walkthrough, not just green tests.

The biggest threats are: anonymous session orphaning on auth (conversation lost = trust destroyed), Apple App Store rejection for subscription implementation (weeks of delay), LSFin compliance breach via premium gate framing (criminal liability), and couple mode privacy leaks (nLPD violation). All are preventable with the mitigations documented in PITFALLS.md, but they require upfront decisions (RevenueCat vs raw IAP, free/premium line definition, partner data isolation model) made during Phase 1 planning, not mid-sprint.

## Key Findings

### Recommended Stack

The existing stack covers 95% of needs. Net changes: remove `in_app_purchase` + `in_app_purchase_platform_interface`, add `purchases_flutter: ^9.16.0` + `purchases_ui_flutter: ^9.16.0` (RevenueCat), upgrade `flutter_local_notifications` to `^19.0.0`. Zero backend dependency changes.

**Core additions:**
- **RevenueCat** (`purchases_flutter`): Cross-platform subscriptions (Apple + Google + Web) — replaces 158-line iOS-only IAP service with ~50-line unified service. Free up to $2,500/month MTR. Handles receipt validation, entitlement sync, paywall A/B testing.
- **flutter_local_notifications ^19.0.0**: Improved iOS exact scheduling reliability — needed for implementation intention reminders. Non-breaking upgrade from ^18.0.1.

**Explicitly NOT adding:** Redis (code is ready but single-instance Railway suffices), Firebase Cloud Messaging (local notifications cover commitment devices), WebSockets (couple mode is asymmetric), riverpod/bloc (Provider is established across 9000+ tests), any timeline library (custom widget matches tension-based UX).

### Expected Features

**Must have (table stakes):**
- Anonymous first interaction with premier eclairage in under 20 seconds
- Conversation transfer post-login (anonymous session merges to authenticated user)
- Clear free vs premium boundary (visible, generous, never gates critical information)
- Premium paywall via RevenueCat (iOS + Android + Web, 15 CHF/month)
- Profile data pre-fill from CoachProfile (never ask what MINT already knows)

**Should have (differentiators — from 5-expert audit):**
- Implementation intentions with WHEN/WHERE/IF-THEN follow-up (d=0.65 effect size, no competitor does this)
- Fresh-start anchors on personal landmarks (birthday, new job, anniversary — NOT streaks)
- Pre-mortem before irrevocable decisions (100% LSFin-compliant, zero competitors)
- Asymmetric couple mode (private questionnaire, one partner only — YNAB/Plenty/Zeta all require both)
- Provenance journal via coach conversation (tracks who recommended what, conversational not form-based)
- Implicit earmarking via coach listening (respects mental money separation, zero UI needed)

**Defer to v3.0+:**
- Full living timeline (tension-based home screen) — start with simplified "3 tensions" card
- Graduation Protocol (MINT teaches itself out of a job)
- Dossier Federation (portable open-format dossier)
- Political Pocket (collective action layer)

### Architecture Approach

Each feature integrates into the existing GoRouter/Provider/FastAPI architecture with minimal new components. The key architectural insight is SEPARATION: anonymous chat gets a separate endpoint (not a flag on authenticated), partner estimates live in CoachProfile (not HouseholdProvider), provenance is backend-only (never synced to Flutter), and premium gates use a single reusable `PremiumGateSheet` (not per-feature paywalls). The architecture adds ~7 new backend components (2 models, 2 services, 2 endpoints, 5 coach tools) and ~8 new Flutter components (1 screen, 3 providers, 3 widgets, 1 model).

**Major components:**
1. **Anonymous flow**: Separate `POST /api/v1/coach/anonymous` endpoint with reduced tools (READ only), `AnonymousChatScreen` without shell, session claim on auth
2. **Commitment devices**: `commitment_devices` table + 3 new coach tools (`set_implementation_intention`, `set_fresh_start_anchor`, `set_pre_mortem`) + `CommitmentDeviceProvider` for home screen surfacing
3. **Couple mode**: `PartnerEstimate` model in CoachProfile (not HouseholdProvider), `capture_partner_data` coach tool, couple-aware calculator wiring
4. **Coach provenance**: `provenance_tags` table, `save_provenance_tag` internal tool (backend-only, never forwarded to Flutter), injected into coach context window
5. **Premium gate**: Single `PremiumGateSheet` + `PremiumGateWrapper` components, RevenueCat as source of truth for mobile, Stripe for web
6. **Living timeline**: `tension_engine` backend service aggregating deadlines/commitments/stale data/profile gaps, `TimelineProvider` driving dynamic home screen cards

### Critical Pitfalls

1. **Facade without wiring (meta-pitfall)**: v2.4 had 32 instances of code that existed but was never connected. Prevention: E2E checklist per feature, grep for zero-import files, mandatory device walkthrough. Applies to ALL phases.
2. **Anonymous session orphaning**: User's first meaningful interaction vanishes on auth. Prevention: device-level `anon_session_id`, dedicated `POST /auth/claim-session` endpoint, atomic migration including RAG re-indexing.
3. **Apple App Store rejection**: Subscription implementation rejected for terms visibility, IAP routing, or AI feature explanation. Prevention: RevenueCat abstracts Apple/Google, terms visible before purchase button, AI explained in review notes.
4. **LSFin compliance breach via premium framing**: Marketing premium as "better advice" triggers FINMA (up to 3 years imprisonment). Prevention: premium gates tools/convenience, never advice quality. Banned copy: "meilleur conseil", "strategie optimale", "recommandations personnalisees".
5. **Couple mode privacy leak**: Partner A's answers visible to Partner B (nLPD violation). Prevention: data belongs to entering user only, CoachContext never includes raw partner data, ComplianceGuard flags partner-specific reveals.

## Implications for Roadmap

### Phase 1: Anonymous Hook and Auth Bridge
**Rationale:** This is the user acquisition funnel. Without it, nobody tries MINT. Every subsequent feature depends on having users.
**Delivers:** Anonymous backend endpoint (3-turn limit), `AnonymousChatScreen`, `RouteScope.anonymous`, conversation claim on auth, premier eclairage in under 20 seconds.
**Addresses:** Anonymous first interaction (table stakes), conversation transfer (table stakes)
**Avoids:** Session orphaning (Pitfall 2), rate limiting killing the hook (Pitfall 9), conversation context lost post-auth (Pitfall 10)
**Decision required:** Free/premium line definition (impacts all subsequent phases)

### Phase 2: Premium Gate
**Rationale:** Must exist before shipping any premium features (commitment devices, couple mode). Also: App Store Connect product setup takes 24-48h, so start early.
**Delivers:** `PremiumGateSheet` + `PremiumGateWrapper`, RevenueCat integration (replace raw IAP), `FreeTrialBanner`, gates wired on existing screens.
**Addresses:** Clear free vs premium line (table stakes), premium paywall (table stakes)
**Avoids:** App Store rejection (Pitfall 3), webhook race conditions (Pitfall 4), LSFin framing violation (Pitfall 6), emergency info blocked (Pitfall 16), dual billing conflict (Pitfall 11)
**Uses:** RevenueCat (`purchases_flutter: ^9.16.0`)

### Phase 3: Commitment Devices
**Rationale:** Foundation for the living timeline. Coach needs WRITE tools before the home screen can show commitment-driven tension cards. Also: the behavioral moat — no competitor does this.
**Delivers:** `commitment_devices` table + migration, 3 new coach tools, `CommitmentDeviceProvider`, commitment cards on home screen, `flutter_local_notifications ^19.0.0` upgrade.
**Addresses:** Implementation intentions (differentiator), fresh-start anchors (differentiator), pre-mortem (differentiator)
**Avoids:** Notification permission fatigue (Pitfall 7), implementation intentions not persisted (Pitfall 12), fresh-start timezone bugs (Pitfall 13), pre-mortem anxiety (Pitfall 14)

### Phase 4: Coach Provenance and Relational Intelligence
**Rationale:** Pure backend work with zero Flutter changes. Once deployed, the coach immediately starts capturing provenance and earmarks in every conversation. Must exist before couple mode (partner's money tagging benefits from provenance).
**Delivers:** `provenance_tags` table, `save_provenance_tag` internal tool, `coach_context_builder` injection, implicit earmarking via coach listening.
**Addresses:** Provenance journal (differentiator), implicit earmarking (differentiator)
**Avoids:** Provenance feeling like interrogation (Pitfall 15)

### Phase 5: Couple Mode Dissymetrique
**Rationale:** Requires provenance infrastructure (Phase 4) and commitment devices (Phase 3) to deliver the full couple experience. Also needs premium gate (Phase 2) since couple mode is a premium feature.
**Delivers:** `PartnerEstimate` model, `CoupleProjectionService`, `capture_partner_data` coach tool, couple-aware AVS/LPP/tax calculations, "5 questions to ask your partner" output.
**Addresses:** Asymmetric couple mode (differentiator)
**Avoids:** Partner data isolation failure (Pitfall 5)

### Phase 6: Living Timeline (Simplified)
**Rationale:** Aggregates ALL previous features — commitment cards, stale data, trial status, profile gaps. Must come last because it renders outputs from every other phase.
**Delivers:** `tension_engine` backend, `tensions` endpoint, `TimelineProvider`, `TensionCard` widgets, refactored `LandingScreen` driven by dynamic tension list.
**Addresses:** Tension-based home screen direction (simplified "3 tensions" card, not full timeline)
**Avoids:** Performance death on older devices (Pitfall 8), static widget list anti-pattern

### Phase Ordering Rationale

- **Dependency-driven**: Each phase's output is consumed by subsequent phases. Anonymous flow produces users, premium gate classifies them, commitment devices create actionable data, provenance enriches context, couple mode uses all of the above, timeline renders everything.
- **Risk front-loading**: The two highest-risk phases (anonymous flow with session migration, premium gate with Apple review) come first. If either fails, discovery happens early, not at the end.
- **Value delivery**: Phase 1 alone delivers a testable anonymous hook. Phase 1+2 delivers a monetizable product. Phase 1+2+3 delivers the behavioral moat. Each phase is independently valuable.
- **One-person team constraint**: Phases are sized at 2-4 days each (estimated 15-20 days total). Each phase has a clear "done" signal that can be device-tested.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1 (Anonymous flow):** Session migration edge cases, RAG re-indexing strategy, rate limit tuning — needs `/gsd-research-phase`
- **Phase 2 (Premium gate):** RevenueCat integration specifics, App Store Connect setup, entitlement sync with existing billing_service — needs `/gsd-research-phase`
- **Phase 5 (Couple mode):** Partner data model design, couple calculator wiring, dissymmetric vs symmetric data boundary — needs `/gsd-research-phase`

Phases with standard patterns (skip research-phase):
- **Phase 3 (Commitment devices):** Well-documented SQLAlchemy model + coach tool pattern, notification scheduling is established
- **Phase 4 (Coach provenance):** Pure backend, follows existing internal tool pattern exactly
- **Phase 6 (Living timeline):** Provider + widget pattern, tension engine is a standard priority-sorted query

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Existing stack nearly complete. RevenueCat is industry standard. Changes are minimal and well-documented. |
| Features | MEDIUM | Feature list is strong but no direct Swiss fintech education precedent exists. Competitor patterns are extrapolated from adjacent domains (Cleo, YNAB, Headspace). |
| Architecture | HIGH | Every integration point verified against actual codebase. Component boundaries are clear. Build order is dependency-driven. |
| Pitfalls | HIGH | Codebase-verified (v2.4 audit findings are direct evidence). Regulatory pitfalls confirmed against statutory law (LSFin, nLPD). |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Conversion rate benchmarks**: No data on what anonymous-to-auth conversion rate to expect for a Swiss fintech education app. Will need to instrument and measure in Phase 1.
- **RevenueCat migration path**: Existing `ios_iap_service.dart` has 158 lines of StoreKit ceremony. Migration to RevenueCat needs careful testing to ensure no existing Apple sandbox accounts are disrupted.
- **Couple mode data model**: The boundary between `CoachProfile.partnerEstimate` (dissymmetric) and `HouseholdProvider` (symmetric Couple+ tier) needs an ADR before implementation.
- **Tension scoring algorithm**: How to rank and order tensions on the home screen (urgency vs importance vs recency) is not yet defined. Needs design during Phase 6 planning.
- **Premium pricing validation**: 15 CHF/month is assumed but untested. RevenueCat's paywall A/B testing should be used to validate before hard-committing.

## Sources

### Primary (HIGH confidence)
- Codebase analysis: `app.dart`, `auth.py`, `coach_chat.py`, `billing.py`, `ios_iap_service.dart`, `notification_service.dart`, `subscription_service.dart` — direct code verification
- `.planning/architecture/13-AUDIT.md` — 5-expert audit (game designer, screenwriter, behavioral economist, sociologist, philosopher)
- `.planning/architecture/14-INFRA-AUDIT-FINDINGS.md` — v2.4 infrastructure audit (32 findings)
- LSFin art. 44, nLPD — Swiss statutory law
- [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

### Secondary (MEDIUM confidence)
- [RevenueCat State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps/) — conversion benchmarks
- [purchases_flutter on pub.dev](https://pub.dev/packages/purchases_flutter) — v9.16.1
- [flutter_local_notifications on pub.dev](https://pub.dev/packages/flutter_local_notifications) — v19.5.0
- [Gollwitzer 1999 implementation intentions meta-analysis](https://pubsonline.informs.org/doi/10.1287/mnsc.2014.1901) — d=0.65
- [Dai/Milkman/Riis 2014 Fresh Start Effect](https://pubsonline.informs.org/doi/10.1287/mnsc.2014.1901) — temporal landmarks
- [Klein 2007 Pre-mortem](https://www.researchgate.net/publication/3229642_Performing_a_Project_Premortem)
- Competitor analysis: Cleo, YNAB, Wealthfront, Headspace, Plenty, stickK/Beeminder

### Tertiary (LOW confidence)
- Premium pricing (15 CHF/month) — untested assumption, needs A/B validation
- Anonymous-to-auth conversion rate expectations — no Swiss fintech education precedent

---
*Research completed: 2026-04-12*
*Ready for roadmap: yes*

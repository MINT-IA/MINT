# Domain Pitfalls — v2.5 Transformation

**Domain:** Adding anonymous flow, premium conversion, couple mode, commitment devices, coach intelligence, and living timeline to an existing Swiss fintech Flutter+FastAPI app recovering from a "facade without wiring" state.
**Researched:** 2026-04-12
**Overall confidence:** HIGH (codebase-verified + industry-confirmed patterns)

---

## Critical Pitfalls

Mistakes that cause rewrites, data loss, App Store rejection, or compliance violations.

### Pitfall 1: Facade Without Wiring — Again

**What goes wrong:** The v2.4 audit found 32 instances of code that existed but was never connected (ProfileDrawer built, 0 imports; tool calling coded, camelCase mismatch killed it). The v2.5 features are MORE complex (anonymous sessions, webhook handlers, couple sync). The same pattern repeats: each feature looks done in isolation but the joints between them are dead.

**Why it happens:** Agent-driven development builds components in isolation. Each agent produces a service file that compiles and passes unit tests. Nobody verifies the full data path: anonymous session created on backend -> conversation stored -> user authenticates -> conversation transferred -> entitlements checked -> premium gate applied. Each step works alone; the chain is never tested end-to-end.

**Consequences:** Ship date: "done." Creator opens on iPhone: anonymous conversation vanishes after login, premium gate shows free content as locked, couple questionnaire saves locally but never syncs to dossier.

**Prevention:**
- After each feature, write a 5-step E2E checklist tracing data from creation to consumption.
- The v2.4 lesson: grep for zero-import files after every sprint (`grep -rL "import.*MyNewService" lib/`).
- Device gate is non-negotiable: creator walks the flow cold-start on iPhone before marking done.
- Every new service MUST have at least 1 integration test that crosses the Flutter-backend boundary.

**Detection:** Any service file with 0 imports outside its own test. Any backend endpoint with 0 Flutter callers. Any webhook handler never triggered in staging.

**Phase:** ALL phases. This is the meta-pitfall.

---

### Pitfall 2: Anonymous Session Orphaning

**What goes wrong:** User opens MINT anonymously, has a meaningful conversation, decides to create an account. The anonymous session data (conversation history, any profile data collected via chat) is lost because the authentication flow creates a new user record with no link to the anonymous session.

**Why it happens:** The current auth system (`auth.py`) returns `None` for unauthenticated requests. There is no concept of an anonymous session ID that persists across the auth boundary. If you create anonymous sessions with a temporary ID (UUID in localStorage/SecureStorage) and authenticated sessions with a user_id (JWT), the two identifiers live in different namespaces with no migration path.

**Consequences:** The user's first meaningful interaction with MINT vanishes. This is the WORST possible onboarding failure for a product whose entire pitch is "your first conversation surprises you, you create an account to not lose it."

**Prevention:**
- Generate a device-level `anon_session_id` on first launch, stored in SecureStorage.
- On signup/login, call a dedicated `POST /auth/claim-session` endpoint that migrates all data from `anon_session_id` to the new `user_id`.
- The claim must be atomic: conversation history, any collected profile fields, any documents scanned.
- Backend must handle the case where claim is called twice (idempotent) or where the anonymous session has already been claimed by another account (reject with clear error).
- Rate-limit anonymous endpoints aggressively (3-5 conversations/day per device fingerprint) to prevent abuse without killing the hook.

**Detection:** Test with real flow: open app -> have 2 conversations -> sign up -> verify conversations appear in authenticated history. If they do not, the pipe is broken.

**Phase:** Phase 1 (Anonymous flow). Must be solved first because ALL subsequent features depend on it.

---

### Pitfall 3: Apple App Store Rejection for Subscription Implementation

**What goes wrong:** Apple rejects the app because: (a) the free tier offers "too much" and Apple sees no reason for the subscription, or (b) the free tier offers "too little" and Apple sees it as a paywall for basic functionality, or (c) subscription terms/cancellation policy is not displayed before purchase, or (d) the app uses external payment (Stripe web) without also offering Apple IAP on iOS.

**Why it happens:** Apple's Guideline 3.1.1 requires ALL digital content/feature unlocking to go through Apple IAP on iOS. The existing codebase has BOTH Stripe endpoints (`billing.py`) AND Apple IAP (`ios_iap_service.dart`). If the premium gate routes iOS users to Stripe instead of Apple IAP, Apple will reject. If AI-powered features (coach chat) require explaining clearly how AI works (2025 App Store guideline update), vague descriptions trigger rejection.

**Consequences:** Weeks of back-and-forth with App Review. Launch delayed. Possibly forced to restructure the entire premium/free boundary.

**Prevention:**
- iOS: Apple IAP only (via `IosIapService` already scaffolded). Stripe for web/Android only.
- RevenueCat as the abstraction layer to unify both payment rails into a single entitlement check.
- Before submission: screenshot every paywall screen, ensure pricing/renewal/cancellation terms are visible BEFORE the purchase button.
- Clearly explain AI features in App Review notes: "AI-powered financial education coach using Claude API, no personalized financial advice."
- The free/premium line must be defensible: free = enough value to understand MINT's purpose (anonymous conversations, premier eclairage). Premium = depth (full dossier, couple mode, implementation intentions, unlimited coach).
- Test on physical iOS device with sandbox Apple ID. Emulator IAP testing is insufficient.

**Detection:** Submit a test build to TestFlight with IAP configured. Apple provides sandbox testing environment. If `IosIapService.fetchProducts()` returns empty, product IDs are misconfigured in App Store Connect.

**Phase:** Phase 4 (Premium gate). But App Store Connect product setup should start in Phase 1 (takes 24-48h for Apple to approve product metadata).

---

### Pitfall 4: Webhook Race Conditions and Subscription State Corruption

**What goes wrong:** User subscribes via Apple IAP. The `activateApplePurchase` backend call succeeds and grants entitlements. Minutes later, Apple sends a Server Notification (via webhook) for the same transaction. The webhook handler creates a duplicate subscription record or overwrites the already-correct state. Alternatively: webhook arrives BEFORE the client-side verification call (out-of-order delivery), and the user has no record yet, so the webhook is silently dropped.

**Why it happens:** Webhooks are asynchronous and unreliable. They arrive out of order, can be duplicated, and have no guaranteed delivery time. The existing `billing.py` has both `POST /billing/apple/verify` (client-initiated) and `POST /billing/apple/webhook` (server notification) but they may not share the same idempotency logic.

**Consequences:** User pays but does not get premium. Or user gets premium twice (double-counted revenue). Or subscription renewal fails silently and user loses access mid-session.

**Prevention:**
- Every subscription operation must be idempotent: keyed on `original_transaction_id` (Apple) or `subscription_id` (Stripe).
- Use RevenueCat as the single source of truth for entitlement state. Query RevenueCat server-side before granting/revoking.
- Webhook handler must respond within 5 seconds (Apple requirement) and defer heavy processing to a background task.
- Log every webhook event with timestamp and transaction ID for debugging.
- Handle the "webhook arrives first" case: create a pending subscription record that the client verify call later confirms.

**Detection:** In staging, trigger a subscription, then immediately check `/billing/entitlements`. If entitlements are empty, the client-verify -> entitlement pipeline is broken. Check webhook logs for any events with "user not found" errors.

**Phase:** Phase 4 (Premium gate).

---

### Pitfall 5: Couple Mode Data Isolation Failure (Privacy Breach)

**What goes wrong:** Partner A fills the "what I know about my partner" questionnaire. The data is stored in a way that Partner B (if they also use MINT) can see Partner A's answers about them. Or worse: Partner A's financial data leaks into Partner B's dossier through shared coach context.

**Why it happens:** The couple mode is "dissymmetric" by design — only ONE partner uses MINT. But the data model might not enforce this. If a future feature adds "invite your partner," the assumption of single-user-per-couple breaks. Also: coach context injection might include couple data in prompts sent to Claude, and if the prompt is not carefully scoped, Claude might reveal "your partner said they don't know your salary" to the wrong person.

**Consequences:** Privacy violation. In Swiss law (nLPD, the new Federal Act on Data Protection effective since 2023), sharing personal financial data between individuals without explicit consent is a violation. Trust destruction for the product.

**Prevention:**
- Couple data belongs to the USER who entered it, never to "the couple."
- `CoachContext` must NEVER include raw partner data — only derived insights ("you mentioned uncertainty about shared expenses").
- If couple mode ever becomes bidirectional, each partner's data lives in their own dossier with explicit consent-gated sharing.
- The couple questionnaire output should be: questions for the user to ASK their partner in real life, not data MINT stores about the partner.
- ComplianceGuard must flag any coach response that reveals specifics about a partner's finances.

**Detection:** Review every `CoachContext` builder to verify no partner-attributed financial data is included. Grep for any database field that stores "partner_salary", "partner_3a", etc. — these should be `user_estimate_of_partner_X`, clearly attributed.

**Phase:** Phase 3 (Couple mode).

---

### Pitfall 6: LSFin/FINMA Compliance Breach via Premium Gate Framing

**What goes wrong:** The premium tier is marketed as providing "better financial advice" or "personalized recommendations" or "optimized strategy." Any of these framings turns MINT from an educational tool into a financial advisory service, which requires a FINMA license under LSFin (Loi sur les services financiers).

**Why it happens:** The natural instinct when selling premium is to promise MORE — more insight, more personalization, more optimization. But in Swiss fintech compliance, "more personalization" = closer to advice = regulatory trigger. The premium/free line is an emotional marketing decision that has regulatory consequences.

**Consequences:** FINMA investigation. Cease and desist. Criminal liability for the founder (LSFin art. 44: up to 3 years imprisonment for unlicensed financial services).

**Prevention:**
- Premium framing must be about DEPTH OF EDUCATION and CONVENIENCE, never about advice quality.
- Free: "MINT te montre ton premier eclairage." Premium: "MINT construit ton dossier complet, te rappelle tes intentions, et suit ta vie financiere dans le temps."
- Banned premium copy: "meilleur conseil", "strategie optimale", "recommandations personnalisees", "plan financier sur mesure."
- Allowed premium copy: "dossier illimite", "suivi dans le temps", "rappels d'intentions", "mode couple", "historique complet."
- Every paywall screen must include the educational disclaimer.
- The premium gate must never gate ACCESS TO INFORMATION (that looks like selling advice). It gates TOOLS FOR ORGANIZATION (dossier, reminders, couple, timeline).
- ComplianceGuard must run on all paywall/marketing copy, not just coach responses.

**Detection:** Have a non-team-member read every paywall screen and describe what they think MINT sells. If they say "financial advice" or "investment recommendations," the framing is wrong.

**Phase:** Phase 4 (Premium gate). But the free/premium line definition must be validated in Phase 1 planning.

---

## Moderate Pitfalls

### Pitfall 7: Notification Permission Fatigue and iOS Restrictions

**What goes wrong:** MINT asks for notification permissions too early (onboarding), user denies, and implementation intentions (commitment devices) become useless because they rely on scheduled local notifications to remind users of their WHEN/WHERE/IF-THEN commitments.

**Why it happens:** iOS asks for notification permission ONCE. If denied, the user must go to Settings to re-enable. The existing `notification_service.dart` uses `flutter_local_notifications` with local scheduling. On Android 13+, `POST_NOTIFICATIONS` permission is required at runtime. On Android 14+, exact alarms require `SCHEDULE_EXACT_ALARM` permission.

**Consequences:** The behavioral economist's #1 innovation (implementation intentions, d=0.65 effect size) is silently disabled for 40-60% of users who deny notifications. The app never tells the user their commitment device is broken.

**Prevention:**
- NEVER ask for notification permission during onboarding. Ask at the MOMENT the user creates their first implementation intention: "Tu veux que MINT te rappelle? Autorise les notifications."
- If permission is denied, degrade gracefully: show in-app reminders on next open instead of push notifications.
- On iOS, use `UNUserNotificationCenter` provisional authorization first (delivers quietly to Notification Center without the permission popup), then upgrade to full authorization when the user explicitly asks for reminders.
- Store notification permission state in the user profile and surface it in coach context so the coach can say "tu avais prevu de poser cette question a ton courtier — tu veux que je te rappelle?" without assuming notifications work.

**Detection:** Check `notification_service.dart` for permission request timing. If it is called in `main.dart` or during onboarding, it is too early.

**Phase:** Phase 2 (Commitment devices).

---

### Pitfall 8: Animated Timeline Performance Death on Older Devices

**What goes wrong:** The living timeline (tension-based home screen with past/present/future nodes, animated pulsing, ghosted projections) works beautifully on iPhone 15 Pro but drops to 15fps on iPhone SE 2020 or mid-range Android devices. The timeline uses `CustomPainter` with complex paths, `AnimationController` ticking at 60fps, and a `ListView` of variable-height nodes.

**Why it happens:** `CustomPainter.shouldRepaint()` returns true on every animation tick, causing full repaint of the entire timeline. Each node has its own animation (pulse, fade, shimmer), and AnimatedBuilder wraps the entire subtree instead of just the animating element.

**Consequences:** The home screen — the FIRST thing authenticated users see — feels broken. Battery drain. Users associate MINT with "slow app."

**Prevention:**
- `RepaintBoundary` around each timeline node to isolate repaints.
- `shouldRepaint()` must compare actual state, not return `true`.
- Use `AnimatedBuilder` wrapping ONLY the animated child, not the parent tree.
- Limit concurrent animations: only the "current tension" node pulses. Past and future nodes are static until scrolled into view.
- Profile with `flutter run --profile` on the OLDEST supported device (iPhone SE 2020 or equivalent Android).
- Set a performance budget: 60fps on iPhone SE, 30fps minimum on 2019 Android mid-range.
- Consider using `Rive` or `Lottie` for complex animations instead of `CustomPainter` — they are GPU-optimized and easier to profile.

**Detection:** Run `flutter run --profile` and open the Performance Overlay. If the raster thread exceeds 16ms per frame on the home screen, the timeline needs optimization.

**Phase:** Phase 5 (Living timeline).

---

### Pitfall 9: Anonymous Rate Limiting That Kills the Hook

**What goes wrong:** Rate limiting is set too aggressively (1 conversation/day) to prevent abuse, and the anonymous user never gets enough value to convert. Or rate limiting is set too loosely (unlimited), and bots/scrapers drain the Claude API budget.

**Why it happens:** The tension between "give enough value to hook" and "don't hemorrhage API costs on non-converting anonymous users." The existing backend has rate limiting (`rate_limit.py`) but it is per-authenticated-user. Anonymous rate limiting needs a different key (device fingerprint, IP, or session token).

**Consequences:** Too tight: conversion rate is 0% because nobody experiences enough to care. Too loose: $500/day Claude API bill from a single bot.

**Prevention:**
- Rate limit by device fingerprint (sent as header), not IP (shared in offices/VPNs).
- Tier: 3 free coach exchanges per session, 1 session per device per day. After limit: "Cree ton compte pour continuer cette conversation."
- The rate limit response must feel like a natural stopping point, not a wall: "Tu as decouvert ton premier eclairage. Pour aller plus loin, cree un compte — c'est gratuit."
- Backend: separate rate limit bucket for anonymous endpoints. Do NOT share with authenticated rate limits.
- Monitor: track anonymous-to-auth conversion rate by rate limit cohort. If conversion drops below 5%, the limit is too tight.

**Detection:** After launch, check analytics: what % of anonymous sessions hit the rate limit? What % of those convert? If >80% hit limit and <5% convert, the hook is failing.

**Phase:** Phase 1 (Anonymous flow).

---

### Pitfall 10: Conversation Transfer Loses Context Window

**What goes wrong:** User has 3 anonymous conversations. They sign up. The conversation history is migrated to their account (Pitfall 2 avoided). But the coach does not have access to the anonymous conversation context in its next interaction — the RAG/memory system only indexes post-authentication conversations.

**Why it happens:** The coach's `context_injector_service` builds context from the user's dossier and `conversation_memory_service`. If the migration only copies conversation records to a new user_id but does not re-index them in ChromaDB/RAG, the coach has no memory of the anonymous interactions.

**Consequences:** User: "On avait parle de mon 3a." Coach: "Je n'ai pas cette information." Trust destroyed in the first authenticated interaction.

**Prevention:**
- The session claim endpoint must trigger re-indexing of all migrated conversations into the user's RAG corpus.
- The coach system prompt must include a "conversation continuity" signal: "L'utilisateur vient de creer un compte. Voici le resume de ses conversations precedentes: [summary]."
- Test explicitly: anonymous conversation mentions salary -> sign up -> ask coach "quel est mon salaire?" -> coach must know.

**Detection:** Integration test crossing the auth boundary with conversation context verification.

**Phase:** Phase 1 (Anonymous flow).

---

### Pitfall 11: RevenueCat + Existing Billing Service Conflict

**What goes wrong:** The codebase already has `billing_service.py` with Stripe checkout, Apple verify, webhook handlers, and entitlement logic. Adding RevenueCat creates two competing sources of truth for subscription state: RevenueCat's server and the local `billing` database table.

**Why it happens:** RevenueCat is designed to BE the source of truth. But the existing billing service already manages subscriptions in PostgreSQL. If both systems are active, they will diverge: RevenueCat says "active," local DB says "expired" (or vice versa) because webhook processing has a race condition.

**Consequences:** User has premium on one check, loses it on the next. Support nightmare. Revenue reporting is wrong.

**Prevention:**
- Choose ONE source of truth. Recommendation: RevenueCat for mobile IAP (Apple/Google), Stripe direct for web.
- Local DB stores a CACHE of entitlements, refreshed from RevenueCat on each app launch and on webhook events. Never trust the local cache for gating decisions — always verify with RevenueCat server-side for critical gates.
- OR: skip RevenueCat entirely. The existing `IosIapService` + `billing_service.py` already handle Apple IAP. RevenueCat adds complexity for a one-person team. Use RevenueCat only if you need Google Play Billing (Android) or cross-platform subscription management.
- If keeping both: clearly document which system is authoritative for which platform.

**Detection:** After implementing, subscribe on iOS, then check `/billing/entitlements` on backend. If the response does not reflect the subscription, the sync is broken.

**Phase:** Phase 4 (Premium gate). Decision should be made in Phase 1 planning.

---

## Minor Pitfalls

### Pitfall 12: Implementation Intentions Without Persistence Strategy

**What goes wrong:** Implementation intentions (WHEN/WHERE/IF-THEN) are created via coach conversation but stored only in the conversation memory, not in a dedicated data structure. There is no way to list, edit, or delete them. The notification scheduler cannot find them to schedule reminders.

**Prevention:** Create a first-class `ImplementationIntention` model (backend + Flutter) with fields: trigger_context, action, reminder_datetime, status (pending/completed/expired), linked_conversation_id. The coach creates them; a dedicated service manages their lifecycle.

**Phase:** Phase 2 (Commitment devices).

---

### Pitfall 13: Fresh-Start Anchors Firing on Wrong Dates

**What goes wrong:** Fresh-start anchors (birthday, new year, month-1 of MINT usage) fire based on UTC dates but the user is in Switzerland (CET/CEST, UTC+1/+2). A birthday notification fires at 11pm the day before.

**Prevention:** All date calculations for fresh-start anchors must use the user's timezone (stored in profile or inferred from canton). The existing `notification_scheduler_service.dart` already uses `timezone` package — ensure fresh-start logic uses the same timezone-aware scheduling.

**Phase:** Phase 2 (Commitment devices).

---

### Pitfall 14: Pre-Mortem Prompt Triggering Anxiety

**What goes wrong:** The pre-mortem ("Imagine qu'on est en 2027 et que cette decision s'est mal passee") is a powerful cognitive tool but in the hands of a fintech coach serving users who already feel financial shame, it can amplify anxiety instead of building lucidity.

**Prevention:** Frame as curiosity, not fear: "Si tu regardais cette decision dans un an et qu'elle n'avait pas marche — qu'est-ce qui aurait pu se passer?" Follow immediately with a hope frame: "Et si elle avait tres bien marche — qu'est-ce qui aurait change?" Store both. The pre-mortem is a pair (fear + hope), never fear alone. ComplianceGuard must flag pre-mortem prompts that use banned anxiety terms.

**Phase:** Phase 2 (Commitment devices).

---

### Pitfall 15: Coach Provenance Questions Feeling Like Interrogation

**What goes wrong:** The coach asks "Au fait, ce 3a, c'est qui qui te l'a propose?" and the user feels judged or surveilled. The provenance journal (tracking who recommended what financial product) is valuable for the dossier but the questioning must feel natural, not like a compliance interview.

**Prevention:** Provenance questions should be triggered by context (user mentions a product) not by schedule. The coach should ask ONCE, accept any answer (including "je sais plus"), and never follow up aggressively. Store the provenance tag with low confidence if the user is vague. Never display provenance data as an accusation ("ton courtier t'a vendu ca").

**Phase:** Phase 3 (Coach intelligence).

---

### Pitfall 16: Premium Gate Blocking Emergency Information

**What goes wrong:** A user in a debt crisis hits the premium gate when trying to access information that could help them. The gate feels like MINT is monetizing their distress.

**Prevention:** Debt crisis (`debtCrisis` life event) and disability (`disability`) must NEVER be gated behind premium. The safe mode (disable optimizations, priority = debt reduction) must be accessible to all users. Premium gates tools for planning and organization, NEVER access to critical financial safety information. This is both ethical and compliant with Swiss consumer protection law.

**Phase:** Phase 4 (Premium gate).

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Phase 1: Anonymous flow | Session orphaning on auth (Pitfall 2) | Dedicated claim endpoint, atomic migration, E2E test |
| Phase 1: Anonymous flow | Rate limiting kills hook (Pitfall 9) | Device fingerprint, 3 exchanges/session, soft wall copy |
| Phase 1: Anonymous flow | Conversation context lost post-auth (Pitfall 10) | Re-index migrated conversations in RAG |
| Phase 2: Commitment devices | Notification permission too early (Pitfall 7) | Ask at intention creation, not onboarding |
| Phase 2: Commitment devices | Implementation intentions not persisted (Pitfall 12) | First-class data model, not just conversation text |
| Phase 2: Commitment devices | Fresh-start timezone bugs (Pitfall 13) | Use user timezone from profile/canton |
| Phase 2: Commitment devices | Pre-mortem causes anxiety (Pitfall 14) | Pair fear + hope frames, ComplianceGuard check |
| Phase 3: Couple mode | Partner data leak (Pitfall 5) | Data belongs to entering user, CoachContext scoped |
| Phase 3: Coach intelligence | Provenance feels interrogatory (Pitfall 15) | Context-triggered, accept vague answers |
| Phase 4: Premium gate | App Store rejection (Pitfall 3) | Apple IAP on iOS, Stripe on web, terms visible |
| Phase 4: Premium gate | Webhook race conditions (Pitfall 4) | Idempotent on transaction ID, RevenueCat as source |
| Phase 4: Premium gate | LSFin framing violation (Pitfall 6) | Gate tools/convenience, never advice quality |
| Phase 4: Premium gate | Emergency info blocked (Pitfall 16) | Debt/disability never gated |
| Phase 4: Premium gate | Dual billing system conflict (Pitfall 11) | Single source of truth decision upfront |
| Phase 5: Living timeline | Performance on old devices (Pitfall 8) | RepaintBoundary, profile on iPhone SE |
| ALL phases | Facade without wiring (Pitfall 1) | E2E checklist, grep for 0-import files, device gate |

---

## The One-Person Team Meta-Pitfall

All 16 pitfalls above are compounded by the constraint that MINT is built by one person with AI agents. The specific risks:

1. **Scope creep per phase:** Each phase above has 3-5 pitfalls. A one-person team cannot address all simultaneously. Prioritize: for each phase, identify the ONE critical pitfall and solve it first. The others are mitigations, not blockers.

2. **Testing debt:** Writing E2E integration tests for anonymous->auth->premium->couple is expensive. But skipping them repeats v2.4 (9256 tests green, app broken). Budget 30% of each phase for integration tests that cross boundaries.

3. **Decision fatigue:** RevenueCat vs direct IAP, anonymous session strategy, free/premium line — each is a decision with downstream consequences. Make these decisions in Phase 1 planning, not during implementation. Document in ADRs. Do not revisit mid-sprint.

4. **The "almost done" trap:** Each feature (anonymous flow, couple mode, timeline) can be 80% done in 2 days and require 2 weeks for the remaining 20% (edge cases, error handling, timezone bugs, permission flows). Budget for the 20%, not the 80%.

---

## Sources

- Codebase analysis: `services/backend/app/api/v1/endpoints/billing.py`, `apps/mobile/lib/services/ios_iap_service.dart`, `services/backend/app/core/auth.py`, `apps/mobile/lib/services/notification_service.dart`
- [RevenueCat Flutter docs](https://www.revenuecat.com/docs/getting-started/installation/flutter) — HIGH confidence
- [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — HIGH confidence
- [RevenueCat webhook best practices](https://community.revenuecat.com/general-questions-7/best-practices-on-handling-webhooks-5054) — MEDIUM confidence
- [Flutter local notifications issues](https://github.com/MaikuB/flutter_local_notifications/issues/2737) — MEDIUM confidence
- [App Store Review Guidelines 2026 checklist](https://adapty.io/blog/how-to-pass-app-store-review/) — MEDIUM confidence
- `.planning/architecture/13-AUDIT.md` — 5 expert audit findings (direct codebase source)
- `.planning/architecture/14-INFRA-AUDIT-FINDINGS.md` — v2.4 infrastructure findings (direct codebase source)
- LSFin art. 44 — Swiss Financial Services Act penalties (HIGH confidence, statutory law)

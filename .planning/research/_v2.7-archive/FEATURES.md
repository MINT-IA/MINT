# Feature Landscape — MINT v2.5 Transformation

**Domain:** Anonymous hook, premium conversion, behavioral commitment, couple mode, coach intelligence — Swiss fintech education app
**Researched:** 2026-04-12
**Scope:** Transforming working infrastructure into a product that hooks, converts, and retains
**Confidence:** MEDIUM — patterns drawn from competitor analysis (Cleo, YNAB, Wealthfront, Headspace, Plenty, stickK/Beeminder) + behavioral economics literature + RevenueCat benchmarks. No direct Swiss fintech education precedent exists.

---

## Table Stakes

Features users expect. Missing = product feels incomplete or amateurish.

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| **Anonymous first interaction** | Every modern app lets you try before signup. Cleo, Headspace, Wealthfront all deliver value before auth. 55% of 3-day trial cancellations happen Day 0 — if no aha moment in 60 minutes, user is gone. | **Medium** | Backend anonymous endpoint, rate limiting, session token | Must deliver premier eclairage within 20 seconds of first tap. One felt-state pill -> one personalized insight. No bank connection, no form. |
| **Conversation transfer post-login** | Users who chat anonymously expect their conversation to persist after creating an account. Losing context = losing trust. Standard pattern in Intercom, Cleo, Drift. | **Medium** | Anonymous session ID -> user ID migration, conversation_memory_service | Backend must merge anonymous session into authenticated user. Critical: if this breaks, user feels "MINT forgot me." |
| **Clear free vs premium line** | Every freemium app makes the boundary visible. Users who hit invisible walls feel tricked. Cleo: free budgeting, paid cash advances. YNAB: 34-day trial, then paid. Headspace: free basics, paid library. | **Low** | Feature flag system per user tier | Free = first premier eclairage + limited coach exchanges (3-5/day). Premium = unlimited coach, full dossier, commitment devices, couple mode. Line must feel generous, not stingy. |
| **Premium paywall (RevenueCat/Stripe)** | 15 CHF/month needs a payment system. RevenueCat handles Apple/Google subscriptions + Stripe for web. Not building payment infra from scratch is table stakes for a solo dev. | **Medium** | RevenueCat SDK (Flutter), Stripe backend integration, entitlement checks | RevenueCat paywalls are now remotely configurable. Apple rejects free trial toggles on paywalls as of Feb 2026. Hard paywalls convert 5x better than freemium on Day 35 (10.7% vs 2.1%) but freemium fits MINT better (word of mouth, education mission). |
| **Basic auth flow (existing)** | Magic link + Apple Sign-In already built. Must work reliably as the gate between anonymous and authenticated. | **Low** (exists) | Auth service, SecureStorage | Already validated. Just needs to be the smooth bridge, not a wall. |
| **Profile data pre-fill** | Every screen must pre-fill ALL known data from CoachProfile. Never ask what MINT already knows. Users expect apps to remember. | **Low** | CoachProfile, SimulatorParams.resolve() | Architectural principle already established. Enforce it across new features. |

---

## Differentiators

Features that set MINT apart. Not expected by users, but create the "wow" that drives retention and word-of-mouth. These come from the 5-expert audit.

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| **Implementation intentions (Layer 4 primitive)** | No fintech app does this. When MINT says "ask your broker about X," it follows up with WHEN/WHERE/IF-THEN. "Next Tuesday at your 3pm meeting, ask: 'What happens if I stop in 3 years?'" Gollwitzer 1999 meta-analysis: d=0.65 effect size on follow-through. stickK/Beeminder prove commitment devices work but are standalone products — embedding this IN the financial insight is novel. | **Medium** | `ImplementationIntention` model, `notification_scheduler_service`, coach prompt engineering, persistence layer | Persist as dossier entries. Remind via push notification. Track completion. This is MINT's behavioral moat — insight without follow-through is worthless (the exact critique from the behavioral economist audit). |
| **Fresh-start anchors** | Dai/Milkman/Riis 2014: temporal landmarks increase goal-directed behavior by 25-35%. Headspace does "New Year, fresh start" campaigns. MINT detects personal landmarks (birthday, 1-year-in-MINT, new job, new year, first-of-month) and sends ONE targeted message. NOT streaks (streaks create shame on break). | **Low** | Landmark detector (date math), `anomaly_detection_service`, `snapshot_service`, push notification | Dead simple to implement. High retention impact. One notification, one reframing. "It's been a year since you uploaded your LPP certificate. Here's what changed." |
| **Pre-mortem before irrevocable decisions** | Klein 2007, Kahneman-endorsed. No financial app does this. When user is about to sign something (EPL, 3a lock-in, mortgage), MINT asks: "Imagine it's 2028 and this decision went badly. What happened?" Free text, stored in dossier. Reduces overconfidence by 30% (prospective hindsight research). 100% LSFin-compliant because it's education, not advice. | **Low** | Coach prompt trigger on irrevocable-decision detection, free text storage in dossier | The most differentiated feature in the entire list. Zero competitors do this. Deeply aligned with "lucidite-first" positioning. |
| **Asymmetric couple mode** | 80% of Swiss financial decisions are made by couples, but usually only ONE partner opens the app. Plenty/Tandem/Zeta all require BOTH partners to sign up. MINT's innovation: "What I know about my partner (and what I don't know)" — a private questionnaire that NEVER shares with the partner. MINT produces 5 questions to ask the partner without triggering a fight. | **Medium** | Couple data model (client-side initially), coach prompt for couple-aware insights, questionnaire flow, AVS married cap logic | Zelizer sociology: money in couples is relational, not arithmetic. YNAB Together requires both partners (symmetric). Plenty requires both partners. MINT is the ONLY app designed for the realistic case: one partner cares, the other doesn't. |
| **Provenance journal via coach (not form)** | Zelizer: money carries memory ("grandma's money", "the broker's 3a"). No fintech tracks WHERE advice/products came from. The coach asks casually: "By the way, who suggested this 3a?" and stores the answer. Not a form — conversation. | **Low** | Coach prompt engineering, `conversation_memory_service`, provenance field on dossier entries | Transforms the dossier from a document store into a relational map of the user's financial life. Enables future features: "3 of your 4 products were suggested by the same broker — here's what that means." |
| **Implicit earmarking via coach listening** | Users mentally separate money ("the house fund", "emergency buffer", "grandma's inheritance"). YNAB uses explicit envelope categories. MINT's approach: the coach LISTENS for earmarks in conversation and respects them in future analysis. Never overrides by aggregating into "total patrimoine." | **Low** | `conversation_memory_service`, earmark detection in coach prompt, tag persistence | Requires zero UI. Pure intelligence. When user says "that 32k in 3a is sacred, it's from my grandfather," MINT never again suggests touching it for a mortgage down payment. |
| **Tension-based living timeline (home screen direction)** | Wealthfront's Path shows net worth projections. Cleo shows spending feed. Neither shows TENSIONS. Game designer audit: "MINT should show past events (earned), present tensions (pulsing), future projections (ghosted)." One screen, tap to reveal. | **High** | Refactored home screen, tension detection engine, timeline data model, connection to all calculators | This is the most complex feature and should be a DIRECTION, not a v2.5 deliverable. Start with a simplified "3 tensions" card on the home screen. Full timeline is v3.0. |

---

## Anti-Features

Features to explicitly NOT build. Each is tempting but wrong for MINT.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Streaks / daily check-in** | Creates shame on break. Anti-principle #2 (reduce shame). Headspace abandoned strict streaks for "mindful days." Duolingo streaks are the #1 user complaint. Finance + shame = toxic. | Fresh-start anchors (landmark-based, not streak-based). "Welcome back" not "you broke your streak." |
| **Gamification badges / levels** | Social comparison is banned (CLAUDE.md). Levels imply "you're behind." MINT doctrine: compare only to user's own past. Behavioral economist audit explicitly warned against this. | Graduation Protocol direction (long-term): "Concepts you now master on your own: 7." Progress = independence, not points. |
| **Symmetric couple mode (both partners must sign up)** | YNAB Together, Plenty, Zeta all require this. In practice, one partner cares and the other doesn't. Requiring both = excluding 80% of real couples. | Asymmetric mode: one partner's private understanding of the couple's finances. Questions to ask, not accounts to share. |
| **Bank connection on first use** | Progressive disclosure principle. Asking for bank access before delivering value = maximum friction, minimum trust. Wealthfront gates planning behind connection. Bad pattern for education app. | Document upload + manual entry + coach conversation. Bank connection is a v3+ feature if ever (Open Banking in Switzerland is nascent). |
| **Leaderboards / social comparison** | "Top 20% des Suisses" is explicitly banned. Social comparison creates shame and is antithetical to MINT's mission. | Compare user to their own past only. "Your confidence score went from 42% to 67% in 3 months." |
| **Hard paywall (no free tier)** | RevenueCat data: hard paywalls convert 5x better short-term. But MINT's mission is education + lucidity for ALL Swiss. A hard paywall contradicts "democratize VZ." | Generous free tier (first premier eclairage, limited coach). Premium for depth (unlimited coach, dossier, commitment devices, couple mode). |
| **Content courses / financial literacy modules** | "Pas un prof de prevoyance." MINT identity: learning happens by action, not courses. Situated learning doctrine. | Insights emerge from user's OWN data. Education is contextual, never curricular. |
| **Product recommendations / rankings** | LSFin compliance. No ISINs, no tickers, no "this product is better." Explicitly illegal under Swiss law for MINT's license category. | Side-by-side structural comparison. "Here are the factual differences. You decide." |
| **Reverse trial (full premium then downgrade)** | CXL research shows reverse trials boost conversion. But for MINT, losing features you experienced creates loss aversion + resentment. A lucidity tool should never make the user feel they lost clarity. | Forward trial: free is genuinely useful. Premium unlocks depth. User never loses something they had. |

---

## Feature Dependencies

```
Anonymous endpoint (backend) ─┬─> Anonymous first interaction (mobile)
                               └─> Rate limiting (backend)
                                    └─> Conversation transfer post-login
                                         └─> Auth flow bridges anonymous → authenticated

Feature flag system ──> Free vs premium line ──> RevenueCat paywall
                                                   └─> Entitlement checks on all premium features

Coach prompt engineering ─┬─> Implementation intentions (Layer 4)
                          ├─> Pre-mortem prompts
                          ├─> Provenance journal
                          ├─> Implicit earmarking
                          └─> Couple-aware insights

ImplementationIntention model ──> notification_scheduler_service ──> Push notifications

Couple data model ──> Asymmetric questionnaire ──> Coach couple-aware insights
                                                     └─> AVS married cap (existing calculator)

Tension detection ──> Living timeline (direction, simplified v2.5)
```

---

## MVP Recommendation

### Phase 1 — Anonymous Hook + Auth Bridge (highest ROI, unblocks everything)
1. **Anonymous backend endpoint** with rate limiting (3-5 exchanges)
2. **Premier eclairage in < 20 seconds** from felt-state pill tap
3. **Conversation transfer** on login (anonymous session merges to user)

### Phase 2 — Premium Gate
4. **Free vs premium feature flags** (server-side, not hardcoded)
5. **RevenueCat integration** (iOS + Android subscriptions, 15 CHF/month)
6. **Paywall screen** (shown after free limit hit OR contextually on premium features)

### Phase 3 — Commitment Devices (the behavioral moat)
7. **Implementation intentions** on Layer 4 insights
8. **Fresh-start anchors** (landmark detector + single notification)
9. **Pre-mortem** on irrevocable decisions

### Phase 4 — Relational Intelligence
10. **Asymmetric couple mode** (private questionnaire, couple-aware coach)
11. **Provenance journal** via coach conversation
12. **Implicit earmarking** via coach listening

### Defer to v3.0
- **Full living timeline** (tension-based home screen) — too complex for v2.5, start with simplified "3 tensions" card
- **Graduation Protocol** — long-term direction, needs business model reconciliation
- **Dossier Federation** — long-term direction, needs format standardization
- **Political Pocket** — long-term direction, needs partnership framework

---

## Competitor Patterns Summary

| Feature Area | Cleo | YNAB | Wealthfront | Headspace | MINT Approach |
|-------------|------|------|-------------|-----------|---------------|
| **Anonymous hook** | Chat personality, spending roast | 34-day full trial | Free planning tools | Free basics (breathing) | Felt-state pill -> premier eclairage in 20s |
| **Premium conversion** | Free tracking, paid cash advances ($5.99-$14.99/mo) | Trial then $14.99/mo | Free planning, paid investment (0.25% AUM) | Free basics, $69.99/yr | Free first insight + limited coach, premium 15 CHF/mo |
| **Couple mode** | None | YNAB Together (symmetric, up to 6 people, shared budgets) | None | Shared plan pricing | Asymmetric (one partner, private) |
| **Commitment devices** | Savings challenges, hype roasts | Envelope budgeting (implicit commitment) | Auto-invest (behavioral default) | Streaks, mindful days | Implementation intentions, fresh-start anchors, pre-mortem |
| **Earmarking** | None | Explicit envelope categories | Goal-based portfolios | None | Implicit via coach listening |
| **Timeline/projection** | Spending feed | Budget calendar | Path (net worth projection) | Journey progress | Tension-based timeline (direction) |

---

## Complexity Budget

| Feature | Estimated Effort | Risk Level |
|---------|-----------------|------------|
| Anonymous endpoint + rate limiting | 1-2 days | Low — standard pattern |
| Conversation transfer | 1-2 days | Medium — session migration edge cases |
| Feature flag system | 1 day | Low — boolean checks |
| RevenueCat integration | 2-3 days | Medium — Apple review, entitlement sync |
| Paywall screen | 1 day | Low — UI only |
| Implementation intentions | 1-2 days | Low — model + prompt + notification |
| Fresh-start anchors | 1 day | Low — date math + notification |
| Pre-mortem | 1-2 days | Low — prompt + text storage |
| Asymmetric couple mode | 2-3 days | Medium — new data model, questionnaire UX |
| Provenance journal | 1 day | Low — coach prompt + memory store |
| Implicit earmarking | 1 day | Low — coach prompt + tag persistence |
| Simplified tension card (home) | 2-3 days | Medium — tension detection logic |
| **Total estimated** | **~15-20 days** | |

---

## Sources

- [Cleo pricing and tiers](https://web.meetcleo.com/pricing) — free tracking, paid advances
- [Cleo onboarding approach](https://web.meetcleo.com/blog/onboarding-of-dreams) — conversational, personality-driven
- [YNAB Together](https://support.ynab.com/en_us/ynab-together-B1nS78Cki) — symmetric couple mode, up to 6 people
- [YNAB partner budgeting](https://www.ynab.com/guide/budgeting-as-a-couple) — shared budget philosophy
- [Plenty couples app](https://fortune.com/2024/05/09/plenty-app-couples-money-wealth-management-fintech-patriarchal-stripe/) — yours/mine/ours model, both partners required
- [Tandem couples fintech](https://techcrunch.com/2024/01/17/tandem-modern-couples-app-fintech/) — modern couples finance
- [Wealthfront planning tools](https://www.wealthfront.com/planning) — free financial planning, Path engine
- [Wealthfront H2 2025 shipping](https://www.wealthfront.com/blog/what-we-shipped-h2-2025/) — recent features
- [RevenueCat State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps/) — hard paywall 5x conversion, trial benchmarks
- [RevenueCat paywall best practices](https://www.revenuecat.com/blog/growth/guide-to-mobile-paywalls-subscription-apps/) — timing, design, pricing
- [RevenueCat contextual targeting](https://www.revenuecat.com/blog/growth/contextual-paywall-targeting/) — show paywall in context
- [Apple rejecting trial toggles (Feb 2026)](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026/)
- [Fresh Start Effect (Dai/Milkman/Riis 2014)](https://pubsonline.informs.org/doi/10.1287/mnsc.2014.1901) — temporal landmarks + motivation
- [Pre-mortem (Klein 2007)](https://www.researchgate.net/publication/3229642_Performing_a_Project_Premortem) — prospective hindsight
- [Commitment devices behavioral science](https://learningloop.io/plays/psychology/commitment-devices) — voluntary + cost
- [Beeminder vs stickK](https://blog.beeminder.com/stickk/) — commitment device design patterns
- [Vanguard behavioral design principles 2025](https://corporate.vanguard.com/content/dam/corp/research/pdf/principles_for_behavioral_design_nudging_for_better_investor_outcomes.pdf) — nudging for investor outcomes
- [IPA nudges for financial health](https://poverty-action.org/publication/nudges-financial-health-global-evidence-improved-product-design) — commitment savings +80% in field experiments
- [Headspace/Calm pricing teardown](https://sbigrowth.com/insights/headspace-calm-pricing) — freemium conversion patterns
- [Reverse trial strategy](https://cxl.com/blog/reverse-trial-strategy/) — premium-first then downgrade (rejected for MINT)
- [MINT 5-expert audit](/.planning/architecture/13-AUDIT.md) — source of all 10 innovations

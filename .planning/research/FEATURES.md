# Feature Research

**Domain:** AI-centric UX journey — Swiss fintech education app
**Researched:** 2026-04-05
**Confidence:** MEDIUM (training data through Aug 2025; WebSearch/WebFetch unavailable; supplemented by internal MINT benchmark doc covering 40+ apps and academic research)

---

## Research Note

WebSearch and WebFetch were unavailable during this session. Findings draw from:

1. MINT internal benchmark (`visions/MINT_Analyse_Strategique_Benchmark.md`) — 40+ apps analyzed, 18 academic themes, March 2026
2. MINT product docs (`NAVIGATION_GRAAL_V10.md`, `MINT_UX_GRAAL_MASTERPLAN.md`, `ROADMAP_V2.md`, `MINT_IDENTITY.md`)
3. Training knowledge through August 2025 on Cleo, Perplexity, Arc, Lemonade, Monarch Money, bunq Finn, Fitbod, Duolingo, WHOOP, Noom

Confidence is MEDIUM rather than HIGH because real-time source verification was not possible. The benchmark document itself is recent (March 2026) and covers the reference apps cited in the milestone prompt.

---

## The Core Research Question

**How do the best AI-centric apps handle user journeys in 2025-2028?**

Evidence from 40+ benchmarked apps converges on four findings:

### Finding 1: Chat is infrastructure, not a feature

Cleo ($250M ARR, 1M+ paying users), bunq Finn (97% autonomous resolution, 17M EU users), Albert (agentic AI leader), Chime — all converged to conversational AI as the primary interaction surface by 2024-2025. This is no longer optional; it is table stakes. The MINT benchmark doc states it bluntly: "Le chat AI est devenu la norme, pas une feature."

**MINT has this.** `CoachChatScreen` + `CoachOrchestrator` + Claude tool calling is live in production. The gap is not presence — it is *centrality*. Chat is present but post-onboarding flows do not automatically land users in it.

### Finding 2: Onboarding-to-first-value is a 90-second race

Reference benchmarks:
- **Fitbod**: 3 questions → personalized workout in 90 seconds
- **Duolingo**: placement test → adapted first lesson in 2 minutes
- **Noom**: behavioral quiz → personalized plan in 5 minutes
- **Perplexity**: no onboarding → type a question → answer instantly

The pattern: collect the minimum viable intent signal, then immediately deliver a surprising, personalized output. The "wow" is the output, not the onboarding flow itself.

**MINT's gap**: Intent-based onboarding was just shipped (S56). The problem is what follows: user completes intent screen, then lands somewhere generic. There is no "first impact" scene. The `ReadinessGate` and `CapEngine` exist but are not orchestrated into a post-onboarding narrative.

### Finding 3: Contextual tool surfacing beats menu navigation

**Monarch Money** introduced "sparkle icons" throughout the UI — tapping any data point opens an AI explanation panel in-context. The tool comes to the user, not the other way around.

**Arc Browser** (AI-native browser): no URL bar is the primary UX — instead, the AI interprets intent and routes. Navigation becomes interpretation.

**Notion AI**: AI is a layer embedded in every block, not a separate chat interface. Type `/ai` anywhere.

**The pattern**: Tools appear when the user mentions something relevant in conversation or taps a data element — not by drilling through a category menu. MINT has `RoutePlanner` + `ScreenRegistry` + `route_to_screen` tool in `coach_tools.py`. The wiring exists but is one-directional: user asks → AI routes to screen. The reverse — screen/data element surfacing AI explanation inline — is not yet built.

### Finding 4: The "wow" moment is a single surprising number about the user's own situation

Not a feature. Not an animation. A number the user did not know about themselves, delivered in plain language, at the right moment.

- **WHOOP**: "Your recovery score is 34% — you slept 6h but your HRV collapsed after that meeting. Here is what to adjust."
- **Cleo**: "You spent CHF 847 on subscriptions this month. You probably forgot about 3 of them."
- **Monarch Money**: "Your tax burden went up CHF 2,400 this year because of your freelance income. Here is what you could have done."

In MINT's terms: the `premier_eclairage` — the first personalized insight — is the "wow" moment. The 4-layer engine (factual extraction → human translation → personal perspective → questions to ask) is exactly the right structure. The issue is delivery: it must arrive *before* the user navigates anywhere, as the direct output of onboarding.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Post-onboarding first insight | Every benchmarked AI app delivers immediate value after intake — users expect to see something personalized within seconds of completing onboarding | MEDIUM | `CapEngine` + `CoachProfile` + `premier_eclairage` structure all exist; gap is orchestration into a `FirstImpactScreen` scene |
| Coach chat accessible from the home tab | All major AI-first apps (Cleo, bunq, Albert) make chat the primary surface on the home screen — users expect AI to be one tap away, not buried in a tab | LOW | Tab 2 "Coach" exists; `Aujourd'hui` tab must surface a direct chat entry point or a proactive coach message |
| Calculators reachable from conversation | When coach mentions LPP rachat or EPL, user expects to go directly to the relevant calculator — zero hunt required | MEDIUM | `route_to_screen` tool in coach_tools.py exists; wiring must be complete for all 67 canonical routes → `ScreenRegistry` maps 109 surfaces |
| Profile data pre-fills every screen | Users are frustrated repeating their salary, age, and canton on every calculator screen — Monarch Money, Copilot, every modern fintech auto-fills from profile | LOW | `ProfileAutoFillMixin` + `SimulatorParams.resolve()` pattern documented; verify it is wired into all calculator entry screens |
| Conversation memory within session | User mentions their salary in message 3 — by message 8, coach still knows it. This is expected behavior from any AI assistant (ChatGPT, Perplexity, Claude.ai) | LOW | `ConversationMemoryService` is live; verify cross-session persistence stores correctly |
| Clear path from today's screen to action | Every Cleo, WHOOP, Oura session starts with "here is what needs your attention today" → one tap to act. Users expect a daily summary with a next action | MEDIUM | `PulseHeroEngine` + `ProactiveTriggerService` (7 triggers) exist; `Aujourd'hui` tab must render these as actionable cards not a static dashboard |
| Readable and scannable results | Financial calculators should display results in plain language first, numbers second — Betterment, Wealthfront learned this the hard way | LOW | `premier_eclairage` + `EnhancedConfidence` fields cover this; ensure all calculator output screens lead with the human translation, not the table |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Intent-to-journey routing | User selects "je veux acheter un appartement" at onboarding → entire app experience reorganizes around housing journey: relevant calculators surface first, coach speaks in housing vocabulary, Today tab shows housing-relevant caps | HIGH | `LifecycleDetector` + `ScreenRegistry.intentTag` + `CapEngine` exist; orchestration layer that maps intents to journey configurations is missing |
| Premier eclairage as first screen output | Before any navigation, user sees a single surprising, personalized insight based on their 3 onboarding inputs — delivered with the 4-layer engine (fact → translation → personal perspective → question to ask) | MEDIUM | All components exist (`financial_core`, `premier_eclairage` field, compliance copy framework); requires a `FirstImpactScreen` or `ScoreRevealScreen` wired directly into the post-onboarding route |
| Proactive contextual nudges (JITAI) | App initiates based on user profile, not just responds to taps — e.g., user receives payslip notification → coach surfaces 3a max contribution reminder with exact CHF amount | HIGH | `ProactiveTriggerService` + `JitaiNudgeService` exist; notification delivery and trigger condition precision are partial per ROADMAP_V2 audit |
| ReadinessGate-aware navigation | Instead of exposing all 67 routes, app shows only screens for which user has sufficient data — exactly like Noom showing only the next relevant coaching module | MEDIUM | `ReadinessGate` (3 levels) + `ScreenRegistry` (109 surfaces with requiredFields) are implemented; surfacing this as simplified navigation requires a new top-level routing logic |
| ConfidenceScore as engagement driver | Visible confidence percentage that improves as user adds data — like Duolingo's streak, gives users a reason to return and enrich their profile | LOW | `EnhancedConfidence` 4-axis score exists and is attached to all projections; make it prominent and show exactly what to do to reach the next confidence tier |
| Regional Swiss voice that feels local | No competitor sounds like it was written by a Vaudois who understands that a "Znüni" reference lands differently in Zurich than Geneva | LOW | `RegionalVoiceService` (26 cantons) is live; differentiator is polish — ensure regional prompts feel subtle, earned, never caricature |
| 4-layer insight engine on every coach message | Fact → human translation → personal perspective → question to ask. No competitor structures AI financial insights this rigorously. This is intellectual honesty made visible. | MEDIUM | Framework is in `MINT_IDENTITY.md`; requires coach system prompt to enforce this structure in every substantive response |
| Safe Mode (debt-first protection) | When toxic debt signals detected, disable 3a/LPP optimization features and surface debt-first guidance — no competitor does this explicitly | LOW | `SafeMode` logic exists per ROADMAP_V2; verify it is surfaced clearly in the UX (not just a background logic flag) |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Full chat-only interface (no structured screens) | Simplicity appeal; AI-first narrative | Compliance requires structured disclosure (disclaimer, sources, confidence score, alertes) — these cannot be reliably delivered in freeform chat. Trust breaks down when numbers appear without context. Also, compliance guard is harder to apply consistently | AI-as-layer: chat orchestrates navigation to structured screens. "Voici le simulateur LPP — j'ai pré-rempli tes données" |
| Dashboard with all metrics on one screen | Power users request it; feels comprehensive | Violates single-screen-single-intention principle. Swiss financial complexity cannot be honestly compressed into 6 KPI tiles. Cognitive overload leads to disengagement. Every competitor who started dashboard-first (Personal Capital/Empower) added conversational layer on top | Daily cap card (1 insight) + coach tab for depth + Explorer for browsing. Progressive, not exhaustive |
| Social comparison ("users like you save X% more") | Gamification hook; benchmarks are motivating | LSFin / FINMA risk: framing comparisons as benchmarks can imply advice. Creates shame rather than motivation for majority who are "below average." Academic research (nudge theory) shows negative financial messages trigger avoidance, not action | Personal progression only: "Tu as amélioré ton score de confiance de 12 points ce mois." Cantonal benchmarks anonymized, never "you rank X/Y" |
| Agentic AI that executes (book appointment, start 3a) | Albert/Cleo trend; reduces friction | MINT is constitutionally read-only. LSFin forbids personalized recommendations. Any autonomous action by MINT crosses into regulated financial advice or money movement. Trust requires user agency. | Deep-link to action: "Voici le lien vers ta caisse pour initier un rachat LPP" — MINT informs, user acts |
| Voice-first interface | Cleo/bunq direction; accessibility | Phase 3 roadmap item for good reason — requires STT/TTS pipeline, compliance validation on spoken output, regional voice accent training. Building it before the text journey is solid creates compounded debt | Ship text journey to excellence first; `VoiceService` stub already exists for future integration |
| Retirement-first default | Largest market segment; calculators are built | Directly contradicts MINT identity pivot (protection-first, 18 life events). Post-onboarding retirement projection as default screen recreates the "retirement app" framing that was explicitly corrected in S53/identity pivot | Intent-based routing: default to user's stated life event. Retirement is one of 11 Top 10 Switzerland situations, not the entry point |
| Personalized product recommendations (3a banks, LPP funds) | High user demand; monetization path | LSFin art. 8 prohibition. Immediate compliance violation. Even "here are your options" with ranking implies advice. Regulatory cost would be disproportionate for MVP | Factual comparison: "Les solutions bancaires sont généralement plus flexibles que les assurances. Voici les critères à évaluer." Never name, never rank |

---

## Feature Dependencies

```
[Intent-based onboarding]
    └──feeds──> [FirstImpactScreen / premier eclairage]
                    └──requires──> [CoachProfile (3 fields min)]
                    └──requires──> [financial_core calculators]
                    └──requires──> [ComplianceGuard]

[Premier eclairage delivery]
    └──unlocks──> [CapEngine daily cap]
                    └──feeds──> [Aujourd'hui tab proactive cards]

[Conversation → tool surfacing]
    └──requires──> [RoutePlanner]
    └──requires──> [ScreenRegistry (109 surfaces)]
    └──requires──> [ReadinessGate]
    └──requires──> [ProfileAutoFillMixin on every calculator screen]

[ReadinessGate-aware navigation]
    └──requires──> [CoachProfile completeness]
    └──conflicts──> [Exposing all 67 routes at once]

[ConfidenceScore as engagement driver]
    └──requires──> [Visible ConfidenceScore on Aujourd'hui tab]
    └──enhances──> [Progressive profiling (ask data when it matters)]

[JITAI proactive nudges]
    └──requires──> [ProactiveTriggerService (7 triggers)]
    └──requires──> [NotificationService wiring]
    └──enhances──> [CapEngine daily cap]

[Regional voice]
    └──requires──> [Canton field in CoachProfile (onboarding input 3)]
    └──enhances──> [All coach messages]
```

### Dependency Notes

- **FirstImpactScreen requires CoachProfile (3 fields min):** The minimum viable insight needs age (or birthDate), income, and canton — exactly what intent-based onboarding collects. These 3 fields are sufficient for AVS estimation + LPP threshold check + cantonal tax bracket.
- **Conversation tool surfacing requires ProfileAutoFillMixin on all calculator screens:** If the coach routes to LPP rachat simulator and the screen asks for salary again, the journey breaks. Pre-fill is not optional — it is the mechanism that makes AI routing feel magical rather than annoying.
- **ReadinessGate conflicts with showing all 67 routes:** Displaying `/arbitrage`, `/lpp-deep`, `/3a-deep` in a menu is a symptom of developer taxonomy bleeding into UX. These are tools, not destinations. They should be invisible until the coach or a data element surfaces them contextually.
- **JITAI nudges require NotificationService wiring:** `JitaiNudgeService` trigger logic is complete per ROADMAP_V2 audit; the delivery to notification surface is partial. This is a known "facade sans cablage" risk.

---

## MVP Definition

This milestone (v1.0 UX Journey) is a brownfield assembly milestone, not a greenfield build. All features below exist in code. The work is wiring, removing, and reorganizing — not building new things.

### Launch With (v1.0)

These are the minimum requirements to deliver the PROJECT.md core value: "A user opens MINT and within 3 minutes receives a personalized, surprising insight about their financial situation that they couldn't have found elsewhere — then knows exactly what to do next."

- [ ] **Post-onboarding first impact scene** — After intent screen, user lands on a `FirstImpactScreen` showing their `premier_eclairage` (one number, its implication for them, one question to ask). No navigation required before this. Requires wiring `OnboardingProvider` → `financial_core` → compliance-checked output to a new or repurposed screen. Complexity: MEDIUM.
- [ ] **Aujourd'hui tab as living cap** — Tab 1 must show 1-3 proactive CapEngine cards with clear next actions, not a static dashboard. `PulseHeroEngine` + `ProactiveTriggerService` must feed this. Complexity: MEDIUM.
- [ ] **Coach chat as second action** — The natural next step after first impact is "ask the coach about this." A direct CTA from `FirstImpactScreen` to `CoachChatScreen` pre-seeded with the relevant context. Complexity: LOW.
- [ ] **Profile pre-fill on all calculator entry screens** — `ProfileAutoFillMixin` verified and wired across all projection/calculator screens. User should never be asked for data MINT already has. Complexity: LOW-MEDIUM (audit + patch).
- [ ] **Remove or redirect dead/duplicate routes** — `ScreenRegistry` maps 109 surfaces; GoRouter has ~70 routes. Orphan screens (per Navigation chantier in MEMORY.md) must be removed or aliased, not left as navigation dead ends. Complexity: LOW.
- [ ] **Single coherent user journey for 3 life events** — End-to-end journey maps for `firstJob`, `housingPurchase`, and one more (suggest `newJob` for highest frequency). Each journey: intent → first insight → coach guidance → relevant calculator → result with disclaimer + next step. Complexity: HIGH (but uses existing components).

### Add After Validation (v1.x)

- [ ] **ReadinessGate-aware Explorer** — Show users only the hubs and screens relevant to their life phase. Trigger: users report confusion navigating Explorer after v1.0 launch.
- [ ] **ConfidenceScore visible on Aujourd'hui** — Show current confidence %, what is holding it down, one action to improve it. Trigger: engagement data shows users returning to profile enrichment.
- [ ] **JITAI notification delivery** — Complete `JitaiNudgeService` → `NotificationService` wiring for 2-3 highest-value triggers (lifecycle change, salary event, seasonal 3a deadline). Trigger: notification permission grant rate > 40%.

### Future Consideration (v2+)

- [ ] **Full intent-to-journey routing** — Entire app reorganizes around user's stated life event. Requires `LifecycleDetector` → `CapEngine` → navigation reconfiguration pipeline. Defer: complex, high risk, best after v1.0 confirms the journey model works.
- [ ] **Voice AI** — `VoiceService` stub exists. Phase 3 roadmap. Defer: STT/TTS pipeline + compliance on spoken output is a separate milestone.
- [ ] **Weekly Recap AI** — `WeeklyRecapService` is foundation-only per ROADMAP_V2. Defer: requires consistent engagement data to generate meaningful recaps.
- [ ] **Community/cantonal social proof** — Anonymized benchmarks by canton. Defer: compliance review needed for framing, risk of shame effect if implemented carelessly.

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Post-onboarding first impact scene | HIGH | MEDIUM | P1 |
| Aujourd'hui tab as living cap (not static dashboard) | HIGH | MEDIUM | P1 |
| Profile pre-fill on all calculator screens | HIGH | LOW-MEDIUM | P1 |
| Coach chat as next action from first impact | HIGH | LOW | P1 |
| Journey maps for 3 life events (firstJob, housingPurchase, newJob) | HIGH | HIGH | P1 |
| Remove dead/duplicate routes | MEDIUM | LOW | P1 |
| 4-layer insight engine enforced in coach system prompt | HIGH | LOW | P1 |
| ConfidenceScore visible on Aujourd'hui | MEDIUM | LOW | P2 |
| ReadinessGate-aware Explorer | MEDIUM | MEDIUM | P2 |
| JITAI notification delivery | HIGH | MEDIUM | P2 |
| Safe Mode surface in UX (not just background logic) | MEDIUM | LOW | P2 |
| Full intent-to-journey routing (app reorganizes per life event) | HIGH | HIGH | P3 |
| Weekly Recap AI | MEDIUM | MEDIUM | P3 |
| Voice AI | MEDIUM | HIGH | P3 |

**Priority key:**
- P1: Must have for v1.0 UX Journey milestone
- P2: Should have, add in v1.x after validation
- P3: Future milestone

---

## Competitor Feature Analysis

| Feature | Cleo (US, consumer) | Monarch Money (US, premium) | MINT approach |
|---------|---------------------|------------------------------|---------------|
| First value moment | Personality quiz → roast of spending immediately | Connect bank → automatic spending insights | 3 onboarding inputs → premier eclairage (Swiss calculation, not bank connection required) |
| AI surfacing tools | Chat → AI suggests budget categories, bills, savings goals | "Sparkle icons" on any data element → inline AI | Coach message → RoutePlanner → pre-filled calculator screen |
| Home tab design | Daily "mood" + spending summary + CTA | Net worth + cash flow + AI insights | Cap du jour (1 action) + confidence progress |
| Navigation model | 5 tabs (home, activity, coach, goals, cards) | 4 tabs (dashboard, transactions, planning, coach) | 3 tabs + drawer (Aujourd'hui, Coach, Explorer) |
| Onboarding | Bank connection (Open Banking) | Bank connection required | Intent-first, no bank connection required (Swiss regulatory constraint + trust) |
| Compliance handling | US regulations, relatively permissive | US regulations, fiduciary-adjacent | Swiss LSFin/FINMA, strict read-only, educational framing mandatory |
| What makes users say "wow" | "You spent $847 on Uber this year. Want to know your coffee number?" — surprise through exact specificity | "Your net worth grew $12,400 this year" — personal progress made concrete | "Ton LPP dépasse le seuil — voici ce que personne ne t'a dit." — protection-first surprise |

**Key differentiator MINT must own:** Cleo and Monarch work because US Open Banking gives them transaction data immediately. MINT cannot do this (Swiss regulatory context + early trust-building). MINT's differentiator is *calculating surprising insights from sparse inputs* — 3 data points (age, income, canton) produce genuine Swiss-specific insights nobody else computes. This is the reason the financial_core calculators matter: they enable wow moments without bank connection.

---

## Sources

- MINT internal benchmark: `visions/MINT_Analyse_Strategique_Benchmark.md` — 40+ apps analyzed, 18 academic research themes, March 2026. MEDIUM-HIGH confidence (recent, comprehensive, but internal document).
- MINT product docs: `NAVIGATION_GRAAL_V10.md`, `MINT_UX_GRAAL_MASTERPLAN.md`, `ROADMAP_V2.md`, `MINT_IDENTITY.md` — HIGH confidence for MINT-specific feature state.
- Training knowledge (through Aug 2025): Cleo, Perplexity, Arc, Monarch Money, bunq Finn, Fitbod, Duolingo, WHOOP, Noom UX patterns — MEDIUM confidence (cannot verify 2025-2026 updates).
- Academic research via benchmark doc: JITAI (+40% acceptance at workflow boundaries), gamification (+45% engagement, +30% savings), ConfidenceScore transparency (+32% trust), pension app contribution (+1.8pp from friction reduction) — MEDIUM-HIGH confidence (peer-reviewed, cited in benchmark doc).

---

*Feature research for: AI-centric UX journey — MINT Swiss fintech*
*Researched: 2026-04-05*

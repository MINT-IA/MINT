# Deep Audit 2026-04-17: Cleo 3.0 Gap Analysis vs. MINT

**Document:** `.planning/deep-audit-2026-04-17/03-cleo-gap.md`  
**Date:** 2026-04-17  
**Scope:** 25 unique Cleo 3.0 screenshots (Xnapper 2026-03-20 13:04–17:44) vs. MINT's current Flutter implementation

---

## EXECUTIVE SUMMARY

Cleo 3.0 operates on a **tight Insight → Plan → Conversation → Action → Memory loop** where every micro-interaction (notification, goal picker, transaction prompt) funnels the user into a continuous feedback cycle. MINT has built **superior depth in insight generation (4-layer engine, archetype logic, Swiss compliance)**, but lacks **Cleo's conversational fluidity, proactive friction design, and embedded action velocity**.

### Top 3 Gaps (User Impact):
1. **No embedded action buttons in insights** — MINT shows insights but doesn't surface inline CTAs (transfer button, goal setter, subscription cap prompt)
2. **Conversation not memory-backed** — Coach chat exists but doesn't retain context cross-session; Cleo's memory layer makes every exchange accumulate
3. **Plan layer missing visible daily frame** — MINT has "Cap du jour" concept but no UI equivalent to Cleo's "Hey [Name], [Status] this month + budget circle + action"

### Top 3 MINT Strengths:
1. **4-layer insight engine (fact → translation → perspective → questions)** — Cleo's insights are emoji + number; MINT's are educational
2. **Swiss legal framework by design** — Compliance guards, Safe Mode debt detection, LSFin-native; Cleo is US/UK consumer finance
3. **Archetype system** — MINT routes advice through user's financial identity; Cleo treats all users with same conversational tone

---

## 1. CLEO PATTERN INVENTORY

### INSIGHT CATEGORY (Cleo 3.0)

| Pattern | Screenshot | UX Detail |
|---------|-----------|-----------|
| **Onboarding Hero** | 13.04.30 | Full-width text overlay on gradient (blue→pink) + cloud background; "Cleo understands where you're trying to go" tagline; soft secondary text with micro stats |
| **Split-Screen Income Fact** | 13.06.23 | Person photo (half opacity) + overlay with 2 stacked number blocks: "The fruits of your labor: $52,022" + "The burden of living: $58,260" — reframes income as narrative |
| **Persona Selection** | 13.07.45 | 3 horizontal cards with photography, each card has persona label (e.g., "Build Wealth", "Pay off Debt", "Spend Smarter") + name label; swipeable carousel |
| **Spending Breakdown Stack** | 13.06.51 | Vertical stack of category pills (Groceries $872, Essentials $810, Subscriptions $150, Take Out $834) with pill color-coding + "Money in Banking" CTA button at bottom |
| **Timeline Spend Curve** | 13.13.06, 13.13.32 | Line graph (Jan–Jun, earnings/spending overlaid) + category legend chips (One-offs, Subscriptions); shows historical pattern not projection |

**MINT Equivalent:** 
- `apps/mobile/lib/widgets/home/hero_stat_card.dart` (hero numbers exist)
- `apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart` (spending breakdown exists)
- **Gap:** Persona selection is _absent_; spending breakdown is list-based, not category-pill visual; no timeline curve in home view

---

### PLAN CATEGORY (Cleo 3.0)

| Pattern | Screenshot | UX Detail |
|---------|-----------|-----------|
| **Goal Card** | 13.08.17 | Card with tag "On track", large title "Spend smarter", goal text "Spend less than you earn for at least 4 of the next 6 months", timeline "2 months to go", month calendar picker (Jan–Jun) with current month highlighted |
| **Monthly Savings Target** | 13.08.56 | Two-column layout: "Goal time: 12 months" (left) | "Save per month (avg): $166" (right); muted background image (plant); shows runway math inline |
| **Daily Budget Remaining** | 13.09.54 | Large circular progress meter with "Left to spend: .396" + "On track" label + date range "23 Nov - 22 Dec"; soft background; one-liner context "You're cruising — just $123 spent in 6 days, steady and sustainable" |
| **Personal Daily Greeting** | 13.10.27 | "Hey Tom" (name-personalized) + "Solid work this month" + circular budget remaining (263 left) + "On track" label + context fact "You're cruising — just $123 spent in 6 days" + checkbox for "Left to spend" behavior |
| **Proactive Subscription Check** | 13.10.52 | Modal prompt "Just to check — are you aware of your upcoming subscriptions? $19 payable to Apple next Wednesday" + action buttons ("Add new question" / "Not counting me") — creates friction before autopilot |

**MINT Equivalent:**
- No equivalent to daily greeting / personalized status display
- Cap du jour concept exists in design docs but **not implemented in UI**
- Goal picker exists (`apps/mobile/lib/screens/mortgage/affordability_screen.dart` has goal math)
- **Gap:** Daily plan frame missing (no "Hey [Name], [Status]" greeting); no proactive subscription detection; plan is text-heavy, not numeric-visual

---

### ACTION CATEGORY (Cleo 3.0)

| Pattern | Screenshot | UX Detail |
|---------|-----------|-----------|
| **Widget/Lock-Screen Bubble** | 13.16.07 | Embedded in lock-screen; shows budget remaining + "On track" status + context fact; no tap needed to view; passive awareness |
| **Transaction Alert Modal** | 13.12.05 | "Hey [Name], Monitor your $200 advance. Got something to contribute?" + suggested action (Download, Share); appears after transaction with context |
| **Subscription Interception** | 13.11.20 | "Your highest category is Amazon: $480.28. Shall we cap this at $200 next month?" — proactive cap offer with yes/no action |
| **Savings Transfer Modal** | 13.15.41 | "Savings: $250.00" + 2-field form (From: MasterCard $2,540 / To: Savings Pot $90,635) + dark rounded action button "Transfer to savings" |
| **Savings Goal Unlock** | 13.16.07 | Slider ("Let's aim for $1,000") + confetti-on-unlock effect + progress visualization; framed as collaborative goal-setting |

**MINT Equivalent:**
- `apps/mobile/lib/services/coach_orchestrator.dart` (coach can dispatch actions)
- `apps/mobile/lib/services/response_card_service.dart` (response cards for tool calls)
- Transfer modal might exist in open banking flows
- **Gap:** Proactive subscription interception _missing_; lock-screen widget unsupported in Flutter (platform limitation); action modals are reactive (coach-initiated), not pattern-based; no confetti/delight UX

---

### CONVERSATION CATEGORY (Cleo 3.0)

| Pattern | Screenshot | UX Detail |
|---------|-----------|-----------|
| **Lock-Screen Chat Bubble** | 13.12.05 | Minimal text: "$180 emergency plumber? Maybe we had reasons. Let's relocate." — conversational, assumes context, asks softly; appears on lock-screen |
| **Advice → Action Frame** | 13.15.23 | Video placeholder showing a person (Cleo avatar) with text overlay "Advice → Action"; visual metaphor that chat leads to behavior change |
| **Chat with Context** | 13.16.25 | Chat bubble + transaction reference + suggested action chips; conversation is grounded in user's actual data, not generic |

**MINT Equivalent:**
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` (full chat implementation)
- Coach can access user context via `context_injector_service.dart`
- **Gap:** Coach chat is isolated; doesn't propagate memory into next session; lock-screen integration unsupported; no video/visual explanation frames

---

### MEMORY CATEGORY (Cleo 3.0)

| Pattern | Screenshot | UX Detail |
|---------|-----------|-----------|
| **Insight Generation Loop** | 13.14.09 | Diagram: "Enriched Transactional Data" → Generate → Validate & Rank → Regenerate (loop) → Insights; shows that insights are continuously refined |
| **Daily Plan Orchestration** | 13.14.36 | Flowchart: Insights → Daily Plan (with multiple plan items) → Actions → User Acceptance + Memory layer at bottom; shows closed-loop feedback |

**MINT Equivalent:**
- `apps/mobile/lib/services/cap_memory_store.dart` (Cap memory exists)
- `apps/mobile/lib/services/coach/coach_orchestrator.dart` (orchestration logic)
- `apps/mobile/lib/services/memory/coach_memory_service.dart` (coach memory exists)
- **Gap:** Memory is coach-session-isolated; doesn't flow back into home insights; no visible feedback loop to user showing how their actions changed recommendations

---

## 2. MINT'S CURRENT IMPLEMENTATION PER PATTERN

### Insight Patterns

| Cleo Pattern | MINT File | Status | Quality |
|--------------|-----------|--------|---------|
| Onboarding Hero | `lib/screens/landing_screen.dart` | IMPLEMENTED | INFERIOR — static text, no narrative framing |
| Split-Screen Income Fact | `lib/widgets/home/hero_stat_card.dart` | PARTIAL | Numbers visible but no "reframing" (not linked to life implications) |
| Persona Selection | None found | MISSING | — |
| Spending Breakdown Stack | `lib/screens/mon_argent/mon_argent_screen.dart` | IMPLEMENTED | PARTIAL — list layout, not pill-card visual; no color coding per category |
| Timeline Spend Curve | `lib/screens/mon_argent/mon_argent_screen.dart` | PARTIAL | Chart exists but historical (good), not predictive; not in home feed |

**MINT Insight Gaps:**
- No persona system (archetype exists internally but not as user-facing selector)
- Insights are dashboard cards, not narrative reframes ("earnings = fruits of labor")
- No visual timeline curve in primary home view

---

### Plan Patterns

| Cleo Pattern | MINT File | Status | Quality |
|--------------|-----------|--------|---------|
| Goal Card | `lib/widgets/home/financial_plan_card.dart` | PARTIAL | Card exists; no goal picker or calendar timeline visual |
| Monthly Savings Target | `lib/screens/mortgage/affordability_screen.dart` | PARTIAL | Math calculated but UI buried in simulator, not in plan feed |
| Daily Budget Remaining | None | MISSING | — |
| Personal Daily Greeting | None | MISSING | — |
| Proactive Subscription Check | None | MISSING | — |

**MINT Plan Gaps:**
- Cap du jour concept is in design docs (`MINT_UX_GRAAL_MASTERPLAN.md` §3) but _no screen implementation_
- No daily greeting UX
- No proactive friction points (subscription checks, budget alerts that prompt action)

---

### Action Patterns

| Cleo Pattern | MINT File | Status | Quality |
|--------------|-----------|--------|---------|
| Widget/Lock-Screen Bubble | Platform limitation | MISSING | Flutter doesn't expose iOS lock-screen API |
| Transaction Alert Modal | `lib/services/response_card_service.dart` | PARTIAL | Coach can send cards; no pattern-based triggering |
| Subscription Interception | None | MISSING | — |
| Savings Transfer Modal | `lib/screens/open_banking/open_banking_hub_screen.dart` | PARTIAL | Transfer UI exists; not surfaced proactively from insights |
| Savings Goal Unlock | `lib/widgets/home/progress_milestone_card.dart` | PARTIAL | Progress cards exist; no confetti/delight micro-interactions |

**MINT Action Gaps:**
- Transfer actions are reactive (user navigates to open banking tab) not embedded in insights
- No proactive subscription detection and cap-offer pattern
- Micro-interactions (confetti, unlock animation) are absent
- Action flows are chat-initiated, not insight-initiated

---

### Conversation Patterns

| Cleo Pattern | MINT File | Status | Quality |
|--------------|-----------|--------|---------|
| Lock-Screen Chat Bubble | Platform limitation | MISSING | — |
| Advice → Action Frame | `lib/screens/coach/coach_chat_screen.dart` | PARTIAL | Coach messages exist; no visual "advice → action" metaphor |
| Chat with Context | `lib/services/coach/context_injector_service.dart` | IMPLEMENTED | Good; coach sees user data; limited memory across sessions |

**MINT Conversation Gaps:**
- Chat is isolated; memory doesn't persist visually to home insights
- No video/persona explanation frames
- Chat initiates action but action results don't flow back into conversation
- No lock-screen integration

---

### Memory Patterns

| Cleo Pattern | MINT File | Status | Quality |
|--------------|-----------|--------|---------|
| Insight Generation Loop | `lib/services/coach/coach_orchestrator.dart` + `cap_memory_store.dart` | PARTIAL | Loop exists (coach generates insights); not visible to user |
| Daily Plan Orchestration | Design docs only | MISSING | Orchestration layer is internal; no UI flow showing "Insights → Plan → Actions → Memory" |

**MINT Memory Gaps:**
- Memory is stored but not visualized; user doesn't see how their actions changed insights
- No feedback loop in UI showing insight updates based on behavior
- Memory layer is coach-internal; not surfaced to home feed

---

## 3. TOP 10 GAPS RANKED BY USER-FACING IMPACT

### Gap #1: Daily Plan UI (Personal Greeting + Budget Snapshot)
**Cleo Implementation:**  
Lock-screen greeting ("Hey Tom, Solid work this month") + circular budget remaining (396 left) + "On track" status + context story in 1-2 lines. Appears when user opens phone. Shows budget math, not raw data.

**MINT Current State:**  
No equivalent screen. Cap du jour is mentioned in `MINT_UX_GRAAL_MASTERPLAN.md` (§3, "Cap du jour") but no Flutter widget implemented. Today screen (`lib/screens/aujourdhui/`) shows timeline, not daily budget.

**Why It Matters for Swiss Use Case:**  
Swiss users expect transparency and context; a daily greeting with budget status + personalized comment ("vous avez respecté votre budget cette semaine") builds habit and trust. Ties to 3-pillar planning (AVS/LPP/3a can show daily "on track" status).

**Estimated Effort:** M (3-4 days)
- Create `daily_greeting_widget.dart` with personalization engine
- Integrate budget remaining calculation from existing `financial_fitness_service`
- Add daily context story generation (coach LLM or rule-based)

---

### Gap #2: Embedded Action Buttons in Insights (Transfer, Cap, Set Goal)
**Cleo Implementation:**  
Insights surface inline actions: "Your highest category is Amazon $480.28. Shall we cap at $200?" + yes/no buttons. Transfer amount shown + "Transfer to savings" button. No navigation required.

**MINT Current State:**  
`lib/widgets/home/` cards exist but are informational. Action sheets exist (`lib/services/response_card_service.dart`) but only dispatched by coach, not by insight pattern matching. Open banking transfer UI is in `lib/screens/open_banking/` (requires navigation).

**Why It Matters for Swiss Use Case:**  
MINT's strength is 4-layer insight depth; embedding action reduces friction. For Swiss users with multiple accounts + 3-pillar rules, "Should we rebalance your LPP?" embedded action is powerful.

**Estimated Effort:** M (4-5 days)
- Extend `HeroStatCard` + `FinancialPlanCard` to support action button slots
- Create pattern matcher in `cap_memory_store` (if spend in category > threshold + user's own goal, suggest cap)
- Hook to `response_card_service` for in-app action sheets

---

### Gap #3: Proactive Subscription Interception
**Cleo Implementation:**  
Detects recurring charges, surfaces modal: "$19 payable to Apple next Wednesday. Aware of this?" + context. If subscription is detected but not recognized, suggests confirmation before auto-debit.

**MINT Current State:**  
`lib/services/` has no subscription detection. Open banking data could theoretically enable this, but no rule engine exists.

**Why It Matters for Swiss Use Case:**  
Swiss users are price-sensitive and budget-conscious. Unmanaged subscriptions ($10–50/mo) are common pain points. Proactive alert + cap offer is a clear "MINT protects you" signal. Ties to debt prevention module.

**Estimated Effort:** M (3-4 days)
- Build subscription detection in `financial_fitness_service` (pattern: same amount, same day each month)
- Create modal trigger rule (if detected subscription not in user's subscription list, show prompt)
- Add "cap this category" action to open banking transfer service

---

### Gap #4: Proactive Memory Feedback (How Your Actions Changed Insights)
**Cleo Implementation:**  
Diagram shows closed-loop: Insights → Plan → Actions → Memory. User sees that their behavior (saved $200) updated next month's insights. Implied in UI but shown in help/onboarding.

**MINT Current State:**  
Memory exists (`coach_memory_service.dart`) but is invisible to user. Coach chat can reference past sessions, but user doesn't see "Your 3a contributions have improved your confidence score by 5%."

**Why It Matters for Swiss Use Case:**  
MINT's ConfidenceScore is powerful (0.25 → 1.0 progression). Showing users how their actions (AVS verification, LPP data, 3a entry) directly improved their score drives behavioral reinforcement.

**Estimated Effort:** M (3-4 days)
- Add `memory_feedback_card.dart` showing "Last month you verified your LPP. Confidence: 62% → 74%"
- Query `coach_memory_service` for user actions in past 30 days
- Surface in home feed or dedicated "Your Progress" section

---

### Gap #5: Conversational Memory Visibility (What Does Coach Remember?)
**Cleo Implementation:**  
Chat context persists; user can say "like last time" and coach understands. In Cleo 3.0, memory is mentioned in UI ("I remember you said…").

**MINT Current State:**  
Coach chat (`coach_chat_screen.dart`) loads context per session (recent conversation history), but doesn't show user what coach remembers from past sessions. Memory is server-side, not visible.

**Why It Matters for Swiss Use Case:**  
For financial planning over decades (age 22–99), visible memory is critical. "I remember you wanted to buy a house in Valais by 2030" reassures users that their goals are tracked.

**Estimated Effort:** S (2-3 days)
- Add memory summary card in chat greeting: "I remember: [goal 1], [goal 2], [situation flag]"
- Surface `coach_memory_service` data as chat metadata
- Allow user to add/edit memory from chat interface

---

### Gap #6: Persona-Based Insight Routing
**Cleo Implementation:**  
Personas are UI selector, but underneath Cleo's insights are personalized by user spending/earning profile. MINT's archetype system is more sophisticated but hidden.

**MINT Current State:**  
Archetype system exists internally (`BLUEPRINT_COACH_AI_LAYER.md`), routes advice through financial identity (e.g., "young precariat" gets different messaging). Not surfaced as user-facing persona selector.

**Why It Matters for Swiss Use Case:**  
MINT's Swiss archetypes (frontalier, indépendant, expatrié) are differentiators. Letting user explicitly choose archetype + seeing insights routed through that lens ("As an indépendant, here's your 3a strategy") validates MINT's depth.

**Estimated Effort:** M (2-3 days)
- Create `persona_selector_screen.dart` (horizontal card selection like Cleo)
- Store user's persona in `coach_profile_provider.dart`
- Surface archetype in insight cards: "As a [persona], here's your focus"

---

### Gap #7: Lock-Screen & Push-Notification Integration
**Cleo Implementation:**  
Budget update notifications appear on lock-screen. Alerts ("New subscription detected") use rich push format.

**MINT Current State:**  
`lib/services/analytics_service.dart` and push infrastructure exist but don't surface financial insights on lock-screen. iOS lock-screen widget API is not exposed in Flutter.

**Why It Matters for Swiss Use Case:**  
For busy professionals (core MINT user: 28–55), lock-screen alerts are the first touchpoint. "Your weekly budget is on track" or "New subscription detected" drives daily awareness.

**Estimated Effort:** L (5-7 days)
- Requires native iOS/Android code (not pure Flutter)
- Build lock-screen widget (iOS WidgetKit) + dynamic island support
- Implement rich push notifications with financial context
- Privacy-sensitive: show only non-identifying numbers ("$500 remaining", not "CHF 500 from investment account")

---

### Gap #8: Micro-Interactions & Delight (Confetti, Unlock Animations)
**Cleo Implementation:**  
Savings goal unlocked shows confetti animation. Budget milestone reached triggers celebratory feedback. Small but reinforces positive behavior.

**MINT Current State:**  
`lib/widgets/` are functional but lack delight UX. Animations are minimal (fade-in for cards). No reward/unlock feedback.

**Why It Matters for Swiss Use Case:**  
Swiss design is minimalist, but behavioral science shows micro-rewards (confetti, badges) increase action completion by 20–30%. MINT's educational tone allows subtle delight without being "gamey."

**Estimated Effort:** S (2-3 days)
- Add `confetti_animation.dart` to milestone achievements
- Integrate celebration sound (muted by default)
- Update `progress_milestone_card.dart` to trigger animation on unlock

---

### Gap #9: Conversation-to-Action Closure (Chat Leads to Visible Plan Update)
**Cleo Implementation:**  
User asks "How do I reach my $1k savings goal?" → Coach suggests "Automate $50/week" → User agrees → Savings goal card appears in Daily Plan with "$50 weekly" now visible.

**MINT Current State:**  
Coach chat exists; coach can suggest actions via response cards. But action results don't flow back into home feed insights. No closed-loop UX.

**Why It Matters for Swiss Use Case:**  
MINT's messaging is "Conversation, not lesson" (MINT_IDENTITY.md §3). If conversation doesn't lead to visible plan update, it feels incomplete. Users need to see "Your chat with coach → Your new cap for Amazon is $200" in home feed.

**Estimated Effort:** M (4-5 days)
- Extend `response_card_service` to emit events when user accepts action
- Subscribe in home feed to action events, update displayed plans
- Add "This came from your chat with coach" metadata to plan cards

---

### Gap #10: Timeline Spending Curve in Home Feed (Not Buried in Dashboard Tab)
**Cleo Implementation:**  
Earnings vs. Spending line graph (Jan–Jun) visible in Daily Plan feed. Shows historical pattern (not projection); educates user without overload.

**MINT Current State:**  
`lib/screens/mon_argent/mon_argent_screen.dart` has spending breakdown and charts. Not visible in primary home feed. Home is timeline-focused; chart view requires tab switch.

**Why It Matters for Swiss Use Case:**  
MINT's 4-layer insight works best when contextualized with data. Seeing "You spent 8% more this month (vacations)" + insight card "You're flexible with pleasure budget — good" side-by-side educates. Buried in dashboard tab loses the narrative.

**Estimated Effort:** S (2-3 days)
- Extract chart widget from `mon_argent_screen` → `spending_curve_card.dart`
- Embed in `AujourdhuiScreen` below greeting
- Keep to 3-month view (readable, not overwhelming)

---

## 4. MINT'S STRENGTHS vs. CLEO

### Strength #1: 4-Layer Insight Engine
**File:** `apps/mobile/lib/` (throughout coach logic)  
**Spec:** `MINT_IDENTITY.md` §"Le moteur 4 couches"

**Implementation:**
- Layer 1 (Fact): AVS duration, LPP flexibility, 3a tax benefits
- Layer 2 (Translation): "Ce produit te laisse sortir difficilement"
- Layer 3 (Personalization): "Si ta situation bouge souvent, la flexibilité compte"
- Layer 4 (Questions): "Que se passe-t-il si j'arrête dans 3 ans?"

**Cleo's Approach:** Emoji + number + one-liner ("Your highest category is Amazon. Cap it?"). Immediate, not educational.

**Why It Matters:** Swiss users need to understand _why_ a recommendation is made (LSFin compliance + cultural preference). MINT's layer approach builds trust; Cleo builds urgency.

---

### Strength #2: Swiss Legal Framework by Design
**File:** `apps/mobile/lib/services/coach/compliance_guard.dart`

**Implementation:**
- Never prescriptive ("Do this")
- Always explanatory ("Here's what this means for you")
- Safe Mode: Disables optimization tools if debt detected
- No specific product recommendations (asset classes only)
- Full LSFin alignment

**Cleo's Approach:** UK/US consumer finance; gives recommendations ("Switch to this savings account"); regulated as fintech, not educational.

**Why It Matters:** Cleo is restricted in Switzerland by FINMA. MINT's compliance-first design is a defensible moat for Swiss users. Can expand to adjacent markets (EU education-first products) without rewrite.

---

### Strength #3: Archetype System (Financial Identity Routing)
**File:** Design docs (`BLUEPRINT_COACH_AI_LAYER.md` §4)

**Implementation:** Internal archetypes:
- Young precariat (gig, unstable)
- Frontalier (cross-border tax complexity)
- Indépendant (self-employed, quarterly tax planning)
- High-earner (asset diversification)
- Retiree (decumulation strategy)

Each archetype gets insights + language tuned to their situation. MINT's coach doesn't say "optimize your 3a" to everyone; it says "As a frontalier, your 3a strategy is different because of cross-border tax rules."

**Cleo's Approach:** One-size-fits-all conversational tone; uses spending patterns to adapt, not user identity.

**Why It Matters:** Swiss financial reality varies wildly by life stage + employment status. Archetype routing is MINT's intellectual moat. Combined with 4-layer insights, it's unmatched in category.

---

### Strength #4: ConfidenceScore (Data Maturity Progression)
**File:** `MINT_IDENTITY.md` + implementation in confidence widget  
**Spec:** DataSource enum (systemEstimate: 0.25 → institutionalApi: 1.00)

**Implementation:** Users see their confidence improve as they verify data:
- Initial: 25% (system estimate from public data)
- After onboarding: 45% (user-entered data)
- After document scan: 65% (OCR extraction)
- After open banking link: 85% (transaction data)
- After AVS/LPP API: 95%+ (authoritative source)

**Cleo's Approach:** No explicit confidence tracking; all insights presented as equally valid.

**Why It Matters:** In Switzerland, users are hesitant to trust unverified data. ConfidenceScore is behavioral psychology: "Your insights are only as good as your data; here's how to improve trust." Drives data completion.

---

### Strength #5: 3-Pillar Architecture (AVS/LPP/3a as Spine)
**Files:** Entire app is organized around this (see `/lib/screens/`), with dedicated deep-dives per pillar

**Implementation:**
- AVS (state pension): projection, optimization, frontalier rules
- LPP (pension fund): fund comparisons, free passage rights, early retirement, buybacks
- 3a (private savings): tax strategy, withdrawal timing, asset allocation

**Cleo's Approach:** Generic budgeting + savings; no pension system knowledge.

**Why It Matters:** This is MINT's core differentiation. Swiss retirement is complex (unlike US 401k); MINT educates systematically. No fintech competitor has this depth.

---

## 5. KEY VISUAL & INTERACTION PATTERNS TO ADOPT FROM CLEO

### Micro-Interactions
1. **Confetti on milestone unlock** — When user reaches savings goal, brief confetti shower + celebratory sound (muted by default)
2. **Budget circle progress** — Circular gauge showing "left to spend" updates in real-time as transactions post
3. **Collapsible context lines** — Long explanations hidden behind "Learn more" tap-to-expand (not inline walls of text)

### Empty States
1. **Onboarding hero** — "Cleo understands where you're trying to go" tone; show vision before asking for data
2. **No transactions yet** — "Your transactions will appear here" with illustration + CTA to link account (not blank)

### Chart Styles
1. **Soft palette timeline** — Earnings (teal) vs. Spending (coral) stacked line graph; 3-month view with readable axis labels
2. **Category pie breakdown** — Instead of bars, use pill-shaped category blocks with amount + percentage

### Chip/Button Designs
1. **Dark rounded action buttons** — "Transfer to Savings" / "Set Budget Cap" — high contrast, 48px+ tap target
2. **Inline action chips** — Suggested responses in chat or notifications ("Download" / "Share" / "Ask Coach") as secondary buttons

### Loading States
1. **Skeleton screens** — Show layout outline while data loads (not spinner)
2. **Streaming text** — Coach messages appear token-by-token (already in MINT; good)

---

## 6. IMPLEMENTATION ROADMAP (Prioritized)

### Phase 1: Core Daily Loop (2 weeks) — _Most impactful for user retention_
1. Daily Greeting + Budget Snapshot Screen (Gap #1)
2. Embed Action Buttons in Insight Cards (Gap #2)
3. Micro-Interactions (Confetti, Unlock Animation) (Gap #8)

**Why first:** These three unlock the "daily ritual" behavior that Cleo has and MINT lacks. Users will return daily if they see personalized greeting + can act within home feed.

### Phase 2: Proactive Intelligence (2 weeks)
1. Subscription Interception + Cap Modal (Gap #3)
2. Timeline Curve in Home (Gap #10)

**Why second:** Builds on Phase 1; extends into predictive patterns.

### Phase 3: Memory & Feedback Loops (2 weeks)
1. Memory Visibility in Chat (Gap #5)
2. Conversation-to-Action Closure (Gap #9)
3. Memory Feedback Card (Gap #4)

**Why third:** Requires stable Phase 1 foundations; closes feedback loops.

### Phase 4: Polish & Delight (1 week)
1. Lock-Screen Integration (Gap #7) — requires native code, lower ROI
2. Persona Selector UI (Gap #6) — nice-to-have, not core loop

**Why later:** Nice-to-have; doesn't drive retention.

---

## 7. CLEO PATTERNS MINT SHOULD REFUSE

### Tone & Voice
- MINT's tone is "Doux mais tranchant" (soft but sharp); Cleo is "Cheeky" (too consumer US)
- MINT should never match Cleo's aggressive language ("Autopilot", "Genius AI")
- Better term for MINT: "Cap" (not "Autopilot"); "Coach" (not "Genius")

### UX Philosophy
- MINT should NOT promise autonomous decision-making ("I'll move your money automatically")
- MINT should stay educational; Cleo is directive
- MINT's Safe Mode (debt detection blocks optimization) is non-negotiable; Cleo has no equivalent

### Visual
- MINT should NOT use bright neons (gradient blue→pink); stick to Swiss minimalism (white/cream/earth tones)
- MINT should keep personas subtle (not 3 flashy cards); integrate archetype into insights instead

---

## 8. CONCLUSION

**MINT vs. Cleo: The Choice**

| Dimension | MINT | Cleo |
|-----------|------|------|
| **Depth** | 4-layer insights, 3-pillar architecture | Emoji + number, behavioral patterns |
| **Trust** | Compliance-first, ConfidenceScore tracking | Conversational warmth, personality |
| **Action** | Embedded in insights (potential) | Proactive friction, conversational nudge |
| **Memory** | Exists, not visible | Visible, conversational recall |
| **Reach** | Swiss + EU education markets | UK/US/global, high consumer finance |

**The Gap:** MINT has built intellectual depth; Cleo has built daily ritual. MINT's next 8 weeks should focus on **embedding action + visibility into daily loops**, not adding more analysis layers.

**The Opportunity:** If MINT closes Gaps #1–3 and #8–9 in the next quarter, it will have:
1. Cleo's daily ritual engagement
2. MINT's educational trust + compliance
3. Swiss-specific archetype routing no competitor can match

This is defensible, sustainable, and distinctly Swiss.

---

**Report compiled:** 2026-04-17  
**Data:** 25 unique Cleo screenshots + MINT codebase analysis  
**Next:** `.planning/deep-audit-2026-04-17/04-implementation-sprint-plan.md`

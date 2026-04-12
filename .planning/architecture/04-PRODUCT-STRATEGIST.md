# 04 — Product Strategist: What Lives, What Dies

> **Author**: Senior product strategist (fintech, edtech, consumer, Cleo/Wealthsimple DNA)
> **Date**: 2026-04-11
> **Mandate**: The user has 95 screens and no narrative. I am here to decide what to KILL.
> **Tone**: Opinionated. No hedging. If 50 screens should die, that is what this document says.

---

## Prologue — What I saw when I opened the project

I read the Identity doc. It is one of the sharpest pieces of product writing I have seen in Swiss fintech: *"Mint te dit ce que personne n'a intérêt à te dire."* Protection-first. Anti-shame. 4-layer insight engine. A toilet test. A tone that is *doux mais tranchant*.

Then I opened the screen inventory. 95 screens. A `BudgetContainerScreen` that is a facade pointing back to the chat that spawned it. `AskMintScreen` and `CoachChatScreen` both shipped. 5 mortgage simulators. 4 arbitrages. 3 disability screens. 5 "independants" screens. A gender-gap screen with 6 sliders. Achievements. Streaks. Milestones. A fiscal comparator. A financial report V2. A score reveal.

**This is not one product. This is three products bolted together by goodwill and sprint numbers:**

1. A retirement calculator (LPP/3a/arbitrages) — built to impress the founder
2. A 22-35 optimization toolkit (mortgage, fiscal, independants) — built from roadmap backlogs
3. A chat-first protection coach (Identity v2) — the actual mission

The Identity document describes product #3. The code ships products #1 and #2 and smuggles #3 in through a chat tab. That is the mismatch. That is why nothing fits.

**My job is to kill products #1 and #2 down to their load-bearing parts and rebuild everything as product #3.**

---

## Deliverable A — The MINT-in-one-sentence test

### The sentence

> **MINT is a calm, pocket-sized Swiss intelligence that translates any financial document, decision, or life event into plain-language implications — before you sign, not after.**

That is the product. Everything else dilutes it.

Three things this sentence tells us:

1. **The unit of value is a translated decision**, not a projection, not a dashboard, not a score.
2. **The trigger is always user-initiated or contract-initiated** ("before you sign"). MINT does not volunteer 47 simulators hoping you pick one.
3. **The surface is conversational + document-first**. Chat is the loom; documents (contracts, payslips, certificats) are the thread.

### Category test — what fits, what dilutes

| Category | # screens | Fits sentence? | Verdict |
|---|---|---|---|
| **Coach chat + history + lightning menu** | 3 | Yes — this IS the product | CORE |
| **Document scan + extraction review + vault** | 5 | Yes — feeds the translation engine | CORE |
| **Arbitrage (rente/capital, location/propriété)** | 4 | Partial — only if conversational, not 4 static screens | MERGE → 1 |
| **LPP deep (EPL, rachat, libre passage)** | 3 | Partial — valuable but must be chat-triggered | MERGE → 1 |
| **Mortgage simulators (5 of them)** | 5 | No — 5 screens for "buying a home" is a calculator app | MERGE → 1 |
| **3a deep (comparator, real return, staggered, retroactive)** | 4 | No — this is calculator-app scope creep | MERGE → 1 |
| **Life events (mariage, naissance, divorce, décès…)** | 7 | No — life events are *conversations*, not dedicated screens | MERGE → 1 shared flow |
| **Independants (5 screens)** | 5 | No — same as life events, archetype ≠ dedicated UI | MERGE → 1 |
| **Segments (gender-gap, frontalier)** | 2 | No — segmentation by gender violates anti-shame principle | KILL |
| **Disability (3 screens)** | 3 | No — one protection gap screen is enough | MERGE → 1 |
| **Debt prevention (3 screens)** | 3 | Partial — safe-mode is critical, but 3 screens is 2 too many | MERGE → 1 |
| **Achievements / streaks / milestones / score reveal** | 2 | No — gamification violates anti-shame, no social comparison | KILL |
| **Cantonal benchmark** | 1 | No — social comparison, even if anonymized, dilutes | KILL |
| **Fiscal comparator, financial report V2, portfolio** | 3 | No — these are "dashboard thinking" | KILL or MERGE |
| **Ask MINT (RAG Q&A)** | 1 | No — duplicates coach chat | KILL |
| **Open banking (hub, consents, transactions)** | 3 | Deferred — reward flow, post-v1 | NICE-TO-HAVE |
| **Couple / household** | 2 | Yes — couple is a real Swiss reality | CORE (1 screen) |
| **Budget container + orphan budget** | 2 | Yes — foundational, but the facade is literally broken | MERGE → 1 real screen |
| **Auth (login, register, forgot, verify)** | 4 | Infra — keep all 4 | CORE infra |
| **Settings (byok, slm, langue, privacy, about)** | 5 | Infra — merge into one settings hub | MERGE → 1 |
| **Admin (analytics, observability)** | 2 | Internal — not user-facing, exclude from count | OUT OF SCOPE |
| **Onboarding (data block enrichment)** | 1 | Keep but rethink | VALUABLE |
| **Landing + retirement dashboard + timeline + confidence + profile bilan** | 5 | Too many "home" surfaces | MERGE → 1 |

**Of 95 screens, product-fit analysis says ~25 survive.** The rest are killed, merged, or deferred.

---

## Deliverable B — 7 product principles for navigation

These are non-negotiable filters. If a screen fails any one, it dies.

### 1. Every screen must answer a question the user *already has in their head*

Not a question MINT invented. If the screen exists because an engineer thought "we should have a cantonal move simulator", it dies. The user does not wake up thinking "I need a cantonal move simulator." They wake up thinking "I just got a job offer in Zurich — will I actually be richer?" The former is a tool; the latter is a conversation.

### 2. If a screen has more than 3 inputs before the first insight, it is not MINT — it is a calculator

The gender-gap screen has 6 sliders. The first-job screen has 4 inputs. These are calculators dressed in MINT skin. The Identity doc says *"toilet test: utilisable en 20 secondes"*. Six sliders is not 20 seconds.

### 3. Every destination must have a reason to exist *independent of the chat*

If the only way to reach a screen is via a response card in chat, and the screen adds nothing the chat couldn't have shown inline, the screen is waste. It should be a rich message, not a screen. Currently 40+ routes are shims to the chat — this is the system telling us it wants to collapse.

### 4. No screen may show gamification, badges, streaks, or peer comparison

This is doctrinal, not preference. CLAUDE.md § Compliance: "No-Social-Comparison". MEMORY.md `feedback_anti_shame_situated_learning`: "Never display levels/badges/comparisons". The achievements + streaks + cantonal benchmark + score reveal screens *directly contradict the company's own written doctrine*. They must die.

### 5. Every screen must honor the 4-layer engine: fact → translation → personal implication → question to ask

This is the product's soul. If a screen shows numbers without translating them into life implications and giving the user a question to ask before signing, it is not a MINT screen — it is a fintech screen. This kills 80% of the current simulators, which stop at layer 1 (numbers).

### 6. Navigation is a *consequence* of conversation, not a sibling of it

The moment you add tabs, hubs, and drawers to a chat-first product, you have admitted the chat doesn't work. MINT should have **one primary surface (the coach)** and **one escape hatch (document vault + profile)**. Everything else appears *in response to a conversation*, not in parallel to it.

### 7. No screen may exist if its empty state is "Faire mon diagnostic" → chat

If a screen's default state is to send the user back to the place they came from, the screen is a facade. Delete it. The Budget loop is the most honest bug in the codebase — it is the architecture telling you out loud that the screen should not exist as a standalone route.

---

## Deliverable C — The kill list

Brutal. 95 screens → 26 survive → 69 die, merge, or defer.

### CORE (14 screens — must exist in v1)

| Screen | Why |
|---|---|
| `landing_screen` | Entry point, brand moment |
| `auth/login` + `register` + `forgot_password` + `verify_email` | Infra, 4 screens, non-negotiable |
| `coach/coach_chat_screen` | THE product |
| `coach/conversation_history_screen` | Memory of past translations |
| `document_scan/document_scan_screen` | Feed the engine |
| `document_scan/extraction_review_screen` | Trust via user correction |
| `documents_screen` (vault) | "Mes documents traduits" — second home |
| `profile/financial_summary_screen` (bilan) | The user's living profile, read-mostly |
| `profile/privacy_control_screen` | "Ce que MINT sait de toi" — compliance + trust |
| `onboarding/data_block_enrichment_screen` | Progressive precision, chat-invoked |
| `household_screen` + `accept_invitation` | Couple = real Swiss life, 2 screens justified |

### VALUABLE (5 screens — exist as secondary, reachable but rarely primary)

| Screen | Why — 1 per life-archetype, not 18 |
|---|---|
| **Unified Decision Canvas** (replaces all 4 arbitrages + rente/capital + location/propriété) | ONE canvas that takes two options side-by-side, triggered by chat. Not 4 screens. |
| **Unified Life Simulator** (replaces all 7 life events + first-job + unemployment + expatriation) | ONE flow: "Un événement a changé dans ta vie → dis-m'en plus". Chat-driven. |
| **Unified Protection Gap** (replaces 3 disability + coverage + lamal) | ONE screen: "Si demain tu ne pouvais plus travailler/tu tombais malade/tu mourais — voici les 3 trous dans ton filet." |
| **Unified Prévoyance Planner** (replaces 3a deep ×4 + LPP deep ×3 + retirement dashboard + decaissement + succession) | ONE planner, chat-invoked, with 4 tabs internal: 3a, LPP, retrait, succession. Not 12 screens. |
| **Unified Housing Decision** (replaces all 5 mortgage screens) | ONE: "Je veux acheter / vendre / arbitrer" → one flow, internal tabs for affordability, amortization, SARON, imputed rental, EPL. Not 5 routes. |

### NICE-TO-HAVE (defer to v2, 5 screens)

| Screen | Why defer |
|---|---|
| `open_banking/*` (hub, consents, transactions) | Reward flow, requires legal consultation, not v1 |
| `bank_import_screen` | OCR is enough for v1 |
| `admin_analytics` + `admin_observability` | Internal only, not user-facing |
| `education/comprendre_hub` + `theme_detail` | Education should live inside chat as inserts, not as a separate hub. Defer unless usage proves standalone. |

### KILL (24 screens — delete with prejudice)

| Screen | Why it dies |
|---|---|
| `achievements_screen` | Violates no-social-comparison, no-gamification. Anti-shame doctrine. |
| `ask_mint_screen` | Duplicates coach_chat. Sprint history: shipped twice. Pick one. |
| `cantonal_benchmark_screen` | Social comparison by canton = shame machine. Banned. |
| `score_reveal_screen` | "Score" framing is the gamification trap. Replace with 4-layer translation. |
| `gender_gap_screen` | Segmenting by gender is a lecture, not a translation. Concept lives inside couple/prévoyance flows. |
| `financial_report_v2` | "Exhaustive report" is dashboard thinking. Value is in translations, not PDFs. |
| `portfolio_screen` | MINT is not a portfolio tracker. Out of scope. |
| `timeline_screen` | Calendar-of-insights is a 2027 idea, not v1. Dies now, returns never as a top-level. |
| `confidence_dashboard_screen` | Confidence is a *property of every screen*, not a screen itself. Kill the dedicated one. |
| `fiscal_comparator_screen` | Fiscal lives inside Housing / Life Simulator / Prévoyance. |
| `consumer_credit_screen` | Debt = safe-mode, no consumer-credit simulator. Ethically dubious. |
| `simulator_leasing` + `simulator_compound` + `simulator_3a` + `job_comparison` | Generic simulators are calculator-app scope creep. Die. |
| `retirement_dashboard_screen` | Contradicts "MINT is not a retirement app". Dashboard thinking. |
| `frontalier_screen` + `independant_screen` + `expat_screen` | Archetype ≠ dedicated screen. Archetype modifies *every* chat response. |
| `independants/avs_cotisations` + `ijm` + `pillar_3a_indep` + `dividende_vs_salaire` + `lpp_volontaire` | Same: archetype is a *modifier*, not a sidebar section. All 5 die. |
| `debt_prevention/debt_ratio` + `debt_risk_check` + `help_resources` + `repayment_screen` + `safe-mode dedicated` | Debt lives inside one "Safe Mode" screen triggered automatically. 4 screens → 1. |
| `mortgage/*` (5 screens) | Merged into Unified Housing Decision. |
| `arbitrage/*` (4 screens) | Merged into Unified Decision Canvas. |
| `lpp_deep/*` + `pillar_3a_deep/*` (7 screens) | Merged into Unified Prévoyance Planner. |
| `life-event/*` + `mariage` + `naissance` + `concubinage` + `divorce` + `deces_proche` + `demenagement_cantonal` + `donation` + `housing_sale` + `first_job` + `unemployment` + `expatriation` | Merged into Unified Life Simulator. |
| `disability/*` (3 screens) + `coverage_check` + `lamal_franchise` | Merged into Unified Protection Gap. |
| `budget_container_screen` (facade) | The loop bug IS the product signal. Delete the facade. Route `/budget` to `BudgetScreen` directly. |
| `document_scan/avs_guide` + `document_scan/document_impact` | Merged into `document_scan` as internal steps, not separate routes. |
| `document_detail_screen` | Merged into vault as an inline expansion, not a route. |
| `byok_settings` + `slm_settings` + `langue_settings` + `about` + `admin_*` + `privacy_control` (partial) | Merge all 5+ into ONE `settings_screen` with sections. |
| `coach/cockpit_detail` + `coach/annual_refresh` | Already archived per Wire Spec V2. Confirm deletion. |

### The MERGE rationale — why fewer screens is better

Every time you create a dedicated screen for a narrow case (divorce vs concubinage vs décès), you:

1. Force the user to self-diagnose before they get value ("am I in the divorce flow or the décès flow?")
2. Duplicate code (each screen has its own form, own hypotheses panel, own disclaimer footer)
3. Fragment the voice (each screen ends up written slightly differently)
4. Create the 95-screen problem

A **Unified Life Simulator** works because the chat already knows what event you mentioned. The user says "on se sépare" and MINT opens the canvas pre-filled for séparation. Same canvas, different pre-fill. This is how Cleo handles 40 money topics with 5 screens. It is how Linear handles 300 workflows with 8 views.

---

## Deliverable D — The v1 minimum viable navigation (26 screens)

This is the MINT that ships. Each screen has one job.

### Primary surfaces (3)

1. **Landing** — *User comes here to understand what MINT does in 8 seconds and decide whether to open the chat.*
2. **Coach Chat** — *User comes here to translate a document, decision, or life event into plain language.*
3. **Profile (Mon aperçu)** — *User comes here to see what MINT currently knows about them and quietly correct it.*

### Conversational destinations (5 — chat-invoked, never browsed)

4. **Unified Decision Canvas** — *User arrives here because the chat offered "voyons les deux côtés" on an arbitrage they raised.*
5. **Unified Life Simulator** — *User arrives here because they told the chat about a life event and MINT needs 3 inputs to personalize.*
6. **Unified Protection Gap** — *User arrives here because the chat flagged a hole in their filet de sécurité.*
7. **Unified Prévoyance Planner** — *User arrives here because the chat is helping them think through a multi-year prévoyance question.*
8. **Unified Housing Decision** — *User arrives here because they're thinking about buying, selling, or refinancing and needs real numbers.*

### Document & memory (3)

9. **Document Scan** — *User comes here to upload a contract they don't understand.*
10. **Extraction Review** — *User comes here to confirm what MINT read from their document.*
11. **Document Vault** — *User comes here to find the document they scanned last month and see the translation again.*

### Profile & data (3)

12. **Onboarding (3-question minimum)** — *User comes here once, to give MINT the bare minimum to personalize.*
13. **Data Block Enrichment** — *User comes here because the chat asked "veux-tu préciser ceci maintenant ?" — single-purpose mini-form.*
14. **Privacy Control** — *User comes here to see every field MINT knows and delete what they want.*

### Couple (2)

15. **Household** — *User comes here to add a partner and see combined implications.*
16. **Accept Invitation** — *Partner arrives here via a code to join the household.*

### Conversation memory (1)

17. **History** — *User comes here to find a past conversation with MINT.*

### Infra — auth (4)

18. **Login**
19. **Register**
20. **Forgot Password**
21. **Verify Email**

### Infra — settings (1 merged screen with sections)

22. **Settings** — *User comes here to switch language, configure BYOK, toggle privacy, read about/legal/version. Sections, not 5 routes.*

### Safety (1)

23. **Safe Mode** — *User lands here automatically when toxic debt is detected. Disables optimizations, focuses on debt prevention + help resources. ONE screen, not 3.*

### Deferred v2 but worth reserving a slot (3)

24. **Open Banking Hub** (reserved, gated)
25. **Open Banking Consent** (reserved, gated)
26. **Admin** (internal, not part of user nav)

**Total: 23 user-facing screens + 3 reserved/infra = 26.**

The ratio matters: **3 primary + 5 conversational destinations + 3 document + 3 profile + 2 couple + 1 history + 1 safe mode = 18 screens carry 100% of the user value.** The rest is auth and settings.

---

## Deliverable E — Brand–product fit check

CLAUDE.md gives five brand attributes and five principles. Let's audit the current 95-screen reality against each.

### "Calme" (calm)

- **Current**: 95 screens is not calm. A user opening the app is confronted by 18 life events, 7 hubs, 5 simulators per topic. Choice overload = anxiety. Anti-calm.
- **Embodied version**: One primary surface (chat). Everything else appears only when the conversation summons it. Calm = absence of choice paralysis.

### "Précis" (precise)

- **Current**: Precision exists at the *calculator* level (financial_core/ is excellent), but the UI layer is imprecise — multiple screens solve the same question, each with different hypotheses panels. A precise product has exactly one answer per question.
- **Embodied version**: One Unified Prévoyance Planner. One Decision Canvas. The precision lives in the engine and the chat, not in 12 overlapping surfaces.

### "Fin" (subtle, refined)

- **Current**: Screens like achievements, score reveal, gender gap, cantonal benchmark are the opposite of fin. They are loud product-manager instincts from 2019 consumer fintech.
- **Embodied version**: Remove all gamification and social comparison. The refinement shows up in the micro-copy of the chat, the toilet test, the 4-layer translation. *Fin* means you do less, better.

### "Rassurant" (reassuring)

- **Current**: A broken budget loop is not reassuring. A back button that teleports you somewhere unexpected is not reassuring. 21 `safePop` call sites that each fall back to the chat is not reassuring.
- **Embodied version**: Predictable navigation (every back button goes where the user came from), explicit confidence bands, honest "I don't know yet" states. Reassurance is engineered.

### "Net" (sharp, crisp)

- **Current**: Facades, redirects, orphans, shim routes. Net is the opposite of shim.
- **Embodied version**: 26 screens. Every route resolves to a real screen. Every screen has one purpose. Net means you can point at any pixel and explain why it exists.

### The 5 principles, mapped to architecture

| Principle | Violated by | Fixed by |
|---|---|---|
| **Parler humain** | `/decaissement`, `/3a-deep/real-return`, `/arbitrage/bilan` — names the user can't read | Rename routes to user language; hide route names entirely (chat-invoked) |
| **Réduire la honte** | Achievements, streaks, cantonal benchmark, score reveal, gender gap | Kill all of them |
| **Dialogue, pas leçon** | Education hub, theme detail, financial report V2 | Education lives *inside* chat messages, not in a separate hub |
| **Prise immédiate** | Every screen that requires 4+ inputs before an insight | Decision Canvas pre-fills from profile; 3 inputs max |
| **Doux mais tranchant** | "Optimisation de décaissement" vocabulary | Rewrite with the toilet test; if a 20-second-tired user doesn't get it, rewrite |

---

## Deliverable F — What would Cleo do (and what MINT must do differently)

### Cleo (chat-first AI money coach)

**What Cleo does right**: 90% of Cleo's value happens inside the chat thread. There is no "arbitrage hub", no "mortgage simulator", no "first job screen". Everything is a message, sometimes with a rich card, sometimes with a quick-action. Their whole product is maybe 8 screens: chat, profile, transactions, goals, roast/hype, settings. **Lesson for MINT**: collapse navigation into the conversation. Your 95 → 26 is still too many.

**What MINT must do differently**: Cleo is anglo, casual, roast-based, and sells overdraft products. MINT is Swiss, protection-first, read-only, and forbidden from ranking. The *tone* must stay *doux mais tranchant* — never roast, never shame. And MINT handles *contracts*, which Cleo does not. So MINT's document vault + extraction review is a genuine differentiator Cleo doesn't have.

### Wealthsimple

**What Wealthsimple does right**: Onboarding asks 3 questions before showing value, then reveals precision progressively. No "fill out 40 fields before seeing anything". **Lesson for MINT**: the 4 questions d'or (canton/âge/revenu/statut) is exactly right. Do not regress on this.

**What MINT must do differently**: Wealthsimple is a brokerage. It recommends specific products. MINT *cannot* (LSFin art. 8). MINT must translate decisions without naming instruments. The 4-layer engine is MINT's answer to "how do you add value without recommending products"? It works — but only if every screen honors it.

### Acorns

**What Acorns does right**: Simple metaphors (round-ups, jars, gifts). One idea per screen.
**What MINT must do differently**: Acorns is infantilizing-by-design (cartoonish, gamified). That is literally banned in MINT doctrine. **Avoid**: any "watch your tree grow" metaphor, any mascot, any badge. MINT's metaphor is *correspondence with a trusted friend who reads contracts for a living*, not a savings toy.

### YNAB

**What YNAB does right**: The product has a *method* ("every dollar a job"). The navigation exists *to serve the method*. Screens are few, purposeful, and educational.
**Lesson for MINT**: MINT needs a stated method too. The Identity doc has it — the 4-layer engine. But the current 95 screens do not visibly follow any method. **Fix**: every screen header should quietly signal which layer it's operating at (fact / translation / implication / question). This is an editorial discipline, not a visual one.

### Finanzguru (DE)

**What Finanzguru does right**: Open banking + contract analysis is their core loop. They detect insurance and subscriptions and tell you what to cancel. German-efficient UI, few screens, calm tone.
**Lesson for MINT**: The *contract analysis* half of MINT is the closest product cousin. Study how Finanzguru surfaces findings *without* naming products — they say "an insurance of type X, Y years, Z CHF/month, cancel by date W" — this is exactly MINT's 4-layer engine applied to insurance. Same move, applied to pillar 3a and LPP.
**Differentiator**: MINT's chat layer means users can *ask follow-up questions* Finanzguru can't answer ("so what do I ask my pension fund?"). That is MINT's wedge.

### The synthesis — the one architectural move

If you look across Cleo, Wealthsimple, Acorns, YNAB, and Finanzguru, the best-in-class pattern is the same:

**One conversational or method-driven primary surface + one profile/vault + 5-8 reachable tools + ruthless deletion of everything else.**

MINT currently has: one conversational surface + one profile + **65+ reachable tools + 30 orphan/facade/zombie screens**. The deletion hasn't happened yet. That's the gap.

---

## The last word — to the founder

You asked for experts who tell you what to keep and what to kill. Here is my verdict as a senior product strategist who has shipped consumer fintech:

**Your Identity document is a 10/10. Your code is a 5/10 because it ships three products instead of one.** The fix is not to rewrite the Identity. The fix is to delete 69 screens and let the 26 that remain embody what the Identity already says.

The loop bug in the Budget screen is not a navigation bug — it is the codebase literally speaking out loud: *"this screen should not exist; please route me back to where I came from."* Listen to it.

Kill `achievements`, `streaks`, `cantonal_benchmark`, `score_reveal`, `gender_gap`, `ask_mint`, `retirement_dashboard`, `financial_report_v2`, `portfolio`, `timeline`, `confidence_dashboard`, `fiscal_comparator`, `consumer_credit`, every generic simulator, every dedicated life-event screen, every independants screen, every mortgage simulator beyond one, every arbitrage beyond one, every LPP-deep beyond one, every 3a-deep beyond one, every disability beyond one, every debt-prevention beyond one.

Merge the survivors into 5 Unified flows (Decision Canvas, Life Simulator, Protection Gap, Prévoyance Planner, Housing Decision). Keep the 3 primary surfaces (Landing, Coach, Profile), the 3 document screens, the 3 profile screens, couple, history, auth, and a single merged settings screen.

**26 screens. One product. One voice. One promise: "Mint te dit ce que personne n'a intérêt à te dire."**

Everything else is noise your user didn't ask for and your brand can't afford.

---

*End of strategist memo. Next deliverable should be a screen-by-screen kill ticket list so execution can begin.*

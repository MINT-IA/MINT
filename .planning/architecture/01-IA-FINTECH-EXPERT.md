# MINT — Information Architecture (Fintech Expert View)

> Author perspective: Senior IA lead, fintech consumer mobile (Revolut, Monzo, N26, Cleo, Wealthfront background).
> Date: 2026-04-11
> Scope: mobile app MINT, Swiss financial protection + education.
> Source docs consulted: `CLAUDE.md`, `docs/MINT_IDENTITY.md`, `docs/NAVIGATION_GRAAL_V10.md`, `docs/MINT_UX_GRAAL_MASTERPLAN.md`, `visions/vision_product.md` (flagged obsolete), `.planning/SCREEN_INVENTORY.md`, `.planning/SCREEN_MAP.md`.
> This document is opinionated. It disagrees with parts of `NAVIGATION_GRAAL_V10.md` where I think the spec is wrong for MINT's stated identity.

---

## 0. The argument in one paragraph

MINT's own identity document (`MINT_IDENTITY.md`) says the product is "une intelligence calme, intime, fiable, dans la poche" and the tagline is "Mint te dit ce que personne n'a intérêt à te dire". That is not a dashboard product. It is not a tab-navigated explorer. It is a **voice in your pocket** that protects you at decision moments. `NAVIGATION_GRAAL_V10.md` (4 tabs + 7 hubs + Dossier) tries to reconcile this ambition with a code base that grew as a catalog of 95 simulators — and it ends up exposing the catalog on floor 1. The compromise is visible in `SCREEN_MAP.md`: everything silently routes back to `/coach/chat` because the team *knows* the chat is the product, but the shell doesn't admit it. The result is the Budget infinite loop (LOOP-01), the 40+ dead redirects to chat, and 21 `safePop()` sites that fall back to chat because there is no other coherent "home". **The architecture is already coach-first in the code. The navigation shell should stop pretending it isn't.** I propose a chat-first shell with a structured "Monde" surface for autonomous exploration, a persistent Dossier, and a radically smaller set of surfaces that users can mentally map. Everything else is a Tool opened in context — never a destination.

---

## Deliverable A — Target IA (from zero)

### Top-level navigation (the shell)

**Decision: 2-surface shell with a persistent Coach layer, not 4 tabs.**

```
┌─────────────────────────────────────────┐
│  [Profile avatar]      MINT      [+]    │  ← top bar (always)
├─────────────────────────────────────────┤
│                                         │
│         COACH (home surface)            │
│    conversation + daily cap card       │
│                                         │
├─────────────────────────────────────────┤
│  [ Coach ]           [ Monde ]          │  ← 2 tabs only
└─────────────────────────────────────────┘
```

- **Coach** = the home. The opening surface when you launch the app. Conversation-first, but the top of the scroll is NOT an empty chat input — it's the "Cap du jour" card (1 phrase, 1 number, 1 action, as specified in the masterplan §10) followed by a single conversation thread. The chat isn't a chatbot screen, it's the *reading surface* of a living coach.
- **Monde** = the structured exploration surface. Swiss financial life as a navigable world, organized by life event, NOT by financial instrument. This is where people who refuse to talk to the AI can still find their situation.
- **Profile avatar (top-left)** opens the **Dossier drawer** — profile, documents, couple, confiance, consentements, settings. Not a tab, because it is a utility, not a destination the user visits weekly.
- **+ (top-right)** is the **Capture action**. Scan document, import statement, add a fact. Contextual, always reachable, but not a FAB (see §5 of NAV_GRAAL which I agree with on this one).

Why 2 tabs, not 4:
- Coach + Monde cover **100%** of the use cases. Dossier is a utility (drawer). Aujourd'hui and Coach in NAV_GRAAL_V10 are effectively the same mental surface once you accept that "Cap du jour" lives at the top of the Coach stream — splitting them creates two homes, and MINT's own doctrine ("une intelligence dans la poche") argues for one.
- Apple's HIG (Apple, WWDC22 Designing for iPad navigation) is explicit: tabs should represent **top-level content the user actively moves between**. A user does not move between Aujourd'hui and Coach every session — they either converse or they don't. Two tabs that are siblings of the same flow is a navigation smell.
- More tabs = more places to hide features = more facades (see Budget LOOP-01 as the symptom).

### Hierarchy (3 levels max)

```
LEVEL 1 — always visible
  ├── Coach (tab)           → conversation + cap du jour
  ├── Monde (tab)           → 6 life domains
  ├── Dossier (drawer)      → profile, documents, confiance, couple, consents, settings
  └── Capture (top-right +) → scan, import, manual entry

LEVEL 2 — one tap away
  ├── Coach stream items    → expand a cap, open a response card, inline widgets
  ├── Monde domains         → Commencer · Aimer · Habiter · Gagner sa vie · Protéger · Transmettre
  ├── Dossier sections      → Mes données · Mes documents · Mon couple · Ma confiance · Mes réglages
  └── Capture modes         → Scanner · Importer · Ajouter · Photo + question

LEVEL 3 — two taps away (destinations + tools)
  ├── Situations (life events, 18 total) → Mariage, Divorce, Premier emploi, etc.
  ├── Tools (simulators, ~60)            → Rente vs Capital, EPL, Rachat LPP, etc.
  ├── Documents (individual)              → Certificat LPP CPE, Bulletin de salaire
  └── Settings panels                     → BYOK, SLM, Privacy, Lang, Couple invites
```

**Hard rule**: no user can navigate to a tool except via (a) a life event context in Monde, (b) a coach suggestion, or (c) a direct deep link from a notification/email. **Tools are never discoverable on their own.** The current `/tools` library screen, the current `/3a-deep/*` routes surfaced in Explorer's list-of-calculators — these are anti-patterns. They expose the code base taxonomy to the user, which `NAV_GRAAL_V10` §3 correctly forbids but its own §6.3 then re-introduces by listing 7 hubs with flat calculator lists.

### Mental model anchor

**ONE sentence the user should be able to complete:**
> "MINT is the voice in my pocket that protects me before I sign something I'll regret."

That's it. Not "MINT is my financial dashboard". Not "MINT is my retirement app". Not "MINT is my budget tracker". The core affordance is **protection through translation at decision moments**. Everything in the IA must serve that sentence.

Secondary anchors:
- "If I don't know what to do, I talk to it" → Coach tab.
- "If I want to see how my life maps to Swiss finance, I browse" → Monde tab.
- "If I want to check what MINT knows about me, I swipe" → Dossier drawer.
- "If I have a piece of paper I don't understand, I shoot it" → Capture +.

Four anchors, four fingers. That's the entire user mental model.

### Screen taxonomy (by purpose)

**HOME / HUB screens (5 total)**
1. `CoachHome` — the main Coach tab with Cap du jour at top of stream + conversation below. Replaces `PulseScreen`, `CoachChatScreen` entry, and `AskMintScreen`. **One screen, not three.**
2. `MondeHome` — entrance to the 6 domains, not 7. Rename Explore to Monde (the product isn't about exploring a catalog, it's about navigating a life).
3. `Monde_Situation` (× 6 domains, technically 1 templated screen) — e.g. `Monde > Gagner sa vie`. Opens to ~3 featured life events + "voir tout".
4. `LifeEventHub` (× 18 life events, 1 templated screen) — e.g. `Monde > Aimer > Mariage`. Opens a Roadmap Flow (as per masterplan §8 template 3).
5. `DossierHome` — the drawer landing page. List of sections.

**COACH / DIALOGUE screens (1)**
- `CoachHome` is the only dialogue screen. `ConversationHistoryScreen`, `CoachCheckinScreen`, `AnnualRefreshScreen`, `CockpitDetailScreen`, `AskMintScreen`, `WeeklyRecapScreen` — **all collapse into the Coach stream**. Weekly recap is a message type. History is a drawer pulled from the coach top bar. Cockpit detail is an expandable card inline. The idea that these need separate routes is a code-base-centric taxonomy, not a user mental model.

**TOOLS / SIMULATOR screens (~50 kept, organized by template, not by directory)**
- All simulators obey the 4 master templates from `MINT_UX_GRAAL_MASTERPLAN.md` §8: Hero Plan (HP), Decision Canvas (DC), Roadmap Flow (RF), Quiet Utility (QU).
- They are **never destinations**. They open as a modal sheet over Coach or Monde, not as routes in the tab stack. This matches the current `ChatDrawerHost` pattern (which `SCREEN_MAP.md` §2.3 confirms works well for `/rachat-lpp` as a drawer).
- Dismissing a tool **always** returns to the surface that opened it. This kills the `safePop → /coach/chat` fallback hack (NAV-01 in SCREEN_MAP.md).

**PROFILE / SETTINGS screens (grouped under Dossier)**
- `Dossier > Mes données` (profil + household + confiance, merged — replaces `/profile`, `/profile/bilan`, `/confidence`)
- `Dossier > Mes documents` (replaces `/documents`, `/documents/:id`, `/bank-import`)
- `Dossier > Mon couple` (replaces `/couple`, `/couple/accept`)
- `Dossier > Mes permissions` (replaces `/profile/consent`, `/profile/privacy-control`, `/open-banking/consents`)
- `Dossier > Réglages` (replaces `/profile/byok`, `/profile/slm`, `/settings/langue`, `/about`)

**ONBOARDING / DATA COLLECTION screens (3, not 8)**
- `Welcome` (landing, pre-auth)
- `QuickStart` (3 questions: canton, année de naissance, revenu brut mensuel — as per masterplan)
- `PremierEclairage` (first personalized insight, screen after QuickStart)
- All other onboarding variants (`/advisor/*`, `/onboarding/smart`, `/onboarding/minimal`, `/onboarding/enrichment`) are **killed**. The `/data-block/:type` enrichment screen is merged into `Dossier > Mes données` as inline edit.

**COMPLIANCE / LEGAL screens (1)**
- `About` — version + legal links + disclaimer + sources. One screen, opened from Dossier > Réglages. Law-by-law references live in contextual info sheets attached to each insight, not as a standalone legal library.

### Why this works for FINTECH specifically

**Paragraph 1 — Financial mental load.** Fintech users arrive with shame, not curiosity. Every research paper on financial literacy (FINMA 2024/2025 report, OECD PISA financial literacy) says the same: people who most need protection are the ones who avoid financial UIs. Tab-navigated apps force users to pick a bucket before they know what they want. Chat-first apps (Cleo is the industry proof) invert this: the user never picks a bucket, they just say what's going on, and the product maps it. MINT's identity explicitly wants this: "L'utilisateur peut répondre avec ses mots. Il peut ne pas connaître les termes." A 4-tab shell forces the user to learn "Aujourd'hui vs Coach vs Explorer vs Dossier" before they have shown the product anything about themselves. That's the exact opposite of "reduire la honte" (`MINT_IDENTITY.md` principle #2).

**Paragraph 2 — Trust building.** Swiss fintech users (LSFin/FINMA regulated, per `CLAUDE.md` §6) are rightly suspicious. Trust is built by **slow reveal, visible sources, and a clear opt-out**. The Dossier drawer is not a tab because users do not want a tab that shouts "we have a lot of data on you". A drawer is honest: data lives behind an avatar, the user goes get it when they want. Tabs demand attention; drawers yield control. For a protection-first product, control beats visibility.

**Paragraph 3 — The 18-99 year old problem.** `CLAUDE.md` §1 is explicit: MINT must work for an 18-year-old starting their first job AND a 58-year-old planning retirement, with the same quality bar, without segmenting by age. Tab labels are inherently age-signaling: "Aujourd'hui" reads young (Instagram, Apple Fitness), "Dossier" reads older (insurance broker), "Explorer" reads generic-fintech. A 2-tab shell (Coach / Monde) + Dossier drawer is **generation-neutral**. Everyone talks. Everyone browses their own life. Everyone manages their records. No age signal in the shell itself.

**Paragraph 4 — The 18-life-events problem.** Retirement is 1 of 18 life events. The current NAV_GRAAL §6.3 lists Retraite first in the hub list, which immediately frames the product as retirement-led. `Monde` with domains in life order — **Commencer · Aimer · Habiter · Gagner sa vie · Protéger · Transmettre** — is life-coded, not instrument-coded. A 28-year-old opens "Commencer" (first job, first 3a) and a 58-year-old opens "Transmettre" (succession, donation), but neither sees the other's surface until they're ready for it. This is the NAV_GRAAL's goal, but its 7 hubs (Retraite, Famille, Travail, Logement, Fiscalité, Patrimoine, Santé) expose the instrument taxonomy (Fiscalité, Patrimoine) again. Drop them.

**Paragraph 5 — Anti-catalog discipline.** The most important single rule for a protection-first fintech: **never let the user see a list of tools**. The moment you show 15 simulators in a grid, you've taught the user that MINT is a calculator app, and the "Juste quand il faut" promise is broken. The current `/tools` route, the `3a-deep/*` deep links visible in the route map, the Explorer hubs listing calculators — all of these are catalog exposures. In my proposed IA, the user can reach a simulator ONLY via: (a) a life event hub that contextualizes why this simulator is relevant right now, or (b) a coach suggestion that explains what this simulator will answer. The simulator library is a runtime concept, not a navigation concept.

---

## Deliverable B — Mapping the 95 current screens

Legend:
- **KEEP** — fits the target IA, used as-is (may be restyled per masterplan templates)
- **RELOCATE** → `[target position]`
- **MERGE WITH** `[other screens]`
- **KILL** — does not fit, redundant, or bad UX
- **DEFER** — out of scope for v1, maybe later

| # | File | Verdict | Target position / rationale |
|---|---|---|---|
| 1 | about_screen.dart | KEEP | Dossier > Réglages > About |
| 2 | accept_invitation_screen.dart | RELOCATE | Dossier > Mon couple > Accepter une invitation |
| 3 | achievements_screen.dart | KILL | Contradicts "reduce shame" principle. No badges, no gamification competitive surface. |
| 4 | admin_analytics_screen.dart | KEEP | Hidden behind feature flag, not user-facing. No IA impact. |
| 5 | admin_observability_screen.dart | KEEP | Same as above. Feature flag only. |
| 6 | affordability_screen.dart | RELOCATE | Tool (modal) opened from Monde > Habiter > Acheter un logement. Template: Decision Canvas. |
| 7 | allocation_annuelle_screen.dart | RELOCATE | Tool opened from Monde > Gagner sa vie > Optimiser mon année fiscale. Decision Canvas. |
| 8 | amortization_screen.dart | RELOCATE | Tool opened from Habiter > Hypothèque. Decision Canvas. |
| 9 | annual_refresh_screen.dart | MERGE WITH | CoachHome — becomes a Coach stream message type ("Refresh annuel disponible"), not a screen. |
| 10 | arbitrage_bilan_screen.dart | KILL | Exposes internal "arbitrage" taxonomy. Functionality merges into the coach's Cap du jour + specific life-event hubs. |
| 11 | ask_mint_screen.dart | KILL | Duplicate of coach_chat_screen. Merge into CoachHome. NAV_GRAAL_V10 already flags this for absorption; do it now, not in Phase 2. |
| 12 | avs_cotisations_screen.dart | RELOCATE | Tool opened from Monde > Gagner sa vie > Indépendant. Decision Canvas. |
| 13 | avs_guide_screen.dart | RELOCATE | Capture > Scanner > AVS guide. Roadmap Flow inside the capture sheet. |
| 14 | bank_import_screen.dart | MERGE WITH | Capture > Importer. One unified capture surface, not a standalone route. |
| 15 | budget_container_screen.dart | KILL | FACADE. Confirmed broken in SCREEN_MAP.md LOOP-01. Delete it entirely. |
| 16 | budget_screen.dart | KEEP | Relocate as Tool opened from Monde > Commencer > Mon budget. Template: Hero Plan + inline Decision Canvas. Becomes the ONLY budget route. |
| 17 | byok_settings_screen.dart | RELOCATE | Dossier > Réglages > IA (ma clé) |
| 18 | cantonal_benchmark_screen.dart | KILL | "Social comparison" is explicitly banned in `CLAUDE.md` §6 ("top 20% des Suisses → BANNED"). Cantonal benchmark is a social-comparison tool by definition. Kill it. |
| 19 | coach_chat_screen.dart | KEEP | Becomes the CoachHome surface (the main tab). Not a screen pushed from anywhere. |
| 20 | cockpit_detail_screen.dart | KILL | "Cockpit" is a dev-centric metaphor. MINT is not a cockpit. Content merges into Cap du jour card and Dossier > Ma confiance. |
| 21 | comprendre_hub_screen.dart | KILL | Education hub as a destination contradicts "pas de catalogue". Education content inlines into each life event hub as a contextual insert. |
| 22 | concubinage_screen.dart | RELOCATE | Life event under Monde > Aimer > Concubinage. Template: Roadmap Flow. |
| 23 | confidence_dashboard_screen.dart | RELOCATE | Dossier > Ma confiance. Renamed from "dashboard" to "confiance" — dashboard is a cockpit word. |
| 24 | consent_screen.dart | RELOCATE | Dossier > Mes permissions > Open Banking (only if OB enabled). |
| 25 | consumer_credit_screen.dart | RELOCATE | Tool opened from Monde > Commencer > Sortir d'une dette. Decision Canvas. |
| 26 | conversation_history_screen.dart | RELOCATE | Sub-surface of CoachHome, opened via top-bar button. Not a tab stack screen. |
| 27 | coverage_check_screen.dart | RELOCATE | Tool opened from Monde > Protéger > Mes assurances. Decision Canvas. |
| 28 | data_block_enrichment_screen.dart | MERGE WITH | Dossier > Mes données > [inline edit per block]. Not a separate route. |
| 29 | debt_ratio_screen.dart | RELOCATE | Tool under Monde > Commencer > Sortir d'une dette. Decision Canvas. |
| 30 | debt_risk_check_screen.dart | MERGE WITH | debt_ratio_screen + repayment_screen = one tool "Diagnostic dette" (HP + DC). Kill the split into 3 screens. |
| 31 | deces_proche_screen.dart | RELOCATE | Life event under Monde > Transmettre > Décès d'un proche. Roadmap Flow. |
| 32 | demenagement_cantonal_screen.dart | RELOCATE | Life event under Monde > Habiter > Déménager. Roadmap Flow. |
| 33 | disability_gap_screen.dart | RELOCATE | Life event under Monde > Protéger > Invalidité. Roadmap Flow. |
| 34 | disability_insurance_screen.dart | MERGE WITH | disability_gap_screen. One hub, not three. |
| 35 | disability_self_employed_screen.dart | MERGE WITH | disability_gap_screen (with archetype branching). |
| 36 | dividende_vs_salaire_screen.dart | RELOCATE | Tool under Monde > Gagner sa vie > Indépendant. Decision Canvas. |
| 37 | divorce_simulator_screen.dart | RELOCATE | Life event under Monde > Aimer > Divorce. Roadmap Flow. |
| 38 | document_detail_screen.dart | RELOCATE | Dossier > Mes documents > [document]. |
| 39 | document_impact_screen.dart | MERGE WITH | Capture flow return screen. Becomes a Coach stream message ("voici ce que ce document a débloqué"), not a standalone screen. |
| 40 | document_scan_screen.dart | RELOCATE | Capture > Scanner. Sheet, not route. |
| 41 | documents_screen.dart | RELOCATE | Dossier > Mes documents. |
| 42 | donation_screen.dart | RELOCATE | Life event under Monde > Transmettre > Donation. Roadmap Flow. |
| 43 | epl_combined_screen.dart | MERGE WITH | epl_screen. One EPL tool, not two. |
| 44 | epl_screen.dart | RELOCATE | Tool under Monde > Habiter > Acheter un logement. Decision Canvas. |
| 45 | expat_screen.dart | RELOCATE | Life event under Monde > Gagner sa vie > Expatriation. Roadmap Flow. |
| 46 | extraction_review_screen.dart | MERGE WITH | Capture flow (scan review step). Sub-surface of Capture sheet. |
| 47 | financial_report_screen_v2.dart | RELOCATE | CoachHome premium surface OR Dossier > Mon rapport. Hero Plan template. Not a standalone tab. |
| 48 | financial_summary_screen.dart | MERGE WITH | Dossier > Mes données. This is already the "bilan" — it IS the dossier home. |
| 49 | first_job_screen.dart | RELOCATE | Life event under Monde > Commencer > Premier emploi. Roadmap Flow. |
| 50 | fiscal_comparator_screen.dart | RELOCATE | Tool under Monde > Gagner sa vie > Optimiser mon année fiscale. Decision Canvas. |
| 51 | forgot_password_screen.dart | KEEP | Auth flow. Pre-shell, no IA position. |
| 52 | frontalier_screen.dart | RELOCATE | Life event under Monde > Gagner sa vie > Frontalier. Roadmap Flow. |
| 53 | gender_gap_screen.dart | RELOCATE | Tool contextually surfaced from Monde > Aimer > Mariage/Concubinage (not a standalone hub item). Hero Plan. |
| 54 | help_resources_screen.dart | RELOCATE | Sub-surface of Monde > Commencer > Sortir d'une dette (Safe Mode orientation). Quiet Utility. |
| 55 | household_screen.dart | RELOCATE | Dossier > Mon couple. |
| 56 | housing_sale_screen.dart | RELOCATE | Life event under Monde > Habiter > Vendre. Roadmap Flow. |
| 57 | ijm_screen.dart | RELOCATE | Tool under Monde > Protéger > Indépendant IJM. Decision Canvas. |
| 58 | imputed_rental_screen.dart | RELOCATE | Tool under Monde > Habiter > Hypothèque. Decision Canvas. |
| 59 | independant_screen.dart | RELOCATE | Life event hub under Monde > Gagner sa vie > Indépendance. Roadmap Flow. Container for all `/independants/*` tools. |
| 60 | job_comparison_screen.dart | RELOCATE | Tool under Monde > Gagner sa vie > Changer d'emploi. Decision Canvas. |
| 61 | lamal_franchise_screen.dart | RELOCATE | Tool under Monde > Protéger > LAMal. Decision Canvas. |
| 62 | landing_screen.dart | KEEP | Pre-auth landing, unchanged. |
| 63 | langue_settings_screen.dart | RELOCATE | Dossier > Réglages > Langue. |
| 64 | libre_passage_screen.dart | RELOCATE | Tool under Monde > Gagner sa vie > Changer d'emploi / Chômage. Decision Canvas. |
| 65 | location_vs_propriete_screen.dart | MERGE WITH | affordability_screen. One "Louer vs acheter" Decision Canvas. |
| 66 | login_screen.dart | KEEP | Auth. |
| 67 | lpp_volontaire_screen.dart | RELOCATE | Tool under Monde > Gagner sa vie > Indépendant. |
| 68 | mariage_screen.dart | RELOCATE | Life event under Monde > Aimer > Mariage. Roadmap Flow. |
| 69 | naissance_screen.dart | RELOCATE | Life event under Monde > Aimer > Naissance. Roadmap Flow. (Keeping "Aimer" as the domain is a voice choice: naissance and mariage belong to life stages of attachment, not "Famille" which sounds administrative.) |
| 70 | open_banking_hub_screen.dart | RELOCATE | Dossier > Mes permissions > Open Banking. Feature flag gated. Not a destination. |
| 71 | optimisation_decaissement_screen.dart | RELOCATE | Tool under Monde > Transmettre > Décaissement retraite. Decision Canvas. |
| 72 | pillar_3a_indep_screen.dart | RELOCATE | Tool under Monde > Gagner sa vie > Indépendant > 3a. |
| 73 | portfolio_screen.dart | KILL | MINT is not a portfolio app. Read-only means no asset tracking. Contradicts identity. |
| 74 | privacy_control_screen.dart | MERGE WITH | Dossier > Mes permissions (single page: consents + privacy + data deletion). |
| 75 | provider_comparator_screen.dart | KILL | Comparing 3a providers by name approaches "no-ranking" and LSFin advertising rules. If kept at all, it must be behind a heavy compliance filter. Kill in v1. |
| 76 | rachat_echelonne_screen.dart | RELOCATE | Tool under Monde > Transmettre > Retraite. Decision Canvas. |
| 77 | real_return_screen.dart | RELOCATE | Tool under Monde > Gagner sa vie > 3a. Decision Canvas. |
| 78 | register_screen.dart | KEEP | Auth. |
| 79 | rente_vs_capital_screen.dart | RELOCATE | Tool under Monde > Transmettre > Retraite. Decision Canvas. THE a-ha moment tool — flagship. |
| 80 | repayment_screen.dart | MERGE WITH | debt_ratio_screen tool bundle. |
| 81 | retirement_dashboard_screen.dart | KILL | "Dashboard" is the wrong metaphor. Content becomes a Cap du jour variant in CoachHome + a Hero Plan tool in Monde > Transmettre > Retraite. The standalone screen dies. |
| 82 | retroactive_3a_screen.dart | RELOCATE | Tool under Monde > Gagner sa vie > 3a (rattrapage). Decision Canvas. Flagship post-2026 feature. |
| 83 | saron_vs_fixed_screen.dart | RELOCATE | Tool under Monde > Habiter > Hypothèque. Decision Canvas. |
| 84 | score_reveal_screen.dart | MERGE WITH | PremierEclairage (onboarding). It's the same moment. |
| 85 | simulator_3a_screen.dart | RELOCATE | Tool under Monde > Gagner sa vie > 3a. Decision Canvas. Main 3a simulator. |
| 86 | simulator_compound_screen.dart | KILL | Generic compound interest calculator. Not MINT identity. Already covered inside 3a + retirement tools. |
| 87 | simulator_leasing_screen.dart | RELOCATE | Tool under Monde > Commencer > Sortir d'une dette > Leasing. Decision Canvas. |
| 88 | slm_settings_screen.dart | RELOCATE | Dossier > Réglages > IA locale. |
| 89 | staggered_withdrawal_screen.dart | RELOCATE | Tool under Monde > Transmettre > Retraite > 3a échelonné. Decision Canvas. |
| 90 | succession_patrimoine_screen.dart | RELOCATE | Life event under Monde > Transmettre > Succession. Roadmap Flow. |
| 91 | theme_detail_screen.dart | KILL | Standalone education content is a catalog. Education inlines into life event hubs. |
| 92 | timeline_screen.dart | DEFER | "Timeline" is a powerful metaphor (per vision_product.md "Financial OS Timeline-First") but orthogonal to the current screen. Defer to v2 as a separate strategic decision. |
| 93 | transaction_list_screen.dart | RELOCATE | Dossier > Mes permissions > Open Banking > Transactions. Feature flagged. |
| 94 | unemployment_screen.dart | RELOCATE | Life event under Monde > Gagner sa vie > Chômage. Roadmap Flow. |
| 95 | verify_email_screen.dart | KEEP | Auth. |

**Summary of the mapping:**
- **KEEP as-is**: 6 (auth + landing + admin)
- **RELOCATE under Monde / Dossier / Capture / Coach**: 67
- **MERGE**: 12 (mostly triples that should be one tool)
- **KILL**: 9 (achievements, cockpit, ask-mint, portfolio, education hub, theme detail, arbitrage bilan, retirement dashboard, compound sim, comprendre hub, cantonal benchmark, provider comparator, budget facade — a few more than 9 if we count merges-implied kills)
- **DEFER**: 1 (timeline)

**Net result**: ~95 screens collapse into roughly **55 routable surfaces + 18 life event hubs + 1 coach home + 1 monde home + 1 dossier drawer + 1 capture sheet**. The user sees a **2-tab shell**, **6 domains**, and tools only appear in context. No more `/tools`, no more flat calculator lists, no more LOOP-01, no more "where does safePop send me".

---

## Final note — what I'm pushing back on in NAV_GRAAL_V10

1. **4 tabs is too many for this identity.** The spec correctly rejects chat-only (§1) but then over-corrects into a dashboard shell. Coach + Monde is enough. Aujourd'hui is an element of Coach, not a sibling.
2. **7 hubs is a code-base taxonomy, not a life taxonomy.** "Fiscalité" and "Patrimoine & Succession" are instrument labels. Users don't live in fiscalité, they live in "gagner sa vie" and "transmettre". Rename and reduce to 6 domains that follow the arc of a life, not the chapters of a Swiss tax code.
3. **Dossier as a tab is wrong.** For a protection-first, privacy-sensitive product, the user's data should live **behind** a control surface (drawer), not **in front** as a persistent tab. Tabs ask for attention; drawers yield control.
4. **"Explorer" as a label is wrong.** It's the language of a zoo or a file browser. "Monde" (or "Ma vie", "Situations") frames the surface as the user's own life, not a catalog to browse.
5. **The absorption plan is too slow.** NAV_GRAAL §17 stages `ask-mint → coach` and `tools → explorer` for "Phase 2". Do it in Phase 1. These are the screens generating the Budget loop and the dead redirects today. They are not safe to keep as aliases while we work on the new shell — they actively mislead the user.
6. **The coach-orchestrator dependency is backwards.** NAV_GRAAL §11 correctly says "the new shell should not depend on coach maturity". Good. But then §17 pushes coach-first unification to Phase 4. The right move is: **ship the 2-tab shell in Phase 1**, with the coach doing whatever it does today (even if orchestration is weak), because the shell is what fixes the mental model. The orchestration layer can keep maturing underneath without changing the IA.

MINT's identity document is clearer than its navigation spec. The IA should follow the identity.

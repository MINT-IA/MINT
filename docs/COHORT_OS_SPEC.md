I'll read the three documents you've specified to understand MINT's architecture and then design a production-ready cohort system.
Excellent. I have the three documents. Now let me design the production-ready OS de cohortes for MINT. I'll structure this as a comprehensive specification that can be directly implemented by the team.

---

# OS de Cohortes — MINT Cohort Operating System (Production Spec)

## Executive Summary

This spec defines a **life-phase-based cohort engine** that adapts MINT's experience across 6 age bands (18-99). Rather than generic content, each cohort sees:
- **Different guided sequences** (journeys via coach)
- **Different Explorer tab priorities** (tools + hub order)
- **Different coach tone** (vocabulary, pacing, reassurance style)
- **Different CTA chips** (contextual calls-to-action)
- **Different Pulse caps** (priority actions on Aujourd'hui)
- **Different content suppression** (never show retirement planning to 22yo)

**Implementation strategy**: Build a stateless `CohortDetectionService` that determines cohort from `CoachProfile` + life events + confidence signals. Inject cohort into `CapEngine`, `ExplorerHubController`, and `CoachContextInjectorService`. UI remains unchanged; logic adapts beneath.

---

## 1. COHORT DEFINITIONS (18-99)

### Cohort 1: **18-27 (First Steps)**

**Definition**: Recently employed, learning financial independence, no major commitments yet.

**Detection Logic**:
```dart
// CohortDetectionService.detectCohort(CoachProfile profile, List<LifeEvent> events)
age >= 18 && age <= 27 &&
  (firstJobEvent != null || newJobEvent != null || events.contains(firstJob)) &&
  profile.totalAssets < 50_000 &&
  profile.monthlyDebt == 0 // or debt from studies only
  → Cohort1_FirstSteps
```

**Archetype**: mostly `swiss_native` + some `expat_eu` (AU pairs, exchange students). Low profile completeness (50-60%).

**Cap typique**: "Comprendre mon premier salaire" / "Organiser mon budget"

#### 1.1 Top 3 Guided Sequences (Journeys)

| Journey | Coach Opening | Flow | ARB Key Pattern | Why This Cohort |
|---------|--------------|------|-----------------|-----------------|
| **J1: Premier Salaire Maîtrisé** | "Tu viens de recevoir ta première fiche de paie. On décortique ensemble?" | 1. Brut vs Net (AVS/LPP/IR expliqué) → 2. Budget mensuel simple (revenus - charges fixes) → 3. Épargne réaliste (10% early) → 4. Résumé: "Tu disposes de CHF X/mois" | `journey_first_salary_*` | Foundation for lifetime. High emotional impact (first independence moment). Low complexity (3a/LPP not yet critical). |
| **J2: Sortir d'une Tension Budget** | "Ton budget te serre? Voyons où on peut retrouver de l'air." | 1. Diagnostic rapide (revenus vs charges) → 2. Leaking money audit (Netflix, abos, petits crédits) → 3. Plan d'action (cut cheapest item → free up CHF Y/mois) → 4. Win: "Retrouvé CHF Z, c'est X% de liberté de plus" | `journey_budget_tension_*` | Very common at 22 (student debt lingering, first apt costs, lifestyle inflation). Quick wins = high conversion. |
| **J3: Comparaison d'Offre Job** | "Nouvelle offre en main? Regardons si ça paie vraiment plus." | 1. Brut comparé → 2. Impôt + charges (canton change?) → 3. Bonus/13e impact → 4. Net monthly delta → 5. Non-financial factor (trajet, lifestyle, learning) | `journey_job_comparison_*` | Age 24-27: first job hops. Prevents bad decisions (higher gross ≠ higher net after taxes + canton shift). |

**Wording/Tone Rules for Cohort 1**:
- **Vocab**: Simple, no jargon. "Impôt" > "fiscalité". "Argent de poche" is OK, but not "allocation".
- **Tone**: Supportive mentor (think TikTok financial educateur, not bank). "Cool, on va décortiquer ensemble" vs "Voici votre situation fiscale".
- **Reassurance**: Early financial stress is normal. "Presque tous les Suisses passent par là."
- **Avoid**: Tax optimization language, succession, LIFD art 38, anything over CHF 100k capital.

**Explorer Tab Priorities (Cohort 1)**:

Hub order:
1. **Travail & Statut** (50% space) — premier emploi, comparaison offre, chômage (RIP emotional hit)
2. **Famille** (25%) — concubinage basics, naissance planning (avoid divorce)
3. **Fiscalité** (15%) — déclaration 1ère année, déductions simple
4. **Logement** (10%) — louer vs acheter (not yet buying, but good to know)
5. Hide: Retraite, Patrimoine & Succession, Santé & Protection (unless disability event triggered)

**Screens to Prioritize** (Explorer tiles):
- `first_job_screen` — ★★★★★ (T1 board = 10/10)
- `job_comparison_screen` — ★★★★★
- `budget_breakdown_screen` (new) — simplified spending by category
- `tax_declaration_simple_screen` (new) — "your first tax return in 3 steps"
- `unemployment_safety_net_screen` — emotional, but crucial
- Hide: `retirement_dashboard`, `succession_planner`, `lpp_deep` tabs

**CTA Chips (Coach) for Cohort 1**:

When coach recommends next step, offer these:
```
// ARB: ctaChip_cohort1_*
"📊 Voir mon budget mensuel"      // Opens budget_breakdown
"🎯 Tester une autre offre"       // Opens job_comparison  
"🏦 Comprendre ma fiche de paie" // Opens first_job_screen
"💰 Plan épargne 1ère année"      // Opens savings_goal_screen (new)
"⚠️ Je suis au chômage, aide!"    // Opens unemployment_safety
```

**Pulse Cap (Aujourd'hui Tab) for Cohort 1**:

What MINT shows as the #1 action on landing:

```
IF age 18-21 && firstJobEvent recent:
  CAP: "Ton premier salaire en chiffres"
  → Icon: 💶
  → Subtitle: "Comprendre ce que tu gagnes vraiment"
  → CTA: "Décortiquer"
  → Delta: "Tu vas libérer CHF X/mois"
  
ELSE IF age 22-27 && newJobOffer detected:
  CAP: "Comparer deux offres"
  → Icon: ⚖️
  → Subtitle: "Voir la vraie différence"
  → CTA: "Comparer"
  
ELSE IF debt ratio > 0.3:
  CAP: "Retrouver de l'air ce mois"
  → Icon: 🌬️
  → CTA: "Voir où couper"
  
ELSE:
  CAP: "Construire ton épargne"
  → Icon: 🌱
  → Subtitle: "10% = une fondation solide"
  → CTA: "Planifier"
```

---

### Cohort 2: **28-37 (Build Phase)**

**Definition**: Establishes major life structures: partner, first child, first home, stable career.

**Detection Logic**:
```dart
age >= 28 && age <= 37 &&
  (marriageEvent != null || concubinageEvent != null || 
   housingPurchaseEvent != null || birthEvent != null) &&
  profile.monthlyIncome >= 4_500 // dual income or established single
  → Cohort2_BuildPhase
```

**Archetype**: mostly `swiss_native` + `couple_mode`, some `independant_with_lpp`. Profile completeness 65-80%.

**Cap typique**: "Construire sans me piéger" / "Arbitrer famille vs ambition"

#### 2.1 Top 3 Guided Sequences

| Journey | Coach Opening | Flow | ARB Key | Why This Cohort |
|---------|--------------|------|---------|-----------------|
| **J1: Acheter sans se Piéger** | "Vous songez à acheter? On test la vraie capacité d'emprunt." | 1. Patrimoine + revenus → 2. Capacité FINMA/stress test → 3. Fonds propres (EPL vs 3a vs cash) → 4. Coûts cachés (frais, assurance) → 5. Arbitrage: loyer restant vs remboursement implicite → 6. Résumé: "Capacité CHF X à taux 5% stress" | `journey_housing_affordability_*` | Biggest life decision. Suisse-specific (FINMA, EPL, imputed rental). High conversion (emotional + material impact). |
| **J2: Couple Financier** | "À deux, les règles changent—impôts, retraite, couple-mode. On voit?" | 1. Mariage vs concubinage impact (fiscalité, AVS) → 2. Revenus asymétriques (gestion commune?) → 3. LPP à deux (rachat ensemble?) → 4. Couple-mode pref (séparé vs commun) → 5. Succession si enfants → 6. Résumé: "gain/perte fiscale CHF Z/an" | `journey_couple_financial_*` | Couples avoid tax planning discussions. Coach making it safe = high value. Foundational for next 30 years. |
| **J3: Naissance & Coûts** | "Bébé arrive bientôt? Regardons le vrai coût et les aides." | 1. Coûts directs (alimentation, soin, vêtements) → 2. Garde (crèche, nanny, grands-parents) → 3. Déductions & aides canton → 4. Impact budget famille → 5. Impact LPP (congé maternité, interruption?) → 6. Résumé: "Budget +CHF X/mois après aides" | `journey_birth_costs_*` | Emotionally charged. Aides vary by canton (high delta). LPP pause often forgotten. Real numbers = high trust. |

**Wording/Tone for Cohort 2**:
- **Vocab**: Assume some financial literacy. "Charge hypothécaire", "coordination LPP", "fiscalité du couple" OK.
- **Tone**: Trusted advisor (Swiss confidence: pragmatic, no fluff, factual). "Voyons les chiffres" > "Mon intuition te dit".
- **Reassurance**: Adulting is complex. "La plupart des couples navigent ça ensemble. On te guide pas à pas."
- **Avoid**: Lifestyle aspirationalism ("acheter la maison de rêve"), vague optimism about returns.

**Explorer Tab Priorities (Cohort 2)**:

Hub order:
1. **Logement** (35%) — acheter, EPL, amortissement, imputation locative
2. **Famille** (25%) — mariage, concubinage, naissance, enfants, couple-mode
3. **Fiscalité** (20%) — déclaration couple, déductions enfants, allocation familiale
4. **Travail & Statut** (10%) — interruption travail, congé parental
5. **Retraite** (10%) — 3a couple, rachat LPP intro (not yet optimization)
6. Hide: Patrimoine & Succession (unless inheritance event), Santé (unless disability)

**Screens to Prioritize**:
- `affordability_screen` (housing) — ★★★★★
- `couple_mode_setup_screen` — ★★★★★ (new or refocus)
- `birth_costs_breakdown_screen` — ★★★★★ (new)
- `epl_combined_screen` — ★★★★ (mortgage + 3a EPL combined view)
- `marriage_tax_impact_screen` — ★★★★★
- `tax_deductions_children_screen` — ★★★★
- Hide: `succession_planner`, `lpp_deep` advanced tabs, `forex_expat_planning`

**CTA Chips (Coach) for Cohort 2**:

```
// ARB: ctaChip_cohort2_*
"🏠 Tester ma capacité d'achat"
"👫 Voir l'impact couple"
"📋 Déductions enfants, canton par canton"
"💚 Plan naissance budget"
"🔄 Mariage: gain ou perte?"
"💰 Maximiser 3a à deux"
```

**Pulse Cap for Cohort 2**:

```
IF housingPurchaseEvent in last 12 months:
  CAP: "Sécuriser votre hypothèque"
  → Subtitle: "Réviser EPL, amortissement, assurance"
  → CTA: "Audit 30 min"

ELSE IF marriageEvent in last 3 months OR concubinageEvent:
  CAP: "Adapter votre fiscalité"
  → Subtitle: "Gain/perte: calcul personnalisé"
  → CTA: "Voir l'impact"

ELSE IF pregnancyEvent OR birthEvent in last 12 months:
  CAP: "Préparer l'arrivée financièrement"
  → Subtitle: "Aides, garde, déductions: CHF X libérés"
  → CTA: "Plan naissance"

ELSE IF LPP == nil OR LPP.lastUpdate > 2 years:
  CAP: "Vérifier votre certificat LPP"
  → Subtitle: "Data fraîche = projections exactes"
  → CTA: "Scanner"

ELSE:
  CAP: "Construire votre 3a couple"
  → Subtitle: "CHF X/an d'avantage fiscal"
  → CTA: "Planifier"
```

---

### Cohort 3: **38-52 (Densification)**

**Definition**: Peak earning, complex family, overlapping goals (children + aging parents + career), first serious debt or mortgage stress.

**Detection Logic**:
```dart
age >= 38 && age <= 52 &&
  (profile.monthlyIncome >= 6_000 || profile.monthlyDebt >= 2_000) &&
  (children.isNotEmpty || elderCare.detected) &&
  profile.totalAssets >= 100_000
  → Cohort3_Densification
```

**Archetype**: `swiss_native`, often `independant_with_lpp` or `couple_mode_complex`. Profile completeness 75-85%.

**Cap typique**: "Prioriser les bons leviers" / "Protéger sans surcharger"

#### 3.1 Top 3 Guided Sequences

| Journey | Coach Opening | Flow | ARB Key | Why |
|---------|--------------|------|---------|-----|
| **J1: Densifier sans se Tendre** | "Carrière, famille, dettes, assurances: on priorise les CHF qui comptent vraiment." | 1. Audit complet (revenus, charges, dettes, assurances) → 2. Stress test (perte revenu, invalidité) → 3. Gaps identification (LPP insuffisante? IJM missing?) → 4. Leviers par ordre impact (insurance d'abord, puis 3a, puis EPL rachat) → 5. Plan 12 mois → 6. Résumé: "CHF Z protégé, XXX optimisé/an" | `journey_densification_*` | High complexity (multiple goals conflict). Needs prioritization, not overwhelm. Suisse-specific risk = invalidity gap + LPP shortfall. |
| **J2: Retraite Sérieuse (Preview)** | "À 38-52, c'est le moment de vérifier: tu es on track?" | 1. Scan LPP (profiler gap) → 2. AVS trajectory → 3. 3a capital → 4. Projection retraite 65 → 5. Confidence assessment (data quality) → 6. First levier (rachat LPP? 3a boost?) | `journey_retirement_preview_*` | Many have done nothing. First wake-up call time. Not optimization—just "are we OK?" Confidence usually 40-60% (missing docs). |
| **J3: Protéger la Famille** | "Invalidité, décès, responsabilité: vérifi ton filet." | 1. What if you = disabled (LPP AI, IJM, income loss) → 2. What if you = deceased (family budget, assurances, succession) → 3. Current coverage audit (LPP, private, corporate) → 4. Gaps list → 5. Next steps (IJM yes/no? Private policy? Testament?) → 6. Résumé: "Filet CHF X, gaps CHF Y" | `journey_protection_audit_*` | Age 38-52 = dependents peak + disability risk rising. Suisse-specific = layered pillars (LPP + private + corporate). Most overlook. Emotional + practical. |

**Wording/Tone for Cohort 3**:
- **Vocab**: Full financial terminology OK. "Coordination", "surobligation", "testament", "invalidité", "rachat", "progressive fiscale".
- **Tone**: Serious, efficient, no drama. "Voici le diagnostic. Voici l'ordre logique. Voici le timeline." Not patronizing, not reassuring—just clear.
- **Reassurance**: "À 50, il est encore tôt pour agir. À 55, c'est urgent." (mild urgency, not panic)
- **Avoid**: Scarcity messaging ("hurry before it's too late"), gambling language ("opportunity"), over-optimization ("max out everything").

**Explorer Tab Priorities (Cohort 3)**:

Hub order:
1. **Retraite** (30%) — projection, 3a, LPP, rachat, décaissement preview
2. **Fiscalité** (25%) — revenus élevés, déductions, optimisation
3. **Santé & Protection** (20%) — invalidité, assurances, protection familiale
4. **Famille** (15%) — enfants grands, succession intro
5. **Logement** (10%) — EPL final, refinance, immeuble locatif?
6. Hide: Patrimoine (unless wealth > CHF 500k), Travail (unless entrepreneurship)

**Screens to Prioritize**:
- `retirement_dashboard_screen` — ★★★★★ (now with confidence band)
- `lpp_deep_service` suite (projection, rachat, AI) — ★★★★★
- `protection_audit_screen` (new) — IJM, assurances, gaps
- `tax_optimization_screen` — ★★★★★ (now focused on this cohort)
- `3a_deep` simulateur — ★★★★
- `monte_carlo_screen` — ★★★★ (reintroduce: "Will it last 40+ years?")
- Hide: `first_job`, `budget_basic`, `unemployment` (relegated to "Help" or archive)

**CTA Chips (Coach) for Cohort 3**:

```
// ARB: ctaChip_cohort3_*
"🎯 Ma projection retraite (honnête)"
"🔒 Vérifier mon filet de protection"
"📋 Audit LPP: rachat possible?"
"💰 3a boost: économiser CHF X/an"
"📑 Testament & succession (si enfants)"
"⚠️ Stress test: et si je suis invalide?"
```

**Pulse Cap for Cohort 3**:

```
IF lppCertificate == nil OR lastUpdate > 2 years:
  CAP: "Scanner votre certificat LPP"
  → Subtitle: "Data = CHF 50k+ de clarté"
  → CTA: "Scanner"

ELSE IF retirementConfidence < 50:
  CAP: "Clarifier votre retraite"
  → Subtitle: "Vous êtes on-track? À 38+, on sait."
  → CTA: "Projection 65"

ELSE IF protectionGapsScore > 3:
  CAP: "Audit protection: filet vs réalité"
  → Subtitle: "IJM? Assurances privées? Revoyons."
  → CTA: "Audit 20 min"

ELSE IF age >= 45 && 3aBalance < 100_000:
  CAP: "Booster votre 3a avant 50"
  → Subtitle: "CHF X/an de déduction + rendement"
  → CTA: "Plan boost"

ELSE:
  CAP: "Densification sans surcharge"
  → Subtitle: "Priorisez ce qui compte vraiment"
  → CTA: "Audit complet"
```

---

### Cohort 4: **53-64 (Pre-Retirement)**

**Definition**: Final working decade. Urgency to optimize. Clear retirement horizon (5-12 years). Often complex: inheritance, adult children, parent care, debt payoff timing.

**Detection Logic**:
```dart
age >= 53 && age <= 64 &&
  (profile.monthlyIncome > 0 || retired == false) &&
  (retirementAge != null && retirementAge <= age + 12)
  → Cohort4_PreRetirement
```

**Archetype**: `swiss_native`, often `independant_with_lpp` or widened `couple_mode`. Profile completeness 80-90%.

**Cap typique**: "Préparer la transition" / "Optimiser les derniers leviers"

#### 4.1 Top 3 Guided Sequences

| Journey | Coach Opening | Flow | ARB Key | Why |
|---------|--------------|------|---------|-----|
| **J1: Retraite Optimisée (Full)** | "Dans [X] ans, vous arrêtez. Regardons l'ordre optimal des 11 étapes." | Phase 1 (Clarify, 12 mois): 1. Scanner LPP → 2. Extrait AVS → 3. Recenser 3a → Phase 2 (Arbitrate, 6 mois avant): 4. Rente vs capital → 5. Timing 3a retrait → 6. Hypothèque: rembourser? → Phase 3 (Prepare, 3-6 mois): 7. Rachat LPP art. 79b → 8. LAMal adjustment → 9. Testament → 10. Budget post-retraite → Phase 4 (Act, 1-3 mois): 11. Retrait notification → 12. AVS anticipé→ Final: "Plan retraite signé, confiance 90%+" | `journey_retirement_full_phased_*` | Only cohort where retraite is IMMINENT. 11-step sequence is NOT overwhelming here—it's relief (finally a plan!). Each step = visible progress. TAO sequence champion. |
| **J2: Décaissement Retraite** | "À la retraite, c'est le grand arbitrage: capital, rente, ou mixte? Les chiffres changent tout." | 1. LPP rente vs capital scenario (lifetime income projections) → 2. Tax impact LPP capital → 3. 3a decaissement strategy (LIFO = max tax optimization) → 4. SWR simulation (can I live 40 years on portfolio?) → 5. EPL impact (if mortage) → 6. Summary: "Net monthly income: CHF X (vs CHF Y if rente)" | `journey_withdrawal_strategy_*` | Suisse-specific complexity: rente = taxed income, capital = one-time tax. Most don't understand. Delta easily CHF 500k+ over lifetime. |
| **J3: Succession & Testament** | "4 mois avant retraite, clarifier l'héritage: qui reçoit quoi, testamentaire vs légal." | 1. What if you die before/after retrait → 2. Current marital regime impact → 3. Enfants: part obligatoire? → 4. Donation now (tax-smart) vs testament → 5. Mandat pour inaptitude (often forgotten!) → 6. Notaire next steps → Summary: "Testament drafted, mandat signed" | `journey_succession_protection_*` | Emotional wall most hit at 55-60. Cohort ready (mortality real now). Suisse-specific (forced heirship, mandat inaptitude critical). |

**Wording/Tone for Cohort 4**:
- **Vocab**: Assume full literacy. All technical terms + legal references OK.
- **Tone**: Respectful, calm, authoritative. "Vous avez travaillé 40+ ans. Maintenant, une vraie stratégie." No hype. No "best case scenario"—only realistic ranges.
- **Reassurance**: Maturity. "À ce stade, on sait ce qui compte. Zéro fluff."
- **Avoid**: "You've earned it" (lifestyle aspirational), "make the most of it" (YOLO), "finally rest" (depressing); instead: "secure your independence".

**Explorer Tab Priorities (Cohort 4)**:

Hub order:
1. **Retraite** (40%) — the entire phased sequence, every depth level
2. **Fiscalité** (20%) — capital tax, progression, last years optimizations
3. **Patrimoine & Succession** (20%) — testament, heritage, donations
4. **Santé & Protection** (15%) — LAMal post-retirement adjustments, long-term care
5. **Logement** (5%) — EPL payoff timing, downsizing option
6. Hide: Travail, Famille (unless adult children financial entanglement)

**Screens to Prioritize**:
- `retirement_dashboard_screen` (full phased view) — ★★★★★
- `rente_vs_capital_screen` (LPP + 3a combined) — ★★★★★
- `staggered_withdrawal_screen` (3a + SWR sequences) — ★★★★★
- `succession_planner_screen` — ★★★★★ (refocus, lift from Tier B)
- `testament_guide_screen` (new) — simple, not legal, but clear
- `monte_carlo_screen` (portfolio longevity) — ★★★★★
- `tax_withdrawal_optimizer_screen` — ★★★★★
- Hide: `first_job`, `unemployment`, `birth_costs`, `couple_setup` (archived)

**CTA Chips (Coach) for Cohort 4**:

```
// ARB: ctaChip_cohort4_*
"📊 Plan retraite: les 11 étapes"
"🎯 Rente ou capital? Simulation"
"📋 Défiscaliser le retrait 3a"
"⚖️ Testament & donations"
"🏦 AVS: anticipé ou repoussé?"
"💤 Budget post-retraite: vivable?"
```

**Pulse Cap for Cohort 4**:

```
IF retirementDate within 12 months:
  CAP: "Retraite prévue [Date]: plan final"
  → Subtitle: "11 étapes, timeline claire"
  → CTA: "Phased plan"

ELSE IF retirementDate within 2-5 years:
  CAP: "Préparer votre transition ([X] ans)"
  → Subtitle: "Clarify phase: données manquantes?"
  → CTA: "Checklist"

ELSE IF lppCertificate == nil OR lastUpdate > 1 year:
  CAP: "Certificat LPP: obligatoire avant 55"
  → Subtitle: "Rachat LPP bloqué sans lui"
  → CTA: "Scanner urgent"

ELSE IF testamentStatus == nil:
  CAP: "Testament & mandat pour inaptitude"
  → Subtitle: "Ne pas oublier avant retraite"
  → CTA: "Guide simple"

ELSE:
  CAP: "Décaissement: rente vs capital?"
  → Subtitle: "Impact CHF 500k+ à vie"
  → CTA: "Simuler"
```

---

### Cohort 5: **65-74 (Active Retirement)**

**Definition**: Recently retired (0-9 years). Active, managing consumption rhythm, succession planning, possible inheritance management. Tax-conscious (capital draw-down now visible).

**Detection Logic**:
```dart
age >= 65 && age <= 74 &&
  (retiredEvent != null || avsSalarieStatus == false) &&
  profile.lppCapital > 0 // still in capital phase or rente being received
  → Cohort5_ActiveRetirement
```

**Archetype**: `swiss_native` (mostly), sometimes `returning_swiss` (expats back). Profile completeness 85-95% (retired = clearer picture).

**Cap typique**: "Protéger et piloter" / "Vivre sereinement ma retraite"

#### 5.1 Top 3 Guided Sequences

| Journey | Coach Opening | Flow | ARB Key | Why |
|---------|--------------|------|---------|-----|
| **J1: Rythme de Consommation** | "Retraité maintenant. Question réelle: à ce rythme, l'argent dure jusqu'à 95?" | 1. Current annual draw-down (from rente + capital + SWR) → 2. Inflation scenario (basic + 2%+ scenario) → 3. Longevity test (to age 90 vs 100) → 4. Lifestyle flexibility (what could we cut if needed?) → 5. Reassurance: "Your reserves last to [age]" | `journey_retirement_consumption_*` | Retirees NEED certainty (or honest uncertainty). Monte Carlo rerun each year. Emotional: "Will I run out?" is #1 fear. Low jargon, high reassurance. |
| **J2: Impôt & Succession vivante** | "Vous êtes riche maintenant (capital + rente). Succession: que laisser, comment optimiser?" | 1. Current assets (rente, capital, real estate, inheritance pending) → 2. Estate plan review (testament up to date?) → 3. Donation now (tax-smart, no risk of neediness) vs later (estate) → 4. Enfants & small gifts → 5. Mandat pour inaptitude: is it still valid? → 6. Summary: "Plan protège CHF X, clarifies CHF Y for heirs" | `journey_succession_active_*` | Active retirees often inherit (parents 85+). New wealth needs planning. Suisse-specific: donation strategies, forced heirship updates, mandat refresh crucial. Different from 55 (now wealth is real, not theoretical). |
| **J3: Protection Longévité** | "À 70, santé compte. Couverture santé post-65: revue-t-elle régulièrement?" | 1. Current LAMal franchise/couverture → 2. Private insurer changes post-65 → 3. Soins de longue durée (maison, aide home?) → 4. Costs: CHF X/month plausible? → 5. Assurance vs self-insurance → 6. Mandat pour inaptitude: power of attorney still designates right person? | `journey_longevity_protection_*` | Age 65-74 = last chance to plan pre-decline. LAMal changes, costs rise. Not about fear—about clarity. Suisse-specific: franchise, mandatory coverage, home care costs vary canton. |

**Wording/Tone for Cohort 5**:
- **Vocab**: Full financial + legal. "Succession", "donation", "usufruit", "tenure", "rente viagère", "longévité".
- **Tone**: Calm, reassuring, respectful of mortality. "You've built well. Now protect it wisely."
- **Reassurance**: Abundance (not scarcity). "You can afford to be generous and still be secure."
- **Avoid**: Lifestyle aspirational (you're done working), fear-based language, overly complex scenarios.

**Explorer Tab Priorities (Cohort 5)**:

Hub order:
1. **Retraite** (30%) — consumption, withdrawals, SWR refresh, longevity
2. **Patrimoine & Succession** (30%) — active succession management, donations, heritage
3. **Fiscalité** (20%) — capital gains from withdrawal, donation tax, canton rules
4. **Santé & Protection** (15%) — LAMal, long-term care, protection
5. **Logement** (5%) — downsizing option, second home, transfer
6. Hide: Travail, Famille (unless adult children needing financial help)

**Screens to Prioritize**:
- `consumption_longevity_screen` (new) — "Will CHF last to 95/100?"
- `active_succession_manager_screen` (new) — simple donation/estate tracker
- `monte_carlo_refresh_screen` (annual rerun for retirees) — ★★★★★
- `withdrawal_optimization_screen` (refined for retirees, focus on SWR + tax) — ★★★★★
- `lpp_decaissement_tracking_screen` (are we taking the right amount each month?) — ★★★★
- `protection_longevity_screen` (LAMal, long-term care costs) — ★★★★
- `mandat_inaptitude_screen` (review if still valid) — ★★★★ (lifted from docs)

**CTA Chips (Coach) for Cohort 5**:

```
// ARB: ctaChip_cohort5_*
"💰 L'argent dure jusqu'à 95?"
"📊 Retraite: bilan 5 ans"
"📋 Succession: donations malignes?"
"🏥 LAMal & soins longévité"
"🎁 Aider mes enfants (et rester sûr)"
"⚖️ Mandat pour inaptitude: à jour?"
```

**Pulse Cap for Cohort 5**:

```
IF retiredLessThan2Years:
  CAP: "Retraite: bilan 1er année"
  → Subtitle: "Rythme sustainable? Adaptations?"
  → CTA: "Refresh"

ELSE IF age >= 70:
  CAP: "Protection longévité: vérifier"
  → Subtitle: "LAMal, soins, couverture: à jour?"
  → CTA: "Audit"

ELSE IF inheritancePending || parentAge > 80:
  CAP: "Succession: donation maintenant?"
  → Subtitle: "Tax-smart, et vous restez sûrs"
  → CTA: "Planifier"

ELSE IF yearsUntilAge95 < years_until_portfolio_depletion:
  CAP: "Portfolio dure jusqu'à 95"
  → Subtitle: "Vous êtes couvert. Sérénité."
  → CTA: "Monte Carlo"

ELSE:
  CAP: "Vivre votre retraite sereinement"
  → Subtitle: "Bilan annuel: tout OK?"
  → CTA: "Refresh"
```

---

### Cohort 6: **75+ (Simplification & Legacy)**

**Definition**: Late retirement (10+ years out), simplification focus, legacy clarity, succession close to action, possibly cognitive decline planning.

**Detection Logic**:
```dart
age >= 75 &&
  (retiredEvent != null && yearsRetired >= 10) &&
  (testamentOrMandatStatus != complete || inheritancePassing)
  → Cohort6_Simplification
```

**Archetype**: `swiss_native`, mostly widowed or single. Profile completeness 90%+ (very clear picture).

**Cap typique**: "Garder une vue claire et transmettre proprement"

#### 6.1 Top 3 Guided Sequences

| Journey | Coach Opening | Flow | ARB Key | Why |
|---------|--------------|------|---------|-----|
| **J1: Clarté Patrimoniale** | "À 75, c'est simple: qui possède quoi, et qui hériterait si?" | 1. Full asset map (real estate, bank, insurance, digital) → 2. Where are the docs (testament, will, assurances, mandates)? → 3. Who knows? (enfants, notaire, executor designé?) → 4. What if you become unfit? (mandat inaptitude designates WHO?) → 5. Summary: "Everything is clear and your family knows where to find docs" | `journey_clarity_documentary_*` | Cohort 75+ biggest fear: "Will they know what to do if I'm gone?" Suisse-specific: testament, mandat inaptitude, digital asset list. Non-financial but critical. |
| **J2: Transmission Sereine** | "Succession: transmettre selon vos valeurs, pas par accident." | 1. Who gets what (marital regime impact) → 2. Any wishes beyond legal minimum? (donation now, specific gifts?) → 3. Tax impact for heirs (canton, timing) → 4. Clarity for executor (instructions clear?) → 5. Legacy: any messages? (éthique, valeurs, story) | `journey_transmission_values_*` | Emotional & practical. Not about optimizing (too late)—about clarity + meaning. Helps heirs psychologically (not just financially). Suisse-specific: forced heirship, mandat, notaire role. |
| **J3: Santé & Fin de Vie** | "À 75, anticiper: couverture santé, soins, et si choses s'accélèrent?" | 1. Current LAMal (franchise, couverture, cost changes expected?) → 2. Home care cost projection (CHF X/month if needed) → 3. Insurance coverage review (still appropriate?) → 4. Mandat pour inaptitude: is it CURRENT and legal? → 5. End-of-life directive (if desired) → 6. Safety: family knows where docs? | `journey_health_eol_*` | Medical reality. Not morbid—practical. Suisse-specific: LAMal post-75, long-term care, mandat inaptitude crucial (cognitive decline plausible). This cohort gets it (not depressing, just honest). |

**Wording/Tone for Cohort 6**:
- **Vocab**: Simple + formal. "Testament", "succession", "héritage", "mandat pour inaptitude". Avoid "legacy" (too English).
- **Tone**: Dignified, clear, warm. "Vous avez construit une belle vie. Transmettez-la clairement à ceux que vous aimez."
- **Reassurance**: Completeness. "Quand tout est documenté, vous (et votre famille) pouvez respirer."
- **Avoid**: Mortality language ("When you're gone"), fear-based, overly technical legal jargon.

**Explorer Tab Priorities (Cohort 6)**:

Hub order:
1. **Patrimoine & Succession** (50%) — testament, transmission, mandat, heritage clarity
2. **Santé & Protection** (30%) — LAMal, long-term care, end-of-life, mandat inaptitude
3. **Fiscalité** (15%) — donation tax, inheritance tax for heirs
4. **Retraite** (5%) — consumptions, consumption forecasting if extended longevity
5. Hide everything else

**Screens to Prioritize**:
- `documentary_clarity_screen` (new) — checklist: où sont les docs, qui sait?
- `transmission_guide_screen` (new) — simple transmission planner (not legal, but clear)
- `mandat_inaptitude_screen` (lifted, focus on validity + refresh)
- `testament_simple_guide_screen` (educational, not legal)
- `lamal_longterm_care_screen` (LAMal post-75, costs)
- Hide: everything work/career/first-job/unemployment/job-comparison/birth/young-family

**CTA Chips (Coach) for Cohort 6**:

```
// ARB: ctaChip_cohort6_*
"📋 Où sont mes documents? Checklist"
"👨‍👩‍👧 Héritage clair pour mes enfants"
"🏥 LAMal & soins: couvert?"
"⚖️ Mandat pour inaptitude: valid?"
"💌 Message pour après (si je veux)"
"✅ Transmettre proprement"
```

**Pulse Cap for Cohort 6**:

```
IF documentaryStatus == nil OR incomplete:
  CAP: "Clarité patrimoniale: checklist"
  → Subtitle: "Docs, succession, mandat: où?"
  → CTA: "Remplir"

ELSE IF mandatInaptitudeStatus != valid:
  CAP: "Mandat pour inaptitude: urgent"
  → Subtitle: "Invalide si > 10 ans ou marital change"
  → CTA: "Vérifier"

ELSE IF age >= 78:
  CAP: "Santé & fin de vie: anticiper"
  → Subtitle: "LAMal, soins, couverture"
  → CTA: "Réviser"

ELSE:
  CAP: "Transmission: léguer selon vos valeurs"
  → Subtitle: "Clair pour votre famille"
  → CTA: "Planifier"
```

---

## 2. COHORT DETECTION SERVICE (Implementation)

This is the **single source of truth** for determining user cohort. Called on every app launch + life event trigger.

### 2.1 Location & Contract

```dart
// File: lib/services/cohort_detection_service.dart
// Called by: CapEngine, ExplorerHubController, CoachContextInjectorService
// Input: CoachProfile, List<LifeEvent>, EnhancedConfidence
// Output: CohortId enum (or null if ambiguous)

enum CohortId {
  cohort1_FirstSteps,        // 18-27
  cohort2_BuildPhase,        // 28-37
  cohort3_Densification,     // 38-52
  cohort4_PreRetirement,     // 53-64
  cohort5_ActiveRetirement,  // 65-74
  cohort6_Simplification,    // 75+
}

class CohortDetectionService {
  /// Main entry point: returns cohort for a user
  CohortId? detectCohort(CoachProfile profile, List<LifeEvent> events) {
    final age = profile.age;
    
    // Rule 1: Hard age bands (fallback)
    if (age < 18) return null; // Pre-18 = not target
    if (age >= 18 && age <= 27) return _analyzeCohort1(profile, events);
    if (age >= 28 && age <= 37) return _analyzeCohort2(profile, events);
    if (age >= 38 && age <= 52) return _analyzeCohort3(profile, events);
    if (age >= 53 && age <= 64) return _analyzeCohort4(profile, events);
    if (age >= 65 && age <= 74) return _analyzeCohort5(profile, events);
    if (age >= 75) return _analyzeCohort6(profile, events);
    
    return null;
  }
  
  /// Cohort 1 (18-27): First Steps
  CohortId? _analyzeCohort1(CoachProfile profile, List<LifeEvent> events) {
    final hasFirstJob = events.contains(LifeEvent.firstJob) || 
                        events.contains(LifeEvent.newJob);
    final lowAssets = profile.totalAssets < 50_000;
    final lowDebt = (profile.monthlyDebt ?? 0) == 0 || 
                    (profile.debtSource == 'student_loan');
    
    return (hasFirstJob && lowAssets && lowDebt)
        ? CohortId.cohort1_FirstSteps
        : null;
  }
  
  /// Cohort 2 (28-37): Build Phase
  CohortId? _analyzeCohort2(CoachProfile profile, List<LifeEvent> events) {
    final hasMajorLifeEvent = events.contains(LifeEvent.marriage) ||
                              events.contains(LifeEvent.concubinage) ||
                              events.contains(LifeEvent.housingPurchase) ||
                              events.contains(LifeEvent.birth);
    final stableIncome = (profile.monthlyIncome ?? 0) >= 4_500;
    final hasAssets = profile.totalAssets >= 10_000;
    
    return (hasMajorLifeEvent && stableIncome)
        ? CohortId.cohort2_BuildPhase
        : null;
  }
  
  /// Cohort 3 (38-52): Densification
  CohortId? _analyzeCohort3(CoachProfile profile, List<LifeEvent> events) {
    final highIncome = (profile.monthlyIncome ?? 0) >= 6_000;
    final hasSigDebt = (profile.monthlyDebt ?? 0) >= 2_000;
    final hasComplexity = events.contains(LifeEvent.birth) ||
                         events.contains(LifeEvent.newJob) ||
                         profile.dependentAge != null; // children or elder care
    final hasAssets = profile.totalAssets >= 100_000;
    
    return ((highIncome || hasSigDebt) && hasComplexity)
        ? CohortId.cohort3_Densification
        : null;
  }
  
  /// Cohort 4 (53-64): Pre-Retirement
  CohortId? _analyzeCohort4(CoachProfile profile, List<LifeEvent> events) {
    final stillWorking = profile.salaryStatus == 'employed' || 
                         profile.salaryStatus == 'self_employed';
    final hasRetirementHorizon = profile.targetRetirementAge != null &&
                                 profile.targetRetirementAge! <= profile.age + 12;
    
    return (stillWorking && hasRetirementHorizon)
        ? CohortId.cohort4_PreRetirement
        : null;
  }
  
  /// Cohort 5 (65-74): Active Retirement
  CohortId? _analyzeCohort5(CoachProfile profile, List<LifeEvent> events) {
    final isRetired = events.contains(LifeEvent.retirement) ||
                     profile.salaryStatus == 'retired';
    final hasLppCapital = profile.lppCapital != null && profile.lppCapital! > 0;
    
    return (isRetired && hasLppCapital)
        ? CohortId.cohort5_ActiveRetirement
        : null;
  }
  
  /// Cohort 6 (75+): Simplification & Legacy
  CohortId? _analyzeCohort6(CoachProfile profile, List<LifeEvent> events) {
    final isRetired = events.contains(LifeEvent.retirement) ||
                     profile.salaryStatus == 'retired';
    final longTimeRetired = profile.retirementDate != null &&
        DateTime.now().difference(profile.retirementDate!).inDays > 365 * 10;
    
    return (isRetired && longTimeRetired)
        ? CohortId.cohort6_Simplification
        : null;
  }
}
```

### 2.2 Integration Points

**CapEngine** (`lib/services/cap_engine.dart`):
```dart
// Before selecting a Cap, detect cohort
final cohort = CohortDetectionService().detectCohort(profile, events);

// Filter Caps based on cohort
final eligibleCaps = allCaps.where((cap) {
  // Cohort 1: exclude retirement, succession, advanced tax
  if (cohort == CohortId.cohort1_FirstSteps) {
    return cap.category != 'retirement' && 
           cap.category != 'succession' &&
           cap.complexity != 'advanced';
  }
  // Cohort 5/6: exclude unemployment, first job, birth planning
  if (cohort == CohortId.cohort5_ActiveRetirement ||
      cohort == CohortId.cohort6_Simplification) {
    return cap.category != 'employment_early' &&
           cap.category != 'family_young' &&
           cap.complexity != 'beginner';
  }
  // ... etc for each cohort
  return true;
}).toList();
```

**ExplorerHubController** (`lib/controllers/explorer_hub_controller.dart`):
```dart
// Reorder hubs based on cohort
final hubOrder = _hubOrderByCohort(cohort);
// Dim/hide certain hubs
final visibleHubs = allHubs.where((hub) {
  return !_hiddenHubsByCohort(cohort).contains(hub);
}).toList();
```

**CoachContextInjectorService** (`lib/services/coach_context_injector_service.dart`):
```dart
// Inject cohort into coach system prompt
final coachSystemPrompt = '''
You are MINT's financial coach.

User Profile:
- Age: ${profile.age}
- Cohort: ${cohort.name}  // <-- NEW
- Phase of life: ${_phaseDescription(cohort)}

Tone Guidelines for this cohort:
${_toneGuidelines(cohort)}

Topics to prioritize:
${_topicsByCohorta(cohort).join(', ')}

Topics to AVOID:
${_hiddenTopicsByCohort(cohort).join(', ')}

Always use the CTA chips appropriate for this cohort.
Never recommend advanced features unless user explicitly asks.
''';
```

---

## 3. UI/UX ADAPTATION (NOT Visual Changes, Logic Changes)

### 3.1 Should the UI Visually Change?

**Answer: NO for colors/layout. YES for content density and microcopy.**

- **NOT changing**: Core design system, color palette, layout grid, navigation structure.
- **ARE changing**: Hub visibility, screen priorities, CTA chip set, coach voice + tone, copy complexity, feature visibility.

This keeps engineering cost low while achieving major UX impact.

### 3.2 What Changes Per Cohort

**Cohort 1 (18-27)**:
- Explorer hubs: **4 visible** (Travail, Famille, Fiscalité, Logement), rest collapsed
- Screen density: **Low** (3-5 key screens per hub, no "advanced" tabs)
- Copy: **Simple** ("revenus" not "salaire brut", "impôt" not "fiscalité progressive")
- Onboarding: **Minimal** (just age + salary)

**Cohort 2 (28-37)**:
- Explorer hubs: **5 visible** (Logement, Famille, Fiscalité, Travail, Retraite intro)
- Screen density: **Medium** (8-12 screens per hub, 1-2 "advanced" tabs)
- Copy: **Balanced** (financial terms OK, but explained on first use)
- Onboarding: **Moderate** (age, salary, partner, children, mortgage intent)

**Cohort 3 (38-52)**:
- Explorer hubs: **All 6 visible**
- Screen density: **High** (all screens visible, advanced tabs prominent)
- Copy: **Technical** (all jargon, legal references)
- Onboarding: **Rich** (full profile capture)

**Cohort 4 (53-64)**:
- Explorer hubs: **All 6 visible**, Retraite takes 40% space
- Screen density: **Very high** (all phased retirement screens, calculators, scenarios)
- Copy: **Very technical** (legal, tax, succession language)
- Onboarding: **Mandatory complete** (LPP, AVS, 3a, inheritance details)

**Cohort 5 (65-74)**:
- Explorer hubs: **All 6**, Retraite + Patrimoine each 30%
- Screen density: **High but curated** (focus on consumption, inheritance, longevity)
- Copy: **Warm + technical** ("You've built this. Now protect it.")
- Onboarding: **Complete** (full asset map required)

**Cohort 6 (75+)**:
- Explorer hubs: **Only Patrimoine & Succession + Santé + mini-Retraite** (hide Travail, Famille)
- Screen density: **Low, focused** (checklist-driven, clarity-focused)
- Copy: **Simple but respectful** ("Transmettre proprement", "Documenter")
- Onboarding: **Minimal new** (profile already complete)

---

## 4. CONTENT SUPPRESSION RULES (Never Show)

These rules are **non-negotiable** to prevent inappropriate advice.

### 4.1 Suppression Matrix

| Content | Cohort 1 | Cohort 2 | Cohort 3 | Cohort 4 | Cohort 5 | Cohort 6 |
|---------|----------|----------|----------|----------|----------|----------|
| **Retirement deep dive** | ❌ Hide | ⚠️ Intro only | ⚠️ Preview | ✅ Full | ✅ Full | ✅ Full |
| **Succession / Testament** | ❌ Hide | ❌ Hide | ⚠️ Intro | ✅ Full | ✅ Full | ✅ Full |
| **LPP Rachat strategies** | ❌ Hide | ❌ Hide | ✅ Intro | ✅ Full | ✅ (monitoring) | ✅ (monitoring) |
| **Estate donation tax** | ❌ Hide | ❌ Hide | ❌ Hide | ✅ Full | ✅ Full | ✅ Full |
| **Long-term care planning** | ❌ Hide | ❌ Hide | ⚠️ Prevention | ⚠️ Start | ✅ Full | ✅ Full |
| **End-of-life care** | ❌ Hide | ❌ Hide | ❌ Hide | ❌ Hide | ⚠️ Info | ✅ Full |
| **First job / salary** | ✅ Full | ⚠️ Archived | ❌ Hide | ❌ Hide | ❌ Hide | ❌ Hide |
| **Unemployment aid** | ✅ Full | ✅ Full | ⚠️ Basic | ❌ Hide | ❌ Hide | ❌ Hide |
| **Birth costs** | ❌ Hide | ✅ Full | ✅ (aging parents instead) | ❌ Hide | ❌ Hide | ❌ Hide |
| **Parenting tax deductions** | ❌ Hide | ✅ Full | ✅ Full | ⚠️ Archived | ❌ Hide | ❌ Hide |
| **Job comparison** | ⚠️ Simple | ✅ Full | ✅ Full | ❌ Hide | ❌ Hide | ❌ Hide |
| **Professional insurance (IJM)** | ❌ Hide | ⚠️ Intro | ✅ Full | ✅ Full | ⚠️ Monitoring | ❌ Hide |
| **Investment/asset allocation** | ❌ Hide | ❌ Hide | ⚠️ Portfolio planning | ✅ Full | ✅ Full | ⚠️ Simplified |
| **Expatriate taxation** | ❌ Hide | ❌ Hide | ⚠️ If applicable | ✅ Full (if applicable) | ✅ (monitoring) | ⚠️ (if applicable) |
| **Business owner planning** | ❌ Hide | ❌ Hide | ✅ Full (if self-employed) | ✅ Full | ⚠️ Monitoring | ❌ Hide |
| **Mortgage stress-test** | ❌ Hide | ✅ Full | ✅ (refinance) | ⚠️ Payoff timing | ⚠️ Downsizing option | ❌ Hide |
| **FINMA/ASB rules** | ❌ Hide | ✅ Basic | ✅ Full | ✅ Full | ❌ Hide | ❌ Hide |

### 4.2 Implementation

```dart
// File: lib/constants/cohort_content_rules.dart

class CohortContentRules {
  static bool shouldShowContent(
    String contentKey,
    CohortId cohort,
  ) {
    final suppressionMatrix = {
      'retirement_deep_dive': [
        CohortId.cohort1_FirstSteps,
        CohortId.cohort2_BuildPhase,
      ],
      'succession_full': [
        CohortId.cohort1_FirstSteps,
        CohortId.cohort2_BuildPhase,
      ],
      'endOfLifePlanninBudget': [
        CohortId.cohort1_FirstSteps,
        CohortId.cohort2_BuildPhase,
        CohortId.cohort3_Densification,
        CohortId.cohort4_PreRetirement,
      ],
      // ... more rules
    };
    
    return !suppressionMatrix[contentKey]?.contains(cohort) ?? true;
  }
}

// Usage in screens:
if (CohortContentRules.shouldShowContent('succession_full', userCohort)) {
  SuccessionPlanner();
} else {
  SizedBox.shrink();
}
```

---

## 5. JOURNEY/SEQUENCES (Guided Flows)

Each cohort has **3 flagship journeys** that open via coach chat.

### 5.1 Journey Detection & Routing

```dart
// File: lib/services/journey_orchestration_service.dart

class JourneyOrchestrationService {
  /// Returns eligible journeys for user's cohort + current context
  List<Journey> getEligibleJourneys(
    CohortId cohort,
    CoachProfile profile,
    List<LifeEvent> recentEvents,
  ) {
    if (cohort == CohortId.cohort1_FirstSteps) {
      return [
        Journey(
          id: 'j1_first_salary',
          title: 'Premier Salaire Maîtrisé',
          trigger: recentEvents.contains(LifeEvent.firstJob),
          screens: [
            'first_job_screen',
            'budget_breakdown_screen',
            'savings_goal_screen',
          ],
        ),
        // ... J2, J3
      ];
    }
    // ... other cohorts
  }
}

// Coach chat routing:
// User: "Je viens de recevoir ma première fiche de paie"
// Coach detects: CohortId.cohort1_FirstSteps + LifeEvent.firstJob
// Coach opens: Journey('j1_first_salary') -> starts screen sequence
```

### 5.2 ARB Keys for Journeys

**Pattern**: `journey_<cohort>_<journey_name>_<screen>`

Examples:
- `journey_cohort1_first_salary_opening` — "Tu viens de recevoir ta première fiche de paie..."
- `journey_cohort2_housing_affordability_opening` — "Vous songez à acheter?"
- `journey_cohort4_retirement_phased_phase1_clarify` — "Dans [X] ans, vous arrêtez..."
- `journey_cohort5_consumption_longevity_opening` — "À ce rythme, l'argent dure jusqu'à 95?"

---

## 6. COACHING TONE & VOCABULARY (Detailed)

### 6.1 Vocabulary Allowed by Cohort

| Term | Cohort 1 | Cohort 2 | Cohort 3 | Cohort 4 | Cohort 5 | Cohort 6 |
|------|----------|----------|----------|----------|----------|----------|
| **Fiscalité** | ❌ Use "impôt" | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Coordination LPP** | ❌ | ❌ | ✅ | ✅ | ✅ | ⚠️ (avoid if possible) |
| **Taux de remplacement** | ❌ | ❌ | ✅ | ✅ | ✅ | ⚠️ |
| **Usufruit / tenure** | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |
| **Rachat LPP art. 79b** | ❌ | ❌ | ⚠️ | ✅ | ⚠️ (retired) | ❌ |
| **Rente viagère** | ❌ | ❌ | ⚠️ | ✅ | ✅ | ✅ |
| **Mandat pour inaptitude** | ❌ | ❌ | ⚠️ | ✅ | ✅ | ✅ |
| **Imputation locative** | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ |
| **SWR (Safe Withdrawal Rate)** | ❌ | ❌ | ⚠️ | ✅ | ✅ | ⚠️ (simplify) |

### 6.2 Tone Prompts (for Coach System Prompt)

**Cohort 1 (18-27)**:
```
You are MINT's friend-mentor on financial independence.
Tone: Supportive, demystifying, anti-jargon.
Vocabulary: Simple, direct, avoid abstract concepts.
Goals: Make them feel normal about learning, celebrate small wins.
Example: "Cool! Tu viens de piger ta première fiche de paie. On la décortique ensemble—c'est plus simple qu'il n'y paraît."
Forbidden: "optimal strategy", "maximise", patronizing ("even you can understand").
```

**Cohort 2 (28-37)**:
```
You are MINT's trusted guide through major life decisions.
Tone: Pragmatic, supportive, acknowledging complexity.
Vocabulary: Financial terms OK, always briefly explain first use.
Goals: Help them navigate trade-offs, reduce overwhelm, build confidence.
Example: "À deux, les règles changent—impôts, retraite, couple-mode. Voyons ça ensemble."
Forbidden: "best choice", lifestyle aspirations, false precision.
```

**Cohort 3 (38-52)**:
```
You are MINT's serious, efficient partner through high complexity.
Tone: Direct, clear, no fluff. Acknowledge real constraints (career, family, money).
Vocabulary: Full technical vocabulary OK; assume financial literacy.
Goals: Prioritization, clarity, visible progress.
Example: "Carrière, famille, dettes, assurances: on priorise ce qui compte vraiment."
Forbidden: Cheerleading, oversimplification, false certainty.
```

**Cohort 4 (53-64)**:
```
You are MINT's expert guide to retirement planning.
Tone: Authoritative, calm, respectful of their 40+ years of work.
Vocabulary: Full legal, tax, actuarial terminology.
Goals: Comprehensive plan, visible timeline, confidence in transition.
Example: "À 55, on a encore le temps. À 60, c'est urgent. Voici les 11 étapes."
Forbidden: Hype, lifestyle aspirations, vague promises.
```

**Cohort 5 (65-74)**:
```
You are MINT's calm, respectful guide to active retirement.
Tone: Warm, reassuring, respectful of mortality; avoiding fear or condescension.
Vocabulary: Technical OK, but warm phrasing. "You've built well. Now protect wisely."
Goals: Consumption confidence, wealth protection, legacy clarity.
Example: "Vous êtes retraité. Question réelle: à ce rythme, l'argent dure jusqu'à 95?"
Forbidden: "Finally rest", lifestyle hype, fear-mongering.
```

**Cohort 6 (75+)**:
```
You are MINT's dignified guide to legacy and simplicity.
Tone: Respectful, clear, warm, non-medical. Practical, not morbid.
Vocabulary: Simple + formal. "Testament", "héritage", "mandat pour inaptitude".
Goals: Documentary clarity, transmission peace, family protection.
Example: "À 75, c'est simple: qui possède quoi, et qui hériterait si?"
Forbidden: Medical language, death-focused framing, fear.
```

---

## 7. SCREENS BY COHORT (Prioritization Spec)

### 7.1 Tier A Screens (Must Migrate to New Standard)

**Cohort 1**:
```
Priority 1 (Tier A — full migration):
  - first_job_screen
  - job_comparison_screen
  - budget_breakdown_screen (new)
  - unemployment_safety_net_screen

Priority 2 (Tier B → Tier A conversion):
  - tax_declaration_simple_screen (new)
  - savings_goal_screen (new)
```

**Cohort 2**:
```
Priority 1 (Tier A):
  - affordability_screen (housing)
  - couple_mode_setup_screen
  - birth_costs_breakdown_screen (new)
  - marriage_tax_impact_screen
  - epl_combined_screen

Priority 2 (Tier B → Tier A):
  - tax_deductions_children_screen
  - concubinage_screen (lift to parity with marriage)
```

**Cohort 3**:
```
Priority 1 (Tier A):
  - retirement_dashboard_screen (with confidence band)
  - lpp_deep_service (full suite)
  - protection_audit_screen (new)
  - tax_optimization_screen (focused on high earners)
  - monte_carlo_screen (reintroduce)

Priority 2 (Tier B → Tier A):
  - 3a_deep_simulator
  - debt_stress_test_screen
```

**Cohort 4**:
```
Priority 1 (Tier A):
  - retirement_phased_dashboard (new, 11 steps)
  - rente_vs_capital_screen (LPP + 3a combined)
  - staggered_withdrawal_screen (3a + SWR sequences)
  - succession_planner_screen
  - testament_guide_screen (new)
  - monte_carlo_screen (portfolio longevity)
  - tax_withdrawal_optimizer_screen

Priority 2 (Tier B → Tier A):
  - avs_anticipation_screen
  - lamal_post_retirement_screen
```

**Cohort 5**:
```
Priority 1 (Tier A):
  - consumption_longevity_screen (new — "will CHF last to 95?")
  - active_succession_manager_screen (new)
  - monte_carlo_refresh_screen (annual rerun)
  - withdrawal_optimization_screen (SWR + tax focused)
  - lpp_decaissement_tracking_screen (new)
  - protection_longevity_screen (LAMal + long-term care)

Priority 2 (Tier B → Tier A):
  - mandat_inaptitude_screen
```

**Cohort 6**:
```
Priority 1 (Tier A):
  - documentary_clarity_screen (new — checklist: where are docs?)
  - transmission_guide_screen (new — simple transmission planner)
  - mandat_inaptitude_screen
  - testament_simple_guide_screen
  - lamal_longterm_care_screen

Priority 2 (Hide/Archive):
  - first_job_screen
  - unemployment_screen
  - birth_costs_screen
  - job_comparison_screen
```

---

## 8. ANALYTICS & INSTRUMENTATION

Every cap, journey, and CTA chip should log:
- User cohort at trigger time
- Sequence progress (step 1 of 5, etc.)
- CTA usage by cohort
- Completion rates by cohort + journey
- Dropout points

**ARB Key Pattern for Analytics**: `analytics_cohort<N>_<event_type>`

Example:
```dart
analytics.logEvent(
  'journey_started',
  parameters: {
    'journey_id': 'j1_first_salary',
    'cohort': 'cohort1_FirstSteps',
    'entry_point': 'coach_suggestion',
  },
);

analytics.logEvent(
  'cta_chip_tapped',
  parameters: {
    'chip_key': 'ctaChip_cohort1_see_monthly_budget',
    'cohort': 'cohort1_FirstSteps',
    'tap_position': 2, // second chip tapped
  },
);
```

---

## 9. TESTING & VALIDATION

### 9.1 Golden Couples by Cohort

Test at least one persona per cohort:

| Cohort | Golden Couple | Age | Profile | Test Scenario |
|--------|---------------|-----|---------|---------------|
| 1 | Alex (Suisse native) | 24 | First job CHF 45k, VS, no debt | Sees J1_FirstSalary, CTA chips for budget + job comparison |
| 2 | Julia + Marco (couple) | 32/33 | Married, 1 child, CHF 120k combined, buying CHF 600k apt, VS | Sees J1_Housing, J2_Couple, J3_Birth, CTA chips for EPL + couple tax |
| 3 | Sabine (single, high earner) | 45 | CHF 140k, 2 kids, CHF 300k mortgage, CHF 500k 3a, VS | Sees densification journey, advanced LPP rachat, protection audit |
| 4 | Jérôme (pre-retiree) | 58 | CHF 130k, married, CHF 1.2M LPP, CHF 150k 3a, 7 years to 65 | Sees 11-step phased retirement, rente vs capital, succession intro |
| 5 | Christiane (active retiree) | 70 | Retired 5 years, CHF 45k AVS + CHF 60k capital, CHF 800k estate | Sees consumption longevity, active succession, LAMal update |
| 6 | Margaret (late retiree) | 82 | Retired 15+ years, CHF 1.2M estate, widowed, 3 adult children | Sees documentary clarity, transmission guide, mandat inaptitude review |

### 9.2 Test Matrix

For each cohort:
1. ✅ **Cohort detection** works (correct age + life events → correct cohort)
2. ✅ **Explorer hubs** visible/hidden correctly
3. ✅ **Caps** shown are age-appropriate (no retirement for 22yo)
4. ✅ **CTAs** match cohort tone
5. ✅ **Journey starts** with coach suggestion
6. ✅ **Screens** load without regression
7. ✅ **Copy** uses correct vocabulary (no "coordination" for cohort 1)
8. ✅ **Suppression rules** enforced (no succession tab for 30yo)

---

## 10. MIGRATION ROADMAP

### Phase 1: Infrastructure (2 sprints)
- [ ] Implement `CohortDetectionService`
- [ ] Add cohort field to `CoachProfile`
- [ ] Create `CohortContentRules` suppression matrix
- [ ] Write unit tests for detection logic (10+ test cases)
- [ ] Golden couple validation (pass detection for all 6 personas)

### Phase 2: Explorer Tab Adaptation (2 sprints)
- [ ] Implement `hubOrderByCohort()` in `ExplorerHubController`
- [ ] Hide/show hubs per cohort
- [ ] Update hub tiles to reflect cohort priorities
- [ ] Test with golden couples (verify hub order correct)
- [ ] Suppress screens per `CohortContentRules`

### Phase 3: Coach Integration (2 sprints)
- [ ] Inject cohort into coach system prompt
- [ ] Create 6 tone prompt variants
- [ ] Wire cohort into `CapEngine` (filter caps by cohort)
- [ ] Test coach suggestions (verify age-appropriate)
- [ ] Create CTA chip variants per cohort (6 × 6 = 36 ARB keys)

### Phase 4: Journey/Sequence Implementation (3 sprints)
- [ ] Implement `JourneyOrchestrationService`
- [ ] Build cohort-specific journey flows (3 journeys × 6 cohorts = 18 flows)
- [ ] Lift Tier B screens to Tier A (per cohort)
- [ ] Add "phases" structure to retirement journey for cohort 4
- [ ] Test end-to-end journey flows

### Phase 5: Analytics & Monitoring (1 sprint)
- [ ] Instrument all cohort events
- [ ] Create dashboard (by cohort: cap impressions, CTA usage, journey completion)
- [ ] Set baseline metrics (cohort 1: 80%+ budget completion, cohort 4: 60%+ phased retirement)
- [ ] Monitor for anomalies (wrong cap shown to wrong cohort?)

### Phase 6: Polish & Hardening (1 sprint)
- [ ] Audit all copy for vocabulary compliance
- [ ] Test suppression rules (adversarial: try to show forbidden screens)
- [ ] UX pass (no hardcoded text, all ARB keys)
- [ ] Performance (cohort detection should be <10ms)
- [ ] i18n: translate all cohort-specific ARB keys to 6 languages

**Total: 9-10 sprints** (~2.5 months for an experienced team)

---

## 11. SUMMARY SPEC TABLE

| Aspect | Cohort 1 | Cohort 2 | Cohort 3 | Cohort 4 | Cohort 5 | Cohort 6 |
|--------|----------|----------|----------|----------|----------|----------|
| **Age** | 18-27 | 28-37 | 38-52 | 53-64 | 65-74 | 75+ |
| **Life Phase** | First Steps | Build | Densify | Prepare Transition | Active Retirement | Legacy & Simplicity |
| **J1** | First Salary | Housing | Densify | Retirement Phased | Consumption | Documentary Clarity |
| **J2** | Budget Tension | Couple Financial | Retirement Preview | Decaissement | Succession | Transmission |
| **J3** | Job Comparison | Birth Costs | Protection | Succession | Longevity | Health & EOL |
| **Explorer Hubs (Visible)** | 4 / 7 | 5 / 7 | 6 / 7 | 6 / 7 (Retraite 40%) | 6 / 7 (Retraite + Patrimoine 30% each) | 3 / 7 (Patrimoine, Santé, mini-Retraite) |
| **Tone** | Supportive mentor | Pragmatic guide | Serious advisor | Expert planner | Warm caretaker | Dignified guide |
| **Vocabulary Level** | Simple | Intermediate | Advanced | Expert | Expert | Simple + formal |
| **Copy Complexity** | Beginner | Intermediate | Advanced | Advanced | Advanced | Beginner/formal |
| **Retirement Content** | Hidden | Intro | Preview | Full | Full | Full |
| **Succession Content** | Hidden | Hidden | Intro | Full | Full | Full |
| **Profile Completeness** | 50-60% | 65-80% | 75-85% | 80-90% | 85-95% | 90%+ |
| **Expected Cap Focus** | Income, budget | Logement, couple | Tax, protection, LPP | Retraite, décaissement | Consumption, legacy | Documentation, legacy |

---

## 12. DONE CRITERIA

This spec is **production-ready** when:

- [ ] All 6 cohorts detect correctly on golden couples
- [ ] Each cohort sees only age-appropriate screens (suppression rules enforced)
- [ ] Each cohort receives cohort-specific CTAs (36 chip variants)
- [ ] Each cohort hears cohort-appropriate coach voice (6 tone variants)
- [ ] Each cohort has 3 flagshipjourneys implemented (18 flows)
- [ ] Explorer hubs reorder per cohort (no hardcoded "Retraite" first for 22yo)
- [ ] Analytics tracks cohort at every meaningful event
- [ ] All ARB keys translated to 6 languages
- [ ] `flutter analyze` = 0 issues, `flutter test` = 100% pass rate
- [ ] Golden couples tested end-to-end (each cohort: detect → see caps → start journey → progress)
- [ ] No hardcoded French strings (all via `AppLocalizations`)
- [ ] Documentation updated (navigation, voice, caps systems)

---

## Appendix: ARB Key Patterns

All cohort-related keys follow this pattern:

```
journey_cohort<N>_<journey_slug>_<screen_position>
  e.g., journey_cohort1_first_salary_opening, journey_cohort4_retirement_phase1_intro

cap_cohort<N>_<cap_slug>
  e.g., cap_cohort1_understand_salary, cap_cohort4_retirement_plan

ctaChip_cohort<N>_<action>
  e.g., ctaChip_cohort1_see_monthly_budget, ctaChip_cohort5_will_money_last

coach_tone_cohort<N>_<context>
  e.g., coach_tone_cohort1_intro, coach_tone_cohort4_phased_retirement

explorer_hub_cohort<N>_<hub_name>_visibility
  e.g., explorer_hub_cohort1_retraite_hidden, explorer_hub_cohort2_logement_priority

screen_copy_cohort<N>_<screen>_<element>
  e.g., screen_copy_cohort1_first_job_vocabulary, screen_copy_cohort5_consumption_reassurance

suppression_cohort<N>_<content_key>
  e.g., suppression_cohort1_succession_full, suppression_cohort3_endOfLife_intro
```

---

This spec is **concrete, testable, and directly implementable** by the Flutter + backend teams. It requires no major UI redesign—only logic adaptation, content filtering, and coaching tone variation. When implemented properly, each cohort will experience MINT as if it was designed specifically for their life phase, while the underlying system remains unified.

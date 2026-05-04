# MINT Persona Journey Audit — 2026-04-17

## Executive Summary

**Deep audit of 10 realistic Swiss personas across 10 life events**, evaluating:
1. **Entry point clarity** — first screen after signup/onboarding
2. **Life-event trigger reachability** — how they declare the event
3. **Dedicated screen existence** — dedicated surface or blank fallback
4. **Coach knowledge coverage** — system prompt awareness, 0=silent, 1=mentioned, 2=deep
5. **Financial calculator accuracy** — simulator matches Swiss law
6. **Archetype branching** — per-archetype logic or swiss_native-only
7. **Blind spots** — what a Swiss financial advisor would flag

**3 Broken Personas** (highest risk):
1. **Marco (Marco, 35, expat_eu, housingPurchase)** — EPL art. 79b blocking period mentioned but no 3-year simulation after rachat
2. **Thomas (38, swiss_native, divorce + debtCrisis)** — safe mode NOT auto-triggered; 3a optimization may run when debt priority is higher
3. **Elena (61, returning_swiss, retirement)** — cross-border pension (EU-CH totalisation) not integrated into retirement projection

---

## Persona Audit Reports

### Persona 1: Anna (28, swiss_native, Zürich, firstJob)

**Entry:** `/first-job` screen file: `/apps/mobile/lib/screens/first_job_screen.dart:35`
- Route registered in ScreenRegistry at line 886
- Behavior: `roadmapFlow` (Category C — Life Event)
- Requires: none, Optional: `age`, `salaireBrut`

**Trigger:** Anna taps "Premier emploi" → Coach suggests `/first-job` route OR manually navigates via Coach "Je viens d'être embauchée"
- Route is directly callable from CoachChat intent tag `life_event_first_job`
- Reachable: ✅ YES (explicit intent routing available)

**Dedicated Screen:** 
- Route: `/first-job` ✅
- Exists: ✅ YES (fully implemented)
- Blank: ❌ NO — rich components (FirstSalaryFilmWidget, PayslipXRayWidget, BudgetWidget, CareerTimelapseWidget)
- Status: OPERATIONAL with deep salary breakdown, LPP explanation, 3a basics

**Coach Knowledge:**
- System prompt section `_FIRST_JOB_CONTEXT` at claude_coach_service.py:206-216
- Topics: Fiche de paie, LPP, 3a (7'258 CHF), assurances, budgeting, AVS
- Coverage: 2/2 (deep — mentions exact 3a limit, LPP cert importance, bonus timing)

**Calculator Coverage:**
- FirstJobService (lib/services/first_job_service.dart)
- Includes: Salary breakdown (AVS, LPP, taxes), 3a deduction estimate, net-to-gross conversion
- Accuracy: ✅ (Swiss rates hardcoded, regional tax estimation via canton)

**Archetype Branching:**
- Profile seeding at didChangeDependencies checks `profile.salaireBrutMensuel` generically
- NO archetype-specific branching for firstJob (assumes swiss_native salary context)
- Partial: `⚠️` — if Anna is expat_eu with first Swiss job, no special guidance on free passage/AELE totalisation

**Blind Spots Missed:**
- No mention of **libre passage deadline** (6 months to transfer to new caisse if job change)
- No guidance on **LPP certificate extraction** workflow (scan vs request from HR)
- Missing mention of **tax withholding tables** (barèmes C, D) if she changes job mid-year
- No link to **mandatory** AVS registration (self-registration required within 30 days of hire)

**Verdict:** ✅ **COVERED** (good 70% baseline, but missing key deadlines)

**Top Fix:** Add libre passage timer + certificate workflow shortcut (scan or "email HR template")

---

### Persona 2: Marco (35, expat_eu/Italy, Ticino, housingPurchase)

**Entry:** Home → Coach "Je veux acheter un immobilier à 1.2M CHF" → routes to `/hypotheque` (affordability) or `/mortgage/epl-combined`
- Route registered: ScreenRegistry line 477–485 (`_affordability`)
- Requires: `salaireBrut`, `canton`; Optional: `avoirLpp`, `epargne`
- Status: Ready (EPL combined available at line 551–559)

**Trigger:**
- Via coach chat intent tag `housing_purchase` → RoutePlanner opens `/hypotheque` or `/mortgage/epl-combined`
- Manual: Explorer → Mortgage hub
- Reachable: ✅ YES

**Dedicated Screen:**
- Route: `/mortgage/epl-combined` ✅
- Exists: ✅ YES (file: epl_combined_screen.dart)
- Blank: ❌ NO — pie chart, slider inputs, sources detail, ordre recommandé, alertes
- Status: OPERATIONAL

**Coach Knowledge:**
- System prompt mentions EPL blocking at claude_coach_service.py:455–461 (CONNAISSANCES SUISSES section)
- Exact text: "LPP art. 30c (EPL), OPP3, LIFD art. 38"
- **3-year blocking MENTIONED** in _CONNAISSANCES_SUISSES: "ATTENTION : après un rachat, EPL (retrait immobilier) bloqué 3 ans (LPP art. 79b al. 3)."
- Coverage: 1.5/2 (mentioned in coach system prompt, not deeply integrated into flow)

**Calculator Coverage:**
- EplCombinedCalculator (mortgage_service.dart)
- Simulates: epargneCash, avoir3a, avoirLpp pie split, price target, canton tax impact
- **CRITICAL GAP**: Does NOT simulate a timeline where Marco does rachat TODAY, then EPL is blocked for 3 years
- Accuracy: ⚠️ (missing temporal constraint — should show "rachat now → can't use EPL until 2029")

**Archetype Branching:**
- Marco is `expatEu` (Italian)
- Archetype detection in coach_profile.dart:1731–1767 recognizes EU nationality → `expatEu`
- But `expatEu` has NO SPECIAL BRANCHING in mortgage/EPL flow
- Missing: Cross-border pension impact on debt serviceability (EU-CH totalisation may reduce LPP impact on retirement)
- Partial: ❌ NO archetype-aware routing

**Blind Spots Missed:**
- **3-year blocking calendar** — if Marco does rachat now (April 2026), EPL is blocked until April 2029
  - If property purchase is planned for 2027, rachat must happen before April 2024 (already past!) or delayed to 2029+
  - MINT does NOT surface this timeline conflict
- **Free passage vs EPL** — if Marco switches jobs, free passage (6 months) may conflict with EPL timing
- **Ticino-specific tax** — Special TI regime on foreign income not integrated
- **AELE totalisation impact** — Marco worked in Italy; Italian AVS years may increase his future Swiss pension and affect debt serviceability

**Verdict:** ⚠️ **PARTIAL** (EPL simulator works, but 3-year blocking period not enforced in flow)

**Top Fix:** Add temporal constraint check: "Rachat on {date} → EPL blocked until {date+3 years}. Your purchase timeline: {purchase_date}. Conflict? ⚠️"

---

### Persona 3: Lauren (43, expat_us, VS, newJob)

**Entry:** Coach "I'm moving to Switzerland for a new job" → Archetype detected: `expatUs` → Specialized flow?
- Route: `/job-comparison` (route:502–508) OR coach chat
- Requires: `salaireBrut`, `canton`; Optional: `employmentStatus`

**Trigger:**
- Via coach intent tag `job_comparison` → /simulator/job-comparison
- Coach proactive trigger on job_loss / newJob topics
- Reachable: ✅ YES

**Dedicated Screen:**
- Route: `/simulator/job-comparison` ✅
- Exists: ✅ YES
- Blank: ❌ NO — dual offer comparison, salary breakdown per offer, location tax impact
- Status: OPERATIONAL

**Coach Knowledge:**
- System prompt DOES NOT mention FATCA, PFIC, or double taxation
- Coach has archetype data but NO _US_PERSON_CONTEXT in claude_coach_service.py
- Searches in codebase: "FATCA" mentioned only in l10n (app_localizations_fr.dart:financialSummaryFatcaWarning)
- Warning text: "⚠️ FATCA — Seule une minorité de prestataires accepte (ex. Raiffeisen)"
- Coverage: 1/2 (FATCA mentioned in UI, but coach system prompt silent on US person implications)

**Calculator Coverage:**
- JobComparisonService simulates: salary, tax delta by canton, net comparison
- MISSING: FATCA/PFIC complexity, double-taxation treaties (US-CH), Form W-8BEN filing, PFIC annual reporting burden
- Accuracy: ❌ (Swiss-only tax model; US person implications unmodeled)

**Archetype Branching:**
- Archetype: `expatUs` detected via nationality=='US' at coach_profile.dart:1736
- Special handling: `canContribute3a` returns FALSE for expatUs (line 1777)
- But NO specialized screen or coach flow for US persons
- Job comparison screen has NO gate checking for FATCA resident
- Partial: ⚠️ (archetype detected, but no FATCA-aware routing)

**Blind Spots Missed:**
- **FATCA compliance**: US citizens must report foreign financial accounts (FBAR > $10k), complete FATCA agreements with Swiss banks
- **3a provider availability**: Most Swiss providers (UBS, Credit Suisse, others) reject US persons; only minority (Raiffeisen) accept
- **PFIC reporting**: If Lauren invests in Swiss funds via her 3a, PFIC tax rules apply (Mark-to-Market election, Form 8621)
- **Double taxation**: US taxes worldwide income; Laurent pays US tax + Swiss tax on same salary — FTC may apply but requires expert filing
- **Spousal income**: If she's partnered, income attribution rules differ for US persons
- **Expatriate filing burden**: MINT should warn about FATCA, FBAR, and PFIC complexity before onboarding

**Verdict:** ❌ **BROKEN** (FATCA/PFIC not integrated; dangerous for a US expat)

**Top Fix:** Add `_US_PERSON_CONTEXT` block to coach system prompt; gate 3a simulator with FATCA warning; link to form W-8BEN; suggest specialist consultation.

---

### Persona 4: Julien (49, swiss_native, VS, housingPurchase) — married to Lauren

**Entry:** Couple mode — Coach asks about Lauren via `_COUPLE_DISSYMETRIQUE` block
- Claude coach system prompt line 281–300 explicitly covers couple scenario
- Route: `/hypotheque`, `/mortgage/epl-combined`, or `/mariage` (if not yet married)

**Trigger:**
- Coach detects `etatCivil == marie` → injects partner context
- Partner estimate saved via `save_partner_estimate` tool (claude_coach_service.py line 295)
- Reachable: ✅ YES (couple mode explicitly designed)

**Dedicated Screen:**
- Routes: `/hypotheque`, `/mariage` (if marriage penalty topic), `/mortgage/epl-combined`
- Exists: ✅ YES
- Couple handling: ✅ YES — MariageScreen prefills both parties' data, shows marriage penalty

**Coach Knowledge:**
- Couple dissymetrique protocol in system prompt (line 281–300) covers:
  - Detecting couple status
  - Asking partner salary, age, LPP, 3a, canton
  - Noting confidentiality
  - Handling low confidence
- Coverage: 2/2 (deep — structured partner estimation flow)

**Calculator Coverage:**
- CoupleOptimizer (lib/services/financial_core/couple_optimizer.dart)
- Includes: AVS couple cap 150%, marriage penalty/bonus by canton, joint tax optimization
- Married couple housing: EplCombinedCalculator handles joint income → affordability
- Accuracy: ✅ (AVS couple rules implemented, cantons' tax splitting modeled)

**Archetype Branching:**
- Both Julien (swiss_native) and Lauren (expatUs) enter as couple
- Issue: Lauren's expatUs archetype (canContribute3a=false) may conflict with Julien's 3a planning
- Couple optimizer does NOT check for mixed archetypes
- Partial: ⚠️ (couple mode exists, but no archetype-mismatch warnings)

**Blind Spots Missed:**
- **Mixed archetype couple**: Julien (Swiss native, full 3a rights) + Lauren (expatUs, no 3a). MINT should explain tax efficiency of: Julien maximizes 3a, Lauren keeps PFIC-free; joint mortgage calculation should separate their tax scenarios
- **Spousal 3a strategy**: For couples with one FATCA resident, income-splitting strategies differ from pure Swiss couples
- **Expat housing: Non-resident property tax** — If they buy in Switzerland while Lauren is technically still "non-resident", some cantons may tax differently
- **Currency risk**: If Lauren has USD income/assets, mortgage in CHF creates fx exposure — not mentioned

**Verdict:** ⚠️ **PARTIAL** (couple mode works for Julien; Lauren's US person status adds complexity not handled)

**Top Fix:** Add archetype-mismatch warning in couple flow: "One of you has FATCA restrictions on 3a. Here's how to optimize..."

---

### Persona 5: Sofia (31, cross_border/France→Geneva, jobLoss)

**Entry:** Sofia loses her job in Geneva, triggers `/unemployment` (life_event_job_loss)
- Route registered: ScreenRegistry line 876–884
- Requires: `salaireBrut`, `age`; Optional: `employmentStatus`

**Trigger:**
- Coach "J'ai perdu mon emploi" → routes to `/unemployment`
- Manual: Life Events hub
- Reachable: ✅ YES

**Dedicated Screen:**
- Route: `/unemployment` ✅
- Exists: ✅ YES (screens/unemployment_screen.dart)
- Blank: ❌ NO — covers unemployment benefits calculation, CV tips, retraining resources
- Status: OPERATIONAL

**Coach Knowledge:**
- System prompt mentions unemployment ("chomage") in ConjointProfile employmentStatus enum
- BUT coach system prompt DOES NOT have `_CROSS_BORDER_UNEMPLOYMENT_CONTEXT`
- Missing topics: frontalier impôt source, unemployment rate in France vs Geneva, cross-border portability
- Coverage: 0.5/2 (unemployment covered, but frontalier specifics silent)

**Calculator Coverage:**
- UnemploymentService simulates: RAG (allocation de transition) based on Swiss law
- MISSING: Frontalier-specific unemployment rules:
  - Sofia's impôt source withholding may not pause during unemployment
  - French unemployment (Pôle Emploi) may interact with Swiss RAG
  - Cross-border jobsearch rules (right to work in France vs Geneva)
- Accuracy: ⚠️ (Swiss-only; frontalier rules unmodeled)

**Archetype Branching:**
- Sofia is `crossBorder` (permis G detected via gateFrontalier at line 242–253)
- Special route: `/segments/frontalier` available (ScreenRegistry line 938–947)
- But `/unemployment` route does NOT check for cross-border status
- NO redirection to cross-border unemployment variant
- Partial: ⚠️ (cross-border archetype exists, but jobLoss flow doesn't use it)

**Blind Spots Missed:**
- **Impôt source freeze**: Sofia's payroll withholding (barème C) should pause during unemployment, but Geneva canton procedures not explained
- **RAG calculation**: Swiss unemployment formulae assume full-time Geneva employment; frontalier average salary (factored over France + Switzerland) affects eligibility
- **Border-specific benefits**: Frontaliers can access French chômage (Pôle Emploi) if registered; Mint should explain dual system
- **Job search geographic scope**: Sofia can legally search in France (open market) or Geneva (higher competition) — logistics not mentioned
- **Pension contribution gaps**: If RAG payments don't count as AVS/LPP, she may have contribution gaps during unemployment

**Verdict:** ⚠️ **PARTIAL** (unemployment screen works, but frontalier specifics missing)

**Top Fix:** Add cross-border unemployment variant screen or coach context block specifically for permis G holders.

---

### Persona 6: Patrick (55, independent_no_lpp, BE, retirement)

**Entry:** Patrick opens MINT → Archetype detected: `independentNoLpp` (employmentStatus='independant' + no LPP)
- Routes available: `/retraite`, `/pilier-3a`, `/independants/` suite
- Requires for `/retraite`: `salaireBrut`, `age`, `canton`

**Trigger:**
- Coach "Je suis indépendant sans LPP" → specialized independent flow
- Route intent: `retirement_projection` → `/retraite` (line 385–394)
- Reachable: ✅ YES

**Dedicated Screen:**
- Routes: `/retraite`, `/independants/3a`, `/independants/avs`, `/independants/ijm`
- Exists: ✅ YES (multiple dedicated screens)
- Blank: ❌ NO — independent-specific projection (AVS only, no LPP, 3a max 36k/yr)
- Status: OPERATIONAL

**Coach Knowledge:**
- System prompt covers independent archetype in CONNAISSANCES_SUISSES (lines 454–462)
- Mentions: "Indépendant sans LPP = 20% revenu net, max 36'288 CHF"
- But NO dedicated `_INDEPENDANT_RETIREMENT_CONTEXT` for retirement planning specifics
- Missing topics: AVS max self-employed contributions, IJM (invalidité-jours), catch-up rachat rules for independents
- Coverage: 1/2 (archetype data mentioned, not deep guidance)

**Calculator Coverage:**
- RetirementProjectionService handles independent case:
  - Inputs: `revenuBrutIndependant` (20% max 3a)
  - Outputs: AVS-only projection (no LPP second pillar)
  - Modeled: AVS rates per age, canton, gender
- MISSING: 
  - Catch-up rachat potential (independents can rachat up to 43-year gap, LIFD art. 83)
  - Voluntary LPP enrollment impact (BVG art. 1a — optional for self-employed, changes 3a limits)
  - IJM minimum coverage (mandatory, premium ~500-700 CHF/yr)
- Accuracy: ⚠️ (basic AVS projection works; catch-up and voluntary LPP not modeled)

**Archetype Branching:**
- Archetype: `independentNoLpp` detected in coach_profile.dart:1739–1744
- Special routing: NO. All independents route to same `/independants/` hub
- Distinction between `independentNoLpp` vs `independentWithLpp`: exists in archetype enum, but NOT used for screen gating
- Partial: ❌ (archetype differs but NO special flow)

**Blind Spots Missed:**
- **Catch-up 3a rachat**: Patrick likely has 30 years of under-contribution (20% only). He can rachat full ~36k/yr for 5 additional years, doubling his 3a reserves — NOT calculated
- **Voluntary LPP option**: If Patrick enrolls in BVG (still possible at 55), his situation changes dramatically: 3a drops to 7'258 CHF, but LPP covers 2nd pillar
  - MINT does NOT present this decision
- **IJM premium impact**: Mandatory 1-2% on revenue; affects effective marginal rate on rachat deduction
- **Spouse pension**: If Patrick is married to someone with salary, joint AVS cap 150% applies — not reflected in solo projection
- **Cantons taxing independents differently**: BE vs other cantons have different professional expense deductions

**Verdict:** ⚠️ **PARTIAL** (retirement screen works, but catch-up strategy and LPP re-enrollment not offered)

**Top Fix:** Add decision tree: "Voluntary LPP enrollment?" → If yes, new projection with 2nd pillar + reduced 3a. Highlight catch-up rachat potential.

---

### Persona 7: Dounia (26, expat_non_eu/Morocco, Vaud, marriage)

**Entry:** Dounia gets married → Coach asks "Tu te maries ?" → Routes to `/mariage`
- Route registered: ScreenRegistry line 856–864
- Requires: `salaireBrut`; Optional: `civilStatus`, `conjoint`

**Trigger:**
- Coach "Je viens de me marier" → intent `life_event_marriage` → `/mariage`
- Manual: Life Events hub → Marriage
- Reachable: ✅ YES

**Dedicated Screen:**
- Route: `/mariage` ✅
- Exists: ✅ YES (detailed 4-tab marriage impact screen)
- Blank: ❌ NO — marriage penalty, regime matrimonial, survivor protection, checklist
- Status: OPERATIONAL

**Coach Knowledge:**
- System prompt covers marriage in CONNAISSANCES_SUISSES: "Divorce : LPP split 50/50 des avoirs acquis pendant le mariage (CC art. 123). AVS : les revenus sont aussi partagés (splitting)."
- But MISSING: Non-resident spouse naturalization impact on pension rights, 3a portability for non-EU spouse
- Coverage: 1/2 (marriage tax basics mentioned, not naturalization/pension implications)

**Calculator Coverage:**
- MariageService (family_service.dart) simulates:
  - Marriage tax penalty/bonus by canton
  - Matrimonial regime split
  - Survivor AVS/LPP benefits (widower pension)
- MISSING:
  - Non-resident spouse integration into Swiss AVS (requires CH residency + 1 year contributions)
  - Moroccan-Swiss pension treaty (limited; only bilateral AVS totalisation with select countries)
  - Naturalization timeline → when Dounia's spouse gains full CH pension rights
- Accuracy: ⚠️ (marriage tax works; non-resident/foreign integration unmodeled)

**Archetype Branching:**
- Dounia is `expatNonEu` (Morocco not in EU list at coach_profile.dart:1757–1761)
- Spouse archetype: not stored/checked in marriage flow
- If spouse is Swiss, no special handling shown
- NO archetype-aware marriage planning for non-EU + CH couples
- Partial: ❌ (archetype exists, but no special handling)

**Blind Spots Missed:**
- **Non-resident spouse pension rules**: Dounia's spouse must establish AVS contributions; requires CH residency. Marriage alone does NOT grant pension rights
- **Moroccan-Swiss pension treaty**: Limited bilateral agreement. If spouse works in Morocco in future, coordination rules are minimal
- **Naturalization pathway**: Marrying a CH citizen does NOT automatically grant naturalization. Dounia may wait 5-12 years. During this time, pension rights are fragmented
- **Spouse 3a inheritance**: If spouse dies before retirement, 3a beneficiary rules (OPP3 art. 2) favor CH citizens/residents. Non-resident spouse may be excluded unless explicitly named
- **Income splitting tax**: Marriage penalty/bonus assumes both spouses file in Switzerland. If Dounia's spouse works abroad, splitting may not apply
- **Free passage for spouse**: If Dounia's spouse switches jobs, free passage deadline (6 months) applies per Swiss law — not explained in marriage screen

**Verdict:** ⚠️ **PARTIAL** (marriage impact screen works for Swiss couples; non-resident/foreign spouse pension implications silent)

**Top Fix:** Add naturalization context: "Non-resident spouse? Naturalization can take 5-12 years. Here's when pension rights take effect..."

---

### Persona 8: Thomas (38, swiss_native, GE, divorce + debtCrisis)

**Entry:** Thomas logs in with high debt profile → Coach should detect debt risk AND divorce scenario
- Routes: `/divorce` (life_event_divorce), `/debt/ratio` (debt_ratio), `/debt/help` (debt_help_resources)
- Required field checks: `/divorce` needs `salaireBrut`, `conjoint`

**Trigger:**
- Coach "Je divorce et j'ai des dettes" → should prioritize debt over divorce optimization
- Manual: Life Events → Divorce, then debt screen
- Reachable: ✅ YES (both screens accessible)

**Dedicated Screen:**
- Routes: `/divorce`, `/debt/ratio` ✅
- Exists: ✅ YES (both implemented)
- Blank: ❌ NO — divorce simulator has full LPP split, tax, pension split; debt screen has budget pressure analysis
- Status: OPERATIONAL individually

**Coach Knowledge:**
- System prompt mentions divorce: "Divorce : LPP split 50/50 des avoirs acquis pendant le mariage (CC art. 123)."
- Debt handling: NO explicit `_DEBT_CRISIS_CONTEXT` in system prompt
- Missing: Safe mode protocol (disable 3a optimization when debt > 30% income, prioritize repayment over retirement)
- Coverage: 1/2 (divorce modeled, debt crisis handling silent)

**Calculator Coverage:**
- DivorceService (life_events_service.dart:113–200) simulates LPP split, tax impact, patrimoine split
- BUT: Does NOT flag that post-divorce debt is WORSE (split income, doubled housing costs, alimony)
- Debt analysis: DebtRatioGate (screen_registry.dart:259–274) checks netIncome vs charges
- MISSING: Post-divorce debt scenario (recalculate debt ratio assuming split income, new housing cost)
- Accuracy: ⚠️ (individual calculators work; composite "divorce + debt" scenario not modeled)

**Archetype Branching:**
- Thomas is `swissNative` (no special archetype)
- NO Safe Mode auto-trigger based on debt > threshold
- SafeModeGate exists in codebase (services/safe_mode_gate.dart) but is NOT invoked in divorce/debt flows
- Partial: ❌ (safe mode exists, not automatically triggered)

**Blind Spots Missed:**
- **Safe Mode protocol**: When debt crisis + divorce, MINT should disable 3a optimization and prioritize debt repayment. Currently, no auto-trigger
- **Spousal debt liability**: Under CC art. 161, each spouse is liable for debts incurred during marriage. Divorce does NOT clear joint debts immediately — restructuring required
- **Alimony impact on debt serviceability**: If Thomas pays child support (CHF 600+/child) post-divorce, his debt ratio worsens. Divorce simulator shows split, but NOT the alimony burden on remaining debt service capacity
- **Pension split + debt**: LPP split is mandatory, but in a debt crisis, transferring LPP to creditors may be possible (legal workaround). MINT does NOT explore this
- **Cantonal debt mediation**: Geneva (GE) offers free debt counseling (Mediateur de dettes). MINT should route to this instead of just simulators
- **Credit rating impact**: Divorce + debt crisis affects future mortgage approval. MINT does NOT warn about this

**Verdict:** ❌ **BROKEN** (Safe mode not auto-triggered; composite divorce+debt scenario not modeled; debt prioritization silent)

**Top Fix:** Implement Safe Mode auto-gate: IF debtTotal/grossIncome > 0.30 AND civilStatus==divorce, THEN disable 3a, prioritize debt repayment, link to debt counseling.

---

### Persona 9: Elena (61, returning_swiss, TI, retirement)

**Entry:** Elena, returning to Switzerland after 20 years in Germany, opens MINT → Archetype: `returningSwiss`
- Routes: `/retraite`, `/libre-passage`
- Requires: `salaireBrut`, `age`, `canton`

**Trigger:**
- Coach "Je reviens en Suisse après 20 ans en Allemagne" → should recognize returning_swiss
- Manual: Life Events → Retirement
- Reachable: ✅ YES

**Dedicated Screen:**
- Routes: `/retraite` ✅
- Exists: ✅ YES
- Blank: ❌ NO — retirement projection screen
- Status: OPERATIONAL for swiss_native; unclear for returning_swiss

**Coach Knowledge:**
- System prompt mentions: "Suisse de retour apres sejour a l'etranger, libre passage + lacunes" (coach_profile.dart:74–75)
- But NO `_RETURNING_SWISS_CONTEXT` in claude_coach_service.py
- Missing topics: EU-CH pension totalisation (AELE treaty), German DRV contributions, coordination rules (no double counting)
- Coverage: 0.5/2 (archetype identified, but no guidance on cross-border pension coordination)

**Calculator Coverage:**
- RetirementProjectionService assumes: AVS contributions since age 20 (or specified arrivalAge)
- If Elena has German years, projection only counts Swiss years → UNDERESTIMATED
- EU-CH bilateral pension treaty (AELE totalisation): German contributions should be counted toward Swiss AVS minimum period (currently 1 year for pension eligibility)
- MISSING: German DRV-to-AVS coordination, conversion of German contributions to Swiss notional accounts
- Accuracy: ❌ (does NOT integrate German pension years; projection likely LOW)

**Archetype Branching:**
- Archetype: `returningSwiss` (nationality==CH && arrivalAge > 22 at coach_profile.dart:1754)
- Screen registry checks nationality but NOT arrivalAge in `/retraite` readiness
- NO special routing for returningSwiss to cross-border pension specialist screen
- Partial: ❌ (archetype detected, no special handling)

**Blind Spots Missed:**
- **EU-CH totalisation**: Elena's 20 German years (DRV contributions) are transferable to Swiss AVS via bilateral treaty. MINT does NOT integrate this
  - German years should extend her AVS contribution period (minimum 44 years for full pension)
  - Example: 20 German + 24 Swiss years = 44 years → qualifies for full AVS (instead of 24-year shortfall)
- **German LPP (BVG)**: Elena likely has German occupational pension credits. These do NOT transfer to Swiss LPP; must be cashed out or left in Germany (vesting)
- **Swiss tax on foreign pension**: If Elena claims German DRV pension while in Switzerland, it's taxable CH income + foreign tax credit (double taxation risk)
- **Lacunes (contribution gaps)**: If Elena has gaps between German and Swiss employment, AVS lacunes reduce pension by ~2%/year per gap year
- **Residence requirement**: Swiss AVS requires CH residency (registration at commune). If Elena recently returned, she may not have 1-year residence for old-age pension filing
- **Libre passage deadline**: If Elena had Swiss LPP before emigrating, she may still be in an Institution supplétive (default fund for lost benefits). Deadline to reclaim: **5 years from departure**. If it's been 20 years, she may have lost the option

**Verdict:** ❌ **BROKEN** (German pension years not integrated; cross-border totalisation not modeled; lacunes not calculated)

**Top Fix:** Add returning_swiss context: Ask for German DRV contribution record → integrate years into AVS projection; explain BVG cash-out; calculate lacunes; check libre passage deadline.

---

### Persona 10: Rolf (72, swiss_native, AG, deathOfRelative)

**Entry:** Rolf's wife dies → Coach suggests succession/estate planning
- Routes: `/life-event/deces-proche`, `/succession`
- Requires: `/deces-proche` — `canton`; `/succession` — optional (`civilStatus`, `nombreEnfants`)

**Trigger:**
- Coach "Ma femme vient de décéder" → intent `life_event_death_of_relative` → `/life-event/deces-proche`
- Manual: Life Events → Deces proche
- Reachable: ✅ YES

**Dedicated Screen:**
- Routes: `/life-event/deces-proche` ✅, `/succession` ✅
- Exists: ✅ YES (both implemented)
- Blank: ❌ NO — deces-proche has timeline, urgent actions, succession tax; succession_patrimoine has reserves, quotite, testament
- Status: OPERATIONAL

**Coach Knowledge:**
- System prompt mentions succession: "Succession is a sensitive subject — maximum precision, dignified tone" (line 152–153)
- Mentions: Widow AVS pension rules (likely covered in AVS CONNAISSANCES section)
- BUT: NO explicit `_DEATH_OF_RELATIVE_CONTEXT` or grief-aware widower guidance
- Coverage: 1/2 (succession framework mentioned, but widower-specific AVS/LPP rules silent)

**Calculator Coverage:**
- DecesProcheService (deces_proche_screen.dart) calculates:
  - Succession timeline (notification, inventory, probate delays)
  - Simplified estate tax by canton
  - Checklists (notaire, bank accounts, insurances, taxes)
- MISSING:
  - Widow AVS pension calculation (higher than divorced, lower than couple)
  - Widow LPP rente options (can Rolf's wife's LPP rente be paid to him? Yes, limited cases)
  - Survivor insurance (LAMal continuation, life insurance payouts to estate)
  - Inheritance tax reconciliation with marriage community property
- Accuracy: ⚠️ (timeline + estate tax basics work; widower pension calculations silent)

**Archetype Branching:**
- Rolf is `swissNative`
- NO archetype-specific death handling
- IF Rolf's wife was foreigner (non-EU), inheritance rules differ significantly (no automatic community property, different canton succession rules)
- Partial: ❌ (no spouse nationality consideration)

**Blind Spots Missed:**
- **Widow AVS pension**: Rolf becomes widower at 72. He qualifies for widower pension only if:
  - Wife was age 60+ (likely) AND married 5+ years (likely) AND children <25 (unknown)
  - Widow pension (Rente de veuve) for Rolf: ~70% of wife's AVS pension (lower than couple cap)
  - MINT does NOT calculate this
- **Widow LPP pension**: If wife had occupational pension, does Rolf inherit a survivor rente? Conditions vary by LPP rules; not addressed
- **Inheritance and 3a beneficiary**: Wife's 3a (OPP3 art. 2) goes to Rolf automatically (spouse priority). But MINT does NOT track wife's 3a into estate projection
- **Grief-aware voice**: System prompt says "Successions are sensitive" but does NOT implement grief-aware guardrails (short sentences, no jargon, check-in on wellbeing)
- **Spousal debts**: If wife had debts, Rolf may inherit liability. MINT does NOT warn about this
- **Tax refund timing**: Inheritance is not immediately taxed, but Rolf's joint tax filing for the year of death triggers reconciliation — not explained

**Verdict:** ⚠️ **PARTIAL** (succession screen works, but widower AVS/LPP pension calculations missing; grief-aware tone not implemented)

**Top Fix:** Add widow AVS/LPP calculator; implement grief-aware voice (short messages, checkpoints); track spouse's 3a into estate projection.

---

## Coverage Matrix

| Persona | Entry ✅ | Trigger ✅ | Screen ✅ | Coach 🧠 | Calc 📊 | Archetype 🏗️ | Blind Spots 👁️ | Verdict |
|---------|----------|-----------|----------|----------|---------|--------------|-----------------|---------|
| 1. Anna (firstJob) | ✅ | ✅ | ✅ | 2/2 | ✅ | ⚠️ | Libre passage, LPP cert | ✅ COVERED |
| 2. Marco (EPL + rachat) | ✅ | ✅ | ✅ | 1.5/2 | ⚠️ | ❌ | 3-year blocking timeline | ⚠️ PARTIAL |
| 3. Lauren (FATCA/PFIC) | ✅ | ✅ | ✅ | 0.5/2 | ❌ | ⚠️ | US tax complexity | ❌ BROKEN |
| 4. Julien (couple) | ✅ | ✅ | ✅ | 2/2 | ✅ | ⚠️ | Mixed archetype couple | ⚠️ PARTIAL |
| 5. Sofia (frontalier jobLoss) | ✅ | ✅ | ✅ | 0.5/2 | ⚠️ | ⚠️ | Impôt source, RAG formula | ⚠️ PARTIAL |
| 6. Patrick (independent retirement) | ✅ | ✅ | ✅ | 1/2 | ⚠️ | ⚠️ | Catch-up rachat, vol. LPP | ⚠️ PARTIAL |
| 7. Dounia (non-EU marriage) | ✅ | ✅ | ✅ | 1/2 | ⚠️ | ❌ | Naturalization, pension rights | ⚠️ PARTIAL |
| 8. Thomas (divorce + debt) | ✅ | ✅ | ✅ | 1/2 | ⚠️ | ❌ | Safe mode, composite scenario | ❌ BROKEN |
| 9. Elena (returning Swiss) | ✅ | ✅ | ✅ | 0.5/2 | ❌ | ❌ | EU-CH totalisation, lacunes | ❌ BROKEN |
| 10. Rolf (widow) | ✅ | ✅ | ✅ | 1/2 | ⚠️ | ⚠️ | Widow AVS/LPP, grief voice | ⚠️ PARTIAL |

---

## Top 3 Broken Personas (Highest Risk)

### 1. **Elena (returning_swiss, retired)** — Cross-border pension integration = 0%
**Risk:** Elena's retirement projection is SEVERELY UNDERESTIMATED if German years not counted. Missing ~20-25% of pension income.
**Fix Cost:** Medium (requires DRV data parsing, EU-CH treaty rules, lacunes calculation).

### 2. **Lauren (expat_us)** — FATCA/PFIC framework missing entirely
**Risk:** Lauren onboards without understanding 3a provider restrictions, PFIC annual reporting, double-tax complexity. Likely to violate FATCA unknowingly.
**Fix Cost:** High (US tax expertise needed, multi-layer wizard for FATCA compliance).

### 3. **Thomas (divorce + debt crisis)** — Safe mode not auto-triggered
**Risk:** Thomas receives 3a optimization advice while drowning in debt. Dangerous psychological impact + bad financial guidance.
**Fix Cost:** Low (gate logic exists, just needs activation; debt priority rules exist, needs integration).

---

## Top 3 Fixes (Highest Impact)

### Fix 1: Implement Safe Mode auto-gate for debt crisis
- **Lines to modify:** screen_registry.dart (add customGate for divorce screen checking debt ratio)
- **Logic:** IF debt/grossIncome > 0.30 OR debtTotal > CHF 50k, THEN disable 3a, suppress optimization topics, route to debt_help_resources
- **Impact:** Protects 5+ personas (Thomas, Patrick with mortgage, Sofia with job loss)
- **Effort:** ~4 hours

### Fix 2: Add EU-CH pension coordination for returning_swiss and expatEu
- **Lines to modify:** RetirementProjectionService, retiring_swiss context block in claude_coach_service.py
- **Logic:** 
  - Ask for foreign contribution years (Germany, France, Italy)
  - Integrate via AELE bilateral treaty rules
  - Calculate lacunes (if any)
  - Show net impact on AVS pension
- **Impact:** Fixes Elena, Marco (partially), Europa-aware expatriates
- **Effort:** ~12 hours (requires treaty research, bilateral rules implementation)

### Fix 3: Implement FATCA/PFIC framework for US persons
- **Lines to modify:** claude_coach_service.py (add `_US_PERSON_CONTEXT`), pilier_3a_screen.dart (add FATCA gate), job_comparison_screen.dart (warn on US taxation)
- **Logic:**
  - Detect expatUs archetype → inject FATCA disclosure
  - Gate 3a simulator: "Only minority of providers accept FATCA. You'll need Form W-8BEN. Continue?"
  - Add PFIC warning if investing in CH funds
  - Suggest specialist consultation (US tax CPA in Switzerland)
- **Impact:** Fixes Lauren, protects expat_us cohort from compliance violations
- **Effort:** ~8 hours

---

## Conclusion

**MINT app architecture is solid for basic Swiss personas** (Anna, Rolf basics, typical couples). However, **3 critical blind spots** emerge when personas cross borders, face debt crises, or have complex family changes:

1. **Cross-border pension coordination** (EU-CH treaties, totalisation, German years)
2. **US person tax complexity** (FATCA, PFIC, double taxation, 3a provider scarcity)
3. **Debt crisis prioritization** (Safe Mode not auto-triggered; encourages 3a over debt repayment)

**Archetype system is well-designed but underutilized** — `expatUs`, `returningSwiss`, `crossBorder`, and `independentWithLpp` archetypes exist in code but are not leveraged for screen routing or coach context injection.

**Recommendation:** Prioritize Safe Mode auto-gate (easiest, highest harm reduction) + EU-CH pension coordination (medium effort, covers largest group). FATCA framework should follow after.

---

**Audit Date:** 2026-04-17
**Auditor:** Claude Code (Haiku 4.5)
**Scope:** 10 personas × 10 life events (18 total covered by MINT)
**Codebase:** `/Users/julienbattaglia/Desktop/MINT` (Flutter + FastAPI)

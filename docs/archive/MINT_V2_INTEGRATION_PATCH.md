# MINT_V2_INTEGRATION_PATCH.md
# Reconciliation between existing docs (Gen 1) and Coach Vivant evolution (Gen 2)
# Apply these changes to existing files before starting S30.5

---

## WHAT THIS DOCUMENT IS

The Coach Vivant evolution (S30.5–S40) introduced 5 new documents:
```
docs/ONBOARDING_ARBITRAGE_ENGINE.md
docs/MINT_COACH_VIVANT_ROADMAP.md
docs/DATA_ACQUISITION_STRATEGY.md
.claude/AGENT_FINANCIAL_CORE_UNIFICATION.md
.claude/AGENT_COACH_VIVANT_MASTER_PROMPT.md
```

These must integrate cleanly with the existing operational docs:
```
rules.md
AGENTS.md
AGENT_SYSTEM_PROMPT.md
LEGAL_RELEASE_CHECK.md
DefinitionOfDone.md
AGENTS_LOG.md
TEST_ROADMAP.md
.claude/CLAUDE.md
```

This patch specifies every change needed. Apply surgically.

---

## 1. UNIFIED HIERARCHY OF TRUTH

**Problem**: 3 different hierarchies exist in rules.md, AGENTS.md, and CLAUDE.md.
They must be aligned into ONE canonical order.

### Canonical hierarchy (apply to ALL three files):

```
1. rules.md                              — Non-negotiable technical + ethical rules
2. .claude/CLAUDE.md                     — Project context, constants, compliance, anti-patterns
3. AGENTS.md                             — Team workflow, roles, sprint tracker
4. .claude/skills/                       — Agent-specific conventions and patterns
5. LEGAL_RELEASE_CHECK.md               — Wording compliance checklist
6. visions/                              — Product vision + limits
7. docs/ (evolution specs)               — ONBOARDING_ARBITRAGE_ENGINE, COACH_VIVANT_ROADMAP, DATA_ACQUISITION
8. decisions/ (ADR)                      — Architecture decisions
9. SOT.md + OpenAPI                      — Data contracts
10. Code                                 — Implementation follows documents
```

### Changes to apply:

**In rules.md § 0:**
Replace current hierarchy with the canonical one above.
Add: "docs/ evolution specs sit below visions/ but above ADRs."

**In AGENTS.md § HIÉRARCHIE DE VÉRITÉ:**
Replace current hierarchy with the canonical one above.
Remove the duplicate definition.

**In CLAUDE.md § HIERARCHY OF TRUTH:**
Already close to correct. Add line 7 (docs/ evolution specs).
Ensure exact match with canonical order.

---

## 2. AGENTS.md UPDATES

### 2.1 — Sprint Tracker Extension

Append to the sprint table in AGENTS.md:

```
### Sprints à venir — Coach Vivant Evolution

| Sprint | Module | Prerequisite | Spec Document |
|--------|--------|-------------|---------------|
| **S30.5** | Financial Core Unification (audit + cleanup) | None | AGENT_FINANCIAL_CORE_UNIFICATION.md |
| S31 | Onboarding Redesign + MinimalProfileService | S30.5 | ONBOARDING_ARBITRAGE_ENGINE.md § II |
| S32 | Arbitrage Phase 1 (Rente vs Capital + Allocation) | S31 | ONBOARDING_ARBITRAGE_ENGINE.md § III |
| S33 | Arbitrage Phase 2 + Longitudinal Snapshots | S32 | ONBOARDING_ARBITRAGE_ENGINE.md § III + VI |
| S34 | Compliance Guard (BLOCKER for all LLM) | S30.5 | MINT_COACH_VIVANT_ROADMAP.md § S34 |
| S35 | Coach Narrative Service (T1+T2+T3) | S34 | MINT_COACH_VIVANT_ROADMAP.md § S35 |
| S36 | Notifications + Milestones (T4+T5) | S35 | MINT_COACH_VIVANT_ROADMAP.md § S36 |
| S37 | Scenario Narration + Annual Refresh (T6+T7) | S36 | MINT_COACH_VIVANT_ROADMAP.md § S37 |
| S38 | FRI Shadow Mode | S33 | ONBOARDING_ARBITRAGE_ENGINE.md § V |
| S39 | FRI Beta + Longitudinal Charts | S38 | ONBOARDING_ARBITRAGE_ENGINE.md § V |
| S40 | Reengagement Engine + Consent | S39 | MINT_COACH_VIVANT_ROADMAP.md § S40 |
| S41 | Guided Precision Entry | S40 | DATA_ACQUISITION_STRATEGY.md § Channel 2 |
| S42-43 | LPP Certificate Parsing (OCR) | S41 | DATA_ACQUISITION_STRATEGY.md § Channel 1 |
| S44 | Tax Declaration Parsing | S42 | DATA_ACQUISITION_STRATEGY.md § Channel 1 |
| S45 | AVS Extract Guidance + Parsing | S43 | DATA_ACQUISITION_STRATEGY.md § Channel 1 |
| S46 | Enhanced Confidence Scoring | S45 | DATA_ACQUISITION_STRATEGY.md § Confidence |
```

### 2.2 — New Agent Roles

Add to AGENTS.md § DREAM TEAM ÉLARGIE:

```
### Coach Vivant — Additional Agents

| Agent | Mission | Model | When |
|-------|---------|-------|------|
| **Compliance Guard Agent** | Build + test ComplianceGuard and HallucinationDetector | Opus | S34 (BLOCKER) |
| **Arbitrage Agent** | Implement arbitrage engine (5 modules) | Sonnet | S32-S33 |
| **OCR Agent** | Document parsing pipeline (LPP cert, tax, AVS) | Sonnet | S42-S45 |
```

### 2.3 — Updated Spawn Prompts

Add to AGENTS.md § COMMENT LANCER L'ÉQUIPE:

```
**For S30.5 (Financial Core Unification):**

Spawn a teammate named "audit-agent" with model opus.
Prompt: "Tu es un auditeur senior de code financier.
Lis ces fichiers DANS CET ORDRE avant de faire quoi que ce soit :
1. .claude/CLAUDE.md (constants, financial_core spec, anti-patterns 12-14)
2. decisions/ADR-20260223-unified-financial-engine.md
3. .claude/AGENT_FINANCIAL_CORE_UNIFICATION.md (ta mission complète)
4. .claude/skills/mint-backend-dev/SKILL.md
5. .claude/skills/mint-test-suite/SKILL.md

Tu exécutes les 6 phases du document d'unification.
Phase 1 (Discovery) : tu NE MODIFIES AUCUN CODE. Tu produis un rapport d'audit.
Phase 2 (Plan) : tu proposes un plan de nettoyage. Tu attends validation.
Phases 3-6 : tu exécutes un doublon à la fois, test avant et après chaque changement.
Backend = source de vérité. Si backend et Flutter divergent, backend gagne."


**For S31-S33 (Onboarding + Arbitrage):**

Spawn backend:
"Tu es le backend engineer pour l'évolution Coach Vivant de MINT.
Lis DANS CET ORDRE :
1. .claude/CLAUDE.md
2. docs/ONBOARDING_ARBITRAGE_ENGINE.md (specs complètes)
3. .claude/AGENT_COACH_VIVANT_MASTER_PROMPT.md (ton sprint précis)
4. .claude/skills/mint-backend-dev/SKILL.md
5. .claude/skills/mint-swiss-compliance/SKILL.md
Backend = source de vérité. Fonctions pures. Tests min 15 par module.
MUST use financial_core/ calculators. ZERO duplication."

Spawn flutter:
"Tu es le Flutter engineer pour l'évolution Coach Vivant de MINT.
Lis DANS CET ORDRE :
1. .claude/CLAUDE.md
2. docs/ONBOARDING_ARBITRAGE_ENGINE.md (specs complètes)
3. .claude/AGENT_COACH_VIVANT_MASTER_PROMPT.md (ton sprint précis)
4. .claude/skills/mint-flutter-dev/SKILL.md
5. .claude/skills/mint-test-suite/SKILL.md
MUST import financial_core.dart. NEVER duplicate calculations.
Design: MintColors, Montserrat/Inter, GoRouter, Provider, Material 3."


**For S34 (Compliance Guard — BLOCKER):**

Spawn a teammate named "compliance-guard-agent" with model opus.
Prompt: "Tu es un ingénieur sécurité/compliance construisant le système de garde-fou
pour l'intégration LLM dans MINT.
Lis DANS CET ORDRE :
1. .claude/CLAUDE.md (banned terms, compliance rules)
2. LEGAL_RELEASE_CHECK.md (existing compliance checklist)
3. .claude/skills/mint-swiss-compliance/SKILL.md
4. docs/MINT_COACH_VIVANT_ROADMAP.md § S34 (ton spec complet)
5. .claude/AGENT_COACH_VIVANT_MASTER_PROMPT.md § S34

Tu construis ComplianceGuard + HallucinationDetector + PromptRegistry.
25 tests adversariaux minimum. Aucune sortie LLM ne doit atteindre un utilisateur
sans passer par ton guard. C'est le sprint le plus critique de toute la roadmap."
```

---

## 3. AGENT_SYSTEM_PROMPT.md UPDATES

The existing system prompt is good but needs extension for Coach Vivant.

### Add to § 2 (Interdictions Absolues):

```
- **No-Ranking** : Interdiction de classer des options financières par ordre de préférence.
  Les arbitrages sont présentés côte à côte, jamais classés.
- **No-Social-Comparison** : Interdiction de comparer l'utilisateur à d'autres
  ("top 20% des Suisses" → BANNI). Uniquement comparer à son propre passé.
- **No-LLM-Without-Guard** : Aucune sortie LLM ne peut atteindre l'utilisateur
  sans passer par le ComplianceGuard (à partir de S34).
```

### Add to § 4 (Règles Spécifiques):

```
### Arbitrage Engine Rules
- Toujours montrer au minimum 2 options côte à côte (jamais une seule)
- Rente vs Capital : TOUJOURS montrer 3 options (full rente, full capital, mixte oblig/suroblig)
- Hypothèses TOUJOURS visibles et modifiables par l'utilisateur
- Point de croisement TOUJOURS calculé et affiché quand les courbes se croisent
- Sensibilité TOUJOURS montrée : "Si le rendement passe de X% à Y%, le résultat s'inverse"

### Coach Layer Rules (à partir de S35)
- LLM = narrateur, jamais conseiller
- Chaque appel LLM indépendant (greeting, scoreSummary, tip, chiffreChoc)
- Fallback templates enrichis obligatoires (l'app fonctionne parfaitement sans BYOK)
- Cache invalidé par événement, pas par TTL fixe
- CoachContext ne contient JAMAIS : salaire exact, épargne exacte, dettes exactes, NPA, employeur
```

---

## 4. LEGAL_RELEASE_CHECK.md UPDATES

### Add new section:

```
## 6. Arbitrage Engine Compliance
- [ ] No option is presented as "better", "optimal", or "recommended".
- [ ] All comparisons show options side by side, never ranked.
- [ ] Hypotheses are visible and modifiable on every arbitrage screen.
- [ ] Sensitivity analysis is shown ("Si X change de Y%, le résultat s'inverse").
- [ ] Crossover point is displayed when trajectories intersect.
- [ ] Conditional language used throughout ("Dans ce scénario simulé...").
- [ ] Rente vs Capital ALWAYS shows mixed scenario (oblig/suroblig split).

## 7. Coach Layer Compliance (from S35+)
- [ ] ComplianceGuard validates ALL LLM output before display.
- [ ] HallucinationDetector verifies ALL numbers against financial_core.
- [ ] Banned terms check catches ALL terms from CLAUDE.md banned list.
- [ ] Prescriptive language check catches ALL imperative financial instructions.
- [ ] Disclaimer auto-injected when LLM discusses projections.
- [ ] No social comparison in milestones or coaching ("top X%" → BANNED).
- [ ] BYOK consent screen shows exactly which data is sent to which provider.
- [ ] Fallback templates produce compliant output without LLM.

## 8. Data Acquisition Compliance (from S42+)
- [ ] Document images NEVER stored (deleted after OCR extraction).
- [ ] On-device OCR by default (document never leaves phone).
- [ ] Cloud OCR requires explicit consent + data deleted after processing.
- [ ] Extracted values require user confirmation before profile injection.
- [ ] Source quality tracked per field (document vs manual vs estimated).
- [ ] Longitudinal snapshots require explicit opt-in consent (nLPD art. 5).
- [ ] User can delete all snapshots and extracted data at any time.
```

---

## 5. DefinitionOfDone.md UPDATES

### Add:

```
## Additional DoD — Coach Vivant Sprints (S30.5+)

- **Financial Core Integrity** (S30.5+):
  - Zero private `_calculate*` methods for financial logic outside `financial_core/`.
  - All CLAUDE.md constants verified identical in backend AND Flutter.
  - Parity check on 10 representative profiles (backend vs Flutter ±1 CHF).

- **Arbitrage Modules** (S32-S33):
  - No ranking of options in any user-facing text.
  - Hypotheses visible and editable on every comparison screen.
  - Sensitivity analysis included.
  - Min 15 backend tests per arbitrage module.

- **Compliance Guard** (S34 — BLOCKER):
  - 25+ adversarial tests passing.
  - 100% of CLAUDE.md banned terms caught.
  - Hallucination detector catches fabricated numbers (< 5% false negatives).
  - Fallback templates valid for every component.

- **Coach Layer** (S35+):
  - App functions identically without BYOK (enhanced fallback templates).
  - Every LLM call passes through ComplianceGuard.
  - Cache invalidation by event, not TTL.
  - CoachContext never includes raw financial amounts (except tax saving potential).

- **FRI** (S38-S39):
  - Only displayed when confidenceScore >= 50%.
  - Always shows breakdown (never total alone).
  - Never uses "faible", "mauvais", or social comparison.

- **Data Acquisition** (S41+):
  - Original images deleted after OCR.
  - Extracted values require user confirmation.
  - Source quality tracked per field.
```

---

## 6. TEST_ROADMAP.md UPDATES

### Add new personas for Coach Vivant:

```
## 5. Persona "Anna" (Onboarding Minimal — 3 Questions Only)
*   **Profil** : 28 ans, Salaire 75k, Canton VD. RIEN D'AUTRE.
*   **Flow Attendu** :
    *   Onboarding minimal : 3 questions seulement.
    *   Chiffre choc : "À la retraite, ton revenu estimé : CHF X/mois."
    *   Confiance : ~25% (afficher "Estimation basée sur 3 informations").
    *   Action : "Ouvrir un 3a" (car non déclaré).
    *   Arbitrage : NON accessible (confiance trop basse).

## 6. Persona "Pierre" (Arbitrage Rente vs Capital)
*   **Profil** : 58 ans, Cadre 130k, Marié, LPP 450k (300k oblig + 150k suroblig).
*   **Certificat LPP scanné** : confiance 85%.
*   **Flow Attendu** :
    *   Arbitrage rente vs capital : 3 options (full rente, full capital, mixte).
    *   Mixte doit montrer : oblig en rente (6.8%), suroblig en capital.
    *   Breakeven age calculé et affiché.
    *   Calendrier retraits : stagger 3a/LPP/conjoint.
    *   Chiffre choc : "En étalant tes retraits, tu économises ~CHF X d'impôt."

## 7. Persona "Julia" (Expat EU — Gaps)
*   **Profil** : 35 ans, Expat EU arrivée à 28, 90k, VD.
*   **Flow Attendu** :
    *   Archetype détecté : `expat_eu`.
    *   Chiffre choc prioritaire : "Tu as X années de cotisation AVS manquantes."
    *   AVS projetée inférieure à swiss_native équivalent.
    *   Convention bilatérale mentionnée.
    *   Arbitrage allocation annuelle : 3a prioritaire.

## 8. Persona "Laurent" (Coach Vivant — BYOK Active)
*   **Profil** : 40 ans, 100k, ZH, marié, 2 enfants, propriétaire. BYOK configuré.
*   **Flow Attendu** :
    *   Dashboard : greeting personnalisé (LLM via ComplianceGuard).
    *   Score summary : FRI affiché avec breakdown.
    *   Tip narratif : croisement archetype + calendar (si oct-dec → 3a).
    *   Milestone : si 3a maxé → celebration sans social comparison.
    *   Fallback test : désactiver BYOK → templates enrichis, app identique fonctionnellement.

## 9. Persona "Nadia" (Document Scan — LPP Certificate)
*   **Profil** : 42 ans, 85k, GE. Scanne son certificat LPP.
*   **Flow Attendu** :
    *   OCR extrait : avoir total, oblig/suroblig split, taux conversion, lacune rachat.
    *   Review screen : user confirme les valeurs.
    *   Confiance bondit de ~40% à ~70%.
    *   Rente vs capital maintenant accessible et précis.
    *   Chiffre choc recalculé avec vrais chiffres.
```

---

## 7. AGENTS_LOG.md — Template Entry for S30.5

### Add:

```
### 2026-02-XX — S30.5 Financial Core Unification (PLANNED)
- **Date:** [date]
- **Sujet:** Audit et nettoyage des doublons de calcul à travers le codebase
- **Symptôme:** Calculs financiers dupliqués dans N services, constantes divergentes backend/Flutter
- **Cause racine:** Croissance organique sur 30 sprints sans enforcement strict du financial_core
- **Fix:** [à documenter après exécution]
  - Doublons supprimés: N
  - Constantes alignées: N
  - Méthodes ajoutées à financial_core: N
  - Parity check backend/Flutter: N profils validés
- **Test ajouté:** Parity tests + regression tests
- **Doc/règle mise à jour:** CLAUDE.md (anti-patterns), ADR-20260223
- **Lien PR/commit:** [commit hash]
```

---

## 8. rules.md — Minimal Additions

### Add to § 3 (Fintech-grade):

```
- Arbitrage = comparaison, jamais classement. Montrer côte à côte avec hypothèses modifiables.
- LLM = narrateur, jamais conseiller. Tout output LLM passe par ComplianceGuard.
- Data = traçabilité source. Chaque champ financier tracé (document, manuel, estimé).
```

### Add to § 4 (UX):

```
- Onboarding minimal : 3 questions max avant le premier chiffre choc.
- Précision progressive : demander les données au moment où elles comptent, pas pendant l'onboarding.
- Score FRI : jamais "bon/mauvais", toujours "progression personnelle".
```

---

## 9. DOCUMENT MAP (final state after integration)

```
.claude/
    CLAUDE.md                              ← Project bible (constants, compliance, architecture)
    AGENT_FINANCIAL_CORE_UNIFICATION.md    ← S30.5 cleanup prompt
    AGENT_COACH_VIVANT_MASTER_PROMPT.md    ← S31-S40 agent execution prompt
    skills/
        mint-flutter-dev/SKILL.md
        mint-backend-dev/SKILL.md
        mint-swiss-compliance/SKILL.md
        mint-test-suite/SKILL.md
        mint-commit/SKILL.md

docs/
    ONBOARDING_ARBITRAGE_ENGINE.md         ← Onboarding + Arbitrage + FRI + Adaptive UX specs
    MINT_COACH_VIVANT_ROADMAP.md           ← Coach Layer execution plan (S34-S40)
    DATA_ACQUISITION_STRATEGY.md           ← Data precision strategy (S41-S46)
    MINT_V2_INTEGRATION_PATCH.md           ← THIS FILE (reconciliation)
    PLAN_ACTION_10_CHANTIERS.md            ← Original sprint planning (Gen 1)
    ROADMAP_EVENEMENTS_VIE.md              ← Life events matrix

Root:
    rules.md                               ← Technical + ethical rules (UPDATED)
    AGENTS.md                              ← Team workflow + sprint tracker (UPDATED)
    AGENT_SYSTEM_PROMPT.md                 ← Base system prompt for all agents (UPDATED)
    LEGAL_RELEASE_CHECK.md                 ← Wording compliance (UPDATED with §6-8)
    DefinitionOfDone.md                    ← Quality criteria (UPDATED with Coach Vivant DoD)
    TEST_ROADMAP.md                        ← Golden path personas (UPDATED with 5 new personas)
    AGENTS_LOG.md                          ← Error history (UPDATED with S30.5 template)

decisions/
    ADR-20260223-unified-financial-engine.md
    ADR-20260223-archetype-driven-retirement.md

visions/
    vision_product.md
    vision_features.md
    vision_compliance.md
    vision_trust_privacy.md
    vision_monetization.md
    vision_tech_stack.md
    vision_user_journeys.md
```

---

## 10. EXECUTION ORDER

```
Step 1: Apply this patch to all existing files (rules.md, AGENTS.md, etc.)
Step 2: Place new docs in correct locations (.claude/, docs/)
Step 3: Verify hierarchy of truth is identical in rules.md, AGENTS.md, CLAUDE.md
Step 4: Launch S30.5 (Financial Core Unification)
Step 5: Upon S30.5 completion → launch S31 + S34 in parallel
Step 6: Follow dependency graph from MINT_COACH_VIVANT_ROADMAP.md
```

---

*This is a one-time integration document. Once the patches are applied,
this file can be archived in docs/archive/.*

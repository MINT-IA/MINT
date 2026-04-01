# CLAUDE.md — MINT Project Context (auto-loaded)

> Loaded automatically at every session start. Single source of truth for all agents.
> For conflict resolution: `rules.md` (tier 1) > this file (tier 2). See § HIERARCHY.

---

## 1. IDENTITY

**MINT** — Swiss financial education app (Flutter + FastAPI).
**Mission**: "Juste quand il faut: une explication, une action, un rappel."
**Target V1**: 45-60 yo Swiss residents preparing retirement (couple focus). Secondary: 22-45 yo.
**Design for ALL ages**: UX, copy, and features MUST work for 22-65+. Never design screens, landing pages, or flows that exclude an age group. Segment by life event, not demographics.
**Model**: Read-only, education-first. No money movement. No investment advice.

---

## 2. ARCHITECTURE

```
apps/mobile/              # Flutter (Dart) — iOS/Android/Web
  lib/
    screens/              # Screens by module
    services/
      financial_core/     # ★ SHARED CALCULATORS — single source of truth
    widgets/              # Reusable widgets + educational inserts
    models/               # Data models
    constants/            # Centralized constants (social_insurance.dart)
    theme/colors.dart     # MintColors palette
    providers/            # Provider state management
    l10n/                 # ARB files (6 languages)

services/backend/         # FastAPI (Python)
  app/
    api/v1/endpoints/     # REST endpoints
    services/             # Business logic (pure functions, dataclasses)
    schemas/              # Pydantic v2 (camelCase alias)
  tests/                  # pytest suite

docs/                     # Strategy & specs (VISION_V1, CICD_ARCHITECTURE)
decisions/                # ADR (Architecture Decision Records)
visions/                  # Product vision (4 files)
education/inserts/        # Educational content (18 concept files)
legal/                    # CGU, Privacy, Disclaimer, Mentions légales
.claude/skills/           # Agent-specific skill files
```

### Financial Core Library (`lib/services/financial_core/`)

> **ADR**: `decisions/ADR-20260223-unified-financial-engine.md`

**All AVS, LPP, and tax calculations MUST use these centralized calculators.**

| Calculator | Key Methods | Source |
|-----------|-------------|--------|
| `avs_calculator.dart` | `computeMonthlyRente()`, `renteFromRAMD()`, `computeCouple()` | LAVS art. 21-40 |
| `lpp_calculator.dart` | `projectToRetirement()`, `projectOneMonth()`, `blendedMonthly()` | LPP art. 14-16 |
| `tax_calculator.dart` | `capitalWithdrawalTax()`, `progressiveTax()`, `estimateMonthlyIncomeTax()` | LIFD art. 38 |
| `confidence_scorer.dart` | `EnhancedConfidence` — 4-axis: completeness × accuracy × freshness × understanding | Profile completeness |
| `arbitrage_engine.dart` | `compareLumpSumVsAnnuity()`, `compareHousingOptions()` | Side-by-side scenarios |
| `monte_carlo_service.dart` | `runSimulation()` — 1000+ stochastic projections | Retirement probability |
| `withdrawal_sequencing_service.dart` | `optimizeWithdrawalOrder()` — LIFO/FIFO tax optimization | Withdrawal planning |
| `tornado_sensitivity_service.dart` | `computeSensitivity()` — what-if ±1-5% analysis | Sensitivity charts |

**Consumers** (must import `financial_core.dart`, never reimplement):
`retirement_projection_service`, `forecaster_service`, `lpp_deep_service`, `rente_vs_capital_calculator`, `expat_service`, `financial_report_service`

---

## 3. COMMANDS

```bash
# Backend (in services/backend/)
python3 -m pytest tests/ -q          # Run all tests
uvicorn app.main:app --reload        # Dev server

# Flutter (in apps/mobile/)
flutter analyze                       # Must be 0 errors
flutter test                          # Run tests
flutter gen-l10n                      # Regenerate i18n after ARB changes
```

---

## 4. DEV RULES

> Full git workflow details in `rules.md` (tier 1) and `docs/CICD_ARCHITECTURE.md`.

### Branch flow (NON-NEGOTIABLE)
```
feature/* ──PR──> dev ──PR──> staging ──PR──> main
```
- **Feature branches**: `feature/S{XX}-<slug>` from `dev`. Hotfix: `hotfix/<slug>`.
- **Push**: Direct to `dev` OK. NEVER to `staging` or `main`.
- **PRs**: feature→dev (squash), dev→staging (merge), staging→main (merge).
- **Promotion PRs**: "Staging to vX.Y.Z" / "Production to vX.Y.Z". Only when user requests.
- **Force push is BANNED**. Always `--rebase` on pull.

### Before ANY code modification
1. `git branch --show-current` — confirm feature branch (never `main`/`staging`)
2. `git status` — if dirty, ask user to stash/commit/discard

### Sprint execution method
**All sprints use autoresearch skills** as primary execution method (see `docs/ROADMAP_V2.md`):
`/autoresearch-calculator-forge`, `/autoresearch-test-generation`, `/autoresearch-prompt-lab`,
`/autoresearch-compliance-hardener`, `/autoresearch-ux-polish`, `/autoresearch-quality`,
`/autoresearch-i18n`, `/autoresearch-coach-evolution`

### Testing
- **Service files**: minimum 10 unit tests (edge cases + compliance)
- **Golden couple**: Julien + Lauren tested against known expected values
- **Before merge**: `flutter analyze` (0 issues) + `flutter test` + `pytest tests/ -q`

### Backend Conventions
- **Pure functions** for all calculations (deterministic, testable)
- **Pydantic v2**: `ConfigDict(populate_by_name=True)`, `alias_generator = to_camel`
- **Backend = source of truth** for constants and formulas. Flutter mirrors, never invents.
- **Contract change** → update `tools/openapi/` + `SOT.md`

---

## 5. BUSINESS RULES

### Key Constants (2025/2026)

**Pillar 3a**: Salarié LPP: **7'258 CHF/an** | Indépendant sans LPP: **20% revenu net, max 36'288 CHF/an**

**LPP**: Seuil d'accès: **22'680** (art. 7) | Coordination: **26'460** (art. 8) | Min coordonné: **3'780** | Conversion: **6.8%** (art. 14) | Bonif.: 7% (25-34), 10% (35-44), 15% (45-54), 18% (55-65) | EPL min: **20'000** (OPP2 art. 5) | EPL blocage: **3 ans** (art. 79b al. 3)

**AVS**: Taux total: **10.60%** (5.30+5.30) | Rente max: **30'240 CHF/an** | Cotisation min indép.: **530 CHF/an**

**Mortgage** (FINMA/ASB): Taux théorique: **5%** | Amortissement: **1%/an** | Frais: **1%/an** | Charges max: **1/3 revenu brut** | Fonds propres: **20%** (max 10% du 2e pilier)

**Capital withdrawal tax** (progressive):
`0-100k: ×1.00 | 100-200k: ×1.15 | 200-500k: ×1.30 | 500k-1M: ×1.50 | 1M+: ×1.70`

### Financial Archetypes (8 types)

> **ADR**: `decisions/ADR-20260223-archetype-driven-retirement.md`

Every projection MUST account for archetype. NEVER assume "Swiss native salarié".

| Archetype | Detection | Key difference |
|-----------|-----------|----------------|
| `swiss_native` | CH + arrivé < 22 | Modèle par défaut |
| `expat_eu` | EU + arrivé > 20 | Totalisation périodes EU |
| `expat_non_eu` | Hors EU + arrivé > 20 | Pas de convention |
| `expat_us` | US citizen/green card | FATCA, PFIC, double taxation |
| `independent_with_lpp` | Indép. + LPP déclarée | Rachat possible |
| `independent_no_lpp` | Indép. + pas de LPP | 3a max 36'288 |
| `cross_border` | Permis G / frontalier | Impôt source |
| `returning_swiss` | CH + séjour étranger | Rachat avantageux |

### Life Events (18 — definitive enum)
```
Famille:       marriage, divorce, birth, concubinage, deathOfRelative
Professionnel: firstJob, newJob, selfEmployment, jobLoss, retirement
Patrimoine:    housingPurchase, housingSale, inheritance, donation
Santé:         disability
Mobilité:      cantonMove, countryMove
Crise:         debtCrisis
```

### Confidence Score (mandatory on ALL projections)
- `EnhancedConfidence` (0-100%) — **4-axis**: completeness × accuracy × freshness × understanding (geometric mean)
- `enrichmentPrompts` — actions to improve accuracy (axis-specific)
- Uncertainty band (min/max) when confidence < 70%
- Data sources: estimated(0.25), userInput(0.60), crossValidated(0.70), certificate(0.95), openBanking(1.00)
- Understanding axis: financial literacy engagement (beginner/intermediate/advanced + coach session bonus)

### Capital vs Rente Taxation (CRITICAL)
- **Rente LPP** = revenu imposable annuel (LIFD art. 22)
- **Capital retiré** = taxé séparément au retrait (LIFD art. 38)
- **SWR withdrawals** = consommation de patrimoine, PAS un revenu imposable
- **NEVER double-tax**: retrait tax + income tax on SWR

---

## 6. COMPLIANCE RULES (NON-NEGOTIABLE)

### Interdictions Absolues
1. **Read-Only**: No virements, paiements, or bank account modifications
2. **No-Advice**: No specific product recommendations (no ISINs, no tickers). Asset classes only.
3. **No-Promise**: No guaranteed returns. Always use scenarios (Bas/Moyen/Haut) + disclaimers.
4. **No-Ranking**: Arbitrage options shown side-by-side, never ranked.
5. **No-Social-Comparison**: "top 20% des Suisses" → BANNED. Compare only to user's own past.
6. **No-LLM-Without-Guard**: All LLM output passes through ComplianceGuard before reaching user.
7. **Privacy**: Never log identifiable data (IBANs, names, SSN, employer).

### Banned Terms (never use in user-facing text)
- "garanti", "certain", "assuré", "sans risque"
- "optimal", "meilleur", "parfait" (as absolutes)
- "conseiller" → use "spécialiste" (inclusive)

### Required in Every Calculator/Service Output
- `disclaimer` — "outil éducatif", "ne constitue pas un conseil", "LSFin"
- `sources` — Legal references (LPP art. X, LIFD art. Y)
- `chiffre_choc` — One impactful number with explanatory text
- `alertes` — Warnings when thresholds are crossed

### Swiss Law References
LPP (2e pilier) | LAVS (1er pilier) | OPP3 (3e pilier) | LIFD (impôt fédéral) | LAMal (assurance maladie) | CO (obligations) | CC (civil) | FINMA circulars

### Language & Voice
- **Full spec**: `docs/VOICE_SYSTEM.md` — pillars, tone by context, audience adaptations, 50 avant/après
- User-facing text in French (informal "tu"), inclusive ("un·e spécialiste")
- Educational tone, never prescriptive. Conditional language ("pourrait", "envisager").
- Non-breaking space (`\u00a0`) before `!`, `?`, `:`, `;`, `%`
- Voice: calme, précis, fin, rassurant, net. Jamais générique, jamais infantilisant.
- Adapt by context (discovery/stress/victory), mastery level, and product moment — NOT by age.

### Regional Swiss Voice Identity (NON-NEGOTIABLE)
- **MINT must sound locally rooted** per the user's canton and linguistic region.
- **Suisse Romande** (VD, GE, NE, JU, VS, FR): "septante/nonante", dry humor, pragmatic. VS = direct/montagnard, GE = cosmopolite, VD = détendu.
- **Deutschschweiz** (ZH, BE, LU, ZG, AG, SG, etc.): "Znüni", savings culture, practical wisdom. ZH = urban/finance-savvy, BE = gemütlich, ZG = tax pride.
- **Svizzera Italiana** (TI, GR partly): warm Mediterranean flair + Swiss rigor, family savings, grotto references, lake life.
- **Implementation**: `RegionalVoiceService.forCanton()` → injects regional prompt into coach system prompt via `context_injector_service.dart`.
- **Rule**: NEVER caricature. Always subtle — like an inside joke between locals. The kind of thing that makes someone smile and think "this app really knows my region."
- **Backend**: `claude_coach_service.py` system prompt includes REGIONAL IDENTITY section guiding Claude's tone adaptation.

---

## 7. UX RULES

### Design System (Flutter)
- **Full spec**: `docs/DESIGN_SYSTEM.md` — tokens, components, screen categories, checklist
- **Fonts**: Montserrat (headings), Inter (body) via GoogleFonts. Outfit is deprecated.
- **Colors**: `MintColors.*` from `lib/theme/colors.dart` — NEVER hardcode hex. Core palette = 12 tokens (see DESIGN_SYSTEM.md §3.2).
- **Navigation**: GoRouter — no `Navigator.push`
- **State**: Provider — no raw StatefulWidget for shared data
- **Material 3**, responsive layout, CustomPainter for charts
- **AppBar**: White background standard. Exception: Pulse only uses gradient primary.
- **Deprecated**: `MintGlassCard`, `MintPremiumButton`, `Outfit` font — do not use in new code.

### i18n (NON-NEGOTIABLE)
- **6 languages**: fr (template), en, de, es, it, pt — ARB files in `lib/l10n/`
- **ALL user-facing strings** → `AppLocalizations.of(context)!.key`
- **New string**: add to ALL 6 ARB files, add keys at END (before `}`)
- **Run `flutter gen-l10n`** after modifying ARB files
- **French diacritics mandatory**: é, è, ê, ô, ù, ç, à — ASCII "e" for accented = bug

### Navigation Architecture (target — S52+)
- **Full spec**: `docs/NAVIGATION_GRAAL_V10.md`
- **Philosophy**: Coach-first, UI-assisted. AI-as-layer, NOT chatbot-first.
- **Shell**: 4 tabs — Aujourd'hui | Coach | Explorer | Dossier
- **Capture**: Contextual bottom sheet (scan, import, add data) — NOT a global FAB
- **Explorer**: 7 hubs (Retraite, Famille, Travail & Statut, Logement, Fiscalité, Patrimoine & Succession, Santé & Protection)
- **Screen types**: Destination (user mental map), Flow (triggered by intent), Tool (opened contextually), Alias (legacy compat)
- **Internal taxonomies** (`arbitrage`, `lpp-deep`, `3a-deep`, `segments`) are NOT visible in user navigation
- **All 67 canonical routes remain as deep links** — restructuring is UX surface, not route deletion

### UX Principles (from `rules.md`)
- Progressive disclosure — no bank connection upfront
- 1 screen = 1 intention
- Each recommendation → 1-3 concrete next actions
- Onboarding minimal: 3 questions + revenu before first chiffre choc
- Precision progressive: ask data when it matters, not during onboarding
- Score FRI: never "bon/mauvais", always "progression personnelle"

### Coach & Arbitrage Rules
- **Coach**: LLM = narrator, never advisor. Fallback templates required (app works without BYOK).
- **Arbitrage**: Always ≥ 2 options side-by-side. Rente vs Capital: always 3 (full rente, full capital, mixed).
- **Hypotheses**: Always visible and editable by user.
- **Sensitivity**: Always shown ("Si rendement passe de X% à Y%, le résultat s'inverse").
- **Safe Mode**: If toxic debt detected → disable optimizations (3a/LPP), priority = debt reduction.
- **CoachContext**: NEVER contains exact salary, savings, debts, NPA, or employer.

---

## 8. GOLDEN TEST COUPLE: Julien + Lauren

> Source of truth: `test/golden/` (xlsx + PDF certificats + JPEG)

| | Julien | Lauren |
|--|--------|--------|
| Né le | 12.01.1977 | 23.06.1982 |
| Âge (03.2026) | **49** | **43** |
| Salaire brut | **122'207 CHF/an** | **67'000 CHF/an** |
| Canton | **VS** (Sion) | **VS** (Crans-Montana) |
| Nationalité | CH | US (FATCA) |
| Archetype | swiss_native | expat_us |
| Caisse LPP | **CPE** (rémun. 5%) | **HOTELA** |
| Salaire assuré LPP | **91'967 CHF** (CPE Plan Maxi) | standard coordonné |
| Bonif. vieillesse caisse | **24%** (CPE Plan Maxi, part vieillesse) | standard légal |
| Avoir LPP | **70'377 CHF** | **19'620 CHF** |
| Rachat max LPP | **539'414 CHF** | **52'949 CHF** |
| LPP projeté 65 | 677'847 (rente ~33'892/an) | ~153'000 |
| 3a capital | 32'000 | 14'000 |
| AVS couple (marié, cap 150%) | **3'780 CHF/mois** (LAVS art. 35) |
| Taux remplacement | **65.5%** (~8'505 vs 12'978 net/mois) |

> Note : le taux de 65.5% utilise le revenu net combiné du couple (Julien + Lauren).
> Le code peut produire un résultat différent selon la projection LPP utilisée
> (formule légale standard vs certificat CPE Plan Maxi).

---

## 9. ANTI-PATTERNS (never do)

1. **Code without reading existing code** — understand before modifying
2. **Diverge backend vs Flutter constants** — backend is source of truth
3. **Use banned terms** in user-facing text
4. **Skip tests** — always run before committing
5. **Create files unnecessarily** — prefer editing existing
6. **Promise returns** — use scenarios + disclaimers
7. **Commit non-sprint files** — surgical `git add`
8. **Assume Swiss native** — always check archetype
9. **Projection without confidence score** — always include uncertainty band
10. **Double-tax capital** — capital taxed at withdrawal (LIFD art. 38), SWR ≠ income
11. **Duplicate calculation logic** — NEVER create `_calculate*()` in services. Use `financial_core/`.
12. **Ignore future AVS years** — `AvsCalculator` adds future years. Don't use raw `contributionYears / 44`.
13. **Apply married AVS cap to concubins** — LAVS art. 35 cap (150%) = married only.
14. **Hardcode strings** — ALL user-facing text in ARB files via `AppLocalizations`
15. **Hardcode colors** — NEVER `Color(0xFF...)`, always `MintColors.*`

---

## 10. AGENT TEAM & HIERARCHY

### Team: Swiss-Brain (spec) → Python-Agent (backend) → Dart-Agent (UI) → Team Lead (review)

| Agent | Model | Scope | Skill |
|-------|-------|-------|-------|
| Team Lead | Opus | orchestrate, review, merge | `mint-commit` |
| dart-agent | Sonnet | `apps/mobile/` only | `mint-flutter-dev` |
| python-agent | Sonnet | `services/backend/` only | `mint-backend-dev` |
| swiss-brain | Opus | specs, compliance, docs | `mint-swiss-compliance` |

### Autoresearch Skills (10 — Karpathy loop pattern)

| Skill | Purpose | Metric |
|-------|---------|--------|
| `/autoresearch-quality` | Bug hunter (flutter test → fix code → verify) | test failure count |
| `/autoresearch-calculator-forge` | Financial calc edge-case validator | calculation accuracy % |
| `/autoresearch-test-generation` | Autonomous test factory | test coverage % |
| `/autoresearch-prompt-lab` | Coach AI prompt optimizer | prompt quality score |
| `/autoresearch-compliance-hardener` | Adversarial compliance tester | compliance pass rate |
| `/autoresearch-coach-evolution` | Coaching content optimizer (lifecycle-aware) | composite text score |
| `/autoresearch-i18n` | Hardcoded string extraction | hardcoded string count |
| `/autoresearch-ux-polish` | UX law violation scanner+fixer | ux violations count |
| `/autoresearch-test-coverage` | Test gap auditor + delegator | uncovered services |
| `/autoresearch-privacy-guard` | PII leak scanner + fixer | PII violations count |

### Conflict resolution (priority order)
1. `rules.md` — Non-negotiable technical + ethical rules
2. `CLAUDE.md` (this file) — Project context, constants, compliance
3. `docs/MINT_UX_GRAAL_MASTERPLAN.md` — UX/product umbrella: templates, CapEngine, screen board
4. `docs/DOCUMENTATION_OPERATING_SYSTEM.md` — Which doc to read for which task
5. `.claude/skills/` — Agent-specific conventions
6. `LEGAL_RELEASE_CHECK.md` — Wording compliance checklist
7. `visions/` — Product vision + limits
8. `decisions/` (ADR) — Architecture decisions
9. `docs/` — Strategy specs
10. `SOT.md` + OpenAPI — Data contracts
11. Code — Implementation follows documents

If code contradicts 1-9: fix the code OR write an ADR.

---

## 11. STRATEGIC ROADMAP V2

> Full details: `docs/ROADMAP_V2.md` | Based on: `visions/MINT_Analyse_Strategique_Benchmark.md`

| Phase | Sprints | Focus | Key Features |
|-------|---------|-------|-------------|
| 1 "Le Conversationnel" | S51-S56 | MINT parle | Chat AI, 3a rétroactif, 13e rente AVS, Financial Health Score, streaks+milestones, RAG v1 |
| 2 "Le Compagnon" | S57-S62 | MINT s'adapte | Lifecycle Engine (7 phases), AI memory, Weekly Recap, cantonal benchmarks, JITAI nudges |
| 3 "L'Expert" | S63-S68 | MINT indispensable | Voice AI, multi-LLM, Expert tier (human advisors), advanced gamification |
| 4 "La Référence" | S69+ | Standard suisse | Institutional APIs, B2B caisses+RH, Open Finance, expansion DACH |

**Execution method**: All sprints use autoresearch dev skills (`visions/MINT_Autoresearch_Dev_Agents.md`).

---

## 12. REFERENCE DOCUMENTS

| Document | Purpose |
|----------|---------|
| `rules.md` | Tier 1: fintech-grade principles, UX rules, workflow |
| `docs/DOCUMENTATION_OPERATING_SYSTEM.md` | Task-based reading order + documentation hierarchy |
| `SOT.md` | Data contracts: Profile, SessionReport, EnhancedConfidence |
| `LEGAL_RELEASE_CHECK.md` | Pre-release compliance gate |
| `DefinitionOfDone.md` | Sprint completion criteria |
| `docs/ROADMAP_V2.md` | Strategic roadmap V2 (benchmark-driven, 4 phases) |
| `docs/VISION_UNIFIEE_V1.md` | Historical strategic vision; useful principles, obsolete IA |
| `docs/CICD_ARCHITECTURE.md` | Full CI/CD pipeline reference |
| `docs/ONBOARDING_ARBITRAGE_ENGINE.md` | Onboarding + arbitrage specs |
| `docs/DATA_ACQUISITION_STRATEGY.md` | OCR, guided entry, Open Banking |
| `docs/MINT_UX_GRAAL_MASTERPLAN.md` | UX/product umbrella: templates, visual graal, CapEngine, screen board |
| `docs/DESIGN_SYSTEM.md` | Visual direction + tokens + components + screen categories + checklist |
| `docs/VOICE_SYSTEM.md` | Editorial system: brand voice, tone by context, microcopy, 50 avant/après |
| `docs/NAVIGATION_GRAAL_V10.md` | Detailed target IA; subordinate to masterplan for product direction |
| `docs/BLUEPRINT_COACH_AI_LAYER.md` | Coach AI implementation blueprint; subordinate to masterplan |
| `docs/UX_WIDGET_REDESIGN_MASTERPLAN.md` | UX 7 laws + 75 creative proposals |
| `visions/MINT_Analyse_Strategique_Benchmark.md` | 40+ app benchmark + academic research |
| `visions/MINT_Autoresearch_Dev_Agents.md` | 10 dev agents (build) — sprint execution method |
| `visions/MINT_Autoresearch_Agents.md` | 10 veille agents (post-launch) |
| `visions/vision_product.md` | Core promise, acquisition strategy |
| `visions/vision_compliance.md` | LSFin, FINMA, nLPD framework |
| `legal/DISCLAIMER.md` | User-facing educational disclaimer |

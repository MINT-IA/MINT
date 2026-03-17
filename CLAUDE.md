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

### Language
- User-facing text in French (informal "tu"), inclusive ("un·e spécialiste")
- Educational tone, never prescriptive. Conditional language ("pourrait", "envisager").
- Non-breaking space (`\u00a0`) before `!`, `?`, `:`, `;`, `%`

---

## 7. UX RULES

### Design System (Flutter)
- **Fonts**: Montserrat (headings), Inter (body) via GoogleFonts
- **Colors**: `MintColors.*` from `lib/theme/colors.dart` — NEVER hardcode hex
- **Navigation**: GoRouter — no `Navigator.push`
- **State**: Provider — no raw StatefulWidget for shared data
- **Material 3**, responsive layout, CustomPainter for charts
- **AppBar**: SliverAppBar with gradient from MintColors.primary

### i18n (NON-NEGOTIABLE)
- **6 languages**: fr (template), en, de, es, it, pt — ARB files in `lib/l10n/`
- **ALL user-facing strings** → `AppLocalizations.of(context)!.key`
- **New string**: add to ALL 6 ARB files, add keys at END (before `}`)
- **Run `flutter gen-l10n`** after modifying ARB files
- **French diacritics mandatory**: é, è, ê, ô, ù, ç, à — ASCII "e" for accented = bug

### UX Principles (from `rules.md`)
- Progressive disclosure — no bank connection upfront
- 1 screen = 1 intention
- Each recommendation → 1-3 concrete next actions
- Onboarding minimal: 3 questions max before first chiffre choc
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
| Avoir LPP | **70'377 CHF** | **19'620 CHF** |
| Rachat max LPP | **539'414 CHF** | **52'949 CHF** |
| LPP projeté 65 | 677'847 (rente ~33'892/an) | ~153'000 |
| 3a capital | 32'000 | 14'000 |
| AVS couple | 2'500 CHF/mois |
| Taux remplacement | **65.5%** (~8'505 vs 12'978 net/mois) |

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
3. `.claude/skills/` — Agent-specific conventions
4. `LEGAL_RELEASE_CHECK.md` — Wording compliance checklist
5. `visions/` — Product vision + limits
6. `decisions/` (ADR) — Architecture decisions
7. `docs/` — Strategy specs
8. `SOT.md` + OpenAPI — Data contracts
9. Code — Implementation follows documents

If code contradicts 1-8: fix the code OR write an ADR.

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
| `SOT.md` | Data contracts: Profile, SessionReport, EnhancedConfidence |
| `LEGAL_RELEASE_CHECK.md` | Pre-release compliance gate |
| `DefinitionOfDone.md` | Sprint completion criteria |
| `docs/ROADMAP_V2.md` | Strategic roadmap V2 (benchmark-driven, 4 phases) |
| `docs/VISION_UNIFIEE_V1.md` | Unified V1 vision (7 hermeneutic principles, 3 tabs) |
| `docs/CICD_ARCHITECTURE.md` | Full CI/CD pipeline reference |
| `docs/ONBOARDING_ARBITRAGE_ENGINE.md` | Onboarding + arbitrage specs |
| `docs/DATA_ACQUISITION_STRATEGY.md` | OCR, guided entry, Open Banking |
| `docs/UX_WIDGET_REDESIGN_MASTERPLAN.md` | UX 7 laws + 75 creative proposals |
| `visions/MINT_Analyse_Strategique_Benchmark.md` | 40+ app benchmark + academic research |
| `visions/MINT_Autoresearch_Dev_Agents.md` | 10 dev agents (build) — sprint execution method |
| `visions/MINT_Autoresearch_Agents.md` | 10 veille agents (post-launch) |
| `visions/vision_product.md` | Core promise, acquisition strategy |
| `visions/vision_compliance.md` | LSFin, FINMA, nLPD framework |
| `legal/DISCLAIMER.md` | User-facing educational disclaimer |

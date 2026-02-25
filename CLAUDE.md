# CLAUDE.md — MINT Project Context (auto-loaded)

> This file is automatically loaded by Claude Code at every session start.
> It ensures every agent (main session or spawned teammate) has full project context.

---

## IDENTITY

**MINT** — Swiss financial education app (Flutter + FastAPI).
**Mission**: "Juste quand il faut: une explication, une action, un rappel."
**Target**: 22-45 yo Swiss residents navigating financial complexity (3a, LPP, taxes, mortgage, debt).
**Model**: Read-only, education-first. No money movement. No investment advice.

---

## ARCHITECTURE

```
apps/mobile/          # Flutter (Dart) — iOS/Android/Web
  lib/
    screens/          # Screens organized by module (advisor/, budget/, mortgage/, independants/, etc.)
    services/         # Pure Dart calculators (mirror backend logic)
      financial_core/ # ★ SHARED CALCULATORS — single source of truth (see below)
    widgets/          # Reusable widgets + educational inserts
    models/           # Data models (age_band_policy, session, etc.)
    theme/colors.dart # MintColors palette
    providers/        # Provider state management

services/backend/     # FastAPI (Python)
  app/
    api/v1/endpoints/ # REST endpoints by module
    services/         # Business logic services (pure functions, dataclasses)
    schemas/          # Pydantic v2 schemas (camelCase alias)
  tests/              # pytest test suite

docs/                 # Strategy, roadmaps, plans
visions/              # Product vision documents (7 files)
education/inserts/    # Educational content by wizard question
decisions/            # ADR (Architecture Decision Records)
```

### Financial Core Library (`services/financial_core/`)

> **ADR**: `decisions/ADR-20260223-unified-financial-engine.md`

**All AVS, LPP, and tax calculations MUST use these centralized calculators.**
Never duplicate calculation logic in service-specific files.

| File | Methods | Source |
|------|---------|--------|
| `avs_calculator.dart` | `computeMonthlyRente()`, `renteFromRAMD()`, `computeCouple()` | LAVS art. 21-40 |
| `lpp_calculator.dart` | `projectToRetirement()`, `projectOneMonth()`, `blendedMonthly()` | LPP art. 14-16 |
| `tax_calculator.dart` | `capitalWithdrawalTax()`, `progressiveTax()`, `estimateMonthlyIncomeTax()` | LIFD art. 38 |
| `confidence_scorer.dart` | `ConfidenceScorer.score(profile)` | Profile completeness |
| `financial_core.dart` | Barrel export | — |

**Consumers** (all must import `financial_core.dart`, never reimplement):
- `retirement_projection_service.dart` — main retirement engine
- `forecaster_service.dart` — dashboard 3-scenario projections
- `lpp_deep_service.dart` — EPL simulator, LPP comparison
- `rente_vs_capital_calculator.dart` — rente vs capital breakeven
- `expat_service.dart` — AVS gap analysis
- `financial_report_service.dart` — comprehensive financial report

---

## COMMANDS

### Backend (in `services/backend/`)
```bash
python3 -m pytest tests/ -q          # Run all tests
python3 -m pytest tests/test_X.py -v # Run specific test file
uvicorn app.main:app --reload        # Dev server
```

### Flutter (in `apps/mobile/`)
```bash
flutter analyze                       # Static analysis (must be 0 errors)
flutter test                          # Run tests
flutter run                           # Run app
```

---

## GIT SYNC PROTOCOL (NON-NEGOTIABLE)

### At the START of every task/sprint/session
```bash
git fetch --all
git status
git pull --rebase origin main
# If on a feature branch:
git pull --rebase origin <current-branch>
# If conflicts exist → STOP, report to user, do NOT auto-resolve.
```

### At the END of every task/sprint/session
```bash
git add <only sprint-relevant files>
git status  # show user what will be committed
git commit -m "S{XX}: <description concise>"
git push origin <current-branch>
```

### Branch convention
- Feature work: `feature/S{XX}-<slug>` (e.g. `feature/S35-slm-coach`)
- Hotfix: `hotfix/<description>`
- Always branch from latest `main`
- Never commit directly to `main` without explicit user approval

### Before ANY code modification
1. Confirm current branch with `git branch --show-current`
2. Confirm no uncommitted changes with `git status`
3. If dirty working tree → ask user whether to stash, commit, or discard

### Rules
- **NEVER** force push (`git push --force` is BANNED)
- **NEVER** auto-merge branches without user approval
- **ALWAYS** use `--rebase` on pull (no merge commits)
- **ALWAYS** show `git status` output before committing
- **ALWAYS** delete feature branches after merge (`git branch -d <branch>` local + `git push origin --delete <branch>` remote)

---

## COMPLIANCE RULES (NON-NEGOTIABLE)

### Banned terms (never use in user-facing text)
- "garanti", "certain", "assuré", "sans risque"
- "optimal", "meilleur", "parfait" (as absolutes)
- "conseiller" → use "specialiste" (inclusive)

### Required in every calculator/service output
- `disclaimer: str` — Must mention "outil educatif", "ne constitue pas un conseil", "LSFin"
- `sources: List[str]` — Legal references (LPP art. X, LIFD art. Y, etc.)
- `chiffre_choc` — One impactful number with explanatory text
- `alertes: List[str]` — Warnings when thresholds are crossed

### Swiss law references (cite these)
- LPP (Loi sur la prévoyance professionnelle) — 2nd pillar
- LAVS (Loi sur l'AVS) — 1st pillar
- OPP3 (Ordonnance 3e pilier) — Pillar 3a
- LIFD (Loi sur l'impôt fédéral direct) — Federal taxes
- LAMal (Loi sur l'assurance-maladie) — Health insurance
- CO (Code des obligations) — Employment law
- CC (Code civil) — Family/succession law
- FINMA circulars — Banking regulation

### Language
- All user-facing text in French (informal "tu")
- Inclusive: "un·e spécialiste", "salarié·e"
- Educational tone, never prescriptive

---

## DESIGN SYSTEM (Flutter)

- **Fonts**: GoogleFonts — Montserrat (headings), Inter (body)
- **Colors**: `MintColors` from `lib/theme/colors.dart`
- **Navigation**: GoRouter
- **State**: Provider
- **AppBar**: SliverAppBar with gradient from MintColors.primary
- **Material 3** design
- **Responsive layout**
- **CustomPainter** for charts and visualizations

---

## BACKEND CONVENTIONS

- **Pure functions** for all financial calculations (deterministic, testable)
- **Dataclasses** for internal models
- **Pydantic v2** for API schemas: `model_config = ConfigDict(populate_by_name=True)`, `alias_generator = to_camel`
- **Backend = source of truth** for all constants and formulas (Flutter must align)
- Every service in its own module directory under `app/services/`
- Tests: at least 10 tests per service, edge cases, compliance checks

---

## SPRINT PROGRESS TRACKER

| Sprint | Module | Backend | Flutter | Tests | Commit |
|--------|--------|---------|---------|-------|--------|
| S0-S8 | Core + Budget + RAG + Bank Import | done | done | done | various |
| S9 | Job Change LPP Comparator | done | done | done | `6e37675` |
| S10 | Divorce + Succession | done | done | done | `92bb677` |
| S11 | Proactive Coaching Engine | done | done | done | `8e2f2d3` |
| S12 | Sociological Segments | done | done | done | `3eb7a00` |
| S13 | LAMal Franchise Optimizer | done | done | done | `1ef929d` |
| S14 | Open Banking bLink/SFTI | done | done | done | `49c64be` |
| S15 | LPP Deep Dive | done | done | done | `8259894` |
| S16 | 3a Deep + Debt Prevention | done | done | done | `aa9b607` |
| S17 | Mortgage + Real Estate | done | done | 68 tests | `71460f9` |
| S18 | Indépendants complet | done | done | 66 tests | `5ed7c24` |
| S19 | Chômage + Premier emploi | done | done | 72 tests | `fb8a035` |
| S20 | Fiscalité avancée (26 cantons) | done | done | 53 tests | `4bde23a` |
| S21 | Retraite complète | done | done | 50 tests | `9005cfe` |
| S22 | Mariage + Naissance + Concubinage | done | done | done | various |
| S23 | Expatriation + Frontaliers | done | done | 87 tests | `868cb02` |
| S24 | Housing Sale + Donation (18/18 events) | done | done | done | `a16d5eb` |
| S25 | Integration & Discoverability | done | done | 1314 tests | `b59909f` |
| S26 | Post-Wizard Routing + NextSteps | done | done | 1357 tests | `637854c` |
| S27 | Educational Insert Wiring + Content | done | done | 1576 tests | `d1584e1` |
| S28 | SafeMode Enforcement + Compliance Tests | done | done | 1596 tests | `54026e3` |
| S29 | Smoke Test Coverage (26 screens) | done | done | 52 Flutter tests | `968f972` |
| S30 | Disability Gap Service (Chantier 3) | done | done | 1629 tests | `4d6f317` |

**Backend test baseline**: 1965 passed, 0 failed, 80 skipped
**Flutter analyze**: 0 errors (~896 info/warnings)
**i18n**: 6 locales (fr, de, en, es, it, pt) — `2fc39a1`
**QA fix**: LPP 3780 + AVS 2520 aligned — `750286b`
**Financial Core**: unified AVS/LPP/Tax calculators + confidence scorer — `656e620`

---

## DREAM TEAM WORKFLOW

### Sprint execution pattern
```
1. Plan sprint scope (read PLAN_ACTION_10_CHANTIERS.md)
2. Launch 2 agents in parallel:
   - Backend agent: services + schemas + endpoints + tests
   - Flutter agent: service + screens
3. Verify baseline (tests + analyze) before integration
4. Senior audit: cross-check backend vs Flutter for divergences
   - Constants must match exactly (rates, limits, brackets)
   - Formulas must produce identical results
   - Conventions must align (rounding, edge cases)
5. Fix all CRIT divergences (backend = source of truth, except when Flutter is correct)
6. Run all tests + flutter analyze
7. Surgical git commit (only sprint-specific files)
```

### Financial Core (shared calculation engine)
> **ADR**: `decisions/ADR-20260223-unified-financial-engine.md` — READ THIS before touching any calculator.

All financial calculations MUST use the shared core in `lib/services/financial_core/`:
- `AvsCalculator` — AVS rente (LAVS art. 21-29, 34, 35, 40)
- `LppCalculator` — LPP projection + bonifications (LPP art. 15-16)
- `TaxCalculator` — Capital withdrawal + income tax (LIFD art. 38)
- `ThreeACalculator` — 3a projection (OPP3 art. 7)
- `ConfidenceScorer` — Projection confidence score

**NEVER duplicate formulas** in RetirementProjectionService or ForecasterService.
Both services are thin adapters over the shared core.

### Agent specs template (for spawning)
When launching agents, always specify:
- Swiss law sources and article references
- Exact constants and formulas (barèmes, taux, plafonds)
- Compliance rules (disclaimer, sources, chiffre_choc, banned terms)
- Design system rules (fonts, colors, navigation, state)
- Test requirements (minimum count, edge cases, compliance checks)

---

## KEY CONSTANTS (Source of Truth)

### Pillar 3a (2025/2026)
- Salarié affilié LPP: **7'258 CHF/an**
- Indépendant sans LPP: **20% du revenu net, max 36'288 CHF/an**

### LPP
- Seuil d'accès: **22'680 CHF/an** (LPP art. 7)
- Déduction de coordination: **26'460 CHF** (LPP art. 8)
- Salaire coordonné minimum: **3'780 CHF**
- Taux de conversion minimum: **6.8%** (part obligatoire, LPP art. 14)
- Bonification par âge: 7% (25-34), 10% (35-44), 15% (45-54), 18% (55-65)
- EPL minimum: **20'000 CHF** (OPP2 art. 5)
- EPL blocage rachat: **3 ans** (LPP art. 79b al. 3)

### AVS (2025/2026)
- Taux total: **10.60%** (employé 5.30% + employeur 5.30%)
- Rente maximale individuelle: **30'240 CHF/an**
- Cotisation minimale indépendant: **530 CHF/an**

### Mortgage (FINMA/ASB)
- Taux théorique: **5%** (Tragbarkeitsrechnung)
- Amortissement: **1%/an**
- Frais accessoires: **1%/an** (sur prix d'achat)
- Ratio charges max: **1/3** du revenu brut
- Fonds propres minimum: **20%** (max 10% du 2e pilier)

### Taxation capital withdrawal (progressive brackets)
```
0-100k:     base_rate × 1.00
100k-200k:  base_rate × 1.15
200k-500k:  base_rate × 1.30
500k-1M:    base_rate × 1.50
1M+:        base_rate × 1.70
```

---

## LIFE EVENTS (18 types — definitive enum)

```
Famille:      marriage, divorce, birth, concubinage, deathOfRelative
Professionnel: firstJob, newJob, selfEmployment, jobLoss, retirement
Patrimoine:    housingPurchase, housingSale, inheritance, donation
Santé:         disability
Mobilité:      cantonMove, countryMove
Crise:         debtCrisis
```

---

## FINANCIAL ARCHETYPES (retirement projections)

> **ADR**: `decisions/ADR-20260223-archetype-driven-retirement.md` — READ THIS for full context.

Every retirement/prevoyance calculation MUST account for the user's archetype.
Do NOT assume "Swiss native salarié" for all profiles.

| Archetype | Detection | LPP | AVS | Key difference |
|-----------|-----------|-----|-----|----------------|
| `swiss_native` | CH + arrivé < 22 | Bonif. depuis 25 ans | Plein | Modèle par défaut |
| `expat_eu` | EU + arrivé > 20 | Bonif. depuis `arrivalAge` | Partiel + convention bilat. | Totalisation périodes EU |
| `expat_non_eu` | Hors EU + arrivé > 20 | Bonif. depuis `arrivalAge` | Partiel | Pas de convention |
| `expat_us` | US citizen/green card | Bonif. depuis `arrivalAge` | Partiel + Social Security | FATCA, PFIC, double taxation |
| `independent_with_lpp` | Indép. + LPP déclarée | Facultative (solde réel) | Standard | Rachat possible |
| `independent_no_lpp` | Indép. + pas de LPP | **0** | Standard | 3a max 36'288 |
| `cross_border` | Permis G / frontalier | LPP suisse standard | Convention bilat. | Impôt source |
| `returning_swiss` | CH + séjour étranger | Libre passage + bonif. retour | Avec lacunes | Rachat avantageux |

### Confidence Score (mandatory on all projections)

Every projection MUST include:
- `confidenceScore` (0-100%) based on data completeness for the detected archetype
- `enrichmentPrompts` — actions the user can take to improve accuracy
- Uncertainty band (min/max) when confidence < 70%

### Capital vs Rente taxation (CRITICAL)

- **Rente LPP** = revenu imposable annuel (LIFD art. 22)
- **Capital LPP retiré** = taxé séparément au retrait (LIFD art. 38), retraits SWR = consommation de patrimoine, PAS un revenu imposable
- NEVER double-tax capital: retrait tax + income tax on SWR withdrawals

---

## VISION DOCUMENTS (read for strategic context)

- `visions/vision_product.md` — Core promise, acquisition strategy, North Star metric
- `visions/vision_features.md` — Feature specs, screen contracts
- `visions/vision_compliance.md` — Legal framework, FINMA, LPD
- `visions/vision_tech_stack.md` — Technical choices

---

## HIERARCHY OF TRUTH

In case of conflict, priority order:
1. `rules.md` — Non-negotiable technical + ethical rules
2. `.claude/CLAUDE.md` (this file) — Project context, constants, compliance, anti-patterns
3. `AGENTS.md` — Team workflow, roles, sprint tracker
4. `.claude/skills/` — Agent-specific conventions and patterns
5. `LEGAL_RELEASE_CHECK.md` — Wording compliance checklist
6. `visions/` — Product vision + limits
7. `docs/` (evolution specs) — ONBOARDING_ARBITRAGE_ENGINE, COACH_VIVANT_ROADMAP, DATA_ACQUISITION
8. `decisions/` (ADR) — Architecture decisions
9. `SOT.md` + OpenAPI — Data contracts
10. Code — Implementation follows documents

Archived docs: `docs/archive/`, `visions/archive/`, `.claude/archive/` — historique, accessible via git.

---

## ANTI-PATTERNS (never do)

1. **Code without reading existing code first** — Always understand before modifying
2. **Diverge backend vs Flutter constants** — Backend is source of truth
3. **Use banned terms** in any user-facing text
4. **Skip tests** — Always run before committing
5. **Create files unnecessarily** — Prefer editing existing files
6. **Promise returns** — Use scenarios (Bas/Moyen/Haut) + disclaimers
7. **Ignore audit findings** — Fix all CRIT divergences before committing
8. **Commit non-sprint files** — Surgical git add, only relevant files
9. **Assume Swiss native for all profiles** — Always check archetype (see ADR-20260223)
10. **Show projection without confidence score** — Always include uncertainty band + enrichment prompts
11. **Double-tax capital withdrawals** — Capital taxed at withdrawal (LIFD art. 38), SWR = not income
12. **Duplicate calculation logic** — NEVER create private `_calculateTax()`, `_estimateAvs()`, etc. in service files. Always use `financial_core/` calculators. If a method doesn't exist, add it to the appropriate calculator class.
13. **Ignore future AVS contribution years** — `AvsCalculator.computeMonthlyRente()` correctly adds future years until retirement. Don't use raw `contributionYears / 44` as reduction factor.
14. **Apply married couple AVS cap to concubins** — LAVS art. 35 cap (150% = 3780 CHF) applies ONLY to married couples. Always pass `isMarried: true/false` to `AvsCalculator.computeCouple()`.
15. **Bulk find-replace on Dart code** — NEVER use blind regex/sed to add `const`, rename classes, or refactor across many files. Always edit file-by-file or verify the replacement doesn't corrupt class names (e.g. `BorderRadius` → `Borderconst Radius`). If bulk-fixing lint, do it in small batches and grep for corrupted identifiers before committing.

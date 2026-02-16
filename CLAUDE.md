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

**Backend test baseline**: 1629 passed, 0 failed, 80 skipped
**Flutter analyze**: 0 errors (~896 info/warnings)
**i18n**: 6 locales (fr, de, en, es, it, pt) — `2fc39a1`
**QA fix**: LPP 3780 + AVS 2520 aligned — `750286b`

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

## VISION DOCUMENTS (read for strategic context)

- `visions/vision_product.md` — Core promise, acquisition strategy, North Star metric
- `visions/vision_features.md` — Feature specs, screen contracts
- `visions/vision_compliance.md` — Legal framework, FINMA, LPD
- `visions/vision_trust_privacy.md` — Trust architecture, consent
- `visions/vision_monetization.md` — Revenue model
- `visions/vision_tech_stack.md` — Technical choices
- `visions/vision_user_journeys.md` — Persona journeys

---

## HIERARCHY OF TRUTH

In case of conflict, priority order:
1. `rules.md` — Non-negotiable technical + ethical rules
2. `CLAUDE.md` (this file) — Project context + constants
3. `AGENTS.md` — Team workflow + roles
4. `visions/` — Product vision + limits
5. `LEGAL_RELEASE_CHECK.md` — Wording compliance
6. `decisions/` (ADR) — Architecture decisions
7. Code — Implementation follows documents, not the reverse

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

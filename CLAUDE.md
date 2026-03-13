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
| `confidence_scorer.dart` | `ConfidenceScorer.score(profile)` — 3-axis: completeness × accuracy × freshness | Profile completeness |

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

### At the START of every task/sprint/session

**Case A — New feature branch:**

```bash
git fetch --all
git status
# If dirty working tree → ask user whether to stash, commit, or discard
git checkout dev
git pull --rebase origin dev
git checkout -b feature/S{XX}-<slug>
```

**Case B — Resuming an existing feature branch:**

```bash
git fetch --all
git status
# If dirty working tree → ask user whether to stash, commit, or discard
git checkout feature/S{XX}-<slug>
git pull --rebase origin feature/S{XX}-<slug>
```

IMPORTANT:
- Never start coding on `main` or `staging` directly (always use feature branches or `dev`).
- No need to update `staging` or `main` locally — Claude Code never branches from them.
- Promotion PRs (`dev→staging`, `staging→main`) are done via GitHub, not local checkouts.
- Do NOT rebase on `dev` when resuming — that happens naturally when the PR is merged via GitHub.

### At the END of every task/sprint/session

Steps (execute in order):

```bash
# 1. Verify you are on a feature branch (recommended workflow)
# Note: Direct push to dev is allowed, but feature branches are preferred
BRANCH=$(git branch --show-current)
if [[ "$BRANCH" == "main" || "$BRANCH" == "staging" ]]; then
  echo "ERROR: Cannot commit/push on $BRANCH. Create a feature branch or switch to dev."
  exit 1
fi

# 2. Stage and commit
git add <only sprint-relevant files>
git status  # show user what will be committed
git commit -m "S{XX}: <description concise>"

# 3. Push to feature branch
git push origin "$BRANCH" -u

# 4. Create PR → dev (or ask user for promotion PR dev→staging / staging→main)
# gh pr create --base dev --title "..." --body "..."
```

### Branch convention
- Feature work: `feature/S{XX}-<slug>` (e.g. `feature/S35-slm-coach`)
- Hotfix: `hotfix/<description>`
- Always branch from latest `dev` (NOT from `main` directly)
- Direct push to `dev` is allowed (but PRs from feature branches are preferred)
- Never commit directly to `staging` or `main` (always via PR)

### Branch flow (NON-NEGOTIABLE — see `docs/CICD_ARCHITECTURE.md`)

The CI/CD pipeline enforces a strict promotion flow. Claude Code MUST follow it:

```
feature/* ──PR──> dev ──PR──> staging ──PR──> main
```

Rules:
- **`git push`**: Direct push to `dev` is allowed. NEVER push directly to `staging` or `main`.
- **`gh pr create`**: The base branch (`--base`) MUST match the promotion flow:
  - From `feature/*` or `hotfix/*` → base = `dev`
  - From `dev` → base = `staging` (only when user explicitly asks to promote)
  - From `staging` → base = `main` (only when user explicitly asks to promote)
  - **NEVER** create a PR from a feature branch directly to `staging` or `main`
- **Direct commits** to `staging` or `main` are BANNED (always via PR)
- **Direct commits** to `dev` are allowed but PRs from feature branches are preferred
- **Promotion PRs** (`dev→staging`, `staging→main`): only create when user explicitly requests it
- **Auto-merge `dev→staging`**: Use `gh pr merge --auto --squash` so the PR merges automatically once CI Gate passes
- **Manual merge `staging→main`**: Create the PR but do NOT auto-merge. The user must approve and merge manually (production deploy)
- Before creating a PR `staging→main`: verify the last Smoke Staging run is green (ask user to confirm if unsure)
- After merge to `main`: backend deploy, TestFlight (if mobile changed), and Web App (if web changed) trigger automatically — do NOT manually trigger these workflows unless user asks

# Promotion PRs — Naming convention

For every promotion PR in the MINT workflow:

- **dev→staging**: name the PR "Staging to vX.Y.Z" (preparation for QA validation, agent tests, CI/CD)
- **staging→main**: name the PR "Production to vX.Y.Z" (production deployment, official release)

Version meaning:
| Position | Meaning | Typical MINT trigger | Example |
|----------|--------|----------------------|---------|
| X (Major) | Agent architecture overhaul, breaking change, new agent logic | Structural change, breaking change, major refactor | v2.0.0 |
| Y (Minor) | New visible feature, module extension, new use-case | New screen, calculation, service, agent rule | v1.3.0 |
| Z (Patch) | Bug fix, optimization, minor adjustment | Agent fix, calculation correction, UI improvement, compliance | v1.3.2 |
| Suffix a,b,... | Urgent hotfix in production | Critical patch post-release, urgent compliance fix | v1.3.2a |

The version number must be incremented according to the nature of the change: breaking (X), new feature (Y), bugfix (Z), hotfix (suffix).

MINT examples:
- PR dev→staging: "Staging to v1.3.0" (add agent screen)
- PR dev→staging: "Staging to v2.0.0" (agent architecture overhaul)
- PR staging→main: "Production to v1.3.2" (compliance fix)
- PR staging→main: "Production to v1.3.2a" (urgent hotfix post-release)

**BEFORE creating any promotion PR:**

```bash
# Get last production version from merged PRs to main
gh pr list --state merged --base main --limit 1 --json title -q '.[0].title'
```

Extract version number (e.g., "Production to v0.0.1f" → v0.0.1f), then:
- **Patch (Z)**: increment last number (v0.0.1f → v0.0.2)
- **Minor (Y)**: increment middle, reset patch (v0.0.2 → v0.1.0)
- **Major (X)**: increment first, reset minor+patch (v0.1.0 → v1.0.0)
- **Hotfix (suffix)**: add/increment letter (v0.0.2 → v0.0.2a, v0.0.2a → v0.0.2b)

This convention is mandatory for every promotion in the MINT CI/CD pipeline.

### Before ANY code modification
1. Confirm current branch with `git branch --show-current`
2. Confirm no uncommitted changes with `git status`
3. If dirty working tree → ask user whether to stash, commit, or discard
4. If on `main` or `staging` → create a feature branch first (`git checkout -b feature/...`). Work on `dev` is allowed but feature branches are preferred.

### Rules
- **NEVER** force push (`git push --force` is BANNED)
- **NEVER** auto-merge branches without user approval
- **NEVER** create PRs that skip the branch flow (`feature→dev→staging→main`)
- **ALWAYS** use `--rebase` on pull (no merge commits)
- **ALWAYS** show `git status` output before committing
- **ALWAYS** delete feature branches after merge (`git branch -d <branch>` local + `git push origin --delete <branch>` remote)

### CI/CD
- **CI**: `.github/workflows/ci.yml` — triggers on push to staging/main + PRs
- **Deploy**: `.github/workflows/deploy-backend.yml` — Railway staging (PR merge → staging) + prod (merge → main)
- **TestFlight**: `.github/workflows/testflight.yml` — manual `workflow_dispatch`, dual-track staging/production
- **Full reference**: `docs/CICD_ARCHITECTURE.md`

### Testing
- **Service files**: minimum 10 unit tests (edge cases + compliance)
- **Screens/widgets**: widget tests (render, empty, error states)
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
- `confidenceScore` (0-100%) — 3-axis: completeness × accuracy × freshness (geometric mean)
- `enrichmentPrompts` — actions to improve accuracy
- Uncertainty band (min/max) when confidence < 70%
- Data sources: estimated(0.25), userInput(0.60), crossValidated(0.70), certificate(0.95), openBanking(1.00)

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

## 10. AGENT TEAM WORKFLOW

### Team Structure
- **Team Lead** (Opus): orchestrate, review, merge. Doesn't code (except urgency).
- **dart-agent** (Sonnet): `apps/mobile/` only. Skill: `.claude/skills/mint-flutter-dev/`
- **python-agent** (Sonnet): `services/backend/` only. Skill: `.claude/skills/mint-backend-dev/`
- **swiss-brain** (Opus): transversal review, specs, compliance. Skill: `.claude/skills/mint-swiss-compliance/`

### Workflow: Swiss-Brain validates BEFORE devs implement
```
Swiss-Brain (spec + test cases) → Python-Agent (backend) → Dart-Agent (UI) → Team Lead (review + merge)
```

### Cross-modification rules
| Agent | Can modify | Cannot modify |
|-------|-----------|---------------|
| dart-agent | `apps/mobile/` | `services/backend/`, `tools/openapi/` |
| python-agent | `services/backend/`, `tools/openapi/`, `SOT.md` | `apps/mobile/` |
| swiss-brain | `docs/`, `education/`, `decisions/`, `visions/` | Code (`*.dart`, `*.py`) |

### Skills Index
| Skill | File | For |
|-------|------|-----|
| mint-flutter-dev | `.claude/skills/mint-flutter-dev/SKILL.md` | dart-agent |
| mint-backend-dev | `.claude/skills/mint-backend-dev/SKILL.md` | python-agent |
| mint-swiss-compliance | `.claude/skills/mint-swiss-compliance/SKILL.md` | swiss-brain |
| mint-test-suite | `.claude/skills/mint-test-suite/SKILL.md` | all agents |
| mint-commit | `.claude/skills/mint-commit/SKILL.md` | team-lead |

In case of conflict, priority order:
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

## 12. REFERENCE DOCUMENTS

| Document | Purpose |
|----------|---------|
| `rules.md` | Tier 1: fintech-grade principles, UX rules, workflow |
| `SOT.md` | Data contracts: Profile, SessionReport |
| `LEGAL_RELEASE_CHECK.md` | Pre-release compliance gate |
| `DefinitionOfDone.md` | Sprint completion criteria |
| `docs/VISION_V1.md` | Strategic direction V1 (~25 screens, 3 tabs) |
| `docs/CICD_ARCHITECTURE.md` | Full CI/CD pipeline reference |
| `docs/ONBOARDING_ARBITRAGE_ENGINE.md` | Onboarding + arbitrage specs |
| `docs/DATA_ACQUISITION_STRATEGY.md` | OCR, guided entry, Open Banking |
| `visions/vision_product.md` | Core promise, acquisition strategy |
| `visions/vision_compliance.md` | LSFin, FINMA, nLPD framework |
| `visions/vision_tech_stack.md` | Technical choices |
| `legal/DISCLAIMER.md` | User-facing educational disclaimer |
| `legal/CGU.md` | Terms of service |

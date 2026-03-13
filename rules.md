# Mint — rules.md (règles non négociables)

Objectif: coder vite (“vibe coding”) sans casser la cohérence.

## 0) Hiérarchie de vérité
1. rules.md — Non-negotiable technical + ethical rules
2. .claude/CLAUDE.md — Project context, constants, compliance, anti-patterns
3. AGENTS.md — Team workflow, roles, sprint tracker
4. .claude/skills/ — Agent-specific conventions and patterns
5. LEGAL_RELEASE_CHECK.md — Wording compliance checklist
6. visions/ — Product vision + limits
7. docs/ (evolution specs) — ONBOARDING_ARBITRAGE_ENGINE, COACH_VIVANT_ROADMAP, DATA_ACQUISITION
8. decisions/ (ADR) — Architecture decisions
9. SOT.md + OpenAPI — Data contracts
10. Code — Implementation follows documents

Si le code contredit 1–9: corriger le code OU écrire une ADR.
docs/ evolution specs sit below visions/ but above ADRs.

## 1) Commandes standards

### Backend (FastAPI) — dans services/backend/
- Run dev: uvicorn app.main:app --reload
- Lint: ruff check .
- Format: ruff format .
- Tests: pytest -q

### Mobile (Flutter) — dans apps/mobile/
- flutter pub get
- flutter analyze
- flutter test
*(Note: Sur cet environnement Windows, utiliser `C:\flutter\bin\flutter.bat` si `flutter` n'est pas dans le PATH)*

## 2) Branch Flow (NON-NÉGOCIABLE)

```
feature/* ──PR──> dev ──PR──> staging ──PR──> main
```

**Règles absolues :**
- **JAMAIS** travailler directement sur `staging` ou `main`. Toujours utiliser une feature branch ou `dev`.
- **JAMAIS** créer une PR depuis une feature branch vers `staging` ou `main` (toujours vers `dev`).
- **JAMAIS** push directement sur `staging` ou `main` (toujours via PR).
- **JAMAIS** force push (`git push --force` est BANNI).
- Push direct sur `dev` : autorisé (mais feature branches préférées).
- Feature branches : `feature/S{XX}-<slug>` (brancher depuis `dev`).
- Hotfix : `hotfix/<description>` (brancher depuis `dev`).
- Promotion `dev→staging` : uniquement quand l'utilisateur le demande explicitement.
- Promotion `staging→main` : uniquement quand l'utilisateur le demande explicitement.

**Merge strategy :**
- `feature→dev` : **squash merge** (1 commit propre par feature)
- `dev→staging` : **merge commit** (préserve les SHAs, pas de resync)
- `staging→main` : **merge commit** (idem)

**Si Claude se trouve sur `staging` ou `main` au début d'une session :**
→ NE PAS coder. Créer une feature branch depuis `dev` ou basculer sur `dev`.

## 3) Workflow
- Toujours proposer un plan avant de modifier beaucoup de fichiers.
- Toujours lancer lint/analyze/tests après une série de changements.
- Fix bug => ajouter un test.
- Changement de contrat => mise à jour OpenAPI + SOT.md.
- Décision structurante => ADR obligatoire.

## 4) Fintech-grade (MVP)
- Read-only by design: aucune feature ne doit permettre d'initier un virement/paiement.
- Transparence: afficher hypothèses + limites + période (mensuel/annuel/unique) pour chaque chiffre.
- Pas de dark patterns: pas d'upsell trompeur, pas de pub intrusive.
- Arbitrage = comparaison, jamais classement. Montrer côte à côte avec hypothèses modifiables.
- LLM = narrateur, jamais conseiller. Tout output LLM passe par ComplianceGuard.
- Data = traçabilité source. Chaque champ financier tracé (document, manuel, estimé).

## 5) UX
- Progressive disclosure: on n'impose pas la connexion bancaire au début.
- 1 écran = 1 intention.
- Chaque recommandation se termine par 1–3 actions concrètes (next actions).
- Onboarding minimal : 3 questions max avant le premier chiffre choc.
- Précision progressive : demander les données au moment où elles comptent, pas pendant l'onboarding.
- Score FRI : jamais "bon/mauvais", toujours "progression personnelle".

## 6) Dépendances
- Pas de dépendance lourde sans ADR.

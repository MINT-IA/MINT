# Mint — rules.md (règles non négociables)

Objectif: coder vite (“vibe coding”) sans casser la cohérence.

## 0) Hiérarchie de vérité
1) visions/* (intention produit + limites)
2) tools/openapi/mint.openapi.yaml + SOT.md (contrats)
3) rules.md + AGENTS.md (workflow)
4) code (implémentation)
Si le code contredit 1–3: corriger le code OU écrire une ADR.

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

## 2) Workflow
- Toujours proposer un plan avant de modifier beaucoup de fichiers.
- Toujours lancer lint/analyze/tests après une série de changements.
- Fix bug => ajouter un test + entrée dans AGENTS_LOG.md.
- Changement de contrat => mise à jour OpenAPI + SOT.md.
- Décision structurante => ADR obligatoire.

## 3) Fintech-grade (MVP)
- Read-only by design: aucune feature ne doit permettre d’initier un virement/paiement.
- Transparence: afficher hypothèses + limites + période (mensuel/annuel/unique) pour chaque chiffre.
- Pas de dark patterns: pas d’upsell trompeur, pas de pub intrusive.

## 4) UX
- Progressive disclosure: on n’impose pas la connexion bancaire au début.
- 1 écran = 1 intention.
- Chaque recommandation se termine par 1–3 actions concrètes (next actions).

## 5) Dépendances
- Pas de dépendance lourde sans ADR.

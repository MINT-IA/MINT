# MINT CI/CD Architecture (GitHub Actions + Railway + TestFlight)

Document de reference du pipeline CI/CD MINT.
Etat cible: deploiement backend sur Railway staging/prod, build iOS TestFlight sur main.
Date de reference: 2026-03-06.

## 1) Vue d'ensemble

MINT utilise:

1. GitHub comme source de verite (branches + PR + protections).
2. GitHub Actions pour CI (tests/analyse) et CD (deploiement backend + TestFlight).
3. Railway pour heberger l'API backend (staging + production).
4. App Store Connect / TestFlight pour distribuer l'app iOS de preproduction/production.

## 2) Strategie de branches

Flux recommande:

1. `feature/*` -> PR vers `dev`.
2. `dev` -> PR vers `staging`.
3. `staging` -> PR vers `main`.

Role des branches:

1. `dev`: integration continue (validation de code, pas de deploiement backend auto).
2. `staging`: preproduction (backend deploye sur Railway STAGING apres merge PR).
3. `main`: production (backend deploye sur Railway PROD apres merge PR, TestFlight pour iOS).

Important:

1. Pas d'environnement Railway `dev` dans cette architecture.
2. Le backend est deploie uniquement sur `staging` et `main`.

## 3) Cartographie globale (qui parle a quoi)

```text
feature/*
  -> PR vers dev
      -> CI (backend + flutter + gate)

PR dev -> staging (merge)
  -> CI
  -> Deploy Backend workflow (PR closed+merged)
      -> Pre-deploy tests
      -> Deploy Railway STAGING
      -> Smoke tests STAGING

PR staging -> main (merge)
  -> CI
  -> Deploy Backend workflow (PR closed+merged)
      -> Pre-deploy tests
      -> Deploy Railway PROD
      -> Production healthcheck
  -> TestFlight workflow (si changement apps/mobile/**)
      -> Build iOS + Upload TestFlight
      -> App mobile pointe sur API PROD
```

### Schema visuel 

```text
BRANCHES & DEPLOIEMENT
======================

feature/*
    |
    |  PR
    v
dev (tests/analyze uniquement, pas de deploiement backend)
    |
    |  PR dev -> staging (merge)
    v
staging (CI sur PR + push)
    |
    |  PR merged (event pull_request.closed)
    v
GitHub Action Deploy Backend (staging)
    |
    +-- job: Pre-deploy tests
    +-- job: Deploy to Staging
    +-- job: Smoke Staging (needs: deploy-staging)
         - GET /api/v1/health
         - GET /api/v1/health/ready
         - 2-3 endpoints metier critiques
    v
Railway STAGING (API preprod)

Promotion staging -> main:
    - CI Gate vert obligatoire
    - Regle equipe: ne merger vers main que si le dernier Smoke Staging est vert

Si staging est valide:

staging -> main
    |
    |  PR staging -> main (merge)
    v
main (CI sur PR + push)
    |
    +------------------------------+
    |                              |
    v                              v
Deploy Backend (prod)         TestFlight workflow
    |                              |
    +-- Pre-deploy tests           +-- si apps/mobile/** modifie
    +-- Deploy to Production       +-- Build iOS + Upload
    +-- Production healthcheck     +-- App Store Connect -> TestFlight
    v
Railway PROD (API production)

AU RUNTIME
==========
Build TestFlight (main)
-> API_BASE_URL = Railway PROD (https://api.mint.ch/api/v1)
```

## 4) Workflows GitHub Actions

### 4.1 CI principal

Fichier: `.github/workflows/ci.yml`

Declencheurs:

1. `push` sur `staging` et `main`.
2. `pull_request` vers `dev`, `staging`, `main`.

Jobs:

1. `Backend tests`
2. `Flutter analyze + test`
3. `CI Gate` (echoue si un des 2 jobs precedents echoue)

Controles backend:

1. `pytest` avec couverture mini globale (`--cov-fail-under=60`).
2. `diff-cover` sur PR (lignes modifiees >= 80%).
3. Verification derive OpenAPI canonical.
4. Verification migrations Alembic (`upgrade/downgrade/upgrade`).

Controles flutter:

1. `flutter analyze`.
2. `flutter test` (hors `test/_archive/*`).

### 4.2 Deploiement backend Railway

Fichier: `.github/workflows/deploy-backend.yml`

Declencheurs:

1. `pull_request` `types: [closed]` vers `staging` et `main`.
2. `workflow_dispatch` manuel.

Filtre de fichiers (`paths`):

1. `services/backend/**`
2. `.github/workflows/deploy-backend.yml`
3. `scripts/smoke_staging_api.sh`

Consequence:

1. Si une PR vers `staging/main` ne touche aucun de ces chemins, ce workflow ne se lance pas.

Jobs:

1. `Pre-deploy tests`.
2. `Deploy to Staging` (seulement PR mergee vers `staging` ou dispatch manuel sur branche `staging`).
3. `Smoke Staging` (apres deploy staging).
4. `Deploy to Production` (seulement PR mergee vers `main` ou dispatch manuel sur `main`).

Notes importantes:

1. Deploiement staging utilise `PROJECT_STAGING_TOKEN`.
2. Deploiement production utilise `RAILWAY_TOKEN`.
3. Les commandes `railway up` sont executees sans `--detach` pour attendre la fin reelle du deploiement.
4. Les `RAILWAY_*_ENVIRONMENT_ID` sont obligatoires pour cibler explicitement le bon environnement.

### 4.3 Build iOS TestFlight

Fichier: `.github/workflows/testflight.yml`

Declencheurs:

1. `pull_request` `types: [closed]` vers `main`.
2. Filtre `paths: apps/mobile/**`.
3. `workflow_dispatch` manuel.

Condition d'execution:

1. PR mergee vers `main`, ou
2. run manuel lance sur la branche `main`.

Garanties runtime:

1. `PROD_API_BASE_URL` force a `https://api.mint.ch/api/v1`.
2. Check explicite pour eviter un build TestFlight pointe vers staging.
3. Precheck backend health avant build.

## 5) Smoke tests staging

Fichier: `scripts/smoke_staging_api.sh`

Ce script verifie apres deploy staging:

1. `GET /api/v1/health` -> status ok.
2. `GET /api/v1/health/ready` -> status ok.
3. `GET /api/v1/health/ready` -> database ok.
4. `GET /api/v1/retirement/checklist` -> presence `checklist`.
5. `POST /api/v1/onboarding/minimal-profile` -> presence `confidence_score` ou `confidenceScore`.
6. `POST /api/v1/arbitrage/rente-vs-capital` -> presence `options`.

Robustesse:

1. Retries (`MAX_RETRIES`, default 5).
2. Timeout connexion et requete (`CONNECT_TIMEOUT`, `MAX_TIME`).
3. Logs lisibles + dernier body tronque en cas d'erreur.
4. Exit code 1 si au moins un check echoue.

## 6) Secrets et variables utilises

### 6.1 GitHub Secrets - Backend deploy

Obligatoires staging:

1. `PROJECT_STAGING_TOKEN`
2. `RAILWAY_STAGING_SERVICE_ID`
3. `RAILWAY_STAGING_ENVIRONMENT_ID`

Obligatoires production:

1. `RAILWAY_TOKEN`
2. `RAILWAY_SERVICE_ID`
3. `RAILWAY_PROD_ENVIRONMENT_ID`

Optionnel (mais utile):

1. `RAILWAY_PROJECT_ID` (si vous voulez forcer explicitement un project ID).

Autre secret possible:

1. `STAGING_API_URL` (fallback si variable repo absente).
2. `PROD_API_URL` (fallback si variable repo absente).

### 6.2 GitHub Variables - URLs

Recommandees:

1. `STAGING_API_URL` (ex: `https://mint-staging.up.railway.app/api/v1`).
2. `PROD_API_URL` (ex: `https://api.mint.ch/api/v1`).

Usage:

1. URL d'environnement dans GitHub Deployments.
2. URL utilisee par smoke tests et healthchecks.

### 6.3 GitHub Secrets - TestFlight

Principaux:

1. `APP_STORE_CONNECT_API_KEY_ID`
2. `APP_STORE_CONNECT_ISSUER_ID`
3. `APP_STORE_CONNECT_API_KEY_CONTENT`
4. `MATCH_GIT_URL`
5. `MATCH_PASSWORD`
6. `KEYCHAIN_PASSWORD`

Optionnels selon config modele on-device:

1. `HUGGINGFACE_TOKEN`
2. `SLM_MODEL_URL`

## 7) Branch protections (recommande)

Objectif:

1. Empecher merge sans checks verts.
2. Bloquer push direct sur branches critiques.

Minimum recommande:

1. `dev`: require PR + check `CI Gate`.
2. `staging`: require PR + check `CI Gate`.
3. `main`: require PR + check `CI Gate` + pas de force push.

Note importante:

1. Le workflow `Deploy Backend` est declenche sur `pull_request.closed` (apres merge), donc ses jobs ne peuvent pas etre des checks bloquants de pre-merge.
2. Pour garantir la qualite avant promotion `staging -> main`, appliquez une regle d'equipe: ne merger vers `main` que si le dernier run staging a `Smoke Staging` vert sur le commit courant.
3. Option complementaire: activer l'environnement GitHub `production` avec approbation manuelle (required reviewers) avant execution du job de deploiement production.

Script utile present dans le repo:

1. `scripts/setup-branch-protection.sh` (configure surtout `main`, a completer manuellement pour `dev/staging` selon politique).

## 8) Flux operationnel (journee type)

1. Developpeur pousse sur `feature/*`.
2. Ouvre PR vers `dev`.
3. `CI` doit etre verte.
4. Merge `dev`.
5. Ouvre PR `dev -> staging`.
6. `CI` sur PR staging doit etre verte.
7. Merge PR vers `staging`.
8. Deploy backend staging + smoke se lancent automatiquement.
9. Valider fonctionnellement sur API staging.
10. Ouvrir PR `staging -> main`.
11. Merge vers `main`.
12. Deploy backend production + healthcheck.
13. TestFlight se lance si code mobile modifie.

## 9) Troubleshooting (incidents frequents)

### 9.1 "Deploy Backend ne se lance pas"

Ca arrive si:

1. La PR ne touche pas `services/backend/**`, `.github/workflows/deploy-backend.yml` ou `scripts/smoke_staging_api.sh`.
2. La PR n'est pas mergee (`pull_request.closed` mais `merged=false`).

Action:

1. Verifier fichiers modifies et conditions du workflow.

### 9.2 "Invalid project token for environment"

Cause:

1. Token sans acces a l'environnement cible.
2. Mismatch token/service/environment entre projets Railway.

Action:

1. Verifier coherence entre `PROJECT_STAGING_TOKEN`, `RAILWAY_STAGING_SERVICE_ID`, `RAILWAY_STAGING_ENVIRONMENT_ID`.
2. Verifier coherence entre `RAILWAY_TOKEN`, `RAILWAY_SERVICE_ID`, `RAILWAY_PROD_ENVIRONMENT_ID`.

### 9.3 Smoke staging rouge avec HTTP 200

Cause typique:

1. Pattern de body attendu ne correspond pas exactement au JSON renvoye.

Action:

1. Ajuster pattern du script smoke.
2. Conserver checks stables et non fragiles.

### 9.4 Workflow manuel lance "trop de jobs"

Comportement normal:

1. Le graphe affiche tous les jobs declares.
2. Les jobs non concernes sont `skipped` selon les `if`.

## 10) Rollback

Backend Railway:

1. Ouvrir Railway environment cible (`staging` ou `production`).
2. Service backend -> Deployments.
3. Choisir un deploy precedent sain.
4. Redeployer ce deploy precedent (rollback).

GitHub:

1. Revert du commit fautif via PR.
2. Merge sur la branche cible pour redeclencher pipeline proprement.

## 11) Definition of Done CI/CD

Le setup est considere operationnel si:

1. PR `feature/* -> dev` execute `CI` vert.
2. Merge `dev -> staging` declenche deploy staging + smoke vert.
3. Railway staging montre un nouveau deploy correspondant au commit merge.
4. Merge `staging -> main` declenche deploy production vert.
5. Healthcheck production passe.
6. Si mobile change, TestFlight se lance depuis `main` et build upload OK.
7. Secrets non exposes en clair dans le repo.

---

## Annexes - fichiers source du pipeline

1. `.github/workflows/ci.yml`
2. `.github/workflows/deploy-backend.yml`
3. `.github/workflows/testflight.yml`
4. `scripts/smoke_staging_api.sh`
5. `scripts/setup-branch-protection.sh`

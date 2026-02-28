# CI/CD Setup Guide — MINT

## Vue d'ensemble

```
feature branch → PR → CI passe → merge main
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                  │
              Backend modifie?   Flutter modifie?    Toujours
                    │                 │                  │
              Deploy Railway    Build TestFlight       CI Gate
              (staging → prod)  (auto distribue)    (tests obligatoires)
```

### Safeguards (protection contre les erreurs)

| Protection | Effet |
|-----------|-------|
| PR obligatoire sur `main` | Personne ne peut push directement |
| CI Gate obligatoire | Les tests doivent passer avant merge |
| Force-push bloque | Impossible d'ecraser l'historique |
| Historique lineaire | Pas de merge commits (rebase only) |
| Branches auto-supprimees | Nettoyage automatique apres merge |
| Staging deploy sur PR | Tester avant de deployer en prod |
| Production deploy apres merge | Seulement quand main change |

---

## Etape 1 : Backend sur Railway (~5 min)

### 1.1 Creer un compte Railway

1. Va sur https://railway.com
2. "Start a New Project" → "Deploy from GitHub Repo"
3. Connecte ton repo GitHub (Julienbatt/MINT)
4. Railway detecte le Dockerfile dans `services/backend/`

### 1.2 Configurer le projet

Dans le dashboard Railway :

1. **Root Directory** : set to `services/backend`
2. **Variables** (dans l'onglet Variables) :
   ```
   JWT_SECRET_KEY=<genere avec: openssl rand -hex 32>
   ENVIRONMENT=production
   DATABASE_URL=<auto-rempli si tu ajoutes PostgreSQL>
   ```

3. **Ajouter PostgreSQL** : clique "New" → "Database" → "PostgreSQL"
   Railway connecte automatiquement `DATABASE_URL`.

### 1.3 Creer l'environnement staging

1. Dans Railway, clique "Environments" (en haut a droite)
2. "New Environment" → "staging"
3. Railway deploie automatiquement sur staging quand une PR est ouverte

### 1.4 Token pour GitHub Actions

1. Railway dashboard → ton profil → "Tokens"
2. "Create Token" → nom: `github-actions`
3. Copie le token

Ajoute dans GitHub : Repo > Settings > Secrets > Actions :

| Secret | Valeur |
|--------|--------|
| `RAILWAY_TOKEN` | Le token copie |
| `RAILWAY_SERVICE_ID` | Dashboard Railway > service > Settings > Service ID |
| `RAILWAY_STAGING_SERVICE_ID` | Idem pour l'env staging (optionnel) |

### 1.5 Verifier

Apres deploy, Railway te donne une URL type :
`https://mint-api-production.up.railway.app/api/v1/health`

---

## Etape 2 : Protection de branche (~2 min)

Lance le script une seule fois :

```bash
gh auth login  # si pas deja connecte
./scripts/setup-branch-protection.sh
```

Ca configure :
- PR obligatoire pour merger dans `main`
- CI doit passer (tests backend + Flutter)
- Force-push bloque
- Branches mergees auto-supprimees

**Test** : essaie `git push origin main` — ca doit etre rejete.

---

## Etape 3 : CI automatique (deja pret)

Le fichier `.github/workflows/ci.yml` est deja en place.
Des qu'une PR est ouverte ou qu'on push sur `main`, les tests tournent.

Rien a configurer.

---

## Etape 4 : TestFlight automatique (~20 min, une seule fois)

### 4.1 Creer une API Key App Store Connect

1. Va sur https://appstoreconnect.apple.com/access/integrations/api
2. Clique "+" pour generer une nouvelle cle
3. Nom: `MINT CI/CD`, Acces: `App Manager`
4. Telecharge le fichier `.p8` (tu ne pourras le telecharger qu'une fois !)
5. Note le **Key ID** et l'**Issuer ID** affiches en haut

### 4.2 Encoder la cle en base64

```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

### 4.3 Creer un repo prive pour les certificats (Fastlane Match)

```bash
# Cree un repo prive vide sur GitHub, ex: Julienbatt/mint-certificates
cd apps/mobile/ios
bundle install
bundle exec fastlane match init
# Choisis "git", URL: git@github.com:Julienbatt/mint-certificates.git
# Choisis un mot de passe (MATCH_PASSWORD)

bundle exec fastlane match appstore
```

### 4.4 Ajouter les secrets GitHub

| Secret | Valeur |
|--------|--------|
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID (etape 4.1) |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID (etape 4.1) |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | Contenu base64 du .p8 (etape 4.2) |
| `MATCH_GIT_URL` | `git@github.com:Julienbatt/mint-certificates.git` |
| `MATCH_PASSWORD` | Mot de passe choisi (etape 4.3) |
| `KEYCHAIN_PASSWORD` | N'importe quoi (ex: `ci_temp_12345`) |

### 4.5 Creer le groupe TestFlight

1. App Store Connect > Ton app > TestFlight > Groupes externes
2. Cree un groupe "Beta Testeurs"
3. Ajoute tes testeurs par email

### 4.6 Tester

Manuellement : GitHub > Actions > TestFlight > Run workflow

---

## Etape 5 : Mettre a jour le backend URL dans Flutter

```dart
// Dans lib/services/api_service.dart (ou equivalent)
static const String baseUrl = 'https://mint-api-production.up.railway.app/api/v1';
```

---

## Recapitulatif des secrets GitHub

| Secret | Pour | Source |
|--------|------|--------|
| `RAILWAY_TOKEN` | Deploy backend | Railway > Tokens |
| `RAILWAY_SERVICE_ID` | Service prod | Railway > Service > Settings |
| `RAILWAY_STAGING_SERVICE_ID` | Service staging | Railway > Service > Settings |
| `APP_STORE_CONNECT_API_KEY_ID` | TestFlight | App Store Connect |
| `APP_STORE_CONNECT_ISSUER_ID` | TestFlight | App Store Connect |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | TestFlight | Fichier .p8 en base64 |
| `MATCH_GIT_URL` | Signing certs | Ton repo prive |
| `MATCH_PASSWORD` | Signing certs | Tu le choisis |
| `KEYCHAIN_PASSWORD` | CI keychain | Tu le choisis |

---

## Couts estimes

| Service | Cout |
|---------|------|
| Railway (Hobby plan, scale-to-zero) | ~5 $/mois |
| Railway PostgreSQL | Inclus (5$/mois total) |
| GitHub Actions (Free, 2000 min/mois) | 0 $ |
| Total | **~5 $/mois** |

---

## Ton nouveau workflow quotidien

```
AVANT (manuel, ~30 min par release) :
  1. Code
  2. Test manuellement
  3. Xcode > Product > Archive (~10 min)
  4. Upload to App Store Connect (~5 min)
  5. Attendre le processing (~10 min)
  6. TestFlight > assigner au groupe
  7. Deploy backend manuellement
  8. Prier pour ne pas avoir casse la prod

APRES (automatique, ~0 min) :
  1. Code sur une branche feature
  2. git push → ouvre une PR
  3. CI tourne automatiquement
  4. Backend deploye en staging (testable)
  5. Merge la PR
  6. Backend deploye en prod (~2 min)
  7. TestFlight build + distribue (~15 min)
  8. Tes testeurs recoivent la notification
```

### En cas de probleme

| Situation | Action |
|-----------|--------|
| CI echoue | Fix le code, re-push. Le merge est bloque. |
| Deploy prod casse | Railway → "Rollback" en 1 clic sur le deploy precedent |
| TestFlight build echoue | Check les logs dans GitHub Actions > TestFlight |
| Tu veux deployer sans attendre | GitHub > Actions > Run workflow (manual trigger) |

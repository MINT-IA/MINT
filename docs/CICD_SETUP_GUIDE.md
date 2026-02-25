# CI/CD Setup Guide — MINT

## Vue d'ensemble

```
git push main
     │
     ├─ CI (.github/workflows/ci.yml)
     │   ├─ pytest (backend)
     │   └─ flutter analyze + test
     │
     ├─ Deploy Backend (.github/workflows/deploy-backend.yml)
     │   └─ Fly.io (si services/backend/ modifie)
     │
     └─ TestFlight (.github/workflows/testflight.yml)
         └─ Build iOS + Upload (si apps/mobile/ modifie)
```

---

## Etape 1 : Backend sur Fly.io (~10 min)

### 1.1 Installer Fly CLI

```bash
# macOS
brew install flyctl

# ou curl
curl -L https://fly.io/install.sh | sh
```

### 1.2 Creer un compte + app

```bash
fly auth signup          # ou fly auth login si tu as deja un compte

cd services/backend
fly launch --name mint-api --region cdg --no-deploy
# Repondre "No" a tout (on a deja fly.toml)
```

### 1.3 Creer la base PostgreSQL

```bash
fly postgres create --name mint-db --region cdg --vm-size shared-cpu-1x --initial-cluster-size 1
fly postgres attach mint-db --app mint-api
# Ca set automatiquement DATABASE_URL dans les secrets
```

### 1.4 Configurer les secrets

```bash
fly secrets set JWT_SECRET_KEY="$(openssl rand -hex 32)"
fly secrets set ENVIRONMENT=production
fly secrets set AUTH_REQUIRE_EMAIL_VERIFICATION=false
# Ajoute tes secrets Stripe/email quand tu en auras besoin
```

### 1.5 Premier deploy

```bash
fly deploy
```

Verifie : `https://mint-api.fly.dev/api/v1/health`

### 1.6 Token pour GitHub Actions

```bash
fly tokens create deploy -x 999999h
```

Copie le token et ajoute-le dans GitHub :
> Repo > Settings > Secrets and variables > Actions > New secret
> Name: `FLY_API_TOKEN` / Value: le token

---

## Etape 2 : CI automatique (deja pret)

Le fichier `.github/workflows/ci.yml` est deja cree. Des que tu push sur `main` ou crees une PR, les tests tournent automatiquement.

Rien a configurer.

---

## Etape 3 : TestFlight automatique (~20 min, une seule fois)

### 3.1 Creer une API Key App Store Connect

1. Va sur https://appstoreconnect.apple.com/access/integrations/api
2. Clique "+" pour generer une nouvelle cle
3. Nom: `MINT CI/CD`, Acces: `App Manager`
4. Telecharge le fichier `.p8` (tu ne pourras le telecharger qu'une fois !)
5. Note le **Key ID** et l'**Issuer ID** affiches en haut de la page

### 3.2 Encoder la cle en base64

```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
# Le contenu est maintenant dans ton presse-papier
```

### 3.3 Creer un repo prive pour les certificats (Fastlane Match)

```bash
# Cree un repo prive vide sur GitHub, ex: Julienbatt/mint-certificates
# Puis initialise match :
cd apps/mobile/ios
bundle install
bundle exec fastlane match init
# Choisis "git", entre l'URL du repo: git@github.com:Julienbatt/mint-certificates.git
# Choisis un mot de passe (MATCH_PASSWORD)

# Genere les certificats :
bundle exec fastlane match appstore
```

### 3.4 Ajouter les secrets GitHub

Va dans : Repo > Settings > Secrets and variables > Actions

| Secret | Valeur |
|--------|--------|
| `APP_STORE_CONNECT_API_KEY_ID` | Le Key ID de l'etape 3.1 |
| `APP_STORE_CONNECT_ISSUER_ID` | L'Issuer ID de l'etape 3.1 |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | Le contenu base64 du .p8 (etape 3.2) |
| `MATCH_GIT_URL` | `git@github.com:Julienbatt/mint-certificates.git` |
| `MATCH_PASSWORD` | Le mot de passe choisi a l'etape 3.3 |
| `KEYCHAIN_PASSWORD` | N'importe quoi (ex: `ci_temp_12345`) |

### 3.5 Creer le groupe TestFlight

1. App Store Connect > Ton app > TestFlight > Groupes externes
2. Cree un groupe "Beta Testeurs"
3. Ajoute tes 5 testeurs par email

### 3.6 Tester

```bash
git push origin main
```

Ou manuellement : GitHub > Actions > TestFlight > Run workflow

---

## Etape 4 : Mettre a jour le backend URL dans Flutter

Une fois le backend deploye, mets a jour l'URL dans l'app :

```dart
// Dans lib/services/api_service.dart
static const String baseUrl = 'https://mint-api.fly.dev/api/v1';
```

(Idealement avec une variable d'environnement Flutter pour switcher dev/prod)

---

## Recapitulatif des secrets GitHub

| Secret | Pour | Ou le trouver |
|--------|------|---------------|
| `FLY_API_TOKEN` | Deploy backend | `fly tokens create deploy` |
| `APP_STORE_CONNECT_API_KEY_ID` | TestFlight | App Store Connect > Keys |
| `APP_STORE_CONNECT_ISSUER_ID` | TestFlight | App Store Connect > Keys |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | TestFlight | Fichier .p8 encode base64 |
| `MATCH_GIT_URL` | Signing certs | Ton repo prive de certs |
| `MATCH_PASSWORD` | Signing certs | Mot de passe que tu choisis |
| `KEYCHAIN_PASSWORD` | CI keychain | N'importe quoi |

---

## Couts estimes

| Service | Cout |
|---------|------|
| Fly.io (shared-cpu-1x, 512MB, scale-to-zero) | ~3-5 $/mois |
| Fly.io PostgreSQL (1GB) | ~0 (inclus dans le free tier) |
| GitHub Actions (Free plan, 2000 min/mois) | 0 $ |
| Total | **~5 $/mois** |

---

## Apres le setup : ton nouveau workflow quotidien

```
Avant (manuel, ~30 min) :
  1. Code
  2. Test manuellement
  3. Xcode > Product > Archive (~10 min)
  4. Upload to App Store Connect (~5 min)
  5. Attendre le processing (~10 min)
  6. Aller dans TestFlight, assigner au groupe
  7. Deploy backend manuellement

Apres (automatique, ~0 min) :
  1. Code
  2. git push origin main
  3. C'est tout. Tes testeurs recoivent la MAJ en ~15 min.
```

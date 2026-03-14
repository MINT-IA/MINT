# MINT Web App — Architecture & Audit

Date: 14 mars 2026
Statut: Architecture v2 deployee sur Vercel (staging preview)

---

## 1) Architecture v2 — Resume

MINT web est une **architecture zero-modification** : aucun fichier mobile existant n'est modifie. Tout le web est 100% additif.

```
Mobile:
main.dart → MintApp → app.dart (GoRouter + Providers) → Screens

Web:
main_web.dart → MintWebApp → web_app.dart → webRouter + webProviders → Screens
```

Deux points d'entree, deux routers, deux sets de providers. Les screens sont reutilises du mobile quand ils sont web-compatible.

---

## 2) Fichiers web (tous nouveaux, aucun fichier mobile modifie)

| Fichier | Role |
|---------|------|
| `lib/main_web.dart` | Point d'entree web (init inline, pas de bootstrap) |
| `lib/web/web_app.dart` | Widget racine web (MaterialApp + webRouter + webProviders) |
| `lib/web/web_router.dart` | GoRouter web complet (~68 routes, ecrans dart:io exclus) |
| `lib/web/web_providers.dart` | Providers web-safe (exclut DocumentProvider, SlmProvider) |
| `lib/web/web_navigation_shell.dart` | Navigation shell (sidebar desktop + bottom nav mobile) |
| `lib/web/web_theme.dart` | Theme Material 3 web |
| `lib/web/web_feature_gate.dart` | Registre des features mobile-only |
| `lib/web/screens/web_home_screen.dart` | Page d'accueil web |
| `lib/web/widgets/web_responsive_wrapper.dart` | Wrapper responsive (max 960px) |
| `lib/web/widgets/web_viewport_layout.dart` | Frame viewport (fond MintColors.appleSurface) |

---

## 3) Deploiement

### Infrastructure

| Composant | Service | Branche |
|-----------|---------|---------|
| Backend API (staging) | Railway | staging |
| Backend API (prod) | Railway | main |
| Web app (staging) | Vercel Preview | staging / feature/* |
| Web app (prod) | Vercel Production | main |
| Landing page | Vercel (Next.js) | a venir sur mint-ia.ch |

### Domaines (a configurer sur Infomaniak)

| URL | Contenu |
|-----|---------|
| `mint-ia.ch` | Landing page Next.js (a creer) |
| `app.mint-ia.ch` | App Flutter Web (Vercel) |

### CI/CD Web (`.github/workflows/web.yml`)

1. PR mergee vers `staging` → deploy Vercel Preview (API = `STAGING_API_URL`)
2. PR mergee vers `main` → deploy Vercel Production `--prod` (API = `PROD_API_URL`)
3. `workflow_dispatch` pour deploy manuel depuis n'importe quelle branche

Secrets GitHub: `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`
Variables GitHub: `STAGING_API_URL`, `PROD_API_URL`

### SPA Routing (`vercel.json`)

- Rewrites `/(.*) → /index.html` (SPA routing)
- Headers securite: `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`
- Cache assets: `max-age=31536000, immutable`
- Service worker: `no-cache`

---

## 4) Audit des ecrans — Web vs Mobile

### Disponibles sur le web (~68 routes)

| Categorie | Nb | Routes principales |
|-----------|----|--------------------|
| Navigation | 5 | `/`, `/tools`, `/education/hub`, `/profile` (placeholder), `/home` → `/` |
| Auth | 5 | `/landing`, `/auth/login`, `/auth/register`, `/auth/forgot-password`, `/auth/verify-email` |
| Coach | 5 | `/coach/agir`, `/coach/refresh`, `/coach/cockpit`, `/coach/decaissement`, `/coach/succession` |
| Simulators | 6 | `/simulator/compound`, `leasing`, `3a`, `credit`, `job-comparison`, `disability-gap` |
| Life Events | 8 | `divorce`, `succession`, `housing-sale`, `donation`, `mariage`, `naissance`, `concubinage`, `expatriation` |
| Disability | 3 | `/disability/gap`, `insurance`, `self-employed` |
| Arbitrage | 6 | `bilan`, `rente-vs-capital`, `allocation-annuelle`, `location-vs-propriete`, `rachat-vs-marche`, `calendrier-retraits` |
| LPP Deep | 3 | `rachat`, `libre-passage`, `epl` |
| Independants | 5 | `avs`, `ijm`, `3a`, `dividende-salaire`, `lpp-volontaire` |
| Mortgage | 5 | `affordability`, `amortization`, `epl-combined`, `imputed-rental`, `saron-vs-fixed` |
| Pillar 3a Deep | 3 | `comparator`, `real-return`, `staggered-withdrawal` |
| Debt Prevention | 3 | `ratio`, `help`, `repayment` |
| Segments | 3 | `gender-gap`, `frontalier`, `independant` |
| Assurances | 2 | `lamal`, `coverage` |
| Open Banking | 3 | `hub`, `transactions`, `consents` |
| Onboarding | 3 | `quick`, `chiffre-choc`, `smart` → `quick` |
| Profile sub | 5 | `admin-observability`, `admin-analytics`, `consent`, `byok`, `bilan` |
| Other | 9 | `ask-mint`, `household`, `budget`, `fiscal`, `timeline`, `confidence`, `portfolio`, `report/v2`, `score-reveal` |

### Exclus du web — dart:io / flutter_gemma (7 ecrans avec redirects)

| Ecran | Raison | Comportement web |
|-------|--------|-----------------|
| `MainNavigationShell` | notification_service → dart:io | `/home` → `/` |
| `ProfileScreen` | document_provider → dart:io | `/profile` → placeholder texte |
| `CoachCheckinScreen` | notification_service → dart:io | → `/coach/dashboard` |
| `CoachChatScreen` | slm_engine → dart:io | → `/coach/dashboard` |
| `DataBlockEnrichmentScreen` | slm_provider → dart:io | → `/profile` |
| `RetirementDashboardScreen` | coach_narrative → slm_engine → flutter_gemma | → `/` |
| `SmartOnboardingScreen` | fichier supprime/renomme | → `/onboarding/quick` |

### Exclus — fonctionnalites natives (pas de route web)

| Ecran | Raison |
|-------|--------|
| `DocumentScanScreen` | Camera/OCR natif |
| `DocumentDetailScreen` | document_provider → dart:io |
| `BankImportScreen` | File picker natif |
| `SlmSettingsScreen` | Gestion modele SLM local |
| `DocumentImpactScreen` | Flux document scan |
| `ExtractionReviewScreen` | Flux document scan |

### A examiner

| Ecran | Statut |
|-------|--------|
| `PulseScreen` | Pas dans le web router — a ajouter si web-compatible |
| `AvsGuideScreen` | Partie du flux document scan — probablement a exclure |

---

## 5) Plan SLM Web (sprint futur)

### Probleme

3 ecrans exclus a cause de la chaine d'import SLM :
```
RetirementDashboardScreen → coach_narrative_service → slm_engine → flutter_gemma (dart:io)
CoachChatScreen → slm_engine → flutter_gemma (dart:io)
CoachCheckinScreen → notification_service → dart:io
```

### Solution prevue

Endpoint backend `/api/v1/coach/narrate` qui execute le SLM cote serveur.

```dart
// coach_narrative_service.dart (futur)
if (kIsWeb) {
  return await ApiService.post('/coach/narrate', context);
} else {
  return await SlmEngine.generate(prompt);
}
```

**Etapes** :
1. Backend : creer endpoint `/api/v1/coach/narrate` (python-agent)
2. Flutter : modifier `coach_narrative_service` avec import conditionnel (dart-agent)
3. Resultat : debloque `RetirementDashboardScreen` + `CoachChatScreen` sur le web

---

## 6) Regles non negociables

1. **Zero-modification** : ne jamais modifier les fichiers mobile existants pour le web
2. **dart:io interdit** : tout ecran qui importe dart:io (meme transitivement) doit etre exclu du web router
3. **Pas de duplication** : les ecrans mobile sont reutilises, pas copies
4. **Redirects** : tout ecran exclu doit avoir un redirect vers une page web-safe
5. **MintColors** : jamais de hex hardcode, toujours `MintColors.*`
6. **WebResponsiveWrapper** : tout ecran dans le web router doit etre wrappe (max 960px)

---

## 7) Commandes

```bash
# Build web local
cd apps/mobile
flutter run -d chrome -t lib/main_web.dart --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1

# Build web release
flutter build web -t lib/main_web.dart --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1

# Deploy manuel (via GitHub Actions)
gh workflow run web.yml --ref <branch> -f environment=staging
```

---

## 8) Chemin 3 — Strategie long terme

| Site | URL | Techno | Role |
|------|-----|--------|------|
| Vitrine | `mint-ia.ch` | Next.js | SEO, acquisition, landing page |
| Application | `app.mint-ia.ch` | Flutter Web | App complete, utilisateurs connectes |

La vitrine Next.js est une page marketing simple (5-10 pages) qui redirige vers l'app Flutter Web pour les utilisateurs authentifies.

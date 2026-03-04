# Vision Tech Stack — Mint

## Mobile
- Flutter (iOS + Android)
- Architecture: domain (calculs) séparé de l’UI
- Client API généré depuis OpenAPI (si openapi_generator choisi)

## Backend
- FastAPI + structure modulaire (APIRouter)
- Ruff + Pytest
- OpenAPI contract-first

## Contrats
- tools/openapi/mint.openapi.yaml = contrat d’intégration
- SOT.md = contraintes métier + types canon
## Data Connectivity Layer (Couche d'intégration)

### Architecture d'acquisition des données

```
┌─────────────────────────────────────────────────────────┐
│                     MINT App (Flutter)                   │
│  ┌─────────────┬──────────────┬─────────────────────┐   │
│  │ Document     │ Open Banking │ Institutional APIs  │   │
│  │ Parser       │ Service      │ Service             │   │
│  │ (on-device)  │ (bLink/SFTI) │ (caisses, AVS, AFC)│   │
│  └──────┬──────┴──────┬───────┴──────────┬──────────┘   │
│         │             │                  │              │
│  ┌──────▼─────────────▼──────────────────▼──────────┐   │
│  │           ProfileField<T> (unified)               │   │
│  │   value + DataSource + updatedAt + confidence     │   │
│  └──────────────────────┬───────────────────────────┘   │
│                         │                               │
│  ┌──────────────────────▼───────────────────────────┐   │
│  │   EnhancedConfidenceScorer (3 axes)              │   │
│  │   completeness × accuracy × freshness → score    │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Canal 1 — Document Parsing (on-device)
- **OCR**: google_mlkit_text_recognition (default) / Apple Vision
- **Extraction**: Template-based (top 20 caisses LPP) + LLM fallback (BYOK)
- **Privacy**: Image jamais stockée, OCR sur l'appareil, données chiffrées au repos
- **Documents**: Certificat LPP, déclaration fiscale, extrait AVS, attestation 3a, attestation hypothécaire

### Canal 3 — Open Banking (bLink/SFTI)
- **Protocole**: bLink API v2 (SIX Financial Information AG)
- **Mode**: Sandbox (production = gate FINMA)
- **Consentement**: nLPD-compliant (90j max, révocable, audit log)
- **Banques**: UBS, PostFinance, Raiffeisen, CS/UBS, BCV, BCGE, ZKB, Neon, Yuh

### Canal 4 — APIs Institutionnelles (vision long terme)
- **Caisses de pension**: API REST (pilote) ou scraping portail membre authentifié
  - Authentification: eID / login portail caisse (credentials jamais stockés par MINT)
  - Données: solde LPP (oblig/suroblig), taux conversion, rachat, rente projetée, couverture
  - Protocole cible: JSON REST, OAuth2 / eID-based auth
- **AVS/AI**: PDF parsing (court terme) → eID-based API (moyen terme via www.ahv-iv.ch)
- **AFC**: Barèmes cantonaux publics (déjà intégré via TaxCalculator)
- **Assureurs**: Scan OCR polices (même pipeline documents)

### Source Tracking (DataSource enum)
```dart
enum DataSource {
  systemEstimate,            // 0.25 — MINT computed default
  userEstimate,              // 0.50 — "environ 100k"
  userEntry,                 // 0.70 — exact number typed
  userEntryCrossValidated,   // 0.75 — typed + consistency check
  documentScan,              // 0.85 — OCR from certificate
  documentScanVerified,      // 0.95 — OCR + user confirmed
  openBanking,               // 1.00 — live bank feed (bLink)
  institutionalApi,          // 1.00 — direct from caisse/AFC
}
```

## Design Vision
- Style: Pastel, sober, minimaliste.
- Couleurs: Fond blanc/gris très clair, accents doux (menthe pastel, gris ardoise).
- Typography: Moderne, sobre (ex: Montserrat ou Inter léger), espacement généreux.
- UX: Auto-advance sur les sélections, navigation fluide bidirectionnelle.

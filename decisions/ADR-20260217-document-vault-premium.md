# ADR-20260217-DOCUMENT-VAULT-PREMIUM

Date: 2026-02-17
Status: Proposed

---

## Contexte

MINT est aujourd'hui un outil educatif read-only. L'utilisateur saisit manuellement ses donnees (wizard, sliders) et recoit des simulations pedagogiques. Cette approche a deux limites :

1. **Precision** : les simulateurs (LPP, fiscalite, retraite) sont aussi precis que les donnees saisies manuellement — souvent approximatives.
2. **Retention** : une fois le rapport genere, l'utilisateur n'a pas de raison de revenir regulierement.

L'idee est de transformer MINT en **hub financier permanent** via un coffre-fort documentaire qui centralise, parse et exploite les documents financiers de l'utilisateur (certificat de salaire, certificat LPP, contrats d'assurance, bail, releves LAMal, etc.).

Deux modalites d'ingestion sont evaluees :
- **Upload manuel** (photo/PDF)
- **Adresse email dediee** (`prenom@docs.mint.ch`) ou les services envoient directement les documents

---

## Decision

### Architecture en 3 phases

#### Phase 1 — MVP Upload (Sprint cible : S33-S35)

L'utilisateur upload manuellement ses documents (photo ou PDF). MINT les parse via OCR et extrait les champs cles pour alimenter les simulateurs.

**Documents P0 (Phase 1) :**

| Document | Champs extraits | Alimentent |
|----------|----------------|------------|
| Certificat de salaire | Revenu brut/net, deductions, cotisations LPP/AVS | Fiscalite, budget, retraite |
| Certificat LPP | Avoir, salaire assure, lacune rachat, taux conversion | LPP deep, rachat, retraite |
| Attestation 3a | Montant verse, prestataire | 3a deep, fiscalite |

**Documents P1 (Phase 1, stretch) :**

| Document | Champs extraits | Alimentent |
|----------|----------------|------------|
| Bail / contrat de location | Loyer net, charges, duree, preavis | Budget, comparateur achat/location |
| Police d'assurance (RC, menage) | Couverture, prime, franchise | Audit couverture, budget |

**Stack technique :**
- OCR on-device : `google_mlkit_text_recognition` (Flutter, offline)
- Fallback cloud : Google Vision API ou Azure Form Recognizer (documents complexes)
- Stockage : chiffrement AES-256 at-rest, cle derivee du mot de passe utilisateur
- Aucun document ne transite par le backend MINT en clair — parsing local first
- Extraction de champs : regex + heuristiques suisses (formats connus des certificats de salaire cantonaux)

**UX :**
- Ecran "Mon coffre-fort" accessible depuis le profil
- Upload via camera (scan) ou selection fichier
- Preview du document + champs extraits editables ("On a lu ceci — corrige si besoin")
- Les champs valides alimentent automatiquement les simulateurs (avec badge "Source : document")
- Rappels annuels : "Ton certificat de salaire 2026 est disponible — scanne-le pour mettre a jour tes simulations"

#### Phase 2 — Forward Email (S36+)

L'utilisateur configure un transfert automatique depuis sa boite mail personnelle vers une adresse MINT dediee (`userId@docs.mint.ch` ou `mint+userId@docs.mint.ch`).

**Pourquoi forward plutot qu'adresse directe :**
- En Suisse, les employeurs/assureurs envoient les documents **au salarie**, pas a un tiers
- Le forward preserve le controle de l'utilisateur (c'est lui qui decide ce qui arrive)
- Pas besoin de convaincre des tiers d'utiliser une nouvelle adresse
- Compatible avec les regles de forwarding Gmail/Outlook/ProtonMail

**Stack :**
- Inbound email via Postmark/SendGrid (sous-domaine `docs.mint.ch`)
- Pipeline : reception → extraction PJ → OCR → classification ML → extraction champs → stockage chiffre
- Classification : modele leger (type de document, emetteur, date) entraine sur corpus suisse
- Anti-spam + verification : rejet si expediteur non reconnu, alerte si format suspect

#### Phase 3 — Integrations API directes (S40+)

Connexions API avec des partenaires (caisses de pension, assureurs, regies) pour reception automatique des documents.

- Modele identique a Open Banking (bLink/SFTI) : consent-based, read-only
- Necessite des partenariats commerciaux
- Differenciateur long terme majeur

### Monetisation

| Tier | Fonctionnalite | Prix indicatif |
|------|---------------|---------------|
| Free | Education, simulateurs, wizard, plan d'actions | Gratuit |
| Premium | Coffre-fort (upload), OCR, rappels, audit couverture, coaching proactif | 9.90 CHF/mois |
| Premium+ | Forward email, integrations API, alertes proactives, export fiscal | 14.90 CHF/mois |

### Guidance juridique — Perimetre strict

MINT peut **informer** mais jamais **conseiller** :

| Autorise | Interdit |
|----------|----------|
| "Ton bail prevoit un preavis de 3 mois" (lecture du document) | "Tu devrais contester ce loyer" (conseil juridique) |
| "Le loyer median dans ton quartier est de X CHF" (donnee publique) | "Ton loyer est abusif, voici la marche a suivre" (qualification juridique) |
| "Checklist : as-tu pense a verifier X ?" (education) | "Envoie cette lettre a ta regie" (injonction) |
| Lien vers l'ASLOCA ou un service cantonal (orientation) | Redirection vers un avocat partenaire avec commission (courtage LSFin) |

**Regle** : l'Anwaltsmonopol (monopole du barreau) s'applique dans la plupart des cantons suisses. MINT reste un outil pedagogique — toute formulation qui pourrait etre interpretee comme du conseil juridique personnalise est proscrite.

---

## Alternatives considerees

### A. Adresse email dediee des le MVP

**Rejetee.** Raisons :
1. Les employeurs/assureurs suisses n'enverront pas a une adresse tierce — l'utilisateur devra forward de toute facon
2. Le parsing email est un produit en soi (formats varies, PJ multiples, HTML vs texte)
3. Infrastructure email (anti-spam, deliverabilite, monitoring) trop lourde pour un MVP
4. Risque securitaire : email non chiffre de bout en bout par defaut (SMTP)

### B. Integration API directe des le MVP

**Rejetee.** Raisons :
1. Necessite des partenariats longs a negocier
2. Pas de standard unifie en Suisse pour les documents non bancaires
3. Chaque caisse/assureur a son propre format

### C. Pas de coffre-fort (rester education pure)

**Rejetee.** Raisons :
1. Retention insuffisante — l'utilisateur revient une fois par an
2. Precision limitee — les simulations restent approximatives
3. Pas de justification Premium credible sans valeur tangible recurrente

### D. Partenariat avec un coffre-fort existant (Tresorit, SecureSafe)

**Consideree pour Phase 2+.** Avantages : pas d'infra stockage a gerer. Inconvenients : perte de controle UX, pas de parsing integre, dependance tierce. Pourrait etre un fallback si les couts d'infra sont prohibitifs.

---

## Consequences

### Positives

- **Retention massive** : une fois les documents stockes, switching cost eleve (l'utilisateur ne migre pas facilement)
- **Precision des simulateurs** : donnees reelles vs estimations manuelles
- **Justification Premium** : valeur tangible et recurrente (coffre-fort = service permanent)
- **Upsell naturel** : "Scanne ton certificat LPP pour debloquer le simulateur de rachat precis"
- **Differenciation** : aucun concurrent suisse ne combine education + coffre-fort + parsing
- **Donnees agregees anonymisees** : potentiel pour etudes de marche (sous consentement explicite)

### Negatives

- **Complexite technique** : OCR, classification, extraction — chaque type de document suisse a son format
- **Responsabilite** : si MINT parse mal un salaire, l'utilisateur prend une mauvaise decision fiscale → besoin de disclaimer fort + champs editables
- **Couts infra** : stockage chiffre, OCR cloud (fallback), pipeline ML
- **Assurance RC professionnelle** : potentiellement necessaire si les erreurs de parsing causent un prejudice
- **Support client** : "MINT a mal lu mon document" — necessite un canal de correction

### Compliance (nLPD + FINMA)

| Exigence | Mesure |
|----------|--------|
| nLPD art. 5 (donnees sensibles) | Consentement explicite pour chaque type de document. Sante (LAMal) = opt-in separe |
| nLPD art. 6 (finalite) | Finalite declaree : "ameliorer la precision de tes simulations". Pas de revente, pas de profilage marketing |
| nLPD art. 8 (securite) | AES-256 at-rest, TLS in-transit, cle derivee utilisateur, zero-knowledge si possible |
| nLPD art. 25 (droit d'acces) | Export integralite des documents + donnees extraites sur demande |
| nLPD art. 27 (droit a l'effacement) | Suppression complete (documents + champs extraits) sur demande, delai 30 jours max |
| FINMA | Pas de licence requise tant que MINT reste read-only et educatif. Pas de courtage, pas de commission sur orientation juridique |
| Anwaltsmonopol | Informer, jamais conseiller. Orientation vers services publics (ASLOCA, offices cantonaux) sans commission |

### Risques a monitorer

| Risque | Probabilite | Impact | Mitigation |
|--------|------------|--------|------------|
| Erreur de parsing causant decision erronee | Moyenne | Haut | Champs editables + disclaimer + validation utilisateur obligatoire |
| Fuite de donnees (documents sensibles) | Faible | Critique | Chiffrement E2E, audit securite, pentest avant lancement |
| Requalification FINMA (courtage deguise) | Faible | Haut | Jamais de commission sur orientations. Alternatives non-partenaires toujours proposees |
| Cout infra superieur au revenu Premium | Moyenne | Moyen | Limiter le nombre de documents/mois en Premium. Metering |
| Adoption faible (friction upload) | Moyenne | Moyen | Phase 2 (forward email) reduit la friction. Rappels annuels proactifs |

---

## Plan de migration

### Phase 1 — MVP Upload (estimation : 3 sprints)

```
Sprint 1 : Infrastructure
  - DocumentVaultService (Dart) : upload, stockage chiffre, CRUD
  - DocumentModel : type, rawFile, extractedFields, status, createdAt
  - Ecran "Mon coffre-fort" (liste + upload)
  - Chiffrement AES-256 avec flutter_secure_storage pour la cle

Sprint 2 : OCR + Extraction
  - Integration google_mlkit_text_recognition (on-device)
  - Parsers specifiques : CertificatSalaireParser, CertificatLPPParser
  - Ecran de review : "On a lu ceci — corrige si besoin"
  - Alimentation automatique du profil (avec source tracking)

Sprint 3 : Premium gate + Polish
  - Subscription wall (max 2 documents gratuits, illimite en Premium)
  - Rappels annuels ("Ton certificat 2026 est dispo ?")
  - Audit couverture assurance (si polices uploadees)
  - Tests (OCR accuracy, edge cases cantonaux, compliance)
```

### Phase 2 — Forward Email (estimation : 2 sprints)

```
Sprint 4 : Inbound email pipeline
  - Setup Postmark/SendGrid inbound
  - Classification ML (type de document)
  - Integration dans le coffre-fort existant

Sprint 5 : UX + Onboarding
  - Guide de configuration forward (Gmail, Outlook, ProtonMail)
  - Dashboard "Documents recus automatiquement"
  - Alertes si document non recu (rappel annuel)
```

### Phase 3 — API (estimation : TBD, depend des partenariats)

---

## Liens

- `visions/vision_monetization.md` — Modele de monetisation actuel
- `visions/vision_trust_privacy.md` — Politique de confiance et vie privee
- `visions/vision_compliance.md` — Cadre compliance FINMA/LSFin
- `visions/vision_features.md` — Contrats d'ecran et fonctionnalites
- `decisions/ADR-CH-EDU-SIMULATORS.md` — Simulateurs et inserts educatifs
- nLPD (nouvelle Loi sur la Protection des Donnees, en vigueur depuis sept. 2023)
- LPD art. 5, 6, 8, 25, 27
- FINMA circulaires sur les regles de conduite (LSFin/OSFin)
- Anwaltsmonopol : LLCA art. 12 (Loi sur la libre circulation des avocats)

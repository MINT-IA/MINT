# Analyse d'impact relative à la protection des données (DPIA)

> nLPD Art. 22 — Obligatoire quand le traitement présente un risque élevé pour les droits des personnes

## Traitements à risque élevé identifiés

### 1. Injection de données financières dans un LLM (Claude)

| Aspect | Évaluation |
|--------|-----------|
| **Description** | Le coach AI reçoit un contexte utilisateur (âge, canton, archetype, scores financiers) pour personnaliser ses réponses |
| **Données envoyées** | Prénom, âge, canton, archetype, FRI score, taux de remplacement, mois de liquidité, potentiel fiscal, confiance, streak, phase fiscale |
| **Données JAMAIS envoyées** | Salaire exact, soldes bancaires, montants de dette, IBAN, employeur, noms de famille, adresse |
| **Risque** | Profilage financier par un sous-traitant US. Anthropic pourrait théoriquement reconstituer un profil financier partiel. |
| **Probabilité** | Faible (données agrégées, pas de PII direct) |
| **Gravité** | Moyenne (données financières sensibles même agrégées) |
| **Mesures en place** | CoachContext PII filter, consent explicite (byokDataSharing), ComplianceGuard sur outputs |
| **Mesures à ajouter** | DPA avec Anthropic, SCC, option "do_not_log" dans l'API |
| **Risque résiduel** | Acceptable après DPA + SCC |

### 2. Scan de documents via Claude Vision

| Aspect | Évaluation |
|--------|-----------|
| **Description** | L'utilisateur scanne un certificat LPP/AVS/salaire. L'image est envoyée à Claude Vision pour extraction OCR. |
| **Données envoyées** | Image complète du document (peut contenir : nom, employeur, salaire, numéro AVS, adresse) |
| **Risque** | PII directe envoyée à un sous-traitant US. Le document peut contenir des données très sensibles. |
| **Probabilité** | Élevée (chaque scan envoie un document complet) |
| **Gravité** | Élevée (numéro AVS = identifiant unique, salaire exact) |
| **Mesures en place** | Consentement documentUpload, image non conservée après extraction, rate limit 10/min, timeout 30s |
| **Mesures à ajouter** | DPA avec Anthropic incluant clause de non-rétention des images, SCC, information claire à l'utilisateur avant le scan |
| **Risque résiduel** | Moyen — nécessite DPA pour être acceptable |

### 3. Embeddings vectoriels (OpenAI → pgvector)

| Aspect | Évaluation |
|--------|-----------|
| **Description** | Les insights du coach sont résumés en texte, envoyés à OpenAI pour embedding, stockés dans pgvector pour retrieval futur |
| **Données envoyées** | Résumé textuel de l'insight (~200 chars), topic, type d'insight |
| **Risque** | Le résumé peut contenir du contexte financier implicite ("discussion sur le rachat LPP de 500k") |
| **Probabilité** | Moyenne |
| **Gravité** | Faible (résumés, pas de données structurées) |
| **Mesures en place** | Metadata whitelist (4 safe keys), consent ragQueries, summary truncation 8000 chars |
| **Mesures à ajouter** | DPA avec OpenAI, PII regex scan avant embedding, user_id isolation dans pgvector |
| **Risque résiduel** | Faible après mesures |

### 4. Stockage backend (Railway PostgreSQL)

| Aspect | Évaluation |
|--------|-----------|
| **Description** | Le profil utilisateur complet est stocké en JSON dans PostgreSQL sur Railway |
| **Données stockées** | Tout le CoachProfile (prénom, salaire, pension, dettes, dépenses, objectifs) |
| **Risque** | Brèche de la base de données = exposition de toutes les données financières |
| **Probabilité** | Faible (Railway infrastructure sécurisée) |
| **Gravité** | Critique (données financières complètes) |
| **Mesures en place** | Auth JWT, HTTPS, rate limits, user isolation par endpoints |
| **Mesures à ajouter** | Chiffrement at rest, DPA avec Railway, backups chiffrés, audit logs |
| **Risque résiduel** | Acceptable après DPA + chiffrement |

## Matrice de risque résumée

| Traitement | Probabilité | Gravité | Risque brut | Mesures | Risque résiduel |
|-----------|-------------|---------|-------------|---------|-----------------|
| Coach LLM | Faible | Moyen | MOYEN | CoachContext filter + consent | **FAIBLE** (après DPA) |
| Vision scan | Élevée | Élevée | **ÉLEVÉ** | Consent + non-rétention image | **MOYEN** (après DPA) |
| Embeddings | Moyenne | Faible | FAIBLE | Whitelist + consent | **FAIBLE** (après DPA) |
| Backend DB | Faible | Critique | ÉLEVÉ | JWT + HTTPS + rate limits | **MOYEN** (après DPA + encryption) |

## Décision

☐ Les traitements sont acceptables avec les mesures en place
☐ Les traitements nécessitent des mesures supplémentaires avant mise en production
☐ Consultation du PFPDT nécessaire

**Date** : _À compléter_
**Signataire** : _DPO_

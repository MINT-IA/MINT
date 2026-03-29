# Registre des traitements — MINT

> nLPD Art. 12 / OPDo Art. 12
> Dernière mise à jour : _À compléter_

## 1. Profil financier utilisateur

| Champ | Détail |
|-------|--------|
| **Responsable** | MINT SA (ou raison sociale) |
| **Finalité** | Éducation financière personnalisée (simulations retraite, budget, fiscalité) |
| **Base légale** | Consentement explicite (Art. 6 al. 6 nLPD) |
| **Catégories de données** | Prénom, année de naissance, canton, salaire brut, statut civil, nombre d'enfants, données de prévoyance (LPP, AVS, 3a), dettes, dépenses, objectifs financiers |
| **Catégories de personnes** | Résidents suisses 22-75 ans |
| **Destinataires** | Anthropic (Claude AI), OpenAI (embeddings), Railway (hébergement backend) |
| **Transfert hors CH** | Oui — États-Unis (Anthropic, OpenAI, Railway) |
| **Safeguards** | SCC à mettre en place (voir ops/compliance/DPA/) |
| **Durée de conservation** | Jusqu'à suppression par l'utilisateur. Max 7 jours pour comptes non vérifiés. |
| **Mesures de sécurité** | AES-256 (local), TLS 1.2+ (transit), JWT (auth), consent manager granulaire |

## 2. Scan de documents (Vision)

| Champ | Détail |
|-------|--------|
| **Finalité** | Extraction automatique de données depuis certificats LPP, fiches de salaire, attestations AVS |
| **Base légale** | Consentement explicite (documentUpload) |
| **Données traitées** | Image du document (base64), champs extraits (montants, taux, dates) |
| **Destinataires** | Anthropic Claude Vision API |
| **Transfert hors CH** | Oui — États-Unis |
| **Durée** | Image non conservée après extraction. Champs extraits conservés dans le profil. |
| **Note** | Document original jamais stocké. Seuls les champs structurés sont retenus. |

## 3. Mémoire conversationnelle (RAG)

| Champ | Détail |
|-------|--------|
| **Finalité** | Continuité du coaching AI (se souvenir des sujets abordés) |
| **Base légale** | Consentement explicite (ragQueries) |
| **Données traitées** | Résumés d'insights (topics financiers, pas de montants exacts), embeddings vectoriels |
| **Destinataires** | OpenAI (génération d'embeddings), Railway PostgreSQL + pgvector (stockage) |
| **Transfert hors CH** | Oui — États-Unis |
| **Durée** | Max 50 insights (FIFO). Supprimés à la demande ou à la suppression du compte. |

## 4. Conversations coach

| Champ | Détail |
|-------|--------|
| **Finalité** | Historique des échanges avec le coach AI |
| **Base légale** | Consentement implicite (fonctionnalité core) |
| **Données traitées** | Messages texte utilisateur + réponses coach |
| **Stockage** | Local uniquement (SharedPreferences sur l'appareil) |
| **Transfert hors CH** | Non (stockage local uniquement) |
| **Durée** | Jusqu'à suppression par l'utilisateur ou déconnexion |

## 5. Analytics (optionnel)

| Champ | Détail |
|-------|--------|
| **Finalité** | Amélioration du produit (usage anonymisé) |
| **Base légale** | Consentement explicite (analytics) |
| **Données traitées** | Événements anonymisés (écrans visités, actions effectuées). Jamais de PII. |
| **Destinataires** | Railway (backend MINT uniquement) |
| **Durée** | user_id anonymisé à la suppression du compte |

---

## Sous-traitants (processeurs)

| Sous-traitant | Siège | Données traitées | DPA signé | SCC signé |
|---------------|-------|------------------|-----------|-----------|
| Anthropic | San Francisco, US | Prompts coach, images documents | ☐ À faire | ☐ À faire |
| OpenAI | San Francisco, US | Textes pour embedding | ☐ À faire | ☐ À faire |
| Railway | San Francisco, US | Profils, sessions, embeddings | ☐ À faire | ☐ À faire |
| Apple (TestFlight) | Cupertino, US | App binary, crash logs | ☐ À vérifier | N/A (ToS) |

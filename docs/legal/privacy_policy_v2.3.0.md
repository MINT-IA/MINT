# MINT — Politique de confidentialité v2.3.0

> **Statut** : brouillon technique — version finale à valider avec avocat (Walder Wyss / MLL Legal).
> Cette version est utilisée par le système de consentement granulaire (Phase 29-02 / PRIV-01).
> Modifier cette politique = bumper la version (v2.3.1, v2.4.0, etc.) et régénérer les consentements utilisateurs via la vue diff.

## 1. Responsable du traitement

MINT Finance SA, Sion (VS), Suisse. Contact protection des données : privacy@mint.ch.

## 2. Base légale (nLPD art. 6 al. 6)

Le traitement de tes données personnelles repose sur ton **consentement explicite granulaire**.
Tu peux révoquer chaque consentement à tout moment depuis l'espace "Ma vie privée" du profil.

## 3. Finalités de traitement (4 purposes)

### 3.1 `vision_extraction`

- **Quoi** : lecture automatisée par IA (Claude Vision) des documents que tu uploades (certificats LPP, contrats, fiches de paie).
- **Pourquoi** : extraire les chiffres pertinents pour MINT (avoir LPP, salaire assuré, etc.).
- **Durée** : le temps du traitement (session).
- **Transfert** : voir `transfer_us_anthropic`.

### 3.2 `persistence_365d`

- **Quoi** : conservation chiffrée (AES-256-GCM) du texte extrait de tes documents.
- **Pourquoi** : te permettre de retrouver l'historique et d'éviter de ré-uploader les mêmes pièces.
- **Durée** : 365 jours maximum, puis purge automatique.
- **Révocation** : déclenche une suppression cryptographique (crypto-shredding) sous 30 jours.

### 3.3 `transfer_us_anthropic`

- **Quoi** : envoi du document (masqué des PII lorsque possible) aux serveurs Anthropic aux États-Unis.
- **Pourquoi** : appel de l'API Claude Vision.
- **Durée** : le temps de l'appel. Anthropic opère en mode Zero Data Retention (ZDR).
- **Base** : Swiss-US Data Privacy Framework (reconnu par la Suisse depuis septembre 2024).
- **Statut** : cette finalité sera désactivée à l'issue de la migration vers AWS Bedrock Frankfurt (Phase 29-06).

### 3.4 `couple_projection`

- **Quoi** : utilisation des données de ton/ta partenaire dans les projections de couple (AVS cap 150%, splitting, etc.).
- **Pourquoi** : produire des scénarios réalistes pour un ménage.
- **Déclaration opposable** : tu confirmes avoir obtenu le consentement de la personne concernée (nLPD art. 30-31).
- **Durée** : tant que le lien couple est actif dans ton profil.

## 4. Tes droits (nLPD art. 25-32)

- **Accès / portabilité** : `POST /api/v1/privacy/export`.
- **Suppression** : `POST /api/v1/privacy/delete`.
- **Révocation granulaire** : `POST /api/v1/consents/{receipt_id}/revoke`.
- **Historique des consentements** : `GET /api/v1/consents`.
- **Vérification d'intégrité** (chaîne Merkle) : `GET /api/v1/consents/verify-chain`.

## 5. Reçus de consentement (ISO/IEC 29184:2020)

Chaque consentement produit un reçu JSON signé (HMAC-SHA256) et chaîné (Merkle). Le reçu contient :
`receiptId`, `piiPrincipalId` (sha256 de ton ID, jamais l'ID brut), `purposeCategory`, `policyVersion`,
`policyHash`, `consentTimestamp`, `jurisdiction=CH`, `lawfulBasis=consent_nLPD_art_6_al_6`.

## 6. Contact & plainte

- Délégué·e à la protection des données : privacy@mint.ch.
- Autorité de contrôle : Préposé·e fédéral·e à la protection des données et à la transparence (PFPDT), Berne.

---
_Version technique — texte juridique final à valider._

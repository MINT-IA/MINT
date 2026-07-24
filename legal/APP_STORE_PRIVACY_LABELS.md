# App Store Privacy Labels — MINT

**Dernière mise à jour : mars 2026**

> Ce document décrit les déclarations de confidentialité à soumettre sur l'Apple App Store (Privacy Nutrition Labels) et le Google Play Store (Data Safety Section) pour MINT.

---

## 1. Apple App Store — Privacy Nutrition Labels

### Contexte réglementaire

Depuis décembre 2020, Apple exige que chaque application déclare ses pratiques de collecte de données via les « App Privacy Labels » (aussi appelées « nutrition labels »). Ces informations sont affichées publiquement sur la fiche App Store.

> **Référence** : Apple Developer Documentation — [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)

### Déclarations MINT (état actuel de l'app)

#### Collecte réelle

> Brouillon technique reflétant le comportement RÉEL de l'app. Les valeurs finales soumises à Apple/Google doivent être validées avec le conseil juridique (comme la politique de confidentialité, cf. `docs/legal/privacy_policy_v2.3.0.md`).

L'app collecte un **profil financier** : chiffré, synchronisé côté serveur (Railway, US) et transmis pseudonymisé — montants exacts inclus — au coach IA (Anthropic, US), sans nom, IBAN ni numéro AVS. Les catégories concernées déclarent donc une collecte de données financières liées à l'identité, pour la fonctionnalité de l'app (jamais pour du tracking).

#### Catégories détaillées

| Catégorie Apple | Collecté ? | Lié à l'identité ? | Suivi (tracking) ? | Notes |
|----------------|-----------|-------------------|-------------------|-------|
| **Contact Info** (name, email, phone) | Non | — | — | Ni nom, email ni téléphone transmis (cf. PRIVACY.md 2.3) |
| **Health & Fitness** | Non | — | — | — |
| **Financial Info** | **Oui** | **Oui** | Non | Profil (salaire, LPP, 3a, patrimoine) chiffré, synchronisé serveur + envoyé au coach IA Anthropic (montants exacts, pseudonymisé) — App Functionality |
| **Location** | Non | — | — | Canton déclaré manuellement, pas de GPS |
| **Sensitive Info** | Non | — | — | — |
| **Contacts** | Non | — | — | — |
| **User Content** (documents, messages) | **Oui** | **Oui** | Non | Documents uploadés (certificats LPP, fiches de paie, contrats) analysés par Anthropic Claude Vision (US, masquage PII lorsque possible) + messages écrits au coach transmis tels quels à Anthropic (US) — App Functionality |
| **Browsing History** | Non | — | — | — |
| **Search History** | Non | — | — | — |
| **Identifiers** (User ID) | **Oui** | **Oui** | Non | ID de compte / session (auth JWT) — App Functionality, aucun tracking cross-app |
| **Purchases** | Oui (via App Store) | Non | Non | Gérés par Apple, pas par MINT |
| **Usage Data** (product interaction) | Oui (optionnel) | Non | Non | Analytics anonymisées, désactivables |
| **Diagnostics** (crash data, performance) | Oui | Non | Non | Logs d'erreurs anonymisés, 30 jours max |

#### Résumé pour App Store Connect

```
✅ Data Used to Track You: NONE (aucun tracking cross-app, ATT non requis)
⚠️ Data Linked to You:
   - Financial Info (profil financier — App Functionality)
   - User Content (documents uploadés → Claude Vision + messages au coach IA)
   - Identifiers (ID de compte)
⚠️ Data Not Linked to You:
   - Usage Data (Analytics — optionnel)
   - Diagnostics (Crash logs)
```

### Évolutions futures à déclarer

Lors de l'introduction de l'Open Banking (import de soldes / transactions bancaires réels) :
- **Financial Info** → soldes et transactions bancaires (lié à l'identité, pour fonctionnalité)
- **Contact Info** → email, si une authentification par email est ajoutée

---

## 2. Google Play Store — Data Safety Section

### Contexte réglementaire

Depuis juillet 2022, Google exige que chaque application déclare ses pratiques via la « Data Safety Section ». Ces informations sont affichées sur la fiche Play Store.

> **Référence** : Google Play Console Help — [Provide information for Google Play's Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469)

### Déclarations MINT (état actuel de l'app)

#### Questionnaire Data Safety

| Question Google | Réponse MINT | Justification |
|----------------|-------------|---------------|
| L'application collecte-t-elle ou partage-t-elle des données utilisateur ? | Oui (profil financier + documents + messages + usage + diagnostics) | Profil financier synchronisé serveur ; documents + messages envoyés au coach/Vision IA ; analytics + crash logs |
| L'application partage-t-elle des données avec des tiers ? | **Oui** | Coach IA Anthropic (US) reçoit le profil financier pseudonymisé (montants exacts), les documents uploadés (Claude Vision) et les messages du coach |
| Les données sont-elles chiffrées en transit ? | Oui | HTTPS/TLS 1.2+ pour appels API |
| Les données sont-elles chiffrées au repos ? | Oui | EncryptedSharedPreferences (AES-256-GCM) |
| L'utilisateur peut-il demander la suppression ? | Oui | Fonction « Supprimer toutes mes données » |
| L'application respecte-t-elle la Families Policy ? | Non applicable | App 18+ uniquement |

#### Types de données déclarés

| Type de données Google | Collecté ? | Partagé ? | Optionnel ? | But |
|----------------------|-----------|----------|------------|-----|
| **App activity** (interactions, other actions) | Oui | Non | Oui (désactivable) | Analytics |
| **App info and performance** (crash logs, diagnostics) | Oui | Non | Non | Stabilité |
| **Device or other IDs** | Non | — | — | — |
| **Financial info** | **Oui** | **Oui** (coach IA Anthropic) | Non | Profil chiffré synchronisé serveur + envoyé au coach IA |
| **Personal info** (User IDs) | **Oui** | Non | Non | Identifiant de compte (auth JWT) — métadonnée interne, non transmise au coach/tiers ; ni nom, email, IBAN ni numéro AVS (cf. PRIVACY.md) |
| **Messages** (in-app messages) | **Oui** | **Oui** (Anthropic US) | Non | Messages écrits au coach transmis tels quels à Anthropic |
| **Photos & videos / Files & docs** | **Oui** | **Oui** (Anthropic US) | Non | Documents uploadés (certificats, fiches de paie, contrats) analysés par Claude Vision (US) |
| **Location** | Non | — | — | Canton déclaré manuellement |

#### Résumé pour Google Play Console

```
⚠️ Data shared with third parties: Yes (coach IA — Anthropic PBC, US)
✅ Data encrypted in transit (TLS 1.2+)
✅ Data encrypted at rest (AES-256)
✅ User can request data deletion
✅ Committed to follow Play Families Policy: N/A (18+)
```

---

## 3. Checklist pré-soumission

### Apple App Store

- [ ] Remplir les Privacy Labels dans App Store Connect > App Privacy
- [ ] URL de la Privacy Policy renseignée : `https://mint-app.ch/privacy`
- [ ] Privacy Policy conforme aux Apple Developer Guidelines § 5.1.1
- [ ] App Tracking Transparency (ATT) : **non requis** (pas de tracking)
- [ ] NSUserTrackingUsageDescription : **non requis** (pas de ATT prompt)
- [ ] Mention de l'âge minimum (18+) dans la description et les metadata

### Google Play Store

- [ ] Remplir la Data Safety Section dans Google Play Console
- [ ] URL de la Privacy Policy renseignée : `https://mint-app.ch/privacy`
- [ ] Privacy Policy conforme aux Google Play Developer Policy
- [ ] Content rating questionnaire rempli (IARC)
- [ ] Mention de l'âge minimum (18+) et target audience
- [ ] Data deletion instructions URL : `https://mint-app.ch/data-deletion`

### Les deux plateformes

- [ ] Privacy Policy hébergée sur un URL public accessible (pas de PDF, pas de page derrière login)
- [ ] Privacy Policy à jour avec la version de l'app soumise
- [ ] Support email fonctionnel : privacy@mint-app.ch
- [ ] Page de suppression de données accessible : instruction in-app + email

---

## 4. URL requises (à déployer avant soumission)

| URL | Contenu | Statut |
|-----|---------|--------|
| `https://mint-app.ch/privacy` | Politique de confidentialité (PRIVACY.md) | À déployer |
| `https://mint-app.ch/terms` | Conditions générales (CGU.md) | À déployer |
| `https://mint-app.ch/legal` | Mentions légales (MENTIONS_LEGALES.md) | À déployer |
| `https://mint-app.ch/data-deletion` | Instructions de suppression de données | À déployer |
| `https://mint-app.ch/support` | Page de support / contact | À déployer |

---

*MINT est un outil éducatif d'aide à la compréhension des décisions financières.*

# App Store Privacy Labels — MINT

**Dernière mise à jour : mars 2026**

> Ce document décrit les déclarations de confidentialité à soumettre sur l'Apple App Store (Privacy Nutrition Labels) et le Google Play Store (Data Safety Section) pour MINT.

---

## 1. Apple App Store — Privacy Nutrition Labels

### Contexte réglementaire

Depuis décembre 2020, Apple exige que chaque application déclare ses pratiques de collecte de données via les « App Privacy Labels » (aussi appelées « nutrition labels »). Ces informations sont affichées publiquement sur la fiche App Store.

> **Référence** : Apple Developer Documentation — [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)

### Déclarations MINT (Phase 1)

#### « Data Not Collected »

En Phase 1, MINT peut déclarer **« Data Not Collected »** pour la majorité des catégories, car toutes les données personnelles restent sur l'appareil.

#### Catégories détaillées

| Catégorie Apple | Collecté ? | Lié à l'identité ? | Suivi (tracking) ? | Notes |
|----------------|-----------|-------------------|-------------------|-------|
| **Contact Info** (name, email, phone) | Non | — | — | Pas de compte obligatoire en Phase 1 |
| **Health & Fitness** | Non | — | — | — |
| **Financial Info** | Non (local seulement) | — | — | Données financières stockées localement uniquement |
| **Location** | Non | — | — | Canton déclaré manuellement, pas de GPS |
| **Sensitive Info** | Non | — | — | — |
| **Contacts** | Non | — | — | — |
| **User Content** | Non | — | — | — |
| **Browsing History** | Non | — | — | — |
| **Search History** | Non | — | — | — |
| **Identifiers** (User ID, Device ID) | Non | — | — | Pas de tracking ID |
| **Purchases** | Oui (via App Store) | Non | Non | Gérés par Apple, pas par MINT |
| **Usage Data** (product interaction) | Oui (optionnel) | Non | Non | Analytics anonymisées, désactivables |
| **Diagnostics** (crash data, performance) | Oui | Non | Non | Logs d'erreurs anonymisés, 30 jours max |

#### Résumé pour App Store Connect

```
✅ Data Used to Track You: NONE
✅ Data Linked to You: NONE
⚠️ Data Not Linked to You:
   - Usage Data (Analytics — optional, anonymized)
   - Diagnostics (Crash logs — anonymized)
```

### Déclarations MINT (Phase 2+ — à mettre à jour)

Lors de l'introduction de comptes utilisateur ou d'Open Banking :
- **Contact Info** → Email (lié à l'identité, pour compte)
- **Financial Info** → Soldes, transactions (lié à l'identité, pour fonctionnalité)
- **Identifiers** → User ID (lié à l'identité, pour compte)

---

## 2. Google Play Store — Data Safety Section

### Contexte réglementaire

Depuis juillet 2022, Google exige que chaque application déclare ses pratiques via la « Data Safety Section ». Ces informations sont affichées sur la fiche Play Store.

> **Référence** : Google Play Console Help — [Provide information for Google Play's Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469)

### Déclarations MINT (Phase 1)

#### Questionnaire Data Safety

| Question Google | Réponse MINT | Justification |
|----------------|-------------|---------------|
| L'application collecte-t-elle ou partage-t-elle des données utilisateur ? | Oui (usage + diagnostics) | Analytics anonymisées + crash logs |
| L'application partage-t-elle des données avec des tiers ? | Non | Aucun partage de données |
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
| **Financial info** | Non (local seulement) | — | — | Stocké localement |
| **Personal info** | Non | — | — | Pas de compte Phase 1 |
| **Location** | Non | — | — | Canton déclaré manuellement |

#### Résumé pour Google Play Console

```
✅ No data shared with third parties
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

*MINT — « Juste quand il faut : une explication, une action, un rappel. »*

# Plan d'intégration juridique — MINT App

**Dernière mise à jour : mars 2026**

> Ce document décrit **où** et **comment** intégrer les documents légaux dans l'application MINT, le site web, et les stores.

---

## 1. Vue d'ensemble des documents légaux

| Document | Fichier | URL publique | Emplacement app |
|----------|---------|-------------|-----------------|
| Conditions Générales d'Utilisation | `legal/CGU.md` | `/terms` | Profil > Informations légales |
| Politique de confidentialité | `PRIVACY.md` | `/privacy` | Profil > Informations légales |
| Mentions légales | `legal/MENTIONS_LEGALES.md` | `/legal` | Profil > Informations légales |
| Disclaimer éducatif | `legal/DISCLAIMER.md` | `/disclaimer` | Profil > Informations légales + simulateurs |
| Privacy Labels guide | `legal/APP_STORE_PRIVACY_LABELS.md` | — (interne) | N/A (App Store Connect / Play Console) |

---

## 2. Intégration dans l'application Flutter

### 2.1 Nouvel écran : `LegalHubScreen`

**Route GoRouter** : `/profile/legal`

Créer un écran hub juridique accessible depuis le ProfileScreen, contenant :

```
┌─────────────────────────────────────────┐
│  ← Informations légales                 │
├─────────────────────────────────────────┤
│                                         │
│  📄 Conditions générales d'utilisation  │  → /profile/legal/terms
│     Version 1.0 — mars 2026            │
│                                         │
│  🔒 Politique de confidentialité        │  → /profile/legal/privacy
│     Version 2.1 — mars 2026            │
│                                         │
│  ℹ️  Mentions légales                   │  → /profile/legal/mentions
│                                         │
│  ⚠️  Disclaimer éducatif               │  → /profile/legal/disclaimer
│                                         │
│  🗑️  Gestion des données              │  → /profile/consent (existant)
│     Dashboard de consentement nLPD      │
│                                         │
├─────────────────────────────────────────┤
│  MINT v[version] — Swiss Financial Ed.  │
│  contact@mint-app.ch                    │
│  © 2026 MINT                            │
└─────────────────────────────────────────┘
```

### 2.2 Écrans de détail : `LegalDocScreen`

**Route** : `/profile/legal/:docType`

Un écran générique qui affiche le contenu Markdown d'un document légal :
- Utiliser `flutter_markdown` ou `markdown_widget` pour le rendu
- AppBar avec titre du document
- Bouton de partage (exporter en PDF ou copier l'URL)
- Scroll fluide avec SliverAppBar

### 2.3 Ajout au ProfileScreen

Dans [profile_screen.dart](apps/mobile/lib/screens/profile_screen.dart), ajouter une section « Informations légales » en bas, avant la zone danger :

```dart
// Section Informations légales
_buildSectionTitle(context, S.of(context)!.legalInfoTitle),  // "Informations légales"
_buildLegalTile(
  context,
  icon: Icons.description_outlined,
  title: S.of(context)!.termsOfService,        // "Conditions générales"
  onTap: () => context.push('/profile/legal/terms'),
),
_buildLegalTile(
  context,
  icon: Icons.lock_outlined,
  title: S.of(context)!.privacyPolicy,         // "Politique de confidentialité"
  onTap: () => context.push('/profile/legal/privacy'),
),
_buildLegalTile(
  context,
  icon: Icons.info_outlined,
  title: S.of(context)!.legalNotices,          // "Mentions légales"
  onTap: () => context.push('/profile/legal/mentions'),
),
_buildLegalTile(
  context,
  icon: Icons.warning_amber_outlined,
  title: S.of(context)!.educationalDisclaimer,  // "Disclaimer éducatif"
  onTap: () => context.push('/profile/legal/disclaimer'),
),
```

### 2.4 Onboarding — Acceptation CGU

Lors du premier lancement (ou après mise à jour des CGU), afficher un écran d'acceptation :

```
┌─────────────────────────────────────────┐
│  Bienvenue sur MINT 🌿                  │
│                                         │
│  Avant de commencer, quelques points    │
│  importants :                           │
│                                         │
│  MINT est un outil éducatif. Il ne      │
│  remplace pas un·e spécialiste.         │
│                                         │
│  ☐ J'accepte les Conditions générales   │
│    d'utilisation (lire →)               │
│                                         │
│  ☐ J'ai lu la Politique de             │
│    confidentialité (lire →)             │
│                                         │
│  ☐ Je comprends que MINT ne fournit     │
│    pas de conseil financier             │
│    personnalisé                         │
│                                         │
│  [Continuer]  (grisé tant que non ☑)    │
│                                         │
│  J'ai 18 ans ou plus                    │
└─────────────────────────────────────────┘
```

**Stockage du consentement** :
- `SharedPreferences` : `cgu_accepted_version` = "1.0"
- `SharedPreferences` : `cgu_accepted_date` = ISO 8601
- `SharedPreferences` : `privacy_accepted_version` = "2.1"
- Si la version des CGU change → redemander l'acceptation

### 2.5 Footer dans les simulateurs

Chaque écran de simulateur doit afficher un mini-disclaimer en footer :

```dart
Container(
  padding: const EdgeInsets.all(16),
  child: Text(
    S.of(context)!.simulatorDisclaimer,
    // "Estimation éducative basée sur des hypothèses simplifiées.
    //  Ne constitue pas un conseil financier. Consulte un·e spécialiste
    //  avant toute décision importante."
    style: GoogleFonts.inter(fontSize: 10, color: MintColors.textTertiary),
    textAlign: TextAlign.center,
  ),
),
```

### 2.6 Rapports PDF

Chaque rapport PDF exporté doit contenir en footer :
1. Le disclaimer éducatif complet
2. La date de génération
3. Le numéro de version de l'app
4. Les sources légales citées dans le rapport
5. La mention « Consulte un·e spécialiste qualifié·e avant toute décision. »

---

## 3. Intégration dans les ARB (i18n)

### Nouvelles clés à ajouter dans `app_fr.arb` (et les 5 autres langues)

```json
{
  "legalInfoTitle": "Informations légales",
  "termsOfService": "Conditions générales d'utilisation",
  "privacyPolicy": "Politique de confidentialité",
  "legalNotices": "Mentions légales",
  "educationalDisclaimer": "Disclaimer éducatif",
  "cguVersion": "Version {version} — {date}",
  "@cguVersion": {
    "placeholders": {
      "version": { "type": "String" },
      "date": { "type": "String" }
    }
  },
  "simulatorDisclaimer": "Estimation éducative basée sur des hypothèses simplifiées. Ne constitue pas un conseil financier personnalisé. Consulte un·e spécialiste avant toute décision importante.",
  "cguAcceptTitle": "Conditions d'utilisation",
  "cguAcceptCheckbox": "J'accepte les Conditions générales d'utilisation",
  "privacyAcceptCheckbox": "J'ai lu la Politique de confidentialité",
  "disclaimerAcceptCheckbox": "Je comprends que MINT ne fournit pas de conseil financier personnalisé",
  "ageConfirmation": "J'ai 18 ans ou plus",
  "continueButton": "Continuer",
  "readMore": "Lire →",
  "legalContact": "Contact : {email}",
  "@legalContact": {
    "placeholders": {
      "email": { "type": "String" }
    }
  },
  "dataManagement": "Gestion des données",
  "reportDisclaimer": "Ce rapport est généré par MINT, un outil éducatif. Il ne constitue pas un conseil financier, fiscal ou juridique au sens de la LSFin. Consulte un·e spécialiste qualifié·e avant toute décision importante.",
  "reportGeneratedDate": "Rapport généré le {date} — MINT v{version}",
  "@reportGeneratedDate": {
    "placeholders": {
      "date": { "type": "String" },
      "version": { "type": "String" }
    }
  }
}
```

---

## 4. Routes GoRouter à ajouter

```dart
// Dans app.dart — sous /profile
GoRoute(
  path: 'legal',
  builder: (context, state) => const LegalHubScreen(),
  routes: [
    GoRoute(
      path: 'terms',
      builder: (context, state) => const LegalDocScreen(docType: LegalDocType.terms),
    ),
    GoRoute(
      path: 'privacy',
      builder: (context, state) => const LegalDocScreen(docType: LegalDocType.privacy),
    ),
    GoRoute(
      path: 'mentions',
      builder: (context, state) => const LegalDocScreen(docType: LegalDocType.mentions),
    ),
    GoRoute(
      path: 'disclaimer',
      builder: (context, state) => const LegalDocScreen(docType: LegalDocType.disclaimer),
    ),
  ],
),
```

---

## 5. Site web — Pages légales

### Pages à déployer sur mint-app.ch

| Route web | Contenu source | Priorité |
|-----------|---------------|----------|
| `/privacy` | `PRIVACY.md` | **BLOQUANT** (requis par Apple + Google) |
| `/terms` | `legal/CGU.md` | **BLOQUANT** (requis par Apple + Google) |
| `/legal` | `legal/MENTIONS_LEGALES.md` | Haute (LCD art. 3) |
| `/disclaimer` | `legal/DISCLAIMER.md` | Haute |
| `/data-deletion` | Instructions suppression | **BLOQUANT** (requis par Google Play) |
| `/support` | Page contact | Haute |

### Page `/data-deletion` (Google Play obligation)

Contenu minimal requis :

```
Comment supprimer tes données MINT

1. Ouvre l'application MINT
2. Va dans Profil > Gestion des données
3. Appuie sur « Supprimer toutes mes données »
4. Confirme la suppression

La suppression est immédiate et irréversible. Toutes tes données
(profil, simulations, rapports) seront effacées de ton appareil.

Tu peux aussi nous contacter : privacy@mint-app.ch
```

---

## 6. Checklist d'implémentation

### Phase 1 — Avant soumission App Store / Play Store (BLOQUANT)

- [ ] Héberger PRIVACY.md sur `mint-app.ch/privacy`
- [ ] Héberger CGU.md sur `mint-app.ch/terms`
- [ ] Créer page `mint-app.ch/data-deletion`
- [ ] Remplir Apple Privacy Labels dans App Store Connect
- [ ] Remplir Google Data Safety dans Play Console
- [ ] Ajouter URL privacy policy dans App Store Connect
- [ ] Ajouter URL privacy policy dans Google Play Console
- [ ] Ajouter écran d'acceptation CGU au premier lancement

### Phase 2 — Intégration in-app (Haute priorité, post-soumission OK)

- [ ] Créer `LegalHubScreen` avec 4 documents
- [ ] Créer `LegalDocScreen` (rendu Markdown)
- [ ] Ajouter routes GoRouter `/profile/legal/*`
- [ ] Ajouter section « Informations légales » dans ProfileScreen
- [ ] Ajouter clés i18n dans les 6 ARB files
- [ ] Ajouter mini-disclaimer footer dans tous les simulateurs
- [ ] Vérifier footer disclaimer dans les rapports PDF
- [ ] Tests : widget tests pour LegalHubScreen + LegalDocScreen

### Phase 3 — Améliorations (Nice to have)

- [ ] Versioning automatique des CGU avec détection de changement
- [ ] Historique des acceptations de CGU dans le ConsentDashboard
- [ ] Notifications push lors de mise à jour des CGU
- [ ] Héberger mentions légales en allemand et italien (marchés CH)
- [ ] Dépôt de marque MINT auprès de l'IPI
- [ ] Souscrire RC professionnelle + cyber-risques

---

## 7. Actions juridiques hors-app (pré-lancement)

| Action | Responsable | Priorité | Statut |
|--------|------------|----------|--------|
| Créer l'entité juridique (Sàrl/SA) | Fondateur | **BLOQUANT** | À faire |
| Inscription au Registre du Commerce | Fondateur + notaire | **BLOQUANT** | À faire |
| Obtenir numéro IDE/CHE | Registre du Commerce | **BLOQUANT** | À faire |
| Compléter adresse dans MENTIONS_LEGALES.md | Fondateur | **BLOQUANT** | À faire |
| Compléter adresse dans CGU.md | Fondateur | **BLOQUANT** | À faire |
| Dépôt de marque « MINT » à l'IPI | Conseil en PI | Haute | À faire |
| Vérifier absence de conflit de marque | Conseil en PI | Haute | À faire |
| Souscrire assurance RC professionnelle | Courtier | Haute | À faire |
| Souscrire assurance cyber-risques | Courtier | Recommandée | À faire |
| Consulter avocat pour validation CGU | Avocat droit des affaires | Haute | À faire |
| Consulter PFPDT si doute sur nLPD | privacy@mint-app.ch | Si nécessaire | — |
| Configurer emails (contact@, privacy@, security@) | IT | **BLOQUANT** | À faire |

---

*MINT — « Juste quand il faut : une explication, une action, un rappel. »*

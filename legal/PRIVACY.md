# Politique de confidentialité — MINT

**Dernière mise à jour : 1er avril 2026**

MINT-IA SA, Sion, Valais, Suisse (ci-après « MINT ») s'engage à protéger tes données personnelles conformément à la nouvelle Loi fédérale sur la protection des données (nLPD, RS 235.1) et à l'Ordonnance sur la protection des données (OPDo).

## 1. Responsable du traitement

MINT-IA SA
Sion, Valais, Suisse
Contact : privacy@mint.ch

## 2. Données collectées

### 2.1 Données de profil financier
- Année de naissance, canton, salaire brut, situation familiale
- Avoir LPP, épargne 3a, patrimoine
- Objectifs financiers, statut d'emploi

### 2.2 Données techniques
- Identifiant de session (anonyme), version de l'app
- Événements d'interaction (opt-in uniquement, après consentement)

### 2.3 Données NON collectées
- Noms de famille, numéros AVS, IBAN (jamais transmis au serveur)
- Données bancaires réelles (mode lecture seule)

## 3. Finalités du traitement

Les données sont traitées exclusivement pour :
- Calcul de projections de prévoyance (éducatif, non-conseil)
- Personnalisation du coach AI
- Amélioration de l'expérience utilisateur (analytics opt-in)

Base légale : consentement (nLPD art. 6 al. 6 let. a).

## 4. Sous-traitants et transferts

### 4.1 Sous-traitants (nLPD art. 9)

| Sous-traitant | Service | Localisation | Données concernées |
|---------------|---------|-------------|-------------------|
| **Railway Inc.** | Hébergement backend (PostgreSQL) | USA (Oregon) | Profil financier chiffré |
| **Anthropic PBC** | Coach AI (Claude API) | USA | Contexte agrégé (pas de PII) |
| **Sentry Inc.** | Monitoring d'erreurs | USA (Virginia) | Stack traces (pas de PII, `send_default_pii=False`) |
| **Apple Inc.** | Distribution iOS (TestFlight/App Store) | USA | Métadonnées app uniquement |
| **Google LLC** | Distribution Android (Play Store) | USA | Métadonnées app uniquement |

**Google Fonts** (Google LLC, États-Unis)
- Données : adresse IP (lors du téléchargement initial des polices)
- Durée : ponctuel (polices mises en cache localement)
- Base légale : intérêt légitime (affichage typographique)

### 4.2 Transfert international (nLPD art. 16-17)

Des données sont transférées aux USA via les sous-traitants ci-dessus.
Garanties : contrats standard de protection des données (SCC) conformes aux exigences du PFPDT.

**Important** : Le coach AI (Anthropic Claude) reçoit uniquement des données agrégées (scores, ratios), JAMAIS de données personnelles identifiantes (salaire exact, IBAN, nom, numéro AVS). Voir la documentation technique `CoachContext`.

En Phase 2, nous prévoyons un hébergement en Suisse pour les données utilisateurs.

## 5. Durée de conservation

- Données de profil : jusqu'à suppression du compte
- Analytics : 90 jours maximum
- Snapshots financiers : jusqu'à suppression du compte
- Coach memory : jusqu'à suppression du compte ou révocation du consentement

## 6. Droits de la personne concernée

Tu as le droit de :
- **Accéder** à tes données (nLPD art. 25) — via Profil > Consentements > Exporter
- **Rectifier** tes données — via l'édition de profil
- **Supprimer** tes données (nLPD art. 32) — via Profil > Supprimer mon compte
- **Révoquer** ton consentement à tout moment — via Profil > Consentements

Délai de réponse : 30 jours.

## 7. Sécurité

- Chiffrement TLS en transit (HSTS activé)
- Chiffrement au repos (PostgreSQL chiffré, FlutterSecureStorage)
- Authentification JWT avec rotation de tokens
- Rate limiting sur tous les endpoints API
- Aucune donnée PII dans les logs (nLPD art. 8)

## 8. Contact

Pour toute question relative à la protection des données :
privacy@mint.ch

Pour exercer tes droits : Profil > Consentements > Exporter / Supprimer

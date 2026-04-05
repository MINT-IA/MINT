# GLOSSAIRE PRODUIT MINT

> **⚠️ LEGACY NOTE (2026-04-05):** Uses "chiffre choc" (legacy term → "premier éclairage", see `docs/MINT_IDENTITY.md`).

> Dernière mise à jour : 2026-03-27
> Statut : **AUTORITATIF** — Ce document fait foi pour tous les nommages produit.
> Toute nouvelle feature, route, ou libellé doit s'aligner sur ce glossaire.

---

## 1. Surfaces utilisateur (ce que l'utilisateur voit)

| Label utilisateur (FR) | Route | Classe Dart | Rôle |
|---|---|---|---|
| **Aujourd'hui** | `/home?tab=0` | `PulseScreen` | Cockpit quotidien : 1 cap, 1 hero number, 2 signaux |
| **Mint** | `/home?tab=1` | `MintCoachTab` → `CoachChatScreen` | Coach conversationnel : chat, outils, enrichissement |
| **Explorer** | `/home?tab=2` | `ExploreTab` | 7 hubs thématiques : Retraite, Famille, Travail, Logement, Fiscalité, Patrimoine, Santé |
| **Dossier** | `/home?tab=3` | `DossierTab` | Miroir de l'état utilisateur : identité, données, documents, couple, plan, préférences |

### Termes obsolètes à ne plus utiliser

| Terme obsolète | Remplacé par | Contexte |
|---|---|---|
| `Pulse` | Aujourd'hui | Ancien nom interne de l'onglet 0 |
| `MAINTENANT` / `NOW` | Aujourd'hui | Clés i18n mortes (`tabNow`) |
| `Moi` | Dossier (nav) / titre interne ProfileScreen | `tabMoi` est utilisé uniquement comme titre de ProfileScreen |
| `Ask Mint` | Mint (tab) | Ancien nom du chat |
| `Advisor` | Onboarding | Ancien namespace (`/advisor/*` → `/onboarding/*`) |

---

## 2. Concepts financiers (ce que MINT calcule)

| Concept | Définition MINT | Ce que ce n'est PAS |
|---|---|---|
| **Budget A** | Liberté mensuelle aujourd'hui (revenu - charges = libre) | Un budget classique catégorisé |
| **Budget B** | Liberté mensuelle à la retraite (AVS + LPP + 3a - charges) | Une projection unique figée |
| **Gap** | L'écart entre Budget A et Budget B (CHF/mois) | Un score ou une note |
| **Cap** | La meilleure action unique à proposer maintenant | Un conseil financier |
| **Premier éclairage** | Premier insight personnalisé révélé à l'onboarding (nombre, angle mort, implication, ou question à poser). Remplace le legacy "chiffre choc". | Une projection complète |
| **Taux de remplacement** | Revenu retraite / revenu actuel (%) | Un score de santé |
| **Confiance** | Fiabilité de la projection (0-100%, 4 axes) | Un score d'engagement |
| **FRI** | Financial Resilience Index (liquidité + fiscal + retraite + risque) | Un score de rendement |

---

## 3. Modèles de données (ce que le code utilise)

| Modèle | Fichier | Rôle | Autorité |
|---|---|---|---|
| **CoachProfile** | `models/coach_profile.dart` | Profil complet local (wizard + OCR + enrichissement) | **SOURCE DE VÉRITÉ locale** pour l'identité, le revenu, la prévoyance, le patrimoine |
| **MintUserState** | `models/mint_user_state.dart` | État unifié calculé (profil + services) | **SOURCE DE VÉRITÉ runtime** pour toutes les surfaces (Pulse, Coach, Explorer, Dossier) |
| **Profile** | `models/profile.dart` | Modèle API léger pour sync backend | Sync descendante uniquement (CoachProfile → Profile → API) |
| **UserProfile** | `models/financial_report.dart` | Modèle intermédiaire pour rapports financiers | Dette architecturale — devrait consommer CoachProfile directement |
| **MinimalProfileResult** | `models/minimal_profile_models.dart` | Snapshot onboarding éphémère (3 inputs → projection) | Transitoire — jamais persisté dans CoachProfile |

### Règle de gouvernance

**CoachProfile est le modèle maître.** Tout nouveau champ doit être ajouté à CoachProfile en premier, puis propagé aux consommateurs. Ne jamais ajouter un champ à Profile ou UserProfile sans l'avoir dans CoachProfile.

---

## 4. Systèmes de score (qui mesure quoi)

| Score | Autorité | Axes | Range | Gouverne |
|---|---|---|---|---|
| **EnhancedConfidence** (backend) | **SOT** | completeness × accuracy × freshness × understanding | 0-100 | Feature gates, enrichment prompts |
| **EnhancedConfidence** (mobile) | Fallback offline | completeness × accuracy × freshness | 0-100 | UI confidence bars hors ligne |
| **ConfidenceScorer** (financial_core) | Projections | 12 composants pondérés (salaire, LPP, AVS, 3a...) | 0-100 | Seuil projection (≥ 40), enrichment ranking |
| **FRI** | Résilience structurelle | Liquidité + Fiscal + Retraite + Risque | 0-100 | Shadow mode (calibration), futur dashboard |
| **FHS** | Engagement quotidien | FRI + tendance temporelle | 0-100 | Pulse, streaks, weekly recap |
| **VisibilityScore** | Clarté perçue | 4 axes contextuels (âge + archetype) | 0-100 | Pulse visibility card, couple comparison |
| **CircleScoring** | Éducation onboarding | 4 cercles (Protection, Prévoyance, Croissance, Optimisation) | 0-100 | Wizard score reveal uniquement |

### Règle de gouvernance

**Le backend EnhancedConfidence est la source de vérité pour la confiance.** Le mobile la mirror pour l'offline. Le ConfidenceScorer (financial_core) est spécifique aux projections et ne doit pas être confondu avec la confiance globale.

---

## 5. Nommage des routes (politique)

| Convention | Exemples | Usage |
|---|---|---|
| **Français kebab-case** | `/retraite`, `/hypotheque`, `/pilier-3a` | **Standard pour toute nouvelle route** |
| **Anglais kebab-case** | `/auth/login`, `/mortgage/amortization` | Héritage accepté, ne pas créer de nouvelles |
| **Mixte** | `/3a-deep/comparator`, `/life-event/donation` | Héritage accepté, ne pas créer de nouvelles |

Voir `ROUTE_POLICY.md` pour les règles détaillées.

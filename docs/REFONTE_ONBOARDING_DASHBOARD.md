# REFONTE ONBOARDING + DASHBOARD — Plan Complet

> **Date**: 2026-02-26
> **Auteurs**: Dream Team (UX, Actuaire, CFA, UI, Compliance)
> **Focus**: Retraite (extensible aux autres scénarios)
> **Branche**: `claude/retirement-planning-features-hRXie`

---

## DIAGNOSTIC — Ce qui ne va pas aujourd'hui

### Audit UX (screenshots Julien, 26.02.2026)

| # | Bug / Friction | Sévérité | Cause racine |
|---|----------------|----------|--------------|
| 1 | "Bonjour utilisateur" — pas de prénom | CRIT | `firstName` vide → fallback cassé |
| 2 | "Taux de remplacement: 7%" — absurde | CRIT | ForecasterService calcule avec LPP=0, 3a=0 |
| 3 | "Coach Vivant — S30 a S46" + labels sprint | CRIT | Texte dev interne visible en prod |
| 4 | "Précision: 55%" avec 14 données | HIGH | Confiance affichée sans contexte |
| 5 | 3 étapes pour ~30 champs | HIGH | Mini-onboarding trop compressé |
| 6 | Salaire net demandé, brut utilisé | HIGH | Conversion ÷0.87 silencieuse |
| 7 | CHF 64'690 sans contexte | MED | Label manquant sur le chiffre |
| 8 | SLM invisible malgré l'update | CRIT | Aucune navigation vers `/profile/slm` |
| 9 | Dashboard montre des projections avec données vides | CRIT | Pas de guard rails |
| 10 | Le savais-tu? cards sans lien avec le profil | MED | Contenu éducatif statique |

### Analyse technique

**Mini-onboarding collecte** : âge, salaire brut, canton (3 champs)
**ForecasterService a besoin de** : LPP avoir, taux conversion, 3a soldes, AVS années, état civil, statut emploi, patrimoine...

**Gap** : Le dashboard affiche des projections basées sur ~80% d'estimations → résultats absurdes.

---

## VISION — Dream Team Perspectives

### Actuaire (Prévoyance Suisse)
> "Un taux de remplacement de 7% est non seulement faux mais dangereux — il crée de la panique.
> Il faut un **seuil de confiance minimum** avant d'afficher une projection chiffrée.
> En dessous de 40% de confiance → ne pas afficher de chiffre, montrer une fourchette qualitative."

**Règle** : Jamais de projection chiffrée si `confidenceScore < 40%`. Afficher plutôt :
- Fourchette qualitative ("entre 50% et 80% de ton revenu actuel")
- Les 3 données manquantes les plus impactantes (EVI-ranked)

### CFA / Financial Planner
> "L'onboarding doit capturer en priorité les données à **haute valeur informationnelle** :
> 1. LPP avoir actuel (impact: ±30% sur la projection)
> 2. Taux de conversion (impact: ±15%)
> 3. Années AVS cotisées ou date d'arrivée en Suisse (impact: ±20%)
> 4. Soldes 3a (impact: ±10%)
> 5. État civil (impact: couples = AVS plafonnée à 150%)"

**Règle** : L'onboarding doit capturer au minimum le "Core 5" avant d'afficher une trajectoire.

### UX Designer
> "3 écrans avec 10 champs chacun → cognitive overload.
> La bonne approche : **progressive disclosure** avec reward immédiat.
> Chaque donnée ajoutée = animation de l'impact sur ta projection.
> Le chiffre choc actuel est bon mais arrive trop tard."

**Principes** :
1. **1 question = 1 écran** (mobile-first, pas de scroll dans les forms)
2. **Feedback immédiat** : chaque réponse met à jour un indicateur visuel
3. **Gamification** : barre de précision qui monte + confetti à 70%
4. **Exit possible** : l'utilisateur peut quitter à tout moment sans perte
5. **Smart defaults** : pré-remplir quand possible (âge → LPP estimé)

### UI Designer
> "Le dashboard est un monstre de 5'300 lignes. Il faut le découper en composants.
> Le 'Coach Vivant Hub' avec les sprints est un artefact de dev, pas un produit.
> Le parcours doit être : onboarding fluide → dashboard clair → actions ciblées."

**Principes** :
1. Cards hiérarchisées : **1 métrique hero** en haut, détails en dessous
2. Empty states élégants (pas de "?" ou "0%")
3. Progressive reveal : le dashboard s'enrichit au fur et à mesure du profil
4. Micro-animations pour les transitions de données

### Compliance (LSFin / FINMA)
> "Afficher 'Taux de remplacement: 7%' sans disclaimer visible est un risque légal.
> Chaque projection doit montrer sa base de données et son incertitude."

**Règle** : Toute projection chiffrée doit afficher :
- Le nombre de données réelles vs estimées
- Le disclaimer "outil éducatif" visible (pas caché en bas)
- Les sources légales (LAVS, LPP, LIFD)

---

## ARCHITECTURE CIBLE

### Phase 0 : Quick Fixes (immédiat, cette session)

**Objectif** : Corriger les bugs critiques visibles en prod.

| Fix | Fichier | Action |
|-----|---------|--------|
| firstName fallback | `coach_dashboard_screen.dart:2636` | Si vide → "Bonjour" sans nom |
| Sprint labels | `coach_dashboard_screen.dart:975-1035` | Remplacer par section "Explore" avec titres user-facing |
| Guard rail projections | `coach_dashboard_screen.dart` | Si `confidenceScore < 40%` → masquer chiffres, afficher fourchette |
| SLM navigation | `profile_screen.dart:880-892` | Ajouter section SLM sous BYOK |

### Phase 1 : Onboarding "Smart Flow" (nouveau)

**Principe** : Remplacer le mini-onboarding 3-steps par un flow conversationnel qui collecte le **Core 5** en 90 secondes.

#### Flow cible (7 écrans, ~90 secondes)

```
Écran 1: BIENVENUE
  "Découvre ta situation retraite en 90 secondes"
  [Bouton: "C'est parti"]

Écran 2: TOI
  - Prénom (text field, placeholder "Comment tu t'appelles ?")
  - Année de naissance (date picker, smart default)
  - Canton (dropdown avec les 26 cantons, détection GPS optionnelle)
  → Feedback: avatar animé qui prend forme

Écran 3: TON TRAVAIL
  - Statut emploi (chips: Salarié·e / Indépendant·e / Sans emploi / Étudiant·e)
  - Revenu mensuel NET (slider + input, adapté au statut)
  - 13ème salaire ? (toggle, affiché si salarié·e)
  → Feedback: "Ton salaire brut estimé : CHF X'XXX/mois"

Écran 4: TA PRÉVOYANCE (question clé #1)
  - "As-tu un 2ème pilier (LPP) ?"
    → Si oui: "Connais-tu ton avoir actuel ?"
      → Input CHF ou "Je ne sais pas" (→ estimation)
    → Si non (indépendant): skip
  - Taux de conversion (si connu) ou "standard (6.8%)"
  → Feedback: barre "Ton 2ème pilier" se remplit

Écran 5: TON 3ème PILIER
  - "As-tu un 3ème pilier (3a) ?"
    → Si oui: solde approximatif (input)
    → Cotisation annuelle (slider 0 → 7'258 CHF)
  → Feedback: barre "Ton 3ème pilier" se remplit

Écran 6: TA SITUATION
  - État civil (chips: Célibataire / En couple / Marié·e / Divorcé·e)
  - Si en couple/marié: "Ton·ta partenaire travaille ?" (toggle)
    → Si oui: revenu estimé du partenaire (slider)
  - Nationalité / date d'arrivée en Suisse (si pas suisse)
  → Feedback: score de confiance qui monte + "Précision: XX%"

Écran 7: TON RÉSULTAT (Chiffre Choc 2.0)
  - Animation: compteur qui monte vers ton taux de remplacement estimé
  - Bande d'incertitude visible (min-max)
  - "Ton revenu à la retraite : entre CHF X et CHF Y / mois"
  - Score de confiance (ex: "Précision: 72%")
  - 3 actions ranked par impact:
    1. "Ajoute ton certificat LPP" (+15% précision)
    2. "Commande ton extrait AVS" (+10% précision)
    3. "Voir ma trajectoire détaillée" → Dashboard
  - [Bouton principal: "Voir mon dashboard"]
```

#### Règles techniques du flow

1. **Sauvegarde à chaque écran** : `SharedPreferences` + `CoachProfileProvider`
2. **Reprise** : si l'utilisateur quitte et revient → reprend au dernier écran complété
3. **Calcul temps-réel** : `MinimalProfileService.compute()` après chaque écran
4. **Pas de scroll dans les forms** : 1 question = 1 écran, tout visible
5. **Smart defaults** :
   - LPP estimé = bonifications depuis 25 ans × salaire (déjà dans `_estimateLppAvoir()`)
   - AVS = années depuis 20 ans ou depuis arrivée en Suisse
   - LAMal = estimation cantonale
6. **Conversions transparentes** : Si net → brut, montrer "≈ CHF X brut/mois (charges sociales ~13%)"

### Phase 2 : Dashboard "Retirement Focus" (refonte)

#### Nouveau layout (3 états)

##### État A : Profil riche (confidence ≥ 70%)
```
┌─────────────────────────────────┐
│ SliverAppBar                    │
│ "Bonjour Julien"                │
│ Précision: 82% ████████░░      │
├─────────────────────────────────┤
│ ┌─ HERO CARD ─────────────────┐ │
│ │ Ton revenu retraite estimé  │ │
│ │     CHF 5'420 / mois        │ │
│ │ (72% de ton revenu actuel)  │ │
│ │ ░░░░░░░░░█████ fourchette   │ │
│ │ CHF 4'200 ←——→ CHF 6'800   │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─ TRAJECTOIRE ───────────────┐ │
│ │ [Chart 3 scénarios]         │ │
│ │ Prudent / Base / Optimiste  │ │
│ │ Interactive: tap pour détail │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─ DÉCOMPOSITION ─────────────┐ │
│ │ AVS:    CHF 2'100/mois  ██  │ │
│ │ LPP:    CHF 2'500/mois  ███ │ │
│ │ 3a:     CHF   520/mois  █   │ │
│ │ Libre:  CHF   300/mois  ░   │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─ IMPACT MINT ───────────────┐ │
│ │ Sans optimisation │ Avec    │ │
│ │ CHF 4'800         │ 5'420   │ │
│ │ (+CHF 620/mois grâce à tes  │ │
│ │  actions sur le 3a et LPP)  │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─ ACTIONS RECOMMANDÉES ──────┐ │
│ │ 1. Rachat LPP possible      │ │
│ │ 2. Optimise ton 3a          │ │
│ │ 3. Vérifie ta franchise     │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─ SCORE FINANCIER ───────────┐ │
│ │ [Gauge 0-100] 68/100        │ │
│ │ Budget ██████░░  Prévoyance  │ │
│ │ Patrimoine ████░░            │ │
│ └─────────────────────────────┘ │
│                                 │
│ [Disclaimer LSFin]              │
└─────────────────────────────────┘
```

##### État B : Profil partiel (confidence 40-69%)
```
┌─────────────────────────────────┐
│ "Bonjour Julien"                │
│ Précision: 52% █████░░░░░      │
├─────────────────────────────────┤
│ ┌─ HERO CARD (fourchette) ────┐ │
│ │ Ton revenu retraite estimé  │ │
│ │ entre CHF 3'500 et 6'200    │ │
│ │ /mois                       │ │
│ │ ⚠ Données incomplètes —     │ │
│ │   ajoute ton LPP pour       │ │
│ │   une estimation précise    │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─ CE QU'ON SAIT ─────────────┐ │
│ │ ✓ AVS estimée: ~2'100/mois  │ │
│ │ ✓ Canton: VD (fiscal)       │ │
│ │ ? LPP: donnée manquante     │ │
│ │ ? 3a: donnée manquante      │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─ ENRICHIR (+20% précision) ─┐ │
│ │ [Photo] Ajoute ton certif.  │ │
│ │         LPP (scan ou saisie)│ │
│ │ → Impact: ±CHF 1'200/mois   │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─ CHIFFRE CHOC ──────────────┐ │
│ │ "Sais-tu que le 3a te fait  │ │
│ │  économiser ~CHF 2'100/an   │ │
│ │  d'impôts ?"                │ │
│ └─────────────────────────────┘ │
│                                 │
│ [Trajectoire en teaser flou]    │
│                                 │
│ [Disclaimer LSFin]              │
└─────────────────────────────────┘
```

##### État C : Données insuffisantes (confidence < 40%)
```
┌─────────────────────────────────┐
│ "Bonjour"                       │
├─────────────────────────────────┤
│ ┌─ HERO CARD (pas de chiffre) ┐ │
│ │ On n'a pas encore assez      │ │
│ │ d'infos pour estimer ta      │ │
│ │ retraite.                    │ │
│ │                              │ │
│ │ En moyenne en Suisse, le     │ │
│ │ taux de remplacement est     │ │
│ │ de 60-70% du dernier salaire │ │
│ │                              │ │
│ │ [Bouton: Compléter mon       │ │
│ │  profil — 2 min]             │ │
│ └──────────────────────────────┘ │
│                                  │
│ ┌─ LE SAVAIS-TU ? ────────────┐ │
│ │ 3 cards éducatives           │ │
│ │ contextualisées par canton   │ │
│ └──────────────────────────────┘ │
│                                  │
│ [PAS de trajectoire]             │
│ [PAS de taux de remplacement]    │
│ [PAS de chiffres spécifiques]    │
│                                  │
│ [Disclaimer LSFin]               │
└──────────────────────────────────┘
```

#### Règles du dashboard

1. **Jamais de projection chiffrée si confidence < 40%** → message éducatif générique
2. **Fourchette obligatoire si confidence 40-69%** → pas de chiffre unique
3. **Chiffre unique + fourchette si confidence ≥ 70%** → projection fiable
4. **Taux de remplacement** : ne s'affiche que si LPP ET salaire sont connus (pas estimés)
5. **Décomposition par pilier** : toujours montrer d'où vient le revenu
6. **Impact MINT** : "Sans tes actions" vs "Avec" — mais seulement si delta > 0
7. **Actions ranked** : par Expected Value of Information (EVI) du confidence scorer

### Phase 3 : Coach Vivant Hub → "Explore" (refonte)

Remplacer le hub dev avec sprint labels par une section clean :

```
┌─ EXPLORER ────────────────────────┐
│                                    │
│ [icon] Mon profil retraite         │
│        Compléter / ajuster         │
│                                    │
│ [icon] Simulateurs                 │
│        3a, LPP, rente vs capital   │
│                                    │
│ [icon] Coach IA                    │
│        Pose une question           │
│                                    │
│ [icon] Scan de documents           │
│        Certificat LPP, fiscalité   │
│                                    │
└────────────────────────────────────┘
```

### Phase 4 : SLM Integration

**Root cause identifié** : Le SLM engine est complet (`slm_engine.dart`, `slm_download_service.dart`, `slm_settings_screen.dart`) et la route `/profile/slm` existe, mais **aucun lien de navigation** n'existe dans l'app.

**Fix** :
1. Ajouter section SLM dans `profile_screen.dart` (sous BYOK)
2. Ajouter indicateur SLM dans le dashboard (badge "IA on-device" si dispo)
3. Auto-detection : si `SlmEngine.isAvailable` → proposer en premier choix coach

---

## PLAN D'IMPLÉMENTATION

### Immédiat (Phase 0) — Cette session

| # | Tâche | Fichier | LOC estimé |
|---|-------|---------|------------|
| 0.1 | Fix firstName fallback | `coach_dashboard_screen.dart` | ~5 |
| 0.2 | Remplacer section Hub (sprint labels → Explore) | `coach_dashboard_screen.dart` | ~80 |
| 0.3 | Guard rail: masquer projections si confidence < 40% | `coach_dashboard_screen.dart` | ~30 |
| 0.4 | Ajouter nav SLM dans profile | `profile_screen.dart` | ~25 |

### Sprint S31 (Phase 1 — Onboarding Smart Flow)

| # | Tâche | Fichier | LOC estimé |
|---|-------|---------|------------|
| 1.1 | Créer `smart_onboarding_screen.dart` — flow 7 écrans | Nouveau | ~800 |
| 1.2 | Real-time projection widget (barre de confiance animée) | Nouveau widget | ~200 |
| 1.3 | Mise à jour router (nouveau path `/onboarding/smart`) | `app.dart` | ~10 |
| 1.4 | Migration : ancien onboarding → nouveau flow | `app.dart` | ~20 |
| 1.5 | Smart defaults service (LPP/AVS auto-estimation) | Existant dans `MinimalProfileService` | ~50 |

### Sprint S32 (Phase 2 — Dashboard Refonte)

| # | Tâche | Fichier | LOC estimé |
|---|-------|---------|------------|
| 2.1 | Extraire Hero Card widget | Nouveau widget | ~200 |
| 2.2 | Extraire Décomposition widget | Nouveau widget | ~150 |
| 2.3 | Extraire Impact MINT widget | Nouveau widget | ~150 |
| 2.4 | Refactorer dashboard 3 états (A/B/C) | `coach_dashboard_screen.dart` | Refactor majeur |
| 2.5 | Guard rails confidence-driven | `coach_dashboard_screen.dart` | ~100 |

### Sprint S33 (Phase 3+4 — Explore + SLM)

| # | Tâche | Fichier | LOC estimé |
|---|-------|---------|------------|
| 3.1 | Remplacer Hub par Explore card | `coach_dashboard_screen.dart` | ~100 |
| 3.2 | SLM settings navigation | `profile_screen.dart` | ~30 |
| 3.3 | SLM coach badge dans dashboard | `coach_dashboard_screen.dart` | ~40 |
| 3.4 | Tests onboarding + dashboard | Tests | ~200 |

---

## MÉTRIQUES DE SUCCÈS

| Métrique | Avant | Cible |
|----------|-------|-------|
| Champs collectés au onboarding | 3 | 8-12 (Core 5 + contexte) |
| Confidence score moyen post-onboarding | ~35% | ≥ 55% |
| Projections avec confidence < 40% affichées | 100% | 0% |
| Temps onboarding | ~45 sec | ~90 sec |
| Sprint labels visibles en prod | 6 | 0 |
| firstName fallback "utilisateur" | Oui | Non |
| SLM accessible dans l'UI | Non | Oui |

---

## EXTENSIBILITÉ (autres scénarios futurs)

Le nouveau flow est conçu pour être **extensible** :

- **Écran 3 (Travail)** : peut accueillir "changement d'emploi", "chômage", "indépendant"
- **Écran 6 (Situation)** : peut accueillir "mariage", "divorce", "naissance", "déménagement"
- **Dashboard Hero Card** : peut switcher entre "retraite" et "immobilier" ou "dette" selon le `goalA`
- **Actions recommandées** : dynamiques selon le life event détecté
- **L'architecture en 3 états** (A/B/C) s'applique à tous les scénarios

Le système de confiance est **archetype-aware** (suisse natif, expat EU, frontalier, etc.) et ajuste automatiquement les questions et estimations.

---

*Document généré par la Dream Team MINT — UX × Actuaire × CFA × UI × Compliance*

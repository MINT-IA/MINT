> **SUPERSEDED** (2026-03-27) — Ce document décrit l'ancien modèle 3-tab coach-centric.
> L'app utilise maintenant un shell 4-tab (Aujourd'hui | Mint | Explorer | Dossier).
> Voir : `docs/NAVIGATION_GRAAL_V10.md` + `docs/MINT_UX_GRAAL_MASTERPLAN.md`

# UX V2 — Coach Conversationnel : Spec Post-Audit

> **Date** : 10 mars 2026 (S48)
> **Statut** : Spec validée post challenge-panel
> **Prédécesseur** : `UX_REDESIGN_COACH.md` (Proposition C originale)
> **Décision** : Hybride data-first + chat complémentaire, approche incrémentale 3 phases

---

## 1. CONTEXTE & DÉCISION

### Proposition C originale (rejetée en l'état)
- Chat-first avec 20 écrans + Response Cards
- MintScore /100
- Big bang 6 sprints
- Webapp companion

### Challenge Panel (5 experts)
Audit complet de la Proposition C par 5 experts (UX, Compliance, Frontend, Data, Produit).
6 risques identifiés, 3 sévérité HAUTE.

### Décision : Hybride révisé
**Data-first** : Pulse = dashboard scannable (Tab 1), Chat = complément (Tab 2).
**Incrémental** : 3 phases, chaque phase livre une app fonctionnelle.
**Mobile-only** : webapp reportée post-V1.

---

## 2. CHANGEMENTS CLÉS POST-AUDIT

| # | Risque identifié | Décision |
|---|------------------|----------|
| 1 | "MintScore /100" = rating financier déguisé (FINMA) | Renommé **"Visibilité financière"** — mesure ce que l'utilisateur SAIT, pas ce qu'il A |
| 2 | Disclaimers qui scrollent dans le chat | **Micro-disclaimer inline** dans chaque Response Card (obligatoire) |
| 3 | CTA prescriptifs ("Rachète 15k") | Reformulé en invitations : **"Simuler / Explorer"** (jamais impératif) |
| 4 | Score uniforme 25/25/25/25 inadapté | **Phase 0** : 25/25/25/25 — **Phase 1** : pondération contextuelle (âge/archetype) |
| 5 | Freshness decay punit l'utilisateur | **Score gelé** au dernier check-in + **nudge** pour mise à jour (pas de baisse visible) |
| 6 | Score couple masque le conjoint faible | **Double affichage** : min(A,B) en alerte + moyenne pondérée en score global |
| 7 | Big bang 6 sprints = risque | **3 phases incrémentales**, chaque phase = app fonctionnelle |
| 8 | Webapp = 2e produit à maintenir | **Reportée post-V1**, mobile-only |
| 9 | Problème = langage, pas architecture | **Simplification langage intégrée** dans Phase 0 (pas un sprint séparé) |

---

## 3. SCORE "VISIBILITÉ FINANCIÈRE"

### Définition
Le score mesure **le degré de connaissance que l'utilisateur a de sa propre situation financière**.
Ce n'est PAS un jugement sur la qualité de sa situation. C'est une mesure de **clarté**.

- 72% = "Tu as une vision claire de 72% de ta situation"
- 100% = "Tu as une vision complète" (ne signifie PAS "ta situation est bonne")

### Nom & terminologie

| Interdit | Retenu |
|----------|--------|
| MintScore | **Ton profil MINT** / **Visibilité financière** |
| Santé financière | Visibilité financière |
| Score /100 | **72% de visibilité** |
| "Ton score baisse" | "Tes données datent de X mois, mets-les à jour" |

### 4 axes (chacun /25 en Phase 0)

| Axe | Ce qu'il mesure | Données nécessaires |
|-----|-----------------|---------------------|
| **Liquidité** (L) | Budget, épargne, dettes, coussin sécurité | Revenu, charges, dettes, épargne liquide |
| **Fiscalité** (F) | Situation fiscale, optimisations connues | Canton, état civil, 3a, rachats LPP |
| **Retraite** (R) | Prévoyance 1er + 2e + 3e pilier | Avoir LPP, 3a, AVS, âge retraite |
| **Sécurité** (S) | Assurances, protection famille, succession | LAMal, APG, testament, mandat pour cause d'inaptitude |

### Phase 0 : Pondération uniforme
```
Score = L/25 + F/25 + R/25 + S/25 = X/100 → affiché en %
```

### Phase 1 : Pondération contextuelle (avec feedback utilisateur)
```
Score = w₁×L + w₂×F + w₃×R + w₄×S (Σw = 100)

Profils indicatifs :
  Défaut :             25 / 25 / 25 / 25
  > 55 ans :           20 / 20 / 35 / 25  (retraite pèse plus)
  Indépendant :        30 / 25 / 20 / 25  (liquidité pèse plus)
  Endetté :            35 / 20 / 20 / 25  (liquidité critique)
```

Les poids exacts seront calibrés avec les données d'usage réelles de Phase 0.

### Freshness : pas de punition

```
Comportement :
1. L'utilisateur met à jour ses données LPP → score recalculé → affiché
2. 8 mois passent sans mise à jour → score RESTE à 72%
3. Un nudge apparaît : "Tes données LPP datent de 8 mois. Mets-les à jour pour plus de précision."
4. L'utilisateur met à jour → score recalculé (peut monter OU baisser selon nouvelles données)

Interne : le confidence score (ConfidenceScorer) applique le decay pour le tri des actions.
Visible : le score affiché est GELÉ au dernier check-in.
```

### Score couple

```
Affichage :
┌──────────────────────────────────────┐
│  Votre visibilité couple    67%      │
│  ████████████████░░░░░░░░           │
│                                      │
│  ⚠️ Point d'attention : Lauren 45%   │
│  "Le profil de Lauren manque de      │
│   données retraite et fiscalité"     │
│  [Compléter le profil de Lauren →]   │
│                                      │
│  Julien  72%  ████████████████░░░░  │
│  Lauren  45%  ███████████░░░░░░░░░  │
└──────────────────────────────────────┘

Calcul :
  Score couple = moyenne pondérée par revenu
  = (scoreJ × salaireJ + scoreL × salaireL) / (salaireJ + salaireL)

  Alerte "point faible" = min(scoreJ, scoreL)
  → Affichée si écart > 15 points entre les deux
```

---

## 4. RESPONSE CARDS — Modèle de compliance

Chaque Response Card (dans Pulse ET dans le chat) DOIT respecter ce template :

```
┌─────────────────────────────────────┐
│  [Titre de la card]                 │
│                                     │
│  [Chiffre-choc / visualisation]     │
│                                     │
│  [Explication 2 lignes max]         │
│                                     │
│  [CTA éducatif]        [💬 ? →]    │
│                                     │
│  ℹ️ Estimation éducative · [Réf]    │
└─────────────────────────────────────┘
```

### Règles obligatoires

1. **Micro-disclaimer inline** : toujours visible, jamais scrollé hors écran
2. **Référence légale** : LAVS art. X, LPP art. Y, LIFD art. Z
3. **CTA éducatif** : "Simuler", "Explorer", "Découvrir l'impact de..."
4. **Jamais prescriptif** : pas de "Fais ceci", "Rachète", "Verse"

### CTA — Reformulation obligatoire

| ❌ Prescriptif (interdit) | ✅ Éducatif (retenu) |
|---------------------------|----------------------|
| "Rachète 15k en LPP" | "Simuler un rachat de 15k" |
| "Verse ton 3a maintenant" | "Découvrir l'impact d'un versement 3a" |
| "Améliorer ton score" | "Explorer des pistes" |
| "Action : refinancer" | "Simuler un refinancement" |
| "Tu dois consulter" | "Un·e spécialiste pourrait t'aider" |

---

## 5. ARCHITECTURE 3 TABS (cible finale Phase 2)

```
┌─────────────────────────────────────┐
│  [Pulse]    [Mint]    [Moi]         │
│                                     │
│  Tab 1 : Dashboard scannable        │
│  Tab 2 : Coach conversationnel      │
│  Tab 3 : Profil + couple + settings │
└─────────────────────────────────────┘
```

### Tab 1 — Pulse (data-first)
L'utilisateur voit sa situation **sans rien taper** :

```
┌─────────────────────────────────────┐
│  Bonjour Julien 👋                  │
│                                     │
│  Visibilité financière    72%       │
│  ████████████████░░░░░░░░          │
│                                     │
│  💡 "Ton taux de remplacement       │
│   retraite est de 65%. La plupart   │
│   des ménages visent 70-80%."       │
│                                     │
│  ── Tes priorités ─────────────     │
│  [Card Retraite]                    │
│  [Card Fiscalité]                   │
│  [Card 3a]                          │
│                                     │
│  ── Comprendre ────────────────     │
│  [Rente vs Capital]                 │
│  [Simuler un rachat LPP]           │
│  [Optimisation fiscale 3a]          │
│                                     │
│  ℹ️ Outil éducatif. Ne constitue    │
│  pas un conseil. LSFin art. 3       │
└─────────────────────────────────────┘
```

### Tab 2 — Mint (coach conversationnel)
Chat avec SLM/BYOK, Response Cards inline, suggested prompts contextuels.
**Complémentaire** au dashboard, ne le remplace pas.

### Tab 3 — Moi (profil)
Données personnelles, profil couple, archetype, préférences, paramètres.

### Simulateurs (écrans dédiés, conservés)
Les simulateurs clés restent des **écrans full-screen** accessibles depuis Pulse ET le chat :
- Retraite (trajectoire complète)
- Rente vs Capital (breakeven)
- EPL (retrait anticipé)
- Rachat LPP (optimisation fiscale)
- Budget (vue mensuelle/annuelle)

---

## 6. PLAN D'EXÉCUTION — 3 Phases incrémentales

### Phase 0 (S48-S49) — "Pulse sur l'existant"

**Objectif** : Améliorer Tab 1 sans rien casser.

| Tâche | Détail |
|-------|--------|
| Transformer Tab 1 → Pulse | Score visibilité (25/25/25/25) + narrative + 3 action cards |
| Section "Comprendre" | Liens directs vers simulateurs, en bas de Pulse |
| Simplification langage | Réécrire le texte des cards : 8 mots max, zéro jargon |
| Tabs 2/3/4 | **Inchangés** |

**Livrable** : App améliorée, aucune régression, zéro risque.

### Phase 1 (S50-S51) — "Response Cards"

**Objectif** : Créer les templates visuels, les intégrer partout.

| Tâche | Détail |
|-------|--------|
| 10 templates Response Cards | Retraite, Budget, 3a, LPP, Fiscal, Couple, AVS, EPL, Assurance, Alerte |
| Intégrer dans Pulse | Cards dynamiques remplacent les cards statiques |
| Intégrer dans Chat | Response Cards inline dans CoachChatScreen |
| Suggested prompts personnalisés | Basés sur le profil, l'archetype, les données manquantes |
| Pondération contextuelle score | Poids par âge/archetype (remplace 25/25/25/25) |

**Livrable** : UX unifiée Cards, chat enrichi, scoring affiné.

### Phase 2 (S52-S53) — "Nettoyage & consolidation"

**Objectif** : Supprimer le legacy, passer à 3 tabs.

| Tâche | Détail |
|-------|--------|
| Supprimer ExploreTab | Contenu migré vers "Comprendre" dans Pulse |
| Supprimer FinancialSummary | Remplacé par Pulse |
| Supprimer MentorFAB | Remplacé par Tab Mint |
| Tab 3 → "Moi" | Refonte profil avec couple première classe |
| Couple UX | Sélecteur Julien/Lauren/Couple sur Pulse et Chat |

**Livrable** : App finale 3 tabs, ~25 écrans, architecture cible.

---

## 7. CE QUI N'EST PAS DANS LE SCOPE V1

| Élément | Raison | Horizon |
|---------|--------|---------|
| Webapp companion | Double produit à maintenir, équipe trop petite | Post-V1 |
| Chat-first (chat = Tab 1) | Inadapté cible 45-60, anxiété page blanche | Jamais (hybride confirmé) |
| Score pondéré dès Phase 0 | Besoin données utilisateur réelles pour calibrer | Phase 1 |
| NLU custom | SLM + BYOK + templates suffisent | Post-V1 si nécessaire |
| Dark mode | Pas prioritaire vs coach | Post-V1 |

---

## 8. COMPLIANCE CHECKLIST

Chaque écran / card / réponse chat DOIT respecter :

- [ ] **Pas de termes bannis** : garanti, certain, optimal, meilleur, conseiller
- [ ] **Micro-disclaimer inline** visible sans scroll
- [ ] **Référence légale** (LPP art. X, LAVS art. Y, etc.)
- [ ] **CTA éducatif** (simuler/explorer, jamais prescriptif)
- [ ] **Score = "visibilité"** (jamais "santé" ou "score financier")
- [ ] **Chiffre-choc** avec explication contextuelle
- [ ] **Sources** listées
- [ ] **Alertes** quand seuils franchis

---

## 9. AUDIT TRAIL

### Challenge Panel (10 mars 2026)
- **Expert UX** : Chat-first risqué → DÉJÀ COUVERT par hybride data-first
- **Expert Compliance** : Score /100 = rating → INTÉGRÉ : renommé "visibilité financière"
- **Expert Frontend** : 6 sprints big bang → INTÉGRÉ : 3 phases incrémentales
- **Expert Data** : Score uniforme fragile → INTÉGRÉ : pondération Phase 1, pas de decay visible
- **Expert Produit** : Problème = langage → PARTIELLEMENT INTÉGRÉ : simplification dans Phase 0

### Points rejetés (avec justification)
1. "Le moteur de chat n'existe pas" → FAUX : CoachChatScreen + SLM + BYOK existent
2. "Maxiom a un LLM, MINT non" → FAUX : SLM Gemma 3n + BYOK + FallbackTemplates
3. "Si simplifier le langage suffit, pas besoin de refonte" → FAUX : le problème est aussi la densité et la navigation, pas seulement le vocabulaire

---

> **Prochaine étape** : Phase 0 (S48-S49) — Pulse dashboard + score visibilité + simplification langage.

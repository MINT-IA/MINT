# MINT Design System v2

> **⚠️ LEGACY NOTE (2026-04-05):** Uses "chiffre choc" (legacy term → "premier éclairage", see `docs/MINT_IDENTITY.md`).

> **Statut** : Document cible. Migration en cours depuis le code existant.
> **Gouvernance** : Ce document décrit la direction visuelle cible pour MINT.
> CLAUDE.md §7 pointe ici pour les détails. En cas de divergence entre ce document
> et le code actuel, c'est ce document qui décrit l'état souhaité — mais le code fait
> foi pour l'état actuel. Les écarts sont trackés dans le plan de migration (§9).
> **Source de vérité** : oui, pour les tokens, composants et règles visuelles détaillées.
> **Ne couvre pas** : vision produit globale, priorisation CapEngine, stratégie de navigation.

---

## 1. ART DIRECTION

**MINT = l'anti-dashboard.** Une expérience intime et premium qui donne confiance.
Chaque écran doit ressembler à une page d'un beau livre, pas à un cockpit d'avion.

**Références** : Chloé (luxe discret), Aesop (espace), Wise (clarté), Linear (sobriété).

### Principes directeurs

1. **L'air est un composant.** Le whitespace est du luxe, pas du vide.
2. **Hiérarchie radicale.** Un élément dominant par vue, le reste recule.
3. **Dire moins, montrer mieux.** Si tu peux enlever un élément, enlève-le.
4. **Le scroll est noble.** Plutôt un scroll aéré que tout comprimer au-dessus du fold.
5. **Zéro décoration gratuite.** Chaque bordure, ombre, icône a une raison fonctionnelle.

---

## 2. CATÉGORIES D'ÉCRANS

Les règles s'appliquent différemment selon le type d'écran. Chaque écran MINT appartient
à exactement une catégorie.

### A. Hero Screens (Insight / Projection)
> Pulse, Retirement Dashboard, Score Reveal, Chiffre-Choc, Financial Report

- **1 chiffre dominant** (`displayLarge`), visible en <3s
- **Max 2 sections** au-dessus du fold (hero + 1 secondaire)
- **1 CTA primaire** unique
- **Avant/Après** présent (comparaison visible)
- **Grand whitespace** entre les sections (`spacingXxl`)

### B. Simulator Screens (Calcul / Arbitrage)
> Fiscal Comparator, Allocation Annuelle, Rente vs Capital, Budget, Affordability,
> Amortization, EPL Combined, Imputed Rental, SARON vs Fixed, Rachat Échelonné,
> EPL (LPP deep), Dividende vs Salaire, Simulator 3a/Compound/Leasing,
> Provider Comparator, Real Return, Staggered Withdrawal, Retroactive 3a

- **Inputs** compacts en haut, **résultat** dominant en dessous
- **Max 3 sliders/inputs** visibles simultanément
- **Chiffre résultat** en `displayMedium`
- **Hypothèses** visibles et éditables
- **Disclaimer + sources** obligatoires en footer
- **Avant/Après** ou scénario Bas/Moyen/Haut

**Note** : `budget` est ici car c'est un outil de calcul (50/30/20, enveloppes) même si
l'utilisateur y revient fréquemment. Si le budget évolue vers un tracker quotidien,
il migrerait en catégorie A.

### C. Life Event Screens (Événement de vie)
> Mariage, Divorce, Naissance, Concubinage, Housing Sale, Donation, Décès Proche,
> Déménagement Cantonal, Gender Gap, First Job, Unemployment, Job Comparison,
> Expat, Frontalier, Indépendant, Disability Gap/Insurance/Self-Employed,
> LAMal Franchise, Coverage Check

- **Chiffre-choc** d'impact en hero (ex: "-23% de revenu")
- **Tabs** pour structurer (max 4)
- **Checklist** d'actions concrètes
- **Insert éducatif** avec source légale
- **Ton émotionnel** adapté à l'événement

**Note** : `consumer_credit` est en C car c'est déclenché par un besoin de vie
(achat voiture, urgence). `lamal_franchise` et `coverage_check` sont en C car ils
répondent à un changement de situation (déménagement, emploi, naissance).

### D. Form Screens (Onboarding / Data Entry / Check-in)
> Quick Start, Data Block Enrichment, Document Scan, Extraction Review, AVS Guide,
> Coach Check-in, Annual Refresh, Accept Invitation

- **Progressive disclosure** : révéler les champs un par un ou par étape
- **Preview live** si possible (chiffre qui change en temps réel)
- **Pas de premier éclairage obligatoire** — le focus est la complétion
- **Validation inline** (pas de page d'erreur séparée)
- **1 CTA** "Continuer" en bas, sticky

**Note** : `coach_checkin` et `annual_refresh` sont ici car ce sont des formulaires de
mise à jour de données, même s'ils contiennent du contenu éducatif. Le résultat
(nouveau score) s'affiche après soumission, pas pendant.

### E. Utility Screens (Settings / Auth / Admin)
> Login, Register, Forgot Password, Verify Email, Profile, BYOK Settings,
> SLM Settings, Consent Dashboard, Admin Observability, Admin Analytics

- **Fonctionnel avant tout** — pas besoin de premier éclairage
- **Layout standard** Material 3
- **Whitespace normal** (`spacingLg`)
- **i18n et accessibilité** obligatoires comme partout

### F. List / Hub Screens (Navigation / Catalogue)
> Tools Library, Documents, Document Detail, Conversation History, Comprendre Hub,
> Theme Detail, Open Banking Hub, Consent (OB), Transaction List, Bank Import,
> Portfolio, Timeline, Achievements, Cantonal Benchmark, Confidence Dashboard

- **Pas de chiffre dominant** — le focus est la navigation
- **Recherche/filtre** si > 10 items
- **Empty state** avec illustration + CTA
- **Cards uniformes** en liste verticale

**Note** : `theme_detail` est ici car c'est une page de lecture dans un catalogue
éducatif. `document_detail` est ici car c'est une vue de détail dans la liste
documents. `confidence_dashboard` est ici car c'est un hub de métriques consultable.

### Spécial : Coach Screens
> Coach Chat, Ask Mint, Cockpit Detail, Succession Patrimoine, Optimisation Décaissement

Ces écrans sont **hybrides** : ils combinent du contenu éducatif (catégorie A/C)
avec de l'interaction conversationnelle. Règles :
- **Coach Chat / Ask Mint** : interface conversationnelle, pas de chiffre dominant.
  Le chiffre apparaît dans les Response Cards (qui suivent les règles B).
- **Cockpit Detail** : catégorie A (hero avec score).
- **Succession / Décaissement** : catégorie B (simulation avec résultats).

### Spécial : Shell / Marketing
> Main Navigation Shell, Budget Container, Landing

Ces écrans sont des conteneurs ou des pages marketing. Pas de catégorie UX —
ils suivent leurs propres règles (landing = conversion, shell = navigation).

---

## 3. DESIGN TOKENS

### 3.1 Typographie

| Token | Font | Size | Weight | Letter-sp | Line-h | Dart constant | Usage |
|-------|------|------|--------|-----------|--------|---------------|-------|
| `displayLarge` | Montserrat | 48 | w800 | -1.0 | 1.1 | `MintTextStyles.displayLarge` | Chiffre dominant (Hero A) |
| `displayMedium` | Montserrat | 32 | w700 | -0.5 | 1.15 | `MintTextStyles.displayMedium` | Chiffre résultat (Sim B) |
| `headlineLarge` | Montserrat | 26 | w700 | -0.5 | 1.15 | `MintTextStyles.headlineLarge` | Titre d'écran |
| `headlineMedium` | Montserrat | 22 | w600 | 0 | 1.2 | `MintTextStyles.headlineMedium` | Titre de section |
| `titleMedium` | Inter | 16 | w600 | 0 | 1.3 | `MintTextStyles.titleMedium` | Label de carte |
| `bodyLarge` | Inter | 16 | w400 | 0 | 1.5 | `MintTextStyles.bodyLarge` | Texte courant |
| `bodyMedium` | Inter | 14 | w400 | 0 | 1.5 | `MintTextStyles.bodyMedium` | Texte secondaire |
| `bodySmall` | Inter | 13 | w500 | 0 | 1.4 | `MintTextStyles.bodySmall` | Labels, hint text |
| `labelSmall` | Inter | 11 | w500 | 0 | 1.3 | `MintTextStyles.labelSmall` | Captions, métadonnées |
| `micro` | Inter | 10 | w400i | 0 | 1.3 | `MintTextStyles.micro` | Disclaimer |

**Fichier** : `lib/theme/mint_text_styles.dart` (à créer — Phase 1 migration).

**Règles** :
- Max 2 fonts par écran (Montserrat + Inter). **Outfit est déprécié** — migrer vers Montserrat.
- Max 4 tailles différentes visibles simultanément.
- Couleur texte : `textPrimary` (titres/chiffres), `textSecondary` (body), `textMuted` (labels).

### 3.2 Palette Core

Chaque token mappe exactement à une constante `MintColors.*` existante dans
`lib/theme/colors.dart`.

| Token | Constante Dart | Hex actuel | Usage | Règle |
|-------|----------------|------------|-------|-------|
| primary | `MintColors.primary` | `#1D1D1F` | CTA, AppBar Pulse | 1-2 usages/écran |
| white | `MintColors.white` | `#FFFFFF` | Background | Background par défaut |
| surface | `MintColors.surface` | `#F5F5F7` | Cartes, inputs | Gris très léger |
| card | `MintColors.card` | `#FFFFFF` | Cartes blanches | Blanc pur |
| textPrimary | `MintColors.textPrimary` | `#1D1D1F` | Titres, chiffres | Noir profond |
| textSecondary | `MintColors.textSecondary` | `#6E6E73` | Descriptions | Gris moyen |
| textMuted | `MintColors.textMuted` | `#86868B` | Labels, captions | Gris clair |
| border | `MintColors.border` | `#D2D2D7` | Bordures | Subtil |
| success | `MintColors.success` | `#24B14D` | Positif | Parcimonie |
| warning | `MintColors.warning` | `#FF9F0A` | Attention | Parcimonie |
| error | `MintColors.error` | `#FF453A` | Urgent | Urgences seules |
| info | `MintColors.info` | `#007AFF` | Liens, neutre | Actions secondaires |

**Couleurs étendues légitimes** (charts, piliers, life events — voir §6) :
- `MintColors.retirementAvs`, `retirementLpp`, `retirement3a`, `retirementLibre`
- `MintColors.trajectoryOptimiste`, `trajectoryBase`, `trajectoryPrudent`
- `MintColors.purple`, `pink`, `cyan`, `indigo`, `teal`, `amber`, `deepOrange`

**Couleurs à nettoyer** (~130 couleurs) : toutes les autres dans `colors.dart`.
Ne PAS les utiliser dans du nouveau code. Le nettoyage se fait en Phase 4.

### 3.3 Spacing

| Token | Value | Constante Dart | Usage |
|-------|-------|----------------|-------|
| `spacingXs` | 4px | `MintSpacing.xs` | Entre label et input |
| `spacingSm` | 8px | `MintSpacing.sm` | Entre éléments proches |
| `spacingMd` | 16px | `MintSpacing.md` | Padding interne cartes |
| `spacingLg` | 24px | `MintSpacing.lg` | Padding horizontal (mobile) |
| `spacingXl` | 32px | `MintSpacing.xl` | Entre sections principales |
| `spacingXxl` | 48px | `MintSpacing.xxl` | Grand espacement (Hero) |
| `spacingPage` | 32px | `MintSpacing.page` | Padding horizontal (tablet) |

**Fichier** : `lib/theme/mint_spacing.dart` (à créer — Phase 1 migration).

### 3.4 Rayons

| Token | Value | Usage |
|-------|-------|-------|
| `radiusSm` | 8px | Badges, chips |
| `radiusMd` | 12px | Boutons, inputs |
| `radiusLg` | 16px | Cartes |
| `radiusXl` | 20px | Modals, bottom sheets |

### 3.5 Ombres

| Token | Value | Usage |
|-------|-------|-------|
| `shadowSubtle` | `blur: 8, offset: (0,2), alpha: 0.04` | Cartes au repos |
| `shadowElevated` | `blur: 16, offset: (0,6), alpha: 0.08` | Cartes en focus |
| `shadowNone` | aucune | Default — préférer pas d'ombre |

**Règle** : Pas de bordure ET ombre sur le même composant. L'un ou l'autre.

---

## 4. COMPOSANTS

### 4.1 Cartes

**Standard Card** (la plus fréquente) :
```
Background: MintColors.white ou MintColors.surface
Bordure: MintColors.border à alpha 0.5 OU aucune
Ombre: shadowSubtle OU aucune (jamais les deux avec bordure)
Radius: radiusLg (16px)
Padding: spacingMd à spacingLg (16-24px)
```

**Pas de glassmorphism.** `MintGlassCard` est déprécié — remplacer par Standard Card.

### 4.1b Composants Premium (S54+)

Famille de composants éditoriaux pour les surfaces manifestes MINT.

| Composant | Fichier | Usage |
|-----------|---------|-------|
| `MintHeroNumber` | `widgets/premium/mint_hero_number.dart` | Chiffre dominant 56pt avec fade-in |
| `MintSurface` | `widgets/premium/mint_surface.dart` | Container chaud (6 tones: porcelaine/craie/sauge/bleu/peche/blanc) |
| `MintNarrativeCard` | `widgets/premium/mint_narrative_card.dart` | Carte calme pour cap/insight/story |
| `MintProgressArc` | `widgets/premium/mint_progress_arc.dart` | Arc gauge 270° pour scores/pourcentages |
| `MintSignalRow` | `widgets/premium/mint_signal_row.dart` | Ligne label+value minimale |
| `MintPremiumSlider` | `widgets/premium/mint_premium_slider.dart` | Slider avec thumb anneau, value pill, track porcelaine |
| `MintResultHeroCard` | `widgets/premium/mint_result_hero_card.dart` | Carte de révélation (conséquence financière) |
| `MintChoiceCard` | `widgets/premium/mint_choice_card.dart` | Carte sélectionnable pour écrans de décision |
| `MintInlineInputChip` | `widgets/premium/mint_inline_input_chip.dart` | Chip compact tap-to-edit |
| `MintConfidenceNotice` | `widgets/premium/mint_confidence_notice.dart` | Notice fiabilité (pêche si <50%, sauge si ≥50%) |

**Règle** : tout nouvel écran Tier 1-3 doit utiliser ces composants, pas des Container/Card manuels.

### 4.2 Boutons

| Variante | Widget | Background | Texte | Height | Radius | Usage |
|----------|--------|------------|-------|--------|--------|-------|
| **Primary** | `FilledButton` | `primary` | blanc | 52px | 12px | CTA unique/écran |
| **Secondary** | `OutlinedButton` | transparent | `primary` | 44px | 12px | Action alternative |
| **Ghost** | `TextButton` | transparent | `info` | 40px | 8px | Navigation, retour |
| **Danger** | `FilledButton` | `error` | blanc | 52px | 12px | Destructif (rare) |

**Pas de bouton glossy.** `MintPremiumButton` est déprécié → `FilledButton` + `primary`.
Full-width par défaut sur mobile.

### 4.3 Inputs

```
Background: MintColors.surface
Bordure: 1px MintColors.border
Radius: radiusMd (12px)
Padding: 14px horizontal, 12px vertical
Label: au-dessus (bodySmall, MintColors.textPrimary, w600)
Hint: bodyMedium, MintColors.textMuted
Error: bodySmall, MintColors.error — sous le champ
```

Pas de floating label. Pas d'icône de préfixe (sauf recherche).

### 4.4 Sliders

```
Track: 4px height
Active: MintColors.primary
Inactive: MintColors.border
Thumb: 16px diameter, MintColors.primary
Valeur: affichée à droite du label (bodySmall, MintColors.primary, w700)
```

### 4.5 AppBar

| Type | Background | Texte | Quand |
|------|------------|-------|-------|
| **Standard** | `MintColors.white` | `textPrimary` | 95% des écrans |
| **Pulse** | gradient `primary → primaryLight` | blanc | Pulse uniquement |

Titre : `headlineMedium` (Montserrat 22pt w600). Back button : Material standard.
Max 1 action icon.

### 4.6 Bottom Sheets

```
Background: MintColors.white
Radius top: radiusXl (20px)
Handle: 40×4px, MintColors.border, radiusSm
Max height: 85% de l'écran
Padding: spacingLg (24px) horizontal
```

### 4.7 États

| État | Pattern | Composant |
|------|---------|-----------|
| **Loading** | Skeleton shimmer sur les zones de contenu. Spinner 20×20 dans les boutons. | `MintLoadingSkeleton` |
| **Empty** | Centre vertical : icône outline 48px (textMuted, alpha 0.4) + titre headlineMedium + body + CTA primary. | `MintEmptyState` |
| **Error** | Bandeau inline : fond `error` alpha 0.06, bordure `error` alpha 0.15, icône + message + TextButton retry. | `MintErrorBanner` |
| **No data** | Comme Empty mais CTA orienté enrichment ("Ajoute tes données pour voir…"). | `MintEmptyState` variante |

---

## 5. DATA VISUALIZATION (Charts, Comparatifs, Alertes)

### 5.1 Principes généraux

- **Pas de chart pour le plaisir.** Chaque visualisation répond à une question précise.
- **Le chiffre d'abord, le chart ensuite.** Le nombre clé est en texte (`displayMedium`),
  le graphe est secondaire et explicatif.
- **Max 1 chart par vue** visible au-dessus du fold. Charts supplémentaires sous le fold.
- **Légende intégrée** au chart (labels inline sur les séries), pas en bloc séparé.

### 5.2 Couleurs de séries

| Série | Couleur | Usage |
|-------|---------|-------|
| AVS (1er pilier) | `MintColors.info` | Bleu — sécurité sociale |
| LPP (2e pilier) | `MintColors.pillarLpp` | Indigo — prévoyance pro |
| 3a (3e pilier) | `MintColors.retirement3a` | Violet — épargne volontaire |
| Libre passage | `MintColors.retirementLibre` | Teal — hors piliers |
| Scénario optimiste | `MintColors.trajectoryOptimiste` | Vert |
| Scénario base | `MintColors.trajectoryBase` | Bleu |
| Scénario prudent | `MintColors.trajectoryPrudent` | Orange |

Max 4 séries par graphe. Au-delà, regrouper ou utiliser des tabs.

### 5.3 Types de chart autorisés

| Type | Usage | Règles |
|------|-------|--------|
| **Barre horizontale** | Comparaison (rente vs capital, cantons) | Max 6 barres. Label + valeur inline. |
| **Barre empilée** | Décomposition (AVS + LPP + 3a = total) | Max 4 segments. Légende intégrée. |
| **Ligne** | Projection temporelle (capital LPP sur 20 ans) | Max 3 séries. Axe Y en CHF, axe X en années. |
| **Donut / Ring** | Répartition (allocation, patrimoine) | Max 5 segments. Chiffre central. |
| **Gauge linéaire** | Score / progression (FHS, confidence, taux) | 1 seul par écran. Valeur en texte dessus. |
| **Tornado** | Sensibilité (±5% sur rendement) | Paires symétriques. Max 6 variables. |

**Interdits** : Pie chart (utiliser donut), 3D, radar, bubble, scatter.

### 5.4 Confidence Bands

Quand `confidence < 70%` :
- Zone grisée entre min et max (`MintColors.border`, alpha 0.15)
- Ligne centrale = scénario base
- Label : "Fourchette d'estimation — affine ton profil pour réduire l'incertitude"
- **Toujours** un CTA vers l'enrichment associé

### 5.5 Alertes et indicateurs

| Type | Couleur fond | Couleur bordure | Icône | Usage |
|------|-------------|-----------------|-------|-------|
| **Info** | `info` alpha 0.06 | `info` alpha 0.15 | `info_outline` | Information neutre |
| **Succès** | `success` alpha 0.06 | `success` alpha 0.15 | `check_circle_outline` | Objectif atteint |
| **Attention** | `warning` alpha 0.06 | `warning` alpha 0.15 | `warning_amber` | Seuil approché |
| **Urgent** | `error` alpha 0.06 | `error` alpha 0.15 | `error_outline` | Action requise |

Structure : `Container` avec `border`, `borderRadius: radiusMd`, `padding: spacingMd`.
Contenu : icône + texte body (pas de titre séparé). 1-2 lignes max.

---

## 6. COPY UX (Ton, Titres, Labels, CTAs)

### 6.1 Ton général

- **Tu** (informel, direct). Pas de "vous".
- **Inclusif** : "un·e spécialiste", pas "un conseiller".
- **Éducatif, jamais prescriptif** : "tu pourrais envisager", pas "tu dois faire".
- **Conditionnel** : "pourrait", "envisager", "si tu…". Jamais d'impératif financier.
- **Empathique** pour les événements difficiles (chômage, divorce, décès) :
  réduire le jargon, allonger les phrases, ajouter du souffle.

### 6.2 Titres

| Contexte | Longueur max | Style | Exemple |
|----------|-------------|-------|---------|
| Titre écran (H2) | 5 mots | Sentence case, concret | "Ton aperçu retraite" |
| Titre section | 4 mots | Sentence case | "Tes prochaines actions" |
| Titre carte | 6 mots | Sentence case, question ou action | "Combien coûte un rachat ?" |
| Chiffre-choc caption | 10 mots | Phrase complète, impact | "Tu gardes 63% de ton train de vie" |

**Jamais** de titre en UPPERCASE. **Jamais** de titre décoratif sans contenu.

### 6.3 Labels de statut

| Statut | Label FR | Couleur | Ton |
|--------|----------|---------|-----|
| Positif | "En bonne voie" | `success` | Encourageant |
| Attention | "À surveiller" | `warning` | Factuel, pas alarmiste |
| Urgent | "Action requise" | `error` | Direct, pas anxiogène |
| Neutre | "Estimation" | `textMuted` | Informatif |
| Incomplet | "Données manquantes" | `textMuted` | Invitant ("Ajoute…") |

**Jamais** : "Bon", "Mauvais", "Optimal", "Parfait", "Garanti" (termes interdits CLAUDE.md §6).

### 6.4 CTAs

| Type | Longueur | Structure | Exemple |
|------|----------|-----------|---------|
| CTA primaire | 3-5 mots | Verbe + objet | "Voir mon aperçu" |
| CTA secondaire | 2-4 mots | Verbe infinitif | "En savoir plus" |
| CTA enrichment | 4-6 mots | "Ajoute" + quoi + bénéfice | "Ajoute ton LPP → +30 pts" |

**1 seul CTA primaire par écran.** Si 2 actions sont nécessaires, la seconde est
un `OutlinedButton` ou un `TextButton`.

### 6.5 Disclaimers

- **Position** : footer de tout écran contenant un calcul ou une projection.
- **Style** : `micro` (Inter 10pt italic), `MintColors.textMuted`.
- **Structure** : "Outil éducatif. Ne constitue pas un conseil financier (LSFin art. 3)."
  + Sources légales si applicable.
- **Pas de disclaimer dans les écrans Utility/Auth/List.** Seulement là où il y a du calcul.

---

## 6.6 Art Direction — 5 règles non négociables (S55+)

1. **L'écran commence par un enjeu, jamais par un contrôle.**
   Quick Start, simulateurs, Decision Canvas : on doit d'abord sentir ce qui se joue.

2. **Un seul moment hero par écran.**
   Un chiffre, une phrase, ou un choix. Pas trois centres de gravité.

3. **Les contrôles deviennent secondaires visuellement.**
   Sliders, toggles, champs servent la décision. Ils ne mènent pas la composition.

4. **La matière visuelle doit être chaude, calme, éditoriale.**
   Porcelaine, craie, sauge, ardoise, bleu air, contraste mesuré, grandes marges.

5. **Les résultats doivent être vécus comme des conséquences, pas comme des outputs.**
   Toujours : ce que ça veut dire, ce que ça change, quoi faire ensuite.

---

## 7. PATTERNS INTERDITS

| # | Pattern | Remplacer par |
|---|---------|---------------|
| 1 | Grille 2×2 de cartes avec icônes | Liste verticale ou bottom sheet menu |
| 2 | Badge coloré flottant ("+22 pts") | Texte inline avec couleur sémantique |
| 3 | Glassmorphism (`MintGlassCard`) | Standard Card (§4.1) |
| 4 | Bouton glossy (`MintPremiumButton`) | `FilledButton` primary (§4.2) |
| 5 | Sous-titres en UPPERCASE + letter-spacing | Sentence case, `bodySmall` w600 |
| 6 | Font `Outfit` | Montserrat (mêmes usages) |
| 7 | Multiple gradients par page | 1 gradient max (hero OU AppBar, pas les deux) |
| 8 | Icônes décoratives sans fonction interactive | Supprimer ou rendre tap-able |
| 9 | Bordure + ombre sur le même composant | L'un OU l'autre |
| 10 | Cards dans des cards (nesting) | Sections avec spacing |
| 11 | `CircularProgressIndicator` décoratif | Gauge linéaire ou texte |
| 12 | > 3 couleurs d'accent par écran | primary + max 2 sémantiques |
| 13 | Couleurs hors palette (§3.2 + §5.2) dans du nouveau code | Tokens core ou séries chart |
| 14 | Pie chart, 3D, radar, bubble | Donut, barre, ligne, gauge |
| 15 | Titre > 6 mots | Réduire à l'essentiel |
| 16 | Plus de 1 CTA primaire par écran | Secondary/Ghost pour les autres |
| 17 | **Form first** : écran qui ouvre sur une pile de champs/sliders | Commencer par l'enjeu, contrôles après |
| 18 | **Pretty calculator** : simulateur joliment stylé sans scène de décision | Montrer la conséquence d'abord |
| 19 | **Grey soup** : trop de gris clairs, cartes similaires, pas de tension | Utiliser les tons premium (sauge/pêche/bleu) |
| 20 | **Micro-polish sans macro** : améliorer pills/ombres sans résoudre la composition | Résoudre le layout d'abord |
| 21 | **Everything visible** : toutes les hypothèses/inputs/états affichés ensemble | Progressive disclosure |

---

## 8. CHECKLIST "PROD READY" (par écran)

### Obligatoire (tous les écrans, toutes catégories)

- [ ] i18n : 0 string hardcodée (tout via `S.of(context)!`)
- [ ] Colors : 0 couleur hardcodée (tout via `MintColors.*`)
- [ ] Nav : GoRouter uniquement (pas de `Navigator.push/pop`)
- [ ] Semantics : sur tous les éléments interactifs
- [ ] Aucun pattern interdit (§7)
- [ ] Typo : Montserrat + Inter uniquement (pas Outfit)
- [ ] AppBar : blanc standard (sauf Pulse)
- [ ] Flutter analyze : 0 erreurs sur le fichier
- [ ] Accents français corrects (é, è, ê, ô, ù, ç, à)
- [ ] Copy UX conforme (§6) : ton, longueur titres, labels statut, CTA

### Selon la catégorie (§2)

| Critère | A Hero | B Sim | C Life | D Form | E Util | F List |
|---------|--------|-------|--------|--------|--------|--------|
| Chiffre dominant | `displayLarge` | `displayMedium` | `displayMedium` | Non | Non | Non |
| Avant/Après | Oui | Oui (ou scénarios) | Oui | Non | Non | Non |
| Max sections au fold | 2 | 3 | 3 | Libre | Libre | Libre |
| Disclaimer + sources | Si calcul | Oui | Si calcul | Non | Non | Non |
| Insert éducatif | Oui | Oui | Oui | Optionnel | Non | Non |
| Ton émotionnel | Oui | Modéré | Fort | Neutre | Neutre | Neutre |
| Empty state (§4.7) | Oui | Oui | Non | Non | Non | Oui |
| Charts conformes (§5) | Si applicable | Oui | Si applicable | Non | Non | Non |

---

## 9. PLAN DE MIGRATION

### État actuel du code (à date)

| Composant | État actuel | Cible |
|-----------|------------|-------|
| `MintGlassCard` | Utilisé (~10 écrans) | Déprécié → Standard Card |
| `MintPremiumButton` | Utilisé (~5 écrans) | Déprécié → FilledButton |
| `MintHeader` (Outfit, UPPERCASE) | Utilisé (~15 écrans) | Migrer vers Montserrat, sentence case |
| `colors.dart` | ~200 couleurs | Core 12 + extended ~20 + chart ~10 |
| `MintTextStyles` | N'existe pas | À créer (§3.1) |
| `MintSpacing` | N'existe pas | À créer (§3.3) |
| AppBar gradient | ~60 écrans | Blanc standard (sauf Pulse) |
| Hardcoded FR strings | ~45 écrans | 0 (tout via i18n) |

### Phase 1 : Fondations (immédiat)

- [ ] Créer `lib/theme/mint_text_styles.dart` — tokens §3.1
- [ ] Créer `lib/theme/mint_spacing.dart` — tokens §3.3
- [ ] Annoter `@Deprecated` sur `MintGlassCard`, `MintPremiumButton`
- [ ] CLAUDE.md §7 mis à jour ✅ (fait)

### Phase 2 : Composants partagés (sprint S52)

- [ ] Créer `MintCard` widget — Standard Card §4.1
- [ ] Créer `MintEmptyState` — §4.7
- [ ] Créer `MintErrorBanner` — §4.7
- [ ] Créer `MintLoadingSkeleton` — §4.7
- [ ] Migrer `MintHeader` : Outfit → Montserrat, UPPERCASE → sentence case

### Phase 3 : Écrans (sprints S52-S54)

Chaque écran passe la checklist §8. Ordre de priorité :
1. **Tier 1** (6 écrans) : Pulse, Quick Start, Chiffre-Choc, Profile, Coach Chat, Budget
2. **Tier 2** (6 écrans) : Retirement Dashboard, Rente vs Capital, Rachat LPP, 3a Retrait, Décaissement, Succession
3. **Tier 3** (6 écrans) : Mariage, Naissance, Affordability, Divorce, Chômage, Déménagement
4. **Tier 4** (6 écrans) : Fiscal Comparator, Simulator 3a, 3a Rendement, Allocation, Indépendant, Expatrié
5. **Tier 5** (7 écrans) : Frontalier, Premier Emploi, LAMal, Job Comparison, Gender Gap, Achievements, Documents
6. **Tier 6** (restant) : Tous les autres écrans

### Phase 4 : Nettoyage (sprint S55)

- [ ] Audit `colors.dart` — supprimer les ~130 couleurs orphelines
- [ ] Supprimer `MintGlassCard`, `MintPremiumButton` une fois tous les usages migrés
- [ ] Audit fonts — vérifier 0 usage de Outfit dans le codebase

---

## 10. CLASSIFICATION COMPLÈTE DES 101 ÉCRANS

| Cat. | Écran | Priorité |
|------|-------|----------|
| **A** | pulse_screen | Tier 1 |
| **A** | premier_eclairage_screen (legacy: chiffre_choc_screen) | Tier 1 |
| **A** | retirement_dashboard_screen | Tier 2 |
| **A** | score_reveal_screen | Tier 5 |
| **A** | financial_report_screen_v2 | Tier 6 |
| **A** | cockpit_detail_screen | Tier 6 |
| **B** | rente_vs_capital_screen | Tier 2 |
| **B** | rachat_echelonne_screen | Tier 2 |
| **B** | fiscal_comparator_screen | Tier 4 |
| **B** | allocation_annuelle_screen | Tier 4 |
| **B** | location_vs_propriete_screen | Tier 6 |
| **B** | simulator_3a_screen | Tier 4 |
| **B** | simulator_compound_screen | Tier 6 |
| **B** | simulator_leasing_screen | Tier 6 |
| **B** | provider_comparator_screen | Tier 6 |
| **B** | real_return_screen | Tier 4 |
| **B** | staggered_withdrawal_screen | Tier 2 |
| **B** | retroactive_3a_screen | Tier 6 |
| **B** | affordability_screen | Tier 3 |
| **B** | amortization_screen | Tier 6 |
| **B** | epl_combined_screen | Tier 6 |
| **B** | imputed_rental_screen | Tier 6 |
| **B** | saron_vs_fixed_screen | Tier 6 |
| **B** | epl_screen (LPP deep) | Tier 6 |
| **B** | dividende_vs_salaire_screen | Tier 6 |
| **B** | budget_screen | Tier 1 |
| **B** | succession_patrimoine_screen | Tier 2 |
| **B** | optimisation_decaissement_screen | Tier 2 |
| **C** | mariage_screen | Tier 3 |
| **C** | divorce_simulator_screen | Tier 3 |
| **C** | naissance_screen | Tier 3 |
| **C** | concubinage_screen | Tier 6 |
| **C** | housing_sale_screen | Tier 6 |
| **C** | donation_screen | Tier 6 |
| **C** | deces_proche_screen | Tier 6 |
| **C** | demenagement_cantonal_screen | Tier 3 |
| **C** | gender_gap_screen | Tier 5 |
| **C** | first_job_screen | Tier 5 |
| **C** | unemployment_screen | Tier 3 |
| **C** | job_comparison_screen | Tier 5 |
| **C** | expat_screen | Tier 4 |
| **C** | frontalier_screen | Tier 5 |
| **C** | independant_screen | Tier 4 |
| **C** | disability_gap_screen | Tier 6 |
| **C** | disability_insurance_screen | Tier 6 |
| **C** | disability_self_employed_screen | Tier 6 |
| **C** | lamal_franchise_screen | Tier 5 |
| **C** | coverage_check_screen | Tier 6 |
| **C** | consumer_credit_screen | Tier 6 |
| **D** | quick_start_screen | Tier 1 |
| **D** | data_block_enrichment_screen | Tier 6 |
| **D** | document_scan_screen | Tier 5 |
| **D** | extraction_review_screen | Tier 6 |
| **D** | avs_guide_screen | Tier 6 |
| **D** | coach_checkin_screen | Tier 6 |
| **D** | annual_refresh_screen | Tier 6 |
| **D** | accept_invitation_screen | Tier 6 |
| **E** | login_screen | Tier 6 |
| **E** | register_screen | Tier 6 |
| **E** | forgot_password_screen | Tier 6 |
| **E** | verify_email_screen | Tier 6 |
| **E** | profile_screen | Tier 1 |
| **E** | byok_settings_screen | Tier 6 |
| **E** | slm_settings_screen | Tier 6 |
| **E** | consent_dashboard_screen | Tier 6 |
| **E** | admin_observability_screen | Tier 6 |
| **E** | admin_analytics_screen | Tier 6 |
| **F** | tools_library_screen | Tier 6 |
| **F** | documents_screen | Tier 5 |
| **F** | document_detail_screen | Tier 6 |
| **F** | conversation_history_screen | Tier 6 |
| **F** | comprendre_hub_screen | Tier 6 |
| **F** | theme_detail_screen | Tier 6 |
| **F** | open_banking_hub_screen | Tier 6 |
| **F** | consent_screen (OB) | Tier 6 |
| **F** | transaction_list_screen | Tier 6 |
| **F** | bank_import_screen | Tier 6 |
| **F** | portfolio_screen | Tier 6 |
| **F** | timeline_screen | Tier 6 |
| **F** | achievements_screen | Tier 5 |
| **F** | cantonal_benchmark_screen | Tier 6 |
| **F** | confidence_dashboard_screen | Tier 6 |
| **—** | coach_chat_screen | Tier 1 |
| **—** | ask_mint_screen | Tier 6 |
| **—** | main_navigation_shell | Tier 6 |
| **—** | budget_container_screen | Tier 6 |
| **—** | landing_screen | Tier 6 |
| **—** | household_screen | Tier 6 |
| **—** | financial_summary_screen | Tier 6 |
| **F** | debt_risk_check_screen | Tier 6 |
| **B** | debt_ratio_screen | Tier 6 |
| **F** | help_resources_screen | Tier 6 |
| **B** | repayment_screen | Tier 6 |
| **—** | libre_passage_screen | Tier 6 |
| **C** | avs_cotisations_screen (indép) | Tier 6 |
| **C** | ijm_screen (indép) | Tier 6 |
| **B** | pillar_3a_indep_screen | Tier 6 |
| **C** | lpp_volontaire_screen (indép) | Tier 6 |

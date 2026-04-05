# Quick Start + Rente ou Capital V2 — Flutter Spec

> **⚠️ LEGACY NOTE (2026-04-05):** Uses "chiffre choc" (legacy term → "premier éclairage", see `docs/MINT_IDENTITY.md`).

> Statut: spec d'implémentation exécutable
> Rôle: transformer 2 écrans stratégiques en surfaces manifestes MINT
> Source de vérité: oui, pour l'implémentation Flutter de ces 2 refontes
> Dépend de: `CLAUDE.md`, `MINT_UX_GRAAL_MASTERPLAN.md`, `DESIGN_SYSTEM.md`, `VOICE_SYSTEM.md`
> Ne couvre pas: tout le long tail, navigation globale, logique actuarielle exhaustive

---

## 1. But

Ces 2 écrans ne doivent plus lire comme:
- un formulaire mieux stylé,
- un simulateur avec plus de polish,
- une pile de contrôles suivie d'un résultat.

Ils doivent devenir:
- des écrans de révélation,
- des écrans de décision,
- des écrans qui montrent une conséquence avant de demander un effort.

Règle commune:
- d'abord l'enjeu,
- puis la conséquence,
- puis les contrôles,
- puis la preuve.

---

## 2. Cible

### 2.1 Quick Start V2

But:
- faire sentir une première vérité en moins de 5 secondes
- garder le parcours extrêmement léger
- faire du premier résultat la vraie star de l'écran

### 2.2 Rente ou capital V2

But:
- poser le dilemme avant la mécanique
- montrer la différence de vie entre les options
- repousser les paramètres experts après le premier niveau de compréhension

---

## 3. Fichiers concernés

### À modifier
- `apps/mobile/lib/screens/onboarding/quick_start_screen.dart`
- `apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart`

### À créer
- `apps/mobile/lib/widgets/premium/mint_result_hero_card.dart`
- `apps/mobile/lib/widgets/premium/mint_choice_card.dart`
- `apps/mobile/lib/widgets/premium/mint_inline_input_chip.dart`
- `apps/mobile/lib/widgets/premium/mint_confidence_notice.dart`

### À réutiliser
- `apps/mobile/lib/widgets/premium/mint_surface.dart`
- `apps/mobile/lib/widgets/premium/mint_hero_number.dart`
- `apps/mobile/lib/widgets/premium/mint_narrative_card.dart`
- `apps/mobile/lib/widgets/premium/mint_signal_row.dart`
- `apps/mobile/lib/widgets/premium/mint_premium_slider.dart`

### Tests à modifier / ajouter
- `apps/mobile/test/screens/onboarding/quick_start_screen_test.dart`
- `apps/mobile/test/screens/arbitrage/rente_vs_capital_screen_test.dart`

---

## 4. Quick Start V2

## 4.1 Contrat UX

L'écran doit montrer:
1. un titre fort
2. 3 inputs compacts maximum
3. une carte hero de révélation
4. un CTA unique
5. une micro-preuve discrète

L'écran ne doit plus montrer:
- des sliders pleine largeur au-dessus du fold comme centre de gravité
- une petite carte de résultat secondaire
- une impression de formulaire d'onboarding classique

## 4.2 Structure cible

```text
Scaffold
└─ SafeArea
   └─ CustomScrollView
      ├─ Top bar minimale
      ├─ Hero intro
      ├─ Input cluster compact
      ├─ Result hero card
      ├─ Micro proof
      ├─ Primary CTA
      └─ Secondary defer link
```

## 4.3 Ordre de rendu

### Bloc 1 — Intro

Contenu:
- titre: `Trois chiffres, une première vérité.`
- sous-phrase: `La suite viendra après.`

Règles:
- 2 lignes max pour le titre
- pas de sous-texte long
- grand espace blanc après le titre

### Bloc 2 — Inputs compacts

Inputs visibles d'abord:
- âge
- revenu brut annuel
- canton

Prénom:
- secondaire
- soit en champ discret replié
- soit déplacé sous la ligne de flottaison

Comportement:
- mise à jour immédiate du hero
- aucun mur de sliders

Implémentation recommandée:
- `MintInlineInputChip` pour âge / revenu / canton
- ouvrir `bottom sheet` ou `modal` légère pour modification
- fallback acceptable: 3 contrôles compacts inline si le refactor chip coûte trop cher

### Bloc 3 — Result hero card

Composant:
- `MintResultHeroCard`

Contenu:
- label supérieur: `Premier aperçu retraite`
- valeur principale: `CHF X/mois`
- comparaison secondaire: `Aujourd'hui: CHF Y/mois`
- phrase interprétative:
  - `Tu gardes ~62% de ton niveau de vie.`
  - ou version faible confiance: `Premier ordre de grandeur, à préciser.`

Règles:
- la valeur retraite est visuellement dominante
- l'écart n'est pas une mini data-viz compliquée
- une seule couleur d'accent
- pas de badge parasite

### Bloc 4 — Micro proof

Texte:
- très discret
- `Estimation éducative basée sur ton âge, ton revenu et ton canton.`

Si données par défaut:
- doit le dire explicitement

### Bloc 5 — CTA principal

Label cible:
- `Voir ce qui change`

Pas:
- `Voir mon aperçu`

Sortie:
- vers `chiffre-choc`
- ou flow équivalent si déjà mieux intégré

### Bloc 6 — Lien secondaire

Label type:
- `J'ajouterai plus de détails plus tard`

Rôle:
- rassurer sans casser la hiérarchie

## 4.4 État et logique

État minimal local:
- `firstName`
- `age`
- `salary`
- `canton`

Calcul:
- conserver la logique actuelle de preview
- ne pas changer les formules dans ce chantier
- uniquement changer mise en scène + ordre + contrôles

Règles:
- le hero doit se recalculer à chaque changement
- aucune animation agressive
- pas de loader si les calculs sont synchrones

## 4.5 DOD Quick Start

- le résultat domine visuellement les inputs
- le titre + hero suffisent à comprendre l'écran en 3 secondes
- 3 inputs principaux max au premier regard
- le CTA semble être la suite naturelle de la révélation
- aucune impression de mur de sliders
- tests widget réalignés

---

## 5. Rente ou capital V2

## 5.1 Contrat UX

L'écran doit:
- poser un vrai dilemme
- montrer ce qui change entre les options
- repousser les paramètres avancés
- être crédible même sans certificat

L'écran ne doit plus:
- ouvrir directement sur un formulaire expert
- présenter les champs comme centre de gravité
- noyer le choix dans les hypothèses

## 5.2 Structure cible

```text
Scaffold
└─ SafeArea
   └─ CustomScrollView
      ├─ Top bar minimale
      ├─ Decision hero
      ├─ 3 choice cards
      ├─ Consequence comparison block
      ├─ Confidence notice
      ├─ Fast estimate inputs
      ├─ Primary CTA
      └─ Advanced inputs disclosure
```

## 5.3 Ordre de rendu

### Bloc 1 — Decision hero

Titre:
- `Rente ou capital.`

Sous-titre:
- `Le même argent. Deux vies différentes.`

Règles:
- ton net, calme, sans jargon
- pas de longue introduction pédagogique en haut

### Bloc 2 — Choice cards

Composant:
- `MintChoiceCard`

3 cartes:
- `Rente`
- `Capital`
- `Mixte`

Chaque carte:
- 1 phrase maximum
- 1 nuance dominante
- 1 tonalité visuelle légère

Exemples:
- `Rente — plus stable, moins flexible`
- `Capital — plus libre, plus exigeant`
- `Mixte — un équilibre à construire`

Comportement:
- tap = active la vue comparative associée
- pas besoin de tab bar technique

### Bloc 3 — Consequence comparison block

Composant:
- `MintResultHeroCard` ou variante dédiée

Contenu:
- option la plus stable
- option la plus flexible
- 3 lignes de comparaison max:
  - revenu mensuel
  - fiscalité
  - transmission / flexibilité

Règles:
- montrer une différence de vie, pas juste un tableau actuariel
- une estimation simple au premier regard

### Bloc 4 — Confidence notice

Composant:
- `MintConfidenceNotice`

Cas sans certificat:
- `Fiabilité actuelle: 30%`
- `Sans certificat LPP, on reste sur une estimation large.`
- CTA secondaire: `Préciser mes données`

Cas avec certificat:
- le bloc devient plus discret

### Bloc 5 — Fast estimate inputs

Inputs visibles au départ:
- âge
- retraite prévue
- salaire brut

Règles:
- 3 inputs max avant disclosure
- pas d'avoir LPP / rachat / EPL au-dessus du fold

Implémentation:
- réutiliser `MintPremiumSlider` si nécessaire
- mais en nombre limité

### Bloc 6 — CTA principal

Label cible:
- `Comparer pour moi`

Pas:
- `Estimer`
- `Calculer`

### Bloc 7 — Advanced inputs disclosure

Titre:
- `J'ai mon certificat LPP`

Ouverture:
- section avancée repliable

Contenu avancé:
- avoir LPP actuel
- rachat LPP
- EPL
- canton
- état civil
- paramètres experts complémentaires

Règles:
- la précision vient après la compréhension
- pas avant

## 5.4 État et logique

Conserver:
- logique métier actuelle
- mode estimateur vs mode certificat
- calculs existants

Réorganiser:
- ordre de l'interface
- hiérarchie
- mécanisme d'activation du détail

Ajouter:
- un `selectedOutcomeMode` local (`rente`, `capital`, `mixte`)
- un état `advancedExpanded`

## 5.5 DOD Rente ou capital

- le dilemme est compréhensible avant les hypothèses
- les paramètres experts ne dominent plus l'écran
- sans certificat, l'incertitude est visible tout de suite
- le premier regard montre une conséquence, pas un formulaire
- la comparaison tient en 3 lignes max au-dessus du détail
- tests widget réalignés

---

## 6. Composants premium à créer

## 6.1 MintResultHeroCard

Usage:
- Quick Start
- Rente ou capital
- potentiellement Budget / 3a plus tard

API cible:

```dart
class MintResultHeroCard extends StatelessWidget {
  final String eyebrow;
  final String primaryLabel;
  final String primaryValue;
  final String? secondaryLabel;
  final String? secondaryValue;
  final String narrative;
  final Color accentColor;
}
```

## 6.2 MintChoiceCard

Usage:
- cartes `Rente / Capital / Mixte`

API cible:

```dart
class MintChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
}
```

## 6.3 MintInlineInputChip

Usage:
- Quick Start inputs compacts

API cible:

```dart
class MintInlineInputChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
}
```

## 6.4 MintConfidenceNotice

Usage:
- zones faible fiabilité

API cible:

```dart
class MintConfidenceNotice extends StatelessWidget {
  final int percent;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onTap;
}
```

---

## 7. Ordre recommandé d'implémentation

### PR 1 — composants premium manquants
- `mint_result_hero_card.dart`
- `mint_choice_card.dart`
- `mint_inline_input_chip.dart`
- `mint_confidence_notice.dart`

### PR 2 — Quick Start V2
- refonte hiérarchie
- inputs compacts
- hero card
- CTA
- tests

### PR 3 — Rente ou capital V2
- decision hero
- choice cards
- comparison block
- confidence notice
- disclosure avancée
- tests

---

## 8. Anti-régressions

- ne pas changer les formules métier dans ce chantier
- ne pas réintroduire de hardcoded strings
- ne pas multiplier les sliders premium juste parce qu'ils sont jolis
- ne pas transformer la disclosure avancée en deuxième écran déguisé
- ne pas cacher la preuve ou la confiance

---

## 9. Définition de réussite

Ces 2 écrans sont réussis si:
- ils ne lisent plus comme des formulaires,
- ils ne lisent plus comme des calculateurs,
- ils donnent envie de continuer,
- ils rendent la conséquence lisible avant l'effort,
- et ils deviennent des surfaces manifestes du MINT à venir.

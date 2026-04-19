# 03 — Composants Flutter, un par un

Pour chaque composant : **signature**, **tokens**, **structure**, **référence visuelle dans le prototype**, **gotchas**.

---

## 1. MintInlineInsightCard

**Rôle :** Niveau 1 — petite carte éditoriale dans le chat.
**Prototype :** `chat-vivant/insight-card.jsx` — composant `InsightCard`.

```dart
class MintInlineInsightCard extends StatelessWidget {
  final String label;              // "CE QUI COMPTE VRAIMENT"
  final Widget headline;           // Text.rich avec em Fraunces possibles
  final String? supporting;
  final MintInsightTone tone;      // porcelaine | sauge | peche | craie

  const MintInlineInsightCard({
    required this.label,
    required this.headline,
    this.supporting,
    this.tone = MintInsightTone.porcelaine,
  });
}

enum MintInsightTone { porcelaine, sauge, peche, craie }
```

**Tokens :**
- Fond selon tone : `porcelaine` / `saugeClaire` / `pecheDouce.withOpacity(0.35)` / `craie`
- Label : `labelMedium` 10.5pt, `corailDiscret` (ou `successAaa` pour sauge), uppercase, letterSpacing 1.2
- Headline : `editorialLarge` (Fraunces 22pt, weight 400)
- Supporting : `bodySmall`, `textSecondaryAaa`
- BorderRadius 16, padding 16h × 18v, border 0.5px `MintColors.border`

---

## 2. MintRatioCard

**Rôle :** Niveau 1 spécialisé — afficher une proportion (ex: "63% de ton train de vie").
**Prototype :** `chat-vivant/insight-card.jsx` — composant `RatioCard`.

```dart
class MintRatioCard extends StatelessWidget {
  final String label;
  final double numerator;
  final double denominator;
  final String explainer;
}
```

**Structure :**
1. Label eyebrow (corailDiscret, uppercase)
2. Gros chiffre % en Montserrat 44pt (displayLarge shrunk) + sous-titre "{num} sur {den} CHF/mois"
3. Barre de proportion gradient `retirementLpp → retirementAvs`, hauteur 6px
4. Explainer `bodySmall`

---

## 3. MintLifeLineSlider

**Rôle :** Widget atomique — slider horizontal avec marqueur d'épuisement.
**Prototype :** `chat-vivant/scene-rente-capital.jsx` — composant `LifeLine`.

```dart
class MintLifeLineSlider extends StatelessWidget {
  final int age;
  final ValueChanged<int> onAgeChanged;
  final int ageEpuisement;
  final int min;  // default 70
  final int max;  // default 100
  final Color fillColor; // dérive de age > ageEpuisement
}
```

**Gotchas :**
- Le fill change de couleur selon `age > ageEpuisement` → transition `AnimatedContainer`
- Marqueur épuisement : trait vertical 1.5px, opacité 0.5, avec label `capital épuisé` dessous en `labelSmall` 9.5pt
- Le thumb est un cercle 16×16 blanc, border 2px de la couleur fill, shadow subtile

---

## 4. MintSceneRenteCapital

**Rôle :** Niveau 2 — la scène hero, interactive.
**Prototype :** `chat-vivant/scene-rente-capital.jsx` — composant `SceneRenteCapital`.

```dart
class MintSceneRenteCapital extends StatefulWidget {
  final ScenePayload payload; // seed: {capitalBrut, tauxConversion, impotCapital, rendementReel}
  final VoidCallback? onOpenCanvas;
  final MintSceneVariant variant; // inline (CTA visible) | embedded (pas de CTA)
}
```

**Structure (de haut en bas) :**
1. **Eyebrow ligne** : "SCÈNE · ta LPP · 520'000 CHF" (corailDiscret + textMutedAaa)
2. **Phrase-signature Fraunces** : "Si tu vis jusqu'à **89 ans**, la rente te *rapporte plus*."
3. **Grid 2 colonnes** : `Rente à vie` / `Capital placé` — chaque colonne = `MintSceneColumn` (chiffre `CountUp`, sub-label coloré)
4. **MintLifeLineSlider** — contrôle `age` state
5. **Phrase de recul** — fond `craie`, `bodySmall`, avec `em` Fraunces
6. **CTA "Creuser"** si `variant == inline` — fond `textPrimary`, texte blanc, flèche droite

**Logique :**
- `avantageRente = age > ageEpuisement` détermine quelle colonne est "highlighted" (fond blanc + shadow + dot accent)
- `ageEpuisement` calculé par itération annuelle (voir code JSX)
- **Ne pas recalculer côté backend** — c'est local au widget

---

## 5. MintSceneRachatLPP

**Rôle :** Niveau 2 — scène rachat échelonné.
**Prototype :** `chat-vivant/scene-rachat-lpp.jsx`.

```dart
class MintSceneRachatLPP extends StatefulWidget {
  final ScenePayload payload; // seed: {tauxMarginal, anneesEchelon, tauxConversion}
  final VoidCallback? onOpenCanvas;
}
```

**Structure :**
1. Eyebrow "SCÈNE · rachat échelonné sur 4 ans"
2. Phrase-signature : "Si tu rachètes **60'000 CHF**, tu *récupères 21'000 CHF* en impôts."
3. Grid 2 colonnes (fond blanc) : `Économie fiscale` (en `successAaa`) / `Rente en plus` (en `retirementLpp`)
   - Utilise `MintCountUp` trigger sur changement montant
4. Slider montant rachat (20k → 150k, step 5k) — même shape que MintLifeLineSlider, couleur `corailDiscret`
5. Phrase de recul : "Coût réel net : **X CHF**. Le reste, c'est l'État qui finance."
6. CTA "Voir le plan année par année"

---

## 6. MintCanvasProjection (shell)

**Rôle :** Niveau 3 — canvas plein écran qui se déplie depuis le chat.
**Prototype :** `chat-vivant/canvas-rente-capital.jsx`.

```dart
class MintCanvasProjection extends StatefulWidget {
  final String title;
  final String eyebrow;           // "SCÈNE DÉPLIÉE"
  final List<MintCanvasChapitre> chapitres;
  final MintCanvasVerdict verdict;
  final VoidCallback onReturn;    // doit produire CanvasReturn
}
```

**Structure :**
- SafeArea + SingleChildScrollView
- Header sticky : eyebrow + titre + close button (cercle 36px, fond blanc, shadow)
- Body : chapitres empilés (gap 28px entre eux)
- Footer : carte noire `MintCanvasVerdict` (fond `textPrimary`, accent `pecheDouce` sur les em)
- Animation entrée : slide-up + fade 350ms `Curves.easeOutCubic`

**Route :**
```dart
Navigator.of(context).push(
  PageRouteBuilder(
    opaque: false,
    pageBuilder: (_, __, ___) => MintCanvasProjection(...),
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween(begin: const Offset(0, 0.1), end: Offset.zero).animate(
        CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
      ),
      child: FadeTransition(opacity: anim, child: child),
    ),
    transitionDuration: const Duration(milliseconds: 350),
  ),
);
```

---

## 7. MintCanvasChapitre

**Rôle :** section éditoriale dans le canvas.

```dart
class MintCanvasChapitre extends StatelessWidget {
  final String num;       // "01"
  final String titre;     // "Ce que ça te verse"
  final String? subtitle; // "bouge les hypothèses, regarde ce qui tient"
  final Widget child;     // contenu de la carte blanche
}
```

**Structure :**
- En-tête : num 11pt `corailDiscret` bold + titre `headlineSmall` + subtitle optionnel
- Carte : fond blanc, border 0.5px `lightBorder`, radius 18, padding 20×18

---

## 8. MintSensibiliteWidget

**Rôle :** panel de sliders dans le canvas, chapitre 04.
**Prototype :** même fichier — composant `SensibiliteWidget`.

```dart
class MintSensibiliteWidget extends StatefulWidget {
  final double ageVie;
  final double rendement;
  final ValueChanged<double> onAgeVieChanged;
  final ValueChanged<double> onRendementChanged;
  final int ageEpuisement; // calculé depuis le parent
}
```

Deux `MintSensSlider` empilés + phrase de synthèse Fraunces avec le chiffre vif en `corailDiscret` 600.

---

## Tokens à ajouter à `mint_text_styles.dart`

```dart
// ── Editorial (Fraunces — nouveau) ──

/// Signature éditoriale — moment de recul Fraunces (32pt).
/// Utilisé dans les verdicts, phrases-signature de fin de scène.
static TextStyle editorialDisplay({Color? color}) => GoogleFonts.fraunces(
      fontSize: 32,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.5,
      height: 1.15,
      color: color ?? MintColors.textPrimary,
    );

/// Phrase-signature en tête de scène ou insight (22pt Fraunces regular).
static TextStyle editorialLarge({Color? color}) => GoogleFonts.fraunces(
      fontSize: 22,
      fontWeight: FontWeight.w400,
      height: 1.3,
      color: color ?? MintColors.textPrimary,
    );

/// Body éditorial pour verdicts et passages signature (17pt Fraunces).
static TextStyle editorialBody({Color? color}) => GoogleFonts.fraunces(
      fontSize: 17,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: color ?? MintColors.textPrimary,
    );
```

**Ajouter `fraunces` aux fonts déclarées dans `pubspec.yaml` via `google_fonts`.**

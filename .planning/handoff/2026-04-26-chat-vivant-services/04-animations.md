# 04 — Animations

Tous les timings du prototype, mappés vers Flutter.

---

## MintCountUp

**Déjà existant ?** Vérifier `lib/widgets/premium/mint_count_up.dart`. Sinon :

```dart
class MintCountUp extends StatefulWidget {
  final double value;
  final Duration duration;             // default 900ms
  final Duration startDelay;            // default 0
  final String Function(double) format; // default: fmtCHF
  final Object? trigger;                // change → relance l'anim
}

// Implémentation : AnimationController + Curves.easeOutCubic
// Format par défaut : séparateur ' (U+2019) milliers à la suisse
String fmtCHF(double v) => v.round().toString()
  .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '\u2019');
```

**Gotcha :** `trigger` doit recréer l'AnimationController ou au minimum `forward(from: 0)` pour re-animer quand l'utilisateur bouge un slider.

---

## MintReveal

**Rôle :** fade+slide-up 6px à l'apparition d'un message dans le chat.

```dart
class MintReveal extends StatelessWidget {
  final Widget child;
  final Duration delay;

  // TweenAnimationBuilder double 0 → 1 en 400ms Curves.easeOut
  // opacity = value, translateY = (1 - value) * 6
}
```

---

## Typing dots

3 points qui montent et descendent en décalage 150ms entre chaque.

```dart
class MintTypingDots extends StatefulWidget {
  // AnimationController 1.2s repeat
  // Chaque dot: opacity 0.3 → 1 → 0.3, translateY 0 → -3 → 0
  // Dot i décalé de i * 150ms
}
```

Container fond `craie`, borderRadius 18 avec coin bas-gauche 6 (asymétrique), padding 12×16.

---

## Canvas slide-up (ouverture)

Voir `03-components.md` §MintCanvasProjection — `PageRouteBuilder` + slide + fade 350ms `Curves.easeOutCubic`.

---

## Slider live feedback

Quand l'utilisateur bouge un slider dans une scène :
1. Le chiffre change instantanément (tabular-nums, `fontVariantNumeric: 'tabular-nums'` équivalent : `StrutStyle` + `TextStyle.fontFeatures = [FontFeature.tabularFigures()]`)
2. La colonne mise en valeur change → `AnimatedContainer` 300ms `Curves.ease`
3. Le fill du slider track change de couleur → `AnimatedContainer` 300ms

**Pas de count-up sur interaction live** — trop lent, l'utilisateur veut le retour immédiat. Le count-up sert uniquement à l'apparition de la scène.

---

## Récap timings

| Moment | Durée | Courbe |
|---|---|---|
| Apparition bulle / insight / scène | 400ms | easeOut |
| Count-up chiffre | 800-900ms | easeOutCubic |
| Canvas slide-up | 350ms | easeOutCubic |
| Slider feedback (color change) | 300ms | ease |
| Typing dots cycle | 1200ms repeat | ease in-out |

---

## Conversation auto-play (démo uniquement)

Dans le prototype, la conversation se joue toute seule avec des delays entre steps. **En production, ne pas reproduire ça** — chaque message MINT apparaît quand le backend répond. Le `typing` est déclenché côté client dès qu'une requête part, remplacé par le vrai message à la réception.

Les délais du prototype (pour référence, à titre d'indicateur de rythme perçu) :
```
user → typing: 400ms
typing → mint text: 900ms (court) à 1800ms (long)
mint text → scene: 600ms
user interaction → typing: 700ms
```

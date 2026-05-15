# 01 — Vision : le chat vivant

## Le problème qu'on résout

Aujourd'hui le chat MINT fait du texte. L'utilisateur demande "rente ou capital ?", MINT répond en 200 mots, puis dit "ouvre l'écran X pour creuser". C'est une **rupture**. L'utilisateur doit quitter la conversation pour voir les chiffres.

Claude.ai a résolu ça : quand tu demandes un graphe, il **dessine dans la conversation**. Pas de rupture. Le texte et le visuel forment un seul fil de pensée.

**MINT doit faire pareil** — à l'échelle de la finance personnelle suisse.

---

## Les 3 niveaux de projection

Chaque réponse MINT peut contenir un ou plusieurs de ces éléments, intercalés avec du texte conversationnel.

### Niveau 1 — L'insight inline
**Équivalent Claude :** un tableau court dans une réponse.

Une petite carte éditoriale posée dans la bulle MINT. Label court en `corailDiscret` majuscules, un grand chiffre ou une phrase-signature Fraunces, un supporting text optionnel. Fond `porcelaine` ou `saugeClaire` selon le ton (neutre vs positif).

**Exemples :**
- "63% — c'est ce que tu gardes." (ratio train de vie)
- "Tu n'as pas besoin de choisir tout de suite. Tu dois décider 3 ans avant." (insight éditorial)

**Widget Flutter :** `MintInlineInsightCard`, `MintRatioCard`.

### Niveau 2 — La scène projetée
**Équivalent Claude :** un graphe matplotlib rendu inline, interactif.

Une carte plein-largeur dans le flux chat. Header éditorial (eyebrow + phrase-signature), chiffres côte-à-côte, widget interactif (slider, toggle), phrase de recul, CTA "Creuser" noir.

**Exemples :**
- `MintSceneRenteCapital` — slider âge d'espérance de vie, deux colonnes Rente/Capital qui bougent en live.
- `MintSceneRachatLPP` — slider montant rachat, deux chiffres (économie fiscale, rente gagnée) avec count-up.

**Invariant :** la scène **répond déjà à la question**. Le canvas (niveau 3) est optionnel, pour creuser.

### Niveau 3 — Le canvas plein écran
**Équivalent Claude :** un artifact qui s'ouvre.

Se déplie en slide-up depuis le chat. Structure éditoriale : 4 chapitres numérotés (01, 02, 03, 04), chaque chapitre est une carte blanche avec son titre, son contenu dense (chiffres, sliders, micro-tables), et ses hypothèses en pied.

Le canvas **se ferme** avec un verdict éditorial (fond `textPrimary`, accent `pecheDouce`), et un CTA "Revenir au fil — avec ce que je viens de voir". Ce retour doit **passer le contexte** au chat : la prochaine réplique MINT peut dire "tu as regardé à 85 ans + 4% rendement, voici ce que j'en retiens".

---

## La grammaire éditoriale

### Tons et couleurs
| Moment | Fond | Accent | Exemple |
|---|---|---|---|
| Conversation calme | `craie` (#FCFBF8) | — | Fond du chat |
| Scène / insight | `porcelaine` (#F7F4EE) | `corailDiscret` (#E6855E) | Label majuscules, mots-clés |
| Bonne nouvelle | `saugeClaire` (#D8E4DB) | `successAaa` (#0F5E28) | Insights positifs |
| Accent chaud | `pecheDouce` (#F5C8AE) | — | Verdict sur fond sombre |
| Verdict / mise en scène finale | `textPrimary` (#1D1D1F) | `pecheDouce` | Carte noire en fin de canvas |

### Typo
| Usage | Font | Style |
|---|---|---|
| Chiffres héros | Montserrat | `displayHero` / `displayLarge` |
| Titres écrans, sections | Montserrat | `headlineLarge/Medium/Small` |
| **Phrases-signature, em, labels "Aujourd'hui"** | **Fraunces** | **`editorialLarge/Body/Display` — à créer** |
| Body, UI standard | Inter | `bodyLarge/Medium/Small` |

### Micro-règles
- **Chaque scène a une "phrase de recul"** — sur fond `craie`, `bodySmall`, qui remet la donnée en perspective humaine.
- **Les hypothèses sont visibles** — en `micro` italique, sous une border dashed haute de 0.5px.
- **Les CTA dans les scènes** sont noirs, pas colorés — la scène elle-même porte la couleur.

---

## Ce qu'on évite

- **Les bulles grises par défaut** du chat actuel. La bulle MINT a un fond `craie` avec un avatar carré arrondi noir à gauche, typo éditoriale.
- **Les "voir dans l'onglet X"** renvois vers un écran. Si la question mérite un écran, la scène est posée dans le chat.
- **Les placeholders "data viz"** — pas de chart.js générique. Chaque visualisation est spécifique à son moment.
- **Les emoji.** Aucun, jamais.

---

## Le test de succès

Un utilisateur de 58 ans demande "rente ou capital ?" dans le chat. En 40 secondes de conversation, il a :
1. Compris qu'il y a deux options avec des logiques opposées.
2. Vu les chiffres qui le concernent (sa LPP, son âge).
3. Bougé un paramètre (espérance de vie) et vu le résultat en live.
4. Ouvert le canvas, creusé 30 secondes, et retrouvé le fil du chat avec son contexte préservé.

**Sans** avoir quitté la conversation une seule fois.

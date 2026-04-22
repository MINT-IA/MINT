# Panel 3 — Post-opener + Explorer timing (2026-04-22)

Cinq voix, deux questions, trois itérations visibles par question. Cohérence de voix : `OPENER-PHRASES-PANEL2.md`. Grammaire : `.planning/handoffs/chat-vivant-2026-04-19/03-components.md` (Niveaux 1/2/3).

Persona hypothétique pour peupler les teasers : **Julien, 34 ans, Lausanne, 90k CHF/an, pas de 3e pilier, loyer 2 100 CHF, pas d'enfant, célibataire.**

---

## Question 1 — Après « Il est temps que tu saches. », que montre-t-on ?

### Itération 1 — 5 concepts divergents

- **Motion (ex-Apple Weather/Linear)** : Trois cartes-teasers empilées légèrement, qui se révèlent en cascade (stagger 80 ms). Chacune anime UNE donnée en 1,2 s : un chiffre qui compte, une ligne qui pousse, un chip qui éclôt. Tap → ouverture Niveau 2 (scène). Budget motion : 60 fps, pas de shader lourd.

- **Product (ex-Things/Arc)** : Abandonner les chips. **Une seule carte-trailer** qui cycle entre 3 scènes toutes les 3,5 s, avec un swipe latéral pour forcer la suivante. Moins de choix = moins de charge cognitive après une phrase aussi frontale. La carte est la question, pas la réponse.

- **Info design (Bloomberg/Upshot)** : 4 pastilles 320×140, chacune est un **mini-graph statique-qui-vit** (sparkline qui se trace une fois, chiffre qui atterrit). Densité : titre 6 mots, 1 chiffre hero, 1 légende. Pas d'animation décorative, chaque pixel porte. Réf : Upshot « How much house can you afford ».

- **Trailer (ciné art-et-essai)** : Structure 3 secondes — **hook** (chiffre brut : « 247 000 CHF »), **twist** (contexte : « c'est ce que ton 3a te coûte de ne pas avoir »), **reveal** (action : « voir pourquoi »). Pas de pub, pas de promesse. Juste la tension. Une seule carte à la fois, séquence inévitable.

- **Philosopher (Muji/Herman Miller)** : **Rien.** Après la phrase, 2 s de silence, puis UNE carte unique qui respire. Pas de choix. Le coach propose, l'user accepte ou tape pour autre chose. « Moins d'options, plus de soin. » Dissidence inaugurale assumée.

### Itération 2 — débat + élimination

**Motion attaque Product** : « Un seul trailer cycling, c'est une pub de banque. L'user ne contrôle pas le rythme, il subit. On a dit pas de pub. »
**Product** : « Sauf que 4 chips plates = 4 décisions à prendre juste après une phrase qui dit *arrête de fuir*. C'est contradictoire. »
**Philosopher** coupe : « Les deux ont raison. La vraie erreur, c'est 4 options. Trois maximum, ou une. »

**Trailer attaque Info design** : « 4 pastilles denses = tableau de bord. On a dit que MINT n'est pas un dashboard. Après *Il est temps que tu saches*, un tableau Bloomberg c'est glacial. »
**Info design** : « La densité n'est pas froide si elle est habitée. Un chiffre personnel (247k CHF) dans une carte NYT, c'est plus chaud qu'un chip *Un papier que je ne comprends pas*. »
**Motion** : « D'accord si les cartes bougent. Statique = Bloomberg, vivant = NYT Upshot. »

**Philosopher** challenge son propre concept : « Une seule carte sans choix, c'est peut-être trop autoritaire juste après un opener autoritaire. Double-dose. »

**Éliminés** :
- ❌ **Product (carte unique cycling)** — risque de ressembler à une pub de banque, pas de contrôle user.
- ❌ **Philosopher (rien + 1 carte)** — double-autoritarisme après l'opener ; gèle l'user au moment où il faut lui donner une prise.

**Raffinés, restants** :
- **Motion** : cascade de cartes animées.
- **Info design** : densité NYT-Upshot habitée.
- **Trailer** : structure hook/twist/reveal par carte.

### Itération 3 — tranché

**Fusion Motion + Info design + Trailer** : **3 cartes-teasers**, pas 4. Chaque carte est un mini-trailer 3 secondes avec densité Upshot et animation Linear. L'user choisit laquelle ouvrir. Pas de cycling automatique.

**Proposition finale :**

- **Nombre de teasers** : **3** (pas 4 — Philosopher gagne sur ce point).
- **Disposition** : empilés verticalement, cartes 340×160, espacement 12 px, coins 16 px. Cascade de révélation stagger 80 ms après le message opener.
- **Durée animation par carte** : **1,4 s** (chiffre qui compte 600 ms + sparkline qui se trace 600 ms + label qui fade 200 ms). Une seule animation au mount, puis immobile. Pas de loop.
- **Contenu des 3 teasers (Julien-persona 34ans Lausanne 90k)** :
  1. **« Ton 3e pilier, si tu le lançais ce mois. »** — Chiffre hero : *247 000 CHF* qui s'incrémente de 0 à 247k en 600 ms (easing : cubic-bezier 0.2, 0.9, 0.3, 1). Sparkline 34→65 ans qui se trace. Légende : *à 65 ans, rendement moyen 2,5 %*. Tap → scène Niveau 2 (slider rendement + âge départ).
  2. **« Ton loyer, vu sur 30 ans. »** — Chiffre hero : *756 000 CHF* (2 100 × 12 × 30) qui compte. Barre horizontale qui se remplit, comparée à une barre « si tu achetais » (plus courte). Légende : *ce que tu paies à ton bailleur*. Tap → scène Niveau 2 (loyer vs achat, taux hypothécaire éditable).
  3. **« Ton impôt 2026, décomposé. »** — Donut qui se dessine en 600 ms (4 segments : fédéral / cantonal / communal / AVS). Chiffre hero au centre : *~16 400 CHF*. Légende : *Vaud, célibataire, 90k*. Tap → scène Niveau 2 (déductions 3a/rachat LPP simulables).
- **Palette** : fond carte `MintColors.surface`, chiffre hero `MintColors.primary`, sparkline `MintColors.accent`, légende `MintColors.textSecondary`. Aucun gradient, aucune ombre portée (Aesop).
- **Grammar Chat Vivant** : les 3 teasers sont des **Niveau 1 enrichis** (insight inline avec mini-dataviz embarquée). Tap = transition vers **Niveau 2** (scène projetée avec sliders). Respect strict de la doctrine 03-components.md.
- **Data source** : calculateurs `financial_core/` existants (avs_calculator, pillar3a_calculator, tax_calculator) appelés avec profil hypothétique par défaut tant que l'user n'a pas renseigné le sien. Disclaimer implicite via label *hypothèse Lausanne 34 ans 90k — ajuste quand tu veux*.

**Dev cost estimate (solo dev)** : **4 jours**. Jour 1 : widget `TeaserCard` avec animation chiffre + sparkline (reuse `AnimatedCounter` existant). Jour 2 : 3 variantes teaser + branchement calculateurs. Jour 3 : transition Niveau 1 → Niveau 2 (scène simulateur déjà existante, juste à câbler). Jour 4 : polish motion, tests golden Julien+Lauren, i18n 6 langues.

**Dissidence résiduelle** : Philosopher maintient que 3 reste 1 de trop — « 2 aurait suffi, le 3e dilue ». Noté, pas retenu (3 = minimum pour signaler la diversité des life events).

---

## Question 2 — Explorer tab timing

### Itération 1 — 5 positions divergentes

- **Motion** : Explorer toujours visible, **contenu qui se transforme**. Pré-profil = 3 teasers cycling. Post-profil = archive des scènes vues avec thumbnails animés au scroll. Pas de disparition de tab, c'est perturbant.

- **Product (Things/Arc)** : Explorer **caché** jusqu'à la première scène canvas fermée. Apparition avec un micro-rituel coach : *« Ce que tu viens de voir est rangé dans Explorer. »* Tab slide-in depuis le bas, 400 ms, haptic léger. L'UI grandit avec l'user, doctrine Things.

- **Info design** : Explorer **visible dès le départ mais grisé** (inactif), avec badge *« vide pour l'instant »*. Dès la 1re scène archivée, badge disparaît, tab devient actif. Honnête sur l'état, pas magique.

- **Trailer** : Explorer **absent** au début. Apparaît après 3 scènes vues (seuil narratif : une trilogie). Rituel coach fort : *« Tu as vu trois choses. Je les garde ici. »* Tension dramatique construite.

- **Philosopher** : Explorer **n'existe pas comme tab**. L'archive vit dans le chat (scroll back). Pourquoi dupliquer ? Moins d'options, plus de soin. Suppression pure.

### Itération 2 — débat + élimination

**Product attaque Philosopher** : « Scroll back dans un chat qui peut faire 2 000 messages après 3 mois = l'user ne retrouve rien. L'archive a besoin d'un lieu. Things a un Inbox + une archive, c'est pas dupliqué, c'est stratifié. »
**Philosopher concède à moitié** : « D'accord pour un lieu, mais pas un tab permanent. Un accès depuis le menu coach. »

**Info design attaque Trailer** : « Seuil 3 scènes = arbitraire. Et si l'user fait sa 2e scène 3 semaines après la 1re ? Le rituel tombe à plat. »
**Trailer** : « Alors 1 scène, pas 3. Le rituel vaut mieux à la 1re. »

**Motion attaque Product** : « Tab qui slide-in après coup = petite violation du shell. L'user vérifie sa barre de tabs 30 fois par session, si elle change, c'est un micro-choc. »
**Product** : « C'est le POINT. Micro-choc intentionnel = moment mémorable. Arc fait ça avec les Spaces qui apparaissent. Things fait ça avec les Tags. »
**Motion** cède : « OK si l'animation est soignée (400 ms, ease-out, haptic light). »

**Info design attaque sa propre idée (grisé dès départ)** : « Un tab grisé *vide pour l'instant* contredit *Il est temps que tu saches*. Ça dit *pas encore*, alors que l'opener dit *maintenant*. »

**Éliminés** :
- ❌ **Philosopher (pas de tab du tout)** — l'archive a besoin d'un lieu stable pour être retrouvable.
- ❌ **Info design (grisé dès départ)** — contredit l'énergie de l'opener, signale du vide plutôt que de la promesse.
- ❌ **Trailer (seuil 3 scènes)** — rythme trop lent, l'user peut décrocher avant.

**Restants** :
- **Motion** : toujours visible, contenu transformé.
- **Product** : caché puis apparition rituelle après 1re scène archivée.

### Itération 3 — tranché

**Débat final** : toujours visible vs apparition rituelle ?

Motion : « L'user regarde les 4 tabs à l'ouverture comme une promesse du territoire. Si Explorer manque, il sent un manque. »
Product : « Non, il voit 3 tabs et les habite. Quand le 4e arrive, c'est un cadeau, pas un manque comblé. »
Trailer (revenu pour trancher) : « Un trailer qui promet trop au début s'éteint. Un trailer qui construit gagne. Product a raison sur la narration. »

**Décision : Product gagne. Explorer caché, apparaît après la 1re scène Niveau 3 (canvas plein écran) fermée.**

**Proposition finale :**

- **Mode d'apparition** : **Caché au démarrage.** 3 tabs visibles : Aujourd'hui / Mon argent / Coach.
- **Seuil exact** : **1re fermeture d'un canvas Niveau 3** (scène plein écran). Pas Niveau 2 (scène inline) — trop léger, trop fréquent. Pas 3 scènes — trop lent. Le canvas Niveau 3 = moment où l'user s'est engagé en profondeur dans un simulateur, il mérite un lieu pour y revenir.
- **Animation/rituel** : Bulle coach dans le chat : *« Je range ce que tu viens de voir dans Explorer. »* (registre manifeste, pas explicatif). 400 ms après, le tab **Explorer** slide-in depuis le bas (ease-out cubic-bezier 0.2, 0.9, 0.3, 1), avec haptic light iOS (`HapticFeedback.lightImpact`). Petite pastille `MintColors.accent` sur l'icône pendant 24 h ou jusqu'à 1er tap.
- **Contenu pré-profil (tab absent)** : n/a, le tab n'existe pas.
- **Contenu post-profil / post-1re-scène** : Liste chronologique inverse des scènes/canvases fermés, thumbnail 120×80 (snapshot dataviz), titre de la scène, date relative. Tap → ré-ouvre le canvas avec l'état exact où l'user l'avait laissé (slider positions, hypothèses). Archive vivante, pas musée. Réf : Arc Archive + Things Logbook.
- **Grammar Chat Vivant** : Explorer devient le **persistant Niveau 3** — le chat contient le Niveau 1/2, Explorer stocke les Niveau 3 retrouvables. Doctrine cohérente.

**Dev cost estimate (solo dev)** : **3 jours**. Jour 1 : logique d'apparition conditionnelle du tab (`MintShell` + état user `hasClosedFirstCanvas`), animation slide-in, haptic, persistance. Jour 2 : screen Explorer avec liste chronologique + thumbnails (reuse scene snapshot), tap → restore canvas state. Jour 3 : bulle coach du rituel, i18n, tests (incluant scénario user qui n'atteint jamais Niveau 3).

**Dissidence résiduelle** : Motion maintient qu'un shell à 3 tabs qui devient 4 est un micro-choc — accepte la décision mais demande que l'animation soit irréprochable sous peine de sentir « bricolé ».

---

## Synthèse pour Julien — 2 questions, 2 réponses, 3 décisions à valider

- **Q1 tranchée** : **3 cartes-teasers empilées** (pas 4 chips), chacune anime en 1,4 s un chiffre personnel hypothétique (247k 3a / 756k loyer / 16,4k impôt) avec mini-dataviz Upshot-style, tap → scène Niveau 2. Dev : 4 jours.
- **Q2 tranchée** : **Explorer caché au départ**, apparaît après la 1re fermeture de canvas Niveau 3 avec rituel coach *« Je range ce que tu viens de voir »* + slide-in 400 ms + haptic. Archive personnelle, pas catalogue. Dev : 3 jours.
- **Décisions à valider** : (1) OK pour 3 teasers à la place des 4 chips ? (2) OK seuil d'apparition Explorer = 1re fermeture canvas Niveau 3 (pas 1 scène N2, pas 3 scènes) ? (3) OK dev 7 jours au total pour les deux ?

---

PANEL3 prêt, Q1 tranchée: 3 cartes-teasers animées avec chiffres Julien-persona et tap vers Niveau 2, Q2 tranchée: Explorer caché au départ avec apparition rituelle après 1re fermeture de canvas Niveau 3.

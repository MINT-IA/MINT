---
description: D5 « évolution visible » — spec de la courbe de confiance sur « Ton histoire ». Le socle d'historisation existe (ConfidenceHistoryService) ; cette page cadre l'unité UI suivante (widget courbe + câblage + preuve runtime).
---

# D5 — Courbe de confiance « toi d'avant vs toi maintenant » (design)

Statut : **Proposed**. Cadre l'unité UI qui suit le socle d'historisation
livré dans `codex/journey-os-d5-evolution`.

## Ce que le socle fournit déjà (livré)

- `ConfidenceHistoryService` (`lib/services/confidence/confidence_history_service.dart`)
  persiste **localement** un `ConfidencePoint` daté par jour :
  `{date, combined, completeness, accuracy, freshness, understanding, trigger}`.
  Dédupliqué par jour (dernière mesure du jour gagne), plafonné à 90 jours,
  jamais synchronisé au backend.
- Points capturés à : l'hydratation du profil (`trigger: profile_load`, une
  fois par session, donne l'origine de la courbe), le scan de document
  (`document_scan`), et le check-in mensuel (`check_in`).
- `combined` = moyenne géométrique des 4 axes (`ConfidenceScorer.scoreEnhanced`).
- Effacé par le contrat de reset (`ReportPersistenceService.clearCoachHistory`).
- Lecture : `ConfidenceHistoryService.load()` → `List<ConfidencePoint>`
  (chronologique, plus ancien d'abord).

La matière première n'existait pas avant : le score était recalculé à chaque
rendu mais jamais daté ni persisté. La courbe est donc devenue possible.

## La surface

`aujourdhui_screen.dart`, section « Ton histoire » (le divider
`timelineSectionTitle`, aujourd'hui suivi des mois de la timeline vivante et
d'un état vide `timelineEmpty`). La courbe se place **en tête de cette
section**, au-dessus des mois — un `ConfidenceEvolutionCard` inséré comme un
`SliverToBoxAdapter`.

## Règle de rendu qui ne se casse jamais (principe 5 + critère de sortie D5)

Le critère de sortie D5 exige : « aucune régression possible de la progression
affichée par simple inaction ». Or `combined` **peut baisser** par inaction
(l'axe fraîcheur décroît quand la donnée vieillit). Donc :

> Le widget ne trace **pas** `combined` brut. Il trace une **série monotone
> non décroissante** : le **maximum courant** de `combined` (running max) au fil
> des points. Un utilisateur passif voit une courbe **plate** ; un utilisateur
> qui enrichit voit la courbe **monter**. Jamais de descente par inaction.

Le socle stocke les axes bruts (honnête, flexible) ; la monotonie est une
décision de présentation, portée par le widget — pas par le stockage.

## Design (synthèse des 4 lentilles à mener sur le widget avant push)

- **Air comme structure** (principe 11) : une carte sobre, tokens 8/16/24, une
  seule idée — « ta lucidité grandit ». Pas d'axe chargé, pas de grille dense.
  Une ligne, un point final marqué, un libellé de valeur discret.
- **Un chiffre d'abord** (principe 1) : le point le plus récent porte le
  `combined` courant en clair ; les axes restent en profondeur (tap → détail,
  réutiliser `MintTrameConfiance`), pas tout d'un coup.
- **Couleur = vocabulaire unique** (principe 9) : la courbe reprend **la seule**
  couleur sémantique de la confiance déjà utilisée par `MintTrameConfiance` /
  les cartes de confiance — ne pas inventer de palette. Réutiliser le mapping
  de niveau existant, ne pas le dupliquer.
- **Chaleur sans jugement** (principes 6-8) : mesuré en **compréhension**, pas en
  dépenses. Un jalon nommé, positif, tiré du `trigger` (ex. `document_scan` sur
  le 2e pilier → « Tu as éclairé ton 2e pilier le 12 mars »). Jamais « tu as
  laissé filer », jamais de compteur qui punit l'absence.
- **A11y** : `Semantics` sur la carte décrivant la tendance en mots
  (« ta confiance est passée de X à Y depuis mars ») ; la courbe seule ne doit
  pas être la seule information. Attention au repli AX iOS 26 sur les surfaces
  denses — garder la carte légère (voir mémoire AX).
- **LSFin** : aucun terme banni (« garanti », « optimal »…). Formuler en progrès
  de compréhension, pas en promesse de rendement.

## États

- **0 point** (profil vide / première ouverture) : ne rien afficher, ou reprendre
  l'invitation sobre existante (`timelineEmpty`) — pas de section vide (D4).
- **1 point** : un point simple + un libellé « reviens pour voir ta courbe
  grandir », sans tracer de ligne (une ligne exige ≥ 2 points).
- **≥ 2 points** : la courbe monotone + le jalon nommé le plus marquant.

## i18n (clés à créer, 6 ARB)

À définir avant implémentation, ex. : titre de carte (« Ta lucidité grandit »),
libellé de tendance, gabarit de jalon avec placeholders `{event}` + `{date}`,
libellé état 1-point. Toutes via `AppLocalizations` (jamais de littéral).

## Preuve runtime attendue (unité suivante)

Le socle est prouvé par tests unitaires + test provider (câblage
d'hydratation). La courbe, elle, est une surface financière visible → gate
runtime :

1. Seeder une persona avec ≥ 2 `ConfidencePoint` datés (backdatés) via le
   store local, puis rendre `aujourdhui` → capture montrant la courbe.
2. Preuve du critère de sortie D5 : sur sim, un enrichissement (scan) fait
   apparaître un avant/après visible ; kill + relance → la courbe persiste.
3. Widget test : ≥ 2 points → courbe rendue ; 0-1 point → état gracieux.

## Counter-arguments and data gaps

- **Vue opposée la plus forte** : une courbe de confiance peut se lire comme un
  score gamifié qui pousse à revenir pour le score lui-même, pas pour une vraie
  décision — exactement le travers « relevé qui culpabilise » que le principe 6
  cherche à éviter. Mitigation retenue : mesurer la compréhension (axes +
  jalons nommés), série monotone, zéro mécanique punitive. Si des tests montrent
  que la courbe crée une pression de fréquence sans valeur de décision, la
  réduire à un simple « depuis ton dernier passage » (rejoint D2).
- **Ce que cette page ne traite pas** : le choix exact du libellé de jalon par
  `trigger` (mapping event → phrase FR) ; le comportement multi-profils/couple ;
  le rendu quand la fraîcheur a fait chuter `combined` sous le max historique
  (la série monotone le masque, mais faut-il le signaler ailleurs ?). Aucune
  mesure utilisateur réelle ne valide encore que la courbe augmente la lucidité
  perçue.
- **Ce qui changerait la conclusion** : un verdict a11y défavorable sur la
  densité de la carte (repli AX iOS 26) → dégrader vers une ligne de texte de
  tendance sans graphe ; un signal produit que « montrer une courbe » n'aide pas
  la décision → remplacer par le rituel delta D2.

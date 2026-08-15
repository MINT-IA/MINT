---
description: Où en est MINT et quoi ensuite — en une page. Tranches verticales fermées, chacune finissant par quelque chose que la personne VOIT.
status: Active
date: 2026-08-14
---

# Feuille de route MINT

> **MINT est le copilote financier des personnes vivant en Suisse.** Il
> construit une représentation fiable de leur vie financière, la maintient à
> jour, et la transforme en explications, arbitrages et actions.

Ce document répond à deux questions, et à rien d'autre : **on en est où**, et
**quoi ensuite**. Le récit détaillé de la construction — et les défauts que
chaque branchement a révélés — est archivé dans
`.planning/audit/2026-08-14-journal-de-construction-du-jumeau.md`.

---

## Ce qui a changé le 2026-08-14 dans ma façon de travailler

Trois lectures indépendantes — un axe Codex sur le séquencement, la conduite de
chantier, l'expérience — ont convergé sur le même constat, après que Julien a
dit se sentir **perdu et enlisé**.

> Le principe « fondations d'abord » était juste. **L'ampleur ne l'était pas.**
> Il fallait la fondation sur UN fait, une tranche visible dessus, PUIS
> généraliser. Les cinq faits ont été généralisés avant la première tranche.

Et la phrase qui tranche : **« 11 122 tests verts et zéro écran, c'est un signal
qui ment. »**

**Ce que « aucune dette » veut dire désormais** : chaque tranche est complète et
nettoyée — pas « toute la fondation doit être finie avant toute valeur ». La
dette ne se prouve pas absente en empilant des gardes ; elle se prouve en
faisant passer une personne de bout en bout et en regardant ce qui casse.

---

## Où on en est

**Le jumeau financier fonctionne, pour deux faits.** Déclarer un logement ou un
revenu crée une **version** au lieu d'écraser ; corriger garde la trace de
l'ancien chiffre ; supprimer laisse une pierre tombale ; et le chiffre atteint
la déduction fiscale. Vérifié depuis un geste d'écran jusqu'au calcul, sur
appareil réel.

| Acquis | État |
|---|---|
| Registre append-only, enveloppe de 16 champs, temps métier ≠ temps d'enregistrement | ✅ |
| Faits multiples décomposés (un fait par versement 3a), réconciliation sans réécriture | ✅ |
| Frontière de commande — écriture ET suppression — pour 5 faits | ✅ |
| Jumeau **autorité** en production | ✅ logement, revenu · ⏸ 4 autres |
| Aller-retour vérifié mécaniquement pour chaque fait du catalogue | ✅ |
| Preuve d'exécution depuis le geste d'écran, sur la vraie pile | ✅ |

**Ce que la personne voit de tout ça aujourd'hui : rien.** C'est le problème.

---

## Ce que la première marche a trouvé (2026-08-14)

MINT a été parcouru **à la main, depuis l'accueil**, pour la première fois de la
session : intention → FATCA → nationalité → statut → famille → expatriation →
naissance → canton → revenu → projection → rente/capital.

**Ce qui marche, et qu'aucun test ne disait** : le parcours va au bout, et
« TON DOSSIER » se remplit **en direct** sous les questions — date de naissance,
canton, revenu net apparaissent au fur et à mesure. Le jumeau est déjà
perceptible, sans qu'on ait rien construit pour ça. Et l'écran rente/capital
porte **déjà un reçu de calcul** (`mobile_l1_arbitrage_engine`, version
`rvc-arbitra…`) : T2 a un précédent dans le produit.

**Quatre défauts que seule la marche pouvait montrer**, dans l'ordre de gravité
— un ordre que j'avais d'abord écrit faux, et qu'un axe Codex a démoli.

1. **L'application déclare l'hypothèse qu'elle a modélisée et tait celles qui
   dominent.** L'écran affiche « CHF 4'108 – 5'524 / mois dès 65 ans » avec
   « Hypothèse : rendement moyen 1,5 à 3,5 % » et deux articles de loi. Or dans
   `mint_scene_rente_trouee.dart` : le brut est **dérivé** du net (facteur
   1.17), l'avoir LPP déjà accumulé est présumé **nul** (`currentBalance: 0`),
   l'affiliation LPP n'est **jamais vérifiée**, et la fourchette annoncée
   mesure l'incertitude du **rendement de caisse** — pas celle de la carrière,
   qui la dépasse d'un ordre de grandeur.
   Une étiquette « carrière complète supposée » existe bien (ligne 166), mais
   elle est **conditionnée à `currentAge < 30`**. Pour la personne née en 1992
   que j'ai simulée — 34 ans — elle ne s'affiche pas, alors que supposer 44
   années de cotisation à quelqu'un qui en a treize reste tout autant une
   hypothèse. À 45 ou 55 ans, même silence.
   C'est **NEVER #9** (projection sans indicateur de confiance) et la phrase
   « voici ce qui arrive si tu ne bouges rien » est fausse : le calcul suppose
   précisément que beaucoup de choses continueront d'une manière déterminée.
2. ~~**La revendication de localité est une rupture de consentement.**~~
   **RETIRÉ le 2026-08-14, après vérification.** L'axe Codex classait
   « Anonyme · conservé sur cet appareil »
   (`diagnosticOnboardingTerminalAnonymousLocal`) comme « matériellement
   fausse ». Elle ne l'est pas : l'état vient d'un vrai drapeau
   (`auth_provider.dart:583-593`, quatre états dont `cloudSyncOn`), et
   `coach_profile_provider.dart:569-577` **saute effectivement** la poussée du
   profil en mode local, avec trace `profile_sync_skipped` / `cloud_sync_off`.
   Ce qui reste est une question de doctrine — MINT s'interdit les
   revendications de localité parce que le backend est cloud — pas un mensonge
   de l'application. Elle reste affichée au moment exact où la personne décide
   de créer un compte, ce qui vaut arbitrage, pas correctif d'urgence.

   **Et c'est la leçon la plus utile de ce lot** : j'ai vérifié la revendication
   de MINT et pas celle de Codex. Un axe adverse qui démolit un classement
   produit des affirmations aussi vérifiables que celles qu'il démolit. Le
   0-trust est symétrique, ou il n'est rien.
3. **Le seul parcours praticable n'existe qu'en français.** ~53 chaînes en dur
   sur 7 fichiers de `lib/screens/onboarding/mvp_wedge/`. MINT déclare six
   langues ; la Suisse est majoritairement germanophone. Bloqueur de
   distribution — mais un francophone peut s'en servir aujourd'hui, ce qui le
   place après les deux ruptures de vérité.
4. **Le garde-fou des accents est une liste de 14 mots.**
   `SCENE · TA RETRAITE PROJETEE` s'affiche, et `accent_lint_fr.py --file` rend
   `EXIT=0`. Une liste ne rattrape que ce que quelqu'un a déjà imaginé ; ce
   qu'une personne lit n'est pas borné. Le défaut visible est mineur ; ce qu'il
   révèle — aucun garde-fou généralisable — ne l'est pas.

**Ce que ce classement m'apprend sur ma propre lecture** : j'avais mis
l'i18n en tête parce qu'elle se compte (53 chaînes, 7 fichiers, 6 langues). Les
deux défauts plus graves ne se comptent pas — ils se lisent. Une métrique
disponible a chassé un jugement.

**Et ce que la marche a corrigé dans ma propre analyse** : la coque de
préversion **ne bloque pas** `/mint-next/vertical-3a` — son propriétaire est
`system`, et la coque ne ferme que `coach`, `explore` et l'onboarding legacy.
J'avais annoncé le contraire. L'écran est hors du parcours pour une autre
raison : ses deux points d'entrée vivent dans l'application principale
(`aujourdhui_screen.dart:563`, `mon_argent_screen.dart:907`), après le wedge.

---

## Ce qui a été fermé le 2026-08-14, après la marche

La marche a déclenché un chantier qui n'était dans aucune tranche, et qui
passe devant : **un écran affichait un chiffre qu'il ne savait pas défendre.**

**Le motif, qui compte plus que les défauts.** Statut d'emploi demandé puis
ignoré. État civil demandé puis ignoré. 13ᵉ rente AVS que `AvsCalculator`
savait annualiser sans que personne l'appelle. Aveu du proxy de carrière que le
pied de page de l'accueil formule déjà. **Quatre fois la même maladie : la
capacité existe, l'appel manque.** Le défaut n'était jamais dans le calcul — il
était dans une liste d'arguments. C'est la règle du jumeau prise à l'envers :
l'information rejoint bien le jumeau, et l'écran ne la consulte pas au retour.

| Fermé | Preuve |
|---|---|
| L'étiquette d'hypothèse de carrière s'affiche jusqu'à l'âge de référence, plus seulement avant 30 ans | `ad9843314` — et un test qui **gardait le mensonge** a été retourné |
| Le statut d'emploi atteint la scène : un indépendant ne se voit plus attribuer un 2ᵉ pilier | `b43a38226` |
| Le facteur brut/net suit le statut au lieu d'être toujours salarié | `b43a38226` |
| Le cumulé compte 13 rentes AVS et 12 LPP, au lieu de 12 pour tout le monde | `b43a38226` |
| Inventaire de vérité : 14 oracles, dont 5 invariants métamorphiques | `253f7c6fd` + `49a9601cc` |
| Lot sédiments : 3 chemins destructifs fermés dans l'élagueur, vérifiés par mutation | `600033188` |
| Doctrine multi-agent : un orchestrateur, un écrivain, auditeurs en quarantaine | `6bcd52de4` |

**Ce que Codex a changé, et que j'aurais raté seul** : j'allais mettre la
composante LPP à **zéro** pour un indépendant. Aussi faux que de la projeter —
`false` veut dire « non présumée », pas « prouvée absente » (adhésion
volontaire LPP art. 4, avoir de libre passage). L'écran dit désormais « 2e
pilier pas compté : on ne le connaît pas encore ». **Zéro aurait été une
affirmation ; l'absence est un aveu.**

**Ce qui reste ouvert sur cet écran, et qui n'est pas un mensonge mais un choix
de modèle** : l'avoir LPP accumulé reste présumé nul et n'est jamais demandé ;
le RAMD est approché par le salaire actuel alors que l'AVS moyenne un
historique revalorisé (LAVS art. 29quater, 30) ; le plafond de couple à 150 %
(art. 35) n'est pas appliqué — et le correctif honnête n'est PAS de câbler
`computeCouple`, qui exige un revenu du conjoint que MINT ne demande jamais,
mais de **dire** que la projection est individuelle ; la marge ±8 % compte deux
fois l'incertitude déjà portée par la fourchette 1,5–3,5 %.

---

## Où en est le travail, au 2026-08-15

**Le Lego en cours est la bascule 4 « première ouverture pure »**, pas les
tranches T1-T4 ci-dessous. Celles-ci restent le cap produit ; le Lego est ce
qui se construit maintenant, sous cadrage.

| Beat | État |
|---|---|
| `b4_owner_legacy` · `b4_policy_fail_closed` · `b4_entry_local` · `b4_registry_closure` | verts, hérités |
| `b4_reset_to_landing` · `b4_lifecycle` | **fermés le 14-15.08**, vérifiés par mutation |
| `b4_legacy_data_isolation` | ouvert — bloqué sur la branche de travail, prouvable depuis `dev` |
| `b4_cold_start_receipt` | ouvert — puits de trace, script et flot Maestro **à écrire** |

**Ce qui a été trouvé et qui dépasse le Lego** : `TwinBootstrap.ensureMigrated()`
promeut au démarrage les données wizard legacy en faits du jumeau — exactement
ce que le cadrage de la bascule 4 interdit. Absent de `dev`, donc la bascule 4
reconstruite depuis `dev` n'a pas la violation ; mais le Lego « fondation du
jumeau » devra porter la contrainte.

### Pourquoi il n'y a pas de loop autonome en ce moment

Un loop a tourné toute la journée du 14 et a **dérivé complètement** : son texte
était figé une semaine plus tôt, il a répété un ordre du jour mort, et le Lego
réel n'a pas été touché. Un second loop, sous **bail**, a bien fonctionné —
deux beats fermés, quatre rouges CI corrigées, une contradiction trouvée et
enregistrée *sans partir dessus*.

Julien a demandé d'en relancer un. Un axe adverse, sollicité en mode
pessimiste, a répondu **non**, avec deux raisons que j'ai vérifiées :

- le worktree dédié ne contient **ni le bail ni son garde** — l'endroit où le
  travail se ferait n'a aucune serrure ;
- le bail **s'autorisait lui-même** et son garde : un loop pouvait étendre sa
  propre laisse au milieu d'une tâche, ce que j'ai fait trois fois sans le voir.

> « Le lancer aujourd'hui serait remettre une autonomie forte derrière une
> serrure décorative. »

Trois refus ont été ajoutés au garde depuis (bail figé pendant le travail,
branche vérifiée, base vérifiée), tous testés par mutation. Ce qui manque
encore n'est pas à moi : **un superviseur extérieur au worktree, non modifiable
par l'agent**. Je peux resserrer ce qui réduit ma latitude ; je ne peux pas
écrire mon propre geôlier et prétendre qu'il tient.

---

## Quoi ensuite — tranches verticales, dans cet ordre

Chaque ligne finit par quelque chose de **visible**. On ne passe à la suivante
qu'une fois la précédente fermée et nettoyée.

### T1 — La marge 3a devient un chiffre qu'on peut lire

**Ce que la personne voit** : « Il te reste X CHF de versement 3a possible pour
2026. »

**Pourquoi en premier** : les versements 3a sont le seul fait déjà décomposé
**et** doté d'une frontière de commande ; l'écran et le calculateur existent
déjà sur disque, et une branche verte de 108 tests attend d'être fusionnée.
Coût marginal le plus bas pour la première valeur visible.

**État au 2026-08-14** — l'écran et le calculateur **existent déjà** sur la
branche courante, routés sous `/mint-next/vertical-3a`, derrière le drapeau
`enableMintNextVertical3a` qui vaut `false`. La branche non fusionnée n'est
donc pas le sujet : T1 se réduit à faire passer les versements 3a par le
jumeau, vérifier que le chiffre en vient, et allumer.

**✅ Les versements 3a sont possédés par le jumeau**, et la preuve part du geste
d'écran : déclarer deux versements donne un total lisible **tout de suite**,
corriger l'un n'écrit rien sur l'autre, et la correction survit au
rechargement.

**Une fausse alerte, corrigée** : j'avais annoncé un « défaut préexistant » —
le fait ressortait nul après sauvegarde. C'était **mon test** qui fabriquait le
fait à la main avec une table de révisions vide alors que ses versements
référençaient 2026 ; l'enregistrement canonique ressortait `corrupt`. Un écran
ne fabrique jamais ce fait de zéro : il part de `empty` et applique les
mutations, qui maintiennent la révision de chaque année touchée. Le test fait
désormais pareil — sinon il teste un objet que personne ne produit.

**Reste pour fermer T1** — et la marche a montré que ce n'est PAS une ligne.
J'ai allumé `enableMintNextVertical3a`, marché le parcours, et **je n'ai pas vu
l'écran** : le wedge ne passe pas par là. Ses deux points d'entrée sont dans
l'application principale (`aujourdhui_screen.dart:563`,
`mon_argent_screen.dart:907`), derrière la création de compte que je n'ai pas
faite. Je ne sais donc pas s'il s'affiche — je sais seulement que le drapeau ne
suffit pas.

**Le drapeau est reparti à `false`.** Un écran allumé que personne n'a vu
atteindre est une façade sans câblage — la doctrine #1 de MINT. Il se rallume
dans le lot qui prouve qu'on y arrive.

### T1, diagnostiqué pour de bon (2026-08-14, après lecture)

**L'écran de marge 3a est excellent, et c'est la découverte.** Il porte la
doctrine que l'écran de rente n'avait pas :

- entièrement traduit, contrairement au wedge ;
- une ligne de **fraîcheur** (date de la donnée la plus récente) et une ligne de
  **provenance** portant l'empreinte des constantes — donc **T2 a déjà un
  précédent fonctionnel ici**, il n'est pas à inventer ;
- il montre **versé** et **plafond** séparément, pas un total opaque ;
- trois états d'échec explicitement distingués, « jamais confondus » ;
- et surtout : `if (!lppAffiliationKnown) return
  'undetermined_lpp_affiliation_unknown'` avec le commentaire
  « **l'affiliation INCONNUE domine — jamais déduite du statut d'emploi** ».

Là où la scène de rente **déduisait en silence**, celle-ci **refuse de
déduire**. Le même projet a produit les deux doctrines opposées — et c'est la
prudente qui est restée derrière un drapeau éteint pendant que la négligente
tournait en production. C'est le constat le plus utile de la journée sur
l'ordre des tranches.

Mieux : quand l'affiliation manque, l'écran propose lui-même la route
`/mint-next/lpp-affiliation` pour aller la déclarer. La chaîne est complète et
se répare elle-même.

**Le vrai blocage n'est donc pas un drapeau, c'est QUATRE.**
`_mintNextLppAffiliation`, `_mintNextVersements3a` et `_mintNextMarge3a` valent
`PreviewShellPolicy.previewDefine`, c'est-à-dire
`bool.fromEnvironment('MINT_NEXT_PREVIEW')` — faux dans une compilation
normale. `_mintNextVertical3a` vaut `false` en dur.

Allumer le seul drapeau de destination éclairerait donc le point d'arrivée en
laissant ses trois alimentations éteintes : la personne atteindrait la marge,
lirait « affiliation inconnue », toucherait le bouton pour aller la déclarer —
et tomberait sur une route tuée par son propre drapeau. **Un cul-de-sac.**

**T1 se reformule** : allumer la chaîne entière dans l'ordre — affiliation,
versements, marge, vertical — et la marcher de bout en bout. Ce n'est plus une
ligne, mais ce n'est pas non plus un chantier : les quatre écrans existent, ils
consomment des faits du jumeau, et ils refusent de deviner.

**Ce qui reste à vérifier avant d'allumer** : un axe adverse lancé sur cet
écran a été tué par son délai avant de rendre son verdict — deuxième fois
aujourd'hui, malgré la clause « rends un verdict partiel ». Le taux de
lancements sans valeur passe donc à 3 sur 8, ce que l'ADR
`2026-08-14-un-orchestrateur-un-ecrivain-auditeurs-en-quarantaine.md` demande
précisément d'enregistrer.

### T2 — Un chiffre affiché dit d'où il vient

**Ce que la personne voit** : elle touche un montant, une feuille monte —
« Tu l'as dit le 14 août. Pour 2025. Avant : 1 800. » Une seule action :
corriger.

**Pourquoi à ce rang** : c'est la première fois que l'enveloppe devient
perceptible. Et c'est le différenciateur — pas le registre lui-même.

**Le piège à éviter** : construire un écran « Jumeau » avec timeline et
journal. La provenance est une **propriété des chiffres**, atteinte par un
geste — jamais une destination.

### T3 — Les promesses non tenues sont réparées

**Ce que la personne voit** : « Supprimer » efface vraiment ; « Modifier » dit
qu'une correction s'ajoute à l'historique.

**Pourquoi ça ne peut pas attendre** : depuis que les faits ont une histoire,
**« Supprimer » promet l'effacement alors qu'une pierre tombale garde la
valeur**. C'est une promesse non tenue qui touche le consentement. Même
famille : un chiffre affiché nu ment par omission quand son année est
inconnue ; et la complétude binaire (rempli / vide) est périmée depuis que six
états de connaissance existent.

### T4 — Un mini-plan, sur le 3a seulement

**Ce que la personne voit** : « Verse Y par mois d'ici au 31 décembre » — avec
l'objectif, la trajectoire, la prochaine action, et un indicateur d'avancement.

**Pourquoi en dernier** : la couche 3 suppose un fait entièrement historisé et
une décision qui tient. Prématuré avant T1.

---

## Ce qu'on arrête

- **Élargir la fondation aux faits qu'aucune tranche n'utilise.** Les 17
  écritures héritées sous cliquet attendront qu'une tranche les touche.
- **Compter les tests comme du progrès.** Ils prouvent qu'on n'a pas cassé ;
  ils ne prouvent pas qu'on a servi.
- **Écrire ce document comme un journal de bataille.** Il dit où on va.

---

## En attente, hors tranches

| Sujet | Pourquoi il attend |
|---|---|
| ~~Revendications de localité (6 clés orphelines)~~ | **Promu en tranche** : la marche en a trouvé une VIVANTE dans le parcours principal |
| Certificat Apple Development pour l'équipe du projet | Confort d'outillage ; le Keychain simulateur fonctionne sans lui |
| Propagation d'un changement de profil au backend, hors reprise de compte | Mesuré, corrigé pour la fusion ; l'horodatage d'ENVOI reste une approximation |
| Connexions bancaires | Dépend du consentement et de la résidence des données |

---

## Contre-arguments et lacunes

- *« Les fondations resteront utiles, donc le temps n'est pas perdu. »* Vrai, et
  insuffisant : quatre défauts sérieux de cette session ne sont sortis qu'au
  branchement. Il en reste de cette classe, et le lot de découverte grossit à
  chaque semaine de fondation supplémentaire sans usage.
- *« Une tranche visible d'abord aurait produit une fondation bancale. »*
  Possible. Mais la fondation actuelle a été validée par des **oracles**, jamais
  par un **usage** — et c'est l'usage qui a trouvé chaque défaut.
- ~~**Lacune** : personne n'a encore parcouru MINT de bout en bout.~~ **Fermée
  le 2026-08-14** — et elle a produit plus de constats en vingt minutes que la
  moitié de la session en fondation. C'est l'argument le plus fort pour l'ordre
  des tranches ci-dessus.
- **Nouvelle lacune, plus gênante** : le parcours a été marché en français
  seulement, sur un simulateur, par moi. Personne ne l'a marché en allemand —
  et pour cause, il n'existe pas en allemand.
- **Ce que la marche a révélé sur notre automatisation — le constat le plus
  gênant du lot.** J'ai marché à l'`idb` brut alors que la règle maison passe
  par Maestro. En vérifiant l'ampleur de ma faute, j'ai trouvé pire :
  `tools/simulator/flows/salvage01_retraite_onboarding_coach.yaml` **marche
  exactement ce parcours**, et choisit **la même date de naissance que moi**
  (15.07.1992). J'ai rejoué à la main un parcours déjà automatisé — et le flot
  n'avait vu aucun des défauts.

  Pourquoi : ses assertions sont `assertNotVisible: "Page introuvable"`,
  `"NoSuchMethodError"`, `"Ton âge: 2026"`, `"Dis-moi."`, plus deux identifiants
  de route et d'âge. **Toutes vérifient qu'il ne s'est rien passé de
  catastrophique. Aucune ne regarde ce que la personne lit.**

  C'est la classe d'automatisation qui prouve l'absence de plantage et l'appelle
  qualité. Elle explique comment 11 122 tests et un flot de bout en bout ont
  coexisté avec un écran qui annonce un chiffre à quarante ans en taisant
  l'hypothèse qui le porte. Le lot à ouvrir n'est donc pas « écrire un flot
  Maestro » — il existe — mais **lui faire assurer ce qui est lu**, pas
  seulement ce qui n'a pas planté.
- *« Le monolinguisme est de l'i18n, pas un défaut produit. »* C'est la lecture
  confortable. La lecture réaliste : un utilisateur zurichois qui ouvre MINT
  aujourd'hui ne peut pas s'en servir. Le classer en hygiène, c'est décider que
  ce n'est pas grave.

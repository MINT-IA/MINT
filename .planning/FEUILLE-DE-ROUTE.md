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
- **Lacune d'outillage, à ma charge** : la marche a été faite à l'`idb` brut,
  alors que la règle maison dit que les preuves de simulateur passent par
  Maestro (`tools/simulator/flows/`). Un parcours marché à la main ne se rejoue
  pas, ne tourne pas en CI, et disparaît avec la session. Ce parcours doit
  devenir un flot Maestro — sinon les quatre défauts trouvés aujourd'hui
  peuvent revenir sans que rien ne le signale.
- *« Le monolinguisme est de l'i18n, pas un défaut produit. »* C'est la lecture
  confortable. La lecture réaliste : un utilisateur zurichois qui ouvre MINT
  aujourd'hui ne peut pas s'en servir. Le classer en hygiène, c'est décider que
  ce n'est pas grave.

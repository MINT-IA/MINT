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

**Reste pour fermer T1** : allumer `enableMintNextVertical3a`. Une ligne, et
c'est une décision produit — rendre un écran visible — pas une décision
technique.

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
| Revendications de localité restantes (6 clés orphelines) + garde qui les rate | Lot séparé, avant toute distribution — pas dans une tranche produit |
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
- **Lacune** : personne n'a encore parcouru MINT de bout en bout, à la main,
  depuis l'accueil. Toutes les preuves partent d'un appel de code.

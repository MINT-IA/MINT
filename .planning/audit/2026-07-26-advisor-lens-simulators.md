---
description: Revue Codex « conseiller financier VZ / private banking 2026 » des simulateurs de vie — 11 constats CRITIQUES de vérité métier, dont deux règles juridiques inexistantes (entretien après divorce, liquidation du régime matrimonial).
---

# Audit lentille conseiller — simulateurs de vie (2026-07-26)

## TLDR

Après la clôture du chantier P2 « gate dur » (aucun chiffre affiché sur un défaut
fabriqué), une revue adversariale d'un autre type a été lancée à la demande de
Julien : **Codex CLI en rôle de conseiller patrimonial suisse senior (niveau VZ
VermögensZentrum / private banking 2026)**, sur la logique métier et non sur le
code.

Verdict exécutif de la revue : *« ces simulateurs ne sont pas encore utilisables
en conseil client au standard VZ/private-banking »*. Le gate-dur garantit que les
chiffres proviennent de **données réelles de l'utilisateur** ; la revue montre que
plusieurs simulateurs appliquent à ces données des **règles qui n'existent pas en
droit suisse**. C'est une classe de défaut plus grave que la fabrication d'entrée.

## Pourquoi cette revue existe

Le gate-dur répond à : « ce chiffre vient-il d'une donnée réelle ? ». Il ne répond
pas à : « la règle appliquée à cette donnée est-elle juste ? ». Un simulateur peut
être parfaitement gaté et rester trompeur si le modèle métier est faux. La lentille
conseiller ferme cet angle mort.

## Constats CRITIQUES (11)

### P0 — règles juridiques inexistantes

1. **Divorce — l'entretien n'est pas un calcul suisse** (`life_events_service.dart:274-296`).
   Le moteur pose : CHF 600 par enfant (sans âge, garde ni besoins), 8 % ou 15 % de
   l'écart de revenu pour l'entretien du conjoint, et des seuils de droit à 5 et
   10 ans de mariage. Aucune règle suisse ne fonctionne ainsi. Une évaluation réelle
   exige au minimum : revenus disponibles **nets**, minimum vital (LP/droit de la
   famille), logement, assurance maladie, frais de garde et de formation, taux de
   garde, train de vie, capacité de gain, clean-break, traitement fiscal et
   allocations familiales. **Risque client :** négocier ou accepter une convention
   autour d'un montant entièrement artificiel.

2. **Divorce — la liquidation du régime matrimonial applique des règles qui n'existent pas**
   (`life_events_service.dart:208-232`). Partage 50/50 de « fortune commune − dettes »
   sous participation aux acquêts **et** sous communauté ; sous **séparation de biens**,
   répartition **proportionnelle aux revenus**. Les proportions de revenu ne
   déterminent pas la propriété. La participation aux acquêts exige quatre masses
   (biens propres et acquêts de chaque époux), l'attribution des dettes à la bonne
   masse et les récompenses. **Risque client :** peut inverser qui est créancier, de
   plusieurs centaines de milliers de francs (immobilier, héritages, entreprise,
   biens pré-maritaux).

### Autres constats critiques

3. Divorce — le partage LPP omet les intérêts et la date de valorisation légale.
4. Mariage/concubinage — le label « pénalité / bonus » fiscal n'est pas défendable
   avec la finesse actuelle du moteur.
5. Concubinage — l'impôt de succession est un pourcentage forfaitaire de la fortune
   totale, sans modélisation légale (réserve, quotité disponible, héritiers).
6. Divorce — la fiscalité post-divorce ignore l'entretien, la garde et les domiciles
   futurs.
7. Concubinage — l'explication de la clause bénéficiaire 3a est juridiquement
   incomplète.
8. Concubinage — la protection LPP du concubin est mal décrite (beaucoup de caisses
   exigent une déclaration écrite + 5 ans de ménage commun).
9. Concubinage — le score à pondération égale relève de la pseudo-recommandation.
10. Gender gap — modélise le **minimum LPP**, pas le plan de prévoyance réel du
    client (données du certificat nécessaires).
11. Gender gap — plafond 3a périmé et formulation de recommandation trop directive.

## Ce qui a été confirmé correct

- Constantes LPP 2026 : déduction de coordination CHF 26'460, seuil d'entrée
  CHF 22'680, taux d'intérêt minimal 1.25 %.
- Nuance 2026 retenue : l'imposition individuelle a été acceptée le 8 mars 2026
  mais n'entrera en vigueur que vers 2032 — l'imposition commune reste la référence
  actuelle.

## TOP 3 des chantiers à plus forte valeur client

1. **Découper le divorce en trois modules juridiquement distincts** : partage LPP
   confirmé par l'institution, liquidation du régime au niveau des actifs, budgets
   d'entretien à deux ménages. Supprimer les formules actuelles d'entretien et de
   répartition proportionnelle aux revenus.
2. **Construire une vraie couche fiscale / scénarios de ménage** (revenu imposable,
   commune, déductions réelles, garde, allocation de l'entretien). En attendant,
   retirer les estimations ponctuelles « bonus / pénalité ».
3. **Faire des certificats et de la composition patrimoniale la colonne vertébrale
   du conseil** : données du plan de prévoyance pour gender gap / survivant ;
   propriété des actifs, héritiers, réserves et hiérarchie des bénéficiaires pour
   concubinage / mariage. Afficher des **fourchettes de scénarios** et un « qu'est-ce
   qui changerait cela matériellement », pas des réponses à un seul chiffre.

## Contre-arguments et limites de cet audit

- **La revue est probabiliste.** Codex n'est pas un juriste ; ses citations
  d'articles doivent être re-vérifiées avant toute implémentation. Le protocole
  0-TRUST s'applique à cet audit comme au reste : chaque constat doit être confirmé
  contre la source légale avant de coder un correctif.
- **Le périmètre produit n'est pas celui d'un conseil.** MINT est un outil
  **éducatif** (LSFin), pas un mandat de conseil. Une partie des « omissions »
  relevées (inventaire d'actifs, minimum vital, données de caisse) supposent un
  niveau de collecte de données que le produit n'a pas encore et n'assume peut-être
  pas. Le standard VZ est une cible de qualité, pas une obligation réglementaire.
- **Le risque de sur-correction est réel.** Remplacer un chiffre faux par un
  formulaire de vingt champs peut détruire l'usage sans gagner en vérité. La
  direction retenue — supprimer le chiffre indéfendable, énoncer les facteurs qui
  décident, renvoyer au spécialiste — est le compromis choisi.
- **Données manquantes :** la revue n'a pas pu vérifier les barèmes cantonaux de
  succession ni les pratiques de caisses (déclaration concubin) contre des sources
  primaires ; ces points restent à confirmer.

## Suites

- Beads P0 : constat 1 (entretien) et constat 2 (liquidation du régime).
- Bead P1 : les neuf autres constats.
- Prompt de la revue conservé pour réutilisation : lentille conseiller à relancer
  après chaque changement de logique métier significatif.

---

## Journal de vérification (2026-07-26, après-midi)

> **À lire AVANT de rouvrir un constat de cette page.** Chacun des onze constats
> a été confronté au code. Plusieurs étaient faux. Rouvrir un constat déjà
> invalidé ici coûte une demi-journée pour rien.

### Constats INVALIDÉS — ne pas corriger

| Constat | Ce que dit la vérification |
|---|---|
| #11 « plafond 3a périmé » | **Faux.** Le code lit le registre : `reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp)` = 36'288, conforme à OPP3 art. 7 al. 2. Seul le *commentaire* de `segments_service.dart:726` porte encore l'ancienne valeur 35'280. Bug de commentaire, pas de calcul. |
| `7'056` dans `coach_profile_seeds.dart` | **Faux positif.** C'est l'ancien plafond 2022, mais `activeSeed` est court-circuité par `kReleaseMode` : les builds de production reçoivent `null`. Aucun utilisateur n'y est exposé. Seed de debug et de walker uniquement. |
| #11 « formulation trop directive » sur gender gap | **Mal attribué.** Les recommandations de gender gap sont saines (« Explorer une augmentation du taux d'activité », « Vérifier la proratisation »). Les impératifs prescriptifs (« Souscrire une assurance IJM », « Souscrire une assurance LAA ») sont dans le parcours **indépendant**, pas ici. Chantier distinct : prescription de produit. |
| Plafond du salaire coordonné LPP absent | **Faux — constat produit par la revue Codex elle-même.** Le plafond existe : `LppCalculator.computeSalaireCoordonne` borne par `lpp.max_coordinated_salary`, et `lppSalaireCoordMax = 64260.0` (= 90'720 − 26'460), exactement la valeur réclamée. |

**Le relecteur expert se trompe aussi.** Deux des constats invalidés ci-dessus
proviennent de la revue Codex. Le protocole 0-TRUST s'applique à l'auditeur au
même titre qu'au code : un constat n'est pas un fait tant qu'il n'a pas été
confronté à la source.

### Constats CONFIRMÉS et traités

| Constat | Traitement | Preuve |
|---|---|---|
| #4 label « pénalité / bonus » | Remplacé par la mécanique et le sens de l'écart, sans qualificatif de valeur, plus une note de limite du modèle. Ligne « Impôts » de la matrice passée en neutre, montant privé de son signe et de son rouge/vert — la couleur était la version chromatique du verdict. | PR #1053, `mergedAt=2026-07-26T14:06:13Z` |
| #9 score à pondération égale | Retiré sans remplacement. Deux verdicts dormants trouvés au passage : `fiscalAdvantage` (aucun consommateur) et un **second** compteur agrégé interne au widget, invisible au grep parce qu'il dérivait le gagnant des `advantage` de chaque ligne. | idem |
| #7 clause bénéficiaire 3a | Déjà fermé par un travail antérieur : la carte conditionnelle cite OPP3 art. 2 et l'ordre légal des bénéficiaires. | `concubinage3aClauseEducational` |
| #8 protection LPP du concubin | Partiellement fermé : le texte renvoie à l'inscription auprès de la caisse et mentionne les conditions de ménage commun. Reste vague sur l'exigence de déclaration écrite et la durée. | `concubinageChecklist2Desc` |

### Constats CONFIRMÉS, en cours

- **#5 impôt successoral.** Trois défauts distincts, tous établis contre le code :
  1. la base est `patrimoine * taux`, soit **100 % du patrimoine**, alors que la
     réserve des descendants plafonne le legs à la moitié de la succession nette
     (CC art. 470-471, révision entrée en vigueur le 1.1.2023) — et qu'un bien en
     copropriété n'entre dans la succession que pour la quote-part du défunt ;
  2. le texte pédagogique annonce « souvent entre 20 % et 40 % » alors que la
     table `_inheritanceTaxRatesNonMarie` **du même fichier** va de 0.00 à 0.25,
     Schwyz et Obwald ne prélevant rien. **Le texte contredit ses propres
     données** ;
  3. « CC art. 462 » est cité pour une exonération **fiscale**. Cet article règle
     la part successorale **civile** du conjoint. L'exonération découle des lois
     fiscales **cantonales**, et elle vaut dans **tous** les cantons.
- **#10 modèle LPP de gender gap.** Le calcul emploie le régime obligatoire
  minimal — salaire coordonné légal et taux de conversion minimal de 6.8 % — ce
  qui n'est pas le règlement de la caisse de l'utilisateur. L'écran divulgue le
  rendement et l'horizon, jamais le modèle. Nuance à retenir : appliquer 6.8 % à
  la totalité du capital peut aussi **surestimer**, les caisses enveloppantes
  appliquant souvent un taux plus bas sur l'ensemble.

### Un défaut d'une autre nature, trouvé en cherchant à prouver

En tentant de constater sur simulateur le cluster fiscal **déverrouillé**, un
plantage est apparu : valider un montant faisait crasher l'app en debug.

Deux défauts superposés, le second masqué par le premier — l'ordre
`onChanged` puis `pop` d'une part, un `TextEditingController` libéré dès le `pop`
alors que l'animation de sortie reconstruit encore le champ d'autre part. Cause
de fond commune : un objet à cycle de vie confié à un `StatelessWidget`.

L'assert n'existant qu'en debug, l'incident était invisible en release. Mais il
rendait **tout fait saisissable inconfirmable sur simulateur**, donc la preuve
device des écrans « gate dur » mécaniquement impossible — sur les **17 fichiers**
qui dépendent de `MintAmountField`. Corrigé et prouvé par test dans la même PR.

**Leçon de méthode :** chercher à prouver un travail révèle des défauts que
relire le code ne révèle pas. L'obstacle rencontré en cours de vérification vaut
souvent plus que ce qu'on cherchait à vérifier.

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

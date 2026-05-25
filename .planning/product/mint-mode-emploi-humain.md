description: Mode d'emploi produit pour comprendre comment MINT doit fonctionner pour un utilisateur humain.

# MINT — mode d'emploi humain

Ce document décrit le fonctionnement attendu de MINT côté utilisateur. Il sert de boussole produit pour relier navigation, chat, données financières, budget, projections et plans suivis dans le temps.

## Le principe

MINT doit aider une personne en Suisse à voir sa situation financière actuelle, comprendre les arbitrages devant elle, puis suivre un plan concret de A vers B.

Le chat n'est pas seulement un support. C'est un navigateur intelligent au-dessus des mêmes données que les écrans. Il doit pouvoir dire : « voici ce que je sais », « voici ce qui manque », « voici l'effet possible de ce choix », puis ouvrir le bon écran ou la bonne action.

## Parcours naturel

1. L'utilisateur arrive dans MINT.
2. Il choisit de parler à Mint, de continuer sans compte, ou de se connecter.
3. MINT capture progressivement les faits structurants : âge, canton, revenu, logement, LAMal, dettes, liquidités, investissements, AVS, LPP, 3a, objectif.
4. Ces faits alimentent une situation financière lisible dans `Mon Argent`.
5. Le budget montre le flux mensuel : revenu, charges, futur, libre.
6. La trajectoire relie la situation actuelle à un objectif : achat, réserve, prévoyance, dette, fiscalité, famille, carrière.
7. Le chat explique les mêmes valeurs, demande les pièces manquantes, puis propose des actions concrètes.
8. Les calculateurs produisent les chiffres déterministes de niveau L1.
9. Les services backend produisent les comparaisons, éclairages et invariants de niveau L2-L4.
10. MINT revient régulièrement vers l'utilisateur avec l'état du plan : sur la trajectoire, en dérive, bloqué par donnée manquante, ou prêt pour la prochaine action.

## Écrans centraux

`Aujourd'hui` est la surface d'attention. Elle met en avant le cap du jour, les actions courtes, et le chat-as-verb.

`Mon Argent` est la situation financière structurée. Il doit montrer le libre mensuel, la fiabilité, le patrimoine net, les postes clés, les trois piliers suisses, et la trajectoire.

`Budget` est la vue de flux. Il doit rendre compréhensible ce qui entre, ce qui sort, ce qui part vers le futur, et ce qui reste disponible.

`Coach` est le navigateur conversationnel. Il doit toujours parler depuis le même contexte structuré que les écrans.

`Explorer` est la bibliothèque d'actions et de calculateurs. Elle reste secondaire : le chat et les cartes doivent y envoyer l'utilisateur quand une action précise devient pertinente.

## Données qui doivent être centrales

La situation financière et le budget sont le socle. Sans eux, le chat devient narratif, les widgets se contredisent, et les projections perdent leur ancrage.

Les valeurs prioritaires sont :

- identité financière : âge, canton, statut, ménage ;
- revenu : net mensuel, brut annuel, fréquence ;
- charges fixes : logement, LAMal, transport, télécom, électricité, santé, autres ;
- patrimoine : liquidités, investissements, dettes ;
- trois piliers : AVS, LPP, 3a ;
- objectif actif : type, montant, horizon ;
- trajectoire : capacité mensuelle, besoin mensuel, écart, prochain levier ;
- fiabilité : source, fraîcheur, degré de complétude.

## Règle d'architecture

Un fait utilisateur doit exister une seule fois en source canonique locale : `wizard_answers_v2`, puis `CoachProfile`, puis `MintUserState.dataSpineSnapshot`.

Les écrans, le chat et les calculateurs doivent lire ce même état. Ajouter un widget sans câblage à cette chaîne crée une façade.

## Ce que le chat doit savoir faire

Le chat doit :

- résumer les faits connus ;
- détecter les données manquantes ;
- expliquer une valeur affichée dans un écran ;
- ouvrir l'action adaptée ;
- mettre à jour une donnée quand le canal de capture est fiable ;
- distinguer saisie utilisateur, estimation, document scanné et donnée plus ancienne ;
- citer ou pointer vers les blocs de contexte quand il évoque des chiffres.

## Critère de fonctionnement

Un flow MINT fonctionne quand un utilisateur peut :

1. ouvrir MINT ;
2. voir sa situation dans `Mon Argent` ;
3. saisir ou corriger ses charges dans `Budget` ;
4. revenir au chat ;
5. demander « qu'est-ce que ça change pour moi ? » ;
6. recevoir une réponse cohérente avec les mêmes valeurs ;
7. lancer une action ou un calcul ;
8. retrouver la même situation après relance.

Les tests Maestro doivent couvrir ces transitions plutôt que seulement vérifier qu'un écran s'ouvre.

---
description: La commune détermine le canton — le fait « domicile » s'identifie par le numéro OFS, plus par un nom tapé. Registre fédéral embarqué (2110 communes, daté), sélection obligatoire, canton dérivé.
status: Proposed
date: 2026-08-13
---

# Identité communale : le numéro OFS plutôt qu'un nom tapé

## Le déclencheur

Julien, en regardant le parcours domicile : « Et si tu as la commune, tu as
automatiquement le canton… » Puis, sur la difficulté que cela soulève : « Il y a
peut-être des communes qui ont le même nom, mais on peut mettre entre
parenthèses les initiales du canton. »

Les deux remarques sont exactes. La seconde décrit, sans le savoir, la règle que
le registre fédéral applique déjà.

## Ce que le code faisait

`apps/mobile/lib/screens/mint_next_domicile/mint_next_domicile_screen.dart`
demandait deux choses : un canton dans une liste de 26, puis une commune en
**texte libre**, sans validation ni correspondance avec un référentiel.

Le modèle `MintNextDomicileFact` portait déjà un champ `communeBfs` — le numéro
OFS, l'identité fédérale. Vérification faite : **aucun écran ne l'écrivait
jamais**. Seuls des tests le renseignaient. En production, ce champ valait
toujours `null`. Le fait enregistré était donc un couple (canton choisi dans une
liste, chaîne de caractères tapée) que rien ne rattachait à une commune réelle.

## Ce qui a été mesuré

Tout ce qui suit est mesuré, pas estimé.

| Fait | Mesure | Source |
|---|---|---|
| Communes du registre fédéral | 2110 | instantané OFS au 13-08-2026 |
| Communes de notre jeu fiscal | 169, soit **8 %** | `commune_service.py` + `commune_multipliers.json` |
| Noms nus partagés par plusieurs communes | 35 noms, 77 communes | instantané OFS |
| Noms officiels portant déjà le suffixe cantonal | 152 | instantané OFS |
| Homonymes que le suffixe officiel ne distingue PAS | **0** | instantané OFS |
| Record d'homonymie | Rickenbach ×5 (ZH, LU, SO, TG, BL) | instantané OFS |
| NPA désignant plusieurs communes | 17 dans notre seul jeu (1212 → Genève *et* Lancy) | `commune_service.py` |
| Poids du registre complet embarqué | 63 Ko brut, 17 Ko compressé | fichier généré |

Deux conclusions tombent d'elles-mêmes.

D'abord, **la proposition de Julien est déjà la règle fédérale** : quand un nom
est partagé, le registre porte lui-même le suffixe cantonal dans le nom officiel
(« Rickenbach (LU) », « Bargen (BE) », « Lengnau (AG) »). Et cette règle est
mécaniquement complète : zéro cas résiduel où deux communes resteraient
indiscernables.

Ensuite, **le NPA n'est pas une clé**. Il désigne plusieurs communes, y compris
dans notre échantillon réduit. Toute dérivation passant par le code postal
produirait des attributions fausses.

## La source

Le registre vient de l'OFS directement :
`https://www.agvchapp.bfs.admin.ch/api/communes/snapshot?date=JJ-MM-AAAA`.

Ce choix n'est pas cosmétique. L'API tierce OpenPLZ, essayée d'abord, renvoyait
le 2026-08-13 **« Moutier BE 700 »** alors que la commune a été transférée au
Jura le 01.01.2026 et vaut désormais **JU 6831**. Le registre fédéral le dit
correctement. Un intermédiaire périmé aurait rattaché un habitant de Moutier au
mauvais canton fiscal, silencieusement.

C'est aussi ce qui justifie que le fichier porte sa date d'instantané : ce qu'il
décrit est vrai **à cette date**, pas éternellement.

## La décision

1. Le parcours ne demande plus qu'**une** information : la commune. Le canton en
   est dérivé, jamais saisi.
2. Ce qui est enregistré est le **numéro OFS**, plus le nom officiel et le canton
   dérivé. Un nom change, fusionne, se traduit ; le numéro est la clé qui
   survit — sauf transfert de canton, cas où il change lui aussi, d'où la date.
3. **Rien ne s'enregistre sans sélection** dans le registre. Un texte libre n'est
   pas une identité communale, et le laisser passer reviendrait à afficher plus
   tard des chiffres fondés sur une commune que MINT n'a jamais identifiée.
4. Les homonymes s'affichent avec le suffixe officiel **et** le canton en toutes
   lettres. Deux initiales ne parlent pas à tout le monde.
5. Un fait ancien sans numéro OFS **reste non résolu**. On ne lui invente pas une
   identité par correspondance de nom : rien ne prouve que le « Aarau » tapé un
   jour désignait la commune 4001.

## Ce que cela ne règle pas

Le registre d'**identité** couvre le pays. Les **paramètres fiscaux** — les
multiplicateurs communaux — n'existent que pour 169 communes. Les deux
référentiels sont désormais distincts, et c'est volontaire : MINT peut savoir
correctement où quelqu'un habite sans pouvoir calculer sa charge communale.

Un défaut existant a été relevé sans être corrigé ici, pour rester dans le
périmètre : `apps/mobile/lib/services/fiscal_service.dart:121-127` retombe
silencieusement sur la valeur cantonale quand le multiplicateur communal est
absent. Aucun message ne signale la substitution. C'est un chiffre présenté comme
communal alors qu'il ne l'est pas — exactement ce que l'axe données a rangé parmi
les comportements incorrects. À traiter dans un chantier dédié.

Second constat hors périmètre : `FamilyService.cantonNames` contient
`Geneve`, `Neuchatel`, `Bale-Ville`, `Bale-Campagne` sans accents, et ces
libellés sont affichés dans le sélecteur de canton de l'écran écart de rentes.
La règle d'accentuation du projet est violée sur une surface visible. Les mêmes
valeurs ont été corrigées dans `cantonFullNames` parce que le parcours domicile
en dépend désormais.

## Counter-arguments and data gaps

**Contre-argument 1 — « 63 Ko d'asset pour une information que l'utilisateur
connaît par cœur ».** Recevable sur le poids ressenti, faux sur le fond : sans
référentiel, il n'y a pas d'identité, et sans identité le fait n'est joignable ni
dans le temps ni avec les données fiscales. 63 Ko bruts, 17 Ko compressés, à
comparer aux 4,5 Ko du noyau de calcul pour un plafond de 100 Ko.

**Contre-argument 2 — « exiger une sélection va bloquer des gens ».** C'est le
risque principal. Quelqu'un dont la recherche échoue — orthographe, exonyme,
nom de hameau plutôt que de commune — se retrouve arrêté à la toute première
action de l'app. La couverture nationale réduit ce risque sans l'éliminer ; les
alias de recherche (« Morat » pour Murten, « Bienne » pour Biel/Bienne) le
réduisent encore. Il reste réel et il n'est pas mesuré.

**Contre-argument 3 — « le canton affiché après coup peut dérouter ».** Possible.
L'axe UX a tranché pour l'affichage, au motif que la personne doit pouvoir
vérifier la déduction plutôt que la subir. Non testé auprès d'utilisateurs.

**Lacune 1 — aucune preuve d'exécution.** Les oracles couvrent l'analyse du
fichier, la recherche, le cycle de sélection et la persistance de l'identité. Le
chargement réel de l'asset **sur appareil** n'est pas prouvé : `rootBundle` n'est
pas monté en test unitaire, et le test d'asset lit le fichier par le système de
fichiers. Tant qu'un passage sur simulateur n'est pas cité, « l'écran charge le
registre » reste une hypothèse.

**Lacune 2 — la liste des exonymes est courte et manuelle.** Onze entrées
vérifiées, tirées d'une note de recherche interne. Il en manque certainement.
Aucune source exhaustive n'a été trouvée pour les formes localisées des noms de
communes, le registre fédéral n'en portant qu'une seule par commune.

**Lacune 3 — la fraîcheur du registre n'est pas surveillée.** Le fichier porte sa
date, mais rien n'alerte quand il vieillit. Les fusions de communes se produisent
chaque 1er janvier. Aucun mécanisme ne signale qu'un fait enregistré pointe vers
une commune qui n'existe plus.

**Lacune 4 — la cohérence mobile/backend n'est pas garantie.** Le backend ne
connaît pas ce registre. Un numéro OFS enregistré côté mobile n'a aucun
répondant côté serveur aujourd'hui.

## Le chantier ouvert par la revue : les gens sans commune suisse

L'axe copie a relevé un défaut qui dépasse l'expérience. Un frontalier, ou toute
personne imposée à la source sans domicile fiscal en Suisse, n'a pas de commune
à indiquer. L'écran l'oblige pourtant à en choisir une pour avancer. Ce n'est
pas une friction : c'est **une donnée fausse enregistrée comme un fait**, chez
un public que la doctrine du projet range explicitement hors des cas limites
(huit archétypes, dont `cross_border` et `expat_us`).

La sortie manquante — « je n'ai pas de commune fiscale en Suisse » — n'est pas
qu'un bouton. Elle suppose un fait distinct, et une réponse à la question de ce
que l'écran d'ouverture propose ensuite à quelqu'un qui vient de la prendre :
sans cela, il redemanderait la commune à chaque ouverture, ce que le contrat de
la première ouverture interdit. Ce chantier est donc ouvert séparément plutôt
que traité à moitié.

## Provenance

Quatre passes Codex, sur des axes séparés. Avant écriture : UX/parcours et
données/intégrité référentielle, **REJET** tous deux sur la version naïve —
leurs conditions d'acceptation convergentes sont ce qui est implémenté.
Après écriture : code adversarial et copie/voix, **REJET** tous deux.

L'axe code a trouvé qu'une recherche gardant la ponctuation rate « St. Gallen »
dès que le point n'est pas tapé, qu'un asset tronqué passait pour un registre
chargé, qu'un échec de lecture laissait un écran mort sans explication ni
reprise, et que tous les oracles d'écran contournaient la branche asynchrone.
L'axe copie a trouvé que l'écran employait quatre formulations pour une seule
donnée, que la mention de provenance arrivait avant la première frappe où elle
n'aide personne, que « vérifie l'orthographe » accuse la personne d'une faute
que MINT n'a pas constatée, et le défaut frontalier ci-dessus.

Liens : `.planning/decisions/2026-08-03-doctrine-reconstruction-mint.md` ·
`product/mint_next/storyboard/domicile_fiscal.storyboard.json` ·
`.claude/agent-memory-local/mint-swiss-brain/reference_bfs_commune_mutations_datasources.md`

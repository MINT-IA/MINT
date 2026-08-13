---
description: La feuille de route vivante de MINT — ce qu'on construit, dans quel ordre, avec quelle preuve. Tenue à jour à chaque lot livré, jamais rétro-écrite.
status: Active
date: 2026-08-13
---

# Feuille de route MINT

> **MINT est le copilote financier des personnes vivant en Suisse.** Il
> construit progressivement une représentation fiable de leur vie financière,
> la maintient à jour, et la transforme en explications, arbitrages et actions.

Ce document est le seul endroit où l'on répond à « on en est où, et quoi
ensuite ». Il est mis à jour **à chaque lot livré**. Une ligne n'y devient
« fait » que si un reçu de vérification la couvre.

---

## La règle qui gouverne tout le reste

> **Aucun écran n'est terminé si les informations qu'il collecte ne rejoignent
> pas le jumeau financier, et si ses résultats ne peuvent pas être retrouvés et
> réutilisés ailleurs.**

Énoncée par Julien le 2026-08-13. Tant qu'elle est seulement écrite ici, elle
sera oubliée : le chantier **F3** ci-dessous la rend mécanique.

---

## Les trois couches, et où nous en sommes

| Couche | Question | État réel |
|---|---|---|
| **Comprendre** | « Où en suis-je ? » | 6 faits collectables, aucun historique |
| **Décider** | « Quelle option me convient ? » | moteurs déterministes existants, mal reliés aux faits |
| **Agir et suivre** | « Comment y arriver ? » | **rien** — pas de mini-plan, pas de trajectoire |

L'ordre est contraint : on ne peut pas suivre une trajectoire sans faits
historisés. Construire la couche 3 avant la couche 1 produirait des plans
fondés sur des données qui s'écrasent.

---

## Fondations — le jumeau financier

Sans elles, tout écran construit au-dessus fabrique de la dette.

| # | Chantier | Pourquoi maintenant | État |
|---|---|---|---|
| **F1** | **Historique des faits** — versions immuables ajoutées ; `asOf(instant)` répond à « que savait MINT alors » | Sans historique, impossible de suivre un déménagement, un mariage, un changement d'emploi. | ✅ **fait** — `f776d2ed1`, `451a694c8`, `9ff461e7f` · reçu `a941c25bd3` · 28 oracles |
| **F1b** | **Persistance durable** — une transaction liant le registre et sa projection | Sans elle, deux processus peuvent perdre une version ou en produire deux courantes. Nommé par la relecture comme le manque principal. | ⏳ prochain lot |
| **F1c** | **Migration v1** des six faits déjà écrits | Le registre reste théorique tant qu'il ne porte pas les faits réels. | ⏳ après F1b |
| **F2** | **Contexte porté par chaque fait** — enveloppe complète, plus un reçu de calcul citant les versions consommées | Un montant sans son année ni sa source ne peut alimenter aucun calcul honnête. | ✅ **fait avec F1** — et « sans date d'effet, la couverture est INCONNUE, pas supposée » |
| **F3** | **Le garde de la règle** — un contrôle mécanique qui échoue si un écran collecte sans rejoindre le jumeau | Une règle déclarative sera oubliée. Mesuré ailleurs : une consigne procédurale sans contrôle mécanique dégrade le résultat. | ⏳ après F1-F2 |
| **F4** | **Rebrancher les faits orphelins** — le logement est enregistré mais consommé nulle part | Vérifié le 2026-08-13 : le fait logement EST persisté, rechargé et visible dans « Ma situation » — mais absent de la frontière fiscale. Les intérêts hypothécaires n'atteignent aucun calcul. La donnée n'est pas perdue, elle est inerte. | ⏳ après F2 |

---

## Ce qui est réellement acquis

Vérifié, pas déclaré. Chaque ligne porte son commit.

| Acquis | Preuve |
|---|---|
| Le wizard historique ne peut plus s'ouvrir en préversion | `166fd2044` — propriétaire de route dédié, fail-closed, 11 chemins fermés |
| L'écran d'ouverture ne montre plus de catalogue avant le premier fait | `db78d11a0` — état éditorial, une seule action, refus sans relance |
| La commune détermine le canton, par identité fédérale | `7859ffa1d` — registre OFS 2110 communes daté, 35 homonymes distingués |
| Un nom tapé sans numéro OFS n'alimente aucun chiffre | `af2ffa436` |
| Un frontalier n'a plus à inventer une commune suisse | `946679393` — fait à deux états, sans valeur sentinelle |
| Aucun canton n'est fabriqué pour qui n'en a pas | `bd6787c08`, `ddd059f90`, `01b5c3598` — ZH, CH et le taux « national » supprimés |
| Le périmètre de vérification n'est plus un choix | `aa32dbc62`, `2066bf107` — 9 gates, reçu machine, garde de pré-envoi |
| Un frontalier ne se voit plus redemander son canton | `01b5c3598` — la complétude lit l'état du fait, plus la seule présence de la clé |
| Écrire un fait n'efface plus le précédent | `f776d2ed1` + `451a694c8` — registre en ajout seul, 28 oracles |
| 52 fichiers de test entrent enfin en intégration continue | `7ce7c2c67`, `a28ff0053` |

---

## Ce qui attend, et pourquoi pas maintenant

| Chantier | Pourquoi il attend |
|---|---|
| Date d'effet du domicile | Le lot refuse désormais les années antérieures à la déclaration plutôt que de mentir. Dégradation explicite, donc différable. |
| Table des mutations OFS | Provoque une demande de reconfirmation, pas un calcul faux. |
| Propagation du fait à deux états vers le backend | **Non différable** — le serveur peut conserver un canton explicitement invalidé. Prochain lot. |
| Lego C1 (éclairage marge 3a) | Branche verte à 108 tests, jamais fusionnée. À reprendre après les fondations. |
| Mini-plans | Couche 3. Dépend de F1-F2. |
| Connexions bancaires | Dépend du consentement (F2) et de la résidence des données. |

---

## Les mini-plans, quand leur tour viendra

Forme minimale visée, à ne pas dépasser au premier essai : **un objectif, une
trajectoire, une prochaine action, un indicateur « sur la bonne voie / à
ajuster »**.

Et une contrainte de ton, posée d'emblée : recalculer souvent ne veut pas dire
parler souvent. MINT ne doit pas devenir une machine à culpabiliser.

---

## Comment ce document reste vrai

- Mis à jour **à chaque lot livré**, jamais rétro-écrit.
- Une ligne passe en « acquis » seulement avec son commit **et** un reçu de
  vérification couvrant l'arbre correspondant.
- Un chantier qui attend porte **la raison** de son attente, pas un simple
  « plus tard ».
- Ce qui s'est révélé inutile est **retiré**, pas coché. Exemple : « purger 5 Go
  de données dérivées » a été retiré le 2026-08-13 — le disque est à 8 %
  d'occupation, la tâche reposait sur une prémisse fausse.

## Counter-arguments and data gaps

**Contre-argument — « une feuille de route de plus, que personne ne lira ».**
Recevable : le dépôt en contient déjà plusieurs, dont une marquée dépassée.
Celle-ci ne survivra que si elle est mise à jour à chaque lot ; si trois lots
passent sans qu'elle bouge, elle aura échoué et devra être supprimée plutôt que
maintenue par politesse.

**Lacune 1 — aucune preuve d'exécution récente.** Rien de ce qui est listé en
« acquis » n'a été vu tourner sur simulateur depuis le début de ces travaux.
Les tests sont verts ; l'application n'a pas été ouverte. C'est la lacune la
plus sérieuse de ce document.

**Lacune 2 — aucune estimation de durée.** Volontaire : les estimations
produites sans données historiques de vélocité sont des chiffres inventés. Elles
apparaîtront quand quelques lots auront été mesurés.

**Lacune 3 — l'ordre F1 → F2 → F3 → F4 n'est pas arbitré.** Il découle du bon
sens (pas de contexte sans historique) mais n'a pas encore été confronté à une
relecture adversariale au moment où ces lignes sont écrites.

**Ce que la relecture de F1 a coûté, et rapporté.** Six défauts, dont un aveu :
`coversFiscalYear` fabriquait une couverture depuis l'année de déclaration
pendant que le commentaire voisin promettait « on ne sait pas ». Un domicile
déclaré le 31 décembre couvrait janvier, puis toutes les années suivantes. Sans
cette relecture, le registre serait passé pour honnête. C'est l'argument le plus
concret en faveur de la dépense.

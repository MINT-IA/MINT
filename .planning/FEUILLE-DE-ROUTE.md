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
| **F1b** | **Transaction** — registre et projection écrits ensemble, révision comparée DANS l'écriture, pierres tombales pour la suppression | Sans elle, deux processus perdent une version. Et supprimer, dans un registre où rien ne s'efface, demande une forme propre. | ✅ **fait** — `3af8e6d92`, `9a23c7346`, `d8e5c540c` · reçu `55e1dc919c` |
| **F1c** | **Migration v1** des six faits déjà écrits | Le registre reste théorique tant qu'il ne porte pas les faits réels. | ✅ **fait** — `bf7d59b53` · reçu `bed73ab38f` · sans inventer date d'effet, déclaration ni propriétaire |
| **F2b** | **Brancher le registre sur le magasin réel** | Sans lui le jumeau était complet et inutilisé. | ✅ **fait** — `4553dbc04` · reçu `b5686a778a` · le registre vit sous une clé réservée du même objet que sa projection |
| **F2** | **Contexte porté par chaque fait** — enveloppe complète, plus un reçu de calcul citant les versions consommées | Un montant sans son année ni sa source ne peut alimenter aucun calcul honnête. | ✅ **fait avec F1** — et « sans date d'effet, la couverture est INCONNUE, pas supposée » |
| **F3** | **Le garde de la règle** — plus aucune écriture directe NOUVELLE dans la projection | Une règle déclarative sera oubliée. Cliquet sur 28 sites hérités : ils sont nommés, tolérés, et la liste ne peut que décroître. | ✅ **fait** — 10ᵉ gate, plus un job CI dédié |
| **F4** | **Rebrancher les faits orphelins** — le logement entre dans la frontière fiscale | Les intérêts hypothécaires, déduction la plus courante en Suisse, étaient enregistrés, affichés, et n'atteignaient aucun calcul. La donnée n'était pas perdue : elle était inerte. | ✅ **fait** — avec son ANNÉE : une attestation 2025 ne répond pas pour 2026, et le dit au lieu de fournir un chiffre |

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
| Écrire un fait n'efface plus le précédent | `f776d2ed1` + `451a694c8` — registre en ajout seul |
| Registre et projection ne peuvent plus diverger | `3af8e6d92` + `9a23c7346` — une seule écriture, comparaison atomique |
| Les six faits existants sont enveloppés sans invention | `bf7d59b53` — 56 oracles sur le jumeau |
| Le jumeau écrit dans le magasin que lisent les écrans | `4553dbc04` — une écriture, un objet |
| Une écriture directe NOUVELLE est mécaniquement refusée | garde + cliquet à 28 sites hérités |
| Les intérêts hypothécaires atteignent un calcul | le fait logement entre dans la frontière fiscale, avec son année |
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

## ⛔ Ce qui BLOQUE la suite — le contrat des faits

Une relecture du lot complet a posé la question que j'avais formulée ainsi :
« qu'est-ce qui, si on ne le fait pas maintenant, coûtera dix fois plus cher
dans six mois ? » La réponse est nette, et elle arrête l'ajout de tout nouveau
fait.

**Les faits naturellement multiples sont impossibles.** Trois comptes 3a, deux
hypothèques, plusieurs employeurs : sous un `factId` unique, chaque écriture
remplace la précédente ; sous des identités inventées au vol, la projection
lève un conflit de propriétaire. Pluralité théorique dans le registre,
**écrasement ou exception dans le produit**.

**La projection détruit l'enveloppe.** Provenance, statut, confirmation
attendue, date d'effet, année fiscale, péremption, identité de version :
tout disparaît. CHF 4 250 d'intérêts 2025, tirés d'un document et encore à
confirmer, deviennent une clé et un montant. Ce que lisent les écrans ne sait
ni de quelle année il s'agit, ni d'où ça vient, ni si c'est confirmé.

**Deux temps sont mélangés.** Le début de validité est du temps métier, la fin
est du temps d'enregistrement. `asOf()` répond donc à « que savait MINT ? »,
jamais à « qu'est-ce qui était vrai ? ». Une correction rétroactive après
taxation ne se reconstruit pas.

**Et le coach ne peut pas savoir ce qu'il ignore.** Des champs nullables ne
sont pas une connaissance des lacunes : rien ne distingue « inconnu » de
« confirmé absent », d'« inapplicable », de « périmé » ou d'« à confirmer ».

**F0 — Le contrat canonique des faits** est ✅ **fait** (`38e648876`, reçu
`0e9bc3a496`). Trois comptes 3a coexistent désormais, chacun avec sa propre
histoire ; mettre à jour l'un ne touche pas les autres. Le catalogue déclare
pour chaque type sa cardinalité, la règle qui identifie un membre, le temps
métier auquel il se rapporte, et ce qui le rend sans objet. Cinq états de
connaissance remplacent le champ nul qui n'en distinguait aucun. Le registre
l'impose à l'écriture **et** au chargement.

**Reste de ce chantier**, et il n'est pas mince :

- **F0b — l'enveloppe accompagne désormais la projection.** ✅ Provenance,
  statut, année fiscale, péremption, identité de version voyagent avec chaque
  valeur, dans une table compagne. Les écrans lisent la valeur exactement comme
  avant ; on peut en plus demander d'où elle vient.
- **F0f — le registre du jumeau descendait la PII dans les préférences en
  clair.** ✅ Trouvé en préparant F0e, par une sonde et non par relecture :
  cinq des six faits portent des clés classées **sensibles** — état civil,
  montants de revenu, chiffres hypothécaires, avoir LPP, versements 3a. Ces
  valeurs sont chiffrées dans le Keychain et remplacées par un jeton dans les
  préférences. Le registre les recopiait **en clair** dans son JSON, sous une
  clé que le classificateur ne connaissait pas : la même donnée scellée d'un
  côté, lisible de l'autre — l'inverse exact de SEC-10.
  **Rien n'avait fuité** : le jumeau n'est branché à aucun écran, la porte
  était ouverte mais personne n'y était encore passé. C'est bien pour ça
  qu'elle devait être fermée **avant** F0e.
  Au passage, une seconde chose : quand le coffre ne rend rien, la
  restauration laisse la clé présente avec une valeur nulle. Repartir de zéro
  aurait recouvert définitivement une histoire que le coffre aurait pu rendre.
  Le jumeau distingue désormais « rien à lire » de « quelque chose qu'on ne
  sait plus lire », et refuse d'écrire par-dessus le second.

  **Axe adverse Codex sur ce correctif — huit constats, triés.**
  Trois retenus, et ce sont les trois fois le même dommage : perdre une
  histoire.
  - *L'échange comparé ne comparait rien.* Entre lire la révision et écrire, il
    y a des `await` : deux écritures lancées ensemble lisaient la même
    révision, passaient toutes les deux, et la seconde recouvrait la première.
    Corrigé par une file d'attente. **Vérifié par mutation** — en neutralisant
    la file, l'oracle échoue avec le symptôme exact : deux écritures acceptées
    au lieu d'une.
  - *L'écriture ne refusait pas ce que la lecture refusait.* Même règle
    désormais aux deux portes.
  - *Le magasin de réponses échoue en silence* — JSON illisible, carte vide.
    Le registre, scellé, y survivait ; on concluait « pas de jumeau » et
    l'écriture suivante recouvrait une histoire intacte. Le registre se lit
    maintenant depuis le coffre : la perte devient une récupération.

  Deux rejetés, avec preuve : « fuite persistante sur les installations
  existantes » et « résidus dans les sauvegardes système » supposent qu'un
  registre en clair existe déjà quelque part. Il n'en existe aucun — aucun
  écran n'appelle le jumeau, donc aucune installation n'a jamais écrit cette
  clé.

  Un différé, argumenté : la table compagne et la révision restent en clair.
  Elle ne porte aucune VALEUR (un oracle le vérifie), et les noms de clés
  qu'elle expose figurent déjà dans les préférences sous forme de jetons. Ce
  qu'elle ajoute — années fiscales, cadence des confirmations — est un
  incrément réel mais mince. À rouvrir si le jumeau se met à porter des faits
  plus révélateurs.

  Un noté, non corrigé : le coffre est écrit avant les préférences. Si la
  seconde écriture échoue, le registre scellé est en avance d'une version sur
  la révision. Conséquence bornée — la version suivante réécrit par-dessus,
  rien ne se perd.
- **F0e — DEUX AUTORITÉS coexistent, et ce n'est pas tenable.** Découvert en
  câblant F0b : `saveAnswers` **retire toutes les clés des six faits
  canoniques** de ce qu'on lui donne, puis les réécrit depuis le coffre
  sécurisé. Une valeur que le jumeau projette pour ces clés est donc écrasée.
  Le jumeau ne peut pas encore posséder les faits qu'il est censé posséder.
  C'est le prochain vrai chantier — sans lui, le branchement reste
  partiellement décoratif pour les six faits.
  **Ce que F0f a changé à ce diagnostic** : cette seconde autorité n'est pas un
  doublon arbitraire, c'est le coffre **chiffré**. Le retrait-puis-réécriture
  existe pour une bonne raison. La résolution n'est donc pas « le jumeau
  gagne » mais « le jumeau devient l'autorité **sans perdre le chiffrement** ».
  Formulé autrement, F0f était le prérequis, pas une digression.
- **F0e — le jumeau est devenu l'autorité, pour le LOGEMENT.** ✅ La
  canonicalisation le consulte avant le coffre canonique, qui n'est plus qu'un
  repli pour les faits qu'il n'a **jamais** connus. Tri-état — absent, vivant,
  supprimé : avec deux états, une suppression serait retombée dans « le jumeau
  n'a rien » et le repli l'aurait ressuscitée. L'idée du tri-état vient de
  l'axe Codex sur la conception ; elle manquait à mon énoncé du problème.
  Cinq vérifications : registre vivant contre coffre divergent, registre absent
  (résultat historique **inchangé**), pierre tombale sans résurrection, deux
  chargements identiques, et la seule qui compte — le chiffre atteint le
  **calcul**.

  **Un plantage trouvé en écrivant l'oracle.** La migration donnait aux faits
  leur type nu comme identifiant. Le contrat, arrivé après, déclare quatre
  faits MULTIPLES et refuse un identifiant sans clé de membre : elle levait
  donc pour le logement, le revenu, la LPP et les versements 3a — elle plantait
  sur tout dossier un peu rempli. Le trou n'était pas dans le code mais dans le
  CHOIX du cas testé : les oracles n'exerçaient que `domicile`, un fait unique.
  Le nouvel oracle parcourt le catalogue au lieu d'en élire un, et la mutation
  confirme qu'il attrape le défaut. Latent, pas advenu — rien n'est branché.

- **F0e (suite) — quatre canonicalisations sur cinq sont branchées.** ✅
  Logement, état civil, revenu, affiliation LPP.
  La sortie n'a PAS été la suppression bilatérale envisagée au lot précédent :
  plus simple et plus sûr, la pierre tombale du jumeau **force** la branche
  « supprimé » existante — avec ses purges propres — par une substitution de
  variable. Rien n'est recopié, donc rien ne peut dériver.

  **Trois défauts trouvés en branchant**, tous par des oracles, aucun par
  relecture :

  1. *Le registre n'appliquait la règle « scalaires uniquement » qu'à la
     RELECTURE.* Écrire une liste réussissait ; c'est le chargement suivant qui
     levait — et cette exception remonte jusqu'au `catch` du magasin de
     réponses, lequel rend une carte **vide**. Une seule écriture mal formée
     effaçait donc tout le profil visible, au lancement d'après, sans que rien
     ne désigne la cause. La règle s'applique désormais à l'écriture : refuser
     au moment de la faute, pas au prochain démarrage.
  2. *Forcer la branche « supprimé » ne suffisait pas pour le revenu.* Elle lit
     `projectionPurged`, qui dit que le nettoyage de la tombe **canonique** a
     déjà eu lieu. Une tombe du **jumeau** est un événement plus récent, dont
     le nettoyage n'a pas eu lieu : lire le drapeau de l'autre laissait le
     revenu survivre par sa clé héritée — donc pas supprimé du tout.
  3. *Les versements 3a ne peuvent pas être branchés du tout.* Leur valeur
     canonique est une **liste de comptes dans une seule clé** — exactement la
     forme que leur propre contrat veut remplacer par plusieurs membres. Ils
     sortent donc du catalogue migrable, **nommés** dans
     `kFactsAwaitingDecomposition`, avec un oracle vérifiant que les deux
     listes se recouvrent : un fait ne peut pas disparaître en silence entre
     elles. Les brancher demande d'abord d'éclater la liste en un fait par
     compte — c'est F0d, un vrai chantier.

- **F0c — deux temps restent mélangés.** Début de validité métier, fin
  d'enregistrement. `asOf()` répond à « que savait MINT », jamais à « qu'est-ce
  qui était vrai ». Une correction rétroactive après taxation ne se reconstruit
  pas.
- **F0d — les faits existants ne portent pas encore de clé de membre.** Le
  contrat les déclare multiples ; la migration devra leur en donner une.

## La fondation est posée — ce qu'elle permet maintenant

Les cinq chantiers F1 à F4 sont faits. Concrètement, cela veut dire :

- écrire un fait n'efface plus le précédent, et l'on peut demander « qu'est-ce
  que MINT savait le 3 mars ? » ;
- chaque valeur porte d'où elle vient, quand elle a été dite, si elle est
  confirmée ou estimée, et jusqu'à quand elle vaut probablement ;
- supprimer laisse une trace au lieu d'effacer, et disparaît quand même des
  écrans ;
- un chiffre affiché peut dire de quoi il est fait, par son reçu de calcul ;
- et un écran qui écrirait à côté du jumeau fait échouer l'intégration.

Ce qui n'est PAS fait : les 28 écritures héritées, qui court-circuitent encore
le registre. Elles sont nommées, sous cliquet, et seront reprises une par une.

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

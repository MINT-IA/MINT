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
| Propagation du fait à deux états vers le backend | ✅ **fait pour la reprise de compte** — un domicile récusé EFFACE désormais canton et commune côté serveur, au lieu d'être simplement omis. **Reste ouvert** : le mobile n'a AUCUN chemin de mise à jour du profil serveur après l'inscription (`POST /profiles` existe et n'est appelé par personne), donc un changement postérieur ne se propage pas. C'est une capacité manquante, pas un correctif. |
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

- **F0d — les versements 3a sont décomposés : un fait par versement.** ✅ Et
  c'est le lot où l'enveloppe des seize champs cesse d'être une promesse.

  Chaque versement portait déjà, sans qu'on s'en serve, **tout ce qu'il
  fallait** : un identifiant stable opaque — la clé de membre exacte que le
  contrat réclame, et la raison pour laquelle « une correction ne devient
  jamais suppression + doublon » ; une **année fiscale épinglée**, qui est
  `fiscalYear` ; une **date de crédit**, qui est `effectiveFrom`. Deux des
  quatre champs d'un versement appartenaient donc à l'enveloppe, pas à la
  charge utile.

  Ce que ça rend possible : « répartir plusieurs comptes 3a » — l'exemple même
  de la doctrine — existe enfin. Corriger un versement allonge SON histoire et
  n'écrit rien sur les autres, là où la liste les réécrivait tous.

  **Et ça simplifie plus que ça n'ajoute.** La révision par année fiscale
  servait à périmer le contexte d'une année sans toucher aux autres ; elle
  était tenue à la main, bumpée à chaque mutation, avec un **compteur de
  mutations** en renfort parce que deux mutations à la même seconde produisaient
  le même horodatage. Elle se **dérive** désormais des identités de version de
  l'année : elle change exactement quand cette année-là change, et jamais
  autrement. Un invariant maintenu par construction plutôt que par discipline —
  et le compteur devient un vestige.

  Une distinction gagnée au passage : **supprimer tous ses versements est une
  RÉPONSE**, pas un silence. Le fait existe et ne porte plus rien. Les
  confondre relancerait quelqu'un qui a déjà répondu.

  **Mon contrat décrivait un monde qui n'existe pas.** Il disait « l'établissement
  et le compte » ; la donnée porte des **versements**. L'écart n'est apparu
  qu'en tentant la décomposition — écrire la règle ne l'avait pas confrontée au
  réel.

- **PREUVE D'EXÉCUTION — l'app a enfin été ouverte.** ✅ Build simulateur,
  installation, lancement : l'app démarre et affiche son écran de bêta. Le
  chemin de démarrage tient malgré la lecture du coffre ajoutée aujourd'hui
  dans `loadAnswers` (cinq fois par chargement). Aucun blocage, aucune
  exception applicative — les erreurs du journal sont du bruit de simulateur.

  **Et la preuve a rapporté ce qu'aucun test ne pouvait dire.**

  1. **Le build simulateur n'a AUCUN droit Keychain** (`-34018` à chaque
     accès). Le coffre y échoue systématiquement. J'avais jugé ce chemin
     dégradé « surtout théorique » en raisonnant sur le code — il est la
     norme sur l'appareil où l'on teste. Conséquence directe : le jour où le
     chemin d'écriture atterrira, le registre scellé sera illisible sur
     simulateur, donc `indisponible`, donc la canonicalisation rendra la carte
     inchangée — et le profil disparaîtra des écrans. Le quatrième état trouvé
     par Codex n'était donc pas une précaution : c'est le cas NOMINAL en
     développement. À traiter avant d'activer l'écriture.

  2. **Une revendication de localité s'affiche sur le PREMIER écran** :
     « Tes données restent sur ton appareil ». Elle est abolie depuis le
     2026-08-05 — le backend est dans le cloud. Elle vit dans au moins quatre
     clés (`askMintPrivacyBadge`, `landingLegalFooter`,
     `consentSecurityMessage`, `authGatePrivacyNote`).
     Le garde `no_false_privacy_attestation.py` **passe** : ses motifs ne
     visent que des tournures étroites (« traitement intégralement sur ton
     appareil ») et ratent la formulation simple. Un garde qui rassure en
     manquant l'occurrence la plus visible est pire qu'un garde absent.
     Hors de ce chantier, et la correction touche la copie de conformité dans
     six langues : **signalé, pas corrigé unilatéralement**.

- **F0g — le chemin d'ÉCRITURE, et le piège qui l'attendait.** Le jumeau est
  désormais LU par les cinq canonicalisations, et ÉCRIT par personne : en
  production le registre est vide, tout retombe sur le repli, le comportement
  est rigoureusement inchangé.

  Déclencher simplement la migration au démarrage **casserait l'édition** : le
  registre deviendrait l'autorité pendant que les écrans continuent d'écrire
  dans le coffre canonique. La personne modifierait son logement et ne verrait
  rien changer — le problème des deux autorités, retourné.

  Et la solution évidente — faire écrire le jumeau depuis `writeCanonicalX` —
  est une **récurrence infinie** : ce writer est appelé depuis la branche
  `missing` de la canonicalisation, que l'écriture du jumeau rappellerait.

  **Voie retenue (axe Codex) — write-through centralisé, non réentrant.** Le
  backend du jumeau lit et écrit son bloc **directement**, sans passer par
  `loadAnswers` : c'est ça qui casse le cycle à la racine. `writeCanonicalX`
  devient la frontière de commande — append dans le jumeau, puis mise à jour
  du repli — et la branche `missing` appelle un helper legacy brut, jamais
  `writeCanonicalX`.

  **Ce que ça lève, et que je croyais dur.** Le registre vivait dans le MÊME
  objet que sa projection pour qu'ils s'écrivent ensemble ou pas du tout.
  Depuis que la canonicalisation projette le jumeau, la projection est
  **recalculée à chaque lecture** : une divergence se répare d'elle-même.
  L'atomicité qui justifiait ce choix n'a plus d'objet.

  Première étape : **logement seul**, derrière un interrupteur désactivé par
  défaut, avec deux vérifications mécaniques — l'édition gagne après
  redémarrage, et le backend n'appelle jamais `loadAnswers`.

- **F0g (première étape) — le support du jumeau est devenu INDÉPENDANT.** ✅
  Il n'écrit plus jamais dans le magasin de réponses : le registre va dans le
  coffre où il est scellé, la révision et l'enveloppe dans leurs propres
  entrées. Plus aucune récurrence possible le jour où une écriture d'écran
  appellera le jumeau — c'était le piège qui bloquait ce chantier.

  **Ce qui a rendu ça possible, et qui n'était pas vrai il y a deux lots** : la
  projection est désormais DÉRIVÉE à chaque chargement. Une divergence entre le
  registre et le magasin plat se répare donc d'elle-même — il n'y a plus deux
  vérités à tenir synchronisées, il y a une vérité et une vue. L'atomicité qui
  justifiait de tout écrire dans le même objet n'avait plus d'objet.

  **Et elle coûtait cher pour rien.** `saveAnswers` appelle lui aussi les cinq
  canonicalisations, lesquelles lisent le registre. La projection écrite était
  donc calculée à partir de l'ANCIEN registre — en retard d'une version, et
  corrigée au chargement suivant. On payait un aller-retour complet pour
  stocker une valeur périmée que personne ne lisait.

  **Un fait orphelin découvert en retirant l'écriture.** Le domicile n'avait
  AUCUNE canonicalisation : sa valeur n'atteignait les écrans que par la
  projection qu'on venait de supprimer. Le défaut ne se voyait pas — le fait
  entrait au registre, l'écriture réussissait, les oracles du registre
  passaient, et l'écran restait vide. **Un fait qu'on enregistre et que
  personne ne lit est pire qu'un fait absent : il donne l'impression d'avoir
  été collecté.**

  D'où un garde de plus, `twin_every_fact_is_derived.py` : tout type déclaré au
  catalogue doit être consulté quelque part dans la canonicalisation. Vérifié
  par mutation — en débranchant le domicile, il échoue en le nommant.

  Neuf oracles décrivaient l'ancien rangement ; ils décrivent le nouveau. Reste
  la deuxième étape : `writeCanonicalX` comme frontière de commande, logement
  seul, derrière un interrupteur.

- **F0g (deuxième étape) — la FRONTIÈRE DE COMMANDE est posée.** ✅ Les écrans
  continuent d'appeler `writeCanonicalHousing` ; c'est elle qui fait entrer le
  fait au registre. Recâbler dix parcours un par un aurait multiplié les
  occasions d'en oublier un — et un écran oublié est exactement le défaut que
  ce chantier combat.

  **Derrière un interrupteur ÉTEINT** (`FeatureFlags.twinOwnsHousing`). Tant
  qu'il l'est, rien ne change : le registre reste vide, les canonicalisations
  retombent sur le repli, le comportement est celui d'hier. Un oracle le
  vérifie explicitement — c'est la garantie de non-régression.

  La branche « fait absent » appelle désormais un helper brut, jamais la
  frontière : réparer un magasin pendant qu'on le lit n'est pas une commande de
  l'utilisateur et n'a rien à faire dans l'histoire du jumeau.

  **Mon oracle central ne prouvait rien, et je l'ai vu en voulant le muter.**
  Il vérifiait qu'après deux écritures la seconde valeur ressort — mais le
  repli rendait la MÊME réponse que le jumeau, donc il serait passé sans
  frontière de commande. Corrigé en faisant **diverger** les deux magasins :
  le coffre repart en arrière, le jumeau garde la correction, et seul le jumeau
  peut produire la bonne réponse. Vérifié par mutation — en débranchant la
  frontière, trois oracles tombent.

  Reste avant d'allumer : la migration au démarrage (le registre est encore
  vide pour les installations existantes), et une preuve d'exécution
  interrupteur allumé.

- **F0g (troisième étape) — l'AMORCE, une fois et une seule.** ✅ La migration
  entre dans le démarrage, gardée par l'existence même du registre : s'il porte
  déjà quelque chose, il n'y a rien à faire ; s'il est illisible, la lecture
  lève et rien ne s'écrit.

  **Et elle ne migre QUE ce qu'on sait aussi écrire.** Les canonicalisations
  lisent le jumeau inconditionnellement : dès qu'un fait entre au registre,
  c'est lui qui répond. Un fait migré mais que les écrans ne savent pas écrire
  serait donc **gelé** — modifié à l'écran, inchangé à l'affichage. Le pire des
  symptômes, parce qu'il frappe au moment exact où quelqu'un corrige une
  erreur. Aujourd'hui, un seul fait a une frontière de commande : le logement.

  Deux refus valent d'être notés. Un profil vide **n'écrit pas** de registre :
  le marquer « déjà migré » ferait que la déclaration faite demain ne serait
  jamais reprise. Et une panne d'amorce n'empêche pas l'app de démarrer — le
  jumeau reste vide, le repli répond, le comportement est celui d'hier.

- **⛔ LE SIMULATEUR NE PEUT PAS PROUVER LE JUMEAU — ni aucun fait sensible.**
  Mesuré le 2026-08-14, pas supposé. Un test d'intégration lancé sur la VRAIE
  pile (iPhone 17 Pro, iOS 26.2) montre que `SecureWizardStore.write` rend
  **false** : le coffre refuse. `codesign -d --entitlements` sur le `.app`
  produit ne rend rien — les builds simulateur iOS n'embarquent **aucun droit**,
  donc le `keychain-access-groups` déclaré par l'app est absent et l'accès
  échoue (`-34018`).

  J'avais d'abord soupçonné mon propre `--no-codesign`. Vérifié : un build à la
  manière de `walker.sh`, sans ce drapeau, ne porte pas plus de droits. Ce
  n'est donc pas mon erreur d'invocation.

  **La portée dépasse largement le jumeau.** Sur ce simulateur, ni le registre
  ni le **coffre canonique** ne persistent : aucun des six faits financiers n'y
  survit. Toute marche de vérification impliquant un fait enregistré teste une
  application vide — et rend un vert qui ne prouve rien.

  Le test d'intégration le dit désormais lui-même : il sonde le coffre en
  premier, et déclare les oracles dépendants **ignorés** plutôt que réussis.
  Un vert qui ne prouve rien est exactement ce que ce fichier existe pour
  éviter.

  **CAUSE RACINE trouvée, et elle est délibérée.** `Debug.xcconfig` pose
  `CODE_SIGNING_ALLOWED=NO`, et `tools/simulator/codesign_shim/codesign` est un
  **no-op** qui rend `codesign` inopérant. Décision du 2026-05-05 (WALKC-09)
  pour débloquer le walker sur des builds non signés — les attributs étendus de
  provenance d'un dossier `.nosync` faisaient échouer la signature.

  La conséquence n'avait pas été tirée à l'époque : **sans signature, aucun
  droit ; sans droit, pas de trousseau ; sans trousseau, aucun fait financier
  ne persiste**. Toutes les marches simulateur depuis mai sont donc aveugles au
  stockage sécurisé.

  **La correction naïve NE MARCHE PAS**, vérifié plutôt que supposé. Signer
  l'app en ad-hoc après le build embarque bien les droits — mais signer les
  frameworks imbriqués réintroduit les attributs étendus (« resource fork,
  Finder information ») et l'app ne se lance plus
  (`FBSOpenApplicationServiceErrorDomain code=1`). État simulateur restauré par
  un build propre.

  **Ce qu'il faudrait vraiment** : réactiver la signature pour les builds
  simulateur avec une identité de développement, et régler le problème des
  attributs étendus autrement — construire hors de `.nosync`, ou poser un
  `xattr -cr` en phase de build. C'est une décision d'outillage qui touche le
  walker, pas un correctif de code : **à trancher avec Julien**.

- **F0c — les deux temps sont séparés.** ✅ Dernier trou nommé du registre.

  `effectiveTo` — temps **métier** — recevait la date d'**enregistrement** de la
  version suivante. Remplacer un domicile aujourd'hui faisait donc dire à
  l'ancienne version qu'elle avait cessé d'être vraie aujourd'hui : une
  affirmation sur le monde, déduite d'un geste dans l'application, que personne
  n'avait déclarée. Et `coversFiscalYear` lisait ce champ — la couverture
  fiscale d'un fait dépendait donc de la date à laquelle on l'avait remplacé.

  Désormais : `supersededAt` porte le temps d'enregistrement, `effectiveTo` le
  temps métier — renseigné **seulement quand la version suivante dit depuis
  quand elle vaut**. Sinon la fin reste inconnue, et l'inventer serait pire.

  Et `trueAt()` répond enfin à « qu'est-ce qui était **vrai** », à côté de
  `asOf()` qui répond à « que **savait** MINT ». Quelqu'un qui déclare en août
  avoir déménagé en mars : `trueAt(avril)` rend Lausanne — il y habitait déjà —
  pendant que `asOf(avril)` rend Aarau, tout ce que MINT savait alors. C'est
  cette distinction qui permet de reconstruire une déclaration fiscale après
  coup sans réécrire l'histoire.

  **Sans nouvelle table** : l'ADR du 2026-05-17 a rejeté le bitemporal SCD2 au
  profit d'un journal d'événements. « Ce qui était vrai » se répond par une
  seconde lecture du même journal, pas par un second schéma. Début de validité métier, fin
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

---
description: Le jumeau financier s'écrit en versions immuables ajoutées, jamais écrasées. Le magasin plat devient une projection de l'état courant, plus l'autorité. Les calculs portent un reçu citant les versions exactes consommées.
status: Proposed
date: 2026-08-13
---

# Le jumeau financier : des faits versionnés, pas une photo écrasée

## Ce que Julien a énoncé

> « MINT construit progressivement une représentation fiable de la vie
> financière d'une personne, la maintient à jour pendant toute son existence.
> Chaque donnée doit avoir un contexte : à quelle année fiscale elle se
> rapporte, d'où elle vient, quand elle a été obtenue, si elle est confirmée ou
> estimée, combien de temps elle reste valable, ce qu'elle remplace, quels
> calculs en dépendent, si l'utilisateur en a autorisé l'usage. Il faut
> conserver l'historique, pas seulement la dernière valeur. »

Et la règle : **aucun écran n'est terminé si les informations qu'il collecte ne
rejoignent pas le jumeau et si ses résultats ne peuvent pas être réutilisés
ailleurs.**

## Le constat était à moitié faux, et l'autre moitié plus grave

Julien décrivait le parcours logement ainsi : « l'écran les connaît, le jumeau
financier ne les connaît pas durablement, elles disparaissent après la
session ». Vérifié dans le code, ce n'est pas ce qui se passe.

**Ce qui existe déjà** : `MintNextHousingFact` porte les cinq champs cités —
statut d'occupation, présence d'hypothèque, année de l'attestation, intérêts,
solde de la dette. L'écran appelle `saveHousingFact` et `deleteHousingFact`, le
fait est persisté, rechargé au retour, et visible dans « Ma situation ». Rien ne
disparaît après la session.

**Ce qui manque vraiment, et qui est pire** : ce fait n'est consommé **nulle
part ailleurs**. Il est absent de la frontière fiscale
(`mint_next_3a_tax_boundary.dart`). Autrement dit, les intérêts hypothécaires —
la déduction fiscale la plus courante en Suisse — sont enregistrés, affichés, et
n'atteignent **aucun calcul**. La donnée n'est pas perdue ; elle est inerte.

La règle de Julien reste donc exactement juste, mais elle mord sur la seconde
moitié de sa formulation : *« et si ses résultats ne peuvent pas être retrouvés
et réutilisés ailleurs »*.

## La décision

Soumise à une relecture d'architecture, qui a tranché.

**Versionnement immuable par fait, en ajout seul.** Chaque modification ajoute
une version et référence celle qu'elle remplace. Le magasin plat clé-valeur
existant **reste**, mais change de rôle : il devient la *projection de l'état
courant*, plus l'autorité. L'autorité est le registre des versions.

Ce choix est retenu contre deux alternatives plus ambitieuses, écartées pour
disproportion : le bitemporel complet et le journal d'événements métier
intégral. Ils apporteraient la correction rétroactive, dont aucun besoin réel
n'est encore constaté.

### L'enveloppe

```text
factId          UUID          identité du fait, stable dans le temps
versionId       UUID          identité de CETTE version
factType        String
subjectId       UUID
payload         Map<String, Scalar?>

effectiveFrom   Date?         depuis quand c'est vrai — pas la date de saisie
effectiveTo     Date?
fiscalYear      Int?

assertedAt      DateTime      quand la personne l'a déclaré
recordedAt      DateTime      quand MINT l'a écrit
source          Enum          déclaration, document, connexion
status          Enum          confirmé | estimé
validUntil      DateTime?     péremption probable
needsConfirmation bool

supersedesVersionId UUID?     ce que cette version remplace
schemaVersion   Int
consentRef      UUID?
```

### « Quels calculs dépendent de ce fait ? »

Pas un tableau inverse maintenu dans le fait — il dériverait au premier oubli.
Un **reçu de calcul**, séparé :

```text
calculationId   UUID
calculationType String
inputVersionIds List<UUID>    les versions EXACTES consommées
computedAt      DateTime
rulesetVersion  String
```

La question se pose alors comme une requête sur les reçus. Et un chiffre affiché
peut dire de quoi il est fait.

### La règle rendue mécanique

Une règle écrite dans un document sera oubliée — c'est mesuré ailleurs dans ce
dépôt. Trois éléments la rendent contraignante :

1. chaque écran qui collecte déclare les `factType` qu'il produit ;
2. un test de contrat pilote chaque soumission et exige qu'une nouvelle version
   apparaisse au registre, enveloppe valide ;
3. l'intégration continue échoue si un écran déclaré n'émet rien, **ou s'il
   écrit directement dans le magasin plat**.

### La migration des six faits existants

Encapsuler chaque valeur actuelle dans une version `v1` importée :
`recordedAt` = date de migration, `assertedAt` = la valeur existante,
`source` / `schemaVersion` / `needsConfirmation` conservés — et surtout
**période fiscale et date d'effet à `null`, jamais inventées**. L'historique
antérieur est perdu : les anciennes valeurs ont été écrasées. On ne le
reconstruit pas.

## Ce qui coûterait cher pour peu, et qu'on ne fait pas

- le bitemporel complet partout, avant tout besoin réel de correction
  rétroactive ;
- un journal d'événements métier intégral avec relecture ;
- un graphe de dépendances bidirectionnel tenu en temps réel — les reçus de
  calcul suffisent ;
- le consentement par champ et par calcul : un consentement versionné par
  finalité et par source suffit ;
- reconstruire l'historique antérieur, qui n'existe plus ;
- une péremption « intelligente » universelle : commencer par quelques règles
  explicites selon le type et la source.

## Counter-arguments and data gaps

**Contre-argument 1 — « deux représentations du même fait, c'est deux fois plus
de choses qui peuvent diverger ».** Vrai, et c'est le risque principal de cette
décision. La projection plate peut se désynchroniser du registre. La parade est
qu'elle soit **dérivée** et jamais écrite à la main — d'où le contrôle qui
refuse une écriture directe dans le magasin plat. Si cette parade n'est pas
mécanique, la décision se retourne contre elle-même.

**Contre-argument 2 — « le versionnement immuable fait grossir le stockage sans
fin ».** Sur des faits financiers déclarés par une personne, le volume est
minuscule : quelques dizaines de versions par personne et par an. Le problème
n'existera pas avant les connexions bancaires automatiques, qui produiront des
transactions — mais celles-ci ne sont pas des faits déclarés et n'ont pas
vocation à entrer dans ce registre.

**Contre-argument 3 — « la migration invente une date d'effet ».** Elle ne
l'invente pas, elle la laisse nulle. Conséquence assumée : les faits migrés ne
pourront répondre à aucune question rétroactive. C'est une dégradation
explicite, préférable à une date fabriquée.

**Lacune 1 — l'ordre F1 → F2 → F3 → F4 n'est pas prouvé.** Il découle du bon
sens (pas de contexte sans historique), mais aucune relecture adversariale n'a
encore attaqué cet ordre lui-même.

**Lacune 2 — le coût de migration n'est pas chiffré.** Six faits, un magasin
clé-valeur, aucune donnée de production réelle à ce jour puisque l'application
n'est pas distribuée. Le coût est probablement faible ; « probablement » n'est
pas une mesure.

**Lacune 3 — le consentement reste une référence, pas un modèle.** `consentRef`
pointe vers quelque chose qui n'existe pas encore. Tant que ce quelque chose
n'est pas défini, le champ est un vœu.

**Lacune 4 — rien de tout ceci n'a été vu tourner.** L'application n'a pas été
ouverte depuis le début de ces travaux. Une architecture de données validée par
des tests unitaires reste une hypothèse sur le comportement réel.

## Provenance

Constat mesuré dans le code le 2026-08-13 (faits existants, consommateurs,
absence de la frontière fiscale). Architecture soumise à une relecture
indépendante, qui a tranché sur le mode de stockage, l'enveloppe, le reçu de
calcul et ce qu'il ne faut pas construire.

Lié : `.planning/FEUILLE-DE-ROUTE.md` ·
`.planning/decisions/2026-08-13-identite-communale-registre-federal.md`

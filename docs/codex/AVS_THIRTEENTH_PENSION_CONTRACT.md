# 13e rente AVS — contrat de cash-flow G1

> Statut : **NO-GO G1-AVS-02 pour l'activation produit**. Le noyau typé et la
> migration des proxys annuels sont présents sur le snapshot audité
> `06115ed38`, mais ce
> document ne prouve ni persistance end-to-end, ni renderer séparé, ni runtime
> activé. Snapshot juridique vérifié le **2026-07-13** : droit applicable dès le
> **01.01.2026**, C 13 RV état **17.06.2026**, synthèse OFAS publiée le
> **19.06.2026**. Premier versement : décembre 2026. Ce contrat ne démarre ni G2
> ni G3 et ne remplace pas le calcul d'une caisse de compensation AVS.

## 0. Verdict borné sur le snapshot audité `06115ed38`

`AvsCalculator.annualRente`, `include13eme` et les constantes génériques
`×13` ont été supprimés. `RetirementProjectionService` conserve douze rentes
ordinaires récurrentes et ne les gonfle plus par `13 / 12`.

`AvsThirteenthPensionCalculator` porte désormais un contrat owner-scoped en
centimes exacts : douze faits mensuels, droit au 1er décembre, niveau de preuve,
version juridique, cadence, date de paiement, montant certifié ou estimation
éducative séparés et correction rétroactive. Sa frontière temporelle accepte
uniquement des instants UTC canoniques ; elle rejette les `DateTime` locaux,
puis convertit en date civile `Europe/Zurich` selon CET/CEST avant de comparer
le mois d'effet, le 1er décembre ou une date de paiement annualisée.

Cette implémentation ne vaut toutefois pas activation. Le seul bridge produit,
dans `IndependantsService`, reste derrière
`enableAvsThirteenthScenarioCashflow = false`. Trois P2 restent explicitement
ouverts avant toute activation :

1. **Owner de scénario** : `independant-self-scenario` est un identifiant
   générique, pas l'owner pseudonyme authentifié de la personne.
2. **Renderer séparé** : lorsque le flag est forcé dans un test, le supplément
   est encore fusionné dans `projectionSansLpp` et `projectionAvecLpp`, alors
   qu'aucun renderer ne l'affiche comme événement de cash-flow distinct.
3. **Précédence du zéro légal** : les sources mensuelles sont validées avant le
   `notEntitled` officiel. Le test actuel couvre un mois `unknown` dont la source
   reste complète ; il ne prouve donc pas qu'un zéro légal officiel prévaut sur
   une source mensuelle absente plutôt que de retourner `sourceTooWeak`.

La page OFAS du 19 juin 2026 est sans ambiguïté : **aucun calcul précis n'est
possible avant décembre**. MINT ne peut donc afficher un montant certifié avant
décembre ni sans preuve de la caisse compétente ; au mieux, il expose une
estimation éducative datée et ses hypothèses. G1-AVS-02 reste NO-GO tant que les
trois P2 et les hard gates distincts de persistance, renderer et preuve runtime
ne sont pas fermés.

## 1. Règles légales 2026

### 1.1 Droit et moment du versement

1. Le droit existe seulement si la personne est en vie le **1er décembre** et
   a droit à une rente de vieillesse AVS au mois de décembre.
2. Le supplément est dû pour la première fois le 1er décembre 2026.
3. Pour une rente versée mensuellement, il est payé avec la rente de décembre.
4. Pour une rente faible versée une fois l'an selon l'art. 44, al. 2, LAVS, le
   droit reste évalué en décembre, mais le supplément est payé avec le versement
   annuel. L'absence de virement bancaire en décembre ne signifie donc pas
   absence de droit.
5. Un décès avant le 1er décembre éteint le droit pour toute l'année, même si
   des rentes de vieillesse ont été versées de janvier à novembre. Un décès en
   décembre laisse dus la rente de décembre et le supplément ; ils entrent alors
   dans la succession comme prestations en cours.
6. Une extinction du droit avant le 1er décembre, notamment après un transfert
   de domicile à l'étranger lorsque le droit AVS cesse ou après remplacement par
   une rente de survivant plus élevée, exclut également tout supplément partiel.

### 1.2 Base de calcul

La base est, pour **une personne identifiée**, la somme des montants mensuels de
rente de vieillesse déterminants effectivement versés pendant l'année civile.
Le supplément est construit mois par mois :

```text
part_mensuelle[m] = arrondi_centime(rente_vieillesse_determinante[m] / 12)
solde_centimes     = somme(part_mensuelle[janvier..decembre])
supplement_CHF     = arrondi_franc_commercial(solde_centimes)
```

- chaque part mensuelle est arrondie à deux décimales ;
- le solde est ensuite arrondi au franc entier avant paiement ;
- selon l'art. 53, al. 2, RAVS, une fraction finale d'au moins 50 centimes est
  arrondie au franc supérieur ; une fraction inférieure à 50 centimes au franc
  inférieur ;
- le calcul monétaire utilise un type décimal, jamais un `double` binaire ;
- aucun montant précis n'est certifiable avant décembre et sans preuve de la
  caisse compétente, car une mutation peut encore intervenir pendant l'année.

Le calcul `somme annuelle / 12` n'est pas une substitution acceptable : la
circulaire OFAS comptabilise et arrondit chaque part mensuelle avant de sommer.

### 1.3 Montants inclus

`determiningOldAgePensionChf` est **un seul montant mensuel, après toutes les
mutations applicables**, provenant du registre ou de la décision de rente. Il
peut représenter :

- une rente de vieillesse ordinaire ou extraordinaire ;
- une rente de vieillesse déjà plafonnée ;
- une rente réduite par anticipation totale ou partielle ;
- une rente augmentée après révocation totale ou partielle d'un ajournement ;
- une rente de vieillesse comprenant le supplément de veuvage.

Ces mots décrivent l'état du montant ; ils ne sont pas des composantes à ajouter
une seconde fois. Le plafonnement du couple reste effectué sur les rentes
mensuelles. La 13e rente n'entre pas dans le test du plafond. Ensuite, chaque
personne calcule son supplément sur sa propre rente plafonnée effectivement
versée.

### 1.4 Montants exclus

Ne contribuent jamais à `determiningOldAgePensionChf` :

- rente AI ;
- rente de veuve, de veuf ou d'orphelin lorsque la prestation versée reste une
  rente de survivant ;
- rente pour enfant ;
- rente complémentaire à la rente de vieillesse ;
- supplément AVS 21 des femmes de la génération transitoire selon l'art. 34bis
  LAVS ;
- allocation pour impotent, prestation complémentaire et toute autre prestation
  qui n'est pas classée par la caisse comme rente de vieillesse déterminante ;
- la 13e rente elle-même, notamment dans le calcul d'une réduction pour
  anticipation ou d'une augmentation pour ajournement.

Une prestation inconnue n'est ni incluse par défaut ni transformée en zéro :
elle bloque le montant certifié et requiert sa classification par la caisse ou
un·e spécialiste.

### 1.5 Anticipation, ajournement et changement de prestation

- **Anticipation** : utiliser chaque mois la rente réduite effectivement versée.
  Si le montant change à l'âge de référence, conserver deux périodes distinctes.
- **Ajournement total** : aucun droit tant qu'aucune part de rente n'est perçue.
- **Ajournement partiel** : seule la part effectivement perçue alimente le
  supplément. Après révocation, la part versée, majoration comprise, devient la
  nouvelle base mensuelle.
- **Conversion AI vers vieillesse** : les mois AI sont exclus ; seuls les mois
  où une rente de vieillesse est effectivement versée peuvent alimenter le
  supplément, sous réserve du droit en décembre.
- **Concours survivant/vieillesse** : si la caisse verse finalement la rente de
  vieillesse, son montant annuel comparatif inclut le supplément. Si elle verse
  la rente de survivant plus élevée et éteint la rente de vieillesse avant le
  1er décembre, aucun supplément n'est dû.

## 2. Contrat typé implémenté

Les noms ci-dessous reflètent `avs_thirteenth_pension_calculator.dart` sur le
snapshot audité `06115ed38`. `ChfAmount` stocke un nombre entier de centimes ;
aucun `double` binaire n'entre dans le calcul après validation de la frontière
legacy.

```dart
enum AvsMonthlyOldAgeState {
  paidEligibleOldAge,
  explicitlyNoOldAgeEntitlement,
  unknown,
}

enum AvsOldAgePensionKind { ordinary, extraordinary }

enum AvsOldAgeAdjustment {
  capped,
  anticipated,
  deferredIncrease,
  widowSupplementIncluded,
}

enum AvsPensionBenefitKind { oldAge, disability, survivor, none, unknown }

enum AvsExcludedComponentKind {
  disabilityPension,
  survivorPension,
  orphanPension,
  childPension,
  complementaryPension,
  avs21TransitionSupplement,
  helplessnessAllowance,
  supplementaryBenefit,
  unknown,
}

enum AvsDecemberEntitlementState { entitled, notEntitled, unknown }

enum AvsPensionPaymentCadence { monthly, annualArticle44Paragraph2 }

enum AvsEvidenceTier {
  avsFundLedger,
  avsFundDecision,
  userDeclaredFromDocument,
  scenario,
}

enum AvsThirteenthReadiness {
  certified,
  explicitlyNotEntitled,
  notInForce,
  declaredComplete,
  illustrativeOnly,
  pendingDecember,
  missingMonthlyHistory,
  unclassifiedComponent,
  sourceTooWeak,
  unsupportedLegalYear,
  providerCorrectionRequired,
}

class AvsMonthlyOldAgeFact {
  final int month; // 1..12, unique
  final AvsMonthlyOldAgeState state;
  final AvsPensionBenefitKind benefitKind;

  // Montant AVS déterminant selon C 13 RV ch. 4005, après plafond,
  // anticipation/ajournement et supplément de veuvage éventuels.
  // Null pour no-entitlement et unknown ; jamais reconstruit depuis un salaire.
  final ChfAmount? determiningOldAgePensionChf;

  final AvsOldAgePensionKind? pensionKind;
  final Set<AvsOldAgeAdjustment> adjustments;
  final Map<AvsExcludedComponentKind, ChfAmount> excludedCashflowsChf;
  final AvsEvidence evidence;
}

class AvsEvidence {
  final AvsEvidenceTier tier;
  final String ownerId;
  final String? documentOrProviderRef;
  final DateTime? sourceDate; // non-null et UTC pour tout calcul accepté
  final DateTime effectiveFrom; // UTC canonique
  final int legalYear;
}

class AvsDecemberEntitlementEvidence {
  final AvsDecemberEntitlementState state;
  final String ownerId;
  final AvsEvidenceTier evidenceTier;
  final bool? aliveOnDecemberFirst;
  final String? decisionOrProviderRef;
  final DateTime? sourceDate; // non-null et UTC pour tout calcul accepté
  final int legalYear;
}

class AvsThirteenthPensionInput {
  final String ownerId;
  final int calendarYear;
  final List<AvsMonthlyOldAgeFact> months; // exactement 12 entrées
  final AvsDecemberEntitlementEvidence decemberEntitlement;
  final AvsPensionPaymentCadence paymentCadence;
  final DateTime? supplementPaymentDate; // UTC ; obligatoire si annualisée
  final ChfAmount? previouslyPaidThirteenthChf;
  final DateTime calculationDate; // UTC canonique
  final int legalYear;
  final String ruleVersion; // ex. OFAS-C13RV-2026-01-01
}

class AvsThirteenthPensionResult {
  final String ownerId;
  final int calendarYear;
  final ChfAmount? decemberOrdinaryOldAgePensionChf;
  final ChfAmount? eligibleOldAgePensionsPaidChf;
  final List<ChfAmount?> monthlyAccrualPartsChf;

  // Non-null seulement avec un état officiel résolu : montant payable ou
  // zéro explicite pour notEntitled/notInForce.
  final ChfAmount? certifiedThirteenthPensionChf;

  // Champ séparé, possible pour données déclarées/scénario ; jamais rendu
  // comme montant de caisse ni copié dans certifiedThirteenthPensionChf.
  final ChfAmount? educationalEstimateChf;

  final ChfAmount? eligibleOldAgeCashflowWithSupplementChf;
  final ChfAmount? correctionAgainstPreviousPaymentChf;
  final AvsPensionPaymentCadence paymentCadence;
  final DateTime? supplementPaymentDate;
  final AvsThirteenthReadiness readiness;
  final List<String> missingFields;
  final Set<AvsExcludedComponentKind> excludedComponentKinds;
  final int legalYear;
  final String ruleVersion;
  final List<String> legalSources;
  final DateTime calculatedAt; // UTC canonique
}
```

### 2.1 Invariants

1. `ownerId` est identique sur l'enveloppe, chaque fait mensuel et sa preuve.
2. Il existe exactement douze mois uniques, dans l'ordre 1 à 12.
3. `paidEligibleOldAge` requiert un montant fini, positif ou nul explicitement
   fourni par la caisse ; `unknown` ne peut porter aucun montant.
4. `explicitlyNoOldAgeEntitlement` n'est pas un montant CHF 0 inventé : c'est
   un état sourcé.
5. Un composant `unknown`, une source absente ou un mois `unknown` interdit
   `certifiedThirteenthPensionChf`.
6. `decemberEntitlement.unknown` produit `pendingDecember`, jamais CHF 0.
7. `notEntitled` sourcé produit `explicitlyNotEntitled` et CHF 0, même si des
   rentes de vieillesse ont été versées avant décembre.
8. Avant décembre, une projection peut alimenter seulement
   `educationalEstimateChf`; le montant certifié reste nul.
9. Un résultat `certified` requiert la source de caisse, la date de source,
   l'année légale, le propriétaire et la version de règle.
10. Une saisie manuelle complète reste `declaredComplete`, avec son origine
    visible ; elle ne devient pas une décision de caisse.
11. La rente mensuelle ordinaire reste le montant de décembre (ou le montant du
    mois affiché), sans division du total annuel par 12.
12. Les cash-flows exclus peuvent être affichés séparément, mais ils ne passent
    jamais dans le calcul du supplément.
13. Un calcul de couple exécute ce contrat deux fois, par propriétaire. Il ne
    somme les résultats qu'après calcul et ne réapplique pas un plafond de 150 %
    au supplément.
14. Les corrections rétroactives recalculent les mois touchés et exposent un
    delta contre `previouslyPaidThirteenthChf`; aucun catch silencieux ne masque
    une restitution ou un paiement complémentaire.
15. `calculationDate`, `supplementPaymentDate`, `sourceDate` et `effectiveFrom`
    sont des instants UTC canoniques. Un `DateTime` local est ambigu et échoue
    fermement ; aucune normalisation implicite par le fuseau de l'appareil.
16. La cadence `annualArticle44Paragraph2` requiert une
    `supplementPaymentDate` qui ne précède pas civilement le 1er décembre de
    l'année de droit. Cadence et date survivent dans le résultat.

### 2.2 Frontière UTC et calendrier civil suisse

L'UTC est le format canonique de transport, pas le calendrier juridique final.
Après validation `isUtc`, l'implémentation convertit l'instant en date civile de
Zurich avec l'heure normale CET (UTC+1) ou l'heure d'été CEST (UTC+2), entre le
dernier dimanche de mars à 01:00 UTC et le dernier dimanche d'octobre à
01:00 UTC. Les comparaisons de mois d'effet et du 1er décembre sont faites sur
cette date civile. Un instant UTC du 31 janvier à 23:30 peut donc appartenir au
1er février en Suisse ; l'issue ne dépend jamais du fuseau de l'appareil.

## 3. Algorithme fail-closed

```text
1. Rejeter owner vide, argent négatif et tout instant non UTC avant toute
   conversion en date civile Europe/Zurich.
2. Exiger legalYear=2026 et ruleVersion=OFAS-C13RV-2026-01-01. Pour une année
   antérieure à 2026 : certified=0 et readiness=notInForce. Après 2026, le
   snapshot 2026 est autorisé uniquement si les douze mois et décembre sont
   tous des preuves scenario ; le résultat reste illustrativeOnly.
3. Vérifier owner, douze mois ordonnés, preuves, ChfAmount et composants.
4. Si cadence annualArticle44Paragraph2, exiger une date de paiement UTC dont
   la date civile suisse ne précède pas le 1er décembre de l'année de droit.
5. Si droit décembre = unknown : certified=null, readiness=pendingDecember.
6. Si droit décembre = notEntitled avec preuve officielle observable : certified=0,
   readiness=explicitlyNotEntitled ; ne pas calculer de prorata.
7. Si un mois ou composant déterminant est inconnu : certified=null avec
   missingFields précis ; ne pas remplacer par zéro ni par le dernier mois connu.
8. Pour chaque mois paidEligibleOldAge : part = arrondi_centime(montant / 12).
   Pour chaque mois explicitementNoOldAgeEntitlement : part=0 sourcé.
9. Somme des parts puis arrondi commercial au franc entier.
10. Déterminer evidenceTier :
   - caisse + calcul effectué lorsque décembre est connu -> certified ;
   - déclaration documentée -> declaredComplete, educationalEstimate seulement ;
   - scénario -> illustrativeOnly, educationalEstimate seulement.
11. Avant le 1er décembre civil suisse, une preuve non-scenario reste
    pendingDecember et ne peut produire qu'une educationalEstimate datée.
12. Conserver séparément : montant mensuel, base annuelle, supplément de
   décembre, total annuel de vieillesse et autres prestations exclues.
13. Si previouslyPaidThirteenthChf existe, retourner le delta explicite.
```

La méthode n'accepte pas `include13eme`, `isOldAge = true` implicite, un montant
mensuel nu ou une constante globale `active = true` comme preuve de droit.

## 4. Cas d'acceptance numérotés

Les valeurs sont synthétiques en CHF. Les calculs suivent C 13 RV ch. 4001 à
4010. Sauf mention contraire, la personne est en vie le 1er décembre, a droit à
la rente de vieillesse en décembre et les faits proviennent de la caisse.

| # | Entrée synthétique | Sortie attendue |
|---|---|---|
| 01 | Rente vieillesse 2'520 de janvier à décembre. | Part 210.00 × 12 ; supplément 2'520 ; rente mensuelle affichée 2'520 ; base annuelle 30'240 ; cash-flow vieillesse avec supplément 32'760. |
| 02 | Rente vieillesse 1'260 de janvier à décembre. | Part 105.00 × 12 ; supplément 1'260 ; total vieillesse 16'380. |
| 03 | Aucun droit janvier-juin, rente 1'800 juillet-décembre. | Six parts de 150.00 ; supplément 900 ; base annuelle 10'800 ; total vieillesse 11'700. |
| 04 | Aucun droit janvier-novembre, rente 1'266 en décembre. | Part 105.50 ; arrondi final au franc supérieur : supplément 106 ; base annuelle 1'266. |
| 05 | Aucun droit janvier-septembre, rente 1'270 octobre-décembre. | Trois parts de 105.83 = 317.49 ; arrondi final au franc inférieur : supplément 317. |
| 06 | Rente 2'520 janvier-juin, puis rente plafonnée 1'890 juillet-décembre. | 6 × 210.00 + 6 × 157.50 = supplément 2'205. Cas OFAS. |
| 07 | Anticipation totale : rente réduite 2'160 janvier-décembre. | Supplément 2'160 ; ne pas utiliser la rente non réduite. |
| 08 | Anticipation : rente réduite 2'160 janvier-août, puis nouveau montant réduit 2'275 septembre-décembre. | 8 × 180.00 + 4 × 189.58 = 2'198.32 ; supplément arrondi 2'198. Cas OFAS. |
| 09 | Ajournement révoqué : rente augmentée 2'951 janvier-décembre. | 12 × 245.92 = 2'951.04 ; supplément 2'951. La majoration est incluse. |
| 10 | Ajournement total non révoqué au 1er décembre ; aucun mois de rente perçu. | Droit décembre `notEntitled`, supplément certifié CHF 0, readiness `explicitlyNotEntitled`. |
| 11 | Ajournement partiel : seule une part de rente de 1'000 est perçue chaque mois. | 12 × 83.33 = 999.96 ; supplément 1'000. La part encore ajournée est exclue. |
| 12 | Rente 2'000 janvier-novembre ; décès le 30 novembre. | Pas de droit en décembre ; supplément CHF 0, sans prorata des 22'000 déjà versés. |
| 13 | Rente 2'000 janvier-décembre ; décès le 15 décembre. | Rente décembre et supplément 2'000 dus ; total vieillesse 26'000 ; montants en cours dans la succession. |
| 14 | Rente AI 1'800 janvier-juin, conversion en rente vieillesse 2'000 juillet-décembre. | AI exclue ; six parts de 166.67 = 1'000.02 ; supplément 1'000 ; base vieillesse 12'000. |
| 15 | Rente de survivant 2'100 toute l'année, aucune rente de vieillesse en décembre. | Supplément CHF 0, readiness `explicitlyNotEntitled`. |
| 16 | Chaque mois : rente vieillesse déterminante 2'000 + rente enfant 500 + rente complémentaire 100 + supplément AVS21 50. | Base du supplément limitée à 2'000/mois ; supplément 2'000. Les 650/mois restent des cash-flows exclus séparés. |
| 17 | Rente vieillesse comprenant 1'800 de base et 360 de supplément de veuvage, montant de caisse 2'160, toute l'année. | Montant déterminant 2'160 ; supplément 2'160. Ne pas ajouter le supplément de veuvage deux fois. |
| 18 | Couple : chaque personne reçoit une rente plafonnée de 1'890 toute l'année. | Deux calculs owner-scoped : 1'890 chacun ; supplément household affichable 3'780 après somme, sans nouveau plafonnement. |
| 19 | Un mois porte `unknown`; les onze autres mois valent 2'000 et le droit décembre est connu. | `certifiedThirteenthPensionChf=null`, readiness `missingMonthlyHistory`; aucun remplacement du mois par 0 ou 2'000. |
| 20 | Douze virements bancaires sont présents mais une composante n'est pas classée par la caisse. | Montant certifié nul, readiness `unclassifiedComponent`; un virement net n'est pas une preuve de base AVS déterminante. |
| 21 | Calcul demandé le 13 juillet 2026 avec 2'000 projetés jusqu'en décembre. | `certifiedThirteenthPensionChf=null`, readiness `pendingDecember` ou `illustrativeOnly`; une estimation éducative de 2'000 peut rester séparée et datée. |
| 22 | Rente annualisée art. 44, al. 2 : équivalent 200/mois de juin à décembre 2026, vivant le 1er décembre. | 7 × 16.67 = 116.69 ; supplément 117 dû pour 2026 et payé avec la rente annuelle en juin 2027. |
| 23 | Rente vieillesse 2'000 janvier-août, puis remplacement par rente de survivant plus élevée dès septembre et extinction du droit vieillesse avant décembre. | Supplément CHF 0 ; aucun prorata des huit mois de vieillesse. |
| 24 | Rente vieillesse 2'000 janvier-octobre, puis extinction sourcée du droit après transfert à l'étranger avant le 1er décembre. | Supplément CHF 0 ; état explicitement non éligible. |
| 25 | Supplément déjà payé 2'000 ; correction rétroactive : 2'100 janvier-juin, 2'000 juillet-décembre. | 6 × 175.00 + 6 × 166.67 = 2'050.02 ; nouveau supplément 2'050 ; delta de paiement +50. |
| 26 | Supplément déjà payé 2'000 ; correction rétroactive : 1'900 janvier-juin, 2'000 juillet-décembre. | 6 × 158.33 + 6 × 166.67 = 1'950.00 ; nouveau supplément 1'950 ; restitution/delta -50, jamais absorbé silencieusement. |
| 27 | Année civile 2025, rente vieillesse 2'520 janvier-décembre. | Supplément CHF 0, readiness `notInForce`; la base annuelle de rente reste 30'240. |

Tests additionnels structurels obligatoires : mois dupliqué, mois hors 1..12,
`NaN`/infini, valeur négative, owner mismatch, sourceDate absente, legalYear
incompatible, rente AI injectée comme vieillesse, composant inconnu et calcul
couple avec owners inversés doivent tous échouer fermement.

## 5. Source, date, confiance et statut produit

Chaque fait mensuel doit conserver :

- propriétaire (`ownerId`) ;
- source et référence de document ou de provider ;
- date de source et date d'effet ;
- année légale ;
- nature vieillesse ordinaire/extraordinaire ;
- état après plafond, anticipation, ajournement et supplément de veuvage ;
- prestations exclues, sans les fusionner dans la base ;
- niveau de preuve.

Hiérarchie de rendu :

| preuve | sortie autorisée |
|---|---|
| registre/décision de caisse, douze mois complets, droit décembre résolu | montant `certified`, source et date visibles |
| saisie manuelle depuis un document, complète | calcul `declaredComplete`, jamais présenté comme montant de caisse |
| scénario futur complet | `educationalEstimate`, hypothèses et date visibles |
| mois, composant, droit décembre ou owner manquant | pas de montant ; état partiel + question ciblée |

Même avec douze mois saisis, un calcul exécuté avant décembre ne devient pas
certifié : l'OFAS indique qu'aucun calcul précis n'est possible avant décembre.
Après décembre, la certification MINT requiert encore une preuve de la caisse
compétente ; une saisie manuelle reste une estimation éducative.

Question de récupération prioritaire : « As-tu une décision ou un relevé de ta
caisse AVS qui indique les montants de rente de vieillesse versés pour chaque
période de cette année ? » Une liaison de compte conjoint ne remplace ni le
consentement par champ ni l'identité propriétaire de cette preuve.

## 6. Ambiguïtés et limites à ne pas deviner

La circulaire 2026 ferme les règles principales, y compris les corrections et
les restitutions. Les points suivants doivent toutefois rester provider- ou
spécialiste-required tant que MINT n'a pas intégré les données de caisse :

1. Le libellé d'un virement bancaire ne permet pas de séparer rente déterminante,
   compensation, restitution, saisie ou autre prestation.
2. Un changement rétroactif exige le mois d'effet officiel et le montant corrigé
   de chaque période ; MINT ne répartit pas lui-même un paiement global.
3. Pour une rente annualisée ou un dossier international, la date de cash réelle
   peut être postérieure au mois de droit. Le provider doit exposer l'année de
   droit et la période, pas seulement la date bancaire.
4. Une fin de droit lors d'un départ à l'étranger dépend du statut/convention et
   d'une décision de caisse ; le changement d'adresse seul ne suffit pas.
5. Le choix survivant/vieillesse et sa date d'effet proviennent de la caisse.
6. L'ordinogramme AVS-AI demeure la référence d'exécution pour le calcul au
   centime. L'implémentation doit utiliser `Decimal` et les fixtures officielles
   C 13 RV ; elle ne doit pas dépendre du mode d'arrondi natif d'un langage.

## 7. Séparation obligatoire dans l'UI, le dossier et le PDF

Un consumer affiche au minimum :

```text
Rente de vieillesse ordinaire du mois : CHF X
13e rente estimée/certifiée, versée séparément : CHF Y en décembre
Total annuel de rente de vieillesse, supplément compris : CHF Z
Source : caisse / déclaration / scénario — date — année légale
```

Il y a **douze rentes ordinaires récurrentes**. Il est interdit d'afficher
`Z / 12` comme nouvelle rente mensuelle ou de présenter le supplément comme un
treizième mois récurrent. Un budget mensuel utilise `X`; le calendrier de
cash-flow ajoute `Y` séparément en décembre ou à la date du versement annualisé
portée par `supplementPaymentDate`. Les prestations enfant, AVS21, AI,
survivants, PC et autres cash-flows ont leurs propres lignes.

## 8. État de la migration sur le snapshot audité `06115ed38`

Vérification réalisée le 2026-07-13 avec :

```bash
rg -n 'AvsCalculator\.annualRente|include13eme|avs13emeRenteFactor|avsNombreRentesParAn|avsRenteMaxAnnuelle13m|avsMaxAnnualRenteForYear|avsMaxRenteAnnuelleForYear' apps/mobile/lib apps/mobile/test
```

Le grep est vide. `AvsCalculator.annualRente` et les alias `×13` ont été
supprimés, pas conservés comme façade sans caller.

### 8.1 Production — état des quatre anciens consumers

| consumer | état au snapshot | dette restante |
|---|---|---|
| `IndependantsService.calculateLppVolontaire` | Douze rentes ordinaires par défaut ; scénario typé seulement derrière un flag local default-off. | Les P2 owner générique et fusion du supplément dans les projections restent ouverts ; aucun renderer distinct. |
| `AvsGapWidget._lifetimeLoss` | Utilise `AvsCalculator.ordinaryRecurringLifetimeLoss`, soit perte mensuelle × 12 × années ; le supplément est exclu. | Une éventuelle projection future du supplément exigera son propre calendrier et ses propres hypothèses. |
| `RetirementProjectionService` — owner self | Utilise la rente mensuelle ordinaire sans `annual / 12`. | Aucun événement typé de supplément n'est activé dans cette projection. |
| `RetirementProjectionService` — owner partner | Même migration, sans convertir une absence partenaire en zéro. | Le futur événement requiert owner partenaire et consentement par champ. |

### 8.2 Tests et alias

Le contrat exact est couvert par
`apps/mobile/test/services/financial_core/avs_thirteenth_pension_calculator_test.dart`
(71 tests à ce snapshot), avec les cas numérotés, les erreurs structurelles, la
cadence annualisée, le snapshot futur scenario-only et les frontières UTC / mois
civil Zurich. Les anciens golden tests `×12/×13` ont été migrés vers le contrat
typé ou la rente ordinaire récurrente. La précédence d'un `notEntitled` officiel
sur une source mensuelle réellement absente reste toutefois un P2 non couvert.

Les alias historiques ont été retirés de `social_insurance.dart` et
`retirement_service.dart`. Une année civile postérieure à 2026 n'est toujours
pas une preuve : les données officielles sont refusées, et seul un jeu de preuves
entièrement `scenario` peut réutiliser le snapshot 2026 comme estimation
illustrative.

## 9. Gates d'implémentation G1-AVS-02

Le ticket peut devenir vert seulement si :

1. un test RED démontre les échecs de `monthly * 13`, du début en juillet, de
   l'absence de droit en décembre et de l'inflation mensuelle `annual / 12` ;
2. le contrat owner-scoped en centimes exacts (`ChfAmount`) est implémenté dans
   `financial_core` ;
3. `avs_thirteenth_pension_calculator_test.dart` couvre les 27 cas d'acceptance,
   les cas structurels, UTC/Zurich, cadence/date et snapshot futur ;
4. les quatre consumers production sont migrés ou réellement inaccessibles ;
5. `rg` prouve zéro `annualRente`, zéro `include13eme` et zéro conversion
   générique `13 / 12` pour l'AVS ;
6. le calendrier sépare rente mensuelle et paiement de décembre ;
7. source, sourceDate, legalYear, owner, missingFields et readiness survivent à
   la persistence ;
8. le couple reste deux personnes et le partenaire facultatif, révocable et
   limité par consentement ;
9. les tests ciblés, le corpus `financial_core`, l'analyse Flutter et le gate
   ledger sont verts ;
10. les audits externes `code` et `product-domain` n'ont plus de P0/P1 ;
11. la scorecard et la preuve runtime Maestro/Patrol restent NO-GO jusqu'au
    parcours réellement câblé.

État borné à ce snapshot : les points 1 à 5 sont couverts par la migration
et les tests statiques. Le calendrier existe dans le résultat typé, mais le
point 6 n'est pas rempli côté renderer. Les points 7, 10 et 11 restent ouverts,
de même que l'owner réel requis par le point 8. Aucun GO produit ou runtime ne
peut être déduit du seul passage des 71 tests du calculateur.

## 10. Sources officielles primaires

| proposition | source | état |
|---|---|---|
| droit en décembre, un douzième du montant perçu dans l'année, versement en décembre ou avec la rente annualisée | [Fedlex — LAVS art. 34ter](https://www.fedlex.admin.ch/eli/cc/63/837_843_843/fr#art_34_ter) | droit applicable dès 01.01.2026 |
| extinction du rétroactif au décès, succession ; concours survivant/vieillesse ; plafond couple | [Fedlex — LAVS arts. 24b, 35 et 46, al. 2bis](https://www.fedlex.admin.ch/eli/cc/63/837_843_843/fr) | loi vérifiée 13.07.2026 |
| exécution réglementaire du supplément et arrondi commercial au franc | [Fedlex — RAVS arts. 52ater à 52aquinquies et 53, al. 2](https://www.fedlex.admin.ch/eli/cc/63/1185_1183_1185/fr) | règlement vérifié 13.07.2026 |
| conditions, mois, composants, centimes, anticipation, ajournement, décès, annualisation, corrections et cas transitoires | [OFAS — Circulaire sur la 13e rente de vieillesse, C 13 RV, ch. 1001-13001](https://sozialversicherungen.admin.ch/fr/d/21610/download) | valable dès 01.01.2026 ; état 17.06.2026 |
| synthèse, exclusions, caisse compétente et impossibilité d'un calcul précis avant décembre | [OFAS — Mise en œuvre de la 13e rente AVS](https://www.bsv.admin.ch/fr/misenoeuvre-13-rente-avs) | publié 19.06.2026 |
| explication législative : décès, anticipation, ajournement, supplément de veuvage inclus, AVS21 exclu | [Message du Conseil fédéral FF 2024 2747, commentaire art. 34ter](https://www.fedlex.admin.ch/filestore/fedlex.data.admin.ch/eli/fga/2024/2747/fr/pdf-a/fedlex-data-admin-ch-eli-fga-2024-2747-fr-pdf-a.pdf) | message 16.10.2024 ; loi adoptée depuis |
| information aux bénéficiaires, prorata, exclusions et arrondi | [Centre d'information AVS/AI — 13e rente AVS](https://www.ahv-iv.ch/fr/Assurances-sociales/Assurance-vieillesse-et-survivants-AVS/13e-rente-AVS) | consulté 13.07.2026 |

La C 13 RV état 17 juin 2026 est la source opérationnelle de premier rang pour
le calcul 2026. Son `ruleVersion` logiciel reste
`OFAS-C13RV-2026-01-01`, date d'entrée en vigueur du snapshot ; l'état de la
circulaire est documenté séparément et doit être revérifié avant toute nouvelle
activation. Le message explique le sens du texte mais ne remplace pas la loi et
la circulaire en vigueur.

### Disclaimer éducatif

> Les résultats présentés sont des estimations à titre indicatif, basées sur
> les données fournies et la législation en vigueur. Ils ne constituent pas un
> conseil financier personnalisé. Consultez un·e spécialiste pour votre
> situation spécifique.

# G1-PROV-03 — Contrat d’ingestion d’une taxation suisse

**Statut :** contrat métier implémenté et GREEN sur les tests ciblés; activation
runtime bloquée par le gate composite
`FeatureFlags.taxAssessmentIngestionEnabled=false`
**Périmètre :** personnes physiques, impôts directs ordinaires
**Sources vérifiées le :** 13 juillet 2026

## 1. Verdict métier

**GREEN pour l’implémentation de G1-PROV-03; NO-GO pour l’activation**, tant
que les preuves runtime gelées, les audits Claude externes et la scorecard G1
finale ne sont pas acquis. Le contrat livré respecte les conditions suivantes :

1. MINT ne doit plus confondre une **déclaration fiscale remplie par le
   contribuable**, un **bordereau provisoire**, une **décision/avis de taxation**
   et un **bordereau final**. Seuls les champs confirmés d’une décision/avis de
   taxation émis par l’autorité peuvent recevoir la source mobile
   `certificate`.
2. Une déclaration confirmée reste `userInput`; un bordereau/acompte
   provisoire reste `estimated`; un résultat OCR non confirmé reste un candidat
   sans écriture au Data Ledger.
3. Le « taux moyen » et `(impôts / revenu imposable)` ne sont pas des taux
   marginaux. Ils ne doivent jamais hydrater `marginalIncomeTaxRate` ni piloter
   un arbitrage 3a/LPP/retraite.
4. `_coach_tax_impot_cantonal` est mal nommé : le parseur accepte tantôt
   l’impôt cantonal seul, tantôt un total cantonal et communal (« ICC »). Une
   valeur ne peut être agrégée que si le document le dit explicitement.
5. `legalYear` est ambigu. Le nom canonique fiscal doit être `taxYear`
   (période fiscale). Il ne renomme et ne réutilise pas le `legalYear` de
   `avs_thirteenth_pension_calculator.dart`, qui décrit une année de régime
   légal pour le treizième versement AVS.
   La version de droit utilisée par un calcul fiscal futur est encore une autre
   métadonnée (`rulesetVersion`) et ne doit pas être extraite comme un fait du
   contribuable.

Une décision de taxation fixe les éléments imposables, le taux et le montant
d’impôt pour une année. Elle reste susceptible de réclamation avant son entrée
en force. Le mot « définitif » sur une facture ne suffit donc pas à inférer
`inForce`.

### État de livraison vérifiable

Le modèle typé, le writer unique, la persistance strict-secure, le cold reload,
le selector, la revue et l’impact fiscal sont câblés dans `apps/mobile/`. Le
chemin reste fail-closed et invisible en production par défaut : ce statut
GREEN de code ne vaut ni décision d’activation, ni preuve runtime finale.

Les preuves de code canoniques sont rejouables notamment dans :

- `apps/mobile/test/providers/coach_profile_provider_tax_extraction_test.dart` ;
- `apps/mobile/test/providers/tax_provenance_profile_test.dart` ;
- `apps/mobile/test/screens/document_scan/tax_extraction_review_screen_test.dart` ;
- `apps/mobile/test/screens/document_scan/tax_feature_flag_and_impact_test.dart` ;
- `apps/mobile/test/screens/document_scan/tax_scan_local_only_source_contract_test.dart` ;
- `apps/mobile/test/services/document_parser/tax_assessment_parser_contract_test.dart` ;
- `apps/mobile/test/services/financial_core/confidence_scorer_tax_source_contract_test.dart` ;
- `apps/mobile/test/services/financial_core/confidence_scorer_tax_kill_switch_test.dart` ;
- `apps/mobile/test/services/secure_wizard_store_test.dart` ;
- `apps/mobile/test/services/tax_backend_privacy_wiring_test.dart`.

Les harness Maestro/Patrol existent, mais leur exécution sur un SHA gelé et un
même simulateur, les audits Claude via le wrapper MINT et la scorecard finale
restent des gates G1 en attente. Aucun de ces éléments n’est présumé par le
présent document.

## 2. Modèle typé minimal

`FiscalProfile` est intégré à `CoachProfile`, sans second store :

```text
FiscalProfile
  snapshots: List<TaxSnapshot>
  provenanceValidatedSnapshotIds: Set<String>
  legacyDataNeedsReview: bool

TaxSnapshot
  snapshotId: String                  // UUID v4 local opaque et path-safe
  profileOwnerId: String              // UUID v4 local stable du profil fiscal
  taxYear: int?                       // année civile imposée, jamais inférée
  basedOnTaxYear: int?                // utile aux bordereaux provisoires
  sourceDate: DateTime?               // date émise/imprimée par la source
  documentKind: TaxDocumentKind
  assessmentStatus: TaxAssessmentStatus
  inForceAttested: bool                // false par défaut; attestation secondaire explicite
  subjectScope: TaxSubjectScope
  cantonCode: String?
  municipalityId: String?             // identifiant canonique si disponible
  municipalityLabel: String?
  cantonalCommunalTaxableIncomeChf: double?
  federalTaxableIncomeChf: double?
  cantonalCommunalTaxableWealthChf: double?
  cantonalCommunalAssessedTax: AssessedTaxAmount?
  federalDirectAssessedTax: AssessedTaxAmount?
  explicitMarginalIncomeTaxRate: double?  // ratio 0...1
  explicitAverageIncomeTaxRate: double?   // ratio 0...1, champ distinct
  updatedAt: DateTime                 // confirmation, pas date de la source

AssessedTaxAmount
  amountChf: double
  authorityScope: cantonalOnly | communalOnly |
                  cantonalCommunalCombined | federalDirect | unknown
  baseScope: incomeOnly | wealthOnly | incomeAndWealth |
             totalInvoice | unknown

TaxDocumentKind
  taxpayerReturn | provisionalBill | assessmentNotice |
  finalTaxBill | unknown

TaxAssessmentStatus
  selfDeclared | provisional | assessedAppealable |
  contested | inForce | unknown

TaxSubjectScope
  individual | jointlyAssessedCouple | unknown
```

Le seul payload fiscal persistant est la clé strict-secure
`_coach_tax_snapshots_v1` du snapshot logique `wizard_answers_v2`, avec la
forme exacte `{schemaVersion: 1, snapshots: [...], legacyQuarantine: {...}}`.
La quarantaine legacy n’utilise jamais une seconde clé autonome. Les détails
de sérialisation et de validation complets restent normatifs dans
`DATA_LEDGER.md` §4.0.

`snapshotId` est créé une seule fois dans `TaxExtractionCandidate`, au moment
où un résultat de parsing est retenu pour revue. Il est distinct du
`scanSessionId` de route. Une correction de revue et un retry de sauvegarde du
même candidat réutilisent cet identifiant; le cold reload ne le retrouve
qu’après la sauvegarde canonique. Ce contrat ne prétend pas persister l’OCR ou
son identifiant avant parsing, ni reprendre un OCR après process death. Un
autre candidat documentaire reçoit un autre identifiant. Il doit respecter
`^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`, ne
contenir ni point ni séparateur de chemin, et ne jamais
être dérivé du texte OCR, d’un numéro de contribuable ou d’une autre donnée
personnelle. Il est donc stable pour les chemins de provenance sans devenir un
identifiant métier.

### Pourquoi une liste de snapshots

Une déclaration 2025, un provisoire 2025 fondé sur 2024 et une décision 2024
peuvent coexister. Ils ne doivent ni s’écraser ni former un faux dossier hybride.
Une écriture remplace atomiquement un snapshot du même document; elle ne fusionne
jamais des champs de périodes, d’autorités ou d’unités fiscales différentes.

### Seam d’ingestion obligatoire

Le chemin livré doit être typé de bout en bout; aucun des maillons suivants ne
peut être court-circuité :

```text
TaxDeclarationParser
  -> TaxExtractionCandidate            // candidat, zéro écriture profil
  -> TaxReviewConfirmation             // valeurs + métadonnées confirmables
  -> CoachProfileProvider.acceptTaxReview(...)
  -> TaxProfilePersistence             // load/save injectable, même snapshot
  -> CoachProfile.fromWizardAnswers    // cold reload exact
  -> FiscalSnapshotSelector.selectAssessedBaseline(...)
```

- Le parser produit des candidats typés et des indices de classification. Il
  n’émet ni chemin `CoachProfile`, ni `ProfileDataSource`, ni fait certifié. Le
  candidat OCR éphémère peut refléter une incohérence du document, y compris un
  montant IFD associé à `wealthOnly` ou `incomeAndWealth`; cette représentation
  brute n’autorise jamais sa confirmation.
- La revue fait confirmer/corriger au minimum `documentKind`,
  `assessmentStatus`, `taxYear`, `sourceDate`, `subjectScope`, les périmètres
  ICC/IFD et chaque valeur retenue. Une combinaison kind/status invalide ne
  peut pas produire un `TaxReviewConfirmation` accepté. Pour un périmètre IFD
  brut incohérent, l’UI présélectionne `unknown`, affiche l’incohérence et ne
  propose pas de confirmer `wealthOnly` ou `incomeAndWealth`.
- Le provider est le seul mutateur. Il construit valeur, métadonnées et
  provenance, puis appelle un `TaxProfilePersistence` injectable qui enveloppe
  `loadAnswers/saveAnswers`. Il publie le nouveau profil et notifie les
  listeners uniquement après le succès d’un appel logique unique de sauvegarde
  de `wizard_answers_v2`. Ce contrat d’ordre ne prétend pas fournir une
  transaction crash-atomique entre SecureWizardStore et SharedPreferences.
- Le cold reload reconstruit les snapshots, leurs identifiants et leur
  provenance sans réinférence. Son chemin de load exécute d’abord le helper
  privé `CoachProfileProvider._withLegacyTaxQuarantine(...)`, puis seulement
  `CoachProfile.fromWizardAnswers`. Les consommateurs n’accèdent pas directement
  à `snapshots`; ils passent par `FiscalSnapshotSelector`. Une entrée froide
  invalide ou dont `sourceDate` est future est exclue de la validation de
  provenance et de toute sélection, sans correction, clamp ou réinférence.

### Chemins de provenance

Chaque valeur métier active conserve sa provenance field-centric sur un chemin
exact, par exemple :

```text
fiscal.snapshots.<snapshotId>.cantonalCommunalTaxableIncomeChf
fiscal.snapshots.<snapshotId>.federalTaxableIncomeChf
fiscal.snapshots.<snapshotId>.cantonalCommunalAssessedTax.amountChf
fiscal.snapshots.<snapshotId>.federalDirectAssessedTax.amountChf
fiscal.snapshots.<snapshotId>.explicitMarginalIncomeTaxRate
```

Les métadonnées qui changent le sens ou la sélection reçoivent elles aussi une
provenance exacte :

```text
fiscal.snapshots.<snapshotId>.taxYear
fiscal.snapshots.<snapshotId>.basedOnTaxYear
fiscal.snapshots.<snapshotId>.sourceDate
fiscal.snapshots.<snapshotId>.documentKind
fiscal.snapshots.<snapshotId>.assessmentStatus
fiscal.snapshots.<snapshotId>.inForceAttested
fiscal.snapshots.<snapshotId>.subjectScope
fiscal.snapshots.<snapshotId>.cantonCode
fiscal.snapshots.<snapshotId>.municipalityId
fiscal.snapshots.<snapshotId>.municipalityLabel
```

`inForceAttested=false` reste sérialisé comme état de schéma par défaut pour
un cold reload fidèle, mais ne constitue pas un fait d’attestation actif et ne
reçoit donc aucun chemin de provenance. Le chemin exact
`inForceAttested` devient obligatoire uniquement lorsque sa valeur est `true`.

L’enveloppe reste exactement `{source, updatedAt, sourceDate}`. La source des
métadonnées suit la classification confirmée du snapshot (`certificate`,
`userInput` ou `estimated`), elle n’est pas promue par le parser. `sourceDate`
est la date du document, pas la date d’acceptation par MINT. Elle reste `null`
si le document n’en fournit pas et doit être inférieure ou égale à la date
civile `today` fournie par une horloge injectable. Une date future bloque la
revue et le writer; à froid elle exclut le snapshot. `taxYear` et
`basedOnTaxYear`, lorsqu’ils sont connus, restent dans `1900...today.year`; pour
un provisoire, `basedOnTaxYear` ne peut pas dépasser `taxYear`. Les mêmes
défenses existent dans la confirmation, le writer, la validation froide et le
selector indépendant. `updatedAt` est l’instant où l’utilisateur confirme la
valeur. `taxYear` est stocké dans le snapshot; il n’est jamais déduit de
`sourceDate` ou de l’année courante. `snapshotId` est une identité technique et
ne reçoit pas de provenance financière.

### Matrice document, état et source

Seules ces combinaisons peuvent sortir de la revue :

| `documentKind` | `assessmentStatus` admis | source des faits documentaires confirmés |
|---|---|---|
| `taxpayerReturn` | `selfDeclared` | `userInput` |
| `provisionalBill` | `provisional` | `estimated` |
| `assessmentNotice` | `assessedAppealable`, `contested`, `inForce` | `certificate` |
| `finalTaxBill` | `unknown` | `estimated`; non-baseline |
| `unknown` | `unknown` | `estimated`; affichage partiel seulement |

`inForce` exige toujours une attestation secondaire explicite
`inForceAttested=true`, séparée du texte parsé et décochée par défaut. Le parser
ne peut jamais la produire. Pour le MVP, cette attestation de revue et les
chemins `assessmentStatus`/`inForceAttested` qui en dépendent ont une provenance
`userInput`; les montants et métadonnées réellement lus dans l’avis de taxation
restent `certificate`. La provenance est donc field-centric et ne peut pas être
déduite d’une source homogène attribuée au snapshot entier. À froid,
`assessmentStatus=inForce` sans attestation ou sans provenance exacte est exclu
des snapshots validés et du selector. Toute autre paire kind/status reste
candidate/quarantaine et n’entre pas dans `FiscalProfile`. Un
`finalTaxBill` seul ne certifie aucun élément. S’il embarque aussi une décision
autoritative identifiable, la revue doit reclassifier le document ou les
éléments concernés en `assessmentNotice` avant toute source `certificate`.
Un `provisionalBill`, `finalTaxBill` ou document `unknown` peut conserver un
taux explicitement libellé « marginal » avec source `estimated`, pour affichage
seulement. Les consommateurs financiers de baseline excluent ces snapshots; un
taux moyen reste `explicitAverageIncomeTaxRate` et ne devient jamais marginal.

### Gate composite d’ingestion fiscale

Les deux kill switches locaux restent `false` par défaut :

- `FeatureFlags.typedTaxProfile` contrôle le ledger typé, son writer et son
  selector. À `false`, le provider refuse toute publication typée,
  `FiscalSnapshotSelector` retourne une baseline indisponible/`partial+ask`, et
  aucun `_coach_tax_*` legacy ne sert de fallback ;
- `FeatureFlags.documentTaxAssessmentEnabled` contrôle les surfaces
  d’acquisition et de revue documentaire. À `false`, elles restent masquées et
  leurs handlers retournent avant toute acquisition.

Le gate produit est leur conjonction exacte :

```text
taxAssessmentIngestionEnabled =
  documentTaxAssessmentEnabled && typedTaxProfile
```

Un seul flag à `true` ne suffit jamais à exposer le parcours. L’activation
exige les tests ciblés GREEN, une preuve runtime write → restart → read →
selector sur le même SHA, puis une décision explicite de `mint-lead`.

## 3. Sémantique fiscale obligatoire

### Revenu et fortune imposables

- Un document peut présenter des revenus imposables différents pour l’ICC et
  l’IFD. Le champ unique actuel `revenuImposable` est insuffisant.
- La fortune imposable relève des cantons et communes, pas de l’IFD des
  personnes physiques.
- Un montant négatif explicitement libellé revenu imposable ICC ou IFD est
  conservé tel quel à l’ingestion et reconfirmé; MINT ne le transforme ni en
  zéro ni en impôt négatif. Son usage par un calcul dépend du canton, du
  ruleset et du libellé exact; il reste `partial+ask` si le document désigne
  plutôt une perte ou un revenu net. En revanche, fortune imposable, montants
  d’impôt et taux négatifs restent des candidats incohérents et ne deviennent
  pas des faits confirmés.
- Une valeur négative libellée « fortune nette » ne doit pas être requalifiée en
  « fortune imposable ». Une `cantonalCommunalTaxableWealthChf` négative est un
  candidat incohérent à vérifier, pas un fait connu.
- `deductionsEffectuees` est hors du modèle minimal tant que le document ne
  distingue pas les déductions déclarées/admis(es) et leur base ICC/IFD.

### Impôts taxés

- `cantonalCommunalCombined` n’est accepté que pour un libellé explicite tel que
  « impôt cantonal et communal », « ICC » ou l’équivalent allemand.
- « Impôt cantonal » / `Kantonssteuer` alimente `cantonalOnly`, jamais le total
  cantonal-communal.
- Le périmètre revenu/fortune doit être explicite; un total de facture qui peut
  inclure impôt ecclésiastique, taxe personnelle, intérêts ou acomptes reste
  `totalInvoice` et ne devient pas un montant ICC pur.
- `unknown` et `totalInvoice` sont persistables comme connaissance partielle
  après revue, avec leur provenance exacte, mais restent non consommables : le
  selector retourne `partial+ask`. Ils ne sont ni supprimés, ni promus, ni
  convertis silencieusement en `incomeOnly` ou `incomeAndWealth`.
- Pour un montant `federalDirect`, `incomeOnly` est le seul périmètre consommable.
  `unknown` peut être persisté comme partiel; `wealthOnly` et
  `incomeAndWealth` sont refusés par la confirmation et par le writer, avec zéro
  sauvegarde et zéro publication. Le fait que le candidat OCR puisse porter ces
  deux valeurs sert uniquement à montrer l’incohérence à corriger.
- IFD et ICC restent deux montants séparés. Leur somme peut être une vue
  d’affichage étiquetée, pas un nouveau fait persisté.

### Taux marginal

- Stockage canonique en **ratio** : `0.315` pour `31,5 %`. Le format actuel
  `31.5` ne doit pas entrer dans le nouveau modèle.
- `explicitMarginalIncomeTaxRate` n’est rempli que si le document indique
  explicitement « taux marginal » / `Grenzsteuersatz` et si son périmètre est
  intelligible.
- « Taux moyen », « taux effectif » / `Effektiver Steuersatz` et
  `(ICC + IFD) / revenu` alimentent au plus
  `explicitAverageIncomeTaxRate`; ils ne sont jamais des alias ou fallbacks du
  taux marginal.
- Une estimation marginale future est un résultat de calcul `estimated`, avec
  canton, commune, année, unité fiscale et hypothèses; elle ne fait pas partie
  de l’ingestion certifiée.

### État et unité de taxation

- `assessmentNotice` devient `assessedAppealable` par défaut, mais ce nom
  technique signifie uniquement « taxé, entrée en force non confirmée ». Il
  n’affirme jamais qu’un délai de réclamation est encore ouvert : `sourceDate`
  n’est pas la date de notification et MINT ne calcule aucun délai procédural.
  `inForce` exige une attestation secondaire explicite; ne pas l’inférer de la
  date d’émission, de « bordereau définitif », de « décision exécutoire » ou
  d’un indice OCR.
- En Suisse, au 14 juillet 2026, les époux sont encore imposés conjointement.
  Le [DFF confirme que la loi sur l’imposition individuelle a été acceptée le
  8 mars 2026 et entrera en vigueur au plus tard en
  2032](https://www.efd.admin.ch/fr/votation-imposition-individuelle), à une
  date encore à fixer. Le
  `subjectScope` doit donc venir du document ou d’une confirmation et rester lié
  à `taxYear`; il ne doit pas être déduit du seul état civil actuel.
- Un snapshot `jointlyAssessedCouple` appartient à l’unité fiscale. Il ne doit
  pas être divisé entre deux personnes. L’absence de compte partenaire ne vaut
  jamais revenu, fortune ou impôt partenaire égal à zéro.
- Le lien de comptes reste optionnel. Importer localement une taxation commune
  ne donne pas un consentement de partage vers le compte partenaire.

## 4. Sélection par les consommateurs

Le seul sélecteur de consommation est
`FiscalSnapshotSelector.selectAssessedBaseline(fiscalProfile, query)`. Pour une
année demandée, il n’accepte que cette année; pour « dernière taxation », il
classe les snapshots éligibles par le tuple déterministe suivant :

1. `taxYear` décroissant;
2. état `inForce` avant `assessedAppealable`;
3. `sourceDate` décroissante, `null` en dernier;
4. à rang égal, comparaison du payload sémantique canonique;
5. uniquement pour des doublons sémantiquement identiques, `updatedAt`
   décroissant puis `snapshotId` croissant comme tie-breakers techniques.

Le sélecteur filtre d’abord le champ demandé, le périmètre d’autorité, la
juridiction et l’unité fiscale compatibles, puis exclut les `sourceDate`
postérieures à son `today` injectable et tout `inForce` sans attestation et
provenance exactes. `contested`, `selfDeclared`,
`provisional` et `unknown` restent visibles dans leur vue dédiée, mais ne sont
pas une baseline taxée. Deux snapshots de même rang, même date de source et
même périmètre qui divergent sur kind/status, unité fiscale, juridiction,
périmètre d’impôt ou valeur entrent en conflit **avant** toute comparaison de
`updatedAt`/UUID : le résultat est `partial+ask` et les deux restent en
quarantaine. `updatedAt` et UUID ne départagent que des duplications
sémantiquement identiques; ils ne masquent jamais un conflit métier. Une
déclaration ou un provisoire ne remplace donc pas une taxation antérieure de
l’autorité.

Cette défense appartient aussi au sélecteur lui-même : un snapshot `inForce`
avec attestation absente ou `false` reste `partial+ask`, même si son identifiant
apparaît à tort dans `provenanceValidatedSnapshotIds`. Le set validé ne remplace
jamais la vérification du booléen explicite.

Si `taxYear`, `subjectScope`, le périmètre du montant ou la juridiction requise
manque, le résultat reste `partial+ask`. Si `sourceDate` manque,
`latestCompleteness` reste `partial+ask`; une requête historique précise peut
garder la valeur visible avec le statut `availableNeedsConfirmation`, mais elle
ne doit pas être présentée comme actuelle ou complète. `null` signifie inconnu;
il ne devient jamais `0`.

### Migration des clés legacy

Au premier cold reload, `CoachProfileProvider._withLegacyTaxQuarantine`
retire toutes les clés
`_coach_tax_*` existantes du chemin actif et les copie dans
`_coach_tax_snapshots_v1.legacyQuarantine`, dans le même appel logique de
sauvegarde strict-secure avant reconstruction/publication.
Cette quarantaine reste locale, chiffrée, non consommable et exclue du backend :

| clé legacy | traitement |
|---|---|
| `_coach_tax_revenu_imposable` | quarantaine : périmètre ICC/IFD inconnu |
| `_coach_tax_fortune_imposable` | quarantaine : année/état/source date inconnus |
| `_coach_tax_impot_cantonal` | quarantaine : cantonal seul ou ICC indécidable |
| `_coach_tax_impot_federal` | quarantaine : année et état indécidables |
| `_coach_tax_deductions` | quarantaine : déclarées/admis(es), ICC/IFD indécidables |
| `_coach_tax_taux_marginal` | quarantaine : unité et sémantique moyen/marginal indécidables |
| `_coach_tax_source` | marqueur legacy seulement; aucune promotion de confiance |

Si le root canonique existe mais est malformé, MINT ne retombe jamais sur ces
clés. Il préserve sa valeur brute exacte et les éventuels loose facts dans cette
même quarantaine imbriquée, publie zéro snapshot, supprime les loose keys et la
provenance `fiscal.*` orpheline, puis sauvegarde une seule fois avant
publication; le cold load suivant est idempotent. La sentinelle `__secure__`
signale au contraire une valeur Keychain temporairement illisible : elle reste
strictement inchangée avec zéro écriture et zéro fait consommé.

La migration automatique ne crée donc aucun `TaxSnapshot`. Dans le périmètre
G1-PROV-03 livré, `legacyDataNeedsReview=true` est uniquement un signal de
quarantaine : aucun consumer, API ou écran de production ne lit, ne normalise,
ne promeut ou ne supprime les valeurs brutes. `acceptTaxReview` préserve la
quarantaine inchangée lorsqu’un nouveau document canonique est confirmé. Une
future revue de reconfirmation devra disposer de son propre ticket, de son UI et
de preuves red→green avant de pouvoir promouvoir un élément et retirer son
résidu dans une même sauvegarde. En particulier, `31.5` n’est pas converti en
`0.315` aujourd’hui, même si son unité paraît reconnaissable; un taux moyen
n’est jamais renommé ou copié vers `explicitMarginalIncomeTaxRate`.

`FiscalProfile` est l’unique source de vérité fiscale. Aucun `BiographyFact` ne
duplique les valeurs ou métadonnées de `TaxSnapshot`; une timeline peut au plus
référencer l’opaque `snapshotId`. Le `sourceText` OCR reste dans la session de
revue en mémoire et est supprimé après confirmation/abandon. Ni `FiscalProfile`,
ni `_coach_tax_snapshots_v1.legacyQuarantine`, ni le texte OCR, ni la provenance
fiscale ne sont synchronisés au backend avant un contrat API/privacy dédié.

### Acquisition locale et libellés

`DocumentType.taxDeclaration` est le nom technique historique du canal; le
libellé produit avant classification est **« Document fiscal »**. Sa description
demande d’identifier puis de confirmer le type de pièce sans annoncer d’avance
une déclaration, un revenu, une fortune, un taux marginal ou des points de
confiance. L’impact de confiance fiscal initial et celui du candidat parser sont
zéro; le delta présenté n’est calculé qu’après une sauvegarde réussie par
`score -> save -> score`.

Tant qu’aucun moteur OCR fiscal réellement local n’est câblé, les surfaces
caméra, galerie et import PDF sont masquées pour ce type de document. Les
handlers conservent en défense en profondeur un retour fiscal dominant avant
consentement, picker, création de fichier temporaire, Docling, Vision, RAG, LLM
ou HTTP. Un chemin de texte local synthétique peut rester disponible pour les
tests et la revue manuelle; il ne constitue pas une acquisition documentaire de
production.

### Impact après revue

L’impact fiscal n’existe qu’après une `TaxReviewConfirmation` acceptée et une
sauvegarde locale réussie. Son payload est reconstruit depuis les champs
canoniques corrigés de cette confirmation — ou depuis le `TaxSnapshot` accepté
retourné par le writer — jamais depuis les champs OCR bruts. Il ne contient que
les valeurs confirmées non nulles, dans un ordre déterministe, avec
`sourceText=''`, sans `profileField`, déduction legacy, warning OCR ou donnée
personnelle. Une sauvegarde échouée ne produit aucun impact.

L’écran d’impact conserve le libellé neutre **« Document fiscal »**, expose les
résultats comme post-revue et ne prétend pas que des valeurs partielles ont été
« intégrées dans les projections ». Le CTA de sortie fiscal n’appelle jamais
`ScreenCompletionTracker` : zéro événement stream, zéro écriture préférences et
zéro retour pending. Le handoff est local via le seul `scanSessionId`; l’écran
reste également interdit de premier éclairage distant et de mémoire coach.

## 5. Cas de tests déterministes

Toutes les valeurs ci-dessous sont des fixtures synthétiques, pas des barèmes.

1. **Décision 2025 confirmée.** Avis émis le 20.06.2026, ICC revenu imposable
   98’500, IFD revenu imposable 96’200, fortune imposable 245’000, ICC combiné
   14’520, IFD 3’840, taux marginal explicitement 32,5 %. Attendre
   `certificate`, `taxYear=2025`, `sourceDate=2026-06-20`, taux `0.325`, valeurs
   et provenance identiques après redémarrage.
2. **Déclaration auto-remplie.** Mêmes montants, `documentKind=taxpayerReturn`.
   Attendre `selfDeclared` + `userInput`, jamais `certificate`; le consommateur
   « taxation précise » reste partiel.
3. **Bordereau provisoire IFD.** Période 2025, émis le 05.02.2026, calculé à
   partir de 2024, montant 4’200. Attendre `taxYear=2025`,
   `basedOnTaxYear=2024`, `provisional`, `estimated`; aucun revenu imposable ni
   taux marginal n’est inventé.
4. **2024 taxé + 2025 provisoire.** La décision 2024 reste le dernier snapshot
   taxé, marqué ancien; le provisoire 2025 reste séparé. Aucun champ 2024/2025
   n’est fusionné.
5. **Document sans date d’émission.** Conserver `sourceDate=null`, sans la
   remplacer par `updatedAt`. La fraîcheur reste inconnue et déclenche une
   demande de confirmation.
6. **Document sans année fiscale.** Conserver un snapshot avec `taxYear=null`
   ou un candidat de revue; il ne remplace aucune taxation datée et les
   consommateurs restent `partial+ask`.
7. **Taux moyen seulement.** « Taux moyen d’imposition 22,3 % » donne
   `explicitAverageIncomeTaxRate=0.223` et
   `explicitMarginalIncomeTaxRate=null`.
8. **Faux marginal calculé.** ICC 15’000 + IFD 5’000, revenu imposable 100’000.
   Le ratio 20 % ne crée aucun taux marginal.
9. **Cantonal seul vs ICC.** « Impôt cantonal 10’000 » donne `cantonalOnly`;
   « ICC 14’520 » donne `cantonalCommunalCombined`. Les deux ne sont pas des
   alias.
10. **Taxation commune, partenaire absent.** Décision 2025 avec
    `subjectScope=jointlyAssessedCouple`, aucun compte partenaire lié. Garder
    les montants au niveau de l’unité fiscale; tous les champs individuels du
    partenaire restent `null`, jamais zéro.
11. **Bordereau final non-baseline.** `documentKind=finalTaxBill` reste
    `assessmentStatus=unknown`, `estimated` et non-baseline. Si la fixture
    contient une décision autoritative distincte, la revue la reclassifie en
    `assessmentNotice` avant toute certification; jamais `inForce`
    automatiquement. Un taux explicitement marginal peut rester `estimated`
    pour affichage, mais le selector de baseline l’exclut.
12. **Persistance avant publication.** En cas d’échec de sauvegarde, ni le
    profil en mémoire ni un listener ne voient le nouveau snapshot. Le test
    injecte un `TaxProfilePersistence` qui échoue, puis un spy qui démontre une
    seule sauvegarde avant notification.
13. **Seam complet.** Le candidat du parser ne modifie rien; seule une
    `TaxReviewConfirmation` valide atteint le provider; le cold reload puis
    `FiscalSnapshotSelector` restituent la même baseline.
14. **Identifiant retry-stable.** Une correction de revue et deux retries de
    sauvegarde du même `TaxExtractionCandidate` conservent le même UUID/path de
    provenance; un autre candidat reçoit un UUID différent et aucune donnée
    personnelle n’apparaît dans l’identifiant. Le test ne prétend pas reprendre
    l’OCR avant parsing ou après process death.
15. **Provenance des métadonnées.** `taxYear`, kind, status, subject scope,
    canton et commune round-trippent avec leurs enveloppes exactes; une enveloppe
    malformée échoue fermée pour le même chemin.
16. **Matrice invalide.** `taxpayerReturn + inForce` et
    `provisionalBill + assessedAppealable` ne peuvent pas être confirmés ni
    publiés.
17. **Tie-break et conflit.** Après année, état et source date, deux payloads
    sémantiquement divergents produisent `partial+ask` et une quarantaine avant
    toute lecture de `updatedAt`/UUID. Ces tie-breakers techniques ne classent
    que des doublons sémantiquement identiques.
18. **Migration legacy.** Les `_coach_tax_*` quittent le chemin actif sans
    créer de snapshot et entrent dans
    `_coach_tax_snapshots_v1.legacyQuarantine`, sans seconde clé. `31.5` et un
    taux moyen à `22.3` restent tous deux bruts et quarantinés; le chemin livré
    n’offre aucune reconfirmation ou normalisation implicite. Un root malformé
    est lui-même conservé opaque dans cette quarantaine avec zéro snapshot,
    loose key ou provenance fiscale active; le second cold load n’écrit plus.
    `__secure__` reste inchangé et provoque zéro écriture.
19. **Pas de duplication/transmission.** Après confirmation, aucun
    `BiographyFact`, payload backend, log ou stockage persistant ne contient une
    copie des faits fiscaux ou du `sourceText` OCR.
20. **Gate composite fail-closed.** Avec l’un ou l’autre des deux flags à
    `false`, `taxAssessmentIngestionEnabled` reste `false` et le parcours
    documentaire n’est pas exposé. `typedTaxProfile=false` interdit en plus
    toute écriture typée, baseline selector ou lecture fallback `_coach_tax_*`;
    `documentTaxAssessmentEnabled=false` masque les surfaces et coupe leurs
    handlers avant acquisition. L’activation n’est testée qu’avec les preuves
    ciblées et runtime requises.
21. **Périmètre IFD incohérent.** Un candidat OCR peut contenir
    `federalDirect + wealthOnly` ou `incomeAndWealth`; la revue présélectionne
    `unknown` et signale l’incohérence. Toute tentative de construire directement
    une confirmation avec le périmètre invalide est rejetée par le writer avant
    sauvegarde et publication. `federalDirect + unknown` round-trippe comme
    snapshot partiel et le selector répond `partial+ask`.
22. **Total de facture partiel.** Un ICC `totalInvoice` confirmé round-trippe
    sans coercition, mais ne satisfait jamais une requête ICC précise et retourne
    `partial+ask`.
23. **Attestation `inForce`.** Le parser ne retourne jamais `inForce`, y compris
    pour « définitif », « exécutoire » ou `rechtskräftig`. Sans
    `inForceAttested=true`, le writer rejette avant sauvegarde. Avec attestation,
    le statut et l’attestation ont une provenance `userInput`, tandis que les
    montants documentaires restent `certificate`; le cold reload conserve
    l’attestation exacte.
24. **Temps fiscal fail-closed.** Horloge injectée au 14.07.2026 : le 14.07 et
    `taxYear=2026` sont acceptés; le 15.07 ou `taxYear=2027` est refusé par la
    revue et le writer sans seconde sauvegarde. Pour un provisoire,
    `basedOnTaxYear > taxYear` est refusé. Une fixture froide datée ou taxée en
    2099 est exclue; elle ne bat pas une fixture 2025 valide et n’est jamais
    corrigée vers `today`, `null` ou 2026. Une source date absente reste visible
    en requête précise avec confirmation requise, mais ne complète jamais
    `latestCompleteness` ni le score fiscal.
25. **Revenus négatifs.** Le parser conserve `-4’200` ICC et `-3’900` IFD comme
    revenus imposables finis; une fortune de `-25’000` et des impôts négatifs
    restent `null`. Un revenu confirmé de `-1` round-trippe avec sa provenance,
    mais les selectors précis et latest répondent `partial+ask` tant que son
    sens label/canton/ruleset n’est pas modélisé; il n’ajoute aucun point de
    confiance et ne supprime pas le prompt fiscal.
26. **Impact canonique.** Une fixture OCR avec valeurs sentinelles et déduction
    legacy est corrigée en revue; après sauvegarde, l’impact contient exactement
    les champs canoniques corrigés, aucun sentinel, aucun `sourceText` et aucun
    `profileField`.
27. **Impact partiel et sortie.** Un impact partiel ne dit jamais « intégrées
    dans tes projections ». Son CTA émet zéro `ScreenCompletionTracker`, ne crée
    aucune préférence ni retour pending, et la session est supprimée à la sortie.
28. **Acquisition locale uniquement.** Sans OCR fiscal local, caméra, galerie et
    PDF sont masqués; leurs handlers retournent avant consentement, picker,
    fichier temporaire ou réseau. Les services Vision/RAG/HTTP rejettent aussi
    `tax_declaration` avant transport.
29. **Taxonomie et score.** Avant revue, le label est « Document fiscal », la
    description reste neutre et les impacts de confiance statiques/parser valent
    zéro. Le seul delta affiché est celui recalculé après sauvegarde réussie.

## 6. Texte éducatif et transfert à un spécialiste

Texte recommandé pour une décision confirmée :

> « Ces montants proviennent de ta décision de taxation pour l’année indiquée.
> Vérifie le périmètre ICC/IFD et l’état d’une éventuelle réclamation. Un taux
> moyen ne permet pas de connaître ton taux marginal. »

Questions à joindre au dossier spécialiste :

- S’agit-il de la déclaration, d’un provisoire, de la décision de taxation ou
  d’un bordereau final ?
- Quelle période fiscale, quel canton, quelle commune et quelle unité fiscale
  figurent sur le document ?
- Les montants ICC couvrent-ils revenu, fortune et commune, ou seulement une
  composante ?
- Une réclamation ou un recours est-il pendant ?
- Quel taux marginal et quel périmètre faut-il utiliser pour le scénario étudié ?

Pour un délai, une réclamation, une situation intercantonale/internationale ou
une décision contestée, MINT doit orienter vers l’administration fiscale
cantonale ou un·e fiscaliste, sans qualifier les chances ni dicter une conduite.

Disclaimer :

> « Les résultats présentés sont des estimations à titre indicatif, basées sur
> les données fournies et la législation en vigueur. Ils ne constituent pas un
> conseil financier, fiscal ou juridique personnalisé. Consultez un·e
> spécialiste pour votre situation spécifique. »

## 7. Confidentialité

Le document fiscal contient des données financières et des identifiants à fort
impact. MINT conserve uniquement les champs confirmés, la provenance et un
`snapshotId` local opaque. Snapshots et quarantaine legacy partagent le seul
payload strict-secure `_coach_tax_snapshots_v1`; aucune clé de quarantaine
autonome n’est permise. Aucun numéro de contribuable, adresse, texte OCR
brut ou image ne doit entrer dans le profil, les logs, l’analytique, un prompt
LLM ou un export partenaire. Une taxation commune ne peut être partagée avec
le compte du partenaire sans grant explicite, limité aux champs et révocable.

## 8. Sources officielles

Consultées ou revalidées le 14 juillet 2026 :

- [LIFD (RS 642.11), notamment art. 40 et 130–132 — Fedlex](https://www.fedlex.admin.ch/eli/cc/1991/1184_1184_1184/fr?version=20260101)
- [LHID (RS 642.14), notamment art. 15, 46 et 48 — Fedlex](https://www.fedlex.admin.ch/eli/cc/1991/1256_1256_1256/fr?version=20260101)
- [AFC/CSI — Procédure de taxation, décision et entrée en force](https://www.estv.admin.ch/dam/estv/fr/dokumente/estv/steuersystem/dossier-steuerinformationen/e/e-veranlagungsverfahren-2022.pdf.download.pdf/e-veranlagungsverfahren-2022.pdf)
- [AFC/CSI — Impôt sur la fortune des personnes physiques](https://www.estv.admin.ch/dam/estv/fr/dokumente/estv/steuersystem/dossier-steuerinformationen/d/d-vermoegenssteuer-np.pdf)
- [AFC — Progressivité : distinction mathématique entre taux moyen et taux marginal](https://www.estv.admin.ch/dam/estv/fr/dokumente/estv/steuerpolitik/arbeitspapiere/stp-arbeitspapiere-2013-progressivite-impot-revenus-suisse-fr.pdf.download.pdf/stp-arbeitspapiere-2013-progressivite-impot-revenus-suisse-fr.pdf)
- [État de Genève — facture, bordereaux et avis de taxation ICC/IFD](https://www.ge.ch/j-ai-entre-18-25-ans-mes-impots-je-gere/facture-impot-bordereau-avis-taxation)
- [État de Genève — bordereau provisoire IFD 2025 fondé sur la taxation 2024](https://www.ge.ch/actualite/j-ai-re%63u-mon-bordereau-provisoire-ifd-que-dois-je-faire-5-02-2026)
- [DFF — imposition individuelle acceptée le 8 mars 2026; entrée en vigueur au plus tard en 2032](https://www.efd.admin.ch/fr/votation-imposition-individuelle)

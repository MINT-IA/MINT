---
description: >
  Audit actuaire des deux réserves Codex issues de #1135 sur des moteurs
  préexistants — (1) FamilyService.compareFiscalMariage (comparaison marié vs 2
  célibataires) et (2) la rente de survivant LPP affichée par mariage_screen.
  Verdicts, écarts chiffrés sur famille_bern, et décision de placement L1/L2.
metadata:
  type: audit
  date: 2026-07-30
  author: mint-swiss-brain
  scope: apps/mobile — famille/mariage
---

# Moteur famille — audit actuaire (réserves #1135)

## TLDR

Deux moteurs préexistants, deux verdicts distincts.

1. **`FamilyService.compareFiscalMariage` → FAUX (corrigé).** Il portait un modèle
   fiscal parallèle (`_effectiveRates100kSingle` : un taux effectif plat par canton
   × un `_incomeAdjustment` quasi quadratique × un facteur marié plat 0.92) — exactement
   la conception que l'étalon canonique `income_tax_model_v2.dart` documente avoir
   remplacée parce que ses **différences d'impôt étaient fausses**. Sur le persona seed
   **famille_bern** (114k + 78k brut, BE, 1 enfant), il annonçait une **PÉNALITÉ de
   +404 CHF** là où l'étalon ESTV calibré donne un **BONUS de −2'454 CHF** :
   **inversion de signe** du signal de tête. Fix appliqué : délégation à
   `estimateIncomeTaxV2` (mobile L1, déjà utilisé par 4 autres services), suppression de
   la table de taux par canton (aligné lint #1062). Résiduel documenté : base = brut −
   déductions fiscales seulement (pas de déductions sociales) ; constantes de déduction
   fédérales périmées.

2. **Rente de survivant LPP (`mariage_screen`) → APPROXIMATION acceptable, MAL DOCUMENTÉE
   (citation corrigée).** Le taux 60 % est juste, mais la **citation légale du taux était
   fausse** : le code l'attribuait à `LPP art. 19` (qui régit les *conditions d'octroi*),
   alors que le **taux 60 % est LPP art. 21 al. 1** (montant). La base employée est la
   rente LPP *courante* (avoir actuel converti), une approximation **conservatrice** de la
   base légale (rente d'invalidité *projetée*, art. 21). Fix appliqué : citation corrigée
   (docstrings + commentaire + caveat écran), zéro changement de comportement. Le
   footnote ARB `mariageLppSurvivorFootnote` citait déjà art. 19 pour les *conditions* —
   c'est **correct**, laissé tel quel.

Contre-argument / limites : voir §5.

---

## 1. Étalon métier (sources)

### 1.1 Impôt sur le revenu marié vs célibataire

L'app possède DÉJÀ un étalon canonique de l'impôt sur le revenu, calibré sur l'API
officielle ESTV :

- Backend : `services/backend/app/services/fiscal/cantonal_comparator.py::estimate_income_tax`
  — IFD 2026 progressif (`FEDERAL_BRACKETS`, LIFD art. 36) + impôt cantonal/communal
  **interpolé** entre 8 points calibrés ESTV par canton (`CANTONAL_COMMUNAL_TAX_CHF`,
  chef-lieu, célibataire). Marié = **splitting ×0.80** (approximation LHID, appliquée à la
  somme). Doctrine explicite du fichier : *« le taux marginal n'est pas une donnée : c'est
  une DÉRIVÉE ; toute table qui le stocke est une copie qui divergera »* — et lint #1062
  interdit d'ajouter une nouvelle table de taux par canton.
- Mobile (miroir L1) : `apps/mobile/lib/services/financial_core/income_tax_model_v2.dart::estimateIncomeTaxV2`
  — mêmes tables, mêmes conventions ; consommé par `fiscal_service`, `lpp_deep_service`,
  `life_events_service`, `tax_calculator`.

Le canton (BE) module l'impôt via l'effet de barème réel encodé dans les points ESTV, pas
via un coefficient plat. Le splitting/quotient familial des cantons hétérogènes (BE :
Verheiratetentarif/splitting partiel) est approché par le facteur ×0.80 sur les points
célibataires — documenté comme approximation, mais **ancré sur des points réels**.

### 1.2 Rente de conjoint survivant LPP

- **LPP art. 19** : conditions d'octroi du conjoint survivant (enfant à charge, OU 45 ans
  révolus + 5 ans de mariage ; sinon indemnité unique = 3 rentes annuelles).
- **LPP art. 20** : conditions de la rente d'orphelin.
- **LPP art. 21 al. 1** : **MONTANT** — rente de veuve/veuf = **60 %**, rente d'orphelin =
  **20 %**, de la rente d'invalidité entière (ou de la rente de vieillesse en cours) à
  laquelle l'assuré·e aurait eu droit. Pour un·e assuré·e actif·ve décédé·e avant la
  retraite, la base est la rente d'invalidité **projetée** (crédits futurs sans intérêt).
- Sources : BSV/OFAS « Prévoyance pour les survivants dans la prévoyance professionnelle » ;
  guidesocial.ch fiche LPP ; koordination.ch « Prestations de survivants ». Confirmé par
  recherche 2026-07-30.

La moteur canonique `LppCalculator.computeSurvivorPension` modélise déjà art. 19 al. 2
(branche indemnité unique) et art. 19 al. 3 (plafond 100 % avec orphelins).

---

## 2. Moteur 1 — `compareFiscalMariage` : verdict FAUX, écart chiffré

### 2.1 Ce qu'il faisait (avant)

```
baseRate = _effectiveRates100kSingle[canton]        # taux effectif plat à 100k
taxSingle = (revenu - 1800) * baseRate * _incomeAdjustment(...)   # quasi quadratique
taxMarie  = revenuImposable * (baseRate * _incomeAdjustment(...) * 0.92)   # splitting plat
```

### 2.2 Divergence mesurée (2026-07-30, sorties déterministes)

Bases imposables IDENTIQUES (celles du service) des deux côtés — on isole l'erreur de
**structure de taux** :

| Cas (canton, revenus, enfants) | Modèle CRUDE (avant) | Étalon ESTV (après) | Verdict |
|---|---|---|---|
| **famille_bern** BE 114k+78k, 1 enf. | **+404 CHF (PÉNALITÉ)** | **−2'454 CHF (BONUS)** | **signe inversé** |
| VD 100k+100k, 0 enf. | +1'497 (pénalité) | +3'221 (pénalité) | signe ok, ampleur ×2.2 |
| VD 120k+0, 0 enf. | −2'238 (bonus) | −7'107 (bonus) | signe ok, ampleur ×3.2 |
| GE 80k+60k, 0 enf. | +1'878 (pénalité) | +2'504 (pénalité) | signe ok |
| GE 80k+60k, 2 enf. | −628 (bonus) | −1'247 (bonus) | signe ok |

Cause de l'inversion famille_bern : le taux plat `_effectiveRates100kSingle['BE']=0.1389`
**sous-estime l'impôt BE d'environ 41 %** (célibataire imposable 112'200 : crude 15'965 vs
ESTV 26'997). La compression de l'impôt célibataire fait que l'impôt marié (lui aussi
sous-estimé) le dépasse d'un cheveu → +404. L'étalon calibré, avec un impôt BE réaliste et
le splitting ×0.80, donne un bonus net.

### 2.3 Conséquence produit

`mariage_screen` (onglet Impôt) et `concubinage_screen` (comparateur) affichaient un signal
qui **contredit l'app elle-même** : tout le reste de la surface fiscale (rachat LPP,
first-job, life-events) passe par `estimateIncomeTaxV2`. Deux surfaces du même produit
donnaient des directions opposées — précisément le mode d'échec (bloc/étalé inversés) que le
modèle v2 a été créé pour tuer.

### 2.4 Décision de placement (frontière L1/L2)

`compareFiscalMariage` est sémantiquement un **comparateur (L2)** ; la doctrine CLAUDE.md
place L2-comparer en backend-canonical. MAIS le calcul sous-jacent (impôt d'un scénario) est
un primitif **L1** (single-number, offline) déjà mirroré en mobile via `estimateIncomeTaxV2`,
que 4 autres services mobiles consomment. Le **fix minimal borné** rebranche le comparateur
sur ce mirror L1 existant — il **retire un doublon**, il n'**ajoute pas** de violation
cross-layer. La migration « comparateur → backend L2 » reste une question architecturale
séparée (strangler-fig D-11), listée au plan §4, pas un préalable au retrait de l'inversion.

### 2.5 Fix appliqué

- `family_service.dart` : `compareFiscalMariage` délègue single/marié à `estimateIncomeTaxV2`
  (marié = `isMarried: true`, splitting ×0.80). Suppression de `_effectiveRates100kSingle`,
  `_estimateSingleTax`, `_marriedEffectiveRate`, `_incomeAdjustment`. Clés de sortie et
  comptabilité des déductions inchangées.
- Test de non-régression (`family_service_test.dart`) : **pin de délégation** (identité avec
  `estimateIncomeTaxV2` sur les bases du service pour famille_bern) — pas un montant « vérité
  terrain » contestable — + assertion que l'inversion +404 a disparu.
- Fixtures d'écran recalibrées (`mariage_gate_test.dart`) : la pénalité se démontre désormais
  avec 100k/100k (fenêtre ~90k-130k/tête ; au-delà le splitting reprend). Le test-garde
  « les deux fixtures encadrent les deux sens », conçu pour tomber en premier si le moteur
  change, a fait exactement son travail.

---

## 3. Moteur 2 — rente de survivant LPP : verdict APPROXIMATION mal documentée

### 3.1 Constat

`mariage_screen` affiche `lppSurvivor = _renteLpp * FamilyService.lppSurvivorFactor` (0.60),
où `_renteLpp` est amorcé via `LppCalculator.monthlyRenteFromAvoir(avoirLppTotal)`.

- **Taux 60 %** : juste. Mais **mal cité** — le code (`lppSurvivorFactor`,
  `LppCalculator.survivorSpouseRate`/`survivorOrphanRate`, commentaire écran) l'attribuait à
  **art. 19** ; le taux est **art. 21 al. 1**. Art. 19 = conditions.
- **Base** : `_renteLpp` = rente issue de l'**avoir courant** converti à 6.8 %. La base légale
  pour un·e actif·ve est 60 % de la rente d'invalidité **projetée** (art. 21) → pour un·e
  assuré·e jeune, la valeur affichée **sous-estime** (approximation conservatrice). Le caveat
  écran ne mentionnait que l'éligibilité art. 19, pas la simplification de base.
- **Canonique bypassé** : `LppCalculator.computeSurvivorPension` (art. 19 al. 2 indemnité
  unique + art. 19 al. 3 plafond 100 % + orphelins art. 21/20 %) n'est pas appelé ; le
  constant 0.60 (`FamilyService.lppSurvivorFactor`) duplique `survivorSpouseRate`
  (numériquement identiques). Sur le chemin gaté par défaut (1 enfant) l'éligibilité art. 19
  al. 2 (a) est remplie → même 60 % : la valeur affichée ne change pas.

### 3.2 Pourquoi « acceptable » et pas « faux »

Le nombre affiché (60 % de la rente montrée) est interne-cohérent et le 60 % est légalement
juste. Les défauts sont (a) la citation d'article et (b) une base conservatrice non
documentée — pas une erreur de calcul. Verdict : **approximation acceptable, à documenter**.

### 3.3 Fix appliqué (borné, zéro comportement)

Correction de citation (docstrings `lppSurvivorFactor`, `survivorSpouseRate`,
`survivorOrphanRate` ; commentaire `mariage_screen`) : le taux 60 %/20 % = **LPP art. 21
al. 1** ; art. 19/20 = conditions. Caveat écran enrichi (base = rente courante, approximation
conservatrice de la rente projetée). Aucune chaîne ARB user-facing n'était mal citée (le
footnote décrit les *conditions* art. 19 → correct).

---

## 4. Plan (planifié, non fait dans cette PR)

1. **Base gross → imposable (Moteur 1)** : `compareFiscalMariage` reçoit du brut et n'ôte que
   les déductions fiscales fédérales (assurance/marié/enfant/Zweiverdiener), sans déductions
   sociales (AVS/AI/APG/AC/LPP ~13 %) ni frais professionnels → revenu imposable surestimé.
   Chantier : convertir brut→imposable (réutiliser un convertisseur existant si présent),
   séparé car il change les montants affichés et exige une validation ESTV couple.
2. **Constantes de déduction périmées (Moteur 1)** : `deductionDoubleRevenu=2800` devrait être
   le Zweiverdienerabzug (50 % du revenu le plus bas, borné 8'600–14'100), `deductionMarie=2700`
   → 2'800, `deductionAssuranceMarie=3600` → 3'700 (réf. mémoire
   `reference_ifd_lifd_deductions_2026.md`). Non corrigé ici : dans un modèle total-tax ces
   déductions fédérales n'ont qu'un effet partiel, et `deductionAssuranceMarie` est verrouillé
   par un test au double du célibataire.
3. **Migration L2 → backend (Moteur 1)** : à terme, exposer la comparaison marié/concubin comme
   un `L2ComparePayload` backend (strangler-fig D-11), le mobile ne gardant que l'appel.
4. **Rente projetée (Moteur 2)** : router l'affichage survivant via
   `LppCalculator.computeSurvivorPension(projectedAnnualRente=...)` une fois que l'écran
   collecte/gate l'âge du conjoint + la durée de mariage (sinon art. 19 al. 2 reste au défaut
   45 ans/5 ans) — pour couvrir la branche indemnité unique et les orphelins.
5. **Contre-factuel « 2 célibataires » avec enfant commun (Moteur 1 — challenge Codex 2026-07-30)** :
   pour un couple avec enfant, le scénario « 2 célibataires » n'est pas « 2 célibataires SANS
   enfant ». Le parent qui a l'enfant dans son ménage peut prétendre à la déduction enfant ET,
   au fédéral, au **barème parental** (tarif marié, LIFD art. 36 al. 2bis), et la répartition
   varie selon canton/garde. Le comparateur applique aujourd'hui le barème célibataire nu aux
   deux têtes et concentre la déduction enfant côté marié → le « bonus » peut donc rester biaisé
   MALGRÉ l'alignement interne sur l'étalon. Chantier : modéliser le contre-factuel parental côté
   « séparés ». Ce biais préexiste au fix et n'est pas aggravé par lui (le fix retire l'inversion
   de signe et la table plate) — mais il limite la portée « vérité fiscale » du montant.

6. **AVS survivant (hors périmètre)** : `avsSurvivorFactor=0.80` cité « LAVS art. 35 » — à
   vérifier (rente de veuve = 80 % de la rente de vieillesse, plutôt LAVS art. 36) ; non touché
   ici.

## 5. Contre-arguments / gaps de données

- Le « bonus −2'454 CHF » de famille_bern est la sortie de **notre étalon** (splitting ×0.80),
  pas une vérité terrain ESTV couple vérifiée montant par montant. Le test épingle donc la
  **délégation**, pas ce montant. L'affirmation solide est : *le comparateur ne contredit plus
  l'étalon fiscal de l'app*.
- Le facteur marié ×0.80 reste une approximation du splitting/quotient réel (BE, VD, GE
  diffèrent) ; il est simplement **mieux ancré** (points ESTV réels) que le 0.92 plat retiré.
- La base gross-vs-imposable (§4.1) demeure : les montants affichés restent des estimations
  éducatives, pas des impôts exacts — la limite est dite à l'écran (« Estimation simplifiée /
  barème cantonal détaillé »).

## 6. Traçabilité

- Modèle canonique : `income_tax_model_v2.dart`, `cantonal_comparator.py::estimate_income_tax`.
- Moteur survivant canonique : `lpp_calculator.dart::computeSurvivorPension`.
- Mesures : sorties déterministes `estimate_income_tax` (backend) vs formules crude, 2026-07-30.
- Tests : `family_service_test.dart` (+ pin délégation), `mariage_gate_test.dart` (fixtures
  recalibrées + test-garde), `lpp_calculator_test.dart` (inchangé). `flutter analyze` : 0 issue.

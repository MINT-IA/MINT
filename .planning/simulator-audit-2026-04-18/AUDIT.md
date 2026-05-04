# Simulator Audit — 2026-04-18

Audit croisé Actuaire LPP / Fiscaliste / Edge-cases sur 9 simulateurs :
`rachat_echelonne`, `epl`, `libre_passage`, `staggered_withdrawal_3a`, `retroactive_3a`,
`real_return_3a`, `provider_comparator`, `compareRenteVsCapital`, `compareLocationVsPropriete`.

---

## P0 — Réalisme ou compliance cassé

### P0-1 — Rachat LPP : échelonnement > salaire brut annuel (bug founder)
**File** : `apps/mobile/lib/services/lpp_deep_service.dart:120-151`.
**Symptôme reproduit** : `rachatMax = 350'000`, `revenuImposable = 122'000`, `horizon = 3` →
`rachatAnnuel = 350'000 / 3 = 116'667`. Le cap `clamp(0, revenuImposable)` (ligne 122-123) permet
cette valeur puisque 116'667 < 122'000. Le simulateur affiche 3 versements à 116'667 CHF chacun
comme "réalisable". C'est **non-réaliste** :
1. Aucune caisse de pension n'accepte un rachat annuel représentant ~95% du salaire brut
   (pas de liquidité disponible après charges sociales + impôts + vie courante).
2. Même si la caisse accepte, la **déduction fiscale est plafonnée par l'assiette de revenu
   imposable après autres déductions** (LIFD art. 33 al. 1 let. d + art. 25) : rachat de 116k
   sur revenu brut 122k → revenu imposable résiduel ≈ 0 → économie fiscale écrêtée, pas égale au
   rachat × taux marginal. Le calcul utilise pourtant `grossSalary - blocDeductible` via
   `NetIncomeBreakdown.compute`, ce qui masque partiellement l'incohérence MAIS le simulateur
   n'alerte jamais l'utilisateur que "tu dois avoir cette liquidité hors salaire" ni que
   l'horizon affiché est financièrement irréaliste.
3. Dans le cas du founder (rachatMax = 350k, revenu = 122k), l'étalement minimal réaliste est
   **rachatMax / (revenu × ~25%)** ≈ 12 ans (soit ~30k/an = ~25% du brut = limite soutenable
   cash-flow + reste fiscalement déductible chaque année), pas 3 ans.

**Fix** :
1. Introduire un `rachatAnnuelSoutenable = min(revenuImposable × 0.25, rachatMax / horizonMin)`.
2. `horizonMin = ceil(rachatMax / rachatAnnuelSoutenable)` et **refuser** horizon < horizonMin
   avec alerte "Étaler sur N ans minimum pour rester cash-flow soutenable".
3. Ajouter une alerte quand `rachatAnnuel > revenu × 0.30` : "Rachat annuel supérieur à 30%
   de ton salaire brut — vérifie ta liquidité hors salaire (épargne, vente d'actifs)."
4. La UI (`rachat_echelonne_screen.dart:691`) autorise slider horizon 1-15 ans → **étendre
   à 1-25 ans** pour permettre l'étalement réaliste dans les gros rachats (350k+).

**Réfs** : LIFD art. 33 al. 1 let. d ; LPP art. 79b ; OPP2 art. 60a (plafonnement annuel
si salaire assuré élevé).

---

### P0-2 — Rachat LPP : blocage EPL 3 ans non propagé dans la UI
**File** : `lpp_deep_service.dart:160-163` (disclaimer texte) + `epl_screen.dart` (pas de
cross-check).
**Symptôme** : Après un rachat LPP via `RachatEchelonneSimulator`, aucun flag n'est écrit
dans `CoachProfile.prevoyance.rachatEffectue` (voir `rachat_echelonne_screen.dart:230-231`
qui passe `rachatEffectue: profile.prevoyance.rachatEffectue` — aucune mise à jour !).
Conséquence : `EplSimulator.simulate(aRachete: false, ...)` ne déclenche jamais le blocage
3 ans même si l'utilisateur vient de simuler un rachat. L'écran EPL (`epl_screen.dart`) lit
`_aRachete = false` par défaut et ne pré-remplit pas depuis le profil.

**Fix** :
1. `rachat_echelonne_screen.dart:228-235` → passer `rachatEffectue: true` et
   `dateRachatLpp: DateTime.now()` dans `copyWith`.
2. `epl_screen.dart` → dans `_initializeFromProfile`, lire `profile.prevoyance.rachatEffectue`
   et `dateRachatLpp` pour alimenter `_aRachete` et `_anneesSDepuisRachat`.

**Réf** : LPP art. 79b al. 3.

---

### P0-3 — EPL : formule "montant max à 50 ans" inventée (non conforme LPP art. 30e)
**File** : `lpp_deep_service.dart:436-453`.
**Symptôme** : Pour `age ≥ 50`, le code calcule `ratioA50 = (25 / (age - 25)).clamp(0.3, 1.0)`,
puis `avoirEstimeA50 = avoirTotal × ratioA50`, et prend `max(avoirEstimeA50, avoirTotal / 2)`.
Cette formule est **inventée**. LPP art. 30e al. 2 dispose que le montant retirable à partir
de 50 ans est `max(avoir_au_50_ans, moitié_avoir_actuel)`. Le code tente d'estimer
`avoir_au_50_ans` via un ratio linéaire, mais :
- Pour `age = 50` : ratio = 1.0 → avoirEstimeA50 = avoirTotal entier → retrait total possible.
  **Faux** : à exactement 50 ans, le plafond LPP art. 30e n'a pas encore d'effet (le plafond
  commence à s'appliquer **au-delà** de 50 ans).
- Pour `age = 65`, avoirTotal = 200k : ratio = 25/40 = 0.625 → avoirEstimeA50 = 125k →
  max(125k, 100k) = 125k. Or aucun certificat LPP ne garantit que l'avoir de 50 ans
  représentait 62.5% de l'avoir à 65 ans — ça dépend des bonifications cumulées
  (7/10/15/18%) et des rendements.

**Fix** : lire `profile.prevoyance.avoirLpp50ans` si scanné (certificat CPE/Hotela), sinon
afficher clairement "estimation non garantie — demande le certificat annuel à ta caisse"
et ne PAS montrer un chiffre précis. Mieux : utiliser `LppCalculator.projectToRetirement`
en mode rétrograde (project from current balance backwards to age 50 via
`caisseReturn` négatif et bonifications inverses).

**Réf** : LPP art. 30c al. 2, OPP2 art. 5.

---

### P0-4 — Retrait échelonné 3a : duréeMax = 7 ans (hard-cap), incohérent avec retrait 59-70
**File** : `pillar_3a_deep_service.dart:112` → `(clampedFin - clampedDebut + 1).clamp(1, 7)`.
**Symptôme** : Un user de 55 ans peut légalement retirer son 3a de 59 à 70 ans → **12 années
de fenêtre** (OPP3 art. 3). Le clamp à 7 ans force l'échelonnement dans une fenêtre max
7 ans, ce qui :
1. Empêche la stratégie optimale "1 compte 3a retiré par an sur 5 comptes" si l'user veut
   commencer à 59 et finir à 70 (11 ans).
2. Ne correspond à aucune règle légale : rien dans OPP3 ne limite la fenêtre à 7 ans.

**Fix** : `.clamp(1, 12)` (fenêtre 59→70 = 12 ans) et aligner le `MAX_COMPTES = 5` du backend
avec la réalité : 2-5 comptes suffisent puisque chaque compte doit être retiré entièrement
(OPP3 art. 3 al. 2), mais les comptes peuvent être étalés sur **jusqu'à 11 tax years**.

**Réf** : OPP3 art. 3 al. 1 + al. 2 (retrait 5 ans avant/après âge ordinaire, chaque compte
intégralement).

---

### P0-5 — Rétroactif 3a : plafonds historiques 2016-2024 présentés comme utilisables
**File** : `retroactive_3a_calculator.dart:100-128` + `social_insurance.dart:481-493`.
**Symptôme** : Le code itère `for i = 1..gapYears` et pour chaque année passée, fixe
`baseLimit = pilier3aHistoricalLimits[year]` (ex. 2017 = 6'768 CHF, 2020 = 6'826). **Or le
texte législatif adopté (OPP3 art. 7a, amendement Fédéral adopté 2023, entrée en vigueur
1er janvier 2025 — PAS 2026)** autorise le rachat 3a à hauteur du plafond **de l'année du
rachat** (pas du plafond historique de l'année manquée). Chaque année manquée rachetable =
7'258 CHF (plafond 2026), pas 6'826 (plafond 2020). Le code sous-estime donc la déduction.
Inversement, la ligne 104 `if (year < 2025) break;` empêche le rachat pour les années
**avant 2025** → cohérent avec l'entrée en vigueur 2025 — mais alors à partir de 2026 il y a
seulement 1 année rattrapable (2025), pas 10. Le clamp
`gapYears.clamp(1, pilier3aMaxRetroactiveYears)` (ligne 93) autorise jusqu'à 10 mais le
`break` limite à 1 → contradiction masquée.

**Fix** :
1. Changer `baseLimit = pilier3aHistoricalLimits[year] ?? 6768.0` → `baseLimit = plafond_annee_rachat`
   (= plafond 2026 = 7'258 pour un rachat effectué en 2026, même pour une année manquée en 2020).
2. Retirer `pilier3aHistoricalLimits` de `social_insurance.dart` (trompe et faux).
3. Vérifier la date d'entrée en vigueur (2025 vs 2026) avec swiss-brain — le code dit
   "dès 2026" (ligne 162, 481 "amendement 2026"), mais l'amendement fédéral dit 1er janvier 2025.
   → question ouverte ci-dessous.

**Réf** : OPP3 art. 7a (nouveau, modification OPP3 du 06.11.2024, RO 2024 687).

---

### P0-6 — Provider comparator : injecte un badge "WARNING" qui écrase les vrais badges
**File** : `pillar_3a_deep_service.dart:606` → `if (r.provider.type == 'assurance') badge = 'WARNING';`.
**Symptôme** : Pour le provider `Assurance 3a (mixte)`, la ligne 606 écrase sans condition le
badge calculé (ex. "Rendement le plus eleve + Plus bas frais" ou "Plus bas frais"). Plus grave,
**"WARNING" en anglais non-internationalisé** s'affiche dans la UI (ARB non traduits),
violation compliance §6 (langue = français) + §7 (i18n NON-NEGOTIABLE). Et la logique est
douteuse : 1 provider à 1.75% de frais sur 30 ans est TOUJOURS pénalisé ; on ne devrait pas
écraser le badge, on devrait ajouter un badge distinct "⚠ Frais élevés" localisé.

**Fix** : Ne PAS écraser `badge`. Créer un champ séparé `assuranceWarning: bool` et render
un second badge rouge localisé ("Frais élevés — pertinent si tu veux une couverture risque
intégrée"). ARB key à ajouter dans 6 langues.

**Réf** : CLAUDE.md §6 (compliance: language), §7 (i18n).

---

### P0-7 — Staggered 3a : optimal "nbComptes maximal" sans considérer frais d'ouverture
**File** : `pillar_3a_deep_service.dart:137-148`.
**Symptôme** : La boucle "optimale" teste n=1..5 comptes et retient celui qui minimise
l'impôt. Puisque la progressivité est monotone croissante, **n=5 gagne toujours** dès que
l'avoir dépasse 100k. Conséquence : recommande systématiquement 5 comptes, ce qui :
1. Ignore qu'un 3a fintech coûte ~0.05-0.30% frais de garde/an × 5 comptes → frais cumulés
   peuvent dépasser l'économie fiscale sur petits montants.
2. Viole la doctrine "side-by-side, never ranked" (CLAUDE.md §6.4 No-Ranking) : le simulateur
   désigne UNE option comme "optimal" avec `nbComptesOptimal` retourné et affiché en hero.
3. Ne modélise pas le fait que scinder 100k en 5 comptes de 20k donne
   tax = 5 × (20k × taux_base × 1.0) = identique à 1 × (100k × taux_base × 1.0) puisque
   la première tranche 0-100k a multiplier 1.0. La "économie" vient uniquement quand une
   tranche > 100k est franchie.

**Fix** :
1. Ajouter `fraisGardeParCompte` (default 60 CHF/an) × années × n → soustraire de
   `economie`. Quand net négatif, recommander moins de comptes.
2. Renommer `nbComptesOptimal` → `nbComptesMinImpot` et afficher toutes les valeurs 1-5
   côte-à-côte sans "winner".
3. Afficher clairement "L'échelonnement n'apporte rien si ton avoir total < 100'000 CHF"
   (parce que tout reste dans la tranche plate 1.0×).

**Réf** : CLAUDE.md §6.4 (No-Ranking), §6 (No-Advice).

---

## P1 — Logique douteuse ou edge case cassé

### P1-1 — Rachat LPP : âge hardcodé à 50 dans `NetIncomeBreakdown.compute`
`lpp_deep_service.dart:89, 106, 130` → `age: 50` forcé pour calculer net/brut. Pour un user
de 62 ans, la bonification LPP est 18% (pas celle de 50=15%), donc le `lppEmployee` calculé
dans `NetIncomeBreakdown` est sous-estimé → revenu net surévalué → impôt surévalué →
économie fiscale surévaluée. Fix : passer `profile.age` au lieu de `50`.

### P1-2 — EPL : réduction rente invalidité formule magique
`lpp_deep_service.dart:491` → `reductionInvalidite = reductionRatio × avoirTotal × 0.06`.
Le 0.06 n'est pas la rente invalidité (LPP art. 24 al. 2: 67.2% du salaire assuré
coordonné), c'est une pseudo-multiplication. Pour avoirTotal = 200k, retrait = 100k :
reductionInvalidite = 0.5 × 200'000 × 0.06 = 6'000 → affiché comme "réduction rente
invalidité". Ce chiffre n'a **aucun lien** avec la vraie formule LPP art. 24 (rente
invalidité = avoir_vieillesse_projeté × taux_conversion × (salaire_assuré / référence)).
Fix : utiliser `LppCalculator.projectToRetirement` avant/après pour calculer la réelle
perte de rente invalidité, ou supprimer ce chiffre et lister uniquement "réduction à vérifier
auprès de la caisse".

### P1-3 — EPL : blocage EPL affiche "CHF 0 retirable" sans montrer alternative
`lpp_deep_service.dart:466-472` → si rachat récent, `montantMax = 0`. OK mais **on n'indique
pas la date de déblocage** ("retrait possible dès le 12.04.2029"). Fix : computer et
afficher date concrète.

### P1-4 — Staggered 3a : effet combiné revenu+capital sur même année fiscale ignoré
`pillar_3a_deep_service.dart:119-130` applique `_calculerImpotRetrait(montantParRetrait, tauxBase)`
à chaque année. **Mais les années 59-64, le user est encore salarié** (`revenuImposable`
est passé en input). Les cantons additionnent (ou non selon jurisprudence) rente LPP +
retrait capital sur la même année fiscale au niveau de la progressivité. Le simulateur
suppose que le retrait capital est imposé isolément de l'impôt sur le revenu, ce qui est
correct au fédéral (LIFD art. 38) mais **varie cantonalement** pour le cumul avec retraits
multiples 3a/LPP dans la même année. Fix : alerter "Ne retire pas 2 comptes 3a la même
année fiscale : la plupart des cantons cumulent les retraits (art. 38 LIFD) et annulent
le bénéfice de la progressivité."

### P1-5 — Real return 3a : `tauxEpargne` hardcodé 1.5% (ligne 274)
`pillar_3a_deep_service.dart:274` → `const tauxEpargne = 0.015;`. Comparaison "vs épargne"
utilise 1.5% alors que les taux d'épargne en Suisse sont <1% depuis 2023 et souvent
0.1-0.5% chez les grandes banques. Résultat : le gain 3a vs épargne est **sous-estimé**.
Fix : passer en paramètre ou utiliser 0.5% (médiane UBS/PostFinance 2026).

### P1-6 — Compare rente vs capital : `tauxConversionSurobligatoire = 0.05` hardcodé
`arbitrage_engine.dart:73, 205`. 5% est une valeur de marché pour un plan standard, mais
les plans CPE/Hotela/Swisscanto actuels appliquent **4.50%, 4.75%, 5.00% selon règlement**.
Pour Julien (test couple, CPE Plan Maxi), le certificat peut indiquer autre chose. Fix :
lire `profile.prevoyance.tauxConversionCertificatSurob` s'il existe, fallback 4.80%.

### P1-7 — Compare location vs propriété : `tauxHypotheque = 0.02` (ligne 884) ignore SARON
`arbitrage_engine.dart:884` → SARON au 04/2026 ≈ 1.25%, hypothèque fixe 10 ans ≈ 1.85%.
2% est raisonnable en moyenne mais **la sensitivity tornado ne varie pas le taux
hypothécaire** (seulement rendement marché + loyer, lignes 1060-1094). Fix : ajouter
tornado sensitivity sur `tauxHypotheque` ±1%.

### P1-8 — Provider comparator : rendements `equilibre/dynamique` codés 3-5.5% sans
disclaimer de cherry-picking. Les rendements historiques VIAC/Finpension 2021-2024 sont
-4% à +15% selon année. Simuler 3.5% constant sur 30 ans fait apparaître le 3a fintech
invariablement gagnant, ce qui viole §6.3 No-Promise. Fix : ajouter Monte Carlo ±volatilité
ou afficher min/max bande 5e/95e percentile. Alternative : disclaimer explicite "3.5% =
hypothèse théorique CAGR long-terme ; variabilité réelle ±20% par an".

### P1-9 — Retroactive 3a : clamp taux marginal 0-60%
`retroactive_3a_calculator.dart:95` → `tauxMarginal.clamp(0.0, 0.60)`. Le taux marginal
Suisse plafonne ~45% (GE couple non-splittant fortune élevée). 60% surestime les économies
de 15-33%. Fix : `.clamp(0.0, 0.45)` cohérent avec `estimateMarginalRate`
(`tax_calculator.dart:350`).

### P1-10 — `fvAnnuityDue` en cas de `r = 0` exactement
`pillar_3a_deep_service.dart:327-328` → `if (r.abs() < 1e-10) return pmt × n × (1+r);`.
Pour r = 0 exact : renvoie `pmt × n × 1 = pmt × n`. Or annuity-due avec r=0 = pmt × n
(dépôts au début, pas de croissance). OK mais `pmt × n × (1 + r)` pour r=1e-11 renvoie
`pmt × n × 1.00000000001`, incorrect par cohérence. Fix : `return pmt × n` (sans le facteur
(1+r)).

---

## P2 — UX ou présentation

- **Rachat échelonné waterfall** (`rachat_echelonne_screen.dart:1019-1024`) : `_brackets`
  hardcodés (15/25/32/38%) différents des vrais barèmes cantonaux → confusion visuelle.
- **Staggered 3a** (`staggered_withdrawal_screen.dart:44-45`) : défauts `ageRetraitDebut=60,
  Fin=64` → range 5 ans, alors que l'optimal légal est 66-70 (retrait post-retraite possible
  si activité lucrative continue, OPP3 art. 3 al. 1). Ajouter preset "Étalement 66-70"
  (5 comptes, 1/an).
- **EPL** : slider `_obligRatio = 0.6` (60% oblig / 40% suroblig) est un défaut arbitraire —
  le certificat LPP indique la vraie répartition ; pré-remplir depuis profil.
- **Rétroactif 3a** : label "nouveauté 2026" (ligne 23) est peut-être 2025 (voir P0-5).
- **Provider comparator** : `Fintech A/B/C` anonymisés alors que la UI affiche des
  benchmarks très précis (0.39% vs 0.52% frais). Soit nommer (VIAC/Finpension/Frankly),
  soit les retirer — l'hybride crée un faux suspense ("lequel est Fintech A ?").

---

## Violations de doctrine Swiss finance

1. **Provider comparator ranking** (`pillar_3a_deep_service.dart:600-606`) : attribue
   badges "Rendement le plus eleve" et "Plus bas frais" → viole §6.4 No-Ranking.
   Side-by-side OK, désignation d'un vainqueur NON.
2. **Staggered 3a `nbComptesOptimal`** : désigne un optimum → même violation.
3. **Rachat échelonné `_buildComparisonCard` `isWinner`** (`rachat_echelonne_screen.dart:775-777`) :
   affiche badge "Plus adapté" sur la colonne gagnante → violation directe No-Ranking.
4. **Retroactive 3a chiffre choc** (`retroactive_3a_calculator.dart:146-150`) : "Tu peux
   rattraper N ans et économiser CHF X" — formulation promotionnelle, limite §6.3 No-Promise.
   Préférer "Rattraper N ans réduirait ton impôt de CHF X en 2026 (estimation au taux
   marginal X%)".
5. **EPL `aRachete=false` par défaut** : implique que user commence vierge à chaque session,
   cache le blocage 3 ans d'une vraie opération récente → risque "false clean".
6. **Word "WARNING" en anglais dans provider comparator** : viole §6 (langue = français)
   ET §7 (i18n).

---

## Divergences mobile vs backend

1. **Staggered 3a `MAX_COMPTES=5` aligné** entre mobile et backend, mais la **fenêtre
   temporelle diverge** : backend autorise `age_retrait_debut` jusqu'à 70, `age_retrait_fin`
   jusqu'à 70 (clamp `multi_account_service.py:123-124`), mobile clamp la **durée** à
   max 7 ans (`.clamp(1, 7)` ligne 112) — le backend n'a pas ce clamp. Mobile sous-estime
   le nombre de retraits possibles.
2. **Backend `_calc_effective_rate` vs mobile `_calculerImpotRetrait`** : mêmes tranches,
   mêmes multiplicateurs — OK. Différence subtile : backend (ligne 138) calcule
   `montant_par_compte = round(avoir_total / nb_comptes_effectif, 2)` et le **dernier
   compte reçoit le reste d'arrondi** ; mobile divise uniformément (`clampedAvoir /
   comptesEffectifs`). Pour 100'003 / 3 → backend : 33'334 / 33'334 / 33'335 ; mobile :
   33'334.33 × 3. Écart d'impôt ~0.50 CHF — négligeable.
3. **Rachat LPP** : aucun backend équivalent → mobile seul fait foi. Risque de dérive si
   la règle change.
4. **Retroactive 3a** : aucun backend → même risque.

---

## Questions ouvertes pour swiss-brain

1. **OPP3 art. 7a (rachat 3a rétroactif)** : date d'entrée en vigueur = 01.01.2025 ou
   01.01.2026 ? Le code mobile dit "amendement 2026" mais le RO 2024 687 parle de 2025.
   Besoin confirmation avant release du simulateur.
2. **Plafond annuel de déduction rachat LPP** : LIFD art. 33 al. 1 let. d limite à
   "cotisations … prévoyance professionnelle". Existe-t-il un plafond absolu annuel
   (type 3a) ou seulement la contrainte "≤ revenu imposable" ? Jurisprudence cantonale
   variable — trancher.
3. **Cumul retraits LPP + 3a la même année fiscale** : LIFD art. 38 prévoit "toutes les
   prestations" — mais chaque canton a sa jurisprudence sur le cumul capital LPP +
   capital 3a. Besoin matrice cantonale cumul oui/non.
4. **EPL post-rachat LPP** : blocage 3 ans s'applique-t-il aussi aux rachats
   partiellement remboursés, ou au dernier rachat ? Ambiguïté LPP art. 79b al. 3.
5. **Married capital tax discount 0.85** (`social_insurance.dart:402`) : VS applique un
   splitting différent (0.80 pour >200k), GE 0.75. Un coefficient national unique est
   faux. Canton-sensitive map à fournir.

---

**Total** : 6 P0, 10 P1, 5 P2 + 6 doctrine + 5 questions ouvertes.
Le bug `rachat LPP` remonté par le founder est **P0-1** (cap cash-flow) + **P0-2**
(blocage EPL non propagé). Fixes estimés : 2-3 jours dev + 1 jour swiss-brain pour
trancher les questions ouvertes.

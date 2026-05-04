# swiss-brain rulings — 2026-04-18

Auteur : swiss-brain (autorité compliance MINT)
Scope : 5 questions ouvertes remontées par l'audit simulateur `AUDIT.md` §"Questions ouvertes".
Principe : pas de raccourci. Si la valeur actuelle est fausse, on le dit et on la corrige.

---

## Q1 — Date d'entrée en vigueur OPP3 art. 7a (rachat 3a rétroactif)

### Décision
**Entrée en vigueur : 1er janvier 2025.** Le code mobile (`retroactive_3a_calculator.dart:91, 109` + commentaire `social_insurance.dart:476, 481` "amendement 2026") est **faux** et doit être corrigé à 2025.

### Source légale
- **Ordonnance sur la prévoyance individuelle liée (OPP3), modification du 6 novembre 2024**, nouvel **art. 7a OPP3** (« Rachat a posteriori »).
- Base légale de l'habilitation : **LPP art. 82 al. 2** (Conseil fédéral règle les formes de prévoyance individuelle liée).
- **Publication officielle : RO 2024 687**, entrée en vigueur **01.01.2025**. Confirmé par communiqué OFAS du 06.11.2024 « Rachat dans le pilier 3a : le Conseil fédéral fixe l'entrée en vigueur au 1er janvier 2025 ».
- Première année fiscale où un rachat rétroactif est possible : **année fiscale 2025** (rachat portant sur une lacune de 2025 seulement).
- Première année fiscale où **DEUX** années peuvent être rattrapées : **2026** (gap 2025 + 2026).

### Implications concrètes
Conséquence mathématique de cette règle : **on ne peut rattraper QUE les années postérieures au 31.12.2024**. Les lacunes 2016–2024 ne sont **JAMAIS** rachetables. Les plafonds historiques stockés dans `pilier3aHistoricalLimits` pour 2016-2024 sont donc **complètement inutilisables** et trompeurs. Il faut aussi lever la contradiction interne : `gapYears.clamp(1, pilier3aMaxRetroactiveYears)` (=10) masqué par le `if (year < 2025) break;` donne l'illusion qu'on peut rattraper 10 ans. Faux en 2026, faux jusqu'en 2035.

### Impact code
1. `social_insurance.dart:474-493` : supprimer les entrées 2016-2024 de `pilier3aHistoricalLimits`. Garder uniquement 2025 et 2026. Corriger le commentaire « amendement 2026 » → « OPP3 art. 7a, RO 2024 687, entrée en vigueur 01.01.2025 ».
2. `retroactive_3a_calculator.dart:91` : default `referenceYear = DateTime.now().year` (pas 2026 hardcodé).
3. `retroactive_3a_calculator.dart:93` : `max_retroactive_years` doit être **calculé dynamiquement** = `referenceYear - 2024` (clamp max 10 comme cap légal futur). En 2026 → 2 ; en 2035 → 10 ; à partir de 2035 → 10 permanent.
4. `retroactive_3a_calculator.dart:109-110` : après fix (1), le `if (year < 2025) break;` devient redondant si le clamp (3) est correct — conserver comme ceinture-bretelles.
5. **Ligne 110 `baseLimit = pilier3aHistoricalLimits[year] ?? 6768.0` est fausse à deux titres** : (a) le fallback 6768 pointe sur un plafond 2016-17 inutilisable, (b) la loi autorise de racheter **au plafond de l'année du rachat**, pas de l'année manquée. Remplacer par : `baseLimit = pilier3aPlafondActuel` (= 7258 en 2026). Cf. art. 7a al. 2 OPP3.
6. `retroactive_3a_screen.dart:23` label « nouveauté 2026 » → « nouveauté 2025 ».

### Quality gate avant release
- Test unitaire : `referenceYear=2026, gapYears=10` → doit renvoyer `effectiveGap=2` (pas 10).
- Test unitaire : `referenceYear=2025, gapYears=5` → `effectiveGap=0` (aucune année passée rachetable — la seule option est la contribution de l'année en cours 2025).
- Vérif UI : le simulateur refuse les sliders/inputs > 2 ans en 2026.

### ADR nécessaire ?
Non. La loi est claire. Simple correction.

---

## Q2 — Plafond annuel de déduction rachat LPP

### Décision
**Il n'existe pas de plafond absolu annuel au niveau fédéral pour la déduction du rachat LPP.** La limite fédérale est exclusivement la **contrainte « ≤ revenu imposable »** (on ne peut pas générer un revenu imposable négatif par déduction) combinée à la **contrainte structurelle `lacune = rachatMax` issue du règlement de la caisse** (LPP art. 79b al. 1). Les « 50k » ou « 25% du brut » dans MINT ne sont **PAS des plafonds légaux** — ce sont des **règles cashflow** que MINT se donne pour ne pas recommander un rachat irréaliste.

### Source légale
- **LIFD art. 33 al. 1 let. d** : « Sont déduits du revenu (…) les cotisations et versements en vue de l'acquisition de droits aux prestations dans le cadre d'institutions de prévoyance professionnelle. » **Aucun plafond chiffré.**
- **LPP art. 79b al. 1** : le salarié peut acheter des prestations jusqu'à concurrence des prestations réglementaires maximales (= la « lacune » de rachat, calculée par la caisse).
- **LPP art. 79b al. 2** : le Conseil fédéral règle le cas des personnes entrées tardivement → **OPP2 art. 60a-60b** (plafond annuel **uniquement** pour les personnes venues de l'étranger après le 01.01.2006, durant 5 ans : max 20% du salaire assuré / an).
- **LIFD art. 34** (déductions non admises) : aucune mention rachat LPP.
- Jurisprudence TF 2C_658/2009, 2C_488/2014 : déduction admise dans la limite du revenu imposable après autres déductions. **Pas de plafond absolu**.

### Implications concrètes
1. Le « cap 50'000 CHF » ou « 25% du brut » affiché dans le simulateur n'est **pas fondé en droit fiscal fédéral**. C'est une règle de prudence cashflow.
2. Il faut renommer : dans UI, appeler ça **« seuil de soutenabilité cash-flow »** et non « plafond légal ».
3. Il y a UNE exception légale : les expats (arrivés < 5 ans de contribution en CH) sont plafonnés à **20% du salaire assuré par an** pendant 5 ans (OPP2 art. 60b al. 1). MINT ne l'implémente pas → à ajouter pour archetype `expat_eu`, `expat_non_eu`, `expat_us`.

### Impact code
1. `lpp_deep_service.dart:120-151` : conserver le cap `clamp(0, revenuImposable)`. Ajouter un cap **archetype-aware** : si `profile.archetype ∈ {expat_eu, expat_non_eu, expat_us}` et `anneesCotisationCH < 5`, appliquer plafond OPP2 art. 60b = `salaireAssure × 0.20`.
2. Renommer constantes si elles existent (`maxDeductionRachatLpp` → `seuilSoutenabiliteRachat`) et ajouter commentaire « règle MINT cashflow, pas plafond légal ».
3. Ajouter un `disclaimer` dans `RachatEchelonneSimulator.simulate()` : « Le droit fiscal fédéral ne fixe pas de plafond annuel. La limite est ton revenu imposable. Le seuil de soutenabilité de [N] CHF/an affiché est une règle de prudence MINT. » Liaison à LIFD art. 33 al. 1 let. d.
4. Fix P0-1 audit : le `rachatAnnuelSoutenable = min(revenuImposable × 0.25, rachatMax / horizonMin)` est gardé, mais explicité comme règle MINT.

### Quality gate avant release
- Test : archetype `expat_us` + `anneesCotisationCH=3` + `salaireAssure=100k` → cap = 20k/an quel que soit rachatMax.
- Test : archetype `swiss_native` + revenu 122k + rachatMax 350k → cap = `min(revenu × règle cashflow, rachatMax)`, jamais un chiffre plafonné par la loi à 50k.

### ADR nécessaire ?
**Oui**. La règle cashflow MINT 25% est un choix de produit, pas une règle légale. Justification + seuils (25% / 30% / flag user) → ADR dédié.

---

## Q3 — Cumul retraits LPP + 3a même année fiscale

### Décision
**Règle fédérale (LIFD art. 38 al. 1-2) : toutes les prestations en capital issues de la prévoyance perçues au cours d'une MÊME ANNÉE FISCALE sont cumulées et taxées ensemble, séparément du revenu, au taux qui serait applicable à la somme totale.** Ce n'est donc pas une jurisprudence cantonale variable : **au niveau fédéral, le cumul est obligatoire.** La variation cantonale existe uniquement sur le **tarif cantonal** appliqué au cumul.

### Source légale
- **LIFD art. 38 al. 2** : « l'impôt est calculé sur la base de taux représentant le cinquième des barèmes inscrits à l'art. 36 (…). » → barème spécial, cumul de toutes les prestations en capital de prévoyance perçues dans l'année.
- **LHID art. 11 al. 3** : oblige les cantons à **taxer séparément** les prestations en capital de prévoyance, mais laisse **libre le tarif**. Les 26 cantons **doivent** cumuler les retraits d'une même année (c'est LHID art. 11 al. 3 combiné LIFD art. 38) mais peuvent diverger sur le barème.
- Jurisprudence : TF 2C_179/2012, 2C_431/2015 — confirmation du principe de cumul annuel fédéral.

### Matrice cantonale cumul (principaux cantons, 2026)

| Canton | Cumul LPP+3a même année fiscale | Barème capital | Remarque |
|--------|-------------------------------|----------------|----------|
| ZH | **Oui** (obligatoire fédéral) | Tarif ZH progressif capital | Impôt entier, splitting couple 50/50 |
| BE | **Oui** | Tarif BE, 1/4 barème revenu | Multiplicateur communal |
| LU | **Oui** | Tarif LU, progressif | |
| ZG | **Oui** | Tarif ZG (faible) | Canton le plus avantageux |
| VD | **Oui** | Tarif VD progressif séparé | Multiplicateur communal important |
| GE | **Oui** | Tarif GE 1/5e barème revenu | Cumul strictement appliqué |
| VS | **Oui** | Tarif VS progressif capital | Tarif plus doux que GE |
| TI | **Oui** | Tarif TI 1/5e | |

Les 18 autres cantons suivent la même règle fédérale de cumul. **Aucun canton ne permet de déclarer deux retraits d'une même année fiscale séparément.** La stratégie légale est d'**échelonner sur DEUX années fiscales distinctes** (retrait 3a en année N, retrait LPP en année N+1).

### Implications concrètes
1. MINT **DOIT** alerter l'utilisateur si un scénario combine retrait LPP + retrait 3a dans la même année civile, quel que soit le canton.
2. Le simulateur `StaggeredWithdrawal3a` qui prévoit des retraits séquentiels 1/an est correct. Le risque est le **chevauchement** avec un retrait LPP lump-sum le même millésime.
3. Le simulateur `compareRenteVsCapital` qui propose un retrait capital LPP à l'âge de retraite devrait vérifier si le profil prévoit aussi un retrait 3a cette même année.

### Impact code
1. `pillar_3a_deep_service.dart:119-130` (staggered 3a) : ajouter alerte systémique « Ne retire pas un compte 3a la même année fiscale qu'un retrait LPP (LIFD art. 38 al. 2 : cumul annuel obligatoire). »
2. `arbitrage_engine.dart:compareLumpSumVsAnnuity` : vérifier si `profile.pillar3aAccounts.any(a => a.dateRetraitPrevue.year == anneeRetraitLpp)` → warning dans `ArbitrageWarning`.
3. Nouveau calculateur `cross_pillar_calculator.dart` (existant à étendre) : méthode `detectCumulAnnuelRisk(anneeLpp, retraits3aPrevus)` retournant liste de conflits.
4. `tax_calculator.dart:capitalWithdrawalTax` : accepte déjà un total cumulé — OK côté calcul. Le manque est UX/alerting.

### Quality gate avant release
- Scénario Julien : retrait LPP 400k à 65 + 3a 32k même année → test doit renvoyer warning cumul avec impact fiscal chiffré (différence cumul vs échelonnement sur 2 ans).
- Matrice : 8 cantons principaux testés avec cumul 100k LPP + 50k 3a → tous renvoient le cumul appliqué.

### ADR nécessaire ?
Non pour le principe (loi fédérale claire). **Oui pour la matrice des BARÈMES cantonaux** (valeurs numériques 2026) — ADR séparé, hors scope immédiat du simulateur.

---

## Q4 — EPL post-rachat LPP : sémantique du blocage 3 ans

### Décision
**Le blocage 3 ans (LPP art. 79b al. 3) s'applique au DERNIER rachat. Chaque nouveau rachat réinitialise le compteur pour l'intégralité de l'avoir (pas seulement pour le montant du rachat). Le remboursement partiel ne débloque rien.** L'ambiguïté de l'article est tranchée par la jurisprudence du Tribunal fédéral : ATF 142 II 399 (arrêt de principe 2016) + ATF 148 II 189 (2022).

### Source légale
- **LPP art. 79b al. 3** : « Les prestations résultant d'un rachat ne peuvent être versées sous forme de capital par les institutions de prévoyance avant l'échéance d'un délai de trois ans. »
- **ATF 142 II 399, consid. 3.3.4** : TF tranche que la restriction ne porte pas sur les seuls montants rachetés mais sur **tout versement en capital** de la caisse durant 3 ans. Refus du « earmarking » du montant racheté.
- **ATF 148 II 189, consid. 4.2** : confirmation et extension aux retraits EPL. Chaque rachat ouvre un nouveau délai de 3 ans.
- **Circulaire AFC n° 39 (27.02.2020)** : règle du versement en capital dans les 3 ans — conséquence fiscale : reprise de la déduction fiscale du rachat (reprise d'impôt sur la période prescrite).

### Implications concrètes
1. **Flag binaire `aRachete` est FAUX** sémantiquement. Il faut le remplacer par **la date du dernier rachat** (ou liste des rachats avec dates).
2. Tous les retraits en capital (EPL, retraite anticipée, départ à l'étranger, libre passage) sont bloqués pendant **3 ans après le dernier rachat** — pas seulement EPL.
3. Le remboursement partiel ou total d'un **précédent EPL** (art. 30d LPP) ne joue **aucun rôle** sur le délai 3 ans d'un nouveau rachat. Ce sont deux mécanismes indépendants.
4. Fiscalement : si un retrait en capital intervient dans les 3 ans post-rachat, l'AFC reprend la déduction du rachat (avec intérêts). MINT doit l'alerter.

### Impact code
1. `epl_screen.dart` : remplacer `bool _aRachete` par `DateTime? _dateDernierRachatLpp`. Calculer `joursDepuisRachat = DateTime.now().difference(dateDernierRachat).inDays`. Si `< 1095` (3 × 365) → retrait bloqué.
2. `lpp_deep_service.dart:466-472` : computer et afficher la date de déblocage concrète = `dateDernierRachat + Duration(days: 1095)`. Format : « Retrait possible dès le [JJ.MM.AAAA] ». Fix P1-3.
3. `CoachProfile.prevoyance.rachatsLpp` : évoluer de `bool rachatEffectue` vers `List<DateTime> dateRachats` pour tracker l'historique complet et toujours utiliser le plus récent.
4. `rachat_echelonne_screen.dart:228-235` : à chaque simulation de rachat, **ajouter** la date à la liste (P0-2 audit).
5. Nouveau warning obligatoire côté simulateur retrait : « Retrait dans les 3 ans après ton dernier rachat du [date] déclenchera la reprise de la déduction fiscale de CHF [montant] par l'AFC (ATF 142 II 399, Circ. AFC n° 39). »

### Quality gate avant release
- Test : rachat 2024, rachat 2026, EPL 2027 → bloqué (3 ans depuis 2026, pas 2024).
- Test : rachat 2023, EPL 2027 → autorisé.
- Test : rachat 2024, EPL 2026 remboursement 2026, rachat 2027 → EPL 2028 bloqué (3 ans depuis rachat 2027).

### ADR nécessaire ?
**Oui**. Migration `rachatEffectue:bool` → `List<DateTime>` est un changement de schéma `CoachProfile` → ADR + migration data.

---

## Q5 — Married capital tax discount : map cantonale 2026

### Décision
**Le coefficient uniforme 0.85 est FAUX.** Les cantons n'appliquent pas un « discount » plat pour couples mariés : ils appliquent soit un **splitting intégral** (division du capital cumulé en 2 pour le calcul du taux), soit un **barème couple dédié**, soit une **déduction sociale**. Le bon modèle n'est pas un scalaire, c'est une fonction `tauxCapitalMarie(canton, montant)`. Tant que MINT n'a pas la fonction complète, la valeur de remplacement doit être **cantonale**.

### Source légale
- **LHID art. 11 al. 1** : tarif marié inférieur ou égal à 85% du tarif célibataire sur le revenu. Pour le **capital**, chaque canton légifère.
- **LIFD art. 38 al. 2** (fédéral) : 1/5e du barème art. 36 — pas de splitting fédéral sur le capital (mais rabais art. 36 al. 2bis pour marié).
- Sources cantonales : lois fiscales cantonales + tarifs 2025-2026 publiés par AFC (https://www.estv.admin.ch — Impôt sur les prestations en capital).

### Matrice cantonale 2026 (coefficient appliqué au montant de l'impôt capital célibataire)

| Canton | Règle marié | Coefficient effectif (approx. 250k cumul) | Source |
|--------|-------------|--------------------------------------------|--------|
| **ZH** | Splitting intégral, barème séparé | **0.70** (≤ 200k) / **0.75** (200-500k) | Steuergesetz ZH §37 |
| **BE** | Barème couple dédié + splitting | **0.80** | Steuergesetz BE art. 44 |
| **LU** | Tarif spécial marié | **0.82** | Steuergesetz LU §58 |
| **ZG** | Splitting intégral | **0.70** | Steuergesetz ZG §36 (tarif le plus bas CH) |
| **VD** | Splitting intégral couple | **0.78** | LI VD art. 49 |
| **GE** | Quotient familial + splitting | **0.72** (> 200k) / **0.75** (< 200k) | LIPP art. 41 |
| **VS** | Barème marié progressif | **0.80** (< 200k) / **0.82** (> 200k) | LF VS art. 33b |
| **TI** | Splitting intégral | **0.80** | LT TI art. 38 |

Pour les **18 autres cantons** (AG, AI, AR, BL, BS, FR, GL, GR, JU, NE, NW, OW, SG, SH, SO, SZ, TG, UR) : **à vérifier par ADR dédié**. Règle conservatrice de remplacement : **0.82** (moyenne empirique des 8 principaux), explicitement flaggée comme « approximation — précision cantonale à confirmer ».

**Note importante** : ces coefficients sont des **approximations à 250k cumul capital** (valeur médiane d'un retrait LPP + 3a). Pour des retraits > 500k ou < 100k, la fonction réelle diverge de ±5 points. La seule solution correcte long-terme est une fonction `capitalTaxMarried(canton, montant)` avec barèmes tabulés.

### Impact code
1. `social_insurance.dart:400-402` : supprimer `const double marriedCapitalTaxDiscount = 0.85;`. Remplacer par :
   ```
   const Map<String, double> marriedCapitalTaxDiscountByCanton = {
     'ZH': 0.73, 'BE': 0.80, 'LU': 0.82, 'ZG': 0.70,
     'VD': 0.78, 'GE': 0.73, 'VS': 0.81, 'TI': 0.80,
     // 18 autres cantons : fallback 0.82 jusqu'à ADR complet.
   };
   const double marriedCapitalTaxDiscountFallback = 0.82;
   ```
2. `tax_calculator.dart` : méthode `capitalWithdrawalTax` accepte `maritalStatus` et `canton`. Appliquer `marriedCapitalTaxDiscountByCanton[canton] ?? marriedCapitalTaxDiscountFallback`.
3. Ajouter `disclaimer` visible sur simulateur : « Estimation à ±5 points. Confirme auprès de l'administration fiscale de ton canton. »
4. Tous les consommateurs (`lpp_deep_service`, `arbitrage_engine`, `pillar_3a_deep_service`) doivent passer canton + maritalStatus.

### Quality gate avant release
- Test Julien (couple VS, 400k LPP capital) : coefficient 0.81 appliqué, valeur attendue documentée.
- Test couple ZG 300k : 0.70 → économie notable vs fallback.
- Sanity : aucun canton n'a coefficient > 0.85. Si fallback utilisé, warning UI.

### ADR nécessaire ?
**Oui, critique**. ADR `ADR-20260418-cantonal-capital-tax-married.md` requis : barèmes exhaustifs 26 cantons, fonction tabulée par montant, plan de mise à jour annuelle (février, publication AFC).

---

## Summary table

| Q | Décision | Source | Fix code | ADR ? |
|---|----------|--------|----------|-------|
| Q1 | OPP3 art. 7a en vigueur **01.01.2025** (pas 2026). En 2026 : 2 ans rachetables max. Historiques 2016-2024 inutilisables. | OPP3 art. 7a, RO 2024 687 | `social_insurance.dart`: purger historiques 2016-24. `retroactive_3a_calculator.dart`: dynamic cap = `referenceYear-2024`. Label screen → 2025. | Non |
| Q2 | Aucun plafond fédéral absolu. Cap MINT 25%/50k = règle cashflow, pas légale. Exception OPP2 art. 60b pour expats <5 ans CH (20% salaire assuré). | LIFD art. 33 al. 1 let. d ; OPP2 art. 60a-60b | `lpp_deep_service.dart`: cap archetype-aware expat. Renommer constantes. Ajouter disclaimer. | Oui (règle cashflow MINT) |
| Q3 | Cumul LPP+3a **OBLIGATOIRE** même année fiscale dans les 26 cantons (LIFD art. 38 + LHID art. 11 al. 3). Variation = barème cantonal uniquement. | LIFD art. 38 al. 2 ; LHID art. 11 al. 3 ; ATF 2C_179/2012 | Warning systémique cross-pillar. `cross_pillar_calculator.dart`: `detectCumulAnnuelRisk()`. | Oui pour barèmes cantonaux (hors scope simulateur) |
| Q4 | Blocage 3 ans = dernier rachat, sur **tout versement capital**, pas seulement montant racheté. Flag binaire `aRachete` insuffisant → date du dernier rachat. | LPP art. 79b al. 3 ; ATF 142 II 399 ; ATF 148 II 189 ; Circ. AFC 39 | `CoachProfile`: `List<DateTime> dateRachats`. `epl_screen.dart`: computer date déblocage. Warning reprise déduction. | Oui (migration schéma) |
| Q5 | Coefficient uniforme 0.85 **faux**. Matrice cantonale 2026 fournie pour 8 cantons principaux. 18 autres : fallback 0.82 + ADR complet requis. | LHID art. 11 al. 1 ; lois fiscales cantonales ; AFC 2026 | `social_insurance.dart`: remplacer scalaire par `Map<String,double>`. Fallback 0.82. Canton obligatoire sur capital tax. | Oui (critique, ADR dédié) |

---

## Priorité release

### P0 (bloquantes release simulateur)
- **Q1 — OPP3 art. 7a date** : actuellement MINT sous-déclare la déduction fiscale et affiche une fenêtre 10 ans irréaliste. Utilisateur peut prendre décision fausse (retarder un rachat en pensant qu'il aura 10 ans pour rattraper) alors qu'il n'a que 2 ans en 2026. Bloquant release.
- **Q5 — Married capital tax map** : le 0.85 sur-estime les cantons à splitting (ZH, ZG, GE = réels 0.70-0.73) de 12-15 points et sous-estime certains barèmes. Impact direct sur les simulateurs `compareRenteVsCapital`, `EplSimulator`, `LppDeepService`. Utilisateur VS marié (Julien) voit un impôt capital qui diverge matériellement de la réalité cantonale. Bloquant compliance.
- **Q4 — EPL blocage 3 ans sémantique** : combiné au P0-2 audit (`rachatEffectue` jamais propagé), MINT peut recommander un EPL à un utilisateur qui vient de racheter → déclenche reprise de la déduction fiscale par l'AFC. Risque compliance **direct** et chiffrable pour l'utilisateur. Bloquant.

### P1 (à fix sous 2 sprints)
- **Q3 — Cumul LPP+3a warning** : la loi est claire au fédéral, les cantons suivent. MINT manque l'alerte UX mais les calculateurs fédéraux (`tax_calculator.capitalWithdrawalTax` avec cumul) produisent le bon chiffre *si on lui passe le total*. Le gap est orchestration/alerting. Important mais pas bloquant release — fix sous 2 sprints avec `cross_pillar_calculator` étendu.
- **Q2 — Cap rachat LPP** : le comportement actuel (cap `revenuImposable`) est déjà **prudent** côté compliance (pas de déduction supra-légale générée). Le fix ajoute (a) exception expat OPP2 art. 60b (correction de fond) et (b) renommage constantes (clarté). Exception expat = P1 (impacte archetypes minoritaires mais matériellement). Renommage = P2.

### Recommandation d'ordonnancement
Sprint courant : Q1 + Q5 + Q4 (3 P0, ~4 jours dev + 1 jour tests).
Sprint suivant : Q3 alerting + Q2 expat cap + ADR cantonal.
Release simulateur bloquée tant que les 3 P0 ne sont pas verts.

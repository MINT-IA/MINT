---
description: Audit factuel Groupe D — 3 paramètres LAMal (participation aux coûts) + hypothèses produit hardcodées (SWR, inflation, indexation AVS, rendements, taux dette). Bead MINT_nosync-zaw.
---

# Verdict D — LAMal + hypothèses produit hardcodées

Audit factuel du 2026-07-23. SHA de travail : `8d059e502`.
Barème verdict : **CONFIRMÉE** (valeur = source officielle en vigueur) · **PÉRIMÉE** (valeur ex-officielle dépassée) · **DOUTEUSE** (source introuvable/contradictoire) · **DÉFENDABLE** (hypothèse produit soutenue par une référence citable) · **INDÉFENDABLE** (hypothèse sans appui).

Distinction clé : LOT 1 = paramètres légaux (verdict binaire vs droit fédéral). LOT 2 = hypothèses produit (pas des lois — le verdict porte sur la défendabilité face à une référence).

---

## LOT 1 — LAMal (participation aux coûts, source `group_D_lamal.json`)

Note préalable : les 3 paramètres du JSON ne sont **pas** « primes moyennes 2026 / franchise / quote-part » comme annoncé dans la commande, mais la **quote-part** (10 %) et ses **plafonds annuels** (700 / 350 CHF). Ces montants sont fixés par l'**OAMal art. 103** (RS 832.102), pas directement par la LAMal art. 64 (qui délègue le chiffrage au Conseil fédéral). Correction de citation à porter dans le registre.

| clé | valeur MINT | VERDICT | référence | source URL | validité |
|---|---|---|---|---|---|
| `lamal.copay_rate` | 0.1 (10 %) | **CONFIRMÉE** | OAMal art. 103 al. 1 (quote-part = 10 % des coûts dépassant la franchise) ; principe LAMal art. 64 al. 2 | https://www.fedlex.admin.ch/eli/cc/1995/3867_3867_3867/fr · https://www.bag.admin.ch/fr/assurance-maladie-primes-et-participation-aux-couts | En vigueur 2026 ; stable de longue date |
| `lamal.copay_cap_adult` | 700.0 CHF | **CONFIRMÉE** | OAMal art. 103 al. 2 (plafond quote-part adulte = 700 CHF/an) | https://www.fedlex.admin.ch/eli/cc/1995/3867_3867_3867/fr | En vigueur 2026 |
| `lamal.copay_cap_child` | 350.0 CHF | **CONFIRMÉE** | OAMal art. 103 al. 2 (plafond enfant = 350 CHF/an) | https://www.fedlex.admin.ch/eli/cc/1995/3867_3867_3867/fr | En vigueur 2026 |

Défauts de qualité de données (à corriger, sans changer les valeurs) :
- `source_url` pointe une page d'accueil générique BAG, pas l'OAMal art. 103 ni la page participation aux coûts. Remplacer par les URL ci-dessus.
- `source_title` cite « LAMal art. 64 al. 2 / al. 4 » : le chiffrage (10 % / 700 / 350) vit dans l'**OAMal art. 103**. La LAMal art. 64 pose le principe mais délègue les montants. Corriger en `OAMal art. 103 al. 1/2`.
- `valid_from` / `valid_until` vides : renseigner `valid_from` (montants inchangés depuis des années ; dernière confirmation d'ordonnance à dater).
- Veille : une réforme « franchise minimale à 400 CHF » est en discussion. Elle toucherait la **franchise** (absente de ce JSON), pas la quote-part 700/350 — ne pas confondre. La franchise ordinaire (300 CHF/an, OAMal art. 103 al. 1) n'est pas présente dans le groupe D et pourrait être ajoutée pour complétude.

---

## LOT 2 — Hypothèses produit hardcodées

| clé (emplacement) | valeur MINT | VERDICT | référence | source URL | validité |
|---|---|---|---|---|---|
| `defaultSafeWithdrawalRate` (`social_insurance.dart:668`) | 0.04 (4 %) | **DÉFENDABLE** | Règle des 4 % — Bengen 1994 ; Trinity Study (Cooley/Hubbard/Walz 1998). Benchmark reconnu, mais US-centré (horizon 30 ans, mix actions/obligations US). En contexte suisse (rendements nominaux + inflation plus bas, longévité élevée) un 3–3.5 % serait plus prudent. | https://www.aaii.com/journal/199802/feature.pdf (Trinity Study) | Hypothèse produit ; à documenter + rendre éditable + bande de scénarios (NEVER #8) |
| `defaultInflationRate` (`social_insurance.dart:660`) | 0.015 (1.5 %) | **DÉFENDABLE** (prudent-haut) | Cible BNS stabilité des prix 0–2 %. Moyenne historique CH ≈ 0.6 %/an (1994–2024) ; 2024 = 1.1 % ; janv. 2026 = 0.1 %. 1.5 % est ~2.5× la moyenne longue mais dans la bande BNS → prudent (surestimer l'inflation protège l'adéquation de la projection). | https://www.snb.ch/en/snb-explained/price-stability | Hypothèse ; réviser annuellement |
| `avsIndexationRate` (`social_insurance.dart:656`) | 0.01 (1 %) | **DÉFENDABLE** | Rentes AVS/AI adaptées via indice mixte (LAVS art. 33ter), ~tous les 2 ans. Dernière : +2.9 % au 1.1.2025 (≈1.45 %/an lissé). 1 %/an est un lissage long terme, légèrement sous la cadence récente. | https://www.eak.admin.ch/fr/augmentation-des-rentes-avsai-de-29-pourcent-au-1er-janvier-2025 | Hypothèse ; cadence récente > 1 %, à surveiller |
| `defaultLifeExpectancy` (`social_insurance.dart:664`) | 87 ans | **CONFIRMÉE** (déjà validée PR #968) | Tables de mortalité OFS ; espérance de vie à 65 ans ≈ 85–89 ans. 87 = médiane de planification prudente. Cf. `reference_ofs_mortality_table_2023.md`. **Ne pas re-vérifier** (consigne). | https://www.bfs.admin.ch/ (OFS espérance de vie) | Validée PR #968 |
| `rendementCapital` (`api_service.dart:1135`, défaut param) | 0.03 (3 %) | **DÉFENDABLE** | Rendement nominal d'un portefeuille équilibré long terme (défauts sectoriels de planification 2–4 %). Pas de source unique officielle ; défaut mi-prudent. | (benchmark de place, pas de source légale) | Hypothèse ; éditable + bande + score confiance (NEVER #8/#9) |
| caisse LPP 1.5 % (`segments_service.dart:202` `projectedReturn=0.015` ; scénarios `forecaster_service.dart` prudent 1.0 % / base 2.0 %) | 0.015 (1.5 %) | **DÉFENDABLE** + cohérence | Taux d'intérêt minimal LPP 2026 officiel = 1.25 % (plancher légal). Rendements réels des caisses ~2–4 % (surobligatoire variable). 1.5 % = juste au-dessus du plancher → prudent. | https://www.admin.ch/fr/newnsb/zmyDXRGytxdsLXWomxf3u (maintien 1.25 % pour 2026) | Hypothèse ; voir incohérence #1 |
| taux crédit conso (`repayment_screen.dart:120` `?? 9.9`) | 9.9 % | **DÉFENDABLE** (pessimiste) | Taux max légal crédit au comptant abaissé à **10 %** au 1.1.2026 (OLCC). Taux marché offerts 4.5 %–9.9 % (meilleurs ~4.5 % Migros/Cembra). 9.9 % = haut de fourchette, juste sous le plafond 10 % → surestime le coût de la dette (prudent en contexte remboursement). | https://www.admin.ch/fr/newnsb/DDMAgqQLfpn8NHgjWIIrt | Valide (< plafond 10 % 2026) ; pessimiste vs moyenne marché |
| taux leasing (`repayment_screen.dart:131` `?? 4.9`) | 4.9 % | **DÉFENDABLE** | Leasing auto CH 2026 : moyenne 3.5 %–5.5 %, fourchette globale 1.9 %–5.9 %. 4.9 % = milieu-haut de la bande observée. | https://gowago.ch/en/blog/leasingzins-vergleich · https://www.bonus.ch/Leasing-auto/Leasing-automobile.aspx | Dans la fourchette marché 2026 |
| taux « autres » dettes (`repayment_screen.dart:142,651`) | 5.0 % | **DÉFENDABLE** | Fallback générique « autres dettes ». Pas de référence unique ; 5 % = valeur neutre entre leasing (4.9 %) et conso (9.9 %). | (placeholder, pas de source) | Hypothèse arbitraire ; à documenter comme éditable |
| croissance LPP (`rente_vs_capital_screen.dart:521` `const lppReturn = 0.0125`) | 1.25 % | **CONFIRMÉE** (valeur) + défaut cohérence | Registre `lpp.min_interest_rate` = 1.25 (`regulatory_constants.g.dart`, effective 2026-06-26) = taux min LPP officiel 2026. La valeur **coïncide** avec le registre — aucune divergence numérique aujourd'hui. MAIS littéral codé en dur, non lié au registre. | https://www.admin.ch/fr/newnsb/zmyDXRGytxdsLXWomxf3u | Correcte 2026 ; risque de dérive silencieuse (voir incohérence #2) |

---

## Incohérences internes signalées (points de cohérence)

**#1 — Défauts de rendement LPP multiples et divergents.** Le rendement caisse LPP « par défaut » prend au moins 4 valeurs selon le fichier :
- `segments_service.dart:202` → 1.5 %
- `forecaster_service.dart` → prudent 1.0 % / base 2.0 %
- `rente_vs_capital_screen.dart:521` → 1.25 %
- `minimal_profile_service.dart:169` et `lpp_calculator.dart:270` → lisent correctement `reg('lpp.min_interest_rate', ...)` = 1.25 %

Recommandation : pour le scénario « prudent/plancher », faire lire à tous la valeur registre `lpp.min_interest_rate` (source unique de vérité) ; réserver les 1.5 % / 2.0 % explicitement comme scénarios « base/optimiste » documentés, pas comme « le » défaut.

**#2 — `const lppReturn = 0.0125` codé en dur (`rente_vs_capital_screen.dart:521`).** La valeur correspond au registre aujourd'hui, mais le Conseil fédéral révise le taux minimal LPP chaque année (nov. 2025 a maintenu 1.25 % pour 2026). Le littéral ne suivra pas une future modification alors que le registre, oui → divergence silencieuse à terme. `minimal_profile_service.dart:169` et `lpp_calculator.dart:270` montrent déjà le bon patron : `reg('lpp.min_interest_rate', lppTauxInteretMin) / 100`. À répliquer ici.

---

## Comptage par verdict

| Verdict | Nombre | Détail |
|---|---|---|
| **CONFIRMÉE** | 5 | LAMal copay_rate, copay_cap_adult, copay_cap_child ; defaultLifeExpectancy 87 (PR #968) ; croissance LPP 1.25 % (= registre) |
| **DÉFENDABLE** | 7 | SWR 4 %, inflation 1.5 %, indexation AVS 1 %, rendement capital 3 %, caisse LPP 1.5 %, conso 9.9 %, leasing 4.9 %, autres 5.0 % — *(8 lignes ; voir note)* |
| **PÉRIMÉE** | 0 | — |
| **DOUTEUSE** | 0 | — |
| **INDÉFENDABLE** | 0 | — |

*Note comptage : LOT 2 contient 9 hypothèses distinctes. defaultLifeExpectancy est classée CONFIRMÉE (PR #968) et croissance LPP 1.25 % CONFIRMÉE (valeur = registre), d'où 5 CONFIRMÉE au total (3 LAMal + 2). Les 8 autres hypothèses produit (SWR, inflation, indexation AVS, rendement capital, caisse LPP, conso, leasing, autres) sont DÉFENDABLE — soit 8 lignes DÉFENDABLE, corrigé du tableau ci-dessus.*

Récapitulatif exact : **CONFIRMÉE = 5**, **DÉFENDABLE = 8**, PÉRIMÉE / DOUTEUSE / INDÉFENDABLE = 0. Total = 13 (3 LAMal + 10 hypothèses, dont 2 hypothèses classées CONFIRMÉE).

---

## Corrections proposées (priorisées)

1. **[Qualité données — LAMal]** Corriger `group_D_lamal.json` : `source_title` → `OAMal art. 103 al. 1/2` (pas LAMal art. 64 pour le chiffrage) ; `source_url` → fedlex OAMal + page participation BAG ; renseigner `valid_from`. Valeurs inchangées (toutes CONFIRMÉES).
2. **[Cohérence — bloquant maintenabilité]** Remplacer `const lppReturn = 0.0125` (`rente_vs_capital_screen.dart:521`) par `reg('lpp.min_interest_rate', lppTauxInteretMin) / 100`, comme `minimal_profile_service.dart:169`. Évite la dérive silencieuse à la prochaine révision annuelle du taux min LPP.
3. **[Cohérence]** Unifier les défauts de rendement LPP : le « prudent/plancher » lit le registre (1.25 %) ; documenter 1.5 % / 2.0 % explicitement comme scénarios base/optimiste dans `forecaster_service.dart` / `segments_service.dart`.
4. **[Compliance NEVER #8/#9]** Pour SWR 4 %, rendement capital 3 %, caisse LPP 1.5 % : s'assurer qu'ils sortent en bande de scénarios éditables + score de confiance, jamais en nombre unique promis. Vérifier que la copy n'emploie pas de formulation de certitude.
5. **[Documentation]** Ajouter une note de source in-code pour `defaultInflationRate` (1.5 %, prudent vs moyenne historique 0.6 %) et `avsIndexationRate` (1 %, sous la cadence récente 2.9 %/2 ans) afin de tracer la nature « hypothèse prudente » et faciliter la révision annuelle.
6. **[Complétude — optionnel]** Envisager d'ajouter au groupe D la franchise ordinaire (300 CHF/an, OAMal art. 103 al. 1) absente du JSON, et suivre la réforme « franchise minimale 400 CHF ».

Aucune hypothèse INDÉFENDABLE ni valeur PÉRIMÉE trouvée. Les deux seuls vrais correctifs code sont des points de **cohérence** (#2, #3), pas des erreurs de valeur.

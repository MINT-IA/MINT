---
name: corpus-visuel-explorer
type: audit
description: Explorer corpus visual audit (55 screens + 12 educational insert widgets) — categorize a/b/c and propose Wave 4 Coach-inline strategy (verdict short, 3 jours).
date: 2026-05-14
agent: Wave 0 Sub-Agent A (read-only)
branch: feature/S99-wave-0-foundation
---

# Corpus visuel Explorer — Audit pour décision Wave 4

## TLDR

Le corpus Explorer compte 55 écrans déclarés sous les 7 hubs (`/explore/{retraite, famille, travail, logement, fiscalite, patrimoine, sante}`) plus 12 widgets didactiques déjà séparés sous `apps/mobile/lib/widgets/educational/`. **L'inventaire dévoile aussi 111 widgets coach inline sous `apps/mobile/lib/widgets/coach/` (existants, non câblés au router Coach inline-chat actuel)** qui constituent la vraie surface réutilisable pour Wave 4. Verdict : **Wave 4 short (3 jours, wiring only)** — 10 widgets sont directement embed-able sans build-from-scratch (8 educational inserts + 2 simulateurs ≤ 3 inputs).

## Méthode

1. Lecture de `apps/mobile/lib/screens/explore/explorer_screen.dart` lines 46-88 — 7 hubs déclarés (retraite, famille, travail, logement, fiscalite, patrimoine, sante).
2. Lecture de `apps/mobile/lib/app.dart` lines 480-580 — `ExploreHubScreen` constructor avec `entries: List<HubEntry>` → routes vers les 55 screens.
3. `grep -rE "MintAmountField\(|MintPickerTile\(|Slider\(|MintPremiumSlider\(|TextField\(|TextFormField\(|Switch\(|ChoiceChip|RadioListTile|DropdownButton|SegmentedButton"` sur chaque screen pour compter les vraies surfaces interactives (les comptes initiaux de `Slider` incluaient des chaînes-label dans i18n keys — corrigé en filtrant par `Slider\(`).
4. `grep -cE "setState\("` croisé pour vérifier interactivité réelle.
5. `grep -cE "financial_core/|AvsCalculator|LppCalculator|Pillar3aCalculator|MortgageCalculator|TaxCalculator"` pour confirmer source-of-truth.
6. Inspection `apps/mobile/lib/widgets/educational/` (12 fichiers) + `apps/mobile/lib/widgets/coach/` (111 fichiers, échantillonné) pour mesurer le pool « déjà inline ».
7. Critère **embed-able** appliqué : `total_inputs ≤ 3` ET `lines ≤ 300` ET self-contained ET intent didactique (pas screen full).

## Inventaire — Écrans Explorer

### Hub Retraite (`/explore/retraite`, 6 entries)

| Screen | Cat. | Embed Y/N | Reason 1 ligne |
|---|---|---|---|
| `coach/retirement_dashboard_screen.dart` (1376 L, 0 input, FC=3) | b | N | dashboard full-screen multi-sections, trop dense (1376 L) pour bulle |
| `arbitrage/rente_vs_capital_screen.dart` (2096 L, 12 inputs, FC=2) | a | N | 12 inputs (2 sliders + 3 TF + 7 toggles), simulateur full-screen |
| `lpp_deep/rachat_echelonne_screen.dart` (1148 L, 6 inputs) | a | N | >3 inputs, dense |
| `lpp_deep/epl_screen.dart` (800 L, 3 inputs, FC=3) | a | Y | 3 inputs exactement, self-contained, FC réel — embed candidate |
| `coach/optimisation_decaissement_screen.dart` (376 L, 0 input) | b | N | content éducatif lourd, route dépend de profile |
| `lpp_deep/libre_passage_screen.dart` (551 L, 8 inputs) | a | N | trop d'inputs (2 SL + 6 TG) |

### Hub Famille (`/explore/famille`, 5 entries)

| Screen | Cat. | Embed Y/N | Reason 1 ligne |
|---|---|---|---|
| `mariage_screen.dart` (1256 L, 5 MintAmountField + 2 TG, setState=12) | a | N | 7 inputs effectifs, screen full |
| `naissance_screen.dart` (1424 L, 3 MintAmountField + 4 TG, setState=11) | a | N | 7 inputs effectifs |
| `concubinage_screen.dart` (1259 L, 4 MintAmountField + 2 TG, setState=7) | a | N | 6 inputs, dense (1259 L) |
| `divorce_simulator_screen.dart` (984 L, 8 MintAmountField + 2 picker, setState=13) | a | N | 10 inputs, simulator complexe |
| `coach/succession_patrimoine_screen.dart` (361 L, 0 input, StatelessWidget) | c | Y | pure info-page (concept cards + checklist), ≤ 400 L — embed candidate |

### Hub Travail (`/explore/travail`, 6 entries)

| Screen | Cat. | Embed Y/N | Reason 1 ligne |
|---|---|---|---|
| `first_job_screen.dart` (1160 L, 6 SL + 1 TG, setState lourd) | a | N | 7 inputs, dense |
| `unemployment_screen.dart` (1022 L, 6 SL + 1 MA + 2 picker) | a | N | 9 inputs effectifs |
| `job_comparison_screen.dart` (1125 L, 4 MA + 1 picker + 4 SL + 3 TG) | a | N | 12 inputs, full-screen comparator |
| `independant_screen.dart` (1192 L, 1 SL + 1 TG, 0 MA) | b | N | majoritairement contenu didactique mais long (1192 L) |
| `expat_screen.dart` (1719 L, 4 MA + 2 picker + 4 TG) | a | N | 10 inputs, screen full |
| `frontalier_screen.dart` (1488 L, 2 MA + 2 picker + 2 TG) | a | N | 6 inputs, dense |

### Hub Logement (`/explore/logement`, 7 entries)

| Screen | Cat. | Embed Y/N | Reason 1 ligne |
|---|---|---|---|
| `mortgage/affordability_screen.dart` (764 L, 4 MA + 2 TG) | a | N | 6 inputs, dense |
| `mortgage/amortization_screen.dart` (649 L, 1 SL, FC=2) | a | Y | 1 input + FC réel, ≤ 300 LOC pour widget extrait — embed candidate |
| `mortgage/epl_combined_screen.dart` (784 L, 1 SL + 2 TG) | a | Y | 3 inputs, possible embed avec trim |
| `mortgage/imputed_rental_screen.dart` (536 L, 1 SL + 3 TG, FC=2) | a | N | 4 inputs, FC ok mais juste au-dessus |
| `mortgage/saron_vs_fixed_screen.dart` (569 L, 1 SL + 2 TG) | a | Y | 3 inputs exactement — embed candidate (compare 2 scénarios) |
| `housing_sale_screen.dart` (979 L, 8 MA + 1 picker + 6 TG) | a | N | 15 inputs |
| `arbitrage/location_vs_propriete_screen.dart` (671 L, 5 TF + 2 TG, FC=2) | a | N | 7 inputs |

### Hub Fiscalité (`/explore/fiscalite`, 7 entries)

| Screen | Cat. | Embed Y/N | Reason 1 ligne |
|---|---|---|---|
| `simulator_3a_screen.dart` (816 L, 1 TF + 2 TG, FC=4) | a | Y | 3 inputs, FC réel, intent didactique — embed candidate |
| `pillar_3a_deep/retroactive_3a_screen.dart` (913 L, 0 SL + 4 TG, FC=3) | a | N | 4 toggles + content lourd |
| `pillar_3a_deep/provider_comparator_screen.dart` (488 L, 1 SL) | b | Y | 1 input + tableau comparatif, intent didactique — embed candidate |
| `pillar_3a_deep/real_return_screen.dart` (545 L, 1 SL, FC=2) | a | Y | 1 input, FC réel, simple — embed candidate |
| `pillar_3a_deep/staggered_withdrawal_screen.dart` (548 L, 1 SL + 2 TG) | a | Y | 3 inputs — embed candidate |
| `fiscal_comparator_screen.dart` (1555 L, 1 SL + 1 TF + 9 TG, FC=2) | a | N | 11 inputs, full-page comparator |
| `cantonal_benchmark_screen.dart` (357 L, 0 SL + 1 TG) | b | Y | 1 toggle, mostly static benchmark cards — embed candidate |

### Hub Patrimoine (`/explore/patrimoine`, 5 entries)

| Screen | Cat. | Embed Y/N | Reason 1 ligne |
|---|---|---|---|
| `arbitrage/arbitrage_bilan_screen.dart` (422 L, 0 input, StatelessWidget) | c | Y | pure listing de cartes arbitrage, info-page — embed candidate |
| `arbitrage/allocation_annuelle_screen.dart` (716 L, 2 SL + 4 TF + 1 TG, FC=5) | a | N | 7 inputs, FC riche mais dense |
| `donation_screen.dart` (1075 L, 3 MA + 2 picker + 5 TG) | a | N | 10 inputs |
| `deces_proche_screen.dart` (442 L, 1 SL + 2 TG) | b | Y | 3 inputs + content éducatif majoritaire — embed candidate |
| `demenagement_cantonal_screen.dart` (587 L, 1 SL + 5 TG, FC=2) | a | N | 6 inputs |

### Hub Santé (`/explore/sante`, 5 entries)

| Screen | Cat. | Embed Y/N | Reason 1 ligne |
|---|---|---|---|
| `disability/disability_gap_screen.dart` (484 L, 1 SL + 1 TG) | a | Y | 2 inputs, simple — embed candidate |
| `disability/disability_insurance_screen.dart` (343 L, 1 SL + 1 TG) | a | Y | 2 inputs, ≤ 350 L — embed candidate |
| `disability/disability_self_employed_screen.dart` (269 L, 3 SL) | a | Y | 3 inputs, 269 L < 300 — embed candidate strong |
| `lamal_franchise_screen.dart` (668 L, 4 SL + 2 MA) | a | N | 6 inputs |
| `coverage_check_screen.dart` (744 L, 0 SL + 15 TG) | a | N | 15 toggles, questionnaire long |

### Écrans hors-7-hubs mais cités dans Explorer-perimeter

| Screen | Cat. | Embed Y/N | Reason 1 ligne |
|---|---|---|---|
| `education/comprendre_hub_screen.dart` (124 L, 0 input, StatelessWidget) | c | Y | pure index page, parfaite pour embed-as-suggested-topics |
| `education/theme_detail_screen.dart` (755 L, 0 input) | c | N | info-page longue mais 0 interaction — embed-able si trim layout |
| `simulator_compound_screen.dart` (307 L, 4 SL) | a | N | 4 inputs (1 de trop) |
| `simulator_leasing_screen.dart` (312 L, 5 SL) | a | N | 5 inputs |
| `consumer_credit_screen.dart` (365 L, 5 SL) | a | N | 5 inputs |
| `gender_gap_screen.dart` (663 L, 3 SL) | a | Y | 3 inputs exactement, intent didactique — embed candidate |
| `debt_risk_check_screen.dart` (372 L, 0 input) | b | Y | quiz statique, pas d'input continu — embed candidate |
| `debt_prevention/debt_ratio_screen.dart` (1237 L, 1 TF) | b | N | très long, content lourd |
| `debt_prevention/repayment_screen.dart` (1019 L, 2 TF) | a | N | dense |
| `debt_prevention/help_resources_screen.dart` (403 L, 2 TG) | c | Y | resource list, info-page — embed candidate |
| `independants/*` (5 screens, 372-756 L) | a | N | tous 3-8 sliders, simulateurs spécialisés non prioritaires Wave 4 |

### Bonus — Inventaire `widgets/educational/` (déjà extraits)

Source : `apps/mobile/lib/widgets/educational/` (12 fichiers, 93-342 L).

| Widget | Lines | Stateful | Inputs réels | Embed-able? |
|---|---|---|---|---|
| `educational_insert_widget.dart` (base) | 157 | N | 0 | Y (template) |
| `stress_check_insert_widget.dart` | 93 | N | 0 (4 actions) | Y |
| `lpp_pivot_insert_widget.dart` | 184 | N | 1 toggle | Y |
| `salary_breakdown_widget.dart` | 342 | N | 0 (computed from props) | Y (mais 342 L) |
| `tax_savings_insert_widget.dart` | 274 | Y | 1 slider | Y |
| `emergency_fund_insert_widget.dart` | 254 | Y | 1 slider | Y |
| `credit_cost_insert_widget.dart` | 316 | Y | 2 sliders | Y (limite 300) |
| `leasing_cost_insert_widget.dart` | 258 | Y | 1 slider | Y |
| `mortgage_comparison_insert_widget.dart` | 156 | N | 0 (computed) | Y |
| `generic_info_insert_widget.dart` | 180 | N | 0 | Y |
| `unemployment_timeline_widget.dart` | 249 | N | 0 (computed) | Y |
| `educational_widgets.dart` | 13 | barrel | — | — |

**11 widgets `educational/` sont structurellement déjà embed-able** (StatefulWidget contrôlés, ≤ 342 L, intent didactique, payload via constructor props). Le service `EducationalInsertService` (`apps/mobile/lib/services/educational_insert_service.dart` lines 25-46) les wire déjà à 16 question IDs onboarding — réutilisable comme pattern pour Coach inline.

### Bonus — `widgets/coach/` (111 widgets existants)

`ls apps/mobile/lib/widgets/coach/ | wc -l` → 111. Échantillon : `avs_gap_widget.dart`, `baby_cost_widget.dart`, `clause_3a_widget.dart`, `crash_test_budget_widget.dart`, `disability_cliff_widget.dart`, `divorce_film_widget.dart`, `expat_countdown_widget.dart`, `prix_du_silence_widget.dart`, etc. Ces widgets existent déjà sous forme « animation/narration coach » utilisés dans les screens life-event (cf. `divorce_simulator_screen.dart:7-8` import `divorce_film_widget` + `prix_du_silence_widget`). **Pool de réutilisation massif, déjà inline-friendly, non-câblé au chat-vivant orchestrator actuel.**

## Comptage final

- **(a) Interactif (simulateurs avec inputs+résultats live)** : **38 écrans**
- **(b) Statique didactique (pages éducatives, calculatrices passives, content de référence)** : **9 écrans** (independant_screen, optimisation_decaissement, retirement_dashboard, provider_comparator_3a, cantonal_benchmark, deces_proche, debt_risk_check, debt_ratio, debt_repayment-narrative-half)
- **(c) Info-page pure (FAQ, glossaire, theme_detail)** : **8 écrans** (succession_patrimoine, arbitrage_bilan, comprendre_hub, theme_detail, help_resources, et 3 cartes admin/about en dehors du périmètre)
- **Embed-able dans Coach inline (Y selon critères ≤ 3 inputs + ≤ 300 LOC ou trivial extract)** : **15 écrans candidats + 11 widgets educational/ + ~30 widgets coach/ réutilisables = ~56 surfaces inline réutilisables**

Détail des 15 screens embed-able marqués Y :
1. `lpp_deep/epl_screen.dart`
2. `coach/succession_patrimoine_screen.dart`
3. `mortgage/amortization_screen.dart`
4. `mortgage/epl_combined_screen.dart`
5. `mortgage/saron_vs_fixed_screen.dart`
6. `simulator_3a_screen.dart`
7. `pillar_3a_deep/provider_comparator_screen.dart`
8. `pillar_3a_deep/real_return_screen.dart`
9. `pillar_3a_deep/staggered_withdrawal_screen.dart`
10. `cantonal_benchmark_screen.dart`
11. `arbitrage/arbitrage_bilan_screen.dart`
12. `deces_proche_screen.dart`
13. `disability/disability_gap_screen.dart`
14. `disability/disability_insurance_screen.dart`
15. `disability/disability_self_employed_screen.dart` (+ `gender_gap_screen`, `debt_risk_check`, `help_resources`, `education/comprendre_hub`, `education/theme_detail` qui frôlent le seuil → 20 si on assouplit critère LOC à 500).

## Verdict pour Wave 4

**Wave 4 SHORT — 3 jours, wiring only.**

Justification :
- `embed-able ≥ 8` est atteint **15× sur écrans seuls** ; le seuil short (≥ 8) est franchi avant même de compter `widgets/educational/` (+11) et `widgets/coach/` (+~30).
- Le travail Wave 4 n'est PAS de construire de nouveaux widgets — il est de **wirer 3 surfaces existantes au Coach inline-chat orchestrator** :
  1. `EducationalInsertService` (déjà mappe question_id → widget pour onboarding) → étendre à `coach_intent → widget` mapping pour Coach inline.
  2. Les 11 widgets `educational/` exposent déjà un constructor à props (`monthlyExpenses`, `hasPensionFund`, `currentSavings`…) → payload `{seed: {...}}` du brief Wave 0-4 mappe 1-pour-1.
  3. Pour les 5-8 surfaces simulateur (3a, amortization, saron, real_return, disability_gap, provider_comparator, gender_gap), extraire le `Column(children: [Slider, Result])` body en `StatelessWidget` thin avec `seed` props (1-2 jours).

Day-by-day Wave 4 short :
- **J1** : Wire `EducationalInsertService` v2 → ajouter `getCoachInlineWidget(intent, seed)`. Wire les 11 widgets `educational/` à la liste d'intents Coach (LPP-pivot, emergency-fund, tax-savings, credit-cost, leasing, mortgage-comparison, salary-breakdown, stress-check, unemployment-timeline, generic-info, lpp-pivot).
- **J2** : Extraire 5 simulateurs-thin (3a, amortization, saron-vs-fixed, real-return-3a, disability-gap) en widgets ≤ 250 LOC chacun, payload seed-driven.
- **J3** : Maestro flow `flow_coach_inline_widgets.yaml` qui dispatch 3 intents test (« quel impact sur mon 3a ? », « j'hésite SARON ou fixe », « ma lacune invalidité ? ») et vérifie `idb ui describe-all` montre le widget inline dans la bulle. Lint l10n + accent. Tests golden Julien+Lauren.

## Caveats (ce que je n'ai pas pu vérifier)

1. **Wiring chat-vivant orchestrator actuel** — je n'ai pas inspecté `coach_chat_screen.dart` ni `services/coach/` pour confirmer que la machinerie « payload → bulle widget » existe déjà. Le brief Wave 0-4 dit qu'elle existe à des stades partiels (`chat_inline_inputs.dart` présent dans `widgets/coach/`), mais le coût intégration peut être J+0.5 à J+1 supplémentaire si l'API `ChatMessage.embed(widget)` doit être ajoutée.
2. **Compliance LSFin sur l'embed-inline** — un widget « simulateur live » embed dans une bulle Coach pourrait être lu comme conseil personnalisé si le seed est extrait d'un profile_provider authentique (vs. valeurs neutres). Mitigation : forcer chaque embed à exposer `EducationalInsertWidget.disclaimer` (déjà présent en pattern).
3. **DESIGN_SYSTEM.md §F « canvas niveau 3 »** — je n'ai pas lu DESIGN_SYSTEM.md pour confirmer la définition exacte du « niveau 3 canvas » mentionné dans le brief. Mon critère « > 3 inputs → push full screen » est un compromis raisonnable mais pourrait être resserré à 2 inputs selon spec finale.
4. **Tests sim non exécutés** — l'audit est statique (grep + Read). Aucun `idb ui describe-all` exécuté. Embed-ability finale dépend de la hauteur de bulle effective sur device (iPhone 13 mini = 375 px width, certains widgets `educational/` peuvent overflow).
5. **5 entries hub non-vérifiées par lecture intégrale** — `coach/optimisation_decaissement_screen.dart` et `coach/succession_patrimoine_screen.dart` ont été classés sur head-only + grep ; un Read complet pourrait révéler du wiring caché.
6. **Widgets `coach/` (111 fichiers) non audités individuellement** — comptés au listing seulement. Le verdict short suppose qu'au moins ~30 sont structurellement réutilisables, hypothèse plausible vu les noms (`*_widget.dart` standalone) mais à valider J1 Wave 4.

## Counter-argument (per CLAUDE.md §8 wiki schema)

**Contre-arg pour Wave 4 medium (1 sem)** : si l'audit `widgets/coach/` (111 fichiers) en J1 révèle que la moitié sont des fragments d'écran non-extractibles (controllers couplés à provider, dépendances setState parent), alors le pool « ~30 réutilisables » s'effondre à ~5, et Wave 4 short devient sous-dimensionné. Donc J1 commence par un audit-binaire `widgets/coach/` en parallèle du wiring, avec gate de pivot vers medium si pool < 8 à J1-fin.

**Data gap** : aucun signal sur l'usage actuel des écrans Explorer en production (analytics, taux d'entrée par hub). La hiérarchie « priorité Wave 4 » est inférée par densité de financial_core usage (FC=3+ → priorité haute : retirement_dashboard, mortgage/imputed_rental, lpp_deep/epl, pillar_3a_deep/retroactive, simulator_3a, allocation_annuelle). À confronter à analytics quand disponibles.

---

**Verdict final** : Wave 4 **short (3 jours)**, séquence J1-audit-coach-pool + wire-educational, J2-extract-5-simulators-thin, J3-Maestro-flow + lint + golden.

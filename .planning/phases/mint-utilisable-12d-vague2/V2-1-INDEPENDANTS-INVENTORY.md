---
description: "Inventaire des calculs locaux du cluster 12D V2-1 (Indépendants) — drainés / validés / documentés — + écarts chiffrés, findings cross-layer (Q1 dividende 50→70 %, Q2 impôt sur le bénéfice) et dette résiduelle (#31 + 4 écrans). Sortie de la 1re unité (PR dividende D2+D10)."
---

# Cluster 12D V2-1 — Indépendants : inventaire des calculs locaux

TLDR : le domaine indépendant a un **étalon backend complet**
(`services/backend/app/services/independants/*.py`) que le mobile **miroite en
local** (`independants_service.dart` + `segments_service.dart`) SANS aucun test
de parité. La 1re unité (PR `fix(independants): cluster 12D V2-1 — drains D2 +
confidence D10`) traite l'écran #37 `dividende_vs_salaire` à fond : durcit les
littéraux nus en constantes sourcées, aligne l'alerte de requalification sur le
backend, pose la 1re **fixture de parité écran↔coach**, et rend l'appareil de
confiance + la bande d'incertitude (D10). Le reste (#31 + 4 écrans + 2 findings
cross-layer) est documenté ici. Ruling swiss-brain : 2026-07-31 (Q1–Q5, sources
ESTV/OFAS ci-dessous).

## Cartographie des deux moteurs mobiles

| Écran (registre) | Service local | Dans `financial_core/` ? | Étalon backend |
|---|---|---|---|
| `dividende_vs_salaire` (#37) | `IndependantsService.calculateDividendeVsSalaire` | non (`lib/services/`) | `independants/dividende_vs_salaire_service.py` |
| `avs_cotisations` | `IndependantsService.calculateAvsCotisations` | non | `independants/avs_cotisations_service.py` |
| `pillar_3a_indep` | `IndependantsService.calculate3aIndependant` | non | `independants/pillar_3a_indep_service.py` |
| `ijm` | `IndependantsService.calculateIjm` | non | `independants/ijm_service.py` |
| `lpp_volontaire` | `IndependantsService.calculateLppVolontaire` | non | `independants/lpp_volontaire_service.py` |
| `independant_screen` (#31) | `IndependantService.analyse` (`segments_service.dart`) + ratios inline | non | `independant_service.py` |

Nature D2 : ce sont des sorties **L1 chiffrer** (single-number déterministe,
offline). Elles vivent hors `financial_core/` → violation littérale de
`docs/calculator-graph.md`. MAIS le vrai risque n'est pas l'emplacement du
fichier : c'est qu'aucun test ne garantit la **parité écran↔coach** (le coach
utilise l'étalon backend). Toute dérive silencieuse = un utilisateur voit deux
chiffres différents. C'est ce que la fixture de parité ferme.

## Inventaire des formules — VERDICT (swiss-brain 2026-07-31)

### `dividende_vs_salaire` (#37) — TRAITÉ dans cette PR

| Formule / littéral | Verdict | Action |
|---|---|---|
| Charges sociales salaire `0.125` (12.5 %) | VALIDÉ (parité backend `CHARGES_SOCIALES_TOTALES`) | promu en const sourcée `_chargesSocialesTotales` |
| Imposition partielle dividende `0.50` | **OUTDATED (fédéral)** — voir Q1 cross-layer | promu en const `_tauxImpositionDividendePartielle` (documenté = minimum cantonal, PAS fédéral) ; point d'estimation gardé (parité backend) ; **borne fédérale 70 % ajoutée** pour la bande D10 |
| Seuil requalification `< 60` | VALIDÉ (proxy pratique) | promu en const `_seuilRequalificationPct` |
| Plancher salaire raisonnable `60'000` | **MANQUANT** (mobile sous-alertait) — Q4 | **ajouté** (converge vers backend) |
| Impôt sur le bénéfice (société) | **OMIS = défaut de lucidité** — Q2 cross-layer | caveat D10 obligatoire + confiance basse (40 %) qui NOMME l'exclusion |
| AVS barème (`_avsBareme`) | CORRECT 2025/2026 (byte-identique backend) | inchangé (couvert par la fixture de parité) |

Écarts chiffrés (avant → après), inputs par défaut de l'écran
(bénéfice 200'000, part 70 %, taux 30 %) :
- Économie (point) : **inchangée** (CHF 55'000, parité backend préservée).
- **NOUVEAU** : bande d'incertitude rendue `CHF 43'000 → CHF 55'000` (borne
  fédérale 70 % → minimum cantonal 50 %) + caveat « exclut l'impôt sur le
  bénéfice → l'économie réelle est plus faible ».
- **NOUVEAU** : alerte de requalification déclenchée AUSSI si salaire proposé
  < 60'000 (avant : uniquement si part < 60 %). Ex. bénéfice 80'000 / part
  65 % (salaire 52'000) : avant = pas d'alerte ; après = alerte.

### AVS cotisations indépendant — VALIDÉ (footnote D11)

Barème dégressif RAVS art. 21, plein 10.0 % dès 60'500 (AVS 8.1 + AI 1.4 +
APG 0.5, **pas** 10.6 %), plancher fixe 530 sous 10'100 (LAVS art. 8 al. 2).
CORRECT 2025 = 2026. **Dette D11 à suivre** : si l'écran `avs_cotisations`
présente 10.0 % comme la charge cash TOTALE, ajouter une note « hors frais de
gestion de caisse » (OAVS art. 69, jusqu'à ~5 % de la cotisation).

### `pillar_3a_indep`, `ijm`, `lpp_volontaire` — À AUDITER (unités suivantes)

- 3a indépendant : plafond `min(revenu × 20 %, 36'288)` / `7'258` avec LPP —
  valeurs OFAS 2026 (constantes centralisées). À couvrir par parité + confiance.
- IJM : `_ijmRates` = **prix d'assurance marché illustratifs**, pas un étalon
  légal → à dater/sourcer (D11) + disclaimer « indicatif, dépend de l'assureur ».
- LPP volontaire : délègue déjà partiellement (`AvsCalculator.annualRente`,
  `LppCalculator.adjustedConversionRate`, `getLppBonificationRate`) — bon patron.

### `independant_screen` (#31) — DOCUMENTÉ (unité suivante, refonte séparée)

Non traité dans cette PR : #31 utilise un **service différent**
(`IndependantService.analyse`) et le smoke `flow_tierb_travail_independant`
l'exerce → refonte séparée pour ne pas mettre le gate de non-régression en
risque. Calculs locaux à drainer/sourcer :

| Site | Littéral nu | Nature |
|---|---|---|
| `_buildMintIndependantSection` | `taxes = net × 0.22`, `social × 0.10`, `businessExp × 0.15`, `unpaidDays × 0.05` | ratios illustratifs (widget TrueHourlyRate) SANS source |
| idem | `annualTaxSavings: net × 0.08`, `taxRate: 0.25`, `annualDeduction: 20000`, `3600` | déductions fiscales inline SANS source |
| `_buildJourJSection` | `kLaaIndepMensuel = 150.0`, `kIjmIndepMensuel = 100.0` | primes mensuelles en dur |
| `DoublePriceFreedom` | `net × 0.020` / `× 0.040` (frais pro) | ratios inline |

Action recommandée : sourcer chaque ratio (constante + citation) OU dériver des
calculateurs réels ; ajouter confiance D10 ; couvrir par widget test. À faire
avec le smoke #31 comme gate de non-régression.

## Findings cross-layer (NE PAS diverger le mobile seul)

Ces deux corrections touchent la **formule partagée** (mobile == backend
actuellement). Les changer côté mobile seul CASSERAIT la parité L1/L2. Elles
nécessitent une unité coordonnée mobile + backend (owner `mint-backend` +
sign-off swiss-brain), pas un patch mobile.

1. **Q1 — imposition partielle du dividende 50 % → 70 % (fédéral).** Depuis RFFA
   (en vigueur 1.1.2020), LIFD art. 20 al. 1bis impose les participations
   qualifiantes (≥10 %, fortune privée) à **70 %** au fédéral ; LHID art. 7 al. 1
   impose un **minimum cantonal de 50 %** (cantons 50–70 %). Le « 50 % » du
   modèle n'est défendable que comme proxy du minimum cantonal, jamais comme
   taux fédéral. Direction du biais : sous-estime l'impôt → surévalue l'économie.
   Le vrai fix a besoin du **canton** (le taux est canton-dépendant).
2. **Q2 — impôt sur le bénéfice de la société omis.** La voie dividende paie
   l'impôt sur le bénéfice (~11.85 % ZG → ~20.5 % BE effectif) AVANT distribution,
   puis l'impôt partiel personnel (double imposition économique). L'omettre
   surévalue systématiquement l'économie. Fix minimal honnête : intégrer un taux
   d'impôt sur le bénéfice représentatif éditable (défaut ~15 %, sélectionnable
   par canton) OU reframe en scénario-bande. Dans cette PR mobile-only : caveat
   + bande D10 (ship) ; inclusion du taux = finding coordonné.

## Sources (swiss-brain ruling 2026-07-31)

- LIFD art. 20 al. 1bis (imposition partielle 70 % fédéral, RFFA 1.1.2020) ;
  LHID art. 7 al. 1 (min. cantonal 50 %).
- LAVS art. 8 + RAVS art. 21 (barème dégressif indépendant, 10.0 % plein, 530
  plancher) — Mémento AVS 2.02, valeurs 2025 = 2026.
- Requalification : ATF 134 V 297, ATF 145 V 50, Directives OFAS sur le salaire
  déterminant (DSD).
- LSFin art. 7-10 (no-promise) : « optimal » banni ; « adapté / indicatif » OK.

## Preuve (0-trust)

- Tests : `independants_service_test.dart` (+6 cas Q4/D10), `independants_backend_parity_test.dart` (NOUVEAU, 8 goldens de parité), `dividende_vs_salaire_screen_test.dart` (NOUVEAU, 3 widget tests D10) — 63/63 verts.
- `flutter analyze` : clean. `arb_parity` : 6 langues OK (7230 clés). `no_hardcoded_fr --added-only`, `accent_lint --added-only`, `banned_terms_arb`, `journey_os_check` : verts.
- Non-régression smoke : `flow_tierb_travail_independant` exerce `/segments/independant` via `IndependantService.analyse` + `social_insurance.dart` — AUCUN des deux n'est modifié par ce diff → smoke inchangé par construction.

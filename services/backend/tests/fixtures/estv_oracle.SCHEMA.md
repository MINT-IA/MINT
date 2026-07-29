# estv_oracle_2025.jsonl — Schema & Lifecycle (oracle d'INTERPOLATION)

> Réveillé le 2026-07-28 (audit constants, finding panel actuariel #4 « oracle ESTV dormant »).
> Origine : Phase 92.5 CALC-03 (`.planning/phases/92.5-mvp-calc-rigor-foundations/`).
> Capture : `services/backend/tests/scripts/capture_estv_oracle.py` (cadence annuelle, hors CI).
> Test consommateur (le contrat) : `services/backend/tests/test_estv_oracle.py`.

## Ce que l'oracle valide : l'INTERPOLATION, pas la calibration

`CANTONAL_COMMUNAL_TAX_CHF` (revenu) et `CANTONAL_CAPITAL_TAX_CHF` (capital,
célibataire) — dans `app/services/fiscal/cantonal_comparator.py` — sont calibrées
EXACTEMENT sur des points de grille ESTV (revenu : 40/70/100/150/250k ; capital :
100/250/500/750k/1M). Re-capturer ces nœuds ne teste que la reproductibilité,
déjà prouvée. **L'utilisateur, lui, voit une valeur interpolée ENTRE les nœuds** —
c'est là que vit l'erreur, et c'est ce que cet oracle mesure.

La fixture capture donc des points **hors des nœuds**, auprès de l'API officielle
ESTV, pour les 26 chefs-lieux :

| Moteur | Opération ESTV | Points hors-nœud (par canton) | Comparaison |
| --- | --- | --- | --- |
| revenu | `API_calculateSimpleTaxes` | 55k, 85k, 125k, **175k, 225k** (zone lâche 150-250k), 300k (extrap. haute) | composante cantonale+communale (`estimate_income_tax_parts`) + IFD exact séparé |
| capital (célibataire) | `API_calculateManyCapitalTaxes` | 175k, 350k, 620k, 880k | total (`estimate_capital_withdrawal_tax`, `is_married=False`) |

Total : **156 revenu + 104 capital = 260 vecteurs**. (Le capital MARIÉ est hors
périmètre — il vit sur une branche non fusionnée ; ne pas le coupler ici.)

### Points volontairement EXCLUS (documentés comme findings, pas comme faux verts)

Le revenu < 40k (extrapolation linéaire depuis (0,0)) surestime l'impôt cantonal
jusqu'à **+59.8 %** (GE @ 30k : MINT 2780 vs ESTV 1739), car le vrai barème a un
seuil non imposable. C'est une **limite de modèle**, pas de l'interpolation : un
vecteur « qui passe » avec une tolérance de 60 % serait du théâtre de test. Le
finding est documenté (retour de session / commit) ; il n'entre pas dans la
fixture de détection de dérive.

## Porte d'intégrité du pipeline (0-trust)

AVANT d'émettre le moindre point hors-nœud pour un canton, `capture_estv_oracle.py`
**reproduit les 5 nœuds committés de ce canton** (même opération, même profil) et
exige une correspondance à ±1 CHF sur `cantonal_communal`. Reproduire l'étalon
committé au CHF près prouve que le profil / l'année / l'endpoint sont exacts — la
même méthode que la collecte capital marié (`consolidated.json`). Un canton qui ne
reproduit pas ses nœuds est ABANDONNÉ (aucune donnée inventée). Le 2026-07-28,
**26/26 cantons ont passé la porte** pour les deux moteurs.

## Champs (un objet JSON par ligne JSONL)

| Champ | Type | Description |
| --- | --- | --- |
| `id` | `string` | `<engine>__<canton>__<input_chf>`, ex. `income__VS__175000`. IDs de paramétrage pytest + lint de fraîcheur. |
| `engine` | `string` | `income` \| `capital`. Choisit la fonction MINT et l'axe de comparaison. |
| `canton` | `string` | Code canton 2 lettres (chef-lieu). |
| `marital_status` | `string` | Toujours `single` (célibataire) dans cette fixture. |
| `input_chf` | `int` | Revenu imposable (income) ou montant du retrait capital (capital). **Hors-nœud** par construction. |
| `segment` | `string` | Intervalle de grille contenant le point (ex. `150k-250k`, `250k-500k`, `extrap-high(>250k)`). Regroupement « par région ». |
| `off_node` | `bool` | `true` (documentaire — la fixture ne contient que des points hors-nœud). |
| `tax_year` | `int` | Année fiscale ESTV interrogée. `2026` partout SAUF revenu SG/TI = `2025` (l'ESTV n'avait pas publié leur 2026 ; la table committée est aussi 2025). |
| `expected_cantonal_communal_chf` | `float` | Impôt cantonal+communal ESTV. Revenu : `IncomeTaxCanton+IncomeTaxCity+PersonalTax+IncomeTaxChurch`. Capital : `TaxCanton+TaxCity+TaxChurch`. |
| `expected_ifd_chf` | `float` | Impôt fédéral direct ESTV (`IncomeTaxFed` / `TaxFed`). |
| `expected_total_chf` | `float` | `expected_cantonal_communal_chf + expected_ifd_chf`. Axe de comparaison capital. |
| `measured_rel_err` | `float` | Erreur d'interpolation mesurée à la collecte (income : cantonale ; capital : total). Stockée pour transparence — c'est la donnée que `tol_rel` borne. |
| `measured_rel_err_cantonal` | `float` | (capital seulement) erreur d'interpolation de la composante cantonale isolée, pour le reporting. |
| `tol_rel` | `float` | Bande de dérive assertée. Fixée **juste au-dessus** de `measured_rel_err` (`max(2%, mesuré×1.2 + 0.3pt)`, arrondi 0.5 %). Tight (2 %) pour les points bien interpolés ; bande documentée là où le barème est fortement courbé. JAMAIS une tolérance globale silencieuse. |
| `tol_note` | `string` | Non vide dès que `measured_rel_err > 2 %` : explique la région/courbure. Chaque point > 2 % est un finding documenté. |
| `expected_capture_date` | `string` | ISO `YYYY-MM-DD`. Lu par `tools/checks/estv_oracle_freshness.py` (WARN à 14 mois). |
| `source_url` | `string` | URL du simulateur ESTV. |
| `source_operation` | `string` | `API_calculateSimpleTaxes` \| `API_calculateManyCapitalTaxes`. |

### Exemple de ligne (BL capital 350k — le pire écart d'interpolation capital)

```json
{"id": "capital__BL__350000", "engine": "capital", "canton": "BL", "marital_status": "single", "input_chf": 350000, "segment": "250k-500k", "off_node": true, "tax_year": 2026, "expected_cantonal_communal_chf": 11550.0, "expected_ifd_chf": 6541.0, "expected_total_chf": 18091.0, "measured_rel_err": 0.14591, "measured_rel_err_cantonal": 0.22854, "tol_rel": 0.18, "tol_note": "Erreur d'interpolation totale 14.59% > 2% (composante cantonale 22.85%) ... Finding oracle documente.", "expected_capture_date": "2026-07-28", "source_url": "https://swisstaxcalculator.estv.admin.ch/#/calculator/income-wealth-tax", "source_operation": "API_calculateManyCapitalTaxes"}
```

## Assertions du test (`test_mint_matches_estv`, un test par vecteur)

* **revenu** : `estimate_income_tax_parts(input, canton)` → la composante
  cantonale+communale doit être dans `tol_rel` de `expected_cantonal_communal_chf`
  (c'est la SEULE partie interpolée). L'IFD (exact) est vérifié séparément :
  ±1.5 CHF pour 2026, ±12 CHF pour SG/TI 2025 (décalage d'indexation fédérale
  documenté, le barème fédéral MINT étant 2026).
* **capital** : `estimate_capital_withdrawal_tax(input, canton, is_married=False)`
  → le total doit être dans `tol_rel` de `expected_total_chf`. (Pas de fonction
  « parts » capital ; comparer le total évite de refactorer
  `estimate_capital_withdrawal_tax`, que la branche capital marié non fusionnée
  modifie.)

Aucun skip quand la fixture est peuplée. Skip PROPRE uniquement si la fixture est
vidée (garde `test_oracle_fixture_present_or_skip`, 0-trust §9).

## Cycle de vie

Toute modification de valeurs ESTV (`expected_*`) ou de `expected_capture_date`
passe par un commit dédié préfixé **`fix(estv-oracle):`** — l'audit distingue
ainsi une re-capture d'une évolution de feature. Re-capture attendue au cycle de
publication ESTV (nov.-déc.) ou si le test se met à FAIL (présomption : constante
fédérale/cantonale périmée dans le code, pas vecteur périmé).

`capture_estv_oracle.py` réécrit le JSONL de façon idempotente ; il ré-exécute la
porte d'intégrité des nœuds à chaque run.

## Contrat de fraîcheur (14 mois)

`tools/checks/estv_oracle_freshness.py` émet `[freshness] STALE <id>` (stderr,
WARN, exit 0) dès qu'un `expected_capture_date` dépasse ~14 mois. `--strict`
(non câblé en CI) fait échouer. Sur la fixture VIDE le lint était no-op — il est
maintenant actif (260 dates lues).

## Note 0-trust (CLAUDE.md §9)

Chaque valeur `expected_*` est une sortie live de l'API ESTV du 2026-07-28,
adossée à la reproduction ±1 CHF des 130 nœuds committés. Rien n'est estimé « de
tête ». Les points où l'erreur d'interpolation dépasse 2 % sont documentés
(`tol_note` + retour de session), jamais masqués par une tolérance globale.

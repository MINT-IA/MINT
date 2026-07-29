# tests/scripts — utilitaires de capture manuelle (oracle ESTV)

> Réveillé le 2026-07-28 (finding panel actuariel #4 « oracle ESTV dormant »).
> Origine : Phase 92.5 CALC-03. Schéma : `../fixtures/estv_oracle.SCHEMA.md`.

## Objectif

Scripts hors-CI qui maintiennent la **fixture oracle** consommée par
`services/backend/tests/test_estv_oracle.py`. Exécutés par Julien à cadence lente
(annuelle) ; l'artefact JSONL résultant est committé.

## `capture_estv_oracle.py` — capture des points HORS-NŒUD

Collecte, pour les 26 chefs-lieux, des points d'impôt situés ENTRE les nœuds des
tables committées (là où l'utilisateur voit une valeur interpolée), auprès de
l'API JSON officielle du simulateur ESTV :

- **revenu** — `API_calculateSimpleTaxes`, points 55k / 85k / 125k / 175k / 225k / 300k
  (revenu imposable). Comparaison sur la composante cantonale+communale.
- **capital (célibataire)** — `API_calculateManyCapitalTaxes`, montants 175k / 350k / 620k / 880k.
  Comparaison sur le total.
- 26 cantons → **156 + 104 = 260 vecteurs**.

Endpoint : `POST https://swisstaxcalculator.estv.admin.ch/delegate/ost-integration/v1/lg-proxy/operation/c3b67379_ESTV/<opération>`.
C'est la MÊME API que le SPA officiel et que la calibration des tables committées.
**Aucune dépendance Playwright** : urllib (stdlib) suffit (l'API exige POST ;
WebFetch, GET-only, ne marche pas). L'ancien scaffold Playwright `[oracle]` est
supprimé.

### Porte d'intégrité 0-trust (pourquoi ces valeurs font foi)

Pour CHAQUE canton, AVANT d'émettre le moindre point hors-nœud, le script
reproduit les **5 nœuds committés** (`CANTONAL_COMMUNAL_TAX_CHF` /
`CANTONAL_CAPITAL_TAX_CHF`) à ±1 CHF. Reproduire l'étalon committé au CHF près
prouve que profil + année + endpoint sont exacts. Un canton hors porte est
ABANDONNÉ — **aucune donnée inventée**. Collecte 2026-07-28 : **26/26 cantons
dans la porte**.

### Usage

```bash
cd services/backend
python3 -m tests.scripts.capture_estv_oracle \
  --output tests/fixtures/estv_oracle_2025.jsonl
# ou, pour capturer + rapport SANS écrire :
python3 -m tests.scripts.capture_estv_oracle --dry-run
```

Durée : ~5 min (546 requêtes réseau : 260 nœuds de garde + 260 hors-nœud +
marges). `--sleep` règle la politesse (défaut 0.3 s).

### Cadence

**Nov.-déc. chaque année** (publication des tarifs ESTV pour l'année suivante),
ou si `test_estv_oracle.py` se met à FAIL — présomption : constante
fédérale/cantonale périmée dans le code, PAS vecteur périmé. Le lint de fraîcheur
(`tools/checks/estv_oracle_freshness.py`) émet un WARN à 14 mois.

### Année fiscale

2026 partout, SAUF le **revenu SG et TI = 2025** (l'ESTV n'avait pas publié leur
barème 2026 ; la table committée est aussi 2025). Le capital est 2026 partout.
Conséquence : l'IFD revenu SG/TI (barème 2025 ESTV) diffère du FEDERAL_BRACKETS
2026 de MINT jusqu'à ~10.56 CHF — décalage d'indexation fédérale documenté,
absorbé par une tolérance IFD 2025 dédiée dans le test.

### Modes d'échec

- **API ESTV indisponible** — le script signale l'échec par canton (`__error__`)
  et sort en code 2 sans rien écrire d'inventé. Ré-essayer plus tard (la cadence
  annuelle a du mou ; le lint reste WARN-only).
- **Canton hors porte** (nœuds non reproduits) — le canton est listé et exclu ;
  soit l'ESTV a changé son barème (re-calibrer la table committée), soit le
  TaxLocationID a bougé.

### Préfixe de commit

```
fix(estv-oracle): re-capture <cycle> ESTV (260 vecteurs hors-noeud)
```

Un préfixe dédié distingue une re-capture d'une évolution de feature.

### Note 0-trust (CLAUDE.md §9)

La fixture n'est peuplée qu'après une vraie session de capture. Chaque `expected_*`
est une sortie live de l'API ESTV, adossée à la reproduction ±1 CHF des 130 nœuds
committés. Les points où l'erreur d'interpolation dépasse 2 % sont documentés
(`tol_note`), jamais masqués par une tolérance globale.

## G6 calc-correctness gate — divergence détectée / divergence detected

**Phase 92.5 / CALC-04** — `.github/workflows/calc-rigor.yml` a échoué sur cette PR parce que le **moteur de calcul Mobile** est la source de vérité, et tes changements ont fait diverger les **helpers Python du backend** au-delà de la tolérance (CONTEXT 92.5 D-06, D-14, D-18).

> **Présomption asymétrique** (CONTEXT 92.5 specifics line 169) — quand le différentiel diverge, la présomption par défaut est que **le Python backend a dérivé, PAS le Mobile**. ADR-20260223-unified-financial-engine.md établit `apps/mobile/lib/services/financial_core/` comme source canonique. Corrige le côté Backend en premier ; n'édite Dart que si tu as la preuve que le Mobile est faux.

> **Asymmetric presumption (English)** — when differential disagrees, the default presumption is that **Backend Python has drift, NOT Mobile**. ADR-20260223 establishes `apps/mobile/lib/services/financial_core/` as canonical. Fix the Backend side first ; only edit Dart if you have evidence Mobile is wrong.

### Axe de divergence / divergence axis

| Axis | Tolerance (D-06) | Where it's checked |
|---|---|---|
| `capital_withdrawal_tax` | ±5 CHF | `services/backend/tests/test_calc_diff_harness.py::test_axis_within_tolerance[capital_withdrawal_tax]` |
| `lpp_bonification_rate` | ±0.05 | `test_axis_within_tolerance[lpp_bonification_rate]` |
| `avs_rente_from_ramd` | ±1 CHF | `test_axis_within_tolerance[avs_rente_from_ramd]` |
| `ai_rente_monthly` | ±1 CHF | `test_axis_within_tolerance[ai_rente_monthly]` |
| `estv_oracle` (real-world) | ±5 CHF | `services/backend/tests/test_estv_oracle.py` |

### Première fixture en échec / first failing fixture

```
fixture_id: ${FIXTURE_ID}
axis:       ${AXIS}
Mobile (canonical): ${MOBILE_VALUE}
Backend (under test): ${BACKEND_VALUE}
divergence: |${MOBILE_VALUE} − ${BACKEND_VALUE}| > tolerance
```

(Les variables `${...}` seront remplies par une étape `envsubst` dans le workflow lors d'un raffinage ultérieur — D-claude-discretion #4. Sur la première divergence réelle, le commentaire posté contient le template tel quel.)

### Reproduction locale / how to repro locally

```bash
# Build Dart binary
cd apps/mobile && dart compile exe tools/calc_harness/main.dart -o /tmp/calc_harness_dart

# Run differential harness
cd ../../services/backend
CALC_HARNESS_BIN=/tmp/calc_harness_dart python3 -m pytest tests/test_calc_diff_harness.py -v

# Run property invariants
python3 -m pytest tests/test_property_invariants.py -v

# Run ESTV oracle (skipped if fixture empty)
python3 -m pytest tests/test_estv_oracle.py -v
```

### Causes probables / likely root causes

1. **Constante Backend obsolète** dans `services/backend/app/constants/social_insurance.py` (le plus fréquent — mises à jour fédérales/cantonales annuelles).
2. **Décote couple par canton** — les deux côtés utilisent la table par canton (Dart `marriedCapitalTaxDiscountFor()` ⟷ Python `married_capital_tax_discount_for()`, miroir depuis beads -axj/-ku6). Si une fixture `couple_dual_earner` diverge, vérifier que les DEUX tables (Dart `marriedCapitalTaxDiscountByCanton` / Python `MARRIED_CAPITAL_TAX_DISCOUNT_BY_CANTON`) sont restées identiques — toute mise à jour doit toucher les deux.
3. **Dérive dans `app/services/`** appelant les helpers avec de mauvais arguments — re-grep les callers de la fonction défaillante par mémoire `feedback_pre_push_checklist`.

### Garde-fous doctrine (à NE PAS contourner)

- Ne pas ajouter une classe Python qui ré-implémente `AvsCalculator` / `LppCalculator` / `RetirementTaxCalculator` (CLAUDE.md §4 NEVER #3, ADR-20260223). Le port Backend complet est hors-scope pour cette phase ; reporté au backlog 999.4 / Phase 92.6.
- Ne pas relâcher les constantes de tolérance dans `tests/test_calc_diff_harness.py`. Elles sont verrouillées par CONTEXT D-06 et le critère de succès #1 de ROADMAP §92.5.

— Généré par `.github/workflows/calc-rigor.yml` (CALC-04, CONTEXT 92.5 D-20)

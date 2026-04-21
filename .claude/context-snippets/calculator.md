## 🧮 Financial calculator reminder (CLAUDE.md triplets #3 #7 #9)

`calcul` / `simulator` / `projection` / `rente` / `capital` / `tax` détecté. Critique :

- **NEVER réinventer**. Utilise `apps/mobile/lib/services/financial_core/` :
  - `AvsCalculator` (rente, couple, RAMD), `LppCalculator.projectToRetirement()`
  - `TaxCalculator.capitalWithdrawalTax()` (LIFD art. 38), `progressiveTax()`
  - `ConfidenceScorer.EnhancedConfidence` — 4-axis **MANDATORY** sur toute projection.
  - `arbitrage_engine`, `monte_carlo_service`, `tornado_sensitivity_service`.
- **Backend miroir** : `services/backend/app/services/` = source of truth des constantes.
- **NEVER double-tax** : capital (LIFD art. 38) ≠ SWR (consommation, pas revenu).
- **Archetype obligatoire** : 8 types (swiss_native, expat_eu/us FATCA, cross_border, indep_with/no_lpp, returning_swiss).
- **MINT ≠ retirement app** : 18 life events. Framing générique.

Détail : `docs/AGENTS/swiss-brain.md`.

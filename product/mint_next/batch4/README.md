# Batch 4 — architecture canonique avant écrans

Ce batch ne construit aucun écran. Il remplace les suppositions par six registres
lisibles par machine: audience, concepts, décisions, expérience, données/claims et
réutilisation legacy.

`ONE-PAGE.md` et `views/` sont générés; ils ne sont jamais sources de vérité.

```bash
python3 tools/checks/mint_next_batch4_generate_views.py
python3 tools/checks/mint_next_batch4_architecture_guard.py
pytest -q tools/checks/tests/test_mint_next_batch4_architecture_guard.py
```

Le statut reste `draft_unproven` tant que les roasts indépendants et le reçu de
promotion lié au HEAD exact ne sont pas présents.

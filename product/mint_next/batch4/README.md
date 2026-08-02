# Batch 4 — architecture canonique avant écrans

Rôle: `non_authoritative_exact_human_view`.

Les champs structurés de `batch.yaml` et `formula_contracts.yaml` sont les seules
sources canoniques des sémantiques de confiance et gagnent toujours en cas de
désaccord. Ce README est leur vue humaine exacte, vérifiée mécaniquement; il ne
peut ajouter, étendre ou modifier librement aucune règle de confiance.

Ce batch ne construit aucun écran. Il remplace les suppositions par six registres
lisibles par machine: audience, concepts, décisions, expérience, données/claims et
réutilisation legacy.

`ONE-PAGE.md` et `views/` sont générés; ils ne sont jamais sources de vérité.

```bash
python3 tools/checks/mint_next_batch4_generate_views.py
python3 tools/checks/mint_next_batch4_architecture_guard.py
pytest -q tools/checks/tests/test_mint_next_batch4_architecture_guard.py
```

## Frontière de confiance

Les rapports produits dans des contextes agents séparés sont des avis non fiables:
ils peuvent signaler un problème, mais ne prouvent ni identité, ni indépendance,
ni acceptation. La promotion exige des preuves déterministes et, dans un gate
séparé, soit une attestation externe dont identité et provenance sont vérifiées,
soit une revue cross-provider. Cette dernière ajoute uniquement de la diversité;
elle ne prouve aucune identité authentifiée ou indépendance cryptographique.

Le token `independent_Swiss_domain_review_golden_vectors_and_mutation_tests` des
contrats de formule désigne exclusivement un **futur gate d’expert suisse externe
et authentifié**, accompagné de vecteurs golden et de tests de mutation.
Il ne peut jamais désigner un rapport d’agent local ou une revue cross-provider.
Ce gate est actuellement absent et toutes ces formules restent `unimplemented_blocking`.

Le statut reste `draft_unproven` avec un reçu de promotion `null` tant que le gate
externe ou cross-provider séparé, les preuves déterministes et le reçu lié au HEAD
exact ne sont pas présents.

# Évidence — campagne étalon fiscal 2026-07 (coach_advice_turn)

Enregistrée le 2026-07-29 (réconciliation plans, mandat Julien 2026-07-29).

## Ce que la campagne change pour ce journey

La promesse du journey — « quand le coach donne un chiffre, il est courant,
cité et borné » — repose sur les modèles fiscaux backend. La campagne étalon
fiscal 2026-07-25→29 a recalibré cette fondation sur dev :

- ~50 PR mergées (#1024-#1062, plus receipts #1065-#1095), puis vagues
  #1063-#1100 gouvernées par le plan de fusion de #1100 ;
- modèles fiscaux canoniques calibrés ESTV v2 sous
  `services/backend/app/services/fiscal/` (revenu + capital + rente) ;
- un seul taux marginal, dérivé de l'étalon ESTV (#1061) ; lint
  `no_cantonal_rate_table` interdisant toute nouvelle table de taux par
  canton (#1062, câblé lefthook) ;
- provenance documentée des 39 clés fiscales du registre réglementaire
  (`services/backend/tests/test_337_fiscal_provenance.py`).

## Preuve déterministe (exécutée au commit ci-dessous)

Commande :

```
cd services/backend && python3 -m pytest tests/test_fiscal.py tests/test_337_fiscal_provenance.py -q
```

Sortie (queue) :

```
53 passed, 1 warning in 0.31s
```

Commit d'exécution : `1ae9af4fadead2c0fbe193a42de9af6d7179b23f`
(branche `codex/journey-os-cloture-plans`, base `origin/dev`).

## Limite explicite

Preuve unitaire backend, pas une preuve runtime du tour de conseil : la
re-preuve runtime post-fusion des vagues est trackée par l'issue JOS-006
(`bash tools/simulator/journey_os_runtime_replay.sh --set top`).

# Fichiers autorisés — phase remédiation 2026-07

Périmètre autorisé (ajouté à ALLOW dans journey_os_check.py) :
- Docs privacy/légal : PRIVACY.md, LEGAL_RELEASE_CHECK.md, docs/DATA_ACQUISITION_STRATEGY.md
- Gate : tools/checks/no_false_privacy_attestation.py, tools/checks/journey_os_check.py
- Calcul rente-vs-capital : apps/mobile/lib/services/financial_core/arbitrage_engine.dart
  + apps/mobile/test/simulators/rente_vs_capital_test.dart
- Infra : .gitignore
- Cette phase : .planning/phases/remediation-audit-2026-07/**

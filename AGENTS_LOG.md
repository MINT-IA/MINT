# AGENTS_LOG.md — Historique des erreurs (anti-répétition)

Format d’entrée:
- Date:
- Sujet:
- Symptôme:
- Cause racine:
- Fix:
- Test ajouté:
- Doc/règle mise à jour (quel fichier):
- Lien PR/commit:

## Entries

### 2026-01-10 — Anti-Surendettement Feature: Privacy Pitfall Avoided
- **Date:** 2026-01-10
- **Sujet:** Questionnaire Risque d'Endettement (debt_risk)
- **Symptôme:** N/A (prévention)
- **Cause racine:** Risque de stocker des données sensibles (réponses questionnaire, score de risque, flag jeux d'argent)
- **Fix:**
  - Calcul côté client (Dart) uniquement
  - Aucun stockage backend des réponses du questionnaire
  - Documentation explicite dans `SOT.md` et `vision_trust_privacy.md`
  - Disclaimers obligatoires sur tous les écrans sensibles
- **Test ajouté:** `test_rules_engine.py::TestDebtRiskScore` (5 tests)
- **Doc/règle mise à jour:** `SOT.md`, `vision_trust_privacy.md`, `vision_features.md`
- **Lien PR/commit:** N/A (feature initiale)

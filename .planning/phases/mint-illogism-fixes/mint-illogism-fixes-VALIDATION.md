---
phase: mint-illogism-fixes
slug: mint-illogism-fixes
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-11
---

# Phase mint-illogism-fixes — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (mobile) + Maestro 2.5.1 (device flows) + oracles Python (matrice) |
| **Config file** | `apps/mobile/pubspec.yaml` (existing — no Wave 0 install) |
| **Quick run command** | `cd apps/mobile && flutter test test/services/ test/models/` (sites touchés) |
| **Full suite command** | `cd apps/mobile && flutter analyze && flutter test` |
| **Estimated runtime** | quick ~120 s · full ~600 s |

---

## Sampling Rate

- **After every task commit:** Run quick command + l'oracle de reproduction des lignes de matrice fermées par la tâche
- **After every plan wave:** Full suite + lints (`accent_lint_fr`, `validate_arb_parity`, `check_banned_terms`) + sim walkthrough (build workaround `/tmp/mint_build_ios`)
- **Before `/gsd:verify-work`:** Full suite green + flows Maestro `bug__ILLOG01/02` au statut attendu de la vague + matrice mise à jour (lignes fermées citées)
- **Max feedback latency:** 600 s

---

## Per-Task Verification Map

> Rempli par le planner : chaque tâche cite les IDs de findings de la matrice qu'elle ferme
> (ex. `salarie_swiss-2`, `independent_no_lpp-4`, `D5`) — l'oracle de reproduction de la ligne
> est la commande automatisée ; les tests de parité (W1) et les flows Maestro (W3/W5)
> complètent.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| (à remplir par gsd-planner) | | | MATRIX-<finding-id> | — | | parity/oracle/maestro/unit | | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `apps/mobile/test/services/financial_parity_test.dart` — squelette des tests de parité W1 (une quantité = tous chemins d'appel = même valeur)
- [ ] Re-run baseline des oracles de la matrice (état RED documenté avant fix)
- [ ] Flows Maestro `bug__ILLOG01/02` RED confirmés sur build courant (déjà fait 2026-06-11)

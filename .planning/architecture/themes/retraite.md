---
description: "Carte de navigation du thème retraite — 22 routes : 2 câblées (lien cliquable), 17 atteignables seulement par séquence/registre, 3 îles. Verdict : PORTE UNIQUE."
---

# Thème « retraite » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart`, un grep littéral des `context.go/push`, et le `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 2 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 17 | atteignable seulement via le registre / le coach |
| 🔴 île | 3 | aucun chemin détecté |
| **Total** | **22** | **verdict : PORTE UNIQUE** (2/22 = 9 % cliquables) |

## ⚠️ Portes manquantes

Ces routes n'ont **aucun lien cliquable**. Un utilisateur qui explore l'app ne peut pas les atteindre : elles dépendent d'une décision du coach ou d'une séquence.

- `/__e2e/row23-independent-no-lpp-profile` — ?
- `/rente-vs-capital` — ?
- `/simulator/rente-capital` — ?

## Inventaire

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/__e2e/row23-independent-no-lpp-profile` | ? | 🔴 île | — | non |
| `/arbitrage/rente-vs-capital` | ? | 🟡 séquence | — | oui |
| `/assurances/coverage` | CoverageCheckScreen | 🟡 séquence | — | oui |
| `/assurances/lamal` | LamalFranchiseScreen | 🟡 séquence | — | oui |
| `/decaissement` | OptimisationDecaissementScreen | 🟡 séquence | — | oui |
| `/independants/lpp-volontaire` | LppVolontaireScreen | 🟡 séquence | — | oui |
| `/invalidite` | DisabilityGapScreen | 🟡 séquence | — | oui |
| `/libre-passage` | LibrePassageScreen | 🟡 séquence | — | oui |
| `/lpp-deep/epl` | ? | 🟡 séquence | — | oui |
| `/lpp-deep/libre-passage` | ? | 🟡 séquence | — | oui |
| `/rente-vs-capital` | ? | 🔴 île | — | non |
| `/retirement` | ? | 🟡 séquence | — | oui |
| `/retirement/projection` | ? | 🟡 séquence | — | oui |
| `/retraite` | RetirementDashboardScreen | 🟢 câblée | `coach_message_bubble`, `early_retirement_comparison`, `retirement_dashboard_screen`, `smart_shortcuts`, `trajectory_card`, `widget_renderer` | oui |
| `/retraite/rente-vs-capital` | RenteVsCapitalScreen | 🟢 câblée | `coach_message_bubble`, `onboarding_shell_screen` | oui |
| `/simulator/3a` | ? | 🟡 séquence | — | oui |
| `/simulator/compound` | SimulatorCompoundScreen | 🟡 séquence | — | oui |
| `/simulator/credit` | ConsumerCreditSimulatorScreen | 🟡 séquence | — | oui |
| `/simulator/disability-gap` | ? | 🟡 séquence | — | oui |
| `/simulator/job-comparison` | JobComparisonScreen | 🟡 séquence | — | oui |
| `/simulator/leasing` | SimulatorLeasingScreen | 🟡 séquence | — | oui |
| `/simulator/rente-capital` | ? | 🔴 île | — | non |

## Graphe des entrées

```mermaid
graph LR
  coach_message_bubble["coach_message_bubble"] --> _retraite["/retraite"]
  early_retirement_comparison["early_retirement_comparison"] --> _retraite["/retraite"]
  retirement_dashboard_screen["retirement_dashboard_screen"] --> _retraite["/retraite"]
  smart_shortcuts["smart_shortcuts"] --> _retraite["/retraite"]
  trajectory_card["trajectory_card"] --> _retraite["/retraite"]
  widget_renderer["widget_renderer"] --> _retraite["/retraite"]
  coach_message_bubble["coach_message_bubble"] --> _retraite_rente_vs_capital["/retraite/rente-vs-capital"]
  onboarding_shell_screen["onboarding_shell_screen"] --> _retraite_rente_vs_capital["/retraite/rente-vs-capital"]
```

---
description: "Carte de navigation du thème home — 10 routes : 5 câblées (lien cliquable), 5 atteignables seulement par séquence/registre, 0 îles. Verdict : PARCOURABLE."
---

# Thème « home » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart` : routes, liens littéraux `context.go/push`, liens des hubs thématiques (`ExploreHubScreen`/`_HubCard`, cliquables mais via variable), et `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 5 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 5 | atteignable seulement via le registre / le coach |
| 🔴 île | 0 | aucun chemin détecté |
| **Total** | **10** | **verdict : PARCOURABLE** (5/10 = 50 % cliquables) |

## Inventaire (routes produit)

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/arbitrage/bilan` | ArbitrageBilanScreen | 🟢 câblée | `arbitrage_teaser_card`, `hub:/explore/patrimoine` | oui |
| `/bank-import` | BankImportScreen | 🟢 câblée | `documents_screen` | oui |
| `/budget` | ? | 🟢 câblée | `coach_message_bubble`, `mon_argent_screen`, `widget_renderer` | oui |
| `/budget/setup` | BudgetSetupScreen | 🟢 câblée | `budget_container_screen`, `mon_argent_screen` | oui |
| `/home` | ? | 🟡 séquence | — | oui |
| `/mon-argent` | ? | 🟢 câblée | `financial_report_screen_v2` | oui |
| `/open-banking` | OpenBankingHubScreen | 🟡 séquence | — | oui |
| `/open-banking/consents` | ConsentScreen | 🟡 séquence | — | oui |
| `/open-banking/transactions` | TransactionListScreen | 🟡 séquence | — | oui |
| `/portfolio` | ? | 🟡 séquence | — | oui |

## Graphe des entrées

```mermaid
graph LR
  arbitrage_teaser_card["arbitrage_teaser_card"] --> _arbitrage_bilan["/arbitrage/bilan"]
  hub__explore_patrimoine["hub:/explore/patrimoine"] --> _arbitrage_bilan["/arbitrage/bilan"]
  documents_screen["documents_screen"] --> _bank_import["/bank-import"]
  coach_message_bubble["coach_message_bubble"] --> _budget["/budget"]
  mon_argent_screen["mon_argent_screen"] --> _budget["/budget"]
  widget_renderer["widget_renderer"] --> _budget["/budget"]
  budget_container_screen["budget_container_screen"] --> _budget_setup["/budget/setup"]
  mon_argent_screen["mon_argent_screen"] --> _budget_setup["/budget/setup"]
  financial_report_screen_v2["financial_report_screen_v2"] --> _mon_argent["/mon-argent"]
```

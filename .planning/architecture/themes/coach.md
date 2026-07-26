---
description: "Carte de navigation du thème coach — 17 routes : 1 câblées (lien cliquable), 14 atteignables seulement par séquence/registre, 2 îles. Verdict : PORTE UNIQUE."
---

# Thème « coach » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart`, un grep littéral des `context.go/push`, et le `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 1 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 14 | atteignable seulement via le registre / le coach |
| 🔴 île | 2 | aucun chemin détecté |
| **Total** | **17** | **verdict : PORTE UNIQUE** (1/17 = 6 % cliquables) |

## ⚠️ Portes manquantes

Ces routes n'ont **aucun lien cliquable**. Un utilisateur qui explore l'app ne peut pas les atteindre : elles dépendent d'une décision du coach ou d'une séquence.

- `/anonymous/chat` — ?
- `/debug/chat-as-verb` — ChatAsVerbDemoScreen

## Inventaire

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/advisor` | ? | 🟡 séquence | — | oui |
| `/advisor/plan-30-days` | ? | 🟡 séquence | — | oui |
| `/advisor/wizard` | ? | 🟡 séquence | — | oui |
| `/anonymous/chat` | ? | 🔴 île | — | non |
| `/arbitrage/rachat-vs-marche` | ? | 🟡 séquence | — | oui |
| `/coach/agir` | ? | 🟡 séquence | — | oui |
| `/coach/chat` | ? | 🟢 câblée | `arbitrage_bilan_screen`, `aujourdhui_screen`, `budget_screen`, `budget_setup_screen`, `cantonal_benchmark_screen`, `cap_du_jour_banner`, `commitments_and_checkins_card`, `conjoint_missing_hint`, `conversation_history_screen`, `document_impact_screen`, `financial_report_screen_v2`, `mon_argent_screen`, `retroactive_3a_screen`, `staggered_withdrawal_screen` | oui |
| `/coach/checkin` | ? | 🟡 séquence | — | oui |
| `/coach/cockpit` | ? | 🟡 séquence | — | oui |
| `/coach/dashboard` | ? | 🟡 séquence | — | oui |
| `/coach/decaissement` | ? | 🟡 séquence | — | oui |
| `/coach/history` | ConversationHistoryScreen | 🟡 séquence | — | oui |
| `/coach/refresh` | ? | 🟡 séquence | — | oui |
| `/coach/succession` | ? | 🟡 séquence | — | oui |
| `/debug/chat-as-verb` | ChatAsVerbDemoScreen | 🔴 île | — | non |
| `/lpp-deep/rachat` | ? | 🟡 séquence | — | oui |
| `/rachat-lpp` | RachatEchelonneScreen | 🟡 séquence | — | oui |

## Graphe des entrées

```mermaid
graph LR
  arbitrage_bilan_screen["arbitrage_bilan_screen"] --> _coach_chat["/coach/chat"]
  aujourdhui_screen["aujourdhui_screen"] --> _coach_chat["/coach/chat"]
  budget_screen["budget_screen"] --> _coach_chat["/coach/chat"]
  budget_setup_screen["budget_setup_screen"] --> _coach_chat["/coach/chat"]
  cantonal_benchmark_screen["cantonal_benchmark_screen"] --> _coach_chat["/coach/chat"]
  cap_du_jour_banner["cap_du_jour_banner"] --> _coach_chat["/coach/chat"]
  commitments_and_checkins_card["commitments_and_checkins_card"] --> _coach_chat["/coach/chat"]
  conjoint_missing_hint["conjoint_missing_hint"] --> _coach_chat["/coach/chat"]
  conversation_history_screen["conversation_history_screen"] --> _coach_chat["/coach/chat"]
  document_impact_screen["document_impact_screen"] --> _coach_chat["/coach/chat"]
  financial_report_screen_v2["financial_report_screen_v2"] --> _coach_chat["/coach/chat"]
  mon_argent_screen["mon_argent_screen"] --> _coach_chat["/coach/chat"]
  retroactive_3a_screen["retroactive_3a_screen"] --> _coach_chat["/coach/chat"]
  staggered_withdrawal_screen["staggered_withdrawal_screen"] --> _coach_chat["/coach/chat"]
```

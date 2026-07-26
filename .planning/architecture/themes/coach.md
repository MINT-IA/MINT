---
description: "Carte de navigation du thème coach — 16 routes : 2 câblées (lien cliquable), 13 atteignables seulement par séquence/registre, 1 îles. Verdict : PORTE UNIQUE."
---

# Thème « coach » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart` : routes, liens littéraux `context.go/push`, liens des hubs thématiques (`ExploreHubScreen`/`_HubCard`, cliquables mais via variable), et `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 2 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 13 | atteignable seulement via le registre / le coach |
| 🔴 île | 1 | aucun chemin détecté |
| **Total** | **16** | **verdict : PORTE UNIQUE** (2/16 = 12 % cliquables) |

## ⚠️ Portes manquantes

Ces routes n'ont **aucun lien cliquable**. Un utilisateur qui explore l'app ne peut pas les atteindre : elles dépendent d'une décision du coach ou d'une séquence.

- `/anonymous/chat` — ?

## Hors périmètre produit

Ces routes ne doivent PAS être cliquables — les compter comme des îles créerait un faux problème.

| Route | Écran | Nature |
|---|---|---|
| `/debug/chat-as-verb` | ChatAsVerbDemoScreen | admin |

## Inventaire (routes produit)

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
| `/lpp-deep/rachat` | ? | 🟡 séquence | — | oui |
| `/rachat-lpp` | RachatEchelonneScreen | 🟢 câblée | `hub:/explore/retraite` | oui |

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
  hub__explore_retraite["hub:/explore/retraite"] --> _rachat_lpp["/rachat-lpp"]
```

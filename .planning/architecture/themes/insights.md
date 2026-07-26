---
description: "Carte de navigation du thème insights — 7 routes : 2 câblées (lien cliquable), 5 atteignables seulement par séquence/registre, 0 îles. Verdict : PORTE UNIQUE."
---

# Thème « insights » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart` : routes, liens littéraux `context.go/push`, liens des hubs thématiques (`ExploreHubScreen`/`_HubCard`, cliquables mais via variable), et `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 2 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 5 | atteignable seulement via le registre / le coach |
| 🔴 île | 0 | aucun chemin détecté |
| **Total** | **7** | **verdict : PORTE UNIQUE** (2/7 = 29 % cliquables) |

## Inventaire (routes produit)

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/about` | AboutScreen | 🟢 câblée | `register_screen` | non |
| `/achievements` | ? | 🟡 séquence | — | oui |
| `/confidence` | ? | 🟢 câblée | `drawer:coach` | oui |
| `/data-block/:type` | ? | 🟡 séquence | — | oui |
| `/rapport` | ? | 🟡 séquence | — | oui |
| `/report` | ? | 🟡 séquence | — | oui |
| `/report/v2` | ? | 🟡 séquence | — | oui |

## Graphe des entrées

```mermaid
graph LR
  register_screen["register_screen"] --> _about["/about"]
  drawer_coach["drawer:coach"] --> _confidence["/confidence"]
```

---
description: "Carte de navigation du thème autres — 3 routes : 1 câblées (lien cliquable), 2 atteignables seulement par séquence/registre, 0 îles. Verdict : PORTE UNIQUE."
---

# Thème « autres » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart` : routes, liens littéraux `context.go/push`, liens des hubs thématiques (`ExploreHubScreen`/`_HubCard`, cliquables mais via variable), et `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 1 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 2 | atteignable seulement via le registre / le coach |
| 🔴 île | 0 | aucun chemin détecté |
| **Total** | **3** | **verdict : PORTE UNIQUE** (1/3 = 33 % cliquables) |

## Inventaire (routes produit)

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/timeline` | TimelineScreen | 🟡 séquence | — | oui |
| `/tools` | ? | 🟡 séquence | — | oui |
| `/unemployment` | UnemploymentScreen | 🟢 câblée | `hub:/explore/travail` | oui |

## Graphe des entrées

```mermaid
graph LR
  hub__explore_travail["hub:/explore/travail"] --> _unemployment["/unemployment"]
```

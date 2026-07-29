---
description: "Carte de navigation du thème autres — 2 routes : 1 câblées (lien cliquable), 1 atteignables seulement par séquence/registre, 0 îles. Verdict : PARCOURABLE."
---

# Thème « autres » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart` : routes, liens littéraux `context.go/push`, liens des hubs thématiques (`ExploreHubScreen`/`_HubCard`, cliquables mais via variable), et `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 1 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 1 | atteignable seulement via le registre / le coach |
| 🔴 île | 0 | aucun chemin détecté |
| **Total** | **2** | **verdict : PARCOURABLE** (1/2 = 50 % cliquables) |

## Hors périmètre produit

Ces routes ne doivent PAS être cliquables — les compter comme des îles créerait un faux problème.

| Route | Écran | Nature |
|---|---|---|
| `/tools` | ? | redirect |

## Inventaire (routes produit)

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/timeline` | TimelineScreen | 🟡 séquence | — | oui |
| `/unemployment` | UnemploymentScreen | 🟢 câblée | `hub:/explore/travail` | oui |

## Graphe des entrées

```mermaid
graph LR
  hub__explore_travail["hub:/explore/travail"] --> _unemployment["/unemployment"]
```

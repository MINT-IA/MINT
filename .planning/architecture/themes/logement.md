---
description: "Carte de navigation du thème logement — 7 routes : 7 câblées (lien cliquable), 0 atteignables seulement par séquence/registre, 0 îles. Verdict : PARCOURABLE."
---

# Thème « logement » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart` : routes, liens littéraux `context.go/push`, liens des hubs thématiques (`ExploreHubScreen`/`_HubCard`, cliquables mais via variable), et `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 7 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 0 | atteignable seulement via le registre / le coach |
| 🔴 île | 0 | aucun chemin détecté |
| **Total** | **7** | **verdict : PARCOURABLE** (7/7 = 100 % cliquables) |

## Hors périmètre produit

Ces routes ne doivent PAS être cliquables — les compter comme des îles créerait un faux problème.

| Route | Écran | Nature |
|---|---|---|
| `/mortgage/affordability` | ? | redirect |

## Inventaire (routes produit)

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/epl` | EplScreen | 🟢 câblée | `hub:/explore/retraite` | oui |
| `/hypotheque` | AffordabilityScreen | 🟢 câblée | `drawer:coach`, `hub:/explore/logement` | oui |
| `/life-event/housing-sale` | HousingSaleScreen | 🟢 câblée | `hub:/explore/logement` | oui |
| `/mortgage/amortization` | AmortizationScreen | 🟢 câblée | `hub:/explore/logement` | oui |
| `/mortgage/epl-combined` | EplCombinedScreen | 🟢 câblée | `hub:/explore/logement` | oui |
| `/mortgage/imputed-rental` | ImputedRentalScreen | 🟢 câblée | `hub:/explore/logement` | oui |
| `/mortgage/saron-vs-fixed` | SaronVsFixedScreen | 🟢 câblée | `hub:/explore/logement` | oui |

## Graphe des entrées

```mermaid
graph LR
  hub__explore_retraite["hub:/explore/retraite"] --> _epl["/epl"]
  drawer_coach["drawer:coach"] --> _hypotheque["/hypotheque"]
  hub__explore_logement["hub:/explore/logement"] --> _hypotheque["/hypotheque"]
  hub__explore_logement["hub:/explore/logement"] --> _life_event_housing_sale["/life-event/housing-sale"]
  hub__explore_logement["hub:/explore/logement"] --> _mortgage_amortization["/mortgage/amortization"]
  hub__explore_logement["hub:/explore/logement"] --> _mortgage_epl_combined["/mortgage/epl-combined"]
  hub__explore_logement["hub:/explore/logement"] --> _mortgage_imputed_rental["/mortgage/imputed-rental"]
  hub__explore_logement["hub:/explore/logement"] --> _mortgage_saron_vs_fixed["/mortgage/saron-vs-fixed"]
```

---
description: "Carte de navigation du thème profil — 7 routes : 4 câblées (lien cliquable), 3 atteignables seulement par séquence/registre, 0 îles. Verdict : PARCOURABLE."
---

# Thème « profil » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart` : routes, liens littéraux `context.go/push`, liens des hubs thématiques (`ExploreHubScreen`/`_HubCard`, cliquables mais via variable), et `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 4 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 3 | atteignable seulement via le registre / le coach |
| 🔴 île | 0 | aucun chemin détecté |
| **Total** | **7** | **verdict : PARCOURABLE** (4/7 = 57 % cliquables) |

## Hors périmètre produit

Ces routes ne doivent PAS être cliquables — les compter comme des îles créerait un faux problème.

| Route | Écran | Nature |
|---|---|---|
| `/profile/admin-observability` | AdminObservabilityScreen | admin |

## Inventaire (routes produit)

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/couple` | HouseholdScreen | 🟢 câblée | `accept_invitation_screen` | oui |
| `/couple/accept` | ? | 🟡 séquence | — | oui |
| `/household` | ? | 🟡 séquence | — | oui |
| `/household/accept` | ? | 🟢 câblée | `household_screen` | oui |
| `/profile` | ? | 🟢 câblée | `retirement_dashboard_screen` | oui |
| `/settings/confidentialite` | ConfidentialiteSettingsScreen | 🟢 câblée | `financial_summary_screen` | oui |
| `/settings/langue` | LangueSettingsScreen | 🟡 séquence | — | oui |

## Graphe des entrées

```mermaid
graph LR
  accept_invitation_screen["accept_invitation_screen"] --> _couple["/couple"]
  household_screen["household_screen"] --> _household_accept["/household/accept"]
  retirement_dashboard_screen["retirement_dashboard_screen"] --> _profile["/profile"]
  financial_summary_screen["financial_summary_screen"] --> _settings_confidentialite["/settings/confidentialite"]
```

---
description: "Carte de navigation du thème profil — 5 routes : 3 câblées (lien cliquable), 2 atteignables seulement par séquence/registre, 0 îles. Verdict : PARCOURABLE."
---

# Thème « profil » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart` : routes, liens littéraux `context.go/push`, liens des hubs thématiques (`ExploreHubScreen`/`_HubCard`, cliquables mais via variable), et `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 3 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 2 | atteignable seulement via le registre / le coach |
| 🔴 île | 0 | aucun chemin détecté |
| **Total** | **5** | **verdict : PARCOURABLE** (3/5 = 60 % cliquables) |

## Hors périmètre produit

Ces routes ne doivent PAS être cliquables — les compter comme des îles créerait un faux problème.

| Route | Écran | Nature |
|---|---|---|
| `/household` | ? | redirect |
| `/household/accept` | ? | redirect |
| `/profile/admin-observability` | AdminObservabilityScreen | admin |

## Inventaire (routes produit)

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/couple` | HouseholdScreen | 🟢 câblée | `accept_invitation_screen` | oui |
| `/couple/accept` | ? | 🟡 séquence | — | oui |
| `/profile` | ? | 🟢 câblée | `retirement_dashboard_screen` | oui |
| `/settings/confidentialite` | ConfidentialiteSettingsScreen | 🟢 câblée | `financial_summary_screen` | oui |
| `/settings/langue` | LangueSettingsScreen | 🟡 séquence | — | oui |

## Graphe des entrées

```mermaid
graph LR
  accept_invitation_screen["accept_invitation_screen"] --> _couple["/couple"]
  retirement_dashboard_screen["retirement_dashboard_screen"] --> _profile["/profile"]
  financial_summary_screen["financial_summary_screen"] --> _settings_confidentialite["/settings/confidentialite"]
```

---
description: "Carte de navigation du thème onboarding — 5 routes : 4 câblées (lien cliquable), 1 atteignables seulement par séquence/registre, 0 îles. Verdict : PARCOURABLE."
---

# Thème « onboarding » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart` : routes, liens littéraux `context.go/push`, liens des hubs thématiques (`ExploreHubScreen`/`_HubCard`, cliquables mais via variable), et `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 4 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 1 | atteignable seulement via le registre / le coach |
| 🔴 île | 0 | aucun chemin détecté |
| **Total** | **5** | **verdict : PARCOURABLE** (4/5 = 80 % cliquables) |

## Hors périmètre produit

Ces routes ne doivent PAS être cliquables — les compter comme des îles créerait un faux problème.

| Route | Écran | Nature |
|---|---|---|
| `/onboarding/enrichment` | ? | onboarding |
| `/onboarding/intent` | ? | onboarding |
| `/onboarding/minimal` | ? | onboarding |
| `/onboarding/plan` | ? | onboarding |
| `/onboarding/premier-eclairage` | ? | onboarding |
| `/onboarding/promise` | ? | onboarding |
| `/onboarding/quick` | ? | onboarding |
| `/onboarding/quick-start` | ? | onboarding |
| `/onboarding/smart` | ? | onboarding |
| `/waitlist` | ? | deeplink |

## Inventaire (routes produit)

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/` | LandingScreen | 🟢 câblée | `anonymous_chat_screen`, `login_screen`, `privacy_center_screen`, `profile_drawer`, `register_screen`, `waitlist_success` | non |
| `/ask-mint` | ? | 🟢 câblée | `byok_settings_screen` | oui |
| `/onb` | OnboardingShellScreen | 🟢 câblée | `financial_summary_screen`, `retirement_dashboard_screen` | oui |
| `/score-reveal` | ? | 🟡 séquence | — | oui |
| `/start` | ? | 🟢 câblée | `landing_screen` | non |

## Graphe des entrées

```mermaid
graph LR
  anonymous_chat_screen["anonymous_chat_screen"] --> _["/"]
  login_screen["login_screen"] --> _["/"]
  privacy_center_screen["privacy_center_screen"] --> _["/"]
  profile_drawer["profile_drawer"] --> _["/"]
  register_screen["register_screen"] --> _["/"]
  waitlist_success["waitlist_success"] --> _["/"]
  byok_settings_screen["byok_settings_screen"] --> _ask_mint["/ask-mint"]
  financial_summary_screen["financial_summary_screen"] --> _onb["/onb"]
  retirement_dashboard_screen["retirement_dashboard_screen"] --> _onb["/onb"]
  landing_screen["landing_screen"] --> _start["/start"]
```

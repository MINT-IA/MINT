---
description: "Carte de navigation du thème onboarding — 15 routes : 4 câblées (lien cliquable), 2 atteignables seulement par séquence/registre, 9 îles. Verdict : PARTIELLE."
---

# Thème « onboarding » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart`, un grep littéral des `context.go/push`, et le `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 4 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 2 | atteignable seulement via le registre / le coach |
| 🔴 île | 9 | aucun chemin détecté |
| **Total** | **15** | **verdict : PARTIELLE** (4/15 = 27 % cliquables) |

## ⚠️ Portes manquantes

Ces routes n'ont **aucun lien cliquable**. Un utilisateur qui explore l'app ne peut pas les atteindre : elles dépendent d'une décision du coach ou d'une séquence.

- `/onboarding/enrichment` — ?
- `/onboarding/intent` — ?
- `/onboarding/minimal` — ?
- `/onboarding/plan` — ?
- `/onboarding/promise` — ?
- `/onboarding/quick` — ?
- `/onboarding/quick-start` — ?
- `/onboarding/smart` — ?
- `/waitlist` — ?

## Inventaire

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/` | LandingScreen | 🟢 câblée | `anonymous_chat_screen`, `login_screen`, `privacy_center_screen`, `profile_drawer`, `register_screen`, `waitlist_success` | non |
| `/ask-mint` | ? | 🟢 câblée | `byok_settings_screen` | oui |
| `/onb` | OnboardingShellScreen | 🟢 câblée | `financial_summary_screen`, `retirement_dashboard_screen` | oui |
| `/onboarding/enrichment` | ? | 🔴 île | — | non |
| `/onboarding/intent` | ? | 🔴 île | — | non |
| `/onboarding/minimal` | ? | 🔴 île | — | non |
| `/onboarding/plan` | ? | 🔴 île | — | non |
| `/onboarding/premier-eclairage` | ? | 🟡 séquence | — | oui |
| `/onboarding/promise` | ? | 🔴 île | — | non |
| `/onboarding/quick` | ? | 🔴 île | — | non |
| `/onboarding/quick-start` | ? | 🔴 île | — | non |
| `/onboarding/smart` | ? | 🔴 île | — | non |
| `/score-reveal` | ? | 🟡 séquence | — | oui |
| `/start` | ? | 🟢 câblée | `landing_screen` | non |
| `/waitlist` | ? | 🔴 île | — | non |

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

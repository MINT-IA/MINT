---
description: "Carte de navigation du thème auth — 5 routes : 4 câblées (lien cliquable), 0 atteignables seulement par séquence/registre, 1 îles. Verdict : PARTIELLE."
---

# Thème « auth » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart`, un grep littéral des `context.go/push`, et le `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 4 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 0 | atteignable seulement via le registre / le coach |
| 🔴 île | 1 | aucun chemin détecté |
| **Total** | **5** | **verdict : PARTIELLE** (4/5 = 80 % cliquables) |

## ⚠️ Portes manquantes

Ces routes n'ont **aucun lien cliquable**. Un utilisateur qui explore l'app ne peut pas les atteindre : elles dépendent d'une décision du coach ou d'une séquence.

- `/auth/verify` — ?

## Inventaire

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/auth/forgot-password` | ForgotPasswordScreen | 🟢 câblée | `login_screen` | oui |
| `/auth/login` | LoginScreen | 🟢 câblée | `coach_chat_screen`, `forgot_password_screen`, `household_screen`, `landing_screen`, `profile_drawer`, `register_screen`, `verify_email_screen` | oui |
| `/auth/register` | RegisterScreen | 🟢 câblée | `coach_chat_screen`, `document_scan_screen`, `login_screen` | oui |
| `/auth/verify` | ? | 🔴 île | — | non |
| `/auth/verify-email` | VerifyEmailScreen | 🟢 câblée | `login_screen` | oui |

## Graphe des entrées

```mermaid
graph LR
  login_screen["login_screen"] --> _auth_forgot_password["/auth/forgot-password"]
  coach_chat_screen["coach_chat_screen"] --> _auth_login["/auth/login"]
  forgot_password_screen["forgot_password_screen"] --> _auth_login["/auth/login"]
  household_screen["household_screen"] --> _auth_login["/auth/login"]
  landing_screen["landing_screen"] --> _auth_login["/auth/login"]
  profile_drawer["profile_drawer"] --> _auth_login["/auth/login"]
  register_screen["register_screen"] --> _auth_login["/auth/login"]
  verify_email_screen["verify_email_screen"] --> _auth_login["/auth/login"]
  coach_chat_screen["coach_chat_screen"] --> _auth_register["/auth/register"]
  document_scan_screen["document_scan_screen"] --> _auth_register["/auth/register"]
  login_screen["login_screen"] --> _auth_register["/auth/register"]
  login_screen["login_screen"] --> _auth_verify_email["/auth/verify-email"]
```

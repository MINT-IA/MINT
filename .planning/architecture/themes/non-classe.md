---
description: "Carte de navigation du thème non-classe — 6 routes : 0 câblées (lien cliquable), 0 atteignables seulement par séquence/registre, 6 îles. Verdict : AUCUNE PORTE."
---

# Thème « non-classe » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart`, un grep littéral des `context.go/push`, et le `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 0 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 0 | atteignable seulement via le registre / le coach |
| 🔴 île | 6 | aucun chemin détecté |
| **Total** | **6** | **verdict : AUCUNE PORTE** (0/6 = 0 % cliquables) |

## ⚠️ Portes manquantes

Ces routes n'ont **aucun lien cliquable**. Un utilisateur qui explore l'app ne peut pas les atteindre : elles dépendent d'une décision du coach ou d'une séquence.

- `/profile/admin-observability/admin-analytics` — AdminAnalyticsScreen
- `/profile/admin-observability/admin-analytics/byok` — ByokSettingsScreen
- `/profile/admin-observability/admin-analytics/byok/slm` — SlmSettingsScreen
- `/profile/admin-observability/admin-analytics/byok/slm/bilan` — FinancialSummaryScreen
- `/profile/admin-observability/admin-analytics/byok/slm/bilan/privacy-control` — PrivacyControlScreen
- `/profile/admin-observability/admin-analytics/byok/slm/bilan/privacy-control/privacy` — PrivacyCenterScreen

## Inventaire

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/profile/admin-observability/admin-analytics` | AdminAnalyticsScreen | 🔴 île | — | non |
| `/profile/admin-observability/admin-analytics/byok` | ByokSettingsScreen | 🔴 île | — | non |
| `/profile/admin-observability/admin-analytics/byok/slm` | SlmSettingsScreen | 🔴 île | — | non |
| `/profile/admin-observability/admin-analytics/byok/slm/bilan` | FinancialSummaryScreen | 🔴 île | — | non |
| `/profile/admin-observability/admin-analytics/byok/slm/bilan/privacy-control` | PrivacyControlScreen | 🔴 île | — | non |
| `/profile/admin-observability/admin-analytics/byok/slm/bilan/privacy-control/privacy` | PrivacyCenterScreen | 🔴 île | — | non |

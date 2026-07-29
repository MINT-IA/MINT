---
description: "Carte de navigation du thème non-classe — 0 routes : 0 câblées (lien cliquable), 0 atteignables seulement par séquence/registre, 0 îles. Verdict : AUCUNE PORTE."
---

# Thème « non-classe » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart` : routes, liens littéraux `context.go/push`, liens des hubs thématiques (`ExploreHubScreen`/`_HubCard`, cliquables mais via variable), et `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 0 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 0 | atteignable seulement via le registre / le coach |
| 🔴 île | 0 | aucun chemin détecté |
| **Total** | **0** | **verdict : AUCUNE PORTE** (0/0 = 0 % cliquables) |

## ⚠️ Portes manquantes

Ces routes n'ont **aucun lien cliquable**. Un utilisateur qui explore l'app ne peut pas les atteindre : elles dépendent d'une décision du coach ou d'une séquence.


## Hors périmètre produit

Ces routes ne doivent PAS être cliquables — les compter comme des îles créerait un faux problème.

| Route | Écran | Nature |
|---|---|---|
| `/profile/admin-observability/admin-analytics` | AdminAnalyticsScreen | admin |
| `/profile/admin-observability/admin-analytics/byok` | ByokSettingsScreen | admin |
| `/profile/admin-observability/admin-analytics/byok/slm` | SlmSettingsScreen | admin |
| `/profile/admin-observability/admin-analytics/byok/slm/bilan` | FinancialSummaryScreen | admin |
| `/profile/admin-observability/admin-analytics/byok/slm/bilan/privacy-control` | PrivacyControlScreen | admin |
| `/profile/admin-observability/admin-analytics/byok/slm/bilan/privacy-control/privacy` | PrivacyCenterScreen | admin |

## Inventaire (routes produit)

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|

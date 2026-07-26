---
description: "Carte de navigation du thème logement — 8 routes : 0 câblées (lien cliquable), 8 atteignables seulement par séquence/registre, 0 îles. Verdict : AUCUNE PORTE."
---

# Thème « logement » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart`, un grep littéral des `context.go/push`, et le `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 0 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 8 | atteignable seulement via le registre / le coach |
| 🔴 île | 0 | aucun chemin détecté |
| **Total** | **8** | **verdict : AUCUNE PORTE** (0/8 = 0 % cliquables) |

## ⚠️ Portes manquantes

Ces routes n'ont **aucun lien cliquable**. Un utilisateur qui explore l'app ne peut pas les atteindre : elles dépendent d'une décision du coach ou d'une séquence.

- `/epl` — EplScreen
- `/hypotheque` — AffordabilityScreen
- `/life-event/housing-sale` — HousingSaleScreen
- `/mortgage/affordability` — ?
- `/mortgage/amortization` — AmortizationScreen
- `/mortgage/epl-combined` — EplCombinedScreen
- `/mortgage/imputed-rental` — ImputedRentalScreen
- `/mortgage/saron-vs-fixed` — SaronVsFixedScreen

## Inventaire

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/epl` | EplScreen | 🟡 séquence | — | oui |
| `/hypotheque` | AffordabilityScreen | 🟡 séquence | — | oui |
| `/life-event/housing-sale` | HousingSaleScreen | 🟡 séquence | — | oui |
| `/mortgage/affordability` | ? | 🟡 séquence | — | oui |
| `/mortgage/amortization` | AmortizationScreen | 🟡 séquence | — | oui |
| `/mortgage/epl-combined` | EplCombinedScreen | 🟡 séquence | — | oui |
| `/mortgage/imputed-rental` | ImputedRentalScreen | 🟡 séquence | — | oui |
| `/mortgage/saron-vs-fixed` | SaronVsFixedScreen | 🟡 séquence | — | oui |

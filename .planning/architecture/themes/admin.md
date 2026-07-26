---
description: "Carte de navigation du thème admin — 3 routes : 0 câblées (lien cliquable), 0 atteignables seulement par séquence/registre, 3 îles. Verdict : AUCUNE PORTE."
---

# Thème « admin » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart`, un grep littéral des `context.go/push`, et le `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 0 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 0 | atteignable seulement via le registre / le coach |
| 🔴 île | 3 | aucun chemin détecté |
| **Total** | **3** | **verdict : AUCUNE PORTE** (0/3 = 0 % cliquables) |

## ⚠️ Portes manquantes

Ces routes n'ont **aucun lien cliquable**. Un utilisateur qui explore l'app ne peut pas les atteindre : elles dépendent d'une décision du coach ou d'une séquence.

- `/__e2e/budget-direct-inputs` — ?
- `/admin/debug-spine` — AdminShell
- `/admin/routes` — AdminShell

## Inventaire

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/__e2e/budget-direct-inputs` | ? | 🔴 île | — | non |
| `/admin/debug-spine` | AdminShell | 🔴 île | — | non |
| `/admin/routes` | AdminShell | 🔴 île | — | non |

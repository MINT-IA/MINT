---
description: "Carte de navigation du thème autres — 3 routes : 0 câblées (lien cliquable), 3 atteignables seulement par séquence/registre, 0 îles. Verdict : AUCUNE PORTE."
---

# Thème « autres » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart`, un grep littéral des `context.go/push`, et le `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 0 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 3 | atteignable seulement via le registre / le coach |
| 🔴 île | 0 | aucun chemin détecté |
| **Total** | **3** | **verdict : AUCUNE PORTE** (0/3 = 0 % cliquables) |

## ⚠️ Portes manquantes

Ces routes n'ont **aucun lien cliquable**. Un utilisateur qui explore l'app ne peut pas les atteindre : elles dépendent d'une décision du coach ou d'une séquence.

- `/timeline` — TimelineScreen
- `/tools` — ?
- `/unemployment` — UnemploymentScreen

## Inventaire

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/timeline` | TimelineScreen | 🟡 séquence | — | oui |
| `/tools` | ? | 🟡 séquence | — | oui |
| `/unemployment` | UnemploymentScreen | 🟡 séquence | — | oui |

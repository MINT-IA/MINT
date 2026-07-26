---
description: "Index des cartes de navigation par thème — une carte par univers de vie, générée mécaniquement depuis le code. Sert de feuille de route pour rendre chaque thème réellement parcourable."
---

# Architecture de navigation — cartes par thème

> Généré par `tools/checks/generate_theme_maps.py`. Relancer après tout changement de navigation.

| Thème | Routes | 🟢 câblées | 🟡 séquence | 🔴 îles | Verdict |
|---|---:|---:|---:|---:|---|
| [lifeevents](themes/lifeevents.md) | 30 | 24 | 6 | 0 | PARCOURABLE |
| [pilier3a](themes/pilier3a.md) | 12 | 8 | 4 | 0 | PARCOURABLE |
| [retraite](themes/retraite.md) | 12 | 8 | 4 | 0 | PARCOURABLE |
| [home](themes/home.md) | 9 | 5 | 4 | 0 | PARCOURABLE |
| [logement](themes/logement.md) | 7 | 7 | 0 | 0 | PARCOURABLE |
| [documents](themes/documents.md) | 6 | 4 | 2 | 0 | PARCOURABLE |
| [profil](themes/profil.md) | 5 | 3 | 2 | 0 | PARCOURABLE |
| [insights](themes/insights.md) | 4 | 2 | 2 | 0 | PARCOURABLE |
| [auth](themes/auth.md) | 3 | 3 | 0 | 0 | PARCOURABLE |
| [coach](themes/coach.md) | 3 | 2 | 1 | 0 | PARCOURABLE |
| [autres](themes/autres.md) | 2 | 1 | 1 | 0 | PARCOURABLE |
| [onboarding](themes/onboarding.md) | 2 | 2 | 0 | 0 | PARCOURABLE |
| [admin](themes/admin.md) | 0 | 0 | 0 | 0 | AUCUNE PORTE |
| [non-classe](themes/non-classe.md) | 0 | 0 | 0 | 0 | AUCUNE PORTE |
| **Total** | **95** | **69** | **26** | **0** | |

## Comment lire

- **🟢 câblée** : un `context.go/push` littéral y mène depuis un écran — l'utilisateur peut y arriver en cliquant.
- **🟡 séquence** : la route n'existe que dans le `ScreenRegistry` — atteignable si le coach ou une séquence décide d'y aller, jamais en explorant.
- **🔴 île** : aucun chemin détecté.

Un thème n'est un **voyage** que s'il est parcourable : une porte d'entrée visible, puis des liens entre ses écrans.

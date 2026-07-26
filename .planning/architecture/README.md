---
description: "Index des cartes de navigation par thème — une carte par univers de vie, générée mécaniquement depuis le code. Sert de feuille de route pour rendre chaque thème réellement parcourable."
---

# Architecture de navigation — cartes par thème

> Généré par `tools/checks/generate_theme_maps.py`. Relancer après tout changement de navigation.

| Thème | Routes | 🟢 câblées | 🟡 séquence | 🔴 îles | Verdict |
|---|---:|---:|---:|---:|---|
| [onboarding](themes/onboarding.md) | 15 | 4 | 2 | 9 | PARTIELLE |
| [non-classe](themes/non-classe.md) | 6 | 0 | 0 | 6 | AUCUNE PORTE |
| [retraite](themes/retraite.md) | 22 | 2 | 17 | 3 | PORTE UNIQUE |
| [admin](themes/admin.md) | 3 | 0 | 0 | 3 | AUCUNE PORTE |
| [coach](themes/coach.md) | 17 | 1 | 14 | 2 | PORTE UNIQUE |
| [auth](themes/auth.md) | 5 | 4 | 0 | 1 | PARTIELLE |
| [lifeevents](themes/lifeevents.md) | 33 | 4 | 29 | 0 | PARTIELLE |
| [pilier3a](themes/pilier3a.md) | 13 | 1 | 12 | 0 | PORTE UNIQUE |
| [home](themes/home.md) | 10 | 5 | 5 | 0 | PARCOURABLE |
| [documents](themes/documents.md) | 8 | 4 | 4 | 0 | PARCOURABLE |
| [logement](themes/logement.md) | 8 | 0 | 8 | 0 | AUCUNE PORTE |
| [profil](themes/profil.md) | 8 | 4 | 4 | 0 | PARCOURABLE |
| [insights](themes/insights.md) | 7 | 1 | 6 | 0 | PORTE UNIQUE |
| [autres](themes/autres.md) | 3 | 0 | 3 | 0 | AUCUNE PORTE |
| **Total** | **158** | **30** | **104** | **24** | |

## Comment lire

- **🟢 câblée** : un `context.go/push` littéral y mène depuis un écran — l'utilisateur peut y arriver en cliquant.
- **🟡 séquence** : la route n'existe que dans le `ScreenRegistry` — atteignable si le coach ou une séquence décide d'y aller, jamais en explorant.
- **🔴 île** : aucun chemin détecté.

Un thème n'est un **voyage** que s'il est parcourable : une porte d'entrée visible, puis des liens entre ses écrans.

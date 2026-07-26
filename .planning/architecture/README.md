---
description: "Index des cartes de navigation par thème — une carte par univers de vie, générée mécaniquement depuis le code. Sert de feuille de route pour rendre chaque thème réellement parcourable."
---

# Architecture de navigation — cartes par thème

> Généré par `tools/checks/generate_theme_maps.py`. Relancer après tout changement de navigation.

| Thème | Routes | 🟢 câblées | 🟡 séquence | 🔴 îles | Verdict |
|---|---:|---:|---:|---:|---|
| [retraite](themes/retraite.md) | 21 | 8 | 11 | 2 | PARTIELLE |
| [coach](themes/coach.md) | 16 | 2 | 13 | 1 | PORTE UNIQUE |
| [lifeevents](themes/lifeevents.md) | 33 | 24 | 9 | 0 | PARCOURABLE |
| [pilier3a](themes/pilier3a.md) | 13 | 8 | 5 | 0 | PARCOURABLE |
| [home](themes/home.md) | 10 | 5 | 5 | 0 | PARCOURABLE |
| [documents](themes/documents.md) | 8 | 4 | 4 | 0 | PARCOURABLE |
| [logement](themes/logement.md) | 8 | 7 | 1 | 0 | PARCOURABLE |
| [insights](themes/insights.md) | 7 | 2 | 5 | 0 | PORTE UNIQUE |
| [profil](themes/profil.md) | 7 | 4 | 3 | 0 | PARCOURABLE |
| [onboarding](themes/onboarding.md) | 5 | 4 | 1 | 0 | PARCOURABLE |
| [auth](themes/auth.md) | 3 | 3 | 0 | 0 | PARCOURABLE |
| [autres](themes/autres.md) | 3 | 1 | 2 | 0 | PORTE UNIQUE |
| [admin](themes/admin.md) | 0 | 0 | 0 | 0 | AUCUNE PORTE |
| [non-classe](themes/non-classe.md) | 0 | 0 | 0 | 0 | AUCUNE PORTE |
| **Total** | **134** | **72** | **59** | **3** | |

## Comment lire

- **🟢 câblée** : un `context.go/push` littéral y mène depuis un écran — l'utilisateur peut y arriver en cliquant.
- **🟡 séquence** : la route n'existe que dans le `ScreenRegistry` — atteignable si le coach ou une séquence décide d'y aller, jamais en explorant.
- **🔴 île** : aucun chemin détecté.

Un thème n'est un **voyage** que s'il est parcourable : une porte d'entrée visible, puis des liens entre ses écrans.

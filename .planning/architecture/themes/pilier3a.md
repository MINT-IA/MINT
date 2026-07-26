---
description: "Carte de navigation du thème pilier3a — 13 routes : 1 câblées (lien cliquable), 12 atteignables seulement par séquence/registre, 0 îles. Verdict : PORTE UNIQUE."
---

# Thème « pilier3a » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart`, un grep littéral des `context.go/push`, et le `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 1 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 12 | atteignable seulement via le registre / le coach |
| 🔴 île | 0 | aucun chemin détecté |
| **Total** | **13** | **verdict : PORTE UNIQUE** (1/13 = 8 % cliquables) |

## Inventaire

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/3a-deep/comparator` | ProviderComparatorScreen | 🟡 séquence | — | oui |
| `/3a-deep/real-return` | RealReturnScreen | 🟡 séquence | — | oui |
| `/3a-deep/staggered-withdrawal` | StaggeredWithdrawalScreen | 🟡 séquence | — | oui |
| `/3a-retroactif` | Retroactive3aScreen | 🟡 séquence | — | oui |
| `/arbitrage/allocation-annuelle` | AllocationAnnuelleScreen | 🟡 séquence | — | oui |
| `/arbitrage/calendrier-retraits` | ? | 🟡 séquence | — | oui |
| `/arbitrage/location-vs-propriete` | LocationVsProprieteScreen | 🟡 séquence | — | oui |
| `/independants/3a` | Pillar3aIndepScreen | 🟡 séquence | — | oui |
| `/independants/avs` | AvsCotisationsScreen | 🟡 séquence | — | oui |
| `/independants/dividende-salaire` | DividendeVsSalaireScreen | 🟡 séquence | — | oui |
| `/independants/ijm` | IjmScreen | 🟡 séquence | — | oui |
| `/pilier-3a` | Simulator3aScreen | 🟢 câblée | `coach_message_bubble` | oui |
| `/segments/independant` | IndependantScreen | 🟡 séquence | — | oui |

## Graphe des entrées

```mermaid
graph LR
  coach_message_bubble["coach_message_bubble"] --> _pilier_3a["/pilier-3a"]
```

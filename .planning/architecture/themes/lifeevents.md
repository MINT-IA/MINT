---
description: "Carte de navigation du thème lifeevents — 33 routes : 24 câblées (lien cliquable), 9 atteignables seulement par séquence/registre, 0 îles. Verdict : PARCOURABLE."
---

# Thème « lifeevents » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart` : routes, liens littéraux `context.go/push`, liens des hubs thématiques (`ExploreHubScreen`/`_HubCard`, cliquables mais via variable), et `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 24 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 9 | atteignable seulement via le registre / le coach |
| 🔴 île | 0 | aucun chemin détecté |
| **Total** | **33** | **verdict : PARCOURABLE** (24/33 = 73 % cliquables) |

## Inventaire (routes produit)

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/cantonal-benchmark` | CantonalBenchmarkScreen | 🟡 séquence | — | oui |
| `/check/debt` | DebtRiskCheckScreen | 🟡 séquence | — | oui |
| `/concubinage` | ConcubinageScreen | 🟢 câblée | `hub:/explore/famille` | oui |
| `/debt/help` | HelpResourcesScreen | 🟡 séquence | — | oui |
| `/debt/ratio` | DebtRatioScreen | 🟡 séquence | — | oui |
| `/debt/repayment` | RepaymentScreen | 🟢 câblée | `debt_ratio_screen` | oui |
| `/disability/gap` | ? | 🟡 séquence | — | oui |
| `/disability/insurance` | DisabilityInsuranceScreen | 🟢 câblée | `hub:/explore/sante` | oui |
| `/disability/self-employed` | DisabilitySelfEmployedScreen | 🟢 câblée | `hub:/explore/sante` | oui |
| `/divorce` | DivorceSimulatorScreen | 🟢 câblée | `hub:/explore/famille` | oui |
| `/education/hub` | ComprendreHubScreen | 🟢 câblée | `coach_message_bubble`, `retirement_dashboard_screen` | oui |
| `/education/theme/:id` | ? | 🟡 séquence | — | oui |
| `/expatriation` | ExpatScreen | 🟢 câblée | `hub:/explore/travail` | oui |
| `/explore` | ExplorerScreen | 🟢 câblée | `cap_du_jour_banner` | oui |
| `/explore/famille` | ExploreHubScreen | 🟢 câblée | `explorer_screen` | oui |
| `/explore/fiscalite` | ExploreHubScreen | 🟢 câblée | `explorer_screen` | oui |
| `/explore/logement` | ExploreHubScreen | 🟢 câblée | `explorer_screen` | oui |
| `/explore/patrimoine` | ExploreHubScreen | 🟢 câblée | `explorer_screen` | oui |
| `/explore/retraite` | ExploreHubScreen | 🟢 câblée | `explorer_screen` | oui |
| `/explore/sante` | ExploreHubScreen | 🟢 câblée | `explorer_screen` | oui |
| `/explore/travail` | ExploreHubScreen | 🟢 câblée | `explorer_screen` | oui |
| `/first-job` | FirstJobScreen | 🟢 câblée | `hub:/explore/travail` | oui |
| `/fiscal` | FiscalComparatorScreen | 🟢 câblée | `coach_message_bubble`, `hub:/explore/fiscalite` | oui |
| `/life-event/deces-proche` | DecesProcheScreen | 🟢 câblée | `hub:/explore/patrimoine` | oui |
| `/life-event/demenagement-cantonal` | DemenagementCantonalScreen | 🟢 câblée | `hub:/explore/patrimoine` | oui |
| `/life-event/divorce` | ? | 🟡 séquence | — | oui |
| `/life-event/donation` | DonationScreen | 🟢 câblée | `hub:/explore/patrimoine` | oui |
| `/life-event/succession` | ? | 🟡 séquence | — | oui |
| `/mariage` | MariageScreen | 🟢 câblée | `hub:/explore/famille` | oui |
| `/naissance` | NaissanceScreen | 🟢 câblée | `hub:/explore/famille` | oui |
| `/segments/frontalier` | FrontalierScreen | 🟢 câblée | `hub:/explore/travail` | oui |
| `/segments/gender-gap` | GenderGapScreen | 🟡 séquence | — | oui |
| `/succession` | SuccessionPatrimoineScreen | 🟢 câblée | `hub:/explore/famille` | oui |

## Graphe des entrées

```mermaid
graph LR
  hub__explore_famille["hub:/explore/famille"] --> _concubinage["/concubinage"]
  debt_ratio_screen["debt_ratio_screen"] --> _debt_repayment["/debt/repayment"]
  hub__explore_sante["hub:/explore/sante"] --> _disability_insurance["/disability/insurance"]
  hub__explore_sante["hub:/explore/sante"] --> _disability_self_employed["/disability/self-employed"]
  hub__explore_famille["hub:/explore/famille"] --> _divorce["/divorce"]
  coach_message_bubble["coach_message_bubble"] --> _education_hub["/education/hub"]
  retirement_dashboard_screen["retirement_dashboard_screen"] --> _education_hub["/education/hub"]
  hub__explore_travail["hub:/explore/travail"] --> _expatriation["/expatriation"]
  cap_du_jour_banner["cap_du_jour_banner"] --> _explore["/explore"]
  explorer_screen["explorer_screen"] --> _explore_famille["/explore/famille"]
  explorer_screen["explorer_screen"] --> _explore_fiscalite["/explore/fiscalite"]
  explorer_screen["explorer_screen"] --> _explore_logement["/explore/logement"]
  explorer_screen["explorer_screen"] --> _explore_patrimoine["/explore/patrimoine"]
  explorer_screen["explorer_screen"] --> _explore_retraite["/explore/retraite"]
  explorer_screen["explorer_screen"] --> _explore_sante["/explore/sante"]
  explorer_screen["explorer_screen"] --> _explore_travail["/explore/travail"]
  hub__explore_travail["hub:/explore/travail"] --> _first_job["/first-job"]
  coach_message_bubble["coach_message_bubble"] --> _fiscal["/fiscal"]
  hub__explore_fiscalite["hub:/explore/fiscalite"] --> _fiscal["/fiscal"]
  hub__explore_patrimoine["hub:/explore/patrimoine"] --> _life_event_deces_proche["/life-event/deces-proche"]
  hub__explore_patrimoine["hub:/explore/patrimoine"] --> _life_event_demenagement_cantonal["/life-event/demenagement-cantonal"]
  hub__explore_patrimoine["hub:/explore/patrimoine"] --> _life_event_donation["/life-event/donation"]
  hub__explore_famille["hub:/explore/famille"] --> _mariage["/mariage"]
  hub__explore_famille["hub:/explore/famille"] --> _naissance["/naissance"]
  hub__explore_travail["hub:/explore/travail"] --> _segments_frontalier["/segments/frontalier"]
  hub__explore_famille["hub:/explore/famille"] --> _succession["/succession"]
```

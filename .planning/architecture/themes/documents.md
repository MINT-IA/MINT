---
description: "Carte de navigation du thème documents — 8 routes : 4 câblées (lien cliquable), 4 atteignables seulement par séquence/registre, 0 îles. Verdict : PARCOURABLE."
---

# Thème « documents » — carte de navigation

> Généré mécaniquement par `tools/checks/generate_theme_maps.py` depuis `app.dart` : routes, liens littéraux `context.go/push`, liens des hubs thématiques (`ExploreHubScreen`/`_HubCard`, cliquables mais via variable), et `ScreenRegistry`. Aucune donnée saisie à la main.

## TLDR

| | Routes | Signification |
|---|---:|---|
| 🟢 câblée | 4 | un lien cliquable y mène depuis un écran |
| 🟡 séquence | 4 | atteignable seulement via le registre / le coach |
| 🔴 île | 0 | aucun chemin détecté |
| **Total** | **8** | **verdict : PARCOURABLE** (4/8 = 50 % cliquables) |

## Inventaire (routes produit)

| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |
|---|---|---|---|---|
| `/document-scan` | ? | 🟡 séquence | — | oui |
| `/document-scan/avs-guide` | ? | 🟡 séquence | — | oui |
| `/documents` | DocumentsScreen | 🟢 câblée | `widget_renderer` | oui |
| `/documents/:id` | ? | 🟡 séquence | — | oui |
| `/scan` | ? | 🟢 câblée | `avs_guide_screen`, `cap_du_jour_banner`, `coach_chat_screen`, `data_quality_card`, `document_scan_cta`, `financial_summary_screen`, `hero_retirement_card`, `mon_argent_screen` | oui |
| `/scan/avs-guide` | AvsGuideScreen | 🟡 séquence | — | oui |
| `/scan/impact` | ? | 🟢 câblée | `extraction_review_screen` | oui |
| `/scan/review` | ? | 🟢 câblée | `avs_guide_screen`, `document_scan_screen` | oui |

## Graphe des entrées

```mermaid
graph LR
  widget_renderer["widget_renderer"] --> _documents["/documents"]
  avs_guide_screen["avs_guide_screen"] --> _scan["/scan"]
  cap_du_jour_banner["cap_du_jour_banner"] --> _scan["/scan"]
  coach_chat_screen["coach_chat_screen"] --> _scan["/scan"]
  data_quality_card["data_quality_card"] --> _scan["/scan"]
  document_scan_cta["document_scan_cta"] --> _scan["/scan"]
  financial_summary_screen["financial_summary_screen"] --> _scan["/scan"]
  hero_retirement_card["hero_retirement_card"] --> _scan["/scan"]
  mon_argent_screen["mon_argent_screen"] --> _scan["/scan"]
  extraction_review_screen["extraction_review_screen"] --> _scan_impact["/scan/impact"]
  avs_guide_screen["avs_guide_screen"] --> _scan_review["/scan/review"]
  document_scan_screen["document_scan_screen"] --> _scan_review["/scan/review"]
```

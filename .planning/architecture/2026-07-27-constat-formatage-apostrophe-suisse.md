---
description: Constat §3.5 du hand-off 2026-07-27 — il n'existe AUCUN formateur de montants partagé côté backend — au moins 6 fonctions _format_chf privées dupliquées (avec des comportements divergents : préfixe « CHF » ou non) et 15+ fichiers émettant du « {:,.0f} » brut, virgule US « 12,345 » dans des textes user-facing au lieu de l'apostrophe suisse « 12'345 ». La correction est une unité de design (formateur partagé + drain), pas un patch.
---

# Constat — formatage des montants : pas de formateur partagé, virgule US en surface

Item §3.5 du hand-off `2026-07-27-HANDOFF.md` : « Inventorier les surfaces
et identifier s'il existe un formateur partagé avant de toucher. »

## 1. Il n'existe pas de formateur partagé

Le grep `def _format_chf` donne au moins **6 implémentations privées
dupliquées**, chacune dans son service :

| Fichier | Comportement |
|---|---|
| `precision/precision_service.py:952` | préfixe « CHF », apostrophe |
| `disability_gap_service.py:200` | **sans** préfixe, apostrophe |
| `scenario/annual_refresh_service.py:45` (`_format_chf_value`) | à vérifier |
| `pillar_3a_deep/retroactive_3a_service.py:195` | à vérifier |
| `scenario/scenario_narrator_service.py:94` | à vérifier |
| `reengagement/reengagement_engine.py:32` | à vérifier |

Deux comportements différents sont déjà prouvés (préfixe ou non) — le
« formateur partagé » demandé par la question n'existe pas ; il y a six
photocopies divergentes.

## 2. Les surfaces en virgule US

Au moins **15 fichiers** émettent du `{:,.0f}` brut — rendu « 12,345 » (US)
au lieu de « 12'345 » (suisse) — dans des f-strings dont une partie est
user-facing :

`endpoints/coach_chat.py` · `endpoints/fresh_start.py` ·
`endpoints/fiscal.py` · `endpoints/wealth_tax.py` · `housing_sale_service.py`
· `independant_service.py` · `frontalier_service.py` ·
`gender_gap_service.py` · `succession_simulator.py` ·
`document_vision_service.py` · `coaching_engine.py` ·
`document_parser/tax_declaration_parser.py` · `donation_service.py` ·
`rules_engine.py` · `anomaly_detection_service.py`.

Certains sites font `f"{x:,.0f}".replace(",", "'")` à la main (le patron des
`_format_chf`), d'autres émettent la virgule US telle quelle — le tri
site par site n'a pas été fait ici ; c'est la première étape de l'unité de
correction.

## 3. Verdict

La question posée est tranchée : **pas de formateur partagé, dette dupliquée
et divergente**. La correction n'est pas un patch mécanique — c'est une
petite unité de design :

1. créer un formateur canonique unique (emplacement candidat :
   `app/utils/` ou `app/services/formatting.py` — à trancher au moment de
   l'implémentation, avec ou sans préfixe « CHF » selon la surface) ;
2. y drainer les 6 photocopies ;
3. trier les 15 fichiers `{:,.0f}` : user-facing → formateur ; logs/debug →
   laisser ;
4. un lint `--added-only` sur le patron `{:,.0f}` dans les chaînes
   user-facing est le garde-fou naturel (patron #1068 réutilisable).

Pas de décision de Julien requise sur le principe (l'apostrophe suisse est
déjà la convention des `_format_chf` existants) ; l'emplacement du module
partagé est un choix d'implémentation à assumer dans la PR.

## 4. Limites

- « User-facing ou log » n'a pas été qualifié site par site (15 fichiers) ;
  le compte des surfaces réellement visibles peut être inférieur.
- Le côté mobile (Dart `NumberFormat`) n'a pas été inventorié — la
  convention d'affichage y passe par l'i18n Flutter, périmètre distinct.

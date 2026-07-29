---
description: Inventaire §3.3 du hand-off 2026-07-27 — les 16 occurrences du grep « Souscri|Ouvre un|Ouvrez un|Verse le maximum » classées en prescription de produit / instruction de saisie / éducation conditionnelle, avec le statut ComplianceGuard de chaque surface. L'inférence « les sorties déterministes ne traversent jamais le guard » est confirmée pour ces surfaces précises, pas comme universel. Politique et implémentation restent 🔴/⛔.
---

# Inventaire — prescriptions de produit dans les sorties déterministes

Unité §3.3 (phase Inventaire, 🟡) du hand-off `2026-07-27-HANDOFF.md`.
Reproduction : le grep du hand-off, contexte lu pour chaque occurrence.
**Aucune modification de code ici** ; la politique (🔴) et l'implémentation
(⛔) restent bloquées sur les décisions listées en fin de document.

## 1. Grille de lecture

- **P — prescription de produit** : impératif d'achat/souscription d'un
  produit ou d'une classe de produits, a fortiori avec prix ou paramètre de
  contrat. C'est la catégorie au-delà de la ligne selon le hand-off
  (« Souscris une APG privée dès CHF 45/mois »).
- **V — désignation de véhicule légal** : impératif d'ouvrir/utiliser un
  véhicule défini par la loi (compte 3a, testament, désignation de
  bénéficiaire). Le hand-off la traite comme en deçà de la ligne
  (« Ouvrir un compte 3a ») — c'est le point que la décision 🔴 doit trancher.
- **E — éducation conditionnelle** : constat de lacune + explication, sans
  impératif d'achat (« sans IJM, tu n'as aucun revenu en cas de maladie »).

Toutes les occurrences ci-dessous sont **conditionnelles** à une lacune
détectée (sauf les checklists statiques, notées « statique »).

## 2. Les 16 occurrences

| # | Surface | Texte (abrégé) | Classe | Condition | Prix/paramètre |
|---|---|---|---|---|---|
| 1 | `age_band_policy.dart:451` (timeline indépendant) | « Souscrire IJM (URGENCE: 0 couverture sans) » | P | segment indépendant, statique | — |
| 2 | `first_job_service.dart:298` (checklist 1er emploi) | « Souscrire une RC privee (~CHF 5/mois) » | **P + prix** | statique | ~CHF 5/mois |
| 3 | `segments_service.dart:817` | « Souscrivez une assurance IJM individuelle… » | P | `!hasIjm`, urgence « critique » | — |
| 4 | `segments_service.dart:828` | « Souscrivez une assurance accident individuelle. » | P | `!hasLaa` | — |
| 5 | `segments_service.dart:841` | « Ouvrez un 3e pilier et versez le maximum (plafond) » | **V + montant** | `!has3a` | plafond OPP3 |
| 6 | `segments_service.dart:942` | « Souscrire une assurance IJM individuelle : comparer les offres (délai de carence 30/60/90 j, couverture 80 %) » | **P + paramètres** | `!hasIjm` | carence, taux |
| 7 | `segments_service.dart:950` | « Souscrire une assurance accident individuelle (LAA)… » | P | `!hasLaa` | — |
| 8 | `disability_countdown_widget.dart:295` | « Souscris une APG privée (dès CHF 45/mois) » | **P + prix** (cas prouvé du hand-off) | rendu widget coach | dès CHF 45/mois |
| 9 | `independant_service.py:289-293` | « Souscrire une assurance perte de gain maladie… couverture d'au moins 720 jours » | **P + paramètre** | `not a_ijm` | 720 jours |
| 10 | `independant_service.py:304-307` | « Souscrire une assurance accident privee… » | P | lacune LAA | — |
| 11 | `job_comparator.py:617` | « URGENT: Souscrire une IJM individuelle si le nouvel employeur n'en a pas. » | P | `has_ijm -> not has_ijm` | — |
| 12 | `coaching_engine.py:496` | « Ouvrez un compte 3a aupres d'une banque ou d'une assurance et commencez a epargner des maintenant. » | **V** (frontière : « banque ou assurance » oriente le canal) | pas de 3a | — |
| 13 | `concubinage_service.py:391` | « Souscrire une assurance-deces (risque pur)… » | P | checklist concubinage, statique | — |
| 14 | `concubinage_service.py` (même bloc) | « Rediger un testament », « designer ton concubin comme beneficiaire (LPP/3a) » | V/E | statique | — |
| 15 | `first_job/onboarding_service.py:362` | « Souscrire une RC privee (~CHF 5/mois) » — jumeau backend du #2 | **P + prix** | statique | ~CHF 5/mois |
| 16 | `first_job_service.dart:295-304` (reste de la checklist) | « Choisir ta franchise LAMal », « virement épargne automatique (10-20 % du net) » | V/E + **montant** (10-20 %) | statique | 10-20 % |

Aucune occurrence n'est une **instruction de saisie in-app** — la catégorie
prévue par le hand-off est vide sur ce grep. Les classes réellement présentes
sont P, V et E, avec 6 occurrences portant prix ou paramètre de contrat.

## 3. Statut ComplianceGuard de chaque surface — l'inférence §2.2, tranchée

Le grep des références au guard (`compliance_guard|ComplianceGuard`) donne :
`coach_chat.py`, `anonymous_chat.py`, `documents.py`,
`document_vision_service.py`, schémas et modules `compliance/`. Parmi les
endpoints qui servent les services de cet inventaire :

| Endpoint | Sert | Référence compliance ? |
|---|---|---|
| `endpoints/segments.py` | segments_service (miroir), independant_service | **non** |
| `endpoints/job_comparison.py` | job_comparator | **non** |
| `endpoints/family.py` | concubinage_service | **non** |
| `endpoints/coaching.py` | coaching_engine | **non** |
| `endpoints/coach_chat.py` | (coaching_engine via outils coach) | oui |

Verdict : l'universel « les services déterministes ne traversent **jamais**
le guard » était faux comme universel (le guard vit aussi hors chat :
`documents.py`, `document_vision_service.py`). Mais pour **ces surfaces-ci**,
il est confirmé : les textes des lignes 1-16 partent vers le client sans
aucun garde. Nuance : `coaching_engine` a deux chemins — `endpoints/coaching.py`
(sans garde) et le chat coach (gardé) ; le même texte peut donc être gardé ou
non selon la porte d'entrée.

Les surfaces **mobiles** (1-8, 16) sont hors de portée d'un guard backend par
construction : le texte est compilé dans l'app.

## 4. Ce que ce constat ne décide pas (🔴 Julien, hand-off §4.4)

1. Où passe la ligne entre P et V — « Souscris une APG privée dès
   CHF 45/mois » (P + prix) contre « Ouvrir un compte 3a » (V).
2. Le mécanisme : câbler `ComplianceGuard` sur les sorties déterministes
   backend (ne couvre pas les 9 surfaces mobiles), écrire un lint sur les
   impératifs de souscription (couvre les deux côtés, patron
   `banned_terms_python`/`accent_lint_fr` disponible), ou réécrire les
   textes en éducation conditionnelle (E).
3. Ce que deviennent les 6 occurrences à prix/paramètre si la politique les
   interdit — retirer sans remplacer mène au produit vide (reproche explicite
   de l'audit produit).

L'implémentation reste ⛔ tant que la décision n'est pas enregistrée dans
`.planning/decisions/`.

## 5. Limites

- Le grep du hand-off ne capte que quatre motifs impératifs ; des
  prescriptions formulées autrement (« il te faut une IJM », « pense à ton
  assurance ») ne sont pas comptées. L'inventaire est complet **pour ce
  grep**, pas pour le domaine.
- La classification P/V/E est une lecture éditoriale des textes, pas une
  qualification juridique LSFin — c'est l'objet de la décision 🔴.
- Le double chemin de `coaching_engine` (gardé via chat, non gardé via
  `coaching.py`) est établi par grep d'imports, pas par trace d'exécution.

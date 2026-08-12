---
date: 2026-08-05
status: Proposed
authors: Julien Battaglia (demande), Claude (lead, recherche déléguée à deux agents web)
panel: 2-chercheurs-web
supersedes: —
superseded_by: —
description: L'Atlas des écrans se construit (générateur maison depuis les contrats) — aucun outil existant ne couvre la granularité écran+contrat ; quatre patterns éprouvés sont imités.
related:
  - .planning/audit/2026-08-05-atlas-ecosysteme-flutter.md
  - .planning/audit/2026-08-05-atlas-etat-de-lart-hors-flutter.md
  - .planning/decisions/2026-08-04-experience-navigation-compagnon.md
---

# L'Atlas des écrans se construit — il ne s'adopte pas

## TLDR

L'Atlas (page unique générée depuis les contrats scellés : tous les écrans, leur pourquoi, leurs routes, leur statut de gouvernance, plus diagnostics mécaniques de navigation) se construit en générateur maison : la recherche d'état de l'art du 2026-08-05 montre qu'aucun outil existant ne couvre cette combinaison, et quatre patterns éprouvés sont imités plutôt que réinventés.

## Context

Demande du product owner : « un endroit où on peut voir d'un coup tous les écrans et pourquoi ils existent avec leurs routes », avec visibilité sur les illogismes de navigation — et vérification explicite qu'on ne réinvente pas la roue. Deux recherches web indépendantes (écosystème Flutter ; pratiques hors Flutter + agents), mémos complets versés dans `.planning/audit/` (mêmes dates, URLs et signaux de maturité par outil).

## Decision

- **Construire** le générateur maison (contrats YAML scellés → HTML autonome privé). Dans le périmètre de la recherche du 2026-08-05 (bornée, US-centric — voir data gaps) : Widgetbook, le seul acteur Flutter identifié à la fois vivant et mature, est orthogonal (catalogue interactif de composants en isolation, pas d'ingestion de métadonnées externes ; ses capacités clés vivent dans une offre cloud hébergée — écartée par choix de posture : pas d'envoi des rendus produit à un SaaS tiers avant le lancement, décision de confidentialité, pas impossibilité technique) ; les alternatives identifiées sont mortes ou marginales ; l'analyse de Fowler (oct. 2025) ne recense aucun outil SDD projetant des specs vers de la documentation ; aucun linter de graphe de navigation OSS n'a été identifié.
- **Imiter** quatre patterns éprouvés : scorecards de complétude par entité (Backstage), structure exigence→preuve liant chaque statut à son attestation (Serenity BDD living documentation), tags filtrables + identifiant unique par entrée + autodocs (Storybook 9), UX de graphe de routes généré (Compodoc).
- **Adopter** : Mermaid pour les graphes (rendu natif des artifacts) ; goldens Flutter natifs à vraies polices pour les rendus.
- Publication : artifact privé à URL stable tant que le repo est public ; régénération = livrable de clôture de chaque batch ; page générée, jamais rédigée (un champ manquant s'affiche « non contractualisé »).

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?**
  Widgetbook Cloud couvrirait les rendus, les diffs visuels et la revue PR sans code à maintenir, et la niche « single source of truth » de documentation design est en train de mourir commercialement (Backlight et Specify fermés en 2025) — construire dans une niche que le marché abandonne, c'est porter seul la maintenance d'un outil interne de plus.
- **What does this source not address ?**
  Recherche US-centric ; statut d'Overflow.io non tranché ; flowgen.dev évalué via résultats moteur (403 en direct) ; aucun chiffrage du coût de maintenance du générateur sur 12 mois ; pas d'essai concret de Widgetbook sur notre design lab (évaluation documentaire).
- **What would change this conclusion ?**
  Widgetbook ajoutant l'ingestion de métadonnées externes + un export statique monofichier ; le passage du repo en privé ou un assouplissement de la posture SaaS (ouvrant les options hébergées) ; un coût de maintenance mesuré du générateur dépassant le seuil de travail (« quelques heures par mois » — seuil provisoire, à remplacer par la mesure réelle) ; l'émergence d'un OSS « screen registry » crédible (re-vérification semestrielle). Cette décision est prise sur preuve documentaire, avec une v1 déjà en construction et un coût d'entrée faible — elle est réversible ; l'essai concret de Widgetbook sur le design lab est l'action de re-litigation désignée si l'un de ces signaux se déclenche.

## Sources

- `.planning/audit/2026-08-05-atlas-ecosysteme-flutter.md` (Widgetbook, Monarch, Dashbook, alchemist, golden_toolkit abandonné 2024-09-12, DCM, Storybook 9)
- `.planning/audit/2026-08-05-atlas-etat-de-lart-hors-flutter.md` (Backstage, Serenity BDD, Compodoc, Fowler SDD oct. 2025, Flowgen, fermetures Backlight/Specify, ScreenAudit/TaskAudit)

## Status & follow-up

- Implementation tracking : générateur v1 en cours (`generate_atlas.py`, destiné à `tools/` par PR dédiée) ; publication artifact URL stable.
- Re-litigation triggers : les signaux listés ci-dessus ; re-vérification semestrielle de l'écosystème.

---
*Template v1 — Wiki Pattern Karpathy practice 3 enforced by `tools/checks/wiki_lint.py`.*

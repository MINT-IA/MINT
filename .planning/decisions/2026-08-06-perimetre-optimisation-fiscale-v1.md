---
date: 2026-08-06
status: Decided
authors: Claude (Product Leader), validation Julien
panel: single (dossier d'horizon + objection Julien intégrée)
supersedes: —
superseded_by: —
description: Le chantier actif = fermer « Optimisation fiscale v1 » (5 chapitres + écran « Tes leviers ») ; le logement-fiscal en est le chapitre 2, pas un thème séparé.
related:
  - .planning/decisions/2026-08-03-doctrine-reconstruction-mint.md
  - .planning/decisions/2026-07-31-north-star-experience.md
  - .planning/decisions/2026-08-04-experience-navigation-compagnon.md
---

# Le chantier actif ferme « Optimisation fiscale v1 » — le logement-fiscal en est le chapitre 2

## TLDR

Nous fermons le thème « Optimisation fiscale v1 » avant tout autre horizon : cinq
chapitres ordonnés (3a ✅, logement-fiscal, rachats LPP, déductions du quotidien,
lieu) avec un critère de clôture nommé — l'écran « Tes leviers » ; le batch
logement recommandé par le dossier d'horizon reste le prochain batch, recadré
comme chapitre fiscal, pas comme thème séparé.

## Context

Le dossier d'horizon (2026-08-05, moteur exécuté : `estimate_income_tax(120000,
'VD')` = 29 511.84 ; `estimate_tax_saving(120000, 15000, 'VD')` = 5 490.60)
recommandait « élargir sur le logement » comme test de généralisation de la
machinerie. Objection Julien (2026-08-06) : « On était parti sur "optimisation
fiscale" dont le 3a fait partie. Tu ne voudrais pas fermer ce périmètre avant le
logement ? » L'objection est intégrée plutôt que réfutée : le premier batch
logement du dossier est explicitement « mené par le côté déduction » (intérêts
hypothécaires + entretien → `estimate_tax_saving`) — c'est déjà un chapitre
d'optimisation fiscale. L'arc 3a est complet et attesté (parcours 6 écrans,
attestations au sha unique `d218259d1`) ; la série backend mariée est mergée
(#1208, #1209, #1210). Validation Julien : « Je valide » (2026-08-06).

## Decision

Le chantier actif est « Optimisation fiscale v1 », avec ses chapitres ordonnés
et son critère de clôture :

1. **3a** — premier parcours fait (arc R1-R4 attesté, boucle état-civil fermée,
   série backend mariée mergée). Dette qui bloque « fermé » : contrat produit
   marié (pont precision + champ `household_type` de contrat), câblage
   `remaining_room`, **rachats 3a rétroactifs** (OPP3 art. 7a-7b, possibles
   depuis 2025 — déféré gravé au contrat batch22) et **retraits 3a échelonnés**
   (le levier de sortie ; l'écran legacy `/3a-deep/staggered-withdrawal` en
   atteste l'existence métier). Amendé 2026-08-06 (revue Codex) : « fait »
   désignait le parcours, pas l'épuisement des leviers 3a.
2. **Logement-fiscal** — prochain batch, **modèle à deux régimes versionné par
   année fiscale** (amendé 2026-08-06, revue Codex, fait vérifié) : le Conseil
   fédéral a fixé le 1er avril 2026 l'entrée en vigueur de la réforme de
   l'imposition du logement au **1er janvier 2029** — valeur locative supprimée,
   entretien non déductible (sauf biens loués), intérêts passifs partiellement
   déductibles seulement. Régime A (années fiscales ≤ 2028) : déduction
   intérêts + entretien (entièrement fondée sur l'étalon ESTV), valeur locative
   en contre-hypothèse visible tant que ses taux ne sont pas calibrés. Régime
   B (dès 2029) : le levier déduction s'éteint pour le logement propre — l'écran
   le DIT (date d'expiration affichée), jamais une projection au-delà de 2028
   sous le régime A. C'est AUSSI le test de généralisation de la machinerie
   (mécanisme neuf) : l'argument du dossier d'horizon survit intact.
3. **Rachats LPP** — mécanique déduction → économie, mais le cadrage dit la
   nature complète du levier : **effet fiscal + effet prévoyance + liquidité +
   horizon** (amendé 2026-08-06, revue Codex). En particulier LPP art. 79b
   al. 3 : blocage de trois ans du retrait en capital après un rachat — dit à
   l'écran, jamais masqué. Écarté comme tête de série (perception retraite),
   légitime comme chapitre 3 ; le thème reste cadré par événement fiscal, pas
   « retraite-first », sans amputer les conséquences de prévoyance.
4. **Déductions du quotidien** — frais professionnels, formation, garde/enfants
   (le paramètre enfants est déjà dans la file backend).
5. **Lieu** — le levier commune/canton existe à l'éclairage ; sa clôture attend
   le dataset des multiplicateurs communaux (dette nommée).

**Critère de clôture** : l'écran « Tes leviers » — la vue d'ensemble des leviers
fiscaux du profil, chacun avec sa fourchette honnête et ses hypothèses,
présentés **côte à côte, jamais classés** (amendé 2026-08-06, revue Codex :
l'interdit absolu No-Ranking du contrat repo, `docs/AGENTS/swiss-brain.md` §8.4
— un tri par CHF transformerait l'estimation en priorité d'action et ignorerait
liquidité, irréversibilité, effort et applicabilité). L'écran porte une
**matrice d'applicabilité** (un levier non applicable est dit non applicable,
pas caché) et un état honnête « aucun levier pertinent pour ta situation ».
« Fermé » ne signifie pas « tout modélisé » mais « un utilisateur voit ses
leviers fiscaux, chiffrés honnêtement, au même endroit ».

Le coach navigateur-monstrateur reste derrière son ADR d'architecture (où
tourne-t-il ; pré-condition hub), à écrire sans lancer le chantier coach.

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?** La rétention naît de la
  mémoire-compagnon (« l'app se souvient de toi »), pas de la largeur d'un thème
  fiscal : fermer cinq chapitres de calculette avant tout tissu conjonctif peut
  produire une verticale complète que personne ne revient consulter. Si une
  démo/bêta est imminente, un spike coach assumé comme démo frapperait plus fort
  que l'écran « Tes leviers ».
- **What does this source not address ?** Aucune donnée d'usage réelle (pas de
  bêta) ; les taux de valeur locative du régime A ne sont pas calibrés/sourcés
  (déféré déclaré) ; l'effort exact des chapitres 3-5 n'est pas chiffré ;
  l'écran « Tes leviers » n'a ni maquette ni contrat de présentation (côte à
  côte + matrice d'applicabilité restent à spécifier) ; l'ordre des chapitres
  2-3 privilégie des leviers à forte condition d'éligibilité — une matrice
  couverture × applicabilité pourrait faire remonter les déductions du
  quotidien ; la frontière juridique exacte entre information fiscale et
  service financier au sens LSFin n'est pas qualifiée levier par levier.
- **What would change this conclusion ?** Une démo/bêta datée (bascule vers un
  spike coach-démo assumé, cf. ADR architecture coach, trigger 1 — le seul
  déclencheur qui fait repasser le coach devant) ; un trou moteur logement plus
  grand qu'un batch découvert à l'exécution (bascule chapitre 4 devant
  chapitre 2) ; deux chapitres livrés sans réutilisation réelle de la
  machinerie (la « chaîne de production » serait réfutée — re-litiger
  l'approche batch). Amendé 2026-08-06 (revue Codex) : l'ancien déclencheur
  « lab scripté légitime + hub peu coûteux » est retiré — ses deux conditions
  étaient satisfaites par l'ADR coach lui-même sans que la conclusion suive,
  donc il ne déclenchait rien.

## Sources

- Dossier d'horizon : scratchpad session 2026-08-05 (`DOSSIER-HORIZON-elargir-vs-approfondir.md`), moteur exécuté 2026-08-05.
- Moteur : `services/backend/app/services/fiscal/cantonal_comparator.py` (`estimate_income_tax` :448, `estimate_tax_saving` :426) ; `services/backend/app/services/arbitrage/location_vs_propriete.py` ; `apps/mobile/lib/services/financial_core/housing_cost_calculator.dart`.
- Série mariée : PRs #1208 (service L3 `sensibilite_3a_service.py`), #1209 (coach), #1210 (onboarding).
- Arc 3a : branche executor tip `d218259d1` (parcours 6 écrans attesté, runs 31053433101 / 31053533663 / 31053638859).
- Doctrine : `.planning/decisions/2026-08-03-doctrine-reconstruction-mint.md` ; North Star : `.planning/decisions/2026-07-31-north-star-experience.md`.
- No-Ranking : `docs/AGENTS/swiss-brain.md` §8.4 (interdit absolu, side-by-side jamais ranked).
- Réforme imposition du logement : décision du Conseil fédéral du 1er avril 2026, entrée en vigueur 1er janvier 2029 — <https://www.admin.ch/fr/newnsb/yGTqBPowRqyVh0zPokW-q> (consulté 2026-08-06).
- Rachats LPP : LPP art. 79b al. 3 (blocage 3 ans du retrait en capital) — <https://www.fedlex.admin.ch/eli/cc/1983/797_797_797/fr#art_79_b>.

## Status & follow-up

- Implementation tracking : batch logement-fiscal (RED contrat scellé → roast →
  runtime, même gouvernance que l'arc 3a, modèle deux-régimes obligatoire) à
  ouvrir après le scellement de la vague groupée design_lab en cours ; ADR
  architecture coach écrit (Proposed, `2026-08-06-architecture-coach-navigateur-monstrateur.md`).
- Amendement 2026-08-06 : revue destructrice Codex appliquée (réforme logement
  2029 vérifiée deux sources, leviers 3a restants nommés, No-Ranking sur « Tes
  leviers », cadrage complet des rachats LPP, déclencheur inter-ADR réparé).
- Re-litigation triggers : voir « What would change this conclusion ? ».

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

1. **3a** — fait (arc R1-R4 attesté, boucle état-civil fermée, série backend
   mariée mergée). Dette qui bloque « fermé » : contrat produit marié (pont
   precision + champ `household_type` de contrat) et câblage `remaining_room`.
2. **Logement-fiscal** — prochain batch : déduction intérêts + entretien
   (entièrement fondée sur l'étalon ESTV), valeur locative posée en
   contre-hypothèse visible tant que ses taux ne sont pas calibrés (même
   traitement que le multiplicateur communal). C'est AUSSI le test de
   généralisation de la machinerie (mécanisme neuf) : l'argument du dossier
   d'horizon survit intact dans ce cadre.
3. **Rachats LPP** — mécanique identique déduction → économie ; écarté comme
   tête de série (perception retraite), légitime comme chapitre 3 d'un thème
   fiscal déjà large. Framing « déduction », jamais « retraite » (règle
   identitaire : MINT n'est pas une app retraite).
4. **Déductions du quotidien** — frais professionnels, formation, garde/enfants
   (le paramètre enfants est déjà dans la file backend).
5. **Lieu** — le levier commune/canton existe à l'éclairage ; sa clôture attend
   le dataset des multiplicateurs communaux (dette nommée).

**Critère de clôture** : l'écran « Tes leviers » — la vue d'ensemble des leviers
fiscaux du profil, chacun avec sa fourchette honnête et ses hypothèses, classés
par effet pour ce profil. « Fermé » ne signifie pas « tout modélisé » mais « un
utilisateur voit ses leviers fiscaux, chiffrés honnêtement, au même endroit ».

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
  bêta) ; les taux de valeur locative ne sont pas calibrés/sourcés (déféré
  déclaré) ; l'effort exact des chapitres 3-5 n'est pas chiffré ; l'écran « Tes
  leviers » n'a ni maquette ni contrat de ranking (le classement « par effet »
  devra éviter tout langage de recommandation LSFin) ; la réforme valeur
  locative 2028 reste une incertitude législative vive.
- **What would change this conclusion ?** Une démo/bêta imminente (bascule vers
  un spike coach-démo assumé) ; un trou moteur logement plus grand qu'un batch
  découvert à l'exécution (bascule chapitre 4 devant chapitre 2) ; l'ADR
  d'architecture coach tranchant « lab scripté légitime + hub minimal peu
  coûteux » (le coach repasse devant la fin du thème) ; deux chapitres livrés
  sans réutilisation réelle de la machinerie (la « chaîne de production » serait
  réfutée — re-litiger l'approche batch).

## Sources

- Dossier d'horizon : scratchpad session 2026-08-05 (`DOSSIER-HORIZON-elargir-vs-approfondir.md`), moteur exécuté 2026-08-05.
- Moteur : `services/backend/app/services/fiscal/cantonal_comparator.py` (`estimate_income_tax` :448, `estimate_tax_saving` :426) ; `services/backend/app/services/arbitrage/location_vs_propriete.py` ; `apps/mobile/lib/services/financial_core/housing_cost_calculator.dart`.
- Série mariée : PRs #1208 (service L3 `sensibilite_3a_service.py`), #1209 (coach), #1210 (onboarding).
- Arc 3a : branche executor tip `d218259d1` (parcours 6 écrans attesté, runs 31053433101 / 31053533663 / 31053638859).
- Doctrine : `.planning/decisions/2026-08-03-doctrine-reconstruction-mint.md` ; North Star : `.planning/decisions/2026-07-31-north-star-experience.md`.

## Status & follow-up

- Implementation tracking : batch logement-fiscal (RED contrat scellé → roast →
  runtime, même gouvernance que l'arc 3a) à ouvrir après le scellement de la
  vague groupée design_lab en cours ; ADR architecture coach à écrire en
  parallèle.
- Re-litigation triggers : voir « What would change this conclusion ? ».

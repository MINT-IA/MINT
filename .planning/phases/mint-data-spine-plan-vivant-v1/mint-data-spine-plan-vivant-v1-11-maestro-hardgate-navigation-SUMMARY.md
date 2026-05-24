# Summary 11 — Maestro hard-gate navigation

## Resultat

Le flow FATCA hard-gate `flow_hardgate_expat_us.yaml` atteint le waitlist gate et verifie que l'utilisateur expat US ne tombe pas dans le chat generaliste.

## Changements

- Correction de `CoachProfileSeeds.activeSeed` pour accepter les slugs de seed et les slugs d'archetype en mode E2E.
- Ajout d'une couverture test sur le chemin `eclairage_force_kind_test.dart`.
- Plan GSD formalise pour limiter le scope aux defauts de navigation/testability reproductibles.

## Verification locale

- Commit runtime: `9682da8a fix(mobile): resolve e2e archetype seed slugs`.
- Flow Maestro:
  - `.planning/_walker/plan11-g1-20260523T221748/maestro.log`;
  - `.planning/_walker/plan11-g1-postfix-20260523T222623/maestro.log`.
- Les deux traces montrent le parcours complet:
  - waitlist "Encore en chantier pour ton profil" visible;
  - chat "Dis-moi" non visible;
  - consentement, email et success state "Merci, on revient vers toi" visibles;
  - assertion LSFin negative sur les termes interdits;
  - retour accueil execute.

## Limite volontaire

Cette phase ne refond pas la navigation. Elle ferme le premier blocker deterministe du hard-gate et laisse les flows plus larges au perfect-set navigation suivant.

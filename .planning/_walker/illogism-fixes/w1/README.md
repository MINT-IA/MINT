# Device-proof W1 — repro (DEFERRED-TO-ORCHESTRATOR)

Le walkthrough sim de clôture W1 (plan 05 Task 2) n'a PAS été exécuté dans le
worktree executor isolé : un `flutter build ios --simulator` complet depuis un
worktree git partage le cache CocoaPods / DerivedData du checkout principal et
viole la doctrine de build macOS Tahoe (CLAUDE.md — pas de reset destructif,
pas de retrait du lock ios). L'objectif orchestrateur autorise explicitement ce
deferral quand une contrainte de build s'applique dans le worktree.

Le code + les tests du plan 05 sont COMPLETS et vérifiés déterministiquement
(RED→GREEN, 26/26 parité W1-W5, 5844/5844 services, `flutter analyze` clean).
Le device-proof est une preuve §9.2 SUPPLÉMENTAIRE (tests verts ≠ feature
working) à exécuter post-merge par l'orchestrateur sur le checkout principal.

## Quantités W1 à prouver à l'écran (5, plans 01-05)

Pour un même input dans la même session, AUCUNE ne doit afficher deux valeurs
différentes inter-écrans (home hero, mon-argent, response cards, mariage) :

1. Avoir LPP identique inter-écrans (plan 01)
2. Rente LPP unique (plan 02)
3. Taux de remplacement unique (plan 03)
4. Plafond 3a 17280 (indépendant net) / 7258 (salarié LPP) selon archétype (plan 04)
5. Économie d'impôt 3a au barème marié (plan 05) — un marié voit ~1194 CHF
   (et non 1405 CHF célibataire), identique en onboarding et en response card.

## Profils à dérouler

- Marié salarié 102000 (VD ou GE) — preuve quantité #5 (barème marié) + #1-#3.
- Indépendant net 86400 — preuve quantité #4 (plafond 17280, pas 21600).

## Commandes exactes (checkout principal, sim booté)

Pré-requis : sim iOS booté (`xcrun simctl list devices booted`), Maestro CLI
(`/Users/julienbattaglia/.maestro/bin/maestro`), env staging
(`SENTRY_AUTH_TOKEN` chargé depuis le Keychain — vérifié OK au dry-run),
`SENTRY_DSN_STAGING`, `MINT_DEV_AUTH_TOKEN`. L'app cible Railway staging
(`https://mint-staging.up.railway.app/api/v1`) — NE JAMAIS lancer un backend
local (memory app_targets_staging_always).

Workaround build (RESEARCH §1.4, engram #1595) depuis le checkout principal :

```bash
cd /Users/julienbattaglia/Desktop/MINT.nosync
ln -s /tmp/mint_build_ios apps/mobile/build   # si apps/mobile/build absent
cd apps/mobile && flutter build ios --simulator --no-codesign \
  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1
```

Walkthrough archetype-driven (driver canonique, dry-run validé) :

```bash
# Marié salarié — preuve barème marié 3a + LPP/rente/taux uniques
bash tools/simulator/walker.sh --archetype swiss_native --scenario fiscalite

# Indépendant — preuve plafond 3a 17280 (net), pas 21600 (brut)
bash tools/simulator/walker.sh --archetype independent_no_lpp --scenario fiscalite
```

Sorties screenshots : `screenshots/walkthrough/v2.10-final/<slug>/<scenario>/`.
Copier au moins 3 captures preuves ici (`.planning/_walker/illogism-fixes/w1/`)
en les renommant pour citer la quantité prouvée, p.ex. :

- `w1-marie-economie-3a-onboarding.png`
- `w1-marie-economie-3a-response-card.png`
- `w1-independant-plafond-3a-17280.png`

## Critère d'acceptation (plan 05 Task 2)

- ≥3 captures nommées citées dans le SUMMARY prouvant les valeurs uniques à
  l'écran (0-TRUST §9.2).
- Aucune des 5 quantités W1 n'affiche deux valeurs différentes pour le même
  input dans la même session.

## Dry-run vérifié dans le worktree (preuve de validité d'invocation)

```
$ bash tools/simulator/walker.sh --archetype swiss_native --scenario fiscalite --dry-run
[walker] mode=--archetype-walkthrough device='iPhone 17 Pro'
[walker] SENTRY_AUTH_TOKEN loaded from Keychain
[walker] archetype-walkthrough: prompt=Comment pourrais-je envisager mon 3a cette année ?
[walker] DRY-RUN: would build sim with --dart-define=MINT_E2E_ARCHETYPE=swiss_native ...
[walker] archetype-walkthrough: DRY-RUN done — filesystem unchanged
```

Seul le build/install/capture réel reste à exécuter post-merge.

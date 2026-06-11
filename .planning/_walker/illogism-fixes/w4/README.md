# W4 — Device-proof scène rente_trouée (DEFERRED to orchestrator)

> Plan : `mint-illogism-fixes-13-w4-avs-gapfactor`. Deux captures attendues,
> déférées au device-gate orchestrateur (mêmes contraintes build worktree que
> W1, cf. commit `d755c06af`). 0-TRUST : aucune capture fabriquée ici.

## Statut

- **Sim booté au moment de l'exécution** : NON (`xcrun simctl list devices booted` → vide).
- **Maestro disponible** : oui (`~/.maestro/bin/maestro`).
- **Décision** : l'exécuteur séquentiel ne boote pas de sim / ne lance pas de
  build dans ce contexte (précédent W1). Les preuves visuelles sont produites
  par le device-gate orchestrateur après merge des plans de la vague.

## Captures à produire (device-gate)

1. **`scene-lacunes.png`** — onboarding intent « retraite », profil Suisse de
   retour (statut AVS « arrivé tard », arrivée 43 ans). Attendu : chiffre héros
   `CHF X – Y / mois` nettement sous la rente MAX (la composante AVS intègre le
   gapFactor). PAS d'étiquette « hypothèse : carrière complète ».

2. **`scene-jeune-etiquete.png`** — onboarding intent « retraite », profil jeune
   (~25 ans) sans lacune. Attendu : sous le sous-titre `/ mois, dès 65 ans`,
   l'étiquette italique **« hypothèse : carrière complète »** (clé ARB
   `onboardingSceneFullCareerAssumption`, 6 langues).

## Preuves déterministes déjà citées (tests verts, en l'absence de sim)

- `flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart --plain-name "W4 — Scène rente_trouée honnête"` → +3 All tests passed.
- `flutter test test/services/financial_parity_test.dart --plain-name "Parity W4 — Rente AVS"` → +4 All tests passed.
- `grep -n "0\.34" mint_scene_rente_trouee.dart` → seulement commentaires (0 code live).
- `python3 tools/checks/arb_parity.py` → 6 locales, 6915 clés each.

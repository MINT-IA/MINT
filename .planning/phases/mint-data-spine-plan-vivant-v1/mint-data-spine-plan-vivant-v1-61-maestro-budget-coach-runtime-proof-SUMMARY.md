description: Plan 61 valide en simulateur le chemin Mon Argent, Budget et Coach avec garde-fous numériques.

# Summary — Plan 61 Maestro Budget Coach Runtime Proof

## Fait

- Build iOS simulateur relancé avec `julien_swiss` et beta modal désactivée.
- Premier build sans bypass codesign refusé par les xattrs Tahoe ; relance
  réussie avec `CODE_SIGNING_ALLOWED=NO` et `--no-codesign`, conformément aux
  scripts walker existants.
- App installée sur iPhone 17 Pro iOS 26.2.
- Flow Maestro `flow_mon_argent_budget_setup_spine.yaml` exécuté via watchdog.

## Vérifié

- `flow_mon_argent_budget_setup_spine` → passé en 37s.
- JUnit : `.planning/walker/maestro-flows/mon-argent-budget-plan61/20260525T152447Z/result.xml`
  avec `failures="0"`.
- Le budget saisi `2200` + `420` est restauré sur `/budget`.
- Les garde-fous runtime ont tenu :
  - `19'272'200` absent.
  - `420'420` absent.
- Le retour vers `/coach/chat` garde les ancres `coach_input_field`,
  `coach_lightning_menu_button` et `coach_send_button`.

## Observations produit

- Le budget direct relaunch affiche des chiffres cohérents :
  revenu net `CHF 5'379`, logement `CHF 2'200`, LAMal `CHF 420`, disponible
  `CHF 2'239`.
- Le coach affiche désormais une phrase 3a plus saine : `Jusqu'à 7258 CHF
  encore déductibles`, donc plus d'amalgame visible avec une économie fiscale.
- Petit polish restant : formatter ce plafond en `7'258 CHF` dans cette bulle
  coach.

## Reste

- Lancer une phase courte pour formatter le plafond 3a dans les bulles coach.
- Étendre ensuite la preuve Maestro aux profils avec contribution 3a planifiée
  non nulle.

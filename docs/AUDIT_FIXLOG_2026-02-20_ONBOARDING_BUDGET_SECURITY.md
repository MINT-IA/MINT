# Audit Fix Log — Onboarding / Budget / Security (2026-02-20)

## Scope
Corrections issues remontées sur 8 captures (LPP, check-in, budget, login, onboarding, safe-mode).

## Findings & Fixes

### F-01 (CRIT) — API login fail sur build mobile (localhost)
- Symptom: `ClientException ... localhost:8888` sur écran création compte.
- Root cause: `ApiService.baseUrl` fallback hardcodé `http://localhost:8888/api/v1` même hors dev.
- Fix:
  - fallback dynamique:
    - release: `https://api.mint.ch/api/v1`
    - debug: `http://localhost:8888/api/v1`
  - `API_BASE_URL` via `--dart-define` garde la priorité.
- Files:
  - `apps/mobile/lib/services/api_service.dart`
  - `apps/mobile/test/services/api_service_test.dart`

### F-02 (CRIT) — Sur-estimation possible économie fiscale rachat LPP en bloc
- Symptom: montant d’économie perçu irréaliste sur gros rachat.
- Root cause: simulation autorisait une déduction implicite au-delà du revenu imposable.
- Fix:
  - cap strict `deduction <= income`
  - courbe de taux effectif rendue plus décroissante par tranche.
- Files:
  - `apps/mobile/lib/services/lpp_deep_service.dart`
  - `apps/mobile/test/services/lpp_deep_service_test.dart`

### F-03 (MAJEUR) — Check-in affiche parfois `Capital projeté +CHF 0` malgré versements
- Symptom: carte d’impact à `+CHF 0` alors que versements > 0.
- Root cause: delta basé uniquement sur projection avant/après pouvant rester nul si plan inchangé.
- Fix:
  - ajout d’un fallback d’impact “1 mois de versements projeté à l’objectif” par catégorie d’actif.
- Files:
  - `apps/mobile/lib/services/forecaster_service.dart`
  - `apps/mobile/lib/screens/coach/coach_checkin_screen.dart`

### F-04 (MAJEUR) — Budget incomplet (impôts/LAMal/fixes absents)
- Symptom: “disponible” surévalué car charges fixes majeures non prises en compte.
- Root cause: modèle budget initial limité à revenu/logement/dettes.
- Fix:
  - extension modèle budget: `taxProvision`, `healthInsurance`, `otherFixedCosts`
  - calcul `available` corrigé partout
  - affichage détaillé dans écran budget + carte budget rapport
  - estimation impôts mensuels + estimation LAMal si non renseigné
- Files:
  - `apps/mobile/lib/domain/budget/budget_inputs.dart`
  - `apps/mobile/lib/domain/budget/budget_service.dart`
  - `apps/mobile/lib/screens/budget/budget_screen.dart`
  - `apps/mobile/lib/widgets/report/budget_waterfall.dart`
  - `apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart`
  - `apps/mobile/test/domain/budget_service_test.dart`

### F-05 (MOYEN) — Message safe-mode trop opaque (“Pourquoi bloqué ?”)
- Symptom: cartes grisées sans explication actionnable.
- Fix:
  - `SafeModeGate` enrichi: raisons explicites (liste), bottom-sheet explicatif, CTA direct vers plan de désendettement.
  - calcul `hasDebt` harmonisé via `WizardService.isSafeModeActive`.
- Files:
  - `apps/mobile/lib/widgets/common/safe_mode_gate.dart`
  - `apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart`

### F-06 (MOYEN) — Aha Step 2 onboarding ambigu (“1000 pour 100000”)
- Symptom: confusion entre impôt total, écart vs moyenne CH et points de taux.
- Fix:
  - ajout d’indicateurs explicites dans la carte:
    - taux marginal estimé
    - impôt indicatif sur CHF 100k
    - écart vs moyenne CH (CHF)
- Files:
  - `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`

### F-07 (MOYEN) — Transition des cercles onboarding peu parlante / timing
- Symptom: écran transition trop passif et texte dense.
- Fix:
  - auto-advance (~2.6s) + conservation du bouton manuel
  - libellés simplifiés
  - progression “Cercle 1/3, 2/3, 3/3” affichée explicitement.
- Files:
  - `apps/mobile/lib/widgets/circle_transition_widget.dart`
  - `apps/mobile/lib/screens/advisor/advisor_wizard_screen_v2.dart`

## Validation run
- A exécuter après merge local:
  - `flutter analyze`
  - `flutter test test/services/api_service_test.dart`
  - `flutter test test/services/lpp_deep_service_test.dart`
  - `flutter test test/domain/budget_service_test.dart`

### F-08 (MAJEUR) — Mini-onboarding non adaptatif au foyer
- Symptom: préremplissage fiscal/LAMal basé sur célibataire par défaut, sans prise en compte couple/famille.
- Root cause: absence de variable `household` dans le mini-onboarding et persistance partielle insuffisante.
- Fix:
  - ajout choix foyer dans l’étape revenu/statut: `single`, `couple`, `family`
  - persistance mini-onboarding: `q_household_type`
  - inférences cohérentes pour calculs précoces: `q_civil_status`, `q_children`
  - préremplissage impôts/LAMal désormais dépendant du foyer + âge réel si disponible
  - segmentation cohortes onboarding enrichie avec `house_*`
- Files:
  - `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`

### F-09 (MOYEN) — Onboarding encore chargé (Step 4 + Aha + debug quality)
- Symptom: Step 4 perçu comme trop dense, Aha Step 2 encore ambigu sur unités, panel debug trop global.
- Fix:
  - Step 4: simplification cognitive avec rappel de priorité active (1 choix clair avant activation dashboard).
  - Aha Step 2: chips reformulés avec unités explicites (`%`, `CHF/an`, `pts`) pour éviter confusion “par 100k”.
  - Debug metrics: ajout d’un bloc “Qualité par step” (conversions S1→S2→S3→S4→Done + temps moyen par step).
- Files:
  - `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`

### F-10 (MOYEN) — Faible perception de progression immédiate
- Symptom: onboarding jugé “flou”, peu de feedback entre les steps.
- Fix:
  - micro-feedback de validation ajouté en fin des steps 1, 2, 3 quand la donnée minimale est prête.
  - carte “Ce que MINT a compris” ajoutée en step 4 avant activation dashboard (priorité, profil, base fiscale, revenu, charges fixes captées).
  - i18n: nouvelles clés dédiées ajoutées (FR/EN/DE/IT/ES/PT).
- Files:
  - `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`
  - `apps/mobile/lib/l10n/app_fr.arb`
  - `apps/mobile/lib/l10n/app_en.arb`
  - `apps/mobile/lib/l10n/app_de.arb`
  - `apps/mobile/lib/l10n/app_it.arb`
  - `apps/mobile/lib/l10n/app_es.arb`
  - `apps/mobile/lib/l10n/app_pt.arb`

### F-11 (MAJEUR) — Reprise fragile si app fermée en cours de saisie
- Symptom: une partie des infos pouvait être perdue si l’app était tuée avant transition d’étape.
- Fix:
  - autosave debounced sur interactions clés (stress, année, canton, revenu, statut, foyer, coûts fixes, objectif).
  - persistance draft explicite (`mini_draft_*`) pour champs incomplets.
  - hydratation reprend maintenant les valeurs draft si les valeurs finales ne sont pas encore valides.
- Files:
  - `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`

### F-12 (STRUCTURE) — Début refonte monolithe onboarding (Phase 0/1/2)
- Symptom: `advisor_onboarding_screen.dart` (3396 lignes) mélange UI, persistence, analytics, calculs, métriques.
- Fix (incrémental, sans régression produit):
  - Phase 0: création `OnboardingProvider` (état, validations, snapshot, autosave, completion, preview, Aha).
  - Phase 1: création `OnboardingConstants` et remplacement des magic numbers critiques dans l'écran existant.
  - Phase 2: création d'un UI kit onboarding (`MintSelectableCard`, `MintQuickPickChips`, `MintChfInputField`, `OnboardingInsightCard`, `OnboardingStepHeader`, `OnboardingContinueButton`).
  - Phase 3 (préparation): création des 4 widgets de step (`stress`, `essentials`, `income`, `goal`) + helper analytics + metrics panel extrait.
  - App bootstrap: enregistrement de `OnboardingProvider` dans `MultiProvider`.
- Tests ajoutés:
  - `test/providers/onboarding_provider_test.dart`
  - `test/widgets/onboarding_widgets_test.dart`
  - `test/screens/onboarding_steps_test.dart`

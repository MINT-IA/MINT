---
phase: mint-data-spine-plan-vivant-v1
plan: 13
type: flutter-tdd
wave: 13
depends_on:
  - mint-data-spine-plan-vivant-v1-12-drawer-navigation-smoke-PLAN.md
files_modified:
  - apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  - apps/mobile/lib/widgets/coach/lightning_menu.dart
  - apps/mobile/lib/providers/coach_profile_provider.dart
  - apps/mobile/test/screens/onboarding/data_block_enrichment_screen_test.dart
  - apps/mobile/test/widgets/coach/lightning_menu_readiness_resolver_test.dart
autonomous: true
requirements:
  - REQ-DSP-13
must_haves:
  truths:
    - "The user's current financial situation must have a deterministic capture path."
    - "`complete_situation` must not route to a read-only dashboard."
    - "Every captured value must persist through `CoachProfileProvider.mergeAnswers` into `wizard_answers_v2`."
    - "The plan must reuse the current data spine and budget keys, not create another persistence system."
---

# Plan 13 — Capture situation + budget depuis la readiness

## TLDR

Transformer la prochaine action `complete_situation` en vrai chemin de capture structuré: revenu, canton/âge, liquidités et dette mensuelle doivent pouvoir être saisis, persistés, relus par `CoachProfile`, puis reflétés dans `DataSpineSnapshot`.

## Contexte

Plans 06 à 10 ont branché la readiness jusque dans le coach packet et le menu éclair.
Le flux est maintenant:

```text
CoachProfile -> DataSpineSnapshot -> DataSpineReadinessDigest
  -> coach_context_packet.readiness.next_action_id
  -> LightningMenu
```

Mais `complete_situation` et `define_target` pointent encore vers `/profile/bilan`, qui est un bilan consultatif. C'est une façade: l'utilisateur peut voir qu'il manque des données, mais il n'a pas un chemin déterministe pour les écrire.

Le prochain incrément doit corriger ça avant de continuer les visualisations de trajectoire.

## Scope

### Task 1 — RED: route readiness vers une capture réelle

Étendre les tests du menu éclair:

- `complete_situation` doit router vers `/data-block/situation`.
- `define_target` doit router vers `/data-block/objectifRetraite` ou rester explicitement documenté si la route cible est encore différée.
- `stabilize_budget` reste `/budget/setup`.
- Les IDs internes ne doivent jamais apparaître comme texte visible ni comme prompt envoyé au chat.

### Task 2 — RED: écran situation écrit les clés canoniques

Ajouter ou étendre un test widget pour `DataBlockEnrichmentScreen(blockType: 'situation')`:

- champs visibles minimum:
  - année de naissance;
  - canton;
  - revenu net mensuel;
  - liquidités;
  - dette mensuelle ou zéro dette;
- sauvegarde via `CoachProfileProvider.mergeAnswers`;
- clés attendues:
  - `q_birth_year`;
  - `q_canton`;
  - `q_net_income_period_chf`;
  - `q_pay_frequency = monthly`;
  - `q_cash_total`;
  - `q_has_consumer_debt`;
  - `q_debt_payments_period_chf` si dette mensuelle saisie.

Ne pas écrire directement dans SharedPreferences depuis l'écran.

### Task 3 — Implémenter la capture situation dans `/data-block/situation`

Réutiliser `DataBlockEnrichmentScreen` plutôt qu'ajouter une nouvelle route.

Comportement attendu:

- `blockType=situation`, `revenu`, `income`, `salary`, `age_canton` normalisent vers le même bloc canonique `situation`.
- L'écran pré-remplit depuis `CoachProfileProvider.profile`.
- Le bouton de sauvegarde appelle `mergeAnswers`.
- Après sauvegarde, l'utilisateur revient vers `/coach/chat` ou l'écran précédent avec un état profil rafraîchi.
- Le texte visible passe par ARB si de nouvelles strings user-facing sont nécessaires.

### Task 4 — Prouver la dérivation data-spine après sauvegarde

Ajouter un test service ou widget qui vérifie le chaînage:

```text
mergeAnswers(partial situation)
  -> CoachProfile.fromWizardAnswers
  -> DataSpineService.fromProfile
  -> readiness missingDomains ne contient plus situation
```

Ce test doit couvrir au moins un profil qui était `complete_situation` avant saisie.

### Task 5 — Vérification ciblée

Commandes minimum:

```bash
cd apps/mobile && flutter test test/widgets/coach/lightning_menu_readiness_resolver_test.dart test/screens/onboarding/data_block_enrichment_screen_test.dart test/services/data_spine_readiness_digest_service_test.dart test/services/data_spine_service_test.dart
cd apps/mobile && flutter analyze lib/widgets/coach/lightning_menu.dart lib/screens/onboarding/data_block_enrichment_screen.dart test/widgets/coach/lightning_menu_readiness_resolver_test.dart test/screens/onboarding/data_block_enrichment_screen_test.dart
python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb
./tools/mint-routes redirects
git diff --check
```

Si des ARB changent:

```bash
cd apps/mobile && flutter gen-l10n
```

## Non-Goals

- Pas de nouvelle route si `/data-block/:type` suffit.
- Pas de refonte du menu éclair.
- Pas de refonte visuelle du budget.
- Pas de nouveau calcul financier.
- Pas de backend ni de migration de persistance.
- Pas de planification long terme complète; ce plan ne capture que les variables nécessaires pour rendre la situation actuelle exploitable.

## Risques

- `DataBlockEnrichmentScreen` contient déjà des routes et prompts legacy avec du texte FR non finalisé. Ne pas nettoyer tout l'écran dans ce plan: corriger uniquement ce qui est nécessaire au bloc `situation`.
- `q_total_debt_balance_chf` existe dans les questions wizard mais `CoachProfile.fromWizardAnswers` lit surtout `q_debt_payments_period_chf` et `_coach_dettes_*`. Pour v1, capturer la dette mensuelle est le chemin qui alimente le budget et la readiness sans ajouter une nouvelle sémantique.
- `q_cash_total` alimente la situation mais pas un budget mensuel. Ne pas le mélanger avec `monthlyFree`.

## Done

- `complete_situation` ne route plus vers `/profile/bilan`.
- Un utilisateur peut saisir les variables de situation essentielles depuis une action readiness.
- Les valeurs persistent via `mergeAnswers`.
- `DataSpineSnapshot.situation` reflète les valeurs après relance logique.
- Tests ciblés et analyse ciblée verts.

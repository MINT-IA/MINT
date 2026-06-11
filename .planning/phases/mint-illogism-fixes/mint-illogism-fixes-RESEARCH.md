# Phase mint-illogism-fixes — Research

**Researched:** 2026-06-11
**Method:** Distillation de l'audit 2026-06-09→11 — 48 findings produits par 8 agents-archétypes avec oracles Python déterministes, 44 confirmés par agents adverses indépendants (workflow `wf_c24eea46-992`), + grounding device sim iPhone 16e (build staging). Ce document N'EST PAS une re-découverte : chaque claim ci-dessous a déjà une reproduction citée dans la matrice. Confiance plus haute qu'une recherche standard.

## 1. Domain — ce que le planner doit savoir

### 1.1 La maladie systémique (W1)
Chaque quantité financière a 2-4 implémentations qui ne passent PAS par `financial_core`. Pattern récurrent identifié :
- `coach_profile.dart` (modèle) a ses propres `_estimateLppAvoir`/`_estimate3aTotal` inline.
- `minimal_profile_service.dart` (onboarding) a les siens (`_estimateLppBalance`, replacement rate brut).
- `response_card_service.dart` (cartes coach) a les siens (taux 0.058, replacement net).
- Les écrans (`mariage_screen.dart:94`) hardcodent des constantes (0.068).

La cible canonique EXISTE et est correcte : `lpp_calculator.dart` (`computeSalaireCoordonne` :201-205 fait le double clamp ; `adjustedConversionRate` :43-52 gère la retraite anticipée LPP art.13 al.2 ; `projectToRetirement` projette). `tax_calculator.dart:535` `estimate3aTaxImpact(..., isMarried, children)` accepte déjà les paramètres que les appelants omettent. **Le travail W1 est un re-câblage, pas une création.**

Chiffres de divergence mesurés (oracles, repro dans la matrice) : LPP +15.4% (102k revenu) à +105% (162k) ; rente 250-347 CHF/mois ; remplacement 10-20 pts ; 3a indépendant +25% ; économie 3a +17.6%.

### 1.2 Le gap d'archétype (W2)
L'onboarding (`apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart`, flux T1-T9) ne demande NI statut d'emploi NI état civil NI lacunes AVS. Tout passe par les wizard answers `q_*` (stockage `SecureWizardStore`, hydratation `CoachProfileProvider` → `CoachProfile.fromWizardAnswers`). Les clés existent déjà : `q_employment_status`, `q_household_type`, `q_avs_lacunes_status`, `q_avs_arrival_year` (cf. `coach_profile.dart:2801-2827` qui les lit déjà). Le backend Profile a `employmentStatus`, `selfEmployedNetIncome`, `usTaxPerson` (SOT §1). **Le travail W2 est d'ajouter les étapes UI qui peuplent des champs déjà câblés**, puis d'unifier les prédicats de gate (employmentStatus vs q_has_pension_fund — deux moteurs, deux prédicats, cf. matrice independent_no_lpp-3).

FATCA : le seul gate runtime est `coach_chat_screen.dart:1828-1864` (`evaluateCoachArchetypeGate`). Le redirect global GoRouter (`app.dart:234-317`) ne branche que sur l'auth scope — y ajouter une branche archétype est le pattern attendu (les `ScopedGoRoute` existent déjà).

### 1.3 Discipline estimé (W3)
`ProfileDataSource` (SOT §4) et `EnhancedConfidence` (confidence_scorer.dart) existent et sont câblés à 86 endroits. Le problème est l'AFFICHAGE : `/home` hero ignore le gate ; Mon Argent>Prévoyance affiche déjà le badge « estimé » (pattern à généraliser). RvC : `_autoFillFromProfile` (rente_vs_capital_screen.dart:180-215) a déjà le flag `hasEstimates` — le bug est que les défauts hardcodés (:62-66) bypassent ce chemin.

### 1.4 Pièges connus (obligatoires pour le planner)
- **i18n** : toute nouvelle string user-facing → `AppLocalizations` + 6 ARB + `flutter gen-l10n` + `validate_arb_parity()`. Accents FR stricts (`accent_lint_fr.py`).
- **Termes bannis** : « garanti/optimal/meilleur/parfait » interdits dans les nouvelles strings (`check_banned_terms`).
- **Design system** : MintColors/MintUI kit, jamais de `Color(0xFF...)` ; GoRouter, jamais `Navigator.push`.
- **Pré-commit lefthook** : `banned-terms-arb-gate` + `arb-parity-gate` HARD sur `*.arb`.
- **Build sim local** : codesign `.nosync` cassé → workaround `ln -s /tmp/mint_build_ios apps/mobile/build` puis `flutter build ios --simulator --no-codesign --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1` (vérifié 2026-06-11, engram #1595).
- **iOS entitlements** : aucun nouveau `com.apple.developer.*` (release-blocking, memory `feedback_ios_entitlements_block_testflight`) — non concerné par cette phase a priori (Semantics est pur Flutter).
- **ILLOG-02 d'abord** : tant que l'arbre AX de RvC est vide, AUCUNE assertion Maestro ne peut tourner sur cet écran — W5/ILLOG02 doit précéder le gate Maestro de W3/ILLOG01 (dépendance inter-vagues explicite).
- **Tests existants** : ~9300 tests Flutter ; les sites modifiés sont couverts — s'attendre à des snapshots/goldens à mettre à jour, ne PAS les contourner.

## 2. Approach — patterns recommandés

1. **W1 par quantité, pas par fichier** : une PR = une quantité (ex. « rente LPP → adjustedConversionRate partout ») avec un test de parité (calcule par tous les chemins d'appel, assert égalité au centime). Le test de parité est l'anti-régression de toute la classe.
2. **Strangler-fig** : les fonctions inline deviennent des façades dépréciées qui délèguent à financial_core (D-11), supprimées en fin de vague — évite un big-bang.
3. **W2** : nouvelles étapes onboarding = scènes existantes du wedge (pattern T3-T5), réutiliser `MintScene*`; les réponses peuplent les `q_*` déjà lus.
4. **Acceptance par ligne de matrice** : chaque tâche cite les IDs de findings qu'elle ferme (ex. `salarie_swiss-2`) ; vérification = re-run de l'oracle de reproduction de la ligne + device-proof.
5. **Device-proof par vague** : un walkthrough sim (build workaround) + capture, par vague — pas seulement « tests verts » (0-TRUST §9.2).

## 3. Validation Architecture

- **Oracles déterministes** : chaque ligne de matrice porte une reproduction Python/grep re-runnable — re-runner l'oracle après fix = critère de fermeture binaire.
- **Tests de parité** (nouveaux, W1) : par quantité, tous chemins d'appel → même valeur.
- **Flows Maestro de régression** : `bug__ILLOG02__rvc_ax_tree_empty.yaml` puis `bug__ILLOG01__rvc_fiction_defaults.yaml` (OPEN-RED → GREEN). Nouveaux flows par fix device-visible (convention D-36, `_INDEX.md`).
- **Suites mécaniques** : `flutter analyze` + `flutter test` + `accent_lint_fr` + `arb_parity` + `banned_terms` (lefthook + CI).
- **Sim walkthrough** par vague sur iPhone 16e (workaround build), captures dans `.planning/_walker/`.
- **Anti-claim** : aucun « fermé » sans (oracle re-run vert + citation) — la matrice est le tracker, pas la narration.

## 4. Open Questions (planner doit trancher ou escalader)
- Le dénominateur canonique du taux de remplacement : NET courant recommandé (sens utilisateur) — à confirmer avec un golden test Julien/Lauren si disponible.
- Mécanisme exact de la fiabilité divergente 44%/50%/30% (D12) : deux moteurs de confiance (`EnhancedConfidence.combined` géométrique vs `ConfidenceBreakdown.overall` pondéré, cf. SOT §3 NOTE) — candidat racine, à vérifier en W3.
- Provenance exacte du « 43'691 » home hero (estimateur sur quel salaire) — tracer en W1 lors du re-câblage (non-bloquant : le re-câblage le rend canonique de fait).

---
*Research distilled 2026-06-11 from adversarially-verified matrix + device session. Stronger provenance than standard RESEARCH.md: every claim above carries a reproduction in the matrix.*

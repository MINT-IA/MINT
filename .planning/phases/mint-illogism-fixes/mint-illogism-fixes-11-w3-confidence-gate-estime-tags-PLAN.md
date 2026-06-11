---
phase: mint-illogism-fixes
plan: 11
type: execute
wave: 9
depends_on: [mint-illogism-fixes-07, mint-illogism-fixes-10]
files_modified:
  - apps/mobile/lib/widgets/coach/widget_renderer.dart
  - apps/mobile/lib/widgets/pulse/cap_sequence_card.dart
  - apps/mobile/lib/services/financial_core/confidence_scorer.dart
  - apps/mobile/lib/services/minimal_profile_service.dart
  - apps/mobile/lib/l10n/app_fr.arb
  - apps/mobile/lib/l10n/app_en.arb
  - apps/mobile/lib/l10n/app_de.arb
  - apps/mobile/lib/l10n/app_es.arb
  - apps/mobile/lib/l10n/app_it.arb
  - apps/mobile/lib/l10n/app_pt.arb
  - apps/mobile/test/widgets/home_hero_confidence_test.dart
autonomous: true
requirements:
  - MATRIX-D2
  - MATRIX-D12
  - MATRIX-jeune_diplome-5
must_haves:
  truths:
    - "SOT §5 Confidence Gate APPLIQUÉ : combined <50 → l'affichage du chiffre vedette est gated (demande de données à la place) ; <70 → bandes d'incertitude obligatoires."
    - "Un hero number ne vient JAMAIS d'un estimateur : états connu (certificat/saisie) / estimé (étiqueté, pousse vers le scan) / inconnu (demande). Fin du « 43'691 Avoir LPP » nu avec Fiabilité 44% (D2)."
    - "UNE source de confiance par profil : fin de l'incohérence 44% (Mon Argent) vs 50% (RvC) vs 30% (Marc, données réelles) — D12, mécanisme élucidé et unifié."
    - "Toute valeur issue d'un estimateur porte le tag « estimé » sur TOUTES les surfaces (le pattern Mon Argent>Prévoyance généralisé), y compris liquidityMonths=0 artefact du jeune (jeune_diplome-5)."
    - "Statut d'emploi inconnu → pas de chiffre archétype-dépendant en vedette : demander ou étiqueter « hypothèse : salarié » (lock CONTEXT W2)."
  artifacts:
    - path: "apps/mobile/test/widgets/home_hero_confidence_test.dart"
      provides: "Tests : confidence <50 → hero gated ; estimé → badge ; inconnu → demande"
      min_lines: 50
  key_links:
    - from: "home hero (widget_renderer / cap_sequence_card)"
      to: "EnhancedConfidence.combined"
      via: "gate <50 / bandes <70 avant rendu du chiffre"
      pattern: "combined"
---

<objective>
W3 — Discipline estimé-vs-connu (SOT §5) : appliquer le Confidence Gate au hero /home, généraliser le tag « estimé », et résoudre la double comptabilité de confiance (D12 : `EnhancedConfidence.combined` géométrique vs `ConfidenceBreakdown.overall` pondéré, candidat racine cf. SOT §3 NOTE — A_REPRODUIRE puis unifier).

Purpose: ferme D2 (violation device-prouvée), D12, jeune_diplome-5, et l'exigence « hypothèse : salarié » du CONTEXT.
Output: hero à 3 états + tag estimé généralisé + source de confiance unique.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/mint-illogism-fixes/mint-illogism-fixes-CONTEXT.md (W3)
@.planning/reports/MATRIX-illogismes-2026-06-09.md (D2, D12, jeune_diplome-5)
@SOT.md (§3 NOTE deux moteurs de confiance, §4 ProfileDataSource, §5 invariants)

<interfaces>
Surfaces hero : grep « Avoir LPP » → apps/mobile/lib/widgets/coach/widget_renderer.dart + apps/mobile/lib/widgets/pulse/cap_sequence_card.dart (localiser précisément le widget /home qui rend « 43'691 Avoir LPP » — D2 captures ind-home.png).
Confiance : EnhancedConfidence 4-axes (confidence_scorer.dart, combined) vs ConfidenceBreakdown.overall — les surfaces lisent l'un OU l'autre (44% vs 50% vs 30%).
Pattern de tag existant : Mon Argent>Prévoyance affiche déjà le badge « estimé » — réutiliser ce widget/pattern.
Artefact jeune : minimal_profile_service.dart:56-59 `currentSavings = max(0,(age-25)*gross*0.05)` → 0 dur à 25 ans → liquidityMonths=0 non taguée.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Élucider et unifier la source de confiance (D12)</name>
  <files>apps/mobile/lib/services/financial_core/confidence_scorer.dart (+ sites de lecture identifiés)</files>
  <read_first>
    - SOT.md §3 NOTE (deux moteurs) ; apps/mobile/lib/services/financial_core/confidence_scorer.dart
    - `grep -rn "ConfidenceBreakdown\|EnhancedConfidence" apps/mobile/lib/screens/ apps/mobile/lib/widgets/` (cartographier QUI lit QUOI — Mon Argent 44%, RvC 50%, Marc 30%)
    - Ligne matrice D12 (A_REPRODUIRE : confiance inversée fiction 50% > réel 30%)
  </read_first>
  <action>Reproduire D12 en test : même profil → deux scores différents selon le moteur lu. Décision (discretion, à documenter) : `EnhancedConfidence.combined` (4-axes, SOT §3) devient LA source lue par toutes les surfaces ; `ConfidenceBreakdown.overall` délègue ou est déprécié (strangler-fig, pas de big-bang). Cas inversé fiction>réel : vérifier qu'après le plan 10 (fiction tuée) le cas disparaît — sinon corriger la pondération qui récompensait les défauts hardcodés. Test : un profil = UN score sur toutes les surfaces.</action>
  <acceptance_criteria>
    - Mécanisme 44/50/30 expliqué avec citations file:line dans le SUMMARY (exigence A_REPRODUIRE de la matrice).
    - Test unitaire : même profil → même score par tous les chemins de lecture, exit 0.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/ && flutter analyze</automated>
  </verify>
  <done>D12 fermé : une source de confiance par profil.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Hero 3 états + Confidence Gate + tag estimé généralisé</name>
  <files>apps/mobile/lib/widgets/coach/widget_renderer.dart, apps/mobile/lib/widgets/pulse/cap_sequence_card.dart, apps/mobile/lib/services/minimal_profile_service.dart, apps/mobile/lib/l10n/app_*.arb, apps/mobile/test/widgets/home_hero_confidence_test.dart</files>
  <read_first>
    - Le widget hero exact localisé en Task 1 read_first (grep « Avoir LPP »)
    - Le pattern badge « estimé » de Mon Argent>Prévoyance (à réutiliser tel quel)
    - apps/mobile/lib/services/minimal_profile_service.dart:56-59, 161-162 (artefact savings/liquidity)
    - Lignes matrice D2, jeune_diplome-5
  </read_first>
  <behavior>
    - Test : combined <50 → le hero ne rend PAS de chiffre (état « inconnu » : demande de données / CTA scan) ; 50-69 → chiffre + bande d'incertitude ; ≥70 connu → chiffre nu autorisé.
    - Valeur d'origine estimateur → badge « estimé » + CTA scan, JAMAIS en hero nu (même à confiance ≥50).
    - Statut d'emploi inconnu → étiquette « hypothèse : salarié » sur les chiffres archétype-dépendants.
    - liquidityMonths issu du savings estimé → tagué estimé (plus de « 0 mois » présenté comme mesuré).
  </behavior>
  <action>Implémenter les 3 états du hero (connu/estimé/inconnu) dans le widget /home identifié — gate sur `EnhancedConfidence.combined` (Task 1). Tag « estimé » : généraliser le widget badge de Mon Argent aux surfaces estimateur (hero, liquidité). Nouvelles clés ARB ×6 (« estimé », « hypothèse : salarié », bandes — accents, pas de termes bannis : pas de « précis », « certain »). Écrans modifiés → panel design 4-personnes AVANT push. Device-proof : sim, profil Fiabilité <50 → hero gated (l'inverse exact de D2).</action>
  <acceptance_criteria>
    - `cd apps/mobile && flutter test test/widgets/home_hero_confidence_test.dart` exit 0 (3 états testés).
    - Oracle D2 re-run sur sim : profil 44% → PAS de « Avoir LPP » nu en hero ; capture `.planning/_walker/illogism-fixes/w3/` citée.
    - `python3 tools/checks/accent_lint_fr.py` exit 0 + `validate_arb_parity()` + `check_banned_terms` clean.
    - Panel design 4-personnes exécuté, verdicts cités.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test && flutter analyze && python3 tools/checks/accent_lint_fr.py</automated>
    <human-check>Capture : hero gated à confiance 44%, badge estimé visible sur Mon Argent ET home</human-check>
  </verify>
  <done>D2 + jeune_diplome-5 fermés ; SOT §5 appliqué et testé.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| estimateurs → hero UI | une estimation déguisée en fait = intégrité + LSFin (sur-confiance induite) |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-11-01 | Tampering (intégrité de présentation) | hero /home | mitigate | gate <50 + 3 états + tests widget |
| T-ILF-11-02 | Repudiation (score incohérent) | double moteur de confiance | mitigate | source unique EnhancedConfidence.combined |
</threat_model>

<verification>
- `cd apps/mobile && flutter analyze && flutter test` + lints ; device-proof D2 inversé.
</verification>

<success_criteria>
- D2, D12, jeune_diplome-5 fermés avec citations + captures.
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-11-SUMMARY.md` + mise à jour VALIDATION.md Per-Task Map.
</output>

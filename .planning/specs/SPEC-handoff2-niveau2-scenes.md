# SPEC — Handoff 2 Niveau 2: Scènes interactives

**Status:** Draft (CDLC: Generate)
**Author:** Claude (Product Leader, autonomous)
**Date:** 2026-05-03
**Source of truth:** `Downloads/handoff 2/03-components.md §3+§4+§5` + `prototype/chat-vivant/scene-rente-capital.jsx` + `scene-rachat-lpp.jsx`
**Depends on:** PR #459 (Fraunces editorialLarge) + PR #462 (Niveau 1 widgets — for shared visual primitives)

---

## 1. Goal (one sentence)

Replace the « text-only » coach answer pattern (« réponse en 200 mots, puis "ouvre l'écran X pour creuser" ») with **interactive scenes posed inline in the chat bubble** that already answer the question — slider drives live numbers, no rupture into a separate screen.

## 2. Scope (this spec)

**3 widgets** + 1 helper, in order of build:

| # | Widget | LOC est. | Dependencies |
|---|---|---|---|
| 1 | `MintLifeLineSlider` | ~120 | none — atomic |
| 2 | `MintSceneRenteCapital` | ~280 | `MintLifeLineSlider`, `editorialLarge` |
| 3 | `MintSceneRachatLPP` | ~260 | `editorialLarge` |
| 4 | `_SceneColumn` (private) | ~80 | shared by both scenes |

## 3. Hard invariants (non-negotiable)

Per Handoff 2 `00-README.md` § éditoriaux:
1. **Aucun emoji.** Pour une puce, utiliser `▪`.
2. **Un seul chiffre-héros par vue.** Les autres en `displaySmall` ou plus petit.
3. **Fraunces = signature éditoriale.** Pour les `em`, phrases de recul, labels horodatés. Jamais en body long.
4. **Chaque scène a une *phrase de recul*** — une ligne qui remet la donnée en perspective humaine (fond `craie`, `bodySmall`, `em` Fraunces autorisé).
5. **Hypothèses visibles mais discrètes** — `micro` italique, sous dashed border.
6. **CTA dans les scènes** = noirs (`MintColors.textPrimary` fond, `#fff` texte). Le reste joue le rôle.

## 4. Computation contract (Niveau 2 = local, no backend)

Per `02-chat-vivant-services.md`: **les widgets lisent, ne calculent pas** EXCEPT for the local interactivity loop (slider → instantaneous numbers). Heavy financial computation stays in `services/financial_core/` (e.g. `LppCalculator.computeMonthlyRente`). Local computation is limited to:
- Linear interpolations (slider → display)
- Deterministic numerical projections at fixed assumption sets
- Format-only operations (CHF, %)

Reference values for `MintSceneRenteCapital` (per JSX source, deterministic):
- `capitalBrut` = 520'000 CHF
- `tauxConversion` = 4.8%
- `renteAnnuelle` = capitalBrut × tauxConversion = 24'960 CHF/an
- `renteMensuelle` = renteAnnuelle / 12 = 2'080 CHF/mois
- `impotCapital` = 18% (Swiss capital tax assumption)
- `capitalNet` = capitalBrut × (1 − impotCapital) = 426'400 CHF
- `rendementReel` = 2.5%/an
- Iterative `ageEpuisement` = compound (capital × 1.025 − rente_net) until ≤ 0, capped at 110

Reference values for `MintSceneRachatLPP` (TODO once JSX read):
- `tauxMarginal` = 35% (taux marginal d'imposition — assumption)
- `anneesEchelon` = 5 ans
- `tauxConversion` = 4.8% (same as above)

## 5. Slider state machine

`MintLifeLineSlider` is the only stateful piece in Niveau 2:
- Range: `min=70, max=100` (configurable)
- Default: 89 (per JSX prototype)
- Marker: `ageEpuisement` rendered as vertical line at the corresponding x position
- Fill color: derives from `age > ageEpuisement` boolean (sauge if rente wins, peche if capital wins)
- Thumb: 16x16 white circle, border 2px fill color, subtle shadow
- Haptic: light impact on tick (every integer change)

## 6. Tests (CDLC: Evaluate)

### 6.1 Unit / behavioural tests
For each widget, verify:
- Render structure (label + chiffres + slider + recul phrase + CTA when inline)
- Slider value change → triggers `setState` → numbers update via `CountUp`
- `avantageRente` boolean correctly computed at boundary ages (epuisement ± 1)
- Variant `inline` shows CTA, variant `embedded` hides it
- Semantics labels for screen readers
- LSFin compliance: no banned terms in UI strings

### 6.2 Goldens (deferred to Phase 55)
Per Handoff 2 `06-test-plan.md`: « test la structure, pas le pixel » — defer goldens until Fraunces is locked in CI fonts cache (otherwise CI flake).

### 6.3 Regression evals (« context tests » per Debois)
Scenarios to mechanically verify post-merge:
- Eval 1: « user opens chat, taps intent pill « rente vs capital » » → MintSceneRenteCapital surfaces in MINT bubble (not as separate route)
- Eval 2: « user moves slider from 89 to 75 » → both columns re-compute, fill color flips
- Eval 3: « user taps Creuser » → MintCanvasProjection opens (Niveau 3 — deferred PR)

## 7. Anti-patterns (« notre maladie »)

Per Manus + Debois + my own session learnings:
- **NO timestamps in widget keys** — would invalidate cache + break golden tests
- **NO heavy backend RPC inside slider onChanged** — local computation only (re-rendering 30Hz on slider drag)
- **Append-only logic** — never mutate slider history; always compute from current `age` value
- **Preserve failed states** — if computation hits NaN, render fallback « — » not crash
- **No premature SceneRegistry** — wire scenes directly first, abstract once we have ≥2 of them deployed

## 8. Out of scope (next specs)

- `MintCanvasProjection` (Niveau 3 — full-screen canvas, deferred to next spec)
- `SceneRegistry` (orchestration — deferred until 2+ scenes live)
- `ChatProjectionService` (rendering scenes inline — deferred)
- `ReturnContract` (canvas → chat handoff with context preservation — deferred)
- Backend support for scene fixtures (Niveau 2 is fully client-side)

## 9. Definition of done

- [ ] 3 widgets shipped: `MintLifeLineSlider`, `MintSceneRenteCapital`, `MintSceneRachatLPP`
- [ ] 30+ tests green (10 per widget)
- [ ] `flutter analyze` clean
- [ ] PR opened + linked to this SPEC
- [ ] Visual screenshot on sim (1 per scene, at default age)
- [ ] No regression on existing chat-vivant Niveau 1 widgets
- [ ] LSFin compliance: 0 banned terms

## 10. CDLC ownership

Per Debois « Context flywheel needs ownership »:
- **Owner**: Claude (Product Leader, autonomous)
- **Reviewer**: Julien (creator) — single sign-off on visual fidelity to Handoff 2 prototype
- **Distribute**: this SPEC.md committed alongside the widgets PR
- **Observe**: `.planning/reports/SESSION-YYYY-MM-DD.html` rolls up the close-out evidence

---

**Generated 2026-05-03 by autonomous loop. Per CDLC: this spec is the « contract » between intent and code. Code that diverges from this spec without an updated spec is a regression.**

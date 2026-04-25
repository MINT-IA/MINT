# Roadmap: MINT

## Milestones

- ✅ **v1.0 MVP** — Phases 1-8 (shipped 2026-03-20)
- ✅ **v2.0 Systeme Vivant** — Phases 1-6 (shipped 2026-04-07)
- ✅ **v2.1 Stabilisation** — Phase 7 (shipped 2026-04-07)
- ✅ **v2.4 Fondation** — Phases 9-12 (shipped 2026-04-12)
- ✅ **v2.5 Transformation** — Phases 13-18 (shipped 2026-04-13)
- ✅ **v2.6 Le Coach Qui Marche** — Phases 19-26 (shipped 2026-04-13)
- 🟡 **v2.7 Coach Stabilisation + Document Digestion** — Phases 27-30 (code-complete, awaiting device gate)
- 🔵 **v2.8 L'Oracle & La Boucle** — Phases 30.5, 30.6, 30.7, 31-36 (defining)
- 🌱 **v2.9 Chat Vivant** (planted 2026-04-19) — "Le chat ne raconte plus, il montre." 3 niveaux de projection (inline insight / scene interactive / canvas plein écran) à la Claude Artifacts. Source : `.planning/handoffs/chat-vivant-2026-04-19/` (8 docs + 6 JSX + captures HTML). Estimation P50 = 3 semaines calendar solo (refactor `CoachOrchestrator` Stream + i18n 6 langues + creator-device gate). 3 frictions à trancher avant exécution : (1) scenes inline vs écrans Explorer existants → single source of truth ? (2) `Future<CoachResponse>` → `Stream<ChatMessage>` refactor touche 3 code paths orchestrator, (3) i18n ARB 6 langues ~180 entries non comptées. À réveiller après Phase 31 shippée.

<details>
<summary>Previous milestones (v1.0 → v2.7) — see MILESTONES.md + collapsed v2.5-v2.7 detail below</summary>

Full phase detail for v2.5 (Phases 13-18), v2.6 (Phases 19-26), v2.7 (Phases 27-30) preserved in git history of this file (pre-2026-04-19 revisions) + `.planning/MILESTONES.md`.

</details>

---

## v2.8 L'Oracle & La Boucle — SHIPPED 2026-04-25 (with gaps)

<details>
<summary>v2.8 phase detail (collapsed — full archive in milestones/v2.8-ROADMAP.md)</summary>

5 phases shipped + 13 decimal patches :
- 30.5 Context Sanity Core ✓ · 30.6 Context Sanity Advanced ✓ · 30.7 Tools Déterministes ✓ · 31 Instrumenter ✓ · 32 Cartographier ✓
- 30.8-30.20 : tactical fixes (LAND-01, FIX-02, anonymous CTA, error mapping, accent_lint exclusions, doc extraction uplift…)

Phases unshipped (carried forward to v2.9) :
- 33 Kill-switches (4 P0 flags) — needed for v2.9 if user-value features ship behind flag
- 34 Guardrails — workflow design failed, lessons learned, redo with proper exclusions baked in
- 35 Boucle Daily — automation, defer
- 36 Finissage E2E — spirit absorbed into v2.9 « Coach Visuel Hybride »

Full audit: [milestones/v2.8-MILESTONE-AUDIT.md](milestones/v2.8-MILESTONE-AUDIT.md) · 28/48 reqs · 5/9 phases.

</details>

---

## v2.9 Coach Visuel Hybride — Overview

**Goal:** Verticale « Onboarding-to-First-Insight » : un user qui arrive sur MINT a, en moins de 20 min, son profil financier sur les 6 axes suisses (AVS, LPP, 3a, salaire, fortune, charges) + un hero number actionnable « marge fiscale optimisable cette année » + un coach qui balance vignettes / scènes / canvas pour explorer les arbitrages (3a vs rachat LPP vs amortissement vs hypothèque) avec liens deep-dive vers les écrans Explorer existants.

**Doctrine v2.9 (planted 2026-04-19, validated 2026-04-25):** Le coach EST le produit. 3 niveaux de projection visuelle (vignette inline / scène interactive / canvas modal) intégrés dans le chat, avec arbitrage live et lien vers les écrans Explorer pour deep dive.

**Carry-forward from v2.8:** FIX-01 UUID, FIX-03 save_fact, FIX-04 Coach tab, FIX-05 Wave 2+ bare catches (195 P0+128 P1), FIX-07 234 backend accent violations, Phase 33 kill-flags (subset only).

**Phases planned:**
- **Phase 40 — Marge fiscale backend** (3-5j) : pure function `compute_marge_fiscale(profile)` (3a + rachat LPP + cash availability) + endpoint + 10 unit tests
- **Phase 41 — Hero + Vignettes L1** (1 sem) : `MargeFiscaleHero` + `MargeFiscaleVignette` widget, branche dans PulseScreen + chat
- **Phase 42 — Scènes L2 interactives** (2 sem) : `MintSceneArbitrageRetraite` + `MintSceneArbitrageHypotheque` slider live, `SceneRegistry`, début refactor `Stream<ChatMessage>`
- **Phase 43 — Canvas L3 + lien Explorer** (1-2 sem) : `MintCanvasArbitrage` modal, return contract chat ← canvas, optimisation écrans Explorer existants

**KPIs gating (chaque phase):**
- Coverage profil après 5 min ≥ 60%
- Time-to-first-vignette < 90s
- p95 chat response < 3s
- 0 P0 production
- Diff-coverage PR ≥ 80%
- Walk Julien hebdo simctl
- Bare catches 342 → < 100
- ARB parity 6 langs preserved

**Total estimate:** 5-7 semaines solo-dev. Creator-device gate non-skippable.

---
*Last updated: 2026-04-25 — v2.8 closed at 5/9 + 13 decimals, gaps_found ; v2.9 « Coach Visuel Hybride » opened with Phase 40-43.*

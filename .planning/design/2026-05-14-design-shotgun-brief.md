---
description: Brief /design-shotgun (3 variants HTML production-quality) pour le composant TrajectoryMap basé sur wireframe v1 + drift audit + PDF DS v2 mai 8. À invoquer par Julien quand prêt.
name: design-shotgun-brief-trajectory-map
type: design
---

# Brief /design-shotgun — TrajectoryMap component (Wave 0 step D)

> **Author** : Claude (Wave 0 Sentry — Product Leader mode).
> **Status** : Ready for Julien to invoke /design-shotgun (gstack).
> **Date** : 2026-05-14.
> **Wave** : 0 step D — after sub-agents A/C output.

---

## TLDR

Brief pour générer 3 variants HTML du composant TrajectoryMap (sub-agent C wireframe v1) via /design-shotgun. Les variants explorent les 5 questions ouvertes identifiées par sub-agent C : densité timeline, marker actif visualisation, hero number placement, milestones non-linéaires, tap interaction overlay vs bottom sheet vs panel.

## Comment Julien invoque

Quand tu es prêt, lance :

```
/design-shotgun
```

Et colle le brief ci-dessous quand le skill te le demande.

---

## Brief à coller dans /design-shotgun

```
Génère 3 variants HTML production-quality du composant TrajectoryMap pour MINT (Swiss financial lucidity Flutter app, target iPhone 14+ 393×852pt).

## Contexte produit
MINT = coach financier suisse, "Mint te dit ce que personne n'a intérêt à te dire". 18-99 ans, 8 archetypes Swiss (swiss_native, expat_eu, expat_us FATCA, cross_border, independent_no_lpp, etc.). Pas une app de retraite. Pivot 2026-04-12 : lucidité, pas protection.

## Le composant
TrajectoryMap = roadmap personnelle visuelle A→B avec marker position courante + milestones tap-able. Cockpit de COMPRÉHENSION (Karpathy 2026 "I can outsource the thinking but not the understanding"), pas dashboard cosmétique.

## Inputs de design (à lire absolument)
- Wireframe v1 ASCII : .planning/design/2026-05-14-trajectory-map-wireframe-v1.md (sub-agent C output, 3 wireframes W1/W2/W3)
- Drift audit : .planning/audit/2026-05-14-handoff-vs-code-drift.md (Section D.bis + D.ter)
- Design system : docs/DESIGN_SYSTEM.md + .planning/handoff/pdfs/MINT-Design-System-2026-05-08.pdf (PDF canonique)
- Tokens Flutter : apps/mobile/lib/theme/colors.dart + apps/mobile/lib/theme/mint_text_styles.dart
- JSX référence : docs/brand/mint-v2/screen-plan.jsx (stepper vertical, à adapter horizontal)
- ADR Aujourd'hui doctrine : .planning/decisions/2026-05-14-aujourdhui-doctrine.md (director-dashboard one-number)

## Tokens canoniques à utiliser (PAS Color(0x...) hardcoded)
Palette warm (Handoff 2 / DS v2 mai 8) :
- bg principal : #FAF8F5 (warm-white) ou #F4F1EC (porcelaine-hero)
- coach surface : #F8F5F0 (craie-handoff)
- ink primary : #1A1A1A (inkPrimary, NOT cool #1D1D1F primary legacy)
- text secondary : #5A5A5A
- hairline : #E8E4DE (border-subtle)
- accent menthe-vive : #7DD3B5 (PDF DS v2 mai 8 canonique — appliquer sur marker actif + CTA primary)
- sauge : #B8C9B4 (success positif)
- terracotta : #B8735A (rare CTA highlight)

Typo :
- Display headline : Gambarino italic (Fontshare), 22-32pt — UNIQUEMENT sur 2 écrans max (italique banalise ailleurs PER DS v2 mai 8 règle #5)
- UI everything else : Supreme (Fontshare), w400/w500/w700
- Tabular nums pour les chiffres

## Grammaire MINT v2 (PDF DS v2 mai 8 page 5 — 8 règles)
1. Une idée / écran — pas de mur de cartes
2. Voix : observer pas juger — pas "enfin", pas "de justesse", pas "largement mieux"
3. 4 artefacts Coach inline (Décision · Comparaison · Trajectoire · Sensibilité) — sur Coach, pas sur TrajectoryMap
4. 18 events ≠ retraite-app — "Trajectoire", pas "Plan retraite"
5. Italique 2 écrans max
6. **Chiffre nu = INTERDIT** — toujours ConfidenceBand + EnrichmentPrompts à côté
7. Streaming visible (Coach only, pas applicable ici)
8. Dark mode natif — 1ère classe, pas afterthought

## Voix MINT (docs/VOICE_SYSTEM.md)
- Tutoiement systématique (jamais "vous")
- Calme, précis, fin, rassurant, net
- "ami cultivé qui travaille dans la finance suisse"
- Conditionnel ("pourrait", "envisager") JAMAIS impératif ("tu dois", "il faut")
- Banned LSFin terms (NEVER) : garanti, optimal, meilleur, certain, assuré, sans risque, parfait

## Banned terms (CRITICAL — viole LSFin si présent)
NEVER : "garanti", "optimal", "meilleur", "certain", "assuré", "sans risque", "parfait", "tu devrais", "tu dois", "il faut"

## Les 5 questions ouvertes à explorer
Chaque variant explore une combinaison différente :

### Variant A — "Timeline dense, marker rond, hero au-dessus"
- 7 milestones visibles simultanément
- Marker actif = rond plein menthe-vive (24pt)
- Hero number AU-DESSUS de la timeline (taille displayLarge 48pt Gambarino italic)
- Tap milestone → overlay bottom sheet
- Linéaire (pas de branches)

### Variant B — "Timeline aérée, marker zone highlight, hero contextual"
- 5 milestones visibles (zoom contextuel — phases lointaines en sub-card sous le fold)
- Marker actif = zone highlight (rectangle menthe-vive 12% alpha avec hairline)
- Hero number CONTEXTUEL : appears at tap-position, pas above-fold static
- Tap milestone → panel slide-in droite (style iOS Settings detail)
- Branches non-linéaires possibles (FATCA + 3a parallèles)

### Variant C — "Timeline narrative, marker flèche, hero milestone-only"
- 5 milestones visibles + 1 carte hero détaillée du milestone actuel sous la timeline
- Marker actif = flèche pointant vers le milestone (cohérence éditoriale, pas géométrique)
- Hero number SUR LE MILESTONE actif (pas global) — chiffre "ce que ce milestone apporte"
- Tap milestone → overlay Coach scoped (cohérent doctrine Phase 96)
- Linéaire mais avec sub-milestones expandables

## Output souhaité
3 fichiers HTML standalone (CSS inline, pas de framework) :
- variant-a-trajectory-dense.html
- variant-b-trajectory-aere.html
- variant-c-trajectory-narrative.html

Chaque fichier :
- 100% Pretext-native (text reflows, heights computed dynamically — pas de static pixel mockups)
- Mobile viewport iPhone 14 (393×852pt) + dark mode toggle
- Render Persona "Julien swiss_native 49 ans" :
  - Hero number : 5'800 CHF/mois (rente projetée 65 ans)
  - 5-7 milestones depending on variant :
    M1 Comprendre tes 3 piliers (✓ fait)
    M2 Optimiser ton 3a (✓ fait — versé 7'258 CHF en 2024)
    M3 Racheter LPP 10'000 CHF (◉ actif — -3'400 CHF impôts)
    M4 Projeter à 65 ans (à venir)
    M5 Succession (à venir)
  - ConfidenceBand : "Faible · 16 ans d'écart, projection sensible aux revenus"
  - EnrichmentPrompts : "évolution salaire ?", "enfants futurs ?", "achat immobilier ?"
- Header minimal : "Trajectoire · 3/5" (pas "Plan retraite")
- Tab bar 3 tabs : Aujourd'hui · Coach · Trajectoire (TrajectoryMap canoniquement sur Trajectoire tab per PDF DS v2 mai 8 + ADR Mon Argent P2)
- CTA primary milestone-actif : "Continuer M3" en menthe-vive
- Aucun emoji
- Tous les chiffres avec apostrophe séparateur (5'800 pas 5,800)

## Compliance check final (avant render)
- TOP rule #3 OK : framing life-event-agnostic, pas "plan retraite"
- TOP rule #1 OK : zéro banned term
- TOP rule #2 OK : accents 100% FR (é, è, ê, ô, ù, ç, à)
- Grammaire DS v2 mai 8 #6 OK : ConfidenceBand + EnrichmentPrompts présents
- Tokens warm OK : NO #FFFFFF cold backgrounds, oui #FAF8F5 / #F4F1EC / #F8F5F0
```

---

## Après le shotgun

1. Tu reçois 3 variants HTML dans `~/.gstack/projects/MINT-IA-MINT/designs/`
2. **STOP — tu choisis ton variant** (A / B / C / mix)
3. Le variant choisi devient input pour Wave 2 implémentation Flutter (TrajectoryMap component build)

---

## Caveats

1. /design-shotgun (gstack) est interactif — Julien doit le lancer lui-même via la CLI, je ne peux pas l'invoquer en background depuis cette session.
2. Le brief est intentionnellement opinionated : 3 variants ≠ 3 explorations totalement libres, ce sont 3 combinaisons précises des 5 questions ouvertes sub-agent C. Liberté du shotgun = palette de propositions dans la sub-grammaire fournie, pas refonte de la grammaire elle-même.
3. Si /design-shotgun produit un variant qui sort de la doctrine DS v2 (ex : pie chart au lieu de timeline), il faut le rejeter et re-shotgun avec brief renforcé. La doctrine DS v2 mai 8 + ADR Aujourd'hui doctrine sont déjà ratifiées — pas re-litigation au stade design.

---

*Brief produit Wave 0 par Claude pour invocation Julien. Sources : sub-agent C wireframe v1 + drift audit Section D.bis + PDF DS v2 mai 8.*

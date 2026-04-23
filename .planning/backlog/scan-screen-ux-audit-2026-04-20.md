---
type: ux-audit-finding
priority: P2 (ship-blocking UX debt, not functional bug)
status: deferred-v2.9-or-design-sprint
discovered: 2026-04-20 during Phase 32 E2E flow test
screen: /scan (Scanner un document)
screenshots: .planning/phases/32-cartographier/screenshots/flow-test-2026-04-20/10-scanner-tap-587.png + 11-gallery-picker.png + 12-scrolled.png
---

# Scanner un document — écran laid (Julien verdict 2026-04-20)

5 ruptures doctrine identifiées lors E2E test :

1. Header ALL-CAPS "SCANNER UN DOCUMENT" contredit typographie minimaliste (feedback_design_direction — Chloé/Aesop/Wise ref). Should be "Scanner un document" Display title-case.
2. 4 styles boutons discordants (camera noir pleine / "Depuis la galerie" contour / "Coller le texte OCR" fond bleu clair / "Utiliser un exemple de test" contour violet) — chaos hiérarchie visuelle.
3. Redondance chip + card : "Certificat de prévoyance LPP" apparaît en chip top + card détail en dessous sur background crème → contraste nul.
4. "+27 points de confiance" vert gamification — contredit feedback_anti_shame_situated_learning ("Never display levels/badges/comparisons"). Metric non-vulgarisée, trophée creux.
5. **Accent manquant confirmé** : "Certificat de **prevoyance** LPP" → devrait être **prévoyance**. Bug `accent_lint_fr.py` qui a laissé passer OU n'est pas appliqué à cet écran (à vérifier).
6. **Text clipping P1 4e bouton** : "Utiliser un exemple de test" dernière ligne tronquée sur iPhone 17 Pro. Layout overflow.

## Julien call 2026-04-20

> "Ship first (que ça fonctionne), design après sur base du handoff design."

→ Deferred to v2.9+ design sprint OR slotted into Phase 35 if walker.sh dogfood surface-scans it systématique.

## Plan d'action quand picked up

1. Run `/gsd-ui-review` skill (6-pillar visual audit) sur cet écran
2. Cross-check against `docs/DESIGN_SYSTEM.md` + handoff Chat Vivant tokens
3. Fix #5 (accent) is trivial + lint-catchable — ship en standalone hotfix
4. Fix #6 (clipping) is ship-visible regression, prioritize
5. Redesign holistic (items 1-4) = design-review + plan-design-review skills, probably half-day scope

Do NOT touch before Phase 32→35 shipped per kill-policy ADR-20260419.

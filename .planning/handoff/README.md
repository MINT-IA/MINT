---
description: Archive durable des handoffs vision MINT (chat-vivant-services 2026-04-26, design-system-v8 2026-05-09, app-screenshots 2026-05-14, brand+design+Karpathy PDFs). Référence canonique pour toute session future.
---

# `.planning/handoff/` — Archive durable des références vision MINT

**Raison d'être** : ces artefacts vivaient dans `~/Downloads/` (volatile, renommé en `handoff 2/` ou `_to-MINT 2/` par macOS, perdu entre les sessions). Karpathy Wiki anti-pattern : la vision s'éteignait avec la session qui l'avait articulée. Cet archive les remet sous git, version-able, accessible depuis n'importe quelle session Claude Code/agent.

## Contenu

### `2026-04-26-chat-vivant-services/` — vision originale chat-vivant

Handoff vision Julien daté 26 avril 2026 — **prédate Option C de 3 semaines**. Source historique du Coach didactique vivant.

- `00-README.md` — orientation
- `01-vision.md` — vision produit
- `02-chat-vivant-services.md` — **architecture chat-vivant** (source historique d'Option C, à ne plus re-découvrir)
- `03-components.md` — composants UI
- `04-animations.md` — motion design
- `05-integration.md` — intégration backend
- `06-test-plan.md` — plan de tests vision
- `ARCHITECTURE.md` — vue architecture globale
- `architecture.html` — version interactive HTML
- `colors_and_type.css` — design tokens couleurs + typo
- `prompts.md` — prompts LLM proposés
- `prototype/` — mockups HTML/CSS

### `2026-05-09-design-system-v8/` — design system v8 + Claude Code prompts

Package design system itéré (v8, le plus récent zip Julien). Contient l'évolution v2 des écrans + les prompts d'intégration que Julien a préparés pour Claude Code agents :

- `README-installation.md` — comment installer les assets dans l'app
- `handoff/00-README.md` à `06-test-plan.md` — vision raffinée (équivalent mai du handoff avril)
- `handoff/ARCHITECTURE.md` — architecture cible v2
- `handoff/architecture.html` — version interactive
- `handoff/CLAUDE_CODE_PROMPT.md` — **prompt principal 22 KB Julien-authored** pour orchestrer l'intégration Coach IA
- `handoff/CLAUDE_CODE_FIX_PROMPTS.md` — **prompt fix 27 KB** pour bugs récurrents
- `handoff/prototype/MINT - Chat vivant.html` — prototype HTML interactif
- `handoff/prototype/ios-frame.jsx` — frame iOS pour render
- `docs/brand/MINT-brand.html` + `MINT-screens.html` + `colors_and_type.css` — assets brand
- `MINT_COACH_AI_INTEGRATION_PROMPT.md` — prompt système Julien-authored pour Coach Layer IA

Les écrans JSX correspondants (`screen-aujourdhui.jsx`, `screen-coach.jsx`, `screen-lpp.jsx`, etc.) sont copiés directement dans `docs/brand/mint-v2/` (assets vivants, pas archive).

### `2026-05-14-app-screenshots/` — screenshots app état mai 14

3 PNG capturés depuis l'app actuelle (état pré-Wave-0) :
- `01-explore-home.png` — Explorer tab home
- `02-drawer-open.png` — drawer ouvert
- `03-mon-bilan.png` — écran Mon Bilan

Baseline visuelle « MINT au 14 mai 2026 » pour comparaison post-Wave-0/1/2.

### `pdfs/` — PDFs officiels (état figé)

- `MINT-Brand-print-2026-05-09.pdf` — brand book print (~574 KB)
- `MINT-Design-System-2026-05-08.pdf` — design system complet (~756 KB)
- `Karpathy-Wiki-Pattern-2026-05-06.pdf` — article Mustafa Genc sur Karpathy Wiki Pattern (~1.6 MB), référence pour `.planning/` schema (CLAUDE.md §8)

## ⚠️ Caveat — DRIFT entre handoffs et code actuel

Les archives 2026-04-26 et 2026-05-09 ont été produites avant les Phases 95-98 récentes. **Les propositions ne sont PAS automatiquement canoniques.** Risques de drift :

- Architecture chat-vivant proposée peut diverger de la structure actuelle 4 tabs (`apps/mobile/lib/widgets/mint_shell.dart:78-102`) — notamment sur les onglets, rôle de Coach, statut Phase 96 (chatTabVisible, paused per `.planning/decisions/2026-05-14-phase-7-ship-or-pause.md`).
- Composants `03-components.md` peuvent avoir été remplacés ou refactorés (vérifier `apps/mobile/lib/widgets/` + `lib/screens/`).
- Couleurs/typo dans `colors_and_type.css` peuvent avoir divergé de `docs/DESIGN_SYSTEM.md` + `apps/mobile/lib/theme/colors.dart` (MintColors).
- Prompts dans `prompts.md` + `CLAUDE_CODE_PROMPT.md` peuvent être superseded par `services/backend/app/services/coach/prompt_registry.py`.
- JSX écrans dans `docs/brand/mint-v2/` sont des **propositions design**, pas du code Flutter shippable. Traduction Flutter requise.

**Source of truth ACTUELLE** :
- Vision : `docs/MINT_IDENTITY.md` + `CLAUDE.md`
- Design : `docs/DESIGN_SYSTEM.md` + `docs/VOICE_SYSTEM.md` + `apps/mobile/lib/theme/colors.dart`
- Code : `apps/mobile/lib/` + `services/backend/app/`
- Décisions : `.planning/decisions/*.md` (les plus récentes priment)

**Usage correct du handoff** :
1. Lire pour **comprendre la trajectoire historique** et le raisonnement Julien.
2. **Drift audit** (obligatoire pour toute session Wave 0+) : identifier ce qui a été shippé vs divergé vs jamais câblé.
3. Ne JAMAIS re-implementer un composant handoff sans avoir vérifié l'état actuel + check avec Julien si la proposition handoff est toujours valide.

## Convention d'usage

- **Read-only** par Claude. Ne pas modifier les fichiers de l'archive. Si refresh nécessaire, créer `.planning/handoff/YYYY-MM-DD-nouveau-nom/` à côté.
- **Lecture obligatoire** dans toute session traitant architecture Coach, vision MINT, design system, ou wiki pattern. Référencer dans le system context au démarrage **avec drift audit explicite**.
- **INDEX** : `.planning/INDEX.md` doit lister cet archive (regen via `python3 tools/checks/wiki_lint.py index`).

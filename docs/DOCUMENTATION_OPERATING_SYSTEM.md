# MINT Documentation Operating System

> Statut: index de gouvernance documentaire
> Rôle: dire quel document lire, dans quel ordre, et pour quelle tâche
> Source de vérité: oui, pour l'orientation documentaire uniquement
> Ne couvre pas: règles produit détaillées, UI, copy, implémentation

---

## 1. But

Ce document existe pour éviter 3 dérives:
- charger trop de documents "au cas où",
- reconstruire la vision à chaque session,
- laisser plusieurs récits concurrents guider les agents.

Objectif:
- réduire le coût en tokens,
- réduire les contradictions,
- donner une seule ligne de lecture.

---

## 2. Hiérarchie documentaire

Ordre de priorité:
1. `rules.md`
2. `CLAUDE.md`
3. `docs/MINT_UX_GRAAL_MASTERPLAN.md`
4. documents spécialisés de référence
5. documents historiques / archives / transition
6. code

Règle:
- si un document de niveau inférieur contredit un document de niveau supérieur, le document inférieur doit être corrigé ou reclassé.

---

## 3. Documents à lire selon la tâche

### Tâche: coder dans le repo
Lire:
- `CLAUDE.md`
- `docs/MINT_UX_GRAAL_MASTERPLAN.md`

Puis seulement si nécessaire:
- `docs/DESIGN_SYSTEM.md`
- `docs/VOICE_SYSTEM.md`
- `docs/MINT_CAP_ENGINE_SPEC.md`
- `docs/MINT_SCREEN_BOARD_101.md`

### Tâche: refonte écran / UI / widgets
Lire:
- `CLAUDE.md`
- `docs/MINT_UX_GRAAL_MASTERPLAN.md`
- `docs/DESIGN_SYSTEM.md`
- `docs/MINT_SCREEN_BOARD_101.md`

### Tâche: copy / tone / prompts
Lire:
- `CLAUDE.md`
- `docs/MINT_UX_GRAAL_MASTERPLAN.md`
- `docs/VOICE_SYSTEM.md`

### Tâche: Aujourd'hui / Cap / priorisation
Lire:
- `CLAUDE.md`
- `docs/MINT_UX_GRAAL_MASTERPLAN.md`
- `docs/MINT_CAP_ENGINE_SPEC.md`

### Tâche: navigation / routes / IA de navigation
Lire:
- `CLAUDE.md`
- `docs/MINT_UX_GRAAL_MASTERPLAN.md`
- `docs/NAVIGATION_GRAAL_V10.md`

### Tâche: coach AI / orchestration / mémoire
Lire:
- `CLAUDE.md`
- `docs/MINT_UX_GRAAL_MASTERPLAN.md`
- `docs/BLUEPRINT_COACH_AI_LAYER.md`
- `docs/VOICE_SYSTEM.md`

### Tâche: stratégie ou vision globale
Lire:
- `CLAUDE.md`
- `docs/MINT_UX_GRAAL_MASTERPLAN.md`
- `docs/ROADMAP_V2.md`
- `docs/TOP_10_SWISS_CORE_JOURNEYS.md`

---

## 4. Statut des documents (13 actifs)

### Documents maîtres (lire en premier)
- `CLAUDE.md` — règles, constantes, compliance
- `docs/MINT_UX_GRAAL_MASTERPLAN.md` — vision produit umbrella
- `docs/DOCUMENTATION_OPERATING_SYSTEM.md` — cet index

### Documents stratégiques
- `docs/ROADMAP_V2.md` — séquence des sprints, phases, KPIs
- `docs/TOP_10_SWISS_CORE_JOURNEYS.md` — parcours coeur, état actuel, gaps
- `docs/S53_GATE_CLOSER_AGENT_PROMPT.md` — prompt opérable pour agents d'exécution

### Documents spécialisés de référence
- `docs/DESIGN_SYSTEM.md` — tokens, composants, catégories d'écrans
- `docs/VOICE_SYSTEM.md` — voix MINT, ton, microcopy, 50 avant/après
- `docs/MINT_CAP_ENGINE_SPEC.md` — CapEngine, scoring, séquences, clause d'honnêteté
- `docs/MINT_SCREEN_BOARD_101.md` — board des 101 écrans, template par écran

### Documents spécialisés secondaires
- `docs/NAVIGATION_GRAAL_V10.md` — routes, hubs, shell 4 tabs
- `docs/BLUEPRINT_COACH_AI_LAYER.md` — coach AI, mémoire, orchestration
- `docs/CICD_ARCHITECTURE.md` — pipeline CI/CD, Railway, TestFlight
- `docs/DATA_ACQUISITION_STRATEGY.md` — OCR, Open Banking, enrichment

### Archivés (docs/archive/)
66 documents historiques. Utiles pour comprendre les décisions passées, mais ne gouvernent plus.

---

## 5. Règles d'entretien

- Un document doit répondre à une seule question principale.
- Si un document commence à dupliquer la vision umbrella, il dérive.
- Si un document ancien reste utile mais n'est plus directeur, son statut doit l'indiquer explicitement.
- Le masterplan résume; les docs spécialisés détaillent.
- Les archives inspirent; elles ne gouvernent plus.

---

## 6. Phrase directrice

**Un agent ne doit jamais avoir besoin de relire tout MINT pour savoir quoi faire.**

**La hiérarchie documentaire doit rendre la direction immédiate.**

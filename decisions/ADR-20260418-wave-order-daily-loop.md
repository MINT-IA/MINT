# ADR-20260418 — Réordonnancement Waves Daily-Loop : B avant A

**Status** : Accepted
**Date** : 2026-04-18
**Context** : Session autonome post PR #352 merge. Roadmap 6 Waves initialement A→F. Review 3 panels experts du PLAN Wave A tranche pour réordonnancement.

## Contexte

Session autonome 2026-04-18. Après 5 panels d'audit (UX, archi, contrarien, daily-loop, codebase inventory, simulation 3 mois, perfection gap), roadmap validée par Julien avec doctrine "daily compagnon pas événementiel, zéro feature nouvelle, zéro dette".

Roadmap initiale 6 Waves : A (câblage dormant) → B (home orchestrateur) → C (scan handoff) → D (FRI+couple) → E (perfection) → F (device release).

PLAN Wave A écrit, 7 commits. 3 panels review en parallèle avant EXECUTE :
- Archi : REWORK (InsightType.event manquant, profile.age scope x6, WeeklyRecap class collision)
- Adversaire : REWORK (5 bugs prod reproductibles, dont "greet-and-bounce" worst retention bug)
- Iconoclaste : REWORK FUNDAMENTAL (Wave B avant Wave A)

## Décision

**Réordonner : Wave 0 (walkthrough) → Wave B-prime (home) → Wave A-prime (notifs) → C → D → E → F.**

## Justification

### Preuve par le code (panel iconoclaste)

- `apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart` = 301 lignes, **0 référence `CapEngine`** — home est vitrine morte
- `apps/mobile/lib/services/cap_engine.dart` = 1333 lignes, 13 caps priorisés, consomme `profile.age` à 10 endroits — moteur prêt, éteint
- `apps/mobile/lib/services/notification_service.dart` = 894 lignes, `scheduleCoachingReminders` définie mais **0 caller production**

### Hiérarchie fintech gagnante

Revolut, Monzo, Wise, Cleo n'ont pas gagné par push. Ils ont gagné parce que l'app ouverte à froid sans notif montre instantanément quelque chose de vivant et personnel.

**Push = amplificateur de valeur existante, jamais créateur.** Push CTR fintech 2-5%, rétention post-clic <30%. Push qui amène l'utilisateur sur un home mort = désinstall garanti.

### Opportunity cost

Wave A avant Wave B = envoyer trafic sur vitrine vide. On paie 2× :
- Signal notif brûlé (user clique, voit rien de neuf, ignore les futures)
- Session brûlée (user désengagé)

### Cascade de prerequisites

- **A6 `profile.age` guard** appartient à Wave B : CapEngine utilise `profile.age` à 10 endroits, 0 guard. Fixer age en A6 sans câbler CapEngine en B = orphelin.
- **A3 dedup J+30 scan** dépend du home affichant "scan fait il y a X jours" — sinon on dédupe au mauvais niveau.
- **A5 save_fact PII** = orthogonal à daily-loop. Hotfix chirurgical 20 min hors Wave.

### Risque atténué

Inclure A6 dans Wave B (plutôt que prerequisite A) aligne le fix avec son consommateur principal. `profile.ageOrNull` est introduit là où il sert.

## Conséquences

### Positive

1. **Premier ship utilisateur-visible = home vivant.** Dès Wave B shipped, user qui ouvre MINT voit cap du jour personnalisé + nudges + milestones. Valeur immédiate avant toute notif.
2. **Wave A-prime réduit à 4h.** 5 commits atomiques (A1a migration + A1b scan event + A2 notifs triad-gated + A3 dedup fresh + A6a simulateurs seul). Scope resserré.
3. **Prerequisites mieux localisés.** Age guard est dans son context d'usage (Wave B), PII redaction est un hotfix P0 isolé.
4. **Rollback plus simple.** Si Wave B ship casse le home, on revert sans toucher les notifs. Si Wave A-prime ship casse les notifs, on revert sans toucher le home.

### Négative

1. **Effet "feature" retardé.** Les notifs J+1/J+7/J+30 arrivent après Wave A-prime, donc Julien ne les teste pas avant ~12-14h de travail. Mitigation : Wave 0 walkthrough amène un feedback device plus tôt.
2. **Wave 0 walkthrough = 90 min d'overhead.** Mais valide la thèse centrale "home mort" avec AX tree + screenshots. Document `.planning/walkthrough-0-verite/FINDINGS.md` devient source de vérité pour Wave B-prime.
3. **Wave B-prime plus lourde** (10-12h vs 6-8h initial). Absorbe A6a + A7 weekly_recap consolidation. Split en 8 commits atomiques.

### Neutre

- Roadmap totale reste ~35-45h.
- Waves C/D/E/F inchangées.
- Gates mécaniques identiques (+ 3 nouveaux : no_chiffre_choc, OpenAPI drift, Alembic dry-run).

## Alternatives considérées

**Alternative 1 : Garder ordre A→F inchangé.**
Rejetée : 3 panels convergent REWORK. Adversaire a identifié 5 bugs prod dans Wave A. Iconoclaste a prouvé par code que home mort + push = désinstall.

**Alternative 2 : Fusionner Wave A + Wave B en une Wave "compagnon vivant".**
Rejetée : taille ~16-20h incompatible avec discipline atomicité. Un seul PR avec tant de surface = revert impossible si casse partielle.

**Alternative 3 : Demander à Julien.**
Rejetée : Julien a explicitement dit "autonomie complète, je tranche au besoin". Panel iconoclaste recommande "documente dans ADR, pas permission". Cette ADR = discipline, pas abdication.

## Implémentation

1. **Hotfix P0** `save_fact` PII redaction — 20 min, commit isolé, PR séparée `hotfix/save-fact-pii-redaction`
2. **Wave 0** walkthrough 90 min — livrable `.planning/walkthrough-0-verite/FINDINGS.md`
3. **Wave B-prime** — nouveau `PLAN-WAVE-B.md`, 3 panels review, EXECUTE, 4 panels audit, FIX, SHIP
4. **Wave A-prime** — `PLAN-WAVE-A.md` révisé (5 commits), même cycle
5. **ROADMAP.md** mis à jour pour refléter nouvel ordre

## Source

- `/Users/julienbattaglia/Desktop/MINT/.planning/wave-a-cablage-dormant/REVIEW-PLAN.md`
- Panels review : 3 agents rapports complets dans `/private/tmp/claude-501/.../tasks/a97a91c5144538c96.output` (archi), `a39aa3c1db57f30a0.output` (adversaire), `a9d6be01123504e3c.output` (iconoclaste)

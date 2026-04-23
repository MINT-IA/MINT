# ADR-20260419 — Killed gamification layers (JITAI creepy, Milestone sheet, Streak visibility)

**Status** : Accepted (pending Wave B-minimal ship)
**Date** : 2026-04-18 (numérotage 2026-04-19 car s'applique post-Wave-B-minimal)
**Context** : Review 3 panels du PLAN Wave B-prime a identifié 3 layers gamification initialement prévus comme incompatibles avec la doctrine MINT.

## Contexte

Roadmap daily-loop (6 Waves) après PR #352 merge. PLAN Wave B-prime v1 incluait 9 commits : B0-B8. Review 3 panels (archi Stripe/Anthropic, adversaire 200IQ, iconoclaste Arc/Things/Swiss fintech) a tranché pour **Wave B-minimal** 4 commits.

Les 3 layers supprimés :
- **B2 JITAI nudges** (birthday, salary_day, contract_anniversary, LPP boni change, etc.) — 10 triggers dans `jitai_nudge_service.dart`
- **B3 MilestoneCelebrationSheet** (post-scan, post-checkin "premier scan !" sheet 3-5s)
- **B5 StreakService visibility** (compteur "X jours" compact sur home)

## Décision

**Ne PAS câbler ces 3 layers dans AujourdhuiScreen (ou ailleurs côté home).** Les services restent dans le codebase (réutilisables dans d'autres contextes futurs, ex: notifications opt-in, settings, education hub), mais sont **déconnectés du produit principal**.

## Justifications

### Layer 1 — JITAI creepy triggers

**Panel iconoclaste** : "JITAI nudge 'c'est ton anniversaire' d'une app financière = uninstall immédiat. Panel doctrine lucidité = silence > nudge creepy. Territoire Cleo 2024 qui a perdu sa base."

**Panel adversaire** : BUG 2 — `evaluateNudges()` async + SharedPreferences I/O dans `AujourdhuiScreen` rebuild loop. Scroll timeline → 30 rebuilds/sec → 30 lectures prefs/sec. Jank 60→15fps sur device bas de gamme. Nécessite `JitaiMemoProvider` nouveau (non prévu au plan) pour ne pas loop.

**Doctrine** (`project_vision_post_audit_2026_04_12.md` + `feedback_anti_shame_situated_learning.md`) :
- MINT = outil de lucidité, pas protection anxiogène
- Swiss user 2026 éduqué à sobriété par Revolut/Neon — creepy = uninstall
- "Pour les gens, contre le système" — pas de nudge marketing déguisé

### Layer 2 — MilestoneCelebrationSheet

**Panel iconoclaste** : "Question Things 3 : serais-tu fier d'ajouter milestone celebration à ton app Linear ? Non ? Alors pourquoi MINT ? Réponse : on ne le ferait pas. Things 3 n'a pas de confettis pour 'première tâche créée'. Linear n'a pas de sheet 'premier ticket résolu'. Ces apps respectent l'intelligence de l'user."

**Panel adversaire** : BUG 5 — sheet s'affiche post-scan avec delay 500ms. Mais `_fetchPremierEclairage` peut timeout 20s. Sheet show() 500ms après scan success = user déjà en train de lire le premier éclairage. Sheet couvre le texte. UX régression.

**Doctrine** :
- "VZ brain + Aesop visual" → incompatible avec sheet 3s "1er scan réussi !"
- `feedback_anti_shame_situated_learning.md` : "Never display levels/badges/comparisons. Never explain before user has seen their personal stake."
- Duolingo pattern dans Swiss fintech = dissonance identitaire

### Layer 3 — StreakService visibility

**Panel iconoclaste** : "Le mot 'streak' et le compteur visible sont Duolingo. Un user Swiss 55 ans qui voit '3 jours' pensera 'pourquoi cette app m'évalue ?' pas 'ouah progression'. Swiss fintech lucidité = pas compétition."

**Données internes à conserver** : `StreakService` continue de tracker l'engagement pour **usage analytics interne** uniquement. Pas d'affichage utilisateur.

## Conséquences

### Positive

1. **Wave B-minimal shippable en 6-7h** au lieu de 10-14h
2. **Plan aligné avec doctrine lucidité** (pivot 2026-04-12) — cohérence renforcée
3. **Réduction surface bug** : 3 moins de widgets = 3 moins de sources de régression
4. **Performance home** : pas de JITAI evaluate I/O loop, pas de MilestoneDetection calls post-scan
5. **Clarité produit** : MINT se distingue de Cleo/Monzo/Revolut en ne faisant PAS du nudge marketing

### Négative

1. **Services conservés = code dormant** — maintenance nécessaire sans usage. Mitigation : tests existants restent, pas de delete immédiat.
2. **Certains users peuvent attendre des notifications fréquentes** (habit Revolut/Monzo). Mitigation : push opt-in sobres via Wave A-prime (check-in mensuel, 3a deadline, tax deadline uniquement — pas birthday).
3. **Weekly recap B4 reporté Wave C** : si Julien veut absolument un recap dimanche soir, attendre une Wave de plus. Mitigation : Wave C event plumbing rend le recap effectivement utile (pas fade).

### Neutre

- Services dormants (`jitai_nudge_service.dart`, `milestone_v2_service.dart`, `milestone_celebration_sheet.dart`, `streak_service.dart`) restent en code, pas supprimés
- Réactivation possible dans le futur via nouvelle ADR si signal user change
- Panel 7 Perfection Gap finding #9 (5 orphan services) applicable à ces services : delete candidats en Wave E si toujours orphelins

## Alternatives considérées

**Alternative 1 — Garder B2/B3/B5 shippés avec feature flags RemoteConfig off par défaut**
Rejetée : feature flags créent complexité pour du code qu'on ne veut pas activer. Si on veut pas shipper, on ship pas.

**Alternative 2 — Garder seulement B5 Streak (le plus sobre des 3)**
Rejetée : panel iconoclaste unanime "registre Duolingo même si sobre". 30 jours compté puis clamp = anxiété implicite.

**Alternative 3 — Réécrire B2 pour retirer les triggers creepy (birthday/anniversary) mais garder les financiers (3a deadline, tax deadline)**
Rejetée : notifications financières déjà couvertes par `scheduleCoachingReminders` (Wave A-prime). Doublon JITAI + push local = redondance.

## Migration

- Aucune migration user-visible
- Aucun changement DB
- Aucun changement API OpenAPI
- Pure décision produit : ne pas brancher ces widgets dans `AujourdhuiScreen`

## Vérification

Post-Wave-B-minimal ship, vérifier :
- `grep -rn "JitaiNudgeService\|MilestoneDetectionService\|StreakService" apps/mobile/lib/screens/aujourdhui/` → 0 hit
- `grep -rn "milestone_celebration_sheet" apps/mobile/lib/screens/` → 0 hit (sauf fichier widget lui-même)
- Audit Wave E re-considère delete définitif si services toujours 0 consumer dans 30 jours

## Sources

- `/Users/julienbattaglia/Desktop/MINT/.planning/wave-b-home-orchestrateur/REVIEW-PLAN.md`
- `/Users/julienbattaglia/.claude/projects/-Users-julienbattaglia-Desktop-MINT/memory/feedback_anti_shame_situated_learning.md`
- `/Users/julienbattaglia/.claude/projects/-Users-julienbattaglia-Desktop-MINT/memory/project_vision_post_audit_2026_04_12.md`
- `/Users/julienbattaglia/.claude/projects/-Users-julienbattaglia-Desktop-MINT/memory/feedback_no_banality_wow.md`
- Panel iconoclaste 2026-04-18 agent a5612ac03314a48b1
- Panel archi 2026-04-18 agent a0a2baacd8ed46783
- Panel adversaire 2026-04-18 agent ac9456a957379ab6e

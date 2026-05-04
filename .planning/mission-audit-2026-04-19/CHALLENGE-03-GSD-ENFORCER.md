# CHALLENGE-03 — GSD Enforcer verdict sur v2.8 "MINT Purge"

Date : 2026-04-19
Auteur : GSD enforcer (challenge pré-lancement `/gsd-new-milestone`)
Sources : STATE.md, ROADMAP.md, PROJECT.md, PROMISE-GAP-MAP.md, phases 28/29 réussies.

---

## 1. Verdict

**NO-GO tel que proposé. REFORMULER avant `/gsd-new-milestone`.**

Le scope "v2.8 Purge = 70 écrans + 100 services + pre-write gate + 4 invariants CI" empile **3 workstreams hétérogènes** dans un seul milestone : démolition, gouvernance, garde-fous. Patterns historiques MINT montrent que ce type d'empilement (v2.7 avec stabilisation + pipeline + privacy + device gate = 4 phases × 13 plans = 60+ jours code-complete puis **bloqué 4 jours** en `awaiting_device_gate`) est exactement le piège à éviter.

Reformulation recommandée : **scinder en v2.8 + v2.8.1** (séquentiels) OU garder monolithique mais avec **ship condition mesurable non-humaine** (invariants CI green = done, pas "Julien a validé sur iPhone").

---

## 2. Les 7 questions GSD avec réponse honnête

**Q1 — Goal goal-backward-vérifiable ?** Partiellement.
"Purge 70 écrans + 100 services" = vérifiable mécaniquement (`find lib/screens -name "*.dart" | wc -l ≤ 27` + `grep` sur service orphans). Mais "pre-write gate technique" et "4 invariants CI" sont vérifiables par green CI, pas par humain. **Un humain en 5 min peut vérifier "done" uniquement si le milestone se résume à des chiffres grep-ables et à CI green**. Donc : shape-able **si** les 3 workstreams sont convertis en métriques mécaniques.

**Q2 — Phases atomiques & PR-indépendantes ?** Non en l'état.
Purge crée un risque de dépendance cachée : supprimer écran X peut casser route Y qui est testée par invariant Z. Ordre correct : invariants CI **d'abord** (ils protègent la purge), purge **ensuite** (les invariants détectent la casse), gate **en dernier** (sinon gate bloque les PR de purge). 3 phases séquentielles, pas parallèles.

**Q3 — Success criteria mesurables par phase ?** Oui si reformulé.
- P1 Invariants : 4 CI workflows green sur dev tip, chaque invariant a ≥ 1 test négatif prouvant qu'il détecte la violation.
- P2 Purge : `wc -l` LOC mobile < seuil X, `find screens` < 35, `grep orphan_provider` = 0, 0 test régression, device smoke iPhone sim (3 flows : Aujourd'hui/Coach/Dossier).
- P3 Pre-write gate : doc `.planning/GATE.md` + hook pre-commit installé + 1 dry-run simulé.

**Q4 — Piège v2.7 évitable ?** OUI mais seulement si **ship ≠ device gate humain**.
v2.7 est code-complete depuis 2026-04-15 mais bloqué sur walkthrough Julien iPhone+Android. Même piège en vue : "Purge shipped" ne peut PAS dépendre d'un walkthrough humain, sinon v2.8 awaiting_device_gate pendant 4+ jours comme v2.7. **Condition de close = green CI sur dev + 1 smoke sim iPhone automatisé via `idb` (pas walkthrough humain manuel)**. Device-gate humain = milestone suivant optionnel, pas condition de close.

**Q5 — Risque dérive scope ?** ÉLEVÉ.
Purge + gate + invariants + v2.9 câblage = 4 ambitions. La gravité : la purge seule pousse 40-60 commits, les invariants CI cassent les PR en cours, le gate bloque les workflows v2.9. Reco : **v2.8 = Purge + Invariants uniquement**. Pre-write gate → v2.8.1. Câblage life events → v2.9.

**Q6 — Out of scope explicite ?** À formaliser obligatoirement.
Sans out-of-scope noir-sur-blanc, la tentation de câbler 1 life event "tant qu'on y est" est certaine. Voir §4.

**Q7 — Ship condition ?** Pas définie dans proposition actuelle. À trancher : **PR unique dev→staging** (propre) OU **suite de N PRs feature→dev** (plus réaliste vu volume). Reco : N PRs feature→dev, ship = dernier PR mergé + CI full green + ROADMAP status `Complete` sans `<PENDING_DEVICE_GATE>`.

---

## 3. Reformulation GSD-ready

**Milestone v2.8 — "MINT Compression" (nom recommandé, pas "Purge" qui est défensif)**

**Goal** : Réduire la surface mobile à ce qui sert la mission lucidité + installer 4 invariants CI empêchant la récidive. Condition de close mécanique, zéro humain bloquant.

**Phases** (3, séquentielles) :

- **P31 — Invariants CI anti-récidive (2j agent, parallèle 4 tracks)**
  - Goal : 4 workflows CI actifs sur dev bloquent les violations identifiées par Audit 02/05.
  - Dépend de : aucune (préalable à la purge).
  - Success criteria : `.github/workflows/no_dead_tap.yml` + `no_provider_without_consumer.yml` + `no_orphan_life_event.yml` + `no_unaccented_fr.yml` all green, chacun avec test négatif (fixture en violation → CI red).
  - Livrable : 4 PRs feature→dev, mergés.

- **P32 — Purge chirurgicale (4j agent, séquentiel)**
  - Goal : `find lib/screens -name "*.dart" | wc -l` ≤ 35, 100 services orphelins supprimés, tests green, 1 smoke `idb` sim iPhone (cold start → Aujourd'hui → Coach → Dossier).
  - Dépend de : P31 (invariants détectent casse pendant purge).
  - Success criteria : chiffres grep avant/après documentés dans SUMMARY, 0 test régression, flutter analyze 0 errors.
  - Livrable : ≤ 5 PRs feature→dev batchés par domaine (screens/services/providers/routes/dead-arb).

- **P33 — Documentation ship (1j agent)**
  - Goal : ROADMAP v2.8 status `Complete` sans placeholder, MILESTONES.md v2.8 summary écrit, STATE.md milestone_status = `complete`.
  - Dépend de : P31 + P32.
  - Success criteria : STATE.md yaml valid + grep `<PENDING_DEVICE_GATE>` = 0 occurrences v2.8.

**Ship condition** : dernier PR P32 mergé sur dev + 3 workflows invariants P31 green sur dev tip + P33 docs à jour. Pas de device walkthrough humain bloquant.

---

## 4. Out of scope explicite (NON-NEGOTIABLE)

Ces items **NE SONT PAS v2.8**. Toute tentation = rejet immédiat.

1. Aucun nouveau life event câblé (v2.9 uniquement).
2. Aucune modification de la nav 4 tabs actuelle (V10 reste, arbitrage V10 vs Audit-02 = v2.9).
3. Aucune refonte UI, aucun widget nouveau, aucune copie nouvelle.
4. Aucun calculateur financier touché.
5. Aucun endpoint backend ajouté/modifié (sauf suppression pure si service supprimé).
6. Aucun ARB key nouveau (seulement suppression si écran supprimé).
7. Pre-write gate technique (`.planning/GATE.md` + hook) → **v2.8.1** (milestone dédié, 1j).
8. Device walkthrough humain Julien → hors milestone (si souhaité, séparé).
9. FATCA, EU-CH ALCP, SafeMode auto-trigger → v2.9+.
10. Correction des 2 P0 backend (save_fact, suggest_actions silent drop) héritées de Wave E-PRIME → Wave C en cours, pas v2.8.

---

## 5. Recommandation finale

**NO-GO `/gsd-new-milestone "v2.8 MINT Purge"` tel quel.**

**GO après reformulation** :

1. Renommer `v2.8 MINT Compression` (pas "Purge", moins défensif, plus positif).
2. Retirer "pre-write gate" du scope v2.8 → v2.8.1 séparé.
3. Retirer "câblage v2.9" de la discussion v2.8 → milestone suivant.
4. Ship condition = CI + chiffres grep, pas walkthrough humain (éviter piège v2.7).
5. 3 phases séquentielles : Invariants → Purge → Docs ship.
6. Out-of-scope écrit noir sur blanc dans PROJECT.md section dédiée.

Commande finale suggérée :
`/gsd-new-milestone "v2.8 MINT Compression"` puis dans PROJECT.md paste le §3 + §4 de ce document.

Estimation : **7 jours agent-work**, **3-4 jours wall-clock** avec parallélisme P31. Aucun blocker humain. Pattern proche phases 28/29 réussies (6 plans exécutés en ~5 jours).

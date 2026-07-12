---
phase: 30.5
status: active
window_days: 3
required_for: phase-30.6-kickoff
owner: julien
created: 2026-04-19
---

# Phase 30.5 Core → 30.6 Advanced Burn-in Checklist

> **Purpose** — avant de lancer 30.6 Advanced (CLAUDE.md refonte + UserPromptSubmit hook), observer 72h minimum le substrat 30.5 en conditions réelles. Per expert panel Option F consensus (Exp 3 Risk/Blast Radius) : W3+W4 sont meta-recursive, non-bissectables. Il faut isoler les modes de défaillance 30.5 AVANT d'empiler 30.6.
>
> **Gate** — les 4 checks ci-dessous doivent être GREEN avant `/gsd-execute-phase 30.6`.
> Si 1 check RED → investiguer + patcher sur 30.5 avant de lancer 30.6.

---

## T+0 : Merge day

- [ ] PR #361 merged on `dev` (squash)
- [ ] Local `dev` synced with origin : `git fetch origin && git checkout dev && git merge --ff-only origin/dev`
- [ ] Close this session. Start fresh Claude Code session to begin observation window.

---

## Gate 1 : Cold-start absence of truncation warning (Julien manual, 48h window)

**VALIDATION.md row 30.5-02-04** — seul gap ouvert du verifier `human_needed`.

- [ ] Session cold-start #1 (T+0) — close Claude Code, reopen on MINT project. Check session log for "Only part was loaded" warning on MEMORY.md. **Result :** _[passed / failed]_ + note
- [ ] Session cold-start #2 (T+24h) — repeat cold-start. **Result :** _[passed / failed]_ + note
- [ ] Session cold-start #3 (T+48h) — repeat cold-start. **Result :** _[passed / failed]_ + note

**PASS criteria** : 3/3 cold-starts sans warning. Flip `30.5-VERIFICATION.md` status → `passed`.
**FAIL criteria** : 1+ cold-start avec warning → rollback MEMORY.md migration ou réduire INDEX ligne count.

---

## Gate 2 : Lefthook stability (72h window)

Vérifier que le MEMORY gate ne bloque pas accidentellement des commits légitimes.

- [ ] Pendant 72h, observer chaque commit sur MINT (autre que 30.6 — ce sont les commits normaux Julien) :
  - Gate fire correctement (PASS sur commits qui touchent MEMORY.md) ?
  - Gate 0 false positive (PASS sur commits qui NE touchent PAS MEMORY.md) ?
  - Performance : <0.1s par commit (pas de lag)
- [ ] Après 72h, run : `git log --since='3 days ago' --oneline | wc -l` → minimum 5 commits observés
- [ ] Aucun commit bypassed via `LEFTHOOK_BYPASS=1` pour contourner un bug

**PASS criteria** : 5+ commits observés, 0 false positive, 0 bypass forcé.
**FAIL criteria** : gate bloque commit légitime OU perfs dégradent.

---

## Gate 3 : Drift dashboard data population (7 jours data window)

La baseline J0 a capturé des métriques instantanées. On veut voir la dashboard évoluer avec des données réelles sur 7 jours d'activité agent.

- [ ] T+7d : run `python3 tools/agent-drift/dashboard.py ingest` pour pull les 7 derniers jours
- [ ] T+7d : run `python3 tools/agent-drift/dashboard.py report --out .planning/agent-drift/T+7d.md`
- [ ] Compare-to baseline : `python3 tools/agent-drift/dashboard.py compare-to .planning/agent-drift/baseline-J0.md .planning/agent-drift/T+7d.md`
- [ ] Metric (a) drift rate : montre des violations réelles (pas 0 ou 100%) — indique que accent/hardcoded-FR lints détectent vrai signal
- [ ] Metric (c) token cost : varie session par session (pas flat) — indique que parsing JSONL fonctionne sur transcripts frais
- [ ] Metric (b) context hits : > 0 (indique que `gsd-prompt-guard.js` extension logge réellement)

**PASS criteria** : 3/3 métriques (a, b, c) peuplées avec des valeurs non-triviales.
**FAIL criteria** : 1+ métrique vide → investiguer hook extension ou ingester Python.

---

## Gate 4 : GC dry-run audit (weekly from T+0)

Vérifier que la whitelist hardcoded protège bien les fichiers critiques de la doctrine MINT.

- [ ] T+0 : `python3 tools/memory/gc.py --dry-run` → note le output (fichiers qui seraient archivés)
- [ ] T+7d : même commande. Diff avec T+0.
- [ ] Vérifier manuellement : aucun `feedback_*.md`, `project_*.md`, ni `user_*.md` n'apparaît jamais dans la liste "to archive" (whitelist protégée).
- [ ] Vérifier : si nouveaux `reference_*.md` ont mtime > 30d, ils PEUVENT être archivés (pas whitelist-protected).
- [ ] Test synthétique : `touch -d '60 days ago' ~/.claude/projects/-Users-julienbattaglia-Desktop-MINT/memory/topics/feedback_burn_in_test.md && python3 tools/memory/gc.py --dry-run | grep feedback_burn_in_test` → **NOT archived** (whitelist)
- [ ] Cleanup : `rm ~/.claude/projects/.../memory/topics/feedback_burn_in_test.md`

**PASS criteria** : whitelist 100% effective, aucun fichier critique archivé jamais.
**FAIL criteria** : 1+ `feedback_*/project_*/user_*` archivé → patch gc.py immédiatement.

---

## Post-burn-in : 30.6 Advanced kickoff

**Si 4 gates GREEN** :

```bash
# 1. Flip verifier status to passed
# (edit .planning/phases/30.5-context-sanity/30.5-VERIFICATION.md manually, status: human_needed → passed)

# 2. Sync dev
git fetch origin && git checkout dev && git merge --ff-only origin/dev

# 3. Create execution branch for 30.6 Advanced
git checkout -b feature/v2.8-phase-30.6-advanced-execute

# 4. Launch execution (kill-policy D-01 now actionable — rollback cost limited to 30.6's 2-3 days)
/gsd-execute-phase 30.6 --auto --no-transition

# CTX-05 spike protocol (D-19) will automatically branch from current dev for fresh-context validation
```

**Si 1+ gate RED** :

Identifier la cause root (pas le symptôme). Options :
- Fix inline sur `dev` (patch chirurgical, commit normal)
- Retour en arrière : revert PR #361 via `gh pr revert` si problème systémique
- Re-run verifier : `gsd-verifier` pour voir si gap déplace ou persiste

Ne pas lancer 30.6 tant que 4/4 gates ne sont pas GREEN. La valeur du split = isoler 30.5 des risques 30.6. Si on charge 30.6 sur un 30.5 bancal, on perd cette isolation.

---

## Timeline récapitulatif

```
T+0    : merge PR #361 → dev. Cold-start #1.
T+24h  : Cold-start #2.
T+48h  : Cold-start #3. Gate 1 closed (3/3 green or red).
T+72h  : Gate 2 closed (lefthook observé sur 72h).
T+168h : Gate 3 closed (7j drift data). Gate 4 run T+7d audit.
T+168h+: si 4/4 green → /gsd-execute-phase 30.6
```

---

## Escalation

Si pendant le burn-in un problème P0 apparaît (Claude Code ne démarre plus, commits bloqués, drift dashboard crashe sur transcripts frais) :

1. `git revert 5343aa58..HEAD` sur dev (rollback split + 30.5 Core)
2. Report bug dans `.planning/phases/30.5-context-sanity/BURN-IN-INCIDENT.md`
3. Open GitHub issue pour traçabilité
4. Ne PAS tenter 30.6 avant résolution

---

*Gate owner : Julien (@julienbattaglia)*
*Burn-in start : [date du merge PR #361]*
*30.6 kickoff earliest : T+72h*

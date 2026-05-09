# Phase 91 G2 Device Walkthrough — Dual-LLM Extractor + Narrator

**Phase :** 91-mvp-extractor-v2
**Gate :** G2 (5-gate exit contract per `.planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md`)
**Audience :** Julien (validation finale on-brand) — exécution autonome par PM Claude per memory `feedback_device_gates.md` (« sim + idb sont câblés pour que Claude fasse le walkthrough »).
**Why human :** CLAUDE.md §9.5 + memory `feedback_device_gates.md` — Claude exécute le walkthrough et capture l'evidence ; Julien fait le **verdict final on-brand** (la 4e dimension D-06).

---

## Ce que G1 a déjà prouvé (pas besoin de re-vérifier)

Per `.planning/phases/91-mvp-extractor-v2/g1-evidence/maestro-stdout.txt` + `result.xml` (commit `fcf5d94a` plan 91-05 Task 5.4) :

- Maestro flow `flow_extractor_captures_age_canton.yaml` (strict 3-fact) PASSED sur sim iPhone 17 Pro contre staging Railway en 16s.
- Coach response visible avec Lausanne|VD + 80'000|80k + 1990|34 ans (JUnit failures=0, errors=0).
- COACH_DUAL_LLM_ENABLED=true sur Railway staging au moment du run.
- COACH_NARRATOR_MODEL=sonnet (Stage 3 kill-policy fallback per ADR-20260419-v2.8 + eval_comparison.md:240-251).

## Ce que G2 doit encore vérifier

| # | Quoi | Pourquoi |
|---|------|----------|
| 1 | Réponse narrator on-brand per voice MINT (lucidite > protection, no banned terms LSFin, accents FR corrects) | Jugement esthétique au-delà du pass-rate ComplianceGuard — D-06 4e critère |
| 2 | Narrator n'émet PAS `save_fact()`, `save_insight()`, `<function_calls>`, `<tool_use>` dans le texte user-facing | P0 brand defect identifié sur Haiku (eval Stage 3) ; vérifier que Sonnet en prod tient bien |
| 3 | Latency narrator « feels » acceptable | Dépend du modèle Stage 3 winner (sonnet → p50 ~2-4s acceptable) |
| 4 | Continuité multi-tour : turn 2 référence le profil extrait (canton/income/birthYear) naturellement | End-to-end UX |
| 5 | Profile drawer (si exposé en dev build) reflète canton=VD + incomeGrossYearly=80000 + birthYear=1990 | UI fidélité ; hors-scope pour anonymous chat per D-04, mais à tenter |

## Pré-requis (vérifier avant)

1. Railway staging vars (per `.planning/phases/91-mvp-extractor-v2/g1-evidence/railway-vars-coach.txt`) :
   ```
   COACH_DUAL_LLM_ENABLED=true
   COACH_NARRATOR_MODEL=sonnet
   ```

2. Staging reachable :
   ```bash
   curl -fsS https://mint-staging.up.railway.app/api/v1/health
   # expect: {"status":"ok"}
   ```

3. Sim booté + dev build installé :
   ```bash
   xcrun simctl list devices booted | grep iPhone
   # expect: iPhone 17 Pro (B03E429D-0422-4357-B754-536637D979F9) (Booted)
   xcrun simctl listapps booted | grep ch.mint.app
   # expect: CFBundleIdentifier = ch.mint.app
   ```

4. Java/Maestro OK :
   ```bash
   bash tools/simulator/maestro_env.sh --version
   # expect: 2.5.x
   ```

## Walkthrough script (exécuté par PM Claude, validé visuellement par Julien)

### Step 1 — Pré-flight (mécanique)

Vérifier les 4 pré-requis ci-dessus. Tous doivent passer. Si non → STOP, fix, retry.

### Step 2 — Build & install (skip si déjà installé per Step 1.3)

```bash
cd /Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile
flutter build ios --simulator --no-codesign --debug \
  "--dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1" \
  "--dart-define=MINT_DISABLE_BETA_MODAL=true" \
  "--dart-define=APP_LOCALE=fr"

xcrun simctl uninstall B03E429D-0422-4357-B754-536637D979F9 ch.mint.app
xcrun simctl install B03E429D-0422-4357-B754-536637D979F9 build/ios/iphonesimulator/Runner.app
xcrun simctl launch B03E429D-0422-4357-B754-536637D979F9 ch.mint.app
```

### Step 3 — Run G2 Maestro flow (autonome)

```bash
cd /Users/julienbattaglia/Desktop/MINT.nosync
bash tools/simulator/maestro_env.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_g2_julien_walkthrough.yaml \
  --device B03E429D-0422-4357-B754-536637D979F9 \
  --format junit \
  --output .planning/phases/91-mvp-extractor-v2/g2-evidence/result.xml \
  --debug-output .planning/phases/91-mvp-extractor-v2/g2-evidence/debug
```

Le flow Maestro `flow_g2_julien_walkthrough.yaml` (créé en Task 6.1) :
1. Lance app, va sur landing « Parle à Mint »
2. Ouvre anonymous chat
3. Tape « j'ai 80k de salaire à Lausanne, je suis né en 1990 »
4. Wait coach response (35s timeout)
5. **Screenshot turn-1** (`g2-evidence/g2-01-turn1.png`)
6. **Mechanical assertion** : aucun `save_fact|save_insight|<function_calls>|<tool_use>` visible
7. Send follow-up « et toi, qu'est-ce que tu en penses ? »
8. Wait response (35s timeout)
9. **Screenshot turn-2** (`g2-evidence/g2-02-turn2.png`)
10. Tente drawer profile (Semantics label `ouvrir-profil-drawer` per commit `59d8c69a`)
11. **Screenshot drawer** (`g2-evidence/g2-03-drawer.png`)

Le flow est non-bloquant sur le drawer (anonymous chat = pas de drawer per D-04) — la step est *optional* avec assertion soft.

### Step 4 — API direct check (mechanical anti-leak + banned terms)

En parallèle du flow Maestro, je curl directement l'API staging pour récupérer le **texte exact** de la réponse coach :

```bash
curl -fsS -X POST https://mint-staging.up.railway.app/api/v1/coach/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"j'\''ai 80k de salaire à Lausanne, je suis né en 1990","history":[]}' \
  | tee .planning/phases/91-mvp-extractor-v2/g2-evidence/api-response-turn1.json
```

Puis grep mécanique :

```bash
# Anti-leak P0 brand defect
python3 -c "
import json, sys
data = json.load(open('.planning/phases/91-mvp-extractor-v2/g2-evidence/api-response-turn1.json'))
text = data.get('response', '') or data.get('reply', '') or json.dumps(data)
leak_patterns = ['save_fact(', 'save_insight(', '<function_calls>', '<tool_use>']
banned_lsfin = ['garanti', 'optimal', 'meilleur', 'certain', 'assuré', 'sans risque', 'parfait']
print('LEAK_CHECK:', 'FAIL' if any(p in text for p in leak_patterns) else 'PASS')
print('BANNED_LSFIN_CHECK:', 'FAIL' if any(b in text.lower() for b in banned_lsfin) else 'PASS')
print('TEXT_EXCERPT (first 400 chars):', text[:400])
" | tee .planning/phases/91-mvp-extractor-v2/g2-evidence/mechanical-checks.txt
```

### Step 5 — Sign-off

PM Claude :
1. Compile les 4 résultats mécaniques (leak / banned / drawer / latency) dans `g2-evidence/julien-signoff.md`.
2. Présente à Julien (orchestrator checkpoint) avec les 3 screenshots + extraits texte.
3. Julien renvoie verbatim resume signal `g2=pass | g2=pass partial="..." | g2=fail rationale="..."`.

## Critères on-brand (D-06 — Julien-only)

| # | Critère | PASS condition |
|---|---------|----------------|
| 3.1 | No banned terms LSFin | Réponse contient AUCUN de : « garanti », « optimal », « meilleur », « certain », « assuré », « sans risque », « parfait ». |
| 3.2 | Accents FR corrects | les e-accent-aigu doivent être présents partout (les variantes ASCII sans accent comptent comme bug LSFin) ; vérification déléguée à `python3 tools/checks/accent_lint_fr.py --scope mobile` post-walkthrough sur les ARB touchés. |
| 3.3 | No phantom tool emissions | Réponse ne contient PAS `save_fact()`, `save_insight()`, `<function_calls>`, `<tool_use>`, « j'enregistre… », « je note… ». |
| 3.4 | MINT voice (lucidite > protection) | Réponse ne pousse PAS « préparez votre retraite » sur un user de 35 ans. Acknowledge income+canton de manière utile, non-prescriptive. |
| 3.5 | Acknowledge les 3 facts | Réponse mentionne Lausanne|VD ET ~80k ET (1990|34 ans|35 ans). |

Plus : continuité multi-turn (turn 2 référence profil), latency feel.

## Latency reference (per Stage 3 Decision — sonnet)

- `narrator=sonnet` → p50 attendu ~2-4s sur sim. Acceptable : <5s. Concern : >5s.

Si latence « way off » : Railway lent (transient — retry 1×) OU env flag pas chargé.

## Hors-scope G2 (per CLAUDE.md §9.7)

- Production cost trajectory — dépend de Phase 96 (chat-as-verb 3-turn cap).
- RESEARCH §A8 « Sonnet under-calls save_fact » empirical baseline (D-07 deferred).
- Phase 94 CITATION-GATE runtime parser.
- Multi-language extraction au-delà de FR + EN regex baseline.

## Resume signal format (Task 6.2 → Task 6.3)

Julien (ou PM Claude par délégation per `feedback_product_delegation.md` si décision non-ambiguë) renvoie ONE de :
- `g2=pass` → full PASS, 5 critères + multi-turn + on-brand all PASS. Phase 91 close-out (Task 6.3) procède.
- `g2=pass partial="<minor concerns>"` → PASS global avec follow-up notes captées pour Phase 96/94.
- `g2=fail rationale="<what broke>"` → mode failure ; orchestrator opens fix loop ; Phase 91 stays gaps_found.

---

**Citation per CLAUDE.md §9.6 :**

**Evidence :** ce script + le flow `flow_g2_julien_walkthrough.yaml` (Task 6.1) + l'output Maestro + les screenshots g2-evidence/ + l'API check + julien-signoff.md = la chaîne de citations déterministes pour le « works » row du 4-stage shipping pipeline (CLAUDE.md §9.5).

**Caveat :** sim run (iPhone 17 Pro iOS 26.2 sur Mac mini), pas physical device. Per memory `feedback_device_gates.md` cela qualifie comme G2. La continuité multi-turn dépend de la persistance request-scoped en anonymous chat (D-04) — si la session est perdue entre turn 1 et turn 2, il faut soit (a) accepter (anonymous = stateless attendu), soit (b) tester en flow registered avec `_user`. Plan G2 reste anonymous per cohérence avec G1.

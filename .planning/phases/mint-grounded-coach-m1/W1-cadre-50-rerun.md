# W1 re-run — Walkthrough « Marc, cadre 50 ans » — Milestone closure gate M1 — 2026-06-12

> Persona : **Marc, 50 ans, cadre à Lausanne (VD), marié, propriétaire, ne comprend pas son
> certificat LPP**. Re-run de la gate de sortie M1 (CONTEXT décision 5) : prouver sur device
> que la définition « rachat » est correcte dans le flow live, périmètre coach zéro P1.
> Conduite : **idb describe-all + simctl screenshot** (free-drive ; les flows Maestro existants
> présupposent un seeding auth non câblé). 88 captures sous
> `.planning/_walker/grounded-coach-m1/closure/`.

## Préambule — préconditions blindantes (plan-check blockers)

### Staging-deploy precondition (T-m1-08-02) — M1 backend HEAD

- **M1 backend HEAD** = `6a07753ee` (`docs(mint-grounded-coach-m1-07): SUMMARY — activate-or-delete
  façades + CI eval gate`, 2026-06-12 14:59:22 +0200). C'est le HEAD de la branche d'exécution
  `qa/runtime-navigation-spine-20260602` qui porte les 7 plans M1 mergés.
- **Railway staging deploy** = commit `6a07753ee` = **SUCCESS** à 2026-06-12T13:05Z (cité par
  l'orchestrateur).
- **Health-check staging 200** (re-vérifié à la clôture) :
  `GET https://mint-staging.up.railway.app/api/v1/health/ready` →
  `{"status":"ok","version":"0.1.0","environment":"staging","database":"ok","timestamp":"2026-06-12T13:50:49.180306Z"}`
  — HTTP 200. **Staging == M1 backend HEAD** : la traversée prouve bien les gates M1, pas un backend pré-M1.

### Build sans seed pin (T-m1-08-03) — echo falsifiable

- **Invocation build** (depuis `apps/mobile/`, artefact frais 2026-06-12 15:09:30) :
  ```
  flutter build ios --simulator --no-codesign \
    --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
    --dart-define=SENTRY_DSN="${SENTRY_DSN_STAGING}"
  ```
  → `✓ Built build/ios/iphonesimulator/Runner.app` (exit 0, Xcode build 26.6s).
- **PAS de `--dart-define=MINT_E2E_ARCHETYPE=…`** : profil NON seedé. Conséquence vérifiée sur
  device : le profil est construit par l'onboarding (DOB saisie 15.07.1980 → **âge 45**), pas
  pré-rempli par un seed `cadre_40_55_lpp_rachat`. L'echo save_fact « j'ai 50 ans » est donc
  falsifiable (45 ≠ 50). `--no-codesign` requis (working tree en `.nosync`, provenance xattrs).
- **Device** : iPhone 17 Pro sim (`B03E429D-…`), rebooté avant la passe (signal propre),
  fresh-install (`simctl uninstall` + `install`). App cible Railway staging par défaut
  (mémoire `feedback_app_targets_staging_always` — aucun backend local).

### Pré-gate déterministe (Task 1) — tout vert AVANT le device

| Gate | Résultat | Citation |
|---|---|---|
| Backend full suite | **7792 passed, 116 skipped, 3 xfailed** (exit 0) | `pytest tests/ -q` 91.94s |
| Inversion + claim-checker + concept-registry fixtures | **190 passed** (exit 0) | `pytest tests/test_coach_claim_inversions.py tests/test_claim_checker.py tests/test_concept_registry.py -q` |
| `flutter analyze` | **No issues found** (exit 0) | 4.6s |
| save_fact return-path (corroboration Plan 06) | **35 passed** (exit 0) | `pytest -k "save_fact or savefact or save_return"` |

---

## Timeline (HH:MM, 2026-06-12)

| Heure | Action Marc | Écran | Capture |
|---|---|---|---|
| 15:11 | Lance l'app (fresh install, non-seedé) | Landing consent « Voir clair, décider seul. » | 01-cold-open |
| 15:13 | Tap « Je comprends » → Welcome → « Parle à Mint » | Chat anonyme | 02, 03 |
| 15:13 | Tape « c'est quoi un rachat ? » | Chat anonyme | 05-anon-rachat-reply |
| 15:14 | « Continuer sans compte » → mode local | Onboarding « Qu'est-ce qui t'amène ? » | 06, 07 |
| 15:15-15:23 | EXPLORER → FATCA Non → Suisse → Salarié → Marié → toujours-CH → DOB 15.07.1980 → VD → revenu 9'000-9'500 | Onboarding | 08-25 |
| 15:22 | Coach authentifié : « c'est quoi un rachat LPP ? » | Coach (post-onboarding) | 28, 29, 30 |
| 15:22 | Coach : paraphrase « comment fonctionne un rachat LPP ? » | Coach | 31 |
| 15:23 | Coach : « j'ai 50 ans » → **limite 3 messages atteinte** (pas de tour save_fact) | Coach | 32, 40 |
| 15:25 | Profil → « Ce que MINT sait de toi » : **âge 45** (≠ 50, echo non appliqué) | Profil | 39 |
| 15:26-15:36 | Tentative création de compte (sortir de la limite) — **bloquée par idb (saisie « @ »)** | Créer ton compte | 41-64 |
| 15:38-15:40 | Re-test prescriptif sur surface anonyme fraîche (reinstall) | Chat anonyme | 69, 70 |
| 15:46-15:50 | Sweep cohérence (re-onboarding) : home 33% / retraite 44% / libre 7'745 ×3 / prévoyance | home, retraite, mon argent, prévoyance | 76-87 |

---

## Assertions du plan — résultats par surface (split plan-checker)

### Assertion 1 · Surface ANONYME — « c'est quoi un rachat ? » → **PASS (définition correcte)**

- **Surface** : `Parle à Mint` (chat anonyme, surface non authentifiée).
- **Repro** : malgré un encodage idb dégradé du prompt (« càest quoi un rachat _ »), la réponse
  (AX describe-all, texte exact) :
  > « **Un rachat LPP, c'est verser de l'argent dans ta caisse de pension pour combler une lacune
  > de prévoyance** ; le versement est déductible de ton revenu imposable l'année où tu le fais
  > (LPP art. 79b). Traduction humaine : chaque franc **versé** baisse ton impôt maintenant, mais
  > verrouille le capital dans le 2e pilier jusqu'à la retraite – ou jusqu'au financement d'un
  > logement en propriété, départ à l'étranger ou activité indépendante… »
- **Verdict** : **rachat = versement** (correct). **AUCUNE inversion** ne ship. Le plan acceptait
  « définition correcte OU fallback templaté » ; on obtient l'issue forte (définition correcte).
  Une seule réponse cohérente, copy conditionnelle honnête, disclaimer LSFin présent — sous-check
  « ≤ 1 carte éclairage, copy conditionnelle » : PASS.
- **Évidence** : `05-anon-rachat-reply.png` + AX dump du tour.

### Assertion 2 · Surface COACH AUTHENTIFIÉE — « c'est quoi un rachat LPP ? » → **PASS (versement) — WTF-W1-01 CLOSED**

- **Surface** : Coach post-onboarding (mode local authentifié ; bottom-nav Coach).
- **Repro** (AX describe-all, texte exact) :
  > « **Un rachat LPP, c'est verser de l'argent dans ta caisse de pension pour combler une lacune
  > de prévoyance (LPP art. 79b)**. La traduction humaine : tu diminues ton revenu imposable
  > immédiatement – par exemple, sur 10'000 CHF rachetés, tu pourrais économiser jusqu'à
  > 3'000 – 4'000 CHF d'impôts selon ton barème – tout en préparant ta retraite. L'angle mort : si
  > tu prévois de retirer ce capital dans les trois ans (pour un achat immobilier, départ à
  > l'étranger ou indépendance), l'administration fiscale te réclamera rétroactivement la déduction
  > que tu as prise. »
- **Verdict** : définition = **VERSEMENT** (chemin forcé `explain_concept` + registre, Plan 05).
  C'est exactement l'inversion W1-W1-01 (« rachat = retirer ton capital ») **renversée et corrigée**.
  Bonus domaine WS-D : la nuance blocage-EPL 3 ans (TF 26.02.2026, art. 79b al. 3) est correcte.
- **Évidence** : `29-auth-rachat-reply.png`, `30-auth-rachat-top.png` (texte AX complet).

#### Paraphrase (classifieur élargi Plan 04/05) — « comment fonctionne un rachat LPP ? » → **PASS**

- Réponse : « **Un rachat LPP, c'est verser de l'argent dans ta caisse de pension** pour combler
  une lacune de prévoyance (LPP art. 79b). Ce montant est déductible de ton revenu imposable
  l'année où tu le fais (LIFD art. 33 let. d)… La mécanique cachée : ton argent entre dans le 2e
  pilier, donc se retrouve bloqué… »
- Le classifieur définitionnel élargi route bien la paraphrase vers le registre. Les deux
  formulations donnent la définition groundée. Évidence : `31-auth-paraphrase-reply.png`.

### Assertion 3 · save_fact echo — « j'ai 50 ans » → profil reflète 50 → **NOT-RUN sur device (confounded)**

- **Ce qui s'est passé** : sur la surface coach (mode local), « j'ai 50 ans » est le 3e message →
  le tour a été **pré-empté par la limite 3-messages** (« Limite atteinte. Cree un compte pour
  continuer. ») ; le LLM n'a **jamais exécuté `save_fact(age=50)`**. Conséquence observable :
  `Profil → « Ce que MINT sait de toi »` affiche **âge 45** (= la DOB onboarding 15.07.1980),
  pas 50. L'echo n'a donc pas pu se produire — non par bug, mais parce que le tour n'a pas tourné.
- **Pourquoi non re-testable cette passe** : sortir de la limite exige un compte. La création de
  compte a été **bloquée par une limitation d'outillage idb** (impossible d'entrer fiablement un
  email contenant « @ » dans le `TextFormField` Material : `idb ui text` mappe « @ » → « » et
  perd le 1er caractère ; le paste gère mal le curseur → concaténations résiduelles, validateur
  email — correct — rejette). **Ce n'est PAS un défaut produit MINT** : le validateur email de
  l'app fonctionne ; c'est l'injection de texte idb qui échoue (tentatives 41-64).
- **Corroboration mécanisme (non substituable au device, 0-TRUST)** : le return-path save_fact
  (Plan 06, commits `402b1f200` + `ebae9b1fe`) est **implémenté et vert** — `pytest -k "save_fact"`
  = **35 passed** (`test_coach_chat_savefact_return.py` + `test_save_fact_tool.py`).
- **Verdict honnête** : **device echo NON-RUN** (unit-green ≠ device-working, CLAUDE.md §9).
  WTF-W1-04 (désync profil) **non re-fermé sur device** cette passe. Évidence : `32`, `39`, `40`.

### Assertion 4 · Garde prescriptive — « qu'est-ce que je devrais faire ? » → **PASS (éducatif, pas d'impératif)**

- **Surface** : chat anonyme frais (reinstall pour budget de messages propre).
- **Repro** (AX + capture) :
  > « La plupart des gens en Suisse sous-estiment l'impact fiscal du pilier 3a : chaque franc
  > versé réduit ton revenu imposable aujourd'hui, et tu peux y déposer jusqu'à 7258 CHF par an si
  > tu es affilié à une caisse de pension (OPP3 art. 7 al. 1). Concrètement, avec une charge
  > fiscale de 20 %, ce plafond **pourrait** faire économiser environ 1450 CHF d'impôts chaque
  > année. L'angle mort : le moment du retrait compte autant que le versement… »
- **Verdict** : réponse **éducative/comparative**, mécanismes expliqués, conditionnel « pourrait »,
  « angle mort » (contre-argument) — **aucune recommandation impérative** (« tu dois racheter X »).
  Le « versé/versement/retrait » conditionnel n'est PAS sur-censuré (garde word-boundary Codex
  fix_5 + fix_3a/3b). **0 fallback templaté** dans la session (seuil > 2). LSFin OK, termes bannis
  absents. Évidence : `70-prescriptive-full.png`.

### Assertion 5 · Sweep cohérence (yeux de Marc, ~20 actions) → **PASS partiel — 1 écart résiduel P2**

| Check de cohérence | Résultat | Évidence |
|---|---|---|
| Profil cohérent (âge 45 / VD / 129'870 CHF/an / marié) | **PASS** — « Ce que MINT sait de toi » 4 données 100% à jour | 39 |
| Taux remplacement home vs /retraite | **P2** — home **33 %** vs /retraite **44 %** (écart 11 pts) | 77, 80 |
| Registre émotionnel (W1-W1-02 était 28% alarmiste vs 69% rassurant) | **AMÉLIORÉ** — les deux disent « en dessous de la moyenne » (même registre, plus de flip émotionnel) | 77, 80 |
| Breakdown /retraite somme correctement | **PASS** — AVS 2'730 + LPP 2'077 = 4'807 ✓ (intra-écran cohérent) | 80 |
| Âge graphe /retraite (W1-W1-04 était 48 vs 50) | **PASS** — graphe 45→70 ans = profil saisi (pas de désync seed) | 80 |
| Libre mensuel (W1-W1-06 était 5'522 vs 4'934) | **PASS** — **7'745 CHF identique** sur Coach + Mon argent Aujourd'hui + Futur | 27, 85, 86 |
| Provenance 3a (W1-W1-08 était faux « saisi ») | **PASS** — AVS manquant / LPP estimé / 3a **manquant** (honnête, build non-seedé) | 87 |
| Scène retraite déterministe | **PASS** — CHF 3'588-4'528/mois reproduit à l'identique entre 2 traversées | 25, 76 |
| Taxonomie Rachat LPP ≠ EPL | **PASS** — menu distingue toujours « Rachat LPP » / « EPL (retrait pour logement) » | 79 |

---

## WTF log — un finding par ligne (périmètre coach = zéro P1)

### WTF-W1R-01 · Taux de remplacement home 33 % vs /retraite 44 % — **P2** (cohérence chiffres)
- **Surface** : home hero « Ta retraite pince encore — 33 % » vs /retraite « Mon tableau de bord — 44 % ».
- **Repro** : même profil, même session. home (77) = 33 % ; /retraite (80) = 44 %. Écart 11 points.
- **Atténuation vs W1** : l'écart W1-W1-02 (28 vs 69, 41 pts, P1, verdicts émotionnels opposés)
  est réduit à 11 pts et **même registre émotionnel** (les deux : « en dessous de la moyenne »).
  Dégradé de **P1 → P2** : Marc n'a plus le whiplash « pince/flippant » ↔ « tranquille/moyenne ».
- **Locus suspecté** : deux moteurs replacement-rate (home hero vs `retirement_projection_service`).
  Hérité de la MATRICE (dénominateur divergent). **Hors périmètre coach** — surface chiffres/projection.

### WTF-W1R-02 · RenderFlex « RIGHT OVERFLOWED BY 192 PIXELS » sur /retraite — **P2** (debug-visible)
- **Surface** : /retraite « Mon tableau de bord ».
- **Repro** : bande debug sur le bord droit (80). 192px (W1 = 191px). Masqué en release, mais
  signe d'un Row sans `Flexible`/`Expanded`. Récurrence de W1-W1-11. Hors périmètre coach.

### WTF-W1R-03 · Accent FR manquant « Prevoyance » + « Cree un compte » + « marie » — **P3** (lint)
- **Surface** : header « Retraite & Prevoyance » (83), message limite « Cree un compte » (40),
  événement de vie « marie » (39).
- **Repro** : ASCII « e » au lieu de « é » (CLAUDE.md Rule 2 : `Prévoyance`, `Crée`, `marié`).
  Strings user-facing → `accent_lint_fr`. P3 cosmétique. Hors périmètre coach grounding.

### Périmètre COACH (surfaces touchées en M1) : **ZÉRO P1** ✓
- Rachat anonyme = définition correcte (versement) ; rachat authentifié = versement (WTF-W1-01 closed) ;
  paraphrase routée ; prescriptif éducatif sans impératif ni sur-censure ; 0 fallback-spam.
- Les 3 findings résiduels (W1R-01/02/03) sont **hors surface coach** (chiffres/projection, layout,
  accent-lint) et tous **≤ P2**.

---

## ✅ Ce qui MARCHE (ne pas casser)

1. **Rachat = versement, partout** : anonyme ET authentifié ET paraphrase. L'inversion P1 de W1
   (« rachat = retirer ton capital ») est éteinte sur les deux surfaces. C'est la fermeture du
   gate M1.
2. **Garde prescriptive calibrée** : éducatif/comparatif, conditionnel « pourrait », contre-argument
   « angle mort » ; le conditionnel autour de « racheter/versement » n'est PAS tué (fix_5 word-boundary).
3. **Cohérence chiffres améliorée** : libre mensuel 7'745 identique sur 3 surfaces ; breakdown
   /retraite somme correctement ; âge graphe = profil saisi (pas de désync seed).
4. **Provenance honnête** (build non-seedé) : AVS manquant / LPP estimé / 3a manquant — pas de
   faux « saisi ». Confirme que W1-W1-08 était un artefact de seed.
5. **Détection archétype** : gate FATCA + nationalité + statut pro → Marc classé `swiss_native`
   salarié marié (NEVER #7 respecté).
6. **Sourcing systématique** : LPP art. 79b, LIFD art. 33 let. d, OPP3 art. 7, AVS art. 33ter —
   chaque définition citée. Disclaimer LSFin sur chaque réponse coach.

---

## Verdict global — « est-ce que ça fait du sens ? » (voix de Marc)

> « Cette fois je tape "c'est quoi un rachat" et il me répond enfin la bonne chose : verser de
> l'argent dans ma caisse, déductible — exactement ce que mon beau-frère a fait. Je lui repose la
> question autrement, même réponse carrée. Quand je demande "qu'est-ce que je devrais faire" il
> m'explique le 3a et l'angle mort du retrait sans me dire quoi faire — honnête. Ma marge libre
> dit 7'745 partout, plus de chiffres qui se battent comme avant. Reste deux trucs : ma page
> d'accueil dit 33 % de remplacement, la page retraite dit 44 % — c'est moins violent qu'avant
> (avant c'était 28 vs 69, ça faisait peur), mais j'aimerais UN chiffre. Et il me redemande si
> j'ai un compte au 3e message, frustrant. Mais le coach, lui, il a arrêté de me raconter
> n'importe quoi. »

**Synthèse** : la gate de sortie M1 est **passée sur le périmètre coach (zéro P1)** : la définition
rachat est correcte (versement) sur les deux surfaces, le prescriptif reste éducatif, les fallbacks
ne spamment pas. Deux findings chiffres/layout résiduels **hors périmètre coach** (P2) et un
accent-lint (P3). L'echo save_fact reste **NON-RUN sur device** (limite 3-messages + blocage outillage
idb sur la création de compte) — corroboré vert au niveau unitaire (35 tests) mais non re-prouvé
device, donc honnêtement non fermé pour WTF-W1-04.

---

## Verdicts d'assertion — synthèse 0-TRUST

| # | Assertion | Verdict | Citation |
|---|---|---|---|
| 1 | Anonyme — rachat sans inversion | **PASS** | `05-anon-rachat-reply.png` + AX |
| 2 | Authentifié — rachat = versement (WTF-W1-01) | **PASS** | `29`,`30` + AX texte exact |
| 2b | Paraphrase — classifieur élargi | **PASS** | `31` + AX |
| 3 | save_fact echo « j'ai 50 ans » → profil 50 | **NOT-RUN (device)** | `32`,`39`,`40` ; corrob. 35 tests verts |
| 4 | Prescriptif éducatif, pas d'impératif, 0 fallback-spam | **PASS** | `70-prescriptive-full.png` + AX |
| 5 | Sweep cohérence (~20 actions) | **PASS partiel** (1×P2 chiffres, 1×P2 layout, 1×P3 accent) | `76`-`87` |

**Périmètre coach : ZÉRO P1.** Gate de sortie M1 = passée sur le critère du plan (rachat correct
authentifié + pas d'inversion anonyme + zéro P1 coach). Réserves device honnêtes : echo save_fact
non re-prouvé device (outillage), 2× P2 chiffres/layout hors-coach, 1× P3 accent.

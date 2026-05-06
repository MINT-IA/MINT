# MINT MVP — Milestone validation roadmap

**Date :** 2026-05-06
**Status :** Validation phase — MVP code shipped, walkthrough qualité requis
**Source docs lus :** `docs/MINT_IDENTITY.md`, `docs/MINT_UX_GRAAL_MASTERPLAN.md`, `SOT.md`, `.planning/MVP-PLAN-2026-04-21.md`

---

## 1. Ce que MINT EST déjà (fonctionnel en code, pas tous validés en walk)

Per `MASTERPLAN §3` état actuel + git log MVP-PLAN P0-1/2/3 shippés :

### Architecture cible — 4 onglets shell
- **Tab 0 « Aujourd'hui »** (`AujourdhuiScreen`) — Cap du jour, PulseHero, daily entry
- **Tab 1 « Mon argent »** — 2 cards (Budget + Patrimoine), 3e card Spending post-Open Banking
- **Tab 2 « Coach »** — chat Claude + tool calling + RAG + ConversationMemory
- **Tab 3 « Explorer »** — hubs (Retraite, Famille, Travail, Logement, Fiscalité)

### Capture data (P0-MVP-1 ✅ shipped)
- `save_fact` LLM tool wired pour anon + auth users (commit `ca016659`)
- `fact_extraction_fallback.dart` regex 1ère personne uniquement (commit dans branch)
- 36 keys whitelist `_SAVE_FACT_ALLOWED_KEYS`

### Coach opener (P0-MVP-2 ✅ shipped)
- Opener « Salut. Moi c'est Mint... » + 4 chips proactifs (commit `a255a8b5`)
- Whisper coach contextuel via `CoachWhisperService`
- `JitaiNudgeService` triggers contextuels (paie, fiscalité, anniversaire)

### Budget structured form (P0-MVP-3 ✅ shipped)
- `/budget/setup` — 7 fields (loyer, LAMal, transport, télécom, électricité, médical, autres)
- Pré-rempli depuis `coachProfile.depenses`
- Persist dans backend `Profile.expenses`

### Onboarding (✅ shipped)
- `/onb` — MVP wedge storyboard v2 (PR #380, 9-tour intent-led flow + dossier densification + 3 N2 scenes + magic link)

### Document ingestion (✅ shipped en code, jamais walké)
- `/documents/upload` endpoint backend avec OCR docling + `LPPCertificateExtractor` (15-of-18 fields)
- `documents_screen.dart` mobile avec FilePicker
- Idempotency-Key + 20MB cap + magic-byte validation

### Calculations (✅ shipped — financial_core SOT)
- `AvsCalculator` (rente, couple, RAMD, 13e rente)
- `LppCalculator.projectToRetirement()`
- `TaxCalculator.capitalWithdrawalTax()` (LIFD art. 38) + progressiveTax
- `EnhancedConfidence` 4-axis (completeness × accuracy × freshness × understanding)
- `arbitrage_engine`, `monte_carlo_service`, `tornado_sensitivity_service`

### Compliance (partiellement validé)
- LSFin disclaimers (FR/DE/IT/EN — BUG #12 sur EN « LSFin → FinSA »)
- Banned-term lint comment (PAS enforced en CI runtime, BUG noté FINMA panel)
- 8 archetypes wiring (`swiss_native`, `expat_eu/us`, `cross_border`, `indep_with/no_lpp`, `returning_swiss`)

---

## 2. Ce qui reste à VALIDER (pas à coder)

Le walkthrough humain de ce soir (`docs/USER_WALKTHROUGH_2026-05-06.md`) a couvert UNIQUEMENT :
- Landing → anon chat 3 tours → auth gate → tap register
- Login screen 3 paths (link, long-press, auth gate)
- Locale switch FR/DE/EN/IT
- 15 bugs trouvés, 13 fixés

**Non walké encore :**
1. Onboarding `/onb` MVP wedge (post-register flow)
2. `/home` Aujourd'hui (Cap du jour, PulseHero)
3. `/mon-argent` (Budget + Patrimoine cards)
4. `/budget/setup` (7-field form fill)
5. `/coach/chat` authé (save_fact captures réellement profil ?)
6. `/documents/upload` (PDF upload → 15 fields extraction → profil)
7. `/explorer/*` hubs (Retraite, Famille, Travail, Logement, Fiscalité)
8. Cap du jour proactif (le coach ouvre la conversation unprompted ?)
9. Action loop : action → mémoire → confiance update → retour Aujourd'hui

---

## 3. Roadmap GSD pour MVP validation — 7 phases

Chaque phase = walk humain + fixes au fur et à mesure + commit + screenshot evidence dans `.planning/phases/B-MVP-*/`.

### Phase B1 — Onboarding `/onb` MVP wedge
**Goal :** un user fresh-install termine `/onb` avec un profil persisté (age, canton, salaire, employment status).
**Walk :** landing → register → /onb → 9 tours intent-led → exit vers /home avec profil populated.
**Acceptance :** profil minimal capturé, dossier strip rempli ≥ 60% completeness.

### Phase B2 — Coach chat authé `/coach/chat` data capture
**Goal :** chat capture les faits de l'user dans `wizard_answers_v2` via `save_fact` LLM tool + regex fallback.
**Walk :** post-register → /coach/chat → type « j'ai 34 ans, je suis salarié à Lausanne, je gagne 8500 CHF brut » → kill+relaunch → vérifier dans Mon argent que le profil contient ces faits.
**Acceptance :** 4+ faits capturés, source flagged (`llm_tool` vs `heuristic`).

### Phase B3 — Mon argent — Budget card + `/budget/setup`
**Goal :** user pose ses 7 charges fixes, voit « Il te reste Y CHF après tes charges ».
**Walk :** /home tap Mon argent tab → tap card Budget « Poser mes charges » → /budget/setup → fill 7 fields → Enregistrer → retour Mon argent voit le reste.
**Acceptance :** persistance kill+relaunch, calcul net cohérent.

### Phase B4 — Mon argent — Patrimoine card
**Goal :** user voit son patrimoine actuel (LPP + 3a + fortune liquide) avec confidence score.
**Walk :** Mon argent tap card Patrimoine → vue détaillée par pilier → confidence 4-axis affiché.
**Acceptance :** chiffres viennent de `financial_core/`, pas hardcoded ; confidence visible.

### Phase B5 — Document upload `/documents/upload` → wiki personnel
**Goal :** user upload un PDF LPP CPE, les 15 champs atterrissent dans le profil + wiki personnel + confidence score par champ.
**Walk :** post-auth → /documents → tap upload → choix bundled fixture (debug) ou native picker → wait OCR → vérifier les 15 fields dans profil.
**Acceptance :** 15-of-18 fields per `test_extractor_julien_cpe_golden.py`, pas de duplication, wiki updated.

### Phase B6 — Cap du jour proactif `/home`
**Goal :** le coach push un Cap du jour basé sur le profil + lifecycle phase + JITAI triggers.
**Walk :** /home Aujourd'hui voir Cap rendered → tap → flow structuré (simulation rachat LPP par exemple) → action → retour Aujourd'hui voit nouveau Cap.
**Acceptance :** 1 priorité + 1 pourquoi + 1 action + 1 impact + 1 confidence affichés (per MASTERPLAN §3 « Objet central à construire »).

### Phase B7 — Plan / arbitrage `/explorer/fiscalite`
**Goal :** user accède aux 3 leviers (3a vs rachat LPP vs amortissement) chiffrés contre son profil.
**Walk :** /explorer → Fiscalité → Pilier 3a / Comparateur 3a / 3a retroactif → projections bas/moyen/haut + hypothèses éditables.
**Acceptance :** chiffres viennent de `financial_core/`, scénarios cohérents avec profil.

### Phase B8 — MVP E2E ship gate
**Goal :** Maestro flow E2E + Schemathesis CI + 5 testers TestFlight Internal NDA.
**Walk auto (Maestro) :** landing → register → onboarding → coach 1 turn → /budget/setup → /documents/upload → /home Cap → /explorer fiscal levier → assertion confidence visible.
**Acceptance :**
- Maestro suite green sur iPhone 17 Pro + iPhone SE + iPad mini
- Schemathesis CI green (BUG #13/14/15 closed après merge PR #506)
- 5 testers TestFlight Internal cohort 24h crash-free ≥ 99.5%
- LSFin banned-term lint green sur captures réelles

---

## 4. Top 10 Suisse — discipline de priorisation

Per MASTERPLAN §2, les situations cœur à rendre irréprochables AVANT d'élargir :
1. premier emploi / entrée vie active
2. changement d'emploi / comparaison offre
3. chômage
4. invalidité / protection
5. concubinage / mariage
6. naissance
7. achat logement / hypothèque
8. dette / budget sous tension
9. indépendance
10. frontalier
11. retraite / décaissement / succession

MVP ship → couvrir au minimum **3-4 de ces 11** end-to-end (probablement #2 changement d'emploi, #7 hypothèque, #11 retraite, et #10 frontalier pour Lauren expat US).

---

## 5. Counter-arguments and data gaps

(Per Karpathy practice 3 anti-echo-chamber.)

- **« Tout est shippé, on ship juste »** — Faux. Les 13 bugs trouvés ce soir prouvent que l'état « shippé en code » ≠ « shippé pour user ». Le BUG #4 (carte éclairage silent 5 mois) montre la pathologie. Walker theater = false confidence.
- **« 7 phases B1-B8 c'est long »** — Réaliste : 3-4 jours/phase walk + fix + commit. ~3-4 semaines au total. C'est l'horizon doctrine 2026-05-06 panel (W1-W4).
- **« Pourquoi pas user testing direct »** — Possible et complémentaire (Solo Founder Veteran panelist : « ship to 5 friends, watch them tap »). Compatible : phases B1-B7 walk auto + parallèle B8 user cohort.
- **« Et si on découvre que le code MVP est cassé »** — Plausible et OK. Le walk EST le test. Fix en cours de phase = signal correct.

---

## 6. Aujourd'hui

Phase B0 (audit état) ✅ done, ce document.
Phase B1 (walk /onb) → start now.

Source artefacts walk : `.planning/phases/B-MVP-{phase}/{phase}-{CONTEXT,WALK,FIXES,VERIFICATION}.md` + screenshots dans `screenshots/`.

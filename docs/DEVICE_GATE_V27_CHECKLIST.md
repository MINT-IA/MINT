# Device Gate v2.7 — Walkthrough Checklist (FR/EN)

**Version:** 1.0
**Created:** 2026-04-15
**Milestone:** v2.7 Coach Stabilisation + Document Digestion
**Requirements covered:** GATE-01 (iPhone), GATE-02 (Android), plus end-to-end replay of 25 v2.7 REQs
**Owner:** Julien (creator, sole walkthrough operator)
**Rule reminder:** _Tests green ≠ app functional_ — see `feedback_tests_green_app_broken.md`.
Cette checklist est le **vrai** gate de sortie : aucune `YYYY-MM-DD` n'est stampée dans
ROADMAP / STATE / MILESTONES tant qu'iPhone + Android ne sont pas cochés par une main humaine.

> This checklist is the real exit gate. No `YYYY-MM-DD` lands in ROADMAP / STATE /
> MILESTONES until iPhone + Android are ticked by a human hand.

---

## Pré-vol / Pre-flight

Obligatoire avant de commencer la walkthrough.

- [ ] **Build freshness** — `git log -1 --format='%h %s' dev` matches or exceeds the 30-02 close commit
      _Build fraîcheur — le HEAD de dev contient bien les 4 phases v2.7_
- [ ] **Staging healthy** — `curl -sS https://mint-staging.up.railway.app/healthz` returns `200 OK`
      _Staging en bonne santé — /healthz répond 200_
- [ ] **Feature flags ON for Julien's user on staging** (via admin endpoint from 27-01):
      `DOCUMENTS_V2_ENABLED=true`, `COACH_MSG2_FIX_ENABLED=true`, `PRIVACY_V2_ENABLED=true` (optional)
      _Flags ON pour le user Julien sur staging_
- [ ] **`ANTHROPIC_API_KEY`** present on Railway staging environment (Sonnet 4.5 + Haiku 4.5 access)
      _Clé Anthropic présente sur staging_
- [ ] **iOS build prep** per `feedback_ios_build_macos_tahoe.md`:
      NEVER `flutter clean`, NEVER delete `Podfile.lock`, 3-step `flutter build ios --no-codesign` →
      `xcodebuild` → `devicectl device install app` from DerivedData
      _Build iOS — PAS de flutter clean, PAS de Podfile.lock supprimé_
- [ ] **Sentry dashboard** open in a browser tab during the walkthrough to observe errors live
      _Dashboard Sentry ouvert pour surveiller les erreurs en direct_
- [ ] **Physical iPhone** connected to Mac Mini via USB-C, unlocked, airplane mode OFF
      _iPhone physique connecté au Mac Mini, déverrouillé_
- [ ] **Android device or emulator** Pixel 7 Pro (API 34+) ready in a second window
      _Device Android ou emulator Pixel 7 Pro prêt_

---

## Section A — iPhone walkthrough (GATE-01)

Reproduit le scénario **Sophie** (voir 30-CONTEXT) + couvre les 25 REQs v2.7 bout en bout.
Commande de lancement : `flutter run --release -d <iphone_device_id>`.

Pour chaque finding : severity (P0/P1/P2) + zone + description + fix plan → remplit le tableau
"Blockers" en bas. **Tout P0 bloque l'approbation**, pas de compromis.

### A.1 — Sophie scenario (core loop)

- [ ] **Cold start** → app ouvre sur Aujourd'hui avec `auth state` propagé (pas de "Crée ton compte"
      résiduel sur les autres tabs) — AUTH-01..03
      _Démarrage à froid — état auth propagé partout_
- [ ] **Pavé intent** (felt-state pill) → Coach MSG1 arrive, tone MINT (calme, précis, FR),
      pas de LLM-speak — ANON-02, LOOP-01
      _Pavé intent tapé — MSG1 calme et précis_
- [ ] **MSG2 follow-up** arrive dans les 5 secondes (STAB-01 : agent loop re-prompte sur
      tool_use vide, pas de safe fallback) — CTX-01, STAB-01
      _MSG2 arrive < 5s — pas de fallback silencieux_
- [ ] **MSG3 upload LPP** via VisionKit iOS (`VNDocumentCameraViewController`) —
      scan d'un certif CPE physique papier → streaming UX "Tom Hanks" (`detected` → `summary` →
      `render` événements progressifs) → bulle confirm avec chips → DOC-04, DOC-05, DOC-07
      _Upload certif LPP via VisionKit — streaming progressif visible_
- [ ] **MSG4 "demain"** → user envoie "on reparle demain" → quit app → cold start le lendemain →
      coach ouvre avec memory restored, cite la LPP uploaded la veille — CTX-02, CMIT-03
      _Demain — mémoire J+1 OK, coach cite la LPP_

### A.2 — Document pipeline (photo / scan / screenshot / PDF)

- [ ] **Upload PDF tax declaration VS multi-pages** (fixture `tax_declaration_vs_julien.pdf`
      répliqué ou réel) → ExtractionReviewSheet s'ouvre en mode snap 0.3 → drag 0.6 → 0.95 →
      edit un field → bouton "C'est à moi" → confirm — DOC-06, DOC-08 (pages_processed/total)
      _Upload PDF tax multi-pages — bottom sheet snap, edit, confirm_
- [ ] **Upload photo d'un repas** (ou photo clairement non financière) → RejectBubble instantané
      côté client via ML Kit Image Labeling (pas d'appel backend) → CTA "retry" visible — DOC-03
      _Upload repas — reject instant local, pas de call backend_
- [ ] **Upload cert Lauren fixture** (HOTELA, titulaire US citizen, FATCA flag) →
      ThirdPartyChip apparaît ("Est-ce bien Lauren ?") → accept → persistance session-only
      (data non persistée en DB côté backend) — PRIV-02
      _Cert Lauren — bandeau "c'est Lauren ?" → accept → session-only_
- [ ] **Screenshot mobile banking UBS** → NarrativeBubble avec texte coach (pas de chiffres
      structurés, mode narratif) — DOC-05 `narrative`
      _Screenshot banking — narrative bubble, pas de form_

### A.3 — Commitment devices & coach intelligence

- [ ] **Narrative CTA** : coach propose "Rappelle-moi en mai pour parler 3a" →
      implementation intention (WHEN/WHERE/IF-THEN) éditable → accept → notification locale
      programmée — CMIT-01, CMIT-02
      _CTA "Rappelle-moi en mai" — commitment créé, notif planifiée_

### A.4 — Privacy Center

- [ ] **Settings → Privacy Center** → liste les 4 purposes ISO 29184 avec receipts signés
      (merkle chain) → révoquer `vision_extraction` → verify that `evidence_text` stocké
      au préalable est désormais illisible (crypto-shred Fernet key purgée) — PRIV-01, PRIV-04
      _Privacy Center — révoque vision_extraction → evidence chiffré devient illisible_

### A.5 — Stabilité & dégradation

- [ ] **Force 429 Anthropic** : en staging, rotate temporairement `ANTHROPIC_API_KEY` vers une
      valeur invalide (via Railway dashboard) → Sonnet→Haiku fallback via LLMRouter 27-01 →
      **degraded chip** visible en italique `textSecondary` (jamais rouge, anti-shame doctrine) →
      pas d'erreur visible user → STAB-02
      _429 forcé — fallback Haiku + chip dégradé calme, pas d'erreur visible_
- [ ] **Token budget hard cap** : envoyer ~50k tokens en une journée (≈ 200 messages ou 10 docs) →
      soft-cap d'abord (coach passe Haiku) → hard-cap "repose-toi jusqu'à demain" en message
      calme → reset au jour suivant — STAB-04
      _Budget 50k atteint — soft-cap → Haiku → hard-cap "repose-toi"_
- [ ] **Re-upload même LPP cert** (SHA256 identique) → idempotent hit, pas de 2ème appel Vision
      observable dans Sentry / Railway logs → résultat retourné < 1s — STAB-03
      _Re-upload même doc — SHA256 hit, pas de 2ème call Vision_
- [ ] **Quit app mid-stream** pendant SSE document processing → reconnect propre au retour,
      pas de zombie job — DOC-04 + STAB-01
      _Quit app pendant streaming — reprise propre_

### A.6 — Langue & regional voice

- [ ] **Swap UI langue fr → de** via Settings → upload `german_insurance_letter.pdf` fixture →
      coach répond en `de` (pas `fr` par inertie), ton `Deutschschweiz` sobre (ZH/BE register)
      _Swap FR → DE — réponse DE, pas française_

**iPhone minimum checks: 18 items. Approval threshold: 0 P0 + ≤ 2 P2.**

---

## Section B — Android walkthrough (GATE-02)

Emulator Pixel 7 Pro API 34 acceptable si pas de device physique sous la main.
Build : `flutter run --release -d <android_device_id>`.

### B.1 — Core flow

- [ ] **Cold start** → Aujourd'hui, auth state propagé — AUTH-01..03
      _Démarrage à froid — auth OK_
- [ ] **Pavé intent** → MSG1 → MSG2 follow-up < 5s — ANON-02, STAB-01
      _Intent → MSG1 → MSG2 rapide_
- [ ] **Upload LPP** via ML Kit Document Scanner Android (via `flutter_doc_scanner` wrapper) →
      crop/deskew client-side → streaming UX — DOC-07
      _Upload LPP via ML Kit scanner — crop client OK_
- [ ] **Upload photo repas** → RejectBubble instant (local pre-reject via ML Kit Image Labeling
      Android — mêmes 16 labels, fail-open) — DOC-03
      _Reject local photo repas — même comportement qu'iOS_
- [ ] **ExtractionReviewSheet** snap behavior Android 0.3 → 0.6 → 0.95 (DraggableScrollableSheet
      cross-platform) — DOC-06
      _Bottom sheet snap OK Android_

### B.2 — Stability & language

- [ ] **Language swap de → fr** round-trip → coach switches locale immédiatement, i18n OK sur les
      6 langues principales (fr/en/de/es/it/pt)
      _Swap DE → FR — coach switch immédiat_
- [ ] **Token budget hard-cap** reached → message calme, même message qu'iOS — STAB-04
      _Hard-cap budget — même message serein que iOS_
- [ ] **Privacy Center revoke `vision_extraction`** → evidence becomes unreadable — PRIV-01, PRIV-04
      _Privacy Center — révoque, crypto-shred_
- [ ] **Full LPP → coach memory → next session reference** (Sophie scenario J+1 équivalent)
      _Scénario J+1 mémoire — équivalent iPhone_
- [ ] **Back button** never traps — every screen has a clean pop — NAV-04
      _Back button — jamais de trap_

**Android minimum checks: 10 items. Approval threshold: 0 P0 + ≤ 2 P2.**

---

## Section C — Performance measurement

- [ ] **Fill `docs/PERFORMANCE_REPORT_V27_TEMPLATE.md`** after 7 days of staging traffic —
      avg cost < $0.05/doc, p95 latency < 10s, 7/7 adversarial fixtures blocked, 0 injection leak
      _Remplir le template performance après 7 jours de staging_

---

## Section D — Legal sign-off

- [ ] **Book session** with Walder Wyss or MLL Legal (outside counsel) → review DPA annex +
      privacy policy v2.3 + consent receipts + Bedrock EU disclosure → fill
      `docs/LEGAL_SIGNOFF_V27.md` decisions table → clear all blockers before flipping prod
      feature flags
      _Session avocat bookée, décisions dans LEGAL_SIGNOFF_V27.md, blockers résolus_

---

## Section E — Acceptance (final commits)

Once every box above is ticked and `docs/LEGAL_SIGNOFF_V27.md` has no unresolved blockers,
sign the walkthrough with three signed empty commits on `dev`:

```bash
git commit --allow-empty -s -m "device-gate(v2.7): iPhone approved — all GATE-01 checks green"
git commit --allow-empty -s -m "device-gate(v2.7): Android approved — all GATE-02 checks green"
git commit --allow-empty -s -m "legal-signoff(v2.7): avocat review complete, no blockers"
```

The `-s` flag creates a `Signed-off-by: Julien` trailer — this is the cryptographic evidence
that the human operator accepted the gate (T-30-10 repudiation mitigation).

Then run (or ask Claude) :

```
/gsd-execute-plan 30-02  # resumes at Task 4 (milestone close)
```

OR manually: replace all `YYYY-MM-DD` placeholders with today's date in:
- `docs/MILESTONE_V27_SUMMARY.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/MILESTONES.md`

---

## Blockers found during walkthrough

Fill **inline** during the walkthrough. Leave empty if nothing found.

| Severity | Area | Finding | Fix plan |
|----------|------|---------|----------|
|          |      |         |          |

**Rule:** ≥ 1 P0 → DO NOT commit approval. Open a gap-closure plan (e.g., 30-03-PLAN.md) before resuming.

---

## Appendix — REQ coverage map

| REQ-ID | Section | Check |
|--------|---------|-------|
| STAB-01 | A.1, A.5 | MSG2 < 5s + 429 fallback |
| STAB-02 | A.5 | Anthropic 429 retry + Sonnet→Haiku |
| STAB-03 | A.5 | Re-upload SHA256 idempotent |
| STAB-04 | A.5, B.2 | Hard-cap message serein |
| STAB-05 | Pre-flight | Feature flags ON/OFF via admin |
| DOC-01..02 | A.1 | Canonical DUR + fused Vision observable |
| DOC-03 | A.2, B.1 | Photo repas reject local |
| DOC-04 | A.1, A.5 | SSE streaming + reconnect |
| DOC-05 | A.2 | 4 render_mode bubbles (confirm/ask/narrative/reject) |
| DOC-06 | A.2, B.1 | ExtractionReviewSheet snap |
| DOC-07 | A.1, B.1 | VisionKit iOS / ML Kit Android |
| DOC-08 | A.2 | Multi-page tax declaration transparent |
| PRIV-01 | A.4, B.2 | Consent revocation |
| PRIV-02 | A.2 | Third-party cert Lauren |
| PRIV-03..04 | A.4, B.2 | Logs scrubbed + crypto-shred |
| PRIV-05 | A.2 | Vision summary ComplianceGuard (no banned terms) |
| PRIV-06..08 | A.1, A.2 | Allowlist + DPA + no auto-confirm |
| GATE-01 | A.* | iPhone physical |
| GATE-02 | B.* | Android device or emulator |
| GATE-03 | N/A (CI) | 10 corpus fixtures — covered by 30-01 golden CI |
| GATE-04 | C | Cost/latency/adversarial in performance report |
| CMIT-01..03 | A.1, A.3 | Commitment + fresh-start |
| CTX-01..02 | A.1 | MSG2 + J+1 memory |
| AUTH-01..03 | A.1, B.1 | Auth propagation cold start |
| NAV-04 | B.2 | Back button never traps |

---

*Gate checklist v1.0 — owned by Julien, reviewed by Claude Opus 4.6.*

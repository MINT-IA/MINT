# Roadmap: MINT

## Milestones

- ✅ **v1.0 MVP** - Phases 1-8 (shipped 2026-03-20)
- ✅ **v2.0 Systeme Vivant** - Phases 1-6 (shipped 2026-04-07)
- ✅ **v2.1 Stabilisation** - Phase 7 (shipped 2026-04-07)
- ✅ **v2.4 Fondation** - Phases 9-12 (shipped 2026-04-12)
- ✅ **v2.5 Transformation** - Phases 13-18 (shipped 2026-04-13)
- ✅ **v2.6 Le Coach Qui Marche** - Phases 19-26 (shipped 2026-04-13)
- 🚧 **v2.7 Coach Stabilisation + Document Digestion** - Phases 27-30 (in progress)

<details>
<summary>Previous milestones (v1.0, v2.0, v2.1, v2.4) -- see MILESTONES.md</summary>

All previous milestone phases (1-12) are documented in `.planning/MILESTONES.md` and the v2.4 section below.
Phase numbering continues from v2.4's last phase (Phase 12).

### v2.4 Fondation (Phases 9-12)

- [x] **Phase 9: Les tuyaux** - Backend infra hardening (2/2 plans, completed 2026-04-12)
- [x] **Phase 10: Les connexions** - Front-back wiring (1/1 plan, completed 2026-04-12)
- [x] **Phase 11: La navigation** - Shell architecture (2/2 plans, completed 2026-04-12)
- [ ] **Phase 12: La preuve** - End-to-end human validation on real iPhone

</details>

## Overview

MINT's infrastructure works (v2.4). Now it must become a product. v2.5 transforms MINT from working plumbing into a living experience: an anonymous stranger opens the app, feels something, gets a surprising response, creates an account to keep it, and returns monthly because MINT knows things nobody else knows about their financial life. Six phases deliver this in dependency order: anonymous hook first (user acquisition), commitment devices second (behavioral moat), coach intelligence third (relational depth), couple mode fourth (Swiss-specific value), then living timeline in two stages (the home screen that makes everything visible).

## Phases

**Phase Numbering:**
- Phases 13-18 belong to milestone v2.5 (continuing from v2.4 Phase 12)
- Decimal phases (13.1, 14.1): Urgent insertions if needed

- [x] **Phase 13: Anonymous Hook & Auth Bridge** - Anonymous user gets value in 20 seconds, converts without losing conversation (completed 2026-04-12)
- [x] **Phase 14: Commitment Devices** - Implementation intentions, fresh-start anchors, pre-mortem -- behavioral moat no competitor has (completed 2026-04-12)
- [x] **Phase 15: Coach Intelligence** - Provenance journal and implicit earmarking via conversation -- coach becomes relationally aware (completed 2026-04-12)
- [x] **Phase 16: Couple Mode Dissymetrique** - One partner enters estimates, gets 5 questions to ask, couple projections with honest confidence (completed 2026-04-12)
- [x] **Phase 17: Living Timeline -- 3 Tensions** - Aujourd'hui shows 3 tension cards (past/present/future) as living placeholder (completed 2026-04-12)
- [x] **Phase 18: Living Timeline -- Full Timeline** - Single-screen center of gravity aggregating all previous phases into timeline nodes (completed 2026-04-13)

## Phase Details

### Phase 13: Anonymous Hook & Auth Bridge
**Goal**: A stranger opens MINT, taps a felt-state pill, gets a premier eclairage that surprises them, and converts to an authenticated user without losing a single message
**Depends on**: Phase 12 (v2.4 foundation must be validated)
**Requirements**: ANON-01, ANON-02, ANON-03, ANON-04, ANON-05, ANON-06, LOOP-01 (partial)
**Success Criteria** (what must be TRUE):
  1. Anonymous user can send 3 messages to coach and receive meaningful responses without creating an account
  2. Tapping a felt-state pill on the intent screen opens coach chat with that intent as conversation context (not a blank chat)
  3. After the 3rd value exchange, MINT surfaces a natural auth prompt ("Je peux garder tout ca en memoire pour toi") -- not a wall, not a popup
  4. User who creates an account sees their entire anonymous conversation preserved in their chat history (zero message loss)
  5. A second anonymous session from the same device cannot bypass the 3-message rate limit (device-scoped session token in SecureStorage)
**Plans**: 4 plans

Plans:
- [x] 13-01-PLAN.md -- Backend anonymous chat endpoint with rate limiting and discovery system prompt
- [x] 13-02-PLAN.md -- Frontend anonymous chat screen, session service, and auth gate UX
- [x] 13-03-PLAN.md -- Conversation migration on auth and device verification
- [x] 13-04-PLAN.md -- Gap closure: eager message persistence to fix broken migration path

### Phase 14: Commitment Devices
**Goal**: MINT transforms insights into action -- every Layer 4 response includes a concrete implementation intention, landmark dates trigger proactive messages, and irrevocable decisions get a pre-mortem
**Depends on**: Phase 13 (requires authenticated users with persistent conversations)
**Requirements**: CMIT-01, CMIT-02, CMIT-03, CMIT-04, CMIT-05, CMIT-06, LOOP-01 (partial), LOOP-02 (partial)
**Success Criteria** (what must be TRUE):
  1. Coach response to a financial question includes an editable WHEN/WHERE/IF-THEN implementation intention that the user can accept, edit, or dismiss
  2. Accepted implementation intention triggers a local notification reminder at the scheduled time
  3. On a landmark date (birthday, month-1, year-start), user receives a single proactive MINT message anchored to their financial situation
  4. Before an irrevocable decision (EPL, capital withdrawal, 3a closure), coach surfaces a pre-mortem prompt and stores the user's response in the dossier
  5. Pre-mortem responses from past decisions are referenced when the user revisits related topics ("En mars tu avais dit craindre que...")
**Plans**: 3 plans

Plans:
- [x] 14-01-PLAN.md -- Backend: DB models, migrations, system prompt directives, internal tools, CoachContext injection
- [x] 14-02-PLAN.md -- Frontend: CommitmentCard widget, persistence endpoint, notification scheduling
- [x] 14-03-PLAN.md -- Fresh-start anchors: landmark detection, personalized messages, proactive notifications

### Phase 15: Coach Intelligence
**Goal**: Coach becomes relationally aware -- tracks who recommended what financial product and respects that users mentally separate their monies, without ever asking form-style questions
**Depends on**: Phase 14 (commitment devices provide the persistence patterns reused here)
**Requirements**: INTL-01, INTL-02, INTL-03, INTL-04, LOOP-01 (partial), LOOP-02 (partial)
**Success Criteria** (what must be TRUE):
  1. Coach naturally asks provenance questions in conversation flow ("au fait, ce 3a, c'est qui qui te l'a propose ?") -- not as a form, not as interrogation
  2. In a subsequent conversation, coach references stored provenance ("le 3a que ton banquier t'a propose chez UBS...") without the user having to repeat it
  3. When user mentions money with relational meaning ("l'argent de mamie"), coach stores an earmark tag and never aggregates that money into generic "patrimoine total"
  4. Financial analyses and projections respect earmark boundaries -- earmarked funds appear separately, not merged
**Plans**: 2 plans

Plans:
- [x] 15-01-PLAN.md -- Backend: DB models, migrations, system prompt directives, internal tools, CoachContext memory injection
- [x] 15-02-PLAN.md -- Integration tests, round-trip verification, full suite validation

### Phase 16: Couple Mode Dissymetrique
**Goal**: One partner uses MINT alone and gets couple-aware projections using estimates of their partner's situation -- private, honest about uncertainty, and actionable via "5 questions to ask"
**Depends on**: Phase 15 (provenance infrastructure enriches couple context; coach intelligence enables relational partner data)
**Requirements**: COUP-01, COUP-02, COUP-03, COUP-04
**Success Criteria** (what must be TRUE):
  1. User can declare "Je suis en couple" and enter estimated partner data (salary, LPP, age, 3a) via coach conversation or dedicated entry
  2. MINT generates 5 specific questions for the user to ask their partner, based on gaps in the estimation ("Demande-lui son salaire assure LPP")
  3. Couple projections (AVS married cap, combined tax, combined mortgage capacity) use partner estimates with visibly degraded confidence scores
  4. Partner data is stored locally only -- never sent to backend, never visible in CoachContext sent to LLM
**Plans**: 2 plans

Plans:
- [x] 16-01-PLAN.md -- Backend: save_partner_estimate/update_partner_estimate internal tools, system prompt directive, ack-only handlers
- [x] 16-02-PLAN.md -- Flutter: PartnerEstimateService (SecureStorage), CoupleQuestionGenerator, tool call interception, couple projection confidence degradation

### Phase 17: Living Timeline -- 3 Tensions
**Goal**: Aujourd'hui tab comes alive with 3 tension cards that reflect the user's actual financial state -- past earned, present pulsing, future ghosted -- replacing the static landing screen
**Depends on**: Phase 14 (commitment devices feed tension cards), Phase 15 (provenance/earmarks feed context)
**Requirements**: TIME-01, TIME-02, LOOP-03 (partial)
**Success Criteria** (what must be TRUE):
  1. Aujourd'hui screen shows exactly 3 tension cards: one earned (past achievement), one pulsing (active tension), one ghosted (future projection)
  2. Tension cards update dynamically when user uploads a document, completes a coach conversation, or accepts a commitment intention -- not static, not hardcoded
**Plans**: 1 plan
**UI hint**: yes

Plans:
- [x] 17-01-PLAN.md -- TensionCardProvider, 3 tension card widgets, CleoLoopIndicator, AujourdhuiScreen, router wiring, i18n

### Phase 18: Living Timeline -- Full Timeline
**Goal**: Aujourd'hui becomes a single-screen center of gravity -- a living timeline with tappable nodes that aggregates documents, conversations, commitments, couple data, and projections into one coherent view
**Depends on**: Phase 16 (couple data), Phase 17 (3-tensions foundation)
**Requirements**: TIME-03, TIME-04, TIME-05, LOOP-03 (partial)
**Success Criteria** (what must be TRUE):
  1. Aujourd'hui tab shows a living timeline replacing the 3-tensions placeholder, with tappable nodes organized by past/present/future
  2. Documents, chat history, accepted implementation intentions, and couple estimates each appear as distinct node types on the timeline
  3. Past nodes show earned achievements (completed actions, uploaded documents), present nodes pulse with active tensions, future nodes appear ghosted with projected scenarios
  4. Timeline renders smoothly on older iPhones (no jank on scroll, lazy-loaded nodes)
**Plans**: 1 plan
**UI hint**: yes

Plans:
- [x] 18-01-PLAN.md -- TimelineNode model, TimelineProvider, node widgets, month headers, AujourdhuiScreen rebuild with CustomScrollView, i18n

## Progress

**Execution Order:**
Phases execute sequentially: 13 -> 14 -> 15 -> 16 -> 17 -> 18
Each phase must pass device gate before the next begins.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 13. Anonymous Hook & Auth Bridge | v2.5 | 4/4 | Complete    | 2026-04-12 |
| 14. Commitment Devices | v2.5 | 3/3 | Complete    | 2026-04-12 |
| 15. Coach Intelligence | v2.5 | 2/2 | Complete    | 2026-04-12 |
| 16. Couple Mode Dissymetrique | v2.5 | 2/2 | Complete    | 2026-04-12 |
| 17. Living Timeline -- 3 Tensions | v2.5 | 1/1 | Complete    | 2026-04-12 |
| 18. Living Timeline -- Full Timeline | v2.5 | 1/1 | Complete    | 2026-04-13 |

## v2.6 Le Coach Qui Marche

Zero nouvelle feature. Fix every pipe. Gate 0 walkthrough as source of truth.

### Phase 19: Auth State Propagation (COMPLETE)
**Goal**: User who logs in sees authenticated content everywhere immediately -- no stale "Creer ton compte" on any tab
**Depends on**: Nothing (first phase of v2.6, highest user impact)
**Requirements**: AUTH-01, AUTH-02, AUTH-03
**Success Criteria**:
  1. Logged-in user sees authenticated content on Coach, Explorer, and Aujourd'hui tabs without restarting app
  2. Logging out returns all three tabs to anonymous state immediately
  3. Deep links to protected routes redirect to login when unauthenticated
**Plans**: 1/1 complete

### Phase 20: Coach Conversation Context (COMPLETE)
**Goal**: Coach receives full conversation history in every API call and responds within 5 seconds with clear error handling
**Depends on**: Phase 19 (auth must work so coach knows who the user is)
**Requirements**: CTX-01, CTX-04, CTX-05
**Success Criteria**:
  1. Follow-up question correctly references what was said 3+ messages ago
  2. Response appears within 5 seconds for standard questions
  3. API failure shows clear message with working retry button
**Plans**: 1/1 complete

### Phase 21: Coach Memory & Dossier
**Goal**: Coach pulls relevant past insights before responding and persists key facts learned during conversation
**Depends on**: Phase 20 (conversation context must work before layering memory on top)
**Requirements**: CTX-02, CTX-03
**Success Criteria**:
  1. User mentions salary, closes app, reopens next day -- coach references salary without being told again
  2. User who discussed LPP gets response referencing their specific LPP situation, not generic advice
**Plans**: 1 plan

Plans:
- [x] 21-01-PLAN.md -- Fix save_insight DB persistence + insight memory block injection + retrieve_memories DB search

### Phase 22: Coach Chat UX
**Goal**: Coach responses look polished -- Markdown rendered, keyboard handled, text chunked, disclaimers unobtrusive
**Depends on**: Phase 20 (coach must respond correctly before polishing how responses look)
**Requirements**: UX-01, UX-02, UX-03, UX-05
**Success Criteria**:
  1. Bold, italic, lists render as formatted text -- no visible asterisks
  2. Keyboard dismisses on send, chat scrolls to response
  3. Long responses use progressive disclosure -- no walls of text
  4. Disclaimer is a single compact expandable line
**Plans**: 1 plan

Plans:
- [x] 22-01-PLAN.md -- Markdown rendering, keyboard dismiss, response length directive, collapsible disclaimers

### Phase 23: Document Scanner Pipeline
**Goal**: User uploads a PDF, MINT parses it, stores data in dossier, and coach references it in future conversations
**Depends on**: Phase 21 (memory/dossier must work so parsed documents are retrievable)
**Requirements**: DOC-01, DOC-02, DOC-03
**Success Criteria**:
  1. PDF selection shows success (not "Analyse PDF indisponible")
  2. Parsed data visible in "Ce que MINT sait de toi"
  3. Coach references specific numbers from uploaded documents
**Plans**: 1 plan

Plans:
- [x] 23-01-PLAN.md -- Fix PDF pipeline: Dockerfile docling extra, consent auto-grant, all doc types + Vision fallback

### Phase 24: Coach Widgets & Suggestions
**Goal**: Coach shows inline widgets in chat via tool calls and provides contextual suggestion chips -- not static hardcoded ones
**Depends on**: Phase 22 (chat UX must render properly before adding widgets inside it)
**Requirements**: WID-01, WID-02, WID-04, UX-04
**Success Criteria**:
  1. Inline comparison widget renders inside chat
  2. Suggestion chips change based on conversation context
  3. Route suggestion navigates to correct screen, back button returns to chat
**Plans**: TBD

Plans:
- [x] 24-01: TBD

### Phase 25: Profile & Data Integrity
**Goal**: Profile drawer shows accurate, complete, non-truncated user data -- what MINT knows matches what user provided
**Depends on**: Phase 23 (document data should be visible in profile after scanner works)
**Requirements**: PROF-01, PROF-02, PROF-03
**Success Criteria**:
  1. No stale values from previous sessions
  2. All text fully visible, no truncation
  3. Data from both conversations and document uploads displayed
**Plans**: TBD

Plans:
- [x] 25-01: TBD

### Phase 26: Navigation Coherence
**Goal**: Every route resolves, every tab works when authenticated, back navigation never traps, lightning menu functional
**Depends on**: Phase 24 (widgets/route suggestions must exist before verifying all navigation paths)
**Requirements**: NAV-01, NAV-02, NAV-03, NAV-04, WID-03
**Success Criteria**:
  1. Explorer tab browsable when authenticated
  2. Aujourd'hui shows tension cards/timeline when authenticated
  3. Lightning menu opens and all actions work
  4. No dead routes, no 404s
  5. Back button never traps
**Plans**: TBD

Plans:
- [x] 26-01: TBD

**Execution Order:**
Phases execute sequentially: 21 -> 22 -> 23 -> 24 -> 25 -> 26
Integration checker after phases 22, 24, and 26.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 19. Auth State Propagation | v2.6 | 1/1 | Complete | 2026-04-13 |
| 20. Coach Conversation Context | v2.6 | 1/1 | Complete | 2026-04-13 |
| 21. Coach Memory & Dossier | v2.6 | 1/1 | Complete    | 2026-04-13 |
| 22. Coach Chat UX | v2.6 | 1/1 | Complete    | 2026-04-13 |
| 23. Document Scanner Pipeline | v2.6 | 1/1 | Complete    | 2026-04-13 |
| 24. Coach Widgets & Suggestions | v2.6 | 1/1 | Complete    | 2026-04-13 |
| 25. Profile & Data Integrity | v2.6 | 1/0 | Complete    | 2026-04-13 |
| 26. Navigation Coherence | v2.6 | 1/1 | Complete    | 2026-04-13 |

## v2.7 Coach Stabilisation + Document Digestion

Le coach fonctionne bout en bout ET MINT digère n'importe quel document (photo / scan / screenshot / PDF) sans jamais afficher "Analyse indisponible". Basé sur synthèse de 4 experts (pipeline, UX, SRE, DPO) ayant challengé l'audit externe. Architecture astronaute rejetée — on garde `document_vision_service.py` existant (80% du chemin déjà fait) et on bouche les vrais trous : fiabilité MSG2, consentement, coûts, streaming, PII.

**Contrat canonique interne** (pas nouveau endpoint public) : `DocumentUnderstandingResult` Pydantic partagé par coach + doc scanner + review screen. Un seul modèle, pas de re-fragmentation.

**Principes**
- 1 appel Vision fusionné (classify + extract prompté ensemble), pas 2.
- 4 `render_mode` côté client : `confirm / ask / narrative / reject`. Le backend ne fuit pas ses `processing_mode` internes.
- VisionKit iOS + `cunning_document_scanner` Android = **prétraitement client** (crop/deskew offline gratuit). Pas d'architecture complète autour.
- `ExtractionReviewScreen` **réduit, pas supprimé** — fallback pour docs haut enjeu (LPP, tax) quand chat-bubble ne suffit pas.
- Chat-first par défaut : docs simples atterrissent en bulle coach avec chips, pas en formulaire plein écran.

### Phase 27: Stabilisation Critique
**Goal**: Le coach ne tombe plus jamais sur le safe fallback. MSG2 (follow-up) fiable à 100%. Budget coût et débit bornés en prod.
**Depends on**: Phase 26 (navigation doit marcher avant de stabiliser le coach)
**Requirements**: STAB-01, STAB-02, STAB-03, STAB-04, STAB-05
**Success Criteria**:
  1. MSG2 follow-up renvoie une réponse Claude valide dans 100% des cas testés (scénario Sophie x10)
  2. Retry Anthropic automatique sur 429/529 (tenacity 3x, backoff exponentiel) sans erreur visible user
  3. Upload idempotent : même fichier (SHA256 identique) ne re-appelle pas Vision, renvoie résultat caché
  4. Token budget par user/jour cappé (default 50k tokens/j), dépassement = message clair "limite quotidienne"
  5. Feature flag `DOCUMENTS_V2_ENABLED` permet rollback instant sans redeploy
  6. Agent loop re-prompte Claude quand tool_use émis avec texte vide (plus d'exit silencieux)
**Plans**: TBD

### Phase 28: Pipeline Document Honnête
**Goal**: Tout upload (photo / scan / screenshot / PDF) produit l'une des 4 sorties acceptables, jamais "200 avec 0 fields sans explication". 1 appel Vision fusionné. Streaming UX (pas de spinner 30s muet).
**Depends on**: Phase 27 (infra retry/budget/flag doit être en place avant le pipeline doc)
**Requirements**: DOC-01, DOC-02, DOC-03, DOC-04, DOC-05, DOC-06, DOC-07, DOC-08
**Success Criteria**:
  1. Contrat canonique interne `DocumentUnderstandingResult` (Pydantic) utilisé par coach + doc scanner + review screen — une seule source de vérité
  2. 1 seul appel Claude Vision par document (classify + extract dans le même prompt), pas 2
  3. `extraction_status` étendu avec `non_financial` — détection locale heuristique AVANT envoi Vision
  4. Queue async : endpoint retourne `202 + job_id`, client poll ou SSE streaming
  5. Backend streame 3 events : `detected {type, person_hint}` → `summary {text}` → `render {mode, payload}`
  6. Client reçoit 4 `render_mode` opaques : `confirm` (fields review) / `ask` (1-3 questions inline chat) / `narrative` (coach bubble sans chiffres) / `reject` (pas financier)
  7. PDF chiffré détecté via `pymupdf.is_encrypted` AVANT Vision → `rejected` propre
  8. Multi-page : `pages_processed / pages_total / warning` visible, pas de truncation silencieuse
  9. `ExtractionReviewScreen` réduit aux docs haut enjeu (LPP, attestation tax, bank statement) — autres flows passent par bulle coach
  10. VisionKit iOS + `flutter_doc_scanner` (ML Kit Android GA 2024) font crop/deskew côté client, pas serveur
**Plans**: 4 plans

Plans:
- [x] 28-01-PLAN.md — Backend canonical contract DocumentUnderstandingResult + fused Vision + PDF preflight + Document Memory v1 + render_mode selector + third-party detection (completed 2026-04-14)
- [x] 28-02-PLAN.md — SSE streaming backend (sse_starlette) + Flutter Stream<DocumentEvent> client + Dart schema mirror
- [x] 28-03-PLAN.md — Native scanner (VisionKit iOS + ML Kit Android) + local image classifier pre-reject (ML Kit labels)
- [x] 28-04-PLAN.md — 4 render_mode UI bubbles (confirm/ask/narrative/reject) + ExtractionReviewSheet (snap 0.3/0.6/0.95) + reduced ExtractionReviewScreen + device gate

### Phase 29: Compliance & Privacy
**Goal**: Avant tout upload, consentement explicite. Données de tiers déclarées. PII scrubée des logs. ComplianceGuard sur output Vision. DPA Anthropic activé. nLPD/LSFin/FINMA compliant.
**Depends on**: Phase 28 (pipeline doit exister avant de le rendre conforme)
**Requirements**: PRIV-01, PRIV-02, PRIV-03, PRIV-04, PRIV-05, PRIV-06, PRIV-07, PRIV-08
**Success Criteria**:
  1. Checkbox consentement explicite pré-upload, horodaté, versionné dans table `consents`, révocable avec cascade delete
  2. Détection "document concerne une tierce personne" (conjoint) → déclaration user obligatoire avant traitement
  3. IBAN/AVS/employeur scrubés dans tous les logs (regex + tokenization `EMPLOYER_1`, `IBAN_****1234`)
  4. `evidence_text` chiffré at-rest avec clé dérivée user (Fernet/libsodium)
  5. ComplianceGuard appliqué à `summary` et `questions_for_user` issus de Claude Vision (banned terms, prescriptive, hallucination)
  6. Allowlist `fact_key` : seuls les champs utiles à MINT sont persistés (minimisation nLPD art. 6 al. 3), le reste dropé post-extraction
  7. DPA Anthropic signé + Zero Data Retention activé côté compte API + mention privacy policy MINT mise à jour (sous-traitant US, finalité)
  8. Statut `confirmed` automatique à 0.9 supprimé : user doit toujours valider explicitement (LSFin éducatif, pas décisionnel)
  9. Rétention définie : document original jamais stocké (stream-only), `profile_facts` durée de vie = compte actif + 6 mois post-suppression
**Plans**: 6 plans

Plans:
- [x] 29-01-PLAN.md — Envelope encryption AES-256-GCM + per-user DEK vault + crypto-shredding (PRIV-04, P0)
- [x] 29-02-PLAN.md — Granular ISO 29184 consent receipts (4 purposes) + merkle chain + Flutter consent sheet + 6-lang ARB (PRIV-01, P0)
- [x] 29-03-PLAN.md — Presidio PII scrubber + FPE IBAN/AVS + fact_key allowlist (8 keys) + CI log-gate (PRIV-03, PRIV-06, P1)
- [x] 29-04-PLAN.md — VisionGuard Haiku LLM-as-judge + NumericSanity + drop auto-confirm + BatchValidationBubble + adversarial PDF suite (PRIV-05, PRIV-08, P1)
- [x] 29-05-PLAN.md — Third-party opposable declaration + nominative receipt + session-scoped routing + invite stub (PRIV-02, P1)
- [x] 29-06-PLAN.md — Bedrock EU migration (shadow→primary) + two-stage image masking + DPA technical annex + legal checklist (PRIV-07, P0)

### Phase 30: Device & Test Gate
**Goal**: Scénario Sophie complet validé sur iPhone + Android réels. Corpus fixtures documents couvre les cas critiques. CI teste le flow document end-to-end.
**Depends on**: Phase 29 (tout doit être conforme avant de valider en conditions réelles)
**Requirements**: GATE-01, GATE-02, GATE-03, GATE-04
**Success Criteria**:
  1. Scénario Sophie (pavé intent + 3 follow-ups + upload LPP + mémoire J+1) validé sur iPhone physique en `flutter run --release`
  2. Scénario équivalent validé sur Android (emulator ou device)
  3. Corpus `test/fixtures/documents/` avec 10 PDFs/images anonymisés : Julien CPE LPP, Lauren HOTELA + FATCA, AVS IK, salary AFC, tax VS, US W-2, scan froissé, photo biais, screenshot mobile banking, PDF allemand
  4. Golden flow CI : upload chaque fixture → assert `render_mode` attendu + fields critiques extraits
  5. Langue UI respectée (Tessinois + doc allemand → réponse italienne, pas allemande)
  6. Prompt injection défendue : fixture avec "Ignore previous instructions" dans le doc → Vision ignore l'instruction
  7. Coût moyen par document mesuré et reporté (< $0.05/doc cible)
  8. Latence p95 mesurée et reportée (< 10s avec streaming)
**Plans**: TBD

**Execution Order:**
Phases execute sequentially: 27 -> 28 -> 29 -> 30
Integration checker after phases 28 and 30. Device gate mandatory before phase 30 sign-off.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 27. Stabilisation Critique | v2.7 | 1/1 | Complete    | 2026-04-14 |
| 28. Pipeline Document Honnête | v2.7 | 4/4 | Complete   | 2026-04-14 |
| 29. Compliance & Privacy | v2.7 | 6/6 | Complete   | 2026-04-14 |
| 30. Device & Test Gate | v2.7 | 0/? | Planned | — |

---
*Roadmap created: 2026-04-12*
*Last updated: 2026-04-14 — v2.7 milestone added (4 phases) after 4-expert challenge of external audit*

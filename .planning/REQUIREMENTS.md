# Requirements: MINT v2.5 Transformation

**Defined:** 2026-04-12
**Core Value:** Un inconnu ouvre MINT, ressent quelque chose, recoit une reponse qui le surprend, cree un compte pour ne pas perdre ca, et revient chaque mois parce que MINT sait des choses que personne d'autre ne sait sur sa vie financiere.

## v2.5 Requirements

Requirements for the Transformation milestone. Each maps to roadmap phases.

### Anonymous Hook & Auth Bridge

- [x] **ANON-01**: Anonymous user can send messages to coach via rate-limited public endpoint (3 messages/session by IP)
- [x] **ANON-02**: Anonymous user tapping a felt-state pill on intent screen arrives in coach chat with that intent as context
- [x] **ANON-03**: After 3 value exchanges, MINT surfaces a natural auth gate ("Je peux garder tout ca en memoire pour toi")
- [x] **ANON-04**: Anonymous conversation history is transferred to persistent storage after user creates account (zero message loss)
- [x] **ANON-05**: Backend anonymous endpoint uses "mode decouverte" system prompt (respond to intent, don't ask for profile)
- [x] **ANON-06**: Anonymous session is device-scoped (SecureStorage session token) to prevent rate-limit evasion

### Commitment Devices

- [x] **CMIT-01**: Each Layer 4 insight includes an implementation intention (WHEN/WHERE/IF-THEN) that user can accept or edit
- [x] **CMIT-02**: Accepted implementation intentions are persisted and surfaced as reminders via notification scheduler
- [x] **CMIT-03**: Fresh-start anchor detector identifies landmark dates (birthday, month-1, year-start, 1-year anniversary) from user profile
- [x] **CMIT-04**: Fresh-start anchors trigger ONE proactive MINT message at each landmark date
- [x] **CMIT-05**: Pre-mortem prompt appears before irrevocable decisions (EPL, capital withdrawal, 3a closure) -- "Imagine qu'on est en 2027 et que cette decision s'est mal passee"
- [x] **CMIT-06**: Pre-mortem free-text response is stored in dossier and referenced in future related conversations

### Coach Intelligence

- [x] **INTL-01**: Coach asks provenance questions naturally in conversation ("au fait, ce 3a, c'est qui qui te l'a propose ?")
- [x] **INTL-02**: Provenance tags are stored in backend and injected into CoachContext for future conversations
- [x] **INTL-03**: Coach detects implicit earmarks in conversation ("ca c'est l'argent de mamie") and stores them via conversation_memory_service
- [x] **INTL-04**: Earmark tags are respected in all future financial analyses (never aggregate earmarked monies into "patrimoine total")

### Couple Mode Dissymetrique

- [x] **COUP-01**: User can declare "Je suis en couple" and enter what they know about their partner (estimated salary, LPP, age, 3a)
- [x] **COUP-02**: MINT generates 5 questions to ask the partner based on gaps in the estimation ("Demande-lui son salaire assure LPP")
- [x] **COUP-03**: Couple projections use partner estimates with explicit confidence degradation (estimated data = lower confidence)
- [x] **COUP-04**: Partner data is stored locally only (not shared) -- privacy by architecture

### Cleo Loop Navigation (transversal)

- [x] **LOOP-01**: After each coach insight, MINT suggests the next step in the loop (plan, action, or document) — never a dead end
- [x] **LOOP-02**: After each user action (document upload, commitment accepted, pre-mortem completed), coach acknowledges and updates the memory visibly ("J'ai note, je m'en souviendrai")
- [x] **LOOP-03**: The Insight→Plan→Conversation→Action→Memory cycle is visible in the UX — user can see where they are in the loop (coach state indicator or contextual next-step chips)

### Living Timeline (3 tensions card -> full timeline)

- [x] **TIME-01**: Aujourd'hui screen shows 3 tension cards (past earned, present pulsing, future ghosted) as living placeholder
- [x] **TIME-02**: Tension cards update dynamically based on user interactions, documents uploaded, and coach conversations
- [x] **TIME-03**: Full living timeline replaces Aujourd'hui tab -- single-screen center of gravity with nodes (tap to reveal)
- [x] **TIME-04**: Documents, chat history, commitment intentions, couple data feed into timeline nodes
- [x] **TIME-05**: Timeline shows earned achievements (past), active tensions (present, pulsing), and projected scenarios (future, ghosted)

## v2.6+ Requirements (Deferred)

### Premium & Monetisation

- **PREM-01**: RevenueCat integration with Apple IAP and Google Play Billing
- **PREM-02**: Paywall UI with gratuit/premium feature matrix
- **PREM-03**: 15 CHF/mois pricing with VZ anchor ("94% moins cher qu'un forfait VZ")
- **PREM-04**: Premium gates on document upload, 4-layer insights, implementation intentions, couple mode

### Long-term Directions

- **GRAD-01**: Graduation Protocol -- concept mastery tracking, guided exercises after 3rd engagement
- **DOSS-01**: Dossier Federation -- portable open-format dossier, user-owned
- **POLI-01**: Political Pocket -- 5th layer collective_action (FRC, FINMA, parliamentary initiatives)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Premium payments / Stripe / RevenueCat | Too early -- zero external users yet. Deferred to v2.6. |
| Voice AI | Phase 3 roadmap (v2.7+) |
| Multi-LLM / model switching | Phase 3 roadmap (v2.7+) |
| Bidirectional couple mode | Both-partners-on-MINT is rare. Dissymmetric only for v2.5. |
| Push notifications infrastructure | Commitment devices degrade gracefully with local notifications. Push = v2.6. |
| Full Graduation Protocol | Direction long-terme, not a v2.5 deliverable. |
| Dossier Federation | Direction long-terme, not a v2.5 deliverable. |
| Political Pocket | Direction existentielle, not a v2.5 deliverable. |
| Budget tracking | Exists but not in scope for v2.5 improvements. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ANON-01 | Phase 13 | Complete |
| ANON-02 | Phase 13 | Complete |
| ANON-03 | Phase 13 | Complete |
| ANON-04 | Phase 13 | Complete |
| ANON-05 | Phase 13 | Complete |
| ANON-06 | Phase 13 | Complete |
| CMIT-01 | Phase 14 | Complete |
| CMIT-02 | Phase 14 | Complete |
| CMIT-03 | Phase 14 | Complete |
| CMIT-04 | Phase 14 | Complete |
| CMIT-05 | Phase 14 | Complete |
| CMIT-06 | Phase 14 | Complete |
| INTL-01 | Phase 15 | Complete |
| INTL-02 | Phase 15 | Complete |
| INTL-03 | Phase 15 | Complete |
| INTL-04 | Phase 15 | Complete |
| COUP-01 | Phase 16 | Complete |
| COUP-02 | Phase 16 | Complete |
| COUP-03 | Phase 16 | Complete |
| COUP-04 | Phase 16 | Complete |
| TIME-01 | Phase 17 | Complete |
| TIME-02 | Phase 17 | Complete |
| TIME-03 | Phase 18 | Complete |
| TIME-04 | Phase 18 | Complete |
| TIME-05 | Phase 18 | Complete |
| LOOP-01 | Phase 13, 14, 15 | Complete |
| LOOP-02 | Phase 14, 15 | Complete |
| LOOP-03 | Phase 17, 18 | Complete |

**Coverage:**
- v2.5 requirements: 28 total
- Mapped to phases: 28
- Unmapped: 0

---

## v2.7 Coach Stabilisation + Document Digestion

**Defined:** 2026-04-14
**Core Value:** Le coach fonctionne bout en bout (MSG2 fiable, mémoire typée, réponses denses) ET MINT digère n'importe quel document (photo / scan / screenshot / PDF) via un contrat canonique interne, sans jamais afficher "Analyse indisponible".

### Stabilisation Critique (Phase 27)

- [ ] **STAB-01**: MSG2 follow-up renvoie une réponse Claude valide dans 100% des scénarios testés (agent loop re-prompte quand tool_use sans texte)
- [ ] **STAB-02**: Retry automatique Anthropic (tenacity, 3x, backoff exponentiel) sur 429/529/503 sans erreur visible user
- [ ] **STAB-03**: Upload idempotent — SHA256(file) caché, même fichier renvoie résultat sans re-appeler Vision
- [ ] **STAB-04**: Token budget par user/jour (default 50k), dépassement = message explicite "limite quotidienne atteinte"
- [ ] **STAB-05**: Feature flag `DOCUMENTS_V2_ENABLED` + `COACH_MSG2_FIX_ENABLED` permettent rollback sans redeploy

### Pipeline Document Honnête (Phase 28)

- [x] **DOC-01**: Contrat Pydantic canonique interne `DocumentUnderstandingResult` partagé par coach + doc scanner + review (une seule source de vérité, pas de re-fragmentation)
- [x] **DOC-02**: 1 seul appel Claude Vision par document (classify + extract fusionnés dans le prompt), pas 2
- [x] **DOC-03**: `extraction_status` étendu avec `non_financial` — détection heuristique locale AVANT envoi Vision (titre, mots-clés) *(backend extraction_status.non_financial done in 28-01; local pre-reject ML Kit deferred to 28-03)*
- [ ] **DOC-04**: Queue async + SSE streaming : backend émet `detected` → `summary` → `render` en 3 events progressifs
- [ ] **DOC-05**: Client reçoit 4 `render_mode` opaques (`confirm` / `ask` / `narrative` / `reject`) — les `processing_mode` internes backend ne fuient pas *(backend selector done in 28-01; client switching deferred to 28-04)*
- [ ] **DOC-06**: `ExtractionReviewScreen` réduit aux docs haut enjeu (LPP, attestation tax, bank statement) ; autres flows passent par bulle coach + chips dans le chat
- [x] **DOC-07**: Prétraitement client : VisionKit iOS (`VNDocumentCameraViewController`) + `cunning_document_scanner` Android font crop/deskew/multi-page offline
- [x] **DOC-08**: Gestion PDF robuste — détection `pymupdf.is_encrypted` avant Vision, `pages_processed/pages_total/warning` transparent, pas de truncation silencieuse

### Compliance & Privacy (Phase 29)

- [ ] **PRIV-01**: Checkbox consentement explicite pré-upload, horodatée, versionnée (table `consents`), révocable avec cascade delete
- [ ] **PRIV-02**: Détection "document de tiers" (nom ≠ user) → déclaration obligatoire "J'ai l'autorisation de X" avant traitement
- [ ] **PRIV-03**: Scrubbing PII systématique dans logs — IBAN tokenisé, AVS haché, employeur → `EMPLOYER_1`, filename haché
- [ ] **PRIV-04**: `evidence_text` persisté chiffré at-rest (Fernet + clé dérivée user)
- [ ] **PRIV-05**: ComplianceGuard appliqué aux `summary` et `questions_for_user` issus de Claude Vision
- [ ] **PRIV-06**: Allowlist `fact_key` — minimisation nLPD, champs inutiles à MINT dropés post-extraction
- [ ] **PRIV-07**: DPA Anthropic signé + Zero Data Retention activé + privacy policy MINT mise à jour (sous-traitant US documenté)
- [ ] **PRIV-08**: Statut `confirmed` auto à 0.9 supprimé — toujours validation user explicite (LSFin éducatif, pas décisionnel)

### Device & Test Gate (Phase 30)

- [ ] **GATE-01**: Scénario Sophie (pavé intent + 3 follow-ups + upload LPP + mémoire J+1) validé en `flutter run --release` sur iPhone physique
- [ ] **GATE-02**: Scénario équivalent validé sur Android (device ou emulator Pixel récent)
- [ ] **GATE-03**: Corpus `test/fixtures/documents/` avec 10 docs anonymisés couvrant : Julien CPE LPP, Lauren HOTELA, AVS IK, salary AFC, tax VS, US W-2, scan froissé, photo biais, screenshot mobile banking, PDF allemand
- [ ] **GATE-04**: Golden flow CI upload chaque fixture, assert `render_mode` + fields critiques ; prompt injection fixture ignorée par Vision ; coût < $0.05/doc ; p95 < 10s

### v2.7 Traceability

| REQ | Phase | Status |
|-----|-------|--------|
| STAB-01..05 | Phase 27 | Complete |
| DOC-01, DOC-02, DOC-08 | Phase 28-01 | Complete |
| DOC-03 (backend half) | Phase 28-01 | Partial |
| DOC-05 (backend selector) | Phase 28-01 | Partial |
| DOC-04, DOC-06, DOC-07 | Phase 28-02..04 | Planned |
| PRIV-01..08 | Phase 29 | Planned |
| GATE-01..04 | Phase 30 | Planned |

**v2.7 Coverage:** 25 requirements total, all mapped.

---
*Requirements defined: 2026-04-12 (v2.5), 2026-04-14 (v2.7)*
*Last updated: 2026-04-14 -- v2.7 added post 4-expert challenge of external audit*

# Pitfalls Research

**Domain:** Adding document intelligence (Vision/OCR), anticipation engine (rule-based alerts), financial biography (local narrative memory), and bLink Open Banking to existing Swiss fintech app (MINT v2.0)
**Researched:** 2026-04-06
**Confidence:** HIGH — grounded in MINT's own codebase analysis (existing `document_vision_service.py`, `lpp_certificate_parser.py`, `blink_connector.py`, `consent_manager.py`, `coach_memory_service.dart`, `ocr_sanitizer.dart`), W1-W14 audit history, and Swiss compliance framework (LSFin, nLPD, LPP art. 14). No speculative claims without explicit flagging.

---

## Critical Pitfalls

### Pitfall 1: LPP Plan Type Blindness — Applying 6.8% to 1e Capital

**What goes wrong:**
`document_vision_service.py` extracts `tauxConversion` as a single float. If the document is for a plan de type 1e (enveloppement libre), the certificate does not show a conversion rate — because 1e plans have no guaranteed conversion rate at all. The employee bears the full investment risk and the pension is market-value-driven at retirement. Applying 6.8% (the LPP legal minimum) to a 1e capital produces a rente estimate that can be 40-60% higher than reality. The existing validator in `_validate_fields()` only checks range (0.03–0.08), which will not reject a missing field.

**Why it happens:**
The LPP extraction prompt in `_build_extraction_prompt()` asks for `tauxConversion` regardless of plan type. There is no plan-type detection step before conversion-rate extraction. Agents implementing document intelligence default to the well-known 6.8% because it is the legal minimum stated everywhere in the codebase and documentation. The surobligatoire/1e distinction is a second-order concern that gets deferred.

**How to avoid:**
1. Add a plan-type detection pass **before** any conversion-rate extraction: look for keywords "enveloppement libre", "1e", "libre passage individualisé", "freie Vorsorge", "freizügig" in the certificate text.
2. If plan type is detected as 1e: set `tauxConversion = null`, flag `planType = "1e"`, and inject a warning: "Plan de type 1e — la rente n'est pas garantie. Le capital est investi individuellement. Consulte ton certificat ou ta caisse pour la valeur de rachat actuelle."
3. In `lpp_calculator.dart` (financial_core), add a guard: if `planType == "1e"` and `tauxConversion == null`, refuse to project a rente. Return a confidence score of 0 with an explanation.
4. Add a dedicated golden test: Julien's CPE Plan Maxi (surobligatoire, known rate) vs a synthetic 1e certificate — verify different outputs.

**Warning signs:**
- `tauxConversion` extracted as 6.8% on a document that mentions "portefeuille individuel" or "Einzelkonto"
- Confidence score shows HIGH on a certificate where `planType` was not extracted
- Rente projection for a high-earner exceeds 60% of final salary without a surobligatoire breakdown

**Phase to address:** Phase 1 (Document Intelligence extraction) — before any projection feeds from extracted LPP data.

---

### Pitfall 2: LLM Vision Hallucinating Numbers That Pass Range Validation

**What goes wrong:**
Claude Vision is asked to extract `avoirLppTotal` from an LPP certificate. The document is a low-quality smartphone photo with glare on the CHF amount. Claude cannot read the number clearly and extrapolates from surrounding context (e.g., it can read the employer contribution and salary, so it estimates the total). It returns `confidence: "medium"` and a plausible number like `"avoirLppTotal": 189000.00`. This passes the `_validate_fields()` range check (0–5,000,000). The user confirms the value without noticing it is different from their actual certificate. Three months later, their LPP rachat calculation is wrong by CHF 50,000.

**Why it happens:**
Range validation catches impossible values (CHF -1 or CHF 9,000,000) but cannot detect plausible-but-wrong values. `source_text` is the mitigation — the extracted number should be accompanied by the exact text from which it was read — but this relies on Claude faithfully returning the verbatim source text, which is not guaranteed when the image is degraded.

**How to avoid:**
1. Require `source_text` for every extracted field. If Claude returns a field without a `source_text`, automatically downgrade confidence to LOW and flag `needs_review = True`.
2. Implement a cross-document consistency check: if the user uploads both an LPP certificate and a salary certificate, verify that the `salaireAssure` on the LPP certificate is within 15% of the `salaireBrutAnnuel` on the salary certificate. Discrepancies flag the LPP extraction.
3. In the confirmation UI, always show `source_text` alongside the extracted value. The user reads "Source: 'Avoir de vieillesse total: CHF 189'000.00'" and can visually compare to their document.
4. For any field where confidence is MEDIUM or LOW, add a direct link to the Swiss LPP lookup portal (www.ch.ch/fr/institutions-LPP/) rather than accepting the extracted value as-is.
5. Add an image quality check before extraction: if blur score (variance of Laplacian) is below a threshold, warn the user to retake the photo before sending to Claude Vision.

**Warning signs:**
- `source_text` field is empty or contains generic language ("voir document") rather than verbatim numbers
- Extracted values cluster suspiciously around round numbers (50,000 / 100,000 / 200,000)
- Overall confidence is HIGH but individual field confidences are all "medium"

**Phase to address:** Phase 1 (Document Intelligence) — confirmation UI and source_text enforcement before Phase 2 uses extracted data for projections.

---

### Pitfall 3: Document Images Containing PII Leaked to Logs or Retained After Extraction

**What goes wrong:**
`document_vision_service.py` receives `image_base64` and calls `client.messages.create()`. The current code logs at `WARNING` level on JSON parse error. A future developer adds a debug log line: `logger.debug("Sending image to Vision: %s", image_base64[:100])`. Now 100 bytes of a base64-encoded document (which could decode to a fragment showing an IBAN, name, or AVS number) appear in Railway production logs. nLPD art. 6 requires data minimization; FINMA circular 2008/21 requires operational risk controls. This is a P0 compliance violation the moment it occurs.

Separately: the `ocr_sanitizer.dart` security contract says "Document images are NEVER stored." But the Flutter `document_service.dart` may write the image to a temp file during processing. If the temp file survives a crash or is accessible via iTunes File Sharing, the contract is violated.

**Why it happens:**
Debug logging is the fastest way to diagnose extraction failures. Developers add it without thinking about what the base64 payload contains. The temp-file issue arises because Flutter's image picker writes to `getTemporaryDirectory()`, and cleanup is not guaranteed if the app crashes between upload and processing.

**How to avoid:**
1. Add a lint rule (via `analysis_options.yaml`) that flags `logger.debug` in files under `services/document_*`. Use a custom lint or a comment-based guard: all debug log lines near image handling must go through a `_safe_log()` wrapper that explicitly strips image data.
2. In the backend, never log `image_base64` at any log level. The `extract_with_vision()` function already does not log it — enforce this with a test that checks log output during extraction does not contain base64 strings.
3. On mobile, use `flutter_secure_storage`-based temp tracking: write the temp path to a secure registry on upload, delete it explicitly after extraction completes, and add a startup cleanup job that deletes any orphaned temp files from previous sessions.
4. Add a deletion assertion to the document upload test: after processing, assert the original file path no longer exists.
5. NEVER log the `raw_analysis` field returned by Claude — it may contain verbatim transcription of document text including names and IBANs.

**Warning signs:**
- `raw_analysis` being stored in any persistent model (database, SharedPreferences, RAG vector store)
- `document_service.dart` tests do not assert file deletion
- Any `logger.info` or `logger.debug` call inside `document_vision_service.py` that references the image parameter

**Phase to address:** Phase 1 (Document Intelligence) — privacy contract must be enforced from the first extraction, not retrofitted later.

---

### Pitfall 4: Alert Fatigue from Anticipation Engine — Every Rule Firing Simultaneously

**What goes wrong:**
The anticipation engine is rule-based. Rules include: fiscal deadline (3a contribution before Dec 31), profile staleness (LPP data not updated for 12 months), legislative change (new LPP reform effective Jan 1), and life event detection (user turns 50). At onboarding time, a new user with a complete profile will trigger 4-8 rules simultaneously. The `Aujourd'hui` tab shows 8 alert cards. The user dismisses all of them. MINT has trained the user to ignore alerts. Six months later, a genuinely critical alert (EPL blocking window expiring) is ignored.

**Why it happens:**
Rules are evaluated independently. Each rule developer adds their rule correctly. No one owns the global "how many alerts is too many" constraint. The rule prioritization is defined (temporal_priority_service.dart exists), but there is no hard cap on alerts per session enforced at the pipeline level.

**How to avoid:**
1. Enforce a hard cap of **maximum 3 alert cards** on the `Aujourd'hui` tab at any time. This is not a soft guideline — the `DashboardCuratorService` must truncate after 3, always.
2. Add a "quiet period" after each alert: once an alert has been shown, it cannot re-surface for at least 7 days unless urgency is CRITICAL (a legislative deadline within 14 days).
3. Implement alert deduplication: fiscal and profile rules that fire simultaneously on first login are collapsed into a single onboarding prompt ("Complète ces 3 choses to unlock MINT's full intelligence") rather than shown as 3 separate cards.
4. Add a "first session grace period": on the user's first 3 sessions, only 1 alert is shown (the highest-priority one). The rest are queued.
5. Track alert dismissal rate per rule. If a rule is dismissed >80% of the time within 5 seconds, auto-disable it for that user.

**Warning signs:**
- QA test with a complete profile (Julien + Lauren) shows more than 3 cards on `Aujourd'hui`
- `temporal_priority_service.dart` returns a ranked list but the caller does not enforce the top-3 cap
- No "last_shown" timestamp on alert records

**Phase to address:** Phase 2 (Anticipation Engine) — cap must be in the `DashboardCuratorService` from the first implementation, not added post-alert-fatigue complaints.

---

### Pitfall 5: Financial Biography Leaking PII Into Coach Context

**What goes wrong:**
`MemoryContextBuilder` has a `_sanitize()` function and explicit rules: "NEVER include exact salary, IBAN, name, SSN, employer." But `CoachMemoryService.saveInsight()` is called from conversation handlers where the insight `summary` field is populated by parsing Claude's response. If Claude's response says "Julien a un salaire de 122'207 CHF chez son employeur à Sion", and the coach handler stores this verbatim as an insight summary, the next call to `buildContext()` injects "Julien a un salaire de 122'207 CHF chez son employeur à Sion" into the system prompt — which goes to Anthropic's API.

nLPD art. 6 and CLAUDE.md §6 both prohibit this. The existing `_sanitize()` only strips control characters and truncates length — it does not redact PII patterns.

**Why it happens:**
The insight-saving logic is in the coach response handler. The developer building that handler assumes that `saveInsight()` will sanitize the content. The developer building `CoachMemoryService` assumes the caller will sanitize before calling. Neither does it. This is the classic two-party assumption gap.

**How to avoid:**
1. Add a PII redaction step **inside** `saveInsight()` that is not bypassable by callers. Use a `_redactPii()` function that applies regex patterns:
   - Swiss salary patterns: `\b\d{2,3}[']\d{3}\b` → replace with "~{montant}"
   - IBAN patterns: `\bCH\d{2}[ ]\d{4}[ ]\d{4}[ ]\d{4}[ ]\d{4}[ ]\d{1}\b` → remove
   - AVS number: `\b756\.\d{4}\.\d{4}\.\d{2}\b` → remove
   - Employer/location: harder to regex — instead limit insight summaries to **topic tags + magnitude buckets** ("revenu >100k CHF" not "122'207 CHF")
2. Add a test in `coach_memory_service_test.dart`: call `saveInsight()` with a summary containing "122'207 CHF", then call `buildContext()` and assert the output does NOT contain "122'207".
3. In `MemoryContextBuilder._buildBlock()`, add a final assertion before returning: if output matches salary patterns, throw in debug mode and log a warning in production.
4. The `_filterMetadata()` in `CoachMemoryService` is correct (allowlist approach) but only covers metadata — apply the same allowlist philosophy to `summary` fields: only topic category + relative magnitude, never verbatim financial figures.

**Warning signs:**
- `CoachInsight.summary` strings containing CHF amounts with apostrophe separators
- No test that validates PII is not present in `buildContext()` output
- `saveInsight()` called with `insight.summary = response.text` (unprocessed LLM response)

**Phase to address:** Phase 3 (Financial Biography) — enforced from the first `saveInsight()` call in Phase 3, with a retroactive test added to Phase 1 setup.

---

### Pitfall 6: bLink Sandbox-to-Production Gap — Consent Architecture That Doesn't Survive Real OAuth

**What goes wrong:**
`BLinkConnector` in sandbox mode takes a `consent_id` string and returns mock data. In production, bLink uses OAuth 2.0 with a bank-specific redirect flow (bank login → consent grant → callback with authorization code → token exchange → access token). The current `ConsentManager.create_consent()` creates a consent record locally and returns a UUID — it does not initiate any OAuth flow. When production is enabled, the entire OAuth flow needs to be built, but by then:
- Mobile UX assumes consent = "show bank list, pick one, done"
- Backend assumes consent_id is issued internally, not by the bank's OAuth server
- The `BankingConsentModel` schema does not store OAuth access tokens, refresh tokens, or bank-issued consent IDs

This means the production migration requires a schema change, a new OAuth flow, and a full UX rebuild — while the sandbox demo "works."

**Why it happens:**
The sandbox works perfectly for development. It's tempting to ship Phase 5 (bLink) with sandbox still active and defer the OAuth architecture to "when we're ready for production." But if the sandbox mock shapes the UX (no redirect, no browser handoff, no token management), the UX will be wrong for production and users will see a broken flow when real bank connections are added.

**How to avoid:**
1. Even in sandbox mode, simulate the full OAuth redirect flow: show a "bank login" webview (even if it's a mock page), simulate a callback, and issue the consent_id only after the "OAuth flow" completes. This forces the mobile UX to handle redirects now.
2. Add `oauth_access_token`, `oauth_refresh_token`, `token_expires_at`, and `bank_consent_id` fields to `BankingConsentModel` now (nullable, unused in sandbox). This makes the schema production-ready without requiring a migration at the worst possible time.
3. Document the exact bLink OAuth 2.0 flow (authorization endpoint, token endpoint, required scopes) in `docs/BLINK_INTEGRATION.md` before writing any sandbox-to-production bridge.
4. Add a feature flag `BLINK_PRODUCTION_ENABLED` that is false by default. The production path in `BLinkConnector` should never be reachable without this flag being explicitly set.

**Warning signs:**
- `BLinkConnector.get_accounts()` called without any preceding OAuth flow in the mobile client
- `ConsentManager.create_consent()` returns a UUID the mobile client generated locally rather than a bank-issued token
- No `oauth_token` column in `banking_consent` table schema

**Phase to address:** Phase 5 (bLink Sandbox) — architecture must account for production requirements even while running in sandbox.

---

### Pitfall 7: Stale Extracted Data Silently Feeding Financial Projections

**What goes wrong:**
A user scans their LPP certificate in January. Their `avoirLppTotal` is updated to 70,377 CHF. In April, they change jobs and their new employer has a completely different LPP plan with a new avoir. They never rescan. The anticipation engine does not fire an alert (no rule detects "employer changed → LPP data stale"). In June, they ask MINT about EPL eligibility — MINT projects based on January data and suggests they have enough for a down payment. They don't.

The PROJECT.md explicitly calls out: "Every extracted field carries extractedAt + decay model. Stale data = conservative fallback." But the decay model and fallback behavior must actually be implemented — it is a stated requirement, not a shipped feature.

**Why it happens:**
The decay model is defined at the architecture level but is easy to skip during implementation. Each individual service that uses LPP data (EPL eligibility, rachat calculation, retirement projection) would need to check data freshness individually. If no one owns this cross-cutting concern, it gets implemented nowhere.

**How to avoid:**
1. Implement a `DataFreshnessGuard` as a cross-cutting service: any financial projection that uses extracted data must pass through it. The guard checks `extractedAt` against a per-field decay model (LPP certificate: 12 months, salary: 6 months, tax declaration: 12 months).
2. If data is stale, the projection must show a confidence band rather than a point estimate, and the premier éclairage must include: "Données basées sur ton certificat de janvier 2026 — rescan pour affiner."
3. Add a rule to the anticipation engine: "LPP data > 11 months old AND user has employer listed" → trigger a "rescanne ton certificat" alert before December deadline.
4. In `EnhancedConfidence`, the freshness axis (already defined as one of the 4 axes) must be wired to `extractedAt`. Currently the freshness axis may only consider session recency, not document scan date.

**Warning signs:**
- `extractedAt` stored per field but never read by any consumer service
- `EnhancedConfidence.freshness` computed without referencing document scan dates
- LPP projection in `lpp_calculator.dart` does not take `dataFreshnessScore` as an input

**Phase to address:** Phase 1 (Document Intelligence) — decay model must be set at extraction time, verified in Phase 2 (Anticipation Engine) alerting, and consumed in Phase 3 projections.

---

### Pitfall 8: Anticipation Engine Triggering Legislative Alerts for Non-Applicable Archetypes

**What goes wrong:**
A rule fires: "LPP reform 2025 — new coordination threshold effective Jan 1, 2026." The alert says "Le seuil de coordination LPP passe à 26'460 CHF — ton salaire assuré va changer." But for an `expat_us` archetype (Lauren), LPP applicability depends on her permit type and employment contract. For an `independent_no_lpp` archetype, LPP reform is irrelevant. The alert still fires because the rule does not filter by archetype.

**Why it happens:**
Legislative rules are written generically ("this law changed") and archetype filtering is added as an afterthought (or not at all). The rule developer knows the law; they don't always know the full 8-archetype matrix.

**How to avoid:**
1. Every rule in the anticipation engine must declare an `applicable_archetypes` field (list). A rule without this field fails validation — it cannot be added to the engine.
2. Rules that fire for all archetypes must explicitly declare `applicable_archetypes: ["all"]` — forcing the developer to make a conscious choice.
3. For legislative rules, the default assumption is **not** "applicable to all" — it is "applicable to the minimal archetype set" (e.g., `swiss_native`, `expat_eu` for LPP changes; add others only after verifying).
4. Add a test: for each rule, verify it does NOT fire for archetypes not in its `applicable_archetypes` list.

**Warning signs:**
- A rule in the rules engine that does not reference `user.archetype` or `applicable_archetypes`
- An alert shown to a user with `archetype = independent_no_lpp` mentioning "cotisations LPP"
- No test file `test_anticipation_rules_archetype_filtering.py`

**Phase to address:** Phase 2 (Anticipation Engine) — rule schema must require archetype declaration from the first rule added.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using sandbox `ConsentManager` in-memory fallback for v2.0 demo | No DB migration needed, faster to demo | Consent records lost on restart; multi-user scenarios broken; doesn't exercise real persistence code | Never in staging — in-memory only for unit tests |
| Storing `raw_analysis` from Vision extraction in DB | Easy debugging of extraction quality | Contains verbatim document text including PII; nLPD violation | Store only extracted field values and their confidence — never raw analysis |
| Single `tauxConversion` field for LPP (no obligatoire/surobligatoire distinction) | Simpler data model | Massively wrong rente projections for plans with mixed rates; 1e plans silently broken | Never — the split is LPP-required from day one |
| SharedPreferences keys without user ID prefix for biography | Works on single-account devices | Data leaks between accounts on shared devices; breaks at logout | Never — prefix with user ID before first production user |
| Firing all anticipation rules on every app open | Simple implementation | Alert fatigue in 2 sessions; users learn to ignore MINT | Never — session-aware rule evaluation from the start |
| Using `extractedAt = now()` for all fields, even manually-entered ones | Unified timestamp model | Manually-entered salary (estimated quality) gets treated as fresh document data | Manual entries must use `DataSource.estimated` + lower freshness weight |
| Document temp file cleanup only on success | Simpler code path | On crash or network error, image persists on device — nLPD violation | Never — cleanup in `finally` block, not just on success |

---

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Claude Vision API (document extraction) | Sending full 4K image to Vision API (large payload, slow, expensive) | Resize to max 1920px on device before encoding; compress JPEG to 70% quality; target <500KB per image |
| Claude Vision API | Expecting deterministic output for identical images | Add a hash-based cache keyed on (image_hash, doc_type) with 24h TTL to avoid redundant API calls for the same document |
| bLink API (sandbox) | Treating mock `last_sync` timestamp as real freshness signal | In sandbox, `last_sync = now()` is always fresh; add a `isMockData: true` flag to all sandbox responses so the UI can show "Données de démonstration" |
| bLink API (production path) | Using bLink sandbox client_id in production (different environments) | Separate `BLINK_CLIENT_ID_SANDBOX` and `BLINK_CLIENT_ID_PROD` env vars; never fall through from prod config to sandbox creds |
| Anthropic API timeout (30s) | Vision extraction fails silently if image is large or API is slow | The current 30s timeout in `document_vision_service.py` is correct; add explicit retry with exponential backoff for 429/503, surface timeout to user as "Réessaie — traitement lent" not as a crash |
| nLPD deletion request | Deleting profile data but not deleting banker consent records | When a user requests data deletion, cascade to: profile, coach_insights (SharedPreferences), banking_consent (DB), audit_events (DB), RAG embeddings (backend sync) |

---

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Evaluating all anticipation rules on every session start | 200ms delay on app open as rule evaluation runs synchronously | Run rule evaluation in a background isolate; cache rule results with a 1h TTL | Immediately at 10+ rules |
| LPP extraction calling Vision API inline on document upload | UI freezes waiting for 3-5s Vision API response | Use async job pattern: upload → job_id → poll for completion → show result | On every upload — this is a user-facing latency issue |
| Storing entire `FinancialBiography` graph in a single SharedPreferences key | On large devices with 50+ biography entries, key read/write locks the UI thread | Shard by year or life event; use `flutter_secure_storage` for sensitive fields only | At ~20 biography entries on older devices |
| Anticipation rule using `datetime.now()` for deadline calculations without timezone | Deadline fires 1-2 hours early/late for Geneva (UTC+1/+2) vs Zurich (same timezone, but edge cases at DST boundaries) | Always use Swiss timezone (Europe/Zurich) with `pytz` for all deadline computations | At DST transitions (March/October) |
| IBAN from bLink stored in Coach context | IBAN transmitted to Anthropic API on every coach session | IBAN is never in `CoachContext`; only balance buckets ("épargne >20k CHF") | Immediately — this is a P0 privacy violation the moment it ships |

---

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Image base64 payload logged at any log level | Document contents (including names, IBANs, salary) in Railway production logs — nLPD P0 violation | Assert in tests that `document_vision_service.py` log output contains no base64 patterns during extraction |
| AVS number extracted and stored (even temporarily) | AVS is a national identifier — nLPD art. 6 treats it as sensitive; storage without explicit purpose is illegal | `ocr_sanitizer.dart` correctly converts AVS to boolean (`hasAvsNumber: true`) — enforce this pattern in all document parser services; no raw AVS number in any model |
| bLink IBAN stored in `BankAccount.iban` field and passed to any LLM | IBAN is PII; sending to Anthropic API violates data minimization | `BankAccount.iban` exists for internal account identification; never include it in `CoachContext` or any RAG embedding |
| `document_service.dart` writing to external storage on Android | Document images accessible to other apps on Android <10 without scoped storage | Use `getApplicationDocumentsDirectory()` (app-private) exclusively; never `getExternalStorageDirectory()` |
| Coach insight summaries containing employer name + salary | Combination is sufficient to identify the user; nLPD art. 3 (sensitive combination) | Enforce: insight summary = topic category + relative magnitude only; employer name is never stored in any insight |
| bLink consent_id used as a capability token (no scope enforcement) | Any endpoint call with a valid consent_id gets all data regardless of granted scopes | `ConsentManager.is_consent_valid()` only checks expiry — add scope enforcement: `is_scope_granted(consent_id, scope)` checked at every bLink API call |

---

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Showing extraction result immediately without user confirmation | User's profile updated with a wrong value (hallucinated by Vision or misread photo); trust permanently broken | Every extracted field must go through a confirmation screen before profile injection; show source_text next to value |
| Asking user to rescan a document when partial extraction succeeded | User frustrated; they already spent effort on the upload | Show what was extracted (with confidence indicators) and ask user to confirm the LOW-confidence fields only, not redo the entire document |
| Showing raw field names ("avoirLppTotal") in confirmation UI | User doesn't know what "avoirLppTotal" means; confirmation is meaningless | Always show the human label ("Avoir total LPP") with a tooltip explaining what the field means and why MINT needs it |
| Anticipation alert explaining a law change without saying what the user should DO | User reads "LPP reform active depuis janvier" and doesn't know if it affects them or what to do | Every alert must end with one concrete action ("Vérifie ton nouveau salaire assuré sur ton prochain certificat") or a dismissable "non applicable pour moi" option |
| Financial biography visible in full detail to the user | User may not remember authorizing MINT to remember something; creates anxiety | Biography is an internal service layer only; users see its outputs (coach personalization, alert context) not the raw biography entries |
| bLink connection shown as a primary onboarding step | Users who don't want to connect their bank feel excluded; conversion drops | bLink is progressive enrichment — shown after the user has already received a premier éclairage and wants to "unlock more precision" |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **LPP extraction:** Verify `planType` detection runs BEFORE `tauxConversion` extraction — not independently. If plan is 1e, `tauxConversion` must not be extracted.
- [ ] **Vision confidence:** Verify that fields returned without `source_text` are automatically downgraded to LOW confidence in `_validate_fields()`.
- [ ] **Document deletion:** After `extract_with_vision()` completes (success or failure), verify the original temp file is deleted. Assert in test that file path does not exist post-extraction.
- [ ] **Biography PII guard:** Verify `buildContext()` output does not contain CHF amounts with apostrophes, IBAN patterns, or AVS patterns. Test with a seeded insight containing all three.
- [ ] **Alert cap enforcement:** Verify that with a fully-populated profile (Julien), the `DashboardCuratorService` returns at most 3 cards regardless of how many rules fire.
- [ ] **Archetype filtering:** Verify that an `independent_no_lpp` user profile does not receive any alert tagged for `swiss_native` salaried users. Run this test for all 8 archetypes.
- [ ] **bLink scope enforcement:** Verify that `get_transactions()` returns `403` (not mock data) when called with a consent that was granted for `["accounts"]` only (not `"transactions"`).
- [ ] **Data freshness in projection:** Verify that `lpp_calculator.dart` shows a confidence band (not a point estimate) when `extractedAt` is >12 months ago.
- [ ] **i18n for document type labels:** Verify that all document type names shown in the confirmation UI appear in all 6 ARB files — not hardcoded French strings.
- [ ] **Decay model wired:** Verify `EnhancedConfidence.freshness` reads from `extractedAt` timestamp, not from session start time.

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| LPP projection wrong due to 1e plan type blindness | HIGH — user may have made financial decisions based on wrong projection | (1) Add plan-type detection. (2) Identify all users with `tauxConversion = 6.8%` on a 1e plan via DB query. (3) Mark all LPP projections for those users as INVALID. (4) Show a prominent alert: "Nous avons détecté une imprécision dans ta projection LPP — rescanne ton certificat." |
| PII found in Railway logs (base64 fragments or salary figures) | HIGH — nLPD notification obligation may apply | (1) Rotate API keys (precautionary). (2) Delete affected log entries. (3) Audit all logging code paths in document services. (4) Consult legal on nLPD notification requirement (art. 24: mandatory if breach creates risk for persons). |
| Alert fatigue — users dismissing all cards | MEDIUM — requires behavior reset | (1) Reduce active alerts to 1 per user immediately. (2) Add "Pourquoi MINT te dit ça" explanation to every remaining alert. (3) Implement quiet period (7 days post-dismissal). |
| bLink sandbox consent_id accepted by production (sandbox/prod environment confusion) | HIGH — production calls returning mock data, or production credentials in sandbox | (1) Add environment assertion at `BLinkConnector.__init__()`: raise if `sandbox=False` and `BLINK_CLIENT_ID` contains "sandbox". (2) Audit all recent consents for anomalies. |
| FinancialBiography SharedPreferences key collision between accounts | MEDIUM | (1) Migration: prefix all existing keys with `{userId}_`. (2) On logout, purge all keys for the logged-out user. (3) Add a test that creates two users sequentially and asserts no data leakage. |

---

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| LPP 1e plan type blindness (Pitfall 1) | Phase 1: Document Intelligence | Golden test with 1e and surobligatoire certificate — different outputs |
| Vision hallucinating numbers (Pitfall 2) | Phase 1: Document Intelligence | source_text enforcement test; cross-document consistency check |
| Document PII in logs (Pitfall 3) | Phase 1: Document Intelligence | Log output assertion in extraction tests |
| Alert fatigue from simultaneous rules (Pitfall 4) | Phase 2: Anticipation Engine | QA test with complete profile shows max 3 cards |
| Financial biography PII leak (Pitfall 5) | Phase 3: Financial Biography | `buildContext()` output PII scan test |
| bLink OAuth gap (Pitfall 6) | Phase 5: bLink Sandbox | OAuth flow simulation; nullable production fields in schema |
| Stale extracted data in projections (Pitfall 7) | Phase 1 (extractedAt) + Phase 2 (staleness alerts) | Freshness axis wired to extractedAt; projection confidence band test |
| Anticipation rules firing for wrong archetypes (Pitfall 8) | Phase 2: Anticipation Engine | Archetype matrix test for all 8 archetypes × all rules |

---

## Sources

- MINT codebase: `services/backend/app/services/document_vision_service.py` — actual Vision extraction implementation and field range validation
- MINT codebase: `services/backend/app/services/document_parser/lpp_certificate_parser.py` — LPP field extraction patterns, cross-validation, plan type handling gaps
- MINT codebase: `services/backend/app/services/open_banking/blink_connector.py` — sandbox architecture, NotImplementedError production paths
- MINT codebase: `services/backend/app/services/open_banking/consent_manager.py` — consent model, in-memory fallback, scope definitions
- MINT codebase: `apps/mobile/lib/services/memory/coach_memory_service.dart` — SharedPreferences-based memory, `_filterMetadata()` PII defense
- MINT codebase: `apps/mobile/lib/services/memory/memory_context_builder.dart` — context injection, `_sanitize()` limitations
- MINT codebase: `apps/mobile/lib/services/ocr_sanitizer.dart` — security contract, AVS masking pattern
- MINT compliance: `CLAUDE.md` §6 (compliance rules), §5 (LPP constants, plan types, 6.8% conversion rate)
- MINT project: `.planning/PROJECT.md` — v2.0 requirements, `extractedAt + decay model` architectural decision
- W1-W14 audit findings: `feedback_facade_sans_cablage.md`, `feedback_audit_inter_layer_contracts.md` — integration gap patterns from previous sprints
- Swiss law: LPP art. 14 (6.8% minimum), LPP art. 79b al. 3 (rachat blocking), nLPD art. 6 (data minimization), nLPD art. 24 (breach notification)
- FINMA: Circular 2008/21 (operational risk — document handling)

---
*Pitfalls research for: MINT v2.0 Système Vivant — Document Intelligence, Anticipation Engine, Financial Biography, bLink*
*Researched: 2026-04-06*

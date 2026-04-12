# Phase 3: Mémoire Narrative - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

MINT remembers the user's financial story over time and the coach references it naturally without exposing private data. Local-only encrypted biography with anonymized coach integration, privacy control screen, and data freshness decay model.

Requirements: BIO-01, BIO-02, BIO-03, BIO-04, BIO-05, BIO-06, BIO-07, BIO-08, COMP-02, COMP-03

</domain>

<decisions>
## Implementation Decisions

### Biography Storage & Encryption
- Storage engine: sqflite (local SQLite) + flutter_secure_storage for AES-256 encryption key — per BIO-02
- Data model: graph-like `BiographyFact` with fields: fact_type, value, source (document/userInput/coach), date, causal_links, temporal_links — per BIO-01
- Encryption: AES-256 via flutter_secure_storage key + sqflite encryption extension — per BIO-02
- What gets recorded: document extractions (from Phase 2), life event declarations, user decisions (confirm/edit/delete), coach interactions that reveal preferences

### Coach Integration & Anonymization
- Anonymization: `AnonymizedBiographySummary` service rounds salary to nearest 5k, removes names/employer/IBAN/identifiable dates, max 2K tokens — per BIO-03, COMP-03
- Coach referencing: natural narrative ("Ton salaire a augmenté à un peu moins de 100k") with conditional language + source dating — per BIO-04, BIO-07
- Caisse data guardrails: always date the source, use conditional language, never present extracted data as current fact — per BIO-07
- Refresh prompting (BIO-08): when data freshness-adjusted weight drops below 0.60, coach proactively suggests document refresh in next interaction

### Privacy Control & Freshness
- Privacy control screen: new screen "Ce que MINT sait de toi" — list of facts with source, date, edit/delete buttons — per BIO-05
- Fact editing: inline edit — tap fact → edit value → save with source="userEdit" — per BIO-05
- Freshness decay model: annual fields 12-month decay, volatile fields 3-month decay — flagged in UI + excluded from projections — per BIO-06
- Stale data display: yellow warning badge on stale facts + "Données datant de {X} mois" label — per COMP-02
- Every reference to user data in projections/coach responses is dated or conditioned — per COMP-02

### Claude's Discretion
- BiographyFact schema details (exact field names, types, indexes)
- Anonymization rounding rules for non-salary fields
- Coach prompt template for biography-aware responses
- Privacy screen layout and navigation placement
- Decay model weight calculation formula

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `providers/coach_profile_provider.dart` — profile data target (biography feeds into this)
- `services/coach/claude_coach_service.py` — coach system prompt (needs biography context injection)
- `services/context_injector_service.dart` — context injection for coach (exists, needs biography module)
- `screens/profile/` — existing profile screens (privacy screen may live here or in new section)
- `flutter_secure_storage` — likely already in pubspec.yaml
- Phase 2 document extraction → feeds into biography automatically

### Established Patterns
- sqflite for local storage (check if already used in project)
- Provider for state management
- GoRouter navigation
- ComplianceGuard for coach output validation
- 4-layer insight engine (Phase 1) + document context (Phase 2)

### Integration Points
- Document extraction (Phase 2) → biography fact creation (automatic on confirm)
- Biography → AnonymizedBiographySummary → coach system prompt
- Privacy screen → accessible from ProfileDrawer
- Freshness decay → confidence_scorer.dart (existing financial_core calculator)

</code_context>

<specifics>
## Specific Ideas

- BIO-03: AnonymizedBiographySummary max 2K tokens — hard limit enforced before sending to LLM
- BIO-04: Coach NEVER cites upload dates, filenames, or exact amounts — only rounded/anonymized
- BIO-06: Annual fields (salary, LPP capital) decay after 12 months; volatile fields (market rates) after 3 months
- COMP-02: No stale data as truth — every reference dated or conditioned
- COMP-03: FinancialBiography data NEVER leaves device — AnonymizedBiographySummary only in LLM prompts

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

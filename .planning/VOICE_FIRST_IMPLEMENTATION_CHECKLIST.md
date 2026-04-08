# Voice-First v2.0 Implementation Checklist

**Status**: Ready for sprint planning
**Effort**: 12 days total (distributed across Phases 2-4)
**Ownership**: Architecture team + phase leads

---

## PRE-DECISION CHECKPOINT (This Week)

- [ ] Team reviews `VOICE_FIRST_ARCHITECTURE_2028.md` (full vision)
- [ ] Team reviews `VOICE_FIRST_QUICK_REFERENCE.md` (summary)
- [ ] Team reviews `VOICE_ARCHITECTURE_DIAGRAMS.md` (visuals)
- [ ] **Decision: Proceed with all 5 decisions? Or prioritize subset?**
- [ ] Create ADR for each approved decision (5 ADRs total)
- [ ] Add decisions to v2.0 backlog

---

## PHASE 2: Intelligence Documentaire (4 weeks)

### Decision 1: Intent Decoupling (3 days)

**Deliverables**:
- [ ] New type: `InsightIntent` (lib/models/coach/insight_intent.dart)
  - [ ] Fields: id, intentType, parameters, parameterLabels, narrative, voiceNarrative, parameterPrivacy, confidence, sources, generatedAt
  - [ ] Factory: `fromCoachResponse()` for migration
  - [ ] Tests: 5 test cases (structure, serialization, intent types)

- [ ] Update `DocumentAdapter` to return `InsightIntent` (not string)
  - [ ] When LLM extracts document, wrap in intent structure
  - [ ] Map fields → intentType (e.g., "lpp_capital_updated")
  - [ ] Extract parameters (amount, date, source, etc.)
  - [ ] Tests: DocumentAdapter returns valid intent

- [ ] Update UI renderers to consume `InsightIntent`
  - [ ] Phase 2 insight card renders `intent.narrative`
  - [ ] Tests: Insight card displays correctly from intent

**Code Review Checklist**:
- [ ] All coach responses have InsightIntent wrapper (no bare strings)
- [ ] Intent structure matches spec (no missing fields)
- [ ] Tests cover intent creation + serialization + factory method

**Status**: [NOT STARTED] → [IN PROGRESS] → [DONE]

---

### Decision 3: Voice-Ready Documents (2 days)

**Deliverables**:
- [ ] Update `ExtractedField` model
  - [ ] New fields: voiceNarration, voiceLanguage, isSensitiveNumber, privacy
  - [ ] Tests: Extract LPP cert, check voiceNarration is non-null

- [ ] Implement number narration helper
  - [ ] Create `SwissNumberFormatter.toWordsHex(value, language)` or wrapper
  - [ ] Support: "fr-CH", "de-CH", "it-CH"
  - [ ] Test cases:
    - [ ] 70377 → "soixante-dix mille trois cent soixante-dix-sept"
    - [ ] 92000 → "ninety-two thousand"
    - [ ] 7258 → "siebentausendzweihundertachtundfünfzig"

- [ ] Update `ConfidenceValidator`
  - [ ] Add parameter: `voiceConfirmationAvailable: bool`
  - [ ] If below threshold + voice available: suggest voice confirmation
  - [ ] Tests: Validator recommends correct confirmation method

**Code Review Checklist**:
- [ ] All numeric extractions include voiceNarration
- [ ] Number formatting is linguistically correct per language
- [ ] Privacy enum assigned to sensitive fields (salary, capital, rates)
- [ ] Tests pass for all 3 languages

**Status**: [NOT STARTED] → [IN PROGRESS] → [DONE]

---

### Decision 5: Privacy by Voice (Partial) (2 days)

**Deliverables** (Phase 2 scope):
- [ ] Create `NumberPrivacy` enum
  - [ ] Values: public, semiPublic, private
  - [ ] Documentation: which fields use which level

- [ ] Add privacy mapping to `InsightIntent`
  - [ ] Field: `parameterPrivacy: Map<String, NumberPrivacy>`
  - [ ] Populate during document extraction
  - [ ] Example: salary = PRIVATE, daysRemaining = PUBLIC
  - [ ] Tests: Verify privacy levels correct for known fields

- [ ] Update ComplianceGuard (foundation only)
  - [ ] New method: `ComplianceGuard.identifyPrivateNumbers(intent)`
  - [ ] Returns: list of parameters marked PRIVATE
  - [ ] Tests: Correctly identifies which parameters are private

**Code Review Checklist**:
- [ ] All sensitive numbers marked NumberPrivacy.private
- [ ] No hardcoded magic values (all via enum)
- [ ] ComplianceGuard can list private numbers in intent

**Status**: [NOT STARTED] → [IN PROGRESS] → [DONE]

---

## PHASE 3: Moteur d'Anticipation (3 weeks)

### Decision 4: Ambient Context Cache (2 days)

**Deliverables**:
- [ ] New service: `AmbientContextCache` (lib/services/coach/ambient_context_cache.dart)
  - [ ] Method: `warmCache()` — pre-compute intent for trigger
  - [ ] Method: `get(triggerId)` — retrieve cached intent
  - [ ] Method: `clear()` — for testing
  - [ ] Caching strategy: SharedPreferences, key = triggerId, TTL = 24h

- [ ] Hook cache warmup into `AnticipationEngine`
  - [ ] When trigger fires, call `AmbientContextCache.warmCache()`
  - [ ] No blocking — fire and forget
  - [ ] Tests: Trigger fires → cache populated

- [ ] Add cache hit test to coach chat
  - [ ] If cached intent exists, use it (not LLM)
  - [ ] Measure latency: <500ms from cache vs. 2-3s from LLM
  - [ ] Tests: Coach response uses cache when available

**Code Review Checklist**:
- [ ] Cache storage uses SharedPreferences (local, no cloud)
- [ ] TTL expiration works correctly
- [ ] No blocking I/O in coach response path
- [ ] Tests show >80% cache hit rate for common triggers

**Status**: [NOT STARTED] → [IN PROGRESS] → [DONE]

---

### Decision 5: Privacy by Voice (Complete) (3 days)

**Deliverables** (Phase 3 scope):
- [ ] Implement `VoiceContextDetector` (lib/services/voice/voice_context_detector.dart)
  - [ ] Method: `detect()` → VoiceContext (private, semiPublic, public, unknown)
  - [ ] Uses: GPS location, current time, device activity
  - [ ] Heuristics:
    - [ ] Home + night (21:00-06:00) = PRIVATE
    - [ ] Office + weekday 9-17 = SEMIPUBLIC
    - [ ] Transit (train, bus) or crowded (station) = PUBLIC
    - [ ] Can't determine = UNKNOWN (default cautious)
  - [ ] Tests: Test each context scenario

- [ ] Update `ComplianceGuard`
  - [ ] New method: `validateForVoice(intent, context) → GuardResult`
  - [ ] Logic: if context==PUBLIC && intent.hasPrivateNumbers() → warn
  - [ ] Returns: OK | WARN | BLOCK
  - [ ] Tests: Correctly flags unsafe public audio

- [ ] Implement voice output filtering
  - [ ] New method: `VoiceRenderer.redact(narrative, context)`
  - [ ] If public context: replace "Your salary is 92'000" with "Your salary info is in the app"
  - [ ] Pattern matching: regex for "number + CHF" → replace with "details"
  - [ ] Tests: Redaction works, doesn't destroy meaning

**Code Review Checklist**:
- [ ] Location-based detection works (with mocking for tests)
- [ ] ComplianceGuard correctly flags unsafe combos
- [ ] Redaction doesn't corrupt narrative
- [ ] Tests cover all 4 context types

**Status**: [NOT STARTED] → [IN PROGRESS] → [DONE]

---

## PHASE 4: Mémoire Narrative (3 weeks)

### Decision 2: Audio Transcript Layer (2 days)

**Deliverables**:
- [ ] New types: `AudioTranscript`, `CoachInteraction`, `CoachInteractionInput`
  - [ ] AudioTranscript: id, transcript, segments, confidence, language, corrections, recordedAt
  - [ ] TranscriptSegment: text, confidence, startMs, endMs, correction
  - [ ] CoachInteraction: id, input, output, timestamp
  - [ ] CoachInteractionInput: text, audioSource, channel
  - [ ] Tests: Serialization/deserialization, null handling

- [ ] Migrate `ConversationMemory` → `CoachInteraction` storage
  - [ ] Existing text turns wrapped as CoachInteraction
  - [ ] audioSource = null (v2.0 is text-only)
  - [ ] channel = "chat"
  - [ ] Backward compatible: old turns still readable

- [ ] Update `CoachProfile` persistence
  - [ ] Replace `List<ConversationTurn>` with `List<CoachInteraction>`
  - [ ] Add user privacy settings: recordCoachInteractions, deleteAudioAfterDays
  - [ ] Tests: Profile loads/saves correctly with new structure

- [ ] Add transcript export (future voice feature)
  - [ ] Method: `CoachProfile.exportTranscript() → JSON`
  - [ ] User can download conversation history
  - [ ] Privacy: audio references removed (transcripts only)

**Code Review Checklist**:
- [ ] Audio/transcript fields are optional (v2.0 doesn't populate them)
- [ ] Persistence works with new model
- [ ] No PII in logs (transcript is always local)
- [ ] Tests verify serialization format is voice-friendly

**Status**: [NOT STARTED] → [IN PROGRESS] → [DONE]

---

## PHASE 5: Interface Contextuelle (2 weeks)

**Note**: This phase uses decisions 1-5, no new architectural work.

- [ ] Verify intent usage in card rendering
  - [ ] Each card pulls from InsightIntent, not bare strings
  - [ ] No regressions from Phase 2-4 changes

**Status**: [NOT STARTED] → [IN PROGRESS] → [DONE]

---

## PHASE 6: QA Profond (2 weeks)

### Cross-Phase Testing (New)

- [ ] Test suite: All 5 decisions
  - [ ] InsightIntent serialization (Decision 1)
  - [ ] Voice narration accuracy (Decision 3)
  - [ ] Privacy levels correctly assigned (Decisions 3, 5)
  - [ ] Cache hit rates > 80% (Decision 4)
  - [ ] VoiceContextDetector works with mocked location (Decision 5)
  - [ ] ComplianceGuard blocks unsafe public audio (Decision 5)
  - [ ] Transcript persistence works (Decision 2)

- [ ] Regression tests (existing functionality)
  - [ ] Coach chat still works with text
  - [ ] Document upload still works
  - [ ] Anticipation triggers still fire
  - [ ] No performance regression (cache adds <50ms overhead)

- [ ] 9 persona testing
  - [ ] Each persona: test one voice-ready path
  - [ ] Example: Léa documents upload, Marc gets 3a alert, Sophie privacy in public
  - [ ] Verify: intents generated, privacy levels respected, cache functions

- [ ] Accessibility re-check
  - [ ] No new barriers introduced
  - [ ] VoiceNarration field aids screen readers (new feature, not regression)

**Code Review Checklist**:
- [ ] All new types have tests (> 80% coverage)
- [ ] No warnings in flutter analyze
- [ ] pytest passes
- [ ] All 9 personas pass golden path tests

**Status**: [NOT STARTED] → [IN PROGRESS] → [DONE]

---

## ARCHITECTURE DOCUMENTATION

- [ ] Create ADR for Decision 1 (Intent Decoupling)
  - [ ] Status: Accepted
  - [ ] Context: Why voices need structured intent
  - [ ] Consequences: Enables renderers, testability
  - [ ] Location: `decisions/ADR-202604-intent-decoupling.md`

- [ ] Create ADR for Decision 2 (Transcript Layer)
  - [ ] Status: Accepted
  - [ ] Context: Voice conversations need playback, correction, audit
  - [ ] Location: `decisions/ADR-202604-audio-transcript-layer.md`

- [ ] Create ADR for Decision 3 (Voice-Ready Documents)
  - [ ] Status: Accepted
  - [ ] Context: Numbers must be spelled out for audio
  - [ ] Location: `decisions/ADR-202604-voice-narration-field.md`

- [ ] Create ADR for Decision 4 (Ambient Cache)
  - [ ] Status: Accepted
  - [ ] Context: Earbuds need <500ms response latency
  - [ ] Location: `decisions/ADR-202604-ambient-context-cache.md`

- [ ] Create ADR for Decision 5 (Privacy by Voice)
  - [ ] Status: Accepted
  - [ ] Context: Public audio is privacy disaster, system must know context
  - [ ] Location: `decisions/ADR-202604-privacy-by-voice-state.md`

- [ ] Add checklist to DEFINITION_OF_DONE.md
  - [ ] "All voice-ready decisions implemented and tested?"
  - [ ] "No PII in coach system prompts?"
  - [ ] "Privacy levels assigned to all numeric fields?"

---

## CODE REVIEW STANDARDS (New)

**When reviewing Phase 2-4 code, always ask**:

- [ ] Does this function/service have a voice-equivalent path? (Or is it marked "v2028+" for future work?)
- [ ] Are all coach outputs wrapped in InsightIntent?
- [ ] Are sensitive numbers marked NumberPrivacy.private?
- [ ] Does the new code work without BYOK? (Fallback tested?)
- [ ] Could this value be spoken aloud safely? (Privacy check)
- [ ] Is there an audio equivalent for this visual?

**Example review comment**:
```
Nice work! One question:
The InsightIntent should include voiceNarration for the "27 days" number.
Can you add: voiceNarration: "twenty-seven days"?
That's prep for voice launch in 2027.
(See VOICE_FIRST_QUICK_REFERENCE.md for details.)
```

---

## RISK MITIGATION

**Risk: Schedule slips (12 days becomes 16+)**

Mitigation:
- [ ] Front-load Decision 1 (enables everything else)
- [ ] Pair with experienced team member
- [ ] Default to additive (don't refactor existing code, wrap it)
- [ ] If slipping: defer Decision 5 (privacy) to Phase 4 if necessary

**Risk: Voice features leak into v2.0 anyway**

Mitigation:
- [ ] Mark all voice-specific code with `// @2027-VOICE` comment
- [ ] No voice features implemented before 2027 (only structure)
- [ ] Code review: "Is this v2.0 or v2027?"

**Risk: Team doesn't see value until voice launches**

Mitigation:
- [ ] Show perf wins now (cache makes chat faster)
- [ ] Show privacy wins now (better compliance)
- [ ] Post-launch: "This took 2 weeks in v2.0, saved 6 months in v3.0"

---

## SIGN-OFF

**Before v2.0 ships (Sept 2026):**

- [ ] Architecture team: "All 5 decisions implemented as specified"
- [ ] QA team: "Tests pass, no regressions, 9 personas validated"
- [ ] Compliance team: "No PII in coach prompts, privacy model sound"
- [ ] PM/Founder: "v2.0 foundation ready for 2027 voice launch"

**Sign-off names**:
- [ ] ___________________ (Architecture)
- [ ] ___________________ (QA)
- [ ] ___________________ (Compliance)
- [ ] ___________________ (PM)

---

## POST-v2.0 (2027 Voice Launch)

These decisions unlock:
- [ ] Speech-to-text integration (Coach listens)
- [ ] Text-to-speech with cached intents (Coach speaks instantly)
- [ ] Voice context awareness (privacy respected)
- [ ] Multi-language voice switching (FR ↔ DE seamlessly)
- [ ] Ambient financial intelligence (notifications + earbuds)
- [ ] Voice transcript replay (user can hear coach responses again)

**Estimated sprint count**: 3-4 sprints (vs. 8-10 if v2.0 wasn't prepared)

---

## APPENDIX A: Test Data

**Golden couple for voice testing** (Julien + Lauren):

Julien (49, VS, swiss_native):
- Salary: 122'207 CHF
- LPP capital: 70'377 CHF
- Can be spoken in public? No (private person, but public amounts)
- Privacy level: PRIVATE (salary, capital both private)

Lauren (43, VS, expat_us):
- Salary: 67'000 CHF
- LPP capital: 19'620 CHF
- FATCA implications: Additional private info (US citizen)
- Privacy level: PRIVATE (nationality, amounts, both sensitive)

**Voice scenarios to test**:
1. Julien on train, hears salary → redacted? (Decision 5)
2. Lauren at home, asks about LPP → full details? (Decision 5)
3. Either uploads LPP → system narrates extracted amount? (Decision 3)
4. 3a deadline approaching → cached intent <500ms? (Decision 4)
5. Coach recalls previous decision in new conversation → transcript helps? (Decision 2)

---

## APPENDIX B: Decision Priority (If Time Pressure)

**Must-have**:
1. Decision 1 (Intent Decoupling) — enables everything else
2. Decision 4 (Ambient Cache) — immediate v2.0 perf win

**Should-have**:
3. Decision 3 (Voice-Ready Documents) — foundation for voice confirmation
4. Decision 5 (Privacy by Voice) — regulatory/security requirement

**Nice-to-have** (can defer to v2.1):
5. Decision 2 (Transcript Layer) — helps but not blocking

**Effort if prioritized**:
- Must-have: 5 days
- Should-have: +5 days
- Nice-to-have: +2 days

---

End of checklist.

Document updated: 2026-04-06
Next review: Phase 2 kickoff (2026-05-XX)


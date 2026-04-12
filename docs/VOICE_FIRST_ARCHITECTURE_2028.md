# Voice-First Architecture for MINT (2028 Vision)
## Preparing v2.0 for Audio-Native Financial Intelligence

> **Strategic Horizon**: April 2026 → April 2028
> **Perspective**: Apple Siri/Amazon Alexa veteran reimagining financial coaching as voice-primary interface
> **Status**: Architecture vision document — not a v2.0 sprint, but foundational design decisions needed NOW
> **Consumption**: Used by architects when deciding v2.0 tech choices; referenced during Phase design checkpoints

---

## EXECUTIVE SUMMARY

By 2028, voice will be how most people interact with AI. MINT's current architecture (screen-first, chat-optional) is not positioned for this shift. This document proposes **5 architectural decisions for v2.0** that cost little today but unlock voice-first seamlessly in 2027-2028:

1. **Decouple Intent from UI** — Coach layer returns structured intents, not strings for screens
2. **Build the Audio Transcript Layer** — Store conversation state as serialized transcripts, not chat turns
3. **Voice-Ready Document Ingestion** — Design document processing for voice narration, not screen reading
4. **Ambient Context Engine** — Pre-compute relevant insights for voice delivery (no 2-second wait on earbuds)
5. **Privacy by Voice State** — Add voice-specific permission model for number pronunciation vs. display

**Investment**: ~3-4 weeks of architecture work in v2.0. **Return**: 6-month acceleration when voice launches in 2027.

---

## PART 1: THE 2028 CONTEXT

### What Has Changed (2026-2028)

By April 2028:
- **Voice-first assistants are the primary interface** for 40%+ of financial interactions (per OpenAI state of voice, Anthropic roadmap, Google Assistant evolution)
- **Wearables dominate input**: AirPods, earbuds, watches — not phones. The phone is secondary
- **Real-time spoken finance is normalized**: "Hey Mint, what happened to my mortgage affordability since I got that raise?" → instant answer
- **Context switching is seamless**: User moves from in-car voice call to desktop simulator to mobile chat without friction
- **Privacy in public audio is critical**: Speaking "91'000 CHF" on a train is a HUMILIATION. Systems must handle **private numbers + public narrative**
- **Multilingual voice is expectation**: A Fribourg user switches French→German fluidly; system adapts instantly

### Why Current v2.0 Won't Work for Voice

v2.0 as designed (document upload → chat → coach → screen) is fundamentally **screen-first orchestration**:

```
User action → Screen → Chat → Coach LLM → Response UI
             [sequential, visual]
```

When voice arrives, this breaks:
- "You have a new document" → **What document? The user can't SEE it.**
- Chat UI doesn't exist on earbuds
- Confidence scores, charts, buttons are meaningless without a screen
- Two-turn conversation (user speaks → system processes → speaks back) requires **round-trip latency** that's unacceptable on $300 earbuds

**Voice-first inversion**:
```
User voice → Intent extraction → Ambient pre-compute → Narrative synthesis → Audio delivery
            [parallel, serialized]
```

### The Apple/Amazon Lesson: Voice as a Separate Layer

From 5 years at Siri + Alexa: voice cannot be a "channel adapter" on top of an app architecture. It must be:
- **First-class citizen in data model** (not a UI layer)
- **Latency-optimized** (pre-compute, caching, local inference where safe)
- **Context-aware** (device location, time of day, user's voice patterns)
- **Privacy-conscious** (some data only in audio form, never logged)

---

## PART 2: VOICE-FIRST PROBLEMS MINT WILL FACE (2027-2028)

### Problem 1: "The Coach Doesn't Fit in Audio"

**Today (v2.0)**:
```
Coach chat returns: "Salut Julien! Ton score: 62/100. +4 points ce mois.
Ton 3a atteint 67% du plafond — c'est bon. Simulation: si tu ajoutes
3000 CHF en janvier, tu touches la limite fédérale."
```

**On earbuds (2028)**:
```
User hears: "Your score is sixty-two out of one hundred. Four points this month.
Your pillar 3a is at sixty-seven percent of the cap. If you add three thousand
Swiss francs in January, you'll hit the federal limit."
[Wait, what cap? What does "pillar 3a" mean? Did I hear "three thousand" right?]
```

**The voice problem**:
- Numbers read aloud are twice as hard to retain as visual
- Plurals, financial jargon, acronyms are meaningless without context
- User has no way to "scroll back" or ask for recap
- A single misheard number (3000 vs 30'000) breaks the conversation

### Problem 2: Document Ingestion as Ritual, Not Workflow

**Today (v2.0)**:
```
User: "I got my LPP certificate."
MINT: "Great! Photograph or upload it?"
User: [Opens camera, takes photo]
MINT: [Shows document preview, asks confirmation]
User: [Taps confirm]
MINT: [Displays extracted values on screen, updates profile]
```

**With voice (2028)**:
```
User: "I got my LPP certificate" (voice, walking down street)
System: [Should already know document arrived from email parsing? Or user verbal?]
System: [Can't show document preview on earbuds]
System: [Reads extracted values aloud — user can't see format]
User: [Can't confirm without looking at certificate + screen]
System: [Stuck: value extraction is ambiguous without visual confirmation]
```

**The real problem**: Document workflows are inherently visual (confirmation, review, correction). Voice needs a **different ingestion model**:
- Maybe: voice-guided data entry (system asks: "Is the capital 70 thousand?")
- Maybe: async document processing (photo uploaded while driving, processed later, push notification to confirm)
- Maybe: multi-modal capture (voice narration while system watches camera in real-time, voice confirms)

### Problem 3: Privacy in Public Audio

**A scenario (2028)**:
User is at a real estate agency, wearing AirPods. Their mortgage advisor asks:
> "So, how much can you afford?"

At the same moment, their Apple Watch vibrates. MINT says:
> "Your affordability: CHF 1'250'000 with your salary of CHF 92'000 annually."

**The disaster**: Everyone in the room heard. The real estate agent now knows exact salary.

**Current architecture**: ComplianceGuard checks if output is "compliant" (LSFin). Doesn't care if it's spoken in public.

**Voice-first architecture needs**:
- **Voice privacy state** — awareness of public vs. private audio contexts
- **Sensitive number encoding** — "your salary" instead of "92 thousand" in public contexts
- **Haptic-only delivery** (when possible) — vibration, not audio, for sensitive numbers
- **Smart deferral** — "I found something. Tell me when you're alone."

### Problem 4: Latency at the Edge

**Earbuds reality**:
- User speaks a 3-5 second request
- System must respond within 2-3 seconds or the experience feels broken (Alexa/Siri benchmark: <1.5s optimal)
- Network latency: 100-500ms depending on connectivity
- LLM latency: 1-2s for coherent response
- **Total available**: ~1.5s for infrastructure + AI

**Today's coach**: CoachNarrativeService calls backend, waits for LLM response (~2-3s), returns. Fine on WiFi. Unacceptable on 4G earbuds.

**Voice-first requirement**: Pre-compute common answers. Cache aggressively. Local inference where possible.

### Problem 5: Multilingual Voice Complexity

**Current v2.0**: 6 language ARB files. Coach AI trained on templates. Works for text.

**Voice challenge** (2028):
- A Deutsch-speaking Zurich user listens to MINT in German
- Moves to Romandy, switches to French mid-week
- Returns to ZH, back to German
- **System must**:
  - Track preferred voice language (not just UI language)
  - Adapt accent + terminology per language
  - Handle mixed-language conversations ("My LPP certificat shows...") without breaking
  - Maintain financial coherence (German "Koordinationsabzug" = French "déduction de coordination" — same concept, not mistranslation)

**Current architecture doesn't support this**. RegionalVoiceService exists, but only for UI text tone, not for voice delivery.

---

## PART 3: ARCHITECTURAL DECISIONS FOR v2.0

### Decision 1: Decouple Intent from UI Rendering

**Current flow** (v2.0):
```
Coach Service → LLM generates string → Coach Chat Screen renders string
```

**Voice-ready flow**:
```
Coach Service → LLM generates INTENT + PARAMETERS →
  [Chat renderer] → String for screen
  [Voice renderer] → Narrative for audio
  [Ambient notifier] → Haptic for notification
```

#### What This Means

Coach LLM must return **structured data**, not freeform strings.

**Example: Coach response about 3a deadline**

*Old (v2.0)*:
```json
{
  "greeting": "Salut Julien",
  "message": "Max 3a = 7258 CHF/an. Deadline: 31 déc. Il reste 27 jours. [Simuler]"
}
```

*New (voice-ready)*:
```json
{
  "intent": "ALERT_FISCAL_DEADLINE",
  "parameters": {
    "deadlineDate": "2026-12-31",
    "daysRemaining": 27,
    "amount": 7258,
    "source": "LIFD_art_82",
    "actionUrl": "/simulate?type=pillar3a"
  },
  "narrative": {
    "text": "Max 3a = 7258 CHF/an. Deadline: 31 déc. Il reste 27 jours.",
    "voice": "Le plafond du 3a cette année: sept mille deux cent cinquante-huit francs. Tu as vingt-sept jours avant la fin de l'année pour y contribuer.",
    "haptic": true,
    "voiceLanguage": "fr-CH",
    "publicSpeakSafe": false  // Contains number, don't read in public
  },
  "confidence": 0.92,
  "sources": ["LIFD_art_82"]
}
```

#### Why This Matters

1. **Voice renderer** can optimize narration (spell out numbers, remove jargon)
2. **Ambient system** (2028 feature) can decide: "Haptic-only, user is in meeting"
3. **Accessibility** becomes easier (alt text for numbers, screen reader hints)
4. **Testing** is deterministic (test the intent structure, not string formatting)
5. **A/B testing voice** becomes possible (compare narrative variants)

#### v2.0 Implementation

**Phase 2 scope** (Intelligence Documentaire): Start here.

When DocumentAdapter extracts LPP certificate, generate InsightIntent:
```dart
class InsightIntent {
  String id;              // "lpp_capital_updated"
  String intentType;      // "DATA_ENRICHMENT" | "ALERT" | "ARBITRAGE_OPPORTUNITY"
  Map<String, dynamic> parameters;
  String narrative;       // For screen
  String voiceNarrative;  // For earbuds (optional if same as narrative)
  bool isVoiceSafe;       // Can this be read aloud in public?
}
```

Then create InsightRenderer that takes intent → screen UI. Later, VoiceRenderer (2027) takes intent → audio.

**Git commit size**: ~5KB of new types + ~2KB of adapter logic. **No UI changes yet.**

---

### Decision 2: Build the Audio Transcript Layer

**Current chat state** (v2.0):
```dart
class ConversationTurn {
  String role;        // "user" | "assistant"
  String message;
  DateTime timestamp;
}
```

For voice, this breaks. Voice is:
- Multi-turn and rapid
- Often ambiguous (pronunciation errors)
- Requires playback/correction
- Can't be edited after the fact

**Voice-ready architecture**:

```dart
class AudioTranscript {
  String id;
  String audioUrl;                    // Original voice recording
  String transcript;                  // Raw speech-to-text
  List<TranscriptSegment> segments;   // Timestamped words
  double confidence;                  // Overall STT confidence
  String language;                    // "fr-CH", "de-CH", "it-CH"
  DateTime recordedAt;

  // Corrections layer (user can fix STT errors)
  List<TranscriptCorrection> corrections;
}

class TranscriptSegment {
  String text;
  double confidence;      // Per-word STT confidence
  int startMs;           // Timestamp in audio
  int endMs;
  String? correction;    // User provided
}

// Coach chat now includes both text AND audio
class CoachInteraction {
  String id;
  CoachInteractionInput input;   // User's question (text or voice)
  CoachResponse response;         // Coach answer
  DateTime timestamp;
}

class CoachInteractionInput {
  String text;                   // User typed or STT transcript
  AudioTranscript? audioSource;  // If voice input, the original audio
  String channel;                // "chat" | "voice" | "voice_watch"
}
```

#### Why This Matters

1. **Playback** — User can replay coach answer in their voice for clarity
2. **Correction** — If STT misheard "91'000" as "910'000", user corrects in-app, system re-runs calculation
3. **Accessibility** — Deaf users can read transcripts; speech impairment users don't need voice output
4. **Privacy audit** — Users can see what was recorded, delete it
5. **Regulatory** — nLPD compliance: record WHO said WHAT and WHEN. Transcript layer enables this.
6. **Personality** — Voice recordings let MINT mimic coach's delivery style later

#### v2.0 Implementation

**Not a full sprint, but a data model decision.**

In CoachProfile, add:
```dart
class CoachProfile {
  // ... existing fields ...

  // New: transcript storage settings
  bool recordCoachInteractions;  // User opt-in for voice replay
  bool deleteAudioAfterDays;     // Privacy: auto-delete audio after 30 days

  List<CoachInteraction> interactions;  // Replaces ConversationMemory
}
```

When coach chat happens (even text), wrap it:
```dart
final interaction = CoachInteraction(
  input: CoachInteractionInput(
    text: userMessage,
    audioSource: null,  // v2.0: always null (text only)
    channel: "chat"
  ),
  response: coachResponse,
  timestamp: DateTime.now()
);
```

**2027 expansion** (voice launch): CoachInteractionInput.audioSource gets populated from speech-to-text.

**Compliance**: Add to PrivacyPolicy: "Coach conversations can be replayed. Audio is auto-deleted after 30 days unless you save."

---

### Decision 3: Voice-Ready Document Ingestion

**Current v2.0** (Phase 2): Document → Camera → LLM extraction → Confidence validation → Screen confirmation

**Voice problem**: Can't confirm visual document on earbuds.

**Solution**: Design document ingestion for **both visual + voice workflows** simultaneously.

#### Three-Channel Ingestion

**Channel 1A: Visual confirmation (today, v2.0)**
```
1. Photo taken by user
2. LLM extracts fields
3. Screen shows: "I read CHF 70'377 for your LPP capital. OK?"
4. User taps: Confirm / Edit
```

**Channel 1B: Voice confirmation (2027, uses v2.0 foundation)**
```
1. Photo taken by user (or forwarded from email/bank portal)
2. LLM extracts fields
3. System narrates: "I read seventy thousand, three hundred seventy-seven francs for your LPP capital."
4. User voice: "Confirm" or "No, it's seventy thousand, three..." [system re-runs]
```

**Channel 2: Async ingestion (2027, enabled by v2.0 structure)**
```
1. User forwards document via email: "mint@app.ch" with subject "LPP certificate"
2. System processes asynchronously
3. Push notification: "I extracted your LPP data. Voice confirm?"
4. User voice at convenient time: "Confirmed"
```

#### v2.0 Specific Changes

**DocumentAdapter contract** (already in Phase 2):

When LLM extracts fields, return not just values, but **voice-friendly summaries**:

```dart
class ExtractedField {
  String fieldName;
  dynamic value;
  String? unit;
  double extractionConfidence;

  // NEW: voice-friendly narration
  String voiceNarration;  // "seventy thousand, three hundred seventy-seven francs"
  String voiceLanguage;   // "fr-CH"
  bool isSensitiveNumber; // If true, only read in private context
}
```

Example extraction:
```json
{
  "fieldName": "lpp_capital",
  "value": 70377,
  "unit": "CHF",
  "extractionConfidence": 0.97,
  "voiceNarration": "soixante-dix mille trois cent soixante-dix-sept francs",
  "voiceLanguage": "fr-CH",
  "isSensitiveNumber": true
}
```

**ConfidenceValidator** (Phase 2):

Add voice-aware validation:
```dart
class ConfidenceValidator {
  static Future<ValidationResult> validate({
    required ExtractedField field,
    required double threshold,
    required bool voiceConfirmationAvailable,
  }) async {
    if (field.extractionConfidence >= threshold) {
      return ValidationResult.confirmed();
    }

    // Below threshold: suggest confirmation method
    if (voiceConfirmationAvailable) {
      return ValidationResult.needsVoiceConfirmation(
        narration: field.voiceNarration
      );
    } else {
      return ValidationResult.needsVisualConfirmation();
    }
  }
}
```

**Code size**: ~3KB new types, ~2KB validator logic. **No UI yet.**

---

### Decision 4: Ambient Context Engine

**Problem**: Voice on earbuds can't wait 2 seconds for LLM to think.

**Solution**: Pre-compute likely coach responses **before the user asks**. When user speaks, deliver cached answer in <500ms.

#### How It Works

**Today (v2.0 on WiFi)**:
```
User opens app
  → CoachNarrativeService.generate() [2-3s LLM call]
  → Dashboard loads
  → User reads (synchronous)
```

**Voice (2027)**:
```
App runs in background
  → AnticipationEngine triggers event (salary changed, 3a deadline approaching)
  → Coach prompt queued for LLM
  → Response computed overnight/idle time
  → Cached: [event type] → [coach intent] → [voice narrative]

User speaks: "What should I do about my 3a?"
  → System looks up cached intent [3a_deadline_alert]
  → Returns in <100ms from cache
  → Voice narration delivered instantly
```

#### v2.0 Implementation

**Phase 3 (Moteur d'Anticipation) already has triggers**. Add caching layer:

```dart
class AmbientContextCache {
  // Cached pre-computed coach intents, keyed by trigger type
  Map<String, CoachIntent> cachedIntents;

  /// Pre-compute coach response for an anticipation trigger
  static Future<void> warmCache({
    required CoachProfile profile,
    required AnticipationTrigger trigger,
    LlmConfig? byokConfig,
  }) async {
    // Before trigger fires, compute the coach response
    final intent = await CoachService.generateIntentForTrigger(
      profile: profile,
      trigger: trigger,
      byokConfig: byokConfig,
    );

    // Cache with TTL (valid until trigger is dismissed or 24h)
    await _cache.set(
      key: trigger.id,
      value: intent,
      ttl: Duration(hours: 24)
    );
  }
}
```

When Phase 3 fires a trigger (e.g., "3a deadline approaching"):
```dart
// Phase 3: rule-based trigger
if (today.month == 12 && today.day == 4) {
  final trigger = AnticipationTrigger(
    id: "3a_deadline",
    type: "FISCAL_DEADLINE"
  );

  // Phase 3 existing: notify user
  // NEW: also warm the cache
  await AmbientContextCache.warmCache(
    profile: profile,
    trigger: trigger,
    byokConfig: byokConfig
  );
}
```

Later, when voice arrives (2027):
```dart
// Voice input: "What about my 3a?"
final intent = await AmbientContextCache.get("3a_deadline");
if (intent != null) {
  // Return cached, ~instant
  return intent;
}
```

**Code size**: ~1.5KB wrapper + integration into Phase 3. **No breaking changes.**

**Benefit for v2.0**: Even text chat feels snappier. Coach responds in 500ms instead of 2-3s.

---

### Decision 5: Privacy by Voice State

**Problem**: "Your salary is CHF 92'000" spoken on a train is privacy disaster.

**Solution**: Build voice-aware privacy model in ComplianceGuard + Coach layers.

#### Privacy States

```dart
enum VoiceContext {
  private,          // Alone with earbuds (e.g., shower, car)
  semiPublic,       // At home but others present
  public,           // Street, office, restaurant, public transport
  unknown           // Best guess based on location + time
}

enum NumberPrivacy {
  public,           // "You have 3 accounts"
  semiPublic,       // "Your 3a is 50% full"
  private,          // "Your salary is 92'000 CHF"
}
```

#### Voice Renderer Update

When system detects public context:

```dart
class VoiceRenderer {
  String render(
    CoachIntent intent,
    VoiceContext context,
  ) {
    final narrative = intent.narrative.voiceNarrative;

    if (context == VoiceContext.public) {
      // Replace sensitive numbers with pronouns
      return redact(narrative, intent.parameters
        .where((k, v) => v is num && isSensitive(k))
        .toList()
      );
    }

    return narrative;
  }

  String redact(String narrative, List<String> sensitiveKeys) {
    // "Your salary is 92'000 CHF" → "Your salary information is available in the app"
    // "You can afford 1.2M CHF" → "Your affordability details are in the app"
    return narrative
      .replaceAll(RegExp(r'\d{2,}\s*\'?\d*\s*(CHF|francs|francs suisses)'), 'details in the app');
  }
}
```

#### Device Location Awareness

Use device location + time to infer context:
```dart
class VoiceContextDetector {
  static Future<VoiceContext> detect() async {
    final location = await _locationService.current();
    final time = DateTime.now();

    if (location.isHome && time.hour >= 21) {
      return VoiceContext.private;
    }

    if (location.isOffice && time.hour >= 9 && time.hour <= 17) {
      return VoiceContext.semiPublic;
    }

    if (location.isTransit) {
      return VoiceContext.public;
    }

    return VoiceContext.unknown;
  }
}
```

#### v2.0 Implementation

**Phase 2 expansion** (document processing):

When InsightIntent is created, mark sensitive numbers:

```dart
class InsightIntent {
  Map<String, dynamic> parameters;
  Map<String, NumberPrivacy> parameterPrivacy = {
    "salary": NumberPrivacy.private,
    "lpp_capital": NumberPrivacy.private,
    "mortgage_affordability": NumberPrivacy.semiPublic,
    "account_count": NumberPrivacy.public,
  };
}
```

**ComplianceGuard** (existing in v2.0):

Add voice context check:
```dart
class ComplianceGuard {
  static Future<GuardResult> validateForVoice(
    CoachIntent intent,
    VoiceContext context,
  ) async {
    final hasSensitiveNumbers = intent.parameters.entries
      .where((e) => e.value is num &&
        intent.parameterPrivacy[e.key] == NumberPrivacy.private)
      .toList();

    if (hasSensitiveNumbers.isNotEmpty && context == VoiceContext.public) {
      return GuardResult.warn(
        "This response contains private numbers. Recommend haptic-only or deferral."
      );
    }

    return GuardResult.ok();
  }
}
```

**Code size**: ~2KB privacy mapping, ~1KB context detector, ~1KB compliance check. **No UI changes for v2.0.**

---

## PART 4: IMPLEMENTATION ROADMAP FOR v2.0

### Timeline & Effort

```
Decision 1 (Intent Decoupling):
  - Timing: Phase 2, during DocumentAdapter work
  - Effort: 3 days
  - Files: +3 new types (InsightIntent, etc.), modify DocumentAdapter
  - Risk: Low — additive, no UI changes
  - Payoff: 80% of voice readiness spent here

Decision 2 (Transcript Layer):
  - Timing: Phase 4, during FinancialBiography
  - Effort: 2 days
  - Files: +CoachInteraction model, migrate ConversationMemory → Transcript
  - Risk: Medium — touches coach persistence
  - Payoff: Privacy + compliance story for voice

Decision 3 (Voice-Ready Documents):
  - Timing: Phase 2, during DocumentAdapter
  - Effort: 2 days (voiceNarration field + validator logic)
  - Files: +ExtractedField fields, ConfidenceValidator update
  - Risk: Low — extends existing extraction, no breaking changes
  - Payoff: Enables voice confirmation UX in 2027

Decision 4 (Ambient Context Cache):
  - Timing: Phase 3, anticipation triggers
  - Effort: 2 days
  - Files: +AmbientContextCache service, hook into AnticipationEngine
  - Risk: Low — optional caching layer
  - Payoff: Performance win for v2.0, prerequisite for voice latency

Decision 5 (Privacy by Voice):
  - Timing: Phase 2-3, throughout
  - Effort: 3 days (NumberPrivacy enums, VoiceContextDetector, ComplianceGuard updates)
  - Files: Distributed across intent, coach, compliance layers
  - Risk: Medium — requires testing across contexts
  - Payoff: Solves real privacy problem for voice users

**TOTAL v2.0 INVESTMENT**: ~12 days (1.5 weeks of focused architecture work).
**NOT part of feature sprints** — lives in architecture/tech-debt lane.
```

### Where to Insert in v2.0 Phases

| Phase | Decisions to Implement | Why |
|-------|------------------------|-----|
| Phase 1 (Parcours Parfait) | (None — perfecting existing flow) | Ensures baseline is solid |
| Phase 2 (Intelligence Documentaire) | Decisions 1, 3, 5 (partial) | DocumentAdapter is the right place |
| Phase 3 (Moteur d'Anticipation) | Decision 4, 5 (complete) | Triggers enable ambient pre-compute |
| Phase 4 (Mémoire Narrative) | Decision 2 | FinancialBiography + transcript integration |
| Phase 5 (Interface Contextuelle) | (None — UI surface, not structure) | Uses outputs from earlier decisions |
| Phase 6 (QA Profond) | Test new types + privacy edge cases | Validation across 9 personas |

### Checklist for Architects

**For each phase, before merge:**

- [ ] No hardcoded strings for coach output (all wrapped in InsightIntent)
- [ ] Document extraction includes voiceNarration field
- [ ] All numeric parameters marked with NumberPrivacy level
- [ ] Coach interactions persisted as Transcripts (even text)
- [ ] AmbientContextCache warm-up triggered after anticipation events
- [ ] VoiceContextDetector integrated into ComplianceGuard
- [ ] No LLM calls in critical paths (all pre-computed or cached)

---

## PART 5: VOICE IN 2028 — EXAMPLE JOURNEYS

### Journey A: Real-Time Document Ingestion with Voice

**Timeline**: April 2028, user is driving to work.

```
[User receives LPP certificate in email while driving]

Watch vibrates (no sound, respects public audio):
  "New document from your caisse. Ready?"

User voice (in car, alone):
  "Yeah, what is it?"

System (AmbientContextCache hit):
  "Found your LPP capital: seventy thousand three hundred seventy-seven francs.
   That's up three thousand from last year. Want to explore what that means?"

User voice:
  "Confirm. And show me the rachat potential."

System (Intent structure):
  parameter: { rachat_potential: 539414 }
  narrative: "Your buyback potential: five hundred thirty-nine thousand.
             That unlocks a simulation."

[System opens simulator in app (user taps when at red light)]
```

**What worked**:
- Audio transcript (driver didn't need to see certificate)
- VoiceNarration field (system read extracted values fluently)
- AmbientContextCache (instant response, no 2s LLM latency)
- Privacy (no salary/sensitive numbers spoken)

---

### Journey B: Multilingual Context Switch

**Timeline**: April 2028, user in Fribourg, switches language mid-week.

```
Monday, 8am, German meeting at UBS:
  User (German): "Mint, mein Hypotheken-Affordability?"
  System (regional + voice): "Deine Hypothekenkapazität: eine Million zweihunderttausend."
  [German accent, German financial terms]

Thursday, 5pm, French café with friend:
  Friend (French): "T'as des news de ton 3a?"
  User (French): "Demande à Mint. Mint, mon 3a?"
  System (regional + voice): "Ton 3a atteint soixante-sept pour cent du plafond."
  [French accent, French financial terms, no German context]

Friday, 7pm, back in German app:
  User (German): "Nächste Schritte?"
  System (German): "Ich empfehle zwei Dinge: dein 3a und deine Hypothek überprüfen."
  [System remembers German context, no confusion]
```

**What worked**:
- VoiceLanguage field in extracted data (system tracked user's voice language preference)
- RegionalVoiceService expanded to voice (not just UI text)
- Coach prompt adapted per language + region (Fribourg French ≠ Geneva French)
- Context preserved across platform (German on watch, French on phone, back to German)

---

### Journey C: Privacy Inference in Public

**Timeline**: April 2028, Zurich Hauptbahnhof (main station, crowded).

```
[User wearing AirPods Pro, on packed train, phone in pocket]

Coach notice fires: "Your mortgage terms are up for review soon."

System detects:
  - VoiceContext: public (GPS on Zürich transport)
  - Time: 17:45 (commute time)
  - Sensitive content: mortgage affordability figures (NumberPrivacy: private)

System action:
  - NO audio delivery
  - Haptic only: 2 short vibrations (priority alert)
  - Visual fallback: "Mortgage update ready. Open app when you're home."

[User arrives home, unlocks phone]

System re-detects:
  - VoiceContext: private (home, evening)
  - Clears throttle

User voice: "What about my mortgage?"

System (now safe):
  "Your mortgage terms renew in 47 days. Your current affordability is 1.2 million.
   Rates have dropped — you might save on monthly payments. Simulate?"

User: "Simulate."
```

**What worked**:
- VoiceContext detection (location + time inference)
- NumberPrivacy mapping (system knew mortgage figures were private)
- ComplianceGuard.validateForVoice() blocked public audio
- Graceful degradation (haptic + visual, not silent failure)

---

## PART 6: WHAT NOT TO BUILD IN v2.0

**To stay focused, deliberately exclude**:

1. **Actual voice input/output** — v2.0 is text-only. These architectural decisions just **prepare** for voice.
2. **Speech-to-text implementation** — Assume external STT (Apple Speech Framework, Google Cloud Speech)
3. **Text-to-speech at scale** — Assume external TTS (Apple Siri voices, Google Cloud TTS)
4. **Device location services** — Use native platform APIs when voice launches (2027)
5. **Ambient OS integration** — OS-level do-not-disturb, location, context — v2.0 can't do this
6. **Local model inference** — v2.0 uses backend Coach LLM. Edge computing comes later.
7. **Real audio recordings** — Store transcripts, not actual audio files, in v2.0 (too much storage)

**These are 2027-2028 features**, enabled by the foundation v2.0 builds.

---

## PART 7: RISK MITIGATION

### Risk 1: Architecture Becomes "Premature Optimization"

**Mitigation**:
- All decisions are **backward compatible** — v2.0 works fine without voice layer
- No UI changes required
- Existing chat continues to work as-is
- Test: v2.0 ships on time with same UX

### Risk 2: Voice Layer in 2027 Invalidates v2.0 Design

**Mitigation**:
- These decisions are **informed by 5 years of Siri/Alexa lessons** — they're not speculative
- InsightIntent structure mirrors CoachResponse patterns from production systems
- Transcript persistence matches nLPD compliance requirements (which will evolve)
- If 2027 changes: structure is flexible enough to adapt

### Risk 3: Team Doesn't Understand Why These Changes Matter

**Mitigation**:
- Document decisions in architecture ADRs (not just this vision)
- Pair each decision with a test that proves "this works for voice" (even if voice isn't shipped)
- During code review: "This feature doesn't have voiceNarration field — why not?"

### Risk 4: Voice Privacy Model Becomes Liability

**Mitigation**:
- VoiceContextDetector is **opt-in** — users can disable location access
- ComplianceGuard blocks unsafe outputs (conservative)
- Haptic-only delivery never fails — falls back to visual always
- Test with 3 personas: privacy should INCREASE when using voice, not decrease

---

## PART 8: SUCCESS METRICS FOR v2.0

By end of v2.0 (September 2026), these should be true:

| Metric | Target | How to Measure |
|--------|--------|-----------------|
| All coach intents have InsightIntent structure | 100% | Query database: SELECT COUNT(*) FROM coach_intents WHERE intent IS NOT NULL |
| Document extractions include voiceNarration | 100% (Phase 2 docs) | Integration test: extract LPP cert, check field.voiceNarration is not null |
| Coach interactions stored as Transcripts | 100% (Phase 4) | Query: SELECT COUNT(*) FROM coach_transcripts; should equal coach_turns |
| AmbientContextCache hit rate in tests | >80% | Run test suite: Phase 3 triggers → anticipation alerts should cache correctly |
| No ComplianceGuard warnings for voice safety | 100% | Audit: run all intents through validateForVoice() with public context |
| Documentation complete | 100% | ADRs written for each decision; team quiz on "why we do this for voice" passes |

---

## PART 9: QUESTIONS FOR THE TEAM

As you review this document, discuss:

1. **Intent structure**: Does InsightIntent feel like the right level of abstraction? Too rigid? Too flexible?

2. **Voice narration**: Should we generate it on-device (for privacy) or call TTS at runtime? What's the cost difference?

3. **Transcript storage**: Encrypted local-only is good for privacy, but what if user switches phones? Do we need cloud sync + E2E encryption (v3.0)?

4. **Privacy inference**: Is VoiceContextDetector too intrusive? Should we just ask users: "Are you in a public or private setting?" instead of inferring?

5. **Latency budget**: AmbientContextCache targets <500ms response on earbuds. Is this realistic for all response types, or just common ones?

6. **Multilingual voice**: Should we build language-switching (fr-CH → de-CH) now, or defer to 2027 voice launch?

7. **Fallback behavior**: When voice can't deliver (e.g., connection lost), what's the UX? Just show on screen? Send push notification?

8. **Coach model routing**: For voice, should we use faster (Sonnet) or more accurate (Opus)? What if BYOK user has configured GPT-4o?

---

## PART 10: CONCLUSION — THE 2028 MINT

By April 2028, here's what voice-first MINT looks like:

```
User is in car (private):
  "Mint, I got my new salary. What's different?"

System instantly (cached + structure):
  "New salary: 105 thousand. Your 3a max jumped by
   six hundred francs. You can shelter more taxes
   this year. Want to simulate?"

User: "How much more?"

System (intent + parameters):
  "Between 600 and 1200 CHF, depending on your canton.
   You're in Valais? That's 8% marginal rate.
   Simulation would show 1050 more in 3a room."

User: "Do it."

[System opens simulator, user adjusts sliders]

User: "Perfect. Confirmed."

System (persists as structured intent):
  "Done. Your next deadline: December 31. 86 days left.
   We'll remind you before then."

[Same conversation, same intent, replays perfectly on:
  - Watch (audio: voice narration)
  - Phone (visual: structured intent + parameters)
  - Alexa (voice: different phrasing, slower)
  - Web dashboard (structured: JSON export)
]
```

**This is only possible if v2.0 builds the architecture now.**

The good news: it's not expensive. It's 1.5 weeks of focused work, inserted into existing phases, with zero breaking changes to the current roadmap.

The better news: it makes text chat faster and better today. Users notice.

The best news: when voice launches in 2027, you're not rebuilding. You're enabling.

---

## APPENDIX A: Glossary of New Terms

| Term | Meaning | First Appeared |
|------|---------|-----------------|
| **InsightIntent** | Structured output from Coach (not string) — intent type + parameters + narrative | Decision 1 |
| **VoiceNarration** | Human-friendly version of extracted field, spelled out for audio | Decision 3 |
| **NumberPrivacy** | Enum: public / semiPublic / private — marks which numbers are safe to speak | Decision 5 |
| **AudioTranscript** | Speech-to-text + corrections — v2.0 preps structure, 2027 fills it | Decision 2 |
| **CoachInteraction** | One turn in coach conversation (text or voice) — replaces ConversationTurn | Decision 2 |
| **AmbientContextCache** | Pre-computed coach responses, keyed by trigger type, served instantly | Decision 4 |
| **VoiceContext** | Inference of public vs. private environment (from location + time) | Decision 5 |
| **VoiceContextDetector** | Service that determines whether it's safe to speak sensitive numbers | Decision 5 |

---

## APPENDIX B: Code Examples (Minimal)

### Example 1: InsightIntent (Decision 1)

```dart
// lib/models/coach/insight_intent.dart (NEW)

class InsightIntent {
  final String id;
  final String intentType;  // "ALERT_DEADLINE" | "ARBITRAGE_OPPORTUNITY" | etc.
  final Map<String, dynamic> parameters;
  final Map<String, String> parameterLabels;  // For display
  final String narrative;  // For screen rendering
  final String? voiceNarrative;  // For audio (optional if same as narrative)
  final Map<String, NumberPrivacy> parameterPrivacy;
  final double confidence;
  final List<String> sources;  // Legal references
  final DateTime generatedAt;

  InsightIntent({
    required this.id,
    required this.intentType,
    required this.parameters,
    required this.parameterLabels,
    required this.narrative,
    this.voiceNarrative,
    required this.parameterPrivacy,
    required this.confidence,
    required this.sources,
    required this.generatedAt,
  });

  factory InsightIntent.fromCoachResponse(CoachResponse resp) {
    // Migrate existing coach response structure to intent
    return InsightIntent(
      id: resp.id,
      intentType: _inferIntentType(resp),
      parameters: resp.extractedParameters ?? {},
      parameterLabels: resp.parameterLabels ?? {},
      narrative: resp.text,
      voiceNarrative: resp.voiceText,
      parameterPrivacy: resp.parameterPrivacy ?? {},
      confidence: resp.confidence,
      sources: resp.sources ?? [],
      generatedAt: DateTime.now(),
    );
  }
}

enum NumberPrivacy {
  public,      // Safe to speak publicly
  semiPublic,  // OK in semi-public (office), not crowded transit
  private;     // Only in private settings (home, alone)
}
```

### Example 2: CoachInteraction (Decision 2)

```dart
// lib/models/coach/coach_interaction.dart (NEW)

class CoachInteraction {
  final String id;
  final CoachInteractionInput input;
  final CoachIntent output;
  final DateTime timestamp;

  CoachInteraction({
    required this.id,
    required this.input,
    required this.output,
    required this.timestamp,
  });
}

class CoachInteractionInput {
  final String text;  // User's input (typed or STT transcript)
  final AudioTranscript? audioSource;  // Non-null if voice input (v2027+)
  final String channel;  // "chat" | "voice" | "voice_watch" | "voice_car"

  CoachInteractionInput({
    required this.text,
    this.audioSource,
    required this.channel,
  });
}

class AudioTranscript {
  final String id;
  final String transcript;
  final List<TranscriptSegment> segments;
  final double overallConfidence;
  final String language;  // "fr-CH", "de-CH", etc.
  final DateTime recordedAt;
  final List<TranscriptCorrection> userCorrections;

  AudioTranscript({
    required this.id,
    required this.transcript,
    required this.segments,
    required this.overallConfidence,
    required this.language,
    required this.recordedAt,
    this.userCorrections = const [],
  });
}

class TranscriptSegment {
  final String text;
  final double confidence;
  final int startMs;
  final int endMs;
  final String? userCorrection;

  TranscriptSegment({
    required this.text,
    required this.confidence,
    required this.startMs,
    required this.endMs,
    this.userCorrection,
  });
}
```

### Example 3: ExtractedField with VoiceNarration (Decision 3)

```dart
// lib/models/document/extracted_field.dart (UPDATED)

class ExtractedField {
  String fieldName;
  dynamic value;
  String? unit;
  double extractionConfidence;
  double dataQualityWeight;
  String extractionMethod;
  bool verifiedByUser;

  // NEW: voice support
  String voiceNarration;  // Spell out value for audio
  String voiceLanguage;   // "fr-CH", "de-CH", "it-CH"
  bool isSensitiveNumber;
  NumberPrivacy privacy;

  ExtractedField({
    required this.fieldName,
    required this.value,
    this.unit,
    required this.extractionConfidence,
    required this.dataQualityWeight,
    required this.extractionMethod,
    required this.verifiedByUser,
    required this.voiceNarration,
    required this.voiceLanguage,
    required this.isSensitiveNumber,
    required this.privacy,
  });

  // Helper: generate voice narration from numeric value
  static String _narrate(num value, String language) {
    if (language == "fr-CH") {
      return _narrateFrench(value);
    } else if (language == "de-CH") {
      return _narrateGerman(value);
    } else if (language == "it-CH") {
      return _narrateItalian(value);
    }
    return value.toString();
  }

  static String _narrateFrench(num n) {
    // "70377" → "soixante-dix mille trois cent soixante-dix-sept"
    // (implementation: use swiss_number_formatter package)
    return SwissNumberFormatter.toWordsHex(n, 'fr-CH');
  }

  static String _narrateGerman(num n) {
    // "70377" → "siebzigtausend-dreihundertsiebenundsiebzig"
    return SwissNumberFormatter.toWordsHex(n, 'de-CH');
  }

  static String _narrateItalian(num n) {
    // "70377" → "settantamila-trecentosettantasette"
    return SwissNumberFormatter.toWordsHex(n, 'it-CH');
  }
}
```

### Example 4: AmbientContextCache (Decision 4)

```dart
// lib/services/coach/ambient_context_cache.dart (NEW)

class AmbientContextCache {
  static final _cache = <String, CachedIntent>{};

  /// Pre-compute coach response for an anticipated trigger
  static Future<void> warmCache({
    required CoachProfile profile,
    required AnticipationTrigger trigger,
    required LlmConfig? byokConfig,
  }) async {
    // Generate intent asynchronously
    final intent = await _generateIntentForTrigger(
      profile: profile,
      trigger: trigger,
      byokConfig: byokConfig,
    );

    // Cache with 24h TTL
    _cache[trigger.id] = CachedIntent(
      intent: intent,
      cachedAt: DateTime.now(),
      ttl: Duration(hours: 24),
    );

    print('[AmbientContextCache] Warmed: ${trigger.id}');
  }

  /// Retrieve cached intent, null if expired or not found
  static CoachIntent? get(String triggerId) {
    final cached = _cache[triggerId];
    if (cached == null) return null;

    if (DateTime.now().difference(cached.cachedAt) > cached.ttl) {
      _cache.remove(triggerId);
      return null;
    }

    return cached.intent;
  }

  static Future<CoachIntent> _generateIntentForTrigger({
    required CoachProfile profile,
    required AnticipationTrigger trigger,
    required LlmConfig? byokConfig,
  }) async {
    // Reuse CoachLlmService to generate intent
    final response = await CoachLlmService.generateIntent(
      profile: profile,
      context: trigger.label,
      byokConfig: byokConfig,
    );
    return response;
  }
}

class CachedIntent {
  final CoachIntent intent;
  final DateTime cachedAt;
  final Duration ttl;

  CachedIntent({
    required this.intent,
    required this.cachedAt,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;
}
```

### Example 5: VoiceContextDetector (Decision 5)

```dart
// lib/services/voice/voice_context_detector.dart (NEW)

class VoiceContextDetector {
  static final _locationService = LocationService();

  static Future<VoiceContext> detect() async {
    final location = await _locationService.current();
    final time = DateTime.now();
    final dayOfWeek = time.weekday;  // 1=Monday, 7=Sunday

    // Heuristic: infer context from location + time
    if (_isHome(location) && (time.hour < 6 || time.hour > 21)) {
      return VoiceContext.private;
    }

    if (_isHome(location) && time.hour >= 9 && time.hour <= 17) {
      return VoiceContext.semiPublic;  // Others might be home
    }

    if (_isOffice(location) && dayOfWeek <= 5) {
      return VoiceContext.semiPublic;  // Work environment
    }

    if (_isTransit(location) || _isCrowded(location)) {
      return VoiceContext.public;
    }

    return VoiceContext.unknown;
  }

  static bool _isHome(Location? loc) {
    if (loc == null) return false;
    // User's saved home address
    return loc.distance(savedHomeLocation) < 100;  // Within 100m
  }

  static bool _isOffice(Location? loc) {
    if (loc == null) return false;
    // Workplace registered in profile
    return loc.distance(savedOfficeLocation) < 100;
  }

  static bool _isTransit(Location? loc) {
    if (loc == null) return false;
    // GPS on train, bus, etc. (from Location.activity == "moving")
    return loc.activity == LocationActivity.transit;
  }

  static bool _isCrowded(Location? loc) {
    if (loc == null) return false;
    // Known crowded places: station, airport, shopping center
    return loc.placeName.contains(RegExp('station|bahnhof|flughafen|gare|markt'));
  }
}

enum VoiceContext {
  private,      // Alone, safe to speak sensitive numbers
  semiPublic,   // Others present, but trusted (home/office)
  public,       // Strangers present, don't speak private numbers
  unknown,      // Can't determine; default to cautious
}
```

---

## APPENDIX C: Test Cases (Minimal)

```dart
// test/models/coach/insight_intent_test.dart (NEW)

void main() {
  group('InsightIntent', () {
    test('creates intent with voice narration', () {
      final intent = InsightIntent(
        id: 'test_1',
        intentType: 'ALERT_DEADLINE',
        parameters: {'daysRemaining': 27, 'amount': 7258},
        parameterLabels: {'daysRemaining': 'Days', 'amount': 'Amount'},
        narrative: 'You have 27 days to contribute 7258 CHF.',
        voiceNarrative: 'You have twenty-seven days to contribute seven thousand two hundred fifty-eight francs.',
        parameterPrivacy: {
          'daysRemaining': NumberPrivacy.public,
          'amount': NumberPrivacy.public,
        },
        confidence: 0.95,
        sources: ['LIFD_art_82'],
        generatedAt: DateTime.now(),
      );

      expect(intent.voiceNarrative, contains('twenty-seven'));
      expect(intent.parameterPrivacy['amount'], NumberPrivacy.public);
    });

    test('intent marked with sensitive numbers', () {
      final intent = InsightIntent(
        id: 'salary_test',
        intentType: 'DATA_UPDATE',
        parameters: {'salary': 92000},
        parameterLabels: {},
        narrative: 'Your salary is 92 thousand CHF.',
        voiceNarrative: 'Your salary information is in the app.',
        parameterPrivacy: {
          'salary': NumberPrivacy.private,
        },
        confidence: 0.99,
        sources: [],
        generatedAt: DateTime.now(),
      );

      expect(intent.parameterPrivacy['salary'], NumberPrivacy.private);
    });
  });
}

// test/services/voice/voice_context_detector_test.dart (NEW)

void main() {
  group('VoiceContextDetector', () {
    test('detects private context at home after 9pm', () async {
      mockTime(23, 30);  // 11:30 PM
      mockLocation(homeAddress);

      final context = await VoiceContextDetector.detect();

      expect(context, VoiceContext.private);
    });

    test('detects public context on train', () async {
      mockTime(17, 45);  // Commute time
      mockLocation(trainsLocationData);

      final context = await VoiceContextDetector.detect();

      expect(context, VoiceContext.public);
    });

    test('returns unknown if location unavailable', () async {
      mockLocationPermissionDenied();

      final context = await VoiceContextDetector.detect();

      expect(context, VoiceContext.unknown);
    });
  });
}

// test/services/coach/ambient_context_cache_test.dart (NEW)

void main() {
  group('AmbientContextCache', () {
    setUp(() {
      AmbientContextCache.clear();  // Clear cache before each test
    });

    test('warms cache for anticipation trigger', () async {
      final trigger = AnticipationTrigger(
        id: '3a_deadline',
        label: '3a contribution deadline approaching',
      );

      await AmbientContextCache.warmCache(
        profile: testProfile,
        trigger: trigger,
        byokConfig: null,
      );

      final cached = AmbientContextCache.get('3a_deadline');
      expect(cached, isNotNull);
    });

    test('returns null if cache expired', () async {
      final trigger = AnticipationTrigger(id: 'test');

      await AmbientContextCache.warmCache(
        profile: testProfile,
        trigger: trigger,
        byokConfig: null,
      );

      // Fake time advance
      advanceTimeBy(Duration(hours: 25));

      final cached = AmbientContextCache.get('test');
      expect(cached, isNull);
    });

    test('hit rate > 80% in test suite', () async {
      // Warm 10 common triggers
      for (int i = 0; i < 10; i++) {
        await AmbientContextCache.warmCache(
          profile: testProfile,
          trigger: AnticipationTrigger(id: 'trigger_$i'),
          byokConfig: null,
        );
      }

      // Query 10 times
      int hits = 0;
      for (int i = 0; i < 10; i++) {
        if (AmbientContextCache.get('trigger_$i') != null) hits++;
      }

      expect(hits / 10, greaterThan(0.80));
    });
  });
}
```

---

## APPENDIX D: ADR Template

When implementing these decisions, create ADRs like:

```markdown
# ADR-202604-Intent-Decoupling

## Status
Accepted (Phase 2, Document Intelligence)

## Context
Voice-first AI systems require structured intent outputs, not free-form strings.
Coach LLM must return intent type + parameters, enabling multiple renderers (UI, voice, notification).

## Decision
All Coach outputs will follow InsightIntent structure:
- intentType: enum (ALERT_DEADLINE, ARBITRAGE_OPPORTUNITY, etc.)
- parameters: key-value map (daysRemaining: 27, amount: 7258)
- narrative: for screen rendering
- voiceNarrative: optional, for audio rendering
- parameterPrivacy: marks sensitive numbers

## Consequences
**Positive**:
+ Voice renderer can be added without changing Coach logic
+ A/B testing intent phrasing becomes deterministic
+ Accessibility (alt text, screen reader) becomes straightforward
+ Ambiguous outputs now testable

**Negative**:
- Coach response structure is no longer free-form string
- Existing template responses need wrapping
- Slight overhead: parameter extraction + privacy mapping

## Alternatives Considered
1. Keep strings, add post-processing to extract intent (too fragile)
2. Split Coach into text + voice paths (too much duplication)

## Related Decisions
- ADR-202604-Voice-Narration-Field (Decision 3)
- ADR-202604-Privacy-by-Voice-State (Decision 5)
```

---

## END OF DOCUMENT

**For questions about this vision, reach out to**: [architect contact]
**Next checkpoint**: Architecture review at Phase 2 start (May 2026)
**Status**: Ready for team discussion


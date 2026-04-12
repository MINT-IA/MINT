# Voice-First Architecture — Visual Diagrams

---

## Diagram 1: v2.0 (Screen-First) vs. 2028 (Voice-Ready)

### TODAY (v2.0) — Screen-First Flow

```
┌─────────────────────────────────────────────────────────────┐
│ User Interaction                                            │
└─────────────────────────────────────────────────────────────┘
         ↓
    [TAP SCREEN]
         ↓
┌─────────────────────────────────────────────────────────────┐
│ Chat Input → "I got my LPP certificate"                    │
└─────────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────────┐
│ Document Upload Flow                                        │
│  1. Take photo / upload PDF                                │
│  2. LLM extraction (2-3s)                                  │
│  3. Show confirmation screen                              │
│  4. User taps confirm                                      │
│  5. Update profile                                         │
└─────────────────────────────────────────────────────────────┘
         ↓
    [SCREEN DISPLAYS]
    Card with numbers
    Buttons: Simulate / Archive
```

**Problem**: Every step is visual. Can't work on earbuds.

---

### 2028 (Voice-Ready) — Parallel Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ User Interaction (Multiple Channels)                       │
├─────────────────────────────────────────────────────────────┤
│ [VOICE: "What about my 3a?"]                              │
│ [SCREEN: Open app]                                         │
│ [EMAIL: Forward LPP certificate]                           │
│ [WATCH: Tap notification]                                  │
└─────────────────────────────────────────────────────────────┘
         ↓ (parallel processing)
    ┌────────────────────────────────────────┐
    │  VOICE INPUT                           │ [2027]
    │  ↓ STT (speech-to-text)               │
    │  ↓ Intent extraction                  │
    │  ↓ AmbientContextCache lookup         │
    │  ← Cached response (<500ms)           │
    └────────────────────────────────────────┘

    ┌────────────────────────────────────────┐
    │  DOCUMENT INPUT                        │ [v2.0]
    │  ↓ Photo/PDF received                 │
    │  ↓ LLM extraction                     │
    │  ↓ ConfidenceValidator                │
    │  → If voice ready: narrate aloud      │
    │  → If screen: show visual confirm     │
    │  → Store as AudioTranscript           │
    └────────────────────────────────────────┘

    ┌────────────────────────────────────────┐
    │  SCREEN INPUT                         │ [v2.0]
    │  ↓ Chat message                       │
    │  ↓ Coach LLM (with intent structure)  │
    │  → Returns InsightIntent              │
    │  → Rendered for screen + voice        │
    │  → Cached for next user (ambient)     │
    └────────────────────────────────────────┘

         ↓ (unified output layer)

┌─────────────────────────────────────────────────────────────┐
│ InsightIntent (Structured Output)                          │
│ {                                                           │
│   intentType: "ALERT_DEADLINE",                           │
│   parameters: {amount: 7258, daysRemaining: 27},          │
│   narrative: "You have 27 days...",  // screen            │
│   voiceNarrative: "You have twenty-seven days...",  // earbuds
│   privacy: {amount: private, daysRemaining: public},      │
│ }                                                          │
└─────────────────────────────────────────────────────────────┘
         ↓ (renderers)
    ┌──────────────────┬────────────────┬─────────────────┐
    ↓                  ↓                 ↓                 ↓
┌─────────────┐  ┌──────────────┐  ┌────────────┐  ┌──────────┐
│ UI RENDER   │  │ VOICE RENDER │  │ NOTIFY     │  │ EMAIL    │
│ (Screen)    │  │ (AirPods)    │  │ (Push)     │  │ (Send)   │
└─────────────┘  └──────────────┘  └────────────┘  └──────────┘
```

**Key difference**: Data layer → Intent layer → Renderer layer. Flexible, reusable, scalable.

---

## Diagram 2: InsightIntent Structure (Decision 1)

```
┌───────────────────────────────────────────────────────────┐
│                  InsightIntent (v2.0)                     │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  id: "3a_deadline_27_days"                               │
│  │                                                        │
│  ├─ intentType: "ALERT_FISCAL_DEADLINE"                 │
│  │  └─ Enum: {ALERT_*, ARBITRAGE_*, DATA_*, etc.}      │
│  │                                                        │
│  ├─ parameters: {                                        │
│  │    daysRemaining: 27,                                │
│  │    amount: 7258,                                     │
│  │    deadline: "2026-12-31",                          │
│  │    source: "LIFD_art_82"                            │
│  │  }                                                    │
│  │                                                        │
│  ├─ narrative: "Tu as 27 jours pour verser..."          │
│  │  └─ Rendered on screen (text-based)                 │
│  │                                                        │
│  ├─ voiceNarrative: "Tu as vingt-sept jours..."        │
│  │  └─ Spoken on earbuds (spelled-out numbers)         │
│  │                                                        │
│  ├─ parameterPrivacy: {                                 │
│  │    daysRemaining: PUBLIC,        // OK in public     │
│  │    amount: PUBLIC,               // OK in public     │
│  │  }                                                    │
│  │  └─ Used by VoiceContextDetector                    │
│  │                                                        │
│  ├─ voiceLanguage: "fr-CH"                              │
│  │  └─ Pronunciation rules for Swiss French             │
│  │                                                        │
│  ├─ confidence: 0.94                                    │
│  │  └─ How sure the coach is about this insight         │
│  │                                                        │
│  └─ sources: ["LIFD_art_82", "tax_calendar"]           │
│     └─ Legal references for compliance                  │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

**Usage**:
```dart
// In Coach Service
final intent = InsightIntent(...);

// Render for screen (today)
final screenText = intent.narrative;

// Render for voice (2027)
final voiceText = intent.voiceNarrative;

// Check privacy (Decision 5)
if (context == VoiceContext.public &&
    intent.parameterPrivacy["amount"] == NumberPrivacy.private) {
  return ComplianceGuard.redact(intent);  // Don't speak numbers
}
```

---

## Diagram 3: Document Ingestion — Dual Channel (Decision 3)

```
                    DOCUMENT ARRIVES
                           │
             ┌─────────────┴─────────────┐
             ↓                           ↓
    ┌─────────────────┐        ┌─────────────────┐
    │ VISUAL CHANNEL  │        │ VOICE CHANNEL   │
    │ (Today, v2.0)   │        │ (2027, ready)   │
    └─────────────────┘        └─────────────────┘
             │                           │
    1. Take photo          1. Email forward
    2. Show preview        2. Async process
    3. LLM extract         3. System narrates
    4. Screen confirm      4. Voice confirm
    5. Update profile      5. Update profile
             │                           │
    ┌─────────────────────────────────────────┐
    │  LLM EXTRACTION (Shared)                │
    │  ↓ CloudVision or BYOK                  │
    │  ↓ Field detection                      │
    │  ↓ Confidence validation                │
    └─────────────────────────────────────────┘
             │
    ┌─────────────────────────────────────────┐
    │  ExtractedField[] (with voiceNarration) │
    │  ├─ fieldName: "lpp_capital"            │
    │  ├─ value: 70377                        │
    │  ├─ extractionConfidence: 0.97          │
    │  ├─ voiceNarration: "soixante-dix..."  │ ← NEW (Decision 3)
    │  ├─ voiceLanguage: "fr-CH"             │ ← NEW
    │  ├─ privacy: NumberPrivacy.private     │ ← NEW
    │  └─ isSensitiveNumber: true            │ ← NEW
    └─────────────────────────────────────────┘
             │
    ┌─────────────────────────────────────────┐
    │  CONFIRMATION (Dual Path)               │
    ├─────────────────────────────────────────┤
    │  VISUAL:                                │
    │  ┌───────────────────────────────┐      │
    │  │ I read:                       │      │
    │  │ LPP Capital: CHF 70'377      │      │
    │  │ [✓ Confirm] [Edit]           │      │
    │  └───────────────────────────────┘      │
    │                                         │
    │  VOICE:                                 │
    │  System: "soixante-dix mille..."       │
    │  User: "Confirmed" / "No, 75k"         │
    └─────────────────────────────────────────┘
             │
    ┌─────────────────────────────────────────┐
    │  ProfileEnricher                        │
    │  ├─ Inject into CoachProfile            │
    │  ├─ Update ConfidenceScore              │
    │  └─ Trigger AnticipationEngine          │
    └─────────────────────────────────────────┘
```

---

## Diagram 4: Ambient Context Cache (Decision 4)

```
┌───────────────────────────────────────────────────────────┐
│ ANTICIPATION ENGINE (Phase 3 — Rule-Based Triggers)      │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  Every day, check:                                       │
│  ├─ Is it Dec 4? → "3a deadline 27 days away"           │
│  ├─ Salary increased? → "Your max 3a changed"           │
│  ├─ Age 50? → "LPP bonification rate bumped to 15%"     │
│  └─ New law posted? → "Parliament changed pillar 3a"    │
│                                                           │
│  When trigger fires, WARM the cache:                    │
│  │                                                        │
│  └─→ AmbientContextCache.warmCache({                    │
│        trigger: "3a_deadline",                          │
│        profile: userProfile,                            │
│        byokConfig: llmConfig,                           │
│      })                                                  │
│                                                           │
│      (Calls Coach LLM asynchronously)                   │
│      → Returns InsightIntent                            │
│      → Stores in cache: [trigger_id] → intent           │
│      → TTL: 24 hours                                    │
│                                                           │
└───────────────────────────────────────────────────────────┘
         ↓
┌───────────────────────────────────────────────────────────┐
│ AMBIENT CONTEXT CACHE (Shared Memory)                    │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  Key: "3a_deadline"                                     │
│  Value: {                                               │
│    intent: InsightIntent {                              │
│      intentType: "ALERT_DEADLINE",                     │
│      narrative: "27 days...",                          │
│      voiceNarrative: "twenty-seven days..."            │
│    },                                                   │
│    cachedAt: 2026-12-04 07:00,                        │
│    ttl: 24h                                            │
│  }                                                      │
│                                                           │
│  [Other cached triggers...]                             │
│  ├─ salary_increase_*                                   │
│  ├─ lpp_birthday_alert                                 │
│  ├─ new_law_pillar3a                                   │
│  └─ mortgage_rate_review                               │
│                                                           │
└───────────────────────────────────────────────────────────┘
         ↓
┌───────────────────────────────────────────────────────────┐
│ USER INTERACTION (2028, Voice)                           │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  User: "Hey Mint, what about my 3a?" (voice)           │
│                                                           │
│  System lookup:                                          │
│  → intent = AmbientContextCache.get("3a_deadline")      │
│  → Found in cache? YES ✓                                │
│  → Valid (not expired)? YES ✓                           │
│  → Return instantly (<100ms)                            │
│                                                           │
│  Compare: without cache                                  │
│  → Call Coach LLM (2-3s)                                │
│  → Too slow for earbuds ✗                               │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

**Timeline**:
```
Dec 1, 2:00 AM (background)
  → Anticipation trigger fires: "3a deadline 27 days"
  → AmbientContextCache.warmCache()
  → Coach LLM called, result cached

Dec 4, 4:45 PM (user driving)
  → User asks via voice: "What about my 3a?"
  → System: "Cache hit!" → Returns in <500ms
  → User hears response before arriving at next light
```

---

## Diagram 5: Privacy by Voice State (Decision 5)

```
┌───────────────────────────────────────────────────────────┐
│ VOICE CONTEXT DETECTION (Location + Time)                │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  VoiceContextDetector.detect():                          │
│  ├─ GPS location                                        │
│  ├─ Current time (hour, day of week)                   │
│  ├─ Device activity (transit, moving, stationary)      │
│  └─ Geofence (home, office, crowded place)             │
│                                                           │
└───────────────────────────────────────────────────────────┘
         ↓
    ┌────────────────────────────────────────────┐
    │  VoiceContext = ?                          │
    │  ├─ PRIVATE (alone at home, 11pm)         │
    │  ├─ SEMIPUBLIC (office 2pm, others around)│
    │  ├─ PUBLIC (train, station, street)       │
    │  └─ UNKNOWN (can't determine)             │
    └────────────────────────────────────────────┘
         ↓
┌───────────────────────────────────────────────────────────┐
│ INTENT PRIVACY MAPPING (Example)                         │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  InsightIntent about salary increase:                   │
│  {                                                      │
│    parameters: {                                        │
│      newSalary: 105000,          ← PRIVATE number       │
│      oldSalary: 92000,           ← PRIVATE number       │
│      max3a: 7858,                ← PUBLIC number        │
│      percentageIncrease: 14,     ← PUBLIC number        │
│    },                                                   │
│    parameterPrivacy: {                                  │
│      newSalary: NumberPrivacy.private,                  │
│      oldSalary: NumberPrivacy.private,                  │
│      max3a: NumberPrivacy.public,                       │
│      percentageIncrease: NumberPrivacy.public,          │
│    }                                                    │
│  }                                                      │
│                                                           │
└───────────────────────────────────────────────────────────┘
         ↓
┌───────────────────────────────────────────────────────────┐
│ COMPLIANCE GUARD VALIDATION                              │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  ComplianceGuard.validateForVoice(intent, context):      │
│                                                           │
│  IF context == VoiceContext.public                       │
│    AND intent.hasPrivateNumbers()                        │
│  THEN:                                                   │
│    ├─ Flag: "UNSAFE_PUBLIC_AUDIO"                       │
│    ├─ Action: Don't call TTS                            │
│    ├─ Fallback: Haptic-only notification                │
│    ├─ User sees: "Sensitive data. Open app when alone." │
│    └─ Or: Defer response until private (24h cache)     │
│                                                           │
└───────────────────────────────────────────────────────────┘
         ↓
    ┌───────────────────────────────────────────┐
    │  VOICE RENDERING (Safe Path)              │
    ├───────────────────────────────────────────┤
    │                                           │
    │  SCENARIO 1: Private context (home)       │
    │  ✓ Full voice narration allowed:          │
    │    "Your salary jumped to 105 thousand." │
    │                                           │
    │  SCENARIO 2: Public context (train)       │
    │  ✗ Redact sensitive numbers:              │
    │    "Your salary information has changed. │
    │     Check the app for details."           │
    │                                           │
    │  SCENARIO 3: Unknown context              │
    │  ⚠ Default to cautious:                   │
    │    Use SEMIPUBLIC rules (redact private)  │
    │                                           │
    └───────────────────────────────────────────┘
```

**Real Example**:

```
[4:45 PM, Zurich Hauptbahnhof, packed train car]

System detects:
  - GPS: Zurich HB (crowded public place)
  - Time: 16:45 (commute time, others listening)
  - Activity: transit
  → VoiceContext = PUBLIC

Coach intent fires: "Your salary increased to 105k"
  - newSalary: 105000 (PRIVATE)
  - oldSalary: 92000 (PRIVATE)

ComplianceGuard.validateForVoice():
  → Has private numbers? YES
  → Context is public? YES
  → Result: UNSAFE

System action:
  → Skip TTS (no voice output)
  → Send haptic: 2 vibrations
  → Show notification: "Salary update. Open app."
  → User arrives home 30 min later
  → Context becomes PRIVATE
  → System speaks full narration: "Your salary jumped..."
```

---

## Diagram 6: Data Flow Architecture (v2.0 to 2028)

```
┌─────────────────────────────────────────────────────────┐
│ INPUT CHANNELS                                          │
├─────────────────────────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐      │
│ │ Screen  │ │ Voice   │ │Document │ │ Email   │      │
│ │ Chat    │ │ (2027)  │ │ (Photo) │ │ (2027)  │      │
│ └─────────┘ └─────────┘ └─────────┘ └─────────┘      │
│      ↓          ↓          ↓            ↓             │
│      └──────────┴──────────┴────────────┘             │
│              ↓                                         │
└─────────────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────┐
│ ADAPTER LAYER (DataIngestionService pattern)           │
├─────────────────────────────────────────────────────────┤
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐   │
│ │ChatAdapter   │ │DocumentAdapter│ │BankAdapter   │   │
│ │(text/voice)  │ │(photo/pdf)    │ │(bLink)       │   │
│ └──────────────┘ └──────────────┘ └──────────────┘   │
│      ↓                 ↓                  ↓            │
│      └─────────────────┴──────────────────┘            │
│              ↓                                         │
│     All adapters → IngestionResult                    │
│     (normalized format)                               │
│              ↓                                         │
└─────────────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────┐
│ PROCESSING LAYER                                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ConfidenceValidator                                  │
│    ├─ Per-field thresholds (salary >= 0.90)          │
│    ├─ Cross-field coherence checks                    │
│    └─ Voice confirmation readiness (NEW)              │
│         ↓                                              │
│  ExtractedField (with voiceNarration)                 │
│    ├─ value: 92000                                   │
│    ├─ voiceNarration: "ninety-two thousand"         │
│    ├─ privacy: NumberPrivacy.private                 │
│    └─ confidence: 0.96                               │
│         ↓                                              │
│  ProfileEnricher                                      │
│    ├─ Inject into CoachProfile                        │
│    ├─ Update ConfidenceScore                          │
│    ├─ Trigger AnticipationEngine                      │
│    └─ Warm AmbientContextCache                        │
│         ↓                                              │
└─────────────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────┐
│ INTELLIGENCE LAYER                                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  AnticipationEngine                                   │
│    ├─ Detects life events + fiscal deadlines          │
│    ├─ Fires triggers (rule-based, zero cost)          │
│    ├─ AmbientContextCache.warmCache()                 │
│    └─ Generates InsightIntent (structured)            │
│         ↓                                              │
│  CoachLLM Service                                     │
│    ├─ Takes InsightIntent (or generates new)          │
│    ├─ Enriches narrative (LLM, if BYOK)              │
│    ├─ Compliance checks (no banned terms)             │
│    └─ Returns structured intent                       │
│         ↓                                              │
│  FinancialBiography (Local, Private)                 │
│    ├─ Stores facts, edges, decisions                 │
│    ├─ Never sent to external APIs                     │
│    └─ Powers coach context (anonymized summary)       │
│         ↓                                              │
└─────────────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────┐
│ INTENT LAYER (InsightIntent)                            │
├─────────────────────────────────────────────────────────┤
│ {                                                       │
│   id, intentType, parameters,                         │
│   narrative, voiceNarrative,                          │
│   parameterPrivacy, confidence, sources               │
│ }                                                      │
│         ↓                                              │
└─────────────────────────────────────────────────────────┘
         ┌──┴──┬──────┬─────────┬────────┐
         ↓     ↓      ↓         ↓        ↓
┌───────────────────────────────────────────────────────────┐
│ RENDERER LAYER (Multiple Outputs)                        │
├───────────────────────────────────────────────────────────┤
│ ┌──────────┐ ┌──────────┐ ┌────────┐ ┌──────────┐      │
│ │UI Render │ │Voice     │ │Push    │ │Email     │      │
│ │(screen)  │ │Render    │ │Notify  │ │(Fwd doc) │      │
│ │          │ │(earbuds) │ │(haptic)│ │          │      │
│ │ "27 days"│ │"twenty-" │ │ 2 vib  │ │ Link     │      │
│ │ "7258"   │ │"seven"   │ │        │ │ [Confirm]│      │
│ │ [Button] │ │ + check  │ │        │ │          │      │
│ │          │ │ privacy  │ │        │ │          │      │
│ └──────────┘ └──────────┘ └────────┘ └──────────┘      │
│                                                         │
└───────────────────────────────────────────────────────────┘
```

---

## Diagram 7: v2.0 Implementation Timeline

```
PHASE 1: Le Parcours Parfait (2 weeks)
  ✗ No architectural changes
  ✓ Perfect baseline

                    ↓

PHASE 2: Intelligence Documentaire (4 weeks)
  Decision 1: InsightIntent decoupling
  Decision 3: ExtractedField.voiceNarration
  Decision 5: NumberPrivacy enums (partial)

  ┌──────────────────┐
  │ Document Upload  │
  │  ↓ Extract       │
  │  ↓ [NEW] Intent  │
  │  ↓ Render        │
  │  ✓ Screen        │
  │  ◐ Voice ready   │
  └──────────────────┘

                    ↓

PHASE 3: Moteur d'Anticipation (3 weeks)
  Decision 4: AmbientContextCache warmup
  Decision 5: VoiceContextDetector + privacy completion

  ┌──────────────────┐
  │ Anticipation     │
  │  ↓ Trigger       │
  │  ↓ [NEW] Cache   │
  │  ↓ Coach prompt  │
  │  ↓ [NEW] Privacy │
  │  ✓ Alerts        │
  │  ◑ Voice faster  │
  └──────────────────┘

                    ↓

PHASE 4: Mémoire Narrative (3 weeks)
  Decision 2: AudioTranscript layer

  ┌──────────────────┐
  │ Coach Chat       │
  │  ↓ User input    │
  │  ↓ LLM response  │
  │  ↓ [NEW]         │
  │     Transcript   │
  │  ↓ Storage       │
  │  ✓ Chat works    │
  │  ◑ Privacy ready │
  └──────────────────┘

                    ↓

PHASE 5: Interface Contextuelle (2 weeks)
  (Uses all previous decisions)

  ┌──────────────────┐
  │ Aujourd'hui      │
  │  ↓ Ranking       │
  │  ↓ Cards         │
  │  ↓ Links intent  │
  │  ✓ Smart display │
  │  ◐ Ready for     │
  │    voice context │
  └──────────────────┘

                    ↓

PHASE 6: QA Profond (2 weeks)
  + Test all new types + privacy edge cases
  + Verify no regression

  ✓ v2.0 SHIPS
  ◐ Voice-ready architecture in place

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PHASE 7: Connexions Externes (1 week)
  (Foundation only, bLink sandbox)

  ✓ v2.0 COMPLETE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

2027 (Voice Launch) — Build on v2.0 foundation
  ✓ Speech-to-text integration
  ✓ Text-to-speech (use cached intents)
  ✓ Ambient context detection (real geofencing)
  ✓ Voice UI (earbuds + watch)
  ✓ 3-month sprint instead of 6-month rebuild
```

---

## Diagram 8: Example: "What About My 3a?" Journey (2028)

```
┌─ 2028 Scenario: User in car, alone, wearing AirPods ─┐
│                                                       │
│ Time: 4:45 PM, driving from work to home             │
│ Location: Highway A1, private vehicle                │
│ Voice context: PRIVATE (alone, vehicle)              │
│                                                       │
└───────────────────────────────────────────────────────┘

User voice: "Hey Mint, what about my 3a?"

         ↓
    ┌─ STT (2027) ─┐
    │ transcript: │
    │ "what about│
    │  my 3a"    │
    └─────────────┘

         ↓
    ┌─────────────────────────┐
    │ Intent extraction:      │
    │ "3a_status_inquiry"     │
    └─────────────────────────┘

         ↓
    ┌─────────────────────────────┐
    │ AmbientContextCache lookup:│
    │ Key: "3a_status"           │
    │ Found? YES ✓ (cached 2h)   │
    │ Latency: <100ms            │
    └─────────────────────────────┘

         ↓
    ┌─────────────────────────────┐
    │ Intent retrieved:           │
    │ {                           │
    │   intentType: "STATUS",     │
    │   parameters: {             │
    │     current: 52000,         │
    │     annual_max: 7858,       │
    │     percentage_filled: 68,  │
    │     days_til_deadline: 27   │
    │   },                        │
    │   narrative: "Your 3a is at │
    │     68% of the annual max..│
    │   voiceNarration:           │
    │     "Your pillar 3a is at   │
    │      sixty-eight percent..." │
    │   privacy: {                │
    │     current: private,       │
    │     percentage_filled:      │
    │       public                │
    │   }                         │
    │ }                           │
    └─────────────────────────────┘

         ↓
    ┌─────────────────────────────┐
    │ Privacy check:              │
    │ VoiceContext.detect():      │
    │ → PRIVATE                   │
    │ → Safe to speak numbers     │
    └─────────────────────────────┘

         ↓
    ┌─────────────────────────────┐
    │ Voice render:               │
    │ (use full voiceNarration)   │
    └─────────────────────────────┘

         ↓
    ┌─────────────────────────────┐
    │ TTS output (via native):    │
    │                             │
    │ "Your pillar 3a is at       │
    │  sixty-eight percent of     │
    │  your annual maximum.       │
    │  You have twenty-seven days │
    │  to add more. Want me to    │
    │  open the simulator?"       │
    └─────────────────────────────┘

         ↓
    ┌─────────────────────────────┐
    │ [Audio plays via AirPods]   │
    │ Elapsed time: ~1.2s         │
    │ (STT + cache + TTS)         │
    │ → Real-time conversation    │
    └─────────────────────────────┘

User voice: "Simulate"

         ↓
    ┌─────────────────────────────┐
    │ System action:              │
    │ → Open simulator in app     │
    │ → App foreground (user      │
    │   is at red light)          │
    │ → User adjusts sliders      │
    │ → Returns to voice          │
    └─────────────────────────────┘

User voice: "Done, 6000 CHF"

         ↓
    ┌─────────────────────────────┐
    │ Update profile:             │
    │ New 3a commitment: 6000 CHF │
    │ Store as CoachInteraction:  │
    │ input: AudioTranscript(..)  │
    │ output: InsightIntent(..)   │
    └─────────────────────────────┘

[User arrives home safely, 3a optimized, never took eyes off road]
```

---

End of diagrams.


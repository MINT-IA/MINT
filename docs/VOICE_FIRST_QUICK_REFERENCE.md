# Voice-First Architecture — Quick Reference
## 5 Decisions for v2.0 (12 days total effort)

---

## The Problem (in 10 seconds)

v2.0 is screen-first (visual cards, chat, taps). Voice assistants (AirPods, Alexa, Google Home) are coming. By 2028, voice will be primary. v2.0 architecture must prepare NOW or 2027 voice launch requires rebuild.

---

## The 5 Decisions

| # | Decision | Where | Effort | Payoff |
|---|----------|-------|--------|--------|
| 1 | Decouple intent from UI | Coach output | 3d | 80% of voice readiness |
| 2 | Build transcript layer | Coach chat | 2d | Privacy + compliance |
| 3 | Voice-ready documents | Document extraction | 2d | Enables voice confirmation |
| 4 | Ambient context cache | Anticipation engine | 2d | Instant response on earbuds |
| 5 | Privacy by voice state | ComplianceGuard | 3d | Don't speak salary on train |

---

## Decision 1: Decouple Intent from UI (3 days)

**What**: Coach returns structured `InsightIntent`, not string.

**Why**: Voice renderer, screen renderer, notification renderer all need same intent. Can't do this with strings.

**Code**:
```dart
// OLD (string)
response = "You have 27 days to save 7258 CHF"

// NEW (intent)
InsightIntent {
  intentType: "ALERT_DEADLINE",
  parameters: {daysRemaining: 27, amount: 7258},
  narrative: "You have...",  // For screen
  voiceNarrative: "You have twenty-seven days...",  // For audio
}
```

**When**: Phase 2 (during document extraction). Insert before Coach returns response.

**Risk**: Low. Additive, no breaking changes.

---

## Decision 2: Build Transcript Layer (2 days)

**What**: Store voice conversations as `AudioTranscript` + `CoachInteraction`, not just chat strings.

**Why**: Voice can be replayed, corrected, audited. Regulatory compliance (nLPD). User privacy control.

**Code**:
```dart
// NEW: CoachInteraction wraps every coach turn
class CoachInteraction {
  String id;
  CoachInteractionInput input;    // User's question (text or audio)
  CoachIntent output;              // Coach's answer
  DateTime timestamp;
}

// NEW: AudioTranscript structure
class AudioTranscript {
  String id;
  String transcript;               // Speech-to-text
  List<TranscriptSegment> segments; // Timestamped words
  double confidence;
  String language;                 // "fr-CH", "de-CH"
  List<TranscriptCorrection> corrections; // User can fix STT errors
}
```

**When**: Phase 4 (FinancialBiography). Migrate `ConversationMemory` → `Transcript`.

**Risk**: Medium. Touches persistence. But fully backward compatible if ConversationMemory still works in parallel.

---

## Decision 3: Voice-Ready Documents (2 days)

**What**: Extracted fields include `voiceNarration` — spell-out of numbers for audio.

**Why**: When system says extracted value aloud, it should say "seventy thousand" not "70000".

**Code**:
```dart
// UPDATED: ExtractedField
class ExtractedField {
  String fieldName;
  dynamic value;              // 70377
  double extractionConfidence;

  // NEW
  String voiceNarration;      // "seventy thousand three hundred seventy-seven"
  String voiceLanguage;       // "en-CH" or "fr-CH"
  NumberPrivacy privacy;      // public / semiPublic / private
}

// Helper: generate narration
"70377" → SwissNumberFormatter.toWordsHex(70377, 'fr-CH')
       → "soixante-dix mille trois cent soixante-dix-sept"
```

**When**: Phase 2 (during DocumentAdapter). After LLM extraction, call `_narrate(value, language)`.

**Risk**: Low. Only affects extracted field structure. No breaking changes.

---

## Decision 4: Ambient Context Cache (2 days)

**What**: Pre-compute coach responses for anticipated events, cache them, return instantly (<500ms).

**Why**: Earbuds can't wait 2-3 seconds for LLM to respond. Pre-compute during idle time.

**Code**:
```dart
// Phase 3: when trigger fires, warm the cache
if (today.month == 12 && today.day == 4) {
  final trigger = AnticipationTrigger(id: "3a_deadline");
  await AmbientContextCache.warmCache(
    profile: profile,
    trigger: trigger,
    byokConfig: byokConfig,
  );
}

// Later, when voice asks: "What about my 3a?"
final intent = await AmbientContextCache.get("3a_deadline");
if (intent != null) {
  // Return instantly from cache, ~500ms
  return intent;
}
```

**When**: Phase 3 (Anticipation Engine). Hook into trigger firing.

**Risk**: Low. Optional caching layer. No breaking changes.

---

## Decision 5: Privacy by Voice State (3 days)

**What**: System detects public vs. private context (location + time). Never speaks salary on a train.

**Why**: "Your salary is 92'000 CHF" spoken aloud in public is a privacy disaster.

**Code**:
```dart
// NEW: Infer voice context
enum VoiceContext { private, semiPublic, public, unknown }

class VoiceContextDetector {
  static Future<VoiceContext> detect() async {
    final location = await gps.current();
    final time = DateTime.now();

    if (_isHome(location) && time.hour >= 21) {
      return VoiceContext.private;
    }
    if (_isTransit(location)) {
      return VoiceContext.public;
    }
    return VoiceContext.unknown;
  }
}

// NEW: Mark sensitive numbers
class InsightIntent {
  Map<String, NumberPrivacy> parameterPrivacy = {
    "salary": NumberPrivacy.private,        // Never speak in public
    "mortgage_affordability": NumberPrivacy.semiPublic,
    "account_count": NumberPrivacy.public,  // OK to speak anywhere
  };
}

// NEW: ComplianceGuard checks voice safety
class ComplianceGuard {
  static validateForVoice(intent, context) {
    if (context == VoiceContext.public &&
        intent.hasSensitiveNumbers()) {
      return GuardResult.warn(
        "Don't speak this. Offer haptic-only or defer."
      );
    }
  }
}
```

**When**: Phase 2-3. Insert privacy mapping into InsightIntent. Hook ComplianceGuard.validateForVoice() before voice render.

**Risk**: Medium. Requires testing across contexts. But conservative (block unsafe, not hide safe).

---

## Where to Insert in v2.0 Sprints

```
Phase 1: Le Parcours Parfait
  ✗ (none — nail the baseline first)

Phase 2: Intelligence Documentaire
  ✓ Decision 1 (intent decoupling)
  ✓ Decision 3 (voiceNarration field)
  ✓ Decision 5 (privacy enums)

Phase 3: Moteur d'Anticipation
  ✓ Decision 4 (ambient cache)
  ✓ Decision 5 (complete)

Phase 4: Mémoire Narrative
  ✓ Decision 2 (transcript layer)

Phase 5+: (Use, don't invent)
```

---

## Checklist for Code Review

Before merge of each phase, ask:

**Phase 2**:
- [ ] Coach intent has structure? (InsightIntent not string)
- [ ] Document fields include voiceNarration?
- [ ] Extracted fields marked with NumberPrivacy?

**Phase 3**:
- [ ] AmbientContextCache warm-up hooked to trigger?
- [ ] VoiceContextDetector integrated?

**Phase 4**:
- [ ] Coach interactions stored as Transcripts?

---

## Success Metrics

**By end of v2.0** (Sept 2026):

- All coach intents structured: 100%
- Document fields have voiceNarration: 100%
- Coach interactions as Transcripts: 100%
- Cache hit rate in tests: >80%
- No ComplianceGuard warnings for voice safety: 100%

---

## FAQ

**Q: Isn't this over-engineering? We don't have voice yet.**
A: No. These are 1.5 weeks of architecture, zero UI changes, zero feature disruption. When voice launches (2027), you ship in months, not years.

**Q: What if voice never happens?**
A: You get faster text chat (cache wins), better privacy compliance, and better accessibility. All wins.

**Q: Do we need to implement TTS (text-to-speech)?**
A: No. v2.0 is structure only. Use native iOS/Android TTS in 2027.

**Q: What about Alexa, Google Home integration?**
A: Out of scope for v2.0. This prepares the foundation.

**Q: Can we do this cheaper?**
A: Sure. Skip Decision 5 (privacy) and do it in 2027. But privacy is the hardest problem; better to solve now.

---

## Next Steps

1. **Team review** (this doc + full vision) — 1 hour
2. **Architecture decision** — OK to proceed? Any concerns?
3. **ADR writing** — One ADR per decision (5 total, 30 min each)
4. **Backlog refinement** — Slot 12 days into Phase 2-4 sprints
5. **Code review setup** — Checklist above added to merge requirements

---

## Questions?

- Confusion on any decision? → See full doc (VOICE_FIRST_ARCHITECTURE_2028.md)
- Disagree with one? → Schedule design session
- Want examples? → Appendix of full doc has minimal code samples
- Want to run POC? → Pick Decision 4 (ambient cache) — lowest risk, immediate win


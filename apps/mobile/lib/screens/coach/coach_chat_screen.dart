import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/models/coaching_preference.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/navigation/route_planner.dart';
import 'package:mint_mobile/services/navigation/screen_registry.dart';
import 'package:mint_mobile/services/response_card_service.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:mint_mobile/models/coach_insight.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/services/coach/memory_reference_service.dart';
import 'package:mint_mobile/widgets/coach/response_card_widget.dart';
import 'package:mint_mobile/widgets/coach/route_suggestion_card.dart';
import 'package:mint_mobile/services/coach/context_injector_service.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/services/financial_core/couple_optimizer.dart';
import 'package:mint_mobile/services/goal_selection_service.dart';
import 'package:mint_mobile/models/sequence_run.dart';
import 'package:mint_mobile/services/sequence/sequence_chat_handler.dart';
import 'package:mint_mobile/services/sequence/sequence_coordinator.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';
import 'package:mint_mobile/widgets/coach/life_event_sheet.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach/voice_chat_integration.dart';
import 'package:mint_mobile/services/coach/voice_service.dart';
import 'package:mint_mobile/services/voice/platform_voice_backend.dart';
import 'package:mint_mobile/services/llm/provider_health_service.dart';
import 'package:mint_mobile/services/coach/data_driven_opener_service.dart';
import 'package:mint_mobile/services/coach/precomputed_insights_service.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/coach/proactive_trigger_service.dart';
import 'package:mint_mobile/services/nudge/nudge_engine.dart';
import 'package:mint_mobile/services/nudge/nudge_persistence.dart';
import 'package:mint_mobile/services/agent/agent_validation_gate.dart';
import 'package:mint_mobile/services/agent/form_prefill_service.dart';
import 'package:mint_mobile/services/agent/letter_generation_service.dart';
import 'package:mint_mobile/widgets/coach/document_card.dart';
import 'package:mint_mobile/widgets/coach/lightning_menu.dart';
import 'package:mint_mobile/widgets/coach/voice_input_button.dart';
import 'package:mint_mobile/widgets/coach/voice_output_button.dart';
import 'package:mint_mobile/widgets/coach/widget_renderer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

// ────────────────────────────────────────────────────────────
//  COACH CHAT SCREEN — SLM-first, streaming, prod-ready
// ────────────────────────────────────────────────────────────
//
// Priority chain:
//   1. SLM on-device (streaming, zero network)
//   2. BYOK cloud LLM (RAG-grounded, user opt-in)
//   3. Honest fallback (no fake chatbot)
//
// Design:
//  - Streaming token-by-token for SLM (live typing effect)
//  - Tier badge on each coach message (On-device / Cloud / —)
//  - No BYOK CTA clutter (settings accessible via gear icon)
//  - Educational disclaimer in header
//  - Export PDF of conversation highlights
//
// Tous les textes en francais (informel "tu").
// Aucun terme banni.
// ────────────────────────────────────────────────────────────

class CoachChatScreen extends StatefulWidget {
  /// Optional initial prompt to send automatically when the screen opens.
  /// Used for contextual routing (e.g., "Parle au coach" from data blocks).
  final String? initialPrompt;

  /// Optional conversation ID to resume an existing conversation.
  final String? conversationId;

  /// When true, hides the back button (used when embedded as a tab).
  final bool isEmbeddedInTab;

  const CoachChatScreen({
    super.key,
    this.initialPrompt,
    this.conversationId,
    this.isEmbeddedInTab = false,
  });

  @override
  State<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends State<CoachChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  CoachProfile? _profile;
  bool _hasProfile = false;

  /// Proactive greeting engagement tracking (P3.5 Coaching Adaptatif).
  /// When a proactive greeting is shown, we track whether the user engages
  /// (sends a message within 60s) or ignores it (sends unrelated or waits).
  String? _proactiveTriggerType;
  DateTime? _proactiveGreetingShownAt;
  final List<ChatMessage> _messages = [];

  // ── Greeting narrative canvas ──────────────────────────────
  /// When true, the greeting is shown as a narrative card above the list.
  /// Becomes false on first user send, collapsing into a normal bubble.
  bool _greetingExpanded = true;

  /// Stored greeting data for the narrative canvas.
  String? _greetingLine1;
  String? _greetingLine2;
  List<String>? _greetingSuggestions;
  ChatTier? _greetingTier;
  bool _isLoading = false;
  bool _isStreaming = false;
  /// Unified guard preventing concurrent sends (covers _isLoading + context building).
  bool _isBusy = false;
  final StringBuffer _streamBuffer = StringBuffer();
  bool _isByokConfigured = false;

  /// Conversation persistence
  final ConversationStore _conversationStore = ConversationStore();
  String? _conversationId;

  /// Cached SharedPreferences instance (T2-3).
  SharedPreferences? _cachedPrefs;
  Future<SharedPreferences> _getPrefs() async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

  /// SLM stream timeout — prevents infinite hang if model deadlocks.
  static const Duration _streamTimeout = Duration(seconds: 45);

  bool _profileInitialized = false;

  bool _isResumingConversation = false;

  // ── Voice (S63) ──────────────────────────────────────────────
  /// Single VoiceService instance for this screen.
  ///
  /// Uses [PlatformVoiceBackend] which probes native channels via
  /// [MethodChannel]. When plugins (flutter_tts / speech_to_text) are absent
  /// the backend degrades gracefully — [MissingPluginException] is caught
  /// internally and both STT and TTS report unavailable.
  /// [VoiceStateMachine] (wired inside [VoiceService]) prevents concurrent
  /// listen+speak operations at the state-machine level.
  final VoiceService _voiceService = VoiceService(
    backend: PlatformVoiceBackend(),
  );

  /// Whether STT is available on this device.
  bool _voiceSttAvailable = false;

  /// Whether TTS is available on this device.
  bool _voiceTtsAvailable = false;

  /// Whether voice mode is currently active (user initiated via mic button).
  /// When active, coach responses are automatically spoken aloud via TTS.
  /// Resets to false when the user sends a typed message.
  bool _voiceModeActive = false;

  /// Integration layer that coordinates STT→chat→TTS loop.
  /// Handles PII scrubbing, compliance validation, and safe mode detection.
  late final VoiceChatIntegration _voiceChatIntegration;

  // ── Provider health (S64) ────────────────────────────────────
  /// Whether the primary provider circuit is open (temporarily unavailable).
  bool _primaryCircuitOpen = false;

  /// Whether all known providers are currently unhealthy.
  bool _allProvidersDown = false;

  // ── Document generation (Agent Autonome) ───────────────────
  /// Last generated form (stored for rendering in document card).
  FormPrefill? _lastGeneratedForm;

  /// Last generated letter (stored for rendering in document card).
  GeneratedLetter? _lastGeneratedLetter;

  // ── Emotional canvas (UX P3) ───────────────────────────────
  /// Background tint that changes subtly based on conversation topic.
  /// Extremely subtle — felt, not seen.
  late final AnimationController _canvasAnimController;
  late Animation<Color?> _canvasAnimation;
  Color _canvasColorBegin = MintColors.white;
  Color _canvasColorEnd = MintColors.white;
  _CanvasMood _currentMood = _CanvasMood.neutral;

  /// Milestone pulse: one-shot controller for completion celebrations.
  AnimationController? _milestonePulseController;
  bool _milestonePulsing = false;

  // ── Write-tool confirmation guards (V3 audit) ──────────────
  /// Pending goal change awaiting user confirmation.
  String? _pendingGoalTag;

  /// Pending step completion awaiting user confirmation.
  String? _pendingStepId;

  /// Realtime subscription to ScreenReturn events from simulators.
  StreamSubscription<ScreenReturn>? _screenReturnSub;

  /// Debounce timer for realtime screen returns — prevents LLM spam when
  /// sliders emit on every change (e.g. affordability, staggered_withdrawal).
  Timer? _screenReturnDebounce;
  ScreenReturn? _lastPendingReturn;

  /// Key of the sequence step consumed by the realtime path.
  /// Format: "{runId}_{stepId}". Set by realtime handler on success.
  /// Checked by _handleRouteReturn for dedup (same key = skip entirely).
  String? _lastRealtimeHandledStepKey;

  /// Key of the sequence step that is currently being navigated via
  /// RouteSuggestionCard. Set BEFORE navigation, checked AFTER return.
  /// Format: "{runId}_{stepId}". Null when not in a guided sequence.
  /// This is the sync guard that allows _handleRouteReturn to bypass
  /// legacy side effects without an async check.
  String? _activeSequenceStepKey;

  @override
  void initState() {
    super.initState();

    // Emotional canvas animation (800-1200ms depending on mood).
    _canvasAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _canvasAnimation = ColorTween(
      begin: MintColors.white,
      end: MintColors.white,
    ).animate(CurvedAnimation(
      parent: _canvasAnimController,
      curve: Curves.easeInOut,
    ));

    // Bug fix: use provided conversationId when resuming, else generate unique ID.
    _conversationId = widget.conversationId ??
        '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
    if (widget.conversationId != null) {
      _isResumingConversation = true;
      _loadExistingConversation(widget.conversationId!);
    }
    // Voice (S63/Sprint E): initialize integration and probe availability.
    _voiceChatIntegration = VoiceChatIntegration(voice: _voiceService);
    _initVoiceAvailability();
    // Provider health (S64): check circuit breaker state on mount.
    _checkProviderHealth();
  }

  /// Probe STT / TTS availability — fires once on mount.
  /// Updates state only if mounted; degrades gracefully on error.
  Future<void> _initVoiceAvailability() async {
    try {
      final stt = await _voiceService.isAvailable();
      final tts = await _voiceService.isTtsAvailable();
      if (mounted) {
        setState(() {
          _voiceSttAvailable = stt;
          _voiceTtsAvailable = tts;
        });
      }
    } catch (_) {
      // VoiceService stub — unavailable by default.
    }
  }

  /// Check provider health circuits — informational only.
  /// Failover logic itself lives in CoachOrchestrator.
  Future<void> _checkProviderHealth() async {
    try {
      final prefs = await _getPrefs();
      final health = await ProviderHealthService.getHealth(prefs);
      if (!mounted) return;
      final allOpen = health.isNotEmpty &&
          health.values.every((h) => h.circuitOpen);
      final primaryOpen = health['claude']?.circuitOpen == true ||
          health['openai']?.circuitOpen == true;
      setState(() {
        _primaryCircuitOpen = primaryOpen && !allOpen;
        _allProvidersDown = allOpen;
      });
    } catch (_) {
      // ProviderHealthService is optional — degrade silently.
    }
  }

  /// Load an existing conversation from persistent storage.
  Future<void> _loadExistingConversation(String id) async {
    final messages = await _conversationStore.loadConversation(id);
    if (messages.isNotEmpty && mounted) {
      setState(() {
        _messages.addAll(messages);
        _profileInitialized = true; // Skip greeting for resumed conversations
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final byok = context.read<ByokProvider>();
    final wasConfigured = _isByokConfigured;
    _isByokConfigured = byok.isConfigured;
    if (wasConfigured != _isByokConfigured && mounted) {
      setState(() {});
    }

    if (!_profileInitialized) {
      _profileInitialized = true;
      final coachProvider = context.read<CoachProfileProvider>();
      if (coachProvider.hasProfile) {
        _profile = coachProvider.profile!;
        _hasProfile = true;
        // Skip greeting when resuming an existing conversation.
        if (!_isResumingConversation) {
          _addInitialGreeting();
        }
        if (mounted) setState(() {});
        // Auto-send initial prompt if provided (contextual routing)
        final prompt = widget.initialPrompt;
        if (prompt != null && prompt.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _sendMessage(prompt);
          });
        }
      }
    }

    // Realtime ReturnContract: listen for simulation results.
    // V5-6 audit fix: cancel existing subscription before creating a new one.
    // didChangeDependencies runs multiple times — without this cancel, each
    // call leaks a new StreamSubscription.
    _screenReturnSub?.cancel();
    _screenReturnSub = ScreenCompletionTracker.stream.listen(
      _onRealtimeScreenReturn,
    );
  }

  @override
  void dispose() {
    _screenReturnSub?.cancel();
    _screenReturnDebounce?.cancel();
    _autoSaveConversation();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _voiceService.dispose();
    _canvasAnimController.dispose();
    _milestonePulseController?.dispose();
    super.dispose();
  }

  /// Auto-save conversation to persistent storage.
  /// Returns a Future so callers can await before navigating.
  Future<void> _autoSaveConversation() async {
    if (_conversationId != null && _messages.any((m) => m.isUser)) {
      await _conversationStore.saveConversation(_conversationId!, _messages);
    }
  }

  // ════════════════════════════════════════════════════════════
  //  GREETING
  // ════════════════════════════════════════════════════════════

  Future<void> _addInitialGreeting() async {
    assert(_profile != null);
    final p = _profile!;
    if (!mounted) return;
    final s = S.of(context)!;
    final name = p.firstName ?? s.coachFallbackName;
    final locale = Localizations.localeOf(context).languageCode;

    final tier = _currentTier();

    // ── Read MintStateProvider synchronously before any await ─────
    // context.read is only safe before the first suspension point.
    // We capture both the pending trigger and the full user state here.
    MintUserState? mintStateSnapshot;
    ProactiveTrigger? preloadedTrigger;
    try {
      final stateProvider = context.read<MintStateProvider>();
      mintStateSnapshot = stateProvider.state;
      preloadedTrigger = mintStateSnapshot?.pendingTrigger;
    } catch (_) {
      // MintStateProvider not registered — fall back to direct evaluation below.
    }

    // ── Proactive trigger evaluation ─────────────────────────────
    // Read from MintStateProvider if available (avoids double evaluate() race).
    // Falls back to direct evaluation if provider not wired yet.
    String? proactiveMessage;
    String? proactiveIntentTag;
    try {
      final prefs = await _getPrefs();
      if (!mounted) return;
      // Prefer MintStateProvider's pre-computed trigger to avoid race condition.
      ProactiveTrigger? trigger = preloadedTrigger;
      if (trigger == null && mintStateSnapshot == null) {
        // MintStateProvider not registered — fall back to direct evaluation.
        trigger = await ProactiveTriggerService.evaluate(
          profile: p,
          prefs: prefs,
          now: DateTime.now(),
        );
      }
      if (trigger != null && mounted) {
        proactiveMessage = _resolveProactiveMessage(trigger, s);
        proactiveIntentTag = trigger.intentTag;
        // Track for engagement measurement (P3.5 Coaching Adaptatif)
        _proactiveTriggerType = trigger.type.name;
        _proactiveGreetingShownAt = DateTime.now();
        // Store current phase and confidence as the new baseline.
        await ProactiveTriggerService.storeCurrentPhase(p, prefs);
        await ProactiveTriggerService.storeCurrentConfidence(p, prefs);
      } else if (trigger == null) {
        // No trigger — store baseline (idempotent, avoids hardcoded SP keys).
        await ProactiveTriggerService.storeCurrentPhase(p, prefs);
        await ProactiveTriggerService.storeCurrentConfidence(p, prefs);
      }
    } catch (_) {
      // Graceful degradation: greeting works without proactive trigger.
    }

    // ── Data-driven opener (Cleo-inspired, Swiss-adapted) ─────────
    // Only fires when no proactive trigger was already selected.
    // Surfaces a real CHF number from the user's state.
    //
    // Priority:
    //   1. Pre-computed cache (instant — written at profile-change time).
    //   2. Synchronous generation from mintStateSnapshot (fallback).
    String? dataDrivenMessage;
    String? dataDrivenIntentTag;
    if (proactiveMessage == null || proactiveMessage.isEmpty) {
      try {
        // Try pre-computed cache first (instant read, no computation).
        final prefs2 = await _getPrefs();
        if (!mounted) return;
        final cached = await PrecomputedInsightsService.getCachedInsight(
          prefs: prefs2,
        );
        if (cached != null) {
          final opener = cached.resolve(s);
          if (opener != null) {
            dataDrivenMessage = opener.message;
            dataDrivenIntentTag = opener.intentTag;
          }
        }
        // Fallback: synchronous generation if cache missed and state is available.
        if (dataDrivenMessage == null && mintStateSnapshot != null) {
          final opener = DataDrivenOpenerService.generate(
            state: mintStateSnapshot,
            l: s,
          );
          if (opener != null) {
            dataDrivenMessage = opener.message;
            dataDrivenIntentTag = opener.intentTag;
          }
        }
      } catch (_) {
        // Graceful degradation: greeting works without data-driven opener.
      }
    }

    // ── Build greeting text ────────────────────────────────────────
    final String greeting;
    if (proactiveMessage != null && proactiveMessage.isNotEmpty) {
      greeting = proactiveMessage;
    } else if (dataDrivenMessage != null && dataDrivenMessage.isNotEmpty) {
      greeting = dataDrivenMessage;
    } else if (tier == ChatTier.slm) {
      greeting = s.coachGreetingSlm(name);
    } else {
      final scoreSuffix = _buildGreetingScoreContext(p);
      greeting = s.coachGreetingDefault(name, scoreSuffix);
    }

    // Phase 1: personalized suggestions based on age/archetype
    final personalizedPrompts =
        ResponseCardService.suggestedPrompts(p, l: s);
    List<String> suggestions;
    if (personalizedPrompts.isNotEmpty) {
      suggestions = List<String>.from(personalizedPrompts);
    } else {
      final tips = CoachingService.generateTips(
        profile: p.toCoachingProfile(),
      );
      final topTipActions = tips.take(3).map((t) => t.title).toList();
      suggestions = topTipActions.isNotEmpty
          ? topTipActions
          : [
              s.coachSuggestRetirement,
              s.coachSuggestDeductions,
              s.coachSuggestSimulate3a,
            ];
    }

    // If a proactive trigger was fired, resolve its intentTag to a
    // human-readable label (never show raw routes as chip text).
    if (proactiveIntentTag != null && proactiveIntentTag.isNotEmpty) {
      final chipLabel = _resolveIntentTagToLabel(proactiveIntentTag, s);
      suggestions.remove(chipLabel);
      suggestions = [
        chipLabel,
        ...suggestions.take(3),
      ];
    }

    // If a data-driven opener was fired (and no proactive trigger), prepend
    // its intentTag as the first suggestion chip.
    if (proactiveMessage == null &&
        dataDrivenIntentTag != null &&
        dataDrivenIntentTag.isNotEmpty) {
      final chipLabel = _resolveIntentTagToLabel(dataDrivenIntentTag, s);
      suggestions.remove(chipLabel);
      suggestions = [
        chipLabel,
        ...suggestions.take(3),
      ];
    }

    // Phase 2: prepend high-priority nudge chips so Claude can reinforce
    // timely topics. Nudges are loaded asynchronously; graceful degradation
    // if SharedPreferences or NudgeEngine fail.
    // Skip nudge chips when a proactive trigger or data-driven opener is
    // already surfaced to avoid information overload.
    if (proactiveMessage == null && dataDrivenMessage == null) {
      try {
        final prefs = await _getPrefs();
        if (!mounted) return;
        final now = DateTime.now();
        final dismissedIds = await NudgePersistence.getDismissedIds(
          prefs,
          now: now,
        );
        final lastActivity =
            await NudgePersistence.getLastActivityTime(prefs);
        final nudges = NudgeEngine.evaluate(
          profile: p,
          now: now,
          dismissedNudgeIds: dismissedIds,
          lastActivityTime: lastActivity,
        );
        // Only surface high-priority nudges as chips (max 2).
        final highPriorityNudges = nudges
            .where((n) => n.priority == NudgePriority.high)
            .take(2)
            .toList();
        if (highPriorityNudges.isNotEmpty && mounted) {
          final nudgeLabels = highPriorityNudges
              .map((n) => _resolveNudgeTitle(n, s, p))
              .where((label) => label.isNotEmpty)
              .toList();
          if (nudgeLabels.isNotEmpty) {
            // Prepend nudge chips, keeping total chips at most 4.
            suggestions = [
              ...nudgeLabels,
              ...suggestions.take(4 - nudgeLabels.length),
            ];
          }
        }
      } catch (_) {
        // Graceful degradation: greeting works without nudge chips.
      }
    }

    if (!mounted) return;

    // No response cards on greeting — they duplicate Pulse.
    // Cards appear only in response to user messages.

    // ── Build narrative canvas line 1: name + time cue ───────────
    final now = DateTime.now();
    final dayName = DateFormat.EEEE(locale).format(now);
    final String timeCue;
    if (now.hour < 12) {
      timeCue = s.greetingMorning;
    } else if (now.hour < 18) {
      timeCue = s.greetingAfternoon;
    } else {
      timeCue = s.greetingEvening;
    }
    final line1 = '$name, $dayName $timeCue.';

    setState(() {
      _greetingExpanded = true;
      _greetingLine1 = line1;
      _greetingLine2 = greeting;
      _greetingSuggestions = suggestions;
      _greetingTier = tier;
    });
  }

  /// Resolve a [ProactiveTrigger]'s ARB messageKey to a display string.
  ///
  /// Parameterised keys (e.g. proactiveGoalMilestone with {progress})
  /// are resolved using [trigger.params]. Returns empty string on failure.
  /// Resolve a route-style intentTag to a user-readable chip label.
  /// Never show raw routes like '/coach/weekly-recap' as chip text.
  String _resolveIntentTagToLabel(String intentTag, S s) {
    // Map known proactive intent tags to i18n labels.
    final map = <String, String>{
      '/coach/weekly-recap': s.recapTitle,
      '/coach/chat': s.coachSuggestRetirement,
      '/home': s.pulseFeedbackRecalculated,
      '/profile': s.profileSectionIdentity,
      // Data-driven opener routes:
      '/budget': s.goalBudgetTitle,
      '/pilier-3a': s.coachSuggestSimulate3a,
      '/retraite': s.goalRetirementTitle,
    };
    // Try direct map, then try ScreenRegistry for intent-tag based labels.
    if (map.containsKey(intentTag)) return map[intentTag]!;
    // Fallback: strip slashes and capitalize.
    final fallback = intentTag
        .replaceAll('/', ' ')
        .replaceAll('-', ' ')
        .trim();
    return fallback.isNotEmpty
        ? '${fallback[0].toUpperCase()}${fallback.substring(1)}'
        : intentTag;
  }

  String _resolveProactiveMessage(ProactiveTrigger trigger, S s) {
    try {
      final p = trigger.params;
      switch (trigger.messageKey) {
        case 'proactiveLifecycleChange':
          return s.proactiveLifecycleChange;
        case 'proactiveWeeklyRecap':
          return s.proactiveWeeklyRecap;
        case 'proactiveGoalMilestone':
          final progress = p?['progress'] ?? '50';
          return s.proactiveGoalMilestone(progress);
        case 'proactiveSeasonalReminder':
          final event = p?['event'] ?? '';
          return s.proactiveSeasonalReminder(event);
        case 'proactiveInactivityReturn':
          final days = p?['days'] ?? '7';
          return s.proactiveInactivityReturn(days);
        case 'proactiveConfidenceUp':
          final delta = p?['delta'] ?? '5';
          return s.proactiveConfidenceUp(delta);
        case 'proactiveNewCap':
          return s.proactiveNewCap;
        default:
          return '';
      }
    } catch (_) {
      return '';
    }
  }

  /// Resolve a nudge's [titleKey] ARB key to a display string.
  ///
  /// Parameterised keys (e.g. nudgeBirthdayTitle with {age}) are resolved
  /// using [profile] data. Returns an empty string if resolution fails.
  String _resolveNudgeTitle(
    Nudge nudge,
    S s,
    CoachProfile p,
  ) {
    try {
      switch (nudge.titleKey) {
        case 'nudgeSalaryTitle':
          return s.nudgeSalaryTitle;
        case 'nudgeTaxDeadlineTitle':
          return s.nudgeTaxDeadlineTitle;
        case 'nudge3aDeadlineTitle':
          return s.nudge3aDeadlineTitle;
        case 'nudgeBirthdayTitle':
          final age = DateTime.now().year - p.birthYear;
          return s.nudgeBirthdayTitle(age.toString());
        case 'nudgeProfileTitle':
          return s.nudgeProfileTitle;
        case 'nudgeInactiveTitle':
          return s.nudgeInactiveTitle;
        case 'nudgeGoalProgressTitle':
          return s.nudgeGoalProgressTitle;
        case 'nudgeAnniversaryTitle':
          return s.nudgeAnniversaryTitle;
        case 'nudgeLppBuybackTitle':
          return s.nudgeLppBuybackTitle;
        case 'nudgeNewYearTitle':
          return s.nudgeNewYearTitle;
        default:
          return '';
      }
    } catch (_) {
      return '';
    }
  }

  String _buildGreetingScoreContext(CoachProfile profile) {
    try {
      final score = FinancialFitnessService.calculate(profile: profile);
      if (score.global > 0) {
        return S.of(context)!.coachScoreSuffix(score.global);
      }
    } catch (_) {}
    return '';
  }

  ChatTier _currentTier() {
    if (FeatureFlags.slmPluginReady &&
        FeatureFlags.enableSlmNarratives &&
        !FeatureFlags.safeModeDegraded &&
        SlmEngine.instance.isAvailable) {
      return ChatTier.slm;
    }
    if (_isByokConfigured) return ChatTier.byok;
    return ChatTier.fallback;
  }

  // ════════════════════════════════════════════════════════════
  //  MESSAGE SENDING — SLM streaming or standard
  // ════════════════════════════════════════════════════════════

  Future<void> _showLifeEventSheet() async {
    final prompt = await LifeEventSheet.show(context);
    if (prompt != null && prompt.isNotEmpty && mounted) {
      _sendMessage(prompt);
    }
  }

  /// Show the Lightning Menu bottom sheet with contextual actions.
  Future<void> _showLightningMenu() async {
    final capMem = await CapMemoryStore.load();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MintColors.transparent,
      builder: (_) => LightningMenu(
        profile: _profile,
        capMemory: capMem,
        onSendMessage: (message) {
          if (mounted) _sendMessage(message);
        },
        onNavigate: (route) {
          if (mounted) context.push(route);
        },
      ),
    );
  }

  /// P3.5 Coaching Adaptatif: record whether the user engaged with
  /// the proactive greeting (responded within 60s) or ignored it.
  void _trackProactiveEngagement() {
    if (_proactiveTriggerType == null || _proactiveGreetingShownAt == null) {
      return;
    }
    final elapsed = DateTime.now().difference(_proactiveGreetingShownAt!);
    final engaged = elapsed.inSeconds <= 60;

    // Capture trigger type in a local variable before clearing the field.
    // The async `.then()` callback would otherwise read a null field
    // because _proactiveTriggerType is cleared synchronously below.
    final triggerType = _proactiveTriggerType!;
    _getPrefs().then((prefs) {
      var pref = CoachingPreference.load(prefs);
      pref = engaged
          ? pref.recordEngagement(triggerType)
          : pref.recordDismissal(triggerType);
      pref.save(prefs);
    });

    // Clear — only track once per proactive greeting
    _proactiveTriggerType = null;
    _proactiveGreetingShownAt = null;
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isBusy) return;

    // ── V3-1: handle pending write-tool confirmations ───────────
    if (_pendingGoalTag != null || _pendingStepId != null) {
      final confirmed = text.trim().toLowerCase() == 'confirmer';
      final cancelled = text.trim().toLowerCase() == 'annuler';
      if (confirmed || cancelled) {
        await _handlePendingWriteConfirmation(confirmed);
        return;
      }
      // If user typed something else, cancel the pending action silently
      // and continue with normal message flow.
      _pendingGoalTag = null;
      _pendingStepId = null;
    }

    setState(() => _isBusy = true);

    try {
      await _sendMessageInner(text);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Execute or cancel a pending write-tool action (V3-1 audit).
  Future<void> _handlePendingWriteConfirmation(bool confirmed) async {
    if (!mounted) return;

    if (_pendingGoalTag != null) {
      final goalTag = _pendingGoalTag!;
      _pendingGoalTag = null;
      if (confirmed && _profile != null) {
        final prefs = await _getPrefs();
        await GoalSelectionService.setSelectedGoal(goalTag, prefs);
        if (mounted) {
          context.read<MintStateProvider>().forceRecompute(_profile!);
          setState(() {
            _messages.add(ChatMessage(
              role: 'assistant',
              content: 'Objectif mis \u00e0 jour\u00a0: $goalTag',
              timestamp: DateTime.now(),
              tier: ChatTier.byok,
            ));
          });
          _scrollToBottom();
        }
      } else if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: 'Changement d\u2019objectif annul\u00e9.',
            timestamp: DateTime.now(),
            tier: ChatTier.byok,
          ));
        });
        _scrollToBottom();
      }
      return;
    }

    if (_pendingStepId != null) {
      final stepId = _pendingStepId!;
      _pendingStepId = null;
      if (confirmed) {
        // V3-2: use canonical CapMemoryStore.markCompleted() API
        final mem = await CapMemoryStore.load();
        await CapMemoryStore.markCompleted(mem, stepId);
        if (mounted) {
          setState(() {
            _messages.add(ChatMessage(
              role: 'assistant',
              content:
                  '\u00c9tape \u00ab\u202f$stepId\u202f\u00bb termin\u00e9e.',
              timestamp: DateTime.now(),
              tier: ChatTier.byok,
            ));
          });
          _scrollToBottom();
        }
      } else if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: 'Action annul\u00e9e.',
            timestamp: DateTime.now(),
            tier: ChatTier.byok,
          ));
        });
        _scrollToBottom();
      }
      return;
    }
  }

  Future<void> _sendMessageInner(String text) async {
    // P3.5 Coaching Adaptatif: track proactive greeting engagement.
    // If user sends a message within 60s of a proactive greeting = engaged.
    _trackProactiveEngagement();

    // Refresh profile in case it changed since screen init (T2-5).
    try {
      final provider = context.read<CoachProfileProvider>();
      if (provider.hasProfile) {
        _profile = provider.profile!;
      }
    } catch (_) {}

    // Capture mintState BEFORE any await (T1-4).
    MintUserState? mintStateForContext;
    try {
      mintStateForContext = context.read<MintStateProvider>().state;
    } catch (_) {
      mintStateForContext = null;
    }

    // Capture LLM config BEFORE any await (P0 async safety).
    final preAwaitConfig = _buildConfig();

    // Collapse greeting narrative canvas into a normal bubble on first send.
    if (_greetingExpanded && _greetingLine2 != null) {
      _messages.insert(
        0,
        ChatMessage(
          role: 'assistant',
          content: _greetingLine2!,
          timestamp: DateTime.now(),
          suggestedActions: _greetingSuggestions,
          tier: _greetingTier ?? ChatTier.fallback,
        ),
      );
      _greetingExpanded = false;
    }

    setState(() {
      _messages.add(ChatMessage(
        role: 'user',
        content: text.trim(),
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();
    // Emotional canvas: update background tint based on conversation topic.
    _updateCanvasMood();

    // Build enriched context for AI memory injection (S58).
    // Timeout + try/catch: if SharedPreferences or any dependency fails/hangs,
    // the chat still works without memory enrichment (graceful degradation).
    String? memoryBlock;
    try {
      final enrichedContext = await ContextInjectorService.buildContext(
        profile: _profile,
        now: DateTime.now(),
        mintState: mintStateForContext,
      ).timeout(const Duration(seconds: 2));
      if (enrichedContext.memoryBlock.isNotEmpty) {
        memoryBlock = enrichedContext.memoryBlock;
      }
    } catch (_) {
      // Graceful degradation: chat works without memory block.
    }

    // Resolve a visible memory reference so the coach can prepend it.
    // This makes past memory VISIBLE to the user (Cleo-style recall).
    MemoryReference? memoryRef;
    try {
      memoryRef = await MemoryReferenceService.findRelevant(
        currentTopic: text.trim(),
        now: DateTime.now(),
      ).timeout(const Duration(seconds: 1));
    } catch (_) {
      // Graceful degradation: chat works without memory reference.
    }

    // Try SLM streaming first.
    final ctx = _buildCoachContext(_profile!, mintState: mintStateForContext);
    final stream = CoachOrchestrator.streamChat(
      userMessage: text.trim(),
      history: _messages,
      ctx: ctx,
      memoryBlock: memoryBlock,
    );

    if (stream != null) {
      await _handleStreamResponse(stream, text.trim(), ctx,
          memoryRef: memoryRef);
      return;
    }

    // Fallback to standard (BYOK → fallback chain).
    await _handleStandardResponse(text.trim(),
        memoryBlock: memoryBlock, memoryRef: memoryRef,
        preAwaitConfig: preAwaitConfig);
  }

  /// Handle SLM streaming response (token-by-token).
  Future<void> _handleStreamResponse(
    Stream<String> stream,
    String userMessage,
    CoachContext ctx, {
    MemoryReference? memoryRef,
  }) async {
    setState(() {
      _isLoading = false;
      _isStreaming = true;
      _streamBuffer.clear();
      // Add placeholder message that will be updated.
      _messages.add(ChatMessage(
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
        tier: ChatTier.slm,
      ));
    });
    _scrollToBottom();

    // Wrap the stream with a timeout to prevent infinite hang.
    bool timedOut = false;
    try {
      final timedStream = stream.timeout(
        _streamTimeout,
        onTimeout: (sink) {
          timedOut = true;
          sink.close();
        },
      );
      await for (final token in timedStream) {
        if (!mounted) return;
        _streamBuffer.write(token);
        final current = _streamBuffer.toString();
        setState(() {
          _messages[_messages.length - 1] = ChatMessage(
            role: 'assistant',
            content: current,
            timestamp: DateTime.now(),
            tier: ChatTier.slm,
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[CoachChat] Stream error: $e');
    }

    if (!mounted) return;

    final rawText = _streamBuffer.toString().trim();

    // SLM produced nothing or timed out with no content — fall back.
    if (rawText.isEmpty) {
      setState(() {
        _messages.removeLast();
        _isStreaming = false;
        _isLoading = true;
      });
      await _handleStandardResponse(userMessage);
      return;
    }

    // If timed out but has partial content, keep what we have.
    if (timedOut) {
      debugPrint('[CoachChat] SLM stream timed out with partial content');
    }

    // Validate through ComplianceGuard.
    ComplianceResult compliance;
    try {
      compliance = ComplianceGuard.validate(
        rawText,
        context: ctx,
        componentType: ComponentType.general,
      );
    } catch (_) {
      // ComplianceGuard crashed — still sanitize banned terms manually
      // since SLM can generate them despite system prompt.
      compliance = ComplianceResult(
        isCompliant: true,
        sanitizedText: ComplianceGuard.sanitizeBannedTerms(rawText),
      );
    }

    final finalText = compliance.useFallback
        ? S.of(context)!.coachComplianceError
        : (compliance.sanitizedText.isNotEmpty
            ? compliance.sanitizedText
            : rawText);

    final suggestedActions =
        compliance.useFallback ? null : _inferSuggestedActions(userMessage);

    // Phase 1: generate inline response cards from user message
    final cards = _profile != null
        ? ResponseCardService.generateForChat(_profile!, userMessage,
            l: S.of(context)!)
        : <ResponseCard>[];

    // S58: detect route_to_screen tool_use in streamed text.
    final rawPayload = compliance.useFallback
        ? null
        : _parseRouteToolUse(finalText);
    final resolvedPayload =
        rawPayload != null ? _resolveRoutePayload(rawPayload) : null;

    // Detect generate_document tool_use in streamed text.
    final docPayload = compliance.useFallback
        ? null
        : _parseDocumentToolUse(finalText);

    var slmBaseText = rawPayload != null
        ? finalText
            .replaceAll(
              RegExp(r'\[ROUTE_TO_SCREEN:\{[^}]*\}\]'),
              '',
            )
            .trim()
        : finalText;
    // Strip GENERATE_DOCUMENT markers from displayed text.
    if (docPayload != null) {
      slmBaseText = slmBaseText
          .replaceAll(
            RegExp(r'\[GENERATE_DOCUMENT:\{[^}]*\}\]'),
            '',
          )
          .trim();
    }

    // Prepend visible memory reference when available (Cleo-style recall).
    final slmDisplayText = _prependMemoryRef(slmBaseText, memoryRef);

    setState(() {
      _messages[_messages.length - 1] = ChatMessage(
        role: 'assistant',
        content: slmDisplayText,
        timestamp: DateTime.now(),
        suggestedActions: suggestedActions,
        responseCards: cards,
        tier: ChatTier.slm,
        routePayload: resolvedPayload,
      );
      _isStreaming = false;
    });
    _scrollToBottom();
    _updateCanvasMood();

    // Generate document card if generate_document tool was detected.
    if (docPayload != null) {
      _handleDocumentGeneration(docPayload);
    }

    // Sprint E: auto-speak coach response when voice mode is active.
    if (_voiceModeActive && _voiceTtsAvailable && slmDisplayText.isNotEmpty) {
      unawaited(_voiceChatIntegration.chatToVoice(slmDisplayText));
    }

    // T1-3: Save conversation after each message exchange.
    await _autoSaveConversation();
  }

  /// Handle standard (non-streaming) response via orchestrator.
  Future<void> _handleStandardResponse(
    String text, {
    String? memoryBlock,
    MemoryReference? memoryRef,
    LlmConfig? preAwaitConfig,
  }) async {
    // Capture localizations before async gap (use_build_context_synchronously)
    final l = S.of(context)!;
    try {
      final config = preAwaitConfig ?? _buildConfig();
      final response = await CoachLlmService.chat(
        userMessage: text,
        profile: _profile!,
        history: _messages,
        config: config,
        memoryBlock: memoryBlock,
      );

      final tier = config.hasApiKey ? ChatTier.byok : ChatTier.fallback;

      // Phase 1: generate inline response cards from user message context
      final cards = _profile != null
          ? ResponseCardService.generateForChat(_profile!, text, l: l)
          : <ResponseCard>[];

      // S58: detect route_to_screen tool_use in response message.
      final rawPayload = _parseRouteToolUse(response.message);
      final resolvedPayload =
          rawPayload != null ? _resolveRoutePayload(rawPayload) : null;

      // Detect generate_document tool_use in response message.
      final docPayload = _parseDocumentToolUse(response.message);

      // Strip the [ROUTE_TO_SCREEN:{...}] marker from the displayed text
      // when a route payload was detected.
      var baseMessage = rawPayload != null
          ? response.message
              .replaceAll(
                RegExp(r'\[ROUTE_TO_SCREEN:\{[^}]*\}\]'),
                '',
              )
              .trim()
          : response.message;

      // Strip GENERATE_DOCUMENT markers from displayed text.
      if (docPayload != null) {
        baseMessage = baseMessage
            .replaceAll(
              RegExp(r'\[GENERATE_DOCUMENT:\{[^}]*\}\]'),
              '',
            )
            .trim();
      }

      // Prepend visible memory reference when available (Cleo-style recall).
      final displayMessage = _prependMemoryRef(baseMessage, memoryRef);

      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: displayMessage,
          timestamp: DateTime.now(),
          suggestedActions: response.suggestedActions,
          sources: response.sources,
          disclaimers: response.disclaimers,
          responseCards: cards,
          tier: tier,
          routePayload: resolvedPayload,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
      _updateCanvasMood();

      // Generate document card if generate_document tool was detected.
      if (docPayload != null) {
        _handleDocumentGeneration(docPayload);
      }

      // T1-1: Handle structured tool_calls from the backend.
      if (response.toolCalls.isNotEmpty) {
        await _processToolCalls(response.toolCalls);
      }

      // Sprint E: auto-speak coach response when voice mode is active.
      if (_voiceModeActive && _voiceTtsAvailable && displayMessage.isNotEmpty) {
        unawaited(_voiceChatIntegration.chatToVoice(displayMessage));
      }

      // T1-3: Save conversation after each message exchange.
      await _autoSaveConversation();
    } on RagApiException catch (e) {
      if (!mounted) return;
      final s = S.of(context)!;
      final String errorMsg;
      switch (e.code) {
        case 'invalid_key':
          errorMsg = s.coachErrorInvalidKey;
          break;
        case 'rate_limit':
          errorMsg = s.coachErrorRateLimit;
          break;
        case 'bad_request':
          errorMsg = s.coachErrorBadRequest;
          break;
        case 'service_unavailable':
          errorMsg = s.coachErrorServiceUnavailable;
          break;
        default:
          errorMsg = s.coachErrorGeneric;
      }
      setState(() {
        _messages.add(ChatMessage(
          role: 'system',
          content: errorMsg,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      // A1: Save conversation even on error — user message + error must persist.
      await _autoSaveConversation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          role: 'system',
          content: S.of(context)!.coachErrorConnection,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      // A1: Save conversation even on error — user message + error must persist.
      await _autoSaveConversation();
    }
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  LlmConfig _buildConfig() {
    final byok = context.read<ByokProvider>();
    if (!byok.isConfigured) return LlmConfig.defaultOpenAI;

    final LlmProvider provider;
    final String model;
    switch (byok.provider) {
      case 'claude':
        provider = LlmProvider.anthropic;
        model = 'claude-sonnet-4-5-20250929';
        break;
      case 'mistral':
        provider = LlmProvider.mistral;
        model = 'mistral-large-latest';
        break;
      default:
        provider = LlmProvider.openai;
        model = 'gpt-4o';
        break;
    }

    return LlmConfig(
      apiKey: byok.apiKey ?? '',
      provider: provider,
      model: model,
    );
  }

  CoachContext _buildCoachContext(CoachProfile profile, {MintUserState? mintState}) {
    final knownValues = <String, double>{};

    // FRI score
    try {
      final score = FinancialFitnessService.calculate(profile: profile);
      final g = score.global.toDouble();
      if (g.isFinite && g > 0) knownValues['fri_total'] = g;
    } catch (_) {}

    // Retirement projection
    try {
      final proj = ForecasterService.project(
        profile: profile,
        targetDate: profile.goalA.targetDate,
      );
      final cap = proj.base.capitalFinal;
      if (cap.isFinite && cap > 0) knownValues['capital_final'] = cap;
      // replacement_ratio is set below from MintUserState (0-1 ratio, not 0-100 %).
    } catch (_) {}

    // Enrich with MintUserState data for backend data lookup tools
    // (get_budget_status, get_retirement_projection, get_cross_pillar_analysis, get_cap_status)
    // T1-4: Use pre-captured mintState only — no context.read after await.
    try {
      if (mintState != null) {
        // Budget fields (consumed by get_budget_status)
        final snap = mintState.budgetSnapshot;
        if (snap != null) {
          final net = snap.present.monthlyNet;
          if (net.isFinite && net > 0) knownValues['monthly_income'] = net;
          final charges = snap.present.monthlyCharges;
          if (charges.isFinite && charges > 0) knownValues['monthly_expenses'] = charges;
        }

        // Retirement fields (consumed by get_retirement_projection)
        final rate = mintState.replacementRate;
        if (rate != null && rate.isFinite && rate > 0) {
          knownValues['replacement_ratio'] = rate / 100.0; // backend expects 0-1
        }

        // LPP capital
        final lpp = profile.prevoyance.avoirLppTotal;
        if (lpp != null && lpp > 0) knownValues['lpp_capital'] = lpp;

        // LPP buyback max (consumed by get_cross_pillar_analysis)
        final rachat = profile.prevoyance.lacuneRachatRestante;
        if (rachat > 0) knownValues['lpp_buyback_max'] = rachat;

        // 3a contribution (consumed by get_cross_pillar_analysis)
        final mensuel3a = profile.total3aMensuel;
        if (mensuel3a > 0) knownValues['annual_3a_contribution'] = mensuel3a * 12;

        // Confidence score
        final conf = mintState.confidenceScore;
        if (conf.isFinite && conf > 0) knownValues['confidence_score'] = conf;
      }
    } catch (_) {
      // Graceful: if MintStateProvider is not available, knownValues stays as-is.
    }

    // C2: Inject couple data so backend tools (get_couple_optimization) have context.
    try {
      final conj = profile.conjoint;
      if (conj != null) {
        knownValues['is_married'] = profile.etatCivil == CoachCivilStatus.marie ? 1.0 : 0.0;
        final conjAge = conj.age;
        if (conjAge != null && conjAge > 0) knownValues['conjoint_age'] = conjAge.toDouble();
        final conjSalary = conj.salaireBrutMensuel;
        if (conjSalary != null && conjSalary > 0) {
          knownValues['conjoint_salary'] = conjSalary;
        }
        // Pre-compute couple optimizer results
        try {
          final result = CoupleOptimizer.optimize(
            mainUser: profile,
            conjoint: conj,
          );
          if (result.avsCap != null) {
            knownValues['couple_avs_monthly'] = result.avsCap!.totalAfterCap;
          }
          if (result.marriagePenalty != null) {
            knownValues['couple_marriage_annual_delta'] = result.marriagePenalty!.annualDelta;
          }
        } catch (_) {
          // CoupleOptimizer failed — skip couple pre-computation
        }
      }
    } catch (_) {
      // Conjoint data not available — skip
    }

    return CoachContext(
      firstName: profile.firstName ?? 'utilisateur',
      age: profile.age,
      canton: profile.canton,
      knownValues: knownValues,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  ROUTE-TO-SCREEN ORCHESTRATION (S58)
  // ════════════════════════════════════════════════════════════

  /// Parses a `[ROUTE_TO_SCREEN:{...}]` marker embedded in a response text.
  ///
  /// When Claude (via BYOK) returns a structured tool_use block, the RAG
  /// backend encodes it as `[ROUTE_TO_SCREEN:{"intent":"...","confidence":0.9,
  /// "context_message":"..."}]` so the Flutter layer can parse it safely.
  ///
  /// Returns null if no marker is present (plain-text response).
  RouteToolPayload? _parseRouteToolUse(String text) {
    final markerStart = text.indexOf('[ROUTE_TO_SCREEN:');
    if (markerStart == -1) return null;
    final jsonStart = markerStart + '[ROUTE_TO_SCREEN:'.length;
    final markerEnd = text.indexOf(']', jsonStart);
    if (markerEnd == -1) return null;

    try {
      final raw = text.substring(jsonStart, markerEnd);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final intent = map['intent'] as String? ?? '';
      final confidence = (map['confidence'] as num?)?.toDouble() ?? 0.0;
      final contextMessage = map['context_message'] as String? ?? '';
      if (intent.isEmpty) return null;
      return RouteToolPayload(
        intent: intent,
        confidence: confidence,
        contextMessage: contextMessage,
      );
    } catch (_) {
      return null;
    }
  }

  /// Resolves a [RouteToolPayload] through [RoutePlanner] and, when routable,
  /// returns a new payload containing the resolved [RouteDecision].
  ///
  /// Returns null when the decision is [RouteAction.conversationOnly] or
  /// [RouteAction.askFirst] — in those cases no card is shown.
  RouteToolPayload? _resolveRoutePayload(RouteToolPayload raw) {
    if (_profile == null) return null;
    final planner = RoutePlanner(
      registry: const MintScreenRegistry(),
      profile: _profile!,
    );
    final decision = planner.plan(raw.intent, confidence: raw.confidence);
    switch (decision.action) {
      case RouteAction.openScreen:
      case RouteAction.openWithWarning:
        // Route is resolved — keep the payload (route is baked into decision).
        // We embed the resolved route and isPartial flag back into a new
        // payload by augmenting contextMessage with a special suffix the
        // renderer can read.  Since RouteToolPayload is immutable we encode
        // the extra data directly on the message.
        return _ResolvedRoutePayload(
          intent: raw.intent,
          confidence: raw.confidence,
          contextMessage: raw.contextMessage,
          resolvedRoute: decision.route!,
          isPartial: decision.action == RouteAction.openWithWarning,
          prefill: decision.prefill,
        );
      case RouteAction.askFirst:
        // Missing critical data — add a coach message naming the specific fields.
        // The user provides the data, profile updates, re-ask triggers re-route.
        if (mounted) {
          final l = S.of(context)!;
          final missing = decision.missingFields ?? [];
          // Map field keys to human-readable labels.
          final fieldLabels = {
            'salaireBrut': l.rcSalaryLabel,
            'age': l.rcAgeLabel,
            'canton': l.rcCantonLabel,
            'civilStatus': l.rcCivilStatusLabel,
            'employmentStatus': l.rcEmploymentStatusLabel,
            'netIncome': l.rcSalaryLabel,
            'avoirLpp': l.rcLppLabel,
            'rachatMaximum': l.rcLppLabel,
          };
          final missingLabels = missing
              .map((f) => fieldLabels[f] ?? f)
              .toSet() // deduplicate
              .join(', ');
          final message = missing.isNotEmpty
              ? '${l.routeSuggestionBlocked}\n$missingLabels'
              : l.routeSuggestionBlocked;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _messages.add(ChatMessage(
                role: 'assistant',
                content: message,
                timestamp: DateTime.now(),
                tier: ChatTier.fallback,
              ));
            });
            _scrollToBottom();
          });
        }
        return null;
      case RouteAction.conversationOnly:
        return null;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  GENERATE_DOCUMENT ORCHESTRATION
  // ════════════════════════════════════════════════════════════

  /// Parses a `[GENERATE_DOCUMENT:{...}]` marker embedded in a response text.
  ///
  /// Returns null if no marker is present (plain-text response).
  DocumentToolPayload? _parseDocumentToolUse(String text) {
    final markerStart = text.indexOf('[GENERATE_DOCUMENT:');
    if (markerStart == -1) return null;
    final jsonStart = markerStart + '[GENERATE_DOCUMENT:'.length;
    final markerEnd = text.indexOf(']', jsonStart);
    if (markerEnd == -1) return null;

    try {
      final raw = text.substring(jsonStart, markerEnd);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final docType = map['document_type'] as String? ?? '';
      final docContext = map['context'] as String? ?? '';
      if (docType.isEmpty) return null;
      return DocumentToolPayload(
        documentType: docType,
        context: docContext,
      );
    } catch (_) {
      return null;
    }
  }

  /// Generates a document from a [DocumentToolPayload] using the appropriate
  /// service, validates via [AgentValidationGate], and adds a document card
  /// message to the chat.
  ///
  /// Read-only posture: documents are GENERATED, never SUBMITTED.
  /// AgentValidationGate MUST approve before display.
  void _handleDocumentGeneration(DocumentToolPayload payload) {
    if (_profile == null || !mounted) return;
    final l = S.of(context)!;

    try {
      switch (payload.documentType) {
        case 'fiscal_declaration':
          final prefill = FormPrefillService.prepareTaxDeclaration(
            profile: _profile!,
            taxYear: DateTime.now().year,
            l: l,
          );
          // Validate through AgentValidationGate before display.
          if (!AgentValidationGate.validateFormPrefill(prefill)) return;
          _addDocumentMessage(formPrefill: prefill);

        case 'pension_fund_letter':
          final letter = LetterGenerationService.generatePensionFundRequest(
            profile: _profile!,
            l: l,
          );
          // Validate through AgentValidationGate before display.
          if (!AgentValidationGate.validateLetter(letter)) return;
          _addDocumentMessage(letter: letter);

        case 'lpp_buyback_request':
          final prefill = FormPrefillService.prepareLppBuyback(
            profile: _profile!,
            l: l,
          );
          // Validate through AgentValidationGate before display.
          if (!AgentValidationGate.validateFormPrefill(prefill)) return;
          _addDocumentMessage(formPrefill: prefill);

        default:
          debugPrint(
            '[CoachChat] Unknown document_type: ${payload.documentType}',
          );
      }
    } catch (e) {
      debugPrint('[CoachChat] Document generation failed: $e');
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: l.docCardValidationFailed,
            timestamp: DateTime.now(),
            tier: ChatTier.fallback,
          ));
        });
        _scrollToBottom();
      }
    }
  }

  /// Adds a document card message to the chat.
  void _addDocumentMessage({
    FormPrefill? formPrefill,
    GeneratedLetter? letter,
  }) {
    if (!mounted) return;
    // Build a DocumentToolPayload to store on the message.
    final docType = formPrefill != null
        ? formPrefill.formType
        : (letter != null ? letter.type : '');
    setState(() {
      _messages.add(ChatMessage(
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
        tier: ChatTier.byok,
        documentPayload: DocumentToolPayload(
          documentType: docType,
          context: '',
        ),
      ));
    });
    _scrollToBottom();
    // Store the generated output on the last message for rendering.
    _lastGeneratedForm = formPrefill;
    _lastGeneratedLetter = letter;
  }

  // ════════════════════════════════════════════════════════════
  //  T1-1: STRUCTURED TOOL_CALL HANDLERS
  // ════════════════════════════════════════════════════════════

  /// Process structured tool_calls from the backend response.
  ///
  /// Handles display tools (show_fact_card, show_budget_snapshot,
  /// show_score_gauge, ask_user_input) and write tools (set_goal,
  /// mark_step_completed, save_insight).
  Future<void> _processToolCalls(List<RagToolCall> toolCalls) async {
    for (final toolCall in toolCalls) {
      // Skip tools already handled via text markers.
      if (toolCall.name == 'route_to_screen' ||
          toolCall.name == 'generate_document') {
        continue;
      }
      try {
        await _handleSingleToolCall(toolCall);
      } catch (e) {
        debugPrint('[CoachChat] Tool call ${toolCall.name} failed: $e');
      }
    }
  }

  Future<void> _handleSingleToolCall(RagToolCall toolCall) async {
    switch (toolCall.name) {
      // ── Display tools → rendered inline via WidgetRenderer ────────
      case 'show_fact_card':
      case 'show_budget_snapshot':
      case 'show_score_gauge':
      case 'show_comparison_card':
      case 'show_retirement_comparison':
      case 'show_budget_overview':
      case 'show_choice_comparison':
      case 'show_pillar_breakdown':
        if (!mounted) return;
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: '',
            timestamp: DateTime.now(),
            tier: ChatTier.byok,
            richToolCalls: [toolCall],
          ));
        });
        _scrollToBottom();

      case 'ask_user_input':
        if (!mounted) return;
        final promptText = toolCall.input['prompt_text'] as String?
            ?? toolCall.input['message'] as String?
            ?? '';
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: promptText,
            timestamp: DateTime.now(),
            tier: ChatTier.byok,
            richToolCalls: [toolCall],
          ));
        });
        _scrollToBottom();

      // ── Write tools with confirmation guard (V3-1 audit) ──────
      case 'set_goal':
        final goalTag = toolCall.input['goal_intent_tag'] as String?;
        if (goalTag != null && _profile != null && mounted) {
          _pendingGoalTag = goalTag;
          setState(() {
            _messages.add(ChatMessage(
              role: 'assistant',
              content:
                  'Changer ton objectif vers\u00a0: $goalTag\u00a0?',
              timestamp: DateTime.now(),
              suggestedActions: const ['Confirmer', 'Annuler'],
              tier: ChatTier.byok,
            ));
          });
          _scrollToBottom();
        }

      case 'mark_step_completed':
        final stepId = toolCall.input['step_id'] as String?;
        if (stepId != null && mounted) {
          _pendingStepId = stepId;
          setState(() {
            _messages.add(ChatMessage(
              role: 'assistant',
              content:
                  'Marquer l\u2019\u00e9tape \u00ab\u202f$stepId\u202f\u00bb comme termin\u00e9e\u00a0?',
              timestamp: DateTime.now(),
              suggestedActions: const ['Confirmer', 'Annuler'],
              tier: ChatTier.byok,
            ));
          });
          _scrollToBottom();
        }

      case 'save_insight':
        final topic = toolCall.input['topic'] as String? ?? '';
        final summary = toolCall.input['summary'] as String? ?? '';
        final typeStr = toolCall.input['type'] as String? ?? 'fact';
        final insightType = InsightType.values.firstWhere(
          (t) => t.name == typeStr,
          orElse: () => InsightType.fact,
        );
        if (topic.isNotEmpty && summary.isNotEmpty) {
          await CoachMemoryService.saveInsight(
            CoachInsight(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              topic: topic,
              summary: summary,
              type: insightType,
              createdAt: DateTime.now(),
            ),
          );
          debugPrint('[CoachChat] Insight enregistr\u00e9: $topic');
        }
    }
  }

  /// Called when an inline input picker (from ask_user_input) is submitted.
  /// Updates the profile and sends the value as a user message.
  void _handleInlineInputSubmitted(String field, String value) {
    if (!mounted) return;
    // Update profile via provider
    final provider = context.read<CoachProfileProvider>();
    final profile = provider.profile;
    if (profile != null) {
      switch (field) {
        case 'age':
          final age = int.tryParse(value);
          if (age != null) {
            provider.updateProfile(profile.copyWith(
              dateOfBirth: DateTime(DateTime.now().year - age, 1, 1),
              updatedAt: DateTime.now(),
            ));
          }
        case 'salary':
        case 'salaireBrut':
          // Contract: ask_user_input(field_key='salaireBrut') sends ANNUAL gross salary.
          // ChatAmountInput displays "CHF" with no period suffix.
          // We convert to monthly for storage (profile.salaireBrutMensuel).
          final salary = double.tryParse(value);
          if (salary != null) {
            provider.updateProfile(profile.copyWith(
              salaireBrutMensuel: salary / 12,
              updatedAt: DateTime.now(),
            ));
          }
        case 'canton':
          provider.updateProfile(profile.copyWith(
            canton: value,
            updatedAt: DateTime.now(),
          ));
        case 'avoirLpp':
          final avoir = double.tryParse(value);
          if (avoir != null) {
            final prev = profile.prevoyance;
            provider.updateProfile(profile.copyWith(
              prevoyance: PrevoyanceProfile(
                anneesContribuees: prev.anneesContribuees,
                lacunesAVS: prev.lacunesAVS,
                renteAVSEstimeeMensuelle: prev.renteAVSEstimeeMensuelle,
                nomCaisse: prev.nomCaisse,
                avoirLppTotal: avoir,
                avoirLppObligatoire: prev.avoirLppObligatoire,
                avoirLppSurobligatoire: prev.avoirLppSurobligatoire,
                rachatMaximum: prev.rachatMaximum,
                rachatEffectue: prev.rachatEffectue,
                tauxConversion: prev.tauxConversion,
                tauxConversionSuroblig: prev.tauxConversionSuroblig,
                rendementCaisse: prev.rendementCaisse,
                salaireAssure: prev.salaireAssure,
                ramd: prev.ramd,
                nombre3a: prev.nombre3a,
                totalEpargne3a: prev.totalEpargne3a,
                comptes3a: prev.comptes3a,
                canContribute3a: prev.canContribute3a,
                librePassage: prev.librePassage,
              ),
              updatedAt: DateTime.now(),
            ));
          }
        case 'epargne3a':
          final epargne = double.tryParse(value);
          if (epargne != null) {
            final prev = profile.prevoyance;
            provider.updateProfile(profile.copyWith(
              prevoyance: PrevoyanceProfile(
                anneesContribuees: prev.anneesContribuees,
                lacunesAVS: prev.lacunesAVS,
                renteAVSEstimeeMensuelle: prev.renteAVSEstimeeMensuelle,
                nomCaisse: prev.nomCaisse,
                avoirLppTotal: prev.avoirLppTotal,
                avoirLppObligatoire: prev.avoirLppObligatoire,
                avoirLppSurobligatoire: prev.avoirLppSurobligatoire,
                rachatMaximum: prev.rachatMaximum,
                rachatEffectue: prev.rachatEffectue,
                tauxConversion: prev.tauxConversion,
                tauxConversionSuroblig: prev.tauxConversionSuroblig,
                rendementCaisse: prev.rendementCaisse,
                salaireAssure: prev.salaireAssure,
                ramd: prev.ramd,
                nombre3a: prev.nombre3a,
                totalEpargne3a: epargne,
                comptes3a: prev.comptes3a,
                canContribute3a: prev.canContribute3a,
                librePassage: prev.librePassage,
              ),
              updatedAt: DateTime.now(),
            ));
          }
        default:
          break;
      }
    }
    // Send as user message to continue the conversation
    _sendMessage(value);
  }

  /// Called when the user returns from a screen opened via [RouteSuggestionCard].
  ///
  /// ReturnContract V2: reacts differently per [ScreenOutcome] —
  /// completed / abandoned / changedInputs each produce a distinct coach
  /// message and a distinct CapMemory update.
  void _handleRouteReturn(ScreenOutcome outcome) {
    if (!mounted) return;
    final s = S.of(context)!;

    // ── SEQUENCE DEDUP: realtime canonical, route-return fallback ──
    //
    // Case 1: Realtime handled this exact step → skip entirely (no
    // sequence processing, no legacy side effects, no double message).
    // Case 2: _activeSequenceStepKey set (we're in a guided sequence
    // but realtime hasn't fired yet) → delegate to sequence handler,
    // skip legacy side effects.
    // Case 3: Neither → normal legacy flow.
    //
    if (_lastRealtimeHandledStepKey != null &&
        (_activeSequenceStepKey == null ||
         _lastRealtimeHandledStepKey == _activeSequenceStepKey)) {
      // Case 1: realtime already consumed this step.
      _lastRealtimeHandledStepKey = null;
      _activeSequenceStepKey = null;
      _scrollToBottom();
      return;
    }
    if (_activeSequenceStepKey != null) {
      // Case 2: we're in a guided sequence, realtime hasn't consumed yet.
      // Delegate to sequence handler, skip legacy entirely.
      _activeSequenceStepKey = null;
      SequenceChatHandler.handleStepReturn(outcome).then((result) {
        if (!mounted || result == null) return;
        _renderSequenceAction(result);
      }).catchError((_) {});
      _scrollToBottom();
      return;
    }

    // Case 3: no sequence active → normal legacy flow.
    // Resolve the last routed intent for CapMemory keying.
    final lastRouted = _messages.reversed
        .where((m) => m.hasRoutePayload)
        .map((m) => m.routePayload!.intent)
        .firstOrNull;

    switch (outcome) {
      case ScreenOutcome.completed:
        // Mark action completed in CapMemory — closes the boucle vivante.
        if (lastRouted != null) {
          CapMemoryStore.load().then((mem) async {
            await CapMemoryStore.markCompleted(mem, 'visited_$lastRouted');
          }).catchError((_) {});
        }
        // Save cross-session insight.
        CoachMemoryService.saveInsight(CoachInsight(
          id: 'route_completed_${DateTime.now().millisecondsSinceEpoch}',
          createdAt: DateTime.now(),
          topic: 'screen_visit',
          summary: 'Completed screen from coach suggestion',
          type: InsightType.fact,
        )).catchError((_) {});
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: s.routeReturnCompleted,
            timestamp: DateTime.now(),
            tier: ChatTier.fallback,
          ));
        });
        // Emotional canvas: pulse sage green for milestone completion.
        _triggerMilestonePulse();

      case ScreenOutcome.abandoned:
        // Record abandoned flow in CapMemory so engine avoids re-proposing too soon.
        if (lastRouted != null) {
          CapMemoryStore.load().then((mem) async {
            await CapMemoryStore.markAbandoned(
              mem,
              'visited_$lastRouted',
              frictionContext: 'flow_abandoned',
            );
          }).catchError((_) {});
        }
        // Save cross-session insight about abandonment.
        CoachMemoryService.saveInsight(CoachInsight(
          id: 'route_abandoned_${DateTime.now().millisecondsSinceEpoch}',
          createdAt: DateTime.now(),
          topic: 'screen_visit',
          summary: 'Abandoned screen from coach suggestion',
          type: InsightType.fact,
        )).catchError((_) {});
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: s.routeReturnAbandoned,
            timestamp: DateTime.now(),
            tier: ChatTier.fallback,
          ));
        });

      case ScreenOutcome.changedInputs:
        // Acknowledge the profile update and trigger projection recompute.
        if (lastRouted != null) {
          CapMemoryStore.load().then((mem) async {
            await CapMemoryStore.markCompleted(mem, 'visited_$lastRouted');
          }).catchError((_) {});
        }
        // Save cross-session insight about data update.
        CoachMemoryService.saveInsight(CoachInsight(
          id: 'route_changed_${DateTime.now().millisecondsSinceEpoch}',
          createdAt: DateTime.now(),
          topic: 'profile_update',
          summary: 'User changed inputs on screen from coach suggestion',
          type: InsightType.fact,
        )).catchError((_) {});
        // The profile provider already notified listeners when the user
        // updated data on the target screen. No explicit refresh needed here.
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: s.routeReturnChanged,
            timestamp: DateTime.now(),
            tier: ChatTier.fallback,
          ));
        });
    }

    _scrollToBottom();
  }

  // ════════════════════════════════════════════════════════════════
  //  REALTIME RETURN CONTRACT — immediate coach reaction
  // ════════════════════════════════════════════════════════════════

  /// Called via stream when ANY screen emits a ScreenReturn — even if the user
  /// navigated there without coach suggestion (direct explore, deep link).
  ///
  /// Builds a context-rich system message from the real simulation data and
  /// sends it to the LLM so the coach can react immediately.
  void _onRealtimeScreenReturn(ScreenReturn ret) {
    if (!mounted) return;

    // ── SEQUENCE MODE (canonical path): bypass debounce, delegate ──
    // Per RFC §6.2: realtime is canonical because it carries the full
    // ScreenReturn with stepOutputs + updatedFields. No debounce for
    // sequence transitions — they should feel immediate.
    SequenceChatHandler.handleRealtimeReturn(ret).then((result) {
      if (!mounted || result == null) return;
      // Record the step key for dedup — _handleRouteReturn will skip
      // if it sees the same key (avoids double consumption).
      final run = result.updatedRun;
      final stepId = run.activeStepId ??
          run.stepStates.entries
              .lastWhere((e) => e.value == StepRunState.completed,
                  orElse: () => const MapEntry('', StepRunState.pending))
              .key;
      _lastRealtimeHandledStepKey = '${run.runId}_$stepId';
      _renderSequenceAction(result);
    }).catchError((_) {});
    // Don't return — debounce below still runs for non-sequence usage.
    // If sequence consumed the event, the debounced message is harmless.

    // Debounce: screens like affordability emit on every slider change.
    // We only react to the LAST event after 2 seconds of quiet.
    _lastPendingReturn = ret;
    _screenReturnDebounce?.cancel();
    _screenReturnDebounce = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_isBusy) return; // Don't interrupt an ongoing LLM call.
      final pending = _lastPendingReturn;
      if (pending == null) return;
      _lastPendingReturn = null;

      // Build a context-rich summary from the real simulation data.
      final buf = StringBuffer();
      buf.write('Je viens de simuler ${pending.route}');
      if (pending.updatedFields != null && pending.updatedFields!.isNotEmpty) {
        final highlights = pending.updatedFields!.entries
            .take(3)
            .map((e) => '${e.key}: ${e.value}')
            .join(', ');
        buf.write(' ($highlights)');
      }
      buf.write('.');

      _sendMessage(buf.toString());
    });
  }

  /// Render the result of a guided sequence step into the chat.
  ///
  /// Called from _handleRouteReturn ONLY when _isInGuidedSequence is true.
  /// Adds a coach message describing the next action (advance, complete, etc.).
  void _renderSequenceAction(SequenceHandlerResult result) {
    if (!mounted) return;

    final String message;
    switch (result.action) {
      case AdvanceAction(:final progressLabel, :final nextStep):
        message = '\u00c9tape $progressLabel termin\u00e9e. '
            'Pr\u00eat pour la suite\u00a0?';
        // Pre-set the sync guard for the NEXT step's route return.
        // This allows _handleRouteReturn to bypass legacy side effects
        // synchronously when the user returns from the next step.
        _activeSequenceStepKey =
            '${result.updatedRun.runId}_${nextStep.id}';
      case CompleteAction():
        message = 'Parcours termin\u00e9\u00a0! '
            'Toutes les \u00e9tapes sont compl\u00e8tes.';
      case PauseAction():
        message = 'On met le parcours en pause. '
            'Tu pourras reprendre quand tu veux.';
      case SkipAction():
        message = 'On passe cette \u00e9tape pour le moment.';
      case RetryAction():
        message = 'Pas de souci. On peut r\u00e9essayer cette \u00e9tape.';
      case ReEvaluateAction():
        message = 'Tes donn\u00e9es ont chang\u00e9. '
            'Je recalcule les \u00e9tapes concern\u00e9es.';
    }

    setState(() {
      _messages.add(ChatMessage(
        role: 'assistant',
        content: message,
        timestamp: DateTime.now(),
        tier: ChatTier.fallback,
      ));
    });
    _scrollToBottom();
    // Update sequence cache when run ends
    if (result.action is CompleteAction) {
      _triggerMilestonePulse();
    }
  }

  /// Prepend a visible memory reference phrase to a coach response.
  ///
  /// When [ref] is non-null and resolution succeeds, returns:
  ///   "{memoryPhrase}\n\n{responseText}"
  ///
  /// Returns [responseText] unchanged when:
  ///   - [ref] is null (no relevant past insight found).
  ///   - Localizations are unavailable.
  ///   - Resolution throws unexpectedly (graceful degradation).
  String _prependMemoryRef(String responseText, MemoryReference? ref) {
    if (ref == null) return responseText;
    try {
      final s = S.of(context)!;
      final phrase = MemoryReferenceService.resolve(
        ref,
        onTopic: (days, topic) => s.memoryRefTopic(days, topic),
        onGoal: (goal) => s.memoryRefGoal(goal),
        onScreen: (screen) => s.memoryRefScreenVisit(screen),
      );
      if (phrase.isEmpty) return responseText;
      return '$phrase\n\n$responseText';
    } catch (_) {
      return responseText;
    }
  }

  List<String> _inferSuggestedActions(String userMessage) {
    final s = S.of(context)!;
    final lower = userMessage.toLowerCase();
    if (lower.contains('3a')) {
      return [s.coachSuggestSimulate3a, s.coachSuggestView3a];
    }
    if (lower.contains('lpp') || lower.contains('rachat')) {
      return [s.coachSuggestSimulateLpp, s.coachSuggestUnderstandLpp];
    }
    if (lower.contains('retraite')) {
      return [s.coachSuggestTrajectory, s.coachSuggestScenarios];
    }
    if (lower.contains('impot') || lower.contains('fiscal')) {
      return [s.coachSuggestDeductions, s.coachSuggestTaxImpact];
    }
    return [s.coachSuggestFitness, s.coachSuggestRetirement];
  }

  /// Map suggested action labels to direct navigation routes.
  /// Returns null if the action should be sent as a chat message instead.
  String? _routeForAction(String action) {
    final s = S.of(context)!;
    final routes = <String, String>{
      // 3a
      s.coachSuggestSimulate3a: '/pilier-3a',
      s.coachSuggestView3a: '/pilier-3a',
      // LPP
      s.coachSuggestSimulateLpp: '/rachat-lpp',
      s.coachSuggestUnderstandLpp: '/rachat-lpp',
      // Retraite
      s.coachSuggestTrajectory: '/retraite',
      s.coachSuggestScenarios: '/rente-vs-capital',
      // Fiscal
      s.coachSuggestDeductions: '/fiscal',
      s.coachSuggestTaxImpact: '/fiscal',
      // Default
      s.coachSuggestFitness: '/confidence',
      s.coachSuggestRetirement: '/retraite',
    };
    if (routes.containsKey(action)) return routes[action];

    // Keyword fallback for greeting prompts (suggestedPrompts)
    final lower = action.toLowerCase();
    if (lower.contains('retraite') || lower.contains('partir')) {
      return '/retraite';
    }
    if (lower.contains('rente') || lower.contains('capital')) {
      return '/rente-vs-capital';
    }
    if (lower.contains('3a') || lower.contains('pilier')) {
      return '/pilier-3a';
    }
    if (lower.contains('lpp') || lower.contains('rachat')) {
      return '/rachat-lpp';
    }
    if (lower.contains('impot') || lower.contains('fiscal')) {
      return '/fiscal';
    }
    // No route → send as chat message
    return null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _exportConversation() async {
    final highlights = <Map<String, String>>[];
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].isUser &&
          i + 1 < _messages.length &&
          _messages[i + 1].isAssistant) {
        highlights.add({
          'question': _messages[i].content,
          'answer': _messages[i + 1].content,
        });
      }
    }
    final limited = highlights.length > 5
        ? highlights.sublist(highlights.length - 5)
        : highlights;

    final sources = <String>{};
    for (final msg in _messages) {
      for (final src in msg.sources) {
        sources.add(
            '${src.title}${src.section.isNotEmpty ? ' \u2014 ${src.section}' : ''}');
      }
    }

    int fitnessScore = 0;
    try {
      final score = FinancialFitnessService.calculate(profile: _profile!);
      fitnessScore = score.global;
    } catch (_) {}

    await PdfService.generateDecisionReportPdf(
      firstName: _profile!.firstName ?? 'Utilisateur',
      canton: _profile!.canton,
      fitnessScore: fitnessScore,
      conversationHighlights: limited,
      legalSources: sources.toList(),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  EMOTIONAL CANVAS (UX P3)
  // ════════════════════════════════════════════════════════════

  /// Detect conversation topic from recent messages and update canvas tint.
  void _updateCanvasMood() {
    final recentTexts = _messages
        .where((m) => !m.isSystem)
        .toList()
        .reversed
        .take(3)
        .map((m) => m.content.toLowerCase())
        .join(' ');

    _CanvasMood detected = _CanvasMood.neutral;

    const stressKeywords = [
      'dette', 'dettes', 'ch\u00f4mage', 'chomage', 'divorce',
      'licenci', 'perte', 'crise', 'stress', 'difficult',
    ];
    for (final kw in stressKeywords) {
      if (recentTexts.contains(kw)) {
        detected = _CanvasMood.stress;
        break;
      }
    }

    if (detected == _CanvasMood.neutral) {
      const retirementKeywords = [
        'retraite', 'pension', '65 ans', 'avs', 'lpp',
        'rente', 'pilier', '2e pilier', '3a',
      ];
      for (final kw in retirementKeywords) {
        if (recentTexts.contains(kw)) {
          detected = _CanvasMood.retirement;
          break;
        }
      }
    }

    if (detected != _currentMood) {
      _currentMood = detected;
      _transitionCanvas(detected);
    }
  }

  void _transitionCanvas(_CanvasMood mood) {
    final Color targetColor;
    final Duration duration;

    switch (mood) {
      case _CanvasMood.retirement:
        targetColor = MintColors.porcelaine.withValues(alpha: 0.25);
        duration = const Duration(milliseconds: 800);
      case _CanvasMood.stress:
        targetColor = MintColors.pecheDouce.withValues(alpha: 0.08);
        duration = const Duration(milliseconds: 1200);
      case _CanvasMood.neutral:
        targetColor = MintColors.white;
        duration = const Duration(milliseconds: 800);
      case _CanvasMood.milestone:
      case _CanvasMood.victory:
      case _CanvasMood.discovery:
        return;
    }

    _canvasColorBegin = _canvasAnimation.value ?? MintColors.white;
    _canvasColorEnd = targetColor;
    _canvasAnimController
      ..duration = duration
      ..reset();
    _canvasAnimation = ColorTween(
      begin: _canvasColorBegin,
      end: _canvasColorEnd,
    ).animate(CurvedAnimation(
      parent: _canvasAnimController,
      curve: Curves.easeInOut,
    ));
    _canvasAnimController.forward();
  }

  void _triggerMilestonePulse() {
    if (_milestonePulsing) return;
    _milestonePulsing = true;

    _milestonePulseController?.dispose();
    _milestonePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    final returnColor = _canvasColorEnd;

    _canvasColorBegin = _canvasAnimation.value ?? MintColors.white;
    _canvasColorEnd = MintColors.saugeClaire.withValues(alpha: 0.10);
    _canvasAnimController
      ..duration = const Duration(milliseconds: 600)
      ..reset();
    _canvasAnimation = ColorTween(
      begin: _canvasColorBegin,
      end: _canvasColorEnd,
    ).animate(CurvedAnimation(
      parent: _canvasAnimController,
      curve: Curves.easeInOut,
    ));
    _canvasAnimController.forward();

    _milestonePulseController!.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _canvasColorBegin = MintColors.saugeClaire.withValues(alpha: 0.10);
        _canvasColorEnd = returnColor;
        _canvasAnimController
          ..duration = const Duration(milliseconds: 800)
          ..reset();
        _canvasAnimation = ColorTween(
          begin: _canvasColorBegin,
          end: _canvasColorEnd,
        ).animate(CurvedAnimation(
          parent: _canvasAnimController,
          curve: Curves.easeInOut,
        ));
        _canvasAnimController.forward();
        _milestonePulsing = false;
      }
    });
    _milestonePulseController!.forward();
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (!_hasProfile) {
      return _buildEmptyState(context);
    }

    return Scaffold(
      backgroundColor: MintColors.background,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: Column(
        children: [
          _buildAppBar(context),
          MintEntrance(child: _buildDisclaimer()),
          if (_greetingExpanded && _greetingLine2 != null)
            _buildGreetingCard(),
          Expanded(
            child: MintEntrance(delay: const Duration(milliseconds: 100), child: AnimatedBuilder(
              animation: _canvasAnimController,
              builder: (context, child) {
                return ColoredBox(
                  color: _canvasAnimation.value ?? MintColors.white,
                  child: child,
                );
              },
              child: _buildMessageList(),
            ),
          )),
          if (_isLoading) _buildLoadingIndicator(),
          MintEntrance(delay: const Duration(milliseconds: 200), child: _buildInputBar()),
        ],
      ))),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: Text(
          s.coachTitle,
          style: MintTextStyles.titleMedium(color: MintColors.white)
              .copyWith(fontWeight: FontWeight.w700),
        ),
        backgroundColor: MintColors.primary,
        foregroundColor: MintColors.white,
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MintSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 64,
                  color: MintColors.textMuted.withValues(alpha: 0.4)),
              const SizedBox(height: MintSpacing.md),
              Text(
                s.coachEmptyStateMessage,
                style: MintTextStyles.bodyLarge(
                    color: MintColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MintSpacing.md),
              FilledButton(
                onPressed: () => context.go('/onboarding/quick'),
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.primary,
                ),
                child: Text(
                  s.coachEmptyStateButton,
                  style: MintTextStyles.titleMedium(
                      color: MintColors.white),
                ),
              ),
            ],
          ),
        ),
      ))),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  APP BAR
  // ════════════════════════════════════════════════════════════

  Widget _buildAppBar(BuildContext context) {
    final tier = _currentTier();
    final s = S.of(context)!;
    return Container(
      decoration: const BoxDecoration(color: MintColors.primary),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md, vertical: MintSpacing.sm + 4),
          child: Row(
            children: [
              if (!widget.isEmbeddedInTab) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: MintColors.white),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: MintSpacing.sm),
              ] else
                const SizedBox(width: MintSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.coachTitle,
                      style: MintTextStyles.titleMedium(color: MintColors.white)
                          .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2), // tight coupling
                    _buildTierSubtitle(tier),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.history, color: MintColors.white),
                tooltip: s.coachTooltipHistory,
                onPressed: () async {
                  final router = GoRouter.of(context);
                  await _autoSaveConversation();
                  if (mounted) router.push('/coach/history');
                },
              ),
              if (_messages.any((m) => m.isUser))
                IconButton(
                  icon: const Icon(Icons.share, color: MintColors.white),
                  tooltip: s.coachTooltipExport,
                  onPressed: _exportConversation,
                ),
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: MintColors.white),
                tooltip: s.coachTooltipSettings,
                onPressed: () => context.push('/profile/byok'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierSubtitle(ChatTier tier) {
    final s = S.of(context)!;

    // S64: circuit breaker status takes precedence over tier label.
    if (_allProvidersDown) {
      return Row(
        children: [
          Icon(Icons.cloud_off,
              size: 12, color: MintColors.warning.withValues(alpha: 0.9)),
          const SizedBox(width: MintSpacing.xs),
          Text(
            s.llmAllProvidersDown,
            style: MintTextStyles.labelSmall(
              color: MintColors.warning.withValues(alpha: 0.9),
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ],
      );
    }

    if (_primaryCircuitOpen) {
      return Row(
        children: [
          Icon(Icons.warning_amber_outlined,
              size: 12, color: MintColors.warning.withValues(alpha: 0.9)),
          const SizedBox(width: MintSpacing.xs),
          Text(
            s.llmCircuitOpen,
            style: MintTextStyles.labelSmall(
              color: MintColors.warning.withValues(alpha: 0.9),
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ],
      );
    }

    final String label;
    final IconData icon;
    switch (tier) {
      case ChatTier.slm:
        label = s.coachTierSlm;
        icon = Icons.smartphone;
        break;
      case ChatTier.byok:
        label = s.coachTierByok;
        icon = Icons.cloud_outlined;
        break;
      default:
        label = s.coachTierFallback;
        icon = Icons.wifi_off;
        break;
    }
    return Row(
      children: [
        Icon(icon, size: 12, color: MintColors.white.withValues(alpha: 0.7)),
        const SizedBox(width: MintSpacing.xs),
        Text(
          label,
          style: MintTextStyles.labelSmall(
            color: MintColors.white.withValues(alpha: 0.7),
          ).copyWith(fontSize: 12, fontWeight: FontWeight.w400),
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.md, vertical: MintSpacing.sm),
      color: MintColors.coachBubble,
      child: Text(
        S.of(context)!.coachDisclaimer,
        style: MintTextStyles.micro(color: MintColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  GREETING NARRATIVE CANVAS
  // ════════════════════════════════════════════════════════════

  Widget _buildGreetingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        MintSpacing.lg, MintSpacing.md, MintSpacing.lg, MintSpacing.md,
      ),
      color: MintColors.craie,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greetingLine1 ?? '',
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            _greetingLine2 ?? '',
            style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (_greetingSuggestions != null &&
              _greetingSuggestions!.isNotEmpty) ...[
            const SizedBox(height: MintSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _greetingSuggestions!.map((action) {
                return ActionChip(
                  label: Text(
                    action,
                    style: MintTextStyles.labelSmall(
                        color: MintColors.coachAccent),
                  ),
                  backgroundColor: MintColors.white,
                  side: BorderSide(
                    color: MintColors.coachAccent.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: () {
                    final route = _routeForAction(action);
                    if (route != null) {
                      context.push(route);
                    } else {
                      _sendMessage(action);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  MESSAGE LIST
  // ════════════════════════════════════════════════════════════

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.md, vertical: MintSpacing.sm + 4),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final Widget child;
        if (msg.isSystem) {
          child = _buildSystemMessage(msg);
        } else if (msg.isUser) {
          child = Semantics(
            label: S.of(context)!.coachUserMessage,
            child: _buildUserBubble(msg),
          );
        } else {
          child = Semantics(
            label: S.of(context)!.coachCoachMessage,
            child: _buildCoachBubble(msg),
          );
        }
        // T2-1: Only animate the last 3 messages for performance.
        if (index >= _messages.length - 3) {
          return TweenAnimationBuilder<double>(
            key: ValueKey('msg_$index'),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (context, value, aChild) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: aChild,
                ),
              );
            },
            child: child,
          );
        }
        return child;
      },
    );
  }

  Widget _buildUserBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: MintSpacing.xxl),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.md, vertical: MintSpacing.sm + 4),
              decoration: BoxDecoration(
                color: MintColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                msg.content,
                style: MintTextStyles.bodyMedium(color: MintColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachBubble(ChatMessage msg) {
    final isStreamingThis =
        _isStreaming && msg == _messages.last && msg.tier == ChatTier.slm;

    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coach avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: MintColors.coachBubble,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: MintColors.border.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'M',
                  style: MintTextStyles.titleMedium(
                    color: MintColors.coachAccent,
                  ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.md, vertical: MintSpacing.sm + 4),
                  decoration: BoxDecoration(
                    color: MintColors.coachBubble,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._buildBubbleContent(msg, isStreamingThis),
                      // Streaming cursor
                      if (isStreamingThis) ...[
                        const SizedBox(height: MintSpacing.xs),
                        SizedBox(
                          width: 8,
                          height: 14,
                          child: _buildCursor(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: MintSpacing.xxl),
            ],
          ),
          // Tier badge + optional TTS button (S63)
          if (!isStreamingThis && msg.tier != ChatTier.none) ...[
            const SizedBox(height: MintSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTierBadge(msg.tier),
                  if (_voiceTtsAvailable && msg.content.isNotEmpty) ...[
                    const SizedBox(width: MintSpacing.xs),
                    VoiceOutputButton(
                      voiceService: _voiceService,
                      text: msg.content,
                    ),
                  ],
                ],
              ),
            ),
          ],
          // Sources
          if (msg.sources.isNotEmpty) ...[
            const SizedBox(height: MintSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 40, right: 48),
              child: _buildSourcesSection(msg.sources),
            ),
          ],
          // Disclaimers (from RAG backend)
          if (msg.disclaimers.isNotEmpty) ...[
            const SizedBox(height: MintSpacing.sm - 2),
            Padding(
              padding: const EdgeInsets.only(left: 40, right: 48),
              child: _buildDisclaimersSection(msg.disclaimers),
            ),
          ],
          // Response Cards (Phase 1 — inline strip)
          if (!isStreamingThis && msg.responseCards.isNotEmpty) ...[
            const SizedBox(height: MintSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: ResponseCardStrip(cards: msg.responseCards),
            ),
          ],
          // Route Suggestion Card — S58 route_to_screen tool_use
          if (!isStreamingThis && msg.hasRoutePayload) ...[
            const SizedBox(height: MintSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 40, right: 8),
              child: _buildRouteSuggestionCard(msg.routePayload!),
            ),
          ],
          // Document Card — generate_document tool_use (Agent Autonome)
          if (!isStreamingThis && msg.hasDocumentPayload) ...[
            const SizedBox(height: MintSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 40, right: 8),
              child: _buildDocumentCard(),
            ),
          ],
          // Rich tool calls — inline widgets via WidgetRenderer
          if (!isStreamingThis && msg.hasRichToolCalls) ...[
            const SizedBox(height: MintSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 40, right: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: msg.richToolCalls.map((tc) {
                  try {
                    return WidgetRenderer.build(
                      context,
                      tc,
                      onInputSubmitted: _handleInlineInputSubmitted,
                    ) ?? const SizedBox.shrink();
                  } catch (e) {
                    debugPrint('[CoachChat] WidgetRenderer error: $e');
                    return const SizedBox.shrink();
                  }
                }).toList(),
              ),
            ),
          ],
          // Suggested actions
          if (!isStreamingThis &&
              msg.suggestedActions != null &&
              msg.suggestedActions!.isNotEmpty) ...[
            const SizedBox(height: MintSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: msg.suggestedActions!.map((action) {
                  return ActionChip(
                    label: Text(
                      action,
                      style: MintTextStyles.labelSmall(
                          color: MintColors.ardoise),
                    ),
                    backgroundColor: MintColors.porcelaine,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () {
                      final route = _routeForAction(action);
                      if (route != null) {
                        context.push(route);
                      } else {
                        _sendMessage(action);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Splits coach bubble content into optional memory-reference block + main text.
  ///
  /// When the content contains a memory reference (prepended by [_prependMemoryRef]),
  /// the first paragraph before `\n\n` is rendered with a peach left border.
  List<Widget> _buildBubbleContent(ChatMessage msg, bool isStreamingThis) {
    final text = msg.content.isEmpty && isStreamingThis ? '...' : msg.content;

    // Detect memory reference: pattern is "{memoryPhrase}\n\n{response}".
    // Memory phrases always contain a known marker pattern from ARB keys.
    final splitIndex = text.indexOf('\n\n');
    if (splitIndex > 0 && splitIndex < text.length - 2) {
      final firstPart = text.substring(0, splitIndex);
      // Heuristic: memory refs contain time markers or goal markers.
      final isMemoryRef = firstPart.contains('jours') ||
          firstPart.contains('objectif') ||
          firstPart.contains('dernière fois');
      if (isMemoryRef) {
        final mainText = text.substring(splitIndex + 2);
        return [
          Container(
            padding: const EdgeInsets.only(
              left: MintSpacing.sm,
              top: MintSpacing.xs,
              bottom: MintSpacing.xs,
            ),
            decoration: BoxDecoration(
              border: const Border(
                left: BorderSide(
                  color: MintColors.pecheDouce,
                  width: 3,
                ),
              ),
              color: MintColors.pecheDouce.withValues(alpha: 0.08),
            ),
            child: Text(
              firstPart,
              style: MintTextStyles.bodySmall(color: MintColors.ardoise)
                  .copyWith(fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            mainText,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          ),
        ];
      }
    }

    // Default: plain text, no memory reference.
    return [
      Text(
        text,
        style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
      ),
    ];
  }

  Widget _buildCursor() {
    return const _BlinkingCursor();
  }

  Widget _buildTierBadge(ChatTier tier) {
    final s = S.of(context)!;
    final String label;
    final IconData icon;
    final Color color;
    switch (tier) {
      case ChatTier.slm:
        label = s.coachBadgeSlm;
        icon = Icons.smartphone;
        color = MintColors.success;
        break;
      case ChatTier.byok:
        label = s.coachBadgeByok;
        icon = Icons.cloud_outlined;
        color = MintColors.info;
        break;
      case ChatTier.fallback:
        label = s.coachBadgeFallback;
        icon = Icons.wifi_off;
        color = MintColors.textMuted;
        break;
      default:
        return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 3),
        Text(
          label,
          style: MintTextStyles.micro(
            color: color.withValues(alpha: 0.7),
          ).copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  /// Builds the [RouteSuggestionCard] for a message carrying a route payload.
  ///
  /// Casts [payload] to [_ResolvedRoutePayload] to get the route + isPartial
  /// fields produced by [_resolveRoutePayload].
  Widget _buildRouteSuggestionCard(RouteToolPayload payload) {
    if (payload is! _ResolvedRoutePayload) {
      return const SizedBox.shrink();
    }
    return RouteSuggestionCard(
      contextMessage: payload.contextMessage,
      route: payload.resolvedRoute,
      isPartial: payload.isPartial,
      prefill: payload.prefill,
      onReturn: _handleRouteReturn,
      profileHashFn: () {
        final profile = context.read<CoachProfileProvider>().profile;
        return profile?.hashCode.toString() ?? '';
      },
    );
  }

  /// Builds a [DocumentCard] for the last generated document.
  ///
  /// Reads from [_lastGeneratedForm] or [_lastGeneratedLetter] which are
  /// populated by [_handleDocumentGeneration] before this method is called.
  Widget _buildDocumentCard() {
    if (_lastGeneratedForm != null) {
      return DocumentCard(formPrefill: _lastGeneratedForm);
    }
    if (_lastGeneratedLetter != null) {
      return DocumentCard(letter: _lastGeneratedLetter);
    }
    return const SizedBox.shrink();
  }

  Widget _buildSystemMessage(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.sm),
      child: Center(
        child: Text(
          msg.content,
          style: MintTextStyles.labelSmall(color: MintColors.textMuted)
              .copyWith(fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    final loadingText = S.of(context)!.coachLoading;
    return Semantics(
      label: loadingText,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.md, vertical: MintSpacing.xs),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: MintColors.coachBubble,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: MintColors.border.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'M',
                style: MintTextStyles.titleMedium(
                  color: MintColors.coachAccent,
                ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: MintSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.md, vertical: MintSpacing.sm + 4),
              decoration: BoxDecoration(
                color: MintColors.coachBubble,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const _BreathingDots(),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SOURCES & DISCLAIMERS
  // ════════════════════════════════════════════════════════════

  Widget _buildSourcesSection(List<RagSource> sources) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.coachSources,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: MintColors.info.withValues(alpha: 0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: MintSpacing.xs),
          for (final source in sources)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Semantics(
                label: source.title,
                button: true,
                child: InkWell(
                  onTap: () => _navigateToSource(source),
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined,
                          size: 13,
                          color: MintColors.info.withValues(alpha: 0.7)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${source.title}${source.section.isNotEmpty ? ' \u2014 ${source.section}' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: MintColors.info,
                            decoration: TextDecoration.underline,
                            decorationColor:
                                MintColors.info.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDisclaimersSection(List<String> disclaimers) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 14, color: MintColors.warning.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              disclaimers.join('\n'),
              style: TextStyle(
                fontSize: 11,
                color: MintColors.warning.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToSource(RagSource source) {
    final file = source.file.toLowerCase();
    if (file.contains('3a') ||
        file.contains('opp3') ||
        file.contains('pilier')) {
      context.push('/pilier-3a');
    } else if (file.contains('lpp') || file.contains('pension')) {
      context.push('/rente-vs-capital');
    } else if (file.contains('lifd') || file.contains('fiscal')) {
      context.push('/fiscal');
    } else if (file.contains('lavs') || file.contains('avs')) {
      context.push('/retraite');
    } else if (file.contains('budget')) {
      context.push('/budget');
    } else {
      context.push('/education/hub');
    }
  }

  // ════════════════════════════════════════════════════════════
  //  INPUT BAR
  // ════════════════════════════════════════════════════════════

  Widget _buildInputBar() {
    final s = S.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: MintColors.background,
        border: Border(
          top: BorderSide(
            color: MintColors.border.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.sm + 4, vertical: MintSpacing.sm),
          child: Row(
            children: [
              // Lightning Menu bolt button (long-press for life events)
              GestureDetector(
                onLongPress: _isStreaming ? null : _showLifeEventSheet,
                child: IconButton(
                  icon: const Icon(Icons.bolt_rounded,
                      color: MintColors.coachAccent, size: 22),
                  tooltip: s.lightningMenuTitle,
                  onPressed: _isStreaming ? null : _showLightningMenu,
                ),
              ),
              Expanded(
                child: Semantics(
                  textField: true,
                  label: s.coachInputHint,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.send,
                    maxLines: null,
                    enabled: !_isStreaming,
                    style: MintTextStyles.bodyMedium(
                        color: MintColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: s.coachInputHint,
                      hintStyle: MintTextStyles.bodyMedium(
                          color: MintColors.textMuted),
                      filled: true,
                      fillColor: MintColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: MintSpacing.md,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: MintColors.border.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: MintColors.border.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: MintColors.coachAccent,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (text) {
                      // Typed submit → deactivate voice mode.
                      _voiceModeActive = false;
                      _sendMessage(text);
                    },
                  ),
                ),
              ),
              // Voice input button (S63) — shown only when STT is available.
              if (_voiceSttAvailable) ...[
                const SizedBox(width: MintSpacing.xs),
                VoiceInputButton(
                  voiceService: _voiceService,
                  onTranscription: (transcript) {
                    // Sprint E: activate voice mode and auto-send transcription.
                    // Voice mode triggers TTS auto-speak on the coach response.
                    // V5-7 audit fix: scrub PII from voice transcript before sending.
                    final clean = ConversationStore.scrubPii(transcript);
                    setState(() => _voiceModeActive = true);
                    _sendMessage(clean);
                  },
                ),
              ],
              const SizedBox(width: MintSpacing.sm),
              Semantics(
                button: true,
                label: s.coachSendButton,
                child: Container(
                  decoration: BoxDecoration(
                    color: _isBusy
                        ? MintColors.textMuted
                        : MintColors.coachAccent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send,
                        color: MintColors.white, size: 20),
                    tooltip: s.coachSendButton,
                    onPressed: _isBusy
                        ? null
                        : () {
                            // Typed send → deactivate voice mode.
                            _voiceModeActive = false;
                            _sendMessage(_controller.text);
                          },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  RESOLVED ROUTE PAYLOAD (S58)
// ════════════════════════════════════════════════════════════════

/// Internal subclass of [RouteToolPayload] that carries the result of
/// [RoutePlanner.plan] — the resolved GoRouter [route] and [isPartial] flag.
///
/// Created by [_CoachChatScreenState._resolveRoutePayload] and consumed by
/// [_CoachChatScreenState._buildRouteSuggestionCard].
class _ResolvedRoutePayload extends RouteToolPayload {
  /// The GoRouter route resolved by [RoutePlanner].
  final String resolvedRoute;

  /// Whether the screen opens in partial/estimation mode.
  final bool isPartial;

  /// Prefill values extracted from [CoachProfile] by [RoutePlanner].
  ///
  /// Passed to the target screen via GoRouter `extra` so the screen can
  /// pre-populate fields with known profile data.
  final Map<String, dynamic>? prefill;

  const _ResolvedRoutePayload({
    required super.intent,
    required super.confidence,
    required super.contextMessage,
    required this.resolvedRoute,
    required this.isPartial,
    this.prefill,
  });
}

/// Emotional canvas mood — drives subtle background tint changes.
enum _CanvasMood { neutral, stress, victory, discovery, retirement, milestone }

/// Isolated blinking cursor — manages its own animation lifecycle.
///
/// Avoids triggering parent [setState] for blink cycles, preventing
/// full [ListView] rebuilds during streaming.
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value < 0.5 ? 1.0 : 0.0,
          child: child,
        );
      },
      child: Container(
        width: 2,
        height: 14,
        color: MintColors.coachAccent,
      ),
    );
  }
}

/// Three softly pulsing dots — replaces CircularProgressIndicator for loading.
///
/// All dots breathe simultaneously (NOT sequential bouncing).
/// Opacity oscillates between 0.2 and 0.7 over 1200ms using a sine wave.
class _BreathingDots extends StatefulWidget {
  const _BreathingDots();

  @override
  State<_BreathingDots> createState() => _BreathingDotsState();
}

class _BreathingDotsState extends State<_BreathingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Sine wave: 0.0→1.0 maps to opacity 0.2→0.7
        final t = (math.sin(_controller.value * 2 * math.pi) + 1) / 2;
        final opacity = 0.2 + (0.5 * t); // range 0.2 – 0.7
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: MintColors.ardoise,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

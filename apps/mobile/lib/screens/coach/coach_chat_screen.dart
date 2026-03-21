import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
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
import 'package:mint_mobile/widgets/coach/response_card_widget.dart';
import 'package:mint_mobile/widgets/coach/route_suggestion_card.dart';
import 'package:mint_mobile/services/coach/context_injector_service.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';
import 'package:mint_mobile/widgets/coach/life_event_sheet.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach/voice_service.dart';
import 'package:mint_mobile/services/llm/provider_health_service.dart';
import 'package:mint_mobile/services/coach/proactive_trigger_service.dart';
import 'package:mint_mobile/services/nudge/nudge_engine.dart';
import 'package:mint_mobile/services/nudge/nudge_persistence.dart';
import 'package:mint_mobile/widgets/coach/voice_input_button.dart';
import 'package:mint_mobile/widgets/coach/voice_output_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _CoachChatScreenState extends State<CoachChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  CoachProfile? _profile;
  bool _hasProfile = false;
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isStreaming = false;
  final StringBuffer _streamBuffer = StringBuffer();
  bool _isByokConfigured = false;

  /// Conversation persistence
  final ConversationStore _conversationStore = ConversationStore();
  String? _conversationId;

  /// SLM stream timeout — prevents infinite hang if model deadlocks.
  static const Duration _streamTimeout = Duration(seconds: 45);

  bool _profileInitialized = false;

  bool _isResumingConversation = false;

  // ── Voice (S63) ──────────────────────────────────────────────
  /// Single VoiceService instance for this screen (stub backend by default —
  /// degrades gracefully when no STT/TTS plugin is configured).
  final VoiceService _voiceService = VoiceService();

  /// Whether STT is available on this device.
  bool _voiceSttAvailable = false;

  /// Whether TTS is available on this device.
  bool _voiceTtsAvailable = false;

  // ── Provider health (S64) ────────────────────────────────────
  /// Whether the primary provider circuit is open (temporarily unavailable).
  bool _primaryCircuitOpen = false;

  /// Whether all known providers are currently unhealthy.
  bool _allProvidersDown = false;

  @override
  void initState() {
    super.initState();
    // Bug fix: use provided conversationId when resuming, else generate unique ID.
    _conversationId = widget.conversationId ??
        '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
    if (widget.conversationId != null) {
      _isResumingConversation = true;
      _loadExistingConversation(widget.conversationId!);
    }
    // Voice (S63): probe availability async — does not block screen init.
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
      final prefs = await SharedPreferences.getInstance();
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
  }

  @override
  void dispose() {
    _autoSaveConversation();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _voiceService.dispose();
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

    final tier = _currentTier();

    // ── Proactive trigger evaluation ─────────────────────────────
    // Read from MintStateProvider if available (avoids double evaluate() race).
    // Falls back to direct evaluation if provider not wired yet.
    String? proactiveMessage;
    String? proactiveIntentTag;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      // Prefer MintStateProvider's pre-computed trigger to avoid race condition.
      ProactiveTrigger? trigger;
      try {
        final stateProvider = context.read<MintStateProvider>();
        trigger = stateProvider.state?.pendingTrigger;
      } catch (_) {
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
        // Store current phase and confidence as the new baseline.
        await ProactiveTriggerService.storeCurrentPhase(p, prefs);
        await ProactiveTriggerService.storeCurrentConfidence(p, prefs);
      } else if (trigger == null) {
        // No trigger — still update baseline if not yet stored.
        final hasPhase = prefs.getString('_proactive_stored_phase') != null;
        if (!hasPhase) {
          await ProactiveTriggerService.storeCurrentPhase(p, prefs);
          await ProactiveTriggerService.storeCurrentConfidence(p, prefs);
        }
      }
    } catch (_) {
      // Graceful degradation: greeting works without proactive trigger.
    }

    // ── Build greeting text ────────────────────────────────────────
    final String greeting;
    if (proactiveMessage != null && proactiveMessage.isNotEmpty) {
      greeting = proactiveMessage;
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

    // If a proactive trigger was fired, prepend its intentTag as
    // the first suggestion chip so the user can act on it directly.
    if (proactiveIntentTag != null && proactiveIntentTag.isNotEmpty) {
      // Remove duplicate if already present, then prepend.
      suggestions.remove(proactiveIntentTag);
      suggestions = [
        proactiveIntentTag,
        ...suggestions.take(3),
      ];
    }

    // Phase 2: prepend high-priority nudge chips so Claude can reinforce
    // timely topics. Nudges are loaded asynchronously; graceful degradation
    // if SharedPreferences or NudgeEngine fail.
    // Skip nudge chips when a proactive trigger is already surfaced to avoid
    // information overload.
    if (proactiveMessage == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
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
    setState(() {
      _messages.add(ChatMessage(
        role: 'assistant',
        content: greeting,
        timestamp: DateTime.now(),
        suggestedActions: suggestions,
        tier: tier,
      ));
    });
  }

  /// Resolve a [ProactiveTrigger]'s ARB messageKey to a display string.
  ///
  /// Parameterised keys (e.g. proactiveGoalMilestone with {progress})
  /// are resolved using [trigger.params]. Returns empty string on failure.
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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

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

    // Build enriched context for AI memory injection (S58).
    // Timeout + try/catch: if SharedPreferences or any dependency fails/hangs,
    // the chat still works without memory enrichment (graceful degradation).
    String? memoryBlock;
    try {
      final enrichedContext = await ContextInjectorService.buildContext(
        profile: _profile,
        now: DateTime.now(),
      ).timeout(const Duration(seconds: 2));
      if (enrichedContext.memoryBlock.isNotEmpty) {
        memoryBlock = enrichedContext.memoryBlock;
      }
    } catch (_) {
      // Graceful degradation: chat works without memory block.
    }

    // Try SLM streaming first.
    final ctx = _buildCoachContext(_profile!);
    final stream = CoachOrchestrator.streamChat(
      userMessage: text.trim(),
      history: _messages,
      ctx: ctx,
      memoryBlock: memoryBlock,
    );

    if (stream != null) {
      await _handleStreamResponse(stream, text.trim(), ctx);
      return;
    }

    // Fallback to standard (BYOK → fallback chain).
    await _handleStandardResponse(text.trim(), memoryBlock: memoryBlock);
  }

  /// Handle SLM streaming response (token-by-token).
  Future<void> _handleStreamResponse(
    Stream<String> stream,
    String userMessage,
    CoachContext ctx,
  ) async {
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
    final slmDisplayText = rawPayload != null
        ? finalText
            .replaceAll(
              RegExp(r'\[ROUTE_TO_SCREEN:\{[^}]*\}\]'),
              '',
            )
            .trim()
        : finalText;

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
  }

  /// Handle standard (non-streaming) response via orchestrator.
  Future<void> _handleStandardResponse(String text,
      {String? memoryBlock}) async {
    // Capture localizations before async gap (use_build_context_synchronously)
    final l = S.of(context)!;
    try {
      final config = _buildConfig();
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

      // Strip the [ROUTE_TO_SCREEN:{...}] marker from the displayed text
      // when a route payload was detected.
      final displayMessage = rawPayload != null
          ? response.message
              .replaceAll(
                RegExp(r'\[ROUTE_TO_SCREEN:\{[^}]*\}\]'),
                '',
              )
              .trim()
          : response.message;

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

  CoachContext _buildCoachContext(CoachProfile profile) {
    final knownValues = <String, double>{};

    try {
      final score = FinancialFitnessService.calculate(profile: profile);
      final g = score.global.toDouble();
      if (g.isFinite && g > 0) knownValues['fri_total'] = g;
    } catch (_) {}

    try {
      final proj = ForecasterService.project(
        profile: profile,
        targetDate: profile.goalA.targetDate,
      );
      final cap = proj.base.capitalFinal;
      final taux = proj.tauxRemplacementBase;
      if (cap.isFinite && cap > 0) knownValues['capital_final'] = cap;
      if (taux.isFinite && taux > 0) knownValues['replacement_ratio'] = taux;
    } catch (_) {}

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

  /// Called when the user returns from a screen opened via [RouteSuggestionCard].
  ///
  /// ReturnContract V2: reacts differently per [ScreenOutcome] —
  /// completed / abandoned / changedInputs each produce a distinct coach
  /// message and a distinct CapMemory update.
  void _handleRouteReturn(ScreenOutcome outcome) {
    if (!mounted) return;
    final s = S.of(context)!;

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
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (!_hasProfile) {
      return _buildEmptyState(context);
    }

    return Scaffold(
      backgroundColor: MintColors.background,
      body: Column(
        children: [
          _buildAppBar(context),
          _buildDisclaimer(),
          Expanded(child: _buildMessageList()),
          if (_isLoading) _buildLoadingIndicator(),
          _buildInputBar(),
        ],
      ),
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
      body: Center(
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
      ),
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
        return TweenAnimationBuilder<double>(
          key: ValueKey('msg_$index'),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: child,
        );
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
                  color: MintColors.coachAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.psychology,
                  color: MintColors.white,
                  size: 18,
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
                      Text(
                        msg.content.isEmpty && isStreamingThis
                            ? '...'
                            : msg.content,
                        style: MintTextStyles.bodyMedium(
                            color: MintColors.textPrimary),
                      ),
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
            ),
          ],
        ],
      ),
    );
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
      onReturn: _handleRouteReturn,
      profileHashFn: () {
        final profile = context.read<CoachProfileProvider>().profile;
        return profile?.hashCode.toString() ?? '';
      },
    );
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
                color: MintColors.coachAccent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.psychology,
                color: MintColors.white,
                size: 18,
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MintColors.coachAccent.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Text(
                    loadingText,
                    style: MintTextStyles.bodySmall(
                        color: MintColors.textMuted),
                  ),
                ],
              ),
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
              // Life event trigger button
              IconButton(
                icon: const Icon(Icons.flash_on_outlined,
                    color: MintColors.coachAccent, size: 22),
                tooltip: s.coachTooltipLifeEvent,
                onPressed: _isStreaming ? null : _showLifeEventSheet,
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
                    onSubmitted: (text) => _sendMessage(text),
                  ),
                ),
              ),
              // Voice input button (S63) — shown only when STT is available.
              if (_voiceSttAvailable) ...[
                const SizedBox(width: MintSpacing.xs),
                VoiceInputButton(
                  voiceService: _voiceService,
                  onTranscription: (transcript) {
                    _controller.text = transcript;
                    _focusNode.requestFocus();
                  },
                ),
              ],
              const SizedBox(width: MintSpacing.sm),
              Semantics(
                button: true,
                label: s.coachSendButton,
                child: Container(
                  decoration: BoxDecoration(
                    color: _isStreaming
                        ? MintColors.textMuted
                        : MintColors.coachAccent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send,
                        color: MintColors.white, size: 20),
                    tooltip: s.coachSendButton,
                    onPressed: _isStreaming
                        ? null
                        : () => _sendMessage(_controller.text),
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

  const _ResolvedRoutePayload({
    required super.intent,
    required super.confidence,
    required super.contextMessage,
    required this.resolvedRoute,
    required this.isPartial,
  });
}

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

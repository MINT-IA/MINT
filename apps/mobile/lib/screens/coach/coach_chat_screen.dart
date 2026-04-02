import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/response_card_service.dart';
import 'package:mint_mobile/services/coach/context_injector_service.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/lightning_menu.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/widgets/coach/coach_app_bar.dart';
import 'package:mint_mobile/widgets/coach/coach_empty_state.dart';
import 'package:mint_mobile/widgets/coach/coach_input_bar.dart';
import 'package:mint_mobile/widgets/coach/coach_loading_indicator.dart';
import 'package:mint_mobile/widgets/coach/coach_message_bubble.dart';
import 'package:mint_mobile/widgets/coach/coach_rich_widgets.dart';
import 'package:mint_mobile/models/coach_insight.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';

// ────────────────────────────────────────────────────────────
//  COACH CHAT SCREEN — SLM-first, streaming, prod-ready
//
//  Extracted components (W13 refactoring, 4193→836 lines):
//  - CoachAppBar         → widgets/coach/coach_app_bar.dart
//  - CoachEmptyState     → widgets/coach/coach_empty_state.dart
//  - CoachInputBar       → widgets/coach/coach_input_bar.dart
//  - CoachLoadingIndicator → widgets/coach/coach_loading_indicator.dart
//  - CoachMessageBubble  → widgets/coach/coach_message_bubble.dart
//  - CoachRichWidgets    → widgets/coach/coach_rich_widgets.dart
//  - LightningMenu       → widgets/coach/lightning_menu.dart
//  Greeting card, canvas background, and disclaimer remain inline
//  (tightly coupled to screen state — extraction deferred).
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

  /// Tracks message indices whose inline input pickers have been answered.
  /// Once answered, the picker is replaced by the user's response text.
  final Set<int> _answeredInputIndices = {};

  /// Voice intensity level (1-5). Persisted in SharedPreferences.
  /// 1 = Tranquille, 2 = Clair (default), 3 = Direct, 4 = Cash, 5 = Brut
  int _cashLevel = 2;

  /// Whether the silent opener is currently displayed (no messages yet).
  bool _showSilentOpener = false;

  /// SharedPreferences keys for proactive opt-in tracking.
  static const String _conversationCountKey = 'mint_coach_conversation_count';
  static const String _proactiveOptInKey = 'mint_coach_proactive_optin';
  static const String _proactiveOptInAskedKey = 'mint_coach_proactive_optin_asked';

  /// Whether the proactive opt-in question has been shown this session.
  bool _optInShownThisSession = false;

  /// Whether the user has already chosen an intensity (hides picker chips).
  bool _intensityChosen = false;

  /// Whether the cash level has been loaded from SharedPreferences.
  bool _cashLevelLoaded = false;

  /// SharedPreferences key for voice intensity level.
  static const String _cashLevelKey = 'mint_coach_cash_level';

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
    _loadCashLevel();
  }

  /// Load voice intensity from SharedPreferences.
  Future<void> _loadCashLevel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final level = prefs.getInt(_cashLevelKey);
      if (mounted) {
        setState(() {
          _cashLevelLoaded = true;
          if (level != null) {
            _cashLevel = level.clamp(1, 5);
            _intensityChosen = true;
          }
        });
      }
    } catch (_) {
      // Graceful degradation: default level 3, show picker.
      if (mounted) {
        setState(() => _cashLevelLoaded = true);
      }
    }
  }

  /// Save voice intensity to SharedPreferences.
  Future<void> _saveCashLevel(int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_cashLevelKey, level);
    } catch (_) {
      // Best-effort persistence.
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
  //  SILENT OPENER — coach shows a NUMBER, not a greeting
  // ════════════════════════════════════════════════════════════

  void _addInitialGreeting() {
    assert(_profile != null);

    // Show silent opener (key number) instead of a proactive message.
    // The opener disappears as soon as the user types.
    setState(() {
      _showSilentOpener = true;
    });

    // Track analytics: silent opener shown
    AnalyticsService().trackEvent('coach_silent_opener_shown', data: {
      'engaged': false,
    });

    // Increment conversation count for opt-in tracking.
    _incrementConversationCount();
  }

  /// Increment the conversation count in SharedPreferences.
  Future<void> _incrementConversationCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_conversationCountKey) ?? 0;
      await prefs.setInt(_conversationCountKey, count + 1);
    } catch (_) {
      // Best-effort persistence.
    }
  }

  /// Compute the key financial number to display in the silent opener.
  /// Returns (formattedNumber, headline) or null if no data available.
  ({String number, String headline})? _computeKeyNumber() {
    if (_profile == null) return null;
    final s = S.of(context)!;

    // Priority 1: replacement rate (most impactful)
    try {
      final proj = ForecasterService.project(
        profile: _profile!,
        targetDate: _profile!.goalA.targetDate,
      );
      final taux = proj.tauxRemplacementBase;
      if (taux.isFinite && taux > 0) {
        return (
          number: '${taux.round()}\u00a0%',
          headline: s.coachSilentOpenerReplacementRate,
        );
      }
    } catch (_) {}

    // Priority 2: financial fitness score
    try {
      final score = FinancialFitnessService.calculate(profile: _profile!);
      final g = score.global;
      if (g > 0) {
        return (
          number: '$g/100',
          headline: s.coachSilentOpenerFitnessScore,
        );
      }
    } catch (_) {}

    // Priority 3: projected capital
    try {
      final proj = ForecasterService.project(
        profile: _profile!,
        targetDate: _profile!.goalA.targetDate,
      );
      final cap = proj.base.capitalFinal;
      if (cap.isFinite && cap > 0) {
        final formatted = _formatChf(cap);
        return (
          number: formatted,
          headline: s.coachSilentOpenerRetirementCapital,
        );
      }
    } catch (_) {}

    return null;
  }

  /// Format a CHF amount for display (e.g. "1'234'567").
  String _formatChf(double amount) {
    final rounded = amount.round();
    final digits = rounded.toString();
    return digits.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => "${m[1]}'");
  }

  // ════════════════════════════════════════════════════════════
  //  MESSAGE SENDING — SLM streaming or standard
  // ════════════════════════════════════════════════════════════

  Future<void> _showLightningMenu() async {
    final capMem = await CapMemoryStore.load();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

  /// Handle intensity chip selection.
  void _onIntensitySelected(int level) {
    setState(() {
      _cashLevel = level;
      _intensityChosen = true;
    });
    _saveCashLevel(level);

    // Add adapted confirmation message.
    final String confirmation;
    switch (level) {
      case 1:
        confirmation =
            'Bien re\u00e7u. Je serai doux et progressif.';
        break;
      case 2:
        confirmation =
            'Compris. Clair et pos\u00e9, sans jargon inutile.';
        break;
      case 3:
        confirmation =
            'OK. Je vais droit au but, sans d\u00e9tour.';
        break;
      case 4:
        confirmation =
            'Re\u00e7u. Je te dis les choses cash, pas de pincettes.';
        break;
      case 5:
        confirmation =
            'Not\u00e9. Mode brut\u00a0: je ne m\u00e2che pas mes mots.';
        break;
      default:
        confirmation = S.of(context)!.intensityDirect;
    }

    setState(() {
      _messages.add(ChatMessage(
        role: 'assistant',
        content: confirmation,
        timestamp: DateTime.now(),
        tier: ChatTier.none,
      ));
    });
    _scrollToBottom();
  }

  /// Regex patterns for voice intensity adjustment commands.
  static final RegExp _intensityUpPattern = RegExp(
    r'(plus cash|plus direct|mode brut|sois plus direct|parle.?moi plus cash|monte.*cran|plus franc)',
    caseSensitive: false,
  );
  static final RegExp _intensityDownPattern = RegExp(
    r'(plus doux|plus gentil|sois plus doux|calme|moins direct|baisse.*cran|plus tranquille|doucement)',
    caseSensitive: false,
  );

  /// Check if the user message is a voice intensity adjustment command.
  /// Returns true if handled (message should not be sent to LLM).
  bool _handleVoiceIntensityCommand(String text) {
    final s = S.of(context)!;
    if (_intensityUpPattern.hasMatch(text)) {
      final newLevel = (_cashLevel + 1).clamp(1, 5);
      if (newLevel == _cashLevel) return false; // Already at max
      setState(() {
        _cashLevel = newLevel;
        _messages.add(ChatMessage(
          role: 'assistant',
          content: s.intensityAdjustedUp,
          timestamp: DateTime.now(),
          tier: ChatTier.none,
        ));
      });
      _saveCashLevel(newLevel);
      _scrollToBottom();
      return true;
    }
    if (_intensityDownPattern.hasMatch(text)) {
      final newLevel = (_cashLevel - 1).clamp(1, 5);
      if (newLevel == _cashLevel) return false; // Already at min
      setState(() {
        _cashLevel = newLevel;
        _messages.add(ChatMessage(
          role: 'assistant',
          content: s.intensityAdjustedDown,
          timestamp: DateTime.now(),
          tier: ChatTier.none,
        ));
      });
      _saveCashLevel(newLevel);
      _scrollToBottom();
      return true;
    }
    return false;
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Dismiss silent opener when user types their first message.
    if (_showSilentOpener) {
      setState(() {
        _showSilentOpener = false;
      });
      // Track analytics: user engaged with the silent opener
      AnalyticsService().trackEvent('coach_silent_opener_shown', data: {
        'engaged': true,
      });
    }

    // Check for voice intensity adjustment commands before sending to LLM.
    if (_handleVoiceIntensityCommand(text.trim())) {
      setState(() {
        _messages.add(ChatMessage(
          role: 'user',
          content: text.trim(),
          timestamp: DateTime.now(),
        ));
      });
      _controller.clear();
      // Re-order: user message first, then response.
      if (_messages.length >= 2) {
        final assistantMsg = _messages.removeLast();
        final userMsg = _messages.removeLast();
        _messages.add(userMsg);
        _messages.add(assistantMsg);
      }
      _scrollToBottom();
      return;
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

    // Build enriched context for AI memory injection (S58).
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

    final suggestedActions = compliance.useFallback
        ? null
        : _inferSuggestedActions(userMessage, finalText);

    // Phase 1: generate inline response cards from user message
    final cards = _profile != null
        ? ResponseCardService.generateForChat(_profile!, userMessage, l: S.of(context)!)
        : <ResponseCard>[];

    setState(() {
      _messages[_messages.length - 1] = ChatMessage(
        role: 'assistant',
        content: finalText,
        timestamp: DateTime.now(),
        suggestedActions: suggestedActions,
        responseCards: cards,
        tier: ChatTier.slm,
      );
      _isStreaming = false;
    });
    _scrollToBottom();

    // Wire S58: extract and persist insight from SLM exchange.
    _extractAndSaveInsight(userMessage, finalText);

    // Check if we should propose proactive opt-in.
    _maybeShowProactiveOptIn();
  }

  /// Handle standard (non-streaming) response via orchestrator.
  Future<void> _handleStandardResponse(String text,
      {String? memoryBlock}) async {
    try {
      final config = _buildConfig();
      final response = await CoachLlmService.chat(
        userMessage: text,
        profile: _profile!,
        history: _messages,
        config: config,
        memoryBlock: memoryBlock,
        cashLevel: _cashLevel,
      );

      final tier = config.hasApiKey ? ChatTier.byok : ChatTier.fallback;

      // Phase 1: generate inline response cards from user message context
      final cards = _profile != null
          ? ResponseCardService.generateForChat(_profile!, text, l: S.of(context)!)
          : <ResponseCard>[];

      // Use LLM-provided suggestions if available, otherwise infer from
      // both the user message and the coach response.
      final suggestedActions = response.suggestedActions ??
          _inferSuggestedActions(text, response.message);

      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: response.message,
          timestamp: DateTime.now(),
          suggestedActions: suggestedActions,
          sources: response.sources,
          disclaimers: response.disclaimers,
          responseCards: cards,
          tier: tier,
        ));
        _isLoading = false;
      });
      _scrollToBottom();

      // Wire S58: extract and persist insight from BYOK/fallback exchange.
      _extractAndSaveInsight(text, response.message);

      // Check if we should propose proactive opt-in.
      _maybeShowProactiveOptIn();
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
  //  INSIGHT EXTRACTION (S58 — AI Memory wiring)
  // ════════════════════════════════════════════════════════════

  /// Regex for detecting financial topics in conversation text.
  static final RegExp _financialTopicPattern = RegExp(
    r'\b(3a|3e|lpp|retraite|fiscalit[eé]|budget|logement|avs|imp[oô]t|rente|capital|pilier)\b',
    caseSensitive: false,
  );

  /// Extract a key insight from a coach exchange and persist it.
  ///
  /// Fire-and-forget: errors are caught silently so chat flow is never blocked.
  /// Skips short exchanges (user < 20 chars or coach < 50 chars) to avoid
  /// storing trivial greetings / acknowledgements.
  void _extractAndSaveInsight(String userMessage, String coachResponse) {
    // Skip trivial exchanges.
    if (userMessage.length < 20 || coachResponse.length < 50) return;

    // Detect financial topic via regex.
    final match = _financialTopicPattern.firstMatch(
      '${userMessage.toLowerCase()} ${coachResponse.toLowerCase()}',
    );
    if (match == null) return;

    final topic = match.group(1) ?? 'general';

    // Build a privacy-safe summary (max 200 chars, no PII).
    final summary = coachResponse.length > 200
        ? coachResponse.substring(0, 197).replaceAll(RegExp(r'\s+\S*$'), '...')
        : coachResponse;

    final insight = CoachInsight(
      id: '${DateTime.now().millisecondsSinceEpoch}_${topic}',
      createdAt: DateTime.now(),
      topic: topic,
      summary: summary,
      type: InsightType.fact,
    );

    // Fire-and-forget — never block the UI.
    CoachMemoryService.saveInsight(insight).catchError((_) {});
  }

  // ════════════════════════════════════════════════════════════
  //  PROACTIVE OPT-IN (after 3rd conversation)
  // ════════════════════════════════════════════════════════════

  /// Check if we should propose proactive opt-in at end of conversation.
  /// Called after each assistant response when user has sent messages.
  Future<void> _maybeShowProactiveOptIn() async {
    if (_optInShownThisSession) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Already asked and declined? Never ask again.
      final alreadyAsked = prefs.getBool(_proactiveOptInAskedKey) ?? false;
      if (alreadyAsked) return;
      // Already opted in? No need to ask.
      final optedIn = prefs.getBool(_proactiveOptInKey) ?? false;
      if (optedIn) return;
      // Only ask after 3rd conversation.
      final count = prefs.getInt(_conversationCountKey) ?? 0;
      if (count < 3) return;
      // Only ask if user has sent at least 2 messages this session.
      final userMsgCount = _messages.where((m) => m.isUser).length;
      if (userMsgCount < 2) return;

      _optInShownThisSession = true;
      if (!mounted) return;

      final s = S.of(context)!;
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: s.coachProactiveOptIn,
          timestamp: DateTime.now(),
          suggestedActions: [s.coachOptInAccept, s.coachOptInDecline],
          tier: ChatTier.none,
        ));
      });
      _scrollToBottom();
    } catch (_) {
      // Best-effort — don't block chat.
    }
  }

  /// Handle the user's response to the proactive opt-in question.
  Future<void> _handleOptInResponse(bool accepted) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_proactiveOptInAskedKey, true);
      if (accepted) {
        await prefs.setBool(_proactiveOptInKey, true);
      }
      // Track analytics
      AnalyticsService().trackEvent('coach_proactive_optin', data: {
        'accepted': accepted,
        'conversationCount': prefs.getInt(_conversationCountKey) ?? 0,
      });
    } catch (_) {
      // Best-effort.
    }
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  /// Called when the user selects a value from an inline input picker.
  void _handleInputSubmitted(int messageIndex, String field, String value) {
    setState(() {
      _answeredInputIndices.add(messageIndex);
    });
    _updateProfileField(field, value);
    final displayText = _displayTextForInput(field, value);
    _sendMessage(displayText);
  }

  /// Map a raw field+value into the correct wizard answer keys
  /// and merge into the existing profile.
  void _updateProfileField(String field, String value) {
    final provider = context.read<CoachProfileProvider>();
    final answers = <String, dynamic>{};

    switch (field) {
      case 'age':
        final age = int.tryParse(value);
        if (age != null) {
          answers['q_birth_year'] = DateTime.now().year - age;
        }
      case 'salary':
        final salary = double.tryParse(value.replaceAll("'", ''));
        if (salary != null) {
          answers['q_net_income_period_chf'] = salary;
        }
      case 'canton':
        answers['q_canton'] = value;
      case 'civil_status':
        final mapped = _mapCivilStatus(value);
        answers['q_civil_status_choice'] = mapped;
      case 'employment_status':
        final mapped = _mapEmploymentStatus(value);
        answers['q_employment_status'] = mapped;
      case 'children':
        final count = value == '4+' ? 4 : int.tryParse(value) ?? 0;
        answers['q_children_count'] = count;
    }

    if (answers.isNotEmpty) {
      provider.mergeAnswers(answers);
      _profile = provider.profile;
      _hasProfile = provider.hasProfile;
    }
  }

  String _mapCivilStatus(String display) {
    final lower = display.toLowerCase();
    if (lower.contains('mari')) return 'married';
    if (lower.contains('divorc')) return 'divorced';
    if (lower.contains('concubin')) return 'concubinage';
    return 'single';
  }

  String _mapEmploymentStatus(String display) {
    final lower = display.toLowerCase();
    if (lower.contains('ind\u00e9pendant') || lower.contains('independant')) {
      return 'independent';
    }
    if (lower.contains('sans emploi')) return 'unemployed';
    return 'employed';
  }

  String _displayTextForInput(String field, String value) {
    switch (field) {
      case 'age':
        return 'J\u2019ai $value ans';
      case 'salary':
        final formatted = _formatForDisplay(value);
        return 'CHF $formatted';
      case 'canton':
        return value;
      case 'civil_status':
        return value;
      case 'employment_status':
        return value;
      case 'children':
        if (value == '0') return 'Pas d\u2019enfants';
        if (value == '1') return '1 enfant';
        return '$value enfants';
      default:
        return value;
    }
  }

  String _formatForDisplay(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '0';
    return digits.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => "${m[1]}'");
  }

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

  List<String> _inferSuggestedActions(
    String userMessage,
    String coachResponse,
  ) {
    final s = S.of(context)!;
    final combined = '$userMessage $coachResponse'.toLowerCase();
    final actions = <String>[];

    if (RegExp(r'3a|pilier|troisi[eè]me|versement').hasMatch(combined)) {
      actions.addAll([s.coachSuggestSimulate3a, s.coachSuggestView3a]);
    }
    if (RegExp(r'lpp|rachat|2e\s*pilier|deuxi[eè]me').hasMatch(combined)) {
      actions.addAll([s.coachSuggestSimulateLpp, s.coachSuggestUnderstandLpp]);
    }
    if (RegExp(r'retraite|pension|avs|rente').hasMatch(combined)) {
      actions.addAll([s.coachSuggestTrajectory, s.coachSuggestScenarios]);
    }
    if (RegExp(r'imp[oô]t|fiscal|d[eé]duction').hasMatch(combined)) {
      actions.addAll([s.coachSuggestDeductions, s.coachSuggestTaxImpact]);
    }
    if (RegExp(r'budget|d[eé]pense|train\s*de\s*vie|niveau\s*de\s*vie')
        .hasMatch(combined)) {
      actions.addAll([s.coachSuggestBudget, s.coachSuggestBudgetGap]);
    }
    if (RegExp(r'immobilier|hypoth[eè]que|maison|achat|propri[eé]t[eé]|logement')
        .hasMatch(combined)) {
      actions.addAll([s.coachSuggestMortgage, s.coachSuggestMortgageCapacity]);
    }

    if (actions.isEmpty) {
      return [s.coachSuggestFitness, s.coachSuggestRetirement];
    }
    // Deduplicate and cap at 3
    return actions.toSet().take(3).toList();
  }

  /// Map suggested action labels to direct navigation routes.
  String? _routeForAction(String action) {
    final s = S.of(context)!;
    final routes = <String, String>{
      s.coachSuggestSimulate3a: '/pilier-3a',
      s.coachSuggestView3a: '/pilier-3a',
      s.coachSuggestSimulateLpp: '/rachat-lpp',
      s.coachSuggestUnderstandLpp: '/rachat-lpp',
      s.coachSuggestTrajectory: '/retraite',
      s.coachSuggestScenarios: '/rente-vs-capital',
      s.coachSuggestDeductions: '/fiscal',
      s.coachSuggestTaxImpact: '/fiscal',
      s.coachSuggestFitness: '/confidence',
      s.coachSuggestRetirement: '/retraite',
      s.coachSuggestBudget: '/budget',
      s.coachSuggestBudgetGap: '/budget',
      s.coachSuggestMortgage: '/hypotheque',
      s.coachSuggestMortgageCapacity: '/hypotheque',
    };
    if (routes.containsKey(action)) return routes[action];

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
    if (lower.contains('budget') || lower.contains('depense')) {
      return '/budget';
    }
    if (lower.contains('immobilier') ||
        lower.contains('hypotheque') ||
        lower.contains('maison')) {
      return '/hypotheque';
    }
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

  /// Handle action tap from suggested action chips.
  void _handleActionTap(String action) {
    final s = S.of(context)!;

    // Handle proactive opt-in responses.
    if (action == s.coachOptInAccept) {
      _handleOptInResponse(true);
      setState(() {
        _messages.add(ChatMessage(
          role: 'user',
          content: action,
          timestamp: DateTime.now(),
        ));
        _messages.add(ChatMessage(
          role: 'assistant',
          content: 'Parfait, je te signalerai ce qui compte.',
          timestamp: DateTime.now(),
          tier: ChatTier.none,
        ));
      });
      _scrollToBottom();
      return;
    }
    if (action == s.coachOptInDecline) {
      _handleOptInResponse(false);
      setState(() {
        _messages.add(ChatMessage(
          role: 'user',
          content: action,
          timestamp: DateTime.now(),
        ));
        _messages.add(ChatMessage(
          role: 'assistant',
          content: 'Compris. Je serai l\u00e0 quand tu viendras.',
          timestamp: DateTime.now(),
          tier: ChatTier.none,
        ));
      });
      _scrollToBottom();
      return;
    }

    final isLifeEvent = action.toLowerCase().contains('il m') &&
        action.toLowerCase().contains('arrive');
    if (isLifeEvent) {
      _showLightningMenu();
      return;
    }
    final route = _routeForAction(action);
    if (route != null) {
      context.push(route);
    } else {
      _sendMessage(action);
    }
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (!_hasProfile) {
      return const CoachEmptyState();
    }

    return Scaffold(
      backgroundColor: MintColors.craie,
      body: Column(
        children: [
          CoachAppBar(
            isEmbeddedInTab: widget.isEmbeddedInTab,
            hasUserMessages: _messages.any((m) => m.isUser),
            onBack: () => context.pop(),
            onHistory: () async {
              final router = GoRouter.of(context);
              await _autoSaveConversation();
              if (mounted) router.push('/coach/history');
            },
            onExport: _exportConversation,
            onSettings: () => context.push('/profile/byok'),
          ),
          Expanded(
            child: _showSilentOpener
                ? _buildSilentOpener()
                : _buildMessageList(),
          ),
          if (_isLoading) const CoachLoadingIndicator(),
          CoachInputBar(
            controller: _controller,
            focusNode: _focusNode,
            isStreaming: _isStreaming,
            onSend: () => _sendMessage(_controller.text),
            onLightningMenu: _showLightningMenu,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SILENT OPENER WIDGET — a key number, not a greeting
  // ════════════════════════════════════════════════════════════

  Widget _buildSilentOpener() {
    final s = S.of(context)!;
    final keyData = _computeKeyNumber();

    // If no financial data available, show a minimal empty state.
    if (keyData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Text(
            s.coachSilentOpenerQuestion,
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: MintColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The number, big, alone
            Text(
              keyData.number,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: MintColors.primary,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),
            // Short context headline
            Text(
              keyData.headline,
              style: const TextStyle(
                fontSize: 15,
                color: MintColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // "Tu veux en parler ?"
            Text(
              s.coachSilentOpenerQuestion,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: MintColors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  MESSAGE LIST
  // ════════════════════════════════════════════════════════════

  Widget _buildMessageList() {
    return RepaintBoundary(
      child: ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.md, vertical: MintSpacing.md),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final Widget child;
        if (msg.isSystem) {
          child = SystemMessageBubble(message: msg);
        } else if (msg.isUser) {
          child = Semantics(
            label: S.of(context)!.coachUserMessage,
            child: UserMessageBubble(message: msg),
          );
        } else {
          // Build rich widget if applicable — look up the preceding user message
          Widget? richWidget;
          if (_profile != null && index > 0 && _messages[index - 1].isUser) {
            richWidget = CoachRichWidgetBuilder.build(
                context, _messages[index - 1].content, _profile!);
          }

          child = Semantics(
            label: S.of(context)!.coachCoachMessage,
            child: CoachMessageBubble(
              message: msg,
              messageIndex: index,
              isStreaming:
                  _isStreaming && msg == _messages.last && msg.tier == ChatTier.slm,
              isInputAnswered: _answeredInputIndices.contains(index),
              richWidget: richWidget,
              onInputSubmitted: _handleInputSubmitted,
              onActionTap: _handleActionTap,
            ),
          );
        }

        // Wrap with intensity picker for first assistant message if needed.
        final bool showIntensity = _cashLevelLoaded &&
            !_intensityChosen &&
            index == 0 &&
            msg.isAssistant &&
            !(_isStreaming && msg == _messages.last);
        final Widget wrappedChild = showIntensity
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  child,
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 42),
                    child: _buildIntensityChips(),
                  ),
                ],
              )
            : child;

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
          child: wrappedChild,
        );
      },
      ),
    );
  }

  /// Build inline intensity picker chips.
  Widget _buildIntensityChips() {
    final s = S.of(context)!;
    // Level 5 (Brut) is excluded from first-chat chips — accessible via settings only.
    final chips = <MapEntry<int, String>>[
      MapEntry(1, s.intensityTranquille),
      MapEntry(2, s.intensityClair),
      MapEntry(3, s.intensityDirect),
      MapEntry(4, s.intensityCash),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: chips.map((entry) {
        return GestureDetector(
          onTap: () => _onIntensitySelected(entry.key),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: MintColors.porcelaine,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: MintColors.border.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              entry.value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
                color: MintColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

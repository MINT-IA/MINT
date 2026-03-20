import 'dart:async';

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
import 'package:mint_mobile/services/backend_coach_service.dart';
import 'package:mint_mobile/services/cap_engine.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/response_card_service.dart';
import 'package:mint_mobile/widgets/coach/response_card_widget.dart';
import 'package:mint_mobile/services/coach/context_injector_service.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';
import 'package:mint_mobile/widgets/coach/life_event_sheet.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';

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
  //  GREETING
  // ════════════════════════════════════════════════════════════

  void _addInitialGreeting() {
    assert(_profile != null);
    final p = _profile!;
    final name = p.firstName ?? S.of(context)!.coachFallbackName;
    final s = S.of(context)!;

    final tier = _currentTier();
    final greeting = _buildCapBasedGreeting(p, name, tier, s);

    // Phase 1: personalized suggestions based on age/archetype
    final personalizedPrompts = ResponseCardService.suggestedPrompts(p);
    final List<String> suggestions;
    if (personalizedPrompts.isNotEmpty) {
      suggestions = personalizedPrompts;
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

    // No response cards on greeting — they duplicate Pulse.
    // Cards appear only in response to user messages.
    _messages.add(ChatMessage(
      role: 'assistant',
      content: greeting,
      timestamp: DateTime.now(),
      suggestedActions: suggestions,
      tier: tier,
    ));
  }

  /// Build a greeting grounded in the user's current cap decision,
  /// not a generic score. Pattern: "{name}, {observation}. {levier}."
  String _buildCapBasedGreeting(
    CoachProfile profile,
    String name,
    ChatTier tier,
    S s,
  ) {
    if (tier == ChatTier.slm) {
      return s.coachGreetingSlm(name);
    }

    // Try to build a greeting from the cap du jour
    try {
      final cap = CapEngine.compute(
        profile: profile,
        now: DateTime.now(),
      );
      // Use the cap headline as the observation
      return '$name, ${cap.headline[0].toLowerCase()}'
          '${cap.headline.substring(1)}. '
          '${cap.ctaLabel}\u00a0?';
    } catch (_) {
      // Fallback: minimal, not generic
      return '$name, tes chiffres sont là. '
          'Qu\u2019est-ce qu\u2019on regarde\u00a0?';
    }
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

    // Try backend Claude proxy (S56 — server-side, no BYOK needed).
    final backendSuccess = await _tryBackendClaude(text.trim());
    if (backendSuccess) return;

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
        ? ResponseCardService.generateForChat(_profile!, userMessage)
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
  }

  /// Try backend Claude proxy (S56). Returns true if successful.
  Future<bool> _tryBackendClaude(String text) async {
    if (_profile == null) return false;

    try {
      final history = _messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final response = await BackendCoachService.chat(
        message: text,
        profile: _profile!,
        history: history,
      );

      if (response == null) return false;

      // Generate inline response cards
      final cards = ResponseCardService.generateForChat(_profile!, text);

      if (!mounted) return true;
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: response.reply,
          timestamp: DateTime.now(),
          suggestedActions: _inferSuggestedActions(text),
          responseCards: cards,
          tier: ChatTier.byok, // Show as AI-powered, not fallback
          disclaimers: [response.disclaimer],
        ));
        _isLoading = false;
      });
      _scrollToBottom();
      return true;
    } catch (e) {
      debugPrint('[CoachChat] Backend Claude error: $e');
      return false;
    }
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
      );

      final tier = config.hasApiKey ? ChatTier.byok : ChatTier.fallback;

      // Phase 1: generate inline response cards from user message context
      final cards = _profile != null
          ? ResponseCardService.generateForChat(_profile!, text)
          : <ResponseCard>[];

      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: response.message,
          timestamp: DateTime.now(),
          suggestedActions: response.suggestedActions,
          sources: response.sources,
          disclaimers: response.disclaimers,
          responseCards: cards,
          tier: tier,
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
      backgroundColor: MintColors.craie,
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
      backgroundColor: MintColors.craie,
      appBar: AppBar(
        title: Text(
          s.coachTitle,
          style: MintTextStyles.titleMedium(color: MintColors.textPrimary)
              .copyWith(fontWeight: FontWeight.w700),
        ),
        backgroundColor: MintColors.craie,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
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
      decoration: const BoxDecoration(color: MintColors.craie),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md, vertical: MintSpacing.sm + 4),
          child: Row(
            children: [
              if (!widget.isEmbeddedInTab) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: MintColors.textPrimary),
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
                      style: MintTextStyles.titleMedium(
                              color: MintColors.textPrimary)
                          .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2), // tight coupling
                    _buildTierSubtitle(tier),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.history,
                    color: MintColors.textSecondary),
                tooltip: s.coachTooltipHistory,
                onPressed: () async {
                  final router = GoRouter.of(context);
                  await _autoSaveConversation();
                  if (mounted) router.push('/coach/history');
                },
              ),
              if (_messages.any((m) => m.isUser))
                IconButton(
                  icon: const Icon(Icons.share,
                      color: MintColors.textSecondary),
                  tooltip: s.coachTooltipExport,
                  onPressed: _exportConversation,
                ),
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: MintColors.textSecondary),
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
        Icon(icon, size: 12, color: MintColors.textMuted),
        const SizedBox(width: MintSpacing.xs),
        Text(
          label,
          style: MintTextStyles.labelSmall(
            color: MintColors.textMuted,
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
      color: MintColors.bleuAir.withValues(alpha: 0.15),
      child: Text(
        S.of(context)!.coachDisclaimer,
        style: MintTextStyles.micro(color: MintColors.textMuted),
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
          horizontal: MintSpacing.md, vertical: MintSpacing.md),
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
      padding: const EdgeInsets.only(bottom: MintSpacing.md),
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
                color: MintColors.porcelaine,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                msg.content,
                style:
                    MintTextStyles.bodyMedium(color: MintColors.textPrimary),
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
      padding: const EdgeInsets.only(bottom: MintSpacing.md),
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
                  color: MintColors.bleuAir,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.psychology,
                  color: MintColors.coachAccent.withValues(alpha: 0.8),
                  size: 18,
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.md, vertical: MintSpacing.sm + 4),
                  decoration: BoxDecoration(
                    color: MintColors.bleuAir.withValues(alpha: 0.3),
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
          // Tier badge
          if (!isStreamingThis && msg.tier != ChatTier.none) ...[
            const SizedBox(height: MintSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: _buildTierBadge(msg.tier),
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
                    backgroundColor: MintColors.bleuAir.withValues(alpha: 0.15),
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
                color: MintColors.bleuAir,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.psychology,
                color: MintColors.coachAccent.withValues(alpha: 0.8),
                size: 18,
              ),
            ),
            const SizedBox(width: MintSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.md, vertical: MintSpacing.sm + 4),
              decoration: BoxDecoration(
                color: MintColors.bleuAir.withValues(alpha: 0.3),
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
        color: MintColors.bleuAir.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
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
        color: MintColors.pecheDouce.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
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
      decoration: const BoxDecoration(
        color: MintColors.craie,
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
                icon: Icon(Icons.flash_on_outlined,
                    color: MintColors.coachAccent.withValues(alpha: 0.7),
                    size: 22),
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
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: MintColors.coachAccent.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    onSubmitted: (text) => _sendMessage(text),
                  ),
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              Semantics(
                button: true,
                label: s.coachSendButton,
                child: Container(
                  decoration: BoxDecoration(
                    color: _isStreaming
                        ? MintColors.textMuted.withValues(alpha: 0.3)
                        : MintColors.primary,
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

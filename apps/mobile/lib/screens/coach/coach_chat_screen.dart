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
import 'package:mint_mobile/widgets/coach/widget_renderer.dart';
import 'package:mint_mobile/services/coach/chat_tool_dispatcher.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/tool_call_parser.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/response_card_service.dart';
import 'package:mint_mobile/widgets/coach/response_card_widget.dart';
import 'package:mint_mobile/services/coach/context_injector_service.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/lightning_menu.dart';
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

  /// Tracks message indices whose inline input pickers have been answered.
  /// Once answered, the picker is replaced by the user's response text.
  final Set<int> _answeredInputIndices = {};

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

    // SILENT greeting: no CapEngine, no score, no retirement mention.
    // The user guides the direction. Silence is premium.
    final name = p.firstName;
    final greeting = name != null && name.isNotEmpty
        ? '$name, on commence par quoi\u00a0?'
        : 'On commence par quoi\u00a0?';

    // Emotional suggestions based on age/situation + life event trigger
    final personalizedPrompts = ResponseCardService.suggestedPrompts(p);
    final suggestions = personalizedPrompts.isNotEmpty
        ? [...personalizedPrompts.take(2), 'Il m\u2019arrive quelque chose']
        : [
            'Par o\u00f9 commencer\u00a0?',
            'C\u2019est quoi tout \u00e7a\u00a0?',
            'Il m\u2019arrive quelque chose',
          ];

    _messages.add(ChatMessage(
      role: 'assistant',
      content: greeting,
      timestamp: DateTime.now(),
      suggestedActions: suggestions,
      tier: ChatTier.none,
    ));
  }

  // ════════════════════════════════════════════════════════════
  //  MESSAGE SENDING — SLM streaming or standard
  // ════════════════════════════════════════════════════════════

  void _showLightningMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LightningMenu(
        profile: _profile,
        onSendMessage: _sendMessage,
      ),
    );
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

    // Extract tool call markers from SLM output before compliance validation.
    // ToolCallParser strips [TOOL_NAME:{...}] markers and returns clean text.
    final parseResult = ToolCallParser.parse(rawText);
    final parsedText = parseResult.cleanText.isNotEmpty
        ? parseResult.cleanText
        : rawText;

    // Normalize SLM ParsedToolCall list → RagToolCall list (capped at 5).
    // T-02-05: ChatToolDispatcher validates and caps before storing.
    final richCalls =
        ChatToolDispatcher.normalize(parseResult.toolCalls);

    // Validate through ComplianceGuard.
    ComplianceResult compliance;
    try {
      compliance = ComplianceGuard.validate(
        parsedText,
        context: ctx,
        componentType: ComponentType.general,
      );
    } catch (_) {
      // ComplianceGuard crashed — still sanitize banned terms manually
      // since SLM can generate them despite system prompt.
      compliance = ComplianceResult(
        isCompliant: true,
        sanitizedText: ComplianceGuard.sanitizeBannedTerms(parsedText),
      );
    }

    final finalText = compliance.useFallback
        ? S.of(context)!.coachComplianceError
        : (compliance.sanitizedText.isNotEmpty
            ? compliance.sanitizedText
            : parsedText);

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
        userQuery: userMessage,
        richToolCalls: richCalls,
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

      // Convert backend widget_call to richToolCalls via ChatToolDispatcher.
      // Also parse any text-marker tool calls embedded in the reply text.
      final parseResult = ToolCallParser.parse(response.reply);
      final cleanReply = parseResult.cleanText.isNotEmpty
          ? parseResult.cleanText
          : response.reply;

      // Combine: text-marker calls + backend widget call (if any)
      final allRawCalls = parseResult.toolCalls.isNotEmpty
          ? parseResult.toolCalls
          : <ParsedToolCall>[];
      var richCalls = ChatToolDispatcher.normalize(allRawCalls);

      // If backend returned a WidgetCall and no text-marker calls,
      // convert it to a RagToolCall so it flows through WidgetRenderer.
      if (richCalls.isEmpty && response.widget != null) {
        richCalls = ChatToolDispatcher.filterRag([
          RagToolCall(
            name: response.widget!.tool,
            input: response.widget!.params,
          ),
        ]);
      }

      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: cleanReply,
          timestamp: DateTime.now(),
          suggestedActions: _inferSuggestedActions(text),
          responseCards: cards,
          tier: ChatTier.byok,
          disclaimers: [response.disclaimer],
          userQuery: text,
          richToolCalls: richCalls,
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

      // Extract text-marker tool calls from BYOK response text.
      // T-02-06: ChatToolDispatcher normalizes and caps (same pipeline as SLM).
      final parseResult = ToolCallParser.parse(response.message);
      final cleanMessage = parseResult.cleanText.isNotEmpty
          ? parseResult.cleanText
          : response.message;
      final richCalls =
          ChatToolDispatcher.normalize(parseResult.toolCalls);

      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: cleanMessage,
          timestamp: DateTime.now(),
          suggestedActions: response.suggestedActions,
          sources: response.sources,
          disclaimers: response.disclaimers,
          responseCards: cards,
          tier: tier,
          userQuery: text,
          richToolCalls: richCalls,
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

  /// Called when the user selects a value from an inline input picker.
  /// Updates the profile, marks the picker as answered, and sends
  /// the value as a user message to continue the conversation.
  void _handleInputSubmitted(int messageIndex, String field, String value) {
    // 1. Mark this input as answered so the picker disappears.
    setState(() {
      _answeredInputIndices.add(messageIndex);
    });

    // 2. Update the profile with the new value.
    _updateProfileField(field, value);

    // 3. Build a human-readable response for the chat.
    final displayText = _displayTextForInput(field, value);

    // 4. Send as user message to continue the conversation.
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
      // Refresh local profile reference.
      _profile = provider.profile;
      _hasProfile = provider.hasProfile;
    }
  }

  /// Map a user-facing civil status label to the internal wizard key.
  String _mapCivilStatus(String display) {
    final lower = display.toLowerCase();
    if (lower.contains('mari')) return 'married';
    if (lower.contains('divorc')) return 'divorced';
    if (lower.contains('concubin')) return 'concubinage';
    return 'single';
  }

  /// Map a user-facing employment status label to the internal wizard key.
  String _mapEmploymentStatus(String display) {
    final lower = display.toLowerCase();
    if (lower.contains('ind\u00e9pendant') || lower.contains('independant')) {
      return 'independent';
    }
    if (lower.contains('sans emploi')) return 'unemployed';
    return 'employed';
  }

  /// Build a natural display text for the user's input response.
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

  /// Format a numeric string with Swiss apostrophe separators for display.
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

  // ════════════════════════════════════════════════════════════
  //  RICH INLINE WIDGETS
  // ════════════════════════════════════════════════════════════
  //
  // S57: Keyword-based widget rendering removed.
  // All inline widgets are now driven by ChatMessage.richToolCalls,
  // populated by ChatToolDispatcher.normalize() in both SLM and BYOK paths.
  // See widget_renderer.dart for the rendering logic.

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
          'MINT',
          style: MintTextStyles.titleMedium(color: MintColors.textPrimary)
              .copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: MintColors.textSecondary,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MintSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: MintColors.bleuAir.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(Icons.auto_awesome_outlined,
                    size: 28,
                    color: MintColors.textSecondary.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: MintSpacing.lg),
              Text(
                s.coachEmptyStateMessage,
                style: MintTextStyles.bodyLarge(
                    color: MintColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MintSpacing.lg),
              FilledButton(
                onPressed: () => context.go('/onboarding/quick'),
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                ),
                child: Text(
                  s.coachEmptyStateButton,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.white).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
    final s = S.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: MintColors.craie,
        border: Border(
          bottom: BorderSide(
            color: MintColors.border.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
          child: Row(
            children: [
              if (!widget.isEmbeddedInTab) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: MintColors.textSecondary, size: 18),
                  onPressed: () => context.pop(),
                ),
              ] else
                const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'MINT',
                  style: MintTextStyles.titleMedium(
                          color: MintColors.textPrimary)
                      .copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.history_rounded,
                    color: MintColors.textMuted, size: 20),
                tooltip: s.coachTooltipHistory,
                onPressed: () async {
                  final router = GoRouter.of(context);
                  await _autoSaveConversation();
                  if (mounted) router.push('/coach/history');
                },
              ),
              if (_messages.any((m) => m.isUser))
                IconButton(
                  icon: const Icon(Icons.ios_share_rounded,
                      color: MintColors.textMuted, size: 20),
                  tooltip: s.coachTooltipExport,
                  onPressed: _exportConversation,
                ),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded,
                    color: MintColors.textMuted, size: 20),
                tooltip: s.coachTooltipSettings,
                onPressed: () => context.push('/profile/byok'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Disclaimer removed from chat header — accessible via settings menu.
  // Educational disclaimer text is still shown in disclaimers section
  // when returned by RAG backend responses.

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
            child: _buildCoachBubble(msg, index),
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
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 72),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                color: MintColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Text(
                msg.content,
                style: MintTextStyles.bodyMedium(
                    color: MintColors.white).copyWith(height: 1.55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachBubble(ChatMessage msg, int messageIndex) {
    final isStreamingThis =
        _isStreaming && msg == _messages.last && msg.tier == ChatTier.slm;
    final isInputAnswered = _answeredInputIndices.contains(messageIndex);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coach avatar — refined 24px dot
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MintColors.saugeClaire,
                      MintColors.bleuAir.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'M',
                    style: MintTextStyles.micro(
                      color: MintColors.ardoise,
                    ).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: const BoxDecoration(
                    color: MintColors.porcelaine,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(22),
                      bottomLeft: Radius.circular(22),
                      bottomRight: Radius.circular(22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.content.isEmpty && isStreamingThis
                            ? '...'
                            : msg.content,
                        style: MintTextStyles.bodyMedium(
                            color: MintColors.textPrimary).copyWith(height: 1.6),
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
              const SizedBox(width: 48),
            ],
          ),
          // Tier badge — very subtle, only on non-greeting messages
          if (!isStreamingThis &&
              msg.tier != ChatTier.none &&
              messageIndex > 0) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: _buildTierBadge(msg.tier),
            ),
          ],
          // Rich inline widgets from tool calls (S57 — ChatToolDispatcher).
          // Renders each RagToolCall via WidgetRenderer.build().
          // ask_user_input is hidden once the user has answered.
          if (!isStreamingThis && msg.richToolCalls.isNotEmpty) ...[
            for (final call in msg.richToolCalls)
              if (!(call.name == 'ask_user_input' && isInputAnswered)) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 42, right: 16),
                  child: WidgetRenderer.build(
                    context,
                    call,
                    onInputSubmitted: (field, value) {
                      _handleInputSubmitted(messageIndex, field, value);
                    },
                  ) ?? const SizedBox.shrink(),
                ),
              ],
          ],
          // Sources
          if (msg.sources.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 42, right: 48),
              child: _buildSourcesSection(msg.sources),
            ),
          ],
          // Disclaimers (from RAG backend)
          if (msg.disclaimers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 42, right: 48),
              child: _buildDisclaimersSection(msg.disclaimers),
            ),
          ],
          // Response Cards (Phase 1 — inline strip)
          if (!isStreamingThis && msg.responseCards.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: ResponseCardStrip(cards: msg.responseCards),
            ),
          ],
          // Note: keyword-based _buildRichWidget removed in S57.
          // Inline widgets are now exclusively driven by richToolCalls.
          // Suggested actions
          if (!isStreamingThis &&
              msg.suggestedActions != null &&
              msg.suggestedActions!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Wrap(
                spacing: 8,
                runSpacing: 10,
                children: msg.suggestedActions!.map((action) {
                  // "Il m'arrive quelque chose" gets a different tone
                  final isLifeEvent = action.toLowerCase().contains('il m') &&
                      action.toLowerCase().contains('arrive');
                  return GestureDetector(
                    onTap: () {
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
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isLifeEvent
                            ? MintColors.pecheDouce.withValues(alpha: 0.18)
                            : MintColors.porcelaine,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isLifeEvent
                              ? MintColors.pecheDouce.withValues(alpha: 0.3)
                              : MintColors.border.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        action,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w500, height: 1.3),
                      ),
                    ),
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
    switch (tier) {
      case ChatTier.slm:
        label = s.coachBadgeSlm;
        icon = Icons.smartphone;
        break;
      case ChatTier.byok:
        label = s.coachBadgeByok;
        icon = Icons.cloud_outlined;
        break;
      case ChatTier.fallback:
        label = s.coachBadgeFallback;
        icon = Icons.wifi_off;
        break;
      default:
        return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 9,
            color: MintColors.textMuted.withValues(alpha: 0.5)),
        const SizedBox(width: 3),
        Text(
          label,
          style: MintTextStyles.micro(
            color: MintColors.textMuted.withValues(alpha: 0.5),
          ).copyWith(fontWeight: FontWeight.w400),
        ),
      ],
    );
  }

  Widget _buildSystemMessage(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: MintColors.porcelaine.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            msg.content,
            style: MintTextStyles.micro(color: MintColors.textMuted)
                .copyWith(fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    MintColors.saugeClaire,
                    MintColors.bleuAir.withValues(alpha: 0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'M',
                  style: MintTextStyles.micro(
                    color: MintColors.ardoise,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                color: MintColors.porcelaine,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(22),
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              child: _buildTypingDots(),
            ),
          ],
        ),
      ),
    );
  }

  /// Animated three-dot typing indicator (replaces spinner).
  Widget _buildTypingDots() {
    return SizedBox(
      width: 24,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (i) => _TypingDot(delay: i * 200)),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SOURCES & DISCLAIMERS
  // ════════════════════════════════════════════════════════════

  Widget _buildSourcesSection(List<RagSource> sources) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MintColors.bleuAir.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.coachSources,
            style: MintTextStyles.micro(
              color: MintColors.textMuted,
            ).copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
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
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _navigateToSource(source),
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined,
                          size: 12,
                          color: MintColors.textSecondary.withValues(alpha: 0.6)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${source.title}${source.section.isNotEmpty ? ' \u2014 ${source.section}' : ''}',
                          style: MintTextStyles.micro(
                            color: MintColors.textSecondary,
                          ).copyWith(
                            decoration: TextDecoration.underline,
                            decorationColor:
                                MintColors.textSecondary.withValues(alpha: 0.3),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MintColors.pecheDouce.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 13, color: MintColors.textMuted.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              disclaimers.join('\n'),
              style: MintTextStyles.micro(
                color: MintColors.textMuted,
              ).copyWith(height: 1.4),
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
        color: MintColors.craie,
        border: Border(
          top: BorderSide(
            color: MintColors.border.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Lightning menu trigger
              GestureDetector(
                onTap: _isStreaming ? null : _showLightningMenu,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: MintColors.porcelaine,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Icon(Icons.bolt_rounded,
                      color: _isStreaming
                          ? MintColors.textMuted.withValues(alpha: 0.3)
                          : MintColors.textSecondary,
                      size: 18),
                ),
              ),
              const SizedBox(width: 10),
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
                          color: MintColors.textMuted.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: MintColors.porcelaine,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
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
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (text) => _sendMessage(text),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Send button
              Semantics(
                button: true,
                label: s.coachSendButton,
                child: GestureDetector(
                  onTap: _isStreaming
                      ? null
                      : () => _sendMessage(_controller.text),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isStreaming
                          ? MintColors.textMuted.withValues(alpha: 0.15)
                          : MintColors.primary,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: const Icon(Icons.arrow_upward_rounded,
                        color: MintColors.white, size: 18),
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
        decoration: BoxDecoration(
          color: MintColors.textSecondary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

/// Individual typing dot with staggered animation for the loading indicator.
class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
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
          opacity: 0.3 + (_controller.value * 0.7),
          child: child,
        );
      },
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: MintColors.textMuted,
          borderRadius: BorderRadius.circular(2.5),
        ),
      ),
    );
  }
}

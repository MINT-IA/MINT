import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/services/response_card_service.dart';
import 'package:mint_mobile/widgets/coach/response_card_widget.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';

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

  const CoachChatScreen({super.key, this.initialPrompt});

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

  /// SLM stream timeout — prevents infinite hang if model deadlocks.
  static const Duration _streamTimeout = Duration(seconds: 45);

  bool _profileInitialized = false;

  @override
  void initState() {
    super.initState();
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
        _addInitialGreeting();
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
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  //  GREETING
  // ════════════════════════════════════════════════════════════

  void _addInitialGreeting() {
    assert(_profile != null);
    final p = _profile!;
    final name = p.firstName ?? 'ami·e';

    final tier = _currentTier();
    final String greeting;

    if (tier == ChatTier.slm) {
      greeting = 'Salut $name ! Je suis ton coach MINT — '
          'je tourne directement sur ton iPhone, aucune donnée ne quitte ton appareil. '
          'Pose-moi tes questions sur la prévoyance, les impôts ou la retraite.';
    } else if (_isByokConfigured) {
      greeting = CoachLlmService.initialGreeting(p);
    } else {
      final scoreSuffix = _buildGreetingScoreContext(p);
      greeting = 'Salut $name ! Je suis ton coach MINT. '
          'Pose-moi tes questions sur la prévoyance, les impôts, '
          'le budget ou la retraite en Suisse.$scoreSuffix';
    }

    // Suggested prompts personnalisees (Phase 1)
    final suggestions = ResponseCardService.suggestedPrompts(
      profile: p,
      limit: 4,
    );

    // Response cards contextuelles pour le greeting
    final greetingCards = ResponseCardService.generate(
      profile: p,
      limit: 2,
    );

    _messages.add(ChatMessage(
      role: 'assistant',
      content: greeting,
      timestamp: DateTime.now(),
      suggestedActions: suggestions,
      responseCards: greetingCards,
      tier: tier,
    ));
  }

  String _buildGreetingScoreContext(CoachProfile profile) {
    try {
      final score = FinancialFitnessService.calculate(profile: profile);
      if (score.global > 0) {
        return ' Ton score Fitness est de ${score.global}/100.';
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

    // Try SLM streaming first.
    final ctx = _buildCoachContext(_profile!);
    final stream = CoachOrchestrator.streamChat(
      userMessage: text.trim(),
      history: _messages,
      ctx: ctx,
    );

    if (stream != null) {
      await _handleStreamResponse(stream, text.trim(), ctx);
      return;
    }

    // Fallback to standard (BYOK → fallback chain).
    await _handleStandardResponse(text.trim());
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
        ? 'Je n\'ai pas pu formuler une réponse conforme. '
            'Reformule ta question ou explore les simulateurs.'
        : (compliance.sanitizedText.isNotEmpty
            ? compliance.sanitizedText
            : rawText);

    final suggestedActions = compliance.useFallback
        ? null
        : _inferSuggestedActions(userMessage);

    // Response cards contextuelles au topic
    final cards = _profile != null
        ? ResponseCardService.forChatTopic(
            profile: _profile!,
            topic: userMessage,
          )
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

  /// Handle standard (non-streaming) response via orchestrator.
  Future<void> _handleStandardResponse(String text) async {
    try {
      final config = _buildConfig();
      final response = await CoachLlmService.chat(
        userMessage: text,
        profile: _profile!,
        history: _messages,
        config: config,
      );

      final tier = config.hasApiKey ? ChatTier.byok : ChatTier.fallback;

      // Response cards contextuelles au topic
      final cards = _profile != null
          ? ResponseCardService.forChatTopic(
              profile: _profile!,
              topic: text,
            )
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
      final String errorMsg;
      switch (e.code) {
        case 'invalid_key':
          errorMsg =
              'Ta clé API semble invalide ou expirée. Vérifie-la dans les paramètres.';
          break;
        case 'rate_limit':
          errorMsg =
              'Limite de requêtes atteinte. Réessaie dans quelques instants.';
          break;
        default:
          errorMsg = 'Erreur technique. Réessaie plus tard.';
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
      setState(() {
        _messages.add(ChatMessage(
          role: 'system',
          content:
              'Erreur de connexion. Vérifie ta connexion internet ou ta clé API.',
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
    final lower = userMessage.toLowerCase();
    if (lower.contains('3a')) {
      return ['Simuler un versement 3a', 'Voir mes comptes 3a'];
    }
    if (lower.contains('lpp') || lower.contains('rachat')) {
      return ['Simuler un rachat LPP', 'Comprendre le rachat LPP'];
    }
    if (lower.contains('retraite')) {
      return ['Voir ma trajectoire', 'Explorer les scénarios'];
    }
    if (lower.contains('impot') || lower.contains('fiscal')) {
      return ['Déductions fiscales possibles', 'Simuler l\'impact fiscal'];
    }
    return ['Mon score Fitness', 'Ma trajectoire retraite'];
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
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: Text(
          'Coach MINT',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: MintColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble_outline,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Complète ton diagnostic pour discuter avec ton coach',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: MintColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.push('/advisor'),
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.primary,
                ),
                child: Text(
                  'Faire mon diagnostic',
                  style: GoogleFonts.inter(
                    fontSize: 14,
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
    final tier = _currentTier();
    return Container(
      decoration: const BoxDecoration(color: MintColors.primary),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coach MINT',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildTierSubtitle(tier),
                  ],
                ),
              ),
              if (_messages.any((m) => m.isUser))
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  tooltip: 'Exporter la conversation',
                  onPressed: _exportConversation,
                ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                tooltip: 'Paramètres IA',
                onPressed: () => context.push('/profile/byok'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierSubtitle(ChatTier tier) {
    final String label;
    final IconData icon;
    switch (tier) {
      case ChatTier.slm:
        label = 'IA on-device';
        icon = Icons.smartphone;
        break;
      case ChatTier.byok:
        label = 'IA cloud (BYOK)';
        icon = Icons.cloud_outlined;
        break;
      default:
        label = 'Mode hors-ligne';
        icon = Icons.wifi_off;
        break;
    }
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: MintColors.coachBubble,
      child: Text(
        'Outil éducatif — les réponses ne constituent pas un conseil financier. LSFin.',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: MintColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        if (msg.isSystem) return _buildSystemMessage(msg);
        if (msg.isUser) return _buildUserBubble(msg);
        return _buildCoachBubble(msg);
      },
    );
  }

  Widget _buildUserBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 48),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: MintColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                msg.content,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
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
      padding: const EdgeInsets.only(bottom: 12),
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
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
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
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: MintColors.textPrimary,
                        ),
                      ),
                      // Streaming cursor
                      if (isStreamingThis) ...[
                        const SizedBox(height: 4),
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
          // Tier badge
          if (!isStreamingThis && msg.tier != ChatTier.none) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: _buildTierBadge(msg.tier),
            ),
          ],
          // Sources
          if (msg.sources.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40, right: 48),
              child: _buildSourcesSection(msg.sources),
            ),
          ],
          // Disclaimers (from RAG backend)
          if (msg.disclaimers.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 40, right: 48),
              child: _buildDisclaimersSection(msg.disclaimers),
            ),
          ],
          // Response cards inline (Phase 1)
          if (!isStreamingThis && msg.responseCards.isNotEmpty) ...[
            const SizedBox(height: 10),
            ResponseCardStrip(cards: msg.responseCards),
          ],
          // Suggested actions
          if (!isStreamingThis &&
              msg.suggestedActions != null &&
              msg.suggestedActions!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: msg.suggestedActions!.map((action) {
                  return ActionChip(
                    label: Text(
                      action,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: MintColors.coachAccent,
                      ),
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: MintColors.coachAccent.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () => _sendMessage(action),
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
    final String label;
    final IconData icon;
    final Color color;
    switch (tier) {
      case ChatTier.slm:
        label = 'On-device';
        icon = Icons.smartphone;
        color = MintColors.success;
        break;
      case ChatTier.byok:
        label = 'Cloud';
        icon = Icons.cloud_outlined;
        color = MintColors.info;
        break;
      case ChatTier.fallback:
        label = 'Hors-ligne';
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
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: color.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemMessage(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          msg.content,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: MintColors.textMuted,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                const SizedBox(width: 8),
                Text(
                  'Réflexion en cours...',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        color: MintColors.info.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sources',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: MintColors.info.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          for (final source in sources)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: InkWell(
                onTap: () => _navigateToSource(source),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined,
                        size: 13,
                        color: MintColors.info.withOpacity(0.7)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${source.title}${source.section.isNotEmpty ? ' \u2014 ${source.section}' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: MintColors.info,
                          decoration: TextDecoration.underline,
                          decorationColor: MintColors.info.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
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
        color: MintColors.warning.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.warning.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 14, color: MintColors.warning.withOpacity(0.8)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              disclaimers.join('\n'),
              style: TextStyle(
                fontSize: 11,
                color: MintColors.warning.withOpacity(0.9),
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
      context.push('/simulator/3a');
    } else if (file.contains('lpp') || file.contains('pension')) {
      context.push('/simulator/rente-capital');
    } else if (file.contains('lifd') || file.contains('fiscal')) {
      context.push('/fiscal');
    } else if (file.contains('lavs') || file.contains('avs')) {
      context.push('/retirement');
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.send,
                  maxLines: null,
                  enabled: !_isStreaming,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Pose ta question...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: MintColors.textMuted,
                    ),
                    filled: true,
                    fillColor: MintColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
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
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: _isStreaming
                      ? MintColors.textMuted
                      : MintColors.coachAccent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  icon:
                      const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _isStreaming
                      ? null
                      : () => _sendMessage(_controller.text),
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

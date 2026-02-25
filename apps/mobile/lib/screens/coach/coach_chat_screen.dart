import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/services/rag_service.dart';

// ────────────────────────────────────────────────────────────
//  COACH CHAT SCREEN — Phase 4 / MINT Coach
// ────────────────────────────────────────────────────────────
//
// Interface de conversation avec le coach LLM.
// BYOK : l'utilisateur configure sa cle API via ByokProvider.
//
// Design :
//  - AppBar "Coach MINT" + subtitle "Conversation educative"
//  - CTA BYOK si cle non configuree
//  - Bulles de chat (user a droite, coach a gauche)
//  - Sources + disclaimers sous les reponses RAG
//  - Barre de saisie en bas avec bouton envoyer
//  - Actions suggerees en chips sous les reponses du coach
//  - Disclaimer legal en haut du chat
//  - Export PDF de la conversation
//
// Tous les textes en francais (informel "tu").
// Aucun terme banni.
// ────────────────────────────────────────────────────────────

class CoachChatScreen extends StatefulWidget {
  const CoachChatScreen({super.key});

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
  bool _isByokConfigured = false;

  bool _profileInitialized = false;

  @override
  void initState() {
    super.initState();
    // Profile will be loaded in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Charger le statut BYOK
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
      }
      // If no profile, show empty state instead of fake data
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addInitialGreeting() {
    assert(_profile != null, '_addInitialGreeting called before profile loaded');
    final p = _profile!;
    final name = p.firstName ?? 'ami·e';

    final String greeting;
    if (_isByokConfigured) {
      // BYOK active: use rich LLM-aware greeting from service
      greeting = CoachLlmService.initialGreeting(p);
    } else {
      // No BYOK: provide context-aware static greeting
      final scoreSuffix = _buildGreetingScoreContext(p);
      greeting = 'Salut $name ! Je suis ton coach MINT. '
          'Pose-moi tes questions sur la prevoyance, les impots, '
          'le budget ou la retraite en Suisse.$scoreSuffix';
    }

    // Build contextual suggested actions from top coaching tips
    final tips = CoachingService.generateTips(
      profile: p.toCoachingProfile(),
    );
    final topTipActions = tips.take(3).map((t) => t.title).toList();
    final suggestions = topTipActions.isNotEmpty
        ? topTipActions
        : CoachLlmService.initialSuggestions;

    _messages.add(ChatMessage(
      role: 'assistant',
      content: greeting,
      timestamp: DateTime.now(),
      suggestedActions: suggestions,
    ));
  }

  /// Build a short score context line for the static greeting.
  String _buildGreetingScoreContext(CoachProfile profile) {
    try {
      final score = FinancialFitnessService.calculate(profile: profile);
      if (score.global > 0) {
        return ' Ton score Fitness est de ${score.global}/100.';
      }
    } catch (_) {
      // Silently ignore — no score context
    }
    return '';
  }

  /// Construit le LlmConfig a partir du ByokProvider.
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

    try {
      final config = _buildConfig();
      final response = await CoachLlmService.chat(
        userMessage: text.trim(),
        profile: _profile!,
        history: _messages,
        config: config,
      );

      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: response.message,
          timestamp: DateTime.now(),
          suggestedActions: response.suggestedActions,
          sources: response.sources,
          disclaimers: response.disclaimers,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    } on RagApiException catch (e) {
      final String errorMsg;
      switch (e.code) {
        case 'invalid_key':
          errorMsg =
              'Ta cle API semble invalide ou expiree. Verifie-la dans les parametres.';
          break;
        case 'rate_limit':
          errorMsg =
              'Limite de requetes atteinte. Reessaie dans quelques instants.';
          break;
        default:
          errorMsg = 'Erreur technique. Reessaie plus tard.';
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
              'Erreur de connexion. Verifie ta connexion internet ou ta cle API.',
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }
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

  /// Exporte les points cles de la conversation en PDF.
  Future<void> _exportConversation() async {
    // Collecter les 5 derniers echanges Q&A
    final highlights = <Map<String, String>>[];
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].isUser && i + 1 < _messages.length && _messages[i + 1].isAssistant) {
        highlights.add({
          'question': _messages[i].content,
          'answer': _messages[i + 1].content,
        });
      }
    }
    // Limiter a 5 highlights
    final limited = highlights.length > 5
        ? highlights.sublist(highlights.length - 5)
        : highlights;

    // Collecter les sources juridiques
    final sources = <String>{};
    for (final msg in _messages) {
      for (final src in msg.sources) {
        sources.add(
            '${src.title}${src.section.isNotEmpty ? ' — ${src.section}' : ''}');
      }
    }

    // Calculer le score fitness
    int fitnessScore = 0;
    try {
      final score =
          FinancialFitnessService.calculate(profile: _profile!);
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

  @override
  Widget build(BuildContext context) {
    if (!_hasProfile) {
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
                const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Complete ton diagnostic pour discuter avec ton coach',
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

    return Scaffold(
      backgroundColor: MintColors.background,
      body: Column(
        children: [
          _buildAppBar(context),
          _buildDisclaimer(),
          if (!_isByokConfigured) _buildByokCta(),
          Expanded(
            child: _buildMessageList(),
          ),
          if (_isLoading) _buildLoadingIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MintColors.primary,
      ),
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
                    Text(
                      'Conversation educative',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Export PDF
              if (_messages.any((m) => m.isUser))
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  tooltip: 'Exporter la conversation',
                  onPressed: _exportConversation,
                ),
              // BYOK settings
              IconButton(
                icon: Icon(
                  _isByokConfigured ? Icons.settings : Icons.key,
                  color: Colors.white,
                ),
                tooltip: 'Configurer la cle API',
                onPressed: () => context.push('/profile/byok'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildByokCta() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: const Borderconst Radius.circular(16),
        border: Border.all(
          color: MintColors.coachAccent.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: MintColors.coachAccent.withValues(alpha: 0.1),
                  borderRadius: const Borderconst Radius.circular(20),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  color: MintColors.coachAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configure ton coach IA',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ajoute ta cle API pour des reponses personnalisees basees sur ton profil.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/profile/byok'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MintColors.coachAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: const Borderconst Radius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Configurer',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: MintColors.coachBubble,
      child: Text(
        'Outil educatif — les reponses ne constituent pas un conseil financier. LSFin.',
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

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        if (msg.isSystem) {
          return _buildSystemMessage(msg);
        }
        if (msg.isUser) {
          return _buildUserBubble(msg);
        }
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: MintColors.primary,
                borderRadius: const Borderconst Radius.circular(16),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar du coach
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: MintColors.coachAccent,
                  borderRadius: const Borderconst Radius.circular(16),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: MintColors.coachBubble,
                    borderRadius: const Borderconst Radius.circular(16),
                  ),
                  child: Text(
                    msg.content,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
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
          // Suggested actions as chips
          if (msg.suggestedActions != null &&
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
                      borderRadius: const Borderconst Radius.circular(20),
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
              borderRadius: const Borderconst Radius.circular(16),
            ),
            child: const Icon(
              Icons.psychology,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: MintColors.coachBubble,
              borderRadius: const Borderconst Radius.circular(16),
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
                  'Reflexion en cours...',
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

  Widget _buildSourcesSection(List<RagSource> sources) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.05),
        borderRadius: const Borderconst Radius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sources',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: MintColors.info.withValues(alpha: 0.8),
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
                        size: 13, color: MintColors.info.withValues(alpha: 0.7)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${source.title}${source.section.isNotEmpty ? ' \u2014 ${source.section}' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: MintColors.info,
                          decoration: TextDecoration.underline,
                          decorationColor: MintColors.info.withValues(alpha: 0.5),
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
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: const Borderconst Radius.circular(12),
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
                      borderRadius: const Borderconst Radius.circular(24),
                      borderSide: BorderSide(
                        color: MintColors.border.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: const Borderconst Radius.circular(24),
                      borderSide: BorderSide(
                        color: MintColors.border.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: const Borderconst Radius.circular(24),
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
                  color: MintColors.coachAccent,
                  borderRadius: const Borderconst Radius.circular(24),
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

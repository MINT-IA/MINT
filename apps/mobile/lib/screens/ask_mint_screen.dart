import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/theme/colors.dart';

/// A single chat message in the Ask MINT conversation.
class _ChatMessage {
  final String text;
  final bool isUser;
  final List<RagSource> sources;
  final List<String> disclaimers;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.sources = const [],
    this.disclaimers = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// "Ask MINT" Chat Screen - RAG-powered Q&A about Swiss finance.
///
/// Provides a ChatGPT-like interface where users can ask questions
/// about Swiss financial topics. Requires BYOK configuration.
class AskMintScreen extends StatefulWidget {
  const AskMintScreen({super.key});

  @override
  State<AskMintScreen> createState() => _AskMintScreenState();
}

class _AskMintScreenState extends State<AskMintScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _ragService = RagService();

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final byok = context.watch<ByokProvider>();

    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.background,
        title: Text(
          s?.askMintTitle ?? 'Ask MINT',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          if (byok.isConfigured)
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 22),
              tooltip: s?.byokTitle ?? 'Intelligence artificielle',
              onPressed: () => context.push('/profile/byok'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: byok.isConfigured
          ? _buildChatInterface(s, byok)
          : _buildConfigureCTA(s),
    );
  }

  // ──────────────────────────────────────────────────────────
  // CTA when BYOK is not configured
  // ──────────────────────────────────────────────────────────

  Widget _buildConfigureCTA(S? s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: MintColors.accentPastel,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: MintColors.accent,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              s?.askMintConfigureTitle ?? 'Configure ton IA',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              s?.askMintConfigureBody ??
                  'Pour poser des questions sur la finance suisse, '
                      'connecte ta propre cl\u00e9 API (Claude, OpenAI ou Mistral). '
                      'Ta cl\u00e9 reste sur ton appareil.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push('/profile/byok'),
                icon: const Icon(Icons.key, size: 18),
                label: Text(
                    s?.askMintConfigureButton ?? 'Configurer ma cl\u00e9 API'),
              ),
            ),
            const SizedBox(height: 16),
            // Privacy note
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline,
                    size: 14, color: MintColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  s?.byokPrivacyShort ??
                      'Ta cl\u00e9 API reste sur ton appareil',
                  style: const TextStyle(
                    fontSize: 12,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Chat interface (when BYOK is configured)
  // ──────────────────────────────────────────────────────────

  Widget _buildChatInterface(S? s, ByokProvider byok) {
    return Column(
      children: [
        // Messages list
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState(s)
              : ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isLoading) {
                      return _buildTypingIndicator();
                    }
                    return _buildMessageBubble(_messages[index], s);
                  },
                ),
        ),

        // Input area
        _buildInputArea(s, byok),
      ],
    );
  }

  /// Build contextual suggested questions based on user profile.
  List<String> _buildContextualSuggestions(Profile? profile) {
    final suggestions = <String>[];

    if (profile == null) {
      return [
        'Comment fonctionne le 3e pilier en Suisse ?',
        'Dois-je choisir la rente ou le capital LPP ?',
        'Comment optimiser mes imp\u00f4ts ?',
        'Qu\'est-ce que le rachat LPP ?',
      ];
    }

    // Debt-first (Safe Mode)
    if (profile.hasDebt) {
      suggestions.add(
        'J\'ai des dettes \u2014 par o\u00f9 commencer pour m\'en sortir ?',
      );
    }

    // Age-based
    final age = profile.birthYear != null
        ? DateTime.now().year - profile.birthYear!
        : null;
    if (age != null) {
      if (age < 30) {
        suggestions.add(
          'J\'ai $age ans, est-ce que je devrais d\u00e9j\u00e0 cotiser au 3e pilier ?',
        );
      } else if (age >= 30 && age < 50) {
        suggestions.add(
          'J\'ai $age ans, est-ce que je devrais racheter du LPP ?',
        );
      } else if (age >= 50) {
        suggestions.add(
          'J\'ai $age ans, comment pr\u00e9parer ma retraite au mieux ?',
        );
      }
    }

    // Employment-based
    final employment = profile.employmentStatus?.value;
    if (employment == 'self_employed') {
      suggestions.add(
        'Je suis ind\u00e9pendant\u00b7e \u2014 comment me prot\u00e9ger sans LPP ?',
      );
    } else if (employment == 'unemployed') {
      suggestions.add(
        'Je suis au ch\u00f4mage \u2014 quel impact sur ma pr\u00e9voyance ?',
      );
    }

    // Canton-based
    if (profile.canton != null) {
      suggestions.add(
        'Quelles d\u00e9ductions fiscales sont possibles dans le canton de ${profile.canton} ?',
      );
    }

    // Income-based
    if (profile.incomeNetMonthly != null && profile.incomeNetMonthly! > 0) {
      suggestions.add(
        'Avec mon revenu, combien je peux d\u00e9duire fiscalement par an ?',
      );
    }

    // Fill up to 4 with generic if needed
    final generics = [
      'Rente ou capital LPP \u2014 quelle est la diff\u00e9rence ?',
      'Comment optimiser mes imp\u00f4ts cette ann\u00e9e ?',
      'Qu\'est-ce que le rachat LPP et est-ce que \u00e7a vaut le coup ?',
      'Comment fonctionne la franchise LAMal ?',
    ];
    for (final g in generics) {
      if (suggestions.length >= 4) break;
      if (!suggestions.contains(g)) suggestions.add(g);
    }

    return suggestions.take(4).toList();
  }

  Widget _buildEmptyState(S? s) {
    final profile = context.read<ProfileProvider>().profile;
    final suggestions = _buildContextualSuggestions(profile);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),

          // Animated logo
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1D1D1F),
                  Color(0xFF2D2D30),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: MintColors.primary.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),

          // Greeting
          Text(
            s?.askMintEmptyTitle ?? 'Pose-moi ta question',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Finance suisse, d\u00e9cryptage des lois, simulateurs \u2014 '
            'je t\'explique tout, sources \u00e0 l\'appui.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Privacy badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: MintColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline,
                    size: 13, color: MintColors.success.withOpacity(0.8)),
                const SizedBox(width: 6),
                Text(
                  'Tes donn\u00e9es restent sur ton appareil',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: MintColors.success.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Contextual suggested questions
          _buildSectionLabel(
            profile != null
                ? 'POUR TOI'
                : (s?.askMintSuggestedTitle ?? 'SUGGESTIONS'),
            context,
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < suggestions.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _buildSuggestedChip(suggestions[i]),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: MintColors.textMuted,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSuggestedChip(String text) {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: () => _sendMessage(text),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: MintColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message, S? s) {
    if (message.isUser) {
      return _buildUserBubble(message);
    }
    return _buildAssistantBubble(message, s);
  }

  Widget _buildUserBubble(_ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 48),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: MintColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            message.text,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(_ChatMessage message, S? s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assistant badge
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: MintColors.accentPastel,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: MintColors.accent, size: 12),
                ),
                const SizedBox(width: 6),
                Text(
                  'MINT',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Message body
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: MintColors.border),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                fontSize: 15,
                color: MintColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),

          // Sources
          if (message.sources.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSourcesSection(message.sources, s),
          ],

          // Disclaimers
          if (message.disclaimers.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDisclaimersSection(message.disclaimers, s),
          ],
        ],
      ),
    );
  }

  Widget _buildSourcesSection(List<RagSource> sources, S? s) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.info.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s?.askMintSourcesTitle ?? 'Sources',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MintColors.info.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          for (final source in sources)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                onTap: () => _navigateToSource(source),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined,
                        size: 14, color: MintColors.info.withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${source.title}${source.section.isNotEmpty ? ' \u2014 ${source.section}' : ''}',
                        style: TextStyle(
                          fontSize: 12,
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

  Widget _buildDisclaimersSection(List<String> disclaimers, S? s) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.warning.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.warning.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 16, color: MintColors.warning.withOpacity(0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              disclaimers.join('\n'),
              style: TextStyle(
                fontSize: 12,
                color: MintColors.warning.withOpacity(0.9),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: MintColors.accentPastel,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: MintColors.accent, size: 12),
                ),
                const SizedBox(width: 6),
                Text(
                  'MINT',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: MintColors.border),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(S? s, ByokProvider byok) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.send,
              maxLines: 3,
              minLines: 1,
              onSubmitted: (_) => _onSend(),
              style: const TextStyle(
                fontSize: 15,
                color: MintColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: s?.askMintInputHint ??
                    'Pose ta question sur la finance suisse...',
                hintStyle: const TextStyle(
                  color: MintColors.textMuted,
                  fontSize: 15,
                ),
                filled: true,
                fillColor: MintColors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  borderSide:
                      const BorderSide(color: MintColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: _inputController.text.trim().isNotEmpty && !_isLoading
                  ? MintColors.primary
                  : MintColors.border,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isLoading ? null : _onSend,
              icon: Icon(
                Icons.arrow_upward,
                color: _inputController.text.trim().isNotEmpty && !_isLoading
                    ? Colors.white
                    : MintColors.textMuted,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Actions
  // ──────────────────────────────────────────────────────────

  void _onSend() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;
    _sendMessage(text);
  }

  Future<void> _sendMessage(String text) async {
    _inputController.clear();
    _focusNode.unfocus();

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    final byok = context.read<ByokProvider>();
    final profile = context.read<ProfileProvider>().profile;

    // Build profile context for personalization
    Map<String, dynamic>? profileContext;
    if (profile != null) {
      profileContext = {
        if (profile.canton != null) 'canton': profile.canton,
        if (profile.birthYear != null) 'birth_year': profile.birthYear,
        'household_type': profile.householdType.name,
        if (profile.incomeNetMonthly != null)
          'income_net_monthly': profile.incomeNetMonthly,
        if (profile.employmentStatus != null)
          'employment_status': profile.employmentStatus!.value,
        'has_debt': profile.hasDebt,
        'goal': profile.goal.name,
      };
    }

    try {
      final response = await _ragService.query(
        question: text,
        apiKey: byok.apiKey!,
        provider: byok.provider!,
        profileContext: profileContext,
        language: 'fr',
      );

      setState(() {
        _messages.add(_ChatMessage(
          text: response.answer,
          isUser: false,
          sources: response.sources,
          disclaimers: response.disclaimers,
        ));
        _isLoading = false;
      });
    } on RagApiException catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: _getErrorMessage(e.code),
          isUser: false,
          disclaimers: [],
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: S.of(context)?.askMintErrorGeneric ??
              'Une erreur est survenue. V\u00e9rifie ta connexion et r\u00e9essaie.',
          isUser: false,
          disclaimers: [],
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  String _getErrorMessage(String code) {
    final s = S.of(context);
    switch (code) {
      case 'invalid_key':
        return s?.askMintErrorInvalidKey ??
            'Ta cl\u00e9 API semble invalide ou expir\u00e9e. V\u00e9rifie-la dans les param\u00e8tres.';
      case 'rate_limit':
        return s?.askMintErrorRateLimit ??
            'Limite de requ\u00eates atteinte. Attends quelques instants avant de r\u00e9essayer.';
      default:
        return s?.askMintErrorGeneric ??
            'Une erreur est survenue. V\u00e9rifie ta connexion et r\u00e9essaie.';
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

  void _navigateToSource(RagSource source) {
    // Map known source files to app routes
    final file = source.file.toLowerCase();
    if (file.contains('3a') || file.contains('pilier')) {
      context.push('/simulator/3a');
    } else if (file.contains('lpp') || file.contains('pension')) {
      context.push('/simulator/rente-capital');
    } else if (file.contains('leasing')) {
      context.push('/simulator/leasing');
    } else if (file.contains('credit') || file.contains('cr\u00e9dit')) {
      context.push('/simulator/credit');
    } else if (file.contains('budget')) {
      context.push('/budget');
    } else {
      // Default: go to education hub
      context.push('/education/hub');
    }
  }
}

/// Animated typing dots indicator.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

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
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final progress = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = (0.3 + 0.7 * _bounce(progress));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: MintColors.textMuted,
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

  double _bounce(double t) {
    if (t < 0.5) return 4 * t * t * (3 - 4 * t);
    return 1 - 4 * (1 - t) * (1 - t) * (4 * (1 - t) - 3).abs();
  }
}

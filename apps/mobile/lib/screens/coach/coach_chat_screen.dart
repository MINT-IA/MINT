import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/widgets/coach/llm_config_sheet.dart';

// ────────────────────────────────────────────────────────────
//  COACH CHAT SCREEN — Sprint C8 / MINT Coach
// ────────────────────────────────────────────────────────────
//
// Interface de conversation avec le coach LLM.
// BYOK : l'utilisateur configure sa propre cle API.
//
// Design :
//  - SliverAppBar "Coach MINT" + subtitle "Conversation educative"
//  - Bulles de chat (user a droite, coach a gauche)
//  - Barre de saisie en bas avec bouton envoyer
//  - Actions suggerees en chips sous les reponses du coach
//  - Disclaimer legal en haut du chat
//  - Si pas de cle API : ecran de configuration
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

  late CoachProfile _profile;
  LlmConfig _config = LlmConfig.defaultOpenAI;
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  bool _profileInitialized = false;

  @override
  void initState() {
    super.initState();
    _profile = CoachProfile.buildDemo(); // Fallback until provider loads
    _addInitialGreeting();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_profileInitialized) {
      _profileInitialized = true;
      final coachProvider = context.read<CoachProfileProvider>();
      if (coachProvider.hasProfile) {
        _profile = coachProvider.profile!;
        // Re-generate greeting with real profile if it's the first message
        if (_messages.length == 1 && _messages.first.isAssistant) {
          _messages.clear();
          _addInitialGreeting();
          if (mounted) setState(() {});
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

  void _addInitialGreeting() {
    final greeting = CoachLlmService.initialGreeting(_profile);
    _messages.add(ChatMessage(
      role: 'assistant',
      content: greeting,
      timestamp: DateTime.now(),
      suggestedActions: CoachLlmService.initialSuggestions,
    ));
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
      final response = await CoachLlmService.chat(
        userMessage: text.trim(),
        profile: _profile,
        history: _messages,
        config: _config,
      );

      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: response.message,
          timestamp: DateTime.now(),
          suggestedActions: response.suggestedActions,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          role: 'system',
          content: 'Erreur de connexion. Verifie ta cle API.',
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

  void _openConfigSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LlmConfigSheet(
        config: _config,
        onSave: (newConfig) {
          setState(() {
            _config = newConfig;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: Column(
        children: [
          _buildAppBar(context),
          _buildDisclaimer(),
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
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                tooltip: 'Configurer la cle API',
                onPressed: _openConfigSheet,
              ),
            ],
          ),
        ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: MintColors.coachBubble,
                    borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  color: MintColors.coachAccent,
                  borderRadius: BorderRadius.circular(24),
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

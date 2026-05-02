import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
// ADR-20260223: financial_core via barrel only — no direct sub-imports.
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/auth/auth_gate_bottom_sheet.dart';

/// Data class for a single chat message in the anonymous flow.
class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

/// Full-screen anonymous chat overlay — no tabs, no shell, no drawer.
///
/// The user arrives here after tapping a felt-state pill on the intent screen.
/// They can send 3 messages. After the 3rd coach response, a conversion
/// prompt appears as a coach message, followed by the auth gate bottom sheet.
/// Dismissing the gate locks input but preserves the conversation.
class AnonymousChatScreen extends StatefulWidget {
  /// The felt-state pill text or free-text from the intent screen.
  final String? intent;

  const AnonymousChatScreen({super.key, this.intent});

  @override
  State<AnonymousChatScreen> createState() => _AnonymousChatScreenState();
}

class _AnonymousChatScreenState extends State<AnonymousChatScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _conversationId = 'anonymous_${DateTime.now().millisecondsSinceEpoch}';
  bool _isLoading = false;
  bool _isAuthGateLocked = false;
  bool _intentSent = false;

  /// User-provided gross annual salary for the anonymous AVS+LPP rente
  /// quick estimate. Null until the user enters a value in the teaser.
  /// When non-null, the teaser flips from « EXEMPLE TYPE » to a
  /// computed projection via AvsCalculator + LppCalculator (real-data
  /// wedge, ferme l'audit Bug #1 « anonymous user never sees the
  /// chat-vivant value » per panel review 2026-05-02).
  double? _wedgeAnnualSalary;
  final TextEditingController _wedgeSalaryController = TextEditingController();

  /// Visible inline error for the wedge input. Per panel compliance review
  /// (PR #424): silent rejection of out-of-range salaries violated nFADP
  /// art. 6 al. 3 transparency spirit + UX. Now we surface a plain hint.
  String? _wedgeError;

  @override
  void initState() {
    super.initState();
    if (widget.intent != null && widget.intent!.isNotEmpty) {
      // Auto-send the intent as the first user message after build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_intentSent) {
          _intentSent = true;
          _sendMessage(widget.intent!);
        }
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _wedgeSalaryController.dispose();
    super.dispose();
  }

  /// Compute the anonymous user's AVS+LPP monthly rente projection from
  /// their gross annual salary input. Per ADR-20260223 (financial_core
  /// = single source of truth), uses `AvsCalculator.computeMonthlyRente`
  /// from the barrel. Anonymous defaults: currentAge=40, retirementAge=65,
  /// arrivalAge=20 (full Swiss career), no lacunes. The number returned
  /// is intentionally an estimate, not a personalized projection — the
  /// teaser labels it accordingly (« Estimation rapide » badge).
  ///
  /// Returns CHF/month rounded to nearest CHF.
  int _computeAnonymousRenteEstimate(double grossAnnualSalary) {
    final monthly = AvsCalculator.computeMonthlyRente(
      currentAge: 40,
      retirementAge: 65,
      arrivalAge: 20,
      grossAnnualSalary: grossAnnualSalary,
    );
    return monthly.round();
  }

  /// Format an integer CHF amount with French thousands separators
  /// (« 3 187 » not « 3,187 » or « 3187 »). Uses fine-space (U+2009)
  /// for visual rhythm — Inter renders it cleanly.
  String _formatChfAmount(int amount) {
    final str = amount.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(' ');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Check if user can still send
    final canSend = await AnonymousSessionService.canSendMessage();
    if (!canSend) {
      _showAuthGate();
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(
        text: trimmed,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
      _inputController.clear();
    });
    _scrollToBottom();

    // Only pass intent on the first message
    final isFirstMessage = _messages.where((m) => m.isUser).length == 1;

    final response = await CoachChatApiService.sendAnonymousMessage(
      message: trimmed,
      intent: isFirstMessage ? widget.intent : null,
    );

    if (!mounted) return;

    final isError = response['error'] == true;
    final coachMessage = response['message'] as String? ?? '';
    final messagesRemaining = response['messagesRemaining'] as int? ?? -1;
    final errorType = response['errorType'] as String?;

    if (isError || coachMessage.isEmpty) {
      // Walk 2026-04-24 P0-2: map errorType → specific ARB copy instead of
      // generic "Je rencontre un problème technique" for every failure mode.
      final l = S.of(context)!;
      final text = switch (errorType) {
        'network' => l.anonymousChatErrorNetwork,
        'service' => l.anonymousChatErrorService,
        'session' => l.anonymousChatErrorSession,
        _ => l.anonymousChatError,
      };
      setState(() {
        _messages.add(_ChatMessage(
          text: text,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(
        text: coachMessage,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _isLoading = false;
    });
    _scrollToBottom();

    // Persist eagerly after each coach response so messages survive navigation.
    _persistToSharedPreferences();

    // After 3rd response (messagesRemaining == 0), show conversion prompt
    if (messagesRemaining == 0) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      final l = S.of(context)!;
      setState(() {
        _messages.add(_ChatMessage(
          text: l.anonymousChatConversionPrompt,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();

      // Persist again after conversion prompt so it is also saved.
      _persistToSharedPreferences();

      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _showAuthGate();
    }
  }

  void _showAuthGate() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MintColors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AuthGateBottomSheet(
        onDismissed: _onDismissed,
      ),
    );
  }

  void _onDismissed() {
    setState(() {
      _isAuthGateLocked = true;
    });
  }

  /// Persist anonymous messages to SharedPreferences (unprefixed keys) so
  /// auth_provider._migrateLocalDataIfNeeded() can find and migrate them
  /// after account creation, regardless of navigation path.
  ///
  /// Fire-and-forget — never blocks UI. Called after each coach response.
  void _persistToSharedPreferences() {
    // Convert local _ChatMessage list to ChatMessage for ConversationStore.
    final chatMessages = _messages
        .map((m) => ChatMessage(
              role: m.isUser ? 'user' : 'assistant',
              content: m.text,
              timestamp: m.timestamp,
            ))
        .toList();

    // Save under anonymous namespace (null userId = unprefixed keys).
    ConversationStore.setCurrentUserId(null);
    ConversationStore().saveConversation(_conversationId, chatMessages).catchError((e) {
      debugPrint('[AnonymousChat] Eager persist failed: $e');
    });
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

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.craie,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar — back button only
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: MintColors.textPrimary,
                  onPressed: () => context.go('/'),
                  tooltip: l.anonymousChatBack,
                ),
              ),
            ),

            // Messages list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    // Loading indicator
                    return _buildTypingIndicator();
                  }
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),

            // Visual demo teaser — shown after the first coach response
            // (≥ 2 messages: 1 user + 1 coach) to demonstrate the « chat
            // vivant » value prop while the user is still anonymous.
            // Tap → /auth/login. Hidden once the auth gate locks (the
            // locked CTA below already drives registration). HARDCODED
            // FR strings for v1 ship; i18n migration tracked as follow-up.
            if (!_isAuthGateLocked && _messages.length >= 2)
              _buildVisualDemoTeaser(context),

            // Locked state — persistent CTA
            if (_isAuthGateLocked) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: MintColors.lightBorder),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      l.anonymousChatLocked,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: MintColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _showAuthGate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MintColors.primary,
                          foregroundColor: MintColors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          l.anonymousChatCreateAccount,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],

            // Input bar — hidden when locked
            if (!_isAuthGateLocked)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                decoration: const BoxDecoration(
                  color: MintColors.craie,
                  border: Border(
                    top: BorderSide(color: MintColors.lightBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        enabled: !_isLoading,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _isLoading ? null : _sendMessage,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: MintColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: l.anonymousIntentFreeTextHint,
                          hintStyle: GoogleFonts.inter(
                            fontSize: 16,
                            color: MintColors.textMuted,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded),
                      color: _isLoading
                          ? MintColors.textMuted
                          : MintColors.primary,
                      onPressed: _isLoading
                          ? null
                          : () => _sendMessage(_inputController.text),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUser ? MintColors.primary : MintColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
          ),
          child: Text(
            message.text,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: isUser ? MintColors.white : MintColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _TypingDot(delay: i * 200),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  //  Visual demo teaser (Anonymous Chat — feature-preview CTA)
  //
  //  Renders an inline « what MINT looks like once it knows you »
  //  preview card after the first coach response. Built with theme
  //  primitives only (no Phase 49.5 dependency, lands cleanly on dev).
  //
  //  Per panel review 2026-05-02 (compliance + adversarial + brand):
  //  - Visible « EXEMPLE TYPE — pas une projection sur ta situation »
  //    label above the figure (LSFin art. 7-8 salience).
  //  - One chiffre-héros only (Handoff 2 §6 « UN SEUL chiffre »).
  //  - No mood labels « sécurité / liberté » (banned-term adjacent +
  //    Cleo Hype Mode register MINT explicitly avoids).
  //  - Reframed phrase de recul as feature-description, not promise.
  //  - CTA → /auth/register (panel-caught route mismatch).
  //  - Semantics labels for a11y screen readers.
  //
  //  HARDCODED FR strings for v1 — i18n extraction is a follow-up PR
  //  gated on Phase 52 settings work landing.
  // ───────────────────────────────────────────────────────────────────
  Widget _buildVisualDemoTeaser(BuildContext context) {
    final l = S.of(context)!;
    // Wedge state: if user has provided a salary, compute an INDICATIVE
    // estimate via AvsCalculator (financial_core barrel, ADR-20260223).
    // Defaults baked in (currentAge=40, retirementAge=65, arrivalAge=20,
    // no lacunes, no divorce, no child credits, refAge=65/male) — copy
    // says « estimation indicative » throughout with assumptions surfaced.
    final hasUserData = _wedgeAnnualSalary != null && _wedgeAnnualSalary! > 0;
    final heroAmount = hasUserData
        ? _formatChfAmount(_computeAnonymousRenteEstimate(_wedgeAnnualSalary!))
        : '3 187';
    final salienceLabel = hasUserData
        ? l.wedgeTeaserSalienceEstimate
        : l.wedgeTeaserSalienceExample;
    final assumptionsLine = hasUserData
        ? l.wedgeTeaserAssumptionsEstimate
        : l.wedgeTeaserAssumptionsExample;
    final reculLine = hasUserData
        ? l.wedgeTeaserReculEstimate
        : l.wedgeTeaserReculExample;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MintColors.lightBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow — uppercase, Inter, tracked. Color uses warningAaa
          // (4.5:1 contrast on white) instead of corailDiscret which
          // failed WCAG AA at this size.
          Semantics(
            label: hasUserData
                ? l.wedgeTeaserEyebrowEstimate
                : l.wedgeTeaserEyebrowExample,
            child: ExcludeSemantics(
              child: Text(
                hasUserData
                    ? l.wedgeTeaserEyebrowEstimate
                    : l.wedgeTeaserEyebrowExample,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: MintColors.warningAaa,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
          // Hero headline removed (Julien feedback 2026-05-02 + literary
          // expert lens added to panel pattern): « Tes vrais chiffres.
          // Pas une démo générique. » was AI-generated-marketing copy
          // (« malin pour être malin », parallel hyphen-pair clichéd
          // structure VOICE_SYSTEM §1 explicitly bans). Per VOICE_SYSTEM §10
          // « Le silence parle » — let the eyebrow + salience badge +
          // figure carry the load. The data IS the message.
          const SizedBox(height: 12),
          // Visible salience label — REQUIRED above the figure per
          // LSFin art. 7-8 (panel compliance review). Color flips
          // sauge → corail subtly when the figure is the user's own
          // estimate, but stays a salience label (never claims
          // « guaranteed » / « will get » — uses « estimation »).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (hasUserData ? MintColors.saugeClaire : MintColors.warningAaa)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (hasUserData ? MintColors.saugeClaire : MintColors.warningAaa)
                    .withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: Text(
              salienceLabel,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: hasUserData
                    ? MintColors.primary
                    : MintColors.warningAaa,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Single chiffre-héros (Handoff 2 §6 « UN SEUL chiffre »).
          // When `hasUserData` is true, this is the live AvsCalculator
          // result for the user's salary; otherwise the AVS-typical
          // exemple. Either way one number, never two.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Semantics(
                label: l.wedgeTeaserHeroSemantics(heroAmount),
                child: ExcludeSemantics(
                  child: Text(
                    heroAmount,
                    style: GoogleFonts.fraunces(
                      fontSize: 44,
                      fontWeight: FontWeight.w500,
                      color: MintColors.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l.wedgeTeaserChfPerMonth,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Visible assumptions — concrete, defensible scenario context.
          Text(
            assumptionsLine,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: MintColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          // Real-data wedge — single salary input, computed via
          // AvsCalculator from financial_core barrel (ADR-20260223).
          // Shown ONLY when user hasn't yet provided a salary; once
          // entered, the figure above flips to the real estimate and
          // this input collapses out.
          if (!hasUserData) _buildWedgeSalaryInput(context),
          if (hasUserData) ...[
            // Edit affordance once the user has computed. 48dp tap target
            // restored (no shrinkWrap override) per a11y review.
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _wedgeAnnualSalary = null;
                    _wedgeSalaryController.clear();
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                child: Text(
                  l.wedgeTeaserModifySalary,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Reframed phrase de recul — feature description, not promise.
          Text(
            reculLine,
            style: GoogleFonts.fraunces(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // CTA noir (Handoff 2 §6) — routes to /auth/register
          // (panel code review caught the previous /auth/login mismatch).
          SizedBox(
            width: double.infinity,
            child: Semantics(
              label: l.wedgeTeaserCtaRegister,
              button: true,
              child: TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.go('/auth/register');
                },
                style: TextButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  foregroundColor: MintColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l.wedgeTeaserCtaRegister,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Inline single-input wedge that lets the anonymous user provide
  /// their gross annual salary and triggers a live AVS rente estimate
  /// via `AvsCalculator.computeMonthlyRente` (financial_core barrel,
  /// ADR-20260223 compliant). One field on purpose: low-intent
  /// anonymous flow stays frictionless.
  Widget _buildWedgeSalaryInput(BuildContext context) {
    final l = S.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.wedgeSalaryInputLabel,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: l.wedgeSalaryInputLabel,
                  textField: true,
                  child: TextField(
                    controller: _wedgeSalaryController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                      signed: false,
                    ),
                    textInputAction: TextInputAction.done,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: MintColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: '95 000',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 16,
                        color: MintColors.textMuted,
                      ),
                      suffixText: 'CHF',
                      suffixStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textSecondary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: MintColors.lightBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: MintColors.lightBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: MintColors.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: _commitWedgeSalary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: l.wedgeSalaryInputActionSemantics,
                button: true,
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _commitWedgeSalary(_wedgeSalaryController.text);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: MintColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    l.wedgeSalaryInputAction,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Inline error (replaces silent no-op; nFADP art. 6 al. 3
          // transparency + UX feedback per panel review). errorAaa token
          // (4.5:1 contrast on white) replaces corailDiscret which failed.
          if (_wedgeError != null) ...[
            const SizedBox(height: 6),
            Text(
              _wedgeError!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.errorAaa,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l.wedgeSalaryStaysOnDevice,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Validate + commit a salary input. Strips spaces and the « . » /
  /// « ' » thousand separators (DE-CH / FR-CH conventions). Surfaces a
  /// visible inline hint when input is invalid (panel compliance review:
  /// silent rejection violated nFADP art. 6 al. 3 transparency spirit).
  /// Triggers `setState` so the teaser flips to its `hasUserData` branch.
  void _commitWedgeSalary(String raw) {
    final l = S.of(context)!;
    final cleaned = raw
        .replaceAll(RegExp(r"[\s '.]"), '')
        .trim();
    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      setState(() {
        _wedgeError = l.wedgeSalaryErrorInvalid;
      });
      return;
    }
    if (parsed < 10000 || parsed > 1000000) {
      setState(() {
        _wedgeError = l.wedgeSalaryErrorOutOfRange;
      });
      return;
    }
    setState(() {
      _wedgeAnnualSalary = parsed;
      _wedgeError = null;
    });
  }
}

/// Animated dot for typing indicator.
class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
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
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: MintColors.textMuted,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

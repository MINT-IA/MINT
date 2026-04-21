import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/chat/fact_extraction_fallback.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/response_card_service.dart';
import 'package:mint_mobile/services/coach/context_injector_service.dart';
import 'package:mint_mobile/services/coach/tool_call_parser.dart';
import 'package:mint_mobile/services/coach/chat_tool_dispatcher.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/lightning_menu.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/widgets/coach/coach_app_bar.dart';
import 'package:mint_mobile/widgets/coach/coach_input_bar.dart';
import 'package:mint_mobile/widgets/coach/coach_loading_indicator.dart';
import 'package:mint_mobile/widgets/coach/coach_message_bubble.dart';
import 'package:mint_mobile/models/coach_insight.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart'
    show VoicePreference;
import 'package:mint_mobile/widgets/coach/chat_drawer_host.dart';
import 'package:mint_mobile/widgets/pulse/cap_card.dart' show CapCoachBridge;

// ────────────────────────────────────────────────────────────
//  COACH CHAT SCREEN — SLM-first, streaming, prod-ready
//
//  Extracted components (W13 refactoring, 4193→836 lines):
//  - CoachAppBar         → widgets/coach/coach_app_bar.dart
//  - CoachEmptyState     → DELETED (KILL-02, Phase 2)
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

  /// Optional structured entry payload for contextual coach sessions.
  /// When present, overrides initialPrompt with topic-specific context.
  /// Wire Spec V2 §3.6 — CoachEntryPayload carries source + topic + data.
  final CoachEntryPayload? entryPayload;

  const CoachChatScreen({
    super.key,
    this.initialPrompt,
    this.conversationId,
    this.isEmbeddedInTab = false,
    this.entryPayload,
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
  /// Maximum messages kept in memory to prevent Watchdog RAM termination.
  static const int _maxMessages = 150;

  /// Remove oldest messages when list exceeds [_maxMessages].
  void _trimMessages() {
    if (_messages.length > _maxMessages) {
      _messages.removeRange(0, _messages.length - _maxMessages);
    }
  }

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

  // Random greeting index removed 2026-04-18 (performative voice deprecated).

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

  /// Extra context from CoachEntryPayload, injected into the system prompt.
  /// One-shot: cleared after first use.
  String? _entryPayloadContext;

  /// ARB chip key from onboarding intent selection (e.g. 'intentChip3a').
  /// Set in _loadOnboardingPayload. Consumed once in _addInitialGreeting.
  String? _pendingIntentChipKey;

  /// Intent-specific opener text for the silent opener (D-06).
  /// Non-null only on the first session after intent selection.
  String? _intentOpenerText;

  /// Subscription to ScreenCompletionTracker for immediate reaction
  /// when user completes a simulation and returns to coach.
  StreamSubscription<ScreenReturn>? _screenReturnSub;

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
    _loadOnboardingPayload();
    _subscribeToScreenReturns();
    _consumeCapCoachBridge();
  }

  /// Consume any pending prompt from CapCoachBridge (set by CapCard).
  /// Converts the raw prompt string into a CoachEntryPayload context injection.
  void _consumeCapCoachBridge() {
    final capPrompt = CapCoachBridge.consume();
    if (capPrompt != null && capPrompt.isNotEmpty) {
      _entryPayloadContext = const CoachEntryPayload(
        source: CoachEntrySource.signal,
        topic: 'capAction',
      ).toContextInjection();
    }
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
    } catch (e) {
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
    } catch (e) {
      // Best-effort persistence.
      debugPrint('[CoachChat] ${e.toString().substring(0, (e.toString().length > 80) ? 80 : e.toString().length)}');
    }
  }

  /// Phase 10-02a: write the miniOnboardingCompleted flag on first chat
  /// entry from an onboarding-intent payload. Idempotent: re-entering the
  /// coach chat later with another intent payload is a no-op.
  Future<void> _markOnboardingCompletedIfNeeded() async {
    try {
      final already =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      if (!already) {
        await ReportPersistenceService.setMiniOnboardingCompleted(true);
      }
    } catch (e) {
      // Best-effort: chat continues even if the flag cannot be written.
      debugPrint('[CoachChat] ${e.toString().substring(0, (e.toString().length > 80) ? 80 : e.toString().length)}');
    }
  }

  /// Load onboarding payload (one-shot).
  ///
  /// Phase 10-02a: emotion replay dropped — coach reacts to facts, not
  /// to a pre-captured mood. Only the selected intent chip key is loaded
  /// for the first-session opener (D-06).
  Future<void> _loadOnboardingPayload() async {
    try {
      // Load onboarding intent for first-session opener (D-06).
      final selectedIntent =
          await ReportPersistenceService.getSelectedOnboardingIntent();
      final hasSeen =
          await ReportPersistenceService.hasSeenPremierEclairage();
      if (selectedIntent != null && !hasSeen && mounted) {
        setState(() {
          _pendingIntentChipKey = selectedIntent;
        });
      }
    } catch (e) {
      // Graceful degradation: coach works without onboarding payload.
      debugPrint('[CoachChat] ${e.toString().substring(0, (e.toString().length > 80) ? 80 : e.toString().length)}');
    }
  }

  /// Load an existing conversation from persistent storage.
  Future<void> _loadExistingConversation(String id) async {
    final messages = await _conversationStore.loadConversation(id);
    if (messages.isNotEmpty && mounted) {
      setState(() {
        _messages.addAll(messages);
        _trimMessages();
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
        // Wire Spec V2: structured entry payload takes priority
        if (widget.entryPayload != null) {
          final payload = widget.entryPayload!;
          // Phase 10-02a: onboarding-done ownership moved here from
          // intent_screen. Conversation is the only honest "onboarding
          // done" signal — the flag is set on the first successful chat
          // entry carried by an onboarding-intent payload.
          if (payload.source == CoachEntrySource.onboardingIntent &&
              payload.data?['fromOnboarding'] == true) {
            _markOnboardingCompletedIfNeeded();
          }
          if (payload.userMessage != null) {
            // User typed a free-form message — send it directly
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _sendMessage(payload.userMessage!);
            });
          } else if (payload.topic == 'onboarding') {
            // Onboarding topic — send a real intake question instead of
            // injecting raw context. This replaces the old ?prompt=onboarding.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _sendMessage(
                'Salut, je viens de creer mon compte. Par ou je commence\u00a0?',
              );
            });
          } else if (_isNotificationTopic(payload.topic)) {
            // Notification topics (monthlyCheckIn, commitmentReminder,
            // freshStart): inject a coach-authored opening message so the
            // conversation starts with a concrete question tied to the
            // notification intent, not a generic greeting.
            final opener = _notificationOpener(payload.topic!, payload.data);
            if (opener != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _addCoachOpenerMessage(opener);
              });
            }
            // Still inject the topic context so downstream prompts know
            // this is a notification-driven entry.
            _entryPayloadContext = payload.toContextInjection();
          } else if (payload.topic != null) {
            // Topic-based entry — inject context into system prompt.
            // The topic context is injected via the memory block,
            // not as a user message.
            _entryPayloadContext = payload.toContextInjection();
          }
        }
      } else {
        // CHAT-01: Anonymous user (no profile) — show silent opener
        // with the question text. The opener invites the user to type,
        // and data capture (CHAT-04) will collect profile data inline.
        if (!_isResumingConversation) {
          setState(() {
            _showSilentOpener = true;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _screenReturnSub?.cancel();
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

  /// Subscribe to ScreenCompletionTracker stream so the coach can react
  /// immediately when the user completes a simulation (e.g., document scan,
  /// retirement dashboard) and returns to the chat.
  void _subscribeToScreenReturns() {
    _screenReturnSub = ScreenCompletionTracker.stream.listen((screenReturn) {
      if (!mounted) return;
      // Inject the screen return as context for the next coach response.
      final fields = screenReturn.updatedFields;
      final fieldSummary = fields != null && fields.isNotEmpty
          ? fields.entries.map((e) => '${e.key}: ${e.value}').join(', ')
          : '';
      final contextLine = "L'utilisateur vient de terminer une simulation "
          "(${screenReturn.route}, r\u00e9sultat\u00a0: ${screenReturn.outcome.name})"
          "${fieldSummary.isNotEmpty ? '. Donn\u00e9es mises \u00e0 jour\u00a0: $fieldSummary' : ''}.";
      _entryPayloadContext = contextLine;
    });
  }

  // ════════════════════════════════════════════════════════════
  //  SILENT OPENER — coach shows a NUMBER, not a greeting
  // ════════════════════════════════════════════════════════════

  void _addInitialGreeting() {
    assert(_profile != null);

    // Intent-aware opener (D-06): resolve chip-specific text on first session.
    if (_pendingIntentChipKey != null) {
      final l10n = S.of(context);
      if (l10n != null) {
        final resolved = resolveIntentOpener(_pendingIntentChipKey!, l10n);
        if (resolved != null) {
          _intentOpenerText = resolved;
        }
      }
      _pendingIntentChipKey = null; // consume once
    }

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

  /// Returns true if [topic] is a notification-driven entry topic that
  /// should trigger a coach-authored opening message.
  bool _isNotificationTopic(String? topic) {
    if (topic == null) return false;
    return topic == 'monthlyCheckIn' ||
        topic == 'commitmentReminder' ||
        topic == 'freshStart';
  }

  /// Returns the opening coach message for a notification topic, or null
  /// if the topic has no dedicated opener.
  ///
  /// [data] may carry notification-specific fields. For commitmentReminder,
  /// `data['commitment']` (String) is interpolated into the message.
  String? _notificationOpener(String topic, Map<String, dynamic>? data) {
    switch (topic) {
      case 'monthlyCheckIn':
        return 'On fait le point sur le mois\u00a0?';
      case 'commitmentReminder':
        final commitment = data?['commitment']?.toString();
        if (commitment != null && commitment.trim().isNotEmpty) {
          return 'Tu m\u2019avais dit que tu allais $commitment. C\u2019est fait\u00a0?';
        }
        return 'Tu avais un engagement a tenir. C\u2019est fait\u00a0?';
      case 'freshStart':
        return 'Nouveau mois. On commence par quoi\u00a0?';
      default:
        return null;
    }
  }

  /// Appends a coach-authored opening message to the conversation.
  /// Dismisses the silent opener so the chat feels like a live conversation.
  void _addCoachOpenerMessage(String content) {
    if (!mounted) return;
    setState(() {
      _showSilentOpener = false;
      _messages.add(ChatMessage(
        role: 'assistant',
        content: content,
        timestamp: DateTime.now(),
        tier: ChatTier.none,
      ));
    });
    _scrollToBottom();
  }

  /// Increment the conversation count in SharedPreferences.
  Future<void> _incrementConversationCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_conversationCountKey) ?? 0;
      await prefs.setInt(_conversationCountKey, count + 1);
    } catch (e) {
      // Best-effort persistence.
      debugPrint('[CoachChat] ${e.toString().substring(0, (e.toString().length > 80) ? 80 : e.toString().length)}');
    }
  }

  /// Compute the key financial number to display in the silent opener.
  /// Returns (formattedNumber, headline) or null if no data available.
  ({String number, String headline})? _computeKeyNumber() {
    if (_profile == null) return null;
    final s = S.of(context)!;

    // Priority 1: most recent enrichment fact (LPP avoir or 3a épargne) —
    // surfaces a raw number the user JUST added to their profile, so the
    // coach acknowledges the upload instead of opening silent. Factual,
    // not projected (anti-shame: fact of the world, not judgment of user).
    final avoirLpp = _profile!.prevoyance.avoirLppTotal;
    if (avoirLpp != null && avoirLpp > 0) {
      return (
        number: _formatChf(avoirLpp),
        headline: s.coachSilentOpenerLppAvoir,
      );
    }
    final epargne3a = _profile!.prevoyance.totalEpargne3a;
    if (epargne3a > 0) {
      return (
        number: _formatChf(epargne3a),
        headline: s.coachSilentOpener3aEpargne,
      );
    }

    // Priority 2: financial fitness score — neutral, life-event-agnostic.
    try {
      final score = FinancialFitnessService.calculate(profile: _profile!);
      final g = score.global;
      if (g > 0) {
        return (
          number: '$g/100',
          headline: s.coachSilentOpenerFitnessScore,
        );
      }
    } catch (e) { debugPrint("[CoachChat] best-effort: $e"); }

    // Priority 3: replacement rate (retirement-framed — only surfaces when
    // nothing neutral above is available and the user has enough data for
    // a projection; headline now neutralized to "taux de remplacement
    // projeté" without the "à la retraite" qualifier).
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
    } catch (e) { debugPrint("[CoachChat] best-effort: $e"); }

    // Priority 4: projected capital (same neutralization rationale).
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
          headline: s.coachSilentOpenerProjectedCapital,
        );
      }
    } catch (e) { debugPrint("[CoachChat] best-effort: $e"); }

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
          if (!mounted) return;
          // CHAT-02: Open as drawer over chat instead of full-page push.
          final widget = ChatDrawerHost.resolveDrawerWidget(route);
          if (widget != null) {
            showChatDrawer(context: context, child: widget);
          } else {
            // NAV-03/WID-03: Routes without drawer support (e.g. /scan,
            // /profile/bilan) fall back to standard push navigation.
            context.push(route);
          }
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
    final l10n = S.of(context)!;
    final String confirmation;
    switch (level) {
      case 1:
        confirmation = l10n.intensityConfirmation1;
        break;
      case 2:
        confirmation = l10n.intensityConfirmation2;
        break;
      case 3:
        confirmation = l10n.intensityConfirmation3;
        break;
      case 4:
        confirmation = l10n.intensityConfirmation4;
        break;
      case 5:
        confirmation = l10n.intensityConfirmation5;
        break;
      default:
        confirmation = l10n.intensityDirect;
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
    _focusNode.unfocus();

    // AUTH NOTE: Auth gate was moved AFTER SLM attempt (see _handleStandardResponse).
    // Anonymous users CAN chat via SLM (on-device, no auth needed).
    // Auth is only required when falling back to server-key API calls.

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
    } catch (e) {
      // Graceful degradation: chat works without memory block.
      debugPrint('[CoachChat] ${e.toString().substring(0, (e.toString().length > 80) ? 80 : e.toString().length)}');
    }

    // Wire Spec V2: append entry payload context if present (one-shot).
    if (_entryPayloadContext != null) {
      memoryBlock = '${memoryBlock ?? ''}\n$_entryPayloadContext';
      _entryPayloadContext = null; // one-shot: clear after first use
    }

    // CHAT-01: Load profile if available — never invent fake data.
    // If no profile exists, use default CoachProfile (all zeros/empty).
    // The system prompt detects confidence=0 and asks for real data.
    if (_profile == null) {
      final provider = context.read<CoachProfileProvider>();
      if (provider.hasProfile) {
        _profile = provider.profile;
      } else {
        // Minimal profile with no fake data — zeros mean "unknown".
        _profile = CoachProfile.defaults();
      }
      _hasProfile = provider.hasProfile;
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
    } catch (e) {
      compliance = ComplianceResult(
        isCompliant: true,
        sanitizedText: ComplianceGuard.sanitizeBannedTerms(rawText),
      );
    }

    final complianceText = compliance.useFallback
        ? S.of(context)!.coachComplianceError
        : (compliance.sanitizedText.isNotEmpty
            ? compliance.sanitizedText
            : rawText);

    // Wire Spec V2 §3.6: parse tool call markers from response.
    final parseResult = ToolCallParser.parse(complianceText);
    final finalText = parseResult.cleanText.isNotEmpty
        ? parseResult.cleanText
        : complianceText;

    // Phase 1: generate inline response cards from user message
    final cards = _profile != null
        ? ResponseCardService.generateForChat(_profile!, userMessage, l: S.of(context)!)
        : <ResponseCard>[];

    // T-02-05: normalize and cap tool calls via ChatToolDispatcher.
    final richCalls = ChatToolDispatcher.normalize(parseResult.toolCalls);

    // Audit 2026-04-18 Wave 5 (user feedback): les 3 chips statiques
    // inférées par regex ("Si je verse plus sur mon 3a", "J'ai combien sur
    // mes comptes 3a", "Ça vaut le coup de racheter du LPP") remplissaient
    // l'écran à CHAQUE réponse coach et étaient insupportables. On ne garde
    // que les chips générées par le LLM via route_to_screen tool_use — ce
    // sont des actions CONTEXTUELLES produites par le modèle, pas une
    // béquille regex. Si le coach ne demande aucune action, l'user tape ce
    // qui l'intéresse. Panel contrarian 2026-04-18 : les chips par défaut
    // sont une béquille.
    final routeChips = _extractRouteChips(richCalls);
    final suggestedActions = routeChips.take(3).toList();

    setState(() {
      _messages[_messages.length - 1] = ChatMessage(
        role: 'assistant',
        content: finalText,
        timestamp: DateTime.now(),
        suggestedActions: suggestedActions.isEmpty ? null : suggestedActions,
        responseCards: cards,
        tier: ChatTier.slm,
        richToolCalls: richCalls,
      );
      _isStreaming = false;
      _trimMessages();
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
      // Capture l10n before await to avoid using BuildContext across async gap.
      final l10n = S.of(context)!;
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
          ? ResponseCardService.generateForChat(_profile!, text, l: l10n)
          : <ResponseCard>[];

      // Wire Spec V2 §3.6: parse tool call markers from response.
      final parseResult = ToolCallParser.parse(response.message);
      final cleanMessage = parseResult.cleanText.isNotEmpty
          ? parseResult.cleanText
          : response.message;

      // T-02-06: normalize and cap tool calls via ChatToolDispatcher.
      // STAB-03 / STAB-04: merge structured toolCalls from the orchestrator
      // (BYOK path — Claude tool_use blocks re-exposed by CoachLlmService.chat)
      // with marker-parsed toolCalls (SLM / legacy text path). Both feed
      // WidgetRenderer via CoachMessageBubble.richToolCalls.
      final markerCalls = ChatToolDispatcher.normalize(parseResult.toolCalls);
      final structuredCalls = ChatToolDispatcher.filterRag(response.toolCalls);
      final richCalls = <RagToolCall>[
        ...structuredCalls,
        ...markerCalls,
      ].take(5).toList();

      // Audit 2026-04-18 Wave 5 : on ne garde que les chips produites par
      // le LLM (suggestedActions directes + route_to_screen tool_use).
      // L'ancienne inférence regex générait 3 chips statiques à chaque
      // réponse, même quand le sujet ne s'y prêtait pas — fatigant UX.
      final llmActions = response.suggestedActions ?? const <String>[];
      final routeChips = _extractRouteChips(richCalls);
      final suggestedActions = <String>{
        ...llmActions,
        ...routeChips,
      }.take(3).toList();

      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: cleanMessage,
          timestamp: DateTime.now(),
          suggestedActions: suggestedActions,
          sources: response.sources,
          disclaimers: response.disclaimers,
          responseCards: cards,
          tier: tier,
          richToolCalls: richCalls,
          // v2.7 Task 8: surface degraded flag to bubble for subtle chip.
          degraded: response.degraded,
        ));
        _isLoading = false;
        _trimMessages();
      });
      _scrollToBottom();

      // Wire S58: extract and persist insight from BYOK/fallback exchange.
      _extractAndSaveInsight(text, cleanMessage);

      // Dispatch `save_fact` tool_use blocks locally so that anonymous users
      // (the default on fresh installs) actually persist the fields the coach
      // just extracted. Backend `save_fact` only writes to ProfileModel.data
      // when user_id is present — anon sessions fall through to "Fait noté
      // (hors DB)" and lose the value otherwise.
      if (mounted) {
        final provider = context.read<CoachProfileProvider>();
        for (final call in response.toolCalls) {
          if (call.name != 'save_fact') continue;
          final key = call.input['key'];
          final value = call.input['value'];
          final conf = call.input['confidence']?.toString() ?? 'medium';
          if (key is String && value != null) {
            unawaited(provider.applySaveFact(key, value, confidence: conf));
          }
        }

        // Safety-net extraction: anonymous users don't get backend save_fact
        // (user_id required) and the INTERNAL_TOOL_NAMES filter strips the
        // tool from external_calls even for authenticated users. Run a
        // first-person-only regex fallback on the user message so the
        // profile actually fills when the user types « j'ai 34 ans, je
        // gagne 7500 brut/mois ». Source: MVP-PLAN-2026-04-21 P0-MVP-1
        // étape 1B. Never fires for canton/householdType — those require
        // explicit LLM save_fact, not brittle regex.
        unawaited(FactExtractionFallback.extract(text, provider));
      }

      // Sync profile from backend after each coach exchange.
      // save_fact writes server-side; this pulls those updates into Flutter.
      if (mounted) {
        context.read<CoachProfileProvider>().syncFromBackend();
      }

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
      // Recover last user message so the user can retry with one tap.
      final lastUserText = _messages
          .lastWhere((m) => m.isUser, orElse: () => ChatMessage(
                role: 'user',
                content: '',
                timestamp: DateTime.now(),
              ))
          .content;
      setState(() {
        _messages.add(ChatMessage(
          role: 'system',
          content: errorMsg,
          timestamp: DateTime.now(),
          suggestedActions: [
            if (lastUserText.isNotEmpty) lastUserText,
          ],
        ));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[CoachChat] Standard response error: $e');

      // ── Anonymous fallback: if user is not logged in, try the public
      // /anonymous/chat endpoint (3 free messages) before showing an error.
      // This bridges the gap between the SLM-first path (which needs no auth)
      // and the server-key path (which requires JWT).
      final auth = context.read<AuthProvider>();
      if (!auth.isLoggedIn) {
        try {
          final anonResponse = await CoachChatApiService.sendAnonymousMessage(
            message: text,
          );
          if (!mounted) return;
          final anonMsg = anonResponse['message'] as String? ?? '';
          final remaining = anonResponse['messagesRemaining'] as int? ?? -1;

          if (anonMsg.isNotEmpty) {
            setState(() {
              _messages.add(ChatMessage(
                role: 'assistant',
                content: anonMsg,
                timestamp: DateTime.now(),
                disclaimers: (anonResponse['disclaimers'] as List?)
                        ?.cast<String>() ??
                    const [],
                tier: ChatTier.fallback,
              ));
              _isLoading = false;
            });
            _scrollToBottom();

            // Show auth gate when anonymous quota is exhausted.
            if (remaining == 0) {
              _showAnonymousAuthGate();
            }
            return;
          }
        } catch (anonError) {
          debugPrint('[CoachChat] Anonymous fallback also failed: $anonError');
        }
      }

      // Recover the last user message for retry suggestion.
      final lastUserMsg = _messages
          .lastWhere((m) => m.isUser, orElse: () => ChatMessage(
                role: 'user',
                content: '',
                timestamp: DateTime.now(),
              ))
          .content;
      final retryActions = <String>[
        if (lastUserMsg.isNotEmpty) lastUserMsg,
      ];
      setState(() {
        _messages.add(ChatMessage(
          role: 'system',
          content: S.of(context)!.coachErrorConnection,
          timestamp: DateTime.now(),
          suggestedActions: retryActions,
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
      id: '${DateTime.now().millisecondsSinceEpoch}_$topic',
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
    } catch (e) {
      // Best-effort — don't block chat.
      debugPrint('[CoachChat] ${e.toString().substring(0, (e.toString().length > 80) ? 80 : e.toString().length)}');
    }
  }

  /// Show auth gate when anonymous message quota is exhausted.
  ///
  /// Adds a coach message inviting the user to create an account,
  /// with tappable chips for register / login.
  void _showAnonymousAuthGate() {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        role: 'assistant',
        content:
            'On a deja decouvert quelques pistes ensemble. '
            'Cree ton compte pour que je me souvienne de tout.',
        timestamp: DateTime.now(),
        suggestedActions: ['Creer mon compte', 'J\'ai deja un compte'],
        tier: ChatTier.none,
      ));
    });
    _scrollToBottom();
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
    } catch (e) {
      // Best-effort.
      debugPrint('[CoachChat] ${e.toString().substring(0, (e.toString().length > 80) ? 80 : e.toString().length)}');
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
    } catch (e) { debugPrint("[CoachChat] best-effort: $e"); }

    try {
      final proj = ForecasterService.project(
        profile: profile,
        targetDate: profile.goalA.targetDate,
      );
      final cap = proj.base.capitalFinal;
      final taux = proj.tauxRemplacementBase;
      if (cap.isFinite && cap > 0) knownValues['capital_final'] = cap;
      if (taux.isFinite && taux > 0) knownValues['replacement_ratio'] = taux;
    } catch (e) { debugPrint("[CoachChat] best-effort: $e"); }

    return CoachContext(
      firstName: profile.firstName ?? 'utilisateur',
      age: profile.age,
      canton: profile.canton,
      knownValues: knownValues,
      hasDebt: profile.isInDebtCrisis,
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

    // UX-04: No hardcoded defaults. Chips appear ONLY when the
    // conversation matches a topic regex — otherwise the list is empty
    // and no chips are shown. This prevents static/irrelevant chips
    // from appearing after every response regardless of context.
    // Deduplicate and cap at 3
    return actions.toSet().take(3).toList();
  }

  /// UX-04: Extract contextual chip labels from route_to_screen tool calls.
  ///
  /// When the LLM returns a route_to_screen tool call, it includes a
  /// context_message explaining why the user should navigate there.
  /// We surface these as tappable suggestion chips so the user has
  /// both the inline card AND a quick-tap chip option.
  List<String> _extractRouteChips(List<RagToolCall> toolCalls) {
    final chips = <String>[];
    for (final call in toolCalls) {
      if (call.name != 'route_to_screen') continue;
      final contextMsg = call.input['context_message'] as String? ??
          call.input['narrative'] as String?;
      if (contextMsg != null && contextMsg.isNotEmpty) {
        // Cap chip text at 60 chars for UI readability
        final label = contextMsg.length > 60
            ? '${contextMsg.substring(0, 57)}...'
            : contextMsg;
        chips.add(label);
      }
    }
    return chips;
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
    } catch (e) { debugPrint("[CoachChat] best-effort: $e"); }

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

    // Handle anonymous auth gate chips.
    if (action == 'Creer mon compte') {
      context.push('/auth/register');
      return;
    }
    if (action == 'J\'ai deja un compte') {
      context.push('/auth/login');
      return;
    }

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
          content: S.of(context)!.coachProactiveDecline,
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
      // CHAT-02: Open as drawer over chat instead of full-page push.
      final drawerWidget = ChatDrawerHost.resolveDrawerWidget(route);
      if (drawerWidget != null) {
        showChatDrawer(context: context, child: drawerWidget);
      }
    } else {
      _sendMessage(action);
    }
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // CoachEmptyState deleted (KILL-02). Chat always renders — coach speaks first.

    return Scaffold(
      backgroundColor: MintColors.craie,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CoachAppBar(
              isEmbeddedInTab: widget.isEmbeddedInTab,
              hasUserMessages: _messages.any((m) => m.isUser),
              onBack: () => safePop(context),
              onHistory: () async {
                final router = GoRouter.of(context);
                await _autoSaveConversation();
                if (mounted) router.push('/coach/history');
              },
              onExport: _exportConversation,
              onSettings: () => context.push('/profile/byok'),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: _showSilentOpener
                    ? _buildSilentOpenerWithTone()
                    : _buildMessageList(),
              ),
            ),
            if (_isLoading) const CoachLoadingIndicator(),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewPadding.bottom,
              ),
              child: CoachInputBar(
                controller: _controller,
                focusNode: _focusNode,
                isStreaming: _isStreaming,
                onSend: () => _sendMessage(_controller.text),
                onLightningMenu: _showLightningMenu,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SILENT OPENER WITH TONE CHIPS (CHAT-05)
  // ════════════════════════════════════════════════════════════

  /// Silent opener + optional intensity chips. One visual anchor at a time:
  /// if the profile carries a key number or intent override, show that;
  /// otherwise the SilentOpener's own minimal empty state renders — no
  /// piquant random greeting (deprecated 2026-04-18 — performative voice
  /// was fatiguing users who open the app daily; calm minimalism wins).
  Widget _buildSilentOpenerWithTone() {
    final Widget hero = _buildSilentOpener();

    final body = Expanded(
      child: SingleChildScrollView(child: hero),
    );

    if (_intensityChosen || !_cashLevelLoaded) {
      return Column(children: [body]);
    }

    return Column(
      children: [
        body,
        Padding(
          padding: const EdgeInsets.only(left: 42, right: 24, bottom: 16),
          child: _buildIntensityChips(),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SILENT OPENER WIDGET — a key number, not a greeting
  // ════════════════════════════════════════════════════════════

  Widget _buildSilentOpener() {
    final s = S.of(context)!;

    // D-06: intent-aware opener on first session.
    if (_intentOpenerText != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _intentOpenerText!,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textPrimary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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

    final keyData = _computeKeyNumber();

    // If no financial data available, show the first-contact opener +
    // 4 conversation starter chips. Gated on _messages.isEmpty so the
    // opener disappears as soon as the user starts typing or taps a chip.
    // Spec: MVP-PLAN-2026-04-21 § P0-MVP-2 (PM panel wording).
    if (keyData == null && _messages.isEmpty) {
      return _buildFirstContactOpener(s);
    }
    if (keyData == null) {
      // Fallback — profile empty but conversation started. Silent frame.
      return const SizedBox.shrink();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The number, big, alone — the headline below qualifies it and
            // the input bar at the bottom already invites the user in, so
            // we drop the faded "Tu veux en parler ?" prompt (60% opacity
            // italic undermined the calm of the frame and the adult tone).
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
            Text(
              keyData.headline,
              style: const TextStyle(
                fontSize: 15,
                color: MintColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  FIRST-CONTACT OPENER (MVP P0-MVP-2)
  // ════════════════════════════════════════════════════════════

  /// Opener widget shown on the very first Parle-à-Mint tap for users with
  /// no profile data and no message history. Combines a 3-line identity +
  /// promise + question with 4 starter chips that route to the right flow.
  /// Disappears as soon as the user types or taps a chip — respects the
  /// « silent chat » doctrine (no widgets hanging around unused).
  Widget _buildFirstContactOpener(S s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.coachOpenerIdentity,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.coachOpenerPromise,
            style: const TextStyle(
              fontSize: 15,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            s.coachOpenerQuestion,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _OpenerChip(
            label: s.coachStarterPaper,
            onTap: () => _handleOpenerChip(_OpenerIntent.paper),
          ),
          const SizedBox(height: 10),
          _OpenerChip(
            label: s.coachStarterChoice,
            onTap: () => _handleOpenerChip(_OpenerIntent.choice),
          ),
          const SizedBox(height: 10),
          _OpenerChip(
            label: s.coachStarterCost,
            onTap: () => _handleOpenerChip(_OpenerIntent.cost),
          ),
          const SizedBox(height: 10),
          _OpenerChip(
            label: s.coachStarterLurk,
            subtle: true,
            onTap: () => _handleOpenerChip(_OpenerIntent.lurk),
          ),
        ],
      ),
    );
  }

  Future<void> _handleOpenerChip(_OpenerIntent intent) async {
    // Mark the opener as seen so it doesn't re-render after a scan/chat
    // returns to this screen. Uses the same flag the silent-opener hero
    // number already depends on.
    await ReportPersistenceService.markPremierEclairageSeen();
    if (!mounted) return;
    switch (intent) {
      case _OpenerIntent.paper:
        // Route directly to the scanner — the chip wording already made
        // the intent clear, no need for an intermediate coach turn.
        context.push('/scan');
      case _OpenerIntent.choice:
        // Pre-fills a user message so the coach has a context anchor
        // rather than a cold « Dis-moi ». The user can still edit it.
        _controller.text = 'Un choix que je dois faire';
        _focusNode.requestFocus();
      case _OpenerIntent.cost:
        _controller.text =
            "Un truc qui me coute chaque mois, je sais pas quoi";
        _focusNode.requestFocus();
      case _OpenerIntent.lurk:
        // Opt-out: dismiss the opener without forcing any action.
        if (mounted) setState(() {});
    }
  }

  // ════════════════════════════════════════════════════════════
  //  MESSAGE LIST
  // ════════════════════════════════════════════════════════════

  Widget _buildMessageList() {
    return RepaintBoundary(
      child: ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.md, vertical: 24),
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
          // v2.7 Task 8: compose bubble + subtle degraded chip (if applicable).
          final bubbleWidget = CoachMessageBubble(
            message: msg,
            messageIndex: index,
            isStreaming:
                _isStreaming && msg == _messages.last && msg.tier == ChatTier.slm,
            isInputAnswered: _answeredInputIndices.contains(index),
            onInputSubmitted: _handleInputSubmitted,
            onActionTap: _handleActionTap,
          );
          child = Semantics(
            label: S.of(context)!.coachCoachMessage,
            child: msg.degraded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bubbleWidget,
                      Padding(
                        padding: const EdgeInsets.only(left: 42, top: 4),
                        child: Text(
                          S.of(context)!.coachResponseDegradedHint,
                          style: TextStyle(
                            fontSize: 11,
                            color: MintColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  )
                : bubbleWidget,
          );
        }

        // Wrap with intensity picker for first assistant message if needed.
        final bool showIntensity = _cashLevelLoaded &&
            !_intensityChosen &&
            index == 0 &&
            msg.isAssistant &&
            !(_isStreaming && msg == _messages.last);

        // Show transparency badge under the first assistant response in session.
        final bool isFirstAssistantInSession = msg.isAssistant &&
            !(_isStreaming && msg == _messages.last) &&
            index == _messages.indexWhere((m) => m.isAssistant);

        final Widget wrappedChild = (showIntensity || isFirstAssistantInSession)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  child,
                  if (isFirstAssistantInSession) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 42),
                      child: Text(
                        msg.tier == ChatTier.slm
                            ? S.of(context)!.coachTransparencySLM
                            : S.of(context)!.coachTransparencyBYOK,
                        style: MintTextStyles.micro(
                          color: MintColors.textMuted.withValues(alpha: 0.5),
                        ).copyWith(
                          fontStyle: FontStyle.italic,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                  if (showIntensity) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 42),
                      child: _buildIntensityChips(),
                    ),
                  ],
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

  /// CHAT-05: Build tone preference chips (Doux / Direct / Sans filtre).
  ///
  /// Shown once in the first conversation after the first assistant message.
  /// Maps to VoicePreference enum and persists via CoachProfileProvider.
  Widget _buildIntensityChips() {
    final chips = <MapEntry<VoicePreference, String>>[
      const MapEntry(VoicePreference.soft, 'Doux'),
      const MapEntry(VoicePreference.direct, 'Direct'),
      const MapEntry(VoicePreference.unfiltered, 'Sans filtre'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          // Was 'Au fait, tu préfères que je sois plutôt…' — the dangling
          // ellipsis read as a truncation bug and the chips below already
          // list the options, making the long phrasing redundant.
          'Comment je te parle\u00a0?',
          style: TextStyle(
            fontSize: 14,
            color: MintColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: chips.map((entry) {
            return GestureDetector(
              onTap: () => _onTonePreferenceSelected(entry.key),
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
        ),
      ],
    );
  }

  /// CHAT-05: Handle tone preference chip selection.
  void _onTonePreferenceSelected(VoicePreference pref) {
    final int level;
    final String confirmation;
    switch (pref) {
      case VoicePreference.soft:
        level = 1;
        confirmation = 'Not\u00e9. Je serai tout en douceur.';
      case VoicePreference.direct:
        level = 3;
        confirmation = 'Compris. Je vais droit au but.';
      case VoicePreference.unfiltered:
        level = 5;
        confirmation = 'OK. Accroche-toi, je ne filtre rien.';
    }

    final provider = context.read<CoachProfileProvider>();
    provider.setVoiceCursorPreference(pref);

    setState(() {
      _cashLevel = level;
      _intensityChosen = true;
      _showSilentOpener = false;
      _messages.add(ChatMessage(
        role: 'assistant',
        content: confirmation,
        timestamp: DateTime.now(),
        tier: ChatTier.none,
      ));
    });
    _saveCashLevel(level);
    _scrollToBottom();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  INTENT OPENER RESOLVER — top-level for testability (D-06, D-07)
// ═══════════════════════════════════════════════════════════════════════════════

/// Maps an onboarding chip key to an intent-specific coach opener string.
///
/// Returns null when:
///   - [chipKey] is unrecognised (graceful degradation → generic opener)
///
/// Kept as a top-level function so tests can call it directly without
/// needing to mount the full CoachChatScreen widget tree.
///
/// Each of the 7 intent keys must produce a **distinct** non-null string.
/// Unknown keys must return null (D-07).
String? resolveIntentOpener(String chipKey, S l10n) {
  final openers = <String, String>{
    'intentChip3a': l10n.coachOpenerIntent3a,
    'intentChipBilan': l10n.coachOpenerIntentBilan,
    'intentChipPrevoyance': l10n.coachOpenerIntentPrevoyance,
    'intentChipFiscalite': l10n.coachOpenerIntentFiscalite,
    'intentChipProjet': l10n.coachOpenerIntentProjet,
    'intentChipChangement': l10n.coachOpenerIntentChangement,
    'intentChipAutre': l10n.coachOpenerIntentAutre,
  };
  return openers[chipKey];
}

/// Intent emitted when the user taps one of the 4 first-contact opener
/// chips. Keeps the action dispatch in one switch rather than per-chip
/// callbacks so the opener UI stays declarative.
enum _OpenerIntent { paper, choice, cost, lurk }

/// One starter chip in the first-contact opener. Rectangular pill with
/// subtle border — intentionally not a filled button because MINT's
/// opener isn't selling engagement, it's offering entry paths.
class _OpenerChip extends StatelessWidget {
  const _OpenerChip({
    required this.label,
    required this.onTap,
    this.subtle = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final textColor =
        subtle ? MintColors.textSecondary : MintColors.textPrimary;
    final borderColor = subtle
        ? MintColors.textSecondary.withValues(alpha: 0.2)
        : MintColors.textPrimary.withValues(alpha: 0.3);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: subtle ? FontWeight.w400 : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

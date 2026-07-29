import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mint_mobile/services/navigation/mint_nav.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_user_state.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/screens/coach/coach_archetype_guard.dart';
import 'package:mint_mobile/screens/waitlist/waitlist_args.dart';
import 'package:mint_mobile/services/coach/coach_context_profile_mapper.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/telemetry/gate_decision_telemetry.dart';
import 'package:mint_mobile/services/chat/fact_extraction_fallback.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/coach/local_fallback_service.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';
import 'package:mint_mobile/services/response_card_service.dart';
import 'package:mint_mobile/services/coach/context_injector_service.dart';
import 'package:mint_mobile/services/coach/tool_call_parser.dart';
import 'package:mint_mobile/services/coach/chat_tool_dispatcher.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/data_spine/coach_context_packet_adapter.dart';
import 'package:mint_mobile/services/data_spine/coach_packet_insight_presenter.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/services/coach/precomputed_insights_service.dart';
import 'package:mint_mobile/services/coach/proactive_trigger_service.dart'
    show ProactiveTrigger, ProactiveTriggerType;
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/widgets/coach/lightning_menu.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/widgets/coach/coach_app_bar.dart';
import 'package:mint_mobile/widgets/coach/coach_input_bar.dart';
import 'package:mint_mobile/widgets/coach/coach_loading_indicator.dart';
import 'package:mint_mobile/widgets/coach/coach_message_bubble.dart';
import 'package:mint_mobile/widgets/coach/coach_packet_insight_card.dart';
import 'package:mint_mobile/widgets/coach/response_card_widget.dart'
    show ResponseCardStrip;
import 'package:mint_mobile/models/coach_insight.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/services/sequence/sequence_chat_handler.dart';
import 'package:mint_mobile/services/sequence/sequence_coordinator.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/widgets/coach/chat_drawer_host.dart';
import 'package:mint_mobile/widgets/pulse/cap_card.dart' show CapCoachBridge;

typedef CoachContextInjectorBuilder = Future<EnrichedContext> Function({
  CoachProfile? profile,
  SharedPreferences? prefs,
  DateTime? now,
  MintUserState? mintState,
});

Future<EnrichedContext> _defaultCoachContextInjectorBuilder({
  CoachProfile? profile,
  SharedPreferences? prefs,
  DateTime? now,
  MintUserState? mintState,
}) {
  return ContextInjectorService.buildContext(
    profile: profile,
    prefs: prefs,
    now: now,
    mintState: mintState,
  );
}

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

  /// Test seam for the enriched context builder.
  ///
  /// Production always uses [ContextInjectorService.buildContext].
  @visibleForTesting
  final CoachContextInjectorBuilder? contextBuilder;

  const CoachChatScreen({
    super.key,
    this.initialPrompt,
    this.conversationId,
    this.isEmbeddedInTab = false,
    this.entryPayload,
    this.contextBuilder,
  });

  @override
  State<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends State<CoachChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  CoachProfile? _profile;
  final List<ChatMessage> _messages = [];
  final DateTime _screenOpenedAt = DateTime.now();

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
  bool _budgetHydrationScheduled = false;

  bool _isResumingConversation = false;

  /// Tracks message indices whose inline input pickers have been answered.
  /// Once answered, the picker is replaced by the user's response text.
  final Set<int> _answeredInputIndices = {};

  /// Voice intensity level (1-5). Persisted in SharedPreferences.
  /// 1 = Tranquille, 2 = Clair (default), 3 = Direct, 4 = Cash, 5 = Brut
  int _cashLevel = 2;

  /// Whether the silent opener is currently displayed (no messages yet).
  bool _showSilentOpener = false;

  /// Garde anti-boucle du flux consentement (beads MINT_nosync-tcr) :
  /// un seul retry après grant — si le backend re-403 malgré le grant,
  /// l'erreur générique s'affiche au lieu de re-présenter la sheet.
  bool _consentRetryInFlight = false;

  // Random greeting index removed 2026-04-18 (performative voice deprecated).

  /// SharedPreferences keys for proactive opt-in tracking.
  static const String _conversationCountKey = 'mint_coach_conversation_count';
  static const String _proactiveOptInKey = 'mint_coach_proactive_optin';
  static const String _proactiveOptInAskedKey =
      'mint_coach_proactive_optin_asked';

  /// Whether the proactive opt-in question has been shown this session.
  bool _optInShownThisSession = false;

  /// Whether a `ProactiveTrigger` has been surfaced as an opener this
  /// session. Per-day deduplication is upstream in
  /// [ProactiveTriggerService.evaluate] (cooldown on evaluation date);
  /// this flag prevents re-showing within a single screen lifetime.
  bool _proactiveTriggerShownThisSession = false;

  /// SharedPreferences key for voice intensity level.
  static const String _cashLevelKey = 'mint_coach_cash_level';

  /// Extra context from CoachEntryPayload, injected into the system prompt.
  /// One-shot: cleared after first use.
  String? _entryPayloadContext;
  late final DateTime _screenReturnHydrationCutoff;

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
    _screenReturnHydrationCutoff = DateTime.now();
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
          _cashLevel = (level ?? 3).clamp(1, 5);
        });
      }
    } catch (e) {
      // Graceful degradation: keep default direct level.
    }
  }

  /// Save voice intensity to SharedPreferences.
  Future<void> _saveCashLevel(int level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_cashLevelKey, level);
    } catch (e) {
      // Best-effort persistence.
      debugPrint(
          '[CoachChat] ${e.toString().substring(0, (e.toString().length > 80) ? 80 : e.toString().length)}');
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
      debugPrint(
          '[CoachChat] ${e.toString().substring(0, (e.toString().length > 80) ? 80 : e.toString().length)}');
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
      final hasSeen = await ReportPersistenceService.hasSeenPremierEclairage();
      if (selectedIntent != null && !hasSeen && mounted) {
        setState(() {
          _pendingIntentChipKey = selectedIntent;
        });
      }
    } catch (e) {
      // Graceful degradation: coach works without onboarding payload.
      debugPrint(
          '[CoachChat] ${e.toString().substring(0, (e.toString().length > 80) ? 80 : e.toString().length)}');
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
    _scheduleBudgetHydrationForSilentOpener();
    final coachProvider = Provider.of<CoachProfileProvider>(context);
    _syncProfileFromProvider(coachProvider);

    if (!_profileInitialized) {
      _profileInitialized = true;
      if (coachProvider.hasProfile) {
        _profile = coachProvider.profile!;
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
            // B1 fix (2026-05-08) : the previous `_sendMessage(...)` call
            // rendered the seed string as user-authored, producing a
            // phantom message « Salut, je viens de créer mon compte. Par
            // où je commence ? » that the user never wrote (CLAUDE.md
            // NEVER #6 + 0-Trust §9.1 trust killer). Switch to a
            // coach-initiated opener so the coach speaks first and the
            // user answers — same pattern as _isNotificationTopic below.
            // The old ARB key coachOnboardingFirstUserMessage is
            // deprecated (no callers post-fix); flutter gen-l10n keeps
            // the binding for backwards compat but it is not referenced
            // in lib/.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _addCoachOpenerMessage(
                S.of(context)!.coachOnboardingFirstAssistantGreeting,
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
        } else if (!_isResumingConversation && _profile!.hasMaterialData) {
          // No entryPayload + authenticated + fresh conversation:
          // - Empty / identity-only profiles keep the first-contact opener.
          //   A weekly recap or cached insight before any material financial
          //   data is collected feels like invented knowledge and breaks the
          //   empty-state cascade from « Mon bilan ».
          // - Phase 54-02 T-03 — first try to surface a precomputed
          //   insight (Cleo 3.0 pattern: profile-change-time computation
          //   read instantly at greeting time). If the cache is non-empty
          //   AND fresh, surface it as a tappable chip and skip the
          //   proactive trigger fallback (« 1 opener chip per chat-open »
          //   rule per Plan 54-02 risks section).
          // - Otherwise fall back to a `MintStateProvider.pendingTrigger`
          //   if one was evaluated this calendar day.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybeSurfaceOpenerOnChatOpen();
          });
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

  void _scheduleBudgetHydrationForSilentOpener() {
    if (_budgetHydrationScheduled) return;
    _budgetHydrationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateBudgetForSilentOpener();
    });
  }

  Future<void> _hydrateBudgetForSilentOpener() async {
    if (!mounted) return;
    if (_profile == null || !_profile!.hasMaterialData) return;
    final budgetProvider = _readBudgetProviderIfAvailable();
    if (budgetProvider == null || budgetProvider.hasFreshInputs) return;
    final restored = await budgetProvider.loadFromStorage();
    if (restored && mounted) setState(() {});
  }

  BudgetProvider? _readBudgetProviderIfAvailable() {
    try {
      return context.read<BudgetProvider>();
    } on ProviderNotFoundException {
      return null;
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
    _screenReturnSub =
        ScreenCompletionTracker.stream.listen((screenReturn) async {
      if (!mounted) return;

      // Phase 53-02 \u2014 if a guided sequence is active, dispatch through
      // SequenceChatHandler.handleRealtimeReturn FIRST. The handler
      // returns null when no sequence is active OR when the event is
      // a stale / wrong-run / duplicate event (its own guards), in
      // which case we fall back to the legacy contextLine path.
      try {
        final result =
            await SequenceChatHandler.handleRealtimeReturn(screenReturn);
        if (!mounted) return;
        if (result != null) {
          _injectSequencePrompt(result);
          return;
        }
      } catch (e) {
        // Sequence dispatch must never block the contextLine fallback.
        debugPrint('[coach_chat] sequence dispatch fallback: $e');
      }

      _entryPayloadContext = _screenReturnContextLine(screenReturn);
    });
  }

  Future<void> _hydrateLatestScreenReturnForNextRequest() async {
    final screenReturn = await ScreenCompletionTracker.consumeLatestReturn(
      after: _screenReturnHydrationCutoff,
    );
    if (screenReturn == null) return;
    _entryPayloadContext = _screenReturnContextLine(screenReturn);
  }

  String _screenReturnContextLine(ScreenReturn screenReturn) {
    final fields = screenReturn.updatedFields;
    final fieldSummary = fields != null && fields.isNotEmpty
        ? fields.entries.map((e) => '${e.key}: ${e.value}').join(', ')
        : '';
    return "L'utilisateur vient de terminer une simulation "
        "(${screenReturn.route}, r\u00e9sultat\u00a0: ${screenReturn.outcome.name})"
        "${fieldSummary.isNotEmpty ? '. Donn\u00e9es mises \u00e0 jour\u00a0: $fieldSummary' : ''}.";
  }

  // Phase 53-02 \u2014 inject the sequence's next-step prompt as a coach
  // message. For now handles AdvanceAction (the most common path) and
  // CompleteAction; other actions fall back to the contextLine path
  // (handled by the caller when this returns without enqueueing).
  void _injectSequencePrompt(SequenceHandlerResult result) {
    if (!mounted) return;
    final action = result.action;

    final l10n = S.of(context);

    if (action is AdvanceAction) {
      // Render the next step as a coach-side suggestion: a route
      // suggestion card pointing at the next step's screen.
      // Phase 54-02 T-04: route the \u00ab \u00c9tape suivante : \u2026 \u00bb string
      // through ARB so all 6 locales render correctly + the
      // accent_lint_fr / no_hardcoded_fr lints don't regress.
      final nextStepText = l10n != null
          ? l10n.coachSequenceNextStepLabel(action.progressLabel)
          : '\u00c9tape suivante : ${action.progressLabel}.';
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: nextStepText,
          timestamp: DateTime.now(),
          richToolCalls: [
            RagToolCall(
              name: 'route_to_screen',
              input: {
                'intent': action.nextStep.intentTag,
                'route': action.route,
                'context_message': action.progressLabel,
                'prefill': action.prefill,
              },
            ),
          ],
        ));
      });
      return;
    }

    if (action is CompleteAction) {
      // Phase 54-02 T-04: ARB-route the completion string.
      final completionText = l10n?.coachSequenceCompletedMessage ??
          'Tu as termin\u00e9 cette s\u00e9quence guid\u00e9e.';
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: completionText,
          timestamp: DateTime.now(),
        ));
      });
      return;
    }

    // PauseAction / SkipAction / RetryAction / ReEvaluateAction:
    // for this initial wiring we let the caller fall back to the
    // legacy contextLine path. A follow-up plan can render dedicated
    // UI for each branch.
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
    final l = S.of(context)!;
    switch (topic) {
      case 'monthlyCheckIn':
        return l.coachNotificationOpenerMonthlyCheckIn;
      case 'commitmentReminder':
        final commitment = data?['commitment']?.toString();
        if (commitment != null && commitment.trim().isNotEmpty) {
          return l.coachNotificationOpenerCommitmentWithLabel(commitment);
        }
        return l.coachNotificationOpenerCommitmentGeneric;
      case 'freshStart':
        return l.coachNotificationOpenerFreshStart;
      default:
        return null;
    }
  }

  /// Appends a coach-authored opening message to the conversation.
  /// Dismisses the silent opener so the chat feels like a live conversation.
  ///
  /// Phase 54-02: when [intentTag] is non-null AND maps to a ScreenRegistry
  /// entry, also emit a `route_to_screen` rich tool call so the existing
  /// `widget_renderer._buildRouteSuggestion` path renders a tappable
  /// `RouteSuggestionCard`. Without [intentTag], behavior is unchanged
  /// (plain text bubble — legacy callers).
  void _addCoachOpenerMessage(
    String content, {
    String? intentTag,
    String? routeHint,
    String? contextMessage,
  }) {
    if (!mounted) return;
    final richCalls = <RagToolCall>[];
    if (intentTag != null && intentTag.isNotEmpty) {
      richCalls.add(RagToolCall(
        name: 'route_to_screen',
        input: <String, dynamic>{
          'intent': intentTag,
          if (routeHint != null && routeHint.isNotEmpty) 'route': routeHint,
          'context_message': contextMessage ?? content,
          'prefill': const <String, dynamic>{},
        },
      ));
    }
    setState(() {
      _showSilentOpener = false;
      _messages.add(ChatMessage(
        role: 'assistant',
        content: content,
        timestamp: DateTime.now(),
        tier: ChatTier.none,
        richToolCalls: richCalls,
      ));
    });
    _scrollToBottom();
  }

  /// Resolve a [ProactiveTrigger] to its localized opener string.
  ///
  /// `messageKey` on the trigger refers to a generated `AppLocalizations`
  /// getter or method; the switch routes through the strongly-typed
  /// API so missing params surface at compile time instead of runtime.
  String _resolveProactiveOpener(S l, ProactiveTrigger t) {
    switch (t.type) {
      case ProactiveTriggerType.lifecyclePhaseChange:
        return l.proactiveLifecycleChange;
      case ProactiveTriggerType.weeklyRecapAvailable:
        return l.proactiveWeeklyRecap;
      case ProactiveTriggerType.goalMilestone:
        return l.proactiveGoalMilestone(t.params?['progress'] ?? '');
      case ProactiveTriggerType.seasonalReminder:
        return l.proactiveSeasonalReminder(t.params?['event'] ?? '');
      case ProactiveTriggerType.inactivityReturn:
        return l.proactiveInactivityReturn(t.params?['days'] ?? '');
      case ProactiveTriggerType.confidenceImproved:
        return l.proactiveConfidenceUp(t.params?['delta'] ?? '');
      case ProactiveTriggerType.newCapAvailable:
        return l.proactiveNewCap;
      case ProactiveTriggerType.contractDeadlineApproaching:
        return l.proactiveContractDeadline(
          t.params?['days'] ?? '',
          t.params?['label'] ?? '',
        );
    }
  }

  /// Phase 54-02 T-03 — surface a single coach opener on chat-open.
  ///
  /// Precedence (« 1 opener chip per chat-open » per Plan 54-02 risks):
  ///   1. Precomputed insight (Cleo 3.0 pattern — pre-computed at
  ///      profile-change time by [PrecomputedInsightsService.computeAndCache]
  ///      and read instantly here). Cache is consumed once: cleared after
  ///      surfacing so the next open falls back to the proactive path
  ///      until the next state recompute.
  ///   2. Proactive trigger (legacy path — `MintStateProvider.pendingTrigger`).
  ///
  /// When neither produces a result, the silent opener stays as the
  /// only visual anchor.
  Future<void> _maybeSurfaceOpenerOnChatOpen() async {
    if (_proactiveTriggerShownThisSession) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final insight =
          await PrecomputedInsightsService.getCachedInsight(prefs: prefs);
      if (!mounted) return;
      if (insight != null) {
        final l10n = S.of(context);
        if (l10n != null) {
          final resolved = insight.resolve(l10n);
          if (resolved != null && resolved.message.isNotEmpty) {
            // Mark the session flag BEFORE the opener message so a
            // re-entrant didChangeDependencies (provider rebuild)
            // can't double-surface.
            _proactiveTriggerShownThisSession = true;
            _addCoachOpenerMessage(
              resolved.message,
              intentTag: insight.intentTag,
              contextMessage: resolved.message,
            );
            // Consume-once: clear the cache so the next open falls
            // back to the proactive path until the next recompute.
            unawaited(PrecomputedInsightsService.clear(prefs));
            AnalyticsService().trackEvent(
              'coach_precomputed_insight_shown',
              data: {
                'type': insight.type.name,
                'has_intent_tag': insight.intentTag != null,
              },
            );
            return;
          }
        }
      }
    } catch (e) {
      // Silent degradation — never block the proactive fallback on a
      // SharedPreferences failure.
      debugPrint('[CoachChat] precomputed insight surfacing failed: $e');
    }
    if (!mounted) return;
    _maybeShowProactiveTrigger();
  }

  /// If [MintStateProvider] holds a `pendingTrigger`, surface it as the
  /// opening coach message. Per-day deduplication is enforced upstream
  /// in [ProactiveTriggerService.evaluate]; this method also guards
  /// re-show within a single screen lifetime via
  /// [_proactiveTriggerShownThisSession].
  void _maybeShowProactiveTrigger() {
    if (_proactiveTriggerShownThisSession) return;
    final stateProvider = context.read<MintStateProvider>();
    final trigger = stateProvider.state?.pendingTrigger;
    if (trigger == null) return;
    _proactiveTriggerShownThisSession = true;
    final opener = _resolveProactiveOpener(S.of(context)!, trigger);
    // Phase 54-02: pass intentTag through so the opener renders a
    // tappable chip via RouteSuggestionCard. The existing chip path
    // (widget_renderer._buildRouteSuggestion) consumes p['intent'] +
    // resolves the route via ChatToolDispatcher when no explicit
    // route is provided. Falls back to plain bubble if intentTag is
    // null (default for some trigger types per
    // ProactiveTrigger.intentTag nullable contract).
    _addCoachOpenerMessage(
      opener,
      intentTag: trigger.intentTag,
      contextMessage: opener,
    );
    AnalyticsService().trackEvent('coach_proactive_trigger_shown', data: {
      'type': trigger.type.name,
      'has_intent_tag': trigger.intentTag != null,
    });
  }

  /// Increment the conversation count in SharedPreferences.
  Future<void> _incrementConversationCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_conversationCountKey) ?? 0;
      await prefs.setInt(_conversationCountKey, count + 1);
    } catch (e) {
      // Best-effort persistence.
      debugPrint(
          '[CoachChat] ${e.toString().substring(0, (e.toString().length > 80) ? 80 : e.toString().length)}');
    }
  }

  /// Compute the key financial number to display in the silent opener.
  /// Returns (formattedNumber, headline) or null if no data available.
  ({String number, String headline})? _computeKeyNumber() {
    final s = S.of(context)!;
    final budgetProvider = _watchBudgetProviderIfAvailable();
    final budgetPlan = budgetProvider?.plan;
    if (budgetProvider != null &&
        budgetProvider.hasFreshInputs &&
        budgetPlan != null &&
        budgetPlan.available.isFinite) {
      return (
        number: _formatChf(budgetPlan.available),
        headline: s.pulseLabelMonthlyFree,
      );
    }

    if (_profile == null) return null;
    if (!_profile!.hasMaterialData) return null;

    if (BudgetInputs.hasTrustedCharges(_profile!)) {
      final monthlyFree =
          BudgetLivingEngine.compute(_profile!).present.monthlyFree;
      if (monthlyFree.isFinite) {
        return (
          number: _formatChf(monthlyFree),
          headline: s.pulseLabelMonthlyFree,
        );
      }
    }

    // Priority 2: most recent enrichment fact (LPP avoir or 3a épargne) —
    // surfaces a raw number the user JUST added to their profile, so the
    // coach acknowledges the upload instead of opening silent. Factual,
    // not projected (anti-shame: fact of the world, not judgment of user).
    final avoirLpp = _profile!.prevoyance.avoirLppTotal;
    final avoirLppSource = _profile!.dataSources['prevoyance.avoirLppTotal'];
    if (avoirLpp != null &&
        avoirLpp > 0 &&
        avoirLppSource != ProfileDataSource.estimated) {
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

    // Priority 3: financial fitness score — neutral, life-event-agnostic.
    try {
      final score = FinancialFitnessService.calculate(profile: _profile!);
      final g = score.global;
      if (g > 0) {
        return (
          number: '$g/100',
          headline: s.coachSilentOpenerFitnessScore,
        );
      }
    } catch (e) {
      debugPrint("[CoachChat] best-effort: $e");
    }

    // Priority 4: replacement rate (retirement-framed — only surfaces when
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
    } catch (e) {
      debugPrint("[CoachChat] best-effort: $e");
    }

    // Priority 5: projected capital (same neutralization rationale).
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
    } catch (e) {
      debugPrint("[CoachChat] best-effort: $e");
    }

    return null;
  }

  BudgetProvider? _watchBudgetProviderIfAvailable() {
    try {
      return context.watch<BudgetProvider>();
    } on ProviderNotFoundException {
      return null;
    }
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
      backgroundColor: MintColors.transparent,
      builder: (_) => LightningMenu(
        profile: _profile,
        capMemory: capMem,
        readiness: _readinessForLightningMenu(),
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
            MintNav.open<void>(context, route);
          }
        },
      ),
    );
  }

  Map<String, dynamic>? _readinessForLightningMenu() {
    final profile = _profile;
    if (profile == null) return null;
    final packet = CoachContextPacketAdapter.fromProfile(profile);
    final readiness = packet['readiness'];
    return readiness is Map<String, dynamic> ? readiness : null;
  }

  void _syncProfileFromProvider([CoachProfileProvider? provider]) {
    provider ??= context.read<CoachProfileProvider>();
    if (provider.hasProfile) {
      final freshProfile = provider.profile;
      if (freshProfile != null && !identical(freshProfile, _profile)) {
        _profile = freshProfile;
      }
      return;
    }

    if (provider.isLoading || provider.isHydrating) {
      return;
    }

    if (_profile != null) {
      _profile = null;
      _messages.clear();
      _showSilentOpener = !_isResumingConversation;
      _proactiveTriggerShownThisSession = false;
      _intentOpenerText = null;
    }
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

    _syncProfileFromProvider();

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
      final mintState = context.read<MintStateProvider>().state;
      final buildContext =
          widget.contextBuilder ?? _defaultCoachContextInjectorBuilder;
      final enrichedContext = await buildContext(
        profile: _profile,
        now: DateTime.now(),
        mintState: mintState,
      ).timeout(const Duration(seconds: 2));
      if (enrichedContext.memoryBlock.isNotEmpty) {
        memoryBlock = enrichedContext.memoryBlock;
      }
    } catch (e) {
      // Graceful degradation: chat works without memory block.
      debugPrint(
          '[CoachChat] ${e.toString().substring(0, (e.toString().length > 80) ? 80 : e.toString().length)}');
    }

    // Mounted gate after the await above (use_build_context_synchronously) —
    // if the widget unmounted during the 2s timeout, abort before any
    // further `context.read` / `context.go`.
    if (!mounted) return;

    await _hydrateLatestScreenReturnForNextRequest();
    if (!mounted) return;

    // Wire Spec V2: append entry payload context if present (one-shot).
    if (_entryPayloadContext != null) {
      memoryBlock = '${memoryBlock ?? ''}\n$_entryPayloadContext';
      _entryPayloadContext = null; // one-shot: clear after first use
    }

    // CHAT-01: Load profile if available — never invent fake data.
    // If no profile exists, use default CoachProfile (all zeros/empty).
    // The system prompt detects confidence=0 and asks for real data.
    // Minimal profile with no fake data — zeros mean "unknown".
    _profile ??= CoachProfile.defaults();

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
        ? ResponseCardService.generateForChat(_profile!, userMessage,
            l: S.of(context)!)
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

  /// Flux consent-avant-coach (beads MINT_nosync-tcr).
  ///
  /// Déclenché par le 403 deny_pointer du consent gate backend
  /// (hard_block) : présente la ConsentSheet (libellé élargi -65y),
  /// enregistre le grant via POST /consents/grant, puis rejoue le même
  /// message UNE fois. Refus -> message système explicite, pas de renvoi.
  Future<void> _handleConsentRequired(String text,
      {String? memoryBlock}) async {
    final granted = await ConsentService().requireGrantedOrPrompt(
      context,
      const [ConsentPurpose.transferUsAnthropic],
    );
    if (!mounted) return;

    if (granted) {
      _consentRetryInFlight = true;
      try {
        await _handleStandardResponse(text, memoryBlock: memoryBlock);
      } finally {
        _consentRetryInFlight = false;
      }
      return;
    }

    final s = S.of(context)!;
    setState(() {
      _messages.add(ChatMessage(
        role: 'system',
        content: s.coachConsentDeclined,
        timestamp: DateTime.now(),
        // Panel -tcr : la voie de reprise promise par le message
        // (« renvoie ton message ») doit être à un tap — le renvoi
        // re-déclenche la ConsentSheet.
        suggestedActions: [text],
      ));
      _isLoading = false;
    });
    _scrollToBottom();
  }

  /// Handle standard (non-streaming) response via orchestrator.
  Future<void> _handleStandardResponse(String text,
      {String? memoryBlock}) async {
    try {
      final config = _buildConfig();
      // Capture l10n before await to avoid using BuildContext across async gap.
      final l10n = S.of(context)!;
      // B13 fix (2026-05-09): pass isLoggedIn so the orchestrator can skip
      // the tier 3.5 anonymous fallback on logged users. Pre-fix, an
      // authenticated user whose tier3 server-key call timed out got
      // silently routed to /anonymous/chat and saw « Limite atteinte. Crée
      // un compte pour continuer. » — trust-killer.
      final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
      final response = await CoachLlmService.chat(
        userMessage: text,
        profile: _profile!,
        history: _messages,
        config: config,
        memoryBlock: memoryBlock,
        cashLevel: _cashLevel,
        isLoggedIn: isLoggedIn,
      );

      final deterministicLocalStatutory =
          _isDeterministicLocalStatutoryResponse(
        userMessage: text,
        response: response,
      );
      final hardGateLocalOrRefusal = FeatureFlags.enableCoachHardGate &&
          _profile?.archetype != FinancialArchetype.swissNative;
      final tier = deterministicLocalStatutory ||
              hardGateLocalOrRefusal ||
              response.refused
          ? ChatTier.none
          : config.hasApiKey
              ? ChatTier.byok
              : ChatTier.fallback;

      // Phase 1: generate inline response cards from user message context
      final cards = deterministicLocalStatutory
          ? <ResponseCard>[]
          : _profile != null
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
          // wave-1b-04 P0-3 fix: forward citationChips into ChatMessage so
          // CoachCitationChipsSection (Plan 05) receives the list at render.
          citationChips: response.citationChips,
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
          // WS-D (mint-grounded-coach-m1 Plan 06): the backend now emits an
          // additive `fact_saved` echo carrying {key, value} when an internal
          // save_fact actually persisted server-side. save_fact itself is in
          // INTERNAL_TOOL_NAMES and is filtered out of flutter_tool_calls, so
          // the ServerKey path only ever sees `fact_saved`. The BYOK/orchestrator
          // path may still re-expose the raw `save_fact` tool_use — handle both
          // by routing through the provider write path (applySaveFact →
          // _mapFactKeyToAnswers → mergeAnswers). No write inside any build
          // method; this is the chat tool_calls processing layer.
          if (call.name == 'fact_saved') {
            unawaited(provider.applyFactSavedEcho(call.input));
            continue;
          }
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
          .lastWhere((m) => m.isUser,
              orElse: () => ChatMessage(
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

      // ── Consent gate (beads MINT_nosync-tcr) : le backend hard_block
      // répond 403 deny_pointer quand le grant TRANSFER_US_ANTHROPIC
      // manque. Au premier message sans grant : ConsentSheet -> POST
      // /consents/grant -> retry du même message. Un refus affiche un
      // message explicite (le coach ne peut pas répondre sans transfert).
      if (e is CoachChatApiException &&
          e.code == 'consent_required' &&
          !_consentRetryInFlight) {
        await _handleConsentRequired(text, memoryBlock: memoryBlock);
        return;
      }

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
                disclaimers:
                    (anonResponse['disclaimers'] as List?)?.cast<String>() ??
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
          .lastWhere((m) => m.isUser,
              orElse: () => ChatMessage(
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
          // Anti-critère réseau (PR-F, SPEC §2.3/A4) : la perte de connexion
          // dégrade proprement — un état NOMMÉ et re-tentable, jamais un
          // écran vide « Aucune donnée pour l'instant » (régression
          // 2026-05-07). Les chiffres L1 restent calculés hors ligne ; seul
          // le coach exige le réseau.
          semanticsIdentifier: 'coach-offline-degradation',
        ));
        _isLoading = false;
      });
    }
  }

  bool _isDeterministicLocalStatutoryResponse({
    required String userMessage,
    required CoachResponse response,
  }) {
    if (_profile == null) return false;
    if (!response.message.contains('Plafond 3a avec LPP')) return false;
    if (!response.message.contains('OPP3 art. 7')) return false;

    return LocalFallbackService.detectsSalariedLpp3aCeiling(
      userMessage: userMessage,
      context: _buildCoachContext(_profile!),
    );
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
      debugPrint(
          '[CoachChat] ${e.toString().substring(0, (e.toString().length > 80) ? 80 : e.toString().length)}');
    }
  }

  /// Show auth gate when anonymous message quota is exhausted.
  ///
  /// Adds a coach message inviting the user to create an account,
  /// with tappable chips for register / login.
  void _showAnonymousAuthGate() {
    if (!mounted) return;
    final s = S.of(context)!;
    setState(() {
      _messages.add(ChatMessage(
        role: 'assistant',
        content: s.coachAnonymousAuthGateMessage,
        timestamp: DateTime.now(),
        suggestedActions: [
          s.coachAuthGateChipRegister,
          s.coachAuthGateChipLogin,
        ],
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
      debugPrint(
          '[CoachChat] ${e.toString().substring(0, (e.toString().length > 80) ? 80 : e.toString().length)}');
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
          // Legacy tool compatibility only. New UI requests date_of_birth.
          answers['q_birth_year'] = DateTime.now().year - age;
        }
      case 'date_of_birth':
      case 'dateOfBirth':
        final dateOfBirth = DateTime.tryParse(value);
        if (dateOfBirth != null) {
          answers['q_date_of_birth'] = dateOfBirth.toIso8601String();
          answers['q_birth_year'] = dateOfBirth.year;
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
        answers['q_civil_status'] = mapped;
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
      case 'date_of_birth':
      case 'dateOfBirth':
        return 'Date de naissance enregistr\u00e9e';
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
    // Sub-phase 01.5 W02-T03 HARD GATE (Mapper §7.2 primary site).
    //
    // The full coach remains calibrated for swissNative only. Most
    // unsupported archetypes (expat_us via FATCA self-declaration, expat_eu,
    // cross_border, etc.) are routed to /waitlist BEFORE we construct a
    // CoachContext. Row 23 / CJT-063 lets independent_no_lpp reach the chat
    // shell only so the orchestrator can serve its audited deterministic
    // no-LPP/3a local fallback; generic questions and streaming remain
    // blocked there. The route navigation is deferred via
    // addPostFrameCallback because this method runs during the build /
    // chat-send synchronous path; navigating in-flight would re-enter the
    // widget tree and trigger setState-during-build assertions.
    //
    // The orchestrator carries the secondary refusal layer (Task 5)
    // in case a deep-link / notification handler bypasses this gate.
    //
    // Sub-phase 01.5 W02-T04 Task 2 (Codex R5) — gate wrapped by
    // FeatureFlags.enableCoachHardGate (default true). When the flag
    // is set to false via server override (emergency rollback only),
    // the redirect AND the refusal placeholder are bypassed; the
    // coach renders normally to all archetypes. Flipping to false
    // re-opens the FATCA / LSFin compliance window — see
    // feature_flags.dart doc-comment for the contract.
    final gate = evaluateCoachArchetypeGate(profile);
    // Sub-phase 01.5 W02-T05 Task 2 (Codex R4) — observability counter.
    // Fire-and-forget telemetry BEFORE the kill-switch check so we always
    // record gate evaluations including kill-switch-bypassed ones. The
    // `gate_fired` attribute tracks the actual redirect (not the policy
    // decision) so dashboards can distinguish « gate would have fired but
    // kill switch is off » via the `kill_switch_enabled` tag. The await
    // is intentionally NOT chained — telemetry must NEVER block a gate
    // evaluation (T-01.5-54 mitigation). The PII contract is enforced
    // inside `recordDecision` (only boolean-shaped strings + archetype
    // slug + cohort marker — no email / salary / canton).
    unawaited(GateDecisionTelemetry.recordDecision(
      profile: profile,
      computedArchetype: profile.archetype,
      // `gateFired` reflects the actual outcome: a redirect happens only
      // when BOTH shouldBlock is true AND the kill switch is on.
      gateFired: gate.shouldBlock && FeatureFlags.enableCoachHardGate,
      killSwitchEnabled: FeatureFlags.enableCoachHardGate,
    ));
    if (gate.shouldBlock && FeatureFlags.enableCoachHardGate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Sub-phase 01.5 W02-NN-PATCH-A11Y (H3, WCAG 1.3.2 / 4.1.3):
          // Announce the redirect so screen reader users hear that the
          // coach is being skipped in favour of the waitlist screen.
          // Without this, the navigation is silent for assistive tech.
          final l10n = S.of(context);
          if (l10n != null) {
            SemanticsService.sendAnnouncement(
              View.of(context),
              l10n.waitlistAnnounceRedirect,
              Directionality.of(context),
            );
          }
          context.go(
            '/waitlist',
            extra: WaitlistArgs(archetype: gate.archetypeSlug),
          );
        }
      });
      // Return a refusal-marked placeholder CoachContext. The
      // orchestrator-level guard (Task 5) recognises archetype='unknown'
      // and refuses to invoke the LLM, so even if the post-frame
      // callback hasn't navigated yet the LLM is never reached.
      return CoachContext(
        firstName: '',
        age: profile.ageOrNull ?? 0,
        canton: profile.canton,
        archetype: 'unknown',
        knownValues: const {},
        hasDebt: false,
      );
    }

    final knownValues = <String, double>{};

    try {
      final score = FinancialFitnessService.calculate(profile: profile);
      final g = score.global.toDouble();
      if (g.isFinite && g > 0) knownValues['fri_total'] = g;
    } catch (e) {
      debugPrint("[CoachChat] best-effort: $e");
    }

    try {
      final proj = ForecasterService.project(
        profile: profile,
        targetDate: profile.goalA.targetDate,
      );
      final cap = proj.base.capitalFinal;
      final taux = proj.tauxRemplacementBase;
      if (cap.isFinite && cap > 0) knownValues['capital_final'] = cap;
      if (taux.isFinite && taux > 0) knownValues['replacement_ratio'] = taux;
    } catch (e) {
      debugPrint("[CoachChat] best-effort: $e");
    }

    // Walker 2026-05-08 Étape 6 fix: also expose the raw verified inputs
    // (LPP avoir, gross salary, 3a savings, months of liquidity) so the
    // coach prompt's HallucinationDetector grounding can cite numbers the
    // user already provided, instead of replying « scanne ton certificat
    // LPP » seconds after the user did exactly that. Keys + units match
    // the contract documented at
    // `lib/services/coach/coach_context_builder.dart:18-26` (CHF, CHF/an,
    // months). All gated on > 0 to avoid HallucinationDetector
    // false-positives on missing data.
    final salaireBrutAnnuel = profile.salaireBrutMensuel * profile.nombreDeMois;
    if (salaireBrutAnnuel.isFinite && salaireBrutAnnuel > 0) {
      knownValues['salaire_brut'] = salaireBrutAnnuel;
    }
    final avoirLpp = profile.prevoyance.avoirLppTotal;
    if (avoirLpp != null && avoirLpp.isFinite && avoirLpp > 0) {
      knownValues['avoir_lpp'] = avoirLpp;
    }
    final epargne3a = profile.prevoyance.totalEpargne3a;
    if (epargne3a.isFinite && epargne3a > 0) {
      knownValues['epargne_3a'] = epargne3a;
    }
    final monthsLiquidity = coachContextMonthsLiquidity(profile);
    if (monthsLiquidity != null && monthsLiquidity > 0) {
      knownValues['months_liquidity'] = monthsLiquidity;
    }
    knownValues.addAll(CoachContextProfileMapper.knownValues(profile));

    final coachContextPacket = CoachContextPacketAdapter.fromProfile(profile);

    return CoachContext(
      firstName: profile.firstName ?? 'utilisateur',
      age: profile.ageOrNull ?? 0,
      canton: profile.canton,
      // B6 fix (2026-05-08) : pass archetype to the LLM context. Adversarial
      // QA audit (panel 2026-05-08) flagged that the previous build dropped
      // the field on the floor → empty default → doctrine_checks fall-through
      // PASS → FATCA bypass on expat_us etc. ~35-45% of CH residents were
      // mis-archétypés silently. Backend snake_case format expected.
      archetype: _archetypeToBackendName(profile.archetype),
      knownValues: knownValues,
      coachContextPacket: coachContextPacket,
      activeGoal: CoachContextProfileMapper.activeGoal(profile),
      plannedContributions:
          CoachContextProfileMapper.plannedContributions(profile),
      dataReliability: CoachContextProfileMapper.dataReliability(profile),
      dataReliabilityDetails:
          CoachContextProfileMapper.dataReliabilityDetails(profile),
      hasDebt: profile.isInDebtCrisis,
    );
  }

  /// B6 helper — convert Dart camelCase [FinancialArchetype] to the snake_case
  /// string the backend expects in [CoachContext.archetype]. Used by the
  /// LLM doctrine_checks (`check_archetype_aware`) to enforce FATCA / PFIC /
  /// frontalier-specific cues per archetype.
  String _archetypeToBackendName(FinancialArchetype a) {
    switch (a) {
      case FinancialArchetype.swissNative:
        return 'swiss_native';
      case FinancialArchetype.expatEu:
        return 'expat_eu';
      case FinancialArchetype.expatNonEu:
        return 'expat_non_eu';
      case FinancialArchetype.expatUs:
        return 'expat_us';
      case FinancialArchetype.independentWithLpp:
        return 'independent_with_lpp';
      case FinancialArchetype.independentNoLpp:
        return 'independent_no_lpp';
      case FinancialArchetype.crossBorder:
        return 'cross_border';
      case FinancialArchetype.returningSwiss:
        return 'returning_swiss';
      case FinancialArchetype.unknown:
        // R1+R4 (Sub-phase 01.5 Wave 02 Plan 01): archetype unknown reaches
        // the LLM context only if the gate (Wave 02 plan 03) is bypassed.
        // Return literal 'unknown' so backend doctrine_checks refuse instead
        // of defaulting to swiss_native semantics (FATCA / PFIC / frontalier
        // guards would silently fail).
        return 'unknown';
    }
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
      s.coachSuggestScenarios: '/retraite/rente-vs-capital',
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
      return '/retraite/rente-vs-capital';
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
    } catch (e) {
      debugPrint("[CoachChat] best-effort: $e");
    }

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
    if (action == s.coachAuthGateChipRegister) {
      context.push('/auth/register');
      return;
    }
    if (action == s.coachAuthGateChipLogin) {
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
          content: s.coachOptInAcknowledged,
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
      } else {
        MintNav.open<void>(context, route);
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

    return Semantics(
      key: const Key('coach_chat_screen'),
      identifier: 'coach_chat_screen',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: MintColors.craie,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              CoachAppBar(
                isEmbeddedInTab: widget.isEmbeddedInTab,
                hasUserMessages: _messages.any((m) => m.isUser),
                onBack: () => safePop(
                  context,
                  fallbackRoute: MintNav.coachFallbackRouteFor(
                    context.read<AuthProvider>().authLifecycle,
                  ),
                ),
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
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SILENT OPENER
  // ════════════════════════════════════════════════════════════

  /// Silent opener. One visual anchor at a time: if the profile carries a key
  /// number or intent override, show that; otherwise the SilentOpener's own
  /// minimal empty state renders — no tone chips and no random greeting.
  Widget _buildSilentOpenerWithTone() {
    final Widget hero = _buildSilentOpener();

    final body = Expanded(
      child: SingleChildScrollView(child: hero),
    );

    return Column(children: [body]);
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
                  fontSize: 17, // lint-ignore: prefer_mint_text_style
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
                  fontSize: 14, // lint-ignore: prefer_mint_text_style
                  fontStyle: FontStyle.italic,
                  color: MintColors.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sync local _profile from provider so keyData picks up scans / budget
    // saves / save_fact writes that happened while the user was on another
    // screen. Without this, a scanned LPP doesn't suppress the opener —
    // deep walkthrough crack #8 « rupture de confiance ».
    final coachProvider = context.watch<CoachProfileProvider>();
    if (coachProvider.hasProfile) {
      final freshProfile = coachProvider.profile;
      if (freshProfile != null && !identical(freshProfile, _profile)) {
        _profile = freshProfile;
      }
    }

    final keyData = _computeKeyNumber();
    final hasMaterialProfile = _profile != null && _profile!.hasMaterialData;
    final packetInsight = !hasMaterialProfile
        ? null
        : CoachPacketInsightPresenter.fromSafeMap(
            CoachContextPacketAdapter.fromProfile(_profile!),
          );

    // If no financial data available, show the first-contact opener +
    // 4 conversation starter chips. Gated on BOTH « no conversation yet »
    // AND « no captured data yet » — either signal means first contact.
    // The previous version checked only _messages.isEmpty, so after
    // scan+confirm the user was thrown back into the opener (deep walk
    // crack #8). Now: once the profile has LPP / 3a / fitness data,
    // the silent opener takes over, never the first-contact one.
    if (keyData == null && packetInsight != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: CoachPacketInsightCard(insight: packetInsight),
        ),
      );
    }
    if (keyData == null && _messages.isEmpty) {
      return _buildFirstContactOpener(s);
    }
    if (keyData == null) {
      // Fallback — profile empty but conversation started. Silent frame.
      return const SizedBox.shrink();
    }

    final silentOpenerCards = _profile == null
        ? const <ResponseCard>[]
        : ResponseCardService.generateForSilentOpener(
            _profile!,
            l: s,
          );

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
            Semantics(
              identifier: 'coach_silent_opener_primary_number',
              child: Text(
                keyData.number,
                style: const TextStyle(
                  fontSize: 48, // lint-ignore: prefer_mint_text_style
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              keyData.headline,
              style: const TextStyle(
                fontSize: 15, // lint-ignore: prefer_mint_text_style
                color: MintColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            if (packetInsight != null) ...[
              const SizedBox(height: 20),
              CoachPacketInsightCard(insight: packetInsight),
            ],
            // Handoff 2 « scènes inline » applied to the silent opener:
            // a single contextual scene card surfaces alongside the key
            // number so the screen feels like a coach who already opened
            // the right tab, not a static stat. Cards are picked from
            // profile shape only — no user message required.
            if (silentOpenerCards.isNotEmpty) ...[
              const SizedBox(height: 28),
              ResponseCardStrip(cards: silentOpenerCards),
            ],
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  FIRST-CONTACT OPENER (MVP P0-MVP-2)
  // ════════════════════════════════════════════════════════════

  /// Opener widget shown on the very first Parle-à-Mint tap for users with
  /// no profile data and no message history. Combines identity + promise
  /// with 4 starter chips that route to the right flow.
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
              fontSize: 22, // lint-ignore: prefer_mint_text_style
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.coachOpenerPromise,
            style: const TextStyle(
              fontSize: 15, // lint-ignore: prefer_mint_text_style
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
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
        _controller.text = "Un truc qui me coute chaque mois, je sais pas quoi";
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
            // Offline degradation (SPEC §2.3/A4) surfaces a visible retry that
            // re-sends the last user message — never a silent dead-end.
            final canRetry =
                msg.semanticsIdentifier == 'coach-offline-degradation' &&
                    (msg.suggestedActions?.isNotEmpty ?? false);
            child = SystemMessageBubble(
              message: msg,
              onRetry: canRetry
                  ? () => _handleActionTap(msg.suggestedActions!.first)
                  : null,
              retryLabel: canRetry ? S.of(context)!.commonRetry : null,
            );
          } else if (msg.isUser) {
            final userOrdinal =
                _messages.take(index + 1).where((m) => m.isUser).length - 1;
            final userIdentifier = 'coach_user_message_$userOrdinal';
            child = Semantics(
              key: userOrdinal == 0
                  ? const Key('coach_user_message_0')
                  : userOrdinal == 1
                      ? const Key('coach_user_message_1')
                      : Key(userIdentifier),
              identifier: userIdentifier,
              container: true,
              label: S.of(context)!.coachUserMessage,
              child: UserMessageBubble(message: msg),
            );
          } else {
            final assistantOrdinal =
                _messages.take(index + 1).where((m) => m.isAssistant).length -
                    1;
            final assistantIdentifier =
                'coach_assistant_message_$assistantOrdinal';
            // v2.7 Task 8: compose bubble + subtle degraded chip (if applicable).
            final bubbleWidget = CoachMessageBubble(
              message: msg,
              messageIndex: index,
              isStreaming: _isStreaming &&
                  msg == _messages.last &&
                  msg.tier == ChatTier.slm,
              announceContentLiveRegion: msg.timestamp.isAfter(_screenOpenedAt),
              isInputAnswered: _answeredInputIndices.contains(index),
              onInputSubmitted: _handleInputSubmitted,
              onActionTap: _handleActionTap,
            );
            child = Semantics(
              key: Key(assistantIdentifier),
              identifier: assistantIdentifier,
              container: true,
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
                            style: MintTextStyles.labelSmall(
                              color: MintColors.textSecondary,
                            ).copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    )
                  : bubbleWidget,
            );
          }

          // Show transparency badge under the first assistant response in session.
          final bool isFirstAssistantInSession = msg.isAssistant &&
              !(_isStreaming && msg == _messages.last) &&
              index == _messages.indexWhere((m) => m.isAssistant);

          final Widget wrappedChild = isFirstAssistantInSession
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    child,
                    if (isFirstAssistantInSession &&
                        msg.tier != ChatTier.none) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 42),
                        child: Text(
                          // P2 walkthrough fix (2026-05-07): the binary
                          // `slm ? SLM-copy : BYOK-copy` was wrong for
                          // ChatTier.fallback (server-key path used by mode-
                          // local + non-BYOK auth users) — it claimed « via
                          // ton API Claude » when in fact the call goes via
                          // the MINT server key, AND it claimed « ton salaire
                          // exact n'est PAS envoyé » even though the user's
                          // chat message (which may include CHF amounts) is
                          // shipped verbatim. New `coachTransparencyServer`
                          // copy is honest about the server-key path.
                          switch (msg.tier) {
                            ChatTier.slm => S.of(context)!.coachTransparencySLM,
                            ChatTier.byok =>
                              S.of(context)!.coachTransparencyBYOK,
                            ChatTier.fallback =>
                              S.of(context)!.coachTransparencyServer,
                            ChatTier.none => '',
                          },
                          style: MintTextStyles.micro(
                            color: MintColors.textMuted.withValues(alpha: 0.5),
                          ).copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
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

double? coachContextMonthsLiquidity(CoachProfile profile) {
  final epargneLiquide = profile.patrimoine.epargneLiquide;
  if (!epargneLiquide.isFinite || epargneLiquide <= 0) return null;

  final plausibleExpenses =
      BudgetInputs.plausibleMonthlyFixedExpensesFromProfile(profile);
  final netMensuel = profile.salaireBrutMensuel * profile.nombreDeMois / 12;
  final monthlyExpenses = plausibleExpenses > 0
      ? plausibleExpenses
      : (netMensuel > 0 ? netMensuel * 0.6 : 0.0);

  return monthlyExpenses > 0 ? epargneLiquide / monthlyExpenses : null;
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
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
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
            style: MintTextStyles.labelLarge(color: textColor).copyWith(
              fontWeight: subtle ? FontWeight.w400 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

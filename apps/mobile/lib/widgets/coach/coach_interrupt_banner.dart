/// Banner widget for JITAI coach interruptions in simulators.
///
/// Wire Spec V2 §3.8: Appears at the bottom of simulator screens
/// when user-entered values cross a significant threshold.
/// Dismissable, max 3 dismissals per threshold, respects maturity level.
///
/// Phase 91 Plan 91-02 (VIVANT-03) — `CoachInterruptBanner.fromNudge`
/// repurposes the same shell on top of the Coach chat message list when
/// `MintStateProvider.state.activeNudges` is non-empty. The Nudge variant
/// owns its dismissal contract via [DismissedNudgesStore] (no per-screen
/// 3-dismiss counter) and exposes a stable `Semantics(identifier:)` so
/// Maestro can target it for E2E (per CONTEXT.md decisions VIVANT-03).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/nudge/nudge_engine.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// A coach interrupt rule evaluated against simulator values.
class CoachInterrupt {
  /// Unique identifier for this interrupt (used for dismiss tracking).
  final String id;

  /// Condition that triggers the interrupt.
  final bool Function(Map<String, dynamic> values) condition;

  /// i18n message key.
  final String messageKey;

  /// Parameters for the i18n message.
  final Map<String, String> Function(Map<String, dynamic> values) paramsBuilder;

  /// Optional route to navigate to when user taps "Voir le calcul".
  final String? ctaRoute;

  const CoachInterrupt({
    required this.id,
    required this.condition,
    required this.messageKey,
    required this.paramsBuilder,
    this.ctaRoute,
  });
}

/// Banner displaying a coach interrupt at the bottom of a simulator.
///
/// Shows when [interrupt] condition is met and the user hasn't dismissed
/// this interrupt 3+ times. Dismissals are tracked per interrupt ID.
///
/// Phase 91 Plan 91-02 (VIVANT-03) — `CoachInterruptBanner.fromNudge`
/// alternates this widget for the Coach chat message list path. In that
/// mode the [interrupt] is null and [nudge] + [onDismiss] drive the UI;
/// dismissal storage is owned by the caller (DismissedNudgesStore).
class CoachInterruptBanner extends StatefulWidget {
  /// The interrupt to evaluate and potentially display.
  ///
  /// Null in the [CoachInterruptBanner.fromNudge] mode where [nudge] is set
  /// and the caller (Coach chat screen) controls visibility lifecycle.
  final CoachInterrupt? interrupt;

  /// Current values from the simulator to evaluate the condition.
  ///
  /// Empty map in [CoachInterruptBanner.fromNudge] mode (the nudge has
  /// already been evaluated upstream by [NudgeEngine]).
  final Map<String, dynamic> currentValues;

  /// Phase 91 Plan 91-02 — JITAI nudge surfaced above the Coach chat
  /// message list. Mutually exclusive with [interrupt].
  final Nudge? nudge;

  /// Phase 91 Plan 91-02 — invoked when the user taps the close button
  /// or swipes the banner down. The caller persists the dismissal via
  /// `DismissedNudgesStore` and removes the banner from its render tree.
  final VoidCallback? onDismiss;

  const CoachInterruptBanner({
    super.key,
    required this.interrupt,
    required this.currentValues,
  })  : nudge = null,
        onDismiss = null;

  /// Phase 91 Plan 91-02 (VIVANT-03) — Coach chat variant.
  ///
  /// Renders [nudge] above the message list. The host screen is responsible
  /// for filtering already-dismissed nudges (via [DismissedNudgesStore]) and
  /// for the « 1 banner per session » throttle.
  const CoachInterruptBanner.fromNudge({
    super.key,
    required Nudge this.nudge,
    required VoidCallback this.onDismiss,
  })  : interrupt = null,
        currentValues = const {};

  @override
  State<CoachInterruptBanner> createState() => _CoachInterruptBannerState();
}

class _CoachInterruptBannerState extends State<CoachInterruptBanner>
    with SingleTickerProviderStateMixin {
  bool _dismissed = false;
  bool _permanentlyDismissed = false;
  late AnimationController _animController;

  static const _maxDismissals = 3;
  static const _prefsPrefix = 'coach_interrupt_dismiss_';

  bool get _isNudgeMode => widget.nudge != null;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    if (_isNudgeMode) {
      // Nudge variant has no per-banner dismiss counter — host owns it.
      _animController.forward();
    } else {
      _checkDismissCount();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkDismissCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt('$_prefsPrefix${widget.interrupt!.id}') ?? 0;
      if (count >= _maxDismissals && mounted) {
        setState(() => _permanentlyDismissed = true);
      } else if (mounted) {
        _animController.forward();
      }
    } catch (_) {
      if (mounted) _animController.forward();
    }
  }

  Future<void> _dismiss() async {
    await _animController.reverse();
    if (!mounted) return;
    setState(() => _dismissed = true);
    if (_isNudgeMode) {
      // Phase 91 Plan 91-02 — host owns persistence (DismissedNudgesStore).
      widget.onDismiss?.call();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefsPrefix${widget.interrupt!.id}';
      final count = (prefs.getInt(key) ?? 0) + 1;
      await prefs.setInt(key, count);
    } catch (_) {
      // Silently fail — dismiss count is best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if condition not met, dismissed, or permanently dismissed
    if (_dismissed || _permanentlyDismissed) return const SizedBox.shrink();
    if (_isNudgeMode) {
      return _buildNudgeBanner(context);
    }
    if (!widget.interrupt!.condition(widget.currentValues)) {
      return const SizedBox.shrink();
    }
    return _buildSimulatorBanner(context);
  }

  Widget _buildSimulatorBanner(BuildContext context) {
    final l10n = S.of(context)!;
    final interrupt = widget.interrupt!;
    final params = interrupt.paramsBuilder(widget.currentValues);
    final message = _resolveMessage(l10n, interrupt.messageKey, params);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      )),
      child: Container(
        margin: const EdgeInsets.all(MintSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.md,
          vertical: MintSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: MintColors.porcelaine,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: MintColors.primary.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              color: MintColors.primary,
              size: 20,
            ),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: MintTextStyles.bodySmall(
                  color: MintColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (interrupt.ctaRoute != null)
              TextButton(
                onPressed: () => context.push(interrupt.ctaRoute!),
                child: Text(
                  l10n.coachInterruptSeeCalc,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.primary,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(
                Icons.close,
                color: MintColors.textSecondary,
                size: 18,
              ),
              onPressed: _dismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  /// Phase 91 Plan 91-02 (VIVANT-03) — Nudge variant.
  ///
  /// Above the chat message list. Wrapped in `Semantics(identifier: …)`
  /// for Maestro E2E targeting (per CONTEXT.md decisions VIVANT-03 a11y).
  /// Swipe-down (`Dismissible`) and tap-X both invoke [widget.onDismiss].
  Widget _buildNudgeBanner(BuildContext context) {
    final l10n = S.of(context)!;
    final nudge = widget.nudge!;
    final title = _resolveNudgeText(l10n, nudge.titleKey, nudge.params);
    final body = _resolveNudgeText(l10n, nudge.bodyKey, nudge.params);

    return Semantics(
      identifier: 'coach-interrupt-banner-${nudge.id}',
      container: true,
      label: title,
      button: true,
      child: Dismissible(
        key: ValueKey('coach-interrupt-banner-dismissible-${nudge.id}'),
        direction: DismissDirection.up,
        onDismissed: (_) => _dismiss(),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animController,
            curve: Curves.easeOut,
          )),
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md,
              vertical: MintSpacing.sm,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md,
              vertical: MintSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: MintColors.porcelaine,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: MintColors.primary.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: MintColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          body,
                          style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: MintColors.textSecondary,
                    size: 18,
                  ),
                  onPressed: _dismiss,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: l10n.consentClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _resolveMessage(
    S l10n,
    String key,
    Map<String, String> params,
  ) {
    return switch (key) {
      'coachInterrupt3aUnderMax' =>
        l10n.coachInterrupt3aUnderMax(params['savings'] ?? ''),
      'coachInterruptMortgageOverThird' =>
        l10n.coachInterruptMortgageOverThird,
      'coachInterruptFullCapitalRisk' => l10n.coachInterruptFullCapitalRisk,
      'coachInterruptEplBlock' => l10n.coachInterruptEplBlock,
      'coachInterruptBudgetDeficit' =>
        l10n.coachInterruptBudgetDeficit(params['deficit'] ?? ''),
      _ => key, // Fallback: return key as-is
    };
  }

  /// Resolve a [Nudge.titleKey] / [Nudge.bodyKey] ARB key to its localised
  /// string. Mirrors `ContextInjectorService._resolveStepTitle` switch
  /// pattern — generated [S] getters are private to the binding so a
  /// hand-rolled switch is the established way to bridge a runtime key.
  /// Falls through to the raw key on miss so the banner never renders blank.
  String _resolveNudgeText(
    S l10n,
    String key,
    Map<String, String>? params,
  ) {
    final p = params ?? const <String, String>{};
    switch (key) {
      // Titles
      case 'nudgeSalaryTitle':
        return l10n.nudgeSalaryTitle;
      case 'nudgeTaxDeadlineTitle':
        return l10n.nudgeTaxDeadlineTitle;
      case 'nudge3aDeadlineTitle':
        return l10n.nudge3aDeadlineTitle;
      case 'nudgeBirthdayTitle':
        return l10n.nudgeBirthdayTitle(p['age'] ?? '');
      case 'nudgeProfileTitle':
        return l10n.nudgeProfileTitle;
      case 'nudgeInactiveTitle':
        return l10n.nudgeInactiveTitle;
      case 'nudgeGoalProgressTitle':
        return l10n.nudgeGoalProgressTitle;
      case 'nudgeAnniversaryTitle':
        return l10n.nudgeAnniversaryTitle;
      case 'nudgeLppBuybackTitle':
        return l10n.nudgeLppBuybackTitle;
      case 'nudgeNewYearTitle':
        return l10n.nudgeNewYearTitle;
      // Bodies (some take params, some don't)
      case 'nudgeSalaryBody':
        return l10n.nudgeSalaryBody;
      case 'nudgeTaxDeadlineBody':
        return l10n.nudgeTaxDeadlineBody;
      case 'nudge3aDeadlineBody':
        return l10n.nudge3aDeadlineBody(
          p['days'] ?? '',
          p['limit'] ?? '',
          p['year'] ?? '',
        );
      case 'nudgeBirthdayBody':
        return l10n.nudgeBirthdayBody;
      case 'nudgeProfileBody':
        return l10n.nudgeProfileBody;
      case 'nudgeInactiveBody':
        return l10n.nudgeInactiveBody;
      case 'nudgeGoalProgressBody':
        return l10n.nudgeGoalProgressBody(p['progress'] ?? '');
      case 'nudgeAnniversaryBody':
        return l10n.nudgeAnniversaryBody;
      case 'nudgeLppBuybackBody':
        return l10n.nudgeLppBuybackBody(p['year'] ?? '');
      case 'nudgeNewYearBody':
        return l10n.nudgeNewYearBody(p['year'] ?? '');
      default:
        return key; // Graceful fallback — Maestro can still target the wrap.
    }
  }
}

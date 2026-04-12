/// Banner widget for JITAI coach interruptions in simulators.
///
/// Wire Spec V2 §3.8: Appears at the bottom of simulator screens
/// when user-entered values cross a significant threshold.
/// Dismissable, max 3 dismissals per threshold, respects maturity level.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
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
class CoachInterruptBanner extends StatefulWidget {
  /// The interrupt to evaluate and potentially display.
  final CoachInterrupt interrupt;

  /// Current values from the simulator to evaluate the condition.
  final Map<String, dynamic> currentValues;

  const CoachInterruptBanner({
    super.key,
    required this.interrupt,
    required this.currentValues,
  });

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

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _checkDismissCount();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkDismissCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt('$_prefsPrefix${widget.interrupt.id}') ?? 0;
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefsPrefix${widget.interrupt.id}';
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
    if (!widget.interrupt.condition(widget.currentValues)) {
      return const SizedBox.shrink();
    }

    final l10n = S.of(context)!;
    final params = widget.interrupt.paramsBuilder(widget.currentValues);
    final message = _resolveMessage(l10n, widget.interrupt.messageKey, params);

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
            if (widget.interrupt.ctaRoute != null)
              TextButton(
                onPressed: () => context.push(widget.interrupt.ctaRoute!),
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
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart' show SafeModeSignal;
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Read the SafeMode flag from [CoachProfileProvider] with graceful fallback.
///
/// Returns `false` when the provider isn't in the widget tree (unit widget
/// tests pump isolated screens without the full shell). Production paths
/// always have the provider injected via the top-level ChangeNotifierProvider
/// so the flag is read correctly.
bool lookupSafeModeFlag(BuildContext context) {
  try {
    return context.watch<CoachProfileProvider>().profile?.isInDebtCrisis ??
        false;
  } on ProviderNotFoundException {
    return false;
  }
}

/// Localized provenance for the active SafeMode pause — the DATA that triggers
/// it, so the gate never blocks without naming why. Derived from the profile's
/// [SafeModeSignal]s (single source of truth). Returns `[]` when no provider is
/// in the tree (isolated widget tests).
List<String> lookupSafeModeReasons(BuildContext context) {
  final l = S.of(context)!;
  List<SafeModeSignal> signals;
  try {
    signals =
        context.watch<CoachProfileProvider>().profile?.safeModeSignals ??
            const <SafeModeSignal>[];
  } on ProviderNotFoundException {
    return const <String>[];
  }

  final reasons = <String>[];
  void add(String reason) {
    if (!reasons.contains(reason)) reasons.add(reason);
  }

  for (final signal in signals) {
    switch (signal) {
      case SafeModeSignal.consumerDebt:
      case SafeModeSignal.retirementDebtLoad:
        add(l.safeModeReasonDebtLoad);
        break;
      case SafeModeSignal.highDebtRatio:
        add(l.safeModeReasonHighDebtRatio);
        break;
      case SafeModeSignal.thinEmergencyFund:
        add(l.safeModeReasonThinCushion);
        break;
    }
  }
  return reasons;
}

/// Advisory pause for advanced 3a / LPP optimizations while a SafeMode signal is
/// active.
///
/// Doctrine (« jamais de blocage sans explication, sans provenance, sans
/// sortie ») — this gate is NEVER a dead end:
///   1. It names WHY it paused (provenance [reasons], auto-fetched from the
///      profile when none are passed).
///   2. It lets the user CORRECT the source data ([correctDataRoute]).
///   3. It ALWAYS offers « Continuer quand même », which reveals the child so
///      the user can proceed with what they came for.
class SafeModeGate extends StatefulWidget {
  final bool hasDebt;
  final Widget child;
  final String? lockedTitle;
  final String? lockedMessage;
  final List<String> reasons;
  final String? ctaRoute;
  final String? ctaLabel;

  /// Where « Corriger mes données » sends the user to fix the data that caused
  /// the pause (savings / expenses / debt). Defaults to the budget screen.
  final String correctDataRoute;

  const SafeModeGate({
    super.key,
    required this.hasDebt,
    required this.child,
    this.lockedTitle,
    this.lockedMessage,
    this.reasons = const [],
    this.ctaRoute = '/debt/repayment',
    this.ctaLabel,
    this.correctDataRoute = '/budget',
  });

  @override
  State<SafeModeGate> createState() => _SafeModeGateState();
}

class _SafeModeGateState extends State<SafeModeGate> {
  /// User chose « Continuer quand même » — reveal the child from here on.
  bool _bypassed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.hasDebt || _bypassed) {
      return widget.child;
    }

    final l = S.of(context)!;
    final title = widget.lockedTitle ?? l.safeModeTitle;
    final message = widget.lockedMessage ?? l.safeModeMessage;
    final cta = widget.ctaLabel ?? l.safeModeCta;

    // Provenance: prefer explicit reasons, else auto-derive from the profile so
    // every gate names its cause without touching each call site.
    final reasons =
        widget.reasons.isNotEmpty ? widget.reasons : lookupSafeModeReasons(context);

    // Locked State visualization
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_person,
              color: MintColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MintTextStyles.bodyMedium(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(height: 1.4),
                ),
                if (reasons.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    l.safeModeReasonsIntro,
                    style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  ...reasons.take(3).map(
                        (reason) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Icon(Icons.circle,
                                    size: 6, color: MintColors.textMuted),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
                const SizedBox(height: 12),
                Semantics(
                  label: l.safeModeWhyBlockedSemantics,
                  button: true,
                  child: InkWell(
                    onTap: () {
                      showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.85,
                      ),
                      backgroundColor: MintColors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                      builder: (ctx) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.of(ctx)!.safeModeWhyBlockedTitle,
                              style: MintTextStyles.titleLarge(color: MintColors.textPrimary),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              S.of(ctx)!.safeModeWhyBlockedBody,
                              style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
                            ),
                            if (reasons.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ...reasons.take(4).map(
                                    (reason) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        '• $reason',
                                        style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
                                      ),
                                    ),
                                  ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                  child: Text(
                    l.safeModeWhyBlockedLink,
                    style: MintTextStyles.labelMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                  ),
                ),
                ),
                const SizedBox(height: 12),
                // Correct the source data that triggered the pause.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.push(widget.correctDataRoute),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: MintColors.primary),
                      foregroundColor: MintColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      l.safeModeCorrectData,
                      style: MintTextStyles.labelMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (widget.ctaRoute != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      // lint-ignore: prefer_mint_cta
                      onPressed: () => context.push(widget.ctaRoute!),
                      style: TextButton.styleFrom(
                        foregroundColor: MintColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        cta,
                        style: MintTextStyles.labelMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                // Never a dead end — always let the user proceed.
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    // lint-ignore: prefer_mint_cta
                    onPressed: () => setState(() => _bypassed = true),
                    style: TextButton.styleFrom(
                      foregroundColor: MintColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      l.safeModeContinueAnyway,
                      style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

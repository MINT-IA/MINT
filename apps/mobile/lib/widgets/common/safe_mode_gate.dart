import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
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

class SafeModeGate extends StatelessWidget {
  final bool hasDebt;
  final Widget child;
  final String? lockedTitle;
  final String? lockedMessage;
  final List<String> reasons;
  final String? ctaRoute;
  final String? ctaLabel;

  const SafeModeGate({
    super.key,
    required this.hasDebt,
    required this.child,
    this.lockedTitle,
    this.lockedMessage,
    this.reasons = const [],
    this.ctaRoute = '/debt/repayment',
    this.ctaLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasDebt) {
      return child;
    }

    final l = S.of(context)!;
    final title = lockedTitle ?? l.safeModeTitle;
    final message = lockedMessage ?? l.safeModeMessage;
    final cta = ctaLabel ?? l.safeModeCta;

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
                  const SizedBox(height: 10),
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed:
                        ctaRoute == null ? null : () => context.push(ctaRoute!),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: MintColors.primary),
                      foregroundColor: MintColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      cta,
                      style: MintTextStyles.labelMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w600),
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

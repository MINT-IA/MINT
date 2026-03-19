import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Actions that require authentication to persist data securely.
enum AuthTrigger {
  documentScan,
  salaryInput,
  coachChat,
  goalCreation,
  simulationSave,
  byokSetup,
  coupleInvite,
  profileEnrichment,
}

/// AuthGate — soft auth wall for data-persisting actions.
///
/// Wraps a child widget. If the user is NOT logged in, shows the
/// child dimmed + a tap interceptor that triggers a registration
/// bottom sheet. If logged in, shows the child normally.
///
/// Usage:
/// ```dart
/// AuthGate(
///   triggerContext: AuthTrigger.documentScan,
///   child: DocumentScanButton(),
/// )
/// ```
///
/// The bottom sheet explains WHY registration is needed for this
/// specific action, with a CTA to register or login.
class AuthGate extends StatelessWidget {
  /// The content to show when the user is authenticated.
  final Widget child;

  /// The action that triggered the auth gate — determines the
  /// contextual message shown in the bottom sheet.
  final AuthTrigger triggerContext;

  const AuthGate({
    super.key,
    required this.child,
    required this.triggerContext,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoggedIn) {
      return child;
    }

    return GestureDetector(
      onTap: () => _showRegistrationSheet(context),
      child: AbsorbPointer(
        child: Opacity(
          opacity: 0.7,
          child: child,
        ),
      ),
    );
  }

  void _showRegistrationSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MintColors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RegistrationBottomSheet(trigger: triggerContext),
    );
  }
}

// ---------------------------------------------------------------------------
// Trigger metadata helpers
// ---------------------------------------------------------------------------

IconData _iconForTrigger(AuthTrigger trigger) {
  switch (trigger) {
    case AuthTrigger.documentScan:
      return Icons.document_scanner_outlined;
    case AuthTrigger.salaryInput:
      return Icons.account_balance_wallet_outlined;
    case AuthTrigger.coachChat:
      return Icons.chat_bubble_outline_rounded;
    case AuthTrigger.goalCreation:
      return Icons.flag_outlined;
    case AuthTrigger.simulationSave:
      return Icons.save_outlined;
    case AuthTrigger.byokSetup:
      return Icons.key_outlined;
    case AuthTrigger.coupleInvite:
      return Icons.people_outline_rounded;
    case AuthTrigger.profileEnrichment:
      return Icons.person_add_alt_1_outlined;
  }
}

String _titleForTrigger(AuthTrigger trigger, S l) {
  switch (trigger) {
    case AuthTrigger.documentScan:
      return l.authGateDocScanTitle;
    case AuthTrigger.salaryInput:
      return l.authGateSalaryTitle;
    case AuthTrigger.coachChat:
      return l.authGateCoachTitle;
    case AuthTrigger.goalCreation:
      return l.authGateGoalTitle;
    case AuthTrigger.simulationSave:
      return l.authGateSimTitle;
    case AuthTrigger.byokSetup:
      return l.authGateByokTitle;
    case AuthTrigger.coupleInvite:
      return l.authGateCoupleTitle;
    case AuthTrigger.profileEnrichment:
      return l.authGateProfileTitle;
  }
}

String _messageForTrigger(AuthTrigger trigger, S l) {
  switch (trigger) {
    case AuthTrigger.documentScan:
      return l.authGateDocScanMessage;
    case AuthTrigger.salaryInput:
      return l.authGateSalaryMessage;
    case AuthTrigger.coachChat:
      return l.authGateCoachMessage;
    case AuthTrigger.goalCreation:
      return l.authGateGoalMessage;
    case AuthTrigger.simulationSave:
      return l.authGateSimMessage;
    case AuthTrigger.byokSetup:
      return l.authGateByokMessage;
    case AuthTrigger.coupleInvite:
      return l.authGateCoupleMessage;
    case AuthTrigger.profileEnrichment:
      return l.authGateProfileMessage;
  }
}

// ---------------------------------------------------------------------------
// Registration bottom sheet
// ---------------------------------------------------------------------------

class _RegistrationBottomSheet extends StatelessWidget {
  final AuthTrigger trigger;

  const _RegistrationBottomSheet({required this.trigger});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final currentRoute =
        GoRouterState.of(context).uri.toString();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MintColors.coachBubble,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MintColors.coachAccent.withValues(alpha: 0.15),
                  ),
                ),
                child: Icon(
                  _iconForTrigger(trigger),
                  color: MintColors.coachAccent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                _titleForTrigger(trigger, l),
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Contextual message
              Text(
                _messageForTrigger(trigger, l),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Primary CTA — Create account
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push(
                      '/auth/register?redirect=${Uri.encodeComponent(currentRoute)}',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: MintColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l.authGateCreateAccount,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary CTA — Login
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push(
                      '/auth/login?redirect=${Uri.encodeComponent(currentRoute)}',
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: MintColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: MintColors.border),
                    ),
                  ),
                  child: Text(
                    l.authGateLogin,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Privacy reassurance
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 14,
                    color: MintColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l.authGatePrivacyNote,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

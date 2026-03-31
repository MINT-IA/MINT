import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/household_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

/// Screen for accepting a household invitation code.
///
/// Provides a 6-character code input field. On success, navigates
/// back to the household screen showing the updated membership.
class AcceptInvitationScreen extends StatefulWidget {
  /// Optional pre-filled code (from deep link).
  final String? initialCode;

  const AcceptInvitationScreen({super.key, this.initialCode});

  @override
  State<AcceptInvitationScreen> createState() => _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState extends State<AcceptInvitationScreen> {
  final _codeController = TextEditingController();
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdProvider>();
    final l = S.of(context)!;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l.acceptInvitationTitle,
            style: MintTextStyles.titleMedium(),
          ),
          backgroundColor: MintColors.white,
          surfaceTintColor: MintColors.white,
          foregroundColor: MintColors.textPrimary,
          elevation: 0,
        ),
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: Padding(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: _accepted
              ? _buildSuccess(context, l)
              : _buildForm(context, household, l),
        ))),
      ),
    );
  }

  Widget _buildForm(BuildContext context, HouseholdProvider household, S l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        const Icon(Icons.people, size: 64, color: MintColors.primary),
        const SizedBox(height: 24),
        MintEntrance(child: Text(
          l.acceptInvitationPrompt,
          textAlign: TextAlign.center,
          style: MintTextStyles.titleLarge(),
        )),
        const SizedBox(height: MintSpacing.sm),
        MintEntrance(delay: const Duration(milliseconds: 100), child: Text(
          l.acceptInvitationCodeValidity,
          textAlign: TextAlign.center,
          style: MintTextStyles.bodyMedium(),
        )),
        const SizedBox(height: 32),
        MintEntrance(delay: const Duration(milliseconds: 200), child: TextField(
          controller: _codeController,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          style: MintTextStyles.displaySmall().copyWith(letterSpacing: 6),
          decoration: InputDecoration(
            hintText: l.householdAcceptCodeHint,
            hintStyle: MintTextStyles.headlineLarge(color: MintColors.greyBorder).copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w300,
              letterSpacing: 6,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
          ),
        )),
        if (household.error != null) ...[
          const SizedBox(height: 12),
          Text(
            household.error!,
            textAlign: TextAlign.center,
            style: MintTextStyles.bodySmall(color: MintColors.redDeep),
          ),
        ],
        const SizedBox(height: 24),
        MintEntrance(delay: const Duration(milliseconds: 300), child: Semantics(
          button: true,
          label: l.acceptInvitationJoin,
          child: FilledButton(
            onPressed: household.isLoading
                ? null
                : () async {
                  final code = _codeController.text.trim();
                  if (code.isEmpty) return;
                  household.clearError();
                  final success = await household.acceptInvitation(code);
                  if (success && mounted) {
                    setState(() => _accepted = true);
                  }
                },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: household.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MintColors.white,
                  ),
                )
              : Text(
                  l.acceptInvitationJoin,
                  style: MintTextStyles.titleMedium(color: MintColors.white),
                ),
        ),
        )),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context, S l) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: MintColors.successBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 72,
              color: MintColors.categoryGreen,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l.acceptInvitationSuccess,
            style: MintTextStyles.headlineMedium(),
          ),
          const SizedBox(height: MintSpacing.md),
          Text(
            l.acceptInvitationSuccessBody,
            textAlign: TextAlign.center,
            style: MintTextStyles.bodyMedium(),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.go('/couple'),
            child: Text(l.acceptInvitationVoirMenage),
          ),
        ],
      ),
    );
  }
}

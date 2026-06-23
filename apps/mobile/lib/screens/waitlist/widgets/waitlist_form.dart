import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/waitlist_provider.dart';
import 'package:mint_mobile/screens/waitlist/waitlist_args.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_loading_indicator.dart';
import 'package:mint_mobile/widgets/premium/mint_text_field.dart';
import 'package:provider/provider.dart';

/// Static email validator — single regex shared between the controller
/// listener and the test expectations.
final RegExp _kEmailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Body of /waitlist when the provider is in the initial / submitting /
/// error state. Owns the local field state (email controller + consent
/// checkbox) and gates the CTA on both validity AND consent.
class WaitlistForm extends StatefulWidget {
  const WaitlistForm({
    super.key,
    required this.args,
    this.onCorrectProfile,
  });

  final WaitlistArgs args;
  final VoidCallback? onCorrectProfile;

  @override
  State<WaitlistForm> createState() => _WaitlistFormState();
}

class _WaitlistFormState extends State<WaitlistForm> {
  final TextEditingController _emailController = TextEditingController();
  bool _emailValid = false;
  bool _consentGiven = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    final next = _kEmailRegex.hasMatch(_emailController.text.trim());
    if (next != _emailValid) {
      setState(() => _emailValid = next);
    }
    // If the user edits after an error, return to initial so the inline
    // error banner is hidden until next submit attempt.
    final provider = context.read<WaitlistProvider>();
    if (provider.status == WaitlistStatus.error) {
      provider.resetError();
    }
  }

  Future<void> _onSubmit() async {
    final provider = context.read<WaitlistProvider>();
    final locale = Localizations.localeOf(context).languageCode;
    await provider.submit(
      email: _emailController.text.trim(),
      archetype: widget.args.archetype ?? 'other',
      locale: locale,
      source: widget.args.source,
      consentGiven: _consentGiven,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final status = context.watch<WaitlistProvider>().status;
    final errorKey = context.watch<WaitlistProvider>().errorKey;
    final isSubmitting = status == WaitlistStatus.submitting;
    final canSubmit = _emailValid && _consentGiven && !isSubmitting;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.screenH,
        vertical: MintSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.waitlistTitle,
              style: MintTextStyles.headlineLarge(color: MintColors.inkPrimary),
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
          Text(
            l.waitlistBodyPara1,
            style: MintTextStyles.bodyLarge(color: MintColors.inkPrimary),
          ),
          const SizedBox(height: MintSpacing.md),
          Text(
            l.waitlistBodyPara2,
            style: MintTextStyles.bodyLarge(color: MintColors.inkPrimary),
          ),
          const SizedBox(height: MintSpacing.md),
          Text(
            l.waitlistBodyPara3,
            style: MintTextStyles.bodyLarge(color: MintColors.inkPrimary),
          ),
          if (widget.onCorrectProfile != null) ...[
            const SizedBox(height: MintSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton( // lint-ignore: prefer_mint_cta
                key: const Key('waitlist-correct-profile-cta'),
                onPressed: widget.onCorrectProfile,
                style: OutlinedButton.styleFrom(
                  foregroundColor: MintColors.inkPrimary,
                  side: const BorderSide(color: MintColors.inkPrimary),
                  padding: const EdgeInsets.symmetric(vertical: MintSpacing.md),
                ),
                child: Text(l.waitlistCorrectProfileCta),
              ),
            ),
          ],
          const SizedBox(height: MintSpacing.xl),
          MintTextField(
            label: l.waitlistEmailLabel,
            hint: l.waitlistEmailHint,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: MintSpacing.md),
          // Explicit UCA opt-in checkbox — Security §5 guardrail #1.
          // CheckboxListTile uses leading affinity so the box sits on the
          // left and the label wraps on the right.
          CheckboxListTile(
            key: const Key('waitlist-consent-checkbox'),
            value: _consentGiven,
            onChanged: (v) => setState(() => _consentGiven = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              l.waitlistConsentCheckbox,
              style: MintTextStyles.bodyMedium(color: MintColors.inkPrimary),
            ),
          ),
          if (errorKey != null) ...[
            const SizedBox(height: MintSpacing.md),
            // Sub-phase 01.5 W02-NN-PATCH-A11Y (H2, WCAG 3.3.1 / 4.1.3):
            // liveRegion semantics so screen readers announce the error
            // text when it appears (bad email vs network failure). Without
            // this, validation failure is silent for assistive-tech users.
            Semantics(
              liveRegion: true,
              container: true,
              label: _errorMessage(l, errorKey),
              child: Text(
                _errorMessage(l, errorKey),
                style: MintTextStyles.bodyMedium(color: MintColors.error),
              ),
            ),
          ],
          const SizedBox(height: MintSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton( // lint-ignore: prefer_mint_cta
              key: const Key('waitlist-cta'),
              onPressed: canSubmit ? _onSubmit : null,
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.inkPrimary,
                foregroundColor: MintColors.white,
                padding: const EdgeInsets.symmetric(vertical: MintSpacing.md),
              ),
              child: isSubmitting
                  ? const MintLoadingIndicator(size: 20)
                  : Text(l.waitlistCta),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            l.waitlistConsentFinePrint,
            style: MintTextStyles.labelSmall(color: MintColors.textMutedAaa),
          ),
        ],
      ),
    );
  }

  String _errorMessage(S l, String key) {
    switch (key) {
      case 'waitlistErrorBadEmail':
        return l.waitlistErrorBadEmail;
      case 'waitlistErrorNetwork':
      default:
        return l.waitlistErrorNetwork;
    }
  }
}

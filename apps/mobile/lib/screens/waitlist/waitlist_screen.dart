import 'package:flutter/material.dart';
import 'package:mint_mobile/providers/waitlist_provider.dart';
import 'package:mint_mobile/screens/waitlist/waitlist_args.dart';
import 'package:mint_mobile/screens/waitlist/widgets/waitlist_form.dart';
import 'package:mint_mobile/screens/waitlist/widgets/waitlist_success.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:provider/provider.dart';

/// Phase 01.5 sub-phase Wave 02 Plan 02 — destination screen for the
/// archetype hard gate. Renders the «Encore en chantier pour ton profil»
/// flow: form (initial / error / submitting) → success (post-submit
/// confirmation + back-to-home CTA).
///
/// Route wiring (`/waitlist` GoRoute + `WaitlistArgs` extra) is in
/// plan 02-03 — this widget is the consumer of those args, not the
/// registrar.
class WaitlistScreen extends StatelessWidget {
  const WaitlistScreen({
    super.key,
    this.args = const WaitlistArgs(),
    this.onCorrectProfile,
  });

  final WaitlistArgs args;
  final VoidCallback? onCorrectProfile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.craieHandoff,
      body: SafeArea(
        child: Consumer<WaitlistProvider>(
          builder: (context, provider, _) {
            switch (provider.status) {
              case WaitlistStatus.success:
                return const WaitlistSuccess();
              case WaitlistStatus.initial:
              case WaitlistStatus.submitting:
              case WaitlistStatus.error:
                return WaitlistForm(
                  args: args,
                  onCorrectProfile: onCorrectProfile,
                );
            }
          },
        ),
      ),
    );
  }
}

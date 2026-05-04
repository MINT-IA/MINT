import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Settings › Confidentialité — Phase 52 cloud-sync opt-in toggle.
///
/// Single explicit Switch wired to [AuthProvider.toggleCloudSync]. Reads
/// state from [AuthProvider.isCloudSyncEnabled]. The whole row is tappable
/// (mirrors LangueSettingsScreen). Below the row, two static disclosure
/// paragraphs explain (a) where data lives in each state and (b) — only
/// when sync is OFF and the user is logged in — that previously-pushed
/// server data is not auto-deleted (D-06 from Phase 52 CONTEXT).
///
/// Route: `/settings/confidentialite`.
class ConfidentialiteSettingsScreen extends StatelessWidget {
  const ConfidentialiteSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final auth = context.watch<AuthProvider>();
    final cloudSyncOn = auth.isCloudSyncEnabled;
    final showServerCaveat = !cloudSyncOn && auth.isLoggedIn;

    void toggle() {
      HapticFeedback.selectionClick();
      context.read<AuthProvider>().toggleCloudSync(!cloudSyncOn);
    }

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        elevation: 0,
        title: Text(
          l.settingsPrivacyTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(MintSpacing.lg),
        children: [
          MintSurface(
            tone: MintSurfaceTone.blanc,
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md,
              vertical: MintSpacing.md,
            ),
            child: InkWell(
              onTap: toggle,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.settingsPrivacyCloudSyncTitle,
                          style: MintTextStyles.titleMedium(
                            color: MintColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: MintSpacing.xs),
                        Text(
                          l.settingsPrivacyCloudSyncSubtitle,
                          style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: MintSpacing.sm),
                        // State label is announced by the Switch itself —
                        // exclude from a11y to avoid double-read.
                        ExcludeSemantics(
                          child: Text(
                            cloudSyncOn
                                ? l.settingsPrivacyCloudSyncOn
                                : l.settingsPrivacyCloudSyncOff,
                            style: MintTextStyles.labelMedium(
                              color: cloudSyncOn
                                  ? MintColors.success
                                  : MintColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: MintSpacing.md),
                  Semantics(
                    container: true,
                    label: l.settingsPrivacyCloudSyncTitle,
                    hint: l.settingsPrivacyCloudSyncSubtitle,
                    child: Switch(
                      value: cloudSyncOn,
                      activeThumbColor: MintColors.primary,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        context.read<AuthProvider>().toggleCloudSync(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm),
            child: Text(
              l.settingsPrivacyDataLocation,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ),
            ),
          ),
          if (showServerCaveat) ...[
            const SizedBox(height: MintSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm),
              child: Text(
                l.settingsPrivacyCloudSyncOffServerCaveat,
                style: MintTextStyles.bodySmall(
                  color: MintColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

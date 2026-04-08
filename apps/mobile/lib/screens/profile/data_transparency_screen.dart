import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Data transparency screen — "Comment MINT utilise tes données".
///
/// Lists every user-facing action that involves data, with a colored
/// badge indicating where data is processed (local / server / third party).
/// Route: /profile/data-transparency
class DataTransparencyScreen extends StatelessWidget {
  const DataTransparencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      appBar: AppBar(
        backgroundColor: MintColors.porcelaine,
        surfaceTintColor: MintColors.porcelaine,
        elevation: 0,
        title: Text(
          l.dataTransparencyTitle,
          style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(MintSpacing.lg),
            children: [
              // Header
              Text(
                l.dataTransparencyTitle,
                style: MintTextStyles.headlineSmall(
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: MintSpacing.xl),

              // Salary entry — Local
              _DataActionCard(
                action: l.dataTransparencySalary,
                detail: l.dataTransparencySalaryDetail,
                badge: _BadgeType.local,
                icon: Icons.attach_money_rounded,
              ),
              const SizedBox(height: MintSpacing.md),

              // Document scan — Server
              _DataActionCard(
                action: l.dataTransparencyScan,
                detail: l.dataTransparencyScanDetail,
                badge: _BadgeType.server,
                icon: Icons.document_scanner_outlined,
              ),
              const SizedBox(height: MintSpacing.md),

              // Coach — Local or Server
              _DataActionCard(
                action: l.dataTransparencyCoach,
                detail: l.dataTransparencyCoachDetail,
                badge: _BadgeType.localOrServer,
                icon: Icons.smart_toy_outlined,
              ),
              const SizedBox(height: MintSpacing.md),

              // Bank import — Server
              _DataActionCard(
                action: l.dataTransparencyImport,
                detail: l.dataTransparencyImportDetail,
                badge: _BadgeType.server,
                icon: Icons.upload_file_rounded,
              ),
              const SizedBox(height: MintSpacing.md),

              // Account deletion — purge
              _DataActionCard(
                action: l.dataTransparencyDelete,
                detail: l.dataTransparencyDeleteDetail,
                badge: _BadgeType.local,
                icon: Icons.delete_outline_rounded,
              ),
              const SizedBox(height: MintSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}

enum _BadgeType { local, server, thirdParty, localOrServer }

class _DataActionCard extends StatelessWidget {
  final String action;
  final String detail;
  final _BadgeType badge;
  final IconData icon;

  const _DataActionCard({
    required this.action,
    required this.detail,
    required this.badge,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: MintColors.textSecondary),
          const SizedBox(width: MintSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  detail,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: MintSpacing.sm),
                _buildBadge(l),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(S l) {
    final String label;
    final Color color;

    switch (badge) {
      case _BadgeType.local:
        label = l.dataTransparencyLocal;
        color = MintColors.greenMint;
      case _BadgeType.server:
        label = l.dataTransparencyServer;
        color = MintColors.orangeGold;
      case _BadgeType.thirdParty:
        label = l.dataTransparencyThirdParty;
        color = MintColors.redApple;
      case _BadgeType.localOrServer:
        // Show both badges
        return Row(
          children: [
            _badgeChip(l.dataTransparencyLocal, MintColors.greenMint),
            const SizedBox(width: MintSpacing.xs),
            _badgeChip(l.dataTransparencyServer, MintColors.orangeGold),
          ],
        );
    }

    return _badgeChip(label, color);
  }

  Widget _badgeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: MintTextStyles.labelSmall(color: color),
          ),
        ],
      ),
    );
  }
}
